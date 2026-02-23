class_name ScenarioManager

const SCENARIOS = {
	"surprise_attack": {
		"name": "Surprise Attack!",
		"description": "Attackers ambush Station Alpha. Defiant must escape.",
	"sides": {
			0: {"name": "Sathar", "color": Color.RED, "role": "Attacker"},
			1: {"name": "UPF", "color": Color.GREEN, "role": "Defender"}
		},
		"ships": [], # Template, filled by generator
		"special_rules": [
			{
				"type": "docked_turn_counter",
				"target_name": "Defiant",
				"counter_property": "evacuation_turns",
				"log_template": "Defiant Evacuation Progress: Turn %d"
			},
			{
				"type": "linked_state_debuff",
				"target_name": "Station Alpha",
				"trigger_name": "Defiant",
				"trigger_condition": "undocked", # When Defiant is NOT docked
				"condition_property": "evacuation_turns",
				"condition_min_value": 3,
				"debuffs": ["no_fire", "no_ms"]
			}
		]
	},
	"the_last_stand": {
		"name": "The Last Stand",
		"description": "A massive Sathar fleet assaults Fortress K'zdit. UPF must hold the line.",
		"sides": {
			0: {"name": "UPF", "color": Color.GREEN, "role": "Defender"},
			1: {"name": "Sathar", "color": Color.RED, "role": "Attacker"}
		},
		"ships": [
			# Ships are generated procedurally in generate_scenario()
		],
		"special_rules": [],
		"planets": [Vector3i(0, 0, 0)]
	},
	"simple_test": {
		"name": "Simple Test",
		"description": "A simple test scenario to test the game engine.",
		"sides": {
			0: {"name": "UPF", "color": Color.GREEN, "role": "Defender"},
			1: {"name": "Sathar", "color": Color.RED, "role": "Attacker"}
		},
		"ships": [],
		"special_rules": []
	},
	"repair_test": {
		"name": "Repair Test",
		"description": "A scenario specifically for testing the Repair Phase UI. Ships start damaged.",
		"sides": {
			0: {"name": "UPF", "color": Color.GREEN, "role": "Defender"},
			1: {"name": "Sathar", "color": Color.RED, "role": "Attacker"}
		},
		"ships": [],
		"special_rules": [
			{
				"type": "start_phase_override",
				"phase": 3 # Phase.REPAIR
			}
		]
	},
	"test_gravity": {
		"name": "Test Gravity",
		"description": "A scenario for testing Gravity Wells. Ships start near a planet.",
		"sides": {
			0: {"name": "UPF", "color": Color.GREEN, " role": "Defender"},
			1: {"name": "Sathar", "color": Color.RED, "role": "Attacker"}
		},
		"ships": [],
		"special_rules": [],
		"planets": [Vector3i(0, 0, 0)]
	},
	"test_docking": {
		"name": "Test Docking",
		"description": "Verify docking, docked movement, and re-arming mechanics.",
		"sides": {
			0: {"name": "UPF", "color": Color.GREEN, "role": "Defender"},
			1: {"name": "Sathar", "color": Color.RED, "role": "Attacker"}
		},
		"ships": [],
		"special_rules": []
	}
}

static func get_scenario(key: String) -> Dictionary:
	return SCENARIOS.get(key, {})

static func generate_scenario(key: String, rng_seed: int) -> Dictionary:
	var base_scen = get_scenario(key)
	if base_scen.is_empty(): return {}
	
	# Clone to avoid modifying const
	var scen = base_scen.duplicate(true)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var ships = []
	
	if key == "surprise_attack":
		# Station Setup
		# Random neighbor of (0,0,0)
		var center_neighbors = [
			Vector3i(1, 0, -1), Vector3i(1, -1, 0), Vector3i(0, -1, 1),
			Vector3i(-1, 0, 1), Vector3i(-1, 1, 0), Vector3i(0, 1, -1)
		]
		var station_pos = center_neighbors[rng.randi() % center_neighbors.size()]
		var station_orbit_dir = 1 if rng.randf() > 0.5 else -1
		print("[SCENARIO] Station Alpha Pos: %s, Orbit: %d" % [station_pos, station_orbit_dir])
		
		# Station Ship Def
		var station = {
			"name": "Station Alpha",
			"class": "Station",
			"faction": "UPF",
			"side_index": 1, # Defender
			"position": station_pos,
			"orbit_direction": station_orbit_dir,
			"overrides": {
				"max_hull": 25,
				"hull": 25,
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
			"side_index": 1, # Defender
			"position": station_pos,
			"docked_at": "Station Alpha",
			"color": Color.CYAN
		})
		
		ships.append({
			"name": "Stiletto",
			"class": "Assault Scout",
			"faction": "UPF",
			"side_index": 1, # Defender
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
			Vector3i(1, 0, -1), Vector3i(0, 1, -1), Vector3i(-1, 1, 0),
			Vector3i(-1, 0, 1), Vector3i(0, -1, 1), Vector3i(1, -1, 0)
		]
		
		var edge_dir_idx = rng.randi() % 6
		var edge_vec = directions[edge_dir_idx]
		var start_dist = 24 # Moved to edge (Map Radius 25)
		
		var venemous_pos = edge_vec * start_dist
		# Facing towards center (Opposite)
		var attack_facing = (edge_dir_idx + 3) % 6
		print("[SCENARIO] Sathar Entry Edge: %d (Vec: %s), Facing: %d" % [edge_dir_idx, edge_vec, attack_facing])
		
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
			"side_index": 0, # Attacker
			"position": venemous_pos,
			"facing": attack_facing,
			"start_speed": 8
		})
		
		ships.append({
			"name": "Perdition",
			"class": "Heavy Cruiser",
			"faction": "Sathar",
			"side_index": 0, # Attacker
			"position": perdition_pos,
			"facing": attack_facing,
			"start_speed": 8
		})
		
		scen["ships"] = ships
		
	elif key == "the_last_stand":
		# UPF SETUP
		# 1. Fortress K'zdit - Random Orbit
		var center_neighbors = [
			Vector3i(1, 0, -1), Vector3i(1, -1, 0), Vector3i(0, -1, 1),
			Vector3i(-1, 0, 1), Vector3i(-1, 1, 0), Vector3i(0, 1, -1)
		]
		var station_pos = center_neighbors[rng.randi() % center_neighbors.size()]
		var station_orbit_dir = 1 if rng.randf() > 0.5 else -1
		
		ships.append({
			"name": "Fortress K'zdit", "class": "Space Station", "side": 0,
			"position": station_pos, "facing": 0,
			"orbit_direction": station_orbit_dir,
			"overrides": {
				"hull": 100, "max_hull": 100, "icm_max": 8, "icm_current": 8, "ms_max": 2, "ms_current": 2,
				"weapons": [
					{"name": "Laser Battery 1", "type": "Laser", "range": 9, "arc": "360", "ammo": 999, "max_ammo": 999, "damage_dice": "1d10", "damage_bonus": 0, "fired": false},
					{"name": "Laser Battery 2", "type": "Laser", "range": 9, "arc": "360", "ammo": 999, "max_ammo": 999, "damage_dice": "1d10", "damage_bonus": 0, "fired": false},
					{"name": "Laser Battery ", "type": "Laser", "range": 9, "arc": "360", "ammo": 999, "max_ammo": 999, "damage_dice": "1d10", "damage_bonus": 0, "fired": false},
					{"name": "Rocket Battery Swarm", "type": "Rocket Battery", "range": 3, "arc": "360", "ammo": 12, "max_ammo": 12, "damage_dice": "2d10", "damage_bonus": 0, "fired": false}
				]
			}
		})
		
		# 2. UPF Fleet - Defensive Cluster near Center (avoiding Station)
		var upf_roster = [
			{"name": "Valiant", "class": "Battleship", "pos": Vector3i(1, 0, -1), "facing": 0}, # Shifted East off Planet
			{"name": "Allison May", "class": "Destroyer", "pos": Vector3i(0, -2, 2), "facing": 1},
			{"name": "Daridia", "class": "Frigate", "pos": Vector3i(-1, 1, 0), "facing": 5},
			{"name": "Dauntless", "class": "Assault Scout", "pos": Vector3i(1, 1, -2), "facing": 0},
			{"name": "Razor", "class": "Assault Scout", "pos": Vector3i(-1, -1, 2), "facing": 3},
			{"name": "Fighter a", "class": "Fighter", "pos": Vector3i(0, 2, -2), "facing": 0},
			{"name": "Fighter b", "class": "Fighter", "pos": Vector3i(0, 3, -3), "facing": 0}
		]
		
		for template in upf_roster:
			# Simple overlap check: If a ship spawns on the station, shift it slightly
			if template["pos"] == station_pos:
				template["pos"] = template["pos"] + Vector3i(1, 0, -1) # Shift East
			
			ships.append({
				"name": template["name"], "class": template["class"], "side": 0,
				"position": template["pos"], "facing": template["facing"]
			})
			
		# SATHAR SETUP
		# Random Edge Direction
		var directions = [
			Vector3i(1, 0, -1), Vector3i(0, 1, -1), Vector3i(-1, 1, 0),
			Vector3i(-1, 0, 1), Vector3i(0, -1, 1), Vector3i(1, -1, 0)
		]
		var edge_dir_idx = rng.randi() % 6
		var edge_vec = directions[edge_dir_idx]
		var center_dist = 22 # Slightly inside max radius
		
		# Anchor point for the fleet
		var anchor_pos = edge_vec * center_dist
		var attack_facing = (edge_dir_idx + 3) % 6 # Facing Center
		
		# Fleet Formation relative to Anchor
		# We define offsets in Hex coordinates relative to a "Forward" facing of 0 (East)
		# Then we rotate these offsets to match the actual attack_facing?
		# Or just use simple manual offsets and hope they don't look too weird when rotated.
		# Actually, simple static cluster around anchor is fine.
		
		var sathar_roster = [
			{"name": "Infamous", "class": "Assault Carrier", "offset": Vector3i(0, 0, 0)},
			{"name": "Star Scourge", "class": "Heavy Cruiser", "offset": Vector3i(1, -1, 0)},
			{"name": "Vicious", "class": "Destroyer", "offset": Vector3i(-1, 0, 1)},
			{"name": "Pestilence", "class": "Destroyer", "offset": Vector3i(0, 1, -1)},
			{"name": "Doomfist", "class": "Destroyer", "offset": Vector3i(0, -1, 1)},
			{"name": "Stinger", "class": "Frigate", "offset": Vector3i(2, -1, -1)},
			# Docked Fighters don't need position
		]
		
		for s_data in sathar_roster:
			ships.append({
				"name": s_data["name"], "class": s_data["class"], "side": 1, "faction": "Sathar",
				"position": anchor_pos + s_data["offset"], # Note: Simple offset, doesn't rotate with edge. Good enough.
				"facing": attack_facing,
				"start_speed": 6
			})
			
		# Docked Fighters for Infamous
		ships.append({
			"name": "Fighter A", "class": "Fighter", "side": 1, "faction": "Sathar",
			"position": anchor_pos, "docked_at": "Infamous"
		})
		ships.append({
			"name": "Fighter B", "class": "Fighter", "side": 1, "faction": "Sathar",
			"position": anchor_pos, "docked_at": "Infamous"
		})

		scen["ships"] = ships
		scen["planets"] = [Vector3i(0, 0, 0)]
		
	elif key == "simple_test":
		ships.append({
			"name": "Vigilant",
			"class": "Frigate",
			"faction": "UPF",
			"side_index": 0,
			"position": Vector3i(-3, 0, 3), # 3 hexes West
			"facing": 0, # East
			"start_speed": 3
		})
		ships.append({
			"name": "Defiant",
			"class": "Frigate",
			"faction": "UPF",
			"side_index": 0,
			"position": Vector3i(-3, 1, 2), # Adjacent to Vigilant
			"facing": 0, # East
			"start_speed": 3
		})
		ships.append({
			"name": "Savage",
			"class": "Frigate",
			"faction": "Sathar",
			"side_index": 1,
			"position": Vector3i(3, 0, -3), # 3 hexes East
			"facing": 3, # West
			"start_speed": 3
		})
		ships.append({
			"name": "Stinger",
			"class": "Frigate",
			"faction": "Sathar",
			"side_index": 1,
			"position": Vector3i(3, -1, -2), # Adjacent to Savage
			"facing": 3, # West
			"start_speed": 3
		})
		scen["ships"] = ships
		
	elif key == "repair_test":
		ships.append({
			"name": "Mended Heart",
			"class": "Heavy Cruiser",
			"faction": "UPF",
			"side_index": 0,
			"position": Vector3i(-2, 0, 2),
			"facing": 0,
			"start_speed": 0,
			"overrides": {
				"hull": 15, # Damaged hull
				"current_adf_modifier": 1 # Damaged ADF
			}
		})
		ships.append({
			"name": "Scraped Knee",
			"class": "Frigate",
			"faction": "UPF",
			"side_index": 0,
			"position": Vector3i(-2, 1, 1),
			"facing": 0,
			"start_speed": 0,
			"overrides": {
				"hull": 20, # Normal hull, but has a fire
				"has_electrical_fire": true,
				"current_adf_modifier": 3
			}
		})
		ships.append({
			"name": "Pristine",
			"class": "Scout",
			"faction": "UPF",
			"side_index": 0,
			"position": Vector3i(-1, 0, 1),
			"facing": 0,
			"start_speed": 0
		})
		ships.append({
			"name": "Shattered",
			"class": "Destroyer",
			"faction": "Sathar",
			"side_index": 1,
			"position": Vector3i(2, 0, -2),
			"facing": 3,
			"start_speed": 0,
			"overrides": {
				"hull": 5, # Very damaged
				"has_disastrous_fire": true
			}
		})
		ships.append({
			"name": "Broken Bone",
			"class": "Heavy Cruiser",
			"faction": "Sathar",
			"side_index": 1,
			"position": Vector3i(2, 1, -3),
			"facing": 3,
			"start_speed": 0,
			"overrides": {
				"hull": 20,
				"icm_max": 0,
				"icm_current": 0,
				"ccs_damaged": true
			}
		})
		scen["ships"] = ships
		
	elif key == "test_gravity":
		# Ship 1: UPF Assault Scout at (2,-1,-1) [distance 2], facing 3 (West) towards planet (0,0,0)
		ships.append({
			"name": "Test UPF",
			"class": "Assault Scout",
			"faction": "UPF",
			"side_index": 0,
			"position": Vector3i(2, -1, -1),
			"facing": 3,
			"start_speed": 4
		})
		# Ship 2: Sathar Destroyer at (-2,1,1) [distance 2], facing 0 (East) towards planet (0,0,0)
		ships.append({
			"name": "Test Sathar",
			"class": "Destroyer",
			"faction": "Sathar",
			"side_index": 1,
			"position": Vector3i(-2, 1, 1),
			"facing": 0,
			"start_speed": 4
		})
		scen["ships"] = ships

	elif key == "test_docking":
		# UPF (Defender, Side 0)
		# Carrier at (-5, 5, 0), moving SE (facing 1), speed 2
		var upf_carrier_pos = Vector3i(-5, 5, 0)
		ships.append({
			"name": "UPF Carrier", "class": "Assault Carrier", "faction": "UPF", "side_index": 0,
			"position": upf_carrier_pos, "facing": 1, "start_speed": 2
		})
		
		# Fighters around UPF Carrier (Dist 3)
		ships.append({
			"name": "UPF Fighter Full", "class": "Fighter", "faction": "UPF", "side_index": 0,
			"position": upf_carrier_pos + Vector3i(0, -3, 3), "facing": 1, "start_speed": 2
		})
		ships.append({
			"name": "UPF Fighter Used", "class": "Fighter", "faction": "UPF", "side_index": 0,
			"position": upf_carrier_pos + Vector3i(3, 0, -3), "facing": 1, "start_speed": 2,
			"overrides": {
				"weapons": [ { "name": "Assault Rockets", "type": "Rocket", "range": 4, "arc": "FF", "ammo": 2, "max_ammo": 3, "damage_dice": "2d10", "damage_bonus": 4, "dtm": -10, "fired": false } ]
			}
		})
		ships.append({
			"name": "UPF Fighter Empty", "class": "Fighter", "faction": "UPF", "side_index": 0,
			"position": upf_carrier_pos + Vector3i(-3, 0, 3), "facing": 1, "start_speed": 2,
			"overrides": {
				"weapons": [ { "name": "Assault Rockets", "type": "Rocket", "range": 4, "arc": "FF", "ammo": 0, "max_ammo": 3, "damage_dice": "2d10", "damage_bonus": 4, "dtm": -10, "fired": false } ]
			}
		})
		
		# Sathar (Attacker, Side 1)
		# Carrier at (5, -5, 0) which is 10 hexes away from (-5, 5, 0).
		# Facing NW (facing 4), speed 2
		var sat_carrier_pos = Vector3i(5, -5, 0)
		ships.append({
			"name": "Sathar Carrier", "class": "Assault Carrier", "faction": "Sathar", "side_index": 1,
			"position": sat_carrier_pos, "facing": 4, "start_speed": 2
		})
		
		# Fighters around Sathar Carrier (Dist 3)
		ships.append({
			"name": "Sathar Fighter Full", "class": "Fighter", "faction": "Sathar", "side_index": 1,
			"position": sat_carrier_pos + Vector3i(0, 3, -3), "facing": 4, "start_speed": 2
		})
		ships.append({
			"name": "Sathar Fighter Used", "class": "Fighter", "faction": "Sathar", "side_index": 1,
			"position": sat_carrier_pos + Vector3i(-3, 0, 3), "facing": 4, "start_speed": 2,
			"overrides": {
				"weapons": [ { "name": "Assault Rockets", "type": "Rocket", "range": 4, "arc": "FF", "ammo": 1, "max_ammo": 3, "damage_dice": "2d10", "damage_bonus": 4, "dtm": -10, "fired": false } ]
			}
		})
		ships.append({
			"name": "Sathar Fighter Empty", "class": "Fighter", "faction": "Sathar", "side_index": 1,
			"position": sat_carrier_pos + Vector3i(3, 0, -3), "facing": 4, "start_speed": 2,
			"overrides": {
				"weapons": [ { "name": "Assault Rockets", "type": "Rocket", "range": 4, "arc": "FF", "ammo": 0, "max_ammo": 3, "damage_dice": "2d10", "damage_bonus": 4, "dtm": -10, "fired": false } ]
			}
		})
		scen["ships"] = ships

	return scen
