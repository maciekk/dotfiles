#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package=${1:?"usage: $0 PACKAGE"}

cd "$repo_dir"

if [[ "$package" == "pi-config" ]]; then
  # pi-usage rejects symlinks, so deploy its tracked config as a regular file.
  stow -R -t "$HOME" --dotfiles --ignore='^pi-usage\.json$' "$package"
  mkdir -p "$HOME/.pi/agent"
  install -m 600 "$repo_dir/pi-config/pi-usage.json" "$HOME/.pi/agent/pi-usage.json"
else
  stow -R -t "$HOME" --dotfiles "$package"
fi
