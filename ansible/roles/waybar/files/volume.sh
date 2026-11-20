#!/bin/sh
# Print the default sink volume for Waybar. Always prints one JSON line.
# Glyphs are from JetBrainsMono Nerd Font. Muted is md-volume_mute (speaker with an x).
vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk -F/ 'NR==1 { gsub(/[% ]/, "", $2); print $2 }')
mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{ print $2 }')

if [ -z "$vol" ]; then
    icon=$(printf '\uf028')
    printf '%s\n' "{\"text\":\"${icon}\",\"tooltip\":\"Volume\"}"
elif [ "$mute" = "yes" ]; then
    icon=$(printf '\U000f075f')
    printf '%s\n' "{\"text\":\"${icon} ${vol}%\",\"class\":\"muted\",\"tooltip\":\"Volume muted\"}"
elif [ "$vol" -lt 35 ]; then
    icon=$(printf '\uf027')
    printf '%s\n' "{\"text\":\"${icon} ${vol}%\",\"tooltip\":\"Volume ${vol}%\"}"
else
    icon=$(printf '\uf028')
    printf '%s\n' "{\"text\":\"${icon} ${vol}%\",\"tooltip\":\"Volume ${vol}%\"}"
fi
