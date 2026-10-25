#!/usr/bin/env bash
# URL picker for tmux panes. Unlike tmux-fzf-url's stock launcher, this keeps
# the popup compact and positions it relative to the active pane.

target_pane=${1:-}
tmux_target=()
[[ -n $target_pane ]] && tmux_target=(-t "$target_pane")

get_option() {
  local option=$1 default=$2 value
  value="$(tmux show-option -gqv "$option")"
  printf '%s\n' "${value:-$default}"
}

open_url() {
  if command -v open >/dev/null 2>&1; then
    nohup open "$1" >/dev/null 2>&1 &
  elif command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$1" >/dev/null 2>&1 &
  elif [[ -n ${BROWSER:-} ]]; then
    nohup "$BROWSER" "$1" >/dev/null 2>&1 &
  fi
}

# In copy-mode -M selects its backing buffer, NOT the scrolled viewport.
# Apply scroll_position to the capture range to obtain the visible rows.
# Omit -e (terminal styling); -J joins soft-wrapped lines.
viewport=$(tmux display-message -p "${tmux_target[@]}" '#{pane_height} #{scroll_position}')
read -r lines scroll_position <<< "$viewport"
scroll_position=${scroll_position:-0}
start=$((-scroll_position))
end=$((lines - scroll_position - 1))
content="$(tmux capture-pane -J -M -p "${tmux_target[@]}" -S "$start" -E "$end")"
# Accept URL characters beyond the upstream plugin's narrow character classes.
# Capture through whitespace; capture-pane above omits terminal styling.
urls=$(printf '%s\n' "$content" | grep -oE '(https?|ftp|file)://[^[:space:]]+')
wwws=$(printf '%s\n' "$content" | grep -oE '(http?s://)?www\.[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}(/\S+)*' | grep -vE '^https?://' | sed 's/^\(.*\)$/http:\/\/\1/')
ips=$(printf '%s\n' "$content" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]{1,5})?(/\S+)*' | sed 's/^\(.*\)$/http:\/\/\1/')
gits=$(printf '%s\n' "$content" | grep -oE '(ssh://)?git@\S*' | sed 's/:/\//g' | sed 's/^\(ssh\/\/\/\)\{0,1\}git@\(.*\)$/https:\/\/\2/')
github=$(printf '%s\n' "$content" | grep -oE "['\"]([_A-Za-z0-9-]*/[_.A-Za-z0-9-]*)['\"]" | sed "s/['\"]//g" | sed 's#^#https://github.com/#')

items=$(printf '%s\n' "$urls" "$wwws" "$github" "$ips" "$gits" |
  grep -v '^$' | sort -u | nl -w3 -s '  ')

if [[ -z $items ]]; then
  tmux display-message 'tmux URL picker: no URLs found'
  exit 0
fi

count=$(printf '%s\n' "$items" | wc -l | tr -d ' ')
columns=$(tmux display-message -p "${tmux_target[@]}" '#{pane_width}')
width_percent=$(get_option '@url-picker-width-percent' 60)
max_height_percent=$(get_option '@url-picker-max-height-percent' 40)
x_offset=$(get_option '@url-picker-x-offset' 20)

# One row per result, plus prompt, border, and a little breathing room.
height=$((count + 4))
max_height=$((lines * max_height_percent / 100))
(( max_height < 6 )) && max_height=6
(( height > max_height )) && height=$max_height

width=$((columns * width_percent / 100))
# Start at the usual centred position, shifted right, without overflowing.
x=$(((columns - width) / 2 + x_offset))
max_x=$((columns - width))
(( x > max_x )) && x=$max_x
(( x < 0 )) && x=0

printf '%s\n' "$items" |
  fzf-tmux -w "${width_percent}%" -h "$height" -x "$x" \
    --multi -0 --no-preview --prompt='   ' --border-label=' Open URL ' |
  awk '{print $2}' |
  while IFS= read -r chosen; do
    open_url "$chosen"
  done
