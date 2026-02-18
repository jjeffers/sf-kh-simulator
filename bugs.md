# Bug Tracker

## 🚨 Critical / High Priority


- [ ] [UI] When a player used the Undo button that change is not sent to all players, so another player on his team doesn't see the change.
- [ ] [UI] When player uses the undo button with an assault carrier with docked fighters, the assault carrier is moved back but the fighters are left in the former end position, undocked. 
- [ ] In a situation with multiple fighters, one player sees fighter #1 at position A, and the other fighter #2 at position B, while the other player on the same team sees fighter #1 at position B and fighter #2 at position A.

## 🐛 Backlog
- [ ] 

## 🔍 Needs Investigation
- [ ] 

## ✅ Fixed
- [x] Fixed stack selection bug: Clicking on an enemy stack with a friendly ship selected now correctly targets the enemy if a weapon is active. (2026-02-16)
- [x] Fixed speed 0 facing constraint bug: Moving 1 hex after free rotation resulted in invalid turning constraints due to incorrect entry facing calculation. (2026-02-16)
- [x] Fixed Infinite Ammo Bug where ammo count of -1 was treated as insufficient ammo. (2026-02-17)
- [x] Fixed Stack Selection Visual Mismatch: Targeting now correctly selects the visually top-most ship in a stack (based on scene tree order) instead of the bottom ship. (2026-02-17)
- [x] Fixed Runtime Error: "Invalid access of index '3'" at GameManager.gd 3882. Cause: "Surprise Attack" scenario used `"stats"` instead of `"overrides"`, causing Space Station to generate random weapon lists (desynced). Fix: Renamed key to `"overrides"`. (2026-02-17)
- [x] Fixed Runtime Error: "Invalid assignment... on previously freed" at GameManager.gd 2801. Cause: `execute_commit_move` continued processing docking logic for a ship that was just destroyed (via Planet/Boundary check). Fix: Added early return upon ship destruction. (2026-02-17)
- [x] Fixed Scenario Hull Bug: Station Alpha in "Surprise Attack" had random hull (e.g. 130) instead of 25 because `overrides` only set `max_hull`, leaving `hull` to `configure_space_station` RNG. Fix: Added `"hull": 25` to overrides. (2026-02-17)
- [x] Fixed Hit Odds Desync: Implemented Full State Synchronization (Ship.get_net_state / apply_net_state) and broadcast it at the start of Movement and Combat Planning phases. This ensures all clients see the same debuffs (CCS damage, etc.) when calculating hit chances. (2026-02-17)
- [x] Fixed Damage Roll Desync: Refactored `execute_commit_combat` to use a "Request -> Broadcast" pattern. Only the Server initiates the resolution (via `rpc_resolve_combat`) after receiving a client request, ensuring all clients execute the combat resolution with the exact same RNG seed. Verified via `test_damage_sync.gd`. (2026-02-17)
