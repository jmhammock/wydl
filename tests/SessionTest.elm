module SessionTest exposing (suite)

{-| The rules of a run, tested without a browser.

These mirror what test-mode.js and drive.js assert through the DOM: how long a
session is, when a test is over, and what counts as passing.

-}

import Expect
import Fixtures exposing (asTest, model, thenMisses, withOutcomes, withQuestions)
import Main exposing (Model)
import Session exposing (Mode(..), correctCount, isFailed, isFinished, isLast, lengthOptions, misses, sessionLength)
import Test exposing (Test, describe, test)


{-| A 25 question test with `outcomes` committed. The session length is fixed at
25 so that "five misses so far" and "five misses in a completed run" stay
distinguishable.
-}
testRun : List Bool -> Model
testRun outcomes =
    model Test 25 |> withOutcomes outcomes


{-| How many questions were actually answered.
-}
answered : Model -> Int
answered m =
    List.length m.answers


suite : Test
suite =
    describe "session"
        [ describe "session length"
            [ test "a test is 25 questions whatever the practice length says" <|
                \_ ->
                    model Practice 10
                        |> asTest
                        |> sessionLength
                        |> Expect.equal 25
            , test "practice uses the chosen length" <|
                \_ -> sessionLength (model Practice 10) |> Expect.equal 10
            , test "practice is offered 10/25/50/100/All for a 144 question bank" <|
                \_ ->
                    lengthOptions 144
                        |> Expect.equal [ 10, 25, 50, 100, 144 ]
            , test "length options drop any size the bank cannot fill" <|
                \_ -> lengthOptions 20 |> Expect.equal [ 10, 20 ]
            , test "length options always end with the whole bank" <|
                \_ ->
                    lengthOptions 144
                        |> List.reverse
                        |> List.head
                        |> Expect.equal (Just 144)
            ]
        , describe "a test tolerates five misses"
            [ test "no misses is not a failure" <|
                \_ -> testRun (thenMisses 10 0) |> isFailed |> Expect.equal False
            , test "five misses partway through is not a failure" <|
                \_ -> testRun (thenMisses 15 5) |> isFailed |> Expect.equal False
            , test "the run continues after five misses" <|
                \_ -> testRun (thenMisses 15 5) |> isFinished |> Expect.equal False
            , test "the sixth miss is a failure" <|
                \_ -> testRun (thenMisses 15 6) |> isFailed |> Expect.equal True
            , test "the sixth miss ends the run early" <|
                \_ -> testRun (thenMisses 15 6) |> isFinished |> Expect.equal True
            , test "ending early leaves questions unanswered" <|
                \_ -> testRun (thenMisses 15 6) |> answered |> Expect.equal 21
            , test "failing on every question stops at 6" <|
                \_ -> testRun (thenMisses 0 6) |> answered |> Expect.equal 6
            , test "five misses spread over the whole run is not a failure" <|
                \_ -> testRun (thenMisses 20 5) |> isFailed |> Expect.equal False
            ]
        , describe "completing a test means passing"
            [ test "twenty of twenty-five correct" <|
                \_ -> testRun (thenMisses 20 5) |> correctCount |> Expect.equal 20
            , test "twenty of twenty-five is not a failure" <|
                \_ -> testRun (thenMisses 20 5) |> isFailed |> Expect.equal False
            , test "twenty of twenty-five is finished" <|
                \_ -> testRun (thenMisses 20 5) |> isFinished |> Expect.equal True
            , test "a perfect run is not a failure" <|
                \_ -> testRun (thenMisses 25 0) |> isFailed |> Expect.equal False
            , test "a perfect run is finished" <|
                \_ -> testRun (thenMisses 25 0) |> isFinished |> Expect.equal True
            , test "answering every question is what ends a test" <|
                \_ -> testRun (thenMisses 24 1) |> answered |> Expect.equal 25
            ]
        , describe "the miss count matches the answers"
            [ test "counts only the wrong answers" <|
                \_ -> testRun (thenMisses 15 5) |> misses |> Expect.equal 5
            , test "counts only the right answers" <|
                \_ -> testRun (thenMisses 15 5) |> correctCount |> Expect.equal 15
            , test "right plus wrong is the questions answered" <|
                \_ ->
                    testRun (thenMisses 15 5)
                        |> (\m -> misses m + correctCount m)
                        |> Expect.equal 20
            , test "a run with no answers has no misses" <|
                \_ -> testRun [] |> misses |> Expect.equal 0
            ]
        , describe "nineteen correct and six wrong fails, not passes"
            {- Here "every question answered" and "failed" are both true, so the
               verdict has to come from the misses rather than the count answered.
            -}
            [ test "is a failure" <|
                \_ -> testRun (thenMisses 19 6) |> isFailed |> Expect.equal True
            , test "reports 19 correct" <|
                \_ -> testRun (thenMisses 19 6) |> correctCount |> Expect.equal 19
            , test "all 25 were answered" <|
                \_ -> testRun (thenMisses 19 6) |> answered |> Expect.equal 25
            , test "twenty correct with five misses is the pass mark" <|
                \_ -> testRun (thenMisses 20 5) |> correctCount |> Expect.equal 20
            ]
        , describe "practice has no pass mark"
            [ test "practice never fails, however many were missed" <|
                \_ ->
                    model Practice 25
                        |> withOutcomes (thenMisses 0 25)
                        |> isFailed
                        |> Expect.equal False
            , test "practice is not finished while questions remain" <|
                \_ ->
                    model Practice 25
                        |> withOutcomes (thenMisses 24 0)
                        |> isFinished
                        |> Expect.equal False
            , test "practice is finished once all 25 are answered" <|
                \_ ->
                    model Practice 25
                        |> withOutcomes (thenMisses 25 0)
                        |> isFinished
                        |> Expect.equal True
            , test "practice still counts its misses" <|
                \_ ->
                    model Practice 25
                        |> withOutcomes (thenMisses 0 25)
                        |> misses
                        |> Expect.equal 25
            , test "practice uses its own length" <|
                \_ ->
                    model Practice 10
                        |> withOutcomes (thenMisses 10 0)
                        |> isFinished
                        |> Expect.equal True
            ]
        , describe "the final question"
            [ test "one question left is the last" <|
                \_ -> testRun (thenMisses 24 0) |> isLast |> Expect.equal True
            , test "two questions left is not the last" <|
                \_ -> testRun (thenMisses 23 0) |> isLast |> Expect.equal False
            , test "nothing answered is not the last" <|
                \_ -> testRun [] |> isLast |> Expect.equal False
            , test "a run with no questions is not finished" <|
                \_ ->
                    model Test 0
                        |> withQuestions []
                        |> isFinished
                        |> Expect.equal False
            , test "a run with no questions is not the last" <|
                \_ ->
                    model Test 0
                        |> withQuestions []
                        |> isLast
                        |> Expect.equal False
            ]
        ]
