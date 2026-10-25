#!/bin/zsh
# Test reload integration without changing OS appearance or local overrides.
set -eu
root=${0:A:h:h:h}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config"
ln -s "$root/zsh/dot-p10k.zsh" "$HOME/.p10k.zsh"
source "$root/zsh/dot-config/zsh/appearance.zsh"
source "$root/zsh/dot-config/zsh/repo-status.zsh"
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
  [[ ${POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[(r)repo_status]} == repo_status ]]
  (( $+functions[prompt_repo_status] ))
  [[ ${precmd_functions[(r)_repos_precmd]} == _repos_precmd ]]
  [[ ${precmd_functions[(r)p10k_appearance_check]} == p10k_appearance_check ]]
done
# Within the polling interval, don't change mode or reload the config.
simulated=dark
p10k_appearance_check || true
[[ $P10K_APPEARANCE == light ]]
# Omarchy's semantic colors replace the fallback palette when its current theme is available.
mkdir -p "$HOME/.local/state/omarchy/current/theme" "$HOME/bin"
: > "$HOME/.local/state/omarchy/current/theme/colors.toml"
cat > "$HOME/bin/omarchy-theme-color" <<'EOF'
#!/bin/sh
cat <<'COLORS'
background	#101010
foreground	#eeeeee
lighter_background	#303030
blue	#4455aa
green	#55aa44
yellow	#aaaa44
red	#aa4455
COLORS
EOF
chmod +x "$HOME/bin/omarchy-theme-color"
path=("$HOME/bin" $path)
rehash
source "$HOME/.p10k.zsh"
[[ $POWERLEVEL9K_OS_ICON_BACKGROUND == '#303030' ]]
[[ $POWERLEVEL9K_DIR_BACKGROUND == '#4455aa' ]]
[[ $POWERLEVEL9K_DIR_FOREGROUND == '#101010' ]]
[[ $POWERLEVEL9K_VCS_CLEAN_BACKGROUND == '#55aa44' ]]
[[ $POWERLEVEL9K_VCS_MODIFIED_BACKGROUND == '#aaaa44' ]]
[[ $POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND == '#aa4455' ]]
# A local palette is loaded after tracked defaults and remains authoritative on reload.
mkdir -p "$XDG_CONFIG_HOME/p10k"
cat > "$XDG_CONFIG_HOME/p10k/theme.local.zsh" <<'EOF'
typeset -g POWERLEVEL9K_DIR_BACKGROUND='#123456'
typeset -g POWERLEVEL9K_VIRTUALENV_BACKGROUND='#654321'
EOF
source "$HOME/.p10k.zsh"
[[ $POWERLEVEL9K_DIR_BACKGROUND == '#123456' ]]
[[ $POWERLEVEL9K_VIRTUALENV_BACKGROUND == '#654321' ]]
simulated=dark
source "$HOME/.p10k.zsh"
[[ $POWERLEVEL9K_DIR_BACKGROUND == '#123456' ]]
[[ $POWERLEVEL9K_VIRTUALENV_BACKGROUND == '#654321' ]]
print 'p10k appearance integration tests passed'
