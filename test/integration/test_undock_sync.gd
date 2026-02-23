extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")

var _game_manager
var _station
var _scout

func before_each():
	_game_manager = GameManager.new()
	add_child_autofree(_game_manager)
	
	# Minimal Setup
	_game_manager.map_radius = 10
	_game_manager.ships.clear()

func test_undock_movement_registration():
	# Setup: 1 Host (Station), 1 Guest (Scout) docked
	_station = Ship.new()
	_station.name = "Station"
	_station.configure_space_station() # Sets class and arrays
	_station.side_id = 1
	_station.grid_position = Vector3i(0, 0, 0)
	_game_manager.add_child(_station)
	_game_manager.ships.append(_station)
	
	_scout = Ship.new()
	_scout.name = "Scout"
	_scout.ship_class = "Assault Scout"
	_scout.side_id = 1
	_scout.grid_position = Vector3i(0, 0, 0)
	_scout.adf = 5
	_scout.speed = 4 # Speed must be < ADF to dock
	_game_manager.add_child(_scout)
	_game_manager.ships.append(_scout)
	
	
	# Manually dock
	_scout.dock_at(_station)
	assert_true(_scout.is_docked, "Scout should be docked")
	assert_eq(_scout.speed, 0, "Docked scout should have speed 0")
	
	# Simulate Client Planning a Move AWAY
	# Move 1 hex East
	var target_hex = Vector3i(1, 0, -1)
	var path: Array[Vector3i] = [target_hex]
	var facing = 0
	
	# Simulate RPC Call (register_movement_plan)
	# This triggers validation logic
	_game_manager.register_movement_plan("Scout", path, facing, 0, false)
	
	# Assert Orders Accepted
	assert_true(_scout.has_orders, "Orders should be accepted by validation")
	
	if not _scout.has_orders:
		gut.p("Orders were rejected! Checking logic...")
		return

	# Simulate Execution Phase
	_game_manager.current_side_id = 1
	_game_manager.execute_all_movement()
	
	# Assert Result
	assert_eq(_scout.grid_position, target_hex, "Scout should have moved")
	assert_false(_scout.is_docked, "Scout should have undocked")
	assert_eq(_game_manager.ships[1].docked_host, null, "Scout.docked_host should be null")
	assert_eq(_scout.speed, 1, "Scout speed should be 1")
