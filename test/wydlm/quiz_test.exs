defmodule Wydlm.QuizTest do
  use Wydlm.DataCase

  alias Wydlm.Quiz
  alias Wydlm.Quiz.Seeds

  import Wydlm.Fixtures

  describe "seeding" do
    test "imports a bank with its questions and options" do
      {:ok, bank} =
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "licensing", "title" => "Licensing", "position" => 0},
            %{
              "slug" => "licensing-permits",
              "title" => "Permits",
              "parent" => "licensing",
              "position" => 1,
              "start_page" => 1,
              "end_page" => 3
            }
          ],
          "questions" => [
            %{
              "id" => 1,
              "section" => "licensing-permits",
              "page" => 2,
              "question" => "Q1?",
              "answers" => ["A", "B", "C"],
              "correct" => 1,
              "explanation" => "Because."
            }
          ]
        })

      assert bank.slug == "wy"

      [question] =
        Wydlm.Repo.all(from q in Wydlm.Quiz.Question, where: q.bank_id == ^bank.id)

      assert question.prompt == "Q1?"
      assert question.page == 2

      section = Wydlm.Repo.get!(Wydlm.Quiz.Section, question.section_id)
      assert section.slug == "licensing-permits"

      parent = Wydlm.Repo.get!(Wydlm.Quiz.Section, section.parent_id)
      assert parent.slug == "licensing"

      assert length(Wydlm.Repo.all(Wydlm.Quiz.AnswerOption, question_id: question.id)) == 3

      correct =
        Wydlm.Repo.one!(
          from o in Wydlm.Quiz.AnswerOption, where: o.question_id == ^question.id and o.correct
        )

      assert correct.text == "B"
    end

    test "re-running the seed updates in place rather than duplicating" do
      data = %{
        "id" => "wy",
        "title" => "Wyoming",
        "subtitle" => "Rules",
        "sections" => [
          %{"slug" => "licensing", "title" => "Licensing", "position" => 0},
          %{
            "slug" => "questions",
            "title" => "Questions",
            "parent" => "licensing",
            "position" => 1,
            "start_page" => 1,
            "end_page" => 10
          }
        ],
        "questions" => [
          %{
            "id" => 1,
            "section" => "questions",
            "page" => 1,
            "question" => "Q1?",
            "answers" => ["A", "B"],
            "correct" => 1,
            "explanation" => "Because."
          }
        ]
      }

      {:ok, _} = Seeds.import_data!(data)
      {:ok, _} = Seeds.import_data!(data)

      assert Wydlm.Repo.aggregate(Wydlm.Quiz.Bank, :count) == 1
      assert Wydlm.Repo.aggregate(Wydlm.Quiz.Question, :count) == 1
      assert Wydlm.Repo.aggregate(Wydlm.Quiz.AnswerOption, :count) == 2
    end

    test "re-running the seed preserves option ids" do
      data = %{
        "id" => "wy",
        "title" => "Wyoming",
        "subtitle" => "Rules",
        "sections" => [
          %{"slug" => "licensing", "title" => "Licensing", "position" => 0},
          %{
            "slug" => "questions",
            "title" => "Questions",
            "parent" => "licensing",
            "position" => 1,
            "start_page" => 1,
            "end_page" => 10
          }
        ],
        "questions" => [
          %{
            "id" => 1,
            "section" => "questions",
            "page" => 1,
            "question" => "Q1?",
            "answers" => ["A", "B"],
            "correct" => 1,
            "explanation" => "Because."
          }
        ]
      }

      {:ok, _} = Seeds.import_data!(data)
      ids_before = Wydlm.Repo.all(from o in Wydlm.Quiz.AnswerOption, select: o.id)

      {:ok, _} = Seeds.import_data!(data)
      ids_after = Wydlm.Repo.all(from o in Wydlm.Quiz.AnswerOption, select: o.id)

      assert ids_after == ids_before
    end

    test "rejects an out-of-range correct index" do
      assert_raise RuntimeError, ~r/out of range/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "licensing", "title" => "Licensing", "position" => 0},
            %{
              "slug" => "questions",
              "title" => "Questions",
              "parent" => "licensing",
              "position" => 1,
              "start_page" => 1,
              "end_page" => 10
            }
          ],
          "questions" => [
            %{
              "id" => 1,
              "section" => "questions",
              "page" => 1,
              "question" => "Q1?",
              "answers" => ["A", "B"],
              "correct" => 5,
              "explanation" => "Because."
            }
          ]
        })
      end
    end

    test "re-running the seed updates sections in place" do
      data = %{
        "id" => "wy",
        "title" => "Wyoming",
        "subtitle" => "Rules",
        "sections" => [
          %{
            "slug" => "licensing",
            "title" => "Licensing",
            "position" => 0,
            "start_page" => 1,
            "end_page" => 1
          }
        ],
        "questions" => []
      }

      {:ok, _} = Seeds.import_data!(data)
      [section] = Wydlm.Repo.all(Wydlm.Quiz.Section)

      {:ok, _} =
        Seeds.import_data!(
          put_in(data, ["sections", Access.at(0), "title"], "Licensing & permits")
        )

      assert [updated] = Wydlm.Repo.all(Wydlm.Quiz.Section)
      assert updated.id == section.id
      assert updated.title == "Licensing & permits"
    end

    test "rejects an unknown section reference" do
      assert_raise RuntimeError, ~r/unknown section/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [%{"slug" => "licensing", "title" => "Licensing"}],
          "questions" => [
            %{
              "id" => 1,
              "section" => "missing",
              "page" => 1,
              "question" => "Q1?",
              "answers" => ["A", "B"],
              "correct" => 0,
              "explanation" => "Because."
            }
          ]
        })
      end
    end

    test "rejects an invalid page reference" do
      assert_raise RuntimeError, ~r/invalid page/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [%{"slug" => "licensing", "title" => "Licensing"}],
          "questions" => [
            %{
              "id" => 1,
              "section" => "licensing",
              "page" => 0,
              "question" => "Q1?",
              "answers" => ["A", "B"],
              "correct" => 0,
              "explanation" => "Because."
            }
          ]
        })
      end
    end

    test "rejects a question with section but no page" do
      assert_raise RuntimeError, ~r/section and page must be provided together/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [%{"slug" => "licensing", "title" => "Licensing"}],
          "questions" => [
            %{
              "id" => 1,
              "section" => "licensing",
              "question" => "Q1?",
              "answers" => ["A", "B"],
              "correct" => 0,
              "explanation" => "Because."
            }
          ]
        })
      end
    end

    test "rejects a section with only one page bound" do
      assert_raise RuntimeError, ~r/start_page and end_page must be provided together/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "licensing", "title" => "Licensing", "start_page" => 5}
          ],
          "questions" => []
        })
      end
    end

    test "rejects an inverted section page range" do
      assert_raise RuntimeError, ~r/invalid page range/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{
              "slug" => "licensing",
              "title" => "Licensing",
              "start_page" => 10,
              "end_page" => 5
            }
          ],
          "questions" => []
        })
      end
    end

    test "preserves taxonomy when re-seeding without section or page keys" do
      base = %{
        "id" => "wy",
        "title" => "Wyoming",
        "subtitle" => "Rules",
        "sections" => [%{"slug" => "licensing", "title" => "Licensing"}],
        "questions" => [
          %{
            "id" => 1,
            "section" => "licensing",
            "page" => 9,
            "question" => "Q1?",
            "answers" => ["A", "B"],
            "correct" => 0,
            "explanation" => "Because."
          }
        ]
      }

      {:ok, bank} = Seeds.import_data!(base)
      [before] = Wydlm.Repo.all(from q in Wydlm.Quiz.Question, where: q.bank_id == ^bank.id)
      assert {before.section_id, before.page} != {nil, nil}

      partial =
        put_in(
          base,
          ["questions", Access.at(0)],
          Map.drop(hd(base["questions"]), ["section", "page"])
        )

      {:ok, _} = Seeds.import_data!(partial)

      [after_question] =
        Wydlm.Repo.all(from q in Wydlm.Quiz.Question, where: q.bank_id == ^bank.id)

      assert after_question.section_id == before.section_id
      assert after_question.page == 9
    end

    test "rejects explicit null taxonomy" do
      base = %{
        "id" => "wy",
        "title" => "Wyoming",
        "subtitle" => "Rules",
        "sections" => [%{"slug" => "licensing", "title" => "Licensing"}],
        "questions" => [
          %{
            "id" => 1,
            "section" => "licensing",
            "page" => 9,
            "question" => "Q1?",
            "answers" => ["A", "B"],
            "correct" => 0,
            "explanation" => "Because."
          }
        ]
      }

      {:ok, _} = Seeds.import_data!(base)

      cleared =
        base
        |> put_in(["questions", Access.at(0), "section"], nil)
        |> put_in(["questions", Access.at(0), "page"], nil)

      assert_raise RuntimeError, ~r/section and page are required/, fn ->
        Seeds.import_data!(cleared)
      end
    end

    test "rejects a section that is its own parent" do
      assert_raise RuntimeError, ~r/cycle/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "licensing", "title" => "Licensing", "parent" => "licensing"}
          ],
          "questions" => []
        })
      end
    end

    test "rejects a cycle in the section tree" do
      assert_raise RuntimeError, ~r/cycle/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "a", "title" => "A", "parent" => "b"},
            %{"slug" => "b", "title" => "B", "parent" => "a"}
          ],
          "questions" => []
        })
      end
    end

    test "rejects duplicate section slugs" do
      assert_raise RuntimeError, ~r/duplicate section slug/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "licensing", "title" => "Licensing"},
            %{"slug" => "licensing", "title" => "Licensing again"}
          ],
          "questions" => []
        })
      end
    end

    test "rejects assigning a question to a domain" do
      assert_raise RuntimeError, ~r/domain, not a leaf/, fn ->
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "licensing", "title" => "Licensing"},
            %{"slug" => "permits", "title" => "Permits", "parent" => "licensing"}
          ],
          "questions" => [
            %{
              "id" => 1,
              "section" => "licensing",
              "page" => 1,
              "question" => "Q1?",
              "answers" => ["A", "B"],
              "correct" => 0,
              "explanation" => "Because."
            }
          ]
        })
      end
    end

    test "links parents defined after their children" do
      {:ok, bank} =
        Seeds.import_data!(%{
          "id" => "wy",
          "title" => "Wyoming",
          "subtitle" => "Rules",
          "sections" => [
            %{"slug" => "permits", "title" => "Permits", "parent" => "licensing"},
            %{"slug" => "licensing", "title" => "Licensing"}
          ],
          "questions" => []
        })

      leaf = Wydlm.Repo.get_by!(Wydlm.Quiz.Section, bank_id: bank.id, slug: "permits")
      parent = Wydlm.Repo.get_by!(Wydlm.Quiz.Section, bank_id: bank.id, slug: "licensing")

      assert leaf.parent_id == parent.id
    end
  end

  describe "start_attempt/4" do
    test "picks the requested number of questions in a stable order" do
      {bank, _questions} = bank_with_questions(25)
      visitor_id = "visitor-1"

      assert {:ok, %{attempt: attempt, questions: questions}} =
               Quiz.start_attempt(bank, visitor_id, :practice, 10)

      assert attempt.question_count == 10
      assert attempt.status == "in_progress"
      assert length(questions) == 10

      positions = Enum.map(questions, & &1.position)
      assert positions == Enum.sort(positions)

      # Every picked question is unique and belongs to the bank
      ids = Enum.map(questions, & &1.question_id)
      assert length(Enum.uniq(ids)) == 10

      assert Enum.all?(questions, fn aq -> length(aq.question.answer_options) == 4 end)

      # The taxonomy is snapshotted so historical reports stay stable
      assert Enum.all?(questions, fn aq ->
               aq.section_id != nil and aq.section_id == aq.question.section_id and
                 aq.section_title == aq.question.section.title
             end)
    end

    test "stores the mode on the attempt" do
      {bank, _questions} = bank_with_questions(30)
      assert {:ok, %{attempt: attempt}} = Quiz.start_attempt(bank, "visitor-1", :test, 25)
      assert attempt.question_count == 25
      assert attempt.mode == "test"
    end

    test "snapshot stays stable when a question is reassigned after the attempt starts" do
      {bank, [question | _]} = bank_with_questions(5)
      other = section_fixture(bank, %{slug: "other-section", title: "Other Section"})

      {:ok, %{questions: attempt_questions}} =
        Quiz.start_attempt(bank, "visitor-1", :practice, 5)

      snapshot = Enum.find(attempt_questions, &(&1.question_id == question.id))
      assert snapshot.section_title == "Test Section"

      question
      |> Ecto.Changeset.change(section_id: other.id)
      |> Wydlm.Repo.update!()

      reloaded =
        Wydlm.Repo.get_by!(Wydlm.Quiz.AttemptQuestion,
          attempt_id: snapshot.attempt_id,
          question_id: question.id
        )

      assert reloaded.section_id == snapshot.section_id
      assert reloaded.section_title == "Test Section"
      assert reloaded.section_id != other.id
    end
  end

  describe "recording and finishing" do
    test "records a correct answer and finishes a run" do
      {bank, _questions} = bank_with_questions(5)
      visitor_id = "visitor-2"

      {:ok, %{attempt: attempt, questions: questions}} =
        Quiz.start_attempt(bank, visitor_id, :practice, 3)

      for attempt_question <- questions do
        correct_option = Enum.find(attempt_question.question.answer_options, & &1.correct)
        assert {:ok, answer} = Quiz.record_answer(attempt_question, correct_option)
        assert answer.correct
      end

      {:ok, finished} = Quiz.finish_attempt(attempt, :completed)
      assert finished.status == "completed"
      assert finished.correct_count == 3
      assert finished.finished_at != nil

      assert [recent] = Quiz.recent_attempts(visitor_id)
      assert recent.correct_count == 3
    end

    test "abandoning marks the attempt abandoned" do
      {bank, _questions} = bank_with_questions(5)
      {:ok, %{attempt: attempt}} = Quiz.start_attempt(bank, "visitor-3", :practice, 3)
      {:ok, abandoned} = Quiz.abandon_attempt(attempt)
      assert abandoned.status == "abandoned"
      assert [] == Quiz.recent_attempts("visitor-3")
    end
  end

  describe "database constraints" do
    test "rejects a non-positive question page" do
      bank = bank_fixture()
      section = section_fixture(bank)

      assert_raise Ecto.ConstraintError, ~r/questions_page_positive/, fn ->
        Wydlm.Repo.insert!(%Wydlm.Quiz.Question{
          bank_id: bank.id,
          source_id: 1,
          prompt: "Q",
          explanation: "E",
          section_id: section.id,
          page: 0
        })
      end
    end

    test "rejects a sectioned question without a page" do
      bank = bank_fixture()
      section = section_fixture(bank)

      assert_raise Exqlite.Error, ~r/NOT NULL constraint failed: questions.page/, fn ->
        Wydlm.Repo.insert!(%Wydlm.Quiz.Question{
          bank_id: bank.id,
          source_id: 1,
          prompt: "Q",
          explanation: "E",
          section_id: section.id
        })
      end
    end

    test "rejects an inverted section page range" do
      bank = bank_fixture()

      assert_raise Ecto.ConstraintError, ~r/sections_page_range/, fn ->
        Wydlm.Repo.insert!(%Wydlm.Quiz.Section{
          bank_id: bank.id,
          slug: "bad-range",
          title: "Bad",
          start_page: 10,
          end_page: 5
        })
      end
    end
  end
end
