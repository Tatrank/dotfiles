#!/usr/bin/env bash
# TODO: Add persistent mode
HYPRGAMEMODE=$(hyprctl getoption animations:enabled | sed -n '1p' | awk '{print $2}')


if pgrep -x "ax-shell" > /dev/null; then
    # If it's running, kill it
    killall ax-shell
else
    # If it's not running, start it
    INSTALL_DIR="$HOME/.config/Ax-Shell"
    uwsm app -- python "$INSTALL_DIR/main.py" > /dev/null 2>&1 & disown
fi



# Hyprland performance
if [ "$HYPRGAMEMODE" = 1 ]; then
        hyprctl -q --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:shadow:xray 1;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0 ;\
        keyword decoration:active_opacity 1 ;\
        keyword decoration:inactive_opacity 1 ;\
        keyword decoration:fullscreen_opacity 1 ;\
        keyword decoration:fullscreen_opacity 1 ;\
        keyword layerrule noanim,waybar ;\
        keyword layerrule noanim,swaync-notification-window ;\
        keyword layerrule noanim,swww-daemon ;\
        keyword layerrule noanim,rofi
        "
        hyprctl 'keyword windowrule opaque,class:(.*)' # ensure all windows are opaque
        exit
else
        hyprctl reload config-only -q
fi
