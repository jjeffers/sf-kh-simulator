extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")

var game_manager

func before_each():
	game_manager = GameManager.new()
	add_child_autofree(game_manager)

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
	
	game_manager.add_child(s)
	game_manager.ships.append(s)
	
	# Simulate execution without explicit orders
	s.has_moved = false
	s.has_orders = false
	
	game_manager.current_side_id = 1
	game_manager.execute_all_movement()
	
	assert_eq(s.speed, 6, "Speed should maintain at 6 instead of dropping")
	assert_eq(s.grid_position, Vector3i(6, 0, -6), "Ship must have moved 6 hexes East")
