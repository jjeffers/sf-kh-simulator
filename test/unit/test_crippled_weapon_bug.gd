extends GutTest

var game_manager: GameManager
var ship: Ship

func before_each():
	game_manager = GameManager.new()
	add_child(game_manager)
	
	ship = load("res://Scripts/Ship.gd").new()
	game_manager.add_child(ship)
	ship.side_id = 1
	
	# Define a standard weapon
	ship.weapons = [ {
		"name": "Laser Battery",
		"type": "Laser",
		"range": 10,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false,
		"is_crippled": false # Default
	}]
	
	# Setup GM context
	game_manager.ships = [ship]
	game_manager.current_phase = GameManager.Phase.COMBAT
	game_manager.firing_side_id = 1
	game_manager.current_side_id = 1

func after_each():
	game_manager.free()
	# Ship freed by GM

func test_crippled_weapon_should_be_unavailable():
	# 1. Verify initially available
	var w = ship.weapons[0]
	var avail_initial = game_manager._is_weapon_available_in_phase(w, ship)
	assert_true(avail_initial, "Weapon should be available initially")
	
	# 2. Cripple the weapon
	w["is_crippled"] = true
	
	# 3. Check availability again
	var avail_crippled = game_manager._is_weapon_available_in_phase(w, ship)
	assert_false(avail_crippled, "Weapon MUST be unavailable if crippled")
