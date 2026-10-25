# Local repository publication indicator for Powerlevel10k.
# Also executable: zsh repo-status.zsh {status|refresh|pull REPO...|worker}

zmodload zsh/datetime
zmodload zsh/system
zmodload zsh/zselect
: ${REPOS_ROOT:=$HOME/src}
: ${REPOS_DOTFILES:=${${(%):-%x}:A:h:h:h:h}}
: ${REPOS_CACHE:=${XDG_CACHE_HOME:-$HOME/.cache}/repo-status}
: ${REPOS_DOT_INTERVAL:=15}
: ${REPOS_SRC_INTERVAL:=60}
: ${REPOS_FETCH_INTERVAL:=900}
# Colon-separated absolute directory paths; excluded along with their descendants.
: ${REPOS_EXCLUDE:=}
typeset -g _repos_module=${${(%):-%x}:A}
typeset -g _repos_text='…'

_repos_excluded() {
  emulate -L zsh
  local entry
  for entry in ${(s.:.)REPOS_EXCLUDE}; do
    [[ -n $entry ]] || continue
    entry=${entry:A}
    [[ -n $entry && ( $1 == $entry || $1 == $entry/* ) ]] && return 0
  done
  return 1
}

_repos_fetch() {
  emulate -L zsh
  # Foreground `repos refresh` also calls this from an interactive shell.
  # Keep its fetch/watchdog jobs private; emulate -L restores caller options.
  unsetopt monitor notify
  # No credential prompts. Bound network attempts so an offline host cannot
  # monopolize the shared worker lock indefinitely.
  GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never \
    GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' \
    git -C "$1" -c credential.interactive=false fetch --all --quiet &
  local fetch_pid=$!
  # Disown the watchdog so cancelling it cannot queue a "terminated" notice
  # that appears after the caller's interactive options are restored.
  ( zselect -t 3000; kill -TERM $fetch_pid 2>/dev/null ) &!
  local timer_pid=$!
  wait $fetch_pid
  local result=$?
  kill $timer_pid 2>/dev/null
  return $result
}

# A submodule is normally detached at the commit recorded by its parent.
_repos_pinned_submodule() {
  emulate -L zsh
  local repo=${1:A} parent relative pinned head
  parent=$(git -C "$repo" rev-parse --show-superproject-working-tree 2>/dev/null) || return 1
  [[ -n $parent ]] || return 1
  parent=${parent:A}
  relative=${repo#"$parent"/}
  pinned=$(git -C "$parent" rev-parse --verify "HEAD:$relative" 2>/dev/null) || return 1
  head=$(git -C "$repo" rev-parse --verify HEAD 2>/dev/null) || return 1
  [[ $head == $pinned ]]
}

_repos_scan_one() {
  emulate -L zsh
  local repo=$1 fetch_due=$2 flags='' branch upstream counts dirty remotes
  local -a pair
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    print -r -- "Q"$'\t'"$repo"
    return
  fi
  if [[ $fetch_due == yes ]]; then
    remotes=$(git -C "$repo" remote)
    if [[ -n $remotes ]] && ! _repos_fetch "$repo"; then
      flags+=F
    fi
  else
    # Preserve a failed remote check until the next fetch attempt.
    [[ $3 == *F* ]] && flags+=F
  fi
  dirty=$(git --no-optional-locks -C "$repo" status --porcelain --untracked-files=normal 2>/dev/null) || flags+=Q
  [[ -n $dirty ]] && flags+=M
  # Inspect every local branch, not just the checked-out branch.
  local branches=$(git -C "$repo" for-each-ref --format='%(refname)' refs/heads)
  [[ -z $branches ]] && flags+=Q
  for branch in ${(f)branches}; do
    upstream=$(git -C "$repo" rev-parse --symbolic-full-name "${branch#refs/heads/}@{upstream}" 2>/dev/null)
    if [[ -z $upstream ]]; then
      [[ $flags == *Q* ]] || flags+=Q
      continue
    fi
    counts=$(git -C "$repo" rev-list --left-right --count "$branch...$upstream" 2>/dev/null) || {
      [[ $flags == *Q* ]] || flags+=Q
      continue
    }
    pair=(${=counts})
    (( pair[1] > 0 )) && [[ $flags != *U* ]] && flags+=U
    (( pair[2] > 0 )) && [[ $flags != *B* ]] && flags+=B
  done
  # A detached submodule follows its parent's pin, not the remote's latest
  # commit. Behind branches are expected there; preserve all other warnings.
  if ! git -C "$repo" symbolic-ref -q HEAD >/dev/null; then
    if _repos_pinned_submodule "$repo"; then
      flags=${flags//B/}
    else
      [[ $flags == *Q* ]] || flags+=Q
    fi
  fi
  print -r -- "${flags:--}"$'\t'"$repo"
}

# NUL-delimited working-tree paths, shared by scanning and explicit commands.
_repos_candidates() {
  emulate -L zsh
  local repo
  if [[ $1 == dot ]]; then
    print -rn -- "$REPOS_DOTFILES"$'\0'
  elif [[ -d $REPOS_ROOT ]]; then
    while IFS= read -r -d '' repo; do
      repo=${repo:h:A}
      [[ $repo == ${REPOS_DOTFILES:A} || $repo == ${REPOS_DOTFILES:A}/* ]] && continue
      _repos_excluded "$repo" && continue
      print -rn -- "$repo"$'\0'
    done < <(find "$REPOS_ROOT" \( -name node_modules -o -name .git \) -prune -name .git -print0 2>/dev/null)
  fi
}

_repos_scan_group() {
  emulate -L zsh
  local group=$1 fetch_due=$2 repo flags old_repo previous
  local -a candidates
  local -A old
  if [[ -r $REPOS_CACHE/$group ]]; then
    while IFS=$'\t' read -r flags old_repo; do
      [[ -n $old_repo ]] && old[$old_repo]=$flags
    done < "$REPOS_CACHE/$group"
  fi
  while IFS= read -r -d '' repo; do
    candidates+=("$repo")
  done < <(_repos_candidates "$group")
  {
    print -r -- "$EPOCHSECONDS"
    for repo in "${candidates[@]}"; do
      # Cache records are tab/newline delimited, never evaluated as shell code.
      [[ $repo == *$'\t'* || $repo == *$'\n'* ]] && continue
      _repos_scan_one "$repo" "$fetch_due" "${old[$repo]:-}"
    done
  } >| "$REPOS_CACHE/$group.tmp.$$" &&
    mv -f -- "$REPOS_CACHE/$group.tmp.$$" "$REPOS_CACHE/$group"
}

_repos_worker() {
  emulate -L zsh
  umask 077
  mkdir -p -- "$REPOS_CACHE" || return
  local lockfd last=0 dot=0 src=0 fetch_due=no
  # Kernel-managed lock: automatically released even when the worker crashes.
  : >> "$REPOS_CACHE/lock"
  if ! zsystem flock -t 0 -f lockfd "$REPOS_CACHE/lock" 2>/dev/null; then
    if [[ ${1:-} == force ]]; then
      print -u2 'repos: refresh busy (another worker holds the cache lock); cache was not updated'
      return 1
    fi
    return 0
  fi
  [[ -r $REPOS_CACHE/fetch ]] && read -r last < "$REPOS_CACHE/fetch"
  [[ -r $REPOS_CACHE/dot ]] && read -r dot < "$REPOS_CACHE/dot"
  [[ -r $REPOS_CACHE/src ]] && read -r src < "$REPOS_CACHE/src"
  (( EPOCHSECONDS - last >= REPOS_FETCH_INTERVAL )) && fetch_due=yes
  # Publish local results before any potentially slow network operations.
  if [[ ${1:-} == force ]] || (( EPOCHSECONDS - dot >= REPOS_DOT_INTERVAL )); then
    _repos_scan_group dot no
  fi
  if [[ ${1:-} == force ]] || (( EPOCHSECONDS - src >= REPOS_SRC_INTERVAL )); then
    _repos_scan_group src no
  fi
  if [[ $fetch_due == yes ]]; then
    _repos_scan_group dot yes
    _repos_scan_group src yes
    print -r -- "$EPOCHSECONDS" >| "$REPOS_CACHE/fetch.tmp.$$"
    mv -f -- "$REPOS_CACHE/fetch.tmp.$$" "$REPOS_CACHE/fetch"
  fi
  zsystem flock -u $lockfd
}

_repos_read() {
  emulate -L zsh
  local group stamp flags repo label text='' part
  local -i u m b q
  for group in dot src; do
    if [[ ! -r $REPOS_CACHE/$group ]]; then
      text+=' …'
      continue
    fi
    u=0 m=0 b=0 q=0
    {
      read -r stamp
      while IFS=$'\t' read -r flags repo; do
        [[ $flags == *U* ]] && (( ++u ))
        [[ $flags == *M* ]] && (( ++m ))
        [[ $flags == *B* ]] && (( ++b ))
        [[ $flags == *[QF]* ]] && (( ++q ))
      done
    } < "$REPOS_CACHE/$group"
    part=''
    (( u )) && part+="${u}↑"
    (( m )) && part+="${m}*"
    (( b )) && part+="${b}↓"
    (( q )) && part+="${q}?"
    # Stale remote information must not masquerade as a fresh clean result.
    local fetched=0
    [[ -r $REPOS_CACHE/fetch ]] && read -r fetched < "$REPOS_CACHE/fetch"
    (( EPOCHSECONDS - fetched > REPOS_FETCH_INTERVAL + 60 )) && part+='~'
    label=d
    [[ $group == src ]] && label='&'
    [[ -n $part ]] && text+=" $label:$part"
  done
  _repos_text=${text# }
}

_repos_precmd() {
  emulate -L zsh
  _repos_read
  local stamp=0
  [[ -r $REPOS_CACHE/dot ]] && read -r stamp < "$REPOS_CACHE/dot"
  if (( EPOCHSECONDS - stamp >= REPOS_DOT_INTERVAL )); then
    # Use a fresh noninteractive shell, not a fork of the interactive shell:
    # inherited job-control/terminal state can stop nested background jobs.
    REPOS_ROOT="$REPOS_ROOT" REPOS_DOTFILES="$REPOS_DOTFILES" \
      REPOS_CACHE="$REPOS_CACHE" REPOS_EXCLUDE="$REPOS_EXCLUDE" \
      REPOS_DOT_INTERVAL="$REPOS_DOT_INTERVAL" REPOS_SRC_INTERVAL="$REPOS_SRC_INTERVAL" \
      REPOS_FETCH_INTERVAL="$REPOS_FETCH_INTERVAL" \
      zsh -f "$_repos_module" worker </dev/null >/dev/null 2>&1 &!
  fi
}

prompt_repo_status() {
  emulate -L zsh
  [[ -n $_repos_text ]] && p10k segment -b '#f2d5cf' -f '#303446' -t "$_repos_text"
}

_repos_pull() {
  emulate -L zsh
  if (( ! $# )); then
    print -u2 'Usage: repos pull REPO [REPO ...] (unique names or absolute paths)'
    return 2
  fi
  local repo arg group branch dirty operation operation_path
  local -a candidates matches
  local -A seen
  local -i pulled=0 skipped=0 failed=0 busy=0
  for group in dot src; do
    while IFS= read -r -d '' repo; do
      candidates+=("${repo:A}")
    done < <(_repos_candidates "$group")
  done
  candidates=("${(@u)candidates}")
  for arg in "$@"; do
    matches=()
    for repo in "${candidates[@]}"; do
      if [[ $arg == /* ]]; then
        [[ ${arg:A} == $repo ]] && matches+=("$repo")
      elif [[ $arg == ${repo:t} || ( $arg == dotfiles && $repo == ${REPOS_DOTFILES:A} ) ]]; then
        matches+=("$repo")
      fi
    done
    if (( ${#matches} != 1 )); then
      if (( ${#matches} )); then
        print -r -- "FAIL $arg: ambiguous name; use an absolute path:"
        printf '  %s\n' "${matches[@]}"
      else
        print -r -- "FAIL $arg: not a discovered repository"
      fi
      (( ++failed ))
      continue
    fi
    repo=$matches[1]
    [[ -n ${seen[$repo]:-} ]] && continue
    seen[$repo]=1
    if [[ $(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) != $repo ]]; then
      print -r -- "FAIL $repo: not a working-tree root"
      (( ++failed )); continue
    fi
    branch=$(git -C "$repo" symbolic-ref -q --short HEAD) || {
      print -r -- "SKIP $repo: detached HEAD"
      (( ++skipped )); continue
    }
    if ! git -C "$repo" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
      print -r -- "SKIP $repo: $branch has no available upstream"
      (( ++skipped )); continue
    fi
    dirty=$(git --no-optional-locks -C "$repo" status --porcelain --untracked-files=normal) || {
      print -r -- "FAIL $repo: cannot inspect working tree"
      (( ++failed )); continue
    }
    if [[ -n $dirty ]]; then
      print -r -- "SKIP $repo: uncommitted changes (including untracked files)"
      (( ++skipped )); continue
    fi
    busy=0
    for operation in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer BISECT_LOG; do
      operation_path=$(git -C "$repo" rev-parse --path-format=absolute --git-path "$operation")
      [[ -e $operation_path ]] && busy=1
    done
    if (( busy )); then
      print -r -- "SKIP $repo: Git operation in progress"
      (( ++skipped )); continue
    fi
    print -r -- "PULL $repo ($branch)"
    # Override local autostash/rebase preferences: never hide changes or rewrite
    # commits just to reconcile a repository. Git itself rejects divergence.
    if git -C "$repo" -c rebase.autoStash=false -c merge.autoStash=false \
        -c pull.autostash=false pull --ff-only --no-rebase --no-autostash; then
      (( ++pulled ))
    else
      print -r -- "FAIL $repo: pull failed; no automatic reconciliation attempted"
      (( ++failed ))
    fi
  done
  print -r -- "Summary: $pulled pulled, $skipped skipped, $failed failed"
  (( skipped == 0 && failed == 0 ))
}

repos() {
  emulate -L zsh
  local group stamp flags repo
  case ${1:-status} in
    pull)
      shift
      _repos_pull "$@"
      ;;
    refresh)
      _repos_worker force || return
      _repos_read
      ;;
    status)
      print -r -- 'FLAGS  REPOSITORY  (↑ unpushed, * modified, ↓ behind, ? unknown, ~ stale fetch)'
      for group in dot src; do
        [[ -r $REPOS_CACHE/$group ]] || { print -r -- "$group: not scanned; run repos refresh"; continue; }
        {
          read -r stamp
          print -r -- "$group: checked $(( EPOCHSECONDS - stamp ))s ago"
          while IFS=$'\t' read -r flags repo; do
            [[ $flags == - ]] && continue
            flags=${flags//U/↑}; flags=${flags//M/*}; flags=${flags//B/↓}; flags=${flags//F/Q}; flags=${flags//QQ/Q}; flags=${flags//Q/?}
            print -r -- "$flags  $repo"
          done
        } < "$REPOS_CACHE/$group"
      done
      _repos_read
      print -r -- "Summary: ${_repos_text:-clean}"
      ;;
    *) print -u2 'Usage: repos [status|refresh|pull REPO ...]'; return 2 ;;
  esac
}

if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then
  case $1 in
    worker)
      # No terminal interaction is needed in a worker. Process substitutions in
      # a background process group can otherwise stop the entire group on tty
      # job-control signals, leaving its cache lock held indefinitely.
      trap '' TTIN TTOU
      unsetopt monitor
      _repos_worker "${2:-}"
      ;;
    *) repos "$@" ;;
  esac
else
  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd _repos_precmd
  add-zsh-hook precmd _repos_precmd
fi
