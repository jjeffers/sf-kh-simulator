class_name ScenarioManager

const SCENARIOS = {
	"surprise_attack": {
		"name": "Surprise Attack!",
		"description": "Attackers ambush Station Alpha. Defiant must escape.",
		"sides": {
			0: {"name": "Defenders (Side A)", "color": Color.GREEN},
			1: {"name": "Attackers (Side B)", "color": Color.RED}
		},
		"ships": [] # Template, filled by generator
	}
}

static func get_scenario(key: String) -> Dictionary:
	return SCENARIOS.get(key, {})

static func generate_scenario(key: String, rng_seed: int) -> Dictionary:
	var base_scen = get_scenario(key)
	if base_scen.is_empty(): return {}
	
	# Clone to avoid modifying const
	var scen = base_scen.duplicate(true)
	
	seed(rng_seed)
	var ships = []
	
	if key == "surprise_attack":
		# Station Setup
		# Random neighbor of (0,0,0)
		var center_neighbors = [
			Vector3i(1, 0, -1), Vector3i(1, -1, 0), Vector3i(0, -1, 1),
			Vector3i(-1, 0, 1), Vector3i(-1, 1, 0), Vector3i(0, 1, -1)
		]
		var station_pos = center_neighbors[randi() % center_neighbors.size()]
		var station_orbit_dir = 1 if randf() > 0.5 else -1
		
		# Station Ship Def
		var station = {
			"name": "Station Alpha",
			"class": "Station",
			"faction": "UPF",
			"side_index": 0,
			"position": station_pos,
			"orbit_direction": station_orbit_dir,
			"stats": {
				"max_hull": 25,
				"icm_max": 6,
				"icm_current": 6,
				"weapons": [ {
					"name": "Laser Battery",
					"type": "Laser",
					"range": 9,
					"arc": "360",
					"ammo": 999,
					"max_ammo": 999,
					"damage_dice": "1d10",
					"damage_bonus": 0,
					"fired": false
				}]
			}
		}
		ships.append(station)
		
		# Defender Ships (Start Docked)
		ships.append({
			"name": "Defiant",
			"class": "Frigate",
			"faction": "UPF",
			"side_index": 0,
			"position": station_pos,
			"docked_at": "Station Alpha",
			"color": Color.CYAN
		})
		
		ships.append({
			"name": "Stiletto",
			"class": "Assault Scout",
			"faction": "UPF",
			"side_index": 0,
			"position": station_pos,
			"docked_at": "Station Alpha",
			"color": Color.CYAN
		})
		
		# Attacker Setup
		# Random Edge Direction (0-5)
		# Directions:
		# 0: (1, 0, -1) E
		# 1: (1, -1, 0) SE
		# 2: (0, -1, 1) SW
		# 3: (-1, 0, 1) W
		# 4: (-1, 1, 0) NW
		# 5: (0, 1, -1) NE
		
		var directions = [
			Vector3i(1, 0, -1), Vector3i(1, -1, 0), Vector3i(0, -1, 1),
			Vector3i(-1, 0, 1), Vector3i(-1, 1, 0), Vector3i(0, 1, -1)
		]
		
		var edge_dir_idx = randi() % 6
		var edge_vec = directions[edge_dir_idx]
		var start_dist = 20
		
		var venemous_pos = edge_vec * start_dist
		# Facing towards center? Center is 0,0,0.
		# Opposite of edge_dir_idx basically.
		# HexGrid facings: 0=E, 1=SE, 2=SW, 3=W, 4=NW, 5=NE
		# If edge is E (0), facing should be W (3).
		# (idx + 3) % 6
		var attack_facing = (edge_dir_idx + 3) % 6
		
		# Perdition adjacent
		# Determine 'right' or 'left' neighbor for formation
		# Let's just pick a neighbor perpendicular-ish to facing?
		# Or just any neighbor.
		# Neighbor 0 relative to facing?
		# Let's say Perdition is at venemous_pos + some_offset
		# Offset = direction (attack_facing + 1) % 6 (The "Forward-Right" of the approach?)
		# No, if facing Center, we want them side-by-side.
		# Side-by-side relative to facing 3 (W) would be N or S directions.
		# Let's just pick (edge_dir_idx + 2) % 6 (a diagonal neighbor)
		var offset_dir = directions[(edge_dir_idx + 2) % 6]
		var perdition_pos = venemous_pos + offset_dir
		
		ships.append({
			"name": "Venemous",
			"class": "Destroyer",
			"faction": "Sathar",
			"side_index": 1,
			"position": venemous_pos,
			"facing": attack_facing,
			"start_speed": 8
		})
		
		ships.append({
			"name": "Perdition",
			"class": "Heavy Cruiser",
			"faction": "Sathar",
			"side_index": 1,
			"position": perdition_pos,
			"facing": attack_facing,
			"start_speed": 8
		})
		
		scen["ships"] = ships
		
	return scen
