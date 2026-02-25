extends GutTest

var ScenarioManagerScript = preload("res://Scripts/ScenarioManager.gd")

func test_generate_scenario_deterministic():
	# With same seed, should get same result
	var seed1 = 12345
	var scen1 = ScenarioManagerScript.generate_scenario("surprise_attack", seed1)
	var scen2 = ScenarioManagerScript.generate_scenario("surprise_attack", seed1)
	
	# Check Station Position
	var station1 = scen1["ships"][0]["position"]
	var station2 = scen2["ships"][0]["position"]
	assert_eq(station1, station2, "Station position should be deterministic")
	
	# Check Venemous Position
	# Venemous is usually index 3 (Station, Defiant, Stiletto, Venemous) based on append order
	var ven1 = scen1["ships"][3]["position"]
	var ven2 = scen2["ships"][3]["position"]
	assert_eq(ven1, ven2, "Venemous position should be deterministic")

func test_generate_scenario_random():
	# With different seeds, likely different results
	# (Note: Small chance of collision, but unlikely for full state)
	var seed1 = 12345
	var seed2 = 99999
	
	var scen1 = ScenarioManagerScript.generate_scenario("surprise_attack", seed1)
	var scen2 = ScenarioManagerScript.generate_scenario("surprise_attack", seed2)
	
	# We can't guarantee every property is different, but the overall state should differ.
	# Let's check Venemous Pos (Random Edge) or Orbit Direction.
	# Station Pos is now Vector3i.ZERO (deterministic) for manual setup.
	var v1 = scen1["ships"][3]["position"]
	var v2 = scen2["ships"][3]["position"]
	var o1 = scen1["ships"][0]["orbit_direction"]
	var o2 = scen2["ships"][0]["orbit_direction"]
	
	var changed = (v1 != v2) or (o1 != o2)
	assert_true(changed, "Different seeds should produce different scenarios")
