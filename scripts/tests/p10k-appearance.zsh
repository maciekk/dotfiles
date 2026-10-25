#!/bin/zsh
# Test reload integration without changing OS appearance or local overrides.
set -eu
root=${0:A:h:h:h}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config"
ln -s "$root/zsh/dot-p10k.zsh" "$HOME/.p10k.zsh"
source "$root/zsh/dot-config/zsh/appearance.zsh"
autoload -Uz add-zsh-hook
add-zsh-hook precmd p10k_appearance_check
# Mock detection and the p10k API, but exercise the real polling and config reload.
typeset simulated=light
_p10k_appearance_select() { typeset -g P10K_APPEARANCE=$simulated; }
p10k() { return 0; }
for simulated in light dark light; do
  _p10k_appearance_last_check=0
  P10K_APPEARANCE=previous
  p10k_appearance_check
  [[ $P10K_APPEARANCE == $simulated ]]
  # Pastel accents and dark ink are consistent; neutral surfaces still switch.
  [[ $POWERLEVEL9K_DIR_BACKGROUND == '#8caaee' ]]
  [[ $POWERLEVEL9K_DIR_FOREGROUND == '#303446' ]]
  [[ $POWERLEVEL9K_VCS_CLEAN_BACKGROUND == '#a6d189' ]]
  [[ $POWERLEVEL9K_VCS_MODIFIED_BACKGROUND == '#e5c890' ]]
  [[ $POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND == '#303446' ]]
  [[ $POWERLEVEL9K_VIRTUALENV_FOREGROUND == '#303446' ]]
  if [[ $simulated == light ]]; then
    [[ $POWERLEVEL9K_OS_ICON_BACKGROUND == '#ccd0da' ]]
  else
    [[ $POWERLEVEL9K_OS_ICON_BACKGROUND == '#414559' ]]
  fi
  [[ ${precmd_functions[(r)p10k_appearance_check]} == p10k_appearance_check ]]
done
# Within the polling interval, don't change mode or reload the config.
simulated=dark
p10k_appearance_check || true
[[ $P10K_APPEARANCE == light ]]
print 'p10k appearance integration tests passed'
