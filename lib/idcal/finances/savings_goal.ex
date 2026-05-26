defmodule Idcal.Finances.SavingsGoal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "savings_goals" do
    field :name, :string
    field :target_amount, :decimal
    field :deadline, :date
    field :tracking_mode, Ecto.Enum, values: [:auto, :manual]
    belongs_to :profile, Idcal.Finances.Profile
    has_many :contributions, Idcal.Finances.SavingsContribution

    timestamps(type: :utc_datetime)
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:name, :target_amount, :deadline, :tracking_mode])
    |> validate_required([:name, :target_amount, :deadline, :tracking_mode])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_number(:target_amount, greater_than: 0)
  end
end
