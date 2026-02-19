extends GutTest

var GameManager
var HexGrid
var ShipScript
var Game
var Ship1
var Ship2

func before_all():
	GameManager = load("res://Scripts/GameManager.gd")
	HexGrid = load("res://Scripts/HexGrid.gd")
	ShipScript = load("res://Scripts/Ship.gd")

func before_each():
	Game = GameManager.new()
	add_child_autofree(Game)
	Game._ready()
	
	Ship1 = ShipScript.new()
	Ship1.name = "Ship1"
	Ship1.side_id = 1
	Ship1.grid_position = Vector3i(0, 0, 0)
	Game.ships.append(Ship1)
	Game.add_child(Ship1)
	
	Ship2 = ShipScript.new()
	Ship2.name = "Ship2"
	Ship2.side_id = 2
	Ship2.grid_position = Vector3i(1, -1, 0)
	Game.ships.append(Ship2)
	Game.add_child(Ship2)

func test_execute_all_movement_advances_side():
	# Setup
	var order: Array[int] = [1, 2]
	Game.turn_order = order
	Game.current_turn_order_index = 0
	Game.current_side_id = 1
	Game.current_phase = Game.Phase.MOVEMENT
	
	# Give Ship1 orders
	Ship1.has_orders = true
	var path1: Array[Vector3i] = [Vector3i(1, 0, -1)]
	Ship1.planned_path = path1
	Ship1.planned_facing = 1
	
	# Execute
	Game.execute_all_movement()
	
	# Verify Ship1 Moved
	assert_true(Ship1.has_moved, "Ship1 should have moved")
	assert_eq(Ship1.grid_position, Vector3i(1, 0, -1), "Ship1 should be at new pos")
	
	# Verify Phase Transition to Combat (Passive)
	# Logic: Movement Done -> Combat (Passive)
	assert_eq(Game.current_phase, Game.Phase.COMBAT, "Phase should switch to COMBAT")
	assert_eq(Game.combat_subphase, 1, "Should be Passive Fire (1)")
	assert_eq(Game.firing_side_id, 2, "Firing side should be Opponent (2)")
	
	# Verify Side is STILL 1 (Movement phase just ended, but turn isn't over til combat done)
	assert_eq(Game.current_side_id, 1, "Active Side should still be 1 during combat")

func test_execute_all_movement_second_side_transitions_to_combat_passive():
	# Setup: Side 2 is moving
	var order: Array[int] = [1, 2]
	Game.turn_order = order
	Game.current_turn_order_index = 1 # Second side
	Game.current_side_id = 2
	Game.current_phase = Game.Phase.MOVEMENT
	
	# Give Ship2 orders
	Ship2.has_orders = true
	var path2: Array[Vector3i] = [Vector3i(2, -1, -1)]
	Ship2.planned_path = path2
	Ship2.planned_facing = 2
	
	# Execute
	Game.execute_all_movement()
	
	# Verify Ship2 Moved
	assert_true(Ship2.has_moved, "Ship2 should have moved")
	
	# Verify Phase Transition to Combat (Passive)
	# Logic: Side 2 Move Done -> Combat (Passive for Side 1)
	assert_eq(Game.current_phase, Game.Phase.COMBAT, "Phase should switch to COMBAT")
	assert_eq(Game.combat_subphase, 1, "Should be Passive Fire (1)")
	assert_eq(Game.firing_side_id, 1, "Firing side should be Opponent (1)")
