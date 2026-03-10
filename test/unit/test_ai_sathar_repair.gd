extends GutTest

func test_repair_logic_execution():
	var gm = preload("res://Scripts/GameManager.gd").new()
	add_child_autoqfree(gm)
	
	gm.current_phase = gm.Phase.REPAIR
	gm.repair_subphase = 1
	gm.test_force_online = true # bypass wait timers
	
	# Create Side 1 ship
	var s1 = preload("res://Scripts/Ship.gd").new()
	s1.name = "Ship1"
	s1.side_id = 1
	s1.max_hull = 10
	s1.hull = 5 # damage
	s1.max_dcr = 100
	s1.current_dcr = 100
	gm.ships.append(s1)
	
	# Create Side 2 ship
	var s2 = preload("res://Scripts/Ship.gd").new()
	s2.name = "Ship2"
	s2.side_id = 2
	s2.max_hull = 10
	s2.hull = 5 # damage
	s2.max_dcr = 100
	s2.current_dcr = 100
	gm.ships.append(s2)
	
	# Simulate AI AutoRepair Processor output for Side 1
	var alloc1 = { "Ship1": { "hull": 90 } }
	gm.rpc_submit_repair_allocations(1, alloc1)
	
	assert_eq(gm.repair_subphase, 2, "Phase should advance to Side 2")
	
	# Simulate AI AutoRepair Processor output for Side 2
	var alloc2 = { "Ship2": { "hull": 90 } }
	gm.rpc_submit_repair_allocations(2, alloc2)
	
	# Verify successful cleanup and transition
	assert_eq(gm.repair_subphase, 3, "Phase should advance to final cleanup phase")
	assert_eq(gm.active_repair_animations, 0, "No pending animations should exist")
	assert_eq(gm.has_submitted_final_repairs, true, "Final repairs flag should be set")
	
	# The turn count increments (starts at 1 natively, so it should be 2)
	assert_eq(gm.turn_count, 2, "Turn count should increment to 2")
	assert_eq(gm.current_phase, gm.Phase.MOVEMENT, "Phase should loop back to movement")
