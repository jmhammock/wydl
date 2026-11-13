# Taxonomy Authoring & Review Guidelines

Guidance for creating, editing, and reviewing the **taxonomy** used to
classify questions and report scores. The taxonomy is the app's
score-reporting dimension: every question belongs to exactly one leaf, and
reports group answers by that tree.

This document is a companion to [`question-authoring.md`](question-authoring.md).
Question quality (stems, distractors, explanations) lives there; the taxonomy
structure and assignment rules live here.

## Purpose

The taxonomy answers one question for every quiz item: **which bucket does
this question count toward?** It exists so that, after an attempt, the learner
can see "how did I do, topic by topic" and study their weak areas.

It is **not** a verbatim copy of the source manual's table of contents. It is a
reporting-oriented refinement of the manual's structure: a small, stable,
mutually exclusive set of buckets that are balanced enough to be scored.

## Concepts

- **Bank-scoped tree.** Each bank owns one taxonomy tree. Nodes belong to a
  bank and are keyed by a stable `slug` within it.
- **Node.** A taxonomy entry with a `slug`, `title`, optional `parent`,
  `position`, and a `start_page`/`end_page` range into the source document.
- **Domain.** A top-level grouping used for roll-up. Domains are never
  assigned to questions directly.
- **Leaf.** A bottom node that questions attach to. Leaves are the reportable
  buckets.
- **Citation.** The exact source page on which a question's tested rule
  appears, stored on the question itself.

## Non-negotiables

A taxonomy is not ready until **all** of these hold:

1. Every question is assigned to **exactly one leaf**, never a domain.
2. Leaves are **mutually exclusive and collectively exhaustive** for the bank.
3. Every node is **traceable to the source document** — no invented categories.
4. Slugs are **stable**: never renumber or reuse one. Titles may be corrected
   for accuracy; attempts snapshot the section title at start, so historical
   report labels do not change.
5. Leaves are **balanced reporting buckets**. In a ~150-question bank, aim for
   roughly 6–20 questions per leaf. Merge a leaf that would hold fewer than
   ~4; split one that exceeds ~25 or that mixes two independently testable
   skills.
6. Every question carries an **exact page citation**: the page where the rule
   it tests is stated.
7. Reporting shows **counts, not just percentages**, and rolls up small
   buckets so a learner is never shown a misleadingly precise score.

If any of these fails, fix the taxonomy before assigning questions.

## Structure rules

- Two reporting levels by default: **domain → leaf**. A third level is allowed
  only for citation and never appears in reports.
- 4–6 domains, 10–18 leaves for a single-source bank.
- **Slugs** are kebab-case and stable; never embed an ordinal or the source's
  own numbering (those change between editions).
- **Titles** are sentence case and use the manual's terminology so a learner
  can find the topic in the book.
- `position` follows the order topics appear in the source document.
- Every node has a **verified page range** (see "Source rules").

### Merge and split

- **Merge** subsections that would each hold fewer than ~4 questions into a
  sibling or parent. A bucket chosen by almost no one is not reportable.
- **Split** a leaf when it mixes two independently testable skills (e.g. a
  leaf spanning both "parking" and "interstate driving").
- Prefer **one leaf per tested rule**, not one leaf per manual heading. The
  manual may use several headings for what learners experience as one topic.

### Retirement

Never delete a node. To retire a leaf, stop assigning new questions to it and
leave the row and its title intact so historical attempts keep resolving to it.
If the source changes, add a new leaf with a new slug instead of repointing the
old one.

## Assignment rules

Assign by the **rule the key tests**, not by the question's wording or the
language of its explanation.

- Read the stem, key, and explanation together to identify the underlying
  rule, then place the question under the leaf that owns that rule.
- **Page** = the first page where that rule is stated. If it spans pages, cite
  the start.
- When two leaves seem plausible, pick the primary rule and, if useful, note
  the cross-reference in the explanation.
- Cite a **content page**, never an ad or unnumbered insert.

## Reporting rules

- **Leaf score** = correct answers / attempted questions, always displayed
  with counts (e.g. `2 / 3`), never a bare percentage.
- Per-attempt, the default view is a **domain roll-up**; leaf detail is a
  drill-down. A 25-question session spread across ~14 leaves gives only ~2 per
  leaf, which is not meaningful on its own.
- Flag buckets with fewer than 3 attempts and suppress the percentage there.
- For trends, use **cumulative accuracy per leaf** across attempts.
- Attempts snapshot the leaf **and its title** at start, so reports remain
  stable when a question is reassigned or a title is corrected.
- History is only as stable as the bank. Deleting a question cascades its
  attempt rows, and deleting an answer option cascades committed answers; keep
  edits non-destructive.
- Never mix taxonomy versions in a single report.

## Source rules (Wyoming 2021 manual)

These are specific to the current source; keep them in mind and re-verify when
a new edition is introduced.

- **Printed page number equals the PDF page number** in this edition (the
  footer `- N -` matches the page index).
- **Do not trust the table of contents page numbers.** In this edition they
  are systematically 2 low (e.g. TOC "Speed 39" is actually page 41;
  "Definitions 89" is page 91). Always read the body footer.
- **Ignore unnumbered inserts and ad pages.** Page 12 is an unnumbered insert;
  ad spreads are interleaved elsewhere (e.g. pages 16, 44–45).
- Record the manual edition and year on the bank's `source`.
- Do not assert a page range until it is checked against the body text.

## Validation checks (automatable)

These mirror the mechanical checks in `question-authoring.md` and should be
enforced in tests or the importer where practical:

- `slug` is unique within the bank.
- `parent` references an existing node; the tree has no cycles; depth ≤ 2.
- Every question has a `section_id` that points to a leaf (not a domain) and a
  `page` in `1..page_count`.
- A question's `page` falls inside its leaf's `start_page`/`end_page` (warn).
- Every leaf has at least the minimum question count (warn).
- No question points at a domain node.
- Sibling page ranges do not overlap (warn), except where the manual nests one
  topic inside another or splits a topic across a shared page (e.g. right of way
  within speed); document each approved exception.

## Workflow

1. **Draft the tree** from the source document's headings.
2. **Validate** MECE coverage and estimated question counts.
3. **Assign** every question to a leaf and a page.
4. **Audit** with `mix wydlm.audit_questions`; it must report no blockers.
5. **Review** against the rubric below.
6. **Seed and test** (`mix wydlm.seed_questions && mix precommit`).
7. **Version** the tree if it changes; do not edit slugs in place.

## Review rubric

| Severity | Meaning | Examples |
| --- | --- | --- |
| **Blocker** | Ship-stopping; must fix before use | A question with no leaf or page, a leaf that overlaps another, a slug collision, a question pointing at a domain |
| **Major** | Undermines reporting; fix before use | A leaf with < 4 questions, a leaf mixing two skills, a page cited to an ad or wrong page, a renamed slug |
| **Minor** | Polish; fix when touching it | Awkward title, slightly off page range, ordering |

## Worked examples

### 1. Too fine → merged leaf

**Bad:** separate leaves for `Scan ahead`, `Scan the roadsides`, and
`Communicate` (one question each).

**Good:** a single leaf `defensive-space` covering the IPDE process and
following-distance rules, with each manual heading cited in the explanation.

### 2. Two skills → split leaf

**Bad:** one leaf `equipment-interstate` mixing "vehicle equipment" (p. 68)
with "interstate driving" (p. 58).

**Good:** `vehicle-equipment` and `interstate-driving` as separate leaves, or
`interstate-driving` folded into `lanes-turns-passing` if it lacks enough
questions to stand alone.

### 3. Overlapping topic → rule-based assignment

**Bad:** a DUI-penalty question (suspension for a 0.08 BAC) filed under
`alcohol-drugs` because it mentions alcohol.

**Good:** filed under `licensing-suspensions`, because the tested rule is the
suspension penalty, while `alcohol-drugs` owns impairment and BAC effects.

### 4. Misleading page → verified page

**Bad:** citing the TOC's "Speed — 39".

**Good:** citing page 41, verified against the body footer.

## Relationship to the schema

- The taxonomy tree lives in a `sections` table (bank-scoped, with `parent_id`
  for domains).
- `questions.section_id` points to a **leaf**; `questions.page` holds the exact
  citation.
- `attempt_questions.section_id` and `attempt_questions.section_title` snapshot
  the leaf and its label at attempt start.
- The legacy `category` field has been removed. Questions display and report by
  their taxonomy leaf, so the app does not maintain two competing topic systems.

## Schema hardening

The backfill is complete. The hardening migration has:

- made `questions.section_id`, `questions.page`,
  `attempt_questions.section_id`, and `attempt_questions.section_title`
  `NOT NULL`,
- removed the legacy `category` column,
- kept the positive-page and ascending-section-range checks.

Integrity queries that must continue to return `0`:

```sql
SELECT count(*) FROM questions WHERE section_id IS NULL OR page IS NULL;
SELECT count(*) FROM attempt_questions
  WHERE section_id IS NULL OR section_title IS NULL;
```

Remaining optional hardening:

1. **Turn on the remaining validations.** Enforce or warn on: a question's
   `page` falls inside its leaf's range, each leaf has a minimum number of
   questions, and sibling page ranges do not overlap.
2. **Consider composite foreign keys** so a question's section must belong to
   the same bank, and a section's parent must belong to the same bank.
3. **Keep delete semantics strict.** Section references use `RESTRICT`; keep it
   that way so retiring a node cannot orphan history.

6. **Re-run** the audit queries and `mix precommit`.
