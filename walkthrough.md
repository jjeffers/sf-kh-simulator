# Walkthrough - New Scenario: The Last Stand

## Overview
Added a new scenario "The Last Stand" featuring a massive Sathar fleet attacking Fortress K'zdit.

## Features
- **Scenarios**: "The Last Stand" and "Surprise Attack".
- **Dynamic Loading**: `GameManager.gd` now supports `load_scenario(key)` with full object instantiation.
- **Overrides**: Scenarios can now override default ship stats (e.g., custom hull/weapons for Fortress K'zdit).
- **Assault Carrier**: Added configuration for the Sathar Assault Carrier (75 Hull, Launch Fighters).
- **Debuffs**: Implemented `linked_state_debuff` support (Station evacuation disables weapons).
- **Planet Masking**: Fixed blocking logic to allow ships inside planet hexes (e.g., Valiant) to fire out, and be targeted.

## How to Play "The Last Stand"
- The scenario is currently set as the **default** in `GameManager.gd`.
- Just launch the game.
- **Objective**: UPF must defend Fortress K'zdit against the Sathar invasion fleet.
- **Randomization**:
    - **Fortress K'zdit**: Spawns in a random orbit around the center planet.
    - **Sathar Fleet**: Spawns at a random map edge, attacking inward.
- **Custom Port**: Users can now specify a server port (default 7000) in the Lobby.

## UI Updates
- **Ship Names**: Ships now display their class abbreviation (e.g., "DD Vicious", "F Fighter") on the map and in logs.
    - F: Fighter
    - FG: Frigate
    - DD: Destroyer
    - C: Heavy Cruiser
    - BB: Battleship
    - SS: Space Station
    - AS: Assault Scout
    - AC: Assault Carrier

## Ship Roster (The Last Stand)
**UPF (Defenders)**:
- Fortress K'zdit (Custom Station)
- Valiant (Battleship)
- Allison May (Destroyer)
- Daridia (Frigate)
- Dauntless & Razor (Assault Scouts)
- 2 Fighters

**Sathar (Invaders)**:
- Infamous (Assault Carrier) with 2 docked Fighters
- Star Scourge (Heavy Cruiser)
- Vicious, Pestilence, Doomfist (Destroyers)
- Stinger (Frigate)

## Bug Fixes
- **Station Auto-Orbit**: Refined orbital movement to be instant (0-second delay), effectively "skipping" the station during movement planning as requested. Fixed a validation bug where `execute_commit_move` was double-checking path validity without the `is_orbiting` flag, causing "Illegal Acceleration" rejections.
- **Orbital Validation**: Patched `_validate_move_path` to explicitly allow orbital movement (Speed 1) for ships with ADF 0 (like Stations), which was previously rejecting the move as "Illegal Acceleration".
- **Combat Skipping**: Fixed a bug where ships were incorrectly skipped during combat if they had fired in the previous turn segment (e.g. Offensive then Defensive). Implemented `reset_turn_state()` at the start of every player turn (instead of just round end) to ensure weapons are refreshed for each new movement/combat cycle.

### Movement UX Improvements
- **Self-Click Deceleration**: Players can now click their own ship's hex during movement planning to request a full stop (Speed 0), provided their ADF allows it.
- **Ghost-Click Commit**: Clicking the "Ghost Ship" (the projected end position of a plotted move) now commits the move, serving as an intuitive "Confirm" action on the map.

