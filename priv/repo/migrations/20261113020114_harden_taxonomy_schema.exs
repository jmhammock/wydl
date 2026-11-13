defmodule Wydlm.Repo.Migrations.HardenTaxonomySchema do
  use Ecto.Migration

  def change do
    create constraint(:questions, :questions_page_positive, check: "page IS NULL OR page > 0")

    create constraint(:questions, :questions_section_requires_page,
             check: "section_id IS NULL OR page IS NOT NULL"
           )

    create constraint(:sections, :sections_position_non_negative, check: "position >= 0")

    create constraint(:sections, :sections_page_range,
             check:
               "(start_page IS NULL AND end_page IS NULL) OR " <>
                 "(start_page > 0 AND end_page >= start_page)"
           )

    create constraint(:attempt_questions, :attempt_questions_section_title,
             check: "section_id IS NULL OR section_title IS NOT NULL"
           )
  end
end
