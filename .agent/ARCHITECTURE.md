# Architecture Overview

This document describes the high-level architecture of the Hex Space Combat project.

## Core Systems

### GameManager (`Scripts/GameManager.gd`)
The central controller for the game. Responsibilities include:
- **State Management:** Tracks Game Phases (Movement, Combat) and Turn Cycles.
- **Entity Management:** Spawns and manages `Ship` instances.
- **UI Management:** Handles the in-game UI (HUD, Planning Panels).
- **Network Coordination:** Executes RPCs to synchronize game state (Movement, Combat Resolution) across clients.
- **Input Handling:** Processes player input for selecting ships, plotting moves, and targeting.

### HexGrid (`Scripts/HexGrid.gd`)
A static utility class defining the coordinate system.
- Uses **Cube Coordinates** (`Vector3i(q, r, s)`) for hex logic.
- Handles conversion between Hex Coordinates and World Space (Pixel) positions.
- Provides distance calculations (`hex_distance`) and line-of-sight/pathfinding helpers (`get_line_coords`).
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
- **State Sync:** Manages the initial handshake and player registration.

## Entities

### Ship (`Scripts/Ship.gd`)
The primary game entity.
- **Visuals:** Handles sprite rendering, rotation, and scaling based on Ship Class.
- **Stats:** Stores Hull, Weapons, Defenses (ICM, Masking Screen).
- **Logic:**
  - `calculate_movement_potential()`: Determines valid moves based on speed and turn cost.
  - `trigger_explosion()`: Visual effects for destruction.
  - **Scaling:** Dynamically sizes sprites relative to `HexGrid.TILE_SIZE`.

## Ship Register

Detailed specifications for all ship classes currently implemented.

| Class | Hull | ADF | MR | Defense | ICM | MS | Weapons |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Fighter** | 8 | 5 | 5 | RH | 0 | 0 | Assault Rockets (x3) |
| **Assault Scout** | 15 | 5 | 4 | RH | 0 | 0 | Laser Battery, Assault Rockets (x4) |
| **Frigate** | 40 | 3 | 3 | RH | 4 | 1 | Laser Battery, Laser Canon, Rocket Battery (x4), Torpedo (x2) |
| **Destroyer** | 50 | 3 | 2 | RH | 4 | 2 | Laser Battery, Laser Canon, Rocket Battery (x6), Torpedo (x2) |
| **Heavy Cruiser** | 80 | 1 | 1 | RH | 8 | 1 | Laser Battery (x3), Laser Canon, Rocket Battery (x8), Torpedo (x4) |
| **Battleship** | 120 | 2 | 2 | RH | 20 | 4 | Laser Canon (x2), Laser Battery (x4), Rocket Battery (x10), Torpedo (x8) |
| **Space Station** | 20-200 | 0 | 0 | RH | 2-8 | 1-4 | Laser Battery (1-3), Rocket Battery (2-12) |

*Note: Space Station stats scale based on Hull points (Randomly generated).*

## Weapon Systems

Combat mechanics and specifications for all weapon types.
**Global Modifiers:**
- **Range:** -5% Hit Chance per hex.
- **Head-On Attack:** +10% Hit Chance.
- **Max Range:** 10 Hexes (Hard cap).

| Weapon | Type | Range | Arc | Damage | Base Chance | Special Rules |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Laser Battery** | Laser | 9 | 360 | 1d10 | 80% | - Reduced to 50% vs RH<br>- Reduced to 10% if Screen active |
| **Laser Canon** | Laser | 10 | FF | 2d10 | 80% | - Reduced to 60% vs RH<br>- Reduced to 20% if Screen active |
| **Assault Rocket** | Rocket | 4 | FF | 2d10+4 | 80% | - Reduced to 60% vs RH<br>- Subject to ICM (-5% per) |
| **Rocket Battery** | Rocket | 3 | 360 | 2d10 | 40% (Flat) | - Flat Base Chance (Distance still applies?)<br>- Subject to ICM (-3% per) |
| **Torpedo** | Torpedo | 4 | 360 | 4d10 | 70% (Flat) | - Flat Base Chance<br>- Subject to ICM (-10% per) |

*Note: "Flat" chances usually ignore Range penalties in some systems, but code implies `Chance = Base - (Dist * 5)`. The "Flat" designation in `Combat.gd` overrides the 80% default base, but the Range logic at line 79 applies to ALL weapons. (Verification needed: `Combat.gd` lines 38-51 return EARLY for Torpedo/RB, skipping line 79?? Yes, they verify `return max(0, chance)`. So Torpedoes/Available Rockets **IGNORE RANGE PENALTY**).*

## Defensive Systems

Mechanics for damage mitigation and avoidance.

### Reflective Hull (RH)
- **Effect:** Permanent passive defense.
- **Laser Battery:** Base hit chance reduced from 80% -> 50%.
- **Laser Canon:** Base hit chance reduced from 80% -> 60%.
- **Assault Rockets:** Base hit chance reduced from 80% -> 60%.
- **Notes:** Does not affect Torpedoes or Rocket Batteries.

### Masking Screen (MS)
- **Effect:** Active defense. Creates a cloud of obscuring particles.
- **Cost:** CONSUMES 1 MS charge per activation.
- **Persistence:** Remains active as long as the ship maintains course and speed (or orbits).
- **Reciprocal:** Affects both incoming AND outgoing fire.
- **Laser Battery:** Base hit chance reduced to 10%.
- **Laser Canon:** Base hit chance reduced to 20%.
- **Notes:** Supersedes Reflective Hull effects when active.

### Inter-Counter-Missiles (ICM)
- **Effect:** Automated point-defense system against ballistic projectiles.
- **Usage:** Passive/Automatic reduction of incoming hit chance.
- **Modifiers:**
  - **vs Torpedo:** -10% Hit Chance per ICM point.
  - **vs Assault Rocket:** -5% Hit Chance per ICM point.
  - **vs Rocket Battery:** -3% Hit Chance per ICM point.

## Scenarios

Available game scenarios and their configurations.

### Surprise Attack!
**Description:** Attackers ambush Station Alpha. The Defiant must escape.

**Defenders (Side A):**
- **Station Alpha** (Space Station)
  - Location: Random hex adjacent to Center (0, 0, 0).
  - Orbit: Clockwise or Counter-Clockwise (Random).
  - Faction: UPF.
- **Defiant** (Frigate)
  - Location: Docked at Station Alpha.
  - Faction: UPF.
- **Stiletto** (Assault Scout)
  - Location: Docked at Station Alpha.
  - Faction: UPF.

**Attackers (Side B):**
- **Spawn:** Random map edge (Distance 24).
- **Venemous** (Destroyer)
  - Location: Edge hex.
  - Heading: Facing inward.
  - Starting Speed: 10
  - Faction: Sathar.
- **Perdition** (Heavy Cruiser)
  - Location: Adjacent to Venemous (Diagonal formation).
  - Heading: Facing inward.
  - Starting Speed: 10
  - Faction: Sathar.

**Objectives:**
- **UPF:** Dock the frigate at the station for 3 turns, then leave the playig area.
- **Sathar:** Prevent the frigate from evacuating the station or leaving the play area after evacuating the station.

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
   - **Combat:** Players plan attacks -> Click "Execute" -> sends plans to Server -> Server sequences -> broadcasts results.

## Key Design Patterns
- **Manager-Controller:** `GameManager` acts as the single source of truth for the game state.
- **Static Utilities:** Math (`HexGrid`) and Rules (`Combat`) are separated from State (`Ship`), making logic easy to test and reuse.
- **RPC Command Pattern:** Actions are validated by the authority (Host) before being executed on clients to prevent desync.
