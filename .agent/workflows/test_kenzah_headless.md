---
description: Spawn two background Headless Godot processes to rapidly simulate the Battle of Ken'zah
---

# Test Battle of Ken'zah Multiplayer Workflow (Headless Bots)

This workflow automatically launches two local Godot processes in `--headless` mode to benchmark the Battle of Ken'zah scenario at hyper-speed. Both a host (Side 1) and a client (Side 2) will run as AI opponents while bypassing native visual animation buffers.

1. Ensure no existing headless scripts are running and clean old logs.
// turbo
pkill -9 -f "godot --headless" || true
// turbo
rm -f host_kenzah.log client_kenzah.log

2. Launch the Server/Host process. It automatically spins up the `battle_of_kenzah` scenario and joins as Side 1 (UPF) running as a bot. Output is piped to `host_kenzah.log`.
// turbo
godot --headless --path . --host --scenario "battle_of_kenzah" --side 1 --bot --wait 2 > host_kenzah.log 2>&1 &

3. Wait for the host to start up, then launch the Client process. Output is piped to `client_kenzah.log`.
// turbo
sleep 2 && godot --headless --path . --join --side 2 --bot > client_kenzah.log 2>&1 &

4. (Optional) Check the progression of the simulation by tailing the logs in a separate terminal:
`tail -f host_kenzah.log`
