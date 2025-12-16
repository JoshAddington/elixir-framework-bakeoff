defmodule Share.Repo do
  use Ecto.Repo,
    otp_app: :share,
    adapter: Ecto.Adapters.Postgres
end
