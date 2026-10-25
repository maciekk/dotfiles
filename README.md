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
