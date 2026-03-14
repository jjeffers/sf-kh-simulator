extends GutTest

var campaign_manager

func before_each():
	campaign_manager = load("res://Scripts/CampaignManager.gd").new()
	add_child_autofree(campaign_manager)
	
func test_map_loading():
	# Load sync, assuming it doesn't await
	campaign_manager._load_map_data()
	
	assert_gt(campaign_manager.systems.size(), 0, "Map systems should be loaded")
	assert_gt(campaign_manager.routes.size(), 0, "Navigation routes should be loaded")
	assert_gt(campaign_manager.start_circles.size(), 0, "Sathar start circles should be loaded")
	assert_true(campaign_manager.systems.has("Prenglar"), "Prenglar should be in the map")

func test_force_initialization():
	campaign_manager._load_map_data()
	campaign_manager.start_new_campaign()
	
	var upf_count = 0
	var sathar_count = 0
	var tf_nova = null
	
	var total_sathar_ships = 0
	var total_sathar_fighters = 0
	
	for f in campaign_manager.fleets:
		if f.faction == "UPF":
			upf_count += 1
			if f.fleet_name == "Strike Force NOVA":
				tf_nova = f
		elif f.faction == "Sathar":
			sathar_count += 1
			total_sathar_ships += f.ships.size()
			for s in f.ships:
				if s["class"] == "Fighter":
					total_sathar_fighters += 1
					
	# UPF: 1 Strike Force + 1 TF Cassidine + 1 TF Prenglar + 10 Militias = 13 Fleets initially
	assert_eq(upf_count, 13, "Should initialize 13 UPF fleets")
	assert_eq(sathar_count, 2, "Should initialize 2 Sathar fleets")
	assert_not_null(tf_nova, "Strike Force NOVA should exist")
	
	# Total Sathar Ships should be 10 + 4 + 4 + 2 + 2 + 1 = 23
	assert_eq(total_sathar_ships, 24, "Total Sathar ships across fleets should be exactly 24")
	assert_eq(total_sathar_fighters, 10, "Sathar should have exactly 10 fighters total")

func test_rpc_transfer_ships():
	campaign_manager._load_map_data()
	campaign_manager.start_new_campaign()
	
	# Find a UPF fleet with more than 1 ship
	var source_idx = -1
	for i in range(campaign_manager.fleets.size()):
		if campaign_manager.fleets[i].faction == "UPF" and campaign_manager.fleets[i].ships.size() > 1:
			source_idx = i
			break
			
	assert_ne(source_idx, -1, "Should find a source fleet")
	
	var source_fleet = campaign_manager.fleets[source_idx]
	var initial_source_count = source_fleet.ships.size()
	var sys_id = source_fleet.current_system_id
	
	# Create a dummy target fleet in the same system
	var new_fleet = campaign_manager.create_new_fleet("UPF", sys_id, "Test Target Fleet")
	var target_idx = campaign_manager.fleets.size() - 1
	var initial_target_count = new_fleet.ships.size()
	assert_eq(initial_target_count, 0)
	
	# Transfer ship at index 0 and 1
	campaign_manager.rpc_transfer_ships(source_idx, target_idx, [0, 1])
	
	assert_eq(source_fleet.ships.size(), initial_source_count - 2, "Source fleet should lose 2 ships")
	assert_eq(new_fleet.ships.size(), 2, "Target fleet should gain 2 ships")

func test_rpc_create_fleet_from_transfer():
	campaign_manager._load_map_data()
	campaign_manager.start_new_campaign()
	
	# Find a UPF fleet with more than 1 ship
	var source_idx = -1
	for i in range(campaign_manager.fleets.size()):
		if campaign_manager.fleets[i].faction == "UPF" and campaign_manager.fleets[i].ships.size() > 1:
			source_idx = i
			break
			
	assert_ne(source_idx, -1, "Should find a source fleet")
	
	var source_fleet = campaign_manager.fleets[source_idx]
	var initial_source_count = source_fleet.ships.size()
	var initial_fleet_count = campaign_manager.fleets.size()
	
	# Transfer ship at index 0
	campaign_manager.rpc_create_fleet_from_transfer(source_idx, [0], "Brand New Fleet")
	
	assert_eq(campaign_manager.fleets.size(), initial_fleet_count + 1, "Should create one new fleet")
	assert_eq(source_fleet.ships.size(), initial_source_count - 1, "Source fleet should lose 1 ship")
	
	var new_fleet = campaign_manager.fleets[campaign_manager.fleets.size() - 1]
	assert_eq(new_fleet.fleet_name, "Brand New Fleet", "New fleet should have correct name")
	assert_eq(new_fleet.ships.size(), 1, "New fleet should have 1 ship")
