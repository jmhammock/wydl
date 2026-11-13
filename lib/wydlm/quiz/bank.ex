defmodule Wydlm.Quiz.Bank do
  @moduledoc """
  A question bank: one set of questions for a state's written test.
  """

  use Ecto.Schema

  schema "banks" do
    field :slug, :string
    field :title, :string
    field :subtitle, :string
    field :source, :string
    field :notes, :string

    has_many :sections, Wydlm.Quiz.Section
    has_many :questions, Wydlm.Quiz.Question
    has_many :attempts, Wydlm.Quiz.Attempt

    timestamps(type: :utc_datetime_usec)
  end
end
