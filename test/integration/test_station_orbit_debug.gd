extends GutTest

var game_manager
var station

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)

func test_station_orbit_environment():
	# 1. Setup Environment similar to "Surprise Attack"
	# We need to manually trigger _spawn_planets to populate planet_hexes
	game_manager._spawn_planets()
	
	print("Planet Hexes: ", game_manager.planet_hexes)
	
	# 2. Spawn Station at known position (1, -1, 0)
	station = load("res://Scripts/Ship.gd").new()
	station.name = "Station Alpha"
	station.configure_space_station()
	station.side_id = 2
	station.orbit_direction = 1
	station.grid_position = Vector3i(1, -1, 0)
	game_manager.ships.append(station)
	game_manager.add_child(station)
	
	game_manager.selected_ship = station
	game_manager.my_side_id = 2
	game_manager.current_side_id = 2
	
	# 3. Test _on_orbit Logic directly
	game_manager._on_orbit(1)
	
	# 4. Check State
	print("State Is Orbiting: ", game_manager.state_is_orbiting)
	print("Current Path: ", game_manager.current_path)
	
	if game_manager.state_is_orbiting:
		# Check UI Validity
		game_manager._update_ui_state()
		print("Commit Button Disabled: ", game_manager.btn_commit.disabled)
	else:
		print("Orbit Failed to start.")
		
	assert_true(game_manager.state_is_orbiting, "Orbit should be active")
	assert_false(game_manager.btn_commit.disabled, "Commit button should be enabled")
