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
printf 'Status plugin fixtures passed.\n'
