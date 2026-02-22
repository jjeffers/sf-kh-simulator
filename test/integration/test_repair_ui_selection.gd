extends GutTest

var _gm = null
var ShipScript = null

func before_all():
	var GM_Script = load("res://Scripts/GameManager.gd")
	_gm = GM_Script.new()
	ShipScript = load("res://Scripts/Ship.gd")
	add_child(_gm)

	# Mock UI elements that GameManager relies on during repair UI updates
	_gm.list_movement = VBoxContainer.new()
	_gm.list_repair = VBoxContainer.new()
	_gm.panel_movement = PanelContainer.new()
	_gm.panel_repair = PanelContainer.new()
	_gm.btn_repair_exec = Button.new()
	_gm.label_status = Label.new()

	_gm.add_child(_gm.list_movement)
	_gm.add_child(_gm.list_repair)
	_gm.add_child(_gm.panel_movement)
	_gm.add_child(_gm.panel_repair)
	_gm.add_child(_gm.btn_repair_exec)
	_gm.add_child(_gm.label_status)

func after_all():
	_gm.queue_free()

func before_each():
	_gm.ships.clear()
	for child in _gm.list_movement.get_children(): child.queue_free()
	for child in _gm.list_repair.get_children(): child.queue_free()
	
	_gm.current_phase = _gm.Phase.REPAIR
	_gm.my_side_id = 1
	_gm.current_side_id = 1
	_gm.repair_subphase = 1

func test_repair_ui_list_filtering():
	# Scenario: 3 friendly ships. 1 undamaged, 2 damaged. 1 enemy ship damaged.
	# The list should only show exactly 2 buttons.
	
	var undamaged_ship = ShipScript.new()
	undamaged_ship.name = "UndamagedFriendly"
	undamaged_ship.side_id = 1
	undamaged_ship.max_hull = 20
	undamaged_ship.hull = 20
	if undamaged_ship.get_parent() == null:
		_game_manager.add_child(undamaged_ship)
	_gm.ships.append(undamaged_ship)
	
	var damaged_ship1 = ShipScript.new()
	damaged_ship1.name = "DamagedFriendly1"
	damaged_ship1.side_id = 1
	damaged_ship1.max_hull = 20
	damaged_ship1.hull = 15
	if damaged_ship1.get_parent() == null:
		_game_manager.add_child(damaged_ship1)
	_gm.ships.append(damaged_ship1)
	
	var damaged_ship2 = ShipScript.new()
	damaged_ship2.name = "DamagedFriendly2"
	damaged_ship2.side_id = 1
	damaged_ship2.max_hull = 20
	damaged_ship2.hull = 10
	if damaged_ship2.get_parent() == null:
		_game_manager.add_child(damaged_ship2)
	_gm.ships.append(damaged_ship2)
	
	var damaged_enemy = ShipScript.new()
	damaged_enemy.name = "DamagedEnemy"
	damaged_enemy.side_id = 2
	damaged_enemy.max_hull = 20
	damaged_enemy.hull = 5
	if damaged_enemy.get_parent() == null:
		_game_manager.add_child(damaged_enemy)
	_gm.ships.append(damaged_enemy)
	
	# Trigger the UI update
	_gm._update_repair_ui_list()
	
	# Verify
	var child_count = 0
	for c in _gm.list_movement.get_children():
		if c is Button and not c.is_queued_for_deletion():
			child_count += 1
			# Should not be Enemy or Undamaged
			assert_ne(c.text, "UndamagedFriendly", "Undamaged ship should NOT be in the repair list")
			assert_ne(c.text, "DamagedEnemy", "Enemy ship should NOT be in the repair list")
			
	assert_eq(child_count, 2, "There should be exactly 2 selectable damaged ships in the UI list")

func test_repair_ui_select_ship():
	var damaged_ship = ShipScript.new()
	damaged_ship.name = "DamagedFriendly"
	damaged_ship.side_id = 1
	damaged_ship.max_hull = 20
	damaged_ship.hull = 15
	damaged_ship.current_dcr = 50
	if damaged_ship.get_parent() == null:
		_game_manager.add_child(damaged_ship)
	_gm.ships.append(damaged_ship)
	
	# Setup fake selection
	_gm.selected_ship = damaged_ship
	
	_gm._update_repair_ui()
	
	# Verify that the repair list was populated with the single Selected slider block
	var has_sliders = false
	for c in _gm.list_repair.get_children():
		if not c.is_queued_for_deletion():
			if c is HBoxContainer: # Sliders are in HBoxContainers
				has_sliders = true
				break
				
	assert_true(has_sliders, "The repair allocation sliders should be generated for the explicitly selected ship")
