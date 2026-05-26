defmodule Idcal.Repo.Migrations.CreateExpenses do
  use Ecto.Migration

  def change do
    create table(:expense_categories) do
      add :name, :string, null: false
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:expense_categories, [:profile_id])
    create unique_index(:expense_categories, [:profile_id, :name])

    create table(:expense_types) do
      add :name, :string, null: false
      add :recurrence, :string, null: false
      add :base_amount, :decimal
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false

      add :expense_category_id, references(:expense_categories, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:expense_types, [:profile_id])
    create index(:expense_types, [:expense_category_id])

    create table(:expense_entries) do
      add :year, :integer, null: false
      add :month, :integer, null: false
      add :amount, :decimal, null: false
      add :note, :string

      add :expense_type_id, references(:expense_types, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:expense_entries, [:expense_type_id])
    create unique_index(:expense_entries, [:expense_type_id, :year, :month])
  end
end
