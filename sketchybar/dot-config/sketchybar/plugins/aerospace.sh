#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/app-labels.sh"

# If AeroSpace is stopped, leave the last known state intact.
focused=$(aerospace list-workspaces --focused 2>/dev/null) || exit 0
workspaces=$(aerospace list-workspaces --all --json 2>/dev/null) || exit 0
windows=$(aerospace list-windows --all \
  --format '%{workspace}%{app-name}' --json 2>/dev/null) || exit 0
items=$(sketchybar --query bar | jq -r '.items[]')

# Accumulate one transaction. Idle polls must not set bar properties or move
# items: those operations can visibly redraw/rearrange an otherwise idle bar.
changes=()
ordered=()
added=false

# Sort by numeric prefix (1-plan, 2-browser, ..., 9, 0), then other names.
while IFS= read -r ws; do
  item="workspace.$ws"
  # Compact display for numbered names; retain the full ID for click actions.
  number="${ws%%-*}"
  case "$number" in
    ''|*[!0-9]*) display_name="$ws" ;;
    *) display_name="$number" ;;
  esac
  current='{}'
  exists=false
  if grep -Fxq -- "$item" <<< "$items"; then
    exists=true
    current=$(sketchybar --query "$item")
  fi
  apps=$(jq -r --arg ws "$ws" \
    '[.[] | select(.workspace == $ws) | .["app-name"]] | unique[]' <<< "$windows")
  if [[ -z "$apps" && "$ws" != "$focused" ]]; then
    # Retain existing items for reuse, hiding only when visibility changes.
    if $exists; then
      ordered+=("$item")
      if [[ "$(jq -r '.geometry.drawing' <<< "$current")" != off ]]; then
        changes+=(--set "$item" drawing=off)
      fi
    fi
    continue
  fi

  ordered+=("$item")
  if ! $exists; then
    # Quote workspace names as shell arguments, including spaces/apostrophes.
    printf -v click '%q workspace %q' "$(command -v aerospace)" "$ws"
    changes+=(--add item "$item" left
      --set "$item" click_script="$click"
        label.font='Helvetica Neue:Medium:13.0'
        icon.font='Helvetica Neue:Bold:13.0' background.drawing=off)
    added=true
  fi
  labels=''
  while IFS= read -r app; do
    [[ -n "$app" ]] || continue
    [[ -z "$labels" ]] || labels+=' · '
    labels+="$(app_label "$app")"
  done <<< "$apps"
  if [[ "$ws" == "$focused" ]]; then
    fg="$ACCENT"
  else
    fg="$MUTED"
  fi
  label_drawing=off
  [[ -n "$labels" ]] && label_drawing=on
  if ! jq -e --arg ws "$display_name" --arg label "$labels" \
      --arg drawing "$label_drawing" --arg fg "$fg" --arg text "$TEXT" '
      .geometry.drawing == "on" and .icon.value == $ws and
      .label.value == $label and .label.drawing == $drawing and
      .geometry.background.drawing == "off" and
      .icon.color == $fg and .label.color == $text' <<< "$current" >/dev/null; then
    changes+=(--set "$item" drawing=on icon="$display_name"
      label="$labels" label.drawing="$label_drawing"
      background.drawing=off icon.color="$fg" label.color="$TEXT")
  fi
done < <(jq -r 'sort_by(.workspace as $ws |
  ((try ($ws | capture("^(?<n>[0-9]+)(?:-|$)").n | tonumber) catch null) // null) as $n |
  if $n == null then [1, 0, $ws]
  else [0, (if $n == 0 then 10 else $n end), $ws] end
  ) | .[].workspace' <<< "$workspaces")

# Clean up dynamically named workspaces that no longer exist.
while IFS= read -r item; do
  [[ "$item" == workspace.* ]] || continue
  ws="${item#workspace.}"
  if ! jq -e --arg ws "$ws" 'any(.[]; .workspace == $ws)' \
      <<< "$workspaces" >/dev/null; then
    changes+=(--remove "$item")
  fi
done <<< "$items"

# Establish order only when adding items, never during ordinary polling.
if $added; then
  for item in "${ordered[@]}"; do
    changes+=(--move "$item" before aerospace_controller)
  done
fi

front=$(aerospace list-windows --focused --json 2>/dev/null) || front='[]'
title=$(jq -r -f "$CONFIG_DIR/plugins/window-title.jq" <<< "$front")
current_title=$(sketchybar --query front_window | jq -r '.label.value')
if [[ "$title" != "$current_title" ]]; then
  changes+=(--set front_window label="$title")
fi
if (( ${#changes[@]} )); then
  sketchybar "${changes[@]}"
fi
