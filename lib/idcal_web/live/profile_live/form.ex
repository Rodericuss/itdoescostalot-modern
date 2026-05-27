defmodule IdcalWeb.ProfileLive.Form do
  use IdcalWeb, :live_view

  alias Idcal.Finances
  alias Idcal.Finances.Profile

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    profile = %Profile{}

    socket
    |> assign(:page_title, gettext("New Profile"))
    |> assign(:profile, profile)
    |> assign(:form, to_form(Finances.change_profile(profile)))
    |> assign(:is_owner, false)
    |> assign(:shares, [])
    |> assign(:share_email, "")
    |> assign(:share_error, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    profile = Finances.get_profile!(socket.assigns.current_scope, id)
    is_owner = profile.user_id == socket.assigns.current_scope.user.id

    socket
    |> assign(:page_title, gettext("Edit Profile"))
    |> assign(:profile, profile)
    |> assign(:form, to_form(Finances.change_profile(profile)))
    |> assign(:is_owner, is_owner)
    |> assign(:shares, if(is_owner, do: Finances.list_profile_shares(profile), else: []))
    |> assign(:share_email, "")
    |> assign(:share_error, nil)
  end

  @impl true
  def handle_event("validate", %{"profile" => params}, socket) do
    changeset = Finances.change_profile(socket.assigns.profile, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"profile" => params}, socket) do
    save_profile(socket, socket.assigns.live_action, params)
  end

  def handle_event("share_profile", %{"email" => email, "role" => role}, socket) do
    profile = socket.assigns.profile

    case Finances.share_profile(profile, String.trim(email), role) do
      {:ok, _share} ->
        {:noreply,
         socket
         |> assign(:shares, Finances.list_profile_shares(profile))
         |> assign(:share_email, "")
         |> assign(:share_error, nil)
         |> put_flash(:info, gettext("Profile shared."))}

      {:error, :user_not_found} ->
        {:noreply, assign(socket, :share_error, gettext("No user found with that email."))}

      {:error, :cannot_share_with_self} ->
        {:noreply, assign(socket, :share_error, gettext("Cannot share with yourself."))}

      {:error, _changeset} ->
        {:noreply, assign(socket, :share_error, gettext("Already shared with this user."))}
    end
  end

  def handle_event("remove_share", %{"id" => id}, socket) do
    profile = socket.assigns.profile
    share = Enum.find(socket.assigns.shares, &(to_string(&1.id) == id))

    if share do
      Finances.delete_profile_share(share)
      {:noreply,
       socket
       |> assign(:shares, Finances.list_profile_shares(profile))
       |> put_flash(:info, gettext("Share removed."))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_share_role", %{"id" => id, "role" => role}, socket) do
    profile = socket.assigns.profile
    share = Enum.find(socket.assigns.shares, &(to_string(&1.id) == id))

    if share do
      Finances.update_profile_share(share, %{role: role})
      {:noreply,
       socket
       |> assign(:shares, Finances.list_profile_shares(profile))
       |> put_flash(:info, gettext("Role updated."))}
    else
      {:noreply, socket}
    end
  end

  defp save_profile(socket, :new, params) do
    case Finances.create_profile(socket.assigns.current_scope, params) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile \"%{name}\" was created.", name: profile.nickname))
         |> push_navigate(to: ~p"/profiles/#{profile}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  defp save_profile(socket, :edit, params) do
    case Finances.update_profile(socket.assigns.profile, params) do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile updated."))
         |> push_navigate(to: ~p"/profiles/#{profile}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="card-neo p-6 space-y-4">
          <h1 class="font-bold text-2xl text-[#A31F34]">{@page_title}</h1>

          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div>
              <label class="text-sm text-[#A31F34]">{gettext("Nickname")}</label>
              <input
                type="text"
                name={@form[:nickname].name}
                value={Phoenix.HTML.Form.normalize_value("text", @form[:nickname].value)}
                class="input-field w-full mt-1"
                placeholder={gettext("e.g. Personal, Freelance Income")}
                autocomplete="off"
              />
              <p
                :for={msg <- Enum.map(@form[:nickname].errors, &translate_error/1)}
                class="text-negative text-sm mt-1"
              >
                {msg}
              </p>
            </div>

            <div>
              <label class="text-sm text-[#A31F34]">{gettext("Start Date")}</label>
              <p class="text-slate text-xs mb-2">
                {gettext("Months before this date will not be tracked.")}
              </p>
              <div class="flex gap-3">
                <div class="flex-1">
                  <label class="text-slate text-xs">{gettext("Year")}</label>
                  <input
                    type="number"
                    name={@form[:start_year].name}
                    value={Phoenix.HTML.Form.normalize_value("number", @form[:start_year].value)}
                    class="input-field w-full mt-1"
                    placeholder="2026"
                    min="1970"
                    max="9999"
                  />
                </div>
                <div class="flex-1">
                  <label class="text-slate text-xs">{gettext("Month")}</label>
                  <input
                    type="number"
                    name={@form[:start_month].name}
                    value={Phoenix.HTML.Form.normalize_value("number", @form[:start_month].value)}
                    class="input-field w-full mt-1"
                    placeholder="1"
                    min="1"
                    max="12"
                  />
                </div>
              </div>
              <p
                :for={msg <- Enum.map(@form[:start_year].errors ++ @form[:start_month].errors, &translate_error/1)}
                class="text-negative text-sm mt-1"
              >
                {msg}
              </p>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="text-sm text-[#A31F34]">{gettext("Currency")}</label>
                <select name={@form[:currency].name} class="input-field w-full mt-1">
                  <option :for={c <- ~w(BRL USD EUR GBP JPY CAD AUD CHF)} value={c} selected={to_string(@form[:currency].value) == c}>
                    {c}
                  </option>
                </select>
              </div>
              <div>
                <label class="text-sm text-[#A31F34]">{gettext("Theme")}</label>
                <select name={@form[:theme].name} class="input-field w-full mt-1">
                  <option value="dark" selected={to_string(@form[:theme].value) == "dark"}>{gettext("Dark")}</option>
                  <option value="light" selected={to_string(@form[:theme].value) == "light"}>{gettext("Light")}</option>
                </select>
              </div>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn-primary">{gettext("Save")}</button>
              <.link navigate={~p"/profiles"} class="btn-ghost">{gettext("Cancel")}</.link>
            </div>
          </.form>
        </div>

        <%!-- Sharing section (owner only, edit mode) --%>
        <div :if={@live_action == :edit && @is_owner} class="card-neo p-6 space-y-4 mt-6">
          <h2 class="font-bold text-lg text-[#A31F34]">{gettext("Shared Users")}</h2>
          <p class="text-slate text-xs">
            {gettext("Invite another user to view or edit this profile.")}
          </p>

          <form phx-submit="share_profile" class="flex gap-2">
            <input
              type="email"
              name="email"
              value={@share_email}
              placeholder={gettext("User's email...")}
              class="input-field flex-1 text-sm"
              required
            />
            <select name="role" class="input-field text-sm">
              <option value="viewer">{gettext("Viewer")}</option>
              <option value="editor">{gettext("Editor")}</option>
            </select>
            <button type="submit" class="btn-primary text-sm">
              {gettext("Invite")}
            </button>
          </form>
          <p :if={@share_error} class="text-[#E24B4A] text-sm">{@share_error}</p>

          <div :if={@shares != []} class="space-y-2 mt-3">
            <div :for={share <- @shares} class="flex justify-between items-center border-b border-[#E0DEDB]/30 pb-2">
              <div>
                <span class="text-ink text-sm">{share.user.email}</span>
                <span class="text-slate text-xs ml-2">({share.role})</span>
              </div>
              <div class="flex gap-2">
                <button
                  :if={share.role == "viewer"}
                  phx-click="update_share_role"
                  phx-value-id={share.id}
                  phx-value-role="editor"
                  class="btn-ghost text-xs"
                >
                  {gettext("Promote")}
                </button>
                <button
                  :if={share.role == "editor"}
                  phx-click="update_share_role"
                  phx-value-id={share.id}
                  phx-value-role="viewer"
                  class="btn-ghost text-xs"
                >
                  {gettext("Demote")}
                </button>
                <button
                  phx-click="remove_share"
                  phx-value-id={share.id}
                  class="btn-ghost text-xs text-[#E24B4A]"
                  data-confirm={gettext("Remove this user's access?")}
                >
                  ✕
                </button>
              </div>
            </div>
          </div>
          <p :if={@shares == []} class="text-slate text-sm">
            {gettext("No users share this profile yet.")}
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
