#!/bin/bash
# Show/hide the AeroSpace cheatsheet popup (cheatsheet.sh), centred on the
# monitor where it opens. Bound to alt-shift-slash in ~/.aerospace.toml.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

anchor=$(sketchybar --query cheatsheet) || exit 1
if [[ $(jq -r .popup.drawing <<< "$anchor") == on ]]; then
  sketchybar --set cheatsheet popup.drawing=off
  exit
fi

# The anchor is drawn only on the active display; the others report it
# off-screen at -9999. Popups hang from the bar's bottom edge, so drop it by
# half the space left over beneath the bar.
y_offset=$(jq -n --argjson anchor "$anchor" \
  --argjson displays "$(sketchybar --query displays)" \
  --argjson bar "$(sketchybar --query bar)" '
  ($anchor.bounding_rects | to_entries
    | map(select(.value.origin[0] > -9999))[0].key // "display-1"
    | ltrimstr("display-") | tonumber) as $id |
  ($displays | map(select(."arrangement-id" == $id))[0].frame.h) as $h |
  ($anchor.popup.items | length) * $anchor.popup.height as $popup |
  [((($h - $bar.height - $popup) / 2) | floor), 0] | max')

sketchybar --set cheatsheet popup.y_offset="${y_offset:-0}" popup.drawing=on
