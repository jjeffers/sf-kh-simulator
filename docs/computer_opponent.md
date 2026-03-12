# PRD: Project UP-SHIP (Utility-Positioned Ship Intelligence Protocol)

**Project Lead:** James Jeffers

**Target System:** Knight Hawks Tactical Simulator (Godot)

**Objective:** Implement a spatial-aware, decision-weighted AI for turn-based hex combat using Heatmaps and Utility Theory.

---

## 1. Executive Summary

The goal is to move away from rigid state-machine logic and toward an emergent AI system. By decoupling **spatial positioning** (Heatmaps) from **action selection** (Utility), the AI will demonstrate more human-like behaviors such as flanking, kiting, and tactical retreats, specifically tuned for the _Star Frontiers: Knight Hawks_ ruleset.

---

## 2. Auto-Spawning & Faction Initialization

When a match is started, the game evaluates player assignments. If no human players have joined a specific side, the game will automatically "spawn" a computer opponent instance to control all ships for the unrepresented side.

### 2.1 Faction Bias Detection
Upon initialization, the spawned AI detects which faction it has been assigned to control. Identifying the controlled faction (e.g., UPF or Sathar) is critical, as this will trigger faction-specific biases (such as the Sathar's innate aggression) that structurally alter its Utility calculations.

### 2.2 Core System Reliance
Once spawned, the computer opponent does not require a monolithic state machine; instead, it relies entirely on the established implementation modules to fully operate all aspects of gameplay:
- **Deployment:** Uses the heuristics defined in `docs/auto-deploy.md`.
- **Movement & Attack:** Evaluates Heatmaps and Utility scores as defined in `docs/ai-movement-attack.md`.
- **Retreat Strategy:** Assesses fleet advantage and individual ship viability as defined in `docs/ai-retreat-strategy.md`.
- **Fighter Flocking:** Coordinates swarm-like behaviors for fighters as defined in `docs/ai-fighter-flocking.md`.

---

## 3. Component A: The Heatmap Engine (Spatial Intelligence)

The Heatmap Engine evaluates the "value" of every reachable hex on the board.

### 3.1 Layer Definitions

|**Layer**|**Weight (w)**|**Logic**|
|---|---|---|
|**L1: Weapon Reach**|+2.0|High value for hexes in Short/Med range of active batteries where range diffusion is applied.|
|**L2: Firing Arc**|+1.5|Multiplier for hexes where the target is in the Forward Firing arc for ships equipped with forward firing weapons.|
|**L3: Threat Avoidance**|-2.5|Negative value for hexes within player's optimal weapon range.|
|**L4: Collision/Obstacle**|-5.0|Extreme penalty for planets, asteroids, or gravity wells.|
|**L5: Vector Momentum**|+1.0|Favors hexes that don't require maximum MR/ADF to reach.|

### 3.2 Calculation

For each hex $(q, r)$ within current movement range:

$$H_{total}(q, r) = \sum (LayerValue \times w)$$

---

## 4. Component B: The Utility Engine (System Management)

The Utility Engine determines the "desire" to perform specific actions regardless of position.

### 4.1 Core Response Curves

- **Attack Utility ($U_a$):** Increases as hit probability increases.
    
- **Defense Utility ($U_d$):** Increases exponentially as Hull Points ($HP$) decrease or ships systems are disabled..
    
- **Resource Utility ($U_r$):** Decreases as weapons with ammunition ("LTD") are expended.
    

### 4.2 Action Scoring

The AI calculates a score for every possible action $A$ (Fire Laser, Launch Seeker, Activate Screen):

$$Score_A = \text{BasePower} \times U_{need}$$

---

## 5. Component C: Attack Planning and Execution

Once spatial positioning and utility are evaluated, the AI must formulate a deliberate offensive strategy rather than firing weapons indiscriminately.

### 5.1 Target Prioritization
The AI evaluates potential targets based on threat level, current hull integrity, and defenselessness. Priority targets include vessels with disabled defenses or those posing an immediate, high-damage threat to the AI's fleet.

### 5.2 Weapon Grouping and Sequential Execution
- **Optimal Pairing:** Weapons are grouped to maximize effect and match target profiles (e.g., using specific weapons for specific range brackets).
- **Dynamic Re-targeting:** The attack execution resolves sequentially. If a planned attack destroys the primary target, any remaining unspent weapons are dynamically reassigned to secondary targets to prevent overkill and wasted resources.

---

## 6. Component D: Setup Phase Strategy (Initial Deployment)

The AI must intelligently handle the pre-combat setup phase, establishing initial positioning, speeds, facings, and deploying mines before active turn cycles begin.

### 6.1 Deployment Positioning
- **Setup Heatmap:** Generate a specialized Heatmap for the deployment zone. It should favor hexes that cluster the fleet for mutual defense (e.g., overlapping anti-fighter screens) and position heavy ships toward the most likely enemy approach vector.
- **Ship Roles:** Place fragile or high-value vessels (e.g., Carriers, Minelayers) in the rear of the deployment zone, while heavily armored vessels (e.g., Battleships, Heavy Cruisers) are placed forward.

### 6.2 Initial Speed and Facing
- **Vector Optimization:** Set initial facings to align forward-firing weapons with the center of the enemy's likely deployment or key objective areas.
- **Speed Allocation:** Assign initial speeds based on ship classification and ADF/MR constraints. Fast attack craft receive higher initial speeds, while capital ships start at lower speeds to maximize initial Maneuver Rating (MR) flexibility.

### 6.3 Pre-Combat Mine Laying
- **Defensive Screening:** If minelayers are present, evaluate the deployment zone for high-utility mine placement. The AI will autonomously drop mines to create defensive screens or block predictable enemy approach vectors during the setup phase.

---

## 7. Component E: Damage Control and Repair Phase

The AI must intelligently manage its vessels' survivability during the end-of-turn Repair Phase. Efficient damage control is critical for maintaining combat effectiveness, especially for capital ships.

### 7.1 Prioritization of Repairs
- **Critical Systems First:** The AI will prioritize repairing systems that directly impact its ability to maneuver and fight. Scored in order of importance:
  1. **Life Support / Structural Integrity:** Prevents immediate ship destruction (e.g., fixing critical fires or imminent hull breaches).
  2. **Engines and Maneuverability (ADF/MR):** Restoring mobility to escape disadvantageous positions or pursue targets.
  3. **Offensive Capabilities:** Repairing disabled weapon batteries or seeker launchers to maintain damage output.
  4. **Defensive Screens:** Restoring shields or defensive arrays to mitigate incoming damage on subsequent turns.

### 7.2 Resource Allocation
- **Damage Control Rating (DCR):** The AI will evaluate the amount of available DCR on each ship. Rather than spreading repairs out randomly, it will concentrate efforts on allocating up to 90 DCR towards high-priority systems (maximizing success chance) before moving on to less critical damage.
- **Triage Protocol:** If a ship is mathematically unsalvageable (e.g., overwhelming fires and critical hull damage), the AI will cease survival repair efforts on that vessel and instead attempt to maximize its remaining offensive utility by dumping all DCR into weapons before its inevitable destruction.

---

## 8. Technical Requirements (Godot/C# Implementation)

### 8.1 Movement Integration

- **Constraint:** The Heatmap must only be generated for hexes reachable via the ship's current **ADF (Acceleration)** and **MR (Maneuver Rating)**.
    
- **Vector Bias:** The AI must consider its current heading to ensure it doesn't "overshoot" its target unless intended.
    

### 8.2 The Decision Loop

1. **Scan:** Generate Heatmap layers for all valid destination hexes.
    
2. **Filter:** Identify the top 5 candidate hexes.
    
3. **Simulate:** For each candidate hex, calculate the Utility of available actions (including planned attacks) from that position.
    
4. **Fuzziness (Gaussian Noise):** Apply a randomized Gaussian noise value to the final evaluated scores for both move selection and attack planning. This noise introduces "fuzziness" to the AI's logic, preventing highly predictable, mathematically perfect behaviors and simulates organic misjudgment.
    
5. **Execute:** Select the $(Hex, Action)$ pair with the highest combined product and Gaussian noise modifier.
    

---

## 9. Knight Hawks Specific Logic

- **Screen Deployment:** If a Seeker is detected within 2 hexes, the `Utility_Screen` score must override `Utility_Attack`.
    
- **Sathar "Aggression" Bias:** Apply a significant positive modifier (e.g., $+0.5$) to all `Attack Utility` scores for Sathar-controlled vessels. This reflects their lore-accurate tenacity and aggressive combat doctrine, causing them to consistently favor sustained offensive pressure and closing distances even when defensive or evasive maneuvers might be mathematically optimal.
    
- **Masking:** AI should favor hexes where planets/asteroids break Line of Sight (LoS) if `Utility_Defense` is high.
    

---

## 10. Future Extensibility

- **Squad Coordination:** Implementing a shared Heatmap where multiple ships gain bonuses for "Focus Fire" on a single target.
    
- **Personality Profiles:** Adjusting weights $w$ to create "Aggressive," "Cautious," or "Erratic" captains.