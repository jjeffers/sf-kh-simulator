extends SceneTree

func _init():
	print("Starting Turn Sequence Refactor Test...")
	
	var root = get_root()
	
	# 1. Setup GameManager
	var gm = GameManager.new()
	gm.name = "GameManager"
	if root:
		root.add_child(gm)
	
	# 2. Setup Ships
	var s1 = Ship.new()
	s1.side_id = 1
	s1.name = "Ship_S1"
	gm.ships.append(s1)
	gm.add_child(s1)
	
	var s2 = Ship.new()
	s2.side_id = 2
	s2.name = "Ship_S2"
	gm.ships.append(s2)
	gm.add_child(s2)
	
	# 3. Start Turn Cycle
	print("Calling start_turn_cycle()...")
	gm.start_turn_cycle()
	
	# EXPECT: Side 1, Phase Movement
	_assert(gm.current_side_id == 1, "Initial Side should be 1. Got: %d" % gm.current_side_id)
	# Phase is enum, verify value (1=MOVEMENT)
	_assert(gm.current_phase == 1, "Initial Phase should be MOVEMENT (1). Got: %d" % gm.current_phase)
	print("State 1 [S1 Move]: OK")
	
	# 4. Simulate Movement Done
	s1.has_moved = true
	# Re-call start_movement_phase to trigger the "available.size() == 0" check
	gm.start_movement_phase()
	
	# EXPECT: Phase Combat (2), Subphase 1 (Passive), Firing Side 2 (3 - 1 = 2)
	_assert(gm.current_phase == 2, "Phase should be COMBAT (2). Got: %d" % gm.current_phase)
	_assert(gm.combat_subphase == 1, "Subphase should be 1 (Passive). Got: %d" % gm.combat_subphase)
	_assert(gm.firing_side_id == 2, "Firing Side should be 2 (Passive). Got: %d" % gm.firing_side_id)
	print("State 2 [S2 Passive Fire]: OK")
	
	# 5. Simulate Passive Fire Done
	# In real game, UI triggers this. We verify start_combat_active logic.
	# We manually set subphase to simulate "passive done" flow if needed, but start_combat_active forces it.
	gm.start_combat_active()
	
	# EXPECT: Phase Combat, Subphase 2 (Active), Firing Side 1
	_assert(gm.current_phase == 2, "Phase should be COMBAT. Got: %d" % gm.current_phase)
	_assert(gm.combat_subphase == 2, "Subphase should be 2 (Active). Got: %d" % gm.combat_subphase)
	_assert(gm.firing_side_id == 1, "Firing Side should be 1 (Active). Got: %d" % gm.firing_side_id)
	print("State 3 [S1 Active Fire]: OK")

	# 6. Simulate Active Fire Done -> End Turn Sequence
	# This basically ends S1's turn and should start S2's turn
	gm.end_turn_cycle()
	
	# EXPECT: Side 2, Phase Movement
	_assert(gm.current_side_id == 2, "Side should switch to 2. Got: %d" % gm.current_side_id)
	_assert(gm.current_phase == 1, "Phase should be MOVEMENT for Side 2. Got: %d" % gm.current_phase)
	print("State 4 [S2 Move]: OK")

	print("--- TEST PASSED ---")
	_log("TEST PASSED")
	
	# Cleanup
	gm.queue_free()
	quit()

func _assert(condition, msg):
	if not condition:
		var err = "FAIL: " + msg
		print(err)
		_log(err)
		quit()

func _log(msg):
	var path = "c:/Users/James Jeffers/.gemini/antigravity/scratch/hex_space_combat/test/refactor_results.txt"
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(path, FileAccess.WRITE)
	file.seek_end()
	file.store_line(msg)
	file.close()
