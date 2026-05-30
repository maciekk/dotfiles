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

- `.pi/agent/extensions/checkpoints.ts`
  - Workflow mode: `strict` or `flexible` (default: `flexible`)
  - `/plan` -> create plan and pause for confirmation
  - `/implement` -> requires planned phase in strict mode; allowed directly in flexible mode
  - `/commit` -> requires implemented phase in strict mode; auto-recovers in flexible mode
  - `/push` -> requires committed phase + explicit authorization
  - `/status` -> show mode, current phase, and next commands
  - `/reset` -> reset phase/authorizations to idle
  - confirms/guards `git commit` and `git push` with actionable recovery hints

After installing/updating, run `/reload` inside pi.
