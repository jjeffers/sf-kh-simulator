extends GutTest

var game_manager_script = load("res://Scripts/GameManager.gd")
var ship_script = load("res://Scripts/Ship.gd")
var gm

func before_each():
	# Prevent GameManager from auto-loading "surprise_attack" (default in NetworkManager)
	if NetworkManager:
		NetworkManager.lobby_data["scenario"] = ""
		
	gm = game_manager_script.new()
	add_child_autofree(gm)
	# Manually trigger _ready if needed, but add_child does it.
	# However, we need to ensure UI is set up.

func after_each():
	pass

func test_ship_list_filtering_sathar_passive_fire():
	# Setup Ships
	var s1 = ship_script.new()
	s1.side_id = 1
	s1.name = "UPF_Ship"
	gm.ships.append(s1)
	
	var s2 = ship_script.new()
	s2.side_id = 2
	s2.name = "Sathar_Ship"
	gm.ships.append(s2)
	
	# Scenario: Side 1 (UPF) moved. Now Side 2 (Sathar) is firing in Passive Phase.
	# This means current_side_id was 1
	gm.current_side_id = 1
	
	# Set Player Identity as Sathar (2)
	gm.my_side_id = 2
	
	# Start Passive Combat
	gm.start_combat_passive()
	# logic: firing_side_id = 3 - current_side_id = 2
	
	assert_eq(gm.firing_side_id, 2, "Firing side should be Sathar (2)")
	
	# Force UI update (it should have happened in start_combat_passive)
	# Check container_ships
	
	var items = gm.container_ships.get_children()
	assert_gt(items.size(), 0, "Should have items in ship list")
	
	for btn in items:
		gut.p("Button Text: " + btn.text)
		if btn.text.contains("Sathar_Ship"):
			assert_true(true, "Found Sathar Ship")
		elif btn.text.contains("UPF_Ship"):
			assert_true(false, "Found UPF Ship in Sathar List!")
		else:
			assert_true(false, "Found Unknown Ship: " + btn.text)

func test_ship_list_filtering_upf_active_fire():
	# Setup Ships
	var s1 = ship_script.new()
	s1.side_id = 1
	s1.name = "UPF_Ship"
	gm.ships.append(s1)
	
	var s2 = ship_script.new()
	s2.side_id = 2
	s2.name = "Sathar_Ship"
	gm.ships.append(s2)

	# Scenario: Side 1 (UPF) is the ACTIVE player.
	gm.current_side_id = 1
	gm.my_side_id = 1
	
	# Active Fire Phase
	gm.start_combat_active()
	# logic: firing_side_id = current_side_id = 1
	
	assert_eq(gm.firing_side_id, 1, "Firing side should be UPF (1)")
	
	var items = gm.container_ships.get_children()
	assert_gt(items.size(), 0, "Should have items in ship list")
	
	for btn in items:
		gut.p("Button Text: " + btn.text)
		if btn.text.contains("UPF_Ship"):
			assert_true(true, "Found UPF Ship")
		elif btn.text.contains("Sathar_Ship"):
			assert_true(false, "Found Sathar Ship in UPF List!")
