# dotfiles

For each "package" directory, run:
 `stow -R -t $HOME --dotfiles $PACKAGE`

Or, more conveniently:
  `./do-stow.sh $PACKAGE`

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
