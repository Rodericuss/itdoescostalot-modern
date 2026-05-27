defmodule IdcalWeb.CalendarLive.Index do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  import IdcalWeb.FormatHelpers, only: [month_abbr: 1]

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)
    year = Date.utc_today().year

    {:ok,
     socket
     |> assign(:page_title, gettext("Recurring Calendar"))
     |> assign(:profile, profile)
     |> assign(:year, year)
     |> load_calendar(profile, year)}
  end

  @impl true
  def handle_event("change_year", %{"year" => year_str}, socket) do
    case Integer.parse(year_str) do
      {year, ""} when year in 1970..9999 ->
        {:noreply,
         socket
         |> assign(:year, year)
         |> load_calendar(socket.assigns.profile, year)}
      _ ->
        {:noreply, socket}
    end
  end

  defp load_calendar(socket, profile, year) do
    data = Finances.recurring_calendar(profile, year)
    assign(socket, :calendar, data)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.link navigate={~p"/profiles/#{@profile}"} class="text-slate hover:text-[#A31F34] text-sm">
        &larr; {@profile.nickname}
      </.link>
      <h1 class="font-bold text-2xl text-[#A31F34] mt-1">{gettext("Recurring Calendar")}</h1>
      <p class="text-slate text-sm mb-4">{gettext("Monthly entries with highlighted gaps.")}</p>

      <div class="flex items-center justify-center gap-4 mb-4">
        <button phx-click="change_year" phx-value-year={@year - 1} class="btn-ghost text-sm">&larr;</button>
        <span class="text-xl text-[#A31F34]">{@year}</span>
        <button phx-click="change_year" phx-value-year={@year + 1} class="btn-ghost text-sm">&rarr;</button>
      </div>

      <div :if={@calendar.income_sources != []} class="card-neo p-5 mb-4">
        <h2 class="card-title text-lg text-[#1D9E75] mb-3">{gettext("Income Sources")}</h2>
        <.calendar_grid items={@calendar.income_sources} entries={@calendar.income} kind={:income} />
      </div>

      <div :if={@calendar.expense_types != []} class="card-neo p-5">
        <h2 class="card-title text-lg text-[#E24B4A] mb-3">{gettext("Expense Types")}</h2>
        <.calendar_grid items={@calendar.expense_types} entries={@calendar.expense} kind={:expense} />
      </div>

      <div :if={@calendar.income_sources == [] && @calendar.expense_types == []} class="card-neo p-5 text-center">
        <p class="text-slate">{gettext("No recurring entries to display.")}</p>
      </div>
    </Layouts.app>
    """
  end

  defp calendar_grid(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-xs">
        <thead>
          <tr class="text-[#A31F34] border-b border-[#E0DEDB]">
            <th class="text-left py-1 px-2">{gettext("Name")}</th>
            <th :for={m <- 1..12} class="text-center py-1 px-1 w-12">{month_abbr(m)}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={item <- @items} class="border-b border-[#E0DEDB]/20">
            <td class="py-1 px-2 text-ink">{item.name}</td>
            <td :for={m <- 1..12} class="text-center py-1">
              <% has = Enum.any?(@entries, fn {name, kind, month, _} -> name == item.name && kind == @kind && month == m end) %>
              <span :if={has} class="text-[#1D9E75]">✓</span>
              <span :if={!has} class="text-[#E24B4A]">·</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
