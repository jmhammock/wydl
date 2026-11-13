defmodule Mix.Tasks.Wydlm.AuditQuestions do
  @moduledoc """
  Audits a question-bank JSON document without touching the database.

      mix wydlm.audit_questions [path] [--all]

  Defaults to `priv/repo/seeds/wy.json`. Exits non-zero when blockers are found.
  By default blockers and majors are listed individually and minors are grouped;
  pass `--all` to list every finding.
  """

  use Mix.Task

  @shortdoc "Audit the question bank JSON"

  @impl Mix.Task
  def run(args) do
    {opts, args, _invalid} = OptionParser.parse(args, strict: [all: :boolean])
    path = args |> List.first() |> default_path()
    data = path |> File.read!() |> Jason.decode!()

    result = Wydlm.Quiz.Audit.audit(data)

    Mix.shell().info(Wydlm.Quiz.Audit.format_report(result, Keyword.take(opts, [:all])))

    if Wydlm.Quiz.Audit.blockers?(result) do
      Mix.raise("Question bank audit failed with blockers")
    end
  end

  defp default_path(nil), do: Path.expand("priv/repo/seeds/wy.json")
  defp default_path(path), do: Path.expand(path)
end
