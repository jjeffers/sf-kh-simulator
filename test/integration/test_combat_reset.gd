extends GutTest

var game_manager
var station
var enemy

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)

func test_combat_target_validation():
	# 1. Check Method Existence
	var has_method = game_manager.has_method("_check_for_valid_combat_targets")
	print("Has _check_for_valid_combat_targets: ", has_method)
	assert_true(has_method, "Method check_for_valid_combat_targets should exist")
	
	if not has_method: return

	# 2. Setup Scenario where UPF should fire
	# UPF Ship (Defiant) at (0,0,0)
	var defiant = load("res://Scripts/Ship.gd").new()
	defiant.name = "Defiant"
	defiant.configure_fighter() # Or Frigate
	defiant.side_id = 1
	defiant.grid_position = Vector3i(0, 0, 0)
	# Equip Laser Battery (Range 10)
	defiant.weapons = [ {
		"name": "Laser Battery",
		"type": "Laser",
		"range": 10,
		"arc": "360",
		"ammo": 10,
		"max_ammo": 10,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false
	}]
	game_manager.ships.append(defiant)
	game_manager.add_child(defiant)
	
	# Enemy Ship at (0, 5, -5) (Dist 5, well within range)
	enemy = load("res://Scripts/Ship.gd").new()
	enemy.name = "Enemy"
	enemy.side_id = 2
	enemy.grid_position = Vector3i(0, 5, -5)
	game_manager.ships.append(enemy)
	game_manager.add_child(enemy)
	
	# SETUP GAME MANAGER STATE
	game_manager.current_phase = game_manager.Phase.COMBAT
	game_manager.firing_side_id = 1
	game_manager.combat_subphase = 2 # Active Fire
	
	# 3. Call the function (Turn 1 - Active)
	var result = game_manager._check_for_valid_combat_targets()
	assert_true(result, "Turn 1: Should return true")
	
	# SIMULATE FIRING
	# We manually set 'fired' = true for the weapon to simulate usage
	defiant.weapons[0]["fired"] = true
	
	# 4. Advance to Turn 2 (Start Turn for Side 2)
	# This should trigger _start_turn_for_side -> reset_turn_state -> reset_weapons
	game_manager._start_turn_for_side(2)
	
	# 5. Check Passive Fire for Side 1 in Turn 2
	game_manager.firing_side_id = 1 # Passive Fire for Side 1
	game_manager.current_phase = game_manager.Phase.COMBAT
	
	# Verify weapons are reset
	print("Defiant Weapon Fired State: ", defiant.weapons[0]["fired"])
	assert_false(defiant.weapons[0]["fired"], "Weapon should be reset after turn change")
	
	result = game_manager._check_for_valid_combat_targets()
	assert_true(result, "Turn 2: Should return true (Refreshed)")
