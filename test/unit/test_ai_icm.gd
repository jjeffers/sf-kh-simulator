extends GutTest

var game_manager: GameManager
var attacker: Ship
var target: Ship
var ai: ComputerOpponent

func before_each():
	game_manager = GameManager.new()
	add_child_autofree(game_manager)
	
	# Setup Network mock
	if not game_manager.has_node("NetworkManager"):
		var nm = Node.new()
		nm.name = "NetworkManager"
		game_manager.add_child(nm)
		nm.set("lobby_data", {"teams": {1: 1}}) # Peer 1 is Side 1
	
	game_manager.my_side_id = 1
	
	attacker = autofree(Ship.new())
	attacker.name = "Attacker"
	attacker.side_id = 1
	game_manager.ships.append(attacker)
	
	target = autofree(Ship.new())
	target.name = "Target"
	target.side_id = 2
	target.hull = 100
	target.max_hull = 100
	target.icm_max = 5
	target.icm_current = 5
	game_manager.ships.append(target)
	
	ai = autofree(ComputerOpponent.new())
	ai.name = "ComputerOpponent_Side2"
	ai.side_id = 2
	ai.game_manager = game_manager
	game_manager.computer_opponents.append(ai)
	game_manager.add_child(ai)

func test_torpedo_prioritization():
	# Chance is 30%. Torpedo reduces 10% per ICM.
	# Requires 2 ICMs to get under 15%.
	var eligible = [target]
	var icm_script = load("res://Scripts/AutoIcmProcessor.gd")
	var allocs = icm_script.calculate_allocations("Torpedo", 30, target, eligible)
	
	assert_true(allocs.has("Target"), "Target should allocate ICMs")
	if allocs.has("Target"):
		assert_eq(allocs["Target"], 2, "Should allocate exactly 2 ICMs to reduce Torpedo from 30% to 10%")

func test_rocket_battery_ignored_when_healthy():
	# Chance is 60%. RB reduces 3% per ICM.
	# Target hull is 100 (healthy > 25%). AI should ignore it.
	var eligible = [target]
	var icm_script = load("res://Scripts/AutoIcmProcessor.gd")
	var allocs = icm_script.calculate_allocations("Rocket", 60, target, eligible)
	assert_true(allocs.is_empty(), "Healthy ship should not waste ICMs on Rocket Batteries")

func test_rocket_battery_defended_when_critical():
	target.max_hull = 100
	target.hull = 20 # Critically damaged
	
	# Chance 55%. AI wants it under 50% = 5% reduction. RB is 3% each.
	# Needs 2 ICMs.
	var eligible = [target]
	var icm_script = load("res://Scripts/AutoIcmProcessor.gd")
	var allocs = icm_script.calculate_allocations("Rocket", 55, target, eligible)
	assert_true(allocs.has("Target"), "Critically damaged ship should defend against rockets")
	if allocs.has("Target"):
		assert_eq(allocs["Target"], 2, "Should allocate exactly 2 ICMs")

func test_assault_rocket_always_defended_high_chance():
	# Chance 40%. Want < 30%. Needs 10% reduction.
	# AR is 5% each. Needs 2 ICMs.
	var eligible = [target]
	var icm_script = load("res://Scripts/AutoIcmProcessor.gd")
	var allocs = icm_script.calculate_allocations("Assault Rocket", 40, target, eligible)
	assert_true(allocs.has("Target"), "Should defend against high chance ARs")
	if allocs.has("Target"):
		assert_eq(allocs["Target"], 2, "Should allocate 2 ICM")
