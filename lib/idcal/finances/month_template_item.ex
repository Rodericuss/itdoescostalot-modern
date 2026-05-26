defmodule Idcal.Finances.MonthTemplateItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "month_template_items" do
    field :kind, :string
    field :category_name, :string
    field :name, :string
    field :amount, :decimal
    field :note, :string
    belongs_to :month_template, Idcal.Finances.MonthTemplate

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:kind, :category_name, :name, :amount, :note])
    |> validate_required([:kind, :category_name, :name, :amount])
    |> validate_inclusion(:kind, ["income", "expense"])
    |> validate_number(:amount, greater_than: 0)
  end
end
