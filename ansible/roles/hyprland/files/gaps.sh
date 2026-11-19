#!/bin/sh

# Adjust global gaps. Usage: gaps.sh in|out +N|-N|0
target=$1
delta=$2

case "$target" in
    in) opt=general:gaps_in ;;
    out) opt=general:gaps_out ;;
    *) exit 1 ;;
esac

current=$(hyprctl getoption "$opt" | awk '/^int:/{print $2; exit}')
current=${current:-0}

if [ "$delta" = "0" ]; then
    next=0
else
    next=$((current + delta))
fi

if [ "$next" -lt 0 ]; then
    next=0
fi

hyprctl keyword "$opt" "$next"
