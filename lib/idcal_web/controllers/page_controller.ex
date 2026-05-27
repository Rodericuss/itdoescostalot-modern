defmodule IdcalWeb.PageController do
  use IdcalWeb, :controller

  alias Idcal.Finances

  def home(conn, _params) do
    profile_summaries =
      case conn.assigns[:current_scope] do
        nil ->
          []

        scope ->
          today = Date.utc_today()

          Finances.list_profiles(scope)
          |> Enum.map(fn profile ->
            income = Finances.resolve_income_for_month(profile, today.year, today.month)
            expenses = Finances.resolve_expenses_for_month(profile, today.year, today.month)
            balance = Decimal.sub(income, expenses)
            %{profile: profile, income: income, expenses: expenses, balance: balance}
          end)
      end

    render(conn, :home, profile_summaries: profile_summaries)
  end
end
