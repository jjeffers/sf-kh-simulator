extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")

var _gm = null

func before_each():
	_gm = GameManager.new()
	add_child(_gm)
	var s1 = Ship.new()
	s1.name = "Ship1"
	s1.side_id = 1
	add_child(s1)
	
	var s2 = Ship.new()
	s2.name = "Ship2"
	s2.side_id = 2
	add_child(s2)
	_gm.test_force_online = true
	_gm.my_side_id = 1
	# _gm.ships.clear() 

func after_each():
	_gm.free()

func test_turn_increment_cycle():
	# Verify initial state (Game starts at Turn 1)
	assert_eq(_gm.turn_count, 1, "Initial turn count should be 1")
	
	# Setup turn order
	# Setup turn order (Default is [1, 2])
	_gm.current_turn_order_index = 0
	
	# Start Turn 1, Side 1 (Already started by default/init, but let's simulate flow)
	# _start_turn_for_side updates current_side_id
	_gm._start_turn_for_side(1)
	assert_eq(_gm.turn_count, 1, "Turn should be 1 after start")
	
	# End Turn 1, Side 1 -> Should go to Side 2
	# We manually call end_turn_cycle to simulate end of turn
	_gm.combat_subphase = 2 # Simulate Active Combat Complete
	_gm.end_turn_cycle()
	
	assert_eq(_gm.current_turn_order_index, 1, "Should be at index 1 (Side 2)")
	assert_eq(_gm.turn_count, 1, "Turn should remain 1 for Side 2")
	
	# End Turn 1, Side 2 -> Should go to Side 1 (Round 2) and INCREMENT Turn
	_gm.combat_subphase = 2 # Simulate Active Combat Complete
	_gm.end_turn_cycle()
	
	assert_eq(_gm.current_turn_order_index, 0, "Should be back at index 0 (Side 1)")
	assert_eq(_gm.turn_count, 2, "Turn should be 2 for Round 2")
