extends GutTest

var _gm = null
var ShipScript = null

func before_all():
	var GM_Script = load("res://Scripts/GameManager.gd")
	_gm = GM_Script.new()
	ShipScript = load("res://Scripts/Ship.gd")
	add_child(_gm)
	# _gm.ships is initialized in declaration, no need to assign [] which causes type error
	# if we want to clear:
	_gm.ships.clear()

func after_all():
	_gm.queue_free()

func before_each():
	_gm.ships.clear()
	_gm.current_phase = _gm.Phase.MOVEMENT
	_gm.my_side_id = 1
	_gm.current_side_id = 1

func test_teleport_exploit():
	# Setup Ship
	var ship = ShipScript.new()
	ship.name = "TestShip"
	ship.side_id = 1
	ship.grid_position = Vector3i(0, 0, 0)
	ship.speed = 2
	ship.adf = 1
	_gm.ships.append(ship)
	_gm.add_child(ship)
	
	# Create an Invalid Path (Teleportation)
	# Jump from 0,0,0 to 10,10,-20 directly
	var invalid_path = [Vector3i(10, 10, -20)]
	var final_facing = 0
	
	# Execute Commit (Simulating RPC)
	# We call execute_commit_move directly as if it came from RPC
	_gm.execute_commit_move(ship.name, invalid_path, final_facing, 0, false)
	
	# ASSERTION: 
	# Desired (Fixed): The ship should stay at (0, 0, 0) because the move was rejected.
	assert_eq(ship.grid_position, Vector3i(0, 0, 0), "Fix Verified: Ship remained at start position after invalid teleport")

func test_speed_limit_exploit():
	# Setup Ship with Speed 2, ADF 1. Max Speed = 3.
	var ship = ShipScript.new()
	ship.name = "TestShip"
	ship.side_id = 1
	ship.grid_position = Vector3i(0, 0, 0)
	ship.speed = 2
	ship.adf = 1
	_gm.ships.append(ship)
	_gm.add_child(ship)
	
	# Create Path that is valid adjacency but too long (Speed 5)
	# 0,0,0 -> 1,0,-1 -> 2,0,-2 -> 3,0,-3 -> 4,0,-4 -> 5,0,-5
	var path = []
	for i in range(1, 6):
		path.append(Vector3i(i, 0, -i))
		
	_gm.execute_commit_move(ship.name, path, 0, 0, false)
	
	# Fix Verified: Ship rejects speed 5, remains at speed 2
	assert_eq(ship.speed, 2, "Fix Verified: Ship speed remained unchanged (2) after invalid acceleration")
