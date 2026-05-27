defmodule Idcal.Finances.Notifier do
  @moduledoc """
  Email notifications for financial events.
  """

  import Swoosh.Email

  alias Idcal.Mailer

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"IDCAL", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc "Sends a monthly check-in reminder to review the ledger."
  def deliver_monthly_reminder(user, year, month) do
    deliver(user.email, "Month closed, time to review your finances", """
    ==============================

    Hi, #{user.email}!

    #{month_name(month)} #{year} is over.

    Time to review your entries and make sure everything is accounted for.

    Visit your profiles and check the monthly summary.

    - IDCAL

    ==============================
    """)
  end

  @doc "Sends a budget alert when categories exceed or approach their limit."
  def deliver_budget_alert(user, profile, alerts) do
    alert_lines =
      Enum.map_join(alerts, "\n", fn {category_name, pct, spent, limit} ->
        "  - #{category_name}: #{spent} / #{limit} (#{pct}%)"
      end)

    deliver(user.email, "Budget Alert, #{profile.nickname}", """
    ==============================

    Hi, #{user.email}!

    Some categories in your profile "#{profile.nickname}" are approaching or exceeding their limit:

    #{alert_lines}

    Review your expenses and adjust your spending before things get tight.

    - IDCAL

    ==============================
    """)
  end

  defp month_name(1), do: "January"
  defp month_name(2), do: "February"
  defp month_name(3), do: "March"
  defp month_name(4), do: "April"
  defp month_name(5), do: "May"
  defp month_name(6), do: "June"
  defp month_name(7), do: "July"
  defp month_name(8), do: "August"
  defp month_name(9), do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"
end
