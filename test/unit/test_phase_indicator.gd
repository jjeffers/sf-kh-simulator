extends GutTest

var game_manager
var friendly_ship

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)
	# Trigger ready to setup UI (which might load scenario)
	game_manager._ready()
	
	# Clear any scenario ships
	game_manager.ships.clear()
	
	# Friendly Ship (Side 1)
	friendly_ship = load("res://Scripts/Ship.gd").new()
	friendly_ship.name = "Friendly"
	friendly_ship.side_id = 1
	friendly_ship.faction = "UPF"
	friendly_ship.grid_position = Vector3i(0, 0, 0)
	if friendly_ship.get_parent() == null:
		_game_manager.add_child(friendly_ship)
	game_manager.ships.append(friendly_ship)
	game_manager.add_child(friendly_ship)

func test_phase_indicator_initial_state():
	assert_not_null(game_manager.label_phase_indicator, "Phase Indicator Label should exist")

func test_phase_indicator_updates_on_turn_start():
	# Start Turn 1 for Side 1
	game_manager.turn_count = 1
	game_manager.current_phase = game_manager.Phase.END # Ensure change
	
	# This calls start_movement_phase internally
	game_manager._start_turn_for_side(1)
	
	var label = game_manager.label_phase_indicator
	# Pattern: "Turn 1, Active: UPF, Movement"
	print("DEBUG LABEL (Turn Start): ", label.text)
	assert_true(label.text.contains("Turn 1"), "Should show Turn 1")
	assert_true(label.text.contains("Active: UPF"), "Should show Active: UPF")
	assert_true(label.text.contains("Movement"), "Should show Movement phase")

func test_phase_indicator_updates_on_combat_active():
	game_manager.turn_count = 1
	game_manager.current_side_id = 1
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	
	# Transition to Active Combat
	game_manager.start_combat_active()
	
	var label = game_manager.label_phase_indicator
	print("DEBUG LABEL (Active): ", label.text)
	assert_true(label.text.contains("Combat"), "Should show Combat phase")
	assert_true(label.text.contains("UPF"), "Should show UPF (Active Firing Side)")

func test_phase_indicator_updates_on_combat_passive():
	game_manager.turn_count = 1
	game_manager.current_side_id = 1 # Moving side is 1
	game_manager.current_phase = game_manager.Phase.MOVEMENT
	
	# Transition to Passive Combat (Opponent, likely Side 2, fires)
	game_manager.start_combat_passive()
	
	var label = game_manager.label_phase_indicator
	print("DEBUG LABEL (Passive): ", label.text)
	assert_true(label.text.contains("Combat"), "Should show Combat phase")
	# Side 2 might be "Sathar" or generic "Side 2" if no ships.
	# With only 1 ship (Side 1), side 2 is empty -> "Side 2" fallback or similar.
	# Let's just check it DOESN'T say UPF.
	assert_false(label.text.contains("UPF"), "Should NOT show UPF (Passive Firing Side is Opponent)")
	assert_true(label.text.contains("Side 2") or label.text.contains("Sathar"), "Should show Side 2/Sathar")
