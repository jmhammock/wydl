# Wyoming Driver Test — Class C

A mobile-friendly practice app for the Wyoming Class C driver license written
test. One static page, no backend, works offline once loaded.

- **Practice mode** — drill 10, 25, 50, 100, or all 144 questions with instant
  feedback and a missed-question review at the end.
- **Test mode** — simulates the real exam: 25 questions, 20 correct to pass,
  ends early once 6 answers are wrong.
- **Question bank** — 144 questions drawn from the 2021 *Rules of the Road*
  manual, in `public/questions.json`.

Built with [Elm](https://elm-lang.org/) 0.19.2. Ships as a PWA (service
worker + web manifest) and deploys to any static host.

## Run it

Prerequisite: Node 18+.

```sh
npm ci          # install the Elm toolchain (elm, elm-test, elm-format)
npm test        # 93 tests
npm run build   # compile src/Main.elm --optimize --> public/elm.js
```

Then serve `public/` **over HTTP** (not `file://` — the app fetches
`questions.json` and registers a service worker, both of which need HTTP):

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
  Question.elm  Question type, JSON decoder, shuffle generator
tests/
  SessionTest.elm  Run rules, without a browser
  ExitTest.elm     Leaving mid-run and other model transitions
  QuestionTest.elm Shuffle + decoder
  Fixtures.elm    Shared test builders
public/
  index.html            App shell (loads elm.js, registers sw.js)
  elm.js                Compiled app (generated — see below, not committed)
  questions.json        The question bank
  styles.css            All styling
  sw.js                 Offline-first service worker
  manifest.webmanifest  PWA manifest + icons/
```

`public/elm.js` is build output and intentionally git-ignored; `npm run build`
regenerates it. Never edit it by hand.

## Fork it for your own test

Everything content-specific lives in a handful of places:

1. **`public/questions.json`** — replace with your own bank. The shape is:
   ```json
   {
     "title": "Your Test Title",
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
   Only the `questions` array is read; everything else at the top level is
   ignored. `correct` is the index into `answers`. Any number of answers per
   question works.
2. **Titles** — `public/index.html` (`<title>`, headers), `src/Main.elm`
   (`viewStart` heading/subtitle), `public/manifest.webmanifest`
   (`name`, `short_name`, `description`).
3. **Test rules** — `src/Session.elm` (`testQuestionCount`, `testPassMark`).
   The UI copy describing the rules lives in `viewStart`/`viewTestResult` in
   `src/Main.elm` and reads those same constants, so they stay in sync.
4. **Icons** — replace `public/icons/*` and match the filenames in the
   manifest.
5. **Service worker** — bump `CACHE` in `public/sw.js` (`driver-test-v1` →
   something of yours) so your fork doesn't share a cache namespace, and bump
   it again on each content update for a clean cutover.

`npm test` pins the decoder and run rules, so a malformed bank or an
inconsistent pass mark will fail fast.

## Deploy

Any static host works. For Cloudflare Pages: build command `npm run build`,
output directory `public`. Each deploy compiles from source, so the ignored
`elm.js` is never an issue.
