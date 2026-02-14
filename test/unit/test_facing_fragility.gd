extends GutTest

var game_manager: Node2D
var ship: Node2D

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child(game_manager)
	
	ship = float_ship()
	game_manager.selected_ship = ship
	game_manager.ghost_ship = float_ship()
	# game_manager.HexGrid = load("res://Scripts/HexGrid.gd")
	game_manager.set_process(false)
	game_manager.set_physics_process(false)
	
	# Initialize MR for testing
	game_manager.selected_ship.mr = 3
	game_manager.turns_remaining = 3

func float_ship():
	var s = load("res://Scripts/Ship.gd").new()
	s.grid_position = Vector3i(0, 0, 0)
	s.facing = 0
	return s

func test_fragile_state_desync():
	# Scenario: Move Forward -> Turn Left -> Undo -> Turn Right
	# Verify that we don't rely on 'step_entry_facing' variable matching reality manually.
	# 1. Start check
	game_manager.ghost_head_facing = 0
	game_manager.ghost_head_pos = Vector3i(0, 0, 0)
	game_manager.current_path.clear()
	# We intentionally do NOT set 'step_entry_facing' to anything specific, 
	# or set it to Garbage to prove we don't use it.
	game_manager.step_entry_facing = 999
	
	# 2. Move Forward 1 hex: (0,0,0) -> (1, 0, -1) (Dir 0 - East)
	game_manager._handle_ghost_input(Vector3i(1, 0, -1))
	
	assert_eq(game_manager.current_path.size(), 1)
	assert_eq(game_manager.turns_remaining, 3, "MR should NOT decrease after forward move")
	
	# 3. Turn Right (Facing 0 -> 1)
	# Current pos: (1, 0, -1).
	# Neighbor 1 (SE) of (1, 0, -1) is (1, 0, -1) + (0, 1, -1) = (1, 1, -2).
	var target_hex_right = Vector3i(1, 1, -2)
	game_manager._handle_mouse_facing(target_hex_right)
	
	assert_eq(game_manager.ghost_ship.facing, 1)
	assert_eq(game_manager.turns_remaining, 2) # Cost 1
	
	# 4. UNDO (Should restore MR and Facing)
	game_manager._on_undo()
	
	assert_eq(game_manager.ghost_ship.facing, 0) # Should be back to 0
	# Turns remaining depends on if undo logic restores it.
	# _on_undo pops history. History pushed before turn had full MR.
	assert_eq(game_manager.turns_remaining, 3)
	
	# 5. Turn LEFT (0 -> 5)
	# Neighbor 5 (NE) of (1, 0, -1) is (1, 0, -1) + (1, -1, 0) = (2, -1, -1)
	var target_hex_left = Vector3i(2, -1, -1)
	
	game_manager._handle_mouse_facing(target_hex_left)
	
	assert_eq(game_manager.ghost_ship.facing, 5)
	assert_eq(game_manager.turns_remaining, 2)
	
	# Pass implies we correctly derived that entry facing was 0 based on the path vector.
