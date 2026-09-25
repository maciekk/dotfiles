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
  - keeps the standard location, usage, context, model, and thinking-level information
  - shows the model in bold white and thinking levels up to `medium` in green
  - highlights `high` thinking with the warning colour and `xhigh`/`max` with the error colour
  - emphasizes usage values, shows the latest prompt's cache hit rate, and colour-codes context pressure
  - shows staged, unstaged, and untracked Git counts plus an activity spinner

After installing/updating, run `/reload` inside pi.
