extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var ComputerOpponentScript = preload("res://Scripts/ComputerOpponent.gd")
var ShipScript = preload("res://Scripts/Ship.gd")
var HexGrid = preload("res://Scripts/HexGrid.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm.my_side_id = 1
	_gm.current_side_id = 1
	_gm.is_headless = true

func after_each():
	_gm.free()

func test_swarm_targeting():
	var ai = ComputerOpponentScript.new()
	ai.game_manager = _gm
	ai.side_id = 2
	ai.is_sathar = true
	_gm.add_child(ai)
	
	# Create 3 Fighters
	var fighters = []
	for i in range(3):
		var f = ShipScript.new()
		f.name = "Fighter_" + str(i)
		f.side_id = 2
		f.ship_class = "Fighter"
		f.grid_position = Vector3i(0, i, -i)
		f.weapons = [{"name": "Laser Battery", "ammo": -1, "range": 5, "damage": "1d10"}]
		_gm.add_child(f)
		_gm.ships.append(f)
		fighters.append(f)
		
	# Create 2 valid Targets
	var t1 = ShipScript.new()
	t1.name = "Target_1"
	t1.side_id = 1
	t1.ship_class = "Destroyer"
	t1.grid_position = Vector3i(2, 0, -2) # Closer
	_gm.add_child(t1)
	_gm.ships.append(t1)
	
	var t2 = ShipScript.new()
	t2.name = "Target_2"
	t2.side_id = 1
	t2.ship_class = "Frigate"
	t2.grid_position = Vector3i(3, 0, -3) # Further
	_gm.add_child(t2)
	_gm.ships.append(t2)
	
	var attacks = ai._plan_combat()
	assert_eq(attacks.size(), 3, "All 3 fighters should have planned an attack")
	
	# All fighters should target the exact same ship due to the Swarm multiplier
	var primary_target = attacks[0]["t"]
	for attack in attacks:
		assert_eq(attack["t"], primary_target, "All fighters should utilize Swarm Bonus to focus fire on the same target")

func test_swarm_cohesion_and_separation():
	var ai = ComputerOpponentScript.new()
	ai.game_manager = _gm
	ai.side_id = 2
	ai.is_sathar = true
	_gm.add_child(ai)
	
	# Setup two friendly fighters
	var f1 = ShipScript.new()
	f1.name = "Fighter_1"
	f1.side_id = 2
	f1.ship_class = "Fighter"
	f1.grid_position = Vector3i(0, 0, 0)
	_gm.add_child(f1)
	_gm.ships.append(f1)
	
	var f2 = ShipScript.new()
	f2.name = "Fighter_2"
	f2.side_id = 2
	f2.ship_class = "Fighter"
	f2.grid_position = Vector3i(0, 1, -1)
	_gm.add_child(f2)
	_gm.ships.append(f2)
	
	var enemy = ShipScript.new()
	enemy.name = "Enemy"
	enemy.side_id = 1
	enemy.ship_class = "Destroyer"
	enemy.grid_position = Vector3i(5, -5, 0)
	_gm.add_child(enemy)
	_gm.ships.append(enemy)

	# F1 evaluating distance hexes
	# Distance 0 to F2 (Stacked) should be penalized heavily
	var hex_stacked = Vector3i(0, 1, -1)
	var score_stacked = ai._score_hex(hex_stacked, enemy, false, f1)
	
	# Distance 1 to F2 (Cohesive) should be buffed
	var hex_adjacent = Vector3i(1, 0, -1)
	var score_adjacent = ai._score_hex(hex_adjacent, enemy, false, f1)
	
	# Distance 5 to F2 (Too far) receives no flock bonus
	var hex_far = Vector3i(0, 5, -5)
	var score_far = ai._score_hex(hex_far, enemy, false, f1)
	
	# Note: there is gaussian noise evaluated (-4.0 to +4.0 roughly), but the structural delta is
	# Stacked (-10 penalty + 5 cohesion = -5)
	# Adjacent (+5 cohesion)
	# Far (0 cohesion)
	# So Adjacent should consistently massively outscore Stacked despite noise.
	
	assert_true(score_adjacent > score_stacked, "Adjacent cohesion score should be considerably higher than stacked penalty score")
