extends GutTest

var game_manager: GameManager
var station: Ship

func before_each():
	game_manager = GameManager.new()
	add_child_autofree(game_manager)
	game_manager._ready()
	
	# Create Station with Orbit Direction
	station = load("res://Scripts/Ship.gd").new()
	station.name = "Station"
	station.ship_class = "Space Station"
	station.grid_position = Vector3i(0, 0, 0)
	station.ship_class = "Space Station"
	station.side_id = 1
	station.orbit_direction = 1 # CW
	station.speed = 0 # Station shouldn't move
	
	if station.get_parent() == null:
		_game_manager.add_child(station)
	game_manager.ships.append(station)
	game_manager.add_child(station)

func test_auto_orbit_with_no_planet_does_not_hang():
	# Scenario: Station wants to orbit, but NO PLANET is nearby.
	# _on_orbit will fail.
	# _on_commit_move will send empty path.
	# execute_commit_move should accept it (Speed 0 -> Speed 0).
	# has_moved should be set.
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	
	# Manually trigger start_movement_phase
	# We expect it NOT to hang.
	# If it hangs, the test will timeout or crash.
	
	game_manager.start_movement_phase()
	
	assert_true(station.has_moved, "Station should be marked as moved (skipped orbit)")
	assert_eq(station.orbit_direction, 0, "Orbit direction should be cleared if orbit failed")
	
func test_auto_orbit_with_planet_succeeds():
	# Scenario: Station next to planet.
	# Setup Planet
	game_manager.planet_hexes.append(Vector3i(1, -1, 0)) # Adjacent
	
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	
	game_manager.start_movement_phase()
	
	assert_true(station.has_moved, "Station should be marked as moved (orbited)")
	assert_eq(station.grid_position, Vector3i(0, -1, 1), "Station should have moved CW around planet (Index 2 -> 3)")
	assert_eq(station.orbit_direction, 1, "Orbit direction should persist")
