- Use HTML5 drag-and-drop API instead of custom handling of mousedown and
  mouseup events for Importing interaction
  - Try to support mobile touchscreens
    (https://github.com/norpan/elm-html5-drag-drop/blob/master/example/Example.elm)
  - Instead of having gardens as targets and importing at the end of them,
    add drop zones at the start, end and between flowers of gardens (make them
    visible during drag, or only when hovering target?)

- Implement Fencing proof interaction with multiselection
  - Start with long press to support mobile
  - Apply by pressing key, or button to support mobile
  - Cancel by clicking on any garden, or by clicking on close button

- Undo/redo history
  - Works for the entire state, thus switching freely between different UI modes
  - Buttons at the bottom of the screen + usual shortkeys

- Mode selection bar at bottom of the screen

- Implement Edit mode
  - The drop zones of Importing turn into `add flower` zones in positive gardens
  - `add petal` zones at the start, end and between petals of negative flowers
  - Negative flowers and positive petals can cropped/pulled (that is, removed)
    by clicking on them (scissors cursor icon)
  - Two clipboards, one for cropped flowers and one for pulled petals
  - `add flower/petal` zones have:
    - text edit to grow atom
      - one can imagine instead a button that launches/inlines a domain-specific
        GUI to build statements/objects in a custom domain, i.e. euclidian
        geometry
    - `grow` buttons to grow a flower/petal
    - free space to paste clipboard
  - Flowers/petals created by `grow` buttons don't have polarity restrictions:
    everything can be removed, and things can be added anywhere

- Implement Navigation mode
  - Underlying data structure: *focus stack* = list of zippers
  - Global context at top of the screen = hypotheses in top of focus stack
  - Focus on flower by clicking
  - Jump to flower in global context by clicking
  - Unfocus by clicking on focused flower
  - Scale/Unscale animation?

# Brainstorming

- Name flowers

- View for partial proof term attached to flower