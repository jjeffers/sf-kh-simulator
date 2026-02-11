extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm._ready()
	
	_gm.my_local_player_id = 1
	_gm.current_player_id = 1
	_gm.ships.clear()
	_gm.planet_hexes.clear()

func after_each():
	_gm.free()

func test_turn_continues_after_casualty():
	# 1. Setup: P1 Attacker, P2 Victim
	var attacker = ShipScript.new()
	attacker.name = "Attacker"
	attacker.player_id = 1
	attacker.grid_position = Vector3i(0, 0, 0)
	_gm.ships.append(attacker)
	_gm.add_child(attacker)
	
	var victim = ShipScript.new()
	victim.name = "Victim"
	victim.player_id = 2
	victim.grid_position = Vector3i(1, -1, 0) # Adjacent
	_gm.ships.append(victim)
	_gm.add_child(victim)
	
	_gm.start_movement_phase()
	_gm.selected_ship = attacker
	
	# 2. Destroy Victim
	# We simulate destruction by calling _on_ship_destroyed directly, 
	# which triggers the "remove from array" logic.
	# Crucially, the "node" is still in memory until end of frame (queue_free).
	_gm._on_ship_destroyed(victim)
	
	# 3. Simulate Interactions that caused crashes
	# A. Cycle Selection (triggeredships.filter)
	# This was crashing at line 981
	_gm._cycle_selection()
	pass_test("Selection cycle survived")
	
	# B. Map Click (triggered _handle_movement_click)
	# This was crashing at line 2276
	_gm._handle_movement_click(Vector3i(0, 0, 0)) # Click on attacker
	pass_test("Map click survived")
	
	# C. Combat Click (triggered _handle_combat_click)
	# Switch to combat phase manually to test this
	_gm.current_phase = _gm.Phase.COMBAT
	_gm.combat_subphase = 1 # Active Player fires
	_gm.firing_player_id = 1
	
	# This was crashing at line 380
	_gm._handle_combat_click(Vector3i(1, -1, 0)) # Click on dead victim's hex
	pass_test("Combat click survived")
	
	# D. Commit Move (triggered execute_commit_move name check)
	# Logic at 1683
	# We need to call execute_commit_move with the dead ship's name
	_gm.execute_commit_move("Victim", [], 0, 0, false)
	pass_test("Move commit on dead ship survived")
	
	assert_eq(_gm.ships.size(), 1, "Victim should be removed from ships array")
