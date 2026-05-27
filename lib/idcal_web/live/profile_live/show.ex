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

    total_income = Enum.reduce(tracked_months, Decimal.new(0), fn m, acc -> Decimal.add(acc, m.income) end)
    total_expenses = Enum.reduce(tracked_months, Decimal.new(0), fn m, acc -> Decimal.add(acc, m.expenses) end)
    total_balance = Decimal.sub(total_income, total_expenses)
    months_tracked = length(tracked_months)

    {best_month, worst_month} =
      case tracked_months do
        [] ->
          {nil, nil}

        list ->
          best = Enum.max_by(list, fn m -> Decimal.to_float(m.balance) end)
          worst = Enum.min_by(list, fn m -> Decimal.to_float(m.balance) end)
          {best, worst}
      end

    avg_balance =
      if months_tracked > 0,
        do: Decimal.div(total_balance, months_tracked) |> Decimal.round(2),
        else: Decimal.new(0)

    socket
    |> assign(:months, months)
    |> assign(:cumulative, cumulative)
    |> assign(:bar_chart_data, bar_chart_data)
    |> assign(:line_chart_data, line_chart_data)
    |> assign(:total_income, total_income)
    |> assign(:total_expenses, total_expenses)
    |> assign(:total_balance, total_balance)
    |> assign(:months_tracked, months_tracked)
    |> assign(:best_month, best_month)
    |> assign(:worst_month, worst_month)
    |> assign(:avg_balance, avg_balance)
  end

  defp build_bar_chart(months) do
    labels = Enum.map(months, fn %{month: m} -> month_abbr(m) end)
    income_data = Enum.map(months, fn %{income: i} -> Decimal.to_float(i) end)
    expense_data = Enum.map(months, fn %{expenses: e} -> Decimal.to_float(e) end)

    Jason.encode!(%{
      labels: labels,
      datasets: [
        %{label: gettext("Income"), data: income_data, backgroundColor: "#1D9E75"},
        %{label: gettext("Expenses"), data: expense_data, backgroundColor: "#E24B4A"}
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
          label: gettext("Cumulative Balance"),
          data: data,
          borderColor: "#A31F34",
          backgroundColor: "rgba(163, 31, 52, 0.1)",
          fill: true,
          tension: 0.3
        }
      ]
    })
  end

  defp bar_chart_options do
    Jason.encode!(%{
      responsive: true,
      plugins: %{legend: %{labels: %{color: "#1A1A1A", font: %{family: "Inter"}}}},
      scales: %{
        x: %{ticks: %{color: "#5F5E5A"}, grid: %{color: "rgba(224,222,219,0.5)"}},
        y: %{ticks: %{color: "#5F5E5A"}, grid: %{color: "rgba(224,222,219,0.5)"}}
      }
    })
  end

  defp line_chart_options do
    Jason.encode!(%{
      responsive: true,
      plugins: %{legend: %{labels: %{color: "#1A1A1A", font: %{family: "Inter"}}}},
      scales: %{
        x: %{ticks: %{color: "#5F5E5A"}, grid: %{color: "rgba(224,222,219,0.5)"}},
        y: %{ticks: %{color: "#5F5E5A"}, grid: %{color: "rgba(224,222,219,0.5)"}}
      }
    })
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.profile_app flash={@flash} current_scope={@current_scope} profile={@profile} active_page={:dashboard}>
      <h1 class="font-bold text-3xl text-[#A31F34]">{@profile.nickname}</h1>

      <%!-- Year selector --%>
      <div class="flex items-center justify-center gap-4">
        <button phx-click="change_year" phx-value-year={@year - 1} class="btn-pill">&larr;</button>
        <span class="text-2xl text-[#A31F34] font-bold">{@year}</span>
        <button phx-click="change_year" phx-value-year={@year + 1} class="btn-pill">&rarr;</button>
      </div>

      <%!-- Hero Balance Card --%>
      <div class="card-hero">
        <p class="label-upper" style="color: #9A9893;">{gettext("Total Balance")} · {@year}</p>
        <p class={[
          "amount-xl mt-1",
          if(Decimal.compare(@total_balance, 0) == :lt, do: "text-[#FF7E7E]", else: "text-[#5DD3A8]")
        ]}>
          {format_short(@total_balance)}
        </p>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-4">
          <div>
            <p class="label-upper" style="color: #9A9893;">{gettext("Total Income")}</p>
            <p class="amount-lg text-[#5DD3A8] mt-0.5">{format_short(@total_income)}</p>
          </div>
          <div>
            <p class="label-upper" style="color: #9A9893;">{gettext("Total Expenses")}</p>
            <p class="amount-lg text-[#FF7E7E] mt-0.5">{format_short(@total_expenses)}</p>
          </div>
          <div>
            <p class="label-upper" style="color: #9A9893;">{gettext("Net Balance")}</p>
            <p class={["amount-lg mt-0.5", if(Decimal.compare(@total_balance, 0) == :lt, do: "text-[#FF7E7E]", else: "text-[#5DD3A8]")]}>
              {format_short(@total_balance)}
            </p>
          </div>
          <div>
            <p class="label-upper" style="color: #9A9893;">{gettext("Months Tracked")}</p>
            <p class="amount-lg text-white mt-0.5">{@months_tracked}</p>
          </div>
        </div>
      </div>

      <%!-- Stat Cards --%>
      <div class="grid gap-4 sm:grid-cols-3">
        <div class="card-stat">
          <p class="label-upper">{gettext("Best Month")}</p>
          <p :if={@best_month} class="amount-lg text-[#1D9E75] mt-1">{format_short(@best_month.balance)}</p>
          <p :if={@best_month} class="text-slate text-xs mt-0.5">{month_abbr(@best_month.month)}</p>
          <p :if={!@best_month} class="text-slate text-sm mt-1">{gettext("No data")}</p>
        </div>
        <div class="card-stat">
          <p class="label-upper">{gettext("Worst Month")}</p>
          <p :if={@worst_month} class="amount-lg text-[#E24B4A] mt-1">{format_short(@worst_month.balance)}</p>
          <p :if={@worst_month} class="text-slate text-xs mt-0.5">{month_abbr(@worst_month.month)}</p>
          <p :if={!@worst_month} class="text-slate text-sm mt-1">{gettext("No data")}</p>
        </div>
        <div class="card-stat">
          <p class="label-upper">{gettext("Average Balance")}</p>
          <p class={["amount-lg mt-1", if(Decimal.compare(@avg_balance, 0) == :lt, do: "text-[#E24B4A]", else: "text-[#1D9E75]")]}>
            {format_short(@avg_balance)}
          </p>
          <p class="text-slate text-xs mt-0.5">{gettext("per month")}</p>
        </div>
      </div>

      <%!-- 12 Month Cards --%>
      <div class="grid gap-3 grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
        <.link
          :for={m <- @months}
          navigate={~p"/profiles/#{@profile}/month/#{@year}/#{m.month}"}
          class={[
            "card-neo p-3 text-center",
            if(m.tracked, do: month_card_border(m.balance), else: "opacity-40 !border-dashed")
          ]}
        >
          <p class="text-[#A31F34] text-sm font-semibold">{month_abbr(m.month)}</p>
          <%= if m.tracked do %>
            <div class="mt-2 space-y-0.5 text-xs font-amount">
              <p class="text-[#1D9E75]">{short_amount(m.income)}</p>
              <p class="text-[#E24B4A]">{short_amount(m.expenses)}</p>
              <p class={["amount-lg", balance_color(m.balance)]}>{short_amount(m.balance)}</p>
            </div>
            <p :if={m.budget.total > 0 && m.budget.over > 0} class="mt-1 text-xs text-[#E24B4A]">
              {ngettext("%{count} category over budget", "%{count} categories over budget", m.budget.over)}
            </p>
          <% else %>
            <p class="mt-2 text-xs text-slate">{gettext("Not tracked")}</p>
          <% end %>
        </.link>
      </div>

      <%!-- Charts --%>
      <div class="grid gap-6 lg:grid-cols-2">
        <div class="card-neo p-5">
          <h2 class="card-title text-lg mb-3">{gettext("Income vs Expenses")}</h2>
          <div class="overflow-x-auto -mx-5 px-5 lg:mx-0 lg:px-0">
            <div class="min-w-[420px]">
              <canvas
                id={"bar-chart-#{@year}"}
                phx-hook="ChartHook"
                data-chart-type="bar"
                data-chart-data={@bar_chart_data}
                data-chart-options={bar_chart_options()}
              />
            </div>
          </div>
        </div>
        <div class="card-neo p-5">
          <h2 class="card-title text-lg mb-3">{gettext("Cumulative Balance")}</h2>
          <div class="overflow-x-auto -mx-5 px-5 lg:mx-0 lg:px-0">
            <div class="min-w-[420px]">
              <canvas
                id={"line-chart-#{@year}"}
                phx-hook="ChartHook"
                data-chart-type="line"
                data-chart-data={@line_chart_data}
                data-chart-options={line_chart_options()}
              />
            </div>
          </div>
        </div>
      </div>
    </Layouts.profile_app>
    """
  end

  defp month_card_border(balance) do
    case Decimal.compare(balance, 0) do
      :gt -> "!border-l-[3px] !border-l-[#1D9E75]"
      :lt -> "!border-l-[3px] !border-l-[#E24B4A]"
      _ -> ""
    end
  end

  defp balance_color(balance) do
    case Decimal.compare(balance, 0) do
      :lt -> "text-[#E24B4A]"
      _ -> "text-[#1D9E75]"
    end
  end

  defp short_amount(decimal), do: format_short(decimal)
end
