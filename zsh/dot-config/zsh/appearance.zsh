# Powerlevel10k appearance selection. Source this before ~/.p10k.zsh.
# macOS Appearance is authoritative in auto mode; inside tmux, use tmux's
# selected appearance so the prompt and status line remain in sync.

: ${XDG_CONFIG_HOME:=$HOME/.config}
typeset -g P10K_APPEARANCE P10K_THEME_SIGNATURE
integer -g _p10k_appearance_last_check=0

_p10k_appearance_select() {
  local mode=auto appearance=light tmux_appearance omarchy_theme
  local mode_file="$XDG_CONFIG_HOME/p10k/theme-mode.local"
  local omarchy_theme_file="$HOME/.local/state/omarchy/current/theme.name"

  [[ -r $omarchy_theme_file ]] && IFS= read -r omarchy_theme < "$omarchy_theme_file"

  [[ -r $mode_file ]] && IFS= read -r mode < "$mode_file"
  case $mode in
    light|dark) appearance=$mode ;;
    auto)
      if [[ -n $omarchy_theme ]] && (( $+commands[omarchy-theme-color] )); then
        if [[ $omarchy_theme == $P10K_THEME_SIGNATURE && $P10K_APPEARANCE == (light|dark) ]]; then
          appearance=$P10K_APPEARANCE
        else
          appearance=$(omarchy-theme-color mode 2>/dev/null)
          [[ $appearance == (light|dark) ]] || appearance=dark
        fi
      else
        if [[ -n ${TMUX:-} ]] && (( $+commands[tmux] )); then
          tmux_appearance=$(tmux show-option -gqv @appearance-current 2>/dev/null)
        fi
        case $tmux_appearance in
          light|dark) appearance=$tmux_appearance ;;
          *)
            if [[ $(uname -s) == Darwin ]] &&
               [[ $(defaults read -g AppleInterfaceStyle 2>/dev/null) == Dark ]]; then
              appearance=dark
            fi
            ;;
        esac
      fi
      ;;
    *)
      print -u2 "Invalid p10k theme mode in $mode_file: $mode"
      return 2
      ;;
  esac

  typeset -g P10K_APPEARANCE=$appearance
  typeset -g P10K_THEME_SIGNATURE=$omarchy_theme
}

p10k_appearance_check() {
  zmodload -F zsh/datetime p:EPOCHSECONDS 2>/dev/null || return
  local -i now=$EPOCHSECONDS
  (( now - _p10k_appearance_last_check >= 15 )) || return
  _p10k_appearance_last_check=$now

  local previous=$P10K_APPEARANCE previous_theme=$P10K_THEME_SIGNATURE
  _p10k_appearance_select || return
  [[ $P10K_APPEARANCE == $previous && $P10K_THEME_SIGNATURE == $previous_theme ]] ||
    source "$HOME/.p10k.zsh"
}

# Pin this prompt independently, or return it to the shared automatic policy.
p10k-theme() {
  local mode=${1:-}
  case $mode in
    auto|light|dark) ;;
    *) print -u2 'Usage: p10k-theme {auto|light|dark}'; return 2 ;;
  esac

  local mode_file="$XDG_CONFIG_HOME/p10k/theme-mode.local"
  mkdir -p -- ${mode_file:h} || return
  print -r -- $mode >| $mode_file || return
  _p10k_appearance_select || return
  _p10k_appearance_last_check=0
  [[ ! -r $HOME/.p10k.zsh ]] || source "$HOME/.p10k.zsh"
}

_p10k_appearance_select
