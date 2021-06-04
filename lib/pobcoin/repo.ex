defmodule Pobcoin.Repo do
  use Ecto.Repo,
    otp_app: :pobcoin,
    adapter: Ecto.Adapters.Postgres
end
