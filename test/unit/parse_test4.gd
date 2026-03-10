extends SceneTree

func _init():
	var nm = load("res://Scripts/NetworkManager.gd").new()
	nm.name = "NetworkManager"
	root.add_child(nm)
	
	var cm = load("res://Scripts/CampaignManager.gd").new()
	cm.name = "CampaignManager"
	root.add_child(cm)
	
	var mm = load("res://Scripts/MainMenu.gd").new()
	root.add_child(mm)
	
	print("Pre-Lobby: ", nm.lobby_data.get("is_saved_game", false))
	
	nm.lobby_data["game_mode"] = "campaign"
	var err = nm.host_game(7000)
	print("Host game err: ", err)
	
	if cm.load_campaign("user://campaign_save2.json"):
		nm.lobby_data["is_saved_game"] = true
		nm.lobby_data["current_day"] = cm.current_day
		print("Current Day assigned: ", cm.current_day)
		nm.update_lobby_data(nm.lobby_data)
	
	print("Post-Lobby: ", nm.lobby_data.get("is_saved_game", false))
	print("Post-Lobby Day: ", nm.lobby_data.get("current_day", 0))
	
	quit()
