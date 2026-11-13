defmodule Wydlm.Quiz.Question do
  @moduledoc """
  A single multiple-choice question within a bank.
  """

  use Ecto.Schema

  schema "questions" do
    field :source_id, :integer
    field :prompt, :string
    field :explanation, :string
    field :page, :integer

    belongs_to :bank, Wydlm.Quiz.Bank
    belongs_to :section, Wydlm.Quiz.Section
    has_many :answer_options, Wydlm.Quiz.AnswerOption
    has_many :attempt_questions, Wydlm.Quiz.AttemptQuestion

    timestamps(type: :utc_datetime_usec)
  end
end
