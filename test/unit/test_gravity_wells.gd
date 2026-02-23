extends GutTest

var game_manager
var ship

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)
	
	# Stub Network Auth
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	game_manager.test_force_online = true
	
	# Clear auto-loaded scenario ships
	for s in game_manager.ships:
		if is_instance_valid(s):
			s.queue_free()
	game_manager.ships.clear()
	game_manager.selected_ship = null
	if game_manager.ghost_ship:
		game_manager.ghost_ship.queue_free()
		game_manager.ghost_ship = null
	
	ship = load("res://Scripts/Ship.gd").new()
	ship.name = "TestShip"
	ship.side_id = 1
	ship.grid_position = Vector3i(2, -2, 0)
	ship.facing = 2 # SW, pointing directly at origin
	ship.speed = 2 
	ship.adf = 1
	ship.mr = 2
	game_manager.add_child(ship)
	game_manager.ships.append(ship)
	
	game_manager.planet_hexes = [Vector3i(0,0,0)] as Array[Vector3i]

func after_each():
	if is_instance_valid(game_manager):
func test_gravity_exit_costs_mr():
	# Position ship INSIDE well: (1, -1, 0)
	ship.grid_position = Vector3i(1, -1, 0)
	ship.facing = 3 # West/SW
	ship.mr = 2
	
	game_manager._select_ship(ship)
	game_manager.start_speed = 3
	game_manager.turns_remaining = ship.mr # Initialize turns available
	
	# Move 1 hex outward: (1,-1,0) -> (0,-1,1)
	game_manager._handle_ghost_input(Vector3i(0, -1, 1))
	
	# The ship started at dist 1 (inside well) and exited to dist 1 (inside well? Wait, (0,-1,1) is dist 1).
	# Actually (0,-1,1) is distance 1 from (0,0,0). So it didn't strictly exit the well, but it exited the *hex* adjacent to the planet.
	# The rule says: "exits the first gravity well hex next to a planet".
	# Since it exited (1,-1,0) which is next to a planet, it incurs the penalty.
	
	assert_eq(game_manager.gravity_penalty_applied_this_turn, true, "Gravity penalty applied upon exiting well hex")
	assert_eq(game_manager.turns_remaining, 1, "MR was reduced by 1")
	
	# Check array
	var found_indicator = false
	for entry in game_manager.mr_expenditures:
		if entry["text"].begins_with("-1 MR (Gravity)") and entry["pos"] == Vector3i(0, -1, 1):
			found_indicator = true
			break
	assert_true(found_indicator, "Visual text indicator for Gravity MR expenditure was spawned at the post-well hex")

func test_gravity_involuntary_facing_change():
	# Position ship INSIDE well: (1, -1, 0)
	ship.grid_position = Vector3i(1, -1, 0)
	ship.facing = 3 # West/SW
	ship.mr = 0 # 0 MR!
	
	game_manager._select_ship(ship)
	game_manager.start_speed = 3
	game_manager.turns_remaining = ship.mr 
	
	# Move 2 hexes outward in direction 3: (1,-1,0) -> (0,-1,1) -> (-1,-1,2)
	game_manager._handle_ghost_input(Vector3i(-1, -1, 2))
	
	# Hex 1 passed: (0, -1, 1). Planet is at (0,0,0).
	# Penalty triggers here because we just exited (1,-1,0) which is adjacent to planet.
	# MR drops to -1.
	# Facing changes toward planet. Line to planet from (0,-1,1) is (0,-1,1) -> (0,0,0).
	# Direction from (0,-1,1) to (0,0,0) is Vector3i(0, 1, -1), which is index 1 (South-East).
	# New forward vector is (0, 1, -1).
	
	# Hex 2: Path bends and uses new forward vector from (0,-1,1) + (0,1,-1) = (0,0,0).
	
	assert_eq(game_manager.gravity_penalty_applied_this_turn, true, "Gravity penalty applied")
	assert_eq(game_manager.turns_remaining, -1, "MR driven below 0")
	assert_eq(game_manager.ghost_head_facing, 1, "Involuntary facing change occurred toward the planet (Index 1)")
	
	# Next hex from (0,-1,1) with new forward vec is (0, 0, 0)!
	assert_eq(game_manager.ghost_head_pos, Vector3i(0, 0, 0), "Ghost diverted into a new hex heading towards the planet")

func test_gravity_inward_turn_free():
	# Position ship INSIDE well: (1, -1, 0)
	ship.grid_position = Vector3i(1, -1, 0)
	ship.facing = 3 # West/SW
	ship.mr = 2 
	
	game_manager._select_ship(ship)
	game_manager.start_speed = 3
	game_manager.turns_remaining = ship.mr 
	
	# Move 1 hex outward: (1,-1,0) -> (0,-1,1)
	# This exit applies the -1 MR gravity penalty on arrival.
	# MR drops from 2 -> 1.
	game_manager._handle_ghost_input(Vector3i(0, -1, 1))
	
	assert_eq(game_manager.gravity_penalty_applied_this_turn, true, "Gravity penalty applied")
	assert_eq(game_manager.turns_remaining, 1, "MR was reduced by 1")
	
	# Hex 1 passed: (0, -1, 1). Planet is at (0,0,0).
	# Direction from (0,-1,1) to (0,0,0) is Vector3i(0, 1, -1), which is index 1 (South-East).
	# Currently facing 3 (West).
	
	# Manually rotate towards planet (Index 1).
	# Rotating directly is not possible in 1 step from 3.
	# Let's rotate to 4, then 5, then maybe check? Wait, we can only turn 60 degrees.
	# From 3, adjacent is 2 or 4.
	# Let's see what is "closer" to 1.
	# We can just manually check `_handle_mouse_facing` by forcing it.
	
	# Let's say we rotate from 3 -> 4 (North-West)
	game_manager._handle_mouse_facing(HexGrid.get_direction_vec(4), 4)
	
	# Wait, is 4 the ideal facing?
	# Line from (0,-1,1) to (0,0,0) has direction 1.
	# So turning to 4 is NOT turning to 1. It should cost 1 MR.
	assert_eq(game_manager.turns_remaining, 0, "Normal turn cost 1 MR")
	
	# Let's try undoing it
	game_manager._handle_mouse_facing(HexGrid.get_direction_vec(3), 3)
	assert_eq(game_manager.turns_remaining, 1, "MR refunded")
	
	# Let's just FORCE the facing to 1 to check the 0 cost logic, 
	# assuming the user somehow clicked there (even if invalid normally, we want to test the MR logic block)
	# The function _handle_mouse_facing checks diff_from_entry.
	# If we just change entry to 0 for a moment to easily jump to 1.
	game_manager.step_entry_facing = 0
	game_manager.ghost_ship.facing = 0
	game_manager._handle_mouse_facing(HexGrid.get_direction_vec(1), 1)
	
	# Is 1 the ideal facing? Yes.
	assert_eq(game_manager.turns_remaining, 2, "Inward gravity turn refunded penalty and cost 0 MR")
	
	var found_indicator = false
	for entry in game_manager.mr_expenditures:
		if entry["text"].begins_with("0 MR (Gravity)") and entry["pos"] == Vector3i(0, -1, 1):
			found_indicator = true
			break
	assert_true(found_indicator, "Visual 0 MR UI text was spawned")
