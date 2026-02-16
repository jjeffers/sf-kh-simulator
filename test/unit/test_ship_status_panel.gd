extends GutTest

var ShipStatusPanel = load("res://Scripts/ShipStatusPanel.gd")
# var Ship = load("res://Scripts/Ship.gd") # Ship is global class_name

var panel
var ship

func before_each():
	ship = Ship.new()
	panel = ShipStatusPanel.new()
	add_child(panel)
	add_child(ship)

func after_each():
	panel.free()
	ship.free()

func test_no_damage_initial_state():
	ship.configure_frigate() # Has stats
	panel.update_from_ship(ship)
	
	assert_false(panel.damaged_systems_panel.visible, "Damaged systems panel should be hidden initially")

func test_adf_reduction():
	ship.configure_frigate()
	# Apply logic manually or via damage effect helper if available, 
	# but for UI test, setting properties is fine if UI reads them.
	ship.current_adf_modifier = 1
	
	panel.update_from_ship(ship)
	
	assert_true(panel.damaged_systems_panel.visible, "Panel should be visible after ADF damage")
	
	# Check Main Stats Label
	# Format: "%d (%d)" % [effective, base]
	# Frigate ADF is 3. Mod is 1. Effective is 2.
	assert_eq(panel.lbl_adf.text, "2 (3)", "ADF Label should show effective and base")
	
	var labels = panel.damaged_systems_vbox.get_children()
	# Index 0 is Title
	assert_gt(labels.size(), 1, "Should have damage items")
	assert_string_contains(labels[1].text, "ADF Reduced", "Should text contain ADF Reduced")

func test_crippled_weapon():
	ship.configure_frigate()
	var w = ship.weapons[0]
	w["is_crippled"] = true
	
	panel.update_from_ship(ship)
	
	assert_true(panel.damaged_systems_panel.visible, "Panel visible")
	var labels = panel.damaged_systems_vbox.get_children()
	assert_string_contains(labels[1].text, "Crippled", "Should show crippled weapon")
	assert_string_contains(labels[1].text, w["name"], "Should show weapon name")

func test_system_damage():
	ship.configure_frigate() # Has ICM (4) and MS (1)
	
	# Damage CCS
	ship.ccs_damaged = true
	panel.update_from_ship(ship)
	var text_found = false
	for c in panel.damaged_systems_vbox.get_children():
		if "Combat Control System" in c.text: text_found = true
	assert_true(text_found, "CCS Damage shown")
	
	# Destroy ICM
	ship.icm_max = 0
	panel.update_from_ship(ship)
	text_found = false
	for c in panel.damaged_systems_vbox.get_children():
		if "ICM System Destroyed" in c.text: text_found = true
	assert_true(text_found, "ICM Destroyed shown")

func test_fire():
	ship.configure_frigate()
	ship.has_electrical_fire = true
	
	panel.update_from_ship(ship)
	var text_found = false
	for c in panel.damaged_systems_vbox.get_children():
		if "ELECTRICAL FIRE" in c.text: text_found = true
	assert_true(text_found, "Fire shown")
