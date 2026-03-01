extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")

var _gm = null
var _ship_valid = null
var _ship_danger = null
var _ship_moved = null
var _ship_waiting = null

func before_all():
	print("DEBUG: test_movement_ui_visuals.gd loaded and running.")

func before_each():
	_gm = GameManager.new()
	add_child(_gm)
	
	# Mock UI Nodes
	_gm.list_movement = VBoxContainer.new()
	_gm.add_child(_gm.list_movement)
	
	_gm.planet_hexes.append(Vector3i(10, -10, 0)) # Planet at specific location
	
	# Create Ships
	_ship_valid = Ship.new()
	_ship_valid.name = "ValidShip"
	_ship_valid.side_id = 1
	if _ship_valid.get_parent() == null:
		_gm.add_child(_ship_valid)
	_gm.ships.append(_ship_valid)
	
	_ship_danger = Ship.new()
	_ship_danger.name = "DangerShip"
	_ship_danger.side_id = 1
	if _ship_danger.get_parent() == null:
		_gm.add_child(_ship_danger)
	_gm.ships.append(_ship_danger)
	
	_ship_moved = Ship.new()
	_ship_moved.name = "MovedShip"
	_ship_moved.side_id = 1
	if _ship_moved.get_parent() == null:
		_gm.add_child(_ship_moved)
	_gm.ships.append(_ship_moved)
	
	_ship_waiting = Ship.new()
	_ship_waiting.name = "WaitingShip"
	_ship_waiting.side_id = 1
	if _ship_waiting.get_parent() == null:
		_gm.add_child(_ship_waiting)
	_gm.ships.append(_ship_waiting)
	
	# Setup Context
	_gm.current_side_id = 1
	_gm.my_side_id = 1

func after_each():
	_gm.free()

func test_ui_shows_waiting_status():
	_gm._update_movement_ui_list()
	
	var children = _gm.list_movement.get_children()
	var btn = _find_button_by_name(children, "WaitingShip")
	
	assert_not_null(btn, "Button for WaitingShip should exist")
	assert_true(btn.text.contains("WAITING"), "Text should contain WAITING")
	assert_eq(btn.modulate, Color.WHITE, "Color should be WHITE")

func test_ui_shows_planned_status_green():
	# Setup Valid Plan
	_ship_valid.has_orders = true
	var path: Array[Vector3i] = [Vector3i(100, 100, 0), Vector3i(101, 100, -1)]
	_ship_valid.planned_path = path # Clear path
	
	print("DEBUG: Planet Hexes: ", _gm.planet_hexes)
	_gm._update_movement_ui_list()
	var btn = _find_button_by_name(_gm.list_movement.get_children(), "ValidShip")
	
	assert_true(btn.text.contains("PLANNED"), "Text should contain PLANNED")
	assert_eq(btn.modulate, Color.GREEN, "Color should be GREEN")

func test_ui_shows_danger_status_red():
	# Setup Dangerous Plan
	_ship_danger.has_orders = true
	var path: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(10, -10, 0)]
	_ship_danger.planned_path = path # Hits Planet
	
	_gm._update_movement_ui_list()
	var btn = _find_button_by_name(_gm.list_movement.get_children(), "DangerShip")
	
	assert_true(btn.text.contains("DANGER"), "Text should contain DANGER")
	assert_eq(btn.modulate, Color.RED, "Color should be RED")

func test_ui_shows_moved_status_cyan():
	# Setup Moved State
	_ship_moved.has_moved = true
	
	_gm._update_movement_ui_list()
	var btn = _find_button_by_name(_gm.list_movement.get_children(), "MovedShip")
	
	assert_true(btn.text.contains("MOVED"), "Text should contain MOVED")
	assert_eq(btn.modulate, Color.CYAN, "Color should be CYAN")

func _find_button_by_name(children, ship_name):
	for c in children:
		if c is Button and c.text.contains(ship_name):
			return c
	return null
