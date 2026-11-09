#!/bin/bash
# Fixture-based plugin tests; never sends updates to the real bar or network.
set -eu
ROOT=$(cd "$(dirname "$0")/../dot-config/sketchybar" && pwd)
export CONFIG_DIR="$ROOT"
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
export XDG_CACHE_HOME="$TEMP/cache" LOG="$TEMP/updates" SENDER=routine INFO=''

sketchybar() { printf '%s|' "$@" >> "$LOG"; printf '\n' >> "$LOG"; }
export -f sketchybar
check() { grep -Fq -- "$1" "$LOG" || { echo "Missing: $1"; cat "$LOG"; exit 1; }; }
run() { : > "$LOG"; bash "$ROOT/plugins/$1.sh"; }

top() { printf '%s\n' 'CPU usage: 10.00% user, 5.00% sys, 85.00% idle'; printf 'CPU usage: 0.00%% user, 0.00%% sys, %s%% idle\n' "${CPU_IDLE:-5.00}"; }
export -f top
run metrics
check 'label=95%'
check 'icon.color=0xffe18c91'
if grep -Fq 'memory|' "$LOG"; then echo 'Unexpected memory update'; exit 1; fi
for sample in '100:0:0xff9bc69b' '76:24:0xff9bc69b' '75:25:0xffe6bb78' '31:69:0xffe6bb78' '30:70:0xffe18c91'; do
  export CPU_IDLE="${sample%%:*}"
  expected="${sample#*:}"
  run metrics
  check "label=${expected%%:*}%|icon.color=${expected#*:}"
done

osascript() { echo 42; }
pmset() { printf "Now drawing from '%s'\n -InternalBattery-0  %s%%;\n" "$POWER" "$BATTERY"; }
export -f osascript pmset
export POWER='AC Power' BATTERY=100
run status
check 'battery|drawing=on|icon=|label=100%|icon.color=0xff9bc69b'
export POWER='Battery Power' BATTERY=15
run status
check 'label=15%|icon.color=0xffe6bb78'
export BATTERY=5
run status
check 'label=5%|icon.color=0xffe18c91'

curl() { printf '%s' "${WEATHER_DATA:-}"; }
export -f curl
export WEATHER_DATA='{"current":{"temperature_2m":-2.6,"weather_code":73}}'
run weather
check 'label=-3°C'
check 'icon=󰖘'
export WEATHER_DATA='invalid'
run weather
check 'label=—°'
export WEATHER_DATA='{"current":{"temperature_2m":null,"weather_code":null}}'
run weather
check 'label=—°'

route() { echo '  interface: en0'; }
netstat() { printf 'Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll\nen0 1500 <Link#14> aa 1 0 %s 1 0 %s 0\n' "$RX" "$TX"; }
networksetup() {
  if [[ "$1" == -listallhardwareports ]]; then
    printf 'Hardware Port: Wi-Fi\nDevice: en0\n'
  elif [[ "${REDACTED:-0}" == 0 ]]; then
    echo 'Current Wi-Fi Network: Guest 5G'
  fi
}
ipconfig() { printf '  LinkStatusActive : %s\n  SSID : <redacted>\n' "${LINK:-TRUE}"; }
date() { echo "$NOW"; }
export -f route netstat networksetup ipconfig date
export RX=10240 TX=20480 NOW=100
run network
check 'network|label=—'
check 'wifi|label=Guest 5G|label.drawing=on'
export RX=20480 TX=40960 NOW=105
run network
check 'network|label=2K ↑4K'
export RX=10240 TX=20480 NOW=110
run network
check 'network|label=—'
export REDACTED=1 SENDER=wifi_change NOW=111
run network
check 'wifi|label=|label.drawing=off|icon='
export LINK=FALSE NOW=112
run network
check 'wifi|label=|label.drawing=off|icon=󰖪'
export LINK=TRUE SENDER=system_woke NOW=200 RX=1000000
run network
check 'network|label=—'

function media-control { printf '%s' "$MEDIA_DATA"; }
export -f media-control
export MEDIA_DATA='{"playing":true,"title":"Song","artist":"Artist"}'
run media
check 'drawing=on|label=Song — Artist'
export MEDIA_DATA='{"playing":false,"title":"Song"}'
run media
check 'drawing=off'
export MEDIA_DATA='null'
run media
check 'drawing=off'
# Two monitors: the external one (display 2) sits left of the built-in one.
sketchybar() {
  case "$1 $2" in
    '--query displays') echo '[{"arrangement-id":1,"frame":{"x":0}},{"arrangement-id":2,"frame":{"x":-2560}}]' ;;
    '--query bar') echo '{"items":["workspace.4","workspaces_other","aerospace_controller","crumb_window","front_window"]}' ;;
    '--query front_window') echo '{"label":{"value":"old"},"icon":{"value":""}}' ;;
    *) printf '%s|' "$@" >> "$LOG"; printf '\n' >> "$LOG" ;;
  esac
}
aerospace() {
  case "$*" in
    'list-workspaces '*) echo '[{"workspace":"9","monitor-appkit-nsscreen-screens-id":1,"workspace-is-focused":false,
        "workspace-root-container-layout":"h_tiles","monitor-name":"Built-in Retina Display"},
      {"workspace":"3-work","monitor-appkit-nsscreen-screens-id":2,"workspace-is-focused":true,
        "workspace-root-container-layout":"v_accordion","monitor-name":"LEN T32p-20"}]' ;;
    'list-windows --all '*) echo '[{"workspace":"3-work","app-name":"Ghostty"},{"workspace":"3-work","app-name":"Slack"},
      {"workspace":"3-work","app-name":"Ghostty"},{"workspace":"4","app-name":"Firefox"},
      {"workspace":"1","app-name":"Firefox"},{"workspace":"1-plan","app-name":"Obsidian"},
      {"workspace":"0-dump","app-name":"Messages"},{"workspace":"misc","app-name":"Notes"}]' ;;
    'list-windows --focused '*) echo '[{"app-name":"Ghostty","window-title":"vim","window-layout":"floating","window-is-fullscreen":false}]' ;;
  esac
}
export -f sketchybar aerospace
run aerospace
check '--add|item|monitor.2|left|--set|monitor.2|icon=󰍹|icon.color=0xff9bc69b|'
check 'label=3-work|label.color=0xff9bc69b|'
check 'background.drawing=on|'
check '--set|monitor.1|icon=󰌢|icon.color=0xff969fad|'
check '--set|apps.2|display=2|'
check 'icon=󰕵|'
check 'label=Ghost² · Slack|label.color=0xffe6e9ef|'
check '--set|apps.1|display=1|'
check 'label=empty|label.color=0xff495361|'
check '--set|workspaces_other|label=1 1-plan 4 0 misc|drawing=on|'
check '--remove|workspace.4|'
check '--move|monitor.2|before|workspaces_other|--move|apps.2|before|crumb_window|--move|monitor.1|'
check '--set|front_window|label=Ghostty — vim|icon=󰖲|'
printf 'Status plugin fixtures passed.\n'
