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
        <.link navigate={~p"/profiles/#{@profile}"} class="text-slate hover:text-[#A31F34] text-sm">
          &larr; {@profile.nickname}
        </.link>
        <h1 class="font-bold text-2xl text-[#A31F34] mt-1">{gettext("Search Notes")}</h1>

        <form phx-change="search" phx-submit="search" class="mt-4">
          <input
            type="text"
            name="query"
            value={@query}
            class="input-field w-full text-sm border-2 border-[#1A1A1A]"
            placeholder={gettext("Search by note text...")}
            phx-debounce="300"
          />
        </form>

        <div :if={@results != []} class="card-neo p-5 mt-4">
          <p class="text-slate text-xs mb-3">
            {ngettext("%{count} result found", "%{count} results found", length(@results))}
          </p>
          <table class="w-full text-sm">
            <thead>
              <tr class="text-[#A31F34] text-xs border-b border-[#E0DEDB]">
                <th class="text-left py-1 px-2">{gettext("Type")}</th>
                <th class="text-left py-1 px-2">{gettext("Category")}</th>
                <th class="text-left py-1 px-2">{gettext("Name")}</th>
                <th class="text-left py-1 px-2">{gettext("Period")}</th>
                <th class="text-right py-1 px-2">{gettext("Amount")}</th>
                <th class="text-left py-1 px-2">{gettext("Note")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={entry <- @results} class="border-b border-[#E0DEDB]/30">
                <td class={["py-1 px-2", if(entry.type == "income", do: "text-[#1D9E75]", else: "text-[#E24B4A]")]}>
                  {if entry.type == "income", do: "+", else: "-"}
                </td>
                <td class="py-1 px-2 text-slate">{entry.category}</td>
                <td class="py-1 px-2 text-ink">{entry.name}</td>
                <td class="py-1 px-2 text-slate">{month_name(entry.month)} {entry.year}</td>
                <td class={["py-1 px-2 text-right font-amount", if(entry.type == "income", do: "text-[#1D9E75]", else: "text-[#E24B4A]")]}>
                  {format_amount(entry.amount)}
                </td>
                <td class="py-1 px-2 text-ink">{entry.note}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div :if={@query != "" && @results == []} class="card-neo p-5 mt-4 text-center">
          <p class="text-slate">{gettext("No entries found with that note.")}</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
