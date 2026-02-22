extends GutTest

var GameManager = load("res://Scripts/GameManager.gd")
var Ship = load("res://Scripts/Ship.gd")

var _gm = null
var _enemy_ship = null

func before_each():
	_gm = GameManager.new()
	add_child(_gm)
	
	_gm.test_force_online = true
	
	_gm.my_side_id = 1
	_gm.current_side_id = 2 # Enemy Turn
	_gm.current_phase = _gm.Phase.MOVEMENT
	
	_enemy_ship = Ship.new()
	_enemy_ship.name = "EnemyShip"
	_enemy_ship.side_id = 2
	_enemy_ship.has_orders = false # Not committed yet
	if _enemy_ship.get_parent() == null:
		_game_manager.add_child(_enemy_ship)
	_gm.ships.append(_enemy_ship)
	_gm.add_child(_enemy_ship)

func after_each():
	_gm.free()

func test_enemy_selection_no_ghost():
	# Scenario: Select Enemy Ship during Enemy Turn
	_gm.selected_ship = _enemy_ship
	
	# Action: Attempt to spawn ghost (triggered by selection usually)
	_gm._spawn_ghost()
	
	# Verify: Ghost should NOT spawn because:
	# 1. Not My Ship overrides "My Turn" (even if it WAS my turn, I can't move enemy)
	# 2. Not My Turn (it is Enemy Turn)
	# 3. No Orders (Not committed)
	
	assert_null(_gm.ghost_ship, "Ghost ship should not spawn for uncommitted enemy ship")

func test_enemy_selection_no_path_preview():
	_gm.selected_ship = _enemy_ship
	_gm._spawn_ghost()
	
	# Verify Process/Draw logic conditions
	# Verify Process/Draw logic conditions
	# Verify Process/Draw logic conditions
	# For a normal player (Side 1) looking at Enemy (Side 2), both should be false
	var is_my_turn_process = (_gm.my_side_id == _gm.current_side_id) or _gm._has_admin_authority()
	
	# We assert that we do NOT have authority to view/move this ship
	assert_false(is_my_turn_process, "Should not be my turn process (Not Admin, Not My Turn)")
	
	# If ghost is null, draw loop for predictive highlights is skipped
	var draw_condition = _gm.current_phase == _gm.Phase.MOVEMENT and is_instance_valid(_gm.ghost_ship)
	assert_false(draw_condition, "Draw condition for highlights should be false")

func test_cycle_selection_enemy_turn():
	# Verify TAB doesn't select enemy
	_gm.selected_ship = null
	_gm._cycle_selection()
	
	assert_null(_gm.selected_ship, "Should not cycle/select anything")
