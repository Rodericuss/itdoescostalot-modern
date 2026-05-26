defmodule Idcal.Finances.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "profiles" do
    field :nickname, :string
    field :start_year, :integer
    field :start_month, :integer
    field :currency, :string, default: "BRL"
    field :theme, :string, default: "dark"
    belongs_to :user, Idcal.Accounts.User
    has_many :shares, Idcal.Finances.ProfileShare

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:nickname, :start_year, :start_month, :currency, :theme])
    |> validate_required([:nickname])
    |> validate_length(:nickname, min: 1, max: 60)
    |> validate_inclusion(:start_month, 1..12)
    |> validate_number(:start_year, greater_than_or_equal_to: 1970, less_than_or_equal_to: 9999)
    |> validate_inclusion(:currency, ~w(BRL USD EUR GBP JPY CAD AUD CHF))
    |> validate_inclusion(:theme, ~w(dark light))
  end

  def tracking_started?(%__MODULE__{start_year: nil}, _year, _month), do: true
  def tracking_started?(%__MODULE__{start_month: nil}, _year, _month), do: true

  def tracking_started?(%__MODULE__{start_year: sy, start_month: sm}, year, month) do
    year > sy or (year == sy and month >= sm)
  end
end
