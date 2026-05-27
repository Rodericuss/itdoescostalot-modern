defmodule IdcalWeb.ForecastLive.Show do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  import IdcalWeb.FormatHelpers, only: [month_abbr: 1, format_amount: 1]

  @impl true
  def mount(%{"id" => profile_id}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)
    income_sources = Finances.list_recurring_income_sources(profile)
    expense_types = Finances.list_recurring_expense_types(profile)

    {:ok,
     socket
     |> assign(:page_title, gettext("Forecast"))
     |> assign(:profile, profile)
     |> assign(:income_sources, income_sources)
     |> assign(:expense_types, expense_types)
     |> assign(:horizon, 6)
     |> assign(:toggles, %{})
     |> assign(:amount_overrides, %{})
     |> recompute_projection()}
  end

  @impl true
  def handle_event("set_horizon", %{"horizon" => h}, socket) do
    horizon = String.to_integer(h)
    {:noreply, socket |> assign(:horizon, horizon) |> recompute_projection()}
  end

  def handle_event("toggle_source", %{"id" => id}, socket) do
    key = {:income, String.to_integer(id)}
    current = Map.get(socket.assigns.toggles, key, true)
    toggles = Map.put(socket.assigns.toggles, key, !current)
    {:noreply, socket |> assign(:toggles, toggles) |> recompute_projection()}
  end

  def handle_event("toggle_type", %{"id" => id}, socket) do
    key = {:expense, String.to_integer(id)}
    current = Map.get(socket.assigns.toggles, key, true)
    toggles = Map.put(socket.assigns.toggles, key, !current)
    {:noreply, socket |> assign(:toggles, toggles) |> recompute_projection()}
  end

  def handle_event("adjust_amount", %{"kind" => kind, "item_id" => id, "amount" => amount_str}, socket) do
    case Decimal.parse(amount_str) do
      {amount, ""} ->
        key = {String.to_existing_atom(kind <> "_amount"), String.to_integer(id)}
        overrides = Map.put(socket.assigns.amount_overrides, key, amount)
        {:noreply, socket |> assign(:amount_overrides, overrides) |> recompute_projection()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("reset_scenarios", _params, socket) do
    {:noreply,
     socket
     |> assign(:toggles, %{})
     |> assign(:amount_overrides, %{})
     |> recompute_projection()}
  end

  defp recompute_projection(socket) do
    overrides = Map.merge(socket.assigns.toggles, socket.assigns.amount_overrides)
    projection = Finances.project_cash_flow(socket.assigns.profile, socket.assigns.horizon, overrides)

    cumulative =
      Enum.scan(projection, Decimal.new(0), fn %{balance: b}, acc -> Decimal.add(acc, b) end)

    chart_data = build_chart(projection, cumulative)

    socket
    |> assign(:projection, projection)
    |> assign(:cumulative, cumulative)
    |> assign(:chart_data, chart_data)
  end

  defp build_chart(projection, cumulative) do
    labels = Enum.map(projection, fn %{year: y, month: m} -> "#{month_abbr(m)} #{y}" end)
    income_data = Enum.map(projection, fn %{income: i} -> Decimal.to_float(i) end)
    expense_data = Enum.map(projection, fn %{expenses: e} -> Decimal.to_float(e) end)
    cumulative_data = Enum.map(cumulative, &Decimal.to_float/1)

    Jason.encode!(%{
      labels: labels,
      datasets: [
        %{type: "bar", label: gettext("Income"), data: income_data, backgroundColor: "#1D9E75", order: 2},
        %{type: "bar", label: gettext("Expenses"), data: expense_data, backgroundColor: "#E24B4A", order: 2},
        %{
          type: "line",
          label: gettext("Cumulative Balance"),
          data: cumulative_data,
          borderColor: "#A31F34",
          backgroundColor: "rgba(163, 31, 52, 0.1)",
          fill: true,
          tension: 0.3,
          order: 1
        }
      ]
    })
  end

  defp chart_options do
    Jason.encode!(%{
      responsive: true,
      plugins: %{legend: %{labels: %{color: "#1A1A1A", font: %{family: "Inter"}}}},
      scales: %{
        x: %{ticks: %{color: "#5F5E5A"}, grid: %{color: "rgba(224,222,219,0.5)"}},
        y: %{ticks: %{color: "#5F5E5A"}, grid: %{color: "rgba(224,222,219,0.5)"}}
      }
    })
  end

  defp source_enabled?(toggles, id) do
    Map.get(toggles, {:income, id}, true)
  end

  defp type_enabled?(toggles, id) do
    Map.get(toggles, {:expense, id}, true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-between">
        <div>
          <.link navigate={~p"/profiles/#{@profile}"} class="text-slate hover:text-[#A31F34] text-sm">
            &larr; {@profile.nickname}
          </.link>
          <h1 class="font-bold text-3xl text-[#BA7517] mt-1">{gettext("Forecast")}</h1>
        </div>
        <div class="flex gap-2">
          <button
            :for={h <- [3, 6, 12]}
            phx-click="set_horizon"
            phx-value-horizon={h}
            class={["btn-pill", if(@horizon == h, do: "active", else: "")]}
          >
            {ngettext("%{count} month", "%{count} months", h)}
          </button>
        </div>
      </div>

      <%!-- Projection chart --%>
      <div class="card-neo p-5">
        <h2 class="card-title text-lg mb-3">{gettext("Projected Cash Flow")}</h2>
        <canvas
          id={"forecast-chart-#{@horizon}-#{:erlang.phash2({@toggles, @amount_overrides})}"}
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={@chart_data}
          data-chart-options={chart_options()}
        />
      </div>

      <%!-- Projection table --%>
      <div class="card-neo p-5">
        <h2 class="card-title text-lg mb-3">{gettext("Monthly Breakdown")}</h2>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-[#A31F34] text-xs border-b border-[#E0DEDB]">
                <th class="text-left py-1 px-2">{gettext("Month")}</th>
                <th class="text-right py-1 px-2">{gettext("Income")}</th>
                <th class="text-right py-1 px-2">{gettext("Expenses")}</th>
                <th class="text-right py-1 px-2">{gettext("Net Balance")}</th>
                <th class="text-right py-1 px-2">{gettext("Cumulative Balance")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{m, cum} <- Enum.zip(@projection, @cumulative)} class="border-b border-[#E0DEDB]/30">
                <td class="py-1 px-2 text-ink">{month_abbr(m.month)} {m.year}</td>
                <td class="py-1 px-2 text-right text-[#1D9E75] font-amount">{format_amount(m.income)}</td>
                <td class="py-1 px-2 text-right text-[#E24B4A] font-amount">{format_amount(m.expenses)}</td>
                <td class={["py-1 px-2 text-right font-amount", if(Decimal.compare(m.balance, 0) == :lt, do: "text-[#E24B4A]", else: "text-[#1D9E75]")]}>
                  {format_amount(m.balance)}
                </td>
                <td class={["py-1 px-2 text-right font-amount", if(Decimal.compare(cum, 0) == :lt, do: "text-[#E24B4A]", else: "text-[#BA7517]")]}>
                  {format_amount(cum)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- What-if toggles --%>
      <div class="grid gap-6 lg:grid-cols-2">
        <%!-- Income sources --%>
        <div class="card-neo p-5">
          <div class="flex items-center justify-between mb-3">
            <h2 class="card-title text-lg">{gettext("Sources")}</h2>
            <button phx-click="reset_scenarios" class="btn-ghost text-xs">{gettext("Reset")}</button>
          </div>
          <p class="text-slate text-xs mb-3">{gettext("Toggle sources on/off to see projected impact.")}</p>
          <div :if={@income_sources == []} class="text-slate text-sm">
            {gettext("No recurring sources.")}
          </div>
          <div :for={source <- @income_sources} class="flex items-center justify-between py-2 border-b border-[#E0DEDB]/30">
            <div class="flex items-center gap-3">
              <button
                phx-click="toggle_source"
                phx-value-id={source.id}
                class={["w-5 h-5 border border-[#E0DEDB] flex items-center justify-center text-xs",
                  if(source_enabled?(@toggles, source.id), do: "bg-[#1D9E75] text-ink", else: "bg-[#F8F7F5] text-slate")
                ]}
              >
                {if source_enabled?(@toggles, source.id), do: "✓", else: "✗"}
              </button>
              <div>
                <span class={["text-ink", if(!source_enabled?(@toggles, source.id), do: "line-through opacity-50")]}>{source.name}</span>
                <span class="text-slate text-xs ml-1">({source.income_category.name})</span>
              </div>
            </div>
            <form phx-change="adjust_amount" class="flex items-center gap-1">
              <input type="hidden" name="kind" value="income" />
              <input type="hidden" name="item_id" value={source.id} />
              <input
                type="number"
                name="amount"
                value={Map.get(@amount_overrides, {:income_amount, source.id}, source.base_amount) |> Decimal.to_string()}
                step="0.01"
                min="0"
                class="w-24 bg-[#F8F7F5] border border-[#E0DEDB] text-[#1D9E75] text-right text-sm px-2 py-0.5 font-amount focus:border-[#BA7517] focus:outline-none"
              />
            </form>
          </div>
        </div>

        <%!-- Expense types --%>
        <div class="card-neo p-5">
          <h2 class="card-title text-lg mb-3">{gettext("Types")}</h2>
          <p class="text-slate text-xs mb-3">{gettext("Toggle types on/off to see projected impact.")}</p>
          <div :if={@expense_types == []} class="text-slate text-sm">
            {gettext("No recurring types.")}
          </div>
          <div :for={type <- @expense_types} class="flex items-center justify-between py-2 border-b border-[#E0DEDB]/30">
            <div class="flex items-center gap-3">
              <button
                phx-click="toggle_type"
                phx-value-id={type.id}
                class={["w-5 h-5 border border-[#E0DEDB] flex items-center justify-center text-xs",
                  if(type_enabled?(@toggles, type.id), do: "bg-[#E24B4A] text-ink", else: "bg-[#F8F7F5] text-slate")
                ]}
              >
                {if type_enabled?(@toggles, type.id), do: "✓", else: "✗"}
              </button>
              <div>
                <span class={["text-ink", if(!type_enabled?(@toggles, type.id), do: "line-through opacity-50")]}>{type.name}</span>
                <span class="text-slate text-xs ml-1">({type.expense_category.name})</span>
              </div>
            </div>
            <form phx-change="adjust_amount" class="flex items-center gap-1">
              <input type="hidden" name="kind" value="expense" />
              <input type="hidden" name="item_id" value={type.id} />
              <input
                type="number"
                name="amount"
                value={Map.get(@amount_overrides, {:expense_amount, type.id}, type.base_amount) |> Decimal.to_string()}
                step="0.01"
                min="0"
                class="w-24 bg-[#F8F7F5] border border-[#E0DEDB] text-[#E24B4A] text-right text-sm px-2 py-0.5 font-amount focus:border-[#BA7517] focus:outline-none"
              />
            </form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
