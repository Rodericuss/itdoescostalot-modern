defmodule Idcal.Finances.ExpenseEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_entries" do
    field :year, :integer
    field :month, :integer
    field :amount, :decimal
    field :note, :string
    belongs_to :expense_type, Idcal.Finances.ExpenseType

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:year, :month, :amount, :note, :expense_type_id])
    |> validate_required([:year, :month, :amount, :expense_type_id])
    |> validate_number(:month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> validate_number(:year, greater_than_or_equal_to: 1970, less_than_or_equal_to: 9999)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_length(:note, max: 200)
    |> assoc_constraint(:expense_type)
    |> unique_constraint([:expense_type_id, :year, :month],
      name: :expense_entries_expense_type_id_year_month_index,
      message: "an entry already exists for this month"
    )
  end
end
