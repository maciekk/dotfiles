# dotfiles

For each "package" directory, run:
 `stow -R -t $HOME --dotfiles $PACKAGE`

Or, more conveniently:
  `./do-stow.sh $PACKAGE`

## Theme auto-switching

### Shared policy

Use **OS appearance as the source of truth**, rather than giving each tool its
own clock or sunrise/sunset schedule. On macOS, choose **System Settings →
Appearance → Auto** for automatic day/night switching, or Light/Dark to pin
all following applications. This is appearance switching, not Night Shift
(the separate display colour-temperature setting).

Tools can use different palettes, but should agree on light versus dark.
Prefer native OS/terminal appearance support; use a small adapter only when
needed. Keep machine-specific overrides local rather than changing shared
config defaults.

### Current setup

| Tool | Appearance source | Light / dark palettes | Configuration |
| --- | --- | --- | --- |
| Ghostty | macOS appearance, native switching | Catppuccin Latte / Catppuccin Frappe | `ghostty/dot-config/ghostty/config.ghostty` |
| tmux | macOS appearance, checked every 15 seconds while attached | Catppuccin Latte / Catppuccin Mocha | `tmux/dot-config/tmux/appearance.sh` and `theme-*.conf` |
| pi | Terminal appearance (following Ghostty) | Built-in `light` / `dark` | `pi-config/dot-pi/agent/settings.json` and live `~/.pi/agent/settings.json` |
| Powerlevel10k | Current Omarchy theme on Omarchy; macOS/tmux appearance elsewhere | Omarchy semantic palette or Latte/Frappe fallback | `zsh/dot-config/zsh/appearance.zsh` and `zsh/dot-p10k.zsh` |

**Ghostty:** the effective setting on this Mac is:

```ini
theme = light:Catppuccin Latte,dark:Catppuccin Frappe
```

Both `config` and `config.ghostty` exist in the Ghostty package, with different
theme settings. Check `ghostty +show-config` for the effective configuration
rather than assuming which file wins. To pin Ghostty independently, use a
single theme, e.g. `theme = Catppuccin Latte`, and reload its configuration.

**tmux:** the appearance helper reads `AppleInterfaceStyle` and selects Latte
or Mocha before plugins load. A silent status-bar job checks every 15 seconds;
it reloads `tmux.conf` only on a change, rebuilding Catppuccin's cached palette
and status modules. No daemon is installed. Auto defaults to light on non-macOS
systems; all sessions on a server share the palette.

Run inside tmux to set a persistent local override:

```sh
sh ~/.config/tmux/appearance.sh light
sh ~/.config/tmux/appearance.sh dark
sh ~/.config/tmux/appearance.sh auto
```

The selection lives in ignored `~/.config/tmux/theme-mode.local`. An existing
`theme.local.conf` takes precedence over these modes; remove that file to use
auto switching. See [tmux/README.md](tmux/README.md) for details.

**pi:** both the tracked and live settings select `"theme": "light/dark"`.
This switches pi's own UI palette with terminal appearance, not just its
inherited background. Restart pi after editing the saved setting externally.
For an explicit per-run override, use `pi --use-theme light/dark` (auto),
`pi --use-theme light`, or `pi --use-theme dark`; CLI overrides do not change
the saved preference. Use `/settings` for interactive theme selection.

Verify the loaded config before changing it: this Mac's live pi config is
not linked to the tracked package, and `/reload` does not install or link
repository files. See [pi-config/README.md](pi-config/README.md) for
installation instructions.

**Powerlevel10k:** on Omarchy, the prompt reads the resolved semantic colors
from the current theme, including legacy themes whose palette only defines ANSI
colors. It checks the Omarchy theme name at most every 15 seconds before a new
prompt and reloads when it changes. On other systems it follows macOS appearance
or tmux's selected mode, using Latte/Frappe neutral surfaces and soft Frappe
pastel accents.

Run in zsh to pin the prompt independently or restore automatic behaviour:

```sh
p10k-theme light
p10k-theme dark
p10k-theme auto
```

The selection lives in ignored `~/.config/p10k/theme-mode.local`. For local
palette changes, put Powerlevel10k assignments in
`~/.config/p10k/theme.local.zsh`; it is loaded after the tracked palette on
startup and every appearance reload, so repository updates cannot override it.
For example:

```zsh
typeset -g POWERLEVEL9K_DIR_BACKGROUND='#123456'
```

Open a new shell (or `source ~/.zshrc`) after installing the `zsh` package.

### Adding another themed tool

1. Identify its **actual loaded config**, including local overrides and Stow
   links; do not assume the tracked file is active.
2. Prefer native OS appearance detection. Terminal applications may instead
   follow the terminal's appearance notifications/background.
3. Define both light and dark palettes, plus a manual override and a way back
   to auto. Keep the OS responsible for scheduling.
4. If an adapter is necessary, refresh only when appearance changes and account
   for theme caches. Document polling intervals, platform fallbacks, and
   whether the setting affects one window or an entire server.
5. Test both directions, manual overrides, and restart/reload behaviour. Add
   the tool, config paths, and controls to the table above.

### Troubleshooting mismatched themes

- Check macOS Appearance first. `defaults read -g AppleInterfaceStyle` reports
  `Dark` in dark mode; a missing key normally means light mode.
- Check Ghostty's effective config with `ghostty +show-config`.
- In tmux, inspect `tmux show-option -gqv @appearance-current` and
  `tmux show-option -gqv @catppuccin_flavor`; check both local override files.
  After changing the config, run `tmux source-file ~/.config/tmux/tmux.conf`.
- In pi, check `/settings`, launch flags, and loaded extensions. Terminal
  background colours and pi's own theme can change independently.
- In zsh, inspect `$P10K_APPEARANCE`; run `p10k-theme auto` to remove a prompt
  override, then press Enter after tmux's next appearance check.

## Neovim

The `nvim` package is installed as `~/.config/nvim-maciek` so it can coexist
with Omarchy's config at `~/.config/nvim`:

```sh
./do-stow.sh nvim
NVIM_APPNAME=nvim-maciek nvim
```

When the `zsh` package is installed, `v` runs the latter command while `nvim`
continues to use Omarchy's LazyVim config. Neovim also isolates the associated
data, state, and cache directories under names ending in `nvim-maciek`.

## Repository publication indicator (zsh / Powerlevel10k)

The right prompt shows local unpublished work, even outside a Git repository:

```text
d:1↑ &:2↑3*
```

`d:` is this dotfiles checkout; `&:` is other working-tree repositories discovered
recursively under `~/src/` (including nested directories and Git worktrees).
Counts mean **repositories**, not commits/files; a repo can count in multiple
categories. Zero counts and empty groups disappear; clean means no segment.
The segment uses a pastel rosewater background with dark text to distinguish
it from the current-repository Git status.

| Symbol | Meaning |
| --- | --- |
| `↑` | Local branch ahead of its upstream |
| `*` | Uncommitted changes, including untracked files |
| `↓` | Local branch behind its upstream |
| `?` | Unknown: missing upstream, detached HEAD, Git error, or failed fetch |
| `~` | Remote information is stale / refresh in progress |
| `…` | Initial scan has not finished |

All local branches are checked, not just the current branch. Divergence shows
both arrows. Upstream comparisons are a useful publication heuristic, not proof
that a commit exists nowhere else. Intentionally private branches without an
upstream also show `?`. A submodule's detached HEAD is accepted when it matches
the commit pinned in its parent's HEAD. Behind-remote warnings are suppressed
for these pinned detached submodules; modifications, unpushed commits, fetch
failures, and missing-upstream warnings still apply.

Install with `./do-stow.sh zsh`, then open a new shell. Implementation lives in
`zsh/dot-config/zsh/repo-status.zsh`; `.zshrc` only sources it and p10k adds one
custom segment beside `context`. The indicator does not depend on SSH/context
visibility and does not replace the current-directory Git segment.

```sh
repos status   # cached per-repo details, local scan ages, and summary
repos refresh  # synchronous local rescan; also fetches if the fetch interval is due
repos pull dotfiles gemini-slurp  # explicit, clean-working-tree, fast-forward-only pulls
```

`repos pull REPO [REPO ...]` resolves unique directory names against freshly
discovered repositories, or accepts absolute paths to those repositories.
`dotfiles` also names the configured dotfiles checkout. Ambiguous names are
rejected with matching paths listed; exclusions apply to pull discovery too.
Quote names/paths containing spaces. No arguments means usage, **not pull all**.

Only the checked-out branch is pulled, unlike the indicator's all-branch scan.
Dirty repositories (including untracked files), detached HEADs, branches without
an available upstream, and repositories with an in-progress Git operation are
skipped. Pulls use `--ff-only --no-rebase --no-autostash`, overriding autostash
preferences: no automatic stash, merge commit, rebase, or force operation.
Divergence or network/authentication errors fail that pull without stopping the
remaining requested repositories. Explicit pulls use Git's normal credentials
and may prompt. Repeated arguments resolving to the same repo are deduplicated.

The final summary counts completed pulls (including already-up-to-date repos),
skips, and failures. Exit status is 0 only if all requested repositories were
pulled successfully, 1 for any skip/failure, and 2 for missing arguments.
The indicator catches up on its normal background scan intervals; `repos refresh`
requests an immediate rescan.

No cron or daemon: a pre-prompt hook reads cached data and launches a detached
worker when due. Dotfiles is checked every 15 seconds, other repos every 60
seconds, and remotes are fetched every 15 minutes **while shells are active**.
The next prompt picks up completed results; the worker never redraws your input.
Fetches suppress credential prompts and have a 30-second limit per repository.
No commits, pushes, pulls, checkouts, or working-tree changes are automated.

Each machine stores private cache files under
`${XDG_CACHE_HOME:-~/.cache}/repo-status`. Atomic replacement prevents partial
reads; a shared kernel-managed lock prevents duplicate workers and is released
on crashes. Explicit `repos refresh` reports an error if another worker holds
that lock, rather than silently leaving the cache unchanged. Background workers
ignore terminal job-control signals so they cannot get suspended by tty handling.
Fetch failures remain `?` until a successful retry; old remote state
is marked `~`. Large/offline repo collections can take time to refresh.

Optional machine-local settings, **before the module is sourced** in `.zshrc`
(or exported by your existing local environment setup):

```sh
export REPOS_ROOT="$HOME/src"
export REPOS_DOTFILES="$HOME/src/dotfiles"  # defaults to the module's checkout
export REPOS_EXCLUDE="$HOME/src/experiments:$HOME/src/vendor"
export REPOS_DOT_INTERVAL=15
export REPOS_SRC_INTERVAL=60
export REPOS_FETCH_INTERVAL=900
```

Exclusions are colon-separated absolute directories, including descendants;
dotfiles remains monitored separately. Discovery skips `.git` internals and
`node_modules`, and does not follow directory symlinks. Bare repositories and
paths containing tabs/newlines are not supported.

Tests (temporary repositories, no network):

```sh
zsh scripts/tests/repo-status.zsh
zsh scripts/tests/repos-pull.zsh
zsh scripts/tests/p10k-appearance.zsh
```
