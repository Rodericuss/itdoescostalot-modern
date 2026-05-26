defmodule IdcalWeb.SearchLive.Index do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  import IdcalWeb.FormatHelpers, only: [month_name: 1, format_amount: 1]

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Search Notes"))
     |> assign(:profile, profile)
     |> assign(:query, "")
     |> assign(:results, [])}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results =
      if String.trim(query) != "" do
        Finances.search_entries_by_note(socket.assigns.profile, String.trim(query))
      else
        []
      end

    {:noreply, assign(socket, query: query, results: results)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <.link navigate={~p"/profiles/#{@profile}"} class="text-muted hover:text-gold font-cinzel text-sm">
          &larr; {@profile.nickname}
        </.link>
        <h1 class="font-cinzel-decorative font-bold text-2xl text-gold mt-1">🔎 {gettext("Search Notes")}</h1>

        <form phx-change="search" phx-submit="search" class="mt-4">
          <input
            type="text"
            name="query"
            value={@query}
            class="input-medieval w-full text-sm"
            placeholder={gettext("Search by note text...")}
            phx-debounce="300"
          />
        </form>

        <div :if={@results != []} class="panel p-5 mt-4">
          <p class="text-muted text-xs mb-3">
            {ngettext("%{count} result found", "%{count} results found", length(@results))}
          </p>
          <table class="w-full text-sm">
            <thead>
              <tr class="text-gold font-cinzel text-xs border-b border-[#7a5c1e]">
                <th class="text-left py-1 px-2">{gettext("Type")}</th>
                <th class="text-left py-1 px-2">{gettext("Guild")}</th>
                <th class="text-left py-1 px-2">{gettext("Name")}</th>
                <th class="text-left py-1 px-2">{gettext("Period")}</th>
                <th class="text-right py-1 px-2">{gettext("Amount")}</th>
                <th class="text-left py-1 px-2">{gettext("Note")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={entry <- @results} class="border-b border-[#7a5c1e]/30">
                <td class={["py-1 px-2", if(entry.type == "income", do: "text-[#3d8b3d]", else: "text-[#8b1a1a]")]}>
                  {if entry.type == "income", do: "🪙", else: "💸"}
                </td>
                <td class="py-1 px-2 text-muted">{entry.category}</td>
                <td class="py-1 px-2 text-cream">{entry.name}</td>
                <td class="py-1 px-2 text-muted">{month_name(entry.month)} {entry.year}</td>
                <td class={["py-1 px-2 text-right font-mono", if(entry.type == "income", do: "text-[#3d8b3d]", else: "text-[#8b1a1a]")]}>
                  {format_amount(entry.amount)}
                </td>
                <td class="py-1 px-2 text-cream">{entry.note}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div :if={@query != "" && @results == []} class="panel p-5 mt-4 text-center">
          <p class="italic-fell text-muted">{gettext("No entries found with that note.")}</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
