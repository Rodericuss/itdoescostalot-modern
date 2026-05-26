defmodule IdcalWeb.ExportController do
  use IdcalWeb, :controller

  alias Idcal.Finances

  @doc "Downloads a CSV of income and expense data for a given month."
  def monthly_csv(conn, %{"id" => profile_id, "year" => year_str, "month" => month_str}) do
    scope = conn.assigns.current_scope
    profile = Finances.get_profile!(scope, profile_id)

    with {year, ""} <- Integer.parse(year_str),
         {month, ""} <- Integer.parse(month_str),
         true <- month in 1..12,
         true <- year in 1970..9999 do
      income_rows = Finances.income_breakdown_for_month(profile, year, month)
      expense_rows = Finances.expense_breakdown_for_month(profile, year, month)

      csv =
        [["Type", "Category", "Name", "Amount"]]
        |> Kernel.++(Enum.map(income_rows, fn {source, amount} ->
          ["Income", source.income_category.name, source.name, Decimal.to_string(amount)]
        end))
        |> Kernel.++(Enum.map(expense_rows, fn {type, amount} ->
          ["Expense", type.expense_category.name, type.name, Decimal.to_string(amount)]
        end))
        |> Enum.map(&Enum.join(&1, ","))
        |> Enum.join("\n")

      filename = "idcal_#{profile.nickname}_#{year}_#{month}.csv"

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_resp(200, csv)
    else
      _ -> redirect(conn, to: ~p"/profiles/#{profile_id}")
    end
  end
end
