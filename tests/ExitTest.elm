module ExitTest exposing (suite)

{-| Leaving a run mid-session, and the other transitions that can strand the
model. Mirrors exit.js, but checked on the model instead of the DOM.
-}

import Banks
import Expect
import Fixtures exposing (asPractice, bankFor, model, mtBank, thenMisses, withBanks, withChosen, withOutcomes, withQuestions, wyBank)
import Http
import Main exposing (Model, Msg(..), Status(..), init, selectedBank, update)
import Session exposing (Mode(..), isFinished)
import Test exposing (Test, describe, test)


apply : Msg -> Model -> Model
apply msg m =
    Tuple.first (update msg m)


loadBank : String -> Model -> Model
loadBank id m =
    apply (GotBank (Ok (bankFor id))) m


{-| Three questions into a 25 question test, nothing chosen yet.
-}
midRun : Model
midRun =
    model Test 25 |> withOutcomes (thenMisses 3 0)


{-| The same, with an answer picked but not yet committed.
-}
answering : Model
answering =
    midRun |> withChosen (Just 0)


suite : Test
suite =
    describe "leaving a run"
        [ describe "arming the leave control"
            [ test "does nothing until asked" <|
                \_ -> midRun |> .exitArmed |> Expect.equal False
            , test "arms" <|
                \_ -> apply ArmExit midRun |> .exitArmed |> Expect.equal True
            , test "arms from an unanswered question too" <|
                \_ -> model Test 25 |> apply ArmExit |> .exitArmed |> Expect.equal True
            , test "cancels" <|
                \_ ->
                    midRun
                        |> apply ArmExit
                        |> apply CancelExit
                        |> .exitArmed
                        |> Expect.equal False
            , test "leaving keeps the mode, so a retry is one tap" <|
                \_ -> midRun |> apply ArmExit |> apply ExitToStart |> .mode |> Expect.equal Test
            , test "leaving clears the questions" <|
                \_ ->
                    midRun
                        |> apply ArmExit
                        |> apply ExitToStart
                        |> .questions
                        |> List.length
                        |> Expect.equal 0
            , test "leaving clears the answers" <|
                \_ ->
                    midRun
                        |> apply ArmExit
                        |> apply ExitToStart
                        |> .answers
                        |> List.length
                        |> Expect.equal 0
            , test "leaving clears the pending choice" <|
                \_ ->
                    answering
                        |> apply ArmExit
                        |> apply ExitToStart
                        |> .chosen
                        |> Expect.equal Nothing
            , test "leaving disarms" <|
                \_ ->
                    midRun
                        |> apply ArmExit
                        |> apply ExitToStart
                        |> .exitArmed
                        |> Expect.equal False
            , test "a run that was never armed also ends clean" <|
                \_ -> midRun |> apply ExitToStart |> .exitArmed |> Expect.equal False
            , test "leaving leaves practice in practice" <|
                \_ ->
                    midRun
                        |> asPractice
                        |> apply ArmExit
                        |> apply ExitToStart
                        |> .mode
                        |> Expect.equal Practice
            , test "leaving does not show results" <|
                \_ -> midRun |> apply ArmExit |> apply ExitToStart |> isFinished |> Expect.equal False
            ]
        , describe "answering dismisses the armed control"
            {- The bug this covers: arming then tapping Next used to carry the
               confirm bar into the following question.
            -}
            [ test "Next disarms" <|
                \_ ->
                    answering
                        |> apply ArmExit
                        |> apply Next
                        |> .exitArmed
                        |> Expect.equal False
            , test "committing an answer disarms and records it" <|
                \_ ->
                    answering
                        |> apply ArmExit
                        |> apply Next
                        |> .answers
                        |> List.length
                        |> Expect.equal 4
            , test "the control can be armed again afterwards" <|
                \_ ->
                    answering
                        |> apply ArmExit
                        |> apply Next
                        |> apply ArmExit
                        |> .exitArmed
                        |> Expect.equal True
            , test "an unanswered Next commits nothing" <|
                \_ ->
                    midRun
                        |> apply ArmExit
                        |> apply Next
                        |> .answers
                        |> List.length
                        |> Expect.equal 3
            , test "an unanswered Next does nothing at all" <|
                \_ ->
                    midRun
                        |> apply ArmExit
                        |> apply Next
                        |> .chosen
                        |> Expect.equal Nothing
            ]
        , describe "a question takes one answer"
            [ test "a choice is recorded" <|
                \_ -> apply (Choose 2) midRun |> .chosen |> Expect.equal (Just 2)
            , test "a second choice is ignored once answered" <|
                \_ ->
                    midRun
                        |> apply (Choose 2)
                        |> apply (Choose 3)
                        |> .chosen
                        |> Expect.equal (Just 2)
            , test "a second choice is ignored even from a fresh click" <|
                \_ ->
                    answering
                        |> apply (Choose 3)
                        |> .chosen
                        |> Expect.equal (Just 0)
            , test "the choice is cleared once committed" <|
                \_ ->
                    midRun
                        |> apply (Choose 2)
                        |> apply Next
                        |> .chosen
                        |> Expect.equal Nothing
            , test "a fresh question accepts a choice again" <|
                \_ ->
                    midRun
                        |> apply (Choose 2)
                        |> apply Next
                        |> apply (Choose 1)
                        |> .chosen
                        |> Expect.equal (Just 1)
            , test "committing records the question that was on screen" <|
                \_ ->
                    midRun
                        |> apply (Choose 1)
                        |> apply Next
                        |> .answers
                        |> List.head
                        |> Maybe.map .question
                        |> Maybe.map .id
                        |> Expect.equal (Just 4)
            ]
        , describe "starting and restarting"
            [ test "starting clears the previous answers" <|
                \_ ->
                    midRun
                        |> apply ExitToStart
                        |> apply Start
                        |> .answers
                        |> List.length
                        |> Expect.equal 0
            , test "starting clears the loaded questions" <|
                \_ ->
                    midRun
                        |> apply Start
                        |> .questions
                        |> List.length
                        |> Expect.equal 0
            , test "starting keeps the mode" <|
                \_ -> midRun |> apply Start |> .mode |> Expect.equal Test
            , test "starting keeps the chosen length" <|
                \_ -> midRun |> apply Start |> .practiceLength |> Expect.equal 25
            , test "switching to practice changes the mode" <|
                \_ ->
                    apply (SetMode Practice) midRun
                        |> .mode
                        |> Expect.equal Practice
            , test "switching to test changes the mode" <|
                \_ ->
                    midRun
                        |> apply (SetMode Practice)
                        |> apply (SetMode Test)
                        |> .mode
                        |> Expect.equal Test
            , test "choosing a length is remembered" <|
                \_ ->
                    midRun
                        |> asPractice
                        |> apply (SetLength 50)
                        |> .practiceLength
                        |> Expect.equal 50
            , test "a run is not finished before the questions load" <|
                \_ -> midRun |> withQuestions [] |> isFinished |> Expect.equal False
            , test "restarting an unfinished run does not mark it finished" <|
                \_ -> midRun |> apply ExitToStart |> isFinished |> Expect.equal False
            , test "restarting keeps the loaded banks" <|
                \_ ->
                    midRun
                        |> apply ExitToStart
                        |> .banks
                        |> List.concatMap .questions
                        |> List.length
                        |> Expect.equal 144
            ]
        , describe "choosing a state"
            [ test "Wyoming is the default" <|
                \_ -> init () |> Tuple.first |> .selected |> Expect.equal "wy"
            , test "Montana can be selected" <|
                \_ ->
                    model Test 25
                        |> withBanks [ wyBank, mtBank ]
                        |> apply (SelectBank "mt")
                        |> .selected
                        |> Expect.equal "mt"
            , test "switching state keeps the mode" <|
                \_ ->
                    model Test 25
                        |> withBanks [ wyBank, mtBank ]
                        |> apply (SelectBank "mt")
                        |> .mode
                        |> Expect.equal Test
            , test "Wyoming's bank is selected by default" <|
                \_ ->
                    model Test 25
                        |> withBanks [ wyBank, mtBank ]
                        |> selectedBank
                        |> Maybe.map .id
                        |> Expect.equal (Just "wy")
            , test "Montana's bank is selected after switching" <|
                \_ ->
                    model Test 25
                        |> withBanks [ wyBank, mtBank ]
                        |> apply (SelectBank "mt")
                        |> selectedBank
                        |> Maybe.map .id
                        |> Expect.equal (Just "mt")
            , test "all but one bank is not enough to start" <|
                \_ ->
                    List.foldl loadBank (Tuple.first (init ())) (List.take (List.length Banks.ids - 1) Banks.ids)
                        |> .status
                        |> Expect.equal Loading
            , test "every discovered bank means ready" <|
                \_ ->
                    List.foldl loadBank (Tuple.first (init ())) Banks.ids
                        |> .status
                        |> Expect.equal Ready
            , test "a failed bank load fails the app" <|
                \_ ->
                    case
                        init ()
                            |> Tuple.first
                            |> apply (GotBank (Err Http.Timeout))
                            |> .status
                    of
                        Failed _ ->
                            Expect.pass

                        _ ->
                            Expect.fail "expected a Failed status"
            ]
        ]
