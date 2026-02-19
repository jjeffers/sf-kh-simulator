---
description: Publish executables to ad hoc Sync folder
---

// turbo-all
Procedure:
1. Export all project configrations:
- `& "c:\Program Files\Godot_v4.6-stable_win64.exe" --path . --export "Windows Desktop"`
- `& "c:\Program Files\Godot_v4.6-stable_win64.exe" --path . --export "Linux"`

2. Copy executables to sync directory:
- copy .\kh.exe F:\Sync\Public\sfkh\
- copy .\kh.x86_64 F:\Sync\Public\sfkh\