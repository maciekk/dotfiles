#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
export LC_ALL=C

# The second sample measures the last second, rather than since boot.
cpu=$(top -l 2 -s 1 -n 0 2>/dev/null | awk '/CPU usage:/ {
  for (i=1; i<=NF; i++) if ($i == "idle") { idle=$(i-1); sub(/%/, "", idle); value=100-idle }
} END { if (value != "") printf "%.0f", value }')
if [[ "$cpu" =~ ^[0-9]+$ ]]; then
  color="$GOOD"
  (( cpu >= 25 )) && color="$WARNING"
  (( cpu >= 70 )) && color="$CRITICAL"
  sketchybar --set cpu label="${cpu}%" icon.color="$color"
fi
