extends GutTest

var game_manager_scene = preload("res://Scenes/Main.tscn")
var game_manager
var ship_script = preload("res://Scripts/Ship.gd")

func before_each():
	game_manager = game_manager_scene.instantiate()
	# Bypass network and scenario waits
	add_child_autofree(game_manager)
	
	# Stub out wait methods so tests run instantly
	game_manager.time_between_phases = 0.0

func test_seeker_deployment_and_activation():
	# 1. Setup Minelayer
	var ship1 = ship_script.new()
	game_manager.add_child(ship1)
	ship1.name = "TestMinelayer"
	ship1.ship_class = "Minelayer"
	ship1.side_id = 1
	ship1.grid_position = Vector3i(0, 0, 0)
	ship1.facing = 0
	ship1.configure_minelayer()
	game_manager.ships.append(ship1)
	
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	game_manager.current_side_id = 1
	game_manager.my_side_id = 1 # We are side 1
	
	# Assert Seeker loadout
	var seeker_weapon = null
	for w in ship1.weapons:
		if w["type"] == "Seeker":
			seeker_weapon = w
			break
	assert_not_null(seeker_weapon, "Minelayer should have Seeker weapon")
	assert_eq(seeker_weapon["ammo"], 4, "Minelayer starts with 4 Seekers")
	
	# 2. Deploy Seeker during movement plan
	ship1.planned_seekers_to_drop.append(Vector3i(0, 0, 0))
	
	# Execute movement manually
	game_manager.execute_all_movement()
	
	# Assert seeker dropped
	assert_eq(seeker_weapon["ammo"], 3, "Seeker ammo should decrement")
	assert_eq(game_manager.active_seekers.size(), 1, "Seeker should be in active list")
	var seeker = game_manager.active_seekers[0]
	assert_eq(seeker["speed"], 0, "Seeker starts inactive (0 speed)")
	assert_eq(seeker["side_id"], 1, "Seeker belongs to side 1")
	
	# 3. Activate Seeker
	game_manager.rpc_activate_seeker(Vector3i(0, 0, 0))
	assert_eq(game_manager.active_seekers[0]["speed"], 2, "Seeker is activated with speed 2")

func test_seeker_autonomous_pursuit_and_detonation():
	# Setup test variables
	var seeker = {
		"pos": Vector3i(0, 0, 0),
		"side_id": 1,
		"owner_name": "TestMinelayer",
		"speed": 2,
		"tracking_pos": Vector3i(4, -4, 0) # Needs an initial tracking target
	}
	game_manager.active_seekers.append(seeker)
	
	# Setup Target
	var target = ship_script.new()
	game_manager.add_child(target)
	target.name = "EnemyCruiser"
	target.ship_class = "Cruiser"
	target.side_id = 2
	target.grid_position = Vector3i(4, -4, 0) # Distance 4
	target.facing = 3
	target.max_hull = 100
	target.hull = 100
	game_manager.ships.append(target)
	
	# Turn 1 and beyond (while loop to mitigate 75% hit chance RNG flakiness)
	var max_attempts = 10
	var attempts = 0
	
	# Force consistent RNG seed for deterministic hit (75% base chance)
	Combat.combat_rng.seed = 12345
	
	while target.hull == target.max_hull and attempts < max_attempts:
		# Reload Seeker if it missed and detonated
		if game_manager.active_seekers.size() == 0:
			var new_seeker = {
				"pos": Vector3i(0, 0, 0),
				"side_id": 1,
				"owner_name": "TestMinelayer",
				"speed": 2,
				"tracking_pos": target.grid_position
			}
			game_manager.active_seekers.append(new_seeker)
			
		await game_manager._resolve_seeker_movement_and_detonations()
		attempts += 1
	
	var dist = HexGrid.hex_distance(Vector3i(0, 0, 0), target.grid_position)
	assert_eq(game_manager.active_seekers.size(), 0, "Seeker should detonate and be removed")
	assert_lt(target.hull, target.max_hull, "Target should have taken damage from detonation")
