extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var ship_script = load("res://Scripts/Ship.gd")
var hex_grid_script = load("res://Scripts/HexGrid.gd")

var gm
var shooter
var target

func before_each():
	gm = game_manager_script.new()
	add_child_autofree(gm)
	gm.ships.clear()
	gm.planet_hexes.clear()

func test_planet_blocks_los():
	# Setup: Shooter (0,0,0) -> Planet (1,-1,0) -> Target (2,-2,0)
	# This is a straight line.
	var planet_hex = Vector3i(1, -1, 0)
	gm.planet_hexes.append(planet_hex)
	
	shooter = ship_script.new()
	shooter.name = "Shooter"
	shooter.grid_position = Vector3i(0, 0, 0)
	shooter.side_id = 1
	# Give weapon with range
	shooter.weapons = [ {"name": "Laser", "type": "Laser", "range": 10, "arc": "T", "ammo": 10, "max_ammo": 10}]
	if shooter.get_parent() == null:
		_game_manager.add_child(shooter)
	gm.ships.append(shooter)
	add_child_autofree(shooter)
	
	target = ship_script.new()
	target.name = "Target"
	target.grid_position = Vector3i(2, -2, 0)
	target.side_id = 2
	if target.get_parent() == null:
		_game_manager.add_child(target)
	gm.ships.append(target)
	add_child_autofree(target)
	
	# Verify LOS is blocked
	var targets = gm._get_valid_targets(shooter)
	var is_target_found = false
	for t in targets:
		if t == target:
			is_target_found = true
			break
			
	assert_false(is_target_found, "Target should be blocked by planet")

func test_planet_does_not_block_clear_los():
	# Setup: Shooter (0,0,0) -> Empty (1,-1,0) -> Target (2,-2,0)
	# Planet is at (1, 0, -1) (adjacent, not in line)
	gm.planet_hexes.append(Vector3i(1, 0, -1))
	
	shooter = ship_script.new()
	shooter.name = "Shooter"
	shooter.grid_position = Vector3i(0, 0, 0)
	shooter.side_id = 1
	shooter.weapons = [ {"name": "Laser", "type": "Laser", "range": 10, "arc": "T", "ammo": 10}]
	if shooter.get_parent() == null:
		_game_manager.add_child(shooter)
	gm.ships.append(shooter)
	add_child_autofree(shooter)
	
	target = ship_script.new()
	target.name = "Target"
	target.grid_position = Vector3i(2, -2, 0)
	target.side_id = 2
	if target.get_parent() == null:
		_game_manager.add_child(target)
	gm.ships.append(target)
	add_child_autofree(target)
	
	# Verify LOS is valid
	var targets = gm._get_valid_targets(shooter)
	var is_target_found = false
	for t in targets:
		if t == target:
			is_target_found = true
			break
			
	assert_true(is_target_found, "Target should be visible")
