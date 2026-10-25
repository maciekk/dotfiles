#!/bin/sh
# Called by tmux: inherit TMUX so commands target the same server/socket.
set -eu
config_dir="$HOME/.config/tmux"
mode_file="$config_dir/theme-mode.local"
action=${1:-check}

case "$action" in
  auto|light|dark)
    printf '%s\n' "$action" > "$mode_file"
    exec tmux source-file "$config_dir/tmux.conf"
    ;;
  select|check) ;;
  *) echo 'Usage: appearance.sh [auto|light|dark|select|check]' >&2; exit 2 ;;
esac

# Preserve existing machine-specific profiles. Remove this file to opt into auto.
if [ -f "$config_dir/theme.local.conf" ]; then
  if [ "$action" = select ]; then
    tmux source-file "$config_dir/theme.local.conf"
  fi
  exit 0
fi

mode=auto
if [ -f "$mode_file" ]; then mode=$(cat "$mode_file"); fi
case "$mode" in
  light|dark) appearance=$mode ;;
  auto)
    appearance=light
    if [ "$(uname -s)" = Darwin ] &&
       [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" = Dark ]; then
      appearance=dark
    fi
    ;;
  *) echo "Invalid theme mode in $mode_file: $mode" >&2; exit 2 ;;
esac

if [ "$action" = check ]; then
  current=$(tmux show-option -gqv @appearance-current)
  [ "$current" = "$appearance" ] || tmux source-file "$config_dir/tmux.conf"
else
  profile=latte
  [ "$appearance" != dark ] || profile=mocha
  tmux source-file "$config_dir/theme-$profile.conf"
  tmux set-option -g @appearance-current "$appearance"
fi
