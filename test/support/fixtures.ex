defmodule Wydlm.Fixtures do
  @moduledoc """
  Builders for test data. Questions follow the Elm test fixtures: four answer
  options, index 0 is always correct.
  """

  alias Wydlm.Quiz.{AnswerOption, Bank, Question}
  alias Wydlm.Repo

  @letters ~w(A B C D)

  def bank_fixture(attrs \\ %{}) do
    {:ok, bank} =
      Repo.insert(
        %Bank{
          slug: "wy",
          title: "Wyoming Test Bank",
          subtitle: "Test Subtitle"
        }
        |> Map.merge(attrs)
      )

    bank
  end

  def question_fixture(bank, source_id) do
    {:ok, question} =
      Repo.insert(%Question{
        bank_id: bank.id,
        source_id: source_id,
        category: "Test",
        prompt: "Question #{source_id}",
        explanation: "Because #{source_id}"
      })

    Enum.each(0..3, fn position ->
      Repo.insert!(%AnswerOption{
        question_id: question.id,
        position: position,
        text: Enum.at(@letters, position),
        correct: position == 0
      })
    end)

    Repo.preload(question, :answer_options)
  end

  def bank_with_questions(count) do
    bank = bank_fixture()

    questions =
      for n <- 1..count do
        question_fixture(bank, n)
      end

    {bank, questions}
  end
end
