extends GutTest

var _gm = null
var ShipScript = null

func before_all():
	var GM_Script = load("res://Scripts/GameManager.gd")
	_gm = GM_Script.new()
	ShipScript = load("res://Scripts/Ship.gd")
	add_child(_gm)

func after_all():
	_gm.queue_free()

func before_each():
	_gm.ships.clear()
	_gm.current_phase = _gm.Phase.MOVEMENT
	_gm.my_side_id = 1
	_gm.current_side_id = 1

func test_zero_speed_with_negative_adf_click():
	# Setup Ship with Speed 0, ADF 1.
	var ship = ShipScript.new()
	ship.name = "ADFShip"
	ship.side_id = 1
	ship.grid_position = Vector3i(0, 0, 0)
	ship.speed = 0
	ship.adf = 1
	# Apply an ADF modifier that strips all ADF
	ship.current_adf_modifier = 2 
	
	if ship.get_parent() == null:
		_game_manager.add_child(ship)
	_gm.ships.append(ship)
	_gm.add_child(ship)
	
	# Selecting the ship initializes its plotting state
	_gm.selected_ship = ship
	_gm._reset_plotting_state() # Sets start_speed = 0
	
	# Capture the previous speed to verify it didn't change/error out
	var initial_speed = ship.speed
	
	# Instead of emulating a mouse click which depends on SceneTree Ghost Ships and UI labels,
	# we verify that a 0-distance move (valid when max(0, start_speed - eff_adf) == 0)
	# is correctly accepted by the underlying execute_commit_move authority function.
	
	_gm.execute_commit_move(ship.name, [], ship.facing, 0, false)
	
	# If the bug STILL existed where min_speed incorrectly clamped to positive numbers 
	# due to hardcoded raw ADF, the execute function checks:
	# var is_valid = (steps >= min_speed and steps <= max_speed)
	# And rejects it.
	
	# With the fix, get_effective_adf() clamps to 0, so min_speed = 0.
	# The stop speed equals the minimum, so the click is accepted.
	
	# If the move was accepted and processed as a Full Stop:
	assert_true(ship.has_orders, "The ship with 0 effective ADF should be allowed to process orders for a 0-distance stop move")
	_gm._apply_movement_plan(ship)
	
	assert_true(ship.has_moved, "The ship processed the move correctly")
	assert_eq(ship.speed, 0, "The ship speed should be set to 0 after confirming the stationary move")
