#!/bin/sh
# Start one Waybar. A leftover from the previous login is replaced.

cfg=/etc/xdg/waybar/config.jsonc
style=/etc/xdg/waybar/style.css
lock="${XDG_RUNTIME_DIR:-/tmp}/waybar.lock"

mkdir -p "$(dirname "$lock")"
exec 9>"$lock"
flock -n 9 || exit 0

pkill -x polybar 2>/dev/null || true
pkill -x waybar 2>/dev/null || true

i=0
while pgrep -x waybar >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -gt 30 ]; then
        pkill -9 -x waybar 2>/dev/null || true
        break
    fi
    sleep 0.1
done

pulseaudio --start >/dev/null 2>&1 || true

if [ -f "$cfg" ] && [ -f "$style" ]; then
    waybar -c "$cfg" -s "$style" &
else
    waybar &
fi
wpid=$!

sleep 0.2
flock -u 9
wait "$wpid"
