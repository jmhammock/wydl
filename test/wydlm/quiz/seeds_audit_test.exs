defmodule Wydlm.Quiz.SeedsAuditTest do
  use ExUnit.Case, async: true

  alias Wydlm.Quiz.{Audit, Seeds}

  test "the seeded bank has no blockers or majors" do
    data =
      Seeds.path()
      |> File.read!()
      |> Jason.decode!()

    findings =
      data
      |> Audit.audit()
      |> Map.fetch!(:findings)
      |> Enum.filter(&(&1.severity in [:blocker, :major]))

    assert findings == [], "seed audit findings: #{inspect(findings)}"
  end
end
