extends GutTest

var panel_script = load("res://Scripts/ShipStatusPanel.gd")
var ship_script = load("res://Scripts/Ship.gd")
var panel
var ship

func before_each():
	panel = panel_script.new()
	add_child_autofree(panel)
	ship = ship_script.new()
	add_child_autofree(ship)
	ship.configure_fighter() # Has Assault Rockets at index 0

func test_weapon_list_generation():
	# Update panel
	panel.update_from_ship(ship)
	
	# Check we have weapons
	assert_eq(panel.weapons_vbox.get_child_count(), 1, "Should have 1 weapon label")
	var lbl = panel.weapons_vbox.get_child(0) as Label
	assert_true(lbl.text.contains("Assault Rockets"), "Label should contain weapon name")

func test_weapon_highlight():
	# Add a second weapon to test selection
	ship.weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 10,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999
	})
	
	# Select 2nd weapon
	ship.current_weapon_index = 1
	
	panel.update_from_ship(ship)
	
	var lbl0 = panel.weapons_vbox.get_child(0) as Label
	var lbl1 = panel.weapons_vbox.get_child(1) as Label
	
	# Current behavior: No highlight, so strict check for highlight chars might fail or pass depending on what we assert.
	# We want to Assert that the Highlight IS present.
	# Highlight format: "> " prefix and Yellow Color
	
	# This assertion EXPECTS the feature to be implemented. 
	# Running this BEFORE implementation should FAIL.
	assert_true(lbl1.text.begins_with("> "), "Selected weapon should have '> ' prefix")
	assert_eq(lbl1.get_theme_color_override("font_color"), Color.YELLOW, "Selected weapon should be Yellow")
	
	# Non-selected should not
	assert_false(lbl0.text.begins_with("> "), "Unselected weapon should NOT have prefix")
	assert_ne(lbl0.get_theme_color_override("font_color"), Color.YELLOW, "Unselected weapon should NOT be Yellow")
