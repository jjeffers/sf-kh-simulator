extends GutTest

var Ship = preload("res://Scripts/Ship.gd")

func test_ship_initialization():
	var s = Ship.new()
	s.configure_fighter()
	
	assert_eq(s.ship_class, "Fighter", "Should be Fighter")
	assert_eq(s.hull, 8, "Fighter Hull should be 8")
	assert_eq(s.adf, 5, "Fighter ADF should be 5")
	assert_eq(s.mr, 5, "Fighter MR should be 5")
	assert_eq(s.weapons.size(), 1, "Fighter should have 1 weapon")
	s.free()

func test_reset_turn_state():
	var s = Ship.new()
	s.has_moved = true
	s.has_fired = true
	
	s.reset_turn_state()
	
	assert_false(s.has_moved, "has_moved should be false after reset")
	assert_false(s.has_fired, "has_fired should be false after reset")
	s.free()
