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
print 'repo-status tests passed'
