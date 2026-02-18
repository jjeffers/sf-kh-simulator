extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var ship_script = load("res://Scripts/Ship.gd")

var _gm = null
var _carrier = null
var _fighter = null

func before_each():
	_gm = game_manager_script.new()
	add_child_autofree(_gm)
	
	# Mock Network Data for RPC Validation
	# Default sender_id is 1. Carrier is Side 1.
	NetworkManager.lobby_data = {"teams": {1: 1}}
	
	# Setup Carrier
	_carrier = ship_script.new()
	_carrier.name = "Carrier"
	_carrier.ship_class = "Assault Carrier"
	_carrier.side_id = 1
	_carrier.grid_position = Vector3i(0, 0, 0)
	_carrier.speed = 0
	_carrier.facing = 0
	_gm.ships.append(_carrier)
	_gm.add_child(_carrier)
	
	# Setup Fighter (Docked)
	_fighter = ship_script.new()
	_fighter.name = "Fighter"
	_fighter.ship_class = "Fighter"
	_fighter.side_id = 1
	_fighter.grid_position = Vector3i(0, 0, 0)
	_fighter.speed = 0
	_fighter.facing = 0
	_fighter.dock_at(_carrier)
	_gm.ships.append(_fighter)
	_gm.add_child(_fighter)

func test_undo_carrier_move_resets_fighter():
	# 1. Capture Start State (Simulate Turn Start)
	_gm.start_movement_phase()
	# Verify Fighter is docked and at 0,0,0
	assert_true(_fighter.is_docked, "Fighter should be docked")
	assert_eq(_fighter.grid_position, Vector3i(0, 0, 0), "Fighter at start")
	
	# Manually populate turn_start_state since we skipped _start_turn_for_side
	_carrier.turn_start_state = {
		"grid_position": Vector3i(0, 0, 0),
		"facing": 0,
		"speed": 0,
		"is_ms_active": false,
		"ms_orbit_start_hex": Vector3i(0, 0, 0)
	}
	
	# 2. Move Carrier
	_gm.selected_ship = _carrier
	var move_pos = Vector3i(1, 0, -1)
	_carrier.grid_position = move_pos
	_carrier.has_moved = true
	_carrier.previous_path.assign([move_pos])
	
	# Verify Fighter Updates (Carrier moves, fighter should follow logic handled by `execute_commit_move` usually)
	# But `has_moved` implies end of turn. The syncing of guests happens in `execute_commit_move`.
	# Let's manually simulate the guest sync that happens after a move
	for g in _carrier.docked_guests:
		g.grid_position = _carrier.grid_position
	
	assert_eq(_fighter.grid_position, move_pos, "Fighter should move with Carrier")
	
	# 3. Undo Carrier Move through RPC (or local simulation if offline)
	# We force the local execution of the RPC function to verify logic
	_gm.rpc_undo_move(_carrier.name)
	
	# 4. Verify Carrier Reset
	assert_eq(_carrier.grid_position, Vector3i(0, 0, 0), "Carrier should reset")
	assert_false(_carrier.has_moved, "Carrier has_moved false")
	
	# 5. Verify Fighter Reset (THE BUG)
	# Fighter should also be back at 0,0,0
	assert_eq(_fighter.grid_position, Vector3i(0, 0, 0), "Fighter should reset position")
