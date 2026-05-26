defmodule Idcal.Finances.IncomeCategory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "income_categories" do
    field :name, :string
    field :pinned, :boolean, default: false
    belongs_to :profile, Idcal.Finances.Profile
    has_many :sources, Idcal.Finances.IncomeSource

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :pinned])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 60)
    |> unique_constraint(:name,
      name: :income_categories_profile_id_name_index,
      message: "already exists"
    )
  end
end
