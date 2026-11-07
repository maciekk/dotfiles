#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
export LC_ALL=C

# Per-user state; lock prevents event/poll races. No SSIDs are written to disk.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-sketchybar"
mkdir -p "$cache"
chmod 700 "$cache"
mkdir "$cache/network.lock" 2>/dev/null || exit 0
trap 'rmdir "$cache/network.lock"; rm -f "$cache/network.tmp.$$"' EXIT
now=$(date +%s)
interface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
counts=$(netstat -ibn -I "${interface:-none}" 2>/dev/null | awk '
  NR==1 {for(i=1;i<=NF;i++) {if($i=="Ibytes") rx=i; if($i=="Obytes") tx=i}}
  /<Link#/ && rx && tx {print $rx, $tx; exit}')
read -r rx tx <<< "$counts"
previous_interface='' previous_time=0 previous_rx=0 previous_tx=0 wifi_time=0
if [[ -r "$cache/network" ]]; then
  read -r previous_interface previous_time previous_rx previous_tx wifi_time < "$cache/network"
fi
for value in previous_time previous_rx previous_tx wifi_time; do
  [[ "${!value}" =~ ^[0-9]+$ ]] || printf -v "$value" '%s' 0
done
label='—'
if [[ "$rx" =~ ^[0-9]+$ && "$tx" =~ ^[0-9]+$ ]]; then
  elapsed=$((now - previous_time))
  # Discard first samples, counter resets, interface switches, and sleep gaps.
  if [[ "$interface" == "$previous_interface" && "$SENDER" != system_woke ]] &&
      (( elapsed > 0 && elapsed <= 30 && rx >= previous_rx && tx >= previous_tx )); then
    label=$(awk -v down="$((rx - previous_rx))" -v up="$((tx - previous_tx))" -v sec="$elapsed" '
      function rate(n) {
        n=n/sec/1024
        if(n>=1024) return sprintf("%.1fM",n/1024)
        return sprintf("%.0fK",n)
      }
      BEGIN {printf "%s ↑%s",rate(down),rate(up)}')
  fi
else
  rx=0 tx=0
fi
sketchybar --set network label="$label"

# SSID queries can be slower than counters; refresh every 30s and on Wi-Fi events.
if (( now - wifi_time >= 30 )) || [[ "$SENDER" == wifi_change || "$SENDER" == system_woke ]]; then
  wifi_time=$now
  device=$(networksetup -listallhardwareports 2>/dev/null |
    awk '/Hardware Port: (Wi-Fi|AirPort)/ {getline; print $2; exit}')
  label=''; color="$DIM"; icon='󰖪'
  if [[ -n "$device" ]]; then
    summary=$(ipconfig getsummary "$device" 2>/dev/null)
    if grep -q 'LinkStatusActive : TRUE' <<< "$summary"; then
      color="$WIFI"; icon=''
      ssid=$(networksetup -getairportnetwork "$device" 2>/dev/null |
        sed -n 's/^Current Wi-Fi Network: //p')
      [[ -n "$ssid" ]] || ssid=$(sed -n 's/^  SSID : //p' <<< "$summary")
      # New macOS versions redact names without Location access. Never call
      # a connected link disconnected merely because the SSID is unavailable.
      if [[ -n "$ssid" && "$ssid" != '<redacted>' ]]; then label="$ssid"; fi
    fi
  fi
  label_drawing=off
  [[ -n "$label" ]] && label_drawing=on
  sketchybar --set wifi label="$label" label.drawing="$label_drawing" icon="$icon" icon.color="$color"
fi
printf '%s %s %s %s %s\n' "${interface:-none}" "$now" "$rx" "$tx" "$wifi_time" > "$cache/network.tmp.$$"
mv "$cache/network.tmp.$$" "$cache/network"
