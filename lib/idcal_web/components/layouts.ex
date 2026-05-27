defmodule IdcalWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use IdcalWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="bg-white border-b-2 border-[#1A1A1A]">
      <div class="mx-auto max-w-6xl flex items-center justify-between px-4 py-3 sm:px-6">
        <a href="/" class="flex items-center gap-2">
          <span class="inline-block w-7 h-7 bg-[#A31F34] border-2 border-[#1A1A1A] rounded-sm"></span>
          <span class="font-bold text-xl text-[#1A1A1A]">IDCAL</span>
          <span class="hidden sm:inline text-slate text-sm">
            It Does Cost A Lot
          </span>
        </a>
        <ul class="flex items-center gap-4 text-sm font-medium">
          <%= if @current_scope do %>
            <li class="hidden sm:block">
              <span class="inline-flex items-center justify-center w-7 h-7 rounded-full bg-[#A31F34] text-white text-xs font-bold border-2 border-[#1A1A1A]" title={@current_scope.user.email}>
                {String.first(@current_scope.user.email) |> String.upcase()}
              </span>
            </li>
            <li>
              <.link href={~p"/profiles"} class="text-ink hover:text-[#A31F34]">{gettext("Profiles")}</.link>
            </li>
            <li>
              <.link href={~p"/users/settings"} class="text-ink hover:text-[#A31F34]">
                {gettext("Settings")}
              </.link>
            </li>
            <li>
              <.link href={~p"/users/log-out"} method="delete" class="text-ink hover:text-[#A31F34]">
                {gettext("Log out")}
              </.link>
            </li>
          <% else %>
            <li>
              <.link href={~p"/users/register"} class="text-ink hover:text-[#A31F34]">
                {gettext("Register")}
              </.link>
            </li>
            <li>
              <.link href={~p"/users/log-in"} class="btn-primary text-sm">
                {gettext("Log in")}
              </.link>
            </li>
          <% end %>
          <li><.locale_switcher /></li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-10 sm:px-6">
      <div class="mx-auto max-w-6xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc "Language switcher (EN | PT) shown in the top bar."
  def locale_switcher(assigns) do
    assigns = assign(assigns, :current, Gettext.get_locale(IdcalWeb.Gettext))

    ~H"""
    <div class="flex items-center gap-1 text-sm" title={gettext("Language")}>
      <.link
        href={~p"/locale/en"}
        class={if @current == "en", do: "text-[#A31F34] font-semibold", else: "text-slate hover:text-[#A31F34]"}
      >
        EN
      </.link>
      <span class="text-slate">|</span>
      <.link
        href={~p"/locale/pt"}
        class={if @current == "pt", do: "text-[#A31F34] font-semibold", else: "text-slate hover:text-[#A31F34]"}
      >
        PT
      </.link>
    </div>
    """
  end

  @doc """
  Layout for profile-scoped pages with a persistent sidebar navigation.

  Desktop (lg+): fixed sidebar on the left, content on the right.
  Mobile (<lg): hamburger button opens a drawer overlay.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :profile, :map, required: true
  attr :active_page, :atom, required: true
  slot :inner_block, required: true

  def profile_app(assigns) do
    ~H"""
    <%!-- Mobile top bar --%>
    <header class="lg:hidden bg-white border-b-2 border-[#1A1A1A] sticky top-0 z-30">
      <div class="flex items-center justify-between px-4 py-3">
        <button
          phx-click={JS.show(to: "#sidebar-overlay") |> JS.show(to: "#sidebar-drawer", transition: {"transition-transform duration-200", "-translate-x-full", "translate-x-0"})}
          class="p-1"
          aria-label="Menu"
        >
          <.icon name="hero-bars-3" class="size-6 text-[#1A1A1A]" />
        </button>
        <a href="/" class="flex items-center gap-2">
          <span class="inline-block w-6 h-6 bg-[#A31F34] border-2 border-[#1A1A1A] rounded-sm"></span>
          <span class="font-bold text-lg text-[#1A1A1A]">IDCAL</span>
        </a>
        <span class="text-sm font-medium text-slate truncate max-w-[8rem]">{@profile.nickname}</span>
      </div>
    </header>

    <%!-- Mobile drawer overlay --%>
    <div id="sidebar-overlay" class="fixed inset-0 z-40 lg:hidden hidden">
      <div
        class="fixed inset-0 bg-black/30"
        phx-click={JS.hide(to: "#sidebar-overlay") |> JS.hide(to: "#sidebar-drawer", transition: {"transition-transform duration-200", "translate-x-0", "-translate-x-full"})}
      />
      <nav id="sidebar-drawer" class="fixed left-0 top-0 bottom-0 w-72 sidebar-neo overflow-y-auto -translate-x-full transition-transform duration-200">
        <.sidebar_nav profile={@profile} active_page={@active_page} current_scope={@current_scope} />
      </nav>
    </div>

    <%!-- Desktop sidebar --%>
    <aside class="hidden lg:flex lg:flex-col lg:fixed lg:inset-y-0 lg:w-64 sidebar-neo overflow-y-auto z-20">
      <.sidebar_nav profile={@profile} active_page={@active_page} current_scope={@current_scope} />
    </aside>

    <%!-- Main content --%>
    <main class="lg:pl-64">
      <div class="px-4 py-8 sm:px-6 mx-auto max-w-5xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :profile, :map, required: true
  attr :active_page, :atom, required: true
  attr :current_scope, :map, default: nil

  defp sidebar_nav(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <%!-- Profile header --%>
      <div class="p-4 border-b-2 border-[#1A1A1A]">
        <a href="/" class="flex items-center gap-2 mb-3">
          <span class="inline-block w-6 h-6 bg-[#A31F34] border-2 border-[#1A1A1A] rounded-sm"></span>
          <span class="font-bold text-lg text-[#1A1A1A]">IDCAL</span>
        </a>
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-[#A31F34] text-white text-sm font-bold border-2 border-[#1A1A1A]">
            {String.first(@profile.nickname) |> String.upcase()}
          </span>
          <span class="font-semibold text-[#1A1A1A] truncate">{@profile.nickname}</span>
        </div>
      </div>

      <%!-- Navigation --%>
      <nav class="flex-1 p-3 space-y-1">
        <.sidebar_item navigate={~p"/profiles/#{@profile}"} icon="hero-home" label={gettext("Dashboard")} active={@active_page == :dashboard} />
        <.sidebar_item navigate={~p"/profiles/#{@profile}/income"} icon="hero-arrow-trending-up" label={gettext("Income")} active={@active_page == :income} />
        <.sidebar_item navigate={~p"/profiles/#{@profile}/expenses"} icon="hero-arrow-trending-down" label={gettext("Expenses")} active={@active_page == :expenses} />
        <.sidebar_item navigate={~p"/profiles/#{@profile}/goals"} icon="hero-flag" label={gettext("Goals")} active={@active_page == :goals} />

        <div class="pt-3 pb-1">
          <span class="sidebar-section-label">{gettext("Analysis")}</span>
        </div>
        <.sidebar_item navigate={~p"/profiles/#{@profile}/insights"} icon="hero-light-bulb" label={gettext("Insights")} active={@active_page == :insights} />
        <.sidebar_item navigate={~p"/profiles/#{@profile}/forecast"} icon="hero-chart-bar-square" label={gettext("Forecast")} active={@active_page == :forecast} />
        <.sidebar_item navigate={~p"/profiles/#{@profile}/calendar"} icon="hero-calendar" label={gettext("Calendar")} active={@active_page == :calendar} />

        <div class="pt-3 pb-1">
          <span class="sidebar-section-label">{gettext("Tools")}</span>
        </div>
        <.sidebar_item navigate={~p"/profiles/#{@profile}/quick"} icon="hero-bolt" label={gettext("Quick Entry")} active={@active_page == :quick} />
        <.sidebar_item navigate={~p"/profiles/#{@profile}/search"} icon="hero-magnifying-glass" label={gettext("Search")} active={@active_page == :search} />
      </nav>

      <%!-- System links --%>
      <div class="p-3 border-t-2 border-[#E0DEDB] space-y-1">
        <.sidebar_item navigate={~p"/profiles"} icon="hero-user-group" label={gettext("All Profiles")} active={false} />
        <.sidebar_item navigate={~p"/profiles/#{@profile}/settings"} icon="hero-cog-6-tooth" label={gettext("Profile Settings")} active={@active_page == :settings} />
        <.link href={~p"/users/log-out"} method="delete" class="sidebar-link">
          <.icon name="hero-arrow-right-on-rectangle" class="size-5" />
          {gettext("Log out")}
        </.link>
        <div class="pt-2">
          <.locale_switcher />
        </div>
      </div>
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true

  defp sidebar_item(assigns) do
    ~H"""
    <.link navigate={@navigate} class={["sidebar-link", @active && "active"]}>
      <.icon name={@icon} class="size-5" />
      {@label}
    </.link>
    """
  end

  @doc "A simple inline SVG coin icon."
  attr :class, :string, default: "size-6"

  def coin_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="12" cy="12" r="9" fill="currentColor" opacity="0.25" />
      <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2" />
      <circle cx="12" cy="12" r="5.5" stroke="currentColor" stroke-width="1.5" />
      <path d="M12 9v6M9.5 12h5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
    </svg>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
