extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var ship_script = load("res://Scripts/Ship.gd")

var gm

func before_each():
	gm = game_manager_script.new()
	add_child_autofree(gm)
	# Initialize minimal state
	gm.ships = []
	gm.planet_hexes = []
	gm.current_phase = gm.Phase.MOVEMENT
	gm.current_side_id = 1

func test_planet_collision_destroys_ship():
	# 1. Setup Planet at (1, -1, 0)
	var planet_hex = Vector3i(1, -1, 0)
	gm.planet_hexes.append(planet_hex)
	
	# 2. Setup Ship at (0, 0, 0) facing hex (1, -1, 0)
	var ship = ship_script.new()
	ship.name = "TestShip"
	ship.grid_position = Vector3i(0, 0, 0)
	ship.side_id = 1
	ship.max_hull = 100
	ship.hull = 100
	gm.ships.append(ship)
	add_child_autofree(ship)
	
	# 3. Execute Move into Planet
	# Path: (0,0,0) -> (1,-1,0). BUT validate_move_path expects segments?
	# If validation checks distance from current, then [next_hex] is sufficient.
	var path = [planet_hex]
	
	# Mock the RPC call locally
	gm.execute_commit_move(ship.name, path, 0, 0, false)
	
	# 4. Assertions
	# Ship should be destroyed
	assert_true(ship.is_destroyed, "Ship should be destroyed after entering planet hex")
	assert_true(ship.is_exploding, "Ship should be exploding")
	
	# Position should be at the planet (or strictly, where it died)
	assert_eq(ship.grid_position, planet_hex, "Ship should die at the planet hex")
	assert_true(ship.has_moved, "Ship should be marked as moved even if destroyed (Anti-Freeze Fix)")

func test_planet_collision_avoids_safe_path():
	# 1. Setup Planet at (2, -2, 0)
	var planet_hex = Vector3i(2, -2, 0)
	gm.planet_hexes.append(planet_hex)
	
	# 2. Ship moves (0,0,0) -> (1,-1,0) (Safe)
	var ship = ship_script.new()
	ship.name = "SafeShip"
	ship.grid_position = Vector3i(0, 0, 0)
	ship.side_id = 1 # Must match current_side_id
	gm.ships.append(ship)
	add_child_autofree(ship)
	
	var path = [Vector3i(1, -1, 0)] # Stops before planet
	
	gm.execute_commit_move(ship.name, path, 0, 0, false)
	
	assert_false(ship.is_destroyed, "Ship should NOT be destroyed if it stops before planet")
