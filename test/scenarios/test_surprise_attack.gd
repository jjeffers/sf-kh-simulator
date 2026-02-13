extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var ScenarioManagerScript = preload("res://Scripts/ScenarioManager.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	
	_gm.my_side_id = 1
	_gm.current_side_id = 1
	_gm.ships.clear()
	_gm.planet_hexes.clear()
	_gm.current_scenario_rules.clear()

func after_each():
	_gm.free()

func test_surprise_attack_setup():
	# GameManager _ready() might have already loaded scenario via signal/rpc
	# Clear it to ensure clean load with our seed
	print("Cleaning up %d ships from _ready" % _gm.ships.size())
	for s in _gm.ships:
		if is_instance_valid(s):
			s.name = "Freed_" + s.name
			s.queue_free() # queue_free is safer? But expected immediate.
			# s.free() caused collision? 
			# Let's try name change.
	
	# Also clear children of _gm that are NOT ships?
	# _spawn_planets_visuals adds children too.
	for c in _gm.get_children():
		if c is Node2D: # Planets/Ships are Node2D
			c.name = "FreedNode_" + c.name
			c.queue_free()
	
	_gm.ships.clear()
	_gm.planet_hexes.clear()
	
	# Force process?
	await get_tree().process_frame
	# Ideally we should also free nodes, but for unit test ships list is key
	
	_gm.load_scenario("surprise_attack", 12345)
	
	# Verify Key Ships
	var defiant = _find_ship("Defiant")
	var station = _find_ship("Station Alpha")
	var stiletto = _find_ship("Stiletto")
	
	assert_not_null(defiant, "Defiant should exist")
	assert_not_null(station, "Station Alpha should exist")
	assert_not_null(stiletto, "Stiletto should exist")
	
	# Verify Docking
	assert_true(defiant.is_docked, "Defiant should start docked")
	assert_eq(defiant.docked_host, station, "Defiant should be docked at Station")
	
	# Verify Orbit
	assert_ne(station.orbit_direction, 0, "Station should be orbiting")
	
	# Verify Fiedler's alignment
	# Venemous should be P2 (Sathar - Side 1 ... Wait, side_id 1 is Sathar)
	var venemous = _find_ship("Venemous")
	assert_not_null(venemous, "Venemous should exist")
	assert_eq(venemous.side_id, 1, "Venemous should be Side 1 (Sathar)")

func _find_ship(name_sub: String):
	for s in _gm.ships:
		if s.name.contains(name_sub):
			return s
	return null
