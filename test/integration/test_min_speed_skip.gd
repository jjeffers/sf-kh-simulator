extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")

var _game_manager

func before_each():
	_game_manager = GameManager.new()
	add_child_autofree(_game_manager)

func test_skip_turn_with_min_speed():
	var s = Ship.new()
	s.name = "FastShip"
	s.ship_class = "Assault Scout"
	s.side_id = 1
	s.configure_assault_scout()
	s.speed = 6
	s.adf = 1
	s.grid_position = Vector3i(0, 0, 0)
	s.facing = 0 # East (1, 0, -1)
	
	_game_manager.add_child(s)
	_game_manager.ships.append(s)
	
	# Simulate execution without explicit orders
	s.has_moved = false
	s.has_orders = false
	
	_game_manager.current_side_id = 1
	_game_manager.execute_all_movement()
	
	assert_eq(s.speed, 5, "Speed should drop from 6 to 5 (ADF 1)")
	assert_eq(s.grid_position, Vector3i(5, 0, -5), "Ship must have moved 5 hexes East")
