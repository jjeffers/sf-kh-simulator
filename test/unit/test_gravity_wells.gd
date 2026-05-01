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
		game_manager.free()

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
	# Original facing is 3. Diff to 1 is -2 (+6 = 4). Step is -1.
	# New facing is 3 - 1 = 2 (South-West).
	# New forward vector is HexGrid.directions[2] which is Vector3i(-1, 1, 0).
	
	# Hex 2: Path bends and uses new forward vector from (0,-1,1) + (-1,1,0) = (-1,0,1).
	
	assert_eq(game_manager.gravity_penalty_applied_this_turn, true, "Gravity penalty applied")
	assert_eq(game_manager.turns_remaining, -1, "MR driven below 0")
	assert_eq(game_manager.ghost_head_facing, 2, "Involuntary facing change occurred toward the planet (Max 1 hex face / 60 degrees)")
	
	# Next hex from (0,-1,1) with new forward vec is (-1, 0, 1)!
	assert_eq(game_manager.ghost_head_pos, Vector3i(-1, 0, 1), "Ghost diverted into a new hex heading towards the planet")

func test_gravity_inward_turn_free():
	# Position ship INSIDE well: (1, -1, 0)
	ship.grid_position = Vector3i(1, -1, 0)
	ship.facing = 4 # NW
	ship.mr = 2
	
	game_manager._select_ship(ship)
	game_manager.start_speed = 3
	game_manager.turns_remaining = ship.mr
	
	# Move from (1, -1, 0) to (1, -2, 1). Vector: (0, -1, 1) = Direction 4 (NW).
	game_manager._handle_ghost_input(Vector3i(1, -2, 1))
	
	# Now at (1, -2, 1). Entry facing is 4.
	# The penalty is applied because we left (1,-1,0).
	assert_eq(game_manager.gravity_penalty_applied_this_turn, true, "Gravity penalty applied")
	assert_eq(game_manager.turns_remaining, 1, "MR was reduced by 1")
	
	# From (1, -2, 1) to (0,0,0): (-1, 2, -1). 
	# Which hex direction is closest to (-1, 2, -1)? Direction 2 (-1, 1, 0) or 1 (0, 1, -1).
	# Let's check which one Godot uses.
	# Our entry facing is 4. Valid turns are 3, 4, 5.
	# Are 3 or 5 inward?
	# From (1, -2, 1) to planet (0,0,0) is (-1, 2, -1).
	# If we just force `is_inward_gravity_turn` to trigger by making it perfectly straight?
	# Let's just manually trigger the validation logic by simulating the exact angle.
	# Wait, if planet is at 0,0,0, and we are at (1, -2, 1), the ideal direction is index 2 or 1.
	# But from 4 we can only reach 3 or 5. Neither is closer to 1 or 2 than 4?
	# Actually, going to 3 is -1, 0, 1. Going to 5 is 1, -1, 0.
	pass
	# It's much easier to just force `is_inward_gravity_turn` by overriding the closest_planet_pos.
	# Let's just create a planet exactly where we need it to be!
	game_manager.planet_hexes.append(Vector3i(-1, -2, 2))
	# Now from (1, -2, 1) the planet is at (-1, -2, 2). Vector is (-2, 0, 1)...
	
	# To make it simple: from (1, -2, 1), we face 4. 
	# Ideal facing towards (0,0,0) is 2.
	# If we turn Right to 5 (NE):
	# Distance from 5 to 2 is 3. Old distance (4 to 2) is 2.
	# This is an OUTWARD turn, so it should cost 1 MR normally.
	game_manager._handle_mouse_facing(game_manager.ghost_ship.grid_position + HexGrid.get_direction_vec(5))
	assert_eq(game_manager.turns_remaining, 0, "Normal turn cost 1 MR")
	game_manager._handle_mouse_facing(game_manager.ghost_ship.grid_position + HexGrid.get_direction_vec(4))
	assert_eq(game_manager.turns_remaining, 1, "MR refunded")
	
	# If we turn Left to 3 (West):
	# Distance from 3 to 2 is 1. Old distance (4 to 2) is 2.
	# This brings us CLOSER to the planet, making it an Inward Gravity Turn!
	game_manager._handle_mouse_facing(game_manager.ghost_ship.grid_position + HexGrid.get_direction_vec(3))
	
	assert_eq(game_manager.turns_remaining, 2, "Inward gravity turn refunded penalty and cost 0 MR")
