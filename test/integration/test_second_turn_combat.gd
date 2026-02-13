extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")

var _gm = null

func before_each():
	NetworkManager.lobby_data = {"teams": {}, "ship_assignments": {}}
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func after_each():
	_gm.free()

func test_second_turn_combat_skip():
	# Configure
	_gm.turn_order.assign([1, 2])
	_gm.current_turn_order_index = 0
	
	# Setup Ships - Make sure they are IN RANGE
	var s1 = ShipScript.new()
	s1.name = "P1_Ship"
	s1.side_id = 1
	s1.grid_position = Vector3i(0, 0, 0)
	s1.weapons = [ {"name": "Laser", "type": "Laser", "range": 5, "arc": "360", "ammo": 10, "damage_dice": "1d10", "damage_bonus": 0}]
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "P2_Ship"
	s2.side_id = 2
	s2.grid_position = Vector3i(2, 0, 0) # Distance 2, in range
	s2.weapons = [ {"name": "Laser", "type": "Laser", "range": 5, "arc": "360", "ammo": 10, "damage_dice": "1d10", "damage_bonus": 0}]
	_gm.ships.append(s2)
	
	# --- TURN 1 Logic ---
	
	# 1. P1 Movement
	_gm.current_side_id = 1
	_gm.start_movement_phase()
	s1.has_moved = true
	_gm.end_turn() # Triggers start_combat_passive
	
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "T1: P1 Combat Started")
	assert_eq(_gm.combat_subphase, 1, "T1: P1 Passive Combat")
	
	# 2. P1 Passive Combat -> Active
	_gm.end_turn_cycle()
	assert_eq(_gm.combat_subphase, 2, "T1: P1 Active Combat")
	
	# 3. P1 Active Combat -> P2 Turn
	_gm.end_turn_cycle()
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "T1: P2 Movement Started")
	assert_eq(_gm.current_side_id, 2, "T1: Side Should be 2")
	
	# 4. P2 Movement
	s2.has_moved = true
	_gm.end_turn() # Triggers P2 Passive
	
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "T1: P2 Combat Started")
	assert_eq(_gm.combat_subphase, 1, "T1: P2 Passive Combat")
	
	# 5. P2 Passive -> Active
	_gm.end_turn_cycle()
	assert_eq(_gm.combat_subphase, 2, "T1: P2 Active Combat")
	
	# 6. P2 Active -> Round End -> Turn 2 P1 Movement
	_gm.end_turn_cycle()
	
	# --- TURN 2 Logic ---
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Turn 2: Movement Phase Started")
	assert_eq(_gm.current_side_id, 1, "Turn 2: P1 Starts")
	
	# Verify Reset State
	assert_false(s1.has_moved, "Turn 2: P1 ship has_moved should be reset")
	assert_false(s2.has_moved, "Turn 2: P2 ship has_moved should be reset")

	# P1 Move
	s1.has_moved = true
	_gm.end_turn()
	
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Turn 2: Should enter Combat Phase")
	
	# Turn 2, P1 moved. Opponent (P2) fires Passive.
	assert_eq(_gm.combat_subphase, 1, "Turn 2: Passive Combat Subphase")
	assert_eq(_gm.firing_side_id, 2, "Turn 2: P2 (Passive) should be firing")
	
	# Check if VALID TARGETS exist (GameManager logic check)
	# P2 firing at P1. Distance 2. Range 5. Should be valid.
	var valid = _gm._check_for_valid_combat_targets()
	assert_true(valid, "Turn 2: Should have valid targets")
