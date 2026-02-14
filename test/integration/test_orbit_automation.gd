extends GutTest

var _gm = null
var ShipScript = null

func before_all():
	var GM_Script = load("res://Scripts/GameManager.gd")
	_gm = GM_Script.new()
	ShipScript = load("res://Scripts/Ship.gd")
	add_child(_gm)
	_gm.ships = []

func after_all():
	_gm.queue_free()

func before_each():
	# Clear existing ships (Children and Array)
	for child in _gm.get_children():
		if child is Ship: # Check if it's a ship
			child.queue_free()
	_gm.ships.clear()
	
	_gm.current_side_id = 1
	_gm.my_side_id = 1
	_gm.current_phase = _gm.Phase.MOVEMENT
	
	# Setup Offline Peer to allow RPCs with "call_local" to work
	var peer = OfflineMultiplayerPeer.new()
	_gm.multiplayer.multiplayer_peer = peer

func test_auto_orbit_authority_logic():
	# Setup Station in Orbit
	var station = ShipScript.new()
	station.name = "Station"
	station.ship_class = "Space Station"
	station.side_id = 1
	station.grid_position = Vector3i(0, 0, 0)
	station.orbit_direction = 1 # CW
	station.adf = 0
	station.mr = 0
	station.speed = 0
	_gm.ships.append(station)
	_gm.add_child(station)
	
	# Add Planet Hex at (1, -1, 0) (Adjacent to 0,0,0)
	_gm.planet_hexes.append(Vector3i(1, -1, 0))

	# Trigger Phase - Should Auto-Orbit Instantly
	_gm.start_movement_phase()
	
	# Allow minimal time for signal/RPC processing
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Assert: Station should have moved
	assert_true(station.has_moved, "Station should have completed auto-orbit move instantly")

func test_auto_orbit_race_condition_protection():
	# Setup Station
	var station = ShipScript.new()
	station.name = "Station"
	station.ship_class = "Space Station"
	station.side_id = 1
	station.grid_position = Vector3i(0, 0, 0)
	station.orbit_direction = 1
	_gm.ships.append(station)
	_gm.add_child(station)
	
	# Add Planet Hex
	_gm.planet_hexes.append(Vector3i(1, -1, 0))
	
	_gm.my_side_id = 1
	_gm.current_side_id = 1
	
	# Call start
	_gm.start_movement_phase()
	
	# IMMEDIATELY change selection or state to simulate race
	# E.g. Disconnect or Turn End
	_gm.current_side_id = 2 # Changed turn!
	_gm.selected_ship = null
	
	await get_tree().create_timer(1.2).timeout
	
	# Assert: Should NOT have crashed, and should NOT have committed move for wrong side.
	# We assert that selected_ship is STILL null (meaning auto-orbit didn't force-reset it after invalidation)
	assert_null(_gm.selected_ship, "Selected ship should remain null due to race condition cancellation")
