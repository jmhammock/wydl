# Driver License Practice Test

A mobile-friendly practice app for the Wyoming Class C driver license
written test, built with [Phoenix](https://www.phoenixframework.org/) and
[LiveView](https://hexdocs.pm/phoenix_live_view).

- **Practice mode** — drill 10, 25, 50, 100, or all 144 questions with instant
  feedback and a missed-question review at the end.
- **Test mode** — simulates the real exam: 25 questions, 20 correct to pass,
  ends early once 6 answers are wrong.
- **Question bank** — 144 Wyoming questions from the 2021 *Rules of the
  Road* manual, stored in SQLite and seeded from `priv/repo/seeds/wy.json`.

Questions and anonymous attempt history live in SQLite. There are no user
accounts: a signed cookie ties each visitor's attempts together.

## Run it

Prerequisite: Elixir 1.17+ (and Erlang/OTP 27). No Node.js is required — the
Tailwind/daisyUI and esbuild toolchains are vendored as Mix dependencies.

```sh
mix setup          # deps, create + migrate DB, seed questions, build assets
mix phx.server     # http://localhost:4000
```

`mix setup` runs `mix ecto.setup`, which seeds the question bank. To reseed
after editing the bank file:

```sh
mix wydlm.seed_questions
# or
mix run priv/repo/seeds.exs
```

## Tests

```sh
mix test          # unit + LiveView tests
mix format       # format all Elixir files
mix precommit    # compile with warnings-as-errors, format, and test
```

## Project layout

```
lib/wydlm/                  Domain: context, schemas, pure session rules
  quiz.ex                   Reads the bank and manages attempts
  quiz/session.ex           Pure run rules (lengths, scoring, pass/fail)
  quiz/seeds.ex             JSON -> SQLite importer
lib/wydlm_web/              Web layer
  live/quiz_live.ex         The quiz LiveView (start -> question -> results)
  plugs/visitor.ex          Assigns an anonymous visitor id
  components/layouts.ex     App shell (header, footer, analytics hook)
priv/repo/
  migrations/               SQLite schema
  seeds/wy.json             The Wyoming question bank
priv/static/                robots.txt, sitemap.xml, icons, og-image
assets/                     Tailwind + daisyUI theme, PostHog hook
config/                     Dev/test/prod/runtime configuration
```

## Theme

The UI uses daisyUI + Tailwind CSS with two custom themes preserving the
original Wyoming brown/gold palette: `wyoming` (light) and `wyoming-dark`
(dark). The dark theme is applied automatically via `prefers-color-scheme`.

## Analytics

Client-side PostHog analytics is optional. Set `POSTHOG_KEY` and
`POSTHOG_HOST` in the environment to enable it; leave them unset and the
PostHog bundle stays dormant. Quiz lifecycle events (`quiz_started`,
`quiz_answer_submitted`, `quiz_completed`, `quiz_abandoned`) are pushed from
the LiveView to a hook that forwards them to PostHog.

## Deploy

The app ships as a Docker release for [Fly.io](https://fly.io), with SQLite on
a persistent volume and [Litestream](https://litestream.io) streaming backups
to object storage.

Secrets to set (via `fly secrets set`):

```sh
SECRET_KEY_BASE=$(mix phx.gen.secret)
LITESTREAM_REPLICA_URL=s3://your-bucket/wydlm   # optional
POSTHOG_KEY=...                                 # optional
POSTHOG_HOST=https://us.i.posthog.com           # optional
```

Then:

```sh
fly launch
```

Because SQLite is a single-writer store, the app runs as a single machine
(`fly scale count 1`). The container entrypoint restores from Litestream when
the database is missing, applies migrations, reseeds the question bank, then
serves traffic under Litestream replication.

## License

See `LICENSE`.
