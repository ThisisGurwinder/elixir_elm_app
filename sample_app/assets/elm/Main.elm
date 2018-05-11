module Main exposing (main)

import Debug
import Html exposing (..)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onWithOptions)
import Http
import Json.Decode as Decode exposing (Decoder, at, int, list, string)
import Json.Decode.Pipeline exposing (decode, required)
import Navigation
import UrlParser


type alias Student =
    { name : String
    , age : Int
    , subject : String
    , classification : String
    }


type Route
    = HomeRoute
    | AboutRoute
    | NotFoundRoute


matchers : UrlParser.Parser (Route -> a) a
matchers =
    UrlParser.oneOf
        [ UrlParser.map HomeRoute UrlParser.top
        , UrlParser.map AboutRoute (UrlParser.s "about")
        ]


type alias Model =
    { students : List Student
    , route : Route
    , changes : Int
    }


type Msg
    = StudentData (Result Http.Error (List Student))
    | ChangeLocation String
    | OnLocationChange Navigation.Location


initialModel : Route -> Model
initialModel route =
    { students =
        [ { name = ""
          , age = 0
          , subject = ""
          , classification = ""
          }
        ]
    , route = route
    , changes = 0
    }


studentDecoder : Decoder Student
studentDecoder =
    decode Student
        |> required "name" string
        |> required "age" int
        |> required "subject" string
        |> required "classification" string


decodeList : Decoder (List Student)
decodeList =
    list studentDecoder


decoder : Decoder (List Student)
decoder =
    at [ "data" ] decodeList


initialCmd : Cmd Msg
initialCmd =
    decoder
        |> Http.get "http://localhost:4000/students"
        |> Http.send StudentData


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        currentRoute =
            parseLocation location
    in
    ( initialModel currentRoute, Cmd.none )


viewStudent : Student -> Html Msg
viewStudent student =
    tr []
        [ td [] [ text (student.name ++ " (" ++ toString student.age ++ ")") ]
        , td [] [ text student.subject ]
        , td [] [ text student.classification ]
        ]


view : Model -> Html Msg
view model =
    div [] [ nav model, page model, viewBody model ]


nav : Model -> Html Msg
nav model =
    div []
        [ a [ href homePath, onLinkClick (ChangeLocation homePath) ] [ text "Home" ]
        , text " "
        , a [ href aboutPath, onLinkClick (ChangeLocation aboutPath) ] [ text "About" ]
        , text (" " ++ toString model.changes)
        ]


page : Model -> Html Msg
page model =
    case model.route of
        HomeRoute ->
            text "Home"

        AboutRoute ->
            text "About"

        NotFoundRoute ->
            text "Not Found"


viewBody : Model -> Html Msg
viewBody model =
    div []
        [ h1 [] [ text "Enrolled Students" ]
        , table [ class "table" ]
            [ thead []
                [ tr []
                    [ th [] [ text "Name (Age)" ]
                    , th [] [ text "Course" ]
                    , th [] [ text "Type" ]
                    ]
                ]
            , tbody [] (List.map viewStudent model.students)
            ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StudentData (Ok students) ->
            ( { model | students = students }, Cmd.none )

        StudentData (Err _) ->
            ( model, Cmd.none )

        ChangeLocation path ->
            let
                updatedCmd =
                    case path of
                        "/about" ->
                            Http.send StudentData (Http.get "localhost:4000/about" decodeUrl)

                        _ ->
                            Cmd.none
            in
            ( { model | changes = model.changes + 1 }, Cmd.batch [ Navigation.newUrl path, updatedCmd ] )

        OnLocationChange location ->
            let
                newRoute =
                    parseLocation location
            in
            ( { model | route = newRoute }, Cmd.none )


parseLocation : Navigation.Location -> Route
parseLocation location =
    case UrlParser.parsePath matchers location of
        Just route ->
            route

        Nothing ->
            NotFoundRoute


homePath =
    "/"


aboutPath =
    "/about"


onLinkClick : msg -> Attribute msg
onLinkClick message =
    let
        options =
            { stopPropagation = False
            , preventDefault = True
            }
    in
    onWithOptions "click" options (Decode.succeed message)


main : Program Never Model Msg
main =
    Navigation.program OnLocationChange
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }
