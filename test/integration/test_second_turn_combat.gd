extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func after_each():
	_gm.free()

func test_second_turn_combat_skip():
	# Configure
	_gm.turn_order = [1, 2]
	_gm.current_turn_order_index = 0
	
	# Setup Ships - Make sure they are IN RANGE
	var s1 = ShipScript.new()
	s1.name = "P1_Ship"
	s1.player_id = 1
	s1.grid_position = Vector3i(0, 0, 0)
	s1.weapons = [ {"name": "Laser", "type": "Laser", "range": 5, "arc": "360", "ammo": 10, "damage_dice": "1d10", "damage_bonus": 0}]
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "P2_Ship"
	s2.player_id = 2
	s2.grid_position = Vector3i(2, 0, 0) # Distance 2, in range
	s2.weapons = [ {"name": "Laser", "type": "Laser", "range": 5, "arc": "360", "ammo": 10, "damage_dice": "1d10", "damage_bonus": 0}]
	_gm.ships.append(s2)
	
	# --- TURN 1 ---
	# P1 Move
	_gm.current_player_id = 1
	_gm.start_movement_phase()
	s1.has_moved = true
	_gm.end_turn()
	
	# P2 Move
	s2.has_moved = true
	_gm.end_turn()
	print("DEBUG: End of Turn 1. Phase: ", _gm.current_phase)
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Turn 1: Combat Phase Started")
	
	# Skip combat for T1 (Simulate no attacks or just finishing)
	# Force end of combat cycle to start Turn 2
	print("DEBUG: Calling end_turn_cycle")
	_gm.end_turn_cycle()
	print("DEBUG: Cycle Ended. Current Phase: ", _gm.current_phase)
	
	# --- TURN 2 ---
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Turn 2: Movement Phase Started")
	assert_eq(_gm.current_player_id, 1, "Turn 2: P1 Starts")
	
	# P1 Move
	s1.has_moved = true
	_gm.end_turn()
	
	# P2 Move
	assert_eq(_gm.current_player_id, 2, "Turn 2: P2 Moves")
	s2.has_moved = true
	_gm.end_turn()
	
	# --- EXPECTATION ---
	# Should be in Combat Phase
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Turn 2: Should enter Combat Phase")
	
	# Should be Passive Phase (P1 firing at P2, since P2 moved last)
	# Wait, logic: start_combat_passive sets firing_player_id = 3 - current_player_id (which is 2)
	# So firing_player_id should be 1.
	assert_eq(_gm.combat_subphase, 1, "Turn 2: Passive Combat Subphase")
	assert_eq(_gm.firing_player_id, 1, "Turn 2: P1 (Passive) should be firing")
	
	# Check if VALID TARGETS exist (GameManager logic check)
	# If this fails, then _check_for_valid_combat_targets() is returning false
	var valid = _gm._check_for_valid_combat_targets()
	assert_true(valid, "Turn 2: Should have valid targets")
    
	# Write result to file
	var f = FileAccess.open("user://test_result.txt", FileAccess.WRITE)
	if f:
		if valid and _gm.current_phase == _gm.Phase.COMBAT:
			f.store_string("PASS: Turn 2 Combat Started with Valid Targets")
		else:
			f.store_string("FAIL: Turn 2 Combat Failed. Phase=%s, Valid=%s" % [_gm.current_phase, valid])
		f.close()
