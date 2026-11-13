defmodule Wydlm.Repo.Migrations.CreateQuizTables do
  use Ecto.Migration

  def change do
    create table(:banks) do
      add :slug, :string, null: false
      add :title, :string, null: false
      add :subtitle, :string, null: false
      add :source, :string
      add :notes, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:banks, [:slug])

    create table(:questions) do
      add :bank_id, references(:banks, on_delete: :delete_all), null: false
      add :source_id, :integer, null: false
      add :category, :string, null: false
      add :prompt, :text, null: false
      add :explanation, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:questions, [:bank_id, :source_id])

    create table(:answer_options) do
      add :question_id, references(:questions, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :text, :text, null: false
      add :correct, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:answer_options, [:question_id, :position])
    create unique_index(:answer_options, [:question_id], where: "correct = 1")

    create table(:attempts) do
      add :visitor_id, :string, null: false
      add :bank_id, references(:banks, on_delete: :delete_all), null: false
      add :mode, :string, null: false
      add :status, :string, null: false, default: "in_progress"
      add :question_count, :integer, null: false
      add :correct_count, :integer, null: false, default: 0
      add :started_at, :utc_datetime_usec, null: false
      add :finished_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:attempts, [:visitor_id, :inserted_at])

    create table(:attempt_questions) do
      add :attempt_id, references(:attempts, on_delete: :delete_all), null: false
      add :question_id, references(:questions, on_delete: :delete_all), null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:attempt_questions, [:attempt_id, :position])
    create unique_index(:attempt_questions, [:attempt_id, :question_id])

    create table(:attempt_answers) do
      add :attempt_question_id, references(:attempt_questions, on_delete: :delete_all),
        null: false

      add :chosen_option_id, references(:answer_options, on_delete: :delete_all), null: false
      add :correct, :boolean, null: false
      add :answered_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:attempt_answers, [:attempt_question_id])
  end
end
