defmodule Wydlm.Quiz.Seeds do
  @moduledoc """
  Imports the question bank from `priv/repo/seeds/wy.json` into SQLite.

  Idempotent and non-destructive: banks, questions, and answer options are
  keyed by their natural identities (slug, source id, position) and updated
  in place, so re-running never rewrites option ids nor clears answer history.
  """

  alias Wydlm.Quiz.{AnswerOption, Bank, Question}
  alias Wydlm.Repo

  def path, do: Application.app_dir(:wydlm, "priv/repo/seeds/wy.json")

  def import! do
    path()
    |> File.read!()
    |> Jason.decode!()
    |> import_data!()
  end

  @doc "Imports a decoded bank document, used by `import!/0` and tests."
  def import_data!(data) do
    Repo.transaction(fn ->
      bank = upsert_bank(data)
      Enum.each(data["questions"], &upsert_question(bank, &1))
      bank
    end)
  end

  defp upsert_bank(data) do
    slug = data["id"]

    case Repo.get_by(Bank, slug: slug) do
      nil ->
        Repo.insert!(%Bank{
          slug: slug,
          title: data["title"],
          subtitle: data["subtitle"],
          source: data["source"],
          notes: data["notes"]
        })

      bank ->
        bank
        |> Ecto.Changeset.change(%{
          title: data["title"],
          subtitle: data["subtitle"],
          source: data["source"],
          notes: data["notes"]
        })
        |> Repo.update!()
    end
  end

  defp upsert_question(bank, data) do
    question =
      case Repo.get_by(Question, bank_id: bank.id, source_id: data["id"]) do
        nil ->
          Repo.insert!(%Question{
            bank_id: bank.id,
            source_id: data["id"],
            category: data["category"],
            prompt: data["question"],
            explanation: data["explanation"]
          })

        question ->
          question
          |> Ecto.Changeset.change(%{
            category: data["category"],
            prompt: data["question"],
            explanation: data["explanation"]
          })
          |> Repo.update!()
      end

    upsert_options(question, data["answers"], data["correct"])
    question
  end

  defp upsert_options(question, answers, correct_index) do
    unless correct_index in 0..(length(answers) - 1) do
      raise "question #{question.source_id}: correct index #{correct_index} is out of range"
    end

    answers
    |> Enum.with_index()
    |> Enum.each(fn {text, position} ->
      params = %{text: text, correct: position == correct_index}

      case Repo.get_by(AnswerOption, question_id: question.id, position: position) do
        nil ->
          Repo.insert!(%AnswerOption{
            question_id: question.id,
            position: position,
            text: text,
            correct: position == correct_index
          })

        option ->
          option
          |> Ecto.Changeset.change(params)
          |> Repo.update!()
      end
    end)

    :ok
  end
end
