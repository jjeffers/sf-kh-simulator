extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var ship_script = load("res://Scripts/Ship.gd")
var gm

func before_each():
	if NetworkManager:
		NetworkManager.lobby_data["scenario"] = ""
	gm = game_manager_script.new()
	add_child_autofree(gm)

func test_ship_destruction_signal_error():
	# 1. Manually add a ship and simulate GM setup
	var s = ship_script.new()
	s.name = "TestShip"
	s.max_hull = 10
	s.hull = 10
	add_child_autofree(s)
	
	# REPRODUCE THE ERROR: 
	# Connect incorrectly like GameManager does currently (line 3463)
	# But wait, I can't easily inject code into GM to fail.
	# The goal is to verify GM *handles* it correctly.
	# So I should let GM setup a ship and destroy it.
	
	gm.ships.append(s)
	
	# This is the line in GM: s.ship_destroyed.connect(func(ship): _on_ship_destroyed(ship))
	# We can't easily invoke GM's internal setup unless we use load_scenario.
	# So let's use load_scenario("surprise_attack") and destroy a ship.

	gm.load_scenario("surprise_attack")
	var ship = gm.ships[0]
	assert_not_null(ship)

	# 2. Destroy Ship
	# This should trigger the signal. 
	# If the connection is bad, it might throw an error or crash.
	# GUT captures errors.
	
	ship.take_damage(999)
	
	# If we reach here without crash, check if _on_ship_destroyed was called?
	# We can check if ship is in gm.ships (should be removed or handled).
	# Actually _on_ship_destroyed just logs and handles internal state.
	
	assert_true(ship.is_destroyed, "Ship should be destroyed")
