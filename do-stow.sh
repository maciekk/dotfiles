#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package=${1:?"usage: $0 PACKAGE"}

cd "$repo_dir"

if [[ "$package" == "pi-config" ]]; then
  # pi-usage rejects symlinks and atomically rewrites its mutable settings.
  stow -R -t "$HOME" --dotfiles --ignore='(^|/)pi-usage\.json$' "$package"
  target="$HOME/.pi/agent/pi-usage.json"
  [[ ! -L "$target" ]] || rm -- "$target"
  install -Dm600 "$package/dot-pi/agent/pi-usage.json" "$target"
else
  stow -R -t "$HOME" --dotfiles "$package"
fi
