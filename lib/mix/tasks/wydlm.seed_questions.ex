defmodule Mix.Tasks.Wydlm.SeedQuestions do
  @moduledoc """
  Imports the question bank into SQLite.

      mix wydlm.seed_questions
  """

  use Mix.Task

  @shortdoc "Seed the question bank"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    {:ok, bank} = Wydlm.Quiz.Seeds.import!()
    Mix.shell().info("Seeded bank \"#{bank.slug}\" (#{bank.title})")
  end
end
