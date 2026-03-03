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
	assert_eq(sathar_count, 3, "Should initialize 3 Sathar fleets")
	assert_not_null(tf_nova, "Strike Force NOVA should exist")
	
	# Total Sathar Ships should be 25 + 8 + 15 + 7 + 8 + 4 = 67
	assert_eq(total_sathar_ships, 67, "Total Sathar ships across fleets should be exactly 67")
	assert_eq(total_sathar_fighters, 25, "Sathar should have exactly 25 fighters total")
