extends GutTest

var gm

func before_each():
	gm = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(gm)

func after_each():
	if is_instance_valid(gm):
		gm.queue_free()

func test_docking_rules():
	var station = load("res://Scripts/Ship.gd").new()
	station.name = "TestStation"
	station.configure_space_station()
	gm.ships.append(station)
	gm.add_child(station)

	var fighter = load("res://Scripts/Ship.gd").new()
	fighter.name = "TestFighter"
	fighter.ship_class = "Fighter"
	fighter.adf = 5
	fighter.speed = 0
	gm.ships.append(fighter)
	gm.add_child(fighter)

	# Same Hex, Speed 0 -> Can Dock
	fighter.grid_position = Vector3i(1, 1, -2)
	station.grid_position = Vector3i(1, 1, -2)
	fighter.speed = 0
	assert_true(fighter.can_dock_with(station), "Fighter at speed 0 in same hex should be able to dock")

	# Wrong Hex -> Cannot Dock
	fighter.grid_position = Vector3i(2, 0, -2)
	assert_false(fighter.can_dock_with(station), "Fighter in different hex cannot dock")

	# Same Hex, Speed > 0 but ADF > Speed -> Can Dock
	fighter.grid_position = Vector3i(1, 1, -2)
	fighter.speed = 4
	assert_true(fighter.can_dock_with(station), "Fighter with speed 4 and ADF 5 can dock")

	# Same Hex, Speed > ADF -> Cannot Dock
	fighter.speed = 6
	assert_false(fighter.can_dock_with(station), "Fighter with speed 6 and ADF 5 cannot dock")

	# Execute Dock
	fighter.speed = 4
	assert_true(fighter.dock_at(station), "Docking successful")
	assert_true(fighter.is_docked, "Fighter is flagged as docked")
	assert_eq(fighter.speed, 0, "Fighter speed reduced to 0 upon docking")
	assert_true(station.docked_guests.has(fighter), "Station records the guest")

func test_docked_movement_cascade():
	var station = load("res://Scripts/Ship.gd").new()
	station.name = "TestStation"
	station.configure_space_station()
	gm.ships.append(station)
	gm.add_child(station)

	var fighter = load("res://Scripts/Ship.gd").new()
	fighter.name = "TestFighter"
	fighter.ship_class = "Fighter"
	gm.ships.append(fighter)
	gm.add_child(fighter)

	fighter.grid_position = Vector3i(0, 0, 0)
	station.grid_position = Vector3i(0, 0, 0)
	fighter.dock_at(station)

	# Move the station
	station.grid_position = Vector3i(1, -1, 0)
	assert_eq(fighter.grid_position, Vector3i(1, -1, 0), "Docked fighter moves with station")

func test_undock_on_move():
	var station = load("res://Scripts/Ship.gd").new()
	station.name = "TestStation"
	station.configure_space_station()
	gm.ships.append(station)
	gm.add_child(station)

	var fighter = load("res://Scripts/Ship.gd").new()
	fighter.name = "TestFighter"
	fighter.ship_class = "Fighter"
	gm.ships.append(fighter)
	gm.add_child(fighter)
	
	fighter.dock_at(station)
	
	# Simulate movement plot registration
	var path: Array[Vector3i] = [Vector3i(1, -1, 0)]
	gm.register_movement_plan(fighter.name, path, 0, 0, false)
	
	assert_false(fighter.is_docked, "Fighter un-docks when a new movement plan is registered")
	assert_false(station.docked_guests.has(fighter), "Fighter removed from station guests")

func test_rearm_mechanics():
	var station = load("res://Scripts/Ship.gd").new()
	station.name = "TestStation"
	station.configure_space_station()
	station.rearm_capacity = 2 # Manually set for test since GM pass 3 isn't run here
	gm.ships.append(station)
	gm.add_child(station)

	var fighter = load("res://Scripts/Ship.gd").new()
	fighter.name = "TestFighter"
	fighter.ship_class = "Fighter"
	
	# Setup weapon state matching a Fighter with Assault Rockets
	fighter.weapons.clear()
	fighter.weapons.append({
		"name": "Assault Rocket",
		"type": "Rocket",
		"ammo": 0,
		"max_ammo": 4
	})
	
	gm.ships.append(fighter)
	gm.add_child(fighter)
	
	fighter.dock_at(station)
	
	# Attempt instant rearm (fails)
	assert_false(fighter.rearm_assault_rockets(), "Cannot rearm immediately upon docking")
	
	# Simulate 1 full turn
	fighter.reset_turn_state()
	
	# Attempt rearm 1
	assert_true(fighter.rearm_assault_rockets(), "Rearm succeeds after 1 full turn")
	assert_eq(fighter.weapons[0]["ammo"], 4, "Ammo replenished")
	assert_eq(station.rearm_capacity, 1, "Station Capacity decremented")
	assert_eq(fighter.turns_docked_since_action, 0, "Timer resets after rearm")
	
	# Use rockets again
	fighter.weapons[0]["ammo"] = 0
	
	# Attempt rearm prematurely
	assert_false(fighter.rearm_assault_rockets(), "Cannot rearm immediately after previous rearm")
	
	# Simulate another turn
	fighter.reset_turn_state()
	
	# Attempt rearm 2
	assert_true(fighter.rearm_assault_rockets(), "Rearm 2 succeeds")
	assert_eq(station.rearm_capacity, 0, "Station Capacity decremented to 0")
	
	# Use rockets again
	fighter.weapons[0]["ammo"] = 0
	fighter.reset_turn_state()
	
	# Attempt rearm 3
	assert_false(fighter.rearm_assault_rockets(), "Cannot rearm, Station out of capacity")
