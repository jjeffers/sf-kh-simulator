extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")

var _gm = null
var _ship = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	
	_ship = ShipScript.new()
	_ship.name = "TestShip"
	_ship.side_id = 1
	_ship.adf = 2
	_ship.mr = 2
	_ship.hull = 10
	_ship.facing = 0
	
	var s_arr: Array[Ship] = [_ship]
	_gm.ships = s_arr
	_gm.add_child(_ship)

	_gm.current_side_id = 1
	_gm.selected_ship = _ship
	var p: Array[Vector3i] = []
	_gm.current_path = p
	_gm.ghost_ship = _ship.duplicate() # Pseudo-ghost
	_gm.add_child(_gm.ghost_ship)

func after_each():
	_gm.free()
	_gm = null
	_ship = null

func test_cannot_turn_at_start_if_speed_gt_0():
	# Setup: Speed 5. Path 0. MR 2.
	_gm.start_speed = 5
	_gm.turns_remaining = 2
	var p: Array[Vector3i] = []
	_gm.current_path = p
	_gm.can_turn_this_step = false # Revert to False
	
	# Try to turn
	_gm._on_turn(1)
	
	# Expectation: Should NOT change facing
	assert_eq(_gm.ghost_ship.facing, _ship.facing, "Should NOT turn at start if speed > 0")
	assert_eq(_gm.turns_remaining, 2, "Should NOT consume MR")

func test_can_turn_freely_at_start_if_speed_0():
	# Setup: Speed 0. Path 0.
	_gm.start_speed = 0
	var p: Array[Vector3i] = []
	_gm.current_path = p
	_gm.turns_remaining = 2
	
	# Current facing 0
	_gm.ghost_ship.facing = 0
	
	# Try to turn
	_gm._on_turn(1)
	
	# Expectation: Should change facing
	assert_eq(_gm.ghost_ship.facing, 1, "Should turn if speed is 0")
	assert_eq(_gm.turns_remaining, 2, "Speed 0 turn should be free (MR not consumed)")
	
	# Turn again
	_gm._on_turn(1)
	assert_eq(_gm.ghost_ship.facing, 2, "Should turn again")
	assert_eq(_gm.turns_remaining, 2, "Still free")

func test_undo_turn_logic():
	# Simulate entered a hex
	_gm.start_speed = 5
	_gm.turns_remaining = 2
	var p_start: Array[Vector3i] = [Vector3i(0, 0, 0)]
	_gm.current_path = p_start
	_gm.can_turn_this_step = true
	_gm.turn_taken_this_step = 0
	var initial_facing = _gm.ghost_ship.facing
	
	# 1. Turn Right (+1)
	_gm._on_turn(1)
	assert_eq(_gm.ghost_ship.facing, (initial_facing + 1) % 6, "Turn Right")
	assert_eq(_gm.turns_remaining, 1, "Consumed MR")
	assert_eq(_gm.turn_taken_this_step, 1, "Recorded Turn Right")
	
	# 2. Try Turn Right Again (+1) -> Should adhere to Max 1 Turn per hex
	_gm._on_turn(1)
	assert_eq(_gm.ghost_ship.facing, (initial_facing + 1) % 6, "Should Not Turn Again")
	assert_eq(_gm.turns_remaining, 1, "Should Not Consume MR")
	
	# 3. Undo with Left (-1)
	_gm._on_turn(-1)
	assert_eq(_gm.ghost_ship.facing, initial_facing, "Turn Back (Undo)")
	assert_eq(_gm.turns_remaining, 2, "Refunded MR")
	assert_eq(_gm.turn_taken_this_step, 0, "Reset Turn Taken")
	assert_true(_gm.can_turn_this_step, "Reset Can Turn")
	
	# 4. Now Turn Left (-1)
	_gm._on_turn(-1)
	var expected_left = (initial_facing - 1)
	if expected_left < 0: expected_left += 6
	assert_eq(_gm.ghost_ship.facing, expected_left, "Turn Left")
	assert_eq(_gm.turns_remaining, 1, "Consumed MR")
	assert_eq(_gm.turn_taken_this_step, -1, "Recorded Turn Left")
