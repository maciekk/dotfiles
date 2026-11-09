#!/bin/zsh
# Run: zsh scripts/tests/repos-completion.zsh
# Drives real Tab completion for `repos` in an interactive shell on a pty.
set -eu
zmodload zsh/zpty zsh/datetime
root=${0:A:h:h:h}
tmp=$(mktemp -d)
# A missed prompt would block zpty -r forever; fail instead.
( sleep 30; print -u2 'repos completion tests timed out'; kill $$ ) &!
watchdog=$!
trap 'kill $watchdog 2>/dev/null; zpty -d z 2>/dev/null; rm -rf -- "$tmp"' EXIT

home=$tmp/home cache=$tmp/cache
mkdir -p "$cache"
print -l -- "$EPOCHSECONDS" "-"$'\t'"$home/dots" > "$cache/dot"
print -l -- "$EPOCHSECONDS" "B"$'\t'"$home/src/a/tool" "-"$'\t'"$home/src/b/tool" \
  "M"$'\t'"$home/src/my repo" "-"$'\t'"$home/src/solo" > "$cache/src"

zpty z 'zsh -f -i'
# The prompt marker is split by %{%} so the echoed command never matches it.
# Input sent before zle draws a prompt can be dropped, so always wait for it.
send() { zpty -w z "$1"; zpty -r z _ '*RY> '; }
send "PS1='%{%}R%{%}Y> '"
send 'autoload -Uz compinit; compinit -u -D'
send "HOME=${(q)home} REPOS_CACHE=${(q)cache} REPOS_DOTFILES=${(q)home}/dots"
send "source ${(q)root}/zsh/dot-config/zsh/repo-status.zsh; add-zsh-hook -d precmd _repos_precmd"
send "dump() { print -r -- \"\$BUFFER\" >| ${(q)tmp}/buffer; BUFFER=; zle accept-line; }"
send "zle -N dump; bindkey '^X' dump"

complete() {
  zpty -w -n z "$1"$'\t\C-x'
  zpty -r z _ '*RY> '
  local got=$(<"$tmp/buffer")
  [[ $got == "$2" ]] || { print -u2 "Completing '$1': expected '$2', got '$got'"; exit 1; }
}
complete 'repos st' 'repos status '
complete 'repos status --o' 'repos status --only '
complete 'repos status unk' 'repos status unknown '
complete 'repos status ^beh' 'repos status ^behind '
complete 'repos pull so' 'repos pull solo '
complete 'repos pull dotf' 'repos pull dotfiles '
# Paths with spaces are quoted; ~ completes paths under HOME.
complete 'repos pull ~/src/m' 'repos pull ~/src/my\ repo '
complete "repos pull $home/src/s" "repos pull $home/src/solo "
# Ambiguous basenames are not offered as names.
complete 'repos pull to' 'repos pull to'
print 'repos completion tests passed'
