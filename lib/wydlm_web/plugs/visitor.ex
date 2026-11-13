defmodule WydlmWeb.Plugs.Visitor do
  @moduledoc """
  Assigns an anonymous visitor id to every session, creating one on first
  visit. Used to tie attempts together without any login.
  """

  import Plug.Conn

  @session_key "visitor_id"

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      nil -> put_session(conn, @session_key, Ecto.UUID.generate())
      _id -> conn
    end
  end
end
