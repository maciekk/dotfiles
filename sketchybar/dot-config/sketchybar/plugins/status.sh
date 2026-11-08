#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

if [[ "$SENDER" == volume_change ]]; then
  volume="$INFO"
else
  volume=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
fi
if [[ "$volume" =~ ^[0-9]+$ ]]; then
  case "$volume" in
    0) icon='󰖁' ;;
    [1-9]|[12][0-9]) icon='󰕿' ;;
    [345][0-9]) icon='󰖀' ;;
    *) icon='󰕾' ;;
  esac
  if (( volume < 33 )); then
    color="$DIM"
  elif (( volume <= 66 )); then
    color="$MUTED"
  elif (( volume <= 80 )); then
    color="$WARNING"
  else
    color="$CRITICAL"
  fi
  sketchybar --set volume icon="$icon" label="${volume}%" \
    icon.color="$color" label.color="$color"
fi
# Volume changes don't need to run the remaining status checks.
[[ "$SENDER" == volume_change ]] && exit 0

sketchybar --set clock label="$(date '+%a %d %b  %H:%M')" \
  icon.color="$CLOCK" label.color="$TEXT"
battery=$(pmset -g batt)
percent=$(grep -Eo '[0-9]+%' <<< "$battery" | head -1 | tr -d '%')
if [[ -n "$percent" ]]; then
  case "$percent" in
    100|9[0-9]) icon='' ;;
    [6-8][0-9]) icon='' ;;
    [3-5][0-9]) icon='' ;;
    [12][0-9]) icon='' ;;
    *) icon='' ;;
  esac
  color="$TEXT"
  if [[ "$battery" == *'AC Power'* ]]; then
    icon=''
    color="$GOOD"
  elif (( percent <= 10 )); then
    color="$CRITICAL"
  elif (( percent <= 20 )); then
    color="$WARNING"
  fi
  sketchybar --set battery drawing=on icon="$icon" label="${percent}%" \
    icon.color="$color" label.color="$TEXT"
else
  sketchybar --set battery drawing=off
fi
