extends GutTest

var game_manager
var friendly_ship
var enemy_ship

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)
	game_manager.ships.clear()
	
	# Friendly Ship (Side 1)
	friendly_ship = load("res://Scripts/Ship.gd").new()
	friendly_ship.name = "FriendlyShip"
	friendly_ship.side_id = 1
	friendly_ship.grid_position = Vector3i(0, 0, 0)
	friendly_ship.facing = 0
	friendly_ship.weapons = [ {"name": "Laser", "type": "Laser", "range": 5, "damage": "1d10", "ammo": - 1, "arc": "360", "fired": false}]
	
	# Enemy Ship (Side 2) - Stacked at same position
	enemy_ship = load("res://Scripts/Ship.gd").new()
	enemy_ship.name = "EnemyShip"
	enemy_ship.side_id = 2
	enemy_ship.grid_position = Vector3i(0, 0, 0)
	enemy_ship.facing = 3
	
	if friendly_ship.get_parent() == null:
		game_manager.add_child(friendly_ship)
	game_manager.ships.append(friendly_ship)
	if enemy_ship.get_parent() == null:
		game_manager.add_child(enemy_ship)
	game_manager.ships.append(enemy_ship)
	
	# Set Phase to Combat
	game_manager.current_phase = game_manager.Phase.COMBAT
	game_manager.my_side_id = 1
	game_manager.current_side_id = 1 # Active player
	game_manager.firing_side_id = 1 # Active firing side
	game_manager.current_combat_state = game_manager.CombatState.PLANNING
	
	game_manager.selected_ship = friendly_ship
	friendly_ship.current_weapon_index = 0

func test_reproduction_stack_selection_bug():
	# Verify initial state
	assert_eq(game_manager.selected_ship, friendly_ship, "Friendly ship starts selected")
	assert_eq(game_manager.queued_attacks.size(), 0, "No attacks queued initially")
	
	# Simulate clicking the stack (Hex 0,0,0)
	# BUG: This should queue an attack on the Enemy, but currently just re-selects (or keeps selected) the Friendly ship without attacking.
	game_manager._handle_combat_click(Vector3i(0, 0, 0))
	
	# Assertion: Expect an attack to be queued
	# If bug exists, this will fail (size will be 0)
	assert_gt(game_manager.queued_attacks.size(), 0, "Should queue an attack on the enemy in the stack")
	
	if game_manager.queued_attacks.size() > 0:
		var atk = game_manager.queued_attacks[0]
		assert_eq(atk["target"], enemy_ship, "Target should be the enemy ship")
		assert_eq(atk["source"], friendly_ship, "Source should be friendly ship")
