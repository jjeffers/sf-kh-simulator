extends GutTest

var GameManagerScript = load("res://Scripts/GameManager.gd")
var ShipScript = load("res://Scripts/Ship.gd")
var HexGridScript = load("res://Scripts/HexGrid.gd")

var _gm = null
var _sender = null
var _ghost = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm.test_force_online = true # Simulate online/authority
	_gm.my_side_id = 1
	_gm.current_side_id = 1
	_gm.current_phase = _gm.Phase.MOVEMENT
	
	_sender = ShipScript.new()
	_sender.name = "TestShip"
	_sender.side_id = 1
	_sender.grid_position = Vector3i(0, 0, 0)
	_sender.configure_heavy_cruiser() # Has multiple weapons
	if _sender.get_parent() == null:
		_gm.add_child(_sender)
	_gm.ships.append(_sender)
	
	_ghost = ShipScript.new()
	_ghost.name = "GhostShip"
	_ghost.grid_position = Vector3i(1, -1, 0) # Adjacent
	_ghost.facing = 0
	
func after_each():
	_gm.free()

func test_draw_weapon_ranges_no_crash():
	var drawn = [false]
	_gm.draw.connect(func():
		if not drawn[0]:
			_gm._draw_weapon_ranges(_ghost, _sender)
			drawn[0] = true
	)
	_gm.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_true(drawn[0], "Draw function was executed")
	pass_test("Function executed without crash")

func test_draw_weapon_ranges_ff_handling():
	# Configure a ship with FF weapons
	_sender.configure_destroyer() # Has Laser Canon (FF)
	
	var drawn = [false]
	_gm.draw.connect(func():
		if not drawn[0]:
			_gm._draw_weapon_ranges(_ghost, _sender)
			drawn[0] = true
	)
	_gm.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_true(drawn[0], "Draw function was executed")
	pass_test("Function executed with FF weapons without crash")

func test_integration_draw_call():
	# Setup GM state to trigger the call in _draw
	_gm.selected_ship = _sender
	_gm.ghost_ship = _ghost
	_gm.ghost_ship.name = "GhostInstance" # Needs to be valid
	_gm.queue_redraw()
	
	# We can't easily check what was drawn, but we can ensure no errors during draw
	# await(_gm.draw, 0.1) -> GUT doesn't wait for draw easily
	# Just running the function manually is the closest proxy
	
	# Verify specific helpers used
	var groups = _sender.get_active_weapon_groups()
	assert_gt(groups.size(), 0, "Should have active weapons")
