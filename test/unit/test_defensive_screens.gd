extends GutTest

var Combat = preload("res://Scripts/Combat.gd")
var Ship = preload("res://Scripts/Ship.gd")

func test_energy_screens_vs_beam_weapons():
	var source = Ship.new()
	var target = Ship.new()
	add_child(source)
	add_child(target)
	
	target.defense = "RH"
	target.active_screen = "None"
	target.is_ms_active = false
	
	var w_proton = {"type": "Proton Beam Battery", "range": 12}
	var w_electron = {"type": "Electron Beam Battery", "range": 10}
	
	# Proton vs RH (Base 60)
	var chance = Combat.calculate_hit_chance(0, w_proton, target)
	assert_eq(chance, 60, "Proton vs RH at range 0 should be 60%")
	
	# Proton vs ES (Base 26)
	target.active_screen = "ES"
	chance = Combat.calculate_hit_chance(0, w_proton, target)
	assert_eq(chance, 26, "Proton vs ES at range 0 should be 26%")
	
	# Electron vs PS (Base 25)
	target.active_screen = "PS"
	chance = Combat.calculate_hit_chance(0, w_electron, target)
	assert_eq(chance, 25, "Electron vs PS at range 0 should be 25%")
	
	# Electron vs SS (Base 40)
	target.active_screen = "SS"
	chance = Combat.calculate_hit_chance(0, w_electron, target)
	assert_eq(chance, 40, "Electron vs SS at range 0 should be 40%")
	
	# Proton vs MS (Base 50)
	target.active_screen = "None"
	target.is_ms_active = true
	chance = Combat.calculate_hit_chance(0, w_proton, target)
	assert_eq(chance, 50, "Proton vs MS at range 0 should be 50%")
	
	target.free()
	source.free()
