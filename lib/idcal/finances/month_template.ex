defmodule Idcal.Finances.MonthTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "month_templates" do
    field :name, :string
    belongs_to :profile, Idcal.Finances.Profile
    has_many :items, Idcal.Finances.MonthTemplateItem

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint([:profile_id, :name])
  end
end
