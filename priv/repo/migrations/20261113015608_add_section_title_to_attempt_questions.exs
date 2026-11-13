defmodule Wydlm.Repo.Migrations.AddSectionTitleToAttemptQuestions do
  use Ecto.Migration

  def change do
    alter table(:attempt_questions) do
      add :section_title, :string
    end
  end
end
