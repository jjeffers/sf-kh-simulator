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

func test_reactive_fire_pass_through_arc():
	var defender = ship_script.new()
	defender.name = "Defender"
	defender.configure_destroyer()
	# Place at center, facing East (Direction 0)
	defender.grid_position = Vector3i(0, 0, 0)
	defender.facing = 0
	defender.side_id = 1
	game_manager.ships.append(defender)
	
	# Give short torpedo (range 3)
	defender.weapons = [{"name": "Short Torpedo", "type": "Torpedo", "range": 3, "arc": "FF", "ammo": 2}]
	
	var attacker = ship_script.new()
	attacker.name = "Attacker"
	attacker.configure_frigate()
	
	# The FF Arc for direction 0 covers lines expanding eastward. 
	# A path starting out of arc (e.g. North-East, q=1,r=-2,s=1 distance 2), passing through the arc (e.g. East q=2,r=-1,s=-1), and ending South-East out of arc.
	# We place the attacker at the final out-of-arc coordinate.
	attacker.grid_position = Vector3i(1, 1, -2) # Distance 2, direction South-East (Facing 1 is roughly out of forward arc)
	
	# Create a path that explicitly crosses the dead-center of the forward arc
	attacker.previous_path.assign([
		Vector3i(1, -2, 1), # Start (North-East, outside arc)
		Vector3i(2, -1, -1), # Middle (Directly East, inside arc at range 2)
		Vector3i(1, 1, -2)   # End (South-East, outside arc)
	])
	attacker.side_id = 2
	game_manager.ships.append(attacker)
	
	# Activate Defensive Fire
	game_manager.current_phase = game_manager.Phase.COMBAT
	game_manager.combat_subphase = 1
	game_manager.current_side_id = 2
	game_manager.firing_side_id = 1
	
	# 1. Test backend logic
	var valid_targets = game_manager._get_valid_targets_for_weapon(defender, defender.weapons[0])
	assert_gt(valid_targets.size(), 0, "Backend should detect Attacker passing through the FF arc")
	
	# 2. Test UI Click Handler Logic (Simulation of _handle_combat_click)
	var can_hit_ui = false
	var target_hexes = [attacker.grid_position]
	target_hexes.append_array(attacker.previous_path)
	
	var w_range = defender.weapons[0]["range"]
	var valid_arc_hexes = game_manager._get_ff_arc_hexes(defender, w_range)
	
	for hex in target_hexes:
		var d = HexGrid.hex_distance(defender.grid_position, hex)
		if d <= w_range:
			if hex in valid_arc_hexes:
				can_hit_ui = true
				break
				
	assert_true(can_hit_ui, "UI click handler simulation should detect the valid FF arc hex within the previous path")
