defmodule Idcal.Repo do
  use Ecto.Repo,
    otp_app: :idcal,
    adapter: Ecto.Adapters.Postgres
end
