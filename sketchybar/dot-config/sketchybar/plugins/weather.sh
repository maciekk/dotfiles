#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"

# Waterloo, Ontario. Open-Meteo: Celsius, no account/key, 15-minute polling.
data=$(curl -fsS --connect-timeout 4 --max-time 8 \
  'https://api.open-meteo.com/v1/forecast?latitude=43.4643&longitude=-80.5204&current=temperature_2m,weather_code&timezone=America%2FToronto' 2>/dev/null)
values=$(jq -er '.current | select((.temperature_2m | type) == "number" and
  (.weather_code | type) == "number") | "\(.temperature_2m | round) \(.weather_code)"' \
  <<< "$data" 2>/dev/null)
if [[ -z "$values" ]]; then
  sketchybar --set weather drawing=on icon='󰖐' label='—°' icon.color="$MUTED"
  exit 0
fi
read -r temp code <<< "$values"
case "$code" in
  0) icon='' ;;
  1|2) icon='󰖕' ;;
  3) icon='' ;;
  45|48) icon='󰖑' ;;
  51|53|55|56|57|61|63|65|66|67|80|81|82) icon='󰖗' ;;
  71|73|75|77|85|86) icon='󰖘' ;;
  95|96|99) icon='󰖓' ;;
  *) icon='󰖐' ;;
esac
sketchybar --set weather drawing=on icon="$icon" label="${temp}°C" icon.color="$WEATHER"
