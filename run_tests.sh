#!/bin/bash
# Check for native Linux Godot first, otherwise fallback to WSL Windows executable
if [ -x "/usr/local/bin/godot" ]; then
    GODOT_CMD="/usr/local/bin/godot"
elif [ -f "/mnt/c/Program Files/Godot_v4.6-stable_win64.exe" ]; then
    GODOT_CMD="/mnt/c/Program Files/Godot_v4.6-stable_win64.exe"
else
    echo "Godot executable not found."
    exit 1
fi

"$GODOT_CMD" --headless --path . -s addons/gut/gut_cmdln.gd "$@"
