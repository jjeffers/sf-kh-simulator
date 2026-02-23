---
description: Spawn two Godot processes (host and client) to test the docking and re-arming scenario
---

# Test Docking Multiplayer Workflow

This workflow automatically launches two local Godot processes to rapidly test the docking scenario with both a host (Side 1) and a client (Side 2).

1. Launch the Server/Host process. It automatically spins up the `test_docking` scenario and joins as Side 1.
// turbo
godot --path . --host --scenario "test_docking" --side 1 --wait 2 &

2. Wait for the host to start up, then launch the Client process. It automatically looks for the local host and joins as Side 2.
// turbo
sleep 2 && godot --path . --join --side 2 &
