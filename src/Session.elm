module Session exposing
    ( Answer
    , Mode(..)
    , allowedMisses
    , correctCount
    , isFailed
    , isFinished
    , isLast
    , lengthOptions
    , missed
    , misses
    , sessionLength
    , testPassMark
    , testQuestionCount
    )

{-| The rules of a run: how long a session is, when a test is over, and
what counts as passing.

Answers are stored newest-first (consed on commit), so `missed` reverses
back to screen order for the review list. Everything else only counts,
so order never matters there.

The index of the question on screen is always the number of answers
committed so far — no separate counter to keep in sync.

Test mode is 25 questions with 20 required to pass, leaving 5 misses
available. A 6th wrong answer puts the pass mark out of reach, so the run
stops there.

-}

import Question exposing (Question)


type Mode
    = Practice
    | Test


testQuestionCount : Int
testQuestionCount =
    25


testPassMark : Int
testPassMark =
    20


allowedMisses : Int
allowedMisses =
    testQuestionCount - testPassMark


{-| A question that has been answered and committed. The chosen answer is
kept alongside the question so the results screen needs no other
bookkeeping.
-}
type alias Answer =
    { question : Question
    , chosen : Int
    }


sessionLength : { a | mode : Mode, practiceLength : Int } -> Int
sessionLength { mode, practiceLength } =
    case mode of
        Practice ->
            practiceLength

        Test ->
            testQuestionCount


isRight : Answer -> Bool
isRight answer =
    answer.chosen == answer.question.correct


wrongs : List Answer -> List Answer
wrongs answers =
    List.filter (not << isRight) answers


{-| The wrong answers, oldest first, for the review list.
-}
missed : { a | answers : List Answer } -> List Answer
missed { answers } =
    wrongs (List.reverse answers)


misses : { a | answers : List Answer } -> Int
misses { answers } =
    List.length (wrongs answers)


correctCount : { a | answers : List Answer } -> Int
correctCount { answers } =
    List.length (List.filter isRight answers)


{-| A test run can only fail by running out of room: past this many misses
the pass mark is unreachable, so the run stops instead of continuing.
-}
isFailed : { a | mode : Mode, answers : List Answer } -> Bool
isFailed { mode, answers } =
    mode == Test && List.length (wrongs answers) > allowedMisses


isFinished : { a | mode : Mode, questions : List Question, answers : List Answer } -> Bool
isFinished { mode, questions, answers } =
    not (List.isEmpty questions)
        && (List.length answers
                == List.length questions
                || isFailed { mode = mode, answers = answers }
           )


isLast : { a | questions : List Question, answers : List Answer } -> Bool
isLast { questions, answers } =
    List.length answers + 1 == List.length questions


lengthOptions : Int -> List Int
lengthOptions total =
    List.filter (\size -> size < total) [ 10, 25, 50, 100 ]
        ++ [ total ]
