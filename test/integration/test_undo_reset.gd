extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var HexGridScript = preload("res://Scripts/HexGrid.gd")

var _gm = null
var _ship = null

func before_each():
	get_node("/root/NetworkManager").lobby_data = {"teams": {}, "ship_assignments": {}}
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm._ready()

	# Clear any auto-loaded ships from _ready/RPC
	_gm.ships.clear()

	_ship = ShipScript.new()
	_ship.name = "TestShip"
	_ship.grid_position = Vector3i(0, 0, 0)
	_ship.side_id = 1
	_ship.adf = 2
	_ship.speed = 2 # Start with speed 2
	_ship.facing = 0 # East
	_gm.ships.append(_ship)
	_gm.add_child(_ship)
	
	_gm.current_side_id = 1
	_gm.my_side_id = 1 # Authoritative
	_gm.current_phase = _gm.Phase.MOVEMENT
	
	_gm.start_movement_phase()
	# Ensure ship is selected
	_gm.selected_ship = _ship
	_gm._reset_plotting_state() # Init state
	_gm._spawn_ghost()

func after_each():
	_gm.free()

func test_undo_resets_full_path():
	# Initial State
	assert_eq(_gm.current_path.size(), 0, "Path should start empty")
	
	# Plot 2 steps
	# 1. Move East (Target 1, 0, -1)
	var hex1 = Vector3i(1, 0, -1)
	_gm._handle_movement_click(hex1)
	
	# 2. Move East (Target 2, 0, -2)
	var hex2 = Vector3i(2, 0, -2)
	_gm._handle_movement_click(hex2)
	
	assert_eq(_gm.current_path.size(), 2, "Path should have 2 steps")
	assert_eq(_gm.ghost_ship.grid_position, hex2, "Ghost should be at end")
	
	# Call UNDO
	_gm._on_undo()
	
	# Verify FULL RESET
	assert_eq(_gm.current_path.size(), 0, "Undo should fully reset path to 0")
	assert_eq(_gm.ghost_ship.grid_position, _ship.grid_position, "Ghost should return to start")
	assert_eq(_gm.ghost_ship.facing, _ship.facing, "Ghost facing should reset")
	assert_eq(_gm.movement_history.size(), 0, "History should be cleared")
