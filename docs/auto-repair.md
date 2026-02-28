# Auto-Repair Processor (AI Damage Control)

**Target System:** Knight Hawks Tactical Simulator (Godot)

**Objective:** Define the rules and technical implementation for how the Computer Opponent automatically allocates Damage Control (DC) teams during the end-of-turn Repair Phase.

---

## 1. Executive Summary

During the Knight Hawks Repair Phase, each ship possesses an attribute called DCR. DCR is allocated to ship systems to repair damage during the Repair Phase. (The DCR value is static unless damaged by combat results.) The `AutoRepairProcessor` is tasked with evaluating a vessel's current damage profile and automatically dispatching these DC teams to maximize the ship's combat survival and effectiveness on the following turn.

Unlike human players who might spread repairs thinly across multiple systems, the AI is programmed to mathematically prioritize immediate survival and mobility, concentrating its DC efforts to fully bring critical systems back online before addressing minor inconveniences.

---

## 2. Damage Control (DC) Evaluation Math

### 2.2 System Repair Costs
The AI inherently "knows" the rules of Knight Hawks repairs - the amount of DCR allocated represents a % chance that repair will be successful. A maximum of 90DCR should be allocated to any single system because any result of 91+ on a d100 roll will result in the repair failing. 

---

## 3. Repair Triage Protocol

A core component of the `AutoRepairProcessor` is the **Triage Protocol**. Before assigning any DCR, the AI runs a survivability check.

**The Triage Check:**
If a ship's current Fire counters $\ge$ its current Hull Points (meaning the fire damage resolved at the start of the next turn will definitively destroy the ship), the AI considers the ship "Mathematically Unsalvageable."

**Triage Action:**
If a ship is Unsalvageable, the AI abandons all long-term survivability repairs (Extinguishing Fires, repairing Hull Points). Instead, it allocates 100% of its DCR to repairing **Offensive Weapons** (up to 90 DCR per weapon), attempting to maximize the ship's final damage output in its last combat phase before destruction.

---

## 4. Standard Priority Queue

For ships that survive the Triage Check, the AI sorts all active damage into a strict Priority Queue and allocates DCR top-down until all DCR is exhausted.

### Priority 1: Prevent Imminent Destruction
*   **Target:** Fires.
*   **Logic:** The AI allocates up to $90$ DCR per active Fire combat counter, up to the amount of available DCR. Unchecked fires guarantee hull damage and system cascades.

### Priority 2: Restore Core Mobility
*   **Target:** Disabled Engines.
*   **Logic:** If the `engines_disabled` flag is true, up to $90$ DCR is allocated. A stationary capital ship is a target-rich environment.

### Priority 3: Restore Primary Offense
*   **Target:** Disabled Weapons.
*   **Logic:** The AI prioritizes weapons by their Utility score (typically base damage or max range length). It spends up to $90$ DCR per disabled battery, starting from the highest-utility weapon. 
*   *Implementation Note:* The AI checks if a Seeker launcher is out of ammo before repairing it; it will not waste DCR repairing an empty battery.

### Priority 4: Restore Defenses
*   **Target:** Disabled Defenses / Screens.
*   **Logic:** The AI allocates up to $90$ DCR per disabled defense system (e.g., Albedo Screen, ICMs).

### Priority 5: Hull patching
*   **Target:** Hull Points.
*   **Logic:** Any remaining DCR not absorbed by the above priorities are dumped into repairing Hull Points (up to $90$ DCR per HP).

---

## 5. Technical Implementation (Godot/GDScript)

### 5.1 Architecture
Create a new utility class: `res://Scripts/AutoRepairProcessor.gd`
This class will be stateless and expose a primary method:
`func execute_repairs(game_manager: GameManager, side_id: int)`

### 5.2 Execution Flow

1.  **Poll Phase:** The `ComputerOpponent` script will call `AutoRepairProcessor.execute_repairs()` when `GameManager.current_phase == Phase.REPAIR` and it is the AI's respective repair subphase.
2.  **Filter Fleet:** Filter `game_manager.ships` for valid instances where `side_id == side_id` and `is_exploding == false`.
3.  **Process Ship:** For each ship, read its available DCR.
4.  **Triage Branch:** Evaluate Fire vs HP.
5.  **Assign Teams:** Deduct allocated DCR sequentially through the priority checks until DCR reaches $0$ or all damage is accounted for.
6.  **Network Sync:** The `AutoRepairProcessor` MUST construct a discrete repair payload containing the planned fixes for each ship. It then calls `game_manager.rpc_submit_repairs(side_id, repair_payload)` to ensure clients sync the AI's decisions identically to a human player clicking the "Commit Repairs" button.
