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
        %{type: "bar", label: gettext("Coffers"), data: income_data, backgroundColor: "#3d8b3d", order: 2},
        %{type: "bar", label: gettext("Tributes"), data: expense_data, backgroundColor: "#8b1a1a", order: 2},
        %{
          type: "line",
          label: gettext("Amassed Hoard"),
          data: cumulative_data,
          borderColor: "#d4a017",
          backgroundColor: "rgba(212, 160, 23, 0.1)",
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
      plugins: %{legend: %{labels: %{color: "#f0dfa0", font: %{family: "Cinzel"}}}},
      scales: %{
        x: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}},
        y: %{ticks: %{color: "#a08050"}, grid: %{color: "rgba(122,92,30,0.3)"}}
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
          <.link navigate={~p"/profiles/#{@profile}"} class="text-muted hover:text-gold font-cinzel text-sm">
            &larr; {@profile.nickname}
          </.link>
          <h1 class="font-cinzel-decorative font-bold text-3xl text-[#d4a017] mt-1">🔮 {gettext("Forecast")}</h1>
        </div>
        <div class="flex gap-2">
          <button
            :for={h <- [3, 6, 12]}
            phx-click="set_horizon"
            phx-value-horizon={h}
            class={["btn-medieval text-sm", if(@horizon == h, do: "border-[#d4a017]", else: "")]}
          >
            {ngettext("%{count} month", "%{count} months", h)}
          </button>
        </div>
      </div>

      <%!-- Projection chart --%>
      <div class="panel p-5">
        <h2 class="panel-title text-lg mb-3">📈 {gettext("Projected Cash Flow")}</h2>
        <canvas
          id={"forecast-chart-#{@horizon}-#{:erlang.phash2({@toggles, @amount_overrides})}"}
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={@chart_data}
          data-chart-options={chart_options()}
        />
      </div>

      <%!-- Projection table --%>
      <div class="panel p-5">
        <h2 class="panel-title text-lg mb-3">📋 {gettext("Monthly Breakdown")}</h2>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-gold font-cinzel text-xs border-b border-[#7a5c1e]">
                <th class="text-left py-1 px-2">{gettext("Month")}</th>
                <th class="text-right py-1 px-2">{gettext("Coffers")}</th>
                <th class="text-right py-1 px-2">{gettext("Tributes")}</th>
                <th class="text-right py-1 px-2">{gettext("Net Purse")}</th>
                <th class="text-right py-1 px-2">{gettext("Amassed Hoard")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{m, cum} <- Enum.zip(@projection, @cumulative)} class="border-b border-[#7a5c1e]/30">
                <td class="py-1 px-2 text-cream font-cinzel">{month_abbr(m.month)} {m.year}</td>
                <td class="py-1 px-2 text-right text-[#3d8b3d] font-mono">{format_amount(m.income)}</td>
                <td class="py-1 px-2 text-right text-[#8b1a1a] font-mono">{format_amount(m.expenses)}</td>
                <td class={["py-1 px-2 text-right font-mono", if(Decimal.compare(m.balance, 0) == :lt, do: "text-[#8b1a1a]", else: "text-[#3d8b3d]")]}>
                  {format_amount(m.balance)}
                </td>
                <td class={["py-1 px-2 text-right font-mono", if(Decimal.compare(cum, 0) == :lt, do: "text-[#8b1a1a]", else: "text-[#d4a017]")]}>
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
        <div class="panel p-5">
          <div class="flex items-center justify-between mb-3">
            <h2 class="panel-title text-lg">🪙 {gettext("Wellsprings")}</h2>
            <button phx-click="reset_scenarios" class="btn-medieval text-xs">{gettext("Reset")}</button>
          </div>
          <p class="text-muted text-xs italic-fell mb-3">{gettext("Toggle sources on/off to see projected impact.")}</p>
          <div :if={@income_sources == []} class="italic-fell text-muted text-sm">
            🕸️ {gettext("No recurring wellsprings.")}
          </div>
          <div :for={source <- @income_sources} class="flex items-center justify-between py-2 border-b border-[#7a5c1e]/30">
            <div class="flex items-center gap-3">
              <button
                phx-click="toggle_source"
                phx-value-id={source.id}
                class={["w-5 h-5 border border-[#7a5c1e] flex items-center justify-center text-xs",
                  if(source_enabled?(@toggles, source.id), do: "bg-[#3d8b3d] text-cream", else: "bg-[#1a1208] text-muted")
                ]}
              >
                {if source_enabled?(@toggles, source.id), do: "✓", else: "✗"}
              </button>
              <div>
                <span class={["text-cream", if(!source_enabled?(@toggles, source.id), do: "line-through opacity-50")]}>{source.name}</span>
                <span class="text-muted text-xs ml-1">({source.income_category.name})</span>
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
                class="w-24 bg-[#1a1208] border border-[#7a5c1e] text-[#3d8b3d] text-right text-sm px-2 py-0.5 font-mono focus:border-[#d4a017] focus:outline-none"
              />
            </form>
          </div>
        </div>

        <%!-- Expense types --%>
        <div class="panel p-5">
          <h2 class="panel-title text-lg mb-3">💸 {gettext("Levies")}</h2>
          <p class="text-muted text-xs italic-fell mb-3">{gettext("Toggle levies on/off to see projected impact.")}</p>
          <div :if={@expense_types == []} class="italic-fell text-muted text-sm">
            🕸️ {gettext("No recurring levies.")}
          </div>
          <div :for={type <- @expense_types} class="flex items-center justify-between py-2 border-b border-[#7a5c1e]/30">
            <div class="flex items-center gap-3">
              <button
                phx-click="toggle_type"
                phx-value-id={type.id}
                class={["w-5 h-5 border border-[#7a5c1e] flex items-center justify-center text-xs",
                  if(type_enabled?(@toggles, type.id), do: "bg-[#8b1a1a] text-cream", else: "bg-[#1a1208] text-muted")
                ]}
              >
                {if type_enabled?(@toggles, type.id), do: "✓", else: "✗"}
              </button>
              <div>
                <span class={["text-cream", if(!type_enabled?(@toggles, type.id), do: "line-through opacity-50")]}>{type.name}</span>
                <span class="text-muted text-xs ml-1">({type.expense_category.name})</span>
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
                class="w-24 bg-[#1a1208] border border-[#7a5c1e] text-[#8b1a1a] text-right text-sm px-2 py-0.5 font-mono focus:border-[#d4a017] focus:outline-none"
              />
            </form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
