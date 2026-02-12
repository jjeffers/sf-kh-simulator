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

func test_full_turn_loop():
	# Configure
	_gm.turn_order = [1, 2]
	_gm.current_turn_order_index = 0
	
	# Setup Ships
	var s1 = ShipScript.new()
	s1.name = "P1_Ship"
	s1.player_id = 1
	s1.grid_position = Vector3i(0, 0, 0)
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "P2_Ship"
	s2.player_id = 2
	s2.grid_position = Vector3i(10, -10, 0)
	_gm.ships.append(s2)
	
	# Start P1 Move
	_gm.current_player_id = 1
	_gm.start_movement_phase()
	assert_eq(_gm.current_player_id, 1, "P1 should start")
	
	# P1 Move Done -> P2 Move
	s1.has_moved = true
	_gm.end_turn()
	assert_eq(_gm.current_player_id, 2, "Should switch to P2 Move")
	
	# P2 Move Done -> Combat (Passive for P2)
	s2.has_moved = true
	_gm.end_turn()
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should be Combat Phase")
	
	# Simulate Combat Resolution End (P2 Passive)
	_gm.combat_subphase = 0 # Initial state inside combat?
	# Wait, start_combat_passive sets subphase?
	# Let's simulate calling end_turn_cycle manually, as combat resolution is complex to mock fully.
	# The bug is in end_turn_cycle logic specifically.
	
	# Assert BEFORE end_turn_cycle
	assert_eq(_gm.current_player_id, 2, "P2 should be active before cycle end")
	
	# Call end_turn_cycle
	# Expectation: Reset to P1
	_gm.end_turn_cycle()
	
	# Verification
	assert_eq(_gm.current_turn_order_index, 0, "Turn Index should reset to 0")
	assert_eq(_gm.current_player_id, 1, "Should restart with P1")
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should be Movement Phase")
