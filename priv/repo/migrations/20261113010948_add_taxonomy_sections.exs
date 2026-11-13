defmodule Wydlm.Repo.Migrations.AddTaxonomySections do
  use Ecto.Migration

  def change do
    create table(:sections) do
      add :bank_id, references(:banks, on_delete: :delete_all), null: false
      add :parent_id, references(:sections, on_delete: :nilify_all)
      add :slug, :string, null: false
      add :title, :string, null: false
      add :position, :integer, null: false, default: 0
      add :start_page, :integer
      add :end_page, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sections, [:bank_id, :slug])
    create index(:sections, [:bank_id, :parent_id, :position])

    alter table(:questions) do
      add :section_id, references(:sections, on_delete: :nilify_all)
      add :page, :integer
    end

    create index(:questions, [:section_id])

    alter table(:attempt_questions) do
      add :section_id, references(:sections, on_delete: :nilify_all)
    end

    create index(:attempt_questions, [:section_id])
  end
end
