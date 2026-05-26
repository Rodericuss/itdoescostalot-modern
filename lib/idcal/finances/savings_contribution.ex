defmodule Idcal.Finances.SavingsContribution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "savings_contributions" do
    field :year, :integer
    field :month, :integer
    field :amount, :decimal
    field :note, :string
    belongs_to :savings_goal, Idcal.Finances.SavingsGoal

    timestamps(type: :utc_datetime)
  end

  def changeset(contribution, attrs) do
    contribution
    |> cast(attrs, [:year, :month, :amount, :note, :savings_goal_id])
    |> validate_required([:year, :month, :amount])
    |> validate_number(:year, greater_than_or_equal_to: 1970, less_than_or_equal_to: 9999)
    |> validate_inclusion(:month, 1..12)
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint([:savings_goal_id, :year, :month])
  end
end
