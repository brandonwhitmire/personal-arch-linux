#!/bin/sh
# Hyprland wallpaper. swaybg has to stay running for the picture to remain.

img=""
if [ -r "$HOME/.config/profile-wallpaper" ]; then
    img=$(tr -d '[:space:]' < "$HOME/.config/profile-wallpaper")
fi

if [ ! -f "$img" ]; then
    case "$(id -un)" in
        dev) img=/usr/share/backgrounds/profiles/wallpaper-dev.jpg ;;
        obb) img=/usr/share/backgrounds/profiles/wallpaper-aoe.jpg ;;
        *) img=/usr/share/backgrounds/profiles/wallpaper-dev.jpg ;;
    esac
fi

[ -f "$img" ] || exit 0

pkill -x swaybg 2>/dev/null || true
exec swaybg -i "$img" -m fit
