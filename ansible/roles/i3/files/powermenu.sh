#!/bin/bash

# A dmenu-based power menu script for i3
# Provides options for Lock, Suspend, Logout, Reboot, and Shutdown

# Use rofi if available, otherwise dmenu
# You can change this to `rofi -dmenu` or a different launcher
LAUNCHER="dmenu -i -p Power"

# Options to display in the menu
# Using standard Unicode emojis for universal compatibility
OPTIONS="🔒 Lock\n😴 Suspend\n🚪 Logout\n🔄 Reboot\n⏻ Shutdown"

# Get the user's choice
CHOSEN=$(echo -e "$OPTIONS" | $LAUNCHER)

# Execute the corresponding command
case "$CHOSEN" in
    "🔒 Lock")
        i3lock --ignore-empty-password --color=444444
        ;;
    "😴 Sleep/Suspend")
        systemctl suspend
        ;;
    "🚪 Logout")
        i3-msg exit
        ;;
    "🔄 Reboot/Restart")
        systemctl reboot
        ;;
    "⏻ Shutdown/Poweroff")
        systemctl poweroff -i
        ;;
esac