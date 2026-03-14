# Campaign Computer Opponent

This document details the behavior, architecture, and constraints of the `CampaignComputerOpponent`, the artificial intelligence responsible for making strategic decisions on the Campaign Map.

## 1. Instantiation & Activation
The campaign AI is triggered when a new campaign or loaded save begins without a human player assigned to one of the playable factions (UPF or Sathar). 
When this condition is met, the `CampaignManager` will instantiate a `CampaignComputerOpponent` node and set its target `faction`. 

Like the tactical `ComputerOpponent`, the campaign AI relies on a polling mechanism tied to the `CampaignManager` state, using short simulated delay timers to allow the UI to update visually and to prevent rapid-fire network desynchs.

## 2. Core Operational Loop
Upon the start of a new campaign day (or upon taking control), the AI executes a standard decision loop:

1. **Auto-Repair Phase:** Evaluates damaged ships currently residing in friendly Starship Construction Centers (SCCs).
2. **Strategy & Targeting Phase:** Determines the highest-value strategic goals (e.g., nearest enemy SCC, nearest enemy fleet).
3. **Movement Phase:** Iterates through all idle fleets and plots AStar pathing to their designated targets.
4. **Combat Resolution Phase:** Scans `active_encounters`. If the AI is the attacking faction, it evaluates the battle odds and either initiates the engagement or attempts a strategic retreat.
5. **End Turn Phase:** Submits its "Ready" status to the `CampaignManager` to advance the day.

## 3. Faction-Specific Behaviors

### UPF (United Planetary Federation)
The UPF AI plays a defensive and intercept-oriented strategy.
- **Repairs:** Granular. The AI will prioritize fixing critically crippled systems (engines, defenses, destroyed weapons) up to the daily capacity limit of the local SCC before spending remaining capacity on raw hull points.
- **Movement:** Defensive. UPF fleets will prioritize intercepting incoming Sathar fleets. Idle fleets without an immediate interception target will fall back to orbit SCC systems or fortresses to act as defensive garrisons.
- **Combat:** Calculating. The UPF will retreat from battles where they are severely outmatched, preferring to preserve ships and consolidate forces.

### Sathar
The Sathar AI plays an aggressive, swarm-oriented strategy aimed at destroying UPF infrastructure.
- **Repairs:** Binary. The Sathar AI evaluates critically damaged ships (e.g., <50% hull or crippled ADF/MR). It will strip these ships from active fleets and place them immediately into the 6-Day SCC repair queue, returning them to combat later as a fresh reinforcement wave.
- **Movement:** Aggressive. Sathar fleets prioritize pathing directly toward the nearest known UPF SCC or Armed Station. They prioritize destroying infrastructure over hunting down dispersed UPF task forces.
- **Combat:** Relentless. The Sathar AI will rarely retreat, fighting to the bitter end unless the combat power gap is catastrophic.

## 4. Pathfinding and Navigational Logic

The AI uses an A* (A-Star) search algorithm overlaid on the `campaign.systems` network. 
- **Routes:** Pathing is restricted to valid established routes between systems.
- **Travel Time:** The AI correctly accounts for route lengths (e.g., 2 days vs. 5 days transit times).
- **Consolidation:** The AI attempts to merge fleets moving to the same destination to maximize combat density upon arrival, preventing isolated ships from being picked off.

## 5. Technical Hooks (CampaignManager)
The `CampaignComputerOpponent` interfaces with the following `CampaignManager` functions to emulate human input:
- `order_fleet_move(fleet, destination)`
- `cancel_fleet_move(fleet)`
- `rpc_open_encounter_dialog(system_id)`
- `submit_turn_ready(faction)`
- `sathar_repair_queue.append(...)` and `upf_scc_capacity_used` manipulation.
