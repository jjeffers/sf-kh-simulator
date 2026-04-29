---
description: Spawn two headless Godot processes (host and client) to test a Campaign game with bots
---

Spawns two headless Godot processes to automatically launch and connect a Campaign game, both running as bots.
The host automatically acts as Sathar, and the client joins as UPF. Output is directed to log files.

1. Ensure no rogue processes are running:
// turbo-all
```bash
pkill -9 -f "godot --headless" || true
rm -f host_campaign.log client_campaign.log
```

2. Launch the Host instance (Sathar) in the background with auto-start, bot, and headless mode:
```bash
godot --headless --campaign-host --faction Sathar --bot --wait 2 --auto-start > host_campaign.log 2>&1 &
```

3. Launch the Client instance (UPF) in the background with bot and headless mode:
```bash
sleep 2 && godot --headless --campaign-join 127.0.0.1 --faction UPF --bot > client_campaign.log 2>&1 &
```

4. (Optional) Check the progression of the simulation by tailing the logs in a separate terminal:
`tail -f host_campaign.log`
