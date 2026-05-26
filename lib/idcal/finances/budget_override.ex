defmodule Idcal.Finances.BudgetOverride do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budget_overrides" do
    field :year, :integer
    field :month, :integer
    field :limit, :decimal
    belongs_to :expense_category, Idcal.Finances.ExpenseCategory

    timestamps(type: :utc_datetime)
  end

  def changeset(override, attrs) do
    override
    |> cast(attrs, [:year, :month, :limit, :expense_category_id])
    |> validate_required([:year, :month, :limit])
    |> validate_number(:year, greater_than_or_equal_to: 1970, less_than_or_equal_to: 9999)
    |> validate_inclusion(:month, 1..12)
    |> validate_number(:limit, greater_than: 0)
    |> unique_constraint([:expense_category_id, :year, :month])
  end
end
