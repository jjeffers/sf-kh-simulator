extends GutTest

var game_manager
var station
var defiant

func before_each():
	# Setup GameManager
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)
	
	# Clear auto-loaded scenario ships
	for s in game_manager.ships:
		s.queue_free()
	game_manager.ships.clear()
	
	# Mock Scenario Data or Manually Spawn Ships
	# We need to simulate Scenario "surprise_attack" loading mostly to test Ship Config
	# But we can just spawn ships manually.
	
	station = load("res://Scripts/Ship.gd").new()
	station.name = "Station Alpha"
	station.configure_space_station() # Sets class "Space Station"
	station.side_id = 2 # UPF
	station.orbit_direction = 1 # CW
	station.grid_position = Vector3i(0, 1, -1)
	game_manager.ships.append(station)
	game_manager.add_child(station)
	
	defiant = load("res://Scripts/Ship.gd").new()
	defiant.name = "Defiant"
	defiant.configure_frigate()
	defiant.side_id = 2 # UPF
	defiant.grid_position = Vector3i(0, 1, -1)
	defiant.dock_at(station) # Defiant starts docked
	game_manager.ships.append(defiant)
	game_manager.add_child(defiant)
	
	# Set Game State
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	game_manager.current_side_id = 2
	game_manager.my_side_id = 2 # Authority
	
	# Add Planet for Orbit Logic
	game_manager.planet_hexes.append(Vector3i(0, 0, 0))
	
func test_station_auto_orbit_detection():
	# Ensure Station is detected as valid candidate
	# We call start_movement_phase and check if selected_ship becomes the station
	# And if it triggers the logic (which we can't easily check without mocking _spawn_ghost etc, but debug logs help)
	# Force logs
	game_manager.start_movement_phase()
	
	# Assertions
	# With instant orbit, the station should be marked has_moved = true
	# And the selection should have moved to the NEXT ship (Defiant)
	
	assert_true(station.has_moved, "Station should have auto-moved instantly")
	assert_eq(game_manager.selected_ship, defiant, "Selection should move to next ship (Defiant)")
	
	# Docking Rules:
	# Docked ships move WITH the host.
	# So they shouldn't be "available" for independent movement until they undock?
	# But the game handles undocking by selecting them and moving them away.
	# So they ARE available.
	
	# However, if Station is prioritized, it should still pick Station first.
	
	# Also check class string matching
	assert_true(station.ship_class in ["Space Station", "Station"], "Station class should be valid")
	assert_ne(station.orbit_direction, 0, "Station orbit should be active")
