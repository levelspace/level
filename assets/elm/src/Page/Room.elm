module Page.Room exposing (Model, Msg, fetchRoom, buildModel, loaded, view, update)

{-| Viewing an particular room.
-}

import Task exposing (Task)
import Http
import Json.Decode as Json
import Html exposing (..)
import Html.Events exposing (on, onWithOptions, defaultOptions, onInput, onClick, keyCode)
import Html.Attributes exposing (..)
import Dom exposing (focus)
import Dom.Scroll exposing (toBottom)
import Date
import Time exposing (Time)
import Data.User exposing (User)
import Data.Room exposing (Room, RoomMessageConnection, RoomMessageEdge, RoomMessage)
import Data.Session exposing (Session)
import Query.Room
import Mutation.CreateRoomMessage as CreateRoomMessage


-- MODEL


type alias Model =
    { room : Room
    , messages : RoomMessageConnection
    , composerBody : String
    , isSubmittingMessage : Bool
    }


{-| Builds a Task to fetch a room by slug.
-}
fetchRoom : Session -> String -> Task Http.Error Query.Room.Response
fetchRoom session slug =
    Query.Room.request session.apiToken (Query.Room.Params slug)
        |> Http.toTask


{-| Builds a model for this page based on the response from initial page request.
-}
buildModel : Query.Room.Data -> Model
buildModel data =
    Model data.room data.messages "" False


{-| Builds the task to perform post-page load.
-}
loaded : Cmd Msg
loaded =
    Cmd.batch [ scrollToBottom, focusOnComposer ]



-- UPDATE


type Msg
    = ComposerBodyChanged String
    | MessageSubmitted
    | MessageSubmitResponse (Result Http.Error RoomMessage)
    | NoOp


update : Msg -> Session -> Model -> ( Model, Cmd Msg )
update msg session model =
    case msg of
        ComposerBodyChanged newBody ->
            ( { model | composerBody = newBody }, Cmd.none )

        MessageSubmitted ->
            let
                params =
                    CreateRoomMessage.Params model.room model.composerBody

                request =
                    CreateRoomMessage.request session.apiToken params
            in
                ( { model | isSubmittingMessage = True }
                , Http.send MessageSubmitResponse request
                )

        MessageSubmitResponse (Ok message) ->
            let
                newMessages =
                    RoomMessageConnection (RoomMessageEdge message :: model.messages.edges)
            in
                ( { model
                    | isSubmittingMessage = False
                    , composerBody = ""
                    , messages = newMessages
                  }
                , scrollToBottom
                )

        MessageSubmitResponse (Err _) ->
            -- TODO: implement this
            ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


{-| Scroll the messages container to the most recent message.
-}
scrollToBottom : Cmd Msg
scrollToBottom =
    Task.attempt (always NoOp) <| toBottom "messages"


{-| Set focus to the composer body textarea.
-}
focusOnComposer : Cmd Msg
focusOnComposer =
    Task.attempt (always NoOp) <| focus "composer-body-field"



-- VIEW


onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Json.succeed msg
            else
                Json.fail "not ENTER"
    in
        onWithOptions "keydown" { defaultOptions | preventDefault = True } (Json.andThen isEnter keyCode)


view : Model -> Html Msg
view model =
    div [ id "main", class "main main--room" ]
        [ div [ class "page-head" ]
            [ h2 [ class "page-head__name" ] [ text model.room.name ]
            , p [ class "page-head__description" ] [ text model.room.description ]
            ]
        , renderMessages model.messages
        , div [ class "composer" ]
            [ div [ class "composer__body" ]
                [ textarea
                    [ id "composer-body-field"
                    , class "text-field text-field--muted textarea composer__body-field"
                    , onInput ComposerBodyChanged
                    , onEnter MessageSubmitted
                    , readonly (isComposerReadOnly model)
                    , value model.composerBody
                    ]
                    []
                ]
            , div [ class "composer__controls" ]
                [ button
                    [ class "button button--primary"
                    , disabled (isSendDisabled model)
                    , onClick MessageSubmitted
                    ]
                    [ text "Send Message" ]
                ]
            ]
        ]


renderMessages : RoomMessageConnection -> Html Msg
renderMessages connection =
    div [ id "messages", class "messages" ] (List.map renderMessage (List.reverse connection.edges))


renderMessage : RoomMessageEdge -> Html Msg
renderMessage edge =
    div [ class "message" ]
        [ div [ class "message__avatar" ] []
        , div [ class "message__contents" ]
            [ div [ class "message__head" ]
                [ span [ class "message__name" ] [ text (Data.User.displayName edge.node.user) ]
                , span [ class "message__middot" ] [ text "·" ]
                , span [ class "message__timestamp" ] [ text (formatTime edge.node.insertedAt) ]
                ]
            , div [ class "message__body" ] [ text edge.node.body ]
            ]
        ]


{-| Determines if the "Send Message" button should be disabled.

    isSendDisabled { composerBody = "" } == True
    isSendDisabled { composerBody = "I have some text" } == False
    isSendDisabled { isSubmittingMessage = True } == False

-}
isSendDisabled : Model -> Bool
isSendDisabled model =
    model.composerBody == "" || (isComposerReadOnly model)


{-| Determines if the composer textarea should be read-only.

    isSendDisabled { composerBody = "" } == True
    isSendDisabled { composerBody = "I have some text" } == False
    isSendDisabled { isSubmittingMessage = True } == False

-}
isComposerReadOnly : Model -> Bool
isComposerReadOnly model =
    model.isSubmittingMessage == True


{-| Converts a Time into a human-friendly time string.

    isSendDisabled 1510444158581 == "11:10am"

-}
formatTime : Time -> String
formatTime time =
    let
        date =
            Date.fromTime time

        hour =
            Date.hour date

        minute =
            Date.minute date
                |> toString
                |> formatMinute

        hourString =
            if hour == 0 then
                "12"
            else
                toString <| hour % 12

        meridian =
            if hour < 12 then
                "am"
            else
                "pm"
    in
        hourString ++ ":" ++ minute ++ meridian


formatMinute : String -> String
formatMinute value =
    if String.length value == 1 then
        "0" ++ value
    else
        value
