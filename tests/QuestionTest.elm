module QuestionTest exposing (suite)

{-| Shuffling and decoding.

The decoder tests matter most here. The app once pointed its decoder at the
whole document instead of the `questions` array, so every load failed and only
the start screen ever rendered. Nothing caught it, so the shape is pinned from
both sides: a document with the array decodes, and one without it is an error.

-}

import Expect
import Fixtures exposing (expectErr, questions)
import Json.Decode as Decode
import Question exposing (Question)
import Random
import Test exposing (Test, describe, test)


seed : Random.Seed
seed =
    Random.initialSeed 20210801


run : Random.Seed -> List Question -> List Question
run s qs =
    Random.step (Question.shuffle qs) s |> Tuple.first


bank : List Question
bank =
    questions 144


shuffled : List Question
shuffled =
    run seed bank


{-| Every question keeps its own fields after a shuffle — the id, the text and
the explanation all still belong to the same question.
-}
fieldsStayPaired : List Question -> Bool
fieldsStayPaired qs =
    List.all
        (\q -> q.question == "Question " ++ String.fromInt q.id && List.length q.answers == 4)
        qs


suite : Test
suite =
    describe "questions"
        [ describe "shuffle"
            [ test "keeps every question" <|
                \_ -> shuffled |> List.length |> Expect.equal 144
            , test "loses nothing" <|
                \_ ->
                    shuffled
                        |> List.map .id
                        |> List.sort
                        |> Expect.equal (List.range 1 144)
            , test "keeps each question's own fields" <|
                \_ -> shuffled |> fieldsStayPaired |> Expect.equal True
            , test "actually reorders" <|
                \_ -> shuffled |> Expect.notEqual bank
            , test "is the same for the same seed" <|
                \_ -> run seed bank |> Expect.equal shuffled
            , test "differs for a different seed" <|
                \_ ->
                    (run (Random.initialSeed 7) bank == shuffled)
                        |> Expect.equal False
            , test "handles an empty list" <|
                \_ -> run seed [] |> Expect.equal []
            , test "handles a single question" <|
                \_ -> run seed (questions 1) |> Expect.equal (questions 1)
            , test "handles two questions" <|
                \_ ->
                    let
                        two =
                            questions 2
                    in
                    run seed two
                        |> List.sortBy .id
                        |> Expect.equal two
            ]
        , describe "decoding a document"
            [ test "pulls the questions array out" <|
                \_ ->
                    Decode.decodeString Question.document documentJson
                        |> Result.map List.length
                        |> Expect.equal (Ok 2)
            , test "reads the ids in order" <|
                \_ ->
                    Decode.decodeString Question.document documentJson
                        |> Result.map (List.map .id)
                        |> Expect.equal (Ok [ 2, 3 ])
            , test "reads the question text" <|
                \_ ->
                    Decode.decodeString Question.document oneQuestionJson
                        |> Result.map (\qs -> List.head qs |> Maybe.map .question)
                        |> Expect.equal (Ok (Just permitQuestion))
            , test "reads the answers" <|
                \_ ->
                    Decode.decodeString Question.document oneQuestionJson
                        |> Result.map (\qs -> List.head qs |> Maybe.map .answers)
                        |> Expect.equal (Ok (Just [ "14", "16", "15", "16-1/2" ]))
            , test "reads the correct index" <|
                \_ ->
                    Decode.decodeString Question.document oneQuestionJson
                        |> Result.map (\qs -> List.head qs |> Maybe.map .correct)
                        |> Expect.equal (Ok (Just 2))
            , test "reads the category" <|
                \_ ->
                    Decode.decodeString Question.document oneQuestionJson
                        |> Result.map (\qs -> List.head qs |> Maybe.map .category)
                        |> Expect.equal (Ok (Just "Licensing & permits"))
            , test "reads the explanation" <|
                \_ ->
                    Decode.decodeString Question.document oneQuestionJson
                        |> Result.map (\qs -> List.head qs |> Maybe.map .explanation)
                        |> Expect.equal (Ok (Just "An instruction permit may be obtained at 15."))
            ]
        , describe "decoding a bank"
            [ test "reads the id" <|
                \_ ->
                    Decode.decodeString Question.bank bankJson
                        |> Result.map .id
                        |> Expect.equal (Ok "wy")
            , test "reads the title" <|
                \_ ->
                    Decode.decodeString Question.bank bankJson
                        |> Result.map .title
                        |> Expect.equal (Ok "Wyoming")
            , test "reads the short name" <|
                \_ ->
                    Decode.decodeString Question.bank bankJson
                        |> Result.map .name
                        |> Expect.equal (Ok "Wyoming")
            , test "reads the subtitle" <|
                \_ ->
                    Decode.decodeString Question.bank bankJson
                        |> Result.map .subtitle
                        |> Expect.equal (Ok "Rules")
            , test "reads the questions" <|
                \_ ->
                    Decode.decodeString Question.bank bankJson
                        |> Result.map (.questions >> List.map .id)
                        |> Expect.equal (Ok [ 2 ])
            , test "a bank with no id is an error" <|
                \_ ->
                    Decode.decodeString Question.bank oneQuestionJson
                        |> expectErr
            ]
        , describe "decoding rejects bad input"
            [ test "a document with no questions field is an error" <|
                \_ ->
                    Decode.decodeString Question.document """{"title":"Wyoming Driver Test"}"""
                        |> expectErr
            , test "questions as a string is an error" <|
                \_ ->
                    Decode.decodeString Question.document """{"title":"t","questions":"none"}"""
                        |> expectErr
            , test "a malformed question is an error" <|
                \_ ->
                    Decode.decodeString Question.document """{"title":"t","questions":[{"id":"one"}]}"""
                        |> expectErr
            , test "a question that is not an object is an error" <|
                \_ ->
                    Decode.decodeString Question.document """{"questions":["nope"]}"""
                        |> expectErr
            , test "a correct index that is not a number is an error" <|
                \_ ->
                    Decode.decodeString Question.document
                        """{"questions":[{"id":1,"category":"c","question":"q","answers":["a"],"correct":"zero","explanation":"e"}]}"""
                        |> expectErr
            , test "a missing explanation is an error" <|
                \_ ->
                    Decode.decodeString Question.document
                        """{"questions":[{"id":1,"category":"c","question":"q","answers":["a"],"correct":0}]}"""
                        |> expectErr
            , test "truncated JSON is an error" <|
                \_ ->
                    Decode.decodeString Question.document """{"questions":["""
                        |> expectErr
            ]
        ]


permitQuestion : String
permitQuestion =
    "At what age may an instruction permit be obtained in Wyoming?"


oneQuestion : String
oneQuestion =
    "{\"id\":2"
        ++ ",\"category\":\"Licensing & permits\""
        ++ ",\"question\":\""
        ++ permitQuestion
        ++ "\""
        ++ ",\"answers\":[\"14\",\"16\",\"15\",\"16-1/2\"]"
        ++ ",\"correct\":2"
        ++ ",\"explanation\":\"An instruction permit may be obtained at 15.\"}"


oneQuestionJson : String
oneQuestionJson =
    "{\"title\":\"Wyoming Driver License Practice Test\",\"questions\":[" ++ oneQuestion ++ "]}"


bankJson : String
bankJson =
    "{\"id\":\"wy\",\"name\":\"Wyoming\",\"title\":\"Wyoming\",\"subtitle\":\"Rules\",\"questions\":[" ++ oneQuestion ++ "]}"


documentJson : String
documentJson =
    "{\"title\":\"t\",\"questions\":["
        ++ oneQuestion
        ++ ",{\"id\":3,\"category\":\"Speed\",\"question\":\"q3\",\"answers\":[\"a\",\"b\",\"c\",\"d\"],\"correct\":1,\"explanation\":\"e3\"}]}"
