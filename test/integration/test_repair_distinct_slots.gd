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

func test_distinct_adf_and_mr_slots():
	var fighter = ShipScript.new()
	fighter.name = "DamagedFighter"
	fighter.side_id = 1
	fighter.max_hull = 20
	fighter.hull = 20
	fighter.current_dcr = 50
	
	# Fighter has high MR and high ADF
	fighter.adf = 4
	fighter.mr = 4
	
	# Simulate 3 points of ADF damage, and 2 points of MR damage
	fighter.current_adf_modifier = 3
	fighter.current_mr_modifier = 2
	
	if fighter.get_parent() == null:
		_game_manager.add_child(fighter)
	_gm.ships.append(fighter)
	
	# Setup fake selection
	_gm.selected_ship = fighter
	
	# Trigger the UI update
	_gm._update_repair_ui()
	
	# Verify that the repair list was populated with distinct slots
	var adf_slots = 0
	var mr_slots = 0
	
	for c in _gm.list_repair.get_children():
		if not c.is_queued_for_deletion() and c is HBoxContainer:
			var lbl = c.get_child(0) as Label
			if lbl:
				if "ADF Loss" in lbl.text:
					adf_slots += 1
				elif "MR Loss" in lbl.text:
					mr_slots += 1
					
	assert_eq(adf_slots, 3, "There should be exactly 3 distinct ADF repair slots generated")
	assert_eq(mr_slots, 2, "There should be exactly 2 distinct MR repair slots generated")
