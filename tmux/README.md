# tmux

## Appearance

By default, tmux follows macOS Appearance: light uses Catppuccin Latte, dark
uses Mocha. On other operating systems, auto defaults to light. Configure the
macOS schedule in System Settings → Appearance → Auto.

The status bar checks every 15 seconds while attached and reloads `tmux.conf`
only when the desired appearance changes. Reloading rebuilds Catppuccin's
cached palette and status modules. No background daemon is installed.

Persistent, machine-local overrides (run inside tmux):

```sh
sh ~/.config/tmux/appearance.sh light
sh ~/.config/tmux/appearance.sh dark
sh ~/.config/tmux/appearance.sh auto
```

The mode is stored in ignored `~/.config/tmux/theme-mode.local`. All sessions
on a tmux server share the selected palette. Existing `theme.local.conf` files
still take precedence; remove that file to enable automatic selection or the
mode commands above.

After installing/updating this package, reload once:

```sh
tmux source-file ~/.config/tmux/tmux.conf
```
