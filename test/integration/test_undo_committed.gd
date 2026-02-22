extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var HexGridScript = preload("res://Scripts/HexGrid.gd")

var _gm = null
var _ship = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm._ready()
	_gm.ships.clear()

	_ship = ShipScript.new()
	_ship.name = "TestShip"
	_ship.grid_position = Vector3i(0, 0, 0)
	_ship.side_id = 1
	_ship.adf = 2
	_ship.speed = 2
	_ship.facing = 0
	if _ship.get_parent() == null:
		_game_manager.add_child(_ship)
	_gm.ships.append(_ship)
	_gm.add_child(_ship)
	
	_gm.current_side_id = 1
	_gm.my_side_id = 1
	_gm.current_phase = _gm.Phase.MOVEMENT
	_gm.start_movement_phase()
	_gm.selected_ship = _ship
	_gm._reset_plotting_state()
	_gm._spawn_ghost()

func after_each():
	_gm.free()

func test_undo_committed_move_restores_state():
	# 1. State Before Move
	assert_eq(_ship.grid_position, Vector3i(0, 0, 0))
	assert_eq(_ship.has_moved, false)
	
	# 2. Plan and Commit Move
	var target = Vector3i(1, 0, -1)
	_gm._handle_movement_click(target)
	_gm._on_commit_move()
	_gm.execute_all_movement() # Execute to set has_moved=true
	
	assert_true(_ship.has_moved, "Ship should be marked as moved")
	assert_eq(_ship.grid_position, target, "Ship should be at target")
	
	# 3. Reselect Ship (Simulate clicking already moved ship)
	_gm.selected_ship = _ship
	_gm._update_ui_state()
	
	# Verify Undo Button Visibility (Expect FAIL before fix)
	# Should be visible if has_moved is true and it's my ship/turn
	# assert_true(_gm.btn_undo.visible, "Undo button should be visible")

	# 4. Perform Undo
	_gm._on_undo()
	
	# Verify Restoration (Expect FAIL before fix)
	assert_false(_ship.has_moved, "Ship should not be marked as moved")
	assert_eq(_ship.grid_position, Vector3i(0, 0, 0), "Ship returned to start")
	assert_eq(_ship.facing, 0, "Facing restored")
	assert_eq(_ship.speed, 2, "Speed restored")
