extends Control

@onready var top_bar_turn = $HBoxContainer/VBoxLeft/TopBar/HBox/TurnLabel
@onready var map_view = $HBoxContainer/VBoxLeft/MapView
@onready var map_container = $HBoxContainer/VBoxLeft/MapView/MapContainer
@onready var map_bg = $HBoxContainer/VBoxLeft/MapView/MapContainer/MapBackground
@onready var systems_container = $HBoxContainer/VBoxLeft/MapView/MapContainer/SystemsContainer
@onready var routes_container = $HBoxContainer/VBoxLeft/MapView/MapContainer/RoutesContainer
@onready var fleets_container = $HBoxContainer/VBoxLeft/MapView/MapContainer/FleetsContainer

@onready var fleet_list = $HBoxContainer/VBoxRight/Panel/VBox/FleetList
@onready var ship_list_ui = $HBoxContainer/VBoxRight/Panel/VBox/ShipList
@onready var cancel_jump_btn = $HBoxContainer/VBoxRight/Panel/VBox/ActionHBox/CancelJumpBtn
@onready var plot_jump_btn = $HBoxContainer/VBoxRight/Panel/VBox/ActionHBox/PlotJumpBtn
@onready var end_turn_btn = $HBoxContainer/VBoxLeft/TopBar/HBox/EndTurnBtn
@onready var turn_status_label = $HBoxContainer/VBoxLeft/TopBar/HBox/TurnStatusLabel

const MAP_GRID_WIDTH = 45.0
const MAP_GRID_HEIGHT = 55.0

# Dependencies
# Assume there's a global CampaignManager auto-load, or we instantiate one
var campaign: Node

var selected_fleet: CampaignFleet = null
var selected_system_id: String = ""
var is_plotting_jump: bool = false
var pan_speed: float = 600.0
var map_move_dir: Vector2 = Vector2.ZERO

var active_encounter_dialog: Node = null

func _ready():
	# CampaignManager is now a guaranteed Autoload
	campaign = CampaignManager
	
	campaign.map_data_loaded.connect(_on_map_data_loaded)
	campaign.campaign_day_advanced.connect(_on_day_advanced)
	campaign.turn_ready_changed.connect(_on_turn_ready_changed)
	campaign.fleet_arrived.connect(_on_fleet_arrived)
	campaign.campaign_encounter_triggered.connect(_on_encounter)
	campaign.open_encounter_dialog.connect(_handle_encounter_click)
	campaign.campaign_state_updated.connect(_on_campaign_state_updated)
	
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	cancel_jump_btn.pressed.connect(_on_cancel_jump_pressed)
	plot_jump_btn.toggled.connect(_on_plot_jump_toggled)
	
	fleet_list.item_selected.connect(_on_fleet_list_selected)
	fleet_list.item_activated.connect(_on_fleet_list_activated)
	ship_list_ui.multi_selected.connect(_on_ship_selection_changed)
	ship_list_ui.item_activated.connect(_on_ship_list_activated)
	
	if campaign.map_data.is_empty():
		campaign._load_map_data()
	else:
		_on_map_data_loaded()
		
	if campaign.fleets.is_empty():
		campaign.start_new_campaign()
		
	# Select an initial system to populate the lists
	var my_fac = _get_my_faction()
	var my_fleets = []
	for f in campaign.fleets:
		if f.faction == my_fac and not f.is_moving():
			my_fleets.append(f)
			
	if my_fleets.size() > 0:
		selected_system_id = my_fleets[0].current_system_id
		
	_update_ui()
	_setup_background()
	
	# Scroll to center initially
	call_deferred("_center_map_initially")

func _center_map_initially():
	# Scroll map to roughly center
	var max_scroll_h = map_container.custom_minimum_size.x - map_view.size.x
	var max_scroll_v = map_container.custom_minimum_size.y - map_view.size.y
	if max_scroll_h > 0: map_view.scroll_horizontal = int(max_scroll_h / 2.0)
	if max_scroll_v > 0: map_view.scroll_vertical = int(max_scroll_v / 2.0)
	
	if selected_system_id != "":
		_focus_camera_on_system(selected_system_id)

func _input(event):
	if event.is_action_pressed("ui_cancel") and not has_node("CampaignMenu"):
		var menu_scn = load("res://Scenes/CampaignMenu.tscn").instantiate()
		menu_scn.name = "CampaignMenu"
		add_child(menu_scn)
		get_viewport().set_input_as_handled()
		return
	# Prioritize Map Panning over UI Element focus navigation
	if event is InputEventKey:
		var handled_arrow = false
		if event.is_action("ui_left"): map_move_dir.x = -1.0 if event.pressed else (1.0 if Input.is_action_pressed("ui_right") else 0.0); handled_arrow = true
		elif event.is_action("ui_right"): map_move_dir.x = 1.0 if event.pressed else (-1.0 if Input.is_action_pressed("ui_left") else 0.0); handled_arrow = true
		elif event.is_action("ui_up"): map_move_dir.y = -1.0 if event.pressed else (1.0 if Input.is_action_pressed("ui_down") else 0.0); handled_arrow = true
		elif event.is_action("ui_down"): map_move_dir.y = 1.0 if event.pressed else (-1.0 if Input.is_action_pressed("ui_up") else 0.0); handled_arrow = true
		
		# If user pressed an arrow key, consume it so the Ship lists don't tab around
		if handled_arrow:
			get_viewport().set_input_as_handled()

func _process(delta):
	if map_move_dir != Vector2.ZERO:
		var normalized_dir = map_move_dir.normalized()
		var move_amount = normalized_dir * pan_speed * delta
		map_view.scroll_horizontal += int(move_amount.x)
		map_view.scroll_vertical += int(move_amount.y)
		
	if is_instance_valid(active_encounter_dialog):
		if active_encounter_dialog.has_meta("sys_name"):
			var sys = active_encounter_dialog.get_meta("sys_name")
			if sys != "" and sys not in campaign.active_encounters:
				active_encounter_dialog.queue_free()
				active_encounter_dialog = null
			
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
	ConsoleManager.log_message(msg)

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
	# Coords relative to the total MapContainer size (2500x2500)
	var map_size = map_container.custom_minimum_size
	# Margin around edge of map bounds inside container
	var margin_x = map_size.x * 0.1
	var margin_y = map_size.y * 0.1
	var usable_width = map_size.x - (margin_x * 2)
	var usable_height = map_size.y - (margin_y * 2)
	
	var pos_x = margin_x + (x / MAP_GRID_WIDTH) * usable_width
	var pos_y = margin_y + (1.0 - (y / MAP_GRID_HEIGHT)) * usable_height # y=0 is bottom
	return Vector2(pos_x, pos_y)

func _get_system_pos(sys_id: String) -> Vector2:
	if campaign.systems.has(sys_id):
		return _coord_to_screen(campaign.systems[sys_id]["x"], campaign.systems[sys_id]["y"])
		
	# Check start circles
	for start_c in campaign.start_circles:
		var circle_name = "Start Circle " + str(int(start_c.get("id", 0)))
		if sys_id == circle_name:
			var parent_sys_id = start_c.get("connected_system", "")
			if campaign.systems.has(parent_sys_id):
				var sys = campaign.systems[parent_sys_id]
				var offset_x = -3.0
				var offset_y = 3.0
				
				var zone = start_c.get("entry_zone", "").to_lower()
				if "north" in zone: offset_y = 4.0
				if "south" in zone: offset_y = -4.0
				if "east" in zone: offset_x = 4.0
				if "west" in zone: offset_x = -4.0
				
				return _coord_to_screen(sys["x"] + offset_x, sys["y"] + offset_y)
				
	return Vector2.ZERO

func _create_system_node(node_id: String, display_name: String, pos: Vector2, is_sathar: bool) -> Control:
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var width = 140
	vbox.position = pos - Vector2(width / 2.0, 24)
	vbox.size = Vector2(width, 70)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var center_hbox = HBoxContainer.new()
	center_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var btn = Panel.new()
	btn.custom_minimum_size = Vector2(48, 48)
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	
	if is_sathar:
		style.bg_color = Color(1.0, 0.2, 0.2, 1.0)
	else:
		style.bg_color = Color(0.05, 0.05, 0.1, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.6, 1.0, 1.0)
		
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.3)
	if not is_sathar:
		hover_style.bg_color = Color(0.3, 0.6, 1.0, 0.3)
		
	btn.add_theme_stylebox_override("panel", style)
	
	btn.gui_input.connect(func(event): _on_system_gui_input(event, node_id))
	center_hbox.add_child(btn)
	
	var lbl = Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	
	if is_sathar:
		lbl.modulate = Color(1.0, 0.4, 0.4, 1.0)
	
	vbox.add_child(center_hbox)
	vbox.add_child(lbl)
	return vbox

func _draw_systems():
	for sys_name in campaign.systems:
		var pos = _get_system_pos(sys_name)
		
		# Draw encounter indicator
		if sys_name in campaign.active_encounters:
			var encounter_circle = Panel.new()
			var enc_style = StyleBoxFlat.new()
			enc_style.bg_color = Color(1.0, 0.0, 0.0, 0.4) # Red translucent
			enc_style.border_color = Color(1.0, 1.0, 1.0, 1.0) # White border
			enc_style.border_width_left = 3
			enc_style.border_width_top = 3
			enc_style.border_width_right = 3
			enc_style.border_width_bottom = 3
			enc_style.corner_radius_top_left = 52
			enc_style.corner_radius_top_right = 52
			enc_style.corner_radius_bottom_left = 52
			enc_style.corner_radius_bottom_right = 52
			
			encounter_circle.add_theme_stylebox_override("panel", enc_style)
			encounter_circle.custom_minimum_size = Vector2(105, 105)
			encounter_circle.mouse_filter = Control.MOUSE_FILTER_STOP
			encounter_circle.gui_input.connect(func(event): _on_system_gui_input(event, sys_name))
			encounter_circle.position = pos - Vector2(52, 52) # Center it visually
			systems_container.add_child(encounter_circle)
			
		var node = _create_system_node(sys_name, sys_name, pos, false)
		systems_container.add_child(node)
		
		# Draw space station indicator if present
		if sys_name in campaign.UPF_FORTRESSES or sys_name in campaign.UPF_ARMED_STATIONS:
			var station_icon = TextureRect.new()
			station_icon.texture = load("res://Assets/upf_space_station.png")
			station_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			station_icon.custom_minimum_size = Vector2(24, 24)
			# Position it nicely offset from the system circle
			station_icon.position = pos + Vector2(-12, -30)
			systems_container.add_child(station_icon)
		
	for start_c in campaign.start_circles:
		var circle_id = "Start Circle " + str(int(start_c.get("id", 0)))
		var pos = _get_system_pos(circle_id)
		var display_name = "Sathar Start " + str(int(start_c.get("id", 0)))
		
		var node = _create_system_node(circle_id, display_name, pos, true)
		systems_container.add_child(node)
		
		var parent_sys_id = start_c.get("connected_system", "")
		if campaign.systems.has(parent_sys_id):
			var sys = campaign.systems[parent_sys_id]
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
		# If it's a moving fleet, it may not be exactly at the system
		if f.is_moving():
			# It's drawn separately midway
			continue
			
		if f.current_system_id != "":
			if not fleets_by_system.has(f.current_system_id):
				fleets_by_system[f.current_system_id] = []
			fleets_by_system[f.current_system_id].append(f)
			
	for sys_id in fleets_by_system:
		var local_fleets = fleets_by_system[sys_id]
		# Find the screen coordinate of the system
		var pos = _get_system_pos(sys_id)
		
		# If we found a valid position, draw the fleet icons
		if pos != Vector2.ZERO:
			var fleets_by_faction = {}
			for f in local_fleets:
				if not fleets_by_faction.has(f.faction):
					fleets_by_faction[f.faction] = []
				fleets_by_faction[f.faction].append(f)
			
			var faction_idx = 0
			for faction in fleets_by_faction:
				var faction_fleets = fleets_by_faction[faction]
				if faction_fleets.is_empty(): continue
				
				var first_f = faction_fleets[0]
				var is_enemy = faction != _get_my_faction()
				if is_enemy and not _can_see_system(first_f.current_system_id):
					continue # Hidden by Fog of War
					
				var offset = Vector2(0, -70)
				if faction_idx > 0:
					offset = Vector2(50, -70) # Shift second faction slightly right and up
					
				var btn = TextureButton.new()
				btn.custom_minimum_size = Vector2(40, 40)
				btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				
				var total_ships = 0
				var names_array = []
				for f in faction_fleets:
					total_ships += f.ships.size()
					names_array.append(f.fleet_name)
					
				btn.tooltip_text = "%s forces: %d ships" % [faction, total_ships]
				
				if faction == "UPF":
					btn.texture_normal = preload("res://Assets/UI/fleet_enemy_upf.svg") if is_enemy else preload("res://Assets/UI/fleet_friendly_upf.svg")
				elif faction == "Sathar":
					btn.texture_normal = preload("res://Assets/UI/fleet_enemy_sathar.svg") if is_enemy else preload("res://Assets/UI/fleet_friendly_sathar.svg")
				
				btn.position = (pos - Vector2(20, 20)) + offset
				btn.pressed.connect(func(): _on_fleet_map_icon_clicked(first_f))
				fleets_container.add_child(btn)
				
				var lbl = Label.new()
				lbl.text = "\n".join(names_array)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", 12)
				lbl.position = btn.position + Vector2(-40, 42)
				lbl.custom_minimum_size = Vector2(120, 20)
				fleets_container.add_child(lbl)
				
				faction_idx += 1
				
	# Group moving fleets by route
	var fleets_by_route = {}
	for f in campaign.fleets:
		if f.is_moving():
			var is_enemy = f.faction != _get_my_faction()
			if is_enemy: continue
			
			var route_key = f.current_system_id + "->" + f.destination_system_id
			if not fleets_by_route.has(route_key):
				fleets_by_route[route_key] = []
			fleets_by_route[route_key].append(f)
			
	for route_key in fleets_by_route:
		var moving_fleets = fleets_by_route[route_key]
		var f_first = moving_fleets[0]
		
		var pos1 = _get_system_pos(f_first.current_system_id)
		var pos2 = _get_system_pos(f_first.destination_system_id)
		
		# Draw arrow body
		var arrow_line = Line2D.new()
		arrow_line.add_point(pos1)
		arrow_line.add_point(pos2)
		arrow_line.width = 4.0
		arrow_line.default_color = Color(1.0, 0.6, 0.2, 0.7) # Orange
		fleets_container.add_child(arrow_line)
		
		# Draw arrow head at pos2
		var dir = (pos2 - pos1).normalized()
		var head_size = 15.0
		var p1 = pos2 - dir * head_size + dir.orthogonal() * head_size * 0.5
		var p2 = pos2 - dir * head_size - dir.orthogonal() * head_size * 0.5
		var head = Polygon2D.new()
		head.polygon = PackedVector2Array([pos2, p1, p2])
		head.color = Color(1.0, 0.6, 0.2, 0.9)
		fleets_container.add_child(head)
		
		var interp_pos = pos1.lerp(pos2, 0.5) # Center point
		var offset = Vector2(0, -45)
		
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		var total_ships = 0
		var names_array = []
		for f in moving_fleets:
			total_ships += f.ships.size()
			names_array.append("%s (%dd)" % [f.fleet_name, f.days_to_arrival])
			
		btn.tooltip_text = "Moving forces: %d ships" % total_ships
		
		if f_first.faction == "UPF":
			btn.texture_normal = preload("res://Assets/UI/fleet_friendly_upf.svg")
		elif f_first.faction == "Sathar":
			btn.texture_normal = preload("res://Assets/UI/fleet_friendly_sathar.svg")
			
		btn.modulate.a = 0.6 # Ghosted for in-transit
			
		btn.position = (interp_pos - Vector2(20, 20)) + offset
		btn.pressed.connect(func(): _on_fleet_map_icon_clicked(f_first))
		fleets_container.add_child(btn)
		
		var lbl = Label.new()
		lbl.text = "\n".join(names_array)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.position = btn.position + Vector2(-40, 42) # Centered beneath icon
		lbl.custom_minimum_size = Vector2(120, 20)
		fleets_container.add_child(lbl)

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

func _on_plot_jump_toggled(pressed: bool):
	is_plotting_jump = pressed

func _on_system_gui_input(event: InputEvent, sys_name: String):
	if event is InputEventMouseButton and event.pressed:
		ConsoleManager.log_message("DEBUG Map GUI Input: sys=%s btn=%d" % [sys_name, event.button_index])
		
		if sys_name in campaign.active_encounters and event.button_index == MOUSE_BUTTON_LEFT:
			campaign.rpc_open_encounter_dialog.rpc(sys_name)
			return
		
		# If we have a fleet selected
		var sel_fac = "None"
		if selected_fleet: sel_fac = selected_fleet.faction
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_plotting_jump and selected_fleet != null and selected_fleet.faction == _get_my_faction() and not selected_fleet.is_moving():
				ConsoleManager.log_message("DEBUG Map: Left-Click Plotting")
				if campaign.are_systems_connected(selected_fleet.current_system_id, sys_name):
					_execute_jump(sys_name)
					plot_jump_btn.button_pressed = false
					return
				else:
					ConsoleManager.log_message("[color=red]Route NOT connected from %s[/color]" % selected_fleet.current_system_id)
					
			_focus_system_only(sys_name)
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			ConsoleManager.log_message("DEBUG Map: Right-Click Plotting")
			if selected_fleet != null and selected_fleet.faction == _get_my_faction() and not selected_fleet.is_moving():
				if campaign.are_systems_connected(selected_fleet.current_system_id, sys_name):
					_execute_jump(sys_name)
					plot_jump_btn.button_pressed = false
				else:
					ConsoleManager.log_message("[color=red]Route NOT connected from %s[/color]" % selected_fleet.current_system_id)

func _focus_system_only(sys_name: String):
	if selected_system_id != sys_name:
		selected_system_id = sys_name
		plot_jump_btn.disabled = true
		plot_jump_btn.button_pressed = false
		cancel_jump_btn.disabled = true
		# Deselect current fleet if we click a different system
		selected_fleet = null
		_update_fleet_list() # Removes highlight
		_update_composition_panel()
		fleet_list.deselect_all()
		_focus_camera_on_system(sys_name)
		_draw_routes()

func _update_ui():
	# Update Window Title
	var my_faction = _get_my_faction()
	var peer_id = multiplayer.get_unique_id() if NetworkManager.multiplayer.has_multiplayer_peer() else 1
	var num = NetworkManager.lobby_data["player_numbers"].get(peer_id, NetworkManager.lobby_data["player_numbers"].get(str(peer_id), peer_id))
	DisplayServer.window_set_title("SFKH Campaign - [%s] Player %d" % [my_faction, num])

	top_bar_turn.text = "Day: %d" % campaign.current_day
	_update_fleet_list()
	
	end_turn_btn.disabled = campaign.active_encounters.size() > 0

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
	var teams = NetworkManager.lobby_data.get("teams", {})
	var team_id = teams.get(peer_id, teams.get(str(peer_id), 1 if peer_id == 1 else 0))
	return "UPF" if team_id == 1 else "Sathar"

func _update_fleet_list():
	fleet_list.clear()
	plot_jump_btn.disabled = true
	cancel_jump_btn.disabled = true
	
	var my_faction = _get_my_faction()
	
	for i in range(campaign.fleets.size()):
		var f = campaign.fleets[i]
		if f.faction == my_faction:
			var display_text = f.fleet_name
			if f.is_moving():
				display_text += " (In Transit: %s days remaining)" % f.days_to_arrival
				
			if selected_fleet == f:
				display_text = "> " + display_text + " <"
				
			fleet_list.add_item(display_text)
			fleet_list.set_item_metadata(fleet_list.item_count - 1, f)
			
			if selected_fleet == f:
				fleet_list.set_item_custom_fg_color(fleet_list.item_count - 1, Color(1.0, 0.84, 0.0)) # Gold

func _on_fleet_list_selected(idx: int):
	# Refresh list first to reset highlighting, then reselect
	selected_fleet = fleet_list.get_item_metadata(idx)
	_update_fleet_list() # Re-draw list with new correct highlight
	
	# Find the new idx after redraw to re-select visually in the UI box
	for i in range(fleet_list.item_count):
		if fleet_list.get_item_metadata(i) == selected_fleet:
			fleet_list.select(i)
			break
			
	if selected_fleet.is_moving():
		cancel_jump_btn.disabled = false
		plot_jump_btn.disabled = true
	else:
		cancel_jump_btn.disabled = true
		plot_jump_btn.disabled = false
		
	_update_composition_panel()
	
	var focus_sys = selected_fleet.current_system_id
	if selected_fleet.is_moving():
		# Optional: center on destination or halfway point
		# We'll just focus on destination for now
		focus_sys = selected_fleet.destination_system_id
		
	_focus_camera_on_system(focus_sys)
	_draw_routes() # Clear jump previews
	
	# Set selected system ID based on fleet so jump logic works
	selected_system_id = selected_fleet.current_system_id

func _on_fleet_map_icon_clicked(fleet: CampaignFleet):
	# Do nothing if it's an enemy fleet and we somehow clicked it (should be filtered above)
	if fleet.faction != _get_my_faction(): return
	
	_focus_system_only(fleet.current_system_id)
	
	for i in range(fleet_list.item_count):
		if fleet_list.get_item_metadata(i) == fleet:
			_on_fleet_list_selected(i)
			break

func _focus_camera_on_system(sys_id: String):
	var pos = Vector2.ZERO
	if campaign.systems.has(sys_id):
		pos = _coord_to_screen(campaign.systems[sys_id]["x"], campaign.systems[sys_id]["y"])
	elif sys_id.begins_with("Start Circle "):
		var circle_id = sys_id.replace("Start Circle ", "").to_int()
		for sc in campaign.start_circles:
			if int(sc.get("id", 0)) == circle_id:
				var parent_sys = sc.get("connected_system", "")
				if campaign.systems.has(parent_sys):
					pos = _coord_to_screen(campaign.systems[parent_sys]["x"], campaign.systems[parent_sys]["y"])
				break
	
	if pos != Vector2.ZERO:
		# Scroll to center the target position in the current viewport size
		var view_size = map_view.size
		map_view.scroll_horizontal = int(pos.x - view_size.x / 2.0)
		map_view.scroll_vertical = int(pos.y - view_size.y / 2.0)

func _update_composition_panel():
	ship_list_ui.clear()
	if selected_fleet == null:
		return
		
	for i in range(selected_fleet.ships.size()):
		var s = selected_fleet.ships[i]
		var s_name = str(s)
		var health_pct = 1.0
		
		if typeof(s) == TYPE_DICTIONARY:
			s_name = s.get("name", s.get("ship_name", "Ship")) + " (" + s.get("class", s.get("ship_class", "Unknown")) + ")"
			# Assuming hull defaults to 100 max in campaign dictionary representation right now
			health_pct = float(s.get("hull", 100)) / 100.0
		elif typeof(s) == TYPE_OBJECT and s.has_method("get_ship_name"):
			s_name = s.get_ship_name()
			if s.get("hull"):
				var max_hull_val = 100.0 # Standardize later
				health_pct = float(s.hull) / max_hull_val
			
		ship_list_ui.add_item(s_name)
		
		var item_idx = ship_list_ui.item_count - 1
		# Color coding
		if health_pct >= 0.75:
			ship_list_ui.set_item_custom_fg_color(item_idx, Color(0.2, 1.0, 0.2)) # Green
		elif health_pct >= 0.25:
			ship_list_ui.set_item_custom_fg_color(item_idx, Color(1.0, 0.6, 0.2)) # Orange
		else:
			ship_list_ui.set_item_custom_fg_color(item_idx, Color(1.0, 0.2, 0.2)) # Red

func _on_campaign_state_updated():
	_draw_fleets()
	_update_fleet_list()
	if selected_fleet:
		_update_composition_panel()

func _on_fleet_list_activated(idx: int):
	var fleet = fleet_list.get_item_metadata(idx)
	if not fleet: return
	if fleet.faction != _get_my_faction(): return
	
	var user_input = LineEdit.new()
	user_input.text = fleet.fleet_name
	user_input.custom_minimum_size = Vector2(250, 0)
	user_input.caret_blink = true
	user_input.select_all()
	
	var label = Label.new()
	label.text = "Enter a new name for this fleet:"
	
	var vbox = VBoxContainer.new()
	vbox.add_child(label)
	vbox.add_child(user_input)
	
	var dialog = ConfirmationDialog.new()
	dialog.title = "Rename Fleet"
	dialog.add_child(vbox)
	add_child(dialog)
	
	dialog.about_to_popup.connect(func(): user_input.grab_focus())
	dialog.confirmed.connect(func():
		var new_val = user_input.text.strip_edges()
		if new_val != "" and new_val != fleet.fleet_name:
			var global_idx = campaign.fleets.find(fleet)
			if global_idx != -1:
				campaign.rpc_rename_fleet.rpc(global_idx, new_val)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	
	dialog.popup_centered()

func _on_ship_list_activated(idx: int):
	if not selected_fleet: return
	if selected_fleet.faction != _get_my_faction(): return
	
	var ship = selected_fleet.ships[idx]
	var current_name = ship.get("name", ship.get("ship_name", "Ship"))
	
	var user_input = LineEdit.new()
	user_input.text = current_name
	user_input.custom_minimum_size = Vector2(250, 0)
	user_input.caret_blink = true
	user_input.select_all()
	
	var label = Label.new()
	label.text = "Enter a new designation for this ship:"
	
	var vbox = VBoxContainer.new()
	vbox.add_child(label)
	vbox.add_child(user_input)
	
	var dialog = ConfirmationDialog.new()
	dialog.title = "Rename Ship"
	dialog.add_child(vbox)
	add_child(dialog)
	
	dialog.about_to_popup.connect(func(): user_input.grab_focus())
	dialog.confirmed.connect(func():
		var new_val = user_input.text.strip_edges()
		if new_val != "" and new_val != current_name:
			var global_idx = campaign.fleets.find(selected_fleet)
			if global_idx != -1:
				campaign.rpc_rename_ship.rpc(global_idx, idx, new_val)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	
	dialog.popup_centered()

func _on_ship_selection_changed(_row, _selected):
	pass

func _execute_jump(target_id: String):
	if selected_fleet:
		ConsoleManager.log_message("DEBUG Map Executing Jump: %s -> %s" % [selected_fleet.current_system_id, target_id])
		if campaign.order_fleet_move(selected_fleet, target_id):
			ConsoleManager.log_message("[color=green]DEBUG Map Success![/color]")
			_log_event("%s has jumped for %s. ETA: Day %d." % [selected_fleet.fleet_name, target_id, campaign.TRANSIT_DAYS])
			plot_jump_btn.button_pressed = false
			plot_jump_btn.disabled = true
			cancel_jump_btn.disabled = false
			_update_fleet_list()
			# Re-select the fleet to highlight it
			for i in range(fleet_list.item_count):
				if fleet_list.get_item_metadata(i) == selected_fleet:
					fleet_list.select(i)
					break
			_update_composition_panel()
			_draw_fleets()
			_draw_routes()
		else:
			ConsoleManager.log_message("[color=red]DEBUG Map Execute Jump FAILED from CampaignManager.order_fleet_move[/color]")

func _on_cancel_jump_pressed():
	if selected_fleet == null or not selected_fleet.is_moving():
		return
		
	_log_event("Movement order cancelled for %s." % selected_fleet.fleet_name)
	campaign.cancel_fleet_move(selected_fleet)
	
	cancel_jump_btn.disabled = true
	plot_jump_btn.disabled = false
	plot_jump_btn.button_pressed = false
	
	_update_fleet_list()
	for i in range(fleet_list.item_count):
		if fleet_list.get_item_metadata(i) == selected_fleet:
			fleet_list.select(i)
			break
	_update_composition_panel()
	_draw_fleets()
	_draw_routes()

func _on_end_turn_pressed():
	if campaign.active_encounters.size() > 0:
		ConsoleManager.log_message("[color=red]Cannot end turn while encounters are unresolved![/color]")
		return
		
	var my_fac = _get_my_faction()
	if my_fac in ["UPF", "Sathar"]:
		var other_fac = "Sathar" if my_fac == "UPF" else "UPF"
		end_turn_btn.disabled = true
		turn_status_label.text = "Waiting for %s to confirm day %d operations." % [other_fac, campaign.current_day]
		campaign.request_end_turn.rpc_id(1, my_fac)
	else:
		# Fallback if testing locally as GM
		campaign.request_end_turn("UPF")
		campaign.request_end_turn("Sathar")

func _on_turn_ready_changed(upf_ready: bool, sathar_ready: bool):
	var my_fac = _get_my_faction()
	var other_fac = "Sathar" if my_fac == "UPF" else "UPF"
	
	if my_fac == "UPF" and upf_ready and not sathar_ready:
		turn_status_label.text = "Waiting for Sathar to confirm day %d operations." % campaign.current_day
	elif my_fac == "Sathar" and sathar_ready and not upf_ready:
		turn_status_label.text = "Waiting for UPF to confirm day %d operations." % campaign.current_day
	elif not upf_ready and not sathar_ready:
		turn_status_label.text = "" # Will reset normally with _on_day_advanced

func _on_day_advanced(day: int):
	# Re-enable the button
	end_turn_btn.disabled = false
	turn_status_label.text = ""
	_update_ui()
	_on_resize() # Re-draw systems (for encounter circles), fleets, and routes

func _on_fleet_arrived(fleet: CampaignFleet, sys_id: String):
	_log_event("%s arrived at %s." % [fleet.fleet_name, sys_id])
	_draw_fleets()

func _on_encounter(sys_id, upf, sathar):
	_log_event("COMBAT TRIGGERED AT %s!" % sys_id)
	pass

func _handle_encounter_click(sys_name: String):
	ConsoleManager.log_message("DEBUG: _handle_encounter_click called for " + sys_name)
	# Don't open duplicates
	if is_instance_valid(active_encounter_dialog) and active_encounter_dialog.get_meta("sys_name") == sys_name:
		ConsoleManager.log_message("DEBUG: _handle_encounter_click aborted (EncounterDialog for this system already exists!)")
		return
	elif is_instance_valid(active_encounter_dialog):
		active_encounter_dialog.queue_free()
		
	var my_fac = _get_my_faction()
	ConsoleManager.log_message("DEBUG: _handle_encounter_click proceeding for faction " + my_fac)
	var is_defender = false
	
	# Determine if we are defending (UPF has stations, or we check who has militia)
	if sys_name in campaign.UPF_FORTRESSES or sys_name in campaign.UPF_ARMED_STATIONS:
		is_defender = (my_fac == "UPF")
	else:
		# Simple fallback: if Sathar is present, they are usually attacking deeply into UPF space.
		is_defender = (my_fac == "UPF")
		
	var layer = CanvasLayer.new()
	layer.name = "EncounterDialog"
	layer.layer = 95
	layer.set_meta("sys_name", sys_name)
		
	active_encounter_dialog = layer
		
	# Build the popup UI panel
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 350)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Combat Encounter: " + sys_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var hs = HSeparator.new()
	vbox.add_child(hs)
	
	var ship_list_label = RichTextLabel.new()
	ship_list_label.bbcode_enabled = true
	ship_list_label.custom_minimum_size = Vector2(0, 150)
	ship_list_label.text = "[b]Friendly Forces Present:[/b]\n"
	
	var friendly_ships = []
	var has_militia = false
	
	# Check for UPF Stations if we are UPF
	if my_fac == "UPF":
		if sys_name in campaign.UPF_FORTRESSES:
			friendly_ships.append({"class": "Space Station (Fortress)", "name": "Fortress " + sys_name})
			ship_list_label.text += "[color=green]Fortress %s - READY[/color]\n" % sys_name
		elif sys_name in campaign.UPF_ARMED_STATIONS:
			friendly_ships.append({"class": "Space Station", "name": sys_name + " Station"})
			ship_list_label.text += "[color=green]Space Station %s - READY[/color]\n" % sys_name
			
	# Append ships from fleets
	for f in campaign.fleets:
		if f.current_system_id == sys_name and not f.is_moving() and f.faction == my_fac:
			for s in f.ships:
				var hp = 100
				var sn = "Ship"
				var cls = "Unknown"
				if typeof(s) == TYPE_DICTIONARY:
					sn = s.get("name", "Ship")
					cls = s.get("class", "Unknown")
					hp = int(s.get("hull", 100))
					if s.get("is_militia", false): has_militia = true
				if hp < 50:
					ship_list_label.text += "[color=red]%s (%s) - Hull: %d%% - CRIPPLED[/color]\n" % [sn, cls, hp]
				elif hp < 100:
					ship_list_label.text += "[color=yellow]%s (%s) - Hull: %d%% - DAMAGED[/color]\n" % [sn, cls, hp]
				else:
					ship_list_label.text += "[color=green]%s (%s) - Hull: %d%% - READY[/color]\n" % [sn, cls, hp]
				friendly_ships.append(s)
	
	vbox.add_child(ship_list_label)
	
	var routes_dropdown = OptionButton.new()
	var valid_routes = []
	if is_defender:
		var retreat_label = Label.new()
		retreat_label.text = "Select Retreat Destination:"
		vbox.add_child(retreat_label)
		
		# Find connected systems
		for route in campaign.routes:
			var target = ""
			var origin = route.get("origin", "")
			var dest = route.get("destination", "")
			if origin == sys_name: target = dest
			elif dest == sys_name: target = origin
			
			if target != "":
				var dist = campaign.TRANSIT_DAYS # Simplified fallback
				valid_routes.append({"sys": target, "dist": dist})
				routes_dropdown.add_item("%s (%d Days Transit)" % [target, dist])
				
		if has_militia:
			var mil_warning = Label.new()
			mil_warning.text = "WARNING: Militia ships cannot retreat from their home system."
			mil_warning.modulate = Color.ORANGE
			vbox.add_child(mil_warning)
			
		vbox.add_child(routes_dropdown)
	else:
		var attack_lbl = Label.new()
		attack_lbl.text = "You are the Attacker."
		attack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(attack_lbl)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var close_btn = Button.new()
	close_btn.text = "Cancel"
	close_btn.pressed.connect(func():
		layer.name = "ClosingDialog" 
		layer.queue_free()
	)
	btn_hbox.add_child(close_btn)
	
	if is_defender and valid_routes.size() > 0 and friendly_ships.size() > 0:
		var retreat_btn = Button.new()
		retreat_btn.text = "Order Fleet Retreat"
		var callable_retreat = func():
			var selected_idx = routes_dropdown.selected
			var target_sys = valid_routes[selected_idx]["sys"]
			_execute_retreat(sys_name, target_sys)
			if is_instance_valid(active_encounter_dialog):
				active_encounter_dialog.queue_free()
				active_encounter_dialog = null
		retreat_btn.pressed.connect(callable_retreat)
		btn_hbox.add_child(retreat_btn)
		
	var start_battle_btn = Button.new()
	start_battle_btn.text = "Ready For Battle"
	start_battle_btn.modulate = Color(1.0, 0.4, 0.4)
	start_battle_btn.pressed.connect(func():
		start_battle_btn.text = "Waiting for other player..."
		start_battle_btn.disabled = true
		_initiate_tactical_battle(sys_name)
	)
	btn_hbox.add_child(start_battle_btn)
	
	vbox.add_child(btn_hbox)
	layer.add_child(panel)
	add_child(layer)
	ConsoleManager.log_message("DEBUG: _handle_encounter_click successfully added EncounterDialog to UI tree.")

func _execute_retreat(from_sys: String, to_sys: String):
	ConsoleManager.log_message("Ordering Retreat from %s to %s" % [from_sys, to_sys])
	var my_fac = _get_my_faction()
	for f in campaign.fleets:
		if f.current_system_id == from_sys and not f.is_moving() and f.faction == my_fac:
			# Militia stripping could happen here, or handled inside start_move
			campaign.order_fleet_move(f, to_sys)
			
	# Update map to remove encounter circle potentially if fleet evacuated?
	# We should really sync this so Sathar knows UPF retreated.
	# With RPC order_fleet_move it broadcasts correctly.

func _initiate_tactical_battle(sys_name: String):
	ConsoleManager.log_message("[color=red]Confirming Readiness for Tactical Battle at %s...[/color]" % sys_name)
	var my_fac = _get_my_faction()
	CampaignManager.rpc_id(1, "set_encounter_ready", sys_name, my_fac, true)
