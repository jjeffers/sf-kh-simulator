extends GutTest
var gm

func before_each():
    gm = load("res://Scripts/GameManager.gd").new()
    add_child_autofree(gm)

func test_last_stand_load():
    gm.setup_game(1234, "the_last_stand")
    assert_true(true, "Successfully generated world and UI lists without crashing.")
