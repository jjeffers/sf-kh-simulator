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
	ship.speed = 1 # Moving
	ship.adf = 1
	
	game_manager.ships.append(ship)
	game_manager.add_child(ship)
	game_manager.selected_ship = ship
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	game_manager.start_speed = 1
	
	game_manager._spawn_ghost()
	
	# Initial Move 1 hex forward to enable turning
	# Facing 1 (SE). Forward is neighbors[1] -> (0, 1, -1)
	var forward_hex = Vector3i(0, 1, -1)
	
	# Manually setup "Moved" state
	var path_arr: Array[Vector3i] = []
	path_arr.append(forward_hex)
	game_manager.current_path = path_arr
	game_manager.ghost_ship.grid_position = forward_hex
	game_manager.ghost_ship.facing = 1 # Still facing SE
	game_manager.can_turn_this_step = true # Allowed to turn now
	game_manager.step_entry_facing = 1 # Enter facing was 1
	
	# CRITICAL: We need to set the internal state that tracks "Original Facing" for this step.
	# Since I haven't implemented it yet, the current code doesn't use it. 
	# But once implemented, this test setup might need to set it.
	# For now, I'll rely on the fact that I'll add `step_entry_facing` logic.

func test_moving_ship_cannot_turn_twice_in_one_step():
	# 1. Turn Left (Valid)
	# Facing 1 (SE). Left is 0 (E). Neighbor (1, 0, -1)?
	# Let's calculate neighbor from current pos (0, 1, -1).
	# Direction 0 from (0, 1, -1) is (0, 1, -1) + (1, 0, -1) = (1, 1, -2).
	var left_nb = Vector3i(1, 1, -2)
	game_manager._handle_mouse_facing(left_nb)
	assert_eq(game_manager.ghost_ship.facing, 0, "First Left turn should work")
	
	# 2. Try to Turn Left AGAIN (Invalid accumulation)
	# Current facing 0 (E). Left is 5 (NE).
	# Neighbor 5 from (0, 1, -1) is (0, 1, -1) + (1, -1, 0) = (1, 0, -1).
	var left_left_nb = Vector3i(1, 0, -1)
	
	game_manager._handle_mouse_facing(left_left_nb)
	
	# EXPECTED: Should stay at 0 (First Left). Should NOT go to 5.
	assert_eq(game_manager.ghost_ship.facing, 0, "Second Left turn should be blocked")

func test_speed_0_can_turn_multiple_times():
	# Setup Speed 0 scenario
	game_manager.start_speed = 0
	var speed0_path: Array[Vector3i] = []
	game_manager.current_path = speed0_path
	game_manager.ghost_ship.grid_position = Vector3i(0, 0, 0)
	game_manager.ghost_ship.facing = 1
	game_manager.can_turn_this_step = true
	
	# 1. Turn Left (0)
	var left_nb = Vector3i(1, 0, -1) # Neighbor 0 of (0,0,0)
	game_manager._handle_mouse_facing(left_nb)
	assert_eq(game_manager.ghost_ship.facing, 0, "Speed 0: First turn ok")
	
	# 2. Turn Left again (5)
	# Neighbor 5 of (0,0,0) is (1, -1, 0)
	var left_left_nb = Vector3i(1, -1, 0)
	game_manager._handle_mouse_facing(left_left_nb)
	
	# EXPECTED: Should allow arbitrary rotation
	assert_eq(game_manager.ghost_ship.facing, 5, "Speed 0: Second turn ok")
