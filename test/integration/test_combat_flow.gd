extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var HexGrid = preload("res://Scripts/HexGrid.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	
	# Mock NetworkManager if needed, but it's Autoloaded so we might use real or override
	# For integration, we assume Single Player or Host logic
	_gm.my_local_player_id = 1 # Act as P1
	_gm.current_player_id = 1
	
	# Clear specific scenario data
	_gm.ships.clear()
	_gm.planet_hexes.clear()
	_gm.current_scenario_rules.clear()

func after_each():
	_gm.free()

func test_turn_cycle_switch():
	# Setup 2 ships
	var s1 = ShipScript.new()
	s1.name = "Ship1"
	s1.player_id = 1
	s1.has_moved = false
	_gm.ships.append(s1)
	
	var s2 = ShipScript.new()
	s2.name = "Ship2"
	s2.player_id = 2
	s2.has_moved = false
	_gm.ships.append(s2)
	autofree(s1)
	autofree(s2)
	
	_gm.current_player_id = 1
	_gm.start_movement_phase()
	
	# P1 Moves
	# Simulate move commit
	_gm.selected_ship = s1
	s1.has_moved = true
	
	# End Turn -> Should check if more ships available for P1
	_gm.end_turn()
	
	# Since no more P1 ships, it should switch phase to Combat Passive?
	# Wait, logic is: Movement Phase P1 -> if done -> Combat Passive (P2 fires)
	
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should switch to Combat Phase after all P1 moved")
	assert_eq(_gm.combat_subphase, 1, "Should be Passive Combat (Subphase 1)")
	assert_eq(_gm.firing_player_id, 2, "Passive Player (P2) should be firing")

func test_ship_destruction_handling():
	# Verify that destroying a ship removes it and doesn't crash turn logic
	var s1 = ShipScript.new()
	s1.name = "Victim"
	s1.player_id = 2
	s1.hull = 5
	_gm.ships.append(s1)
	_gm.add_child(s1) # Needs to be in tree for queue_free/signals?
	
	# Manually trigger destruction logic
	# GameManager._on_ship_destroyed(s1) is likely connected to signal or called directly
	# Let's call it directly to test the response
	
	_gm._on_ship_destroyed(s1)
	
	assert_eq(_gm.ships.size(), 0, "Ship should be removed from list")
	
	# Verify next phase/turn logic doesn't crash
	# If we are in movement and active player lost a ship (maybe self-destruct or boundary?)
	_gm.current_player_id = 2
	_gm.start_movement_phase()
	# Should detect 0 ships and go to Combat
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should transition to Combat if no ships")
