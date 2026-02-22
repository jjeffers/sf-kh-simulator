extends GutTest

var GameManager
var Ship
var HexGrid
var NetworkManager

func before_all():
	GameManager = load("res://Scripts/GameManager.gd")
	Ship = load("res://Scripts/Ship.gd")
	HexGrid = load("res://Scripts/HexGrid.gd")
	NetworkManager = load("res://Scripts/NetworkManager.gd")

func before_each():
	# Clean up any existing nodes
	var existing_gm = get_parent().get_node_or_null("GameManager")
	if existing_gm:
		existing_gm.queue_free()

func test_batch_movement_flow():
	var gm = GameManager.new()
	gm.name = "GameManager"
	add_child_autofree(gm)
	
	# Setup Ships
	var s1 = load("res://Scripts/Ship.gd").new()
	s1.name = "Ship1"
	s1.side_id = 1
	s1.grid_position = Vector3i(0, 0, 0)
	s1.facing = 0
	s1.speed = 0
	s1.adf = 2
	if s1.get_parent() == null:
		_game_manager.add_child(s1)
	gm.ships.append(s1)
	gm.add_child(s1)
	
	var s2 = load("res://Scripts/Ship.gd").new()
	s2.name = "Ship2"
	s2.side_id = 1 # Same side
	s2.grid_position = Vector3i(2, 0, -2)
	s2.facing = 0
	s2.speed = 0
	s2.adf = 2
	if s2.get_parent() == null:
		_game_manager.add_child(s2)
	gm.ships.append(s2)
	gm.add_child(s2)
	
	# gm._ready() # Removed to prevent scenario reload wiping ships
	gm.current_side_id = 1
	gm.my_side_id = 1 # Authority
	gm.start_movement_phase()
	
	# Verify Initial State
	assert_eq(gm.current_phase, gm.Phase.MOVEMENT)
	assert_false(s1.has_orders, "Ship1 should not have orders initially")
	assert_false(s1.has_moved, "Ship1 should not have moved initially")
	
	# --- 1. Plan for Ship 1 ---
	gm.selected_ship = s1
	gm._reset_plotting_state()
	
	# Plot a valid move (1 hex forward)
	var path: Array[Vector3i] = [Vector3i(1, 0, -1)]
	gm.current_path = path
	gm.ghost_head_facing = 0
	
	# Ensure ghost_ship is valid for commit
	gm.ghost_ship = load("res://Scripts/Ship.gd").new()
	gm.ghost_ship.name = "GhostShip"
	gm.ghost_ship.facing = 0
	gm.add_child(gm.ghost_ship)
	
	# Commit (Register Plan)
	gm._on_commit_move()
	
	# Verify Plan Stored but Not Moved
	assert_true(s1.has_orders, "Ship1 should have orders after commit")
	assert_false(s1.has_moved, "Ship1 should NOT have moved yet")
	assert_eq(s1.grid_position, Vector3i(0, 0, 0), "Ship1 position should be unchanged")
	assert_eq(s1.planned_path.size(), 1, "Ship1 should have planned path")
	
	# --- 2. Plan for Ship 2 ---
	gm.selected_ship = s2
	gm._reset_plotting_state()
	
	# Plot move
	var path2: Array[Vector3i] = [Vector3i(3, 0, -3)]
	gm.current_path = path2
	gm.ghost_head_facing = 0
	
	# Manually spawn ghost since _spawn_ghost fails without ship_scene
	gm.ghost_ship = load("res://Scripts/Ship.gd").new()
	gm.ghost_ship.name = "GhostShip2"
	gm.ghost_ship.facing = 0
	gm.add_child(gm.ghost_ship)
	
	gm._on_commit_move()
	
	assert_true(s2.has_orders, "Ship2 should have orders")
	
	# --- 3. Execute Batch ---
	gm._on_exec_move_pressed()
	
	# Check results
	assert_true(s1.has_moved, "Ship1 should have moved")
	assert_false(s1.has_orders, "Ship1 orders should be cleared")
	assert_eq(s1.grid_position, Vector3i(1, 0, -1), "Ship1 should be at new position")
	
	assert_true(s2.has_moved, "Ship2 should have moved")
	assert_eq(s2.grid_position, Vector3i(3, 0, -3), "Ship2 should be at new position")
	
func test_undo_planning():
	var gm = GameManager.new()
	gm.name = "GameManager"
	add_child_autofree(gm)
	
	var s1 = load("res://Scripts/Ship.gd").new()
	s1.name = "ShipUndo"
	s1.side_id = 1
	s1.grid_position = Vector3i(0, 0, 0)
	if s1.get_parent() == null:
		_game_manager.add_child(s1)
	gm.ships.append(s1)
	gm.add_child(s1)
	
	# gm._ready() # Removed to prevent scenario reload wiping ships
	gm.current_side_id = 1
	gm.my_side_id = 1
	gm.start_movement_phase()
	
	# Plan and Commit
	gm.selected_ship = s1
	var invalid_path: Array[Vector3i] = [Vector3i(1, 0, -1)]
	gm.current_path = invalid_path
	
	# Manually spawn ghost since _spawn_ghost fails without ship_scene
	gm.ghost_ship = load("res://Scripts/Ship.gd").new()
	gm.ghost_ship.facing = 0
	gm.add_child(gm.ghost_ship)
	
	gm._on_commit_move()
	
	assert_true(s1.has_orders, "Orders set")
	
	# Undo
	gm._on_undo()
	
	assert_false(s1.has_orders, "Orders should be cleared after undo")
	assert_eq(s1.planned_path.size(), 0, "Planned path cleared")
	assert_false(s1.has_moved, "Ship still has not moved")
