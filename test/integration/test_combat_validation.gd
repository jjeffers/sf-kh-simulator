extends GutTest

var _gm = null
var ShipScript = null
var _hex_grid = null
var _combat = null

func before_all():
	var GM_Script = load("res://Scripts/GameManager.gd")
	_gm = GM_Script.new()
	ShipScript = load("res://Scripts/Ship.gd")
	var Hex_Script = load("res://Scripts/HexGrid.gd")
	_hex_grid = Hex_Script.new()
	var Combat_Script = load("res://Scripts/Combat.gd")
	_combat = Combat_Script.new()
	
	add_child(_gm)

func after_all():
	_gm.queue_free()
	_hex_grid.queue_free()
	_combat.queue_free()

func _log_result(msg):
	var file = FileAccess.open("user://validation_result.txt", FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open("user://validation_result.txt", FileAccess.WRITE)
	file.seek_end()
	file.store_line(msg)
	file.close()

func test_valid_target_in_range():
	_log_result("Starting Validation Test...")
	# Setup P1 Shooter
	var shooter = ShipScript.new()
	shooter.side_id = 1
	shooter.name = "Shooter"
	shooter.grid_position = Vector3i(0, 0, 0)
	shooter.weapons = [
		{"name": "Laser", "type": "Laser", "range": 10, "arc": "360", "ammo": 99, "fired": false}
	]
	_gm.ships.append(shooter)
	
	# Setup P2 Target
	var target = ShipScript.new()
	target.side_id = 2
	target.name = "Target"
	target.grid_position = Vector3i(1, 0, -1) # Adjacent
	_gm.ships.append(target)
	
	# Action
	_gm.firing_side_id = 1
	var result = _gm._check_for_valid_combat_targets()
	
	# Assert
	assert_true(result, "Should find valid target at range 1")
	
	# Cleanup
	_gm.ships.clear()
	shooter.free()
	target.free()

func test_docked_ship_can_fire_lasers():
	# Setup Docked P1 Shooter
	var shooter = ShipScript.new()
	shooter.side_id = 1
	shooter.name = "DockedShooter"
	shooter.grid_position = Vector3i(0, 0, 0)
	shooter.is_docked = true
	shooter.weapons = [
		{"name": "Laser", "type": "Laser", "range": 10, "arc": "360", "ammo": 99, "fired": false}
	]
	_gm.ships.append(shooter)
	
	# Setup P2 Target
	var target = ShipScript.new()
	target.side_id = 2
	target.name = "Target"
	target.grid_position = Vector3i(1, 0, -1) # Adjacent
	_gm.ships.append(target)
	
	# Action
	_gm.firing_side_id = 1
	var result = _gm._check_for_valid_combat_targets()
	
	# Assert
	assert_true(result, "Docked ship should be able to fire Laser")
	
	# Test Restricted Weapon (Torpedo)
	shooter.weapons = [
		{"name": "Torpedo", "type": "Torpedo", "range": 10, "arc": "FF", "ammo": 99, "fired": false}
	]
	
	result = _gm._check_for_valid_combat_targets()
	assert_false(result, "Docked ship should NOT be able to fire Torpedo")

	# Cleanup
	_gm.ships.clear()
	shooter.free()
	target.free()
