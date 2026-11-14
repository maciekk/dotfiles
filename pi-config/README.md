# pi-config

Stow package for global pi config.

## Install

From repo root:

```bash
./do-stow.sh pi-config
```

The wrapper Stows ordinary Pi configuration and copies the tracked `pi-usage.json` into place as a regular file, because that extension rejects symbolic links.

## Uninstall

```bash
stow -D -t "$HOME" --dotfiles --ignore='^pi-usage\.json$' pi-config
```

## Included

- `.pi/agent/extensions/statusline.ts`
  - stable, compact one-line token stats, context bar, Git counts, activity spinner, model, and thinking level
  - omits dollar costs for subscription usage
  - emphasizes remaining quota percentages from `pi-usage`; values above 30% stay neutral/dim, values above 15% and at or below 30% use warning colour without bold, and values at or below 15% use bold error colour
- `.pi/agent/extensions/update-help.ts`
  - Omarchy-only update reminders: update Pi with `mise upgrade pi`, and packages with `pi update --extensions`; `/update-help` recalls both commands anytime
  - checks in the background on startup and `/reload`; only shows a command when the corresponding update is confirmed (silent when current, offline, or checks fail)
  - uses `mise outdated pi --json` for Pi (respecting mise's release-age policy) and Pi's own package checker for extensions; these checks are additional to Pi's built-in notices
  - restart Pi after updating; do not install a second Pi via npm or the pi.dev installer
- `.pi/agent/settings.json`
  - enables `@narumitw/pi-usage`
  - uses fullscreen TUI mode so the mouse wheel always scrolls the transcript
  - follows terminal appearance with `"theme": "light/dark"` (restart pi after changing this setting externally); the shared zsh config overrides this per invocation with Omarchy's generated theme when available
- `.pi/agent/keybindings.json`
  - maps `Ctrl-P` / `Ctrl-N` to cursor-up / cursor-down and disables conflicting shortcuts
- `pi-usage.json`
  - tracked canonical configuration for `@narumitw/pi-usage`
  - keeps remaining percentages and reset countdowns while dropping redundant provider/window labels, for example `82% ↻4h59m | 96% ↻6d23h`
  - deployed as the private regular file `~/.pi/agent/pi-usage.json`, because the extension rejects symlinks

## Changing pi-usage settings

`pi-config/pi-usage.json` is the source of truth shared by all machines. Edit that tracked file whenever a setting should persist, then deploy the whole Pi configuration normally:

```bash
./do-stow.sh pi-config
```

Settings changed through `/usage` or `/fast` modify only the live file and are therefore temporary; the next deployment restores the tracked configuration. The obsolete Stow-tree path `.pi/agent/pi-usage.json` is ignored to avoid creating a second tracked source.

After deploying settings, run `/reload` inside Pi.
