extends Control

@onready var StartupMenu = $StartupMenu
@onready var CampaignHostMenu = $CampaignHostMenu
@onready var CampaignJoinMenu = $CampaignJoinMenu
@onready var TacticalMenu = $TacticalMenu
@onready var status_label = $StatusLabel

@onready var tactical_ip_input = $TacticalMenu/HBoxIP/TacticalIPInput
@onready var tactical_port_input = $TacticalMenu/HBoxPort/TacticalPortInput
@onready var host_button = $TacticalMenu/HostButton
@onready var join_button = $TacticalMenu/JoinButton

@onready var btn_start_campaign = $StartupMenu/BtnStartCampaign
@onready var btn_load_campaign = $StartupMenu/BtnLoadCampaign
@onready var btn_join_campaign = $StartupMenu/BtnJoinCampaign
@onready var btn_start_scenario = $StartupMenu/BtnStartScenario
@onready var btn_settings = $StartupMenu/BtnSettings
@onready var btn_quit = $StartupMenu/BtnQuit

@onready var host_ip_input = $CampaignHostMenu/HBoxIP/HostIPInput
@onready var host_port_input = $CampaignHostMenu/HBoxPort/HostPortInput
@onready var btn_host_start = $CampaignHostMenu/BtnHostStart
@onready var btn_host_back = $CampaignHostMenu/BtnHostBack

@onready var join_ip_input = $CampaignJoinMenu/HBoxIP/JoinIPInput
@onready var join_port_input = $CampaignJoinMenu/HBoxPort/JoinPortInput
@onready var btn_join_connect = $CampaignJoinMenu/BtnJoinConnect
@onready var btn_join_back = $CampaignJoinMenu/BtnJoinBack

@onready var btn_tactical_back = $TacticalMenu/BtnBack

var target_lobby_scene = "res://Scenes/Lobby.tscn"

func _ready():
	var app_name = ProjectSettings.get_setting("application/config/name", "SFKH Simulator")
	var version = ProjectSettings.get_setting("application/config/version", "Unknown")
	DisplayServer.window_set_title("%s v%s" % [app_name, version])
	
	if has_node("StartupMenu/Label"):
		$StartupMenu/Label.text = "Second Sathar War v%s" % version
	
	if not NetworkManager.disconnect_reason.is_empty():
		var reason = NetworkManager.disconnect_reason
		NetworkManager.disconnect_reason = ""
		if NetworkManager.lobby_data.get("game_mode", "") == "campaign":
			_show_menu("campaign_join")
		else:
			_show_menu("tactical")
		status_label.text = reason
	else:
		_show_menu("startup")
	
	btn_start_campaign.pressed.connect(_on_btn_start_campaign)
	btn_load_campaign.pressed.connect(_on_btn_load_campaign)
	btn_join_campaign.pressed.connect(_on_btn_join_campaign)
	btn_start_scenario.pressed.connect(_on_btn_start_scenario)
	if btn_settings:
		btn_settings.pressed.connect(_on_btn_settings)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	btn_host_start.pressed.connect(_on_campaign_host_start)
	btn_host_back.pressed.connect(func(): _show_menu("startup"))
	
	btn_join_connect.pressed.connect(_on_campaign_join_connect)
	btn_join_back.pressed.connect(func(): _show_menu("startup"))
	
	host_button.pressed.connect(_on_tactical_host)
	join_button.pressed.connect(_on_tactical_join)
	btn_tactical_back.pressed.connect(func(): _show_menu("startup"))
	
	NetworkManager.player_connected.connect(_on_connection_success)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	MusicManager.play_music("res://Assets/Audio/Orbital Siege.mp3", -12.0, 2.0)
	
	_load_last_server()
	
	# Parse Command Line for Auto-Host Testing
	var args = OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--host":
			print("[MainMenu] Auto-Hosting local match...")
			call_deferred("_on_tactical_host")
		elif args[i] == "--join":
			print("[MainMenu] Auto-Joining match...")
			if i + 1 < args.size() and not args[i+1].begins_with("--"):
				var parts = args[i+1].split(":")
				tactical_ip_input.text = parts[0]
				if parts.size() > 1 and parts[1].is_valid_int():
					tactical_port_input.text = parts[1]
			call_deferred("_on_tactical_join")
		elif args[i] == "--campaign-host":
			print("[MainMenu] Auto-Hosting Campaign...")
			
			# Check if we should load a save first
			var load_path = ""
			for j in range(args.size()):
				if args[j] == "--load-campaign" and j + 1 < args.size():
					load_path = args[j+1]
					break
					
			if not load_path.is_empty():
				print("[MainMenu] Auto-loading campaign save from: ", load_path)
				if CampaignManager.load_campaign(load_path):
					NetworkManager.lobby_data["is_saved_game"] = true
					NetworkManager.lobby_data["current_day"] = CampaignManager.current_day
					NetworkManager.lobby_data["destroyed_fortresses"] = CampaignManager.destroyed_fortresses_count
					NetworkManager.lobby_data["destroyed_stations"] = CampaignManager.destroyed_stations_count
					NetworkManager.rpc("update_lobby_data", NetworkManager.lobby_data)
				else:
					print("[MainMenu] ERROR: Failed to load campaign save from: ", load_path)
					
			call_deferred("_on_campaign_host_start")
		elif args[i] == "--campaign-join":
			print("[MainMenu] Auto-Joining Campaign...")
			if i + 1 < args.size() and not args[i+1].begins_with("--"):
				join_ip_input.text = args[i+1]
			call_deferred("_on_campaign_join_connect")
		elif args[i] == "--scenario" and i + 1 < args.size():
			var scen_name = args[i + 1]
			print("[MainMenu] Pre-loading scenario:", scen_name)
			NetworkManager.lobby_data["scenario"] = scen_name
		elif args[i] == "--bot":
			DisplayServer.window_set_title("SFKH Simulator (BOT)")

func _show_menu(menu_name: String):
	StartupMenu.visible = false
	CampaignHostMenu.visible = false
	CampaignJoinMenu.visible = false
	TacticalMenu.visible = false
	status_label.text = ""
	
	match menu_name:
		"startup": StartupMenu.visible = true
		"campaign_host": CampaignHostMenu.visible = true
		"campaign_join": CampaignJoinMenu.visible = true
		"tactical": TacticalMenu.visible = true

func _on_btn_start_campaign():
	_show_menu("campaign_host")

func _on_btn_load_campaign():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_USERDATA
	fd.current_dir = "user://"
	fd.filters = PackedStringArray(["*.json ; JSON Files"])
	fd.title = "Load Campaign"
	fd.use_native_dialog = true
	fd.file_selected.connect(func(path):
		target_lobby_scene = "res://Scenes/CampaignLobby.tscn"
		NetworkManager.lobby_data["game_mode"] = "campaign"
		
		# Automatically host locally so we bypass the lobby and re-hydrate
		var err = NetworkManager.host_game(7000)
		if err != null and err != OK:
			status_label.text = "Error hosting restored game: %s" % err
			fd.queue_free()
			return
		
		if CampaignManager.load_campaign(path):
			NetworkManager.lobby_data["is_saved_game"] = true
			NetworkManager.lobby_data["current_day"] = CampaignManager.current_day
			NetworkManager.lobby_data["destroyed_fortresses"] = CampaignManager.destroyed_fortresses_count
			NetworkManager.lobby_data["destroyed_stations"] = CampaignManager.destroyed_stations_count
			NetworkManager.rpc("update_lobby_data", NetworkManager.lobby_data)
			_transition_to_lobby()
		else:
			status_label.text = "Failed to load campaign from %s" % path.get_file()
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	add_child(fd)
	fd.popup_centered(Vector2(600, 400))

func _on_btn_settings():
	var settings_scn = load("res://Scenes/SettingsMenu.tscn").instantiate()
	add_child(settings_scn)

func _on_btn_join_campaign():
	_show_menu("campaign_join")

func _on_btn_start_scenario():
	_show_menu("tactical")

func _on_quit_pressed():
	if not is_inside_tree(): return
	get_tree().quit()

# --- Campaign Connections ---

func _on_campaign_host_start():
	target_lobby_scene = "res://Scenes/CampaignLobby.tscn"
	NetworkManager.lobby_data["game_mode"] = "campaign"
	
	var port = host_port_input.text.to_int()
	if port <= 0: port = 7000
	var ip = host_ip_input.text.strip_edges()
	if ip.is_empty(): ip = "127.0.0.1"
	
	_save_last_server(ip, port)
	
	status_label.text = "Hosting Campaign on Port %d..." % port
	var err = NetworkManager.host_game(port)
	if err != OK:
		status_label.text = "Host Error: %s" % err
	else:
		_transition_to_lobby()

func _on_campaign_join_connect():
	target_lobby_scene = "res://Scenes/CampaignLobby.tscn"
	NetworkManager.lobby_data["game_mode"] = "campaign"
	
	var ip = join_ip_input.text.strip_edges()
	var port = join_port_input.text.to_int()
	if port <= 0: port = 7000
	if ip.is_empty(): ip = "127.0.0.1"
	
	_save_last_server(ip, port)
	
	status_label.text = "Joining Campaign at %s:%d..." % [ip, port]
	var err = NetworkManager.join_game(ip, port)
	if err != OK:
		status_label.text = "Join Error: %s" % err

# --- Tactical Connections ---

func _on_tactical_host():
	target_lobby_scene = "res://Scenes/Lobby.tscn"
	NetworkManager.lobby_data["game_mode"] = "tactical"
	
	var port = tactical_port_input.text.to_int()
	if port <= 0: port = 7000
	var addr = tactical_ip_input.text.strip_edges()
	if addr.is_empty(): addr = "127.0.0.1"
	
	_save_last_server(addr, port)
	
	status_label.text = "Hosting Scenario on %d..." % port
	var err = NetworkManager.host_game(port)
	if err != OK:
		status_label.text = "Host Error: %s" % err
	else:
		_transition_to_lobby()

func _on_tactical_join():
	target_lobby_scene = "res://Scenes/Lobby.tscn"
	NetworkManager.lobby_data["game_mode"] = "tactical"
	
	var port = tactical_port_input.text.to_int()
	if port <= 0: port = 7000
	var addr = tactical_ip_input.text.strip_edges()
	if addr.is_empty(): addr = "127.0.0.1"
	
	_save_last_server(addr, port)
	
	status_label.text = "Connecting to %s:%d..." % [addr, port]
	var err = NetworkManager.join_game(addr, port)
	if err != OK:
		status_label.text = "Join Error: %s" % err

# --- Networking Callbacks ---

func _on_connection_success(_id, _info):
	_transition_to_lobby()

func _on_connection_failed():
	status_label.text = "Connection Failed."

func _on_server_disconnected():
	status_label.text = "Server Disconnected."

func _transition_to_lobby():
	if not is_inside_tree(): return
	get_tree().change_scene_to_file(target_lobby_scene)

# --- Utilities ---

const SETTINGS_FILE = "user://settings.cfg"

func _load_last_server():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		var addr = config.get_value("Network", "server_address", "")
		var port = config.get_value("Network", "server_port", 7000)
		if not addr.is_empty():
			host_ip_input.text = addr
			join_ip_input.text = addr
			tactical_ip_input.text = addr
		host_port_input.text = str(port)
		join_port_input.text = str(port)
		tactical_port_input.text = str(port)

func _save_last_server(addr: String, port: int):
	addr = addr.strip_edges()
	
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("Network", "server_address", addr)
	config.set_value("Network", "server_port", port)
	config.save(SETTINGS_FILE)
