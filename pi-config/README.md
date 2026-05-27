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
  - `/plan` -> create plan and pause for confirmation
  - `/implement` -> requires planned phase
  - `/commit` -> requires implemented phase
  - `/push` -> requires committed phase + confirmation
  - confirms/guards `git commit` and `git push`

After installing/updating, run `/reload` inside pi.
