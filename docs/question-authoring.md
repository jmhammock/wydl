# Question Authoring & Review Guidelines

Guidance for creating, editing, and reviewing multiple-choice questions for
this app. The question bank is the app's source of truth, so every change here
shapes what learners study.

## Scope

These guidelines apply whenever an agent:

- adds a new question to `priv/repo/seeds/wy.json` (or a future bank),
- edits an existing question, its options, or its explanation,
- reviews a question for correctness or quality.

They do **not** cover evaluating the existing bank item-by-item; that is a
separate, deliberate effort.

## Non-negotiables

A question is not ready until **all** of these hold:

1. It tests **one** idea or skill that a learner can unambiguously act on.
2. There is **exactly one defensible correct/best answer**.
3. Every distractor is **plausible** and maps to a **real misconception**.
4. There are **no trick cues**: no length, grammar, or wording hints, no
   "all of the above" / "none of the above", no hidden negatives.
5. The **explanation teaches**: it states the rule and why the key is correct.
6. Every claim is **traceable to the source manual**.

If any of these fails, fix the item before seeding.

## Data contract

Questions live in `priv/repo/seeds/wy.json` and are imported by
`Wydlm.Quiz.Seeds`. The document is structured as:

```json
{
  "id": "wy",
  "title": "Wyoming Driver License Practice Test — Class C",
  "subtitle": "Rules of the Road, 2021",
  "source": "Wyoming Rules of the Road Driver License Manual, 2021 …",
  "notes": "…",
  "questions": [
    {
      "id": 1,
      "category": "Licensing & permits",
      "question": "…",
      "answers": ["A", "B", "C", "D"],
      "correct": 3,
      "explanation": "…"
    }
  ]
}
```

Field rules:

| Field | Rule |
| --- | --- |
| `id` | Integer, unique within the bank. Reuse an existing id only when *editing* that question. |
| `category` | One of the existing 14 categories (see below). Do not invent new categories casually. |
| `question` | The stem. One clear problem (see "Stem" rules). |
| `answers` | An array of strings. Use **4 options** to match the existing bank. No blank or duplicate entries. |
| `correct` | **Zero-based** index into `answers`. Must be in range. |
| `explanation` | Required, non-blank. Must justify the key (see "Explanation" rules). |

Existing categories:

```
Licensing & permits
Tests & vision
Alcohol, drugs & DUI
Speed & road conditions
Right of way
Required stops
Lanes, turning & passing
Signs & pavement markings
Following distance & space
Sharing the road
Weather & special conditions
Crashes & emergencies
Safety belts & child restraints
Equipment & Interstate
```

### Importer behavior

The importer is **idempotent and non-destructive**:

- A question is keyed by its `id`; options are keyed by `position`.
- Re-running updates text in place and **preserves option ids and answer
  history**, so it is safe to edit and reseed.
- An out-of-range `correct` index raises and aborts the import.
- Because options are identified by `position`, **do not reorder existing
  options**. If you must change an option's wording, edit the text in place.
  If you must add/remove options, do so deliberately and re-run the seed.

### Commands

```sh
mix wydlm.seed_questions   # import the bank into SQLite
mix test                    # run unit + LiveView tests
mix precommit               # compile (warnings-as-errors), format, test
```

Run `mix precommit` after any change.

## Authoring rules

The goal of a good multiple-choice item is to measure the target knowledge
while removing *construct-irrelevant* difficulty: reading load, trick wording,
and test-taking skill.

### Stem

- **Meaningful on its own.** A learner should know what is being asked without
  reading the options. Avoid stems like "Which of the following is true?"
- **One problem per item.** Do not bundle two facts or two questions.
- **No irrelevant material.** Extra context ("window dressing") lowers
  reliability and validity.
- **Prefer a direct question.** A question form ("At what age …?") is better
  than a fill-in-the-blank, which increases working-memory load.
- **Keep wording positive.** Avoid negatives and double negatives
  ("Which is least unlikely…"). When a negative is essential (e.g.,
  "Which of the following is NOT…"), keep it explicit and emphasize it.
- **Source-accurate.** The stem must reflect what the manual actually says.

### Correct answer (key)

- **One defensible key.** If a subject expert could argue for two options,
  rewrite. If using "best answer" phrasing, the key must be genuinely better.
- **Not the longest, not the most specific.** The key must not be identifiable
  by style.

### Distractors

- **Plausible.** A distractor chosen by almost no one is dead weight. The best
  source of distractors is **common errors** a real learner makes.
- **Misconception-mapped.** Each wrong option should reveal *why* a learner is
  wrong. Ask: "If a learner picks this, what specific misunderstanding does it
  expose?" If you can't answer, the distractor is not doing its job.
- **Mutually exclusive.** Overlapping options are trick questions.
- **Homogeneous and parallel.** Same grammatical form, similar length, similar
  level of detail and language register.
- **Free of clues.** No absolute words ("always", "never") unless meaningful,
  no grammatical mismatch with the stem, no one option standing out in length
  or precision.
- **No "all/none of the above".** These let learners use partial knowledge to
  shortcut reasoning.

### Explanation

The explanation is where learning happens — it must do more than restate the
key:

- State the rule or principle behind the correct answer.
- Explain **why the key is correct**.
- Where valuable, explain **why the main distractors are wrong** (especially
  the misconception-based ones).
- Cite the manual section/page when possible so a learner (or reviewer) can
  verify.

### Higher-order thinking

Multiple-choice items can go beyond recall. To test application and reasoning:

- Anchor the stem in a short, novel scenario or a sign/road situation.
- Require **multilogical thinking**: combining more than one fact or rule to
  arrive at the answer.
- Use distractors that require discriminating between closely related rules
  (e.g., different following distances, different speed reductions).
- Ask for the **best** answer when several options are partially right but one
  is clearly best.

### Domain-specific rules (Wyoming driver manual)

- **Fidelity first.** The 2021 Wyoming *Rules of the Road* manual is the
  source of truth. Do not invent facts, thresholds, or procedures.
- **Use the manual's terminology.** Prefer its wording for ages, distances,
  speeds, and penalties.
- **No trick questions.** The point is safe, lawful driving knowledge, not
  trapping learners on ambiguity.
- **Flag staleness.** Anything that may have changed since 2021 should be
  checked against current Wyoming law before being treated as authoritative.
  If uncertain, leave a note rather than silently asserting outdated law.

### Accessibility & plain language

- Short sentences, everyday words, active voice.
- No unnecessary jargon; explain technical terms the manual itself uses.
- Do not require cultural knowledge, English idioms, or advanced reading
  ability beyond the source material.
- A learner who knows the answer from the manual should not be blocked by the
  way the question is written.

## Worked examples

### 1. Vague stem → focused stem

**Bad:** "Which of the following is true?"

**Good:** "At what age may an instruction permit be obtained in Wyoming?"

### 2. Implausible distractor → misconception-based distractor

**Bad** (one option is obviously absurd and adds no signal):
"A red octagon means: stop / go faster / yield / the sky is blue."

**Good** (each option targets a real confusion about sign shapes):
"A red octagon means: stop / yield / do not enter / wrong way."

### 3. Length cue → parallel options

**Bad** (the key is far longer and more detailed than the others):
```
A) No seat belt
B) A lap belt only
C) A lap and shoulder belt, keeping the back against the seat back, the
   shoulder belt on the shoulder resting snugly over the chest, the lap belt
   low across the hip, the knees bent over the seat edge, and the feet flat
   on the floor
D) A lap belt worn across the abdomen
```

**Good:** make all options similar in length and detail, or split the long
correct option into a scenario where the learner must choose the single
correct detail.

### 4. Negative stem → positive stem

**Bad:** "Which of the following is not a rule for sharing the road?"

**Good:** "Which of the following is a rule for sharing the road?"

If a negative is essential (e.g., "Which of the following is NOT a situation
requiring a stop?"), keep it but ensure the negative word is unmistakable.

### 5. "All of the above" → distinct options

**Bad:** an item whose fourth option is "All of the above."

**Good:** four independent options, each testable on its own, so a learner
must know the rule rather than recognize that three options are right.

### 6. Weak explanation → explanation that teaches

**Bad:** "The answer is B."

**Good:** "B is correct because … [rule]. A is a common mistake made when …
C reflects confusing X with Y. D …"

## Review rubric

Use this when evaluating a question. Categorize each finding by severity.

| Severity | Meaning | Examples |
| --- | --- | --- |
| **Blocker** | Ship-stopping; must fix before use | Wrong or ambiguous key, factual error, out-of-range `correct`, missing explanation, duplicate/blank options |
| **Major** | Undermines validity; fix before use | Implausible or clue-giving distractor, "all/none of the above", hidden negative, length/grammar cue, unsupported claim |
| **Minor** | Polish; fix when touching the item | Awkward wording, slight length imbalance, missing category fit |

### Mechanical checks (automatable)

- 4 options present, none blank, none duplicated within an item.
- `correct` is a valid 0-based index.
- `id` is unique within the bank.
- Explanation is non-empty.
- No "all of the above" / "none of the above".
- No obvious answer-length outliers.
- Negative stems are intentional and clearly worded.

### Judgment checks (require a human or careful reading)

- Is the key the *only* defensible answer, per the manual?
- Does each distractor correspond to a real, nameable misconception?
- Would a learner who knows the manual but not the test answer correctly?
- Is the language plain enough that reading skill is not being measured?
- Does the category match the topic?

### Review output format

```markdown
| id | severity | issue | suggested fix |
| --- | --- | --- | --- |
| 42 | Blocker | `correct` is 5 but there are 4 answers | set correct to 2 |
| 57 | Major | distractor C is implausible | replace with a misconception-based option |
```

## Workflow

1. **Draft** the item (stem, key, distractors, explanation).
2. **Self-check** against the non-negotiables and the stem/option rules.
3. **Verify against the manual** — confirm the facts and terminology.
4. **Edit the JSON** following the data contract (do not reorder options).
5. **Seed and test**: `mix wydlm.seed_questions && mix precommit`.
6. **Review** with the rubric; record any findings using the review format.
