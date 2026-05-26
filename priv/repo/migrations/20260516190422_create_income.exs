defmodule Idcal.Repo.Migrations.CreateIncome do
  use Ecto.Migration

  def change do
    create table(:income_categories) do
      add :name, :string, null: false
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:income_categories, [:profile_id])
    create unique_index(:income_categories, [:profile_id, :name])

    create table(:income_sources) do
      add :name, :string, null: false
      add :recurrence, :string, null: false
      add :base_amount, :decimal
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false

      add :income_category_id, references(:income_categories, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:income_sources, [:profile_id])
    create index(:income_sources, [:income_category_id])

    create table(:income_entries) do
      add :year, :integer, null: false
      add :month, :integer, null: false
      add :amount, :decimal, null: false
      add :note, :string

      add :income_source_id, references(:income_sources, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:income_entries, [:income_source_id])
    create unique_index(:income_entries, [:income_source_id, :year, :month])
  end
end
