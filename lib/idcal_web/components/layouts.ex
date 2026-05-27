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
            {gettext("It Does Cost A Lot")}
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
