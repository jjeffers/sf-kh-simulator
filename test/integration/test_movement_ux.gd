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
	ship.facing = 1
	ship.speed = 2
	ship.adf = 2 # Can decel to 0
	# Set max speed high enough
	ship.mr = 2
	
	game_manager.ships.append(ship)
	game_manager.add_child(ship)
	
	game_manager.selected_ship = ship
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	
	# Spawn ghost manually as _handle_movement_click usually expects one for planning
	# But for self-click (Start of turn), ghost might not exist yet?
	# Actually, _spawn_ghost is called on selection.
	game_manager._spawn_ghost()

func test_self_click_decelerate_valid():
	# Scenario: Speed 2, ADF 2. Click self (0,0,0). Should commit Speed 0.
	# Verify specific conditions
	assert_eq(ship.speed, 2)
	assert_eq(ship.adf, 2)
	
	# Click Self
	# Ensure GM knows start speed (usually set in start_movement_phase)
	game_manager.start_speed = ship.speed
	game_manager._handle_movement_click(Vector3i(0, 0, 0))
	
	# Assert committed
	# If committed, ship.has_moved should be true
	# And speed should be 0
	assert_true(ship.has_moved, "Ship should have moved (committed)")
	assert_eq(ship.speed, 0, "Ship speed should be 0")

func test_self_click_decelerate_invalid():
	# Scenario: Speed 3, ADF 1. Click self. Should NOT commit.
	ship.speed = 3
	ship.adf = 1
	ship.has_moved = false
	
	game_manager._spawn_ghost() # Reset ghost
	
	# Click Self
	game_manager._handle_movement_click(Vector3i(0, 0, 0))
	
	# Assert NOT committed
	assert_false(ship.has_moved, "Ship should NOT have moved (ADF violation)")
	assert_eq(ship.speed, 3, "Ship speed should remain 3")

func test_ghost_click_commit():
	# Scenario: Plan a valid move, then click the ghost to commit.
	ship.speed = 1
	ship.adf = 1
	
	# 1. Plan a move to (1, -1, 0) - Neighbor 1
	var target = Vector3i(1, -1, 0)
	
	# Simulate clicking target to add to path
	# We manually setup the "Planned" state.
	# current_path is typed Array[Vector3i], so we must assign a typed array.
	var path_arr: Array[Vector3i] = []
	path_arr.append(target)
	game_manager.current_path = path_arr
	
	game_manager.ghost_ship.grid_position = target
	game_manager.ghost_ship.facing = 1
	
	# 2. Click the Ghost (Target Hex)
	game_manager._handle_movement_click(target)
	
	# Assert Committed
	assert_true(ship.has_moved, "Ship should have moved via Ghost Click")
	assert_eq(ship.grid_position, target, "Ship should be at target")
