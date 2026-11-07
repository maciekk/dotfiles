#!/bin/bash
# Compact labels for common apps; keep other application names lowercase.
app_label() {
  local name
  name=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$name" in
    obsidian) printf '%s' 'Obsid' ;;
    firefox) printf '%s' 'Fire' ;;
    ghostty) printf '%s' 'Ghost' ;;
    chatgpt) printf '%s' 'GPT' ;;
    messages) printf '%s' 'SMS' ;;
    *) printf '%s' "$name" ;;
  esac
}
