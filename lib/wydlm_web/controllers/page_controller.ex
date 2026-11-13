defmodule WydlmWeb.PageController do
  use WydlmWeb, :controller

  def health(conn, _params) do
    send_resp(conn, 200, "ok")
  end
end
