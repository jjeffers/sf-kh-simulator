# PRD: Project UP-SHIP (Utility-Positioned Ship Intelligence Protocol)

**Project Lead:** James Jeffers

**Target System:** Knight Hawks Tactical Simulator (Godot)

**Objective:** Implement a spatial-aware, decision-weighted AI for turn-based hex combat using Heatmaps and Utility Theory.

---

## 1. Executive Summary

The goal is to move away from rigid state-machine logic and toward an emergent AI system. By decoupling **spatial positioning** (Heatmaps) from **action selection** (Utility), the AI will demonstrate more human-like behaviors such as flanking, kiting, and tactical retreats, specifically tuned for the _Star Frontiers: Knight Hawks_ ruleset.

---

## 2. Component A: The Heatmap Engine (Spatial Intelligence)

The Heatmap Engine evaluates the "value" of every reachable hex on the board.

### 2.1 Layer Definitions

|**Layer**|**Weight (w)**|**Logic**|
|---|---|---|
|**L1: Weapon Reach**|+2.0|High value for hexes in Short/Med range of active batteries where range diffusion is applied.|
|**L2: Firing Arc**|+1.5|Multiplier for hexes where the target is in the Forward Firing arc for ships equipped with forward firing weapons.|
|**L3: Threat Avoidance**|-2.5|Negative value for hexes within player's optimal weapon range.|
|**L4: Collision/Obstacle**|-5.0|Extreme penalty for planets, asteroids, or gravity wells.|
|**L5: Vector Momentum**|+1.0|Favors hexes that don't require maximum MR/ADF to reach.|

### 2.2 Calculation

For each hex $(q, r)$ within current movement range:

$$H_{total}(q, r) = \sum (LayerValue \times w)$$

---

## 3. Component B: The Utility Engine (System Management)

The Utility Engine determines the "desire" to perform specific actions regardless of position.

### 3.1 Core Response Curves

- **Attack Utility ($U_a$):** Increases as hit probability increases.
    
- **Defense Utility ($U_d$):** Increases exponentially as Hull Points ($HP$) decrease or ships systems are disabled..
    
- **Resource Utility ($U_r$):** Decreases as weapons with ammunition ("LTD") are expended.
    

### 3.2 Action Scoring

The AI calculates a score for every possible action $A$ (Fire Laser, Launch Seeker, Activate Screen):

$$Score_A = \text{BasePower} \times U_{need}$$

---

## 4. Component C: Setup Phase Strategy (Initial Deployment)

The AI must intelligently handle the pre-combat setup phase, establishing initial positioning, speeds, facings, and deploying mines before active turn cycles begin.

### 4.1 Deployment Positioning
- **Setup Heatmap:** Generate a specialized Heatmap for the deployment zone. It should favor hexes that cluster the fleet for mutual defense (e.g., overlapping anti-fighter screens) and position heavy ships toward the most likely enemy approach vector.
- **Ship Roles:** Place fragile or high-value vessels (e.g., Carriers, Minelayers) in the rear of the deployment zone, while heavily armored vessels (e.g., Battleships, Heavy Cruisers) are placed forward.

### 4.2 Initial Speed and Facing
- **Vector Optimization:** Set initial facings to align forward-firing weapons with the center of the enemy's likely deployment or key objective areas.
- **Speed Allocation:** Assign initial speeds based on ship classification and ADF/MR constraints. Fast attack craft receive higher initial speeds, while capital ships start at lower speeds to maximize initial Maneuver Rating (MR) flexibility.

### 4.3 Pre-Combat Mine Laying
- **Defensive Screening:** If minelayers are present, evaluate the deployment zone for high-utility mine placement. The AI will autonomously drop mines to create defensive screens or block predictable enemy approach vectors during the setup phase.

---

## 5. Technical Requirements (Godot/C# Implementation)

### 5.1 Movement Integration

- **Constraint:** The Heatmap must only be generated for hexes reachable via the ship's current **ADF (Acceleration)** and **MR (Maneuver Rating)**.
    
- **Vector Bias:** The AI must consider its current heading to ensure it doesn't "overshoot" its target unless intended.
    

### 5.2 The Decision Loop

1. **Scan:** Generate Heatmap layers for all valid destination hexes.
    
2. **Filter:** Identify the top 5 candidate hexes.
    
3. **Simulate:** For each candidate hex, calculate the Utility of available actions from that position.
    
4. **Execute:** Select the $(Hex, Action)$ pair with the highest combined product.
    

---

## 6. Knight Hawks Specific Logic

- **Screen Deployment:** If a Seeker is detected within 2 hexes, the `Utility_Screen` score must override `Utility_Attack`.
    
- **Sathar "Aggression" Bias:** Apply a $+0.5$ modifier to all `Attack Utility` scores for Sathar-controlled vessels to simulate their lore-accurate tenacity.
    
- **Masking:** AI should favor hexes where planets/asteroids break Line of Sight (LoS) if `Utility_Defense` is high.
    

---

## 7. Future Extensibility

- **Squad Coordination:** Implementing a shared Heatmap where multiple ships gain bonuses for "Focus Fire" on a single target.
    
- **Personality Profiles:** Adjusting weights $w$ to create "Aggressive," "Cautious," or "Erratic" captains.