extends GutTest

var Combat = preload("res://Scripts/Combat.gd")
var Ship = preload("res://Scripts/Ship.gd")

func test_hit_chance_calculation():
	var s_source = Ship.new()
	var s_target = Ship.new()
	add_child(s_source)
	add_child(s_target)
	
	s_target.defense = "None"
	s_target.is_ms_active = false
	
	# Case 1: Laser Battery vs None (Base 80)
	# Dist 4: 80 - (4*5) = 60
	var w_laser = {"type": "Laser", "range": 10}
	var chance = Combat.calculate_hit_chance(4, w_laser, s_target, false, 0, s_source)
	assert_eq(chance, 60, "Laser at Range 4 (Base 80) should be 60%")
	
	# Case 2: Laser vs Reflective Hull (Base 50)
	s_target.defense = "RH"
	chance = Combat.calculate_hit_chance(4, w_laser, s_target, false, 0, s_source)
	assert_eq(chance, 30, "Laser vs RH (Base 50) at Range 4 should be 30%")
	
	# Case 3: Torpedo (Base 70)
	var w_torp = {"type": "Torpedo", "range": 10}
	chance = Combat.calculate_hit_chance(4, w_torp, s_target, false, 0, s_source)
	assert_eq(chance, 70, "Torpedo should be 70% flat")
	
	# Case 4: Head On (+10)
	chance = Combat.calculate_hit_chance(4, w_torp, s_target, true, 0, s_source)
	assert_eq(chance, 80, "Torpedo Head-On should be 80%")
	
	s_source.free()
	s_target.free()

func test_damage_roll():
	# "1d6+2"
	var dmg_str = "1d6+2"
	var dmg = Combat.roll_damage(dmg_str)
	assert_between(dmg, 3, 8, "Damage should be between 1+2 and 6+2")
