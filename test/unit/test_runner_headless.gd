extends SceneTree

func _init():
	var args = OS.get_cmdline_args()
	var mode = ""
	for a in args:
		if a == "run_host_only": mode = "host"
		if a == "run_client_bot": mode = "client"
		
	# Delay execution so autoloads finish setting up first if godot initialized them
	await create_timer(1.0).timeout
		
	if mode == "host":
		print("[Headless] Running Host Only...")
		NetworkManager.lobby_data["scenario"] = "surprise_attack"
		NetworkManager.host_game(7000)
		NetworkManager.lobby_data["is_headless_test"] = true
		
		var gm_scene = load("res://Scenes/Main.tscn").instantiate()
		root.add_child(gm_scene)
		
		# Watch for combat end to auto-quit
		gm_scene.game_over.connect(func(_w): quit())
		
	elif mode == "client":
		print("[Headless] Running Client Bot...")
		NetworkManager.join_game("127.0.0.1", 7000)
		
		var gm_scene = load("res://Scenes/Main.tscn").instantiate()
		root.add_child(gm_scene)
		
		# Give it a moment to connect
		await create_timer(1.0).timeout
		NetworkManager.rpc_id(1, "request_team_change", 2)
		
		# Watch for combat end to auto-quit
		gm_scene.game_over.connect(func(_w): quit())
