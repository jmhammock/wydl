defmodule Wydlm.Quiz.Session do
  @moduledoc """
  The rules of a run: how long a session is, when a test is over, and what
  counts as passing.

  Kept free of Ecto and HTML so the rules can be tested in isolation. Answers
  are any value carrying a boolean `correct` field, ordered as they were
  committed.
  """

  @type mode :: :practice | :test
  @type answer :: %{correct: boolean()}

  @test_question_count 25
  @test_pass_mark 20
  @default_practice_length 25
  @practice_lengths [10, 25, 50, 100]

  def test_question_count, do: @test_question_count
  def test_pass_mark, do: @test_pass_mark
  def default_practice_length, do: @default_practice_length

  @doc "The number of wrong answers a test tolerates before failing."
  def allowed_misses, do: @test_question_count - @test_pass_mark

  @doc "How many questions a session of the given mode contains."
  def session_length(:practice, practice_length), do: practice_length
  def session_length(:test, _practice_length), do: @test_question_count

  @doc "The practice lengths offered for a bank of `total` questions."
  def length_options(total) do
    Enum.filter(@practice_lengths, &(&1 < total)) ++ [total]
  end

  def correct_count(answers), do: Enum.count(answers, & &1.correct)

  def misses(answers), do: Enum.count(answers, &(not &1.correct))

  @doc "The wrong answers, in committed order, for the review list."
  def missed(answers), do: Enum.filter(answers, &(not &1.correct))

  @doc "A test run fails only by running out of room to pass."
  def failed?(:test, answers), do: misses(answers) > allowed_misses()
  def failed?(:practice, _answers), do: false

  def finished?(mode, questions, answers) do
    questions != [] and
      (length(answers) == length(questions) or failed?(mode, answers))
  end

  @doc "True when the next question to answer is the last one."
  def last?(questions, answers), do: length(answers) + 1 == length(questions)
end
