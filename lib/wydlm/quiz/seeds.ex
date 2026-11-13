defmodule Wydlm.Quiz.Seeds do
  @moduledoc """
  Imports the question bank from `priv/repo/seeds/wy.json` into SQLite.

  Idempotent and non-destructive: banks, questions, and answer options are
  keyed by their natural identities (slug, source id, position) and updated
  in place, so re-running never rewrites option ids nor clears answer history.
  """

  alias Wydlm.Quiz.{AnswerOption, Bank, Question, Section}
  alias Wydlm.Repo

  import Ecto.Query

  def path, do: Application.app_dir(:wydlm, "priv/repo/seeds/wy.json")

  def import! do
    path()
    |> File.read!()
    |> Jason.decode!()
    |> import_data!()
  end

  @doc "Imports a decoded bank document, used by `import!/0` and tests."
  def import_data!(data) do
    Repo.transaction(fn ->
      bank = upsert_bank(data)
      upsert_sections(bank, data["sections"] || [])
      ensure_acyclic!(bank)
      non_leaf_ids = non_leaf_section_ids(bank)
      Enum.each(data["questions"], &upsert_question(bank, &1, non_leaf_ids))
      bank
    end)
  end

  defp upsert_bank(data) do
    slug = data["id"]

    case Repo.get_by(Bank, slug: slug) do
      nil ->
        Repo.insert!(%Bank{
          slug: slug,
          title: data["title"],
          subtitle: data["subtitle"],
          source: data["source"],
          notes: data["notes"]
        })

      bank ->
        bank
        |> Ecto.Changeset.change(%{
          title: data["title"],
          subtitle: data["subtitle"],
          source: data["source"],
          notes: data["notes"]
        })
        |> Repo.update!()
    end
  end

  defp upsert_sections(bank, sections) do
    ensure_unique_slugs!(sections)
    Enum.each(sections, &ensure_section_page_range!/1)

    sections
    |> Enum.with_index()
    |> Enum.each(fn {data, index} -> upsert_section(bank, data, index) end)

    Enum.each(sections, &link_section_parent(bank, &1))
  end

  defp ensure_section_page_range!(%{"slug" => slug} = data) do
    case {Map.has_key?(data, "start_page"), Map.has_key?(data, "end_page")} do
      {false, false} ->
        :ok

      {true, true} ->
        ensure_valid_range!(slug, data["start_page"], data["end_page"])

      _ ->
        raise "section #{slug}: start_page and end_page must be provided together"
    end
  end

  defp ensure_valid_range!(_slug, nil, nil), do: :ok

  defp ensure_valid_range!(slug, start_page, end_page) do
    unless is_integer(start_page) and is_integer(end_page) and start_page > 0 and
             end_page >= start_page do
      raise "section #{slug}: invalid page range #{inspect(start_page)}..#{inspect(end_page)}"
    end
  end

  defp ensure_unique_slugs!(sections) do
    duplicates =
      sections
      |> Enum.map(& &1["slug"])
      |> Enum.frequencies()
      |> Enum.filter(fn {_slug, count} -> count > 1 end)
      |> Enum.map(fn {slug, _count} -> slug end)

    if duplicates != [] do
      raise "duplicate section slug(s): #{inspect(duplicates)}"
    end
  end

  defp upsert_section(bank, data, default_position) do
    attrs =
      %{
        title: data["title"],
        position: data["position"] || default_position
      }
      |> put_section_page_range(data)

    case Repo.get_by(Section, bank_id: bank.id, slug: data["slug"]) do
      nil ->
        Repo.insert!(
          %Section{bank_id: bank.id, slug: data["slug"]}
          |> Ecto.Changeset.change(attrs)
        )

      section ->
        section
        |> Ecto.Changeset.change(attrs)
        |> Repo.update!()
    end
  end

  defp put_section_page_range(attrs, data) do
    if Map.has_key?(data, "start_page") do
      attrs
      |> Map.put(:start_page, data["start_page"])
      |> Map.put(:end_page, data["end_page"])
    else
      attrs
    end
  end

  defp link_section_parent(bank, %{"slug" => slug, "parent" => parent_slug})
       when is_binary(parent_slug) do
    section = Repo.get_by!(Section, bank_id: bank.id, slug: slug)

    parent =
      Repo.get_by(Section, bank_id: bank.id, slug: parent_slug) ||
        raise "section #{slug}: unknown parent #{inspect(parent_slug)}"

    section
    |> Ecto.Changeset.change(parent_id: parent.id)
    |> Repo.update!()
  end

  defp link_section_parent(bank, %{"slug" => slug}) do
    Repo.get_by!(Section, bank_id: bank.id, slug: slug)
    |> Ecto.Changeset.change(parent_id: nil)
    |> Repo.update!()
  end

  defp ensure_acyclic!(bank) do
    sections =
      Repo.all(
        from s in Section,
          where: s.bank_id == ^bank.id,
          select: {s.id, s.slug, s.parent_id}
      )

    by_id = Map.new(sections, fn {id, slug, parent_id} -> {id, {slug, parent_id}} end)

    Enum.each(sections, fn {id, _slug, _parent_id} ->
      walk_parent_chain!(by_id, id, MapSet.new(), id)
    end)
  end

  defp walk_parent_chain!(by_id, id, seen, origin_id) do
    if MapSet.member?(seen, id) do
      {slug, _parent_id} = Map.fetch!(by_id, origin_id)
      raise "section #{slug}: cycle in parent chain"
    end

    {_slug, parent_id} = Map.fetch!(by_id, id)

    if parent_id do
      walk_parent_chain!(by_id, parent_id, MapSet.put(seen, id), origin_id)
    end
  end

  defp non_leaf_section_ids(bank) do
    Repo.all(
      from s in Section,
        where: s.bank_id == ^bank.id and not is_nil(s.parent_id),
        select: s.parent_id
    )
    |> MapSet.new()
  end

  defp upsert_question(bank, data, non_leaf_ids) do
    attrs =
      %{
        prompt: data["question"],
        explanation: data["explanation"]
      }
      |> put_taxonomy(bank, data, non_leaf_ids)

    question =
      case Repo.get_by(Question, bank_id: bank.id, source_id: data["id"]) do
        nil ->
          Repo.insert!(
            %Question{bank_id: bank.id, source_id: data["id"]}
            |> Ecto.Changeset.change(attrs)
          )

        question ->
          question
          |> Ecto.Changeset.change(attrs)
          |> Repo.update!()
      end

    upsert_options(question, data["answers"], data["correct"])
    question
  end

  defp put_taxonomy(attrs, _bank, data, _non_leaf_ids)
       when not is_map_key(data, "section") and not is_map_key(data, "page"),
       do: attrs

  defp put_taxonomy(attrs, bank, data, non_leaf_ids)
       when is_map_key(data, "section") and is_map_key(data, "page") do
    if is_nil(data["section"]) or is_nil(data["page"]) do
      raise "question #{data["id"]}: section and page are required"
    end

    attrs
    |> Map.put(:section_id, section_id_for(bank, data, non_leaf_ids))
    |> Map.put(:page, page_for(data))
  end

  defp put_taxonomy(_attrs, _bank, data, _non_leaf_ids) do
    raise "question #{data["id"]}: section and page must be provided together"
  end

  defp section_id_for(_bank, %{"section" => nil}, _non_leaf_ids), do: nil

  defp section_id_for(bank, %{"section" => slug} = data, non_leaf_ids) do
    case Repo.get_by(Section, bank_id: bank.id, slug: slug) do
      nil ->
        raise "question #{data["id"]}: unknown section #{inspect(slug)}"

      %Section{id: id} ->
        if MapSet.member?(non_leaf_ids, id) do
          raise "question #{data["id"]}: section #{inspect(slug)} is a domain, not a leaf"
        end

        id
    end
  end

  defp page_for(%{"page" => nil}), do: nil
  defp page_for(%{"page" => page}) when is_integer(page) and page > 0, do: page

  defp page_for(%{"page" => page} = data),
    do: raise("question #{data["id"]}: invalid page #{inspect(page)}")

  defp upsert_options(question, answers, correct_index) do
    unless correct_index in 0..(length(answers) - 1) do
      raise "question #{question.source_id}: correct index #{correct_index} is out of range"
    end

    answers
    |> Enum.with_index()
    |> Enum.each(fn {text, position} ->
      params = %{text: text, correct: position == correct_index}

      case Repo.get_by(AnswerOption, question_id: question.id, position: position) do
        nil ->
          Repo.insert!(%AnswerOption{
            question_id: question.id,
            position: position,
            text: text,
            correct: position == correct_index
          })

        option ->
          option
          |> Ecto.Changeset.change(params)
          |> Repo.update!()
      end
    end)

    :ok
  end
end
