extends SceneTree

func _init():
	print("[TEST] Starting script without changing active scene...")
	# Simulate what happens after Lobby Data assigns the path
	var path = "user://campaign_save2.json"
	
	var res = CampaignManager.load_campaign(path)
	print("[TEST] Return value of load_campaign: ", res)
	
	quit()
