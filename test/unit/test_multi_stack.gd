extends GutTest

var game_manager
var friendly_ship
var enemy_1
var enemy_2

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)
	game_manager.ships.clear()
	
	# Friendly Ship (Side 1)
	friendly_ship = load("res://Scripts/Ship.gd").new()
	friendly_ship.name = "Friendly"
	friendly_ship.side_id = 1
	friendly_ship.grid_position = Vector3i(0, 0, 0)
	friendly_ship.weapons = [ {"name": "Laser", "range": 5, "damage": "1d10", "ammo": - 1, "arc": "360", "fired": false}]
	
	# Enemy 1 (Side 2)
	enemy_1 = load("res://Scripts/Ship.gd").new()
	enemy_1.name = "Enemy_A"
	enemy_1.side_id = 2
	enemy_1.grid_position = Vector3i(0, 0, 0)
	
	# Enemy 2 (Side 2)
	enemy_2 = load("res://Scripts/Ship.gd").new()
	enemy_2.name = "Enemy_B"
	enemy_2.side_id = 2
	enemy_2.grid_position = Vector3i(0, 0, 0)
	
	if friendly_ship.get_parent() == null:
		_game_manager.add_child(friendly_ship)
	game_manager.ships.append(friendly_ship)
	if enemy_1.get_parent() == null:
		_game_manager.add_child(enemy_1)
	game_manager.ships.append(enemy_1)
	if enemy_2.get_parent() == null:
		_game_manager.add_child(enemy_2)
	game_manager.ships.append(enemy_2)
	
	game_manager.add_child(friendly_ship)
	game_manager.add_child(enemy_1)
	game_manager.add_child(enemy_2)
	
	game_manager.current_phase = game_manager.Phase.COMBAT
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1
	game_manager.firing_side_id = 1
	game_manager.current_combat_state = game_manager.CombatState.PLANNING
	
	game_manager.selected_ship = friendly_ship
	friendly_ship.current_weapon_index = 0

func test_multi_enemy_stack_targeting():
	# 1. Force Visual Mismatch
	# Ships array order: [Friendly, Enemy_A, Enemy_B]
	# Naturally Enemy_B is last = top.
	# Let's force Enemy_A to be TOP visually (move_to_front / raise)
	enemy_1.get_parent().move_child(enemy_1, -1) # Enemy_A is now last sibling (Top)
	
	# 2. Click the stack
	game_manager._handle_combat_click(Vector3i(0, 0, 0))
	
	# Assert we targeted the VISUAL TOP (Enemy_A), even though it is earlier in ships array
	assert_not_null(game_manager.combat_target, "Should have targeted an enemy")
	if game_manager.combat_target:
		assert_eq(game_manager.combat_target.name, "Enemy_A", "Should prioritize Visual Top ship (Enemy A)")
		
	# Check queued attack
	assert_gt(game_manager.queued_attacks.size(), 0, "First click should store attack")
	if game_manager.queued_attacks.size() > 0:
		assert_eq(game_manager.queued_attacks[0]["target"], game_manager.combat_target, "Attacked the selected target")
