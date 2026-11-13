defmodule Wydlm.Quiz.AuditTest do
  use ExUnit.Case, async: true

  alias Wydlm.Quiz.Audit

  test "a clean document has no findings" do
    result = Audit.audit(valid_data())

    assert result.findings == []
    refute Audit.blockers?(result)
    refute Audit.majors?(result)
  end

  test "flags an out-of-range correct index" do
    data = put_in(valid_data(), ["questions", Access.at(0), "correct"], 9)
    assert finding?(data, :blocker, ~r/out of range/)
  end

  test "flags duplicate answer text" do
    data = put_in(valid_data(), ["questions", Access.at(0), "answers"], ["A", "A", "B", "C"])
    assert finding?(data, :blocker, ~r/duplicate answer/)
  end

  test "flags all of the above" do
    data =
      put_in(valid_data(), ["questions", Access.at(0), "answers"], [
        "A",
        "B",
        "C",
        "All of the above"
      ])

    assert finding?(data, :major, ~r/all of the above/i)
  end

  test "flags a section without a page" do
    data = update_in(valid_data(), ["questions", Access.at(0)], &Map.delete(&1, "page"))
    assert finding?(data, :blocker, ~r/section and page/)
  end

  test "flags unknown sections" do
    data = put_in(valid_data(), ["questions", Access.at(0), "section"], "missing")
    assert finding?(data, :blocker, ~r/unknown section/)
  end

  test "flags assignment to a domain" do
    data = put_in(valid_data(), ["questions", Access.at(0), "section"], "licensing")
    assert finding?(data, :blocker, ~r/domain, not a leaf/)
  end

  test "flags a page outside the section range" do
    data = put_in(valid_data(), ["questions", Access.at(0), "page"], 99)
    assert finding?(data, :major, ~r/outside section range/)
  end

  test "flags a cycle" do
    data = put_in(valid_data(), ["sections", Access.at(1), "parent"], "permits")
    assert finding?(data, :blocker, ~r/cycle/)
  end

  test "flags a section with only one page bound" do
    data = update_in(valid_data(), ["sections", Access.at(1)], &Map.delete(&1, "end_page"))
    assert finding?(data, :blocker, ~r/start_page and end_page/)
  end

  test "reports unassigned questions as a single info finding" do
    data =
      update_in(valid_data(), ["questions"], fn questions ->
        Enum.map(questions, &Map.drop(&1, ["section", "page"]))
      end)

    result = Audit.audit(data)

    refute Audit.blockers?(result)
    assert Enum.count(result.findings, &(&1.severity == :info)) == 1
  end

  test "reports leaves with fewer than four questions once fully assigned" do
    data = update_in(valid_data(), ["questions"], fn questions -> Enum.take(questions, 2) end)
    assert finding?(data, :major, ~r/fewer than 4 questions/)
  end

  test "flags overlapping sibling page ranges" do
    data =
      update_in(valid_data(), ["sections"], fn sections ->
        sections ++
          [
            %{
              "slug" => "other",
              "title" => "Other",
              "parent" => "licensing",
              "position" => 2,
              "start_page" => 8,
              "end_page" => 12
            }
          ]
      end)

    assert finding?(data, :minor, ~r/overlap/)
  end

  defp finding?(data, severity, message) do
    data
    |> Audit.audit()
    |> Map.fetch!(:findings)
    |> Enum.any?(fn finding ->
      finding.severity == severity and Regex.match?(message, finding.message)
    end)
  end

  defp valid_data do
    sections = [
      %{"slug" => "licensing", "title" => "Licensing", "position" => 0},
      %{
        "slug" => "permits",
        "title" => "Permits",
        "parent" => "licensing",
        "position" => 1,
        "start_page" => 5,
        "end_page" => 10
      }
    ]

    questions =
      for id <- 1..4 do
        %{
          "id" => id,
          "section" => "permits",
          "page" => 6,
          "question" => "Question #{id}?",
          "answers" => ["A", "B", "C", "D"],
          "correct" => 0,
          "explanation" => "Because #{id}."
        }
      end

    %{
      "id" => "wy",
      "title" => "Wyoming",
      "subtitle" => "Rules",
      "sections" => sections,
      "questions" => questions
    }
  end
end
