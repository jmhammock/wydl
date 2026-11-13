defmodule WydlmWeb.PageControllerTest do
  use WydlmWeb.ConnCase

  test "GET /health", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200) == "ok"
  end
end
