---
description: Publish executables to ad hoc Sync folder
---

// turbo-all
Procedure:
1. Export all project configrations:
   - **Windows**: `& "c:\Program Files\Godot_v4.6-stable_win64.exe" --headless --path . --export-debug "Windows Desktop"`
   - **Windows**: `& "c:\Program Files\Godot_v4.6-stable_win64.exe" --headless --path . --export-debug "Linux"`
   - **Linux**: `/usr/local/bin/godot --headless --path . --export-debug "Windows Desktop"`
   - **Linux**: `/usr/local/bin/godot --headless --path . --export-debug "Linux"`

2. Copy executables to sync directory:
   - **Windows**: `copy .\kh.exe F:\Sync\Public\sfkh\`
   - **Windows**: `copy .\kh.x86_64 F:\Sync\Public\sfkh\`
   - **Linux**: `cp ./kh.exe /path/to/sync/dir/sfkh/`
   - **Linux**: `cp ./kh.x86_64 /path/to/sync/dir/sfkh/`