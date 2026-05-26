defmodule IdcalWeb.InsightsLive.Show do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  import IdcalWeb.FormatHelpers, only: [month_name: 1, month_abbr: 1, format_amount: 1]

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)
    today = Date.utc_today()

    {:ok,
     socket
     |> assign(:page_title, gettext("Insights"))
     |> assign(:profile, profile)
     |> assign(:year, today.year)
     |> assign(:month, today.month)
     |> load_insights(profile, today.year, today.month)}
  end

  @impl true
  def handle_event("change_month", %{"year" => y, "month" => m}, socket) do
    with {year, ""} <- Integer.parse(y),
         {month, ""} <- Integer.parse(m),
         true <- month in 1..12,
         true <- year in 1970..9999 do
      {:noreply,
       socket
       |> assign(:year, year)
       |> assign(:month, month)
       |> load_insights(socket.assigns.profile, year, month)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("prev_month", _params, socket) do
    {y, m} = if socket.assigns.month == 1, do: {socket.assigns.year - 1, 12}, else: {socket.assigns.year, socket.assigns.month - 1}

    {:noreply,
     socket
     |> assign(:year, y)
     |> assign(:month, m)
     |> load_insights(socket.assigns.profile, y, m)}
  end

  def handle_event("next_month", _params, socket) do
    {y, m} = if socket.assigns.month == 12, do: {socket.assigns.year + 1, 1}, else: {socket.assigns.year, socket.assigns.month + 1}

    {:noreply,
     socket
     |> assign(:year, y)
     |> assign(:month, m)
     |> load_insights(socket.assigns.profile, y, m)}
  end

  defp load_insights(socket, profile, year, month) do
    trend = Finances.trend_analysis(profile, year, month)
    averages = Finances.rolling_expense_averages(profile, year, month)
    ratio_data = Finances.income_expense_ratio_over_year(profile, year)

    socket
    |> assign(:trend, trend)
    |> assign(:averages, averages)
    |> assign(:ratio_data, ratio_data)
    |> assign(:ratio_chart, build_ratio_chart(ratio_data))
  end

  defp build_ratio_chart(ratio_data) do
    active = Enum.filter(ratio_data, & &1.ratio)
    labels = Enum.map(active, fn %{month: m} -> month_abbr(m) end)
    data = Enum.map(active, fn %{ratio: r} -> Decimal.to_float(r) end)

    Jason.encode!(%{
      labels: labels,
      datasets: [
        %{
          label: gettext("Income / Expense Ratio"),
          data: data,
          borderColor: "#d4a017",
          backgroundColor: "rgba(212, 160, 23, 0.1)",
          fill: true,
          tension: 0.3
        }
      ]
    })
  end

  defp ratio_chart_options do
    Jason.encode!(%{
      responsive: true,
      plugins: %{
        legend: %{labels: %{color: "#f0dfa0", font: %{family: "Cinzel"}}},
        annotation: %{
          annotations: %{
            line1: %{type: "line", yMin: 1, yMax: 1, borderColor: "#7a5c1e", borderWidth: 1, borderDash: [5, 5]}
          }
        }
      },
      scales: %{
        x: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}},
        y: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}, min: 0}
      }
    })
  end

  defp change_indicator(nil), do: "—"
  defp change_indicator(pct) do
    cond do
      Decimal.gt?(pct, 0) -> "+#{Decimal.to_string(pct)}%"
      Decimal.lt?(pct, 0) -> "#{Decimal.to_string(pct)}%"
      true -> "0%"
    end
  end

  defp change_color(nil, _), do: "text-muted"
  defp change_color(pct, :income) do
    cond do
      Decimal.gt?(pct, 0) -> "text-[#3d8b3d]"
      Decimal.lt?(pct, 0) -> "text-[#8b1a1a]"
      true -> "text-muted"
    end
  end
  defp change_color(pct, :expense) do
    cond do
      Decimal.gt?(pct, 0) -> "text-[#8b1a1a]"
      Decimal.lt?(pct, 0) -> "text-[#3d8b3d]"
      true -> "text-muted"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-between">
        <div>
          <.link navigate={~p"/profiles/#{@profile}"} class="text-muted hover:text-gold font-cinzel text-sm">
            &larr; {@profile.nickname}
          </.link>
          <h1 class="font-cinzel-decorative font-bold text-3xl text-[#d4a017] mt-1">🔍 {gettext("Insights")}</h1>
        </div>
      </div>

      <%!-- Month selector --%>
      <div class="flex items-center justify-center gap-4">
        <button phx-click="prev_month" class="btn-medieval text-sm">&larr;</button>
        <span class="font-cinzel text-xl text-gold">{month_name(@month)} {@year}</span>
        <button phx-click="next_month" class="btn-medieval text-sm">&rarr;</button>
      </div>

      <%!-- Trend Analysis --%>
      <div class="grid gap-6 lg:grid-cols-2">
        <div class="panel p-5">
          <h2 class="panel-title text-lg mb-3">📈 {gettext("vs Previous Month")}</h2>
          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-cream">{gettext("Coffers")}</span>
              <span class={change_color(@trend.vs_prev_month.income_change, :income)}>
                {change_indicator(@trend.vs_prev_month.income_change)}
              </span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-cream">{gettext("Tributes")}</span>
              <span class={change_color(@trend.vs_prev_month.expense_change, :expense)}>
                {change_indicator(@trend.vs_prev_month.expense_change)}
              </span>
            </div>
          </div>
        </div>

        <div class="panel p-5">
          <h2 class="panel-title text-lg mb-3">📊 {gettext("vs Same Month Last Year")}</h2>
          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-cream">{gettext("Coffers")}</span>
              <span class={change_color(@trend.vs_last_year.income_change, :income)}>
                {change_indicator(@trend.vs_last_year.income_change)}
              </span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-cream">{gettext("Tributes")}</span>
              <span class={change_color(@trend.vs_last_year.expense_change, :expense)}>
                {change_indicator(@trend.vs_last_year.expense_change)}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Current month summary --%>
      <div class="panel p-5">
        <h2 class="panel-title text-lg mb-3">⚖️ {gettext("This Moon")}</h2>
        <div class="grid grid-cols-3 gap-4 text-center">
          <div>
            <p class="text-muted text-sm">{gettext("Coffers")}</p>
            <p class="text-[#3d8b3d] font-mono text-lg">{format_amount(@trend.current.income)}</p>
          </div>
          <div>
            <p class="text-muted text-sm">{gettext("Tributes")}</p>
            <p class="text-[#8b1a1a] font-mono text-lg">{format_amount(@trend.current.expenses)}</p>
          </div>
          <div>
            <p class="text-muted text-sm">{gettext("Net Purse")}</p>
            <p class={[
              "font-mono text-lg",
              if(Decimal.compare(@trend.current.balance, 0) == :lt, do: "text-[#8b1a1a]", else: "text-[#3d8b3d]")
            ]}>
              {format_amount(@trend.current.balance)}
            </p>
          </div>
        </div>
      </div>

      <%!-- Rolling expense averages --%>
      <div class="panel p-5">
        <h2 class="panel-title text-lg mb-3">📉 {gettext("Rolling 6-Month Averages by Guild")}</h2>
        <div :if={@averages == []} class="italic-fell text-muted text-sm">
          🕸️ {gettext("No tribute data to analyze.")}
        </div>
        <table :if={@averages != []} class="w-full text-sm">
          <thead>
            <tr class="text-gold font-cinzel text-xs border-b border-[#7a5c1e]">
              <th class="text-left py-1 px-2">{gettext("Guild")}</th>
              <th class="text-right py-1 px-2">{gettext("Average")}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{category, avg} <- @averages} class="border-b border-[#7a5c1e]/30">
              <td class="py-1 px-2 text-cream">{category.name}</td>
              <td class="py-1 px-2 text-right text-[#8b1a1a] font-mono">{format_amount(avg)}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <%!-- Income/Expense ratio chart --%>
      <div class="panel p-5">
        <h2 class="panel-title text-lg mb-3">⚔️ {gettext("Coffers / Tributes Ratio")} ({@year})</h2>
        <p class="text-muted text-xs mb-3 italic-fell">{gettext("Above 1.0 = surplus, below 1.0 = deficit")}</p>
        <canvas
          id={"ratio-chart-#{@year}"}
          phx-hook="ChartHook"
          data-chart-type="line"
          data-chart-data={@ratio_chart}
          data-chart-options={ratio_chart_options()}
        />
      </div>
    </Layouts.app>
    """
  end
end
