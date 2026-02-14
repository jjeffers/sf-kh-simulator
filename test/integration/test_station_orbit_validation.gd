extends GutTest

var game_manager
var station

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)

func test_station_orbit_validation():
	# 1. Setup Station
	station = load("res://Scripts/Ship.gd").new()
	station.name = "Station Alpha"
	station.configure_space_station() # ADF 0, MR 0
	station.side_id = 1
	station.orbit_direction = 1
	station.grid_position = Vector3i(1, -1, 0)
	station.speed = 0
	
	game_manager.ships.append(station)
	game_manager.add_child(station)
	
	# 2. Simulate Execute Commit Move
	# RPC signature: execute_commit_move(ship_name, path, final_facing, orbit_dir, is_orbiting)
	
	# Path for 1 step orbit
	var path: Array[Vector3i] = [Vector3i(1, 0, -1)] # Adjacent hex
	var facing = 0
	var orbit_dir = 1
	var is_orbiting = true
	
	# Mock ownership validation or just enable host mode
	game_manager.multiplayer.set_multiplayer_peer(null) # Offline mode, strict checks might be bypassed?
	# Actually _validate_rpc_ownership uses lobby_data.
	# We can just mock the validation function or ensure lobby data aligns.
	# But _validate_move_path is called AFTER ownership check.
	# Let's call _validate_move_path directly to verify the LOGIC first.
	
	var valid = game_manager._validate_move_path(station, path, facing, is_orbiting)
	assert_true(valid, "Orbit move should be valid despite ADF 0")
	
	# Test invalid non-orbit move
	var invalid_path: Array[Vector3i] = [Vector3i(5, 5, -10)] # Teleport (Non-adjacent)
	var invalid = game_manager._validate_move_path(station, invalid_path, facing, is_orbiting)
	assert_false(invalid, "Teleport should be invalid")
	
	# Test invalid speed without orbit flag
	var normal_move_path: Array[Vector3i] = [Vector3i(1, 0, -1)]
	var valid_normal = game_manager._validate_move_path(station, normal_move_path, facing, false)
	assert_false(valid_normal, "Normal move of speed 1 should be invalid for ADF 0 station")
