#!/bin/bash

# Power menu.
LAUNCHER="wofi --conf /etc/xdg/wofi/config --style /etc/xdg/wofi/style.css --dmenu -i -p Power"

OPTIONS="🔒 Lock\n😴 Suspend\n🚪 Logout\n🔄 Reboot\n⏻ Shutdown"

CHOSEN=$(echo -e "$OPTIONS" | $LAUNCHER)

case "$CHOSEN" in
    "🔒 Lock")
        loginctl lock-session
        ;;
    "😴 Suspend")
        systemctl suspend
        ;;
    "🚪 Logout")
        hyprctl dispatch 'hl.dsp.exit()'
        ;;
    "🔄 Reboot")
        systemctl reboot
        ;;
    "⏻ Shutdown")
        systemctl poweroff -i
        ;;
esac
