extends GutTest

var _gm = null
var ShipScript = null

func before_all():
	var GM_Script = load("res://Scripts/GameManager.gd")
	_gm = GM_Script.new()
	ShipScript = load("res://Scripts/Ship.gd")
	add_child(_gm)
	
	_gm.ui_layer = CanvasLayer.new()
	_gm.add_child(_gm.ui_layer)

func after_all():
	_gm.queue_free()

func before_each():
	_gm.ships.clear()
	if _gm.panel_icm:
		_gm.panel_icm.queue_free()
		_gm.panel_icm = null
		
	_gm.current_phase = _gm.Phase.COMBAT
	_gm.my_side_id = 1
	_gm.current_side_id = 1

func test_shared_icm_defense_allocations():
	var attacker = ShipScript.new()
	attacker.name = "Attacker"
	attacker.side_id = 1
	attacker.grid_position = Vector3i(0, 0, 0)
	attacker.facing = 0
	attacker.weapons = [{"name": "Torps", "type": "Torpedo", "range": 4, "arc": "360", "ammo": 2, "fired": false}]
	_gm.ships.append(attacker)
	
	var defender_target = ShipScript.new()
	defender_target.name = "DefTarget"
	defender_target.side_id = 2
	defender_target.grid_position = Vector3i(2, 0, -2)
	defender_target.icm_max = 4
	defender_target.icm_current = 4
	defender_target.hull = 40
	_gm.ships.append(defender_target)
	
	var defender_helper = ShipScript.new()
	defender_helper.name = "DefHelper"
	defender_helper.side_id = 2
	defender_helper.grid_position = Vector3i(2, 0, -2) # Same hex
	defender_helper.icm_max = 2
	defender_helper.icm_current = 2
	defender_helper.hull = 40
	_gm.ships.append(defender_helper)
	
	# Simulate trigger decision
	_gm.my_side_id = 2 # Become the owning player so UI renders the buttons
	var eligible_ships = [defender_target, defender_helper]
	
	_gm._trigger_icm_decision(attacker.name, "Torps", "Torpedo", 70, defender_target, eligible_ships)
	
	await get_tree().create_timer(0.2).timeout
	
	# Find SpinBoxes in the instantiated UI
	var spinboxes = {}
	var launch_btn = null
	
	# _trigger_icm_decision builds a PanelContainer > VBoxContainer
	var vbox = _gm.panel_icm.get_child(0)
	for child in vbox.get_children():
		if child is HBoxContainer:
			# Look for SpinBoxes
			for sc in child.get_children():
				if sc is SpinBox:
					# Label text is set before Spinbox, we can just grab them by order
					pass
				elif sc is Button:
					if sc.text == "LAUNCH ICM(s)!":
						launch_btn = sc
						
	# We know there should be 2 SpinBoxes since there are 2 eligible ships
	var found_spins = []
	for child in vbox.get_children():
		if child is HBoxContainer:
			for sc in child.get_children():
				if sc is SpinBox:
					found_spins.append(sc)
					
	assert_eq(found_spins.size(), 2, "Should have 2 SpinBoxes for 2 eligible ships")
	
	# Actually finding which is which: The label text contains the name
	# But setting values directly is easier. 
	# Let's say we set the first to 1, the second to 2.
	if found_spins.size() == 2:
		found_spins[0].value = 1
		found_spins[1].value = 2
		
	# Setup a waiter for the signal
	var sig_promise = watch_signals(_gm)
	
	# Click launch
	if launch_btn:
		launch_btn.pressed.emit()
		
	await get_tree().create_timer(0.2).timeout
	
	assert_signal_emitted(_gm, "icm_decision_made")
	var emit_args = get_signal_parameters(_gm, "icm_decision_made")
	
	assert_true(emit_args != null, "Should have emitted arguments")
	if emit_args:
		var allocs = emit_args[0]
		assert_typeof(allocs, TYPE_DICTIONARY, "Should emit a dictionary")
		
		var sum_allocs = 0
		for k in allocs: sum_allocs += allocs[k]
		assert_eq(sum_allocs, 3, "Total allocation should equal 3")
		assert_true(allocs.has("DefTarget"), "DefTarget should be in allocations")
		assert_true(allocs.has("DefHelper"), "DefHelper should be in allocations")
		
		# Now test resolution flow using the allocations
		# _resolve_attack handles the math. We can manually do the deduction here to simulate what GameManager would do:
		for s_name in allocs.keys():
			var amt = allocs[s_name]
			for s in eligible_ships:
				if s.name == s_name:
					s.icm_current -= amt
					
		assert_eq(defender_target.icm_current, 3, "DefTarget should have used 1 ICM (4 -> 3)")
		assert_eq(defender_helper.icm_current, 0, "DefHelper should have used 2 ICMs (2 -> 0)")
