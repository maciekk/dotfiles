#!/bin/bash
# AeroSpace key cheatsheet: a SketchyBar popup toggled by alt-shift-slash
# (see ~/.aerospace.toml, which runs plugins/cheatsheet-toggle.sh). Sourced
# by sketchybarrc; keep rows in sync with the bindings there by hand.
#
# Rows: "keys|description" for a binding, "#Title" for a section header
# (preceded by a blank row), "#" alone for a blank row.
CHEATSHEET_ROWS=(
  '#Windows'
  '⌥  h j k l|Focus left / down / up / right'
  '⌥⇧ h j k l|Move window'
  '⌥  −  =|Shrink / grow'
  '⌥  m|Minimize (native)'
  '#Layout'
  '⌥  /|Tiles; again flips orientation'
  '⌥  ,|Accordion; again flips orientation'
  '⌥  f|Fullscreen'
  '⌥⌃ t|Float / tile window'
  '#Workspaces'
  '⌥  1 … 9|Go to workspace'
  '⌥  0|Go to dump'
  '⌥⇧ 1 … 0|Send window to workspace'
  '⌥  ⇥|Previous workspace'
  '#Monitors'
  '⌥⌃ ← →|Focus monitor'
  '⌥⇧ ⇥|Move workspace to next monitor'
  '#Service mode   ⌥⇧ ;'
  'esc|Reload config'
  'r|Reset layout (flatten)'
  'f|Float / tile window'
  '⌫|Close all other windows'
  '⌥⇧ h j k l|Join with neighbour'
  '#'
  '⌥⇧ /|Show / hide this cheatsheet'
  '#'
)
# Every popup row has this height; plugins/cheatsheet-toggle.sh uses it to
# centre the popup vertically.
CHEATSHEET_ROW_HEIGHT=19

# The anchor is an empty, zero-width item at the bar's centre; display=active
# opens the popup on the focused monitor. It closes on any click in it, or
# when focus moves to another workspace or app.
sketchybar --add item cheatsheet center \
  --set cheatsheet width=0 icon.drawing=off label.drawing=off display=active \
    popup.align=center popup.height="$CHEATSHEET_ROW_HEIGHT" \
    popup.background.color="$BAR" popup.background.corner_radius=10 \
    popup.background.border_width=1 popup.background.border_color="$DIM" \
    popup.blur_radius=18 \
    script='sketchybar --set "$NAME" popup.drawing=off' \
  --subscribe cheatsheet aerospace_workspace_change front_app_switched

# Expand each header into a blank row plus the title row.
cheatsheet_rows=()
for row in "${CHEATSHEET_ROWS[@]}"; do
  [[ "$row" == '#'?* ]] && cheatsheet_rows+=('#')
  cheatsheet_rows+=("$row")
done

cheatsheet_args=()
cheatsheet_i=0
for row in "${cheatsheet_rows[@]}"; do
  item="cheatsheet.$cheatsheet_i"
  cheatsheet_i=$((cheatsheet_i + 1))
  cheatsheet_args+=(--add item "$item" popup.cheatsheet --set "$item"
    click_script='sketchybar --set cheatsheet popup.drawing=off'
    padding_left=10 padding_right=14)
  if [[ "$row" == '#'* ]]; then
    cheatsheet_args+=(icon.drawing=off label="${row#\#}" label.color="$ACCENT"
      label.font='Helvetica Neue:Bold:13.0' label.padding_left=0)
  else
    cheatsheet_args+=(icon="${row%%|*}" icon.width=116 icon.color="$KEYS" icon.padding_left=14
      icon.font='Hack Nerd Font Mono:Bold:14.0'
      label="${row#*|}" label.color="$TEXT"
      label.font='Helvetica Neue:Regular:14.0')
  fi
done
sketchybar "${cheatsheet_args[@]}"
unset row item cheatsheet_rows cheatsheet_args cheatsheet_i
