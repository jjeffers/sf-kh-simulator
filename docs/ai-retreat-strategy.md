# AI Retreat Strategy

## Objective
The computer opponent uses a two-tiered evaluation system to assess when to withdraw from a battle. This logic balances fleet-level strategic preservation with individual ship asset preservation.

## 1. Tier 1: Individual Ship Withdrawal (Ship-Level Assessment)
The AI calculates a `Utility_Retreat` score for each individual ship. If this score exceeds a certain threshold, the ship will automatically use its turn to Withdraw.

### Factors Increasing `Utility_Retreat`
- **Critical Structural Damage:** Hull points drop below a critical threshold (e.g., < 25%).
- **Defensive Collapse:** The ship has no structural integrity and its defensive screens/ICMs are completely depleted or destroyed.
- **Combat Ineffectiveness (Disarmed):** All primary weapons on the ship are destroyed, crippled, or out of ammunition. A ship with an `Attack_Utility` of 0 provides no value to the engagement and should preserve its hull.

### Exceptions (Modifiers Decreasing `Utility_Retreat`)
- **Carrier Duty:** If the ship is an Assault Carrier providing the *only* necessary retrieval capacity for deployed Fighters, it will suffer a massive penalty to its retreat utility, forcing it to stay on the board unless its imminent destruction is a mathematical certainty.
- **Sathar Aggression:** The Sathar's innate aggression trait adds a negative modifier to `Utility_Retreat`, causing them to fight longer than UPF ships under the same conditions.

## 2. Tier 2: Fleet-Level Retreat (Strategic Preservation)
The AI evaluates the overall combat viability of its entire fleet at the start of each turn. If the situation is deemed unwinnable, a "General Retreat" order is issued, causing all surviving AI ships to plot withdrawal routes.

### The Combat Advantage Ratio (CAR)
The AI calculates the total remaining combat power (Hull + Active Weapon output) of its fleet versus the enemy fleet. 

### Retreat Thresholds
- **General Retreat:** If the AI's CAR drops below a critical threshold (e.g., 0.3 or 3-to-1 disadvantage), the Fleet-Level Retreat triggers.
- **Objective Defense Bonus:** If the AI is actively defending a critical structure (like a Space Station or Fortress), the retreat threshold is lowered further (e.g., requires 5-to-1 disadvantage), simulating a "last stand" mentality.
- **Sathar Fanaticism:** Sathar fleets have an inherently much lower threshold for fleet-wide retreat, preferring to fight to the death to inflict maximum casualties, whereas UPF fleets will prefer to preserve forces for future campaign days.

## 3. Execution Mechanics
- **Action Selection:** When a ship determines it must retreat (either individually or due to a fleet-wide order), its primary action for the turn will be forcefully set to "Withdraw", bypassing weapon targeting and movement heatmap selections.
- **Fighters:** Fighters will naturally wait to retreat until their parent carrier retreats, or they will fight to the death to protect it, aligning with the new campaign fighter survival rules.
