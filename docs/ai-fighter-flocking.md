# AI Fighter Flocking Strategy

## 1. Concept Overview
The goal of the Flocking Strategy is to coordinate the actions of AI-controlled Fighters, allowing them to act as a cohesive "swarm" rather than independent, isolated units. This strategy ensures fighters concentrate their firepower on high-value targets while utilizing semi-randomized movement paths to avoid predictable stacking and simulate organic swarm behavior.

## 2. Target Cohesion (The Swarm Mind)
Fighters are fragile and their individual weapons deal minimal damage to capital ships. To be effective, they must focus fire.
- **Squadron Target Lock:** During the AI target evaluation phase, fighters will identify the highest-priority target globally selected by the AI faction.
- **Swarm Bonus:** Fighters receive a massive multiplier to their `Attack_Utility` against targets that are already being targeted by other friendly fighters, ensuring the entire swarm converges on the same victim.

## 3. Movement Flocking (The Heatmap Layer)
To prevent the swarm from traveling in a single, easily predictable conga line, a new layer is added to the AI's Heatmap evaluation specifically for ships of class `Fighter`.

| **Layer** | **Logic** |
| :--- | :--- |
| **Flock Cohesion (+)** | Positive score modifier for candidate hexes that are adjacent to or within 2 hexes of another friendly fighter. This keeps the swarm together as a distinct unit on the battlefield. |
| **Path Separation (-)** | Negative score modifier for candidate hexes that already contain another friendly fighter. This gently pushes fighters to take parallel or flanking routes rather than stacking in the exact same hex, creating a spread-out "cloud" of fighters. |

## 4. Erratic Pathing (Randomness Factor)
The existing AI decision loop (defined in `computer_opponent.md`) includes a `Gaussian Noise` factor.
- **Fighter Evasion Fuzziness:** For fighters specifically, the strength of this Gaussian Noise modifier is increased when evaluating movement hexes. 
- While the Cohesion layer pulls them toward their target, this heightened randomness guarantees their individual paths are erratic, simulating evasive dogfighting maneuvers and making them visually behave like a chaotic swarm.
