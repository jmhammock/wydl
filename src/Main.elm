port module Main exposing (Model, Msg(..), Status(..), init, main, selectedBank, update)

{-| A single-session practice or test run.

The whole app is one loop: load the question banks found under `banks/`,
pick a bank and a mode, answer one at a time, then show the score. The rules
of a run live in `Session`; this module only wires loading, randomness, and
rendering around them.

Which banks exist is discovered at build time (`scripts/gen-banks.js`
writes `src/Banks.elm`), so adding a state is just adding a bank file.
Answers accumulate newest-first. The question on screen is the one at index
"number of answers so far", so there is no separate counter to keep in sync.

-}

import Banks
import Browser
import Html exposing (..)
import Html.Attributes exposing (attribute, class, disabled, href, rel, selected, target, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Question exposing (Bank, Question)
import Random
import Session
    exposing
        ( Answer
        , Mode(..)
        , allowedMisses
        , correctCount
        , isFailed
        , isFinished
        , isLast
        , lengthOptions
        , missed
        , sessionLength
        , testPassMark
        , testQuestionCount
        )



-- MODEL


type Status
    = Loading
    | Ready
    | Failed String


practiceDefaultLength : Int
practiceDefaultLength =
    25


type alias Model =
    { status : Status
    , selected : String
    , mode : Mode
    , banks : List Bank
    , questions : List Question
    , answers : List Answer
    , chosen : Maybe Int
    , practiceLength : Int
    , exitArmed : Bool
    , shareState : String
    }


{-| Payload for the `requestShare` port. Kept as plain strings so Elm can
encode it as JSON with no extra packages; `app.js` draws the share image.
-}
type alias SharePayload =
    { title : String
    , score : String
    , sub : String
    }


port requestShare : SharePayload -> Cmd msg


port shareStatus : (String -> msg) -> Sub msg


init : () -> ( Model, Cmd Msg )
init _ =
    ( { status = Loading
      , selected = Banks.default
      , mode = Practice
      , banks = []
      , questions = []
      , answers = []
      , chosen = Nothing
      , practiceLength = practiceDefaultLength
      , exitArmed = False
      , shareState = ""
      }
    , Cmd.batch (List.map fetchBank Banks.ids)
    )


fetchBank : String -> Cmd Msg
fetchBank id =
    Http.get
        { url = "banks/" ++ id ++ ".json"
        , expect = Http.expectJson GotBank Question.bank
        }



-- UPDATE


type Msg
    = GotBank (Result Http.Error Bank)
    | GotShuffled (List Question)
    | SelectBank String
    | SetMode Mode
    | SetLength Int
    | Start
    | Choose Int
    | Next
    | ArmExit
    | CancelExit
    | ExitToStart
    | ShareResults
    | GotShareStatus String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotBank (Ok bank) ->
            let
                banks =
                    bank :: List.filter (\b -> b.id /= bank.id) model.banks
            in
            ( { model | banks = banks, status = bankStatus banks }, Cmd.none )

        GotBank (Err problem) ->
            ( { model | status = Failed (describeError problem) }, Cmd.none )

        SelectBank id ->
            ( { model | selected = id }, Cmd.none )

        SetMode mode ->
            ( { model | mode = mode }, Cmd.none )

        SetLength n ->
            ( { model | practiceLength = n }, Cmd.none )

        Start ->
            case selectedBank model of
                Nothing ->
                    ( model, Cmd.none )

                Just bank ->
                    ( { model | answers = [], chosen = Nothing, questions = [], shareState = "" }
                    , Random.generate GotShuffled
                        (Question.shuffle bank.questions
                            |> Random.map (List.take (sessionLength model))
                        )
                    )

        GotShuffled questions ->
            ( { model | questions = questions }, Cmd.none )

        Choose i ->
            if model.chosen == Nothing then
                ( { model | chosen = Just i }, Cmd.none )

            else
                ( model, Cmd.none )

        Next ->
            case ( model.chosen, currentQuestion model ) of
                ( Just i, Just q ) ->
                    ( { model | answers = Answer q i :: model.answers, chosen = Nothing, exitArmed = False }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ArmExit ->
            ( { model | exitArmed = True }, Cmd.none )

        CancelExit ->
            ( { model | exitArmed = False }, Cmd.none )

        ExitToStart ->
            ( { model | questions = [], answers = [], chosen = Nothing, exitArmed = False, shareState = "" }
            , Cmd.none
            )

        ShareResults ->
            ( { model | shareState = "Preparing…" }
            , requestShare (sharePayload model)
            )

        GotShareStatus state ->
            ( { model | shareState = state }, Cmd.none )



-- VIEW


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> shareStatus GotShareStatus
        }


view : Model -> Html Msg
view model =
    case model.status of
        Loading ->
            p [ class "hint" ] [ text "Loading questions…" ]

        Failed problem ->
            div [ class "card" ]
                [ h1 [] [ text "Could not load questions" ]
                , p []
                    [ text "The file banks/wy.json could not be read. It must sit in the same folder as index.html." ]
                , pre [ class "error" ] [ text problem ]
                , p [ class "hint" ]
                    [ text "This app has to be served over HTTP, not opened straight from disk. Serving the folder is enough — no backend is needed." ]
                ]

        Ready ->
            if isFinished model then
                viewResults model

            else
                case currentQuestion model of
                    Just q ->
                        viewQuestion model q

                    Nothing ->
                        viewStart model


viewStart : Model -> Html Msg
viewStart model =
    case selectedBank model of
        Nothing ->
            p [ class "hint" ] [ text "Loading questions…" ]

        Just bank ->
            viewReadyStart model bank


viewFooter : Html Msg
viewFooter =
    footer [ class "site-footer" ]
        [ p [ class "footer-text" ]
            [ text "Study aid — not affiliated with any DMV. Questions drawn from official state driver manuals." ]
        , p [ class "free-note" ]
            [ text "This tool is free to use. If it helped you, consider buying me a coffee." ]
        , div [ class "coffee-wrap", attribute "data-bmc-slot" "jhammock" ]
            [ a
                [ class "coffee-btn"
                , href "https://www.buymeacoffee.com/jhammock"
                , target "_blank"
                , rel "noopener"
                ]
                [ text "Buy me a coffee" ]
            ]
        ]


viewReadyStart : Model -> Bank -> Html Msg
viewReadyStart model bank =
    let
        total =
            List.length bank.questions
    in
    div []
        [ div [ class "card" ]
            [ h1 [] [ text bank.title ]
            , p [ class "sub" ] [ text bank.subtitle ]
            , fieldset [ class "lengths" ]
                [ legend [] [ text "State" ]
                , select [ class "state-select", onInput SelectBank ]
                    (List.map (viewBankOption model.selected) (List.sortBy .name model.banks))
                ]
            , fieldset [ class "lengths" ]
                [ legend [] [ text "Mode" ]
                , div [ class "length-row" ]
                    [ viewMode model.mode Practice "Practice"
                    , viewMode model.mode Test "Test"
                    ]
                ]
            , case model.mode of
                Practice ->
                    fieldset [ class "lengths" ]
                        [ legend [] [ text "Questions per session" ]
                        , div [ class "length-row" ]
                            (List.map (viewLength total model.practiceLength) (lengthOptions total))
                        ]

                Test ->
                    p [ class "test-note" ]
                        [ text
                            (String.fromInt testQuestionCount
                                ++ " questions. You need "
                                ++ String.fromInt testPassMark
                                ++ " correct to pass, and the test ends as soon as "
                                ++ String.fromInt (allowedMisses + 1)
                                ++ " answers are wrong."
                            )
                        ]
            , button [ class "btn", type_ "button", onClick Start ]
                [ text
                    (case model.mode of
                        Practice ->
                            "Start"

                        Test ->
                            "Begin test"
                    )
                ]
            ]
        , viewFooter
        ]


viewMode : Mode -> Mode -> String -> Html Msg
viewMode selected mode label =
    viewToggle label (mode == selected) (SetMode mode)


viewBankOption : String -> Bank -> Html Msg
viewBankOption current bank =
    option [ value bank.id, selected (bank.id == current) ] [ text bank.name ]


viewLength : Int -> Int -> Int -> Html Msg
viewLength total selected n =
    viewToggle (lengthLabel total n) (n == selected) (SetLength n)


viewToggle : String -> Bool -> Msg -> Html Msg
viewToggle label selected msg =
    button
        [ class
            (if selected then
                "length length-on"

             else
                "length"
            )
        , type_ "button"
        , onClick msg
        ]
        [ text label ]


lengthLabel : Int -> Int -> String
lengthLabel total n =
    if n == total then
        "All"

    else
        String.fromInt n


viewExit : Model -> Html Msg
viewExit model =
    if model.exitArmed then
        div [ class "exit-confirm" ]
            [ p [] [ text "Your progress will be lost." ]
            , div [ class "exit-actions" ]
                [ button [ class "btn-quiet", type_ "button", onClick CancelExit ]
                    [ text "Keep going" ]
                , button [ class "btn-danger", type_ "button", onClick ExitToStart ]
                    [ text ("Yes, leave the " ++ modeNoun model.mode) ]
                ]
            ]

    else
        button [ class "exit", type_ "button", onClick ArmExit ]
            [ text ("Leave the " ++ modeNoun model.mode) ]


modeNoun : Mode -> String
modeNoun mode =
    case mode of
        Practice ->
            "practice session"

        Test ->
            "test"


viewQuestion : Model -> Question -> Html Msg
viewQuestion model q =
    let
        number =
            List.length model.answers + 1

        total =
            List.length model.questions
    in
    div []
        [ viewExit model
        , div [ class "progress" ]
            [ p [ class "count" ]
                [ text ("Question " ++ String.fromInt number ++ " of " ++ String.fromInt total) ]
            , progress
                [ class "bar"
                , value (String.fromInt number)
                , Html.Attributes.max (String.fromInt total)
                ]
                []
            ]
        , div [ class "card" ]
            [ p [ class "cat" ] [ text q.category ]
            , h1 [ class "q" ] [ text q.question ]
            , div [ class "options" ]
                (List.indexedMap (viewOption q.correct model.chosen) q.answers)
            , viewFeedback (isLast model) q model.chosen
            ]
        ]


viewOption : Int -> Maybe Int -> Int -> String -> Html Msg
viewOption correct chosen index label =
    let
        revealed =
            chosen /= Nothing

        className =
            if not revealed then
                "option"

            else if index == correct then
                "option option-right"

            else if chosen == Just index then
                "option option-wrong"

            else
                "option option-faded"
    in
    button
        [ class className, type_ "button", disabled revealed, onClick (Choose index) ]
        [ span [ class "letter", attribute "aria-hidden" "true" ] [ text (letter index) ]
        , span [ class "option-text" ] [ text label ]
        ]


viewFeedback : Bool -> Question -> Maybe Int -> Html Msg
viewFeedback last q chosen =
    case chosen of
        Nothing ->
            p [ class "hint" ] [ text "Pick an answer to see how it compares." ]

        Just picked ->
            let
                right =
                    picked == q.correct

                correctLine =
                    if right then
                        []

                    else
                        [ p []
                            [ strong [] [ text "Correct answer: " ]
                            , text (nthOr "" q.correct q.answers)
                            ]
                        ]
            in
            div [ class (feedbackClass right) ]
                ([ p [ class "verdict" ] [ text (verdict right) ] ]
                    ++ correctLine
                    ++ [ p [ class "why" ] [ text q.explanation ]
                       , button [ class "btn", type_ "button", onClick Next ]
                            [ text
                                (if last then
                                    "See results"

                                 else
                                    "Next"
                                )
                            ]
                       ]
                )


feedbackClass : Bool -> String
feedbackClass right =
    if right then
        "feedback feedback-right"

    else
        "feedback feedback-wrong"


verdict : Bool -> String
verdict right =
    if right then
        "Correct."

    else
        "Not quite."


viewResults : Model -> Html Msg
viewResults model =
    div []
        [ case model.mode of
            Practice ->
                viewPracticeResult model

            Test ->
                viewTestResult model
        , viewReview model
        , viewFooter
        ]


viewPracticeResult : Model -> Html Msg
viewPracticeResult model =
    let
        total =
            List.length model.answers

        correct =
            correctCount model

        percent =
            if total == 0 then
                0

            else
                round (toFloat correct / toFloat total * 100)
    in
    div [ class "card" ]
        [ h1 [] [ text "Session complete" ]
        , p [ class "score" ]
            [ text (String.fromInt percent ++ "%") ]
        , p [ class "sub" ]
            [ text (String.fromInt correct ++ " of " ++ String.fromInt total ++ " correct") ]
        , viewShareRow model "Start a new session"
        ]


viewTestResult : Model -> Html Msg
viewTestResult model =
    let
        correct =
            correctCount model

        failed =
            isFailed model
    in
    div [ class "card" ]
        [ h1 [ class (resultClass failed) ]
            [ text
                (if failed then
                    "Not passed"

                 else
                    "Passed"
                )
            ]
        , p [ class "score" ]
            [ text (String.fromInt correct ++ " / " ++ String.fromInt testQuestionCount) ]
        , if failed then
            p [ class "sub" ]
                [ text
                    ("You needed "
                        ++ String.fromInt testPassMark
                        ++ " of "
                        ++ String.fromInt testQuestionCount
                        ++ " correct. After "
                        ++ String.fromInt (allowedMisses + 1)
                        ++ " wrong answers that was out of reach, so the test stopped at question "
                        ++ String.fromInt (List.length model.answers)
                        ++ "."
                    )
                ]

          else
            p [ class "sub" ]
                [ text
                    (String.fromInt correct
                        ++ " of "
                        ++ String.fromInt testQuestionCount
                        ++ " correct. You needed "
                        ++ String.fromInt testPassMark
                        ++ "."
                    )
                ]
        , viewShareRow model "Take the test again"
        ]


{-| Text for the share image, drawn by `app.js` from this payload.
-}
sharePayload : Model -> SharePayload
sharePayload model =
    case model.mode of
        Practice ->
            let
                total =
                    List.length model.answers

                correct =
                    correctCount model

                percent =
                    if total == 0 then
                        0

                    else
                        round (toFloat correct / toFloat total * 100)
            in
            { title = "Driver Test"
            , score = String.fromInt percent ++ "%"
            , sub = String.fromInt correct ++ " of " ++ String.fromInt total ++ " correct"
            }

        Test ->
            { title = "Driver Test"
            , score = String.fromInt (correctCount model) ++ " / " ++ String.fromInt testQuestionCount
            , sub =
                if isFailed model then
                    "Not passed"

                else
                    "Passed"
            }


viewShareRow : Model -> String -> Html Msg
viewShareRow model restartLabel =
    div []
        [ div [ class "share-row" ]
            [ button [ class "btn", type_ "button", onClick ExitToStart ]
                [ text restartLabel ]
            , button [ class "btn-secondary", type_ "button", onClick ShareResults ]
                [ text "Share results" ]
            ]
        , viewShareStatus model
        ]


viewShareStatus : Model -> Html Msg
viewShareStatus model =
    if model.shareState == "" then
        text ""

    else
        p [ class "hint" ] [ text model.shareState ]


resultClass : Bool -> String
resultClass failed =
    if failed then
        "result-fail"

    else
        "result-pass"


viewReview : Model -> Html Msg
viewReview model =
    case missed model of
        [] ->
            p [ class "hint perfect" ]
                [ text
                    (if model.mode == Test then
                        "Nothing missed."

                     else
                        "Nothing missed. Come back later and try a longer session."
                    )
                ]

        wrong ->
            section [ class "review" ]
                [ h2 []
                    [ text ("Review — " ++ String.fromInt (List.length wrong) ++ " missed") ]
                , div [] (List.map viewMissed wrong)
                ]


viewMissed : Answer -> Html Msg
viewMissed answer =
    let
        q =
            answer.question
    in
    details [ class "miss" ]
        [ summary [] [ text q.question ]
        , p [ class "cat" ] [ text q.category ]
        , p []
            [ strong [] [ text "Correct answer: " ]
            , text (nthOr "" q.correct q.answers)
            ]
        , p []
            [ text ("You chose: " ++ nthOr "" answer.chosen q.answers) ]
        , p [ class "why" ] [ text q.explanation ]
        ]



-- HELPERS


currentQuestion : Model -> Maybe Question
currentQuestion model =
    nth (List.length model.answers) model.questions


{-| The selected bank, once it has loaded.
-}
selectedBank : Model -> Maybe Bank
selectedBank model =
    List.head (List.filter (\b -> b.id == model.selected) model.banks)


{-| Ready once every bank in `Banks.ids` has loaded.
-}
bankStatus : List Bank -> Status
bankStatus banks =
    if List.length banks == List.length Banks.ids then
        Ready

    else
        Loading


describeError : Http.Error -> String
describeError problem =
    case problem of
        Http.BadUrl url ->
            "The request URL was rejected: " ++ url

        Http.Timeout ->
            "The request timed out."

        Http.NetworkError ->
            "The network failed. The bank file has to be served over HTTP, not opened from disk."

        Http.BadStatus code ->
            "The server answered " ++ String.fromInt code ++ "."

        Http.BadBody reason ->
            "The bank file is not in the shape the app expects: " ++ reason


nth : Int -> List a -> Maybe a
nth i xs =
    List.head (List.drop i xs)


nthOr : a -> Int -> List a -> a
nthOr fallback i xs =
    Maybe.withDefault fallback (nth i xs)


letter : Int -> String
letter index =
    case index of
        0 ->
            "A"

        1 ->
            "B"

        2 ->
            "C"

        3 ->
            "D"

        _ ->
            "?"
