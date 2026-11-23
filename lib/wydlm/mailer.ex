defmodule Wydlm.Mailer do
  @moduledoc """
  Delivers account emails (confirmation, magic links, resets) via Swoosh.
  """
  use Swoosh.Mailer, otp_app: :wydlm
end
