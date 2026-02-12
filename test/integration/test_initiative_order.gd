extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var HexGridScript = preload("res://Scripts/HexGrid.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func after_each():
	_gm.free()

func test_initiative_order_p2_first():
	# Scenario: P2 (UPF) wins initiative and goes first.
	# Expectation: After P2 moves all ships, it should switch to P1 (Sathar).
	# Bug Hypothesis: It skips P1 and goes to Combat or P2 again.
	# Setup Ships
	var s1 = ShipScript.new()
	s1.name = "SatharShip"
	s1.player_id = 1
	s1.adf = 2
	s1.mr = 2
	s1.hp = 100
	s1.grid_position = Vector3i(0, 0, 0)
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "UPFShip"
	s2.player_id = 2
	s2.adf = 2
	s2.mr = 2
	s2.hp = 100
	s2.grid_position = Vector3i(10, -10, 0)
	_gm.ships.append(s2)
	
	# Force Start with P2
	_gm.current_player_id = 2
	_gm.current_phase = _gm.Phase.MOVEMENT
	_gm.start_movement_phase()
	
	# Verify P2 is active
	assert_eq(_gm.current_player_id, 2, "P2 should be active first")
	assert_eq(_gm.selected_ship, s2, "P2 ship should be selected")
	
	# Execute P2 Move
	# Simulate move by just setting has_moved = true and calling end_turn
	# (We don't need full path plotting for this test, just state transition)
	s2.has_moved = true
	_gm.end_turn()
	
	# Expectation: Switch to P1
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should still be in Movement Phase")
	assert_eq(_gm.current_player_id, 1, "Should switch to P1 after P2 is done")
	assert_eq(_gm.selected_ship, s1, "P1 ship should be selected")
	
	# Execute P1 Move
	s1.has_moved = true
	_gm.end_turn()
	
	# Expectation: Combat Phase
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should switch to Combat after both moved")
