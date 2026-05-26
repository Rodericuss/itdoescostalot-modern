defmodule Idcal.Finances.ProfileShare do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profile_shares" do
    field :role, :string, default: "viewer"
    belongs_to :profile, Idcal.Finances.Profile
    belongs_to :user, Idcal.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, ["viewer", "editor"])
    |> unique_constraint([:profile_id, :user_id])
  end
end
