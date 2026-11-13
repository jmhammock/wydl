defmodule Wydlm.Quiz.Section do
  @moduledoc """
  A node in a bank's reporting taxonomy. Parents group leaves; questions attach
  to leaves.
  """

  use Ecto.Schema

  schema "sections" do
    field :slug, :string
    field :title, :string
    field :position, :integer, default: 0
    field :start_page, :integer
    field :end_page, :integer

    belongs_to :bank, Wydlm.Quiz.Bank
    belongs_to :parent, Wydlm.Quiz.Section
    has_many :children, Wydlm.Quiz.Section, foreign_key: :parent_id
    has_many :questions, Wydlm.Quiz.Question

    timestamps(type: :utc_datetime_usec)
  end
end
