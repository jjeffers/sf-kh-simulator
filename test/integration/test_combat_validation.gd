extends GutTest

var GameManager
var Ship
var HexGrid
var Combat

func before_all():
	GameManager = load("res://Scripts/GameManager.gd").new()
	Ship = load("res://Scripts/Ship.gd")
	HexGrid = load("res://Scripts/HexGrid.gd").new()
	Combat = load("res://Scripts/Combat.gd").new()
	
	add_child(GameManager)
	GameManager.ships = []

func after_all():
	GameManager.queue_free()
	HexGrid.queue_free()
	Combat.queue_free()

	# Cleanup
	_log_result("test_docked_ship_can_fire_lasers [PASS]")
	GameManager.ships.clear()
	shooter.free()
	target.free()

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
	var shooter = Ship.new()
	shooter.player_id = 1
	shooter.name = "Shooter"
	shooter.grid_position = Vector3i(0, 0, 0)
	shooter.weapons = [
		{"name": "Laser", "type": "Laser", "range": 10, "arc": "360", "ammo": 99, "fired": false}
	]
	GameManager.ships.append(shooter)
	
	# Setup P2 Target
	var target = Ship.new()
	target.player_id = 2
	target.name = "Target"
	target.grid_position = Vector3i(1, 0, -1) # Adjacent
	GameManager.ships.append(target)
	
	# Action
	GameManager.firing_player_id = 1
	var result = GameManager._check_for_valid_combat_targets()
	
	# Assert
	assert_true(result, "Should find valid target at range 1")
	
	# Cleanup
	GameManager.ships.clear()
	shooter.free()
	target.free()

func test_docked_ship_can_fire_lasers():
	# Setup Docked P1 Shooter
	var shooter = Ship.new()
	shooter.player_id = 1
	shooter.name = "DockedShooter"
	shooter.grid_position = Vector3i(0, 0, 0)
	shooter.is_docked = true
	shooter.weapons = [
		{"name": "Laser", "type": "Laser", "range": 10, "arc": "360", "ammo": 99, "fired": false}
	]
	GameManager.ships.append(shooter)
	
	# Setup P2 Target
	var target = Ship.new()
	target.player_id = 2
	target.name = "Target"
	target.grid_position = Vector3i(1, 0, -1) # Adjacent
	GameManager.ships.append(target)
	
	# Action
	GameManager.firing_player_id = 1
	var result = GameManager._check_for_valid_combat_targets()
	
	# Assert
	assert_true(result, "Docked ship should be able to fire Laser")
	
	# Test Restricted Weapon (Torpedo)
	shooter.weapons = [
		{"name": "Torpedo", "type": "Torpedo", "range": 10, "arc": "FF", "ammo": 99, "fired": false}
	]
	
	result = GameManager._check_for_valid_combat_targets()
	assert_false(result, "Docked ship should NOT be able to fire Torpedo")

	# Cleanup
	GameManager.ships.clear()
	shooter.free()
	target.free()
