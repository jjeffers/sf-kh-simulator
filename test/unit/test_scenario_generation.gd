extends GutTest

func test_generate_scenario_ships():
	var key = "surprise_attack"
	var data = ScenarioManager.generate_scenario(key, 12345)
	var ships = data.get("ships", [])
	
	assert_gt(ships.size(), 0, "Scenario should generate ships")
	
	var station = ships[0]
	assert_eq(station.get("name"), "Station Alpha", "First ship should be Station Alpha")
	
	var key2 = "the_last_stand"
	var data2 = ScenarioManager.generate_scenario(key2, 67890)
	var ships2 = data2.get("ships", [])
	assert_gt(ships2.size(), 0, "The Last Stand should generate ships")
