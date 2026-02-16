extends GutTest

var panel: Control
var ship: Ship

func before_each():
	# Load script and instantiate
	var PanelScript = load("res://Scripts/ShipStatusPanel.gd")
	panel = PanelScript.new()
	add_child(panel)
	
	ship = Ship.new()
	ship.configure_fighter() # Has Assault Rockets
	# Add a second weapon for testing selection
	ship.weapons.append({
		"name": "Test Laser",
		"type": "Laser",
		"range": 5,
		"arc": "360",
		"ammo": 10,
		"max_ammo": 10,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false
	})
	ship.current_weapon_index = 0

func after_each():
	panel.free()
	ship.free()

func test_weapon_highlight():
	# Act
	panel.update_from_ship(ship)
	
	# Assert
	var vbox = panel.weapons_vbox
	assert_not_null(vbox, "Weapons VBox should exist")
	assert_eq(vbox.get_child_count(), 2, "Should have 2 weapon labels")
	
	var lbl0 = vbox.get_child(0) as Label
	var lbl1 = vbox.get_child(1) as Label
	
	# Check Active Weapon (Index 0)
	# It should have prefix "> " and Green Color
	assert_true(lbl0.text.begins_with("> "), "Active weapon should have prefix '> '")
	# In Godot 4, get_theme_color returns the override if present
	var col0 = lbl0.get_theme_color("font_color")
	assert_eq(col0, Color.GREEN, "Active weapon should be GREEN")
	
	# Check Inactive Weapon (Index 1)
	assert_true(lbl1.text.begins_with("• "), "Inactive weapon should have prefix '• '")
	# Inactive weapon should NOT be green. It might be default (White).
	# If no override is set, get_theme_color returns the theme default (usually White or Black depending on theme)
	# Let's just check it is NOT Green.
	var col1 = lbl1.get_theme_color("font_color")
	assert_ne(col1, Color.GREEN, "Inactive weapon should NOT be GREEN")
	
	# Change Selection and Re-Update
	ship.current_weapon_index = 1
	panel.update_from_ship(ship)
	
	lbl0 = vbox.get_child(0) as Label
	lbl1 = vbox.get_child(1) as Label
	
	# Now Index 0 is Inactive
	assert_true(lbl0.text.begins_with("• "), "Former active weapon should now be inactive")
	assert_ne(lbl0.get_theme_color("font_color"), Color.GREEN)
	
	# Index 1 is Active
	assert_true(lbl1.text.begins_with("> "), "New active weapon should have prefix")
	assert_eq(lbl1.get_theme_color("font_color"), Color.GREEN)
