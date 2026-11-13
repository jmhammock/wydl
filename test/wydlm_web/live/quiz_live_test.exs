defmodule WydlmWeb.QuizLiveTest do
  use WydlmWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Wydlm.Fixtures

  setup do
    bank_with_questions(30)
    :ok
  end

  test "start screen shows the bank, modes, and footer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "h1", "Wyoming Test Bank")
    assert has_element?(view, "button", "Practice")
    assert has_element?(view, "button", "Test")
    assert has_element?(view, "button", "10")
    assert has_element?(view, "a", "☕ Buy me a coffee")
  end

  test "switching to test mode shows the test rules", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("set-mode", %{"mode" => "test"})

    assert render(view) =~ "You need 20 correct to pass"
  end

  test "starting a practice session shows the first question", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("start")

    html = render(view)
    assert html =~ "Question 1 of 25"
    assert has_element?(view, "button", "A")
  end

  test "a correct answer reveals positive feedback", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("start")

    view |> element("button", "A") |> render_click()

    html = render(view)
    assert html =~ "Correct."
    assert has_element?(view, "button", "Next")
  end

  test "a wrong answer reveals the correct answer and explanation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("start")

    view |> element("button", "B") |> render_click()

    html = render(view)
    assert html =~ "Not quite."
    assert html =~ "Correct answer:"
  end

  test "next advances to the following question", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("start")
    view |> element("button", "A") |> render_click()
    view |> render_click("next")

    assert render(view) =~ "Question 2 of 25"
  end

  test "completing a practice session shows the score", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("start")

    view = answer_all_correct(view, 25)

    html = render(view)
    assert html =~ "Session complete"
    assert html =~ "100%"
    assert html =~ "25 of 25 correct"
  end

  test "completing a perfect test run passes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_click(view, "set-mode", %{"mode" => "test"})
    render_click(view, "start")

    view = answer_all_correct(view, 25)

    html = render(view)
    assert html =~ "Passed"
    assert html =~ "25 / 25"
  end

  test "leaving a run asks for confirmation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("start")
    view |> render_click("arm-exit")

    assert render(view) =~ "Your progress will be lost."

    view |> render_click("cancel-exit")
    assert render(view) =~ "Question 1 of 25"
  end

  test "leaving returns to the start screen", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> render_click("start")
    view |> render_click("arm-exit")
    view |> render_click("exit")

    assert has_element?(view, "h1", "Wyoming Test Bank")
  end

  defp answer_all_correct(view, count) do
    Enum.each(1..count, fn _ ->
      view |> element("button", "A") |> render_click()
      render_click(view, "next")
    end)

    view
  end
end
