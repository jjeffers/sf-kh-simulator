# Walkthrough - Surprise Attack Scenario Fix

I have replaced the hardcoded test ships with a dynamic scenario loader. The game now correctly loads the "Surprise Attack" scenario from `ScenarioManager.gd`.

## Changes
- **GameManager.gd**:
    - Removed `spawn_ships()` and `spawn_station()`.
    - Added `load_scenario(key: String)`.
    - Updated `_ready()` to call `load_scenario("surprise_attack")`.
- **Infrastructure**:
    - Added **GitHub Actions** workflow (`.github/workflows/godot_export.yml`) to automatically build and export the game for Windows and Linux on every push to `main`.

## Verification Results

### Automated Check
The game launches successfully and initializes the scenario.
- **Log Output**: `Station Alpha orbits to (0, 1, -1).`
- **Confirmation**: "Station Alpha" is present, confirming the scenario data is being read (since the old function was removed).
- **Game State**: `Movement Phase: Player 1` active.

### Validated Scenario Data
 The following ships should now appear:
- **Defenders**: Station Alpha, Defiant, Stiletto.
- **Attackers**: Venemous, Perdition.

### CI/CD Pipeline
- **Workflow**: `Godot Export`
- **Triggers**: Push to `master` / `main`.
- **Outputs**:
    - `Windows Build` (Artifact, ZIP Archive)
    - `Linux Build` (Artifact, ZIP Archive)
