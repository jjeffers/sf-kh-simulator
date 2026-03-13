extends GutTest

var ship_script = preload("res://Scripts/Ship.gd")

func test_docked_fighter_visibility():
	var fighter = ship_script.new()
	fighter.name = "Fighter1"
	fighter.ship_class = "Fighter"
	fighter.visible = true
	
	var station = ship_script.new()
	station.name = "StationAlpha"
	station.ship_class = "Space Station"
	
	# Initial visibility
	assert_true(fighter.visible, "Fighter starts visible")
	
	# Docking should hide it
	var dock_success = fighter.dock_at(station)
	assert_true(dock_success, "Docking should succeed")
	assert_false(fighter.visible, "Fighter should be hidden when docked")
	
	# Undocking should reveal it
	fighter.undock()
	assert_true(fighter.visible, "Fighter should become visible upon undocking")

func test_docked_assault_scout_visibility():
	var scout = ship_script.new()
	scout.name = "Scout1"
	scout.ship_class = "Assault Scout"
	scout.visible = true
	
	var carrier = ship_script.new()
	carrier.name = "CarrierAlpha"
	carrier.ship_class = "Assault Carrier"
	
	# Initial visibility
	assert_true(scout.visible, "Scout starts visible")
	
	# Docking should hide it
	var dock_success = scout.dock_at(carrier)
	assert_true(dock_success, "Docking should succeed")
	assert_false(scout.visible, "Scout should be hidden when docked")
	
	# Undocking should reveal it
	scout.undock()
	assert_true(scout.visible, "Scout should become visible upon undocking")

func test_normal_ship_visibility_not_affected():
	var destroyer = ship_script.new()
	destroyer.name = "Destroyer1"
	destroyer.ship_class = "Destroyer"
	destroyer.visible = true
	
	var station = ship_script.new()
	station.name = "StationAlpha"
	station.ship_class = "Space Station"
	
	# Initial visibility
	assert_true(destroyer.visible, "Destroyer starts visible")
	
	# Docking should NOT hide it
	var dock_success = destroyer.dock_at(station)
	assert_true(dock_success, "Docking should succeed")
	assert_true(destroyer.visible, "Destroyer should remain visible when docked")
	
	# Undocking
	destroyer.undock()
	assert_true(destroyer.visible, "Destroyer should remain visible upon undocking")
