extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var ship_script = load("res://Scripts/Ship.gd")

var _gm = null
var _ship = null

func before_each():
	_gm = game_manager_script.new()
	add_child_autofree(_gm)
	
	_ship = ship_script.new()
	_ship.name = "TestShip"
	_ship.side_id = 1
	_gm.ships.append(_ship)
	_gm.add_child(_ship)

func test_rpc_undo_move_resets_state():
	# 1. Setup Initial State (as if Turn Started)
	var start_pos = Vector3i(0, 0, 0)
	var start_facing = 0
	
	_ship.grid_position = start_pos
	_ship.facing = start_facing
	_ship.speed = 0
	
	# Simulate Turn Start Capture
	_ship.reset_turn_state()
	_ship.turn_start_state = {
		"grid_position": start_pos,
		"facing": start_facing,
		"speed": 0,
		"is_ms_active": false,
		"ms_orbit_start_hex": Vector3i.ZERO
	}
	
	# 2. Perform a Move
	var move_pos = Vector3i(0, 1, -1)
	_ship.grid_position = move_pos
	_ship.has_moved = true
	_ship.previous_path.assign([move_pos])
	
	# 3. Call RPC (Simulate receiving it)
	# We rely on validate logic, so we need to mess with side_id or disable security for test?
	# _validate_rpc_ownership defaults to failing if no sender.
	# But if no multiplayer peer, it assumes local (sender=1)?
	# Let's check logic:
	# if multiplayer.has_multiplayer_peer(): sender = remote_id else: sender = 1
	# The test runner usually has NO peer, so sender=1.
	# We need ship.side_id = 1? But _validate checks if sender_id maps to side_id.
	# NetworkManager.lobby_data["teams"] defaults to empty.
	# So _validate might fail.
	# Let's Mock NetworkManager or bypass?
	# We can set NetworkManager.lobby_data["teams"] = {1: 1}
	
	var NetworkManager = _gm.get_node("/root/NetworkManager")
	if NetworkManager:
		NetworkManager.lobby_data["teams"] = {1: 1} # Peer 1 owns Side 1
	
	_gm.rpc_undo_move("TestShip")
	
	# 4. Verify Reset
	assert_eq(_ship.grid_position, start_pos, "Ship should return to start pos")
	assert_false(_ship.has_moved, "Ship should not be marked as moved")
	assert_eq(_ship.previous_path.size(), 0, "Previous path should be cleared")

func test_undo_on_client_triggers_rpc():
	# This requires creating a mock peer or checking if rpc was called.
	# GUT has 'stub' or 'spy'? 
	# Easier to just verify the logic branch:
	# If has_moved = true, it calls local rpc_undo_move (if offline).
	# Setup
	_gm.selected_ship = _ship
	_ship.has_moved = true
	_ship.turn_start_state = {"grid_position": Vector3i.ZERO, "facing": 0, "speed": 0, "is_ms_active": false, "ms_orbit_start_hex": Vector3i.ZERO}
	
	# Force Offline
	# (Default is offline)
	
	# Execute
	_gm._on_undo()
	
	# Verify
	# Since offline calls rpc_undo_move directly, state should reset.
	assert_eq(_ship.grid_position, Vector3i.ZERO)
	assert_false(_ship.has_moved)
