extends GutTest

var campaign_manager: Node

func before_each():
	campaign_manager = load("res://Scripts/CampaignManager.gd").new()
	add_child(campaign_manager)
	await get_tree().process_frame

func after_each():
	if is_instance_valid(campaign_manager):
		campaign_manager.queue_free()

func test_ship_name_exhaustion():
	# Manually force a tiny names database to test rapid exhaustion
	campaign_manager._ship_names_data = {
		"UPF_Fleet": {
			"Prefix": "UPFS",
			"Assault_Scouts": ["Pioneer", "Explorer", "Voyager"]
		}
	}
	
	# The first 3 generated names MUST be from the list (in any random order)
	var generated_names = []
	for i in range(3):
		var name = campaign_manager._generate_ship_name("UPF", "Assault Scout")
		generated_names.append(name)
		
	assert_true(generated_names.has("UPFS Pioneer"), "List should output Pioneer")
	assert_true(generated_names.has("UPFS Explorer"), "List should output Explorer")
	assert_true(generated_names.has("UPFS Voyager"), "List should output Voyager")
	
	# The 4th generation MUST fallback to sequential
	var fb1 = campaign_manager._generate_ship_name("UPF", "Assault Scout")
	assert_eq(fb1, "UPFS Assault Scout 1", "Fallback 1 should trigger correctly")
	
	# The 5th generation MUST increment correctly
	var fb2 = campaign_manager._generate_ship_name("UPF", "Assault Scout")
	assert_eq(fb2, "UPFS Assault Scout 2", "Fallback 2 should trigger correctly")
	
	# A completely unknown class should fallback immediately to 1
	var unknown = campaign_manager._generate_ship_name("UPF", "Dreadnought")
	assert_eq(unknown, "UPFS Dreadnought 1", "Missing class should fallback to 1")
	
	# A completely unknown faction should fallback using the raw faction string
	var alien = campaign_manager._generate_ship_name("GOG", "Fighter")
	assert_eq(alien, "GOG Fighter 1", "Missing faction should fallback using raw faction name")
