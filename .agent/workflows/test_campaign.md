---
description: Spawn two Godot processes (host and client) to test a Campaign game
---

Spawns two Godot processes to automatically launch and connect a Campaign game.
The host automatically acts as UPF, and the client joins as Sathar.
After the client connects, the host will automatically launch the campaign map.

1. Ensure no rogue processes are running:
// turbo-all
```bash
killall -9 godot godot-runner 2>/dev/null || true
```

2. Launch the Host instance (UPF) in the background with auto-start:
```bash
godot --position 0,0 --campaign-host --faction UPF --auto-start &
```

3. Launch the Client instance (Sathar) in the background:
```bash
sleep 2 && godot --position 1050,0 --campaign-join 127.0.0.1 --faction Sathar &
```