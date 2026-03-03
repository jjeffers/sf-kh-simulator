extends Control

@onready var StartupMenu = $StartupMenu
@onready var CampaignHostMenu = $CampaignHostMenu
@onready var CampaignJoinMenu = $CampaignJoinMenu
@onready var TacticalMenu = $TacticalMenu
@onready var status_label = $StatusLabel

@onready var address_input = $TacticalMenu/AddressInput
@onready var host_button = $TacticalMenu/HostButton
@onready var join_button = $TacticalMenu/JoinButton

@onready var btn_start_campaign = $StartupMenu/BtnStartCampaign
@onready var btn_load_campaign = $StartupMenu/BtnLoadCampaign
@onready var btn_join_campaign = $StartupMenu/BtnJoinCampaign
@onready var btn_start_scenario = $StartupMenu/BtnStartScenario
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
	_show_menu("startup")
	
	btn_start_campaign.pressed.connect(_on_btn_start_campaign)
	btn_load_campaign.pressed.connect(_on_btn_load_campaign)
	btn_join_campaign.pressed.connect(_on_btn_join_campaign)
	btn_start_scenario.pressed.connect(_on_btn_start_scenario)
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
				address_input.text = args[i+1]
			call_deferred("_on_tactical_join")
		elif args[i] == "--campaign-host":
			print("[MainMenu] Auto-Hosting Campaign...")
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
	status_label.text = "Load Campaign is not implemented yet."

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
	
	_save_last_server(ip)
	
	status_label.text = "Joining Campaign at %s:%d..." % [ip, port]
	var err = NetworkManager.join_game(ip, port)
	if err != OK:
		status_label.text = "Join Error: %s" % err

# --- Tactical Connections ---

func _on_tactical_host():
	target_lobby_scene = "res://Scenes/Lobby.tscn"
	NetworkManager.lobby_data["game_mode"] = "tactical"
	
	_save_last_server(address_input.text)
	var data = _get_target_address_port()
	var port = data["port"]
	
	status_label.text = "Hosting Scenario on %d..." % port
	var err = NetworkManager.host_game(port)
	if err != OK:
		status_label.text = "Host Error: %s" % err
	else:
		_transition_to_lobby()

func _on_tactical_join():
	target_lobby_scene = "res://Scenes/Lobby.tscn"
	NetworkManager.lobby_data["game_mode"] = "tactical"
	
	_save_last_server(address_input.text)
	var data = _get_target_address_port()
	var addr = data["address"]
	var port = data["port"]
	
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

func _get_target_address_port() -> Dictionary:
	var txt = address_input.text.strip_edges()
	var default_port = 7000
	var default_addr = "127.0.0.1"
	
	if txt.is_empty():
		return {"address": default_addr, "port": default_port}
	
	var parts = txt.split(":")
	var addr = parts[0]
	var port = default_port
	
	if parts.size() > 1:
		var p_str = parts[1]
		if p_str.is_valid_int():
			port = p_str.to_int()
	
	if addr.is_empty():
		addr = default_addr
		
	return {"address": addr, "port": port}

const SETTINGS_FILE = "user://settings.cfg"

func _load_last_server():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		var addr = config.get_value("Network", "server_address", "")
		if not addr.is_empty():
			address_input.text = addr
			join_ip_input.text = addr

func _save_last_server(addr: String):
	addr = addr.strip_edges()
	if addr.is_empty(): return
	
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("Network", "server_address", addr)
	config.save(SETTINGS_FILE)
