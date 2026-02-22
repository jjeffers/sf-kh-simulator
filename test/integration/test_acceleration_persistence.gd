extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")
var HexGrid = load("res://Scripts/HexGrid.gd")

var _sender
var _game_manager
var _ship

func before_each():
	_sender = InputSender.new(self)
	_game_manager = GameManager.new()
	add_child_autofree(_game_manager)
	
	# Setup map and ship
	_game_manager.map_radius = 10
	
	# Initialize lists (clear any scenario loaded by _ready)
	_game_manager.ships.clear()
	
	_ship = Ship.new()
	_ship.name = "TestShip"
	_ship.configure_destroyer()
	_ship.grid_position = Vector3i(0, 0, 0)
	_ship.facing = 0
	_ship.speed = 0
	_ship.side_id = 1
	if _ship.get_parent() == null:
		_game_manager.add_child(_ship)
	_game_manager.ships.append(_ship)
	
	# Network setup for the test
	_game_manager.my_side_id = 1
	_game_manager.current_side_id = 1
	
	# Start in Movement Phase
	_game_manager.current_phase = _game_manager.Phase.MOVEMENT
	_game_manager.selected_ship = _ship
	_game_manager.ghost_ship = _ship.duplicate() # Need a ghost
	add_child_autofree(_game_manager.ghost_ship)

func test_acceleration_to_3_persists():
	# 1. Verify initial state
	assert_eq(_ship.speed, 0, "Ship should start at speed 0")
	
	# 2. Simulate plotting a move: Accel to 3
	# Populate current_path with 3 hexes (dummy hexes, logic just checks size)
	_game_manager.current_path.clear()
	_game_manager.current_path.append_array([Vector3i(1, 0, -1), Vector3i(2, 0, -2), Vector3i(3, 0, -3)])

	
	# Update Ghost to match end state
	_game_manager.ghost_ship.grid_position = Vector3i(3, 0, -3)
	_game_manager.ghost_ship.facing = 0
	
	# Commit the move
	print("DEBUG: Before _on_commit_move")
	_game_manager._on_commit_move()
	print("DEBUG: After _on_commit_move")
	
	# Verify ship has updated planned_path
	assert_true(_ship.has_orders, "Ship should have orders")
	assert_eq(_ship.planned_path.size(), 3, "Ship planned path size should be 3")
	
	# 3. Apply Movement (Execute)
	print("DEBUG: Before execute_all_movement")
	_game_manager.execute_all_movement()
	print("DEBUG: After execute_all_movement")
	
	# Verify Speed Updated
	if _ship == null:
		print("DEBUG: _SHIP IS NULL!")
	else:
		print("DEBUG: _ship exists, speed is ", _ship.speed)
	assert_eq(_ship.speed, 3, "Ship speed should be 3 after movement application")
	assert_true(_ship.has_moved, "Ship should be marked as moved")
	
func test_icm_dialog_shows_target_name():
	# Setup Target Ship
	var target = Ship.new()
	target.name = "USS Enterprise"
	target.side_id = 1
	target.icm_max = 3
	target.icm_current = 3
	if target.get_parent() == null:
		_game_manager.add_child(target)
	_game_manager.ships.append(target)
	
	# Trigger ICM Decision
	# _trigger_icm_decision(attacker_name, weapon_name, weapon_type, current_chance, target)
	_game_manager._trigger_icm_decision("Enemy Ship", "Torpedo", "Torpedo", 80, target)
	
	# Verify Panel Created
	assert_not_null(_game_manager.panel_icm, "ICM Panel should be created")
	
	# Verify Label Text
	# The label is added to a VBox inside the panel.
	# Structure: Panel -> VBox -> Label (index 0)
	var vbox = _game_manager.panel_icm.get_child(0)
	var lbl = vbox.get_child(0)
	
	assert_true(lbl is Label, "First child should be Label")
	assert_string_contains(lbl.text, "USS Enterprise", "Label should contain target ship name")
	assert_string_contains(lbl.text, "Enemy Ship", "Label should contain attacker name")
