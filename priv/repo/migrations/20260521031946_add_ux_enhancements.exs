defmodule Idcal.Repo.Migrations.AddUxEnhancements do
  use Ecto.Migration

  def change do
    alter table(:expense_categories) do
      add :pinned, :boolean, default: false, null: false
    end

    alter table(:income_categories) do
      add :pinned, :boolean, default: false, null: false
    end

    alter table(:profiles) do
      add :currency, :string, default: "BRL", null: false
      add :theme, :string, default: "dark", null: false
    end
  end
end
