extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")

var _gm = null
var _ship = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	
	_ship = ShipScript.new()
	_ship.name = "TestShip"
	_ship.side_id = 1
	_ship.adf = 2
	_ship.mr = 2
	_ship.speed = 2
	_ship.grid_position = Vector3i(0, 0, 0)
	_ship.facing = 0
	
	var s_arr: Array[Ship] = [_ship]
	_gm.ships = s_arr
	_gm.add_child(_ship)
	
	_gm.current_side_id = 1
	_gm.selected_ship = _ship
	_gm.start_speed = 2
	_gm.turns_remaining = 2
	_gm._spawn_ghost()
	_gm._reset_plotting_state()

func _simulate_turn(dir: int):
	# Helper to simulate mouse turn
	var current_facing = _gm.ghost_ship.facing
	var target_facing = (current_facing + dir + 6) % 6
	# Global HexGrid class is available
	var vec = HexGrid.get_direction_vec(target_facing)
	var target_hex = _gm.ghost_ship.grid_position + vec
	_gm._handle_mouse_facing(target_hex)

func after_each():
	_gm.free()

func test_segmented_undo():
	# Setup: Move 1 hex, Turn Right, Move 1 hex
	# Start at (0,0,0) Facing 0 (East)
	# 1. Move Forward 1 Hex (Facing 0 is East: 1, 0, -1)
	var hex1 = Vector3i(1, 0, -1)
	_gm._handle_ghost_input(hex1)
	
	assert_eq(_gm.movement_history.size(), 1, "History should have 1 segment (Move)")
	assert_eq(_gm.current_path.size(), 1, "Path size 1")
	assert_eq(_gm.ghost_ship.grid_position, hex1, "Ghost at hex1")
	
	# 2. Turn Right (+1) -> Facing 1 (SE: 0, 1, -1)
	_simulate_turn(1)
	
	assert_eq(_gm.movement_history.size(), 2, "History should have 2 segments (Turn)")
	assert_eq(_gm.ghost_ship.facing, 1, "Ghost facing 1")
	assert_eq(_gm.turns_remaining, 1, "Used 1 turn")
	
	# UNDO 1: Revert Turn
	_gm._on_undo()
	
	assert_eq(_gm.movement_history.size(), 1, "History popback")
	assert_eq(_gm.ghost_ship.facing, 0, "Facing restored to 0")
	assert_eq(_gm.turns_remaining, 2, "Turn refunded")
	assert_eq(_gm.ghost_ship.grid_position, hex1, "Position still at hex1")
	
	# UNDO 2: Revert Move
	_gm._on_undo()
	
	assert_eq(_gm.movement_history.size(), 0, "History empty")
	assert_eq(_gm.current_path.size(), 0, "Path cleared")
	assert_eq(_gm.ghost_ship.grid_position, Vector3i(0, 0, 0), "Position restored to start")
