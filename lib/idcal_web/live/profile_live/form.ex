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
    |> assign(:page_title, gettext("Forge a New Ledger"))
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
    |> assign(:page_title, gettext("Rename Ledger"))
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
         |> put_flash(:info, gettext("Ledger shared."))}

      {:error, :user_not_found} ->
        {:noreply, assign(socket, :share_error, gettext("No adventurer found with that email."))}

      {:error, :cannot_share_with_self} ->
        {:noreply, assign(socket, :share_error, gettext("Cannot share with thyself."))}

      {:error, _changeset} ->
        {:noreply, assign(socket, :share_error, gettext("Already shared with this adventurer."))}
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
         |> put_flash(:info, gettext("Ledger \"%{name}\" was forged.", name: profile.nickname))
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
         |> put_flash(:info, gettext("Ledger renamed."))
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
        <div class="panel p-6 space-y-4">
          <h1 class="font-cinzel font-bold text-2xl text-gold">{@page_title}</h1>

          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div>
              <label class="font-cinzel text-sm text-gold">{gettext("Title")}</label>
              <input
                type="text"
                name={@form[:nickname].name}
                value={Phoenix.HTML.Form.normalize_value("text", @form[:nickname].value)}
                class="input-medieval w-full mt-1"
                placeholder={gettext("e.g. Personal, Freelance Coffers")}
                autocomplete="off"
              />
              <p
                :for={msg <- Enum.map(@form[:nickname].errors, &translate_error/1)}
                class="text-expense text-sm mt-1"
              >
                {msg}
              </p>
            </div>

            <div>
              <label class="font-cinzel text-sm text-gold">📅 {gettext("Chronicle Begins")}</label>
              <p class="italic-fell text-muted text-xs mb-2">
                {gettext("Moons before this date shall be excluded from the chronicles.")}
              </p>
              <div class="flex gap-3">
                <div class="flex-1">
                  <label class="text-muted text-xs">{gettext("Year")}</label>
                  <input
                    type="number"
                    name={@form[:start_year].name}
                    value={Phoenix.HTML.Form.normalize_value("number", @form[:start_year].value)}
                    class="input-medieval w-full mt-1"
                    placeholder="2026"
                    min="1970"
                    max="9999"
                  />
                </div>
                <div class="flex-1">
                  <label class="text-muted text-xs">{gettext("Month")}</label>
                  <input
                    type="number"
                    name={@form[:start_month].name}
                    value={Phoenix.HTML.Form.normalize_value("number", @form[:start_month].value)}
                    class="input-medieval w-full mt-1"
                    placeholder="1"
                    min="1"
                    max="12"
                  />
                </div>
              </div>
              <p
                :for={msg <- Enum.map(@form[:start_year].errors ++ @form[:start_month].errors, &translate_error/1)}
                class="text-expense text-sm mt-1"
              >
                {msg}
              </p>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="font-cinzel text-sm text-gold">💰 {gettext("Currency")}</label>
                <select name={@form[:currency].name} class="input-medieval w-full mt-1">
                  <option :for={c <- ~w(BRL USD EUR GBP JPY CAD AUD CHF)} value={c} selected={to_string(@form[:currency].value) == c}>
                    {c}
                  </option>
                </select>
              </div>
              <div>
                <label class="font-cinzel text-sm text-gold">🎨 {gettext("Theme")}</label>
                <select name={@form[:theme].name} class="input-medieval w-full mt-1">
                  <option value="dark" selected={to_string(@form[:theme].value) == "dark"}>{gettext("Dark")}</option>
                  <option value="light" selected={to_string(@form[:theme].value) == "light"}>{gettext("Light")}</option>
                </select>
              </div>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn-medieval">{gettext("Save")}</button>
              <.link navigate={~p"/profiles"} class="btn-medieval">{gettext("Cancel")}</.link>
            </div>
          </.form>
        </div>

        <%!-- Sharing section (owner only, edit mode) --%>
        <div :if={@live_action == :edit && @is_owner} class="panel p-6 space-y-4 mt-6">
          <h2 class="font-cinzel font-bold text-lg text-gold">🤝 {gettext("Shared Adventurers")}</h2>
          <p class="italic-fell text-muted text-xs">
            {gettext("Invite another adventurer to view or edit this ledger.")}
          </p>

          <form phx-submit="share_profile" class="flex gap-2">
            <input
              type="email"
              name="email"
              value={@share_email}
              placeholder={gettext("Adventurer's email...")}
              class="input-medieval flex-1 text-sm"
              required
            />
            <select name="role" class="input-medieval text-sm">
              <option value="viewer">{gettext("Viewer")}</option>
              <option value="editor">{gettext("Editor")}</option>
            </select>
            <button type="submit" class="btn-medieval text-sm">
              {gettext("Invite")}
            </button>
          </form>
          <p :if={@share_error} class="text-[#8b1a1a] text-sm">{@share_error}</p>

          <div :if={@shares != []} class="space-y-2 mt-3">
            <div :for={share <- @shares} class="flex justify-between items-center border-b border-[#7a5c1e]/30 pb-2">
              <div>
                <span class="text-cream text-sm">{share.user.email}</span>
                <span class="text-muted text-xs ml-2">({share.role})</span>
              </div>
              <div class="flex gap-2">
                <button
                  :if={share.role == "viewer"}
                  phx-click="update_share_role"
                  phx-value-id={share.id}
                  phx-value-role="editor"
                  class="btn-medieval text-xs"
                >
                  {gettext("Promote")}
                </button>
                <button
                  :if={share.role == "editor"}
                  phx-click="update_share_role"
                  phx-value-id={share.id}
                  phx-value-role="viewer"
                  class="btn-medieval text-xs"
                >
                  {gettext("Demote")}
                </button>
                <button
                  phx-click="remove_share"
                  phx-value-id={share.id}
                  class="btn-medieval text-xs text-[#8b1a1a]"
                  data-confirm={gettext("Remove this adventurer's access?")}
                >
                  ✕
                </button>
              </div>
            </div>
          </div>
          <p :if={@shares == []} class="italic-fell text-muted text-sm">
            {gettext("No adventurers share this ledger yet.")}
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
