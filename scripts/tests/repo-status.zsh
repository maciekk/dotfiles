#!/bin/zsh
# Run: zsh scripts/tests/repo-status.zsh
set -eu
root=${0:A:h:h:h}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$tmp/src/nested"
export REPOS_ROOT="$tmp/src" REPOS_DOTFILES="$tmp/src/dotfiles" REPOS_CACHE="$tmp/cache"
# No network operations in tests; upstream tracking is updated explicitly.
export REPOS_FETCH_INTERVAL=9999999999
source "$root/zsh/dot-config/zsh/repo-status.zsh"

git init -q --bare "$tmp/remote"
git clone -q "$tmp/remote" "$REPOS_DOTFILES" 2>/dev/null
git -C "$REPOS_DOTFILES" config user.name Test
git -C "$REPOS_DOTFILES" config user.email test@example.com
print seed > "$REPOS_DOTFILES/file"
git -C "$REPOS_DOTFILES" add file
git -C "$REPOS_DOTFILES" commit -qm seed
git -C "$REPOS_DOTFILES" push -qu origin HEAD
git clone -q "$tmp/remote" "$tmp/src/nested/tool with spaces"
# Recent fetch marker avoids the intentional stale indicator.
print "$EPOCHSECONDS" > /dev/null
mkdir -p "$REPOS_CACHE"
print "$EPOCHSECONDS" > "$REPOS_CACHE/fetch"

check() {
  repos refresh
  [[ $_repos_text == "$1" ]] || { print -u2 "Expected '$1', got '$_repos_text'"; exit 1; }
}
check ''
print change >> "$REPOS_DOTFILES/file"
print untracked > "$tmp/src/nested/tool with spaces/new"
check 'd:1* &:1*'
git -C "$REPOS_DOTFILES" commit -qam fix
check 'd:1↑ &:1*'
# A non-current branch with no upstream must not silently disappear.
git -C "$REPOS_DOTFILES" branch forgotten
check 'd:1↑1? &:1*'
git -C "$REPOS_DOTFILES" branch -D forgotten >/dev/null
# Publish, then simulate the other repo having fetched the new commit.
git -C "$REPOS_DOTFILES" push -q
git -C "$tmp/src/nested/tool with spaces" fetch -q
check '&:1*1↓'
REPOS_EXCLUDE="$tmp/src/nested"
check ''
REPOS_EXCLUDE=''
git -C "$tmp/src/nested/tool with spaces" checkout -q --detach
check '&:1*1↓1?'
# Missing tracked dotfiles must produce unknown, not clean.
REPOS_DOTFILES="$tmp/missing"
check 'd:1? &:1*1↓1?'
# Failed fetches are visible, survive local rescans, and clear on success.
REPOS_DOTFILES="$tmp/src/dotfiles"
rm -- "$tmp/src/nested/tool with spaces/new"
git -C "$tmp/src/nested/tool with spaces" checkout -q master
git -C "$tmp/src/nested/tool with spaces" reset -q --hard origin/master
_repos_fetch() { return 1; }
REPOS_FETCH_INTERVAL=900
print 0 > "$REPOS_CACHE/fetch"
check 'd:1? &:1?'
check 'd:1? &:1?'
_repos_fetch() { return 0; }
print 0 > "$REPOS_CACHE/fetch"
check ''
# A stale fetch is visible even with otherwise clean records.
print 0 > "$REPOS_CACHE/fetch"
REPOS_FETCH_INTERVAL=900
_repos_read
[[ $_repos_text == *'~'* ]]
# Cache contents are data, never sourced as executable shell code.
print -r -- "-"$'\t'"\$(touch $tmp/should-not-exist)" >> "$REPOS_CACHE/src"
_repos_read
[[ ! -e $tmp/should-not-exist ]]
# Status filters read synthetic cache records; no rescan is involved.
saved_cache=$REPOS_CACHE
REPOS_CACHE="$tmp/filter-cache"
mkdir -p "$REPOS_CACHE"
print "$EPOCHSECONDS" > "$REPOS_CACHE/fetch"
print -l -- "$EPOCHSECONDS" "U"$'\t'"/d/ahead" > "$REPOS_CACHE/dot"
print -l -- "$EPOCHSECONDS" "M"$'\t'"/s/dirty" "MB"$'\t'"/s/dirty behind" \
  "B"$'\t'"/s/behind" "F"$'\t'"/s/fetch failed" "UMBQ"$'\t'"/s/everything" \
  "-"$'\t'"/s/clean" > "$REPOS_CACHE/src"
names() { repos status -n "$@" | paste -sd '|' -; }
[[ $(names) == '/d/ahead|/s/dirty|/s/dirty behind|/s/behind|/s/fetch failed|/s/everything' ]]
[[ $(names behind) == '/s/dirty behind|/s/behind|/s/everything' ]]
# Exclusions narrow the set: pullable means behind and not dirty.
[[ $(names b ^m) == '/s/behind' ]]
# Plain filters are OR'd.
[[ $(names u q) == '/d/ahead|/s/fetch failed|/s/everything' ]]
[[ $(names dot) == '/d/ahead' ]]
# --only: the listed statuses and nothing else; a failed fetch counts as q.
[[ $(names -o behind) == '/s/behind' ]]
[[ $(names --only b m) == '/s/dirty|/s/dirty behind|/s/behind' ]]
[[ $(names -o q) == '/s/fetch failed' ]]
[[ $(names -o src u) == '' ]]
[[ $(names ^dot dirty) == '/s/dirty|/s/dirty behind|/s/everything' ]]
# -n output is paths only; filtered human output adds the legend line.
[[ $(repos status -n | grep -c -e FLAGS -e Filters -e Summary) == 0 ]]
repos status | grep -q '^Filters:' && exit 1
repos status behind | grep -q '^Filters:'
# Unknown filters fail with the legend on stderr.
result=0
repos status bogus > "$tmp/out" 2> "$tmp/err" || result=$?
[[ $result == 2 && ! -s $tmp/out ]]
grep -q "unknown filter 'bogus'" "$tmp/err" && grep -q '^Filters:' "$tmp/err"
# The path column is aligned regardless of how many flags a repo has.
[[ $(repos status | grep ' /' | while IFS= read -r line; do
  print -r -- ${#${line%%/*}}; done | sort -u) == 7 ]]
REPOS_CACHE=$saved_cache
# Lock contention returns without rewriting snapshots; kernel releases on exit.
(
  zsystem flock -t 0 -f fd "$REPOS_CACHE/lock"
  before=$(cat "$REPOS_CACHE/dot")
  result=0
  zsh "$root/zsh/dot-config/zsh/repo-status.zsh" worker force 2> "$tmp/busy" || result=$?
  [[ $result == 1 ]]
  grep -q 'refresh busy' "$tmp/busy"
  [[ $(cat "$REPOS_CACHE/dot") == "$before" ]]
)
# Exercise the actual detached, noninteractive worker launch as well.
print "$EPOCHSECONDS" > "$REPOS_CACHE/fetch"
rm -- "$REPOS_CACHE/dot" "$REPOS_CACHE/src"
_repos_precmd
for attempt in {1..50}; do
  [[ -f $REPOS_CACHE/src ]] && break
  sleep 0.1
done
[[ -f $REPOS_CACHE/dot && -f $REPOS_CACHE/src ]]
_repos_read
[[ -z $_repos_text ]]
# A real controlling tty is essential: pipe-only tests miss SIGTTOU stops in
# background process substitutions. macOS script(1) supplies that terminal.
if [[ $(uname -s) == Darwin ]]; then
  cat > "$tmp/pty-driver.zsh" <<'DRIVER'
source "$1"
_repos_precmd
for attempt in {1..50}; do
  [[ -f $REPOS_CACHE/src ]] && break
  sleep 0.1
done
if [[ -f $REPOS_CACHE/dot && -f $REPOS_CACHE/src ]]; then
  print passed > "$REPOS_CACHE/pty-passed"
fi
# Exercise a foreground refresh with real local fetches under interactive job
# control, including cancelling its watchdog. Caller options must be restored.
sleep 0.2
[[ -o monitor ]] || exit 1
REPOS_FETCH_INTERVAL=900
print 0 > "$REPOS_CACHE/fetch"
repos refresh || exit 1
[[ -o monitor ]] || exit 1
print passed > "$REPOS_CACHE/foreground-passed"
DRIVER
  REPOS_CACHE="$tmp/pty-cache" REPOS_FETCH_INTERVAL=9999999999 \
    script -q /dev/null zsh -fi "$tmp/pty-driver.zsh" \
    "$root/zsh/dot-config/zsh/repo-status.zsh" </dev/null > "$tmp/pty-output" 2>&1
  [[ -f $tmp/pty-cache/pty-passed && -f $tmp/pty-cache/foreground-passed ]] || {
    cat "$tmp/pty-output"; exit 1
  }
  if grep -Eq '\[[0-9]+\]|terminated' "$tmp/pty-output"; then
    cat "$tmp/pty-output"
    print -u2 'Interactive refresh leaked job notifications'
    exit 1
  fi
fi
# A detached submodule matching its parent's committed pin is not unknown.
parent="$tmp/submodule parent"
module="$parent/theme with spaces"
git init -q "$parent"
git -C "$parent" config user.name Test
git -C "$parent" config user.email test@example.com
git -C "$parent" -c protocol.file.allow=always submodule add -q "$tmp/remote" 'theme with spaces'
git -C "$parent" commit -qm 'pin submodule'
git -C "$module" checkout -q --detach
[[ $(_repos_scan_one "$module" no) == "-"$'\t'"$module" ]]
# Behind local branches are normal only for correctly pinned detached modules.
git -C "$module" branch -f master HEAD~1
[[ $(_repos_scan_one "$module" no) == "-"$'\t'"$module" ]]
git -C "$module" checkout -q master
[[ $(_repos_scan_one "$module" no) == "B"$'\t'"$module" ]]
git -C "$module" checkout -q --detach origin/master
# Dirty files and cached fetch failures must remain visible, even when behind.
print dirty > "$module/untracked"
[[ $(_repos_scan_one "$module" no) == "M"$'\t'"$module" ]]
rm "$module/untracked"
[[ $(_repos_scan_one "$module" no F) == "F"$'\t'"$module" ]]
# A different detached commit still reports both behind and unknown.
git -C "$module" checkout -q HEAD~1
[[ $(_repos_scan_one "$module" no) == "BQ"$'\t'"$module" ]]
git -C "$module" checkout -q origin/master
# Unpushed commits on another branch must not be suppressed.
ahead=$(print local | git -C "$module" -c user.name=Test -c user.email=test@example.com commit-tree 'HEAD^{tree}' -p HEAD)
git -C "$module" branch -f master "$ahead"
[[ $(_repos_scan_one "$module" no) == "U"$'\t'"$module" ]]
git -C "$module" branch -f master origin/master
# Even a correctly pinned submodule still reports untracked local branches.
git -C "$module" branch forgotten
[[ $(_repos_scan_one "$module" no) == "Q"$'\t'"$module" ]]
print 'repo-status tests passed'
