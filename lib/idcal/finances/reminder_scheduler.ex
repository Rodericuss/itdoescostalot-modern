defmodule Idcal.Finances.ReminderScheduler do
  @moduledoc """
  Periodic scheduler that sends monthly check-in reminders and budget alerts.
  Runs daily and triggers on the 1st of each month.
  """

  use GenServer

  alias Idcal.Repo
  alias Idcal.Accounts.User
  alias Idcal.Finances
  alias Idcal.Finances.{Profile, Notifier}

  import Ecto.Query

  @daily_interval :timer.hours(24)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_check()
    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    today = Date.utc_today()

    if today.day == 1 do
      {prev_year, prev_month} = prev_month(today.year, today.month)
      send_monthly_reminders(prev_year, prev_month)
      send_budget_alerts(prev_year, prev_month)
    end

    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check, @daily_interval)
  end

  @doc "Sends monthly reminder emails to all users."
  def send_monthly_reminders(year, month) do
    users = Repo.all(User)

    Enum.each(users, fn user ->
      Notifier.deliver_monthly_reminder(user, year, month)
    end)
  end

  @doc "Sends budget alerts for categories at or above 80% for a given month."
  def send_budget_alerts(year, month) do
    profiles =
      Profile
      |> preload(:user)
      |> Repo.all()

    Enum.each(profiles, fn profile ->
      budget_status = Finances.budget_status_for_month(profile, year, month)

      alerts =
        Enum.filter(budget_status, fn {_cat, status} ->
          Decimal.gte?(status.percentage, 80)
        end)
        |> Enum.map(fn {cat, status} ->
          {cat.name, Decimal.to_string(status.percentage), Decimal.to_string(status.spent), Decimal.to_string(status.limit)}
        end)

      if alerts != [] do
        user = profile.user
        Notifier.deliver_budget_alert(user, profile, alerts)
      end
    end)
  end

  defp prev_month(year, 1), do: {year - 1, 12}
  defp prev_month(year, month), do: {year, month - 1}
end
