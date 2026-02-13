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

func test_full_turn_loop():
	# Configure: Side 1 starts
	var order: Array[int] = [1, 2]
	_gm.turn_order = order
	_gm.current_turn_order_index = 0
	
	# Setup Ships
	var s1 = ShipScript.new()
	s1.name = "P1_Ship"
	s1.side_id = 1
	s1.grid_position = Vector3i(0, 0, 0)
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "P2_Ship"
	s2.side_id = 2
	s2.grid_position = Vector3i(10, -10, 0)
	_gm.ships.append(s2)
	
	# Start P1 Move
	_gm.current_side_id = 1
	_gm.start_movement_phase()
	assert_eq(_gm.current_side_id, 1, "P1 should start")
	
	# P1 Move Done -> Combat (Passive: Opponent S2 fires)
	s1.has_moved = true
	_gm.end_turn()
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should be Combat Phase")
	assert_eq(_gm.combat_subphase, 1, "Passive Combat")
	assert_eq(_gm.firing_side_id, 2, "Passive: Side 2 should fire")
	
	# P2 Passive Done -> Active Combat (S1 fires)
	_gm.end_turn_cycle()
	assert_eq(_gm.combat_subphase, 2, "Active Combat")
	assert_eq(_gm.firing_side_id, 1, "Active: Side 1 should fire")
	
	# P1 Active Done -> P2 Movement
	_gm.end_turn_cycle()
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should switch to Movement")
	assert_eq(_gm.current_side_id, 2, "Should be Side 2 turn")
	
	# P2 Move Done -> Combat (Passive: Opponent S1 fires)
	s2.has_moved = true
	_gm.end_turn()
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should be Combat Phase")
	assert_eq(_gm.combat_subphase, 1, "Passive Combat")
	assert_eq(_gm.firing_side_id, 1, "Passive: Side 1 should fire")
	
	# P1 Passive Done -> Active Combat (S2 fires)
	_gm.end_turn_cycle()
	assert_eq(_gm.combat_subphase, 2, "Active Combat")
	assert_eq(_gm.firing_side_id, 2, "Active: Side 2 should fire")
	
	# P2 Active Done -> Round End -> New Round (S1 Move)
	_gm.end_turn_cycle()
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should be Movement Phase")
	assert_eq(_gm.current_side_id, 1, "Should restart with P1")
	assert_false(s1.has_moved, "S1 moved status reset")
	assert_false(s2.has_moved, "S2 moved status reset")
