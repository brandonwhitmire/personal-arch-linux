#!/bin/sh
# EnvyControl's nvidia layout draws on the NVIDIA screen and leaves the
# Intel panel dark until those outputs are attached. No-op on machines
# that are not using that layout.
providers=$(xrandr --listproviders 2>/dev/null) || exit 0
printf '%s\n' "$providers" | grep -q ' name:NVIDIA-0' || exit 0
printf '%s\n' "$providers" | grep -q ' name:modesetting' || exit 0
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
exit 0
