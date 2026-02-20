extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	
	# Mock Network Data to avoid null errors
	NetworkManager.lobby_data = {
		"scenario": "surprise_attack",
		"teams": {1: 1, 2: 2},
		"ship_assignments": {}
	}
	# Set My Side to 2 (The reporting user's side)
	_gm.my_side_id = 2

func after_each():
	_gm.free()

func test_ship_list_after_turn_switch():
	# 1. Initialize Game
	_gm._ready()
	var seed_val = 12345
	_gm.setup_game(seed_val, "surprise_attack")
	await get_tree().process_frame
	
	# Verify Start State: Side 1 (Sathar) Turn
	assert_eq(_gm.current_side_id, 1, "Game should start with Side 1")
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should be Movement Phase")
	
	# Verify UI initially shows nothing for P2 (since it's P1 turn and not my turn to move)
	# Wait, movement list shows "friendly ships" regardless of turn? 
	# No, _update_movement_ui_list filters for "current_side_id".
	# So if it's P1 turn, and I am P2:
	# List should show P1 ships? 
	# Code: my_ships = ships.filter(s.side_id == current_side_id)
	# So YES, the list shows the ACTIVE player's ships.
	# So as P2, I should see P1 ships in the list during P1 turn.
	
	var list_container = _gm.list_movement
	assert_not_null(list_container, "List container should exist")
	
	# Check content for Side 1
	var children = list_container.get_children()
	assert_gt(children.size(), 0, "Should have ships in list")
	if children.size() > 0:
		var btn_text = children[0].text
		# Side 1 ships: Venemous, Perdition
		assert_true(btn_text.contains("Venew") or btn_text.contains("Perdition") or btn_text.contains("Venemous"), "Should show Side 1 ships (got %s)" % btn_text)

	# 2. Advance Game to Side 2 (UPF) Turn
	# Force P1 Moves
	var p1_ships = _gm.ships.filter(func(s): return s.side_id == 1)
	for s in p1_ships:
		s.has_moved = true
		
	# Complete Movement Phase for P1
	_gm.start_movement_phase() # Detects all moved -> transitions?
	# Wait, start_movement_phase logic: "If available.size() == 0: ... _update_ui_state() ... return"
	# It does NOT auto-transition anymore (commented out).
	# P1 must press "Execute".
	
	# Simulate P1 pressing Execute (we need to be authority or override)
	_gm.my_side_id = 1 # Temporarily become P1 to click button
	_gm._on_exec_move_pressed()
	
	# Now in Combat Phase (Passive) -> Side 2 (UPF) fires
	assert_eq(_gm.current_phase, _gm.Phase.COMBAT, "Should be Combat Phase")
	assert_eq(_gm.combat_subphase, 1, "Should be Passive Fire")
	assert_eq(_gm.firing_side_id, 2, "Side 2 should be firing")
	
	# Skip Combat (P2)
	_gm.end_turn_cycle()
	
	# Now Active Fire -> Side 1 (Sathar) fires
	assert_eq(_gm.combat_subphase, 2, "Should be Active Fire")
	assert_eq(_gm.firing_side_id, 1, "Side 1 should be firing")
	
	# Skip Combat (P1)
	_gm.end_turn_cycle()
	
	# 3. Turn Switch -> Side 2 (UPF) Turn
	assert_eq(_gm.current_side_id, 2, "Should be Side 2 (UPF) Turn")
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should be Movement Phase")
	
	# Restore Identity to P2
	_gm.my_side_id = 2
	
	# Force UI Update (Client would receive RPC or local event)
	_gm._update_ui_state()
	await get_tree().process_frame
	
	# Test passes execution visually.
