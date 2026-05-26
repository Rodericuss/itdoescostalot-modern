defmodule Idcal.Finances.ExpenseType do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_types" do
    field :name, :string
    field :recurrence, Ecto.Enum, values: [:monthly, :sporadic]
    field :base_amount, :decimal
    belongs_to :profile, Idcal.Finances.Profile
    belongs_to :expense_category, Idcal.Finances.ExpenseCategory
    has_many :entries, Idcal.Finances.ExpenseEntry

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(type, attrs) do
    type
    |> cast(attrs, [:name, :recurrence, :base_amount, :expense_category_id])
    |> validate_required([:name, :recurrence, :expense_category_id])
    |> validate_length(:name, min: 1, max: 80)
    |> validate_base_amount()
    |> assoc_constraint(:expense_category)
  end

  defp validate_base_amount(changeset) do
    case get_field(changeset, :recurrence) do
      :monthly ->
        changeset
        |> validate_required([:base_amount])
        |> validate_number(:base_amount, greater_than_or_equal_to: 0)

      :sporadic ->
        put_change(changeset, :base_amount, nil)

      _ ->
        changeset
    end
  end
end
