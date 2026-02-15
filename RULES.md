# Hex Space Combat Rules

## Turn Sequence
A. Side A Turn
1. **Movement Phase**:
   - All ships and stations in orbit are moved 1 hex in the direction of their orbit (CW or CCW).
   - Side A moves all ships.
2. **Combat Phase**:
   - **Passive Fire**: The non-moving side (Side B) plans and executes defensive fire.
   - **Active Fire**: The moving player plans and executes offensive fire.

B. Side B Turn
1. **Movement Phase**:
  - All ships and stations in orbit are moved 1 hex  in the direction of their orbit (CW or CCW).
   - Side B moves all ships.
2. **Combat Phase**:
   - **Passive Fire**: The non-moving side (Side A) plans and executes defensive fire.
   - **Active Fire**: The moving player plans and executes offensive fire.

IMPORTANT: damage is counted as it occurs, it's possible for ships to destroyed during a combat phase. Damage take effect immediately!

## Movement
- Driven by **ADF** (Acceleration/Deceleration Factor).
- Ships can accelerate/decelerate by up to ADF in hexes.
- A ship must move the minimum number of hexes which is their current speed minus their ADF.

- **Turning**: A ship may change it's facing to any direction of it's speed is 0. Otherwise a ship may change facing by 1 hexside when they enter a new hex.
  When planning movement the player may select a hex to move to and then use the the mouse to switch facings, left or right or straight ahead, if current MR allows it. An "undo" button will unwind the last segment of movement (direction and facing). Multiple undos will unwind the entire movement plan.

- **Orbiting**: Special maneuver for ships starting their movement in a hex adjacent to a planet. The ship will orbit the planet clockwise or counter-clockwise, player's choice. The ship will orbit the planet until it decides to move out of the hex away from the planet.

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
- **Head-On Attack:** +10% Hit Chance for forward firing weapons (FF) if the target is in the row of hexes directly forward of a firing ship.
- **Max Range:** 10 Hexes (Hard cap).

| Weapon | Type | Range | Attributes | Damage | Base Chance | Special Rules |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Laser Battery** | Laser | 9 | RD | 1d10 | 80% | - Reduced to 50% vs RH<br>- Reduced to 10% if Screen active |
| **Laser Canon** | Laser | 10 | FF, RD | 2d10 | 80% | - Reduced to 60% vs RH<br>- Reduced to 20% if Screen active |
| **Assault Rocket** | Rocket | 4 | FF, LTD, MPO | 2d10+4 | 80% | - Reduced to 60% vs RH<br>- Subject to ICM (-5% per) |
| **Rocket Battery** | Rocket | 3 | LTD | 2d10 | 40% (Flat) | <br>- Subject to ICM (-3% per) |
| **Torpedo** | Torpedo | 4 | LTD, MPO | 4d10 | 70% (Flat) | <br>- Subject to ICM (-10% per) |

RD = Range Diffusion (weapon accuracy degrades 5% per hex), FF = Forward Fire, MPO = Moving player only (not valid for defensive fire), LTD = Limited Ammunition (limited number of uses)


A weapon's chance to hit is not effected by distance unless it has the RD attribute.
Weapons have can fire in any direction unless they have the FF attribute.

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

Setup: if there is a planet present, ships should not spawn in the same hex as the planet.

### Surprise Attack!
**Description:** Attackers ambush Station Alpha. The Defiant must evacuate the station and then escape.

**Defenders (Side A):**
- **Station Alpha** (Space Station, 25 hull points, laser battery, reflective hull, x6 ICMs)
  - Location: Random hex adjacent to a planet at Center (0, 0, 0).
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
  - Heading: Facing toward the center.
  - Starting Speed: 10
  - Faction: Sathar.
- **Perdition** (Heavy Cruiser)
  - Location: Adjacent to Venemous (Diagonal formation).
  - Heading: Facing toards the center.
  - Starting Speed: 10
  - Faction: Sathar.

**Special Rules**
 - The UPF frigate Defiant must dock for 3 turns to complete evacuation. After the 3rd turn the station is considered evacuated.
 - Once evacuated the station may no longer fire weapons or activate screens.

**Objectives:**
- **UPF:** Dock the frigate Defiant at the station for 3 turns, then leave the playig area.
- **Sathar:** Prevent the frigate from evacuating the station or leaving the play area after evacuating the station.

### The Last Stand
**Description:** A massive Sathar fleet assaults Fortress K'zdit. UPF must hold the line.

**UPF (Defenders):**
- **Fortress K'zdit** (Space Station - Custom)
  - Stats: 100 Hull, 8 ICM, 2 MS.
  - Weapons: 3x Laser Battery, x12 Rocket Battery Swarm (12 shots).
- **Valiant** (Battleship)
- **Allison May** (Destroyer)
- **Daridia** (Frigate)
- **Dauntless, Razor** (Assault Scouts)
- **Fighters** (2 wings)

**Sathar (Invaders):
- **Infamous** (Assault Carrier)
- **Star Scourge** (Heavy Cruiser)
- **Vicious, Pestilence, Doomfist** (Destroyers)
- **Stinger** (Frigate)
- **Fighters** (2 wings, docked with the Infamous)


## Winning Conditions
- Scenarios may have specific victory conditios, but generally destroying all enemy ships is the goal.
