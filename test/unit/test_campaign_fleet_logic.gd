extends GutTest

var campaign_mgr

func before_each():
	campaign_mgr = preload("res://Scripts/CampaignManager.gd").new()
	campaign_mgr.name = "CampaignManager"
	get_tree().root.add_child(campaign_mgr)
	campaign_mgr._load_map_data()
	
func after_each():
	if is_instance_valid(campaign_mgr):
		campaign_mgr.queue_free()
	
func test_fleet_movement_and_arrival():
	# Manually spawn fleets for testing
	var fleet1 = campaign_mgr.create_new_fleet("UPF", "Prenglar", "TF 1")
	# Force a short move that takes 5 days (hardcoded into CampaignFleet.start_move normally)
	var started = campaign_mgr.order_fleet_move(fleet1, "Cassidine")
	assert_true(started, "Fleet should be allowed to move to a connected system")
	
	assert_eq(fleet1.current_system_id, "Prenglar", "Fleet current system should not change until arrival")
	assert_true(fleet1.is_moving(), "Fleet should be moving")
	
	# Advance 4 days
	for i in range(4):
		campaign_mgr.end_turn()
		
	assert_true(fleet1.is_moving(), "Fleet should still be moving after 4 days")
	
	# Advance 5th day
	campaign_mgr.end_turn()
	
	assert_false(fleet1.is_moving(), "Fleet should arrive after 5 days")
	assert_eq(fleet1.current_system_id, "Cassidine", "Fleet should now be at Cassidine")
	
func test_fleet_splitting_merging():
	# Not strictly managed by Fleet, but UI normally. I can test properties.
	var fleet1 = campaign_mgr.create_new_fleet("UPF", "Prenglar", "TF 1")
	fleet1.add_ship({"name": "Ship 1", "class": "Fighter"})
	fleet1.add_ship({"name": "Ship 2", "class": "Frigate"})
	
	var fleet2 = campaign_mgr.create_new_fleet("UPF", "Prenglar", "TF 2")
	
	# Simulate merge logic
	var ships_to_transfer = fleet1.ships.duplicate()
	for s in ships_to_transfer:
		fleet1.remove_ship(s)
		fleet2.add_ship(s)
		
	assert_eq(fleet1.get_ship_count(), 0, "Fleet 1 should be empty")
	assert_eq(fleet2.get_ship_count(), 2, "Fleet 2 should have both ships")
