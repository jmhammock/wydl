module Fixtures exposing (asPractice, asTest, bankFor, expectErr, model, mtBank, questions, thenMisses, withBanks, withChosen, withOutcomes, withQuestions, wyBank)

{-| Shared builders for the test suites.

Every question here has `correct` = 0 and four answers, so an answer counts as
"right" when it picks index 0 and "wrong" when it picks index 1.

Two rules keep this module honest:

  - `model` fixes how long the session is; `withOutcomes` fixes how much of it
    has been answered. Conflating them is what makes "five misses so far" and
    "five misses in a finished run" look like the same state.
  - Committed answers reference the session's own questions and are stored
    newest-first, exactly as `update` keeps them. Elm 0.19.2 will not record
    update off a function call, so all record building happens here — a suite
    wanting `{ model Test 25 | ... }` would need a `let` on every single line.

-}

import Expect exposing (Expectation)
import Main exposing (Model, Status(..))
import Question exposing (Bank, Question)
import Session exposing (Answer, Mode(..))


{-| A decode that was expected to fail. `Expect` has no `isErr`, and matching
on `Err e` would pin the exact error value, which is noise here.
-}
expectErr : Result error value -> Expectation
expectErr result =
    case result of
        Err _ ->
            Expect.pass

        Ok value ->
            Expect.fail ("expected an error, but got: " ++ Debug.toString value)


question : Int -> Question
question n =
    { id = n
    , category = "Test"
    , question = "Question " ++ String.fromInt n
    , answers = [ "A", "B", "C", "D" ]
    , correct = 0
    , explanation = "Because " ++ String.fromInt n
    }


questions : Int -> List Question
questions n =
    List.map question (List.range 1 n)


{-| Loaded bank files, as if fetched. Synthetic test questions under real ids,
so bank selection behaves as in the app.
-}
wyBank : Bank
wyBank =
    { id = "wy"
    , name = "Wyoming"
    , title = "Wyoming Test Bank"
    , subtitle = "Test Subtitle"
    , questions = questions 144
    }


mtBank : Bank
mtBank =
    { id = "mt"
    , name = "Montana"
    , title = "Montana Test Bank"
    , subtitle = "Test Subtitle"
    , questions = questions 60
    }


{-| A minimal bank for any discovered id. Used to drive the loading flow for
whatever `Banks.ids` contains, so the suite needs no updates when a bank
file is added.
-}
bankFor : String -> Bank
bankFor id =
    { id = id
    , name = id
    , title = id ++ " Test Bank"
    , subtitle = "Test Subtitle"
    , questions = questions 5
    }


{-| A session of `n` questions with nothing answered and nothing chosen yet.
-}
model : Mode -> Int -> Model
model mode n =
    { status = Ready
    , selected = "wy"
    , mode = mode
    , banks = [ wyBank ]
    , questions = questions n
    , answers = []
    , chosen = Nothing
    , practiceLength = n
    , exitArmed = False
    }


{-| `rights` right, then `misses` wrong.
-}
thenMisses : Int -> Int -> List Bool
thenMisses rights misses =
    List.repeat rights True ++ List.repeat misses False


answer : Bool -> Question -> Answer
answer right q =
    Answer q
        (if right then
            q.correct

         else
            1
        )


{-| Commit `outcomes` into `m` as the answers so far, each True being a correct
answer. Answers come from the session's own questions and are stored
newest-first, as `update` keeps them. How many this is, and how long the
session is, stay independent.
-}
withOutcomes : List Bool -> Model -> Model
withOutcomes outcomes m =
    { m
        | answers =
            List.map2 answer outcomes (List.take (List.length outcomes) m.questions)
                |> List.reverse
    }


withChosen : Maybe Int -> Model -> Model
withChosen chosen m =
    { m | chosen = chosen }


withQuestions : List Question -> Model -> Model
withQuestions qs m =
    { m | questions = qs }


withBanks : List Bank -> Model -> Model
withBanks banks m =
    { m | banks = banks }


asTest : Model -> Model
asTest m =
    { m | mode = Test }


asPractice : Model -> Model
asPractice m =
    { m | mode = Practice }
