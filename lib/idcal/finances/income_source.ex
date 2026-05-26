defmodule Idcal.Finances.IncomeSource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "income_sources" do
    field :name, :string
    field :recurrence, Ecto.Enum, values: [:monthly, :sporadic]
    field :base_amount, :decimal
    belongs_to :profile, Idcal.Finances.Profile
    belongs_to :income_category, Idcal.Finances.IncomeCategory
    has_many :entries, Idcal.Finances.IncomeEntry

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :recurrence, :base_amount, :income_category_id])
    |> validate_required([:name, :recurrence, :income_category_id])
    |> validate_length(:name, min: 1, max: 80)
    |> validate_base_amount()
    |> assoc_constraint(:income_category)
  end

  # Monthly sources need a base amount; sporadic sources must not carry one.
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
