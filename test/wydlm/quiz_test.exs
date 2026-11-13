defmodule Wydlm.QuizTest do
  use Wydlm.DataCase

  alias Wydlm.Quiz
  alias Wydlm.Quiz.Seeds

  import Wydlm.Fixtures

  describe "seeding" do
    test "imports a bank with its questions and options" do
      {:ok, bank} =
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "questions" => [
            %{
              "id" => 1,
              "category" => "Licensing",
              "question" => "Q1?",
              "answers" => ["A", "B", "C"],
              "correct" => 1,
              "explanation" => "Because."
            }
          ]
        })

      assert bank.slug == "wy"

      [question] =
        Wydlm.Repo.all(from q in Wydlm.Quiz.Question, where: q.bank_id == ^bank.id)

      assert question.prompt == "Q1?"
      assert length(Wydlm.Repo.all(Wydlm.Quiz.AnswerOption, question_id: question.id)) == 3

      correct =
        Wydlm.Repo.one!(
          from o in Wydlm.Quiz.AnswerOption, where: o.question_id == ^question.id and o.correct
        )

      assert correct.text == "B"
    end

    test "re-running the seed updates in place rather than duplicating" do
      data = %{
        "id" => "wy",
        "title" => "Wyoming",
        "subtitle" => "Rules",
        "questions" => [
          %{
            "id" => 1,
            "category" => "Licensing",
            "question" => "Q1?",
            "answers" => ["A", "B"],
            "correct" => 1,
            "explanation" => "Because."
          }
        ]
      }

      {:ok, _} = Seeds.import_data!(data)
      {:ok, _} = Seeds.import_data!(data)

      assert Wydlm.Repo.aggregate(Wydlm.Quiz.Bank, :count) == 1
      assert Wydlm.Repo.aggregate(Wydlm.Quiz.Question, :count) == 1
      assert Wydlm.Repo.aggregate(Wydlm.Quiz.AnswerOption, :count) == 2
    end

    test "re-running the seed preserves option ids" do
      data = %{
        "id" => "wy",
        "title" => "Wyoming",
        "subtitle" => "Rules",
        "questions" => [
          %{
            "id" => 1,
            "category" => "Licensing",
            "question" => "Q1?",
            "answers" => ["A", "B"],
            "correct" => 1,
            "explanation" => "Because."
          }
        ]
      }

      {:ok, _} = Seeds.import_data!(data)
      ids_before = Wydlm.Repo.all(from o in Wydlm.Quiz.AnswerOption, select: o.id)

      {:ok, _} = Seeds.import_data!(data)
      ids_after = Wydlm.Repo.all(from o in Wydlm.Quiz.AnswerOption, select: o.id)

      assert ids_after == ids_before
    end

    test "rejects an out-of-range correct index" do
      assert_raise RuntimeError, ~r/out of range/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "questions" => [
            %{
              "id" => 1,
              "category" => "Licensing",
              "question" => "Q1?",
              "answers" => ["A", "B"],
              "correct" => 5,
              "explanation" => "Because."
            }
          ]
        })
      end
    end
  end

  describe "start_attempt/4" do
    test "picks the requested number of questions in a stable order" do
      {bank, _questions} = bank_with_questions(25)
      visitor_id = "visitor-1"

      assert {:ok, %{attempt: attempt, questions: questions}} =
               Quiz.start_attempt(bank, visitor_id, :practice, 10)

      assert attempt.question_count == 10
      assert attempt.status == "in_progress"
      assert length(questions) == 10

      positions = Enum.map(questions, & &1.position)
      assert positions == Enum.sort(positions)

      # Every picked question is unique and belongs to the bank
      ids = Enum.map(questions, & &1.question_id)
      assert length(Enum.uniq(ids)) == 10

      assert Enum.all?(questions, fn aq -> length(aq.question.answer_options) == 4 end)
    end

    test "stores the mode on the attempt" do
      {bank, _questions} = bank_with_questions(30)
      assert {:ok, %{attempt: attempt}} = Quiz.start_attempt(bank, "visitor-1", :test, 25)
      assert attempt.question_count == 25
      assert attempt.mode == "test"
    end
  end

  describe "recording and finishing" do
    test "records a correct answer and finishes a run" do
      {bank, _questions} = bank_with_questions(5)
      visitor_id = "visitor-2"

      {:ok, %{attempt: attempt, questions: questions}} =
        Quiz.start_attempt(bank, visitor_id, :practice, 3)

      for attempt_question <- questions do
        correct_option = Enum.find(attempt_question.question.answer_options, & &1.correct)
        assert {:ok, answer} = Quiz.record_answer(attempt_question, correct_option)
        assert answer.correct
      end

      {:ok, finished} = Quiz.finish_attempt(attempt, :completed)
      assert finished.status == "completed"
      assert finished.correct_count == 3
      assert finished.finished_at != nil

      assert [recent] = Quiz.recent_attempts(visitor_id)
      assert recent.correct_count == 3
    end

    test "abandoning marks the attempt abandoned" do
      {bank, _questions} = bank_with_questions(5)
      {:ok, %{attempt: attempt}} = Quiz.start_attempt(bank, "visitor-3", :practice, 3)
      {:ok, abandoned} = Quiz.abandon_attempt(attempt)
      assert abandoned.status == "abandoned"
      assert [] == Quiz.recent_attempts("visitor-3")
    end
  end
end
