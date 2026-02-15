extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var scenario_manager_script = load("res://Scripts/ScenarioManager.gd")
var ship_script = load("res://Scripts/Ship.gd")
var gm

func before_each():
	# Prevent auto-loading via NetworkManager
	if NetworkManager:
		NetworkManager.lobby_data["scenario"] = ""

	gm = game_manager_script.new()
	add_child_autofree(gm)

func test_surprise_attack_debuff_logic():
	# 1. Load Scenario
	gm.load_scenario("surprise_attack")
	
	# 2. Find Ships
	var station = gm._find_ship_by_name("Station Alpha")
	var defiant = gm._find_ship_by_name("Defiant")
	
	assert_not_null(station, "Station Alpha should exist")
	assert_not_null(defiant, "Defiant should exist")
	
	# 3. Verify Initial State (Docked)
	assert_true(defiant.is_docked, "Defiant should start docked")
	
	# 4. Premature Undock (Turn 1)
	# Set evacuation_turns to 1 (insufficient, needs 3)
	defiant.evacuation_turns = 1
	
	# Simulate Undock
	defiant.is_docked = false
	
	# 5. Check Debuff (Should NOT be active if logic is fixed, but IS active now)
	# We expect this to FAIL if the bug exists (Debuff active = True)
	# But wait, we want to prove it FAILS the REQUIREMENT. 
	# Requirement: Station CAN fire.
	# Current Code: Station CANNOT fire.
	
	var is_blocked = gm._check_scenario_debuffs(station, "no_fire")
	
	# START_FAIL: This assertion expects the FIX.
	# It should fail now because is_blocked will be TRUE.
	assert_false(is_blocked, "Station should still be able to fire if undocked prematurely (Turns < 3)")

func test_surprise_attack_debuff_success():
	# 1. Load Scenario
	gm.load_scenario("surprise_attack")
	var station = gm._find_ship_by_name("Station Alpha")
	var defiant = gm._find_ship_by_name("Defiant")
	
	# 2. Successful Evacuation
	defiant.evacuation_turns = 3
	defiant.is_docked = false
	
	var is_blocked = gm._check_scenario_debuffs(station, "no_fire")
	assert_true(is_blocked, "Station should be disabled after successful evacuation (Turns >= 3)")
