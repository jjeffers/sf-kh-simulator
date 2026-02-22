extends GutTest

var Combat = preload("res://Scripts/Combat.gd")
var Ship = preload("res://Scripts/Ship.gd")
var HexGrid = preload("res://Scripts/HexGrid.gd")

func test_best_defensive_fire_hex():
	var source = Ship.new()
	var target = Ship.new()
	add_child(source)
	add_child(target)
	
	source.grid_position = Vector3i(0, 0, 0)
	source.facing = 2
	
	target.defense = "None"
	target.is_ms_active = false
	
	# Simulating movement
	# Start at dist 10, move to dist 5, end at dist 8
	var path: Array[Vector3i] = []
	path.append(Vector3i(10, 0, -10)) # Dist 10
	path.append(Vector3i(5, 0, -5)) # Dist 5
	target.previous_path = path
	target.grid_position = Vector3i(8, 0, -8) # Dist 8
	
	var weapon = {"type": "Laser", "range": 10, "arc": "360"}
	# Base 80, -5 per dist
	# Dist 10 => 80 - 50 = 30%
	# Dist 5 => 80 - 25 = 55%
	# Dist 8 => 80 - 40 = 40%
	# Best should be Dist 5 (55%)
	
	# Base 65. Range 5 penalty = 25 (-25). Total 40.
	# It shouldn't use dist 8 (-40 => 25) or dist 10 (-50 => 15).
	
	var best_hex_info = Combat.get_best_defensive_fire_hex(source, target, weapon)
	
	assert_eq(best_hex_info["chance"], 40, "Best chance should be computed from closest hex in path.")
	assert_eq(best_hex_info["distance"], 5, "Best distance should be 5.")
	assert_eq(best_hex_info["hex"], Vector3i(5, 0, -5), "Best hex should be at dist 5.")
	
	source.free()
	target.free()
