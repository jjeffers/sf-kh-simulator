extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")

var _game_manager

func before_each():
	_game_manager = GameManager.new()
	add_child_autofree(_game_manager)

func test_speed_bleed_stationary():
	var s = Ship.new()
	s.name = "TestCarrier"
	s.ship_class = "Assault Carrier"
	s.side_id = 1
	s.configure_assault_carrier()
	s.speed = 2
	s.adf = 1
	_game_manager.add_child(s)
	_game_manager.ships.append(s)

	# Simulate execution (empty path = stationary)
	var empty_path: Array[Vector3i] = []
	s.planned_path = empty_path
	s.has_orders = true
	
	_game_manager.current_side_id = 1
	_game_manager.execute_all_movement()
	
	assert_eq(s.speed, 1, "Speed should bleed from 2 to 1 (ADF 1)")

	# Reset and execute again
	s.has_moved = false
	s.has_orders = true
	_game_manager.execute_all_movement()
	
	assert_eq(s.speed, 0, "Speed should bleed from 1 to 0 (ADF 1)")
