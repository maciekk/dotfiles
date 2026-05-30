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
  - Workflow mode: `strict` or `fast` (default: `fast`)
  - `/plan` -> create plan and pause for confirmation
  - `/implement` -> requires planned phase in strict mode; allowed directly in fast mode
  - `/commit` -> requires implemented phase in strict mode; auto-recovers in fast mode
  - `/push` -> requires committed phase + explicit authorization (always)
  - `/status` -> show mode, phase, next commands, and lightweight change-size stats
  - `/reset` -> reset phase/authorizations to idle
  - fast mode adds lightweight change-size heuristics to nudge caution on larger changes while staying quiet on trivial ones
  - confirms/guards `git commit` and `git push` with actionable recovery hints

After installing/updating, run `/reload` inside pi.
