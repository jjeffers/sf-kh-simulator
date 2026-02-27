# Hex Space Combat Rules

## Game Turn Sequence
### Description
- The game state is managed in a series of "game turns".
- A "game turn" is split in half between the two sides. In each side's turn, the side will plan and execute movement, and then both sides will plan and execute combat.
- A side that performs movment is the "moving side" and the other side is the "non-moving side".
- Combat is resolved in two phases: passive fire and active fire. During passive fire, the non-moving side will plan and execute defensive fire. During active fire, the moving side will plan and execute offensive fire.
- The game shuold track the current game turn as well as the phase within that side's half of the game turn.

### Procedure
A. Side A Turn
1. **Movement Phase**:
   - All ships and stations in orbit are moved 1 hex in the direction of their orbit (CW or CCW).
   - Side A moves all ships. (See the "Movement" section below.)
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

### Reactive Fire aka Defensive Fire
- During the passive fire phase, the non-moving side may fire weapons at the moving side.
- The non-moving side may fire at a ship at any of the hexes the target ship travelled through during the movement phase.
- For example a non-moving ship may fire at a moving ship that approached to within weapon range during the movement phase, even if the target ship is no longer in range at the end of the movement phase.
- In the attack planning the eligible hexes for firing should be shaded in red. 
- The attack odds should reflect the most favorable odds for the firing side. For example, if range is a variable factor, such as with weapons with range diffusion, the attack odds should reflect the most favorable range for the firing side.
- When the attack is resolved, the animations still are drawn with respect to the target ships end position.


IMPORTANT: damage is counted as it occurs, it's possible for ships to destroyed during a combat phase. Damage take effect immediately!

## Damage Effects

### Explanation
When a weapon hits a target, the next step is to determine the nature of the damage. Some of the effects are merely reductions in hull points. Other effects include debuffs in ships operations, like penalties to hit, or loss of weapons systems.

### Procedure 
A number between 1 and 100 is randomly selected (roll a d100). Then the DTM from the weapon system is applied. The result is taken from the following table, the "Damage Table". 

### Damage Table
| Damage Roll | Result | 
| :--- | :--- |
| 10 or less | Hull hit: roll normal damage, then multiply by 2, and apply to hull points |
| 11-45 | Hull hit: roll normal damage and apply to hull points |
| 46-49 | Drive hit: lose 1 ADF point |
| 50-52 | Drive hit: lose 1/2 total ADF (round up) |
| 53    | Drive hit: lose all ADF |
| 54-58 | Steering hit: lose 1 MR |
| 59-60 | Steering hit: lose entire MR |
| 61-62 | Weapon hit: laser canon, laser battery, proton battery, electron battery, assault rockets, rocket battery |
| 63-64 | Weapon hit: proton battery, electron battery, laser battery, rocket battery, torpedos, assault rockets |
| 65-66 | Weapon hit: disruptor cannon, laser canon, assault rockets, torpedoes, laser battery |
| 67-68 | Weapon hit: torpedoes, assault rockets, electron battery, proton battery, laser battery, rocket battery |
| 69-70 | Weapon hit: laser battery, rocket battery, torpedoes, assault rockets, proton battery, electron battery, laser canon |
| 71-74 | Power short circuit: lose ICMs |
| 75-77 | Defense hit: proton screen, electron screen, stasis screen, masking screens, ICMs |
| 78-80 | Defense hit: masking screens, ICMs, stasis screen, proton screen, electron screen |
| 81-84 | Defense hit: ICMs, stasis screen, proton screen, electron screen, masking screens |
| 85-91 | Combat Control System hit: -10% on all attacks |
| 92-97 | Navigation hit: ADF and MR become 0 |
| 98-105 | Electrical fire: roll addition damage at +20 each turn |
| 106-116 | Damage control hit: lose 1/2 of DCR
| 117+ | Disastrous fire: lose all ADF and MR, -10% on all attacks, roll additional damage at +20 each turn. |

#### Damage Table Notes
- hull hits deduct from target ship hull points.
    -- **Hull Integrity Check**:
      - If a ships hull points are reduced to 50% of it's original hull points, the ship may break apart due to strucutural failure.
      1. Subtract 50% of the ships original hull points (rounded down) from the total hull damage taken.
      2. Multiply the result of step 1 by the ADF plus MR points used in the current movement plan.
      3. The result of step 2 is the % chance the ship will be destroyed from breaking apart.
      - A ship in danger of breaking up should shade the movement plan in red and display the break up % for the controlling side to see near the end position of the movement plan.
- drive hits deduct from ADF as noted in the table
- steering hits deduct from MR as noted in the table
- weapon hits cripple weapons systems in the order they are listed. If a weapon is already damaged, then the next weapon in the list is crippled. A ship with mulitple of the same weapon system will only have one crippled (laser battery, laser canon, etc).
- electrical fire is a condition that causes damage at +20 each turn before either side can do attack planning. If an electrical fire damage table roll indicates a hull hit, the damage to the hull is 1d10.
- disastrous fire is condition that causes damage at +20 each turn before either side can do attack planning. It also inflicts the following debuffs: -10% on all attacks. If a disastrous fire damage table roll indicates a hull hit, the damage to the hull is 1d10.
- Important fire rule: multiple fire results are not cumulative. You can only have a single electrical fire or disastrous fire at a time. Also, the ongoing damage rolls from fires will only ever have a maximum +20 adjustment to the damage table. In other words, multiple fire results will not add additional +20 damage rolls.
- when a damage table indicates a result where no more systems can be damaged or that ship does not have the system indicated to be damaged, the hit is instead a hull hit (roll normal hull hit damage). This rule also applied if a system is destroyed, like a ship with no ADF takes a drive hit, that is converted to a hull hit and normal hull damage is rolled and applied.
- when a result indicates a type of fire but the ship already has a fire of that type it is instead a hull hit (roll normal hull hit damage)

### Damage Control
 - Every ship will have an attribute called "DCR", which represents capacity to repair damaged systems or removed conditions like fires.
 - Once every 3 game turns both sides will be prompted for DCR allocation. This occurs at the end of a game turn, after both sides have moved, etc.
 - The amount of DCR allocated represents a % chance that crippled system will be repaired or damage repaired.
 - The maximum amount of DCR you can allocate to a system is 100.
 - The event for repair occurs after the 3rd full cycle of each side's movement and then combat. This is called a Repair Turn.
 - Each side will have sperate repair turn phases, first 1 side, then the other. It does not matter which side goes first, but it must be the same side each turn.

 #### Procedure 
 - During a repair turn each each side will be presented with a list of ships that have damaged systems or conditions. The player will be prompted to allocate DCR to each ship. The DCR allocated to each ship will be used to repair the damaged systems or conditions.
 - Each ship will present a list of damaged sytems and a DCR budget, which is the ship's current effective DCR. (Note tht DCR can be reduced from the start by damage table results.)
 - Each side may allocate DCR to each damaged system or condition. 
 - The DCR allocated must be between 0 and 100.
 - Once all ships have DCR allocated, the side must click the "Execute Repair" button in the ship list to complete the repair turn.
 - Each repair is then attempted in order of the ship list. There should be a brief delay between each repair attempt (like the attack resolution) and a message displayed on the outcome in the logs and on the display.
 - A d100 is rolled for each repair attempt. If the roll is the DCR allocated or under, the repair is successful.
 -- if the repair roll is 90-100, the repair always fails.
 -- if the repair roll is 99 or 100, the repair fails and no futher repair attempts are possible for that system or condition.
 #### Repair Systems Notes
- MR repairs: each point of MR lost must be repaired separately.
- ADF repairs: each point of ADF lost must be repaired separately.
- Fire repairs: successfully repairing extinguishes the fire but not the damage the fire caused.
- hull repairs: successfully repairing restores 1d10 hull points


## Movement
- Procedure: a side will *plan* all movement, but the ships do not move until the end of the planning phase, once the "Execute Movement" button is pressed. This is important because in future game updates, there may be hidden movement hazards that are only revealed when the movement is executed.
- A planned movement is represented by 2 visual elements: a line connecting the starting hex to the destination hex, and a "ghost ship" in the end position which also includes the facing of the ship.
- Ships that are "locked" into specific movement plans (proabably due to lack of navigation control) will generate a predetermined movement plan. If the ship has no ADF it cannot alter the number of hexes it will move (it must move the number of hexes equal to its speed). If a ship has no effective MR, then it cannot change facing, even at speed 0.
- if a movement plan navigates a ship into a planet, the plan should be visual altered to show the impending ship destruction. The movement plan should have a red or orange plan line, and the hex where the ship will be destroyed should be highlighted in red or orange. The ship should also be highlighted in red or orange. Once the player "undoes" the movement plan, the ship should be returned to its original position and the movement plan should be removed. This warning is to help players recognize, but not prevent, poor planning. Note that in some cases (such as a loss of navigation control) this will unavoidable!

- Driven by **ADF** (Acceleration/Deceleration Factor).
- Ships can accelerate/decelerate by up to ADF in hexes.
- A ship must move the minimum number of hexes which is their current speed minus their ADF.

- **Turning**: 
- Driven by MR (maneuver rating).
- A ship may change it's facing to any direction of it's speed is 0. Otherwise a ship may change facing by 1 hexside when they enter a new hex.
- When planning movement the player may select a hex to move to and then use the the mouse to switch facings, left or right or straight ahead, if current MR allows it. An "undo" button will unwind the entire movement plan.
- A ship with speed 0 and and effective MR > 0 may freely rotate to any facing.

- **Orbiting**: Special maneuver for ships starting their movement in a hex adjacent to a planet. The ship will orbit the planet clockwise or counter-clockwise, player's choice. The ship will orbit the planet until it decides to move out of the hex away from the planet.

- **Planets**: 
- Planets block attacks and attack planning that pass through their hex.
- Ships entering a hex with a planet are destroyed.
- Planets generate a gravity well that affects ship movement. Each hex adjacent to a planet can be treated as containing a gravity well. If a ship traverses any adjecent hex, they ship is turned 1 facing towards the planet. A ship must have an effective MR of 1 or greater to resist this turn. This forced facing change occurs once despite the number of adjecent hexes traversed. 

**Docking**:
- a ship may dock with a space station if it has a speed 0 in the same hex as the space station. 
- fighter may dock with an assault carrier if it has a speed 0 in the same hex as the assault carrier
- For docking purposes, a speed of 0 means if the ship ends the movement phase in the same hex as the space station or assault carrier and has an effective ADF > the ships's current speed.
- If a ship is able to dock, then there should be a UI option to "dock" the ship. 
- To undock, a ship simply has to use an "undock" button in the UI, or plot movement away from the space station or assault carrier.
- Once docked, a docked ship moves with the space station or assault carrier as the space station or assault carrier moves.
- A docked ship may not fire FF weapons.
- Docked fighters and assault scouts may not be targeted by attacks when docked.


**Re-arming**:
- fighters and assault scouts may re-arm with assault rockets if they remain docked with a sace station or assault carrier for one full game turn
- a fighter or assault scout may re-arm as many times as the space station or assault carrier has remaining re-arm capacity.
- An assault carrier carries x20 re-arm capacity.
- A space station carries re-arm capacity of x2 per fighter group stationed.

## Ship Registry

Detailed specifications for all ship classes currently implemented.

| Class | Hull | ADF | MR | Defense | ICM | MS | Weapons | DCR|
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---|
| **Fighter** | 8 | 5 | 5 | RH | 0 | 0 | Assault Rockets (x3) | 30 |
| **Assault Scout** | 15 | 5 | 4 | RH | 0 | 0 | Laser Battery, Assault Rockets (x4) | 50 |
| **Frigate** | 40 | 4 | 3 | RH, ICMs (x4) | 4 | 1 | Laser Battery, Laser Canon, Rocket Battery (x4), Torpedo (x2) | 70 |
| **Minelayer** | 40 | 1 | 2 | RH | 4 | 4 | Laser Battery (x2), Mines (x20) | 75 |
| **Destroyer** | 50 | 3 | 3 | RH | 5 | 2 | Laser Battery, Laser Canon, Electron Battery, Rocket Battery (x6), Torpedo (x2) | 75 |
| **Light Cruiser** | 70 | 3 | 2 | RH, ES, SS | 8 | 1 | Disruptor Canon, laser battery, electron battery, proton battery, Rocket Battery (x6), Torpedo (x4) | 100 |
| **Heavy Cruiser** | 80 | 2 | 1 | RH, PS, SS | 8 | 1 | Laser Battery (x2), proton battery, electron battery, Disruptor Canon, Rocket Battery (x8), Torpedo (x4) | 120 |
| **Battleship** | 120 | 2 | 2 | RH, PS, ES, SS | 12 | 4 | Disruptor Canon, Laser Battery (x3), proton battery, electron battery (x2), Rocket Battery (x10), Torpedo (x8) | 200 |
| **Assault Carrier** | 75 | 2 | 1 | RH | 10 | 4 | Laser Battery, proton battery, Rocket Battery (x8) 150 |
| **Space Station** | 20-200 | 0 | 0 | RH, ES, SS, PS | 2-8 | 1-4 | 1 electron battery or 1 proton battery or 1 laser battery pe 50 hull points, Rocket Battery (2-12) | 1/2 hull points |

*Note: Space Station stats scale based on Hull points (Randomly generated).*

## Weapon Systems

Combat mechanics and specifications for all weapon types.
**Global Modifiers:**
- **Head-On Attack:** +10% Hit Chance for forward firing weapons (FF) if the target is in the row of hexes directly forward of a firing ship.
- **Max Range:** 10 Hexes (Hard cap).

| Weapon | Type | Range | Attributes | Damage | base % | % vs RH | % vs PS | % vs ES | %vs SS | % vs MS | DTM | Special Rules |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | 
| **Laser Battery** | Laser | 9 | RD | 1d10 | 65 | 50 | 65 | 65 | 65 | 20| 0 | 1/2 damage on hull hits if target has masking screen |
| **Laser Canon** | Laser | 10 | FF, RD | 2d10 | 75 | 60 | 75 | 75 | 25 | 0 | 1/2 damage on hull hits if target has masking screen |
| **Electron Beam Battery** | Laser | 10 | RD | 1d10 | 60 | 60 | 25 | 70 | 40 | 50| 10 | 1/2 damage on hull hits if target has a proton screen |
| **Proton Beam Battery** | Laser | 12 | RD | 1d10 | 60 | 60 | 70 | 26 | 40 | 50| 10 | 1/2 damage on hull hits if target has an electron screen |
| ***Disruptor Cannon*** | Laser | 9 | FF, RD | 3d10 | 60 | 60 |50 | 50 | 40 | 50 | 20 | |
| **Assault Rocket** | Rocket | 4 | FF, LTD, MPO | 2d10+4 | 60 | 60 | 60 | 60 | 60 | 60 | -10 | - Reduced to 60% vs RH<br>- Subject to ICM (-5% per) |
| **Rocket Battery** | Rocket | 3 | LTD | 2d10 | 40 | 40 | 40 | 40 | 40 | 40 | -10|  <br>- Subject to ICM (-3% per) |
| **Torpedo** | Torpedo | 4 | LTD, MPO | 4d10 | 50 | 50 | 50 | 50 |75 | 50 | -20 | <br>- Subject to ICM (-10% per) |
| **Mine** | Mine | 0 | LTD | 3d10+5 | 60 | 60 | 60 | 60 | 80 | 60 | 0 | <br>Subject to ICM (-8% per) | 

RD = Range Diffusion (weapon accuracy degrades 5% per hex), FF = Forward Fire, MPO = Moving player only (not valid for defensive fire), LTD = Limited Ammunition (limited number of uses), PR = proton screen, ES = electron scrren, SS = stasis screen, MS = masking screen, RH = reflective hull

### Mines
Note that mines are always visible to the owning side, but never shown to the enemy side. Mines detonate when an enemy ship or ships enter a hex containing the mine. All enemy ships entering the mined hex are attacked separately by the mine. After the mine detonates, the hex is cleared of that mine. Mines may be deployed during the setup phase, typically taken from the stock of mines carried by a minelayer. Mines may also be placed into a hex by a minelayer during movement planning. A "drop mine" button should be shown if the selected ship is a minelayer. Clicking the "drop mine" button should place a mine in the hex that the minelayer is currently in. The mine will remain in that hex until it detonates. 

A weapon's chance to hit is not effected by distance unless it has the RD attribute.
Weapons have can fire in any direction unless they have the FF attribute.

DTM in the table above refers to Damage Table Modifier. 

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

### Defensive Energy Screen
- **Description:**: A powered energy field of charged particles.
- **Types:**:
  - Proton Screen: effective in blocking proton and disruptor beams, but attracts electron beams.
  - Electron Screen: effective in blocking electron and disruptor beams, but attracts proton beams.
  - Stasis Screen: Moderately effective against electric beams weapons but attracts the homing systems or torpedoes, assault rockets, and rocket batteries.
- **Activation:**
  - A ship may select one or no active defensive screens to energize during movement planning. This will be repeseneted by a selection in the ship status panel. This selection can only be made during movement planning.
  - A ship may only activate screens one at a time.
  - A ship may only activate screens ir is equipped with. (Some ships have no defensive energy screens.)

### Interceptor Missiles ("ICMs")
- **Effect:** Automated point-defense system against ballistic projectiles.
- **Usage:** Passive/Automatic reduction of incoming hit chance.
- **Modifiers:**
  - **vs Torpedo:** -10% Hit Chance per ICM point.
  - **vs Assault Rocket:** -5% Hit Chance per ICM point.
  - **vs Rocket Battery:** -3% Hit Chance per ICM point.
- Ships in the same hex as a ship targeted by torpedoes, assault rockets, or rocket batteries may fire ICMs at the incoming projectiles. When the ICM dialog is opened, all ships in the same hex as the targeted ship will be listed and can contribute ICMs to the defense. The dialog will show the current ICMs available for each ship and the total ICMs available for the defense. As the ICMs are allocated, the attack odds reduction will be shown in the dialog.

## Scenarios

Available game scenarios and their configurations.

Setup: if there is a planet present, ships should not spawn in the same hex as the planet.

### Setup Phase

Each side is given a chance to deploy their ships on the map. Unless otherwise specifed the defenders deploy first, then the attackers deploy. 

Typically each side may setup their ships with whatever starting speed and facing they desire.

Attackers typically must deploy at a distance of 34 hexes from the center of the map.

Scenarios may specify deployment constraints (e.g. starting positions, speeds, facings, etc.) for space stations, planets, and ships.

#### Deployment UI
Each deploying side should see a list of ships available to deploy, similar to the ship list seen in movement planning.

Once a ship is selected, the side should be able to select a hex to deploy the ship in. The hex must be within the deployment zone for that side. The side may set a starting speed and facing for the ship. 

- Space stations are typically placed in orbit around planets. The deployment UI should highlihght the available hexes for placement (all hexes adjacent to the planet).

There should be a button to confirm the deployment of the current ship ("DEPLOY SHIP") or right click, and a button to confirm the deployment of all ships ("COMPLETE DEPLOYMENT").

Once the first side completes deployment, the other side should be notified and given a chance to deploy their ships.

When both sides have completed deployment, the game should proceed to the first turn.


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
- **Venemous** (Destroyer)
  - Faction: Sathar.
- **Perdition** (Heavy Cruiser)
  - Faction: Sathar.

**Setup:**
 - UPF sets up first.
- The defenders are deployed as docked at the station.
- The attackers may deploy together or an adjacent hexes 34 hexes from the center.
  
- **Venemous** (Destroyer)
- **Perdition** (Heavy Cruiser)

**Special Rules**
 - The UPF frigate Defiant must dock for 3 gae turns to complete evacuation. After the 3rd game turn the station is considered evacuated.
 - Once evacuated the station may no longer fire weapons or activate screens.

**Objectives:**
- **UPF:** Dock the frigate Defiant at the station for 3 turns, then leave the playig area.
- **Sathar:** Prevent the frigate from evacuating the station or leaving the play area after evacuating the station.

## Close Escort
**Description:** UPF forces must escort a transport ship to an escape position before the Sathar can destroy it.

**UPF (Defenders):**
- **Courageous** (Light Cruiser)
- **Scimitar** (Assault Scout)UPF.
- **Dagger** (Assault Scout)
- **Megasaurus** (Civilian bulk transport), hull points 75, ADF 1, MR 1, DCR 40, no weapons, x1 masking screen

**Sathar (Attackers):**
- **Faminewind** (Light Cruiser)
  - Faction: Sathar.
- **Nemesis** (Destroyer)
  - Faction: Sathar.

**Setup:**
 - UPF sets up first on the right-most edge of the playing area. The transport ship must start with a speed of 5.
- The attackers must deploy on the left-most edge of the playing area.
  
**Special Rules**
 - The Megasaurus must reach the left hand side of the paying area. It may only travel in a straight line.
 - Randomaly determine who moves first in this scenario.

**Objectives:**
- **UPF:** ensure the Megauraus escapes by reaching the left and side of the map.
- **Sathar:** Destroy the Megasaurus.

### The Last Stand
**Description:** A massive Sathar fleet assaults Fortress K'zdit. UPF must hold the line.

**Setup:**
- The UPF sets up first.
- The planet is placed near the center of the map.
- The space station is placed in orbit around the planet.
- The UPF forces may be deployed anywhere on the map and given any starting speed and facing.
- The Sathar forces must deploy 34 hexes from the center of the map, but all Sathar ships must be within 2 hexes of each other. Sathar ships may be placed with any starting speed and facing.

**UPF (Defenders):**
- **Fortress K'zdit** (Space Station - Custom)
  - Stats: 100 Hull, 8 ICM, 2 MS.
  - Weapons: 3x Laser Battery, x12 Rocket Battery (12 shots).
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


### Simple Test
**Description:** A simple test scenario to test the game engine.

**UPF (Defenders):**
- **Vigilant** (Frigate)
  - **Spawn**: 2 hexes to the left of the center.
  - Faction: UPF.
- **Defiant** (Frigate)
  - **Spawn**: adjacent to Vigilant.
  - Faction: UPF.
**Sathar (Invaders):**
- **Savage** (Frigate)
  - **Spawn:** 2 hexes to the right of the center.
  - Faction: Sathar.
- **Stinger** (Frigate)
  - **Spawn:** adjacent to Savage.
  - Faction: Sathar.

## Battle of Ken'zah
**Description:** The UPF must defend Ken'zah Station from a Sathar assault.

**Setup:**
- The UPF sets up first.
- The planet is placed near the center of the map.
- The space station is placed in orbit around the planet.
- The UPF forces may be deployed anywhere on the map and given any starting speed and facing.
- The Sathar forces must deploy 34 hexes from the center of the map, but all Sathar ships must be within 2 hexes of each other. Sathar ships may be placed with any starting speed and facing.
- The Sathar side will move first.

**UPF (Defenders):**
- **Ken'zah Station** (Space Station - Custom)
  - Stats: 140 Hull, DCR 100 
  - Weapons: laser battery (x2), rocket battery (x8)
  - Defenses: reflective hull, 10 ICM, 2 MS.
  **Fighters** (wings A, B, C, D, E, F)
- **Z'Rak't Zoz** (Minelayer)
- **Shimmer** (Frigate)
- **Zz'Nakk'T** (Frigate)
- **Rapier, Lancet** (Assault Scouts)

**Sathar (Attacker):
- **Maelstrom** (Assault Carrier)
- **Fighters** (wings A, B, C, D, E, F) - docked with the Maelstrom
- **Bludgeon, Viper** (Destroyers)
- **Deathstroke** (Light Cruiser)
- **Carrion** (Heavy Cruiser)