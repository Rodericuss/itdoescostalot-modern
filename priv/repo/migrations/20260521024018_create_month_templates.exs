defmodule Idcal.Repo.Migrations.CreateMonthTemplates do
  use Ecto.Migration

  def change do
    create table(:month_templates) do
      add :name, :string, null: false
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:month_templates, [:profile_id])
    create unique_index(:month_templates, [:profile_id, :name])

    create table(:month_template_items) do
      add :kind, :string, null: false
      add :category_name, :string, null: false
      add :name, :string, null: false
      add :amount, :decimal, null: false
      add :note, :string
      add :month_template_id, references(:month_templates, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:month_template_items, [:month_template_id])
  end
end
