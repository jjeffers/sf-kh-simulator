extends GutTest

var game_manager
var ship

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)
	
	# Clear ships
	game_manager.ships.clear()
	
	# Create a test ship
	ship = load("res://Scripts/Ship.gd").new()
	ship.name = "TestShip"
	ship.side_id = 1
	ship.grid_position = Vector3i(0, 0, 0)
	ship.facing = 1 # Facing NE (Hex 1)
	ship.speed = 1
	ship.adf = 1
	
	game_manager.ships.append(ship)
	game_manager.add_child(ship)
	
	game_manager.selected_ship = ship
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	
	# Initial Spawn Ghost
	game_manager._spawn_ghost()
	# Verify ghost starts at ship pos/facing
	assert_eq(game_manager.ghost_ship.grid_position, Vector3i(0, 0, 0))
	assert_eq(game_manager.ghost_ship.facing, 1)

func test_mouse_over_left_turn_preview():
	# Scenario: Facing 1 (NE). Mouse over Neighbor 0 (N) -> Left Turn.
	# Neighbor 0 is to the "Left" of NE?
	# Hex Directions: 0=E, 1=SE, 2=SW, 3=W, 4=NW, 5=NE ?
	# Wait, check HexGrid directions.
	# Usually: 0=E, 1=SE, 2=SW, 3=W, 4=NW, 5=NE.
	# If facing 1 (SE). Left is 0 (E). Right is 2 (SW).
	# Let's check logic:
	# diff = (dir_idx - facing + 6) % 6
	# If facing=1, dir=0. diff = (0 - 1 + 6) % 6 = 5. (Left) -> Correct.
	# Setup Ghost at (0,0,0) facing 1.
	game_manager.ghost_ship.facing = 1
	game_manager.can_turn_this_step = true # Allow turn
	
	# Mouse over Hex direction 0 (Neighbor E)
	# (1,0) is usually East? Or (1, -1, 0)?
	# HexGrid.directions:
	# 0: (1, 0, -1) E (Flat top?) Or Point top?
	# Godot flat top: +x is E?
	# Let's assume (1, -1, 0) is roughly E/SE depending on orientation.
	# BUT we can just use HexGrid logic if mocked, or just calculate coordinate.
	# Dir 0 (E): (1, 0, -1) ?
	# Dir 1 (SE): (0, 1, -1) ?
	
	# 1. Start of Turn, Speed 1
	# Moving ships start with can_turn_this_step = false (must move first)
	game_manager.can_turn_this_step = false
	game_manager.ghost_ship.facing = 1
	
	var left_hex = Vector3i(1, 0, -1)
	
	# CASE 1: Speed 0 (Pivot) - Covered by test_speed_0_free_rotation_preview
	
	# CASE 2: Speed > 0 (Moving)
	game_manager.start_speed = 1
	game_manager._handle_mouse_facing(left_hex)
	assert_eq(game_manager.ghost_ship.facing, 1, "Speed > 0 ship should NOT rotate at start")


func test_turn_after_move_preview():
	# Scenario: Speed 1. Move 1 hex. Then turn Left.
	game_manager.start_speed = 1
	
	# 1. Sim Move 1 Hex Forward (to NE neighbor)
	# Current pos (0,0,0). Facing 1 (NE). Neighbor is (1, -1, 0) maybe?
	# Let's just manually set path
	var next_hex = Vector3i(1, -1, 0)
	var path_arr: Array[Vector3i] = []
	path_arr.append(next_hex)
	
	game_manager.current_path = path_arr
	game_manager.ghost_ship.grid_position = next_hex
	game_manager.ghost_ship.facing = 1
	
	# Now we have moved 1 step.
	game_manager.can_turn_this_step = true # Enabled after move
	
	# 2. Hover Left relative to new facing
	# Facing 1 (SE?). Left is 0 (E).
	# Neighbor of (1, -1, 0) in direction 0?
	# (1, -1, 0) + (1, 0, -1) = (2, -1, -1)
	var left_neighbor = Vector3i(2, -1, -1)
	
	# Execute
	game_manager._handle_mouse_facing(left_neighbor)
	
	# Assert
	assert_eq(game_manager.ghost_ship.facing, 0, "Should rotate Left after moving")

func test_mouse_over_right_turn_preview():
	# Facing 1 (SE). Right is 2 (SW). Vector (-1, 1, 0).
	game_manager.ghost_ship.facing = 1
	game_manager.can_turn_this_step = true
	
	var right_hex = Vector3i(-1, 1, 0)
	
	# Execute
	game_manager._handle_mouse_facing(right_hex)
	
	# Assert
	assert_eq(game_manager.ghost_ship.facing, 2, "Ghost should rotate Right to Facing 2")

func test_mouse_over_invalid_turn_preview():
	# Facing 1 (SE). Behind is 4 (NW). Vector (0, -1, 1).
	# Should NOT rotate.
	game_manager.ghost_ship.facing = 1
	game_manager.can_turn_this_step = true
	
	var rear_hex = Vector3i(0, -1, 1)
	
	# Execute
	game_manager._handle_mouse_facing(rear_hex)
	
	# Assert
	assert_eq(game_manager.ghost_ship.facing, 1, "Ghost should NOT rotate to Rear")

func test_cannot_turn_restriction():
	# Facing 1. Try Left Turn. But can_turn_this_step = false AND path not empty.
	game_manager.ghost_ship.facing = 1
	game_manager.can_turn_this_step = false
	var path_arr: Array[Vector3i] = []
	path_arr.append(Vector3i(0, 0, 0))
	game_manager.current_path = path_arr # Moved at least once (dummy)
	
	var left_hex = Vector3i(1, 0, -1)
	
	# Execute
	game_manager._handle_mouse_facing(left_hex)
	
	# Assert
	assert_eq(game_manager.ghost_ship.facing, 1, "Ghost should NOT rotate if turn restricted")

func test_speed_0_free_rotation_preview():
	# Scenario: Speed 0 ship at start of turn. Should be able to rotate freely.
	ship.speed = 0
	game_manager.start_speed = 0
	game_manager.can_turn_this_step = true # Actually irrelevant if path size is 0, checks pass
	var path_arr: Array[Vector3i] = []
	game_manager.current_path = path_arr # Empty path
	
	game_manager.ghost_ship.facing = 1
	var left_hex = Vector3i(1, 0, -1)
	
	# Execute
	game_manager._handle_mouse_facing(left_hex)
	
	# Assert
	assert_eq(game_manager.ghost_ship.facing, 0, "Speed 0 ship should rotate Left")
