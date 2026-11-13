defmodule Wydlm.Repo.Migrations.HardenQuestionsNotNullAndDropCategory do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    repo().checkout(fn ->
      sql!("PRAGMA foreign_keys = OFF")

      ensure_all_assigned!()
      ensure_attempt_snapshots!()

      sql!("""
      CREATE TABLE questions_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_id INTEGER NOT NULL CONSTRAINT questions_bank_id_fkey REFERENCES banks(id) ON DELETE CASCADE,
        source_id INTEGER NOT NULL,
        prompt TEXT NOT NULL,
        explanation TEXT NOT NULL,
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        section_id INTEGER NOT NULL CONSTRAINT questions_section_id_fkey REFERENCES sections(id) ON DELETE RESTRICT,
        page INTEGER NOT NULL,
        CONSTRAINT questions_page_positive CHECK (page > 0)
      )
      """)

      sql!("""
      INSERT INTO questions_new
        (id, bank_id, source_id, prompt, explanation, inserted_at, updated_at, section_id, page)
      SELECT id, bank_id, source_id, prompt, explanation, inserted_at, updated_at, section_id, page
      FROM questions
      """)

      sql!("DROP TABLE questions")
      sql!("ALTER TABLE questions_new RENAME TO questions")

      sql!(
        "CREATE UNIQUE INDEX questions_bank_id_source_id_index ON questions (bank_id, source_id)"
      )

      sql!("CREATE INDEX questions_section_id_index ON questions (section_id)")

      sql!("""
      CREATE TABLE attempt_questions_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        attempt_id INTEGER NOT NULL CONSTRAINT attempt_questions_attempt_id_fkey REFERENCES attempts(id) ON DELETE CASCADE,
        question_id INTEGER NOT NULL CONSTRAINT attempt_questions_question_id_fkey REFERENCES questions(id) ON DELETE CASCADE,
        section_id INTEGER NOT NULL CONSTRAINT attempt_questions_section_id_fkey REFERENCES sections(id) ON DELETE RESTRICT,
        section_title TEXT NOT NULL,
        position INTEGER NOT NULL,
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      """)

      sql!("""
      INSERT INTO attempt_questions_new
        (id, attempt_id, question_id, section_id, section_title, position, inserted_at, updated_at)
      SELECT id, attempt_id, question_id, section_id, section_title, position, inserted_at, updated_at
      FROM attempt_questions
      """)

      sql!("DROP TABLE attempt_questions")
      sql!("ALTER TABLE attempt_questions_new RENAME TO attempt_questions")

      sql!(
        "CREATE UNIQUE INDEX attempt_questions_attempt_id_position_index ON attempt_questions (attempt_id, position)"
      )

      sql!(
        "CREATE UNIQUE INDEX attempt_questions_attempt_id_question_id_index ON attempt_questions (attempt_id, question_id)"
      )

      sql!("CREATE INDEX attempt_questions_section_id_index ON attempt_questions (section_id)")

      sql!("PRAGMA foreign_keys = ON")
    end)
  end

  def down do
    raise "Irreversible: the category column was dropped and taxonomy columns were tightened"
  end

  defp sql!(statement), do: repo().query!(statement)

  defp ensure_all_assigned! do
    %{rows: [[count]]} =
      repo().query!("SELECT count(*) FROM questions WHERE section_id IS NULL OR page IS NULL")

    if count > 0 do
      raise "Cannot harden: #{count} question(s) still have no section or page"
    end
  end

  defp ensure_attempt_snapshots! do
    %{rows: [[count]]} =
      repo().query!(
        "SELECT count(*) FROM attempt_questions WHERE section_id IS NULL OR section_title IS NULL"
      )

    if count > 0 do
      raise "Cannot harden: #{count} attempt question(s) have no section snapshot"
    end
  end
end
