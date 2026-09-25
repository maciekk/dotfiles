# pi-config

Stow package for global pi config.

## Install

From repo root:

```bash
stow -R -t $HOME --dotfiles pi-config
# or
./do-stow.sh pi-config
```

## Uninstall

```bash
stow -D -t $HOME --dotfiles pi-config
```

## Included

- `.pi/agent/extensions/statusline.ts`
  - stable, compact one-line token stats, context bar, Git counts, activity spinner, model, and thinking level
  - displays Codex 5-hour and weekly **used** budgets from the `pi-usage` status item
- `.pi/agent/settings.json`
  - enables `@narumitw/pi-usage` and the web-search package
- `.pi/agent/pi-usage.json`
  - configures budget values as used percentages and labels the windows as `5h` / `wk`

After installing/updating, run `/reload` inside pi.
