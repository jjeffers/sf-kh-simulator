# Architecture Documentation

## Overview
Hex Space Combat is a turn-based tactical space combat simulator built in Godot 4. It uses a hex grid for movement and positioning, with a client-server architecture to support multiplayer gameplay.

## Core Systems

### GameManager (`Scripts/GameManager.gd`)
The central controller for the game. Responsibilities include:
- **State Management:** Tracks Game Phases (Movement, Combat) and Turn Cycles.
- **Entity Management:** Spawns and manages `Ship` instances.
- **UI Management:** Handles the in-game UI (HUD, Planning Panels, MiniMap).
- **Network Coordination:** Executes RPCs to synchronize game state (Movement, Combat Resolution) across clients.
- **Input Handling:** Processes player input for selecting ships, plotting moves, and targeting.
- **Side Resolution:** Maps generic `side_id` (1, 2) to scenario-specific Side Names (e.g. 'UPF', 'Sathar') via `ScenarioManager`.

### HexGrid (`Scripts/HexGrid.gd`)
A static utility class defining the coordinate system.
- **Coordinates:** Uses Cube Coordinates (`Vector3i(q, r, s)`) for hex logic.
- **Pathfinding:** Handles conversion between Hex Coordinates and World Space (Pixel) positions.
- **Metrics:** Provides distance calculations (`hex_distance`) and line-of-sight/pathfinding helpers.
- **Configuration:** Defines `TILE_SIZE` (currently 80.0) which dictates the visual scale of the game.

### ScenarioManager (`Scripts/ScenarioManager.gd`)
A static data provider for game scenarios.
- **Data Structure:** Returns dictionaries defining the initial state (Ships, Positions, Factions, Objectives).
- **Randomization:** Supports seeded generation (e.g., random spawn edges) to ensure consistent setup across networked clients.

### Combat (`Scripts/Combat.gd`)
A static logic library for combat calculations. State-free.
- **Hit Chance:** Calculates percentages based on range, weapon type, and defenses (Masking Screen, ICM).
- **Damage:** Handles dice roll logic (e.g., parsing "1d10+2").
- **Resolution:** Determines hit/miss results based on RNG.

### NetworkManager (`Scripts/NetworkManager.gd`)
An Autoload (Singleton) managing the multiplayer connection.
- **Connection Handling:** Wraps `ENetMultiplayerPeer` for Hosting and Joining.
- **Signal Relay:** Emits signals for connection events (`player_connected`, `server_disconnected`) consumed by the Lobby.
- **Lobby System:** Manages `lobby_data` including Teams and Ship Assignments.
- **RPCs:** Synchronizes game state changes (e.g., `execute_commit_move`, `register_attack`).

## Entities

### Ship (`Scripts/Ship.gd`)
The primary game entity.
- **Visuals:** Handles sprite rendering, rotation, and scaling based on Ship Class.
- **Stats:** Stores Hull, Weapons, Defenses (ICM, Masking Screen).
- **Logic:**
  - `calculate_movement_potential()`: Determines valid moves based on speed and turn cost.
  - `trigger_explosion()`: Visual effects for destruction.
  - **Ownership:** Has `side_id` to determine which team controls it.

## Game Infrastructure

### Scenes
- **Main.tscn:** The primary game loop scene containing `GameManager`, `HexGrid` reference, and UI layers.
- **Lobby.tscn:** The entry point for Hosting/Joining games.

### Network Flow
1. **Lobby Phase:**
   - Host starts server -> Clients join.
   - Host selects Scenario.
   - Host sends `setup_game(seed, scenario_key)` RPC to all clients.
2. **Game Start:**
   - All clients load the scenario using the *synced seed*.
   - This ensures procedural elements (like random spawn locations) are identical on all machines.
3. **Turn Execution:**
   - **Movement:** Players plot moves locally -> Click "Engage" -> sends `request_commit_move` -> Server validates -> broadcasts `execute_move`.
   - **Combat:** Players plan attacks -> Click "Execute" -> sends plans to Server via RPC -> synced `queued_attacks` list -> Server (or Active Client) resolves.

## Key Design Patterns & Gotchas
- **Manager-Controller:** `GameManager` acts as the single source of truth for the game state.
- **Static Utilities:** Math (`HexGrid`) and Rules (`Combat`) are separated from State (`Ship`), making logic easy to test and reuse.
- **RPC Command Pattern:** Actions are validated by the authority (Host) before being executed on clients to prevent desync.

> [!WARNING]
> **Invalid Instance Access:**
> When iterating over the `ships` array (or any collection of nodes), **ALWAYS** check `is_instance_valid(s)` before accessing its properties.
> Ships can be destroyed (freed) during the game loop (e.g., in combat resolution or running into boundaries), but references to them may linger in the array or other variables until explicitly removed.
> 
> **Incorrect Pattern:**
> ```gdscript
> for s in ships:
>     if s.side_id == 1: # CRASH if s is freed!
>         ...
> ```
> 
> **Correct Pattern:**
> ```gdscript
> for s in ships:
>     if is_instance_valid(s) and s.side_id == 1:
>         ...
> ```
