extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var ScenarioManagerScript = preload("res://Scripts/ScenarioManager.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	# Mock Network Data for Surprise Attack
	NetworkManager.lobby_data["scenario"] = "surprise_attack"
	NetworkManager.lobby_data["teams"] = {1: 1, 2: 2}

func after_each():
	_gm.free()
	
func test_turn_order_surprise_attack():
	# 1. Load Scenario
	_gm._ready()
	# Wait for setup
	await get_tree().process_frame
	
	# Verify P1 starts
	assert_eq(_gm.current_player_id, 1, "Player 1 (Sathar) should start")
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should be P1 Movement Phase")
	
	# Verify P1 Ships valid?
	var p1_ships = _gm.ships.filter(func(s): return s.player_id == 1 and not s.has_moved)
	assert_gt(p1_ships.size(), 0, "P1 should have ships to move")
	
	# 2. End P1 Turn (Force it)
	# We simulate all P1 ships moving.
	for s in p1_ships:
		s.has_moved = true
		
	# Trigger phase check (usually done in execute_commit_move)
	# We need to find the function that checks "Are we done?"
	# likely _check_movement_phase_end() or similar, called by execute_commit_move.
	# Let's call start_movement_phase again? No, that resets.
	
	# If we look at GameManager logic, execute_commit_move calls _check_movement_phase_end?
	# Since I can't see private functions easily, I'll simulate the public loop.
	
	# But wait, if P1 is done, logic should switch to P2.
	# Let's try calling start_movement_phase() while current_player_id is 1 
	# BUT all P1 ships have moved.
	
	_gm.start_movement_phase()
	
	# Logic:
	# start_movement_phase checks available ships for current_player_id.
	# If 0, it calls start_combat_passive()? 
	# Wait. If P1 is done, who switches it to P2?
	
	# Ah, if P1 moves last ship, it should trigger "End P1 Turn".
	# If I set has_moved=true and call start_movement_phase, it will see 0 ships and go to Combat?
	# That would mean P2 is SKIPPED if P1 is done?
	
	# Valid behavior:
	# P1 moves ship -> check if P1 done -> if P1 done -> Switch to P2 -> P2 moves.
	# If P2 done -> Switch to Combat.
	
	# 3. Assert P2 Turn
	assert_eq(_gm.current_player_id, 2, "Should switch to P2 (UPF)")
	assert_eq(_gm.current_phase, _gm.Phase.MOVEMENT, "Should stay in Movement Phase for P2")
	
	# Verify P2 Ship Selection
	assert_not_null(_gm.selected_ship, "P2 should have a selected ship")
	assert_eq(_gm.selected_ship.player_id, 2, "Selected ship should belong to P2")
