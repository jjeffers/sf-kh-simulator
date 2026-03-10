---
description: Spawn two Godot processes (host and client) to test the Battle of Ken'zah scenario with bots
---

# Test Battle of Ken'zah Multiplayer Workflow (Bots)

This workflow automatically launches two local Godot processes to rapidly test the Battle of Ken'zah scenario with both a host (Side 1) and a client (Side 2) running as AI computer opponents.

1. Launch the Server/Host process. It automatically spins up the `battle_of_kenzah` scenario and joins as Side 1 (UPF) running as a bot.
// turbo
godot --path . --host --scenario "battle_of_kenzah" --side 1 --bot --wait 2 &

2. Wait for the host to start up, then launch the Client process. It automatically looks for the local host and joins as Side 2 (Sathar) running as a bot.
// turbo
sleep 2 && godot --path . --join --side 2 --bot &
