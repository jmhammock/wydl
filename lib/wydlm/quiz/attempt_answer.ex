defmodule Wydlm.Quiz.AttemptAnswer do
  @moduledoc """
  A committed answer: which option was chosen and whether it was correct.
  """

  use Ecto.Schema

  schema "attempt_answers" do
    field :correct, :boolean
    field :answered_at, :utc_datetime_usec

    belongs_to :attempt_question, Wydlm.Quiz.AttemptQuestion
    belongs_to :chosen_option, Wydlm.Quiz.AnswerOption

    timestamps(type: :utc_datetime_usec)
  end
end
