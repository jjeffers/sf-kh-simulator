# Bug Tracker

## 🚨 Critical / High Priority
- [ ] 

## 🐛 Backlog
- Add graphical explosion effect on ship death
- Implement 3D visual modes for combat rendering
- Create map editor tool
- Repair Panel Missing Systems: When a ship has a damaged masking screen defense, CCS damage, or ICM systems destroyed, they don't show up in the DCR repair panel. 
- Repair Panel Unrepairable Display: If systems didn't show up because of a previous failed repair with a roll of 96-100, we should still show the damaged system but disallow any DCR allocation to visually indicate its permanent destruction.


## 🔍 Needs Investigation
- [ ] 

## ✅ Fixed
- [x] Fixed DCR Graphical Sync: Hooked Masking Screens, CCS, and ICM internal property variables to explicitly expose them as sliders on the DCR interface instead of dropping them off the system. Added `(DESTROYED)` visual locks for systems that fail repair rolls permanently. (2026-02-21)
- [x] Fixed input behavior: Mapped TAB to properly cycle through targets in `Phase.REPAIR` alongside its Movement behavior. Mapped E to target cycling through hostile entities during `Phase.COMBAT`. (2026-02-21)
- [x] Fixed command-line handling: Passed `--host` and `--scenario` arguments inside `MainMenu.gd` now bypass the Lobby connection UI to rapidly launch offline multiplayer games. (2026-02-21)
- [x] Overhauled the Repair Phase UI so `panel_repair` displays damage controls for only the actively clicked ship. (2026-02-21)
- [x] Fixed an issue where the `start_speed - eff_adf = min_speed` calculation incorrectly fetched the flat `.adf` statistic instead of checking for active damage modifiers in `GameManager.gd`. (2026-02-21)
- [x] Fixed stack selection bug: Clicking on an enemy stack with a friendly ship selected now correctly targets the enemy if a weapon is active. (2026-02-16)
- [x] Fixed speed 0 facing constraint bug: Moving 1 hex after free rotation resulted in invalid turning constraints due to incorrect entry facing calculation. (2026-02-16)
- [x] Fixed Infinite Ammo Bug where ammo count of -1 was treated as insufficient ammo. (2026-02-17)
- [x] Fixed Stack Selection Visual Mismatch: Targeting now correctly selects the visually top-most ship in a stack (based on scene tree order) instead of the bottom ship. (2026-02-17)
- [x] Fixed Runtime Error: "Invalid access of index '3'" at GameManager.gd 3882. Cause: "Surprise Attack" scenario used `"stats"` instead of `"overrides"`, causing Space Station to generate random weapon lists (desynced). Fix: Renamed key to `"overrides"`. (2026-02-17)
- [x] Fixed Runtime Error: "Invalid assignment... on previously freed" at GameManager.gd 2801. Cause: `execute_commit_move` continued processing docking logic for a ship that was just destroyed (via Planet/Boundary check). Fix: Added early return upon ship destruction. (2026-02-17)
- [x] Fixed Scenario Hull Bug: Station Alpha in "Surprise Attack" had random hull (e.g. 130) instead of 25 because `overrides` only set `max_hull`, leaving `hull` to `configure_space_station` RNG. Fix: Added `"hull": 25` to overrides. (2026-02-17)
- [x] Fixed Hit Odds Desync: Implemented Full State Synchronization (Ship.get_net_state / apply_net_state) and broadcast it at the start of Movement and Combat Planning phases. This ensures all clients see the same debuffs (CCS damage, etc.) when calculating hit chances. (2026-02-17)
- [x] Fixed Damage Roll Desync: Refactored `execute_commit_combat` to use a "Request -> Broadcast" pattern. Only the Server initiates the resolution (via `rpc_resolve_combat`) after receiving a client request, ensuring all clients execute the combat resolution with the exact same RNG seed. Verified via `test_damage_sync.gd`. (2026-02-17)
- [x] Fixed Turn Restrictions & Host Spying: Disabled navigation controls, interactive ghost ships, and highlighting when out of turn. Specifically fixed a vulnerability where the **Host Player** could unintentionally bypass restrictions due to `is_server` authority. Updated `_spawn_ghost` to only allow bypass for Admin (Side 0) or Offline mode. Verified via `test_enemy_selection_highlights.gd` (with forced online mode). (2026-02-19)
- [x] Fixed Undo Desync: Implemented `rpc_undo_move` to synchronize undo across all clients. Modified `start_movement_phase` to capture `turn_start_state` for all ships, ensuring reliable state restoration. Verified via `test_undo_sync.gd`. (2026-02-18)
- [x] Fixed Auto-Orbit Hang / Phase End: Refactored `start_movement_phase` to use a new `_apply_movement_plan` helper. This allows the Station to auto-orbit immediately *without* triggering `execute_all_movement` (which would prematurely end the phase for the side). Also fixed empty path handling. Verified via `test_auto_orbit_hang.gd`. (2026-02-18)
- [x] Fixed Movement Plan Desync: The server was validating but not broadcasting movement plans to other clients. Implemented `rpc_sync_movement_plan` in `GameManager.gd` and updated `register_movement_plan` to trigger this broadcast from the Server. This ensures all clients receive the confirmed path for visualization (including Orbital moves). Verified via `test_movement_sync.gd`. (2026-02-19)
