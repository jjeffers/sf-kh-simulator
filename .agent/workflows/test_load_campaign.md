---
description: Spawn two Godot processes (host and client) to test loading a Campaign game
---

Spawns two Godot processes to automatically launch, load a save, and connect a Campaign game.
The host automatically loads the campaign from `campaign_save2.json`, acts as UPF, and the client joins as Sathar.
After the client connects, the host will automatically launch the campaign map.

1. Ensure no rogue processes are running:
// turbo-all
```bash
killall -9 godot godot-runner 2>/dev/null || true
```

2. Launch the Host instance (UPF) in the background with auto-start, loading campaign_save2.json:
```bash
godot --position 0,0 --campaign-host --faction UPF --load-campaign user://campaign_save2.json --auto-start &
```

3. Launch the Client instance (Sathar) in the background:
```bash
sleep 2 && godot --position 1050,0 --campaign-join 127.0.0.1 --faction Sathar &
```
