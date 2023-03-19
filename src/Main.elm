port module Main exposing (..)

import Utils.List
import Utils.Events exposing (..)

import Browser

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Events as Events

import Html exposing (Html)
import Html.Attributes exposing (style)

import Html5.DragDrop as DnD

import Json.Decode exposing (Value)      
import Element.Region exposing (description)


-- MAIN

port dragstart : Value -> Cmd msg


main : Program () Model Msg
main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view }


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
  Sub.none      


-- MODEL


type Flower
  = Atom String
  | Flower Garden (List Garden)

type alias Bouquet
  = List Flower

type Garden
  = Garden Bouquet


type Zip
  = Bouquet Bouquet Bouquet
  | Pistil (List Garden)
  | Petal Garden (List Garden) (List Garden)

type alias Zipper
  = List Zip

-- We encode zippers as lists, where the head is the innermost context


fillZip : Zip -> Bouquet -> Bouquet
fillZip zip bouquet =
  case zip of
    Bouquet left right ->
      left ++ bouquet ++ right

    Pistil petals ->
      [Flower (Garden bouquet) petals]

    Petal pistil leftPetals rightPetals ->
      [Flower pistil (leftPetals ++ Garden bouquet :: rightPetals)]


fillZipper : Bouquet -> Zipper -> Bouquet
fillZipper =
  List.foldl fillZip


hypsZip : Zip -> Bouquet
hypsZip zip =
  case zip of
    Bouquet left right ->
      left ++ right

    Pistil _ ->
      []
    
    Petal (Garden bouquet) _ _ ->
      bouquet


hypsZipper : Zipper -> Bouquet
hypsZipper zipper =
  List.foldl (\zip acc -> hypsZip zip ++ acc) [] zipper


isHypothesis : Flower -> Zipper -> Bool
isHypothesis flower zipper =
  List.member flower (hypsZipper zipper)


justifies : Zipper -> Zipper -> Bool
justifies source destination =
  let lca = Utils.List.longestCommonSuffix source destination in
  case source of
    -- Self pollination
    Bouquet _ _ :: (Pistil _ :: grandParent as parent) ->
      lca == grandParent ||
      lca == parent

    -- Wind pollination
    Bouquet _ _ :: parent ->
      lca == parent
    
    _ ->
      False


type Polarity
  = Pos
  | Neg


invert : Polarity -> Polarity
invert polarity =
  case polarity of
    Pos -> Neg
    Neg -> Pos


type alias Context
  = { zipper : Zipper,
      polarity : Polarity }


type alias Selection
  = List Zipper
 

type alias FlowerDragId
  = { source : Zipper, content : Flower }

type alias FlowerDropId
  = Maybe { target : Zipper, content : Bouquet }

type alias FlowerDnD
  = DnD.Model FlowerDragId FlowerDropId

type alias FlowerDnDMsg
  = DnD.Msg FlowerDragId FlowerDropId


type ProofInteraction
  = Justifying
  | Importing FlowerDnD
  | Fencing Selection


type UIMode
  = ProofMode ProofInteraction
  | EditMode
  | NavigationMode


type alias Model
  = { goal : Bouquet
    , mode : UIMode }


yinyang : Flower
yinyang =
  Flower (Garden []) [Garden []]


identity : Flower
identity =
  Flower
    (Garden [Atom "a"])
    [Garden [Atom "a"]]


yvonne : Flower
yvonne =
  Flower
    ( Garden
        [ Flower
            (Garden [Atom "b"])
            [Garden [Atom "c"]] ] )
    [ Garden
        [ Atom "a"
        , Flower
            (Garden [Atom "b"])
            [Garden [Atom "c"]] ]]


bigFlower : Flower
bigFlower =
  Flower
    ( Garden
        [ Atom "a"
        , Flower
            ( Garden
                [ Atom "a" ] )
            [ Garden
                [ Atom "b" ],
              Garden
                [ Flower
                    ( Garden
                        [ Atom "b" ] )
                    [ Garden
                        [ Atom "c" ] ],
                  Atom "b" ] ]
        , Flower
            ( Garden
                [ Atom "d"] )
            [ Garden
                [ Atom "e" ] ] ] )
    [ Garden
        [ Atom "b"
        , Atom "a" ]
    , Garden
      [ Atom "c" ] ]


implies : String -> String -> Flower
implies a b =
  Flower
    ( Garden
        [ Atom a ] )
    [ Garden
        [ Atom b ] ]

modusPonensCurryfied : Flower
modusPonensCurryfied =
  Flower
    ( Garden [ implies "a" "b" ] ) 
    [ Garden [ implies "a" "b" ] ]


notFalse : Flower
notFalse =
  Flower (Garden [Flower (Garden []) []]) []


criticalPair : Flower
criticalPair =
  Flower
    ( Garden
        [ Flower
            ( Garden [] )
            [ Garden [ Atom "a" ]
            , Garden [ Atom "b" ] ]
        , implies "a" "c"
        , implies "b" "c" ] )
    [ Garden [ Atom "c" ] ]


init : () -> (Model, Cmd Msg)
init () =
  ( { goal = [ criticalPair ]
    , mode = ProofMode Justifying }
  , Cmd.none )


-- UPDATE

type ProofRule
  = Justify -- down pollination
  | Import -- up pollination
  | Unlock -- empty pistil
  | Close -- empty petal
  | Fence -- fencing


type Msg
  = ProofAction ProofRule Bouquet Zipper
  | DragDropMsg FlowerDnDMsg
  | ChangeUIMode UIMode
  | DoNothing


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    ProofAction rule bouquet zipper ->
      let
        model_=
          case (rule, bouquet, zipper) of
            (Justify, _, _) ->
              { model | goal = fillZipper [] zipper }
            
            (Import, _, _) ->
              { model
              | goal = fillZipper bouquet zipper
              , mode = ProofMode Justifying }

            (Unlock, [], Pistil [Garden petal] :: parent)  ->
              { model | goal = fillZipper petal parent }
            
            (Unlock, [], Pistil branches :: Bouquet left right :: Pistil petals :: parent) ->
              let
                case_ : Garden -> Flower
                case_ branch =
                  Flower branch petals
                
                pistil =
                  Garden (left ++ right)
                
                cases =
                  List.map case_ branches  
              in
              { model
              | goal = fillZipper [Flower pistil [Garden cases]] parent }
            
            (Close, [], Petal _ _ _ :: parent) ->
              { model | goal = fillZipper [] parent }

            _ ->
              model
      in
      (model_, Cmd.none)

    DragDropMsg dndMsg ->
      let
        cmd =
          DnD.getDragstartEvent dndMsg |>
          Maybe.map (.event >> dragstart) |>
          Maybe.withDefault Cmd.none
        model_ =
          case (model.mode, DnD.getDragstartEvent dndMsg) of
            (ProofMode Justifying, Just _) ->
              let ( newDragDrop, _ ) = DnD.update dndMsg DnD.init in
              { model | mode = ProofMode (Importing newDragDrop) }
            
            (ProofMode (Importing dragDrop), _) ->
              let
                ( newDragDrop, result ) =
                  DnD.update dndMsg dragDrop
                
                newModel =
                  case result of
                    Just (drag, drop, _) ->
                      case drop of
                        Just destination ->
                          update
                            ( ProofAction Import [drag.content] destination.target )
                            model |>
                          Tuple.first
                        
                        Nothing ->
                          model
                    
                    Nothing ->
                      model
              in
              { newModel | mode = ProofMode (Importing newDragDrop) }
            
            _ ->
              model
      in
      (model_, cmd)
    
    ChangeUIMode mode ->
      let _ = Debug.log "mode" mode in
      ({ model | mode = mode }, Cmd.none)
    
    DoNothing ->
      (model, Cmd.none)

-- VIEW


---- Text


viewFlowerText : Flower -> String
viewFlowerText flower =
  case flower of
    Atom name ->
      name    
    
    Flower pistil petals ->
      let
        pistilText =
          viewGardenText pistil

        petalsText =
          petals |>
          List.map viewGardenText |>
          String.join "; "
      in
      "(" ++ pistilText ++ " ⫐ " ++ petalsText ++ ")"


viewGardenText : Garden -> String
viewGardenText (Garden bouquet) =
  bouquet |>
  List.map viewFlowerText |>
  String.join ", "


viewZipperText : Zipper -> String
viewZipperText zipper =
  fillZipper [Atom "□"] zipper |>
  List.map (viewFlowerText) |>
  String.join ", "

logZipper : String -> Zipper -> String
logZipper msg zipper =
  zipper |>
  viewZipperText |>
  Debug.log msg

logBouquet : String -> Bouquet -> String
logBouquet msg bouquet =
  bouquet |>
  List.map viewFlowerText |>
  String.join ", " |>
  Debug.log msg


---- Graphics


transparent : Color
transparent =
  rgba 0 0 0 0


flowerForegroundColor : Polarity -> Color
flowerForegroundColor polarity =
  case polarity of
    Pos ->
      rgb 0 0 0
    Neg ->
      rgb 1 1 1

flowerBackgroundColor : Polarity -> Color
flowerBackgroundColor polarity =
  case polarity of
    Pos ->
      rgb 1 1 1
    Neg ->
      rgb 0 0 0


flowerBorderWidth : Int
flowerBorderWidth =
  3

flowerBorderRound : Int
flowerBorderRound =
  10


actionable : List (Attribute Msg)
actionable =
  [ pointer
  , Border.width 5
  , Border.color (rgb 0.3 0.9 0.3)
  , Border.dotted
  , Border.rounded flowerBorderRound
  , Background.color (rgba 0.3 0.9 0.3 0.5) ]


type alias DropStyle msg
  = { borderWidth : Int
    , active : List (Attribute msg)
    , inactive : List (Attribute msg) }


dropTarget : DropStyle msg
dropTarget =
  let
    width =
      3

    border =
      [ Border.width width
      , Border.dashed
      , Border.rounded flowerBorderRound
      , Border.color (rgb 1 0.8 0) ]
  in
  { borderWidth = width
  , active = Background.color (rgba 1 0.8 0 0.5) :: border
  , inactive = border }


stopPropagation : List (Attribute Msg)
stopPropagation =
  [ onDragOver DoNothing
  , onMouseMove DoNothing ]


nonSelectable : Attribute Msg
nonSelectable =
  htmlAttribute <| style "user-select" "none"


viewAtom : UIMode -> Context -> String -> Element Msg
viewAtom mode context name =
  case mode of
    ProofMode _ ->
      let
        atom =
          Atom name

        justifyAction =
          if isHypothesis atom context.zipper then
            (Events.onClick (ProofAction Justify [atom] context.zipper))
            :: actionable
          else
            []
      in
      el
        [ width fill
        , height fill ]
        ( el
            ( [ width shrink
              , height shrink
              , centerX, centerY
              , padding 10
              , Font.color (flowerForegroundColor context.polarity)
              , Font.size 50
              , nonSelectable ]
            ++ justifyAction )
            ( text name ) )

    _ ->
      Debug.todo ""


viewPistil : UIMode -> Context -> Garden -> List Garden -> Element Msg
viewPistil mode context (Garden bouquet as pistil) petals =
  case mode of
    ProofMode _ ->
      let
        newZipper =
          Pistil petals :: context.zipper

        unlockAction =
          let
            action =
              (Events.onClick (ProofAction Unlock bouquet newZipper))
              :: actionable
          in
          if List.isEmpty bouquet then
            case context.zipper of
              _ :: Pistil _ :: _ ->
                action
              _ ->
                if List.length petals == 1 then action else []
          else
            []
      in
      el
        ( [ width fill
          , height fill
          , Border.rounded flowerBorderRound ])
        ( el
            ( [ width fill
              , height fill
              , padding 10 ]
             ++ unlockAction )
            ( viewGarden
              mode
              { context
              | zipper = newZipper
              , polarity = invert context.polarity }
              pistil ) )
    _ ->
      Debug.todo ""


viewPetal : UIMode -> Context -> Garden -> (List Garden, List Garden) -> Garden -> Element Msg
viewPetal mode context pistil (leftPetals, rightPetals) (Garden bouquet as petal) =
  case mode of
    ProofMode _ ->
      let
        newZipper =
          Petal pistil leftPetals rightPetals :: context.zipper

        closeAction =
          if List.isEmpty bouquet then
            (Events.onClick (ProofAction Close bouquet newZipper))
            :: actionable
          else
            []
      in
      el
        [ width fill
        , height fill
        , Border.rounded flowerBorderRound
        , Background.color (flowerBackgroundColor context.polarity) ]
        ( el
            ( [ width fill
              , height fill
              , padding 10 ]
             ++ closeAction )
            ( viewGarden
                mode
                { context
                | zipper = newZipper }
                petal ) )
    _ ->
      Debug.todo ""


viewFlower : UIMode -> Context -> Flower -> Element Msg
viewFlower mode context flower =
  case mode of
    ProofMode _ ->
      case flower of
        Atom name ->
          viewAtom mode context name
        
        Flower pistil petals ->
          let
            pistilEl =
              viewPistil mode context pistil petals
            
            petalsEl =
              row
                [ width fill
                , height fill
                , spacing flowerBorderWidth ]
                ( Utils.List.zipperMap (viewPetal mode context pistil) petals )

            importStartAction =
              List.map htmlAttribute <|
              DnD.draggable DragDropMsg
                { source = context.zipper, content = flower }
          in
          column
            ( [ width fill
              , height fill
              , padding flowerBorderWidth
              , Background.color (flowerForegroundColor context.polarity)
              , Border.color (flowerForegroundColor context.polarity)
              , Border.rounded flowerBorderRound
              , Border.shadow
                  { offset = (0, 5)
                  , size = 0.25
                  , blur = 15
                  , color = flowerForegroundColor context.polarity } ]
            ++ (List.map htmlAttribute <| DnD.droppable DragDropMsg Nothing)
            ++ importStartAction )
            [ pistilEl, petalsEl ]
    
    _ ->
      Debug.todo ""


viewGarden : UIMode -> Context -> Garden -> Element Msg
viewGarden mode context (Garden bouquet) =
  let
    flowerEl (left, right) =
      viewFlower
        mode
        { context
        | zipper = Bouquet left right :: context.zipper }
    
    dropAction (left, right) =
      case mode of
        ProofMode (Importing dnd) ->
          case DnD.getDragId dnd of
            Just { source, content } ->
              -- if isHypothesis content context.zipper then
              if justifies source context.zipper then
                let
                  dropTargetStyle =
                    case DnD.getDropId dnd of
                      Just (Just { target }) ->
                        if Bouquet left right :: context.zipper == target
                        then dropTarget.active
                        else dropTarget.inactive
                    
                      _ ->
                        dropTarget.inactive
                in
                dropTargetStyle ++
                ( List.map htmlAttribute <|
                  DnD.droppable DragDropMsg
                    (Just { target = Bouquet left right :: context.zipper
                          , content = [content] }) )
              else
                []
            _ ->
              []

        ProofMode Justifying ->
          []
        
        _ ->
          Debug.todo ""
    
    layoutAttrs =
      [ width fill
      , height fill ]
    
    borderAttrs =
      [ Border.width dropTarget.borderWidth
      , Border.color transparent ]

    intersticial () =
      let
        attrs =
          layoutAttrs ++
          [ spacing 10 ]

        dropZone lr =
          el
            ( [ width fill
              , height fill ]
            ++ borderAttrs
            ++ dropAction lr )
            none

        els =
          let
            sperse ((left, right) as lr) flower =
              [dropZone (left, flower :: right), flowerEl lr flower]
          in
          ( bouquet |> Utils.List.zipperMap sperse |> List.concat ) ++
          [ dropZone (bouquet, []) ]
      in
      wrappedRow attrs els
        
    normal () =
      let
        attrs =
          (width (fill |> minimum 30)) ::
          (height (fill |> minimum 30)) ::
          spacing 30 ::
          padding 30 ::
          borderAttrs ++
          dropAction (bouquet, [])

        els =
          bouquet |> Utils.List.zipperMap flowerEl
      in
      wrappedRow attrs els
  in
  normal ()


viewGoal : Model -> Element Msg
viewGoal model =
  -- text (viewFlowerText model)
  let
    bouquetEls =
      let
        workingOnIt =
          el
            [ width fill
            , height fill
            , Background.color (rgb 1 1 1) ]
            ( el
                [ centerX, centerY
                , Font.size 50 ]
                ( text "Working on it!" ) )
      in
      case model.mode of
        ProofMode _ ->
          (Utils.List.zipperMap
            (\(l, r) flower ->
              el [width fill, height fill, centerX, centerY]
              (viewFlower model.mode (Context [Bouquet l r] Pos) flower))
            model.goal)

        _ ->
          [workingOnIt]
  in
  column
    [ width fill
    , height fill
    , scrollbarY
    , spacing 100
    , Background.color (rgb 0.65 0.65 0.65) ]
    bouquetEls


type ModeSelectorPosition
  = Start | Middle | End


viewModeSelector : UIMode -> Element Msg
viewModeSelector currentMode =
  let
    borderRoundSize = 10

    item mode position =
      let
        isSelected =
          case (mode, currentMode) of          
            (ProofMode _, ProofMode _) -> True
            _ -> mode == currentMode

        icon =
          let
            (label, filename) =
              case mode of
                ProofMode _ -> ("Prove", "prove")
                EditMode -> ("Edit", "pen")
                NavigationMode -> ("Navigate", "navigate")
          in
          image
            [ width fill 
            , height fill
            , nonSelectable ]
            { src = "../assets/img/" ++ filename ++ ".svg"
            , description = label }

        (bgColor, fgColor) =
          if isSelected
          then (rgb255 58 134 255, rgb 1 1 1)
          else (rgb 1 1 1, rgb 0 0 0)
        
        borderRound =
          case position of
            Start ->
              { topLeft = borderRoundSize, bottomLeft = borderRoundSize
              , topRight = 0, bottomRight = 0 }
            Middle ->
              { topLeft = 0, bottomLeft = 0
              , topRight = 0, bottomRight = 0 }
            End ->
              { topLeft = 0, bottomLeft = 0
              , topRight = borderRoundSize, bottomRight = borderRoundSize }

        changeAction =
          [ Events.onClick (ChangeUIMode mode)
          , pointer ]
      in
      el
        ( [ width (60 |> px)
          , height fill
          , padding 12
          , Background.color bgColor
          , Border.roundEach borderRound ]
         ++ changeAction )
        icon
    
    borderColor = rgb 0.6 0.6 0.6
  in
  row
    [ width shrink
    , height fill
    , centerX, centerY
    , spacing 1
    , Border.width 0
    , Border.rounded borderRoundSize
    , Border.color borderColor
    , Background.color borderColor ]
    [ item (ProofMode Justifying) Start
    , item EditMode Middle
    , item NavigationMode End ]


viewToolbar : Model -> Element Msg
viewToolbar model =
  row
    [ width fill
    , height shrink
    , padding 15
    , Background.color (rgb 0.9 0.9 0.9) ]
    [ viewModeSelector model.mode ]


view : Model -> Html Msg
view model =
  let
    goal =
      viewGoal model
    
    toolbar =
      viewToolbar model
    
    app =
      column
        [ width fill,
          height fill ]
        [goal, toolbar]
  in
  layout [] app