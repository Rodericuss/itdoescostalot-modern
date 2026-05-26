defmodule IdcalWeb.MonthLive.Show do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  import IdcalWeb.FormatHelpers, only: [month_name: 1, format_amount: 1]

  @impl true
  def mount(%{"id" => profile_id, "year" => year_str, "month" => month_str}, _session, socket) do
    profile = Finances.get_profile!(socket.assigns.current_scope, profile_id)

    with {year, ""} <- Integer.parse(year_str),
         {month, ""} <- Integer.parse(month_str),
         true <- month in 1..12,
         true <- year in 1970..9999 do
      mount_with_data(socket, profile, year, month)
    else
      _ -> {:ok, push_navigate(socket, to: ~p"/profiles/#{profile_id}")}
    end
  end

  defp mount_with_data(socket, profile, year, month) do

    income_breakdown = Finances.income_breakdown_for_month(profile, year, month)
    expense_groups = Finances.expense_breakdown_grouped_by_category(profile, year, month)

    total_income =
      Enum.reduce(income_breakdown, Decimal.new(0), fn {_, amt}, acc -> Decimal.add(acc, amt) end)

    total_expenses =
      Enum.reduce(expense_groups, Decimal.new(0), fn {_, _, cat_total}, acc ->
        Decimal.add(acc, cat_total)
      end)

    balance = Decimal.sub(total_income, total_expenses)

    {:ok,
     socket
     |> assign(:page_title, "#{month_name(month)} #{year}")
     |> assign(:profile, profile)
     |> assign(:year, year)
     |> assign(:month, month)
     |> assign(:income_breakdown, income_breakdown)
     |> assign(:expense_groups, expense_groups)
     |> assign(:total_income, total_income)
     |> assign(:total_expenses, total_expenses)
     |> assign(:balance, balance)
     |> assign(:chart_data, expense_chart_data(expense_groups))
     |> assign_budget_data(profile, year, month)
     |> assign(:expanded_category, nil)
     |> assign(:templates, Finances.list_month_templates(profile))
     |> assign(:show_save_template, false)
     |> assign(:template_name, "")}
  end

  defp mount_with_data_socket(socket, profile, year, month) do
    income_breakdown = Finances.income_breakdown_for_month(profile, year, month)
    expense_groups = Finances.expense_breakdown_grouped_by_category(profile, year, month)

    total_income =
      Enum.reduce(income_breakdown, Decimal.new(0), fn {_, amt}, acc -> Decimal.add(acc, amt) end)

    total_expenses =
      Enum.reduce(expense_groups, Decimal.new(0), fn {_, _, cat_total}, acc ->
        Decimal.add(acc, cat_total)
      end)

    balance = Decimal.sub(total_income, total_expenses)

    socket
    |> assign(:income_breakdown, income_breakdown)
    |> assign(:expense_groups, expense_groups)
    |> assign(:total_income, total_income)
    |> assign(:total_expenses, total_expenses)
    |> assign(:balance, balance)
    |> assign(:chart_data, expense_chart_data(expense_groups))
    |> assign_budget_data(profile, year, month)
  end

  defp assign_budget_data(socket, profile, year, month) do
    budget_status = Finances.budget_status_for_month(profile, year, month)

    alerts =
      Enum.filter(budget_status, fn {_cat, status} -> Decimal.gte?(status.percentage, 80) end)
      |> Enum.map(fn {cat, status} ->
        level = if Decimal.gte?(status.percentage, 100), do: :exceeded, else: :warning
        %{name: cat.name, percentage: status.percentage, level: level}
      end)

    socket
    |> assign(:budget_status, budget_status)
    |> assign(:budget_alerts, alerts)
  end

  defp expense_chart_data(expense_groups) do
    labels = Enum.map(expense_groups, fn {cat, _, _} -> cat.name end)

    amounts =
      Enum.map(expense_groups, fn {_, _, total} -> Decimal.to_float(total) end)

    colors = [
      "#8b1a1a", "#d4a017", "#3d8b3d", "#7a5c1e", "#a08050",
      "#6b3d0f", "#4a7c4a", "#c45c1e", "#2e6e8b", "#8b5213"
    ]

    Jason.encode!(%{
      labels: labels,
      datasets: [
        %{
          data: amounts,
          backgroundColor: Enum.take(colors, length(labels)),
          borderColor: "#7a5c1e",
          borderWidth: 1
        }
      ]
    })
  end

  @impl true
  def handle_event("clone_to_next", _params, socket) do
    profile = socket.assigns.profile
    {to_year, to_month} =
      if socket.assigns.month == 12, do: {socket.assigns.year + 1, 1}, else: {socket.assigns.year, socket.assigns.month + 1}

    case Finances.clone_month(profile, socket.assigns.year, socket.assigns.month, to_year, to_month) do
      {:ok, count} ->
        {:noreply, put_flash(socket, :info, ngettext("%{count} entry cloned.", "%{count} entries cloned.", count))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Clone failed."))}
    end
  end

  def handle_event("toggle_category", %{"id" => id}, socket) do
    current = socket.assigns.expanded_category
    new_id = String.to_integer(id)
    {:noreply, assign(socket, :expanded_category, if(current == new_id, do: nil, else: new_id))}
  end

  def handle_event("toggle_save_template", _params, socket) do
    {:noreply, assign(socket, :show_save_template, !socket.assigns.show_save_template)}
  end

  def handle_event("save_template", %{"name" => name}, socket) do
    profile = socket.assigns.profile

    case Finances.save_month_as_template(profile, socket.assigns.year, socket.assigns.month, String.trim(name)) do
      {:ok, _template} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Template saved."))
         |> assign(:templates, Finances.list_month_templates(profile))
         |> assign(:show_save_template, false)
         |> assign(:template_name, "")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to save template."))}
    end
  end

  def handle_event("apply_template", %{"template_id" => template_id}, socket) do
    profile = socket.assigns.profile

    case Finances.apply_month_template(profile, String.to_integer(template_id), socket.assigns.year, socket.assigns.month) do
      {:ok, count} ->
        socket = mount_with_data_socket(socket, profile, socket.assigns.year, socket.assigns.month)
        {:noreply, put_flash(socket, :info, ngettext("%{count} entry applied.", "%{count} entries applied.", count))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to apply template."))}
    end
  end

  def handle_event("delete_template", %{"template_id" => template_id}, socket) do
    profile = socket.assigns.profile
    template = Finances.get_month_template!(profile, String.to_integer(template_id))

    case Finances.delete_month_template(template) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Template deleted."))
         |> assign(:templates, Finances.list_month_templates(profile))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete template."))}
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
          <h1 class="font-cinzel-decorative font-bold text-3xl text-gold mt-1">
            📅 {gettext("%{month} %{year}", month: month_name(@month), year: @year)}
          </h1>
        </div>
        <div class="flex gap-2">
          <.link navigate={prev_month_path(@profile, @year, @month)} class="btn-medieval text-sm">
            &larr;
          </.link>
          <.link navigate={next_month_path(@profile, @year, @month)} class="btn-medieval text-sm">
            &rarr;
          </.link>
          <.link href={~p"/profiles/#{@profile}/month/#{@year}/#{@month}/export"} class="btn-medieval text-sm">
            📥 {gettext("Export CSV")}
          </.link>
          <button phx-click="clone_to_next" class="btn-medieval text-sm"
            data-confirm={gettext("Clone sporadic entries to the next month?")}
          >
            📋 {gettext("Clone")}
          </button>
          <button phx-click="toggle_save_template" class="btn-medieval text-sm">
            📜 {gettext("Templates")}
          </button>
        </div>
      </div>

      <%!-- Template controls --%>
      <div :if={@show_save_template} class="panel p-4">
        <h3 class="font-cinzel text-gold text-sm mb-3">📜 {gettext("Month Templates")}</h3>
        <div class="flex gap-3 mb-4">
          <form phx-submit="save_template" class="flex gap-2 flex-1">
            <input
              type="text"
              name="name"
              value={@template_name}
              placeholder={gettext("Template name...")}
              class="input-medieval flex-1 text-sm"
              required
            />
            <button type="submit" class="btn-medieval text-sm">
              💾 {gettext("Save Current")}
            </button>
          </form>
        </div>
        <div :if={@templates != []} class="space-y-2">
          <div :for={template <- @templates} class="flex justify-between items-center border-b border-[#7a5c1e]/30 pb-2">
            <div>
              <span class="text-cream text-sm font-cinzel">{template.name}</span>
              <span class="text-muted text-xs ml-2">
                ({ngettext("%{count} item", "%{count} items", length(template.items))})
              </span>
            </div>
            <div class="flex gap-2">
              <button
                phx-click="apply_template"
                phx-value-template_id={template.id}
                class="btn-medieval text-xs"
                data-confirm={gettext("Apply this template to the current month?")}
              >
                ▶ {gettext("Apply")}
              </button>
              <button
                phx-click="delete_template"
                phx-value-template_id={template.id}
                class="btn-medieval text-xs text-[#8b1a1a]"
                data-confirm={gettext("Delete this template?")}
              >
                ✕
              </button>
            </div>
          </div>
        </div>
        <p :if={@templates == []} class="italic-fell text-muted text-sm">
          {gettext("No templates saved yet.")}
        </p>
      </div>

      <%!-- Budget alerts --%>
      <div :for={alert <- @budget_alerts} class={[
        "p-3 border text-sm flex items-center gap-2",
        if(alert.level == :exceeded,
          do: "bg-[#8b1a1a]/20 border-[#8b1a1a] text-[#ff6b6b]",
          else: "bg-[#d4a017]/20 border-[#d4a017] text-[#d4a017]")
      ]}>
        <span>{if alert.level == :exceeded, do: "🚨", else: "⚠️"}</span>
        <span :if={alert.level == :exceeded}>
          {gettext("Guild %{name} hath exceeded its gold limit! (%{pct}%)", name: alert.name, pct: Decimal.to_string(alert.percentage))}
        </span>
        <span :if={alert.level == :warning}>
          {gettext("Guild %{name} approaches its gold limit (%{pct}%)", name: alert.name, pct: Decimal.to_string(alert.percentage))}
        </span>
      </div>

      <%!-- Net Balance --%>
      <div class="panel p-5 text-center">
        <p class="font-cinzel text-muted text-sm">⚖️ {gettext("Net Purse")}</p>
        <p class={[
          "font-mono text-3xl font-bold mt-1",
          if(Decimal.compare(@balance, 0) == :lt, do: "text-[#8b1a1a]", else: "text-[#3d8b3d]")
        ]}>
          {format_amount(@balance)}
        </p>
        <div class="flex justify-center gap-8 mt-3 text-sm">
          <span class="text-[#3d8b3d]">{gettext("Coffers:")} {format_amount(@total_income)}</span>
          <span class="text-[#8b1a1a]">{gettext("Tributes:")} {format_amount(@total_expenses)}</span>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-2">
        <%!-- Income breakdown --%>
        <div class="panel p-5">
          <h2 class="panel-title text-lg text-[#3d8b3d] mb-3">🪙 {gettext("Coffers")}</h2>
          <div :if={@income_breakdown == []} class="italic-fell text-muted text-sm">
            🕸️ {gettext("No coin entered the coffers this moon.")}
          </div>
          <table :if={@income_breakdown != []} class="w-full text-sm">
            <thead>
              <tr class="text-gold font-cinzel text-xs border-b border-[#7a5c1e]">
                <th class="text-left py-1 px-2">{gettext("Wellspring")}</th>
                <th class="text-left py-1 px-2">{gettext("Guild")}</th>
                <th class="text-right py-1 px-2">{gettext("Amount")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{source, amount} <- @income_breakdown} class="border-b border-[#7a5c1e]/30">
                <td class="py-1 px-2 text-cream">{source.name}</td>
                <td class="py-1 px-2 text-muted">{source.income_category.name}</td>
                <td class="py-1 px-2 text-right text-[#3d8b3d] font-mono">{format_amount(amount)}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="border-t-2 border-[#7a5c1e]">
                <td colspan="2" class="py-2 px-2 font-cinzel text-gold">{gettext("Total")}</td>
                <td class="py-2 px-2 text-right text-[#3d8b3d] font-mono font-bold">{format_amount(@total_income)}</td>
              </tr>
            </tfoot>
          </table>
        </div>

        <%!-- Expense breakdown (grouped by category) --%>
        <div class="panel p-5">
          <h2 class="panel-title text-lg text-[#8b1a1a] mb-3">💸 {gettext("Tributes")}</h2>
          <div :if={@expense_groups == []} class="italic-fell text-muted text-sm">
            🕸️ {gettext("No tributes paid this moon.")}
          </div>
          <div :for={{category, items, cat_total} <- @expense_groups} class="mb-4">
            <div
              class="flex justify-between items-center border-b border-[#7a5c1e] pb-1 mb-1 cursor-pointer hover:bg-[#2e1f0e]/50"
              phx-click="toggle_category"
              phx-value-id={category.id}
            >
              <span class="font-cinzel text-gold text-sm">
                {if @expanded_category == category.id, do: "▾", else: "▸"} {category.name}
              </span>
              <span class="text-[#8b1a1a] font-mono text-sm">{format_amount(cat_total)}</span>
            </div>
            <.budget_bar_mini :for={{cat, status} <- @budget_status} :if={cat.id == category.id} status={status} />
            <table class="w-full text-sm">
              <tr :for={{type, amount} <- items} class="border-b border-[#7a5c1e]/20">
                <td class="py-0.5 px-2 text-cream">{type.name}</td>
                <td class="py-0.5 px-2 text-right text-[#8b1a1a] font-mono">{format_amount(amount)}</td>
              </tr>
            </table>
            <%!-- Drilldown: show individual entries when expanded --%>
            <div :if={@expanded_category == category.id} class="ml-4 mt-2 border-l-2 border-[#7a5c1e] pl-3">
              <div :for={{type, _amount} <- items} class="mb-3">
                <p class="font-cinzel text-cream text-xs mb-1">{type.name}</p>
                <div :if={Ecto.assoc_loaded?(type.entries)} class="space-y-0.5">
                  <div
                    :for={entry <- Enum.filter(type.entries, &(&1.year == @year && &1.month == @month))}
                    class="flex justify-between text-xs"
                  >
                    <span class="text-muted">{entry.note || gettext("Entry")}</span>
                    <span class="text-[#8b1a1a] font-mono">{format_amount(entry.amount)}</span>
                  </div>
                </div>
                <p :if={type.recurrence == :monthly && !has_entry_for_month?(type, @year, @month)} class="text-xs text-muted italic-fell">
                  {gettext("Base Tithe")}: {format_amount(type.base_amount)}
                </p>
              </div>
            </div>
          </div>
          <div :if={@expense_groups != []} class="border-t-2 border-[#7a5c1e] pt-2 flex justify-between">
            <span class="font-cinzel text-gold">{gettext("Total")}</span>
            <span class="text-[#8b1a1a] font-mono font-bold">{format_amount(@total_expenses)}</span>
          </div>
        </div>
      </div>

      <%!-- Expense donut chart --%>
      <div :if={@expense_groups != []} class="panel p-5">
        <h2 class="panel-title text-lg mb-3">🥧 {gettext("Tribute Guilds")}</h2>
        <div class="max-w-sm mx-auto">
          <canvas
            id="expense-donut"
            phx-hook="ChartHook"
            data-chart-type="doughnut"
            data-chart-data={@chart_data}
            data-chart-options={chart_options()}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp chart_options do
    Jason.encode!(%{
      plugins: %{
        legend: %{
          position: "bottom",
          labels: %{color: "#f0dfa0", font: %{family: "Cinzel"}}
        }
      },
      cutout: "50%"
    })
  end

  defp has_entry_for_month?(type, year, month) do
    Ecto.assoc_loaded?(type.entries) &&
      Enum.any?(type.entries, &(&1.year == year && &1.month == month))
  end

  defp budget_bar_mini(assigns) do
    pct_float = min(Decimal.to_float(assigns.status.percentage), 100)
    color =
      cond do
        Decimal.gte?(assigns.status.percentage, 100) -> "bg-[#8b1a1a]"
        Decimal.gte?(assigns.status.percentage, 80) -> "bg-[#d4a017]"
        true -> "bg-[#3d8b3d]"
      end

    assigns = assign(assigns, pct_float: pct_float, color: color)

    ~H"""
    <div class="my-1">
      <div class="flex justify-between text-xs">
        <span class="text-muted">{format_amount(@status.spent)} / {format_amount(@status.limit)}</span>
        <span class={if Decimal.gte?(@status.percentage, 100), do: "text-[#8b1a1a]", else: "text-muted"}>
          {Decimal.to_string(@status.percentage)}%
        </span>
      </div>
      <div class="w-full bg-[#1a1208] border border-[#7a5c1e] h-2">
        <div class={["h-full transition-all", @color]} style={"width: #{@pct_float}%"} />
      </div>
    </div>
    """
  end

  defp prev_month_path(profile, year, 1), do: ~p"/profiles/#{profile}/month/#{year - 1}/12"
  defp prev_month_path(profile, year, month), do: ~p"/profiles/#{profile}/month/#{year}/#{month - 1}"

  defp next_month_path(profile, year, 12), do: ~p"/profiles/#{profile}/month/#{year + 1}/1"
  defp next_month_path(profile, year, month), do: ~p"/profiles/#{profile}/month/#{year}/#{month + 1}"
end
