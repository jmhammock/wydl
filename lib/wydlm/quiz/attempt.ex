defmodule Wydlm.Quiz.Attempt do
  @moduledoc """
  A single practice or test run by an anonymous visitor.
  """

  use Ecto.Schema

  schema "attempts" do
    field :visitor_id, :string
    field :mode, :string
    field :status, :string, default: "in_progress"
    field :question_count, :integer
    field :correct_count, :integer, default: 0
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec

    belongs_to :bank, Wydlm.Quiz.Bank
    has_many :attempt_questions, Wydlm.Quiz.AttemptQuestion

    timestamps(type: :utc_datetime_usec)
  end
end
