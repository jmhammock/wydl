defmodule Wydlm.Quiz.AnswerOption do
  @moduledoc """
  One of the possible answers to a question, marked correct or not.
  """

  use Ecto.Schema

  schema "answer_options" do
    field :position, :integer
    field :text, :string
    field :correct, :boolean, default: false

    belongs_to :question, Wydlm.Quiz.Question

    timestamps(type: :utc_datetime_usec)
  end
end
