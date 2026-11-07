#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Native media events work on older macOS. On 15.3+ Apple's private API is
# restricted; optionally install media-control for current macOS support.
if command -v media-control >/dev/null 2>&1; then
  data=$(media-control get 2>/dev/null)
elif [[ "$SENDER" == media_change ]]; then
  data="$INFO"
else
  exit 0
fi
label=$(jq -er 'select(.playing == true or .state == "playing") |
  select((.title | type) == "string" and (.title | length) > 0) |
  [.title, (.artist // "")] | map(select(length > 0)) | join(" — ")' \
  <<< "$data" 2>/dev/null)
if [[ -n "$label" ]]; then
  sketchybar --set now_playing drawing=on label="$label"
else
  sketchybar --set now_playing drawing=off
fi
