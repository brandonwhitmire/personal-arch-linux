#!/bin/sh
# Super+M hides Waybar when it is up, and starts it otherwise.

if pgrep -x waybar >/dev/null 2>&1; then
    exec pkill -x -USR1 waybar
fi

exec /usr/local/lib/hypr/bar.sh
