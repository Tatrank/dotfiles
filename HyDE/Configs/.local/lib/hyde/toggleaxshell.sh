#!/usr/bin/env bash

# Check if Ax-Shell process is running
if pgrep -x "ax-shell" > /dev/null; then
    # If it's running, kill it
    killall ax-shell
else
    # If it's not running, start it
    INSTALL_DIR="$HOME/.config/Ax-Shell"
    uwsm app -- python "$INSTALL_DIR/main.py" > /dev/null 2>&1 & disown
fi