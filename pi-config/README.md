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
  - emphasizes remaining quota percentages from `pi-usage`; values at or below 30% are yellow and values at or below 10% are red
- `.pi/agent/settings.json`
  - enables `@narumitw/pi-usage` and the web-search package
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
