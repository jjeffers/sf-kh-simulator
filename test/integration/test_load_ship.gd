extends GutTest

func test_load_ship():
	var S = load("res://Scripts/Ship.gd")
	if S == null:
		print("FAILED TO LOAD SHIP.GD")
		fail_test("Failed to load Ship.gd")
	else:
		print("SUCCESSFULLY LOADED SHIP.GD")
		pass_test("Successfully loaded Ship.gd")
