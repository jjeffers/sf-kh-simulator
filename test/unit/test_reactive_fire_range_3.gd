extends GutTest

var game_manager: Node
var ship_script: Script

func before_each():
	ship_script = load("res://Scripts/Ship.gd")
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child(game_manager)
	await get_tree().process_frame

func after_each():
	if is_instance_valid(game_manager):
		game_manager.queue_free()

func test_range_3_reactive_fire():
	# Make a defending UPF ship (Side 1)
	var defender = ship_script.new()
	defender.name = "Defender"
	defender.configure_destroyer() # FF weapons
	defender.grid_position = Vector3i(0, 0, 0) # Center
	defender.facing = 0 # Pointing "East" (Direction 0)
	defender.side_id = 1
	game_manager.ships.append(defender)
	
	# Give it a range 3 weapon explicitly
	defender.weapons = [{"name": "Long Torpedo", "type": "Torpedo", "range": 3, "arc": "FF", "ammo": 2}]
	
	# Make an attacking Sathar ship (Side 2) that moves around it
	var attacker = ship_script.new()
	attacker.name = "Attacker"
	attacker.configure_frigate()
	attacker.grid_position = Vector3i(3, -1, -2) # End position (Distance 3)
	
	# It moved from (3, -3, 0) through (3, -2, -1) to (3, -1, -2)
	attacker.previous_path.assign([Vector3i(3, -3, 0), Vector3i(3, -2, -1), Vector3i(3, -1, -2)])
	attacker.side_id = 2
	game_manager.ships.append(attacker)
	
	# Simulate Defensive Fire Phase (Combat Subphase 1, Side 1 is active)
	game_manager.current_phase = game_manager.Phase.COMBAT
	game_manager.combat_subphase = 1
	game_manager.current_side_id = 2 # Side 2 just moved
	game_manager.firing_side_id = 1  # Side 1 is passively firing
	
	var valid_targets = game_manager._get_valid_targets_for_weapon(defender, defender.weapons[0])
	
	assert_gt(valid_targets.size(), 0, "Defender should be able to reactively fire at Attacker moving through Range 3")
