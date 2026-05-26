defmodule IdcalWeb.ProfileLive.Compare do
  use IdcalWeb, :live_view

  alias Idcal.Finances

  import IdcalWeb.FormatHelpers, only: [month_abbr: 1, format_amount: 1]

  @impl true
  def mount(_params, _session, socket) do
    profiles = Finances.list_profiles(socket.assigns.current_scope)
    year = Date.utc_today().year

    {:ok,
     socket
     |> assign(:page_title, gettext("Compare Ledgers"))
     |> assign(:profiles, profiles)
     |> assign(:year, year)
     |> assign(:left_id, nil)
     |> assign(:right_id, nil)
     |> assign(:left_data, nil)
     |> assign(:right_data, nil)}
  end

  @impl true
  def handle_event("select_profiles", params, socket) do
    left_id = parse_id(params["left_id"])
    right_id = parse_id(params["right_id"])
    year = socket.assigns.year
    scope = socket.assigns.current_scope

    left_data = if left_id, do: load_profile_data(scope, left_id, year)
    right_data = if right_id, do: load_profile_data(scope, right_id, year)

    {:noreply,
     socket
     |> assign(:left_id, left_id)
     |> assign(:right_id, right_id)
     |> assign(:left_data, left_data)
     |> assign(:right_data, right_data)}
  end

  def handle_event("change_year", %{"year" => year_str}, socket) do
    case Integer.parse(year_str) do
      {year, ""} when year in 1970..9999 ->
        scope = socket.assigns.current_scope

        left_data = if socket.assigns.left_id, do: load_profile_data(scope, socket.assigns.left_id, year)
        right_data = if socket.assigns.right_id, do: load_profile_data(scope, socket.assigns.right_id, year)

        {:noreply,
         socket
         |> assign(:year, year)
         |> assign(:left_data, left_data)
         |> assign(:right_data, right_data)}

      _ ->
        {:noreply, socket}
    end
  end

  defp parse_id(""), do: nil
  defp parse_id(nil), do: nil
  defp parse_id(id), do: id

  defp load_profile_data(scope, profile_id, year) do
    profile = Finances.get_profile!(scope, profile_id)
    months = Finances.annual_summary(profile, year)
    tracked = Enum.filter(months, & &1.tracked)

    total_income = Enum.reduce(tracked, Decimal.new(0), fn m, acc -> Decimal.add(acc, m.income) end)
    total_expenses = Enum.reduce(tracked, Decimal.new(0), fn m, acc -> Decimal.add(acc, m.expenses) end)
    total_balance = Decimal.sub(total_income, total_expenses)

    %{
      profile: profile,
      months: months,
      total_income: total_income,
      total_expenses: total_expenses,
      total_balance: total_balance
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h1 class="font-cinzel-decorative font-bold text-3xl text-gold">⚖️ {gettext("Compare Ledgers")}</h1>

      <div class="panel p-5">
        <form phx-change="select_profiles" class="flex gap-4 items-end flex-wrap">
          <div>
            <label class="font-cinzel text-sm text-gold">{gettext("Left Ledger")}</label>
            <select name="left_id" class="input-medieval text-sm mt-1">
              <option value="">{gettext("Select...")}</option>
              <option :for={p <- @profiles} value={p.id} selected={to_string(p.id) == to_string(@left_id)}>
                {p.nickname}
              </option>
            </select>
          </div>
          <div>
            <label class="font-cinzel text-sm text-gold">{gettext("Right Ledger")}</label>
            <select name="right_id" class="input-medieval text-sm mt-1">
              <option value="">{gettext("Select...")}</option>
              <option :for={p <- @profiles} value={p.id} selected={to_string(p.id) == to_string(@right_id)}>
                {p.nickname}
              </option>
            </select>
          </div>
        </form>

        <div class="flex items-center justify-center gap-4 mt-4">
          <button phx-click="change_year" phx-value-year={@year - 1} class="btn-medieval text-sm">&larr;</button>
          <span class="font-cinzel text-xl text-gold">{@year}</span>
          <button phx-click="change_year" phx-value-year={@year + 1} class="btn-medieval text-sm">&rarr;</button>
        </div>
      </div>

      <div :if={@left_data && @right_data} class="grid gap-6 lg:grid-cols-2 mt-6">
        <.profile_summary data={@left_data} />
        <.profile_summary data={@right_data} />
      </div>

      <div :if={@left_data && @right_data} class="panel p-5 mt-6">
        <h2 class="panel-title text-lg mb-3">📊 {gettext("Monthly Breakdown")}</h2>
        <table class="w-full text-sm">
          <thead>
            <tr class="text-gold font-cinzel text-xs border-b border-[#7a5c1e]">
              <th class="text-left py-1 px-2">{gettext("Month")}</th>
              <th class="text-right py-1 px-2">{@left_data.profile.nickname}</th>
              <th class="text-right py-1 px-2">{@right_data.profile.nickname}</th>
              <th class="text-right py-1 px-2">{gettext("Difference")}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{lm, rm} <- Enum.zip(@left_data.months, @right_data.months)} class="border-b border-[#7a5c1e]/30">
              <td class="py-1 px-2 text-cream font-cinzel">{month_abbr(lm.month)}</td>
              <td class={["py-1 px-2 text-right font-mono", balance_color(lm.balance)]}>
                {if lm.tracked, do: format_amount(lm.balance), else: "—"}
              </td>
              <td class={["py-1 px-2 text-right font-mono", balance_color(rm.balance)]}>
                {if rm.tracked, do: format_amount(rm.balance), else: "—"}
              </td>
              <td class="py-1 px-2 text-right font-mono text-muted">
                {if lm.tracked && rm.tracked, do: format_amount(Decimal.sub(lm.balance, rm.balance)), else: "—"}
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="border-t-2 border-[#7a5c1e]">
              <td class="py-2 px-2 font-cinzel text-gold">{gettext("Total")}</td>
              <td class={["py-2 px-2 text-right font-mono font-bold", balance_color(@left_data.total_balance)]}>
                {format_amount(@left_data.total_balance)}
              </td>
              <td class={["py-2 px-2 text-right font-mono font-bold", balance_color(@right_data.total_balance)]}>
                {format_amount(@right_data.total_balance)}
              </td>
              <td class="py-2 px-2 text-right font-mono font-bold text-muted">
                {format_amount(Decimal.sub(@left_data.total_balance, @right_data.total_balance))}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>

      <div :if={!@left_data || !@right_data} class="panel p-5 mt-6 text-center">
        <p class="italic-fell text-muted">{gettext("Select two ledgers above to compare their chronicles.")}</p>
      </div>
    </Layouts.app>
    """
  end

  defp profile_summary(assigns) do
    ~H"""
    <div class="panel p-5 text-center">
      <h3 class="font-cinzel text-gold text-lg mb-3">📖 {@data.profile.nickname}</h3>
      <div class="space-y-2">
        <div>
          <p class="text-muted text-xs font-cinzel">{gettext("Coffers")}</p>
          <p class="text-[#3d8b3d] font-mono text-xl font-bold">{format_amount(@data.total_income)}</p>
        </div>
        <div>
          <p class="text-muted text-xs font-cinzel">{gettext("Tributes")}</p>
          <p class="text-[#8b1a1a] font-mono text-xl font-bold">{format_amount(@data.total_expenses)}</p>
        </div>
        <div>
          <p class="text-muted text-xs font-cinzel">{gettext("Net Purse")}</p>
          <p class={["font-mono text-xl font-bold", balance_color(@data.total_balance)]}>
            {format_amount(@data.total_balance)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp balance_color(balance) do
    case Decimal.compare(balance, 0) do
      :lt -> "text-[#8b1a1a]"
      _ -> "text-[#3d8b3d]"
    end
  end
end
