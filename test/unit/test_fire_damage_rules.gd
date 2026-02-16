extends GutTest

var ship_script = load("res://Scripts/Ship.gd")

func test_fire_stack_limit():
	var s = ship_script.new()
	s.configure_frigate()
	
	# 1. Apply Electrical Fire
	s.apply_damage_effect({"type": "Fire", "key": "Electrical"}, 0)
	assert_eq(s.fire_damage_stack, 20, "Stack should be 20")
	assert_true(s.has_electrical_fire, "Should have electrical fire")
	
	# 2. Apply Electrical Fire AGAIN
	s.apply_damage_effect({"type": "Fire", "key": "Electrical"}, 0)
	assert_eq(s.fire_damage_stack, 20, "Stack should REMAIN 20 (Non-cumulative)")
	
func test_disastrous_overrides_electrical():
	var s = ship_script.new()
	s.configure_frigate()
	
	# 1. Electrical
	s.apply_damage_effect({"type": "Fire", "key": "Electrical"}, 0)
	assert_true(s.has_electrical_fire)
	
	# 2. Disastrous
	s.apply_damage_effect({"type": "Fire", "key": "Disastrous"}, 0)
	assert_true(s.has_disastrous_fire, "Disastrous should be active")
	assert_false(s.has_electrical_fire, "Electrical should be cleared")
	assert_eq(s.fire_damage_stack, 20, "Stack should be 20")

func test_electrical_does_not_override_disastrous():
	var s = ship_script.new()
	s.configure_frigate()
	
	# 1. Disastrous
	s.apply_damage_effect({"type": "Fire", "key": "Disastrous"}, 0)
	
	# 2. Electrical
	s.apply_damage_effect({"type": "Fire", "key": "Electrical"}, 0)
	assert_true(s.has_disastrous_fire, "Disastrous should REMAIN active")
	assert_false(s.has_electrical_fire, "Electrical should NOT replace Disastrous")
