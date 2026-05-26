defmodule Idcal.Repo.Migrations.AddBudgetsAndSavingsGoals do
  use Ecto.Migration

  def change do
    alter table(:expense_categories) do
      add :budget_limit, :decimal
    end

    create table(:budget_overrides) do
      add :expense_category_id, references(:expense_categories, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :month, :integer, null: false
      add :limit, :decimal, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:budget_overrides, [:expense_category_id, :year, :month])

    create table(:savings_goals) do
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :target_amount, :decimal, null: false
      add :deadline, :date, null: false
      add :tracking_mode, :string, null: false, default: "manual"

      timestamps(type: :utc_datetime)
    end

    create index(:savings_goals, [:profile_id])

    create table(:savings_contributions) do
      add :savings_goal_id, references(:savings_goals, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :month, :integer, null: false
      add :amount, :decimal, null: false
      add :note, :string

      timestamps(type: :utc_datetime)
    end

    create index(:savings_contributions, [:savings_goal_id])
    create unique_index(:savings_contributions, [:savings_goal_id, :year, :month])
  end
end
