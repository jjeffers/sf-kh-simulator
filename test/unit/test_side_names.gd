extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ScenarioManagerScript = preload("res://Scripts/ScenarioManager.gd")
var NetworkManagerScript = preload("res://Scripts/NetworkManager.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	
	# Mock Lobby Data for Side Names
	NetworkManager.lobby_data = {
		"scenario": "surprise_attack",
		"teams": {},
		"ship_assignments": {},
		"player_numbers": {}
	}

func after_each():
	_gm.free()

func test_get_side_name_returns_correct_name():
	# Side 1 = Index 0 = "Sathar" (for surprise_attack)
	var name1 = _gm.get_side_name(1)
	assert_eq(name1, "Sathar", "Side 1 should be Sathar")
	
	# Side 2 = Index 1 = "UPF" (for surprise_attack)
	var name2 = _gm.get_side_name(2)
	assert_eq(name2, "UPF", "Side 2 should be UPF")
	
func test_get_side_name_fallback():
	var name99 = _gm.get_side_name(99)
	assert_eq(name99, "Side 99", "Invalid side should return fallback")
