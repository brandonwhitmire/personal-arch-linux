#!/bin/sh

# Mirror the X11 xinitrc layout: internal panel at 0x0, HDMI to its right.
# Workspace 2 stays on the external output when one is connected.

i=0
while [ "$i" -lt 25 ]; do
    hyprctl monitors >/dev/null 2>&1 && break
    i=$((i + 1))
    sleep 0.2
done

edp=$(hyprctl monitors | awk '/^Monitor /{print $2}' | grep -i '^eDP' | head -n1)
hdmi=$(hyprctl monitors | awk '/^Monitor /{print $2}' | grep -i '^HDMI' | head -n1)

if [ -n "$edp" ]; then
    hyprctl keyword monitor "$edp,preferred,0x0,1"
fi

if [ -n "$hdmi" ] && [ -n "$edp" ]; then
    hyprctl keyword monitor "$hdmi,preferred,auto-right,1"
    hyprctl keyword workspace "2,monitor:$hdmi"
elif [ -n "$hdmi" ]; then
    hyprctl keyword monitor "$hdmi,preferred,auto,1"
fi
