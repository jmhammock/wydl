defmodule Wydlm.Quiz.Audit do
  @moduledoc """
  Mechanical audit of a decoded question-bank document.

  Checks the rules that can be automated from `docs/question-authoring.md` and
  `docs/taxonomy-authoring.md` without touching the database. It is safe to run
  while the taxonomy is unpopulated: missing assignments are reported as a
  single summary finding rather than per question.
  """

  @severities [:blocker, :major, :minor, :info]

  def audit(data) when is_map(data) do
    findings0 = audit_bank([], data)

    sections = list_or_invalid(data["sections"])
    questions = list_or_invalid(data["questions"])

    findings1 =
      findings0
      |> reject_invalid_list(sections, "sections")
      |> reject_invalid_list(questions, "questions")

    sections = if is_list(sections), do: sections, else: []
    questions = if is_list(questions), do: questions, else: []

    context = build_context(sections)

    findings2 =
      findings1
      |> audit_sections(sections, context)
      |> audit_sibling_overlaps(context)
      |> audit_questions(questions, context)
      |> audit_coverage(questions, context)

    findings =
      findings2
      |> Enum.reverse()
      |> Enum.sort_by(fn finding ->
        {severity_rank(finding.severity), to_string(finding.scope), to_string(finding.id),
         finding.message}
      end)

    %{findings: findings, counts: counts(findings)}
  end

  def blockers?(%{findings: findings}), do: Enum.any?(findings, &(&1.severity == :blocker))
  def majors?(%{findings: findings}), do: Enum.any?(findings, &(&1.severity == :major))

  def format_report(%{findings: findings, counts: counts}, opts \\ []) do
    if findings == [] do
      "Question bank audit: no issues found (#{summary(counts)})"
    else
      all? = Keyword.get(opts, :all, false)

      {detailed, grouped} =
        if all? do
          {findings, []}
        else
          Enum.split_with(findings, &(&1.severity in [:blocker, :major]))
        end

      lines = Enum.map(detailed, &format_finding/1) ++ format_groups(grouped)
      Enum.join(lines ++ ["", summary(counts)], "\n")
    end
  end

  defp format_finding(finding) do
    "[#{finding.severity}] #{scope_label(finding.scope)} #{finding.id}: #{finding.message}"
  end

  defp format_groups(findings) do
    findings
    |> Enum.group_by(&{&1.severity, &1.message})
    |> Enum.sort_by(fn {{severity, message}, _group} ->
      {severity_rank(severity), message}
    end)
    |> Enum.map(fn {{severity, message}, group} ->
      ids =
        group
        |> Enum.map(&to_string(&1.id))
        |> Enum.sort()
        |> Enum.join(", ")

      "[#{severity}] #{length(group)} finding(s): #{message} (#{ids})"
    end)
  end

  defp list_or_invalid(nil), do: []
  defp list_or_invalid(list) when is_list(list), do: list
  defp list_or_invalid(_other), do: :invalid

  defp reject_invalid_list(findings, :invalid, field) do
    add(findings, :blocker, :bank, field, "#{field} must be a list")
  end

  defp reject_invalid_list(findings, _list, _field), do: findings

  defp audit_bank(findings, data) do
    findings
    |> require_string(data, "id")
    |> require_string(data, "title")
    |> require_string(data, "subtitle")
  end

  defp require_string(findings, data, key) do
    if valid_string?(data[key]) do
      findings
    else
      add(findings, :blocker, :bank, key, "#{key} is required")
    end
  end

  defp build_context(sections) do
    valid =
      sections
      |> Enum.filter(&is_map/1)
      |> Enum.filter(&valid_string?(&1["slug"]))

    by_slug =
      Enum.reduce(valid, %{}, fn section, acc ->
        Map.put_new(acc, section["slug"], section)
      end)

    non_leaf =
      valid
      |> Enum.map(& &1["parent"])
      |> Enum.filter(&valid_string?/1)
      |> MapSet.new()

    leaves =
      by_slug
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(non_leaf, &1))
      |> MapSet.new()

    %{by_slug: by_slug, non_leaf: non_leaf, leaves: leaves, sections: valid}
  end

  defp audit_sections(findings, sections, context) do
    findings =
      sections
      |> Enum.with_index()
      |> Enum.reduce(findings, fn {section, index}, acc ->
        audit_section(acc, section, index, context)
      end)

    findings
    |> audit_duplicate_section_slugs(sections)
    |> audit_cycles(context.by_slug)
  end

  defp audit_section(findings, section, index, context) when is_map(section) do
    id = if valid_string?(section["slug"]), do: section["slug"], else: "##{index}"

    findings
    |> audit_section_slug(section, id)
    |> audit_section_title(section, id)
    |> audit_section_position(section, id)
    |> audit_section_parent(section, id, context)
    |> audit_section_page_range(section, id)
  end

  defp audit_section(findings, _section, index, _context) do
    add(findings, :blocker, :section, "##{index}", "section must be an object")
  end

  defp audit_section_slug(findings, section, id) do
    if valid_string?(section["slug"]) do
      findings
    else
      add(findings, :blocker, :section, id, "slug is required")
    end
  end

  defp audit_section_title(findings, section, id) do
    if valid_string?(section["title"]) do
      findings
    else
      add(findings, :blocker, :section, id, "title is required")
    end
  end

  defp audit_section_position(findings, section, id) do
    case section["position"] do
      nil -> findings
      position when is_integer(position) and position >= 0 -> findings
      _ -> add(findings, :blocker, :section, id, "position must be a non-negative integer")
    end
  end

  defp audit_section_parent(findings, section, id, context) do
    case section["parent"] do
      nil ->
        findings

      parent when is_binary(parent) ->
        if Map.has_key?(context.by_slug, parent) do
          findings
        else
          add(findings, :blocker, :section, id, "unknown parent #{inspect(parent)}")
        end

      _other ->
        add(findings, :blocker, :section, id, "parent must be a slug or null")
    end
  end

  defp audit_section_page_range(findings, section, id) do
    case {Map.has_key?(section, "start_page"), Map.has_key?(section, "end_page")} do
      {false, false} ->
        findings

      {true, true} ->
        case {section["start_page"], section["end_page"]} do
          {nil, nil} ->
            findings

          {start_page, end_page}
          when is_integer(start_page) and is_integer(end_page) and start_page > 0 and
                 end_page >= start_page ->
            findings

          {start_page, end_page} ->
            add(
              findings,
              :blocker,
              :section,
              id,
              "invalid page range #{inspect(start_page)}..#{inspect(end_page)}"
            )
        end

      _ ->
        add(findings, :blocker, :section, id, "start_page and end_page must be provided together")
    end
  end

  defp audit_duplicate_section_slugs(findings, sections) do
    sections
    |> Enum.filter(&is_map/1)
    |> Enum.map(& &1["slug"])
    |> Enum.filter(&valid_string?/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_slug, count} -> count > 1 end)
    |> Enum.reduce(findings, fn {slug, _count}, acc ->
      add(acc, :blocker, :section, slug, "duplicate section slug")
    end)
  end

  defp audit_cycles(findings, by_slug) do
    {findings, _reported} =
      Enum.reduce(by_slug, {findings, MapSet.new()}, fn {slug, _section}, {acc, reported} ->
        case parent_cycle(by_slug, slug, []) do
          nil ->
            {acc, reported}

          cycle ->
            key = cycle |> Enum.uniq() |> Enum.sort() |> Enum.join(">")

            if MapSet.member?(reported, key) do
              {acc, reported}
            else
              message = "cycle in parent chain: " <> Enum.join(cycle, " -> ")
              {add(acc, :blocker, :section, slug, message), MapSet.put(reported, key)}
            end
        end
      end)

    findings
  end

  defp parent_cycle(by_slug, slug, path) do
    if slug in path do
      Enum.reverse([slug | path])
    else
      case Map.get(by_slug, slug) do
        nil ->
          nil

        section ->
          case section["parent"] do
            parent when is_binary(parent) -> parent_cycle(by_slug, parent, [slug | path])
            _ -> nil
          end
      end
    end
  end

  defp audit_questions(findings, questions, context) do
    findings = audit_duplicate_question_ids(findings, questions)

    questions
    |> Enum.with_index()
    |> Enum.reduce(findings, fn {question, index}, acc ->
      audit_question(acc, question, index, context)
    end)
  end

  defp audit_duplicate_question_ids(findings, questions) do
    questions
    |> Enum.filter(&is_map/1)
    |> Enum.map(& &1["id"])
    |> Enum.filter(&is_integer/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_id, count} -> count > 1 end)
    |> Enum.reduce(findings, fn {id, _count}, acc ->
      add(acc, :blocker, :question, id, "duplicate question id")
    end)
  end

  defp audit_question(findings, question, index, context) when is_map(question) do
    id = question["id"] || "##{index}"

    findings
    |> audit_question_id(question, id)
    |> audit_question_text(question, id)
    |> audit_answers(question, id)
    |> audit_correct(question, id)
    |> audit_answer_hygiene(question, id)
    |> audit_length_cue(question, id)
    |> audit_negative_stem(question, id)
    |> audit_taxonomy(question, id, context)
  end

  defp audit_question(findings, _question, index, _context) do
    add(findings, :blocker, :question, "##{index}", "question must be an object")
  end

  defp audit_question_id(findings, question, id) do
    if is_integer(question["id"]) do
      findings
    else
      add(findings, :blocker, :question, id, "id must be an integer")
    end
  end

  defp audit_question_text(findings, question, id) do
    findings
    |> require_question_string(question, "question", id)
    |> require_question_string(question, "explanation", id)
  end

  defp require_question_string(findings, question, key, id) do
    if valid_string?(question[key]) do
      findings
    else
      add(findings, :blocker, :question, id, "#{key} is required")
    end
  end

  defp audit_answers(findings, question, id) do
    case question["answers"] do
      answers when is_list(answers) and answers == [] ->
        add(findings, :blocker, :question, id, "answers is empty")

      answers when is_list(answers) ->
        findings =
          if length(answers) != 4 do
            add(findings, :major, :question, id, "expected 4 answers, got #{length(answers)}")
          else
            findings
          end

        audit_answer_values(findings, answers, id)

      _ ->
        add(findings, :blocker, :question, id, "answers must be a list")
    end
  end

  defp audit_answer_values(findings, answers, id) do
    findings =
      answers
      |> Enum.with_index()
      |> Enum.reduce(findings, fn {answer, index}, acc ->
        if valid_string?(answer) do
          acc
        else
          add(acc, :blocker, :question, id, "answer #{index + 1} is blank or not a string")
        end
      end)

    answers
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&normalize/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_text, count} -> count > 1 end)
    |> Enum.reduce(findings, fn {_text, _count}, acc ->
      add(acc, :blocker, :question, id, "duplicate answer text")
    end)
  end

  defp audit_correct(findings, question, id) do
    answers = question["answers"]
    correct = question["correct"]

    cond do
      not is_integer(correct) ->
        add(findings, :blocker, :question, id, "correct must be an integer")

      not is_list(answers) ->
        findings

      correct < 0 or correct >= length(answers) ->
        add(findings, :blocker, :question, id, "correct index #{correct} is out of range")

      true ->
        findings
    end
  end

  defp audit_answer_hygiene(findings, question, id) do
    answers = question["answers"]

    if is_list(answers) do
      Enum.reduce(answers, findings, fn answer, acc ->
        if is_binary(answer) and
             Regex.match?(~r/\b(all|none) of the above\b/i, answer) do
          add(acc, :major, :question, id, "avoid \"#{String.trim(answer)}\"")
        else
          acc
        end
      end)
    else
      findings
    end
  end

  defp audit_length_cue(findings, question, id) do
    answers = question["answers"]
    correct = question["correct"]

    if is_list(answers) and is_integer(correct) and correct >= 0 and
         correct < length(answers) do
      lengths =
        Enum.map(answers, fn answer ->
          if is_binary(answer), do: String.length(String.trim(answer)), else: 0
        end)

      key_length = Enum.at(lengths, correct)
      others = List.delete_at(lengths, correct)
      mean = if others == [], do: 0, else: Enum.sum(others) / length(others)

      if key_length >= 40 and key_length == Enum.max(lengths) and key_length > 1.5 * mean do
        add(findings, :minor, :question, id, "correct answer is much longer than the others")
      else
        findings
      end
    else
      findings
    end
  end

  defp audit_negative_stem(findings, question, id) do
    stem = question["question"]

    if is_binary(stem) and
         (Regex.match?(~r/\b(NOT|EXCEPT)\b/, stem) or
            Regex.match?(~r/which of the following is not/i, stem)) do
      add(findings, :minor, :question, id, "negative stem; verify it is intentional")
    else
      findings
    end
  end

  defp audit_taxonomy(findings, question, id, context) do
    has_section? = Map.has_key?(question, "section")
    has_page? = Map.has_key?(question, "page")

    case {has_section?, has_page?} do
      {true, true} -> audit_assigned_taxonomy(findings, question, id, context)
      {false, false} -> findings
      _ -> add(findings, :blocker, :question, id, "section and page must be provided together")
    end
  end

  defp audit_assigned_taxonomy(findings, question, id, context) do
    section_slug = question["section"]
    page = question["page"]

    cond do
      not valid_string?(section_slug) ->
        add(findings, :blocker, :question, id, "section must be a non-empty string")

      not Map.has_key?(context.by_slug, section_slug) ->
        add(findings, :blocker, :question, id, "unknown section #{inspect(section_slug)}")

      MapSet.member?(context.non_leaf, section_slug) ->
        add(
          findings,
          :blocker,
          :question,
          id,
          "section #{inspect(section_slug)} is a domain, not a leaf"
        )

      not (is_integer(page) and page > 0) ->
        add(findings, :blocker, :question, id, "page must be a positive integer")

      true ->
        audit_page_in_range(findings, question, id, context.by_slug[section_slug])
    end
  end

  defp audit_page_in_range(findings, question, id, section) do
    start_page = section["start_page"]
    end_page = section["end_page"]
    page = question["page"]

    if is_integer(start_page) and is_integer(end_page) and
         (page < start_page or page > end_page) do
      add(
        findings,
        :major,
        :question,
        id,
        "page #{page} is outside section range #{start_page}..#{end_page}"
      )
    else
      findings
    end
  end

  defp audit_coverage(findings, questions, context) do
    total = length(questions)

    assigned =
      Enum.count(questions, fn question ->
        is_map(question) and Map.has_key?(question, "section") and
          Map.has_key?(question, "page")
      end)

    cond do
      total == 0 ->
        findings

      assigned == 0 and context.by_slug == %{} ->
        findings

      assigned == 0 ->
        add(
          findings,
          :info,
          :bank,
          "taxonomy",
          "#{total} question(s) have no taxonomy assignment (backfill pending)"
        )

      assigned < total ->
        add(
          findings,
          :info,
          :bank,
          "taxonomy",
          "#{assigned}/#{total} questions assigned (partial backfill); skipping leaf coverage checks"
        )

      true ->
        audit_leaf_counts(findings, questions, context)
    end
  end

  defp audit_leaf_counts(findings, questions, context) do
    counts =
      questions
      |> Enum.filter(&is_map/1)
      |> Enum.map(& &1["section"])
      |> Enum.filter(&valid_string?/1)
      |> Enum.frequencies()

    Enum.reduce(context.leaves, findings, fn slug, acc ->
      count = Map.get(counts, slug, 0)

      if count < 4 do
        add(acc, :major, :section, slug, "leaf has fewer than 4 questions (#{count})")
      else
        acc
      end
    end)
  end

  defp audit_sibling_overlaps(findings, context) do
    context.sections
    |> Enum.filter(&(MapSet.member?(context.leaves, &1["slug"]) and valid_range?(&1)))
    |> Enum.group_by(& &1["parent"])
    |> Enum.reduce(findings, fn {_parent, siblings}, acc ->
      siblings
      |> all_pairs()
      |> Enum.reduce(acc, fn {left, right}, pair_acc ->
        if ranges_overlap?(left, right) do
          add(
            pair_acc,
            :minor,
            :section,
            "#{left["slug"]}/#{right["slug"]}",
            "sibling page ranges overlap"
          )
        else
          pair_acc
        end
      end)
    end)
  end

  defp all_pairs(list) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, index} ->
      list
      |> Enum.drop(index + 1)
      |> Enum.map(&{item, &1})
    end)
  end

  defp valid_range?(section) do
    is_integer(section["start_page"]) and is_integer(section["end_page"]) and
      section["start_page"] > 0 and section["end_page"] >= section["start_page"]
  end

  defp ranges_overlap?(left, right) do
    left["start_page"] <= right["end_page"] and right["start_page"] <= left["end_page"]
  end

  defp add(findings, severity, scope, id, message) do
    [%{severity: severity, scope: scope, id: id, message: message} | findings]
  end

  defp valid_string?(value), do: is_binary(value) and value != ""

  defp normalize(text), do: text |> String.trim() |> String.downcase()

  defp severity_rank(:blocker), do: 0
  defp severity_rank(:major), do: 1
  defp severity_rank(:minor), do: 2
  defp severity_rank(:info), do: 3

  defp scope_label(:bank), do: "bank"
  defp scope_label(:section), do: "section"
  defp scope_label(:question), do: "question"

  defp counts(findings) do
    Enum.reduce(@severities, %{}, fn severity, acc ->
      Map.put(acc, severity, Enum.count(findings, &(&1.severity == severity)))
    end)
  end

  defp summary(counts) do
    Enum.map_join(@severities, ", ", fn severity ->
      "#{Map.get(counts, severity, 0)} #{severity}"
    end)
  end
end
