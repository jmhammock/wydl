defmodule Wydlm.Quiz.SessionTest do
  use ExUnit.Case, async: true

  alias Wydlm.Quiz.Session

  describe "session length" do
    test "a test is 25 questions whatever the practice length says" do
      assert Session.session_length(:test, 10) == 25
    end

    test "practice uses the chosen length" do
      assert Session.session_length(:practice, 10) == 10
    end

    test "practice is offered 10/25/50/100/All for a 144 question bank" do
      assert Session.length_options(144) == [10, 25, 50, 100, 144]
    end

    test "length options drop any size the bank cannot fill" do
      assert Session.length_options(20) == [10, 20]
    end

    test "length options always end with the whole bank" do
      assert List.last(Session.length_options(144)) == 144
    end
  end

  describe "a test tolerates five misses" do
    test "no misses is not a failure" do
      refute Session.failed?(:test, rights(10))
    end

    test "five misses partway through is not a failure" do
      refute Session.failed?(:test, rights(15) ++ wrongs(5))
    end

    test "the sixth miss is a failure" do
      assert Session.failed?(:test, rights(15) ++ wrongs(6))
    end

    test "the sixth miss ends the run early" do
      assert Session.finished?(:test, questions(25), rights(15) ++ wrongs(6))
    end

    test "five misses spread over the whole run is not a failure" do
      refute Session.failed?(:test, rights(20) ++ wrongs(5))
    end
  end

  describe "completing a test means passing" do
    test "twenty of twenty-five is finished" do
      assert Session.finished?(:test, questions(25), rights(20) ++ wrongs(5))
    end

    test "a perfect run is finished and not a failure" do
      assert Session.finished?(:test, questions(25), rights(25))
      refute Session.failed?(:test, rights(25))
    end

    test "nineteen correct and six wrong fails, not passes" do
      assert Session.failed?(:test, rights(19) ++ wrongs(6))
    end
  end

  describe "scoring" do
    test "counts only the wrong answers" do
      assert Session.misses(rights(15) ++ wrongs(5)) == 5
    end

    test "counts only the right answers" do
      assert Session.correct_count(rights(15) ++ wrongs(5)) == 15
    end

    test "a run with no answers has no misses" do
      assert Session.misses([]) == 0
    end

    test "missed returns the wrong answers in order" do
      answers = [%{correct: true}, %{correct: false}, %{correct: false}, %{correct: true}]
      assert Session.missed(answers) == [%{correct: false}, %{correct: false}]
    end
  end

  describe "practice has no pass mark" do
    test "practice never fails, however many were missed" do
      refute Session.failed?(:practice, wrongs(25))
    end

    test "practice is not finished while questions remain" do
      refute Session.finished?(:practice, questions(25), rights(24))
    end

    test "practice is finished once all 25 are answered" do
      assert Session.finished?(:practice, questions(25), rights(25))
    end
  end

  describe "the final question" do
    test "one question left is the last" do
      assert Session.last?(questions(25), rights(24))
    end

    test "two questions left is not the last" do
      refute Session.last?(questions(25), rights(23))
    end

    test "nothing answered is not the last" do
      refute Session.last?(questions(25), [])
    end

    test "a run with no questions is not finished" do
      refute Session.finished?(:test, [], [])
    end
  end

  defp rights(n), do: List.duplicate(%{correct: true}, n)
  defp wrongs(n), do: List.duplicate(%{correct: false}, n)
  defp questions(n), do: Enum.map(1..n, &%{id: &1})
end
