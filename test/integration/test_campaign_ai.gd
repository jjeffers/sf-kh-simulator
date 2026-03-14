extends GutTest

var campaign_manager: Node

func before_each():
	campaign_manager = load("res://Scripts/CampaignManager.gd").new()
	campaign_manager.name = "CampaignManager"
	add_child(campaign_manager)
	
	# Stub NetworkManager
	var nm = get_tree().root.get_node_or_null("NetworkManager")
	if not nm:
		nm = Node.new()
		nm.name = "NetworkManager"
		nm.set("lobby_data", {"teams": {}})
		get_tree().root.add_child(nm)
	else:
		nm.lobby_data["teams"] = {}
	
	# Needs to load the map to initialize systems
	campaign_manager._ready()
	
func after_each():
	if is_instance_valid(campaign_manager):
		campaign_manager.queue_free()
	var nm = get_tree().root.get_node_or_null("NetworkManager")
	if nm and not nm.has_method("sync_campaign_state"):
		# Only free it if it's our raw Node stub
		get_tree().root.remove_child(nm)
		nm.free()

func test_ai_instantiation():
	# Since NetworkManager teams is empty, starting a new campaign should spawn two AIs
	campaign_manager.start_new_campaign()
	
	var has_upf = false
	var has_sathar = false
	
	for child in campaign_manager.get_children():
		if child.name.begins_with("CampAI_"):
			if child.faction == "UPF": has_upf = true
			if child.faction == "Sathar": has_sathar = true
			
	assert_true(has_upf, "UPF AI should have been instantiated.")
	assert_true(has_sathar, "Sathar AI should have been instantiated.")

func test_sathar_ai_queues_repairs():
	campaign_manager.start_new_campaign()
	
	# Retrieve the Sathar AI
	var ai = null
	for child in campaign_manager.get_children():
		if child.name == "CampAI_Sathar":
			ai = child
			break
			
	assert_not_null(ai, "Sathar AI missing.")
	
	var f = campaign_manager.create_new_fleet("Sathar", "Dixon's Star", "Test Fleet")
	campaign_manager.systems["Dixon's Star"]["is_scc"] = true
	campaign_manager.systems["Dixon's Star"]["occupying_faction"] = "Sathar"
	
	var s = load("res://Scripts/Ship.gd").new()
	s.configure_heavy_cruiser()
	s.name = "Test HC"
	s.hull = 10
	s.max_hull = 100 # Severe damage (< 50%)
	f.ships.append({"name": s.name, "hull": s.hull, "max_hull": s.max_hull, "class": s.ship_class})
	
	var start_q_size = campaign_manager.sathar_repair_queue.size()
	
	ai._execute_repairs()
	
	assert_eq(f.ships.size(), 0, "Critically damaged ship should be removed from active fleet.")
	assert_eq(campaign_manager.sathar_repair_queue.size(), start_q_size + 1, "Ship should be placed in repair queue.")

func test_upf_ai_consumes_scc_capacity():
	campaign_manager.start_new_campaign()
	
	# Retrieve UPF AI
	var ai = null
	for child in campaign_manager.get_children():
		if child.name == "CampAI_UPF":
			ai = child
			break
			
	assert_not_null(ai, "UPF AI missing.")
	
	var f = campaign_manager.create_new_fleet("UPF", "Prenglar", "Test Fleet")
	campaign_manager.systems["Prenglar"]["is_scc"] = true
	var cap = campaign_manager.UPF_SCC_CAPACITIES["Prenglar"]
	
	var s1 = {"name": "Test1", "hull": 80, "max_hull": 100, "unrepairable_adf_modifier": 1} # Critical sys
	var s2 = {"name": "Test2", "hull": 90, "max_hull": 100} # Hull only
	
	f.ships.append(s1)
	f.ships.append(s2)
	
	ai._execute_repairs()
	
	var used = campaign_manager.upf_scc_capacity_used.get("Prenglar", 0)
	assert_eq(used, cap, "UPF AI should have consumed exactly its daily capacity.")
	assert_eq(s1["unrepairable_adf_modifier"], 0, "Critical ADF should be repaired.")
	assert_eq(s2["hull"], 90, "Hull should not be repaired because capacity was exhausted by critical repairs.")
