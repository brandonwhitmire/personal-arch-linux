#!/bin/sh
# Hyprland idle lock. Stands in for xss-lock in the i3 session.
# hypridle has to stay running to hear idle and sleep signals.

pkill -x hypridle 2>/dev/null || true
exec hypridle --config /etc/xdg/hypr/hypridle.conf
