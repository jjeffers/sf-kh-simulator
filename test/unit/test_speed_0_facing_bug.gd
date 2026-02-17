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
	ship.facing = 0 # North (0)
	ship.speed = 0 # Stationary start
	ship.adf = 1
	
	game_manager.ships.append(ship)
	game_manager.add_child(ship)
	game_manager.selected_ship = ship
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	game_manager.start_speed = 0
	
	game_manager._spawn_ghost()

func test_reproduction_speed_0_rotation_and_move():
	# 1. Rotate freely to Facing 1 (NE)
	# Speed 0 allows this.
	# Direction 1 neighbor of (0,0,0) is (1, -1, 0)
	var neighbor_1 = Vector3i(1, -1, 0)
	game_manager._handle_mouse_facing(neighbor_1)
	
	assert_eq(game_manager.ghost_ship.facing, 1, "Speed 0 should allow free rotation to 1")
	
	# 2. Move 1 Hex in Facing 1 direction
	# Move to (1, -1, 0). Ghost is already facing it.
	game_manager._handle_ghost_input(neighbor_1)
	
	assert_eq(game_manager.current_path.size(), 1, "Should have moved 1 hex")
	assert_eq(game_manager.ghost_ship.grid_position, neighbor_1, "Ghost should be at new hex")
	assert_eq(game_manager.ghost_ship.facing, 1, "Ghost facing should still be 1")
	
	# 3. Try to turn to Facing 2 (SE)
	# This is a 1-step turn from Facing 1.
	# Entry facing for this step (the move we just made) SHOULD be 1 (the direction of movement).
	# If bug exists, code falls back to 'selected_ship.facing' (0) because path size <= 1.
	# Diff 0 -> 2 is 2 steps -> Invalid.
	# Diff 1 -> 2 is 1 step -> Valid.
	
	# Calculate Neighbor 2 from current position (1, -1, 0)
	# Direction 2 vector is (1, 0, -1)? No.
	# Grid directions: 0=(0,-1,1)? No.
	# HexGrid.directions: 
	# 0: (+1, -1, 0) ?? No, let's use GameManager logic relies on HexGrid.
	# I need to get the actual neighbor for direction 2 from current pos.
	
	# Let's derive it by rotating ghost pointer.
	# Current pos is (1, -1, 0).
	# Direction 2 from here.
	# I can just use HexGrid.get_neighbor(pos, 2) if available?
	# Or I manually calculate:
	# 0 = N? 1 = NE?
	# Let's assume standard flat top or pointy top?
	# The game uses Cube coords.
	# Let's rely on 'handle_mouse_facing' checking valid adjacency.
	# I'll just pick a hex that IS direction 2 from current.
	
	# (1, -1, 0) + Direction 2 vector.
	var dir_vec_2 = HexGrid.get_direction_vec(2)
	var neighbor_2 = Vector3i(1, -1, 0) + dir_vec_2
	
	game_manager._handle_mouse_facing(neighbor_2)
	
	# Verification
	assert_eq(game_manager.ghost_ship.facing, 2, "Should allow turning to facing 2 (1 step from 1). If failed, it remained 1.")
