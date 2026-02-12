extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var HexGridScript = preload("res://Scripts/HexGrid.gd")

var _gm = null
var _ship = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm._ready()

	# Clear any auto-loaded ships from _ready/RPC
	_gm.ships.clear()

	_ship = ShipScript.new()
	_ship.name = "TestShip"
	_ship.grid_position = Vector3i(0, 0, 0)
	_ship.player_id = 1
	_ship.adf = 2
	_ship.speed = 0 # Start stationary to avoid auto-orbit
	_ship.facing = 0 # East
	_gm.ships.append(_ship)
	_gm.add_child(_ship)
	
	_gm.current_player_id = 1
	_gm.my_side_id = 1 # Authoritative
	_gm.current_phase = _gm.Phase.MOVEMENT
	_gm.selected_ship = _ship
	_gm.start_movement_phase()
	
func after_each():
	_gm.free()

func test_movement_click_handles_ghost_input():
	# Initial State
	assert_eq(_gm.current_path.size(), 0, "Path should start empty")
	
	# Simulate Click on adjacent hex (EAST)
	# Facing 0 is East (1, 0, -1)
	var target_hex = Vector3i(1, 0, -1)
	var pixel_pos = HexGridScript.hex_to_pixel(target_hex)
	
	_gm._handle_movement_click(target_hex)
	
	# Verify Ghost Logic triggered
	# If logic works, ghost ship should move to target hex?
	# Or at least some state changed.
	# _handle_ghost_input checks 'forward_vec'. 
	# Ship facing default 0 = East?
	# Let's verify facing.
	assert_eq(_ship.facing, 0, "Ship facing East")
	
	# If valid move, current_path increases?
	# Ghost ship created?
	assert_not_null(_gm.ghost_ship, "Ghost ship should be spawned")
	assert_eq(_gm.ghost_ship.grid_position, target_hex, "Ghost ship should be at target")
	assert_eq(_gm.current_path.size(), 1, "Path should have 1 step")

func test_previous_path_saved_on_commit():
	# Initial State: Path empty
	assert_eq(_ship.previous_path.size(), 0, "Previous path starts empty")
	
	# Plot a move
	var target_hex = Vector3i(1, 0, -1) # East
	_gm._handle_movement_click(target_hex)
	
	# Commit Move
	# We need to simulate the commit logic. 
	# define execute_commit_move(ship_name: String, path: Array, final_facing: int, orbit_dir: int, is_orbiting: bool)
	var path = _gm.current_path
	var facing = _gm.ghost_ship.facing
	
	_gm.execute_commit_move(_ship.name, path, facing, 0, false)
	
	# Verify
	assert_eq(_ship.previous_path.size(), 1, "Previous path should be saved")
	assert_eq(_ship.previous_path[0], target_hex, "Previous path content match")

func test_select_ship_click():
	# Add another ship
	var s2 = ShipScript.new()
	s2.name = "OtherShip"
	s2.grid_position = Vector3i(-2, 2, 0)
	s2.player_id = 1
	_gm.ships.append(s2)
	_gm.add_child(s2)
	
	# Click on it
	_gm._handle_movement_click(s2.grid_position)
	
	assert_eq(_gm.selected_ship, s2, "Should switch selection to OtherShip")
