# dotfiles

For each "package" directory, run:
 `stow -R -t $HOME --dotfiles $PACKAGE`

Or, more conveniently:
  `./do-stow.sh $PACKAGE`

## AeroSpace (macOS)

`aerospace/dot-aerospace.toml` is based on the default template bundled with
AeroSpace 0.21.3-Beta at
`/Applications/AeroSpace.app/Contents/Resources/default-config.toml`.
Workspaces are limited to 1–9 and 0: Alt-number switches workspace and
Alt-Shift-number moves a window there. Letter-based workspace bindings are
removed; Alt-f toggles AeroSpace fullscreen. The default h/j/k/l focus and
movement bindings remain.

Install the symlink at `~/.aerospace.toml`:

```sh
./do-stow.sh aerospace
```

If that path already contains a config, back it up and reconcile it before
stowing. Edit `aerospace/dot-aerospace.toml` to customize your configuration;
edits through the home-directory symlink also update the repository file.
With AeroSpace running, apply changes using:

```sh
aerospace reload-config
```

The template leaves start-at-login and automatic config reloading disabled.
It also reserves 32pt at the top of external displays for SketchyBar and
notifies the bar on workspace changes (see below). The built-in display uses
no additional top gap because macOS already reserves 32pt for the notch.

## SketchyBar (macOS)

A top-mounted AeroSpace dashboard with the native menu bar set to auto-hide.
Reveal the native bar at the top edge for application menus and Ice-managed
status icons. SketchyBar stays above app windows but below the revealed native
menu bar (`topmost=window`). The bar uses a pinned near-black charcoal palette,
a compact 28pt height, and flat items without pill backgrounds. It shows:

- Occupied workspaces plus the active workspace, with clickable workspace
  numbers/names and full lowercase app names (e.g. `firefox`, `ghostty`,
  `obsidian`). Empty inactive workspaces hide; system statuses retain their
  Nerd Font icons.
- Focused app/window title (truncated), volume, battery/charging, and clock.
- Blue active-workspace number; text is 90% white (`#e6e6e6`), and low battery
  gets a warning color.

Install dependencies (the font is already installed on this Mac):

```sh
brew tap FelixKratz/formulae
brew install sketchybar jq
brew install --cask font-jetbrains-mono-nerd-font
```

Back up any existing `~/.config/sketchybar` directory before deploying:

```sh
./do-stow.sh sketchybar
brew services start sketchybar
sketchybar --reload
aerospace reload-config
```

Enable native menu-bar auto-hide in System Settings (search for “automatically
hide and show the menu bar” and select Always), or apply it on this Mac with:

```sh
osascript -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to true'
```

This preference is machine-local, not applied automatically by Stow. The focused
window title sits on the left rather than beneath the MacBook's camera notch.

Configuration lives in `sketchybar/dot-config/sketchybar/`:

- `sketchybarrc`: layout, fonts, event subscriptions, and click actions.
- `colors.sh`: pinned dark charcoal palette (independent of macOS appearance).
- `plugins/aerospace.sh`: workspace reconciliation and window title.
- `plugins/window-title.jq`: title formatting; strips Obsidian's vault/version
  suffix while preserving the document name. All titles are capped at 55 chars.
- `plugins/app-labels.sh`: full application names, converted to lowercase.
- `plugins/status.sh`: volume, battery, and clock. Click volume to open Sound
  settings.

Workspace switches update immediately through AeroSpace's
`exec-on-workspace-change` callback. App lists/window titles refresh every five
seconds, with extra updates when the front app changes. Unchanged workspace
polls are read-only; actual changes are batched, and items are only reordered
when new ones are added to avoid flicker. Status refreshes every 30 seconds, and volume also reacts to volume-change events. Named workspaces
are discovered automatically; numeric keyboard bindings are unchanged. No
screen-recording permission is needed for this configuration (it does not mirror
native menu-bar items).

The bar is foregrounded so tiled windows cannot obscure it; the AeroSpace top
gap on external displays is 28pt for the bar plus 4pt breathing room. The
built-in display has no extra gap, since macOS already excludes the 32pt notch
area from its usable frame. Native macOS fullscreen hides the bar. On multiple displays, each bar shows the same global workspace list.

After editing, run `sketchybar --reload`. To stop using it:

```sh
brew services stop sketchybar
```

Also restore `gaps.outer.top = 0` in `aerospace/dot-aerospace.toml` and run
`aerospace reload-config` to reclaim the reserved space. To restore the always
visible native menu bar, disable auto-hide in System Settings or run
`osascript -e 'tell application "System Events" to tell dock preferences to set autohide menu bar to false'`. The original demo
configuration was backed up outside the repo at
`~/.config/sketchybar.backup-20261107-120854`.

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
config defaults. SketchyBar is an intentional exception: its charcoal palette
is pinned dark by preference, to blend with the laptop bezel.

### Current setup

| Tool | Appearance source | Light / dark palettes | Configuration |
| --- | --- | --- | --- |
| Ghostty | macOS appearance, native switching | Catppuccin Latte / Catppuccin Frappe | `ghostty/dot-config/ghostty/config.ghostty` |
| tmux | macOS appearance, checked every 15 seconds while attached | Catppuccin Latte / Catppuccin Mocha | `tmux/dot-config/tmux/appearance.sh` and `theme-*.conf` |
| pi | Omarchy palette when available; terminal appearance elsewhere | Omarchy-generated theme / built-in `light` and `dark` | `pi-config/dot-pi/agent/settings.json` and conditional alias in `zsh/dot-zshrc` |
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

**pi:** the tracked setting selects `"theme": "light/dark"`, which switches
pi's own UI palette with terminal appearance on macOS. On an Omarchy system,
the shared zsh config detects Omarchy and its generated `omarchy-system` theme,
then aliases `pi` to `pi --use-theme omarchy-system`. The command-line override
wins without rewriting the stowed `settings.json`, so the Mac keeps its own
automatic light/dark behavior. Omarchy refreshes the generated theme whenever
its system theme changes.

For an explicit per-run override, use `command pi --use-theme light/dark`
(auto), `command pi --use-theme light`, or `command pi --use-theme dark`;
`command` bypasses the Omarchy zsh alias and CLI overrides do not change the
saved preference. Use `/settings` only for shared preferences: changing the
theme there writes the shared stowed file when it is linked.

Verify the loaded config before changing it: `/reload` does not install or link
repository files. See [pi-config/README.md](pi-config/README.md) for
installation instructions.

**Pi installation on Omarchy:** this machine deliberately uses Omarchy's
mise-managed Pi rather than a separate npm or `pi.dev` installer. The global
mise config at `~/.config/mise/config.toml` requests `pi = "latest"`, and `pi`
resolves to `~/.local/share/mise/installs/pi/latest/pi/pi`. Omarchy's updater
runs `mise up`, so normal `omarchy update` runs and manual Pi upgrades operate
on the same installation instead of creating competing executables.

If Pi reports that a newer release is available before Omarchy has installed
it, update that same managed installation with:

```sh
MISE_MINIMUM_RELEASE_AGE=0 mise upgrade --global pi
```

Start a new Pi session afterwards and check `pi --version`. Do not also install
Pi globally with npm or the `pi.dev` shell installer: either can put another
`pi` earlier in `PATH`, bypassing the Omarchy/mise-managed version. Mise's
`upgrade.auto_prune = false` setting keeps the old executable available while
an already-running Pi session finishes.

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
