---
description: Run the full test suite
---

// turbo-all

### Linux / WSL (Bash)
1. Run the test command:
   `/usr/local/bin/godot --headless --path . -s "addons/gut/gut_cmdln.gd"`

2. Individual tests can be run as follows:
   `/usr/local/bin/godot --headless --path . -s "addons/gut/gut_cmdln.gd" -gtest="<path to test>"`

### Windows (PowerShell)
1. Run the test command from PowerShell:
   `& "c:\Program Files\Godot_v4.6-stable_win64.exe" --headless --path . -s "addons/gut/gut_cmdln.gd"`

2. Individual tests can be run as follows:
   `& "c:\Program Files\Godot_v4.6-stable_win64.exe" --headless --path . -s "addons/gut/gut_cmdln.gd" -gtest="<path to test>"`