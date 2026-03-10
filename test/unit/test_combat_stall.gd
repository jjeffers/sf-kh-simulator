extends SceneTree

func _init():
	print("Running Test...")
	
	# Instantiate Faction details
	# Wait, we need Ship.tscn
	var GameManager = preload("res://Scripts/GameManager.gd")
	var gm = GameManager.new()
	
	var ShipClass = preload("res://Scripts/Ship.gd")
	var fighter = ShipClass.new()
	fighter.name = "Sathar Fighter"
	fighter.side_id = 2
	fighter.grid_position = Vector3i(0, 0, 0)
	fighter.facing = 0
	fighter.weapons = [{
		"name": "Assault Rockets",
		"type": "Rocket",
		"range": 4,
		"arc": "FF",
		"ammo": 4,
		"damage": 0,
		"fired": false
	}]
	
	var station = ShipClass.new()
	station.name = "Station"
	station.side_id = 1
	station.grid_position = Vector3i(0, -3, 3) # Directly in front (FF arc)
	
	gm.ships = [fighter, station]
	gm.firing_side_id = 2
	gm.current_side_id = 2
	
	# AI setup
	var ComputerOpponent = load("res://Scripts/ComputerOpponent.gd")
	var ai = ComputerOpponent.new()
	ai.game_manager = gm
	ai.side_id = 2
	ai.setup_faction_details()
	
	print("Valid targets from GameManager:")
	var valid = gm._get_valid_targets_for_weapon(fighter, fighter.weapons[0])
	print(valid.size())
	
	print("Planning combat...")
	var attacks = ai._plan_combat()
	print("Planned attacks:", attacks)
	
	quit()
