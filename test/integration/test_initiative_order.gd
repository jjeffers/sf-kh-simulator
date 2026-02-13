extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var HexGridScript = preload("res://Scripts/HexGrid.gd")

var _gm = null

func before_each():
	NetworkManager.lobby_data = {"teams": {}, "ship_assignments": {}}
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func after_each():
	_gm.free()

func test_initiative_order_p2_first():
	# Scenario: P2 (UPF) wins initiative and goes first.
	# Proper Loop: P2 Move -> Combat(P1 Passive) -> Combat(P2 Active) -> P1 Move...
	# Configure Order [2, 1]
	var order: Array[int] = [2, 1]
	_gm.turn_order = order
	_gm.current_turn_order_index = 0
	
	# Setup Ships
	var s1 = ShipScript.new()
	s1.name = "SatharShip"
	s1.side_id = 1
	s1.grid_position = Vector3i(0, 0, 0)
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "UPFShip"
	s2.side_id = 2
	s2.grid_position = Vector3i(10, -10, 0)
	_gm.ships.append(s2)
	
	# Force Start with P2
	_gm.current_side_id = 2
	_gm.current_phase = _gm.Phase.MOVEMENT
	_gm.start_movement_phase()
	
	# Verify P2 is active
	assert_eq(_gm.current_side_id, 2, "P2 should be active first")
	assert_eq(_gm.selected_ship, s2, "P2 ship should be selected")
	
	# Execute P2 Move
	s2.has_moved = true
	_gm.end_turn()
	
	# Expectation: Combat Phase (Passive for P2's opponent -> P1 fires)
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should switch to Combat")
	assert_eq(_gm.combat_subphase, 1, "Passive")
	assert_eq(_gm.firing_side_id, 1, "Side 1 fires now")
	
	# End Passive -> Active (P2 fires)
	_gm.end_turn_cycle()
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Still Combat")
	assert_eq(_gm.combat_subphase, 2, "Active")
	assert_eq(_gm.firing_side_id, 2, "Side 2 fires now")
	
	# End Active -> P1 Turn
	_gm.end_turn_cycle()
	
	# Expectation: Switch to P1 Movement
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should switch to Movement Phase")
	assert_eq(_gm.current_side_id, 1, "Should switch to P1 after P2 cycle is done")
	assert_eq(_gm.selected_ship, s1, "P1 ship should be selected")
