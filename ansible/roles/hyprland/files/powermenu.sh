#!/bin/bash

# Power menu.
LAUNCHER="wofi --conf /etc/xdg/wofi/config --style /etc/xdg/wofi/style.css --dmenu -i -p Power"

OPTIONS="🔒 Lock\n😴 Suspend\n👥 Switch User\n🚪 Logout\n🔄 Reboot\n⏻ Shutdown"

CHOSEN=$(echo -e "$OPTIONS" | $LAUNCHER)

case "$CHOSEN" in
    "🔒 Lock")
        loginctl lock-session
        ;;
    "😴 Suspend")
        systemctl suspend
        ;;
    "👥 Switch User")
        # Leaves this session running and opens the greeter on another VT.
        if ! dm-tool switch-to-greeter; then
            notify-send 'Switch user failed' 'LightDM could not open the greeter.'
        fi
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
