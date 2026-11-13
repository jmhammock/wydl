defmodule Wydlm.Quiz do
  @moduledoc """
  Reads the question bank and manages anonymous attempts.
  """

  import Ecto.Query

  alias Wydlm.Quiz.{Attempt, AttemptAnswer, AttemptQuestion, Bank, Question}
  alias Wydlm.Repo

  @doc "The single question bank the app serves."
  def bank! do
    Repo.one!(from b in Bank, order_by: b.id, limit: 1)
  end

  @doc "How many questions the bank holds."
  def question_count(bank) do
    Repo.aggregate(Ecto.assoc(bank, :questions), :count)
  end

  @doc """
  Starts a run: picks `length` random questions and records the attempt.
  Returns the attempt with its questions preloaded in position order.
  """
  def start_attempt(bank, visitor_id, mode, length) do
    question_ids =
      Repo.all(from q in Question, where: q.bank_id == ^bank.id, select: q.id)
      |> Enum.take_random(length)

    now = DateTime.utc_now()

    result =
      Repo.transaction(fn ->
        attempt =
          Repo.insert!(%Attempt{
            visitor_id: visitor_id,
            bank_id: bank.id,
            mode: Atom.to_string(mode),
            question_count: length(question_ids),
            started_at: now
          })

        entries =
          question_ids
          |> Enum.with_index()
          |> Enum.map(fn {question_id, position} ->
            %{
              attempt_id: attempt.id,
              question_id: question_id,
              position: position,
              inserted_at: now,
              updated_at: now
            }
          end)

        Repo.insert_all(AttemptQuestion, entries)

        attempt
      end)

    case result do
      {:ok, attempt} -> {:ok, %{attempt: attempt, questions: load_questions(attempt)}}
      {:error, _} = error -> error
    end
  end

  @doc "Records a committed answer against an attempt question."
  def record_answer(attempt_question, chosen_option) do
    Repo.insert(%AttemptAnswer{
      attempt_question_id: attempt_question.id,
      chosen_option_id: chosen_option.id,
      correct: chosen_option.correct,
      answered_at: DateTime.utc_now()
    })
  end

  @doc "Marks an attempt completed or failed, recording its score and end time."
  def finish_attempt(attempt, status) do
    correct_count = Enum.count(load_answers(attempt), & &1.correct)

    attempt
    |> Ecto.Changeset.change(
      status: Atom.to_string(status),
      correct_count: correct_count,
      finished_at: DateTime.utc_now()
    )
    |> Repo.update()
  end

  @doc "Marks an attempt abandoned, recording its end time."
  def abandon_attempt(attempt) do
    attempt
    |> Ecto.Changeset.change(status: "abandoned", finished_at: DateTime.utc_now())
    |> Repo.update()
  end

  @doc "The most recent finished attempts for a visitor, newest first."
  def recent_attempts(visitor_id, limit \\ 5) do
    Repo.all(
      from a in Attempt,
        where: a.visitor_id == ^visitor_id and a.status in ["completed", "failed"],
        order_by: [desc: a.finished_at],
        limit: ^limit
    )
  end

  defp load_questions(attempt) do
    Repo.all(
      from aq in AttemptQuestion,
        where: aq.attempt_id == ^attempt.id,
        order_by: aq.position,
        preload: [question: :answer_options]
    )
    |> Enum.map(fn aq -> %{aq | question: sort_options(aq.question)} end)
  end

  defp load_answers(attempt) do
    Repo.all(
      from a in AttemptAnswer,
        join: aq in AttemptQuestion,
        on: aq.id == a.attempt_question_id,
        where: aq.attempt_id == ^attempt.id
    )
  end

  defp sort_options(%{answer_options: options} = question) do
    %{question | answer_options: Enum.sort_by(options, & &1.position)}
  end
end
