---
description: Spawn two Godot processes (host and client) to test the spatial mines scenario
---

# Test Mines Multiplayer Workflow

This workflow automatically launches two local Godot processes to rapidly test the spatial mines scenario with both a host (Side 1) and a client (Side 2).

1. Launch the Server/Host process. It automatically spins up the `test_mines` scenario and joins as Side 1 (UPF).
// turbo
godot --path . --host --scenario "test_mines" --side 1 --wait 2 &

2. Wait for the host to start up, then launch the Client process. It automatically looks for the local host and joins as Side 2 (Sathar).
// turbo
sleep 2 && godot --path . --join --side 2 &
