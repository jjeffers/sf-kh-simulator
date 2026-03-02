extends GutTest

var game_manager
var scenario_manager 

func before_each():
	game_manager = load("res://Scripts/GameManager.gd").new()
	add_child_autofree(game_manager)

func test_campaign_scenario_generation():
	# We want to check Campaign Tactical Deployment Rules
	var rules = ScenarioManager.get_scenario("campaign_encounter")
	assert_not_null(rules, "campaign_encounter scenario should exist")
	
	NetworkManager.lobby_data["scenario"] = "campaign_encounter"
	
	var valid_attacker_hexes = ScenarioManager.get_valid_deployment_hexes(2, [], [])
	# Attackers deploy at exactly 34 hexes.
	# A hexagon ring of radius R has 6*R hexes. Let's verify size.
	# 6 * 34 = 204 hexes.
	assert_eq(valid_attacker_hexes.size(), 204, "Attackers should have exactly 204 valid deployment hexes in a 34 radius ring")
	
	for hex in valid_attacker_hexes:
		var dist = HexGrid.hex_distance(Vector3i.ZERO, hex)
		if dist != 34:
			assert_true(false, "Found invalid attacker deployment hex at distance %d" % dist)
			break
	
	var valid_defender_hexes = ScenarioManager.get_valid_deployment_hexes(1, [], [])
	# Defenders deploy anywhere < 34. Total hexes in radius R is 3*R*(R+1) + 1
	# R = 33 -> 3 * 33 * 34 + 1 = 3367
	assert_eq(valid_defender_hexes.size(), 3367, "Defenders should have exactly 3367 valid deployment hexes (radius 33)")
