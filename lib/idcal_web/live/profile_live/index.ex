defmodule IdcalWeb.ProfileLive.Index do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  @impl true
  def mount(_params, _session, socket) do
    profiles = Finances.list_profiles(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, gettext("Your Profiles"))
     |> assign(:profiles, profiles)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, id)
    {:ok, _} = Finances.delete_profile(profile)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Profile \"%{name}\" was deleted.", name: profile.nickname))
     |> assign(:profiles, Finances.list_profiles(socket.assigns.current_scope))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-between">
        <h1 class="font-bold text-3xl text-[#A31F34]">{gettext("Your Profiles")}</h1>
        <div class="flex gap-2">
          <.link :if={length(@profiles) >= 2} navigate={~p"/profiles/compare"} class="btn-ghost">
            {gettext("Compare")}
          </.link>
          <.link navigate={~p"/profiles/new"} class="btn-primary">
            {gettext("New Profile")}
          </.link>
        </div>
      </div>

      <div :if={@profiles == []} class="card-neo p-10 text-center">
        <p class="text-slate mt-3">
          {gettext("No profiles yet, create your first one to start tracking.")}
        </p>
      </div>

      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div :for={profile <- @profiles} class="card-neo p-5 flex flex-col gap-3">
          <h2 class="card-title text-xl">{profile.nickname}</h2>
          <div class="flex gap-2 mt-auto">
            <.link navigate={~p"/profiles/#{profile}"} class="btn-primary flex-1 justify-center">
              {gettext("Open")}
            </.link>
            <.link
              navigate={~p"/profiles/#{profile}/settings"}
              class="btn-ghost"
              title={gettext("Rename")}
            >
              <.icon name="hero-pencil-square" class="size-5" />
            </.link>
            <button
              class="btn-ghost btn-danger"
              phx-click="delete"
              phx-value-id={profile.id}
              data-confirm={
                gettext("Delete the profile \"%{name}\"? All its data is lost forever.",
                  name: profile.nickname
                )
              }
              title={gettext("Delete")}
            >
              <.icon name="hero-trash" class="size-5" />
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
