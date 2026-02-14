extends GutTest

var game_manager
var ship

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)
	game_manager.ships.clear()
	
	ship = load("res://Scripts/Ship.gd").new()
	ship.name = "TestShip"
	ship.side_id = 1
	ship.grid_position = Vector3i(0, 0, 0)
	ship.facing = 1 # SE
	ship.speed = 1
	ship.adf = 1
	ship.mr = 3 # 3 Turns allowed
	
	game_manager.ships.append(ship)
	game_manager.add_child(ship)
	game_manager.selected_ship = ship
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	game_manager.start_speed = 1
	game_manager.turns_remaining = 3
	
	game_manager._spawn_ghost()
	
	# Initial Move to enable turning (as per rule: must move before turning unless speed 0)
	var forward_hex = Vector3i(0, 1, -1)
	var path_arr: Array[Vector3i] = []
	path_arr.append(forward_hex)
	game_manager.current_path = path_arr
	game_manager.ghost_ship.grid_position = forward_hex
	game_manager.ghost_ship.facing = 1
	
	# Setup step state
	game_manager.can_turn_this_step = true
	game_manager.step_entry_facing = 1
	game_manager.turn_taken_this_step = 0

func test_mouse_turn_consumes_mr():
	# Initial check
	assert_eq(game_manager.turns_remaining, 3, "Start with 3 MR")
	
	# 1. Turn Right (Mouse Gesture)
	# Facing 1 (SE). Right is 2 (SW).
	# Neighbor 2 of (0, 1, -1) is (0, 1, -1) + (dir 2 vec)
	# Dir 2 vec: (-1, 1, 0)
	var right_nb = Vector3i(0, 1, -1) + Vector3i(-1, 1, 0) # (-1, 2, -1)
	
	game_manager._handle_mouse_facing(right_nb)
	
	assert_eq(game_manager.ghost_ship.facing, 2, "Ship should face Right")
	assert_eq(game_manager.turns_remaining, 2, "MR should decrease to 2")
	assert_eq(game_manager.turns_remaining, 2, "MR should decrease to 2")

func test_mouse_turn_undo_refunds_mr():
	# 1. Turn Right First
	var right_nb = Vector3i(0, 1, -1) + Vector3i(-1, 1, 0)
	game_manager._handle_mouse_facing(right_nb)
	assert_eq(game_manager.turns_remaining, 2, "MR consumed")
	
	# 2. Turn BACK to Center (Undo)
	# Neighbor 1 (SE) of (0, 1, -1) -> Original forward neighbor
	var center_nb = Vector3i(0, 1, -1) + Vector3i(0, 1, -1) # Wait, forward vec is (0, 1, -1) from (0,0,0) logic?
	# Facing 1 is SE. Neighbor 1 of hex H is H + SE_Vec.
	center_nb = Vector3i(0, 1, -1) + Vector3i(0, 1, -1) # (0, 2, -2).
	# Correct. We want to look at the hex that is in direction 1 from us.
	
	game_manager._handle_mouse_facing(center_nb)
	
	assert_eq(game_manager.ghost_ship.facing, 1, "Ship should face Center/Original")
	assert_eq(game_manager.turns_remaining, 3, "MR should be refunded to 3")
	assert_eq(game_manager.turns_remaining, 3, "MR should be refunded to 3")

func test_mouse_turn_blocked_if_no_mr():
	game_manager.turns_remaining = 0
	
	var right_nb = Vector3i(0, 1, -1) + Vector3i(-1, 1, 0)
	game_manager._handle_mouse_facing(right_nb)
	
	assert_eq(game_manager.ghost_ship.facing, 1, "Should NOT turn if 0 MR")
	assert_eq(game_manager.turns_remaining, 0, "MR stays 0")
