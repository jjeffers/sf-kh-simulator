extends GutTest

var game_scene = preload("res://Main.tscn")
var game_manager: Node2D

func before_each():
	game_manager = game_scene.instantiate()
	get_tree().root.add_child(game_manager)
	
	GameManager.reset_state()
	GameManager.test_force_online = false 
	GameManager.my_side_id = 0
	
	NetworkManager.game_setup_data = {
		"scenario": "simple_test",
		"host_side": 0 
	}
	
	GameManager.start_game()
	
	await get_tree().process_frame
	await get_tree().process_frame

func after_each():
	if is_instance_valid(game_manager):
		game_manager.queue_free()
	GameManager.reset_state()
	await get_tree().process_frame

func test_hull_integrity_risk_calculation():
	var ship = game_manager._find_ship_by_name("Test Ship 1")
	assert_not_null(ship, "Test ship should exist")
	
	# Force base values
	ship.max_hull = 100
	ship.hull = 100
	ship.adf = 2
	ship.mr = 2
	
	# Test 1: No Risk at >50%
	ship.take_hull_damage(20) # 80 / 100
	var risk_safe = ship.get_hull_integrity_risk(1, 1)
	assert_eq(risk_safe, 0, "Risk should be 0 when hull > 50%")
	
	# Test 2: Borderline (Exactly 50%)
	ship.take_hull_damage(30) # 50 / 100
	var risk_border = ship.get_hull_integrity_risk(1, 1)
	assert_eq(risk_border, 0, "Risk should be 0 at exactly 50%")
	
	# Test 3: Active Risk (40 / 100)
	ship.take_hull_damage(10) # 40 / 100
	# Threshold = 50. Base Risk = 50 - 40 = 10. Costs = 2. Risk = 20%
	var risk_active = ship.get_hull_integrity_risk(1, 1)
	assert_eq(risk_active, 20, "Risk should be 20% at 40/100 hull with 2 cost")

func test_mr_used_for_plan_calculation():
	var start_pos = Vector3i(0, 0, 0)
	var path: Array[Vector3i] = [
		Vector3i(1, -1, 0), # Move direction 0 (Facing Right/Up)
		Vector3i(2, -1, -1) # Move direction 0 
	]
	
	# Started facing 0, moved 2 hexes facing 0, ended facing 1 (Right Turn)
	var mr1 = game_manager._calculate_mr_used_for_plan(start_pos, 0, path, 1)
	assert_eq(mr1, 1, "Should cost 1 MR to turn right at the end")
	
	# Complex Path
	# Start 0
	# Hex 1: dir 1
	# Hex 2: dir 0
	# Final Facing: 5
	var path2: Array[Vector3i] = [
		Vector3i(1, 0, -1), # turn 0->1 (cost 1)
		Vector3i(2, -1, -1) # turn 1->0 (cost 1)
	]
	# Final facing 5: turn 0->5 (cost 1)
	var mr2 = game_manager._calculate_mr_used_for_plan(start_pos, 0, path2, 5)
	assert_eq(mr2, 3, "Complex zig-zag and final turn should cost 3 MR")

func test_hull_integrity_execution_destruction():
	var ship = game_manager._find_ship_by_name("Test Ship 1")
	assert_not_null(ship, "Test ship should exist")
	
	# Force into danger zone
	ship.max_hull = 100
	ship.hull = 40
	ship.adf = 4
	ship.mr = 4
	
	# 50 - 40 = 10. We will use ADF 1 + MR 1 = 20% Risk.
	var path: Array[Vector3i] = [Vector3i(1, -1, 0)]
	ship.speed = 0 # Docked/Stopped
	
	# We can't easily force `randi` to roll under 20 in normal code without a seed or mocking, 
	# but we can rely on testing the failure path if we make the risk 100%.
	ship.hull = 1 # Risk: 49 * 2 = 98%. If we do MR 3, it's > 100%.
	
	# Set up a deadly move (ADF 1, MR 2) = 3 cost * 49 = 147% Risk
	var deadly_path: Array[Vector3i] = [Vector3i(1, 0, -1)]
	
	# Mock execution
	game_manager.register_movement_plan(ship.name, deadly_path, 2, 0, false)
	game_manager._apply_movement_plan(ship)
	
	# It should have exploded
	assert_true(ship.is_destroyed, "Ship should have exploded due to structural failure (risk > 100)")
