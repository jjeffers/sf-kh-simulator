extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)

func after_each():
	_gm.free()

func test_load_surprise_attack_planets():
	# ScenarioManager has "surprise_attack" with planets: [Vector3i(0,0,0)]
	# GameManager._load_planets_from_scenario should populate planet_hexes
	_gm._load_planets_from_scenario("surprise_attack")
	
	assert_eq(_gm.planet_hexes.size(), 1, "Should have 1 planet")
	if _gm.planet_hexes.size() > 0:
		assert_eq(_gm.planet_hexes[0], Vector3i(0, 0, 0), "Planet should be at center")

func test_spawn_visuals():
	# Verify visual nodes created
	_gm._load_planets_from_scenario("surprise_attack")
	
	var planet_nodes = []
	for c in _gm.get_children():
		if c.name.begins_with("Planet_"):
			planet_nodes.append(c)
			
	assert_eq(planet_nodes.size(), 1, "Should spawn 1 planet sprite")
	if planet_nodes.size() > 0:
		var p = planet_nodes[0] as Sprite2D
		assert_not_null(p, "Should be Sprite2D")
		assert_not_null(p.texture, "Should have texture")
