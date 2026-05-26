defmodule Idcal.Repo.Migrations.AddTrackingStartToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :start_year, :integer
      add :start_month, :integer
    end
  end
end
