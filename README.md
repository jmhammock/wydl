# Driver License Practice Test

A mobile-friendly practice app for the Wyoming Class C driver license
written test. One static page, no backend, works offline once loaded.

- **Practice mode** — drill 10, 25, 50, 100, or all 144 questions with instant
  feedback and a missed-question review at the end.
- **Test mode** — simulates the real exam: 25 questions, 20 correct to pass,
  ends early once 6 answers are wrong.
- **Question bank** — 144 Wyoming questions from the 2021 *Rules of the
  Road* manual (`public/banks/wy.json`).

Built with [Elm](https://elm-lang.org/) 0.19.2. Ships as a PWA (service
worker + web manifest) and deploys to any static host.

## Run it

Prerequisite: Node 18+.

```sh
npm ci          # install the Elm toolchain (elm, elm-test, elm-format)
npm test         # 101 tests (regenerates src/Banks.elm first)
npm run build   # regenerate banks + compile src/Main.elm --optimize --> public/elm.js
```

`npm run build` also generates `public/posthog.js` and `public/posthog-config.js`.
Copy `.env.example` to `.env` and set `POSTHOG_KEY` / `POSTHOG_HOST` to enable
browser analytics; leave them unset to build without it.

Then serve `public/` **over HTTP** (not `file://` — the app fetches its bank
file and registers a service worker, both of which need HTTP):

```sh
npx serve public
# or
python3 -m http.server --directory public
```

`npm run validate` checks `elm-format` compliance.

## Project layout

```
src/
  Main.elm      Browser wiring: loading, update loop, all views
  Session.elm   Pure run rules (lengths, scoring, pass/fail) — no HTML
  Question.elm  Bank + Question types, JSON decoders, shuffle generator
  Banks.elm     Generated bank index (do not edit — see below)
scripts/
  gen-banks.js              Discovers public/banks/*.json, regenerates Banks.elm + sw precache
  build-posthog-assets.js   Generates PostHog browser config + SDK assets (see Deploy)
tests/
  SessionTest.elm  Run rules, without a browser
  ExitTest.elm     Leaving mid-run and other model transitions
  QuestionTest.elm Shuffle + decoder
  Fixtures.elm    Shared test builders
public/
  index.html            App shell (loads elm.js, registers sw.js)
  elm.js                Compiled app (generated — see below, not committed)
  posthog.js            PostHog SDK (generated — see Deploy, not committed)
  posthog-config.js     PostHog browser config (generated — see Deploy, not committed)
  banks/wy.json       The Wyoming question bank
  styles.css            All styling
  sw.js                 Offline-first service worker
  manifest.webmanifest  PWA manifest + icons/
```

`public/elm.js` is build output and intentionally git-ignored; `npm run build`
regenerates it. Never edit it by hand.

## Fork it for your own test

Everything content-specific lives in a handful of places:

1. **Bank file** — replace `public/banks/wy.json` with yours (or add a single
   differently-named file and remove `wy.json`). The shape is:
   ```json
   {
     "id": "wy",
     "title": "Your Test Title",
     "subtitle": "Your Subtitle",
     "questions": [
       {
         "id": 1,
         "category": "Topic name",
         "question": "The question text?",
         "answers": ["First option", "Second option", "Third option"],
         "correct": 0,
         "explanation": "Why the correct answer is right."
       }
     ]
   }
   ```
   The decoder requires `id`, `title`, `subtitle`, and `questions`; anything
   else at the top level (`source`, `notes`) is informational. The `id` must
   match the filename (`wy` ↔ `banks/wy.json`); title and subtitle head the
   bank in the app (`viewStart` reads them from the loaded bank, so they stay
   in sync). `correct` is the index into `answers`. Any number of answers per
   question works.

   There is room for exactly one bank. `scripts/gen-banks.js` (run
   automatically by `npm run build` and `npm test`) validates the file,
   regenerates the `Banks` Elm module and the service worker precache list
   from it, and fails the build if `public/banks/` holds more than one file.
2. **Titles** — `public/index.html` (`<title>`, headers),
   `public/manifest.webmanifest` (`name`, `short_name`, `description`).
3. **Test rules** — `src/Session.elm` (`testQuestionCount`, `testPassMark`).
   The UI copy describing the rules lives in `viewStart`/`viewTestResult` in
   `src/Main.elm` and reads those same constants, so they stay in sync.
4. **Icons** — replace `public/icons/*` and match the filenames in the
   manifest. Also replace `public/og-image.png` (the 1200×630 social share
   banner, referenced by the `og:`/`twitter:` tags in `public/index.html`).
5. **Colors** — the palette (Wyoming brown/gold) lives in the `:root`
   variables in `public/styles.css`, plus `theme-color` in
   `public/index.html`, `theme_color`/`background_color` in
   `public/manifest.webmanifest`, the canvas share card in `public/app.js`,
   and the icons/og-image above.
 6. **Service worker** — bump `CACHE` in `public/sw.js` (`driver-test-v1` →
    something of yours) so your fork doesn't share a cache namespace, and bump
    it again on each content update for a clean cutover.

`npm test` pins the decoder and run rules, so a malformed bank or an
inconsistent pass mark will fail fast.

## Deploy

Any static host works. For Cloudflare: build command `npm run build`, output
directory `public`. Each deploy compiles from source, so the ignored `elm.js`
is never an issue.

Browser analytics is optional. Set `POSTHOG_KEY` and `POSTHOG_HOST` (for
PostHog Cloud US, `https://us.i.posthog.com`) in the build environment to
enable it; the build then writes `public/posthog-config.js` and copies the
SDK to `public/posthog.js`. If either variable is missing, the build writes
inert stubs and the app runs without analytics. See `.env.example`.
