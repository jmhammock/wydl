defmodule Wydlm.Quiz.AttemptQuestion do
  @moduledoc """
  A question in its position within an attempt. The randomized selection
  is materialized here so a run can be reconstructed later.
  """

  use Ecto.Schema

  schema "attempt_questions" do
    field :position, :integer
    field :section_title, :string

    belongs_to :attempt, Wydlm.Quiz.Attempt
    belongs_to :question, Wydlm.Quiz.Question
    belongs_to :section, Wydlm.Quiz.Section
    has_many :attempt_answers, Wydlm.Quiz.AttemptAnswer

    timestamps(type: :utc_datetime_usec)
  end
end
