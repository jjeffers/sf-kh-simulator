# AI Movement & Attack Implementation Principles

The primary artificial intelligence for combat and movement phases is handled dynamically, relying on spatial evaluation and utility scoring rather than rigid state machines. This system governs where a computer-controlled ship moves, who it targets, and how it handles its ordnance.

## 1. Goal Setting & The Decision Engine

The AI evaluates its options by decoupling spatial positioning (Movement) from action selection (Utility). It calculates the best possible physical locations to travel to, and simultaneously calculates its strongest desire to perform a specific action, combining these metrics to make procedural decisions.

## 2. Spatial Heatmap Generation (Movement)

During the Movement phase, the AI evaluates a list of valid destination hexes constrained by the ship's current **Acceleration (ADF)** and **Maneuver Rating (MR)**. It assigns floating-point scores to these hexes based on the following heuristic layers:

- **Weapon Reach Layer:** Hexes that place the enemy within Short or Medium range of the acting ship's active weapon batteries receive a massive positive spike (`+20` weight).
- **Firing Arc Adherence:** Hexes that naturally align forward-firing weapons towards the target receive a multiplier (`+15`), reducing the MR needed to spin and fire.
- **Threat Avoidance Layer:** Hexes positioned directly within the optimal firing ranges of a threatening enemy vessel receive significant negative weights (`-25`). 
- **Planetary/Obstacle Avoidance:** Pathing directly through a planet or an asteroid field results in extreme penalties (`-1000` or discarded entirely) to prevent self-destruction.
- **Vector Momentum:** A small positive modifier (`+5`) is given to hexes aligned with the ship's current vector, encouraging smooth, realistic engine movement rather than erratic zigzagging.
- **Seeker Activation:** If seekers are available and not yet activted, the defender will evaluate enemy ships nearest the seeker. Enemy ships within 2 hexes are highly rated for attack by seeker activation. The value decreases with distance to the enemy ship, and also decreases if friendly ships are closer to the seeker. If the value crosses an aggression threshold the AI will activate that seeker.

## 3. Utility Scoring (Action Selection)

Independently of the heatmap, the AI calculates a raw "desire" score for every action available to it (e.g., Firing a Laser, Launching a Seeker, Activating a Defensive Screen).

- **Attack Utility ($U_a$):** Increases linearly with hit probability and scales against target priority. Targets with lower Hull Points or disabled defensive systems inherently provide a higher return on investment, spiking their $U_a$ score.
- **Defense Utility ($U_d$):** Exponentially increases as the acting ship takes damage. Once Hull Points approach critical thresholds, $U_d$ overrides $U_a$, forcing the AI to prioritize evasive heatmap hexes or activate defensive screens over raw damage output.
- **Resource Utility ($U_r$):** Ensures the AI is conservative with limited ammunition (like Torpedoes), preventing them from being fired at low-percentage targets.

## 4. Attack Execution & Fuzziness

When committing to a movement path and target, the AI combines the Heatmap Score and the Utility Score.

- **Gaussian Noise Integration:** A randomized noise value (e.g., `rng.randfn(0.0, 10.0)`) is applied to the final calculated scores for both movement destinations and target prioritization. This fuzziness prevents the AI from being perfectly mathematically predictable, simulating the organic misjudgments of an imperfect captain.
- **Sequential Re-targeting:** The AI plans its weapon volleys strategically. If the first volley of attacks successfully destroys the primary target, any remaining unspent weapons in the queue are actively reassigned to the secondary target with the next highest Utility Score, eliminating wasted firepower.

## 5. Faction Biases & Overrides

The scenario engine injects faction-specific heuristics to alter the behavior profiles of different adversaries.

- **Sathar Aggression Modifier:** Ships assigned to the Sathar faction receive a flat modifier to all of their Attack Utility ($U_a$) calculations. This directly skews their decision-making loop, compelling Sathar ships to aggressively close the distance, maintain relentless offensive pressure, and ignore mathematically optimal defensive retreats—even when their ship is structurally compromised.
- **Defensive Screening:** If a Seeker missile is detected locked onto high-value ships, Escort class vessels will forcibly elevate their `Utility_Screen` score, abandoning offensive plans to intercept the incoming ordnance.

## 6. Defensive Ordnance Interception (ICMs)

During the combat resolution phase, the AI must decide how to allocate its limited stock of Interceptor Counter Missiles (ICMs) to defend itself and adjacent allies from incoming ballistic ordnance. The AI evaluates incoming attacks using an **Interception Efficiency Matrix** that balances the projectile's damage profile against the hit-chance deduction provided by an ICM.

The AI prioritizes incoming ordnance as follows:

1. **Torpedoes**: (Avg Damage: 22, ICM Reduction: -10% per point). The highest priority. Torpedoes deal devastating damage and are highly susceptible to point defense. The AI will aggressively dump ICMs to neutralize torpedo spreads.
2. **Spatial Mines**: (Avg Damage: 21.5, ICM Reduction: -8% per point). Extreme burst damage with strong point-defense vulnerability. If an AI formation triggers a minefield, escorts will prioritize mitigating the shrapnel over all standard rocket fire.
3. **Assault Rockets**: (Avg Damage: 15, ICM Reduction: -5% per point). Moderate threat. The AI allocates ICMs against Assault Rockets only if the target is structurally compromised or if no heavier ordnance is inbound.
4. **Rocket Batteries**: (Avg Damage: 11, ICM Reduction: -3% per point). Lowest priority. Because of the poor reduction-per-ICM ratio, the AI generally absorbs Rocket Battery fire with its hull, reserving ICMs unless it has a massive surplus or the target ship is critically damaged.

**Allocation Logic:**
- **Threat Sorting:** Incoming attacks within the hex are sorted descending by their damage-to-reduction efficiency.
- **Threshold Targeting:** The AI calculates the number of ICMs required to drop a high-threat attack below a "safe" hit chance threshold (e.g., < 15%) and allocates them sequentially until the ship/hex's ICM pool is depleted.
