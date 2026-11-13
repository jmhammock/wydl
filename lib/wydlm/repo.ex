defmodule Wydlm.Repo do
  use Ecto.Repo,
    otp_app: :wydlm,
    adapter: Ecto.Adapters.SQLite3
end
