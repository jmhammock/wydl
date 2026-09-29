module Question exposing (Question, document, shuffle)

{-| A single practice-test question, exactly as it appears in questions.json.

This module only knows _what_ a question is. It has no opinion on how questions
are displayed, scored, or ordered by the app.

-}

import Json.Decode as Decode
import Random exposing (Generator)



-- QUESTION


type alias Question =
    { id : Int
    , category : String
    , question : String
    , answers : List String
    , correct : Int
    , explanation : String
    }


decoder : Decode.Decoder Question
decoder =
    Decode.map6 Question
        (Decode.field "id" Decode.int)
        (Decode.field "category" Decode.string)
        (Decode.field "question" Decode.string)
        (Decode.field "answers" (Decode.list Decode.string))
        (Decode.field "correct" Decode.int)
        (Decode.field "explanation" Decode.string)


{-| questions.json is a document with a title and a `questions` array. This
pulls the array out of it, so the file's shape is known in exactly one place.
-}
document : Decode.Decoder (List Question)
document =
    Decode.field "questions" (Decode.list decoder)



-- SHUFFLE


{-| Randomise the questions so each session starts somewhere different
instead of always drilling the same first handful.

Pairs every question with a random key and sorts by that key. Kept as a
`Generator` so the caller never threads a seed by hand.

-}
shuffle : List a -> Generator (List a)
shuffle items =
    Random.list (List.length items) (Random.float 0 1)
        |> Random.map (tagged items)


tagged : List a -> List Float -> List a
tagged items keys =
    List.map2 Tuple.pair items keys
        |> List.sortBy Tuple.second
        |> List.map Tuple.first
