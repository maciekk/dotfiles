#!/bin/bash
# AeroSpace breadcrumbs, three sections on the left of every bar that narrow
# in scope (see sketchybarrc for the static items):
#   global     monitor.<d> per monitor, left to right: monitor glyph and its
#              visible workspace, focused one highlighted; workspaces_other
#              lists the remaining workspaces that hold windows. Drawn on
#              all displays.
#   workspace  apps.<d>: layout glyph and app labels (with window counts) for
#              the workspace on display <d>; drawn only on that display.
#   window     front_window: tiled/floating/fullscreen glyph and title.
# <d> is the SketchyBar display (arrangement-id), which matches AeroSpace's
# monitor-appkit-nsscreen-screens-id.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/app-labels.sh"

# If AeroSpace is stopped, leave the last known state intact.
visible=$(aerospace list-workspaces --monitor all --visible --json --format \
  '%{workspace}%{workspace-is-focused}%{workspace-root-container-layout}%{monitor-name}%{monitor-appkit-nsscreen-screens-id}' \
  2>/dev/null) || exit 0
windows=$(aerospace list-windows --all \
  --format '%{workspace}%{app-name}' --json 2>/dev/null) || exit 0
displays=$(sketchybar --query displays) || exit 0

# Events and polls can overlap; serialise so two runs never add one item.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-sketchybar"
state="$cache/aerospace"
mkdir -p "$state"
chmod 700 "$cache"
for _ in {1..30}; do
  mkdir "$cache/aerospace.lock" 2>/dev/null && break
  sleep 0.1
done
trap 'rmdir "$cache/aerospace.lock" 2>/dev/null' EXIT

items=$(sketchybar --query bar | jq -r '.items[]')
# No monitor.* items means a fresh SketchyBar: forget what the last one had.
grep -q '^monitor\.' <<< "$items" || rm -f "$state"/*

# Accumulate one transaction. Idle polls must not set properties or move
# items: those operations can visibly redraw an otherwise idle bar. Each
# item's last-applied properties are cached and re-sent only on change.
changes=()
added=false
sync_item() {
  local item=$1 sig
  shift
  sig=$(printf '%q ' "$@")
  if ! grep -Fxq -- "$item" <<< "$items"; then
    changes+=(--add item "$item" left)
    added=true
  elif [[ -r "$state/$item" && "$(< "$state/$item")" == "$sig" ]]; then
    return
  fi
  changes+=(--set "$item" "$@")
  printf '%s' "$sig" > "$state/$item"
}

layout_glyph() {
  case "$1" in
    h_tiles) printf '%s' '󰕭' ;;
    v_tiles) printf '%s' '󰕪' ;;
    h_accordion) printf '%s' '󰕬' ;;
    v_accordion) printf '%s' '󰕵' ;;
    *) printf '%s' '󰕰' ;;
  esac
}

superscript() {
  case "$1" in
    1) ;;
    2) printf '²' ;; 3) printf '³' ;; 4) printf '⁴' ;; 5) printf '⁵' ;;
    6) printf '⁶' ;; 7) printf '⁷' ;; 8) printf '⁸' ;; 9) printf '⁹' ;;
    *) printf '⁺' ;;
  esac
}

# One row per monitor, ordered by screen position: display, workspace,
# focused, layout, built-in?, apps as "name\x1fcount\x1e..." (sorted by name).
rows=$(jq -r --argjson displays "$displays" --argjson windows "$windows" '
  map(. as $m | (.["monitor-appkit-nsscreen-screens-id"] // 1) as $d | {
    d: $d, ws: .workspace, focused: .["workspace-is-focused"],
    layout: .["workspace-root-container-layout"],
    builtin: (.["monitor-name"] | test("built-in"; "i")),
    x: (($displays | map(select(.["arrangement-id"] == $d))[0].frame.x) // $d),
    apps: ([$windows[] | select(.workspace == $m.workspace) | .["app-name"]]
      | group_by(.) | map("\(.[0])\u001f\(length)") | join("\u001e"))
  }) | sort_by(.x, .d)[] |
  [.d, .ws, .focused, .layout, .builtin, .apps] | @tsv' <<< "$visible")

# Other workspaces holding windows, compactly: numeric prefix, or full name.
others=$(jq -r --argjson visible "$visible" '
  [.[].workspace] - [$visible[].workspace] | unique |
  map(((try (capture("^(?<n>[0-9]+)(?:-|$)").n | tonumber) catch null) // null) as $n |
    {name: (if $n == null then . else ($n | tostring) end),
     key: (if $n == null then [1, 0, .] elif $n == 0 then [0, 10, .]
           else [0, $n, .] end)}) |
  # Spell out names whose numbers collide (e.g. "1" and "1-plan").
  group_by(.name) | map(if length > 1 then map(.name = .key[2]) else . end) |
  add // [] | sort_by(.key) | map(.name) | join(" ")' <<< "$windows")

keep=()
order=()
while IFS=$'\t' read -r d ws focused layout builtin apps; do
  [[ -n "$d" ]] || continue
  keep+=("monitor.$d" "apps.$d")
  order+=("$d")

  labels=''
  IFS=$'\x1e' read -ra groups <<< "$apps"
  for group in "${groups[@]}"; do
    [[ -n "$group" ]] || continue
    [[ -z "$labels" ]] || labels+=' · '
    labels+="$(app_label "${group%$'\x1f'*}")$(superscript "${group##*$'\x1f'}")"
  done

  if [[ "$focused" == true ]]; then
    ws_icon="$ACTIVE" ws_label="$ACTIVE" ws_background=on label_color="$TEXT"
  else
    ws_icon="$MUTED" ws_label="$TEXT" ws_background=off label_color="$MUTED"
  fi
  monitor_glyph='󰍹'
  [[ "$builtin" == true ]] && monitor_glyph='󰌢'
  printf -v click '%q workspace %q' "$(command -v aerospace)" "$ws"
  sync_item "monitor.$d" icon="$monitor_glyph" icon.color="$ws_icon" \
    icon.font='Hack Nerd Font:Regular:16.0' \
    label="$ws" label.color="$ws_label" \
    padding_left=3 padding_right=3 icon.padding_left=6 icon.padding_right=4 \
    label.padding_left=0 label.padding_right=7 \
    background.height=22 background.corner_radius=5 \
    background.color="$ACTIVE_BG" background.drawing="$ws_background" \
    click_script="$click"

  if [[ -z "$labels" ]]; then
    labels='empty'
    label_color="$DIM"
  fi
  sync_item "apps.$d" display="$d" \
    icon="$(layout_glyph "$layout")" icon.font='Hack Nerd Font:Regular:16.0' \
    icon.color="$MUTED" icon.padding_right=5 \
    label="$labels" label.color="$label_color"
done <<< "$rows"

other_drawing=on
[[ -n "$others" ]] || other_drawing=off
sync_item workspaces_other label="$others" drawing="$other_drawing"

# Drop items for unplugged monitors, and the pre-multi-monitor workspace.*.
removed=false
while IFS= read -r item; do
  case "$item" in
    monitor.*|apps.*|workspace.*) ;;
    *) continue ;;
  esac
  printf '%s\n' "${keep[@]}" | grep -Fxq -- "$item" && continue
  changes+=(--remove "$item")
  rm -f "$state/$item"
  removed=true
done <<< "$items"

# Establish order only when monitors change.
order_sig="${order[*]}"
if $added || $removed || [[ ! -r "$state/order" || "$(< "$state/order")" != "$order_sig" ]]; then
  for d in "${order[@]}"; do
    changes+=(--move "monitor.$d" before workspaces_other
      --move "apps.$d" before crumb_window)
  done
  printf '%s' "$order_sig" > "$state/order"
fi

front=$(aerospace list-windows --focused --json --format \
  '%{app-name}%{window-title}%{window-layout}%{window-is-fullscreen}' \
  2>/dev/null) || front='[]'
title=$(jq -r -f "$CONFIG_DIR/plugins/window-title.jq" <<< "$front")
window_glyph=$(jq -r '.[0] // {} |
  if .["window-is-fullscreen"] == true then "󰊓"
  elif .["window-layout"] == "floating" then "󰖲"
  elif .["app-name"] == null then "󰇄"
  else "󱂬" end' <<< "$front")
if ! sketchybar --query front_window | jq -e --arg t "$title" --arg g "$window_glyph" \
    '.label.value == $t and .icon.value == $g' >/dev/null; then
  changes+=(--set front_window label="$title" icon="$window_glyph")
fi
if (( ${#changes[@]} )); then
  sketchybar "${changes[@]}"
fi
