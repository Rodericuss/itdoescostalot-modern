defmodule IdcalWeb.ProfileLive.Show do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  import IdcalWeb.FormatHelpers, only: [month_abbr: 1, format_short: 1]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, id)
    year = Date.utc_today().year

    {:ok,
     socket
     |> assign(:page_title, profile.nickname)
     |> assign(:profile, profile)
     |> assign(:year, year)
     |> load_annual_data(profile, year)}
  end

  @impl true
  def handle_event("change_year", %{"year" => year_str}, socket) do
    case Integer.parse(year_str) do
      {year, ""} when year in 1970..9999 ->
        {:noreply,
         socket
         |> assign(:year, year)
         |> load_annual_data(socket.assigns.profile, year)}

      _ ->
        {:noreply, socket}
    end
  end

  defp load_annual_data(socket, profile, year) do
    months = Finances.annual_summary(profile, year)

    budget_by_month =
      Enum.into(1..12, %{}, fn m ->
        statuses = Finances.budget_status_for_month(profile, year, m)
        over = Enum.count(statuses, fn {_, s} -> Decimal.gte?(s.percentage, 100) end)
        total = length(statuses)
        {m, %{over: over, total: total}}
      end)

    months = Enum.map(months, fn m -> Map.put(m, :budget, Map.get(budget_by_month, m.month)) end)
    tracked_months = Enum.filter(months, & &1.tracked)

    cumulative =
      tracked_months
      |> Enum.scan(Decimal.new(0), fn %{balance: b}, acc -> Decimal.add(acc, b) end)

    bar_chart_data = build_bar_chart(tracked_months)
    line_chart_data = build_line_chart(tracked_months, cumulative)

    socket
    |> assign(:months, months)
    |> assign(:cumulative, cumulative)
    |> assign(:bar_chart_data, bar_chart_data)
    |> assign(:line_chart_data, line_chart_data)
  end

  defp build_bar_chart(months) do
    labels = Enum.map(months, fn %{month: m} -> month_abbr(m) end)
    income_data = Enum.map(months, fn %{income: i} -> Decimal.to_float(i) end)
    expense_data = Enum.map(months, fn %{expenses: e} -> Decimal.to_float(e) end)

    Jason.encode!(%{
      labels: labels,
      datasets: [
        %{label: gettext("Coffers"), data: income_data, backgroundColor: "#3d8b3d"},
        %{label: gettext("Tributes"), data: expense_data, backgroundColor: "#8b1a1a"}
      ]
    })
  end

  defp build_line_chart(tracked_months, cumulative) do
    labels = Enum.map(tracked_months, fn %{month: m} -> month_abbr(m) end)
    data = Enum.map(cumulative, &Decimal.to_float/1)

    Jason.encode!(%{
      labels: labels,
      datasets: [
        %{
          label: gettext("Amassed Hoard"),
          data: data,
          borderColor: "#d4a017",
          backgroundColor: "rgba(212, 160, 23, 0.1)",
          fill: true,
          tension: 0.3
        }
      ]
    })
  end

  defp bar_chart_options do
    Jason.encode!(%{
      responsive: true,
      plugins: %{legend: %{labels: %{color: "#f0dfa0", font: %{family: "Cinzel"}}}},
      scales: %{
        x: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}},
        y: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}}
      }
    })
  end

  defp line_chart_options do
    Jason.encode!(%{
      responsive: true,
      plugins: %{legend: %{labels: %{color: "#f0dfa0", font: %{family: "Cinzel"}}}},
      scales: %{
        x: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}},
        y: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}}
      }
    })
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-between">
        <div>
          <.link navigate={~p"/profiles"} class="text-muted hover:text-gold font-cinzel text-sm">
            &larr; {gettext("All Ledgers")}
          </.link>
          <h1 class="font-cinzel-decorative font-bold text-3xl text-gold mt-1">📖 {@profile.nickname}</h1>
        </div>
        <div class="flex items-center gap-3">
          <.link navigate={~p"/profiles/#{@profile}/income"} class="btn-medieval text-sm">
            🪙 {gettext("Coffers")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/expenses"} class="btn-medieval text-sm">
            💸 {gettext("Tributes")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/goals"} class="btn-medieval text-sm">
            🏆 {gettext("Quests")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/insights"} class="btn-medieval text-sm">
            🔍 {gettext("Insights")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/forecast"} class="btn-medieval text-sm">
            🔮 {gettext("Forecast")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/quick"} class="btn-medieval text-sm">
            ⚡ {gettext("Quick")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/search"} class="btn-medieval text-sm">
            🔎 {gettext("Search")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/calendar"} class="btn-medieval text-sm">
            📅 {gettext("Calendar")}
          </.link>
          <.link navigate={~p"/profiles/#{@profile}/settings"} class="btn-medieval text-sm">
            <.icon name="hero-cog-6-tooth" class="size-4" />
          </.link>
        </div>
      </div>

      <%!-- Year selector --%>
      <div class="flex items-center justify-center gap-4">
        <button phx-click="change_year" phx-value-year={@year - 1} class="btn-medieval text-sm">&larr;</button>
        <span class="font-cinzel text-2xl text-gold">{@year}</span>
        <button phx-click="change_year" phx-value-year={@year + 1} class="btn-medieval text-sm">&rarr;</button>
      </div>

      <%!-- 12 Month Cards --%>
      <div class="grid gap-3 grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
        <.link
          :for={m <- @months}
          navigate={~p"/profiles/#{@profile}/month/#{@year}/#{m.month}"}
          class={[
            "panel p-3 hover:border-[#d4a017] transition-colors text-center",
            if(m.tracked, do: month_card_border(m.balance), else: "opacity-40 border-dashed")
          ]}
        >
          <p class="font-cinzel text-gold text-sm">{month_abbr(m.month)}</p>
          <%= if m.tracked do %>
            <div class="mt-2 space-y-0.5 text-xs font-mono">
              <p class="text-[#3d8b3d]">{short_amount(m.income)}</p>
              <p class="text-[#8b1a1a]">{short_amount(m.expenses)}</p>
              <p class={balance_color(m.balance)}>{short_amount(m.balance)}</p>
            </div>
            <p :if={m.budget.total > 0 && m.budget.over > 0} class="mt-1 text-xs text-[#8b1a1a]">
              ⚠️ {ngettext("%{count} guild over limit", "%{count} guilds over limit", m.budget.over)}
            </p>
          <% else %>
            <p class="mt-2 text-xs italic-fell text-muted">🚫 {gettext("Not tracked")}</p>
          <% end %>
        </.link>
      </div>

      <%!-- Charts --%>
      <div class="grid gap-6 lg:grid-cols-2">
        <div class="panel p-5">
          <h2 class="panel-title text-lg mb-3">⚔️ {gettext("Coffers vs Tributes")}</h2>
          <canvas
            id={"bar-chart-#{@year}"}
            phx-hook="ChartHook"
            data-chart-type="bar"
            data-chart-data={@bar_chart_data}
            data-chart-options={bar_chart_options()}
          />
        </div>
        <div class="panel p-5">
          <h2 class="panel-title text-lg mb-3">📊 {gettext("Amassed Hoard")}</h2>
          <canvas
            id={"line-chart-#{@year}"}
            phx-hook="ChartHook"
            data-chart-type="line"
            data-chart-data={@line_chart_data}
            data-chart-options={line_chart_options()}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp month_card_border(balance) do
    case Decimal.compare(balance, 0) do
      :gt -> "border-[#3d8b3d]/50"
      :lt -> "border-[#8b1a1a]/50"
      _ -> ""
    end
  end

  defp balance_color(balance) do
    case Decimal.compare(balance, 0) do
      :lt -> "text-[#8b1a1a]"
      _ -> "text-[#3d8b3d]"
    end
  end

  defp short_amount(decimal), do: format_short(decimal)
end
