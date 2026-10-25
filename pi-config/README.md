# pi-config

Stow package for global pi config.

## Install

From repo root:

```bash
./do-stow.sh pi-config
```

The wrapper handles `pi-usage.json` specially because that extension rejects symbolic links.

## Uninstall

```bash
stow -D -t $HOME --dotfiles pi-config
```

## Included

- `.pi/agent/extensions/statusline.ts`
  - stable, compact one-line token stats, context bar, Git counts, activity spinner, model, and thinking level
  - displays Codex 5-hour and weekly **remaining** budgets from the `pi-usage` status item; `↓` indicates quota counting down (e.g. `5h↓90% wk↓75%`)
- `.pi/agent/settings.json`
  - enables `@narumitw/pi-usage` and the web-search package
  - uses fullscreen TUI mode so the mouse wheel always scrolls the transcript
  - follows terminal appearance with `"theme": "light/dark"` (restart pi after changing this setting externally)
- `.pi/agent/keybindings.json`
  - maps `Ctrl-P` / `Ctrl-N` to cursor-up / cursor-down and disables conflicting shortcuts
- `.pi/agent/pi-usage.json`
  - reserves a settings file for `pi-usage`; the installed extension reports remaining percentages (it does not support `codexStatusPercentage`)
  - installed as a regular private file because `pi-usage` rejects symbolic links

After installing/updating, run `/reload` inside pi. Use `./do-stow.sh pi-config` rather than invoking Stow directly so `pi-usage.json` is copied correctly.
