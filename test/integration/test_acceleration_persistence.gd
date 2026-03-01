extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")
var HexGrid = load("res://Scripts/HexGrid.gd")

var _sender
var game_manager
var _ship

func before_each():
	_sender = InputSender.new(self)
	game_manager = GameManager.new()
	add_child_autofree(game_manager)
	
	# Setup map and ship
	game_manager.map_radius = 10
	
	# Initialize lists (clear any scenario loaded by _ready)
	game_manager.ships.clear()
	
	_ship = Ship.new()
	_ship.name = "TestShip"
	_ship.configure_destroyer()
	_ship.grid_position = Vector3i(0, 0, 0)
	_ship.facing = 0
	_ship.speed = 0
	_ship.side_id = 1
	if _ship.get_parent() == null:
		game_manager.add_child(_ship)
	game_manager.ships.append(_ship)
	
	# Network setup for the test
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	
	# Start in Movement Phase
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	game_manager.selected_ship = _ship
	game_manager.ghost_ship = _ship.duplicate() # Need a ghost
	add_child_autofree(game_manager.ghost_ship)

func test_acceleration_to_3_persists():
	# 1. Verify initial state
	assert_eq(_ship.speed, 0, "Ship should start at speed 0")
	
	# 2. Simulate plotting a move: Accel to 3
	# Populate current_path with 3 hexes (dummy hexes, logic just checks size)
	game_manager.current_path.clear()
	game_manager.current_path.append_array([Vector3i(1, 0, -1), Vector3i(2, 0, -2), Vector3i(3, 0, -3)])

	
	# Update Ghost to match end state
	game_manager.ghost_ship.grid_position = Vector3i(3, 0, -3)
	game_manager.ghost_ship.facing = 0
	
	# Commit the move
	print("DEBUG: Before _on_commit_move")
	game_manager._on_commit_move()
	print("DEBUG: After _on_commit_move")
	
	# Verify ship has updated planned_path
	assert_true(_ship.has_orders, "Ship should have orders")
	assert_eq(_ship.planned_path.size(), 3, "Ship planned path size should be 3")
	
	# 3. Apply Movement (Execute)
	print("DEBUG: Before execute_all_movement")
	game_manager.execute_all_movement()
	print("DEBUG: After execute_all_movement")
	
	# Verify Speed Updated
	if _ship == null:
		print("DEBUG: _SHIP IS NULL!")
	else:
		print("DEBUG: _ship exists, speed is ", _ship.speed)
	assert_eq(_ship.speed, 3, "Ship speed should be 3 after movement application")
	assert_true(_ship.has_moved, "Ship should be marked as moved")
	
	gut.p("ABOUT TO TRIGGER")
func test_icm_dialog_shows_target_name():
	gut.p("ABOUT TO TRIGGER")
	gut.p("Starting test_icm_dialog_shows_target_name")
	
	# Setup Target Ship
	var target = Ship.new()
	target.name = "USSEnterprise"
	target.side_id = 1
	target.icm_max = 3
	target.icm_current = 3
	if target.get_parent() == null:
		game_manager.add_child(target)
	game_manager.ships.append(target)
	game_manager.my_side_id = 1
	game_manager.ui_layer = autofree(CanvasLayer.new())
	game_manager.add_child(game_manager.ui_layer)
	
	gut.p("Target Name: " + str(target.name))
	gut.p("GameManager IS OFfline? " + str(game_manager._is_server_or_offline()))
	gut.p("Computer Opponents array: " + str(game_manager.computer_opponents))
	
	# Trigger ICM Decision
	game_manager._trigger_icm_decision("Enemy Ship", "Torpedo", "Torpedo", 80, target, [target])
	
	gut.p("Panel ICM exists? " + str(game_manager.panel_icm != null))
	
	# Verify Panel Created
	assert_not_null(game_manager.panel_icm, "ICM Panel should be created")
	
	if game_manager.panel_icm != null:
		var vbox = game_manager.panel_icm.get_child(0)
		var lbl = vbox.get_child(0)
		
		assert_true(lbl is Label, "First child should be Label")
		assert_string_contains(lbl.text, "USSEnterprise", "Label should contain target ship name")
		assert_string_contains(lbl.text, "Enemy Ship", "Label should contain attacker name")
