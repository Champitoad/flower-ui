module Main exposing (..)

import Utils.List
import Utils.Events exposing (..)

import Browser

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Events as Events

import Html exposing (Html, div)
import Html.Attributes exposing (style)

import Html5.DragDrop as DnD


-- MAIN


main : Program () Model Msg
main =
  Browser.sandbox
    { init = init
    , update = update
    , view = view }


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


negate : Polarity -> Polarity
negate polarity =
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
  | Importing
  | Fencing Selection


type UIMode
  = ProofMode ProofInteraction
  | EditMode


type alias Model
  = { goal : Bouquet
    , mode : UIMode
    , dragDrop : FlowerDnD }


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


init : Model
init =
  { goal = [ criticalPair ]
  , mode = ProofMode Justifying
  , dragDrop = DnD.init }


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
  | DoNothing


update : Msg -> Model -> Model
update msg model =
  case msg of
    ProofAction rule bouquet zipper ->
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
    
    DragDropMsg dndMsg ->
      let
        ( dragDrop, result ) =
          DnD.update dndMsg model.dragDrop
        
        newModel =
          case result of
            Just (drag, drop, _) ->
              case drop of
                Just destination ->
                  update
                    ( ProofAction Import
                      ( destination.content ++ [drag.content] )
                      destination.target )
                    model
                
                Nothing ->
                  model
            
            Nothing ->
              model
      in
      { newModel | dragDrop = dragDrop }
    
    DoNothing ->
      model


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


fgColor : Polarity -> Color
fgColor polarity =
  case polarity of
    Pos ->
      rgb 0 0 0
    Neg ->
      rgb 1 1 1

bgColor : Polarity -> Color
bgColor polarity =
  case polarity of
    Pos ->
      rgb 1 1 1
    Neg ->
      rgb 0 0 0


borderWidth : Int
borderWidth =
  3

borderRound : Int
borderRound =
  10


actionable : List (Attribute Msg)
actionable =
  [ pointer
  , Border.width 3
  , Border.color (rgb 1.0 0.5 0)
  , Border.dotted ]


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
      , Border.color (rgb 1 0.8 0) ]
  in
  { borderWidth = width
  , active = Background.color (rgba 1 0.8 0 0.5) :: border
  , inactive = border }


stopPropagation : List (Attribute Msg)
stopPropagation =
  [ onDragOver DoNothing
  , onMouseMove DoNothing ]


viewFlowerProof : FlowerDnD -> Context -> Flower -> Element Msg
viewFlowerProof dnd context flower =
  case flower of
    Atom name ->
      let
        justifyAction : List (Attribute Msg)
        justifyAction =
          if isHypothesis flower context.zipper then
            (Events.onClick (ProofAction Justify [flower] context.zipper))
            :: actionable
          else
            []
      in
      el
        ( [ width shrink
          , height shrink
          , centerX, centerY
          , padding 3
          , Font.color (fgColor context.polarity)
          , Font.size 32
          , htmlAttribute <| style "user-select" "none" ]
          ++ justifyAction )
        ( text name )
    
    Flower pistil petals ->
      let
        pistilEl =
          let
            (Garden bouquet) = pistil

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
              , padding 20
              , Border.rounded borderRound ]
             ++ unlockAction )
            ( viewGardenProof
                dnd
                { context
                | zipper = newZipper
                , polarity = negate context.polarity }
                pistil )
        
        petalsEl =
          let
            petalEl (leftPetals, rightPetals) petal =
              let
                (Garden bouquet) = petal

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
                ( [ width fill
                  , height fill
                  , padding 20
                  , Border.rounded borderRound
                  , Background.color (bgColor context.polarity) ]
                 ++ closeAction )
                ( viewGardenProof
                    dnd
                    { context
                    | zipper = newZipper }
                    petal )
          in
          row
            [ width fill
            , height fill
            , spacing borderWidth ]
            ( Utils.List.zipMap petalEl petals )

        importStartAction =
          List.map htmlAttribute <|
          DnD.draggable DragDropMsg
            { source = context.zipper, content = flower }
      in
      column
        ( [ width fill
          , height fill
          , padding borderWidth
          , Background.color (fgColor context.polarity)
          , Border.color (fgColor context.polarity)
          , Border.rounded borderRound
          , Border.shadow
              { offset = (0, 5)
              , size = 0.25
              , blur = 15
              , color = fgColor context.polarity } ]
         ++ (List.map htmlAttribute <| DnD.droppable DragDropMsg Nothing)
         ++ importStartAction )
        [ pistilEl, petalsEl ]


viewGardenProof : FlowerDnD -> Context -> Garden -> Element Msg
viewGardenProof dnd context (Garden bouquet) =
  let
    flowerEl (left, right) =
      viewFlowerProof
        dnd
        { context
        | zipper = Bouquet left right :: context.zipper }
    
    importAction =
      case DnD.getDragId dnd of
        Just { source } ->
          -- if isHypothesis content context.zipper then
          if justifies source context.zipper then
            let
              dropTargetStyle =
                case DnD.getDropId dnd of
                  Just (Just { target }) ->
                    if context.zipper == target
                    then dropTarget.active
                    else dropTarget.inactive
                
                  _ ->
                    dropTarget.inactive
            in
            dropTargetStyle ++
            ( List.map htmlAttribute <|
              DnD.droppable DragDropMsg
                (Just { target = context.zipper, content = bouquet }) )
          else
            []
      
        _ ->
          []
  in
  wrappedRow
    ( [ width fill
      , height fill
      , spacing 40
      , Border.width dropTarget.borderWidth
      , Border.color transparent ]
     ++ importAction )
    (Utils.List.zipMap flowerEl bouquet)


viewGoal : Model -> Element Msg
viewGoal model =
  -- text (viewFlowerText model)
  let
    bouquetEls =
      case model.mode of
        ProofMode interaction ->
          (Utils.List.zipMap
            (\(l, r) flower ->
              el [width fill, height fill, centerX, centerY]
              (viewFlowerProof model.dragDrop (Context [Bouquet l r] Pos) flower))
            model.goal)

        EditMode ->
          Debug.todo ""  
  in
  column
    [ width fill
    , height fill
    , spacing 100
    , Background.color (rgb 0.65 0.65 0.65) ]
    bouquetEls


view : Model -> Html Msg
view model =
  layout [] (viewGoal model)