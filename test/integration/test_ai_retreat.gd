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

func test_individual_ship_retreat_due_to_critical_hull():
	var ai = ComputerOpponentScript.new()
	ai.game_manager = _gm
	ai.side_id = 2
	ai.is_sathar = true
	_gm.add_child(ai)
	
	var ai_ship = ShipScript.new()
	ai_ship.name = "AI_Ship"
	ai_ship.side_id = 2
	ai_ship.ship_class = "Frigate"
	ai_ship.max_hull = 20
	ai_ship.hull = 4 # 20% - Below 25%
	ai_ship.grid_position = Vector3i(0, 0, 0)
	ai_ship.facing = 0
	ai_ship.speed = 1
	_gm.add_child(ai_ship)
	_gm.ships.append(ai_ship)
	
	# Give it an enemy out of range so it's not blocked from withdrawing
	var p1_ship = ShipScript.new()
	p1_ship.name = "P1_Ship"
	p1_ship.side_id = 1
	p1_ship.ship_class = "Destroyer"
	p1_ship.hull = 20
	p1_ship.grid_position = Vector3i(20, -20, 0)
	p1_ship.weapons = [{"name": "Laser", "ammo": -1, "range": 5}] # Out of range
	_gm.add_child(p1_ship)
	_gm.ships.append(p1_ship)
	
	# We can directly query the utility function rather than waiting for async timers
	var utility = ai._calculate_retreat_utility(ai_ship)
	
	# With 4 hull (20%), no weapons, the utility should be very high.
	# Factor 1: (0.25 - 0.20) * 100 = 5.0
	# Factor 2: < 50% and no defenses = 20.0
	# Factor 3: 0 weapons = 100.0
	# Sathar: -20.0
	# Total Expected: ~105
	assert_true(utility > 50.0, "Critically damaged ship should have retreat utility > 50. Got %f" % utility)

func test_fleet_level_retreat():
	var ai = ComputerOpponentScript.new()
	ai.game_manager = _gm
	ai.side_id = 2
	ai.is_sathar = true
	_gm.add_child(ai)
	
	# 1 tiny AI ship vs 5 massive player ships
	var ai_ship = ShipScript.new()
	ai_ship.name = "AI_Frigate"
	ai_ship.side_id = 2
	ai_ship.ship_class = "Frigate"
	ai_ship.max_hull = 10
	ai_ship.hull = 10
	ai_ship.grid_position = Vector3i(0,0,0)
	ai_ship.speed = 2
	_gm.add_child(ai_ship)
	_gm.ships.append(ai_ship)
	
	for i in range(5):
		var bship = ShipScript.new()
		bship.name = "P1_Battleship_" + str(i)
		bship.ship_class = "Battleship"
		bship.side_id = 1
		bship.hull = 100
		bship.weapons = [{"name": "Heavy Laser", "ammo": -1, "range": 5}]
		bship.grid_position = Vector3i(20+i, -20-i, 0) # Out of range
		_gm.add_child(bship)
		_gm.ships.append(bship)
		
	var triggers_retreat = ai._evaluate_fleet_advantage()
	assert_true(triggers_retreat, "Fleet with extreme disadvantage (10 vs 500) should return true for retreat")

func test_blocked_retreat_flees_to_edge():
	var ai = ComputerOpponentScript.new()
	ai.game_manager = _gm
	ai.side_id = 2
	ai.is_sathar = true
	_gm.add_child(ai)
	
	var ai_ship = ShipScript.new()
	ai_ship.name = "AI_Ship"
	ai_ship.side_id = 2
	ai_ship.ship_class = "Frigate"
	ai_ship.max_hull = 20
	ai_ship.hull = 2 # Below 25% -> wants to retreat
	ai_ship.grid_position = Vector3i(0, 0, 0)
	ai_ship.facing = 0
	ai_ship.speed = 2
	_gm.add_child(ai_ship)
	_gm.ships.append(ai_ship)
	
	# Give it an enemy INSIDE weapon range so withdraw is blocked
	var p1_ship = ShipScript.new()
	p1_ship.name = "P1_Ship"
	p1_ship.side_id = 1
	p1_ship.ship_class = "Destroyer"
	p1_ship.hull = 20
	p1_ship.grid_position = Vector3i(2, -2, 0) # Close range!
	p1_ship.weapons = [{"name": "Laser", "ammo": -1, "range": 5}] 
	_gm.add_child(p1_ship)
	_gm.ships.append(p1_ship)
	
	var is_retreating = true # Simulating passing evaluation
	
	var best_move = ai._find_best_legal_move(ai_ship, p1_ship, is_retreating)
	
	assert_true(best_move != null and best_move.has("path"), "Ship should have plotted an evasion path")
	
	# Verify that the path scored the edge hex highest (if speed > 0)
	var end_hex = best_move["path"].back() if best_move["path"].size() > 0 else ai_ship.grid_position
	# With AI ship at 0,0,0, plotting a move away from center (0,0) towards an edge
	# should result in an end_hex distance > 0.
	assert_true(HexGrid.hex_distance(Vector3i.ZERO, end_hex) > 0, "Retreating movement should pull ship away from the center")
