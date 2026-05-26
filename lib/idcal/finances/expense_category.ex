defmodule Idcal.Finances.ExpenseCategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_categories" do
    field :name, :string
    field :budget_limit, :decimal
    field :pinned, :boolean, default: false
    belongs_to :profile, Idcal.Finances.Profile
    has_many :types, Idcal.Finances.ExpenseType
    has_many :budget_overrides, Idcal.Finances.BudgetOverride

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :budget_limit, :pinned])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 60)
    |> validate_number(:budget_limit, greater_than: 0)
    |> unique_constraint(:name,
      name: :expense_categories_profile_id_name_index,
      message: "already exists"
    )
  end
end
