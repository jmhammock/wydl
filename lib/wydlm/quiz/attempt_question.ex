defmodule Wydlm.Quiz.AttemptQuestion do
  @moduledoc """
  A question in its position within an attempt. The randomized selection
  is materialized here so a run can be reconstructed later.
  """

  use Ecto.Schema

  schema "attempt_questions" do
    field :position, :integer

    belongs_to :attempt, Wydlm.Quiz.Attempt
    belongs_to :question, Wydlm.Quiz.Question
    has_many :attempt_answers, Wydlm.Quiz.AttemptAnswer

    timestamps(type: :utc_datetime_usec)
  end
end
