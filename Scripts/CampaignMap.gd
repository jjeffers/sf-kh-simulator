extends Control

@onready var top_bar_turn = $HBoxContainer/VBoxLeft/TopBar/HBox/TurnLabel
@onready var map_bg = $HBoxContainer/VBoxLeft/MapView/MapBackground
@onready var systems_container = $HBoxContainer/VBoxLeft/MapView/SystemsContainer
@onready var routes_container = $HBoxContainer/VBoxLeft/MapView/RoutesContainer
@onready var fleets_container = $HBoxContainer/VBoxLeft/MapView/FleetsContainer
@onready var event_log = $HBoxContainer/VBoxLeft/EventLogPanel/EventLogText

@onready var fleet_list = $HBoxContainer/VBoxRight/Panel/VBox/FleetList
@onready var ship_list_ui = $HBoxContainer/VBoxRight/Panel/VBox/ShipList
@onready var exec_jump_btn = $HBoxContainer/VBoxRight/Panel/VBox/ExecuteJumpBtn
@onready var end_turn_btn = $HBoxContainer/VBoxLeft/TopBar/HBox/EndTurnBtn

const MAP_GRID_WIDTH = 45.0
const MAP_GRID_HEIGHT = 55.0

# Dependencies
# Assume there's a global CampaignManager auto-load, or we instantiate one
var campaign: Node

var selected_fleet: CampaignFleet = null
var selected_system_id: String = ""
var jump_target_id: String = ""

func _ready():
	# For now, let's look for a global CampaignManager. If not found, create one for testing.
	if get_tree().root.has_node("CampaignManager"):
		campaign = get_tree().root.get_node("CampaignManager")
	else:
		# Fallback/standalone testing mode
		var cm_script = load("res://Scripts/CampaignManager.gd")
		campaign = cm_script.new()
		add_child(campaign)
		campaign.name = "CampaignManager"
	
	campaign.map_data_loaded.connect(_on_map_data_loaded)
	campaign.campaign_day_advanced.connect(_on_day_advanced)
	campaign.fleet_arrived.connect(_on_fleet_arrived)
	campaign.campaign_encounter_triggered.connect(_on_encounter)
	
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	exec_jump_btn.pressed.connect(_on_execute_jump_pressed)
	
	fleet_list.item_selected.connect(_on_fleet_list_selected)
	ship_list_ui.multi_selected.connect(_on_ship_selection_changed)
	
	if campaign.map_data.is_empty():
		campaign._load_map_data()
	else:
		_on_map_data_loaded()
		
	campaign.start_new_campaign()
	_update_ui()
	_setup_background()

func _setup_background():
	# Static Starfield using ParallaxBackground and Downloaded Texture
	var texture = load("res://Assets/starfield_background.png")
	if not texture:
		push_error("Failed to load background texture: res://Assets/starfield_background.png")
		return

	var bg = ParallaxBackground.new()
	bg.name = "StarfieldBackground"
	bg.scroll_ignore_camera_zoom = true
	# Insert it at the back of the UI
	bg.layer = -1
	add_child(bg)
	
	var layer = ParallaxLayer.new()
	layer.name = "StarsLayer"
	layer.motion_scale = Vector2(0.05, 0.05)
	
	var rect = TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	var tile_size = Vector2(4096, 4096)
	rect.size = tile_size
	rect.position = - tile_size / 2
	
	layer.motion_mirroring = tile_size
	
	bg.add_child(layer)
	layer.add_child(rect)

func _log_event(msg: String):
	event_log.text += "\\nLOG Day %d: %s" % [campaign.current_day, msg]
	# Auto-scroll
	event_log.scroll_to_line(event_log.get_line_count() - 1)

func _on_map_data_loaded():
	_draw_routes()
	_draw_systems()
	_draw_fleets()
	# The grid X=0-45, Y=0-55 need to map to the MapBackground rect size
	get_viewport().size_changed.connect(_on_resize)
	call_deferred("_on_resize")

func _on_resize():
	# Redraw positions when window resizes
	for child in systems_container.get_children():
		child.queue_free()
	for child in routes_container.get_children():
		child.queue_free()
	_draw_routes()
	_draw_systems()
	_draw_fleets()

func _coord_to_screen(x: float, y: float) -> Vector2:
	var rect = map_bg.get_global_rect()
	# Optional: invert Y so Y=0 is bottom? The prompt said Bottom-Left (0,0)
	var screen_x = rect.position.x + (x / MAP_GRID_WIDTH) * rect.size.x
	var screen_y = rect.position.y + rect.size.y - ((y / MAP_GRID_HEIGHT) * rect.size.y)
	return Vector2(screen_x, screen_y)

func _draw_systems():
	for sys_name in campaign.systems:
		var sys = campaign.systems[sys_name]
		var pos = _coord_to_screen(sys["x"], sys["y"])
		
		# Create visual node
		var btn = Button.new()
		btn.text = "O\\n" + sys_name
		btn.position = pos - Vector2(20, 20) # Center offset roughly
		
		# Draw space station indicator if present
		if sys_name in campaign.UPF_FORTRESSES or sys_name in campaign.UPF_ARMED_STATIONS:
			var stat_lbl = Label.new()
			stat_lbl.text = "[S]"
			stat_lbl.modulate = Color.YELLOW
			stat_lbl.position = pos + Vector2(10, 10)
			systems_container.add_child(stat_lbl)

		# Determine if UI style should be UPF empty circle
		# We'll use custom styles or modulating in the polish phase
		
		btn.pressed.connect(func(): _on_system_clicked(sys_name))
		systems_container.add_child(btn)
		
	for start_c in campaign.start_circles:
		# Check if the connected system exists to use as an anchor point
		var parent_sys_id = start_c.get("connected_system", "")
		if campaign.systems.has(parent_sys_id):
			var sys = campaign.systems[parent_sys_id]
			# Positional offset for void circles: move them outwards (-x or +y depending on zone string or just a generic offset)
			# For simplicity, we'll shift them left and up relative to the anchor node
			var offset_x = -3.0
			var offset_y = 3.0
			
			var zone = start_c.get("entry_zone", "").to_lower()
			if "north" in zone: offset_y = 4.0
			if "south" in zone: offset_y = -4.0
			if "east" in zone: offset_x = 4.0
			if "west" in zone: offset_x = -4.0
			
			var visual_x = sys["x"] + offset_x
			var visual_y = sys["y"] + offset_y
			
			var pos = _coord_to_screen(visual_x, visual_y)
			
			var btn = Button.new()
			btn.text = "Sathar\\nStart " + str(start_c.get("id"))
			btn.position = pos - Vector2(20, 20)
			# Tint Sathar starts red
			btn.modulate = Color(1.0, 0.4, 0.4, 1.0)
			
			# Ensure we can select start circles too! We treat them as 'systems' for fleet management
			var circle_id = "Start Circle " + str(start_c.get("id"))
			btn.pressed.connect(func(): _on_system_clicked(circle_id))
			systems_container.add_child(btn)
			
			# Draw a dotted/dashed or faint line connecting to the anchor point
			var p1 = pos
			var p2 = _coord_to_screen(sys["x"], sys["y"])
			var line = Line2D.new()
			line.add_point(p1)
			line.add_point(p2)
			line.width = 1.0
			line.default_color = Color(1.0, 0.4, 0.4, 0.5)
			routes_container.add_child(line)

func _draw_fleets():
	for child in fleets_container.get_children():
		child.queue_free()
		
	# Draw fleets clustered at their systems
	var fleets_by_system = {}
	for f in campaign.fleets:
		if f.current_system_id != "":
			if not fleets_by_system.has(f.current_system_id):
				fleets_by_system[f.current_system_id] = []
			fleets_by_system[f.current_system_id].append(f)
			
	for sys_id in fleets_by_system:
		var local_fleets = fleets_by_system[sys_id]
		# Find the screen coordinate of the system
		var pos = Vector2.ZERO
		
		# Check if it's a normal system
		if campaign.systems.has(sys_id):
			pos = _coord_to_screen(campaign.systems[sys_id]["x"], campaign.systems[sys_id]["y"])
		# Check if it's a Start Circle
		elif sys_id.begins_with("Start Circle "):
			var circle_id = sys_id.replace("Start Circle ", "").to_int()
			for sc in campaign.start_circles:
				if sc.get("id") == circle_id:
					var parent_sys_id = sc.get("connected_system", "")
					if campaign.systems.has(parent_sys_id):
						var sys = campaign.systems[parent_sys_id]
						var offset_x = -3.0
						var offset_y = 3.0
						var zone = sc.get("entry_zone", "").to_lower()
						if "north" in zone: offset_y = 4.0
						if "south" in zone: offset_y = -4.0
						if "east" in zone: offset_x = 4.0
						if "west" in zone: offset_x = -4.0
						pos = _coord_to_screen(sys["x"] + offset_x, sys["y"] + offset_y)
					break
		
		# If we found a valid position, draw the fleet icons
		if pos != Vector2.ZERO:
			# If multiple fleets, space them out slightly
			for i in range(local_fleets.size()):
				var f = local_fleets[i]
				var offset = Vector2(30 * (i+1), -30) # Stack them up and right
				
				var is_enemy = f.faction != _get_my_faction()
				if is_enemy and not _can_see_system(f.current_system_id):
					continue # Hidden by Fog of War
				
				var lbl = Label.new()
				lbl.text = "[F]"
				if f.faction == "Sathar":
					lbl.modulate = Color.RED
				elif f.faction == "UPF":
					lbl.modulate = Color.CYAN
					
				lbl.position = (pos - Vector2(10, 10)) + offset
				fleets_container.add_child(lbl)
				
	# Also maybe draw migrating fleets between routes? (Optional polish phase)

func _draw_routes():
	for route in campaign.routes:
		var origin = route["origin"]
		var dest = route["destination"]
		if campaign.systems.has(origin) and campaign.systems.has(dest):
			var p1 = _coord_to_screen(campaign.systems[origin]["x"], campaign.systems[origin]["y"])
			var p2 = _coord_to_screen(campaign.systems[dest]["x"], campaign.systems[dest]["y"])
			
			var line = Line2D.new()
			line.add_point(p1)
			line.add_point(p2)
			line.width = 2.0
			line.default_color = Color.DARK_GRAY
			routes_container.add_child(line)

func _on_system_clicked(sys_name: String):
	if selected_fleet != null:
		# If we have a fleet selected, see if we are trying to jump here
		if campaign.are_systems_connected(selected_fleet.current_system_id, sys_name):
			jump_target_id = sys_name
			exec_jump_btn.disabled = false
			print("Jump target: ", sys_name)
			return
			
	# Else interpret as selecting a system to view
	selected_system_id = sys_name
	_update_fleet_list()

func _update_ui():
	# Update Window Title
	var my_faction = _get_my_faction()
	var peer_id = multiplayer.get_unique_id() if NetworkManager.multiplayer.has_multiplayer_peer() else 1
	var num = NetworkManager.lobby_data["player_numbers"].get(peer_id, peer_id)
	DisplayServer.window_set_title("SFKH Campaign - [%s] Player %d" % [my_faction, num])

	top_bar_turn.text = "Day: %d" % campaign.current_day
	_update_fleet_list()

func _can_see_system(sys_id: String) -> bool:
	var my_faction = _get_my_faction()
	if my_faction == "UPF":
		if sys_id in campaign.UPF_FORTRESSES or sys_id in campaign.UPF_ARMED_STATIONS:
			return true
	
	for f in campaign.fleets:
		if f.faction == my_faction and f.current_system_id == sys_id:
			return true
	return false

func _get_my_faction() -> String:
	var peer_id = multiplayer.get_unique_id() if NetworkManager.multiplayer.has_multiplayer_peer() else 1
	var team_id = NetworkManager.lobby_data["teams"].get(peer_id, 0)
	return "UPF" if team_id == 1 else "Sathar"

func _update_fleet_list():
	fleet_list.clear()
	exec_jump_btn.disabled = true
	jump_target_id = ""
	
	if selected_system_id == "":
		return
		
	var local_fleets = campaign.get_fleets_at_system(selected_system_id)
	for i in range(local_fleets.size()):
		var f = local_fleets[i]
		if f.faction != _get_my_faction() and not _can_see_system(f.current_system_id):
			continue # Fog of War
			
		fleet_list.add_item(f.fleet_name)
		fleet_list.set_item_metadata(fleet_list.item_count - 1, f)

func _on_fleet_list_selected(idx: int):
	selected_fleet = fleet_list.get_item_metadata(idx)
	_update_composition_panel()

func _update_composition_panel():
	ship_list_ui.clear()
	if selected_fleet == null:
		return
		
	for i in range(selected_fleet.ships.size()):
		var s = selected_fleet.ships[i]
		# Fallback logic if we are just storing dicts right now
		var s_name = str(s)
		if typeof(s) == TYPE_DICTIONARY:
			s_name = s.get("ship_name", "Ship") + " (" + s.get("ship_class", "Unknown") + ")"
		elif typeof(s) == TYPE_OBJECT and s.has_method("get_ship_name"):
			s_name = s.get_ship_name()
			
		ship_list_ui.add_item(s_name)

func _on_ship_selection_changed(_row, _selected):
	pass

func _on_execute_jump_pressed():
	if selected_fleet == null or jump_target_id == "":
		return
		
	if campaign.order_fleet_move(selected_fleet, jump_target_id):
		_log_event("%s has jumped for %s. ETA: Day %d." % [selected_fleet.fleet_name, jump_target_id, campaign.current_day + campaign.TRANSIT_DAYS])
		selected_fleet = null
		jump_target_id = ""
		exec_jump_btn.disabled = true
		_update_fleet_list()
		_update_composition_panel()
		_draw_fleets()
	else:
		print("Invalid jump order")

func _on_end_turn_pressed():
	campaign.end_turn()

func _on_day_advanced(day: int):
	_update_ui()
	_draw_fleets()

func _on_fleet_arrived(fleet: CampaignFleet, sys_id: String):
	_log_event("%s arrived at %s." % [fleet.fleet_name, sys_id])
	_draw_fleets()

func _on_encounter(sys_id, upf, sathar):
	_log_event("COMBAT TRIGGERED AT %s!" % sys_id)
	# TODO: Transition to tactical Scene!
