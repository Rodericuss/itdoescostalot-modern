defmodule Idcal.Repo.Migrations.AddSharedProfiles do
  use Ecto.Migration

  def change do
    create table(:profile_shares) do
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "viewer"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profile_shares, [:profile_id, :user_id])
    create index(:profile_shares, [:user_id])
  end
end
