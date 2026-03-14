---
description: Spawn two Godot processes (host and client) to test a Campaign game with bots
---

Spawns two Godot processes to automatically launch and connect a Campaign game, both running as bots.
The host automatically acts as Sathar, and the client joins as UPF.
After the client connects, the host will automatically launch the campaign map.

1. Ensure no rogue processes are running:
// turbo-all
```bash
killall -9 godot godot-runner 2>/dev/null || true
```

2. Launch the Host instance (Sathar) in the background with auto-start and bot mode:
```bash
godot --position 0,0 --campaign-host --faction Sathar --bot --wait 2 --auto-start &
```

3. Launch the Client instance (UPF) in the background with bot mode:
```bash
sleep 2 && godot --position 1050,0 --campaign-join 127.0.0.1 --faction UPF --bot &
```
