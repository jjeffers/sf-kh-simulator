extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var ship_script = load("res://Scripts/Ship.gd")
var hex_grid_script = load("res://Scripts/HexGrid.gd")

var gm
var station
var target

func before_each():
	gm = game_manager_script.new()
	add_child_autofree(gm)
	gm.ships.clear()
	gm.planet_hexes.clear()

func test_station_rocket_battery_range_limit():
	# Setup: Station at (0,0,0)
	station = ship_script.new()
	station.name = "Station Alpha"
	station.grid_position = Vector3i(0, 0, 0)
	station.side_id = 1
	station.configure_space_station() # Should set RB range to 3
	if station.get_parent() == null:
		gm.add_child(station)
		gm.ships.append(station)
	
	# Setup: Target at Range 10 (10, 0, -10)
	target = ship_script.new()
	target.name = "Target Ship"
	target.grid_position = Vector3i(10, 0, -10)
	target.side_id = 2
	if target.get_parent() == null:
		gm.add_child(target)
		gm.ships.append(target)
	
	# Verify Distance
	var dist = hex_grid_script.hex_distance(station.grid_position, target.grid_position)
	assert_eq(dist, 10, "Distance should be 10")
	
	# 2. EXPLOIT ATTEMPT: Call execute_commit_combat directly
	# This simulates a client sending a "valid" looking packet for an invalid weapon
	# Weapon Index 0 = Rocket Battery (configured in Setup)
	# Wait, check weapon indices.
	# Station Config: matches Ship.gd?
	# Station has: Laser Battery (0), Rocket Battery (1) or similar?
	# Let's find index of Rocket Battery
	var rb_idx = -1
	for i in range(station.weapons.size()):
		if station.weapons[i]["type"] == "Rocket Battery":
			rb_idx = i
			break
			
	assert_ne(rb_idx, -1, "Station should have Rocket Batteries")
	
	var attack_packet = [ {
		"s": station.name,
		"t": target.name,
		"w": rb_idx,
		"tp": target.position
	}]
	
	# Execute
	gm.current_phase = gm.Phase.COMBAT
	gm.firing_side_id = 1
	gm.execute_commit_combat(attack_packet, 12345)
	
	# Verify Result
	# If bug exists, pending_resolutions has an item, OR it processed and hit.
	# We want to wait for processing? _process_next_attack is async-ish.
	await gm.get_tree().process_frame
	await gm.get_tree().process_frame
	
	# How to verify hit? Logs? Or Hull damage?
	# Target hull starts at default (e.g. 15 or 40).
	# Rocket Battery 2d10. 
	# If it hit, hull < max.
	
	# BUT... we want to FIX it. So we expect NO damage.
	# Currently, it WILL damage.
	
	# FIXED: Assert NO damage
	assert_eq(target.hull, target.max_hull, "Fix Verified: Target took NO damage from out-of-range Rocket Battery")
