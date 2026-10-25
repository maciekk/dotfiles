#!/bin/zsh
# Isolated local-remotes-only tests: zsh scripts/tests/repos-pull.zsh
set -eu
root=${0:A:h:h:h}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
export REPOS_ROOT="$tmp/src" REPOS_DOTFILES="$tmp/src/dotfiles" REPOS_CACHE="$tmp/cache"
mkdir -p "$HOME" "$REPOS_ROOT/a" "$REPOS_ROOT/b"
git config --global user.name Test
git config --global user.email test@example.com
git init -q --bare --initial-branch=main "$tmp/remote"
git clone -q "$tmp/remote" "$tmp/author" 2>/dev/null
print seed > "$tmp/author/file"
git -C "$tmp/author" add file
git -C "$tmp/author" commit -qm seed
git -C "$tmp/author" push -qu origin HEAD
for name in dotfiles 'tool with spaces' dirty untracked detached private diverged broken busy a/same b/same; do
  git clone -q "$tmp/remote" "$REPOS_ROOT/$name"
done
source "$root/zsh/dot-config/zsh/repo-status.zsh"

run() {
  local expected=$1 text=$2 actual=0
  shift 2
  repos pull "$@" > "$tmp/output" 2>&1 || actual=$?
  if [[ $actual != $expected ]] || ! grep -Fq -- "$text" "$tmp/output"; then
    cat "$tmp/output"
    print -u2 -- "Expected exit $expected and '$text'; got exit $actual"
    exit 1
  fi
}

# Publish an update, then pull both by name/path, deduplicating repeat arguments.
print update >> "$tmp/author/file"
git -C "$tmp/author" commit -qam update
git -C "$tmp/author" push -q
latest=$(git -C "$tmp/author" rev-parse HEAD)
run 0 'Summary: 2 pulled, 0 skipped, 0 failed' dotfiles "$REPOS_ROOT/tool with spaces" dotfiles
[[ $(git -C "$REPOS_DOTFILES" rev-parse HEAD) == $latest ]]
[[ $(git -C "$REPOS_ROOT/tool with spaces" rev-parse HEAD) == $latest ]]

run 2 'Usage: repos pull'
run 1 'ambiguous name' same
run 1 'not a discovered repository' nonexistent
run 0 'Summary: 1 pulled' "$REPOS_ROOT/a/same"
REPOS_EXCLUDE="$REPOS_ROOT/b"
run 1 'not a discovered repository' "$REPOS_ROOT/b/same"
REPOS_EXCLUDE=''

# Dirty repos must not fetch, stash, or update, even with autostash configured.
print local >> "$REPOS_ROOT/dirty/file"
print untracked > "$REPOS_ROOT/untracked/new"
git -C "$REPOS_ROOT/dirty" config rebase.autoStash true
git -C "$REPOS_ROOT/dirty" config merge.autoStash true
before=$(git -C "$REPOS_ROOT/dirty" rev-parse HEAD)
run 1 'Summary: 0 pulled, 2 skipped, 0 failed' dirty untracked
[[ $(git -C "$REPOS_ROOT/dirty" rev-parse HEAD) == $before ]]
[[ -z $(git -C "$REPOS_ROOT/dirty" stash list) ]]
grep -q local "$REPOS_ROOT/dirty/file"
[[ -e "$REPOS_ROOT/untracked/new" ]]

git -C "$REPOS_ROOT/detached" checkout -q --detach
run 1 'detached HEAD' detached
git -C "$REPOS_ROOT/private" branch --unset-upstream
run 1 'no available upstream' private
print bisect > "$REPOS_ROOT/busy/.git/BISECT_LOG"
run 1 'Git operation in progress' busy

# Config requesting rebase must not permit rewriting a divergent local branch.
print local >> "$REPOS_ROOT/diverged/file"
git -C "$REPOS_ROOT/diverged" commit -qam local
git -C "$REPOS_ROOT/diverged" config pull.rebase true
before=$(git -C "$REPOS_ROOT/diverged" rev-parse HEAD)
run 1 'pull failed' diverged
[[ $(git -C "$REPOS_ROOT/diverged" rev-parse HEAD) == $before ]]
[[ ! -e "$REPOS_ROOT/diverged/.git/MERGE_HEAD" ]]
[[ ! -e "$REPOS_ROOT/diverged/.git/rebase-merge" ]]

# A failure doesn't prevent later requested repos from being processed.
git -C "$REPOS_ROOT/broken" remote set-url origin "$tmp/nonexistent"
run 1 'Summary: 1 pulled, 1 skipped, 1 failed' broken detached 'tool with spaces'

# Discover linked worktrees by their .git file as well as regular checkouts.
git -C "$REPOS_DOTFILES" worktree add -qb linked "$REPOS_ROOT/linked" main
git -C "$REPOS_ROOT/linked" branch --set-upstream-to=origin/main >/dev/null
run 0 'Summary: 1 pulled' linked

print 'repos pull tests passed'
