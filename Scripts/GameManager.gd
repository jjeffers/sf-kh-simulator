class_name GameManager
extends Node2D


@export var map_radius: int = 35

var ships: Array[Ship] = []
var campaign_casualties: Array[Ship] = []
const LOG_FILE = "user://game_log.txt"
var current_side_id: int = 1 # The "Active" moving side
var firing_side_id: int = 0 # The side currently firing in Combat Phase
var my_side_id: int = 0 # 0 = All/Debug, otherwise specific Side ID (1 or 2)
var selected_ship: Ship = null
var combat_target: Ship = null

# Initiative / Turn Order
var turn_order: Array[int] = [1, 2] # Side 1, Side 2
var current_turn_order_index: int = 0

@export var camera_speed: float = 500.0

var camera: Camera2D = null
var target_zoom: Vector2 = Vector2.ONE
const ZOOM_MIN = Vector2(0.2, 0.2)
const ZOOM_MAX = Vector2(2.0, 2.0)
const ZOOM_SPEED = 0.1

# Phase Enum
enum Phase {START, DEPLOYMENT, MOVEMENT, COMBAT, REPAIR, END}
# Combat State Enum
enum CombatState {NONE, PLANNING, RESOLVING}

var current_phase: Phase = Phase.START
var current_combat_state: CombatState = CombatState.NONE

# Deployment State
var deployment_subphase: int = 0 # 1 = Side 1 deploying, 2 = Side 2 deploying
var has_deployed_side_1: bool = false
var has_deployed_side_2: bool = false

# Combat Subphase: 0 = None, 1 = Passive Fire (First), 2 = Active Fire (Second)
var combat_subphase: int = 0

# Repair State
var repair_subphase: int = 0 # 1 = Side 1 plan, 2 = Side 2 plan, 3 = Execute
var repair_allocations: Dictionary = {} # { "ship_name": { "damage_key": DCR_amount } }
var active_repair_animations: int = 0
var has_submitted_final_repairs: bool = false

# Deployment UI Nodes
var panel_deployment: PanelContainer
var list_deployment: VBoxContainer
var btn_deploy_ship: Button
var btn_deploy_complete: Button
var btn_deploy_mine: Button
var btn_deploy_seeker: Button
var spin_deploy_speed: SpinBox
var lbl_deploy_facing: Label
var btn_deploy_facing_cw: Button
var btn_deploy_facing_ccw: Button
var btn_auto_deploy: Button

var deploy_speed_val: int = 0
var deploy_facing_val: int = 0
var deploy_tentative_hex: Vector3i = Vector3i.ZERO
var deploy_hex_selected: bool = false
var is_deploying_ship: bool = false

var deploy_orbit_dir_val: int = 1
var btn_deploy_orbit_cw: Button
var btn_deploy_orbit_ccw: Button
var hbox_deploy_orbit: HBoxContainer

# Deployment Mines Tracker
var deployment_mines_placed: Array[Vector3i] = []
var state_deployment_mine_placement = false
var deployment_seekers_placed: Array[Vector3i] = []
var state_deployment_seeker_placement = false

# Repair UI Nodes
var panel_repair: PanelContainer
var list_repair: VBoxContainer
var btn_repair_exec: Button

# Movement State references need to be reset properly

# UI Nodes

# UI Nodes
var ui_layer: CanvasLayer
var btn_commit: Button
var btn_undo: Button
var label_phase_indicator: Label # NEW: Phase Indicator Label


var btn_orbit_cw: Button
var btn_orbit_ccw: Button
var btn_ms_toggle: CheckBox
var opt_active_screen: OptionButton
var btn_exec_move: Button # NEW: Manual Phase Transition
var btn_dock: Button
var btn_rearm: Button
var btn_drop_mine: Button # NEW: Mine placement flag
var btn_drop_seeker: Button # NEW: Seeker placement flag
var btn_withdraw: Button # NEW: Strategic Retreat flag

# Mines State
var active_mines: Array[Dictionary] = [] # Format: {"pos": Vector3i, "side_id": int, "owner_name": String}
var state_mine_placement: bool = false # Tracks if UI is in "select hex to drop mine" mode

# Seekers State
var active_seekers: Array[Dictionary] = [] # Format: {"pos": Vector3i, "side_id": int, "owner_name": String, "speed": int}
var state_seeker_placement: bool = false # Tracks if UI is in "select hex to drop seeker" mode

# Movement State
var ghost_ship: Ship = null
var current_path: Array[Vector3i] = [] # List of hexes visited
var movement_history: Array = [] # Stack of partial states for Undo
var turns_remaining: int = 0
var step_entry_facing: int = 0 # FACING LOGIC REFINEMENT: Tracks facing as we entered the *current* hex step.
var start_speed: int = 0
var can_turn_this_step: bool = false # "Use it or lose it" flag
var turn_taken_this_step: int = 0 # -1 Left, 0 None, 1 Right
var combat_action_taken: bool = false # Lock to prevent click spam
var start_ms_active: bool = false # Track initial state for cost logic
var _e_key_last_press: int = 0

# Ghost Ship Visualization State
var ghost_head_pos: Vector3i
var ghost_head_facing: int = 0
var path_preview_active: bool = false
var has_suffered_gravity_this_turn: bool = false # TRACKER: Gravity adjacency forced turn penalty
var mr_expenditures: Array[Dictionary] = [] # Stores {"pos": Vector3i, "text": String}
var gravity_penalty_applied_this_turn: bool = false
var free_gravity_turn_used: bool = false
var test_force_online: bool = false # For Unit Testing Network Logic

# --- UI References ---
var queued_attacks: Array = [] # Objects: {source, target, weapon_idx}
var pending_resolutions: Array = []

# Environment
var planet_hexes: Array[Vector3i] = []

# Scenario Rules
var current_scenario_rules: Array = []
var turn_count: int = 1 # Track player turns
var game_seed: int = 12345 # Synchronized RNG payload from Host


# Planning UI
var panel_planning: PanelContainer
var container_ships: VBoxContainer
var panel_movement: PanelContainer # NEW: Movement Status Panel
var list_movement: VBoxContainer # NEW
var panel_attack_queue: PanelContainer # NEW: Attack Queue Panel
var list_attack_queue: VBoxContainer # NEW
var btn_clear_all: Button # NEW: Clear All Attacks Button

# ICM UI
signal icm_decision_made(allocations: Dictionary)
var panel_icm: PanelContainer

# Visuals
var selection_highlight: Polygon2D = null
var current_connected_ship: Ship = null

func _on_ship_state_changed():
	if ship_status_panel and is_instance_valid(selected_ship):
		ship_status_panel.update_from_ship(selected_ship)


# ICM State Variables
var _icm_decision_received: bool = false
var _icm_current_allocations: Dictionary = {}

func _ready():
	_init_log_file()
	# Ensure RNG is randomized
	randomize()
	# Camera Setup
	camera = Camera2D.new()
	camera.name = "MainCamera"
	add_child(camera)
	camera.make_current()
	
	_setup_ui()
	_setup_selection_highlight()
	_setup_background()
	queue_redraw()
	_spawn_planets()
	_setup_network_identity()
	
	# Handle dynamic resolution changes gracefully
	if not get_tree().get_root().size_changed.is_connected(_on_window_resized):
		get_tree().get_root().size_changed.connect(_on_window_resized)

func _on_window_resized():
	# Redraw the grid to adjust to new window dimensions
	queue_redraw()
	# Update camera limits/centering if necessary
	_update_camera()

func _setup_background():
	# Static Starfield using ParallaxBackground and Downloaded Texture
	var texture = load("res://Assets/starfield_background.png")
	if not texture:
		push_error("Failed to load background texture: res://Assets/starfield_background.png")
		return

	var bg = ParallaxBackground.new()
	bg.name = "StarfieldBackground"
	bg.scroll_ignore_camera_zoom = true
	add_child(bg)
	
	var layer = ParallaxLayer.new()
	layer.name = "StarsLayer"
	layer.motion_scale = Vector2(0.05, 0.05) # Distant stars
	
	# TextureRect approach for infinite tiling
	var rect = TextureRect.new()
	rect.texture = texture
	# Enable Tiling and Repeat
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Make it huge to cover screen at any zoom (e.g. 4096 or larger)
	# Since movement is relative to camera, we just need it big enough to tile.
	# With mirroring, it just needs to be >= viewport size.
	# Let's make it 4096 to be safe.
	var tile_size = Vector2(4096, 4096)
	rect.size = tile_size
	rect.position = - tile_size / 2 # Center it
	
	# Parallax Mirroring must match the rect size for seamless scrolling
	layer.motion_mirroring = tile_size
	
	bg.add_child(layer)
	layer.add_child(rect)

func _setup_network_identity():
	# Network Setup
	var setup = NetworkManager.game_setup_data if NetworkManager.game_setup_data != null else {}
	# Lobby Data fallback
	var lobby = NetworkManager.lobby_data if NetworkManager.lobby_data != null else {}
	var scen_key = lobby.get("scenario", null)
	
	var peer_id = 1 # Default (Server)
	if _is_networked():
		peer_id = (multiplayer.get_unique_id() if _is_networked() else 1)
		
	# Determine MY Team ID (1 or 2)
	# If in Lobby, we use lobby["teams"].
	# If standalone, we default to 1 (P1) or 0 (Spectator)?
	# Legacy fallback:
	# Legacy fallback:
	if lobby["teams"].has(peer_id):
		my_side_id = lobby["teams"][peer_id]
	else:
		my_side_id = 0 # Default to Spectator if not found
		print("[DEBUG] GameManager: Peer %d NOT in Lobby Teams. Defaulting to 0 (Spectator). Teams: %s" % [peer_id, lobby["teams"]])
		
	# Legacy "host_side" override if lobby incomplete
	if setup and not setup.is_empty():
		scen_key = setup.get("scenario", null)
		var h_side = setup.get("host_side", 0)
		var h_pid = h_side + 1
		
		# Allow override if I am the host (ID 1)
		if peer_id == 1:
			my_side_id = h_pid
		else:
			my_side_id = (h_pid % 2) + 1
		print("[DEBUG] GameManager: Applying Game Setup Override. My Side ID: %d" % my_side_id)
		
		# Determine Identity
		if peer_id == 1:
			my_side_id = h_pid
			log_message("Network: Host playing as Side %d" % my_side_id)
		else:
			# Assuming 2 player for now
			my_side_id = 3 - h_pid
			log_message("Network: Client playing as Side %d" % my_side_id)


	else:
		# Fallback / Debug
		if my_side_id == 0:
			if _is_server_or_offline():
				my_side_id = 1 # Host defaults to Side 1 (Attacker usually)
			else:
				my_side_id = 2 # Client defaults to Side 2 (Defender usually)
			log_message("Network: Default Assignment (Host=1, Client=2). My Side: %d" % my_side_id)
		

		
	# Set Window Title for Easy Identification
	var side_name = get_side_name(my_side_id)
	var title = "Hex Space Combat - Player %d (%s)" % [my_side_id, side_name]
	get_window().title = title

	# Force UI Update to show Side ID immediately
	_update_ui_state()
	_update_phase_indicator() # NEW
		
	# Game Start Handshake
	if _is_networked():
		# Notify Host that we are loaded
		player_loaded.rpc_id(1)
	else:
		# Offline / Testing
		log_message("Offline Mode: Starting Game immediately.")
		var seed_val = randi()
		setup_game(seed_val, scen_key if scen_key else "")

var loaded_players = {}

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	var sender_id = 1
	if _is_networked():
		sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = (multiplayer.get_unique_id() if _is_networked() else 1) # Local call
	
	log_message("Player %d finished loading." % sender_id)
	loaded_players[sender_id] = true
	
	if _is_server_or_offline():
		_check_all_players_ready()

func _check_all_players_ready():
	var all_ready = true
	for pid in NetworkManager.players:
		if not loaded_players.has(pid):
			all_ready = false
			break
	
	if all_ready:
		log_message("All Players Ready. Starting Game...")
		
		# Generate Seed
		var seed_val = randi()
		print("GameManager: Generated Random Seed: %d" % seed_val)
		
		# Determine Scenario Key
		var lobby = NetworkManager.lobby_data
		var setup = NetworkManager.game_setup_data
		var scen_key = lobby.get("scenario", null)
		if setup and not setup.is_empty():
			scen_key = setup.get("scenario", null)
		if _is_networked():
			setup_game.rpc(seed_val, scen_key if scen_key else "")
		else:
			setup_game(seed_val, scen_key if scen_key else "")

@rpc("authority", "call_local", "reliable")
func setup_game(seed_val: int, scen_key: String):
	log_message("Game Setup Received: Seed %d" % seed_val)
	load_scenario(scen_key, seed_val)
	_load_planets_from_scenario(scen_key)
	start_deployment_phase(scen_key)

func start_deployment_phase(scen_key: String = ""):
	current_phase = Phase.DEPLOYMENT
	log_message("[color=cyan]=== DEPLOYMENT Phase ===[/color]")
	has_deployed_side_1 = false
	has_deployed_side_2 = false

	_spawn_computer_opponents()
	
	# UPF sets up first in these specific scenarios as Defenders.
	if scen_key == "":
		scen_key = NetworkManager.lobby_data.get("scenario", "simple_test")
		
	if scen_key in ["surprise_attack", "the_last_stand", "battle_of_kenzah", "campaign_encounter"]:
		# Dynamically determine which side is the Defender
		var scen = ScenarioManager.get_scenario(scen_key)
		var defender_side_id = 1 # Default fallback
		if scen.has("sides"):
			for idx in scen["sides"]:
				if scen["sides"][idx].get("role") == "Defender":
					defender_side_id = int(str(idx)) + 1
					break
		deployment_subphase = defender_side_id
	else:
		deployment_subphase = 2
	
	_update_ui_state()
	_update_deployment_ui()

func _process(delta):
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1
	
	if move_vec != Vector2.ZERO:
		camera.position += move_vec.normalized() * camera_speed * delta / camera.zoom.x
		
	# Smooth Zoom
	camera.zoom = camera.zoom.lerp(target_zoom, 0.1)

	if Input.is_key_pressed(KEY_SPACE):
		_update_camera()

	if Input.is_action_just_pressed("ui_focus_next"): # TAB usually
		_cycle_selection()
		
	if Input.is_key_pressed(KEY_E):
		# Create a cooldown/debounce since is_key_pressed fires every frame
		if Time.get_ticks_msec() - _e_key_last_press > 250:
			_e_key_last_press = Time.get_ticks_msec()
			if current_phase == Phase.COMBAT:
				_cycle_targets()

	if selection_highlight:
		if is_instance_valid(selected_ship):
			selection_highlight.visible = true
			selection_highlight.position = HexGrid.hex_to_pixel(selected_ship.grid_position)
			# Pulse Alpha
			var time = Time.get_ticks_msec() / 200.0
			var alpha = (sin(time) + 1.0) / 2.0 * 0.4 + 0.2
			selection_highlight.color = Color(1, 1, 0, alpha)
		else:
			selection_highlight.visible = false

	# Ghost Ship Hover Preview (Moved from _unhandled_input for reliability)
	# Authority Check: Only allow preview updates if it is my turn/ship
	var is_my_turn_process = (my_side_id == current_side_id) or _has_admin_authority()
	
	if current_phase == Phase.MOVEMENT and is_my_turn_process and ghost_ship and is_instance_valid(ghost_ship) and selected_ship and not selected_ship.has_moved and not selected_ship.has_orders:
		var local_mouse = get_local_mouse_position()
		var hex_hover = HexGrid.pixel_to_hex(local_mouse)
		
		# Check if hovering over current path or start position
		var on_path = current_path.has(hex_hover) or hex_hover == selected_ship.grid_position
		
		if on_path:
			_handle_path_hover(hex_hover)
		else:
			_handle_preview_extension(hex_hover)
			
			# This replaces the logic in _unhandled_input to avoid 1-frame lag when leaving preview zone
			if not path_preview_active:
				_handle_mouse_facing(hex_hover)
	
	elif current_phase == Phase.DEPLOYMENT and is_deploying_ship and is_instance_valid(selected_ship) and deploy_hex_selected:
		# Space Stations and Stations don't have facing or speed mechanics during deployment
		if selected_ship.ship_class not in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
			# Check if it's my turn
			if deployment_subphase == my_side_id or my_side_id == 0:
				var local_mouse = get_local_mouse_position()
				var hex_hover = HexGrid.pixel_to_hex(local_mouse)
				
				if hex_hover != deploy_tentative_hex:
					var dir = HexGrid.get_hex_direction(deploy_tentative_hex, hex_hover)
					if dir != -1:
						deploy_facing_val = dir
						
					var dist = HexGrid.hex_distance(deploy_tentative_hex, hex_hover)
					deploy_speed_val = clampi(dist, 0, 20)
					
					var scen_key = ""
					if NetworkManager.lobby_data != null:
						scen_key = NetworkManager.lobby_data.get("scenario", "")
					if scen_key == "close_escort" and selected_ship.name == "Megasaurus":
						deploy_speed_val = 5
						deploy_facing_val = 3
					
					_update_deploy_preview()
					if is_instance_valid(lbl_deploy_facing): lbl_deploy_facing.text = str(deploy_facing_val)
					if is_instance_valid(spin_deploy_speed): spin_deploy_speed.value = deploy_speed_val
			
func _setup_selection_highlight():
	selection_highlight = Polygon2D.new()
	selection_highlight.name = "SelectionHighlight"
	var points = PackedVector2Array()
	var size = HexGrid.TILE_SIZE * 0.95 # Slightly smaller than hex
	for i in range(6):
		var angle_deg = 60 * i - 30
		var angle_rad = deg_to_rad(angle_deg)
		points.append(Vector2(size * cos(angle_rad), size * sin(angle_rad)))
	selection_highlight.polygon = points
	selection_highlight.color = Color(1, 1, 0, 0.4)
	add_child(selection_highlight)
	move_child(selection_highlight, 0) # Draw behind ships/planets if possible

func _setup_ui():
	if ui_layer:
		ui_layer.queue_free()
		
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# NEW: Phase Indicator (Top Center)
	var panel_phase = PanelContainer.new()
	panel_phase.anchor_left = 0.5
	panel_phase.anchor_right = 0.5
	panel_phase.anchor_top = 0.0
	panel_phase.offset_top = 10
	panel_phase.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui_layer.add_child(panel_phase)
	
	label_phase_indicator = Label.new()
	label_phase_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_phase_indicator.add_theme_font_size_override("font_size", 24)
	panel_phase.add_child(label_phase_indicator)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	ui_layer.add_child(vbox)
	
	label_status = Label.new()
	label_status.visible = true # Repurposed for Phase Info & Planned Attacks
	# Ensure it doesn't overlap with ShipStatusPanel. 
	# ShipStatusPanel is added to vbox FIRST. 
	# Let's add label_status AFTER ShipStatusPanel, or Keep it at top but ensure content is distinct.
	# Actually, ShipStatusPanel is added to vbox. label_status was added to vbox.
	# If we want label_status to show "Planned Attacks", it might be better below the ship panel.
	vbox.add_child(label_status)
	
	# New Ship Status Panel
	var panel_script = load("res://Scripts/ShipStatusPanel.gd")
	if panel_script is GDScript:
		ship_status_panel = panel_script.new()
		vbox.add_child(ship_status_panel)
	else:
		push_error("CRITICAL: Failed to load ShipStatusPanel.gd! UI will be incomplete.")

	_build_deployment_panel(vbox)
	_build_repair_panel(vbox)
	_build_summary_panel()


	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	btn_undo = Button.new()
	btn_undo.text = "Undo"
	btn_undo.pressed.connect(_on_undo)
	hbox.add_child(btn_undo)
	
	btn_commit = Button.new()
	btn_commit.text = "Engage"
	btn_commit.pressed.connect(_on_commit_move)
	vbox.add_child(btn_commit)
	
	btn_drop_mine = Button.new()
	btn_drop_mine.text = "Drop Mine"
	btn_drop_mine.pressed.connect(_on_drop_mine_pressed)
	btn_drop_mine.visible = false
	btn_drop_mine.theme_type_variation = "FlatButton"
	vbox.add_child(btn_drop_mine)
	
	btn_drop_seeker = Button.new()
	btn_drop_seeker.text = "Drop Seeker"
	btn_drop_seeker.pressed.connect(_on_drop_seeker_pressed)
	btn_drop_seeker.visible = false
	btn_drop_seeker.theme_type_variation = "FlatButton"
	vbox.add_child(btn_drop_seeker)
	
	# Turn Buttons Removed (Mouse Gesture Only)
	
	# Orbit Buttons
	var orbit_box = HBoxContainer.new()
	vbox.add_child(orbit_box)
	
	btn_orbit_cw = Button.new()
	btn_orbit_cw.text = "Orbit CW"
	btn_orbit_cw.pressed.connect(func(): _on_orbit(1))
	btn_orbit_cw.visible = false
	orbit_box.add_child(btn_orbit_cw)
	
	btn_orbit_ccw = Button.new()
	btn_orbit_ccw.text = "Orbit CCW"
	btn_orbit_ccw.pressed.connect(func(): _on_orbit(-1))
	btn_orbit_ccw.visible = false
	orbit_box.add_child(btn_orbit_ccw)
	
	# Docking / Re-arming Buttons
	var dock_box = HBoxContainer.new()
	vbox.add_child(dock_box)
	
	btn_dock = Button.new()
	btn_dock.text = "Dock"
	btn_dock.pressed.connect(_on_dock_pressed)
	btn_dock.visible = false
	dock_box.add_child(btn_dock)
	
	btn_rearm = Button.new()
	btn_rearm.text = "Re-arm"
	btn_rearm.pressed.connect(_on_rearm_pressed)
	btn_rearm.visible = false
	dock_box.add_child(btn_rearm)
	
	btn_withdraw = Button.new()
	btn_withdraw.text = "Withdraw"
	btn_withdraw.pressed.connect(_on_withdraw_pressed)
	btn_withdraw.visible = false
	btn_withdraw.modulate = Color(1, 0.5, 0.2)
	vbox.add_child(btn_withdraw)
	
	# MS Toggle
	btn_ms_toggle = CheckBox.new()
	btn_ms_toggle.text = "Deploy Screen"
	btn_ms_toggle.toggled.connect(_on_ms_toggled)
	btn_ms_toggle.visible = false
	vbox.add_child(btn_ms_toggle)
	
	# Active Screen Dropdown
	opt_active_screen = OptionButton.new()
	opt_active_screen.item_selected.connect(_on_active_screen_selected)
	opt_active_screen.visible = false
	vbox.add_child(opt_active_screen)
	
	# Attack Queue Panel
	panel_attack_queue = PanelContainer.new()
	panel_attack_queue.visible = false
	vbox.add_child(panel_attack_queue)
	
	var aq_vbox = VBoxContainer.new()
	panel_attack_queue.add_child(aq_vbox)
	
	var aq_header = HBoxContainer.new()
	aq_vbox.add_child(aq_header)
	
	var aq_lbl = Label.new()
	aq_lbl.text = "[!] PLANNED ATTACKS"
	aq_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aq_header.add_child(aq_lbl)
	
	btn_clear_all = Button.new()
	btn_clear_all.text = "[Clear All]"
	btn_clear_all.pressed.connect(func(): _clear_all_attacks())
	aq_header.add_child(btn_clear_all)
	
	list_attack_queue = VBoxContainer.new()
	aq_vbox.add_child(list_attack_queue)

	
	# Planning UI (Right Side)
	panel_planning = PanelContainer.new()
	# Fixed Top Right, Below Minimap (Margin 20)
	# Minimap Bottom is 220 (20+200). So Panel Top should be ~240.
	panel_planning.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	panel_planning.offset_top = 240 # Override top to be below minimap
	panel_planning.offset_bottom = -240 # Add bottom constraint so it doesn't overlap the log or go off-screen
	if panel_planning.anchor_bottom == 0.0:
		panel_planning.anchor_bottom = 1.0 # Anchor to bottom
	panel_planning.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel_planning.custom_minimum_size.x = 220
	panel_planning.visible = false
	ui_layer.add_child(panel_planning)
	
	# Movement UI (Same position as Planning UI)
	panel_movement = PanelContainer.new()
	panel_movement.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	panel_movement.offset_top = 240
	panel_movement.offset_bottom = -240 # Add bottom constraint so it doesn't overlap the log or go off-screen
	if panel_movement.anchor_bottom == 0.0:
		panel_movement.anchor_bottom = 1.0 # Anchor to bottom
	panel_movement.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel_movement.custom_minimum_size.x = 220
	panel_movement.visible = false
	ui_layer.add_child(panel_movement)
	
	var pm_vbox = VBoxContainer.new()
	panel_movement.add_child(pm_vbox)
	
	var pm_lbl = Label.new()
	pm_lbl.text = "Fleet Status"
	pm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pm_vbox.add_child(pm_lbl)
	
	var scroll_movement = ScrollContainer.new()
	scroll_movement.custom_minimum_size = Vector2(0, 150) # Fallback min size
	scroll_movement.size_flags_vertical = Control.SIZE_EXPAND_FILL # Expands to fill available space
	scroll_movement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pm_vbox.add_child(scroll_movement)
	
	list_movement = VBoxContainer.new()
	list_movement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_movement.add_child(list_movement)
	
	# Execute Movement Button (Manual Phase End)
	btn_exec_move = Button.new()
	btn_exec_move.text = "EXECUTE MOVEMENT"
	btn_exec_move.modulate = Color(1, 0.6, 0.2) # Orange-ish
	btn_exec_move.visible = false
	btn_exec_move.pressed.connect(func(): _on_exec_move_pressed())
	pm_vbox.add_child(btn_exec_move)
	
	btn_repair_exec = Button.new()
	btn_repair_exec.text = "EXECUTE REPAIRS"
	btn_repair_exec.modulate = Color(0.2, 1.0, 0.2)
	btn_repair_exec.visible = false
	btn_repair_exec.pressed.connect(_on_repair_exec_pressed)
	pm_vbox.add_child(btn_repair_exec)
	
	var pp_vbox = VBoxContainer.new()
	panel_planning.add_child(pp_vbox)
	
	var pp_lbl = Label.new()
	pp_lbl.text = "Attack Planning"
	pp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pp_vbox.add_child(pp_lbl)
	
	var scroll_planning = ScrollContainer.new()
	scroll_planning.custom_minimum_size = Vector2(0, 150)
	scroll_planning.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_planning.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pp_vbox.add_child(scroll_planning)
	
	container_ships = VBoxContainer.new()
	container_ships.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_planning.add_child(container_ships)
	
	# Execute Button
	var btn_exec = Button.new()
	btn_exec.text = "EXECUTE ATTACK"
	btn_exec.modulate = Color(1, 0.5, 0.5)
	btn_exec.pressed.connect(_on_combat_commit)
	pp_vbox.add_child(btn_exec)

	# Combat Log
	# Combat Log
	panel_log_container = PanelContainer.new()
	panel_log_container.visible = false
	# Explicit anchors for bottom 25% of screen
	panel_log_container.anchor_left = 0.0
	panel_log_container.anchor_right = 1.0
	panel_log_container.anchor_top = 0.75
	panel_log_container.anchor_bottom = 1.0
	panel_log_container.modulate.a = 0.8
	ui_layer.add_child(panel_log_container)
	
	combat_log = RichTextLabel.new()
	combat_log.scroll_following = true
	combat_log.bbcode_enabled = true
	combat_log.text = "[color=yellow]System Initialized.[/color]\n" # Debug text
	combat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_log_container.add_child(combat_log)
	
	# Game Over Panel
	panel_game_over = PanelContainer.new()
	panel_game_over.visible = false
	# Center it
	panel_game_over.anchors_preset = Control.PRESET_CENTER
	ui_layer.add_child(panel_game_over)
	
	var go_vbox = VBoxContainer.new()
	go_vbox.custom_minimum_size = Vector2(200, 100)
	panel_game_over.add_child(go_vbox)
	
	label_winner = Label.new()
	label_winner.text = "Winner!"
	label_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_winner.add_theme_font_size_override("font_size", 24)
	go_vbox.add_child(label_winner)
	
	btn_restart = Button.new()
	btn_restart.text = "Play Again"
	btn_restart.pressed.connect(_on_restart)
	go_vbox.add_child(btn_restart)
	
	# Center Message Overlay
	label_center_message = Label.new()
	label_center_message.text = ""
	label_center_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_center_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_center_message.anchors_preset = Control.PRESET_CENTER
	label_center_message.add_theme_font_size_override("font_size", 32)
	label_center_message.add_theme_color_override("font_color", Color.YELLOW)
	label_center_message.add_theme_color_override("font_outline_color", Color.BLACK)
	label_center_message.add_theme_constant_override("outline_size", 4)
	label_center_message.visible = false
	ui_layer.add_child(label_center_message)
	
	# Player Info (Top Right)
	label_player_info = Label.new()
	label_player_info.text = "Side: ?"
	label_player_info.add_theme_font_size_override("font_size", 20)
	label_player_info.add_theme_color_override("font_outline_color", Color.BLACK)
	label_player_info.add_theme_constant_override("outline_size", 4)
	# Anchor top right
	label_player_info.anchors_preset = Control.PRESET_TOP_RIGHT
	# Position: Just below minimap or above? Minimap is at x-220, y=20.
	# Let's put this to the left of minimap or below?
	# Minimap is 200x200.
	# Let's put it at Top Center-Right?
	label_player_info.position = Vector2(get_viewport_rect().size.x - 450, 10)
	ui_layer.add_child(label_player_info)
	
	# Audio Setup
	var audio_node = Node.new()
	audio_node.name = "AudioParams"
	add_child(audio_node)
	
	audio_laser = AudioStreamPlayer.new()
	audio_laser.stream = load("res://Assets/Audio/laser.mp3")
	audio_laser.bus = "SFX"
	add_child(audio_laser)
	
	audio_hit = AudioStreamPlayer.new()
	audio_hit.stream = load("res://Assets/Audio/hit.mp3")
	audio_hit.bus = "SFX"
	add_child(audio_hit)

	audio_beep = AudioStreamPlayer.new()
	audio_beep.stream = load("res://Assets/Audio/short-low-beep.mp3")
	audio_beep.bus = "SFX"
	add_child(audio_beep)

	audio_action_complete = AudioStreamPlayer.new()
	audio_action_complete.stream = load("res://Assets/Audio/short-next-selection.mp3")
	audio_action_complete.bus = "SFX"
	add_child(audio_action_complete)
	
	audio_phase_change = AudioStreamPlayer.new()
	# 'short-sound.mp3' was missing, using 'short-computer.mp3'
	audio_phase_change.stream = load("res://Assets/Audio/short-computer.mp3")
	audio_phase_change.bus = "SFX"
	add_child(audio_phase_change)

	audio_ship_select = AudioStreamPlayer.new()
	audio_ship_select.stream = load("res://Assets/Audio/short-departure.mp3")
	audio_ship_select.bus = "SFX"
	add_child(audio_ship_select)

	audio_repair_roll = AudioStreamPlayer.new()
	audio_repair_roll.bus = "SFX"
	if not OS.get_cmdline_args().has("--headless") and FileAccess.file_exists("res://Assets/Audio/glitch-sound-short.mp3.import"):
		audio_repair_roll.stream = load("res://Assets/Audio/glitch-sound-short.mp3")
	add_child(audio_repair_roll)

	audio_repair_success = AudioStreamPlayer.new()
	audio_repair_success.bus = "SFX"
	if not OS.get_cmdline_args().has("--headless") and FileAccess.file_exists("res://Assets/Audio/made-repair.mp3.import"):
		audio_repair_success.stream = load("res://Assets/Audio/made-repair.mp3")
	add_child(audio_repair_success)

	audio_repair_failure = AudioStreamPlayer.new()
	audio_repair_failure.bus = "SFX"
	if not OS.get_cmdline_args().has("--headless") and FileAccess.file_exists("res://Assets/Audio/failed-repair.mp3.import"):
		audio_repair_failure.stream = load("res://Assets/Audio/failed-repair.mp3")
	add_child(audio_repair_failure)

	# MiniMap
	# Add last to be on top? Or managing layout?
	# Top Right, fixed size
	# MiniMap
	# Add last to be on top? Or managing layout?
	# Top Right, fixed size
	mini_map = MiniMap.new()
	mini_map.game_manager = self
	mini_map.custom_minimum_size = Vector2(200, 200)
	# Position Top Right with margin
	mini_map.anchors_preset = Control.PRESET_TOP_RIGHT
	mini_map.position = Vector2(get_viewport_rect().size.x - 220, 20)
	# Make sure it stays anchored
	mini_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 20)
	ui_layer.add_child(mini_map)

func _build_deployment_panel(parent: Container):
	# Deployment Panel
	panel_deployment = PanelContainer.new()
	panel_deployment.visible = false
	parent.add_child(panel_deployment)
	
	var dep_vbox = VBoxContainer.new()
	panel_deployment.add_child(dep_vbox)
	
	var dep_header = Label.new()
	dep_header.text = "DEPLOYMENT PHASE"
	dep_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dep_header.add_theme_font_size_override("font_size", 18)
	dep_vbox.add_child(dep_header)
	
	# ScrollContainer for list of ships
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 150)
	dep_vbox.add_child(sc)
	
	list_deployment = VBoxContainer.new()
	list_deployment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_deployment)
	
	dep_vbox.add_child(HSeparator.new())
	
	# Facing Control
	var f_hbox = HBoxContainer.new()
	dep_vbox.add_child(f_hbox)
	var f_lbl = Label.new()
	f_lbl.text = "Facing:"
	f_hbox.add_child(f_lbl)
	
	btn_deploy_facing_ccw = Button.new()
	btn_deploy_facing_ccw.text = "<"
	btn_deploy_facing_ccw.disabled = true
	btn_deploy_facing_ccw.pressed.connect(func(): if is_deploying_ship: deploy_facing_val = (deploy_facing_val - 1 + 6) % 6; lbl_deploy_facing.text = str(deploy_facing_val); _update_deploy_preview())
	f_hbox.add_child(btn_deploy_facing_ccw)
	
	lbl_deploy_facing = Label.new()
	lbl_deploy_facing.text = "0"
	lbl_deploy_facing.custom_minimum_size = Vector2(20, 0)
	lbl_deploy_facing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f_hbox.add_child(lbl_deploy_facing)
	
	btn_deploy_facing_cw = Button.new()
	btn_deploy_facing_cw.text = ">"
	btn_deploy_facing_cw.disabled = true
	btn_deploy_facing_cw.pressed.connect(func(): if is_deploying_ship: deploy_facing_val = (deploy_facing_val + 1) % 6; lbl_deploy_facing.text = str(deploy_facing_val); _update_deploy_preview())
	f_hbox.add_child(btn_deploy_facing_cw)
	
	# Speed Control
	var s_hbox = HBoxContainer.new()
	dep_vbox.add_child(s_hbox)
	var s_lbl = Label.new()
	s_lbl.text = "Speed: "
	s_hbox.add_child(s_lbl)
	
	spin_deploy_speed = SpinBox.new()
	spin_deploy_speed.min_value = 0
	spin_deploy_speed.max_value = 20
	spin_deploy_speed.value = 0
	spin_deploy_speed.editable = false
	spin_deploy_speed.value_changed.connect(func(v): if is_deploying_ship: deploy_speed_val = int(v))
	s_hbox.add_child(spin_deploy_speed)
	
	dep_vbox.add_child(HSeparator.new())
	
	# Orbit Control (Station Only)
	hbox_deploy_orbit = HBoxContainer.new()
	dep_vbox.add_child(hbox_deploy_orbit)
	
	btn_deploy_orbit_ccw = Button.new()
	btn_deploy_orbit_ccw.text = "Orbit CCW"
	btn_deploy_orbit_ccw.disabled = true
	btn_deploy_orbit_ccw.custom_minimum_size.x = 100
	btn_deploy_orbit_ccw.pressed.connect(func():
		if is_deploying_ship or (is_instance_valid(selected_ship) and selected_ship.is_deployed):
			deploy_orbit_dir_val = -1
			if is_instance_valid(selected_ship) and selected_ship.is_deployed:
				selected_ship.orbit_direction = -1
			_update_deployment_ui()
			_update_deploy_preview()
			queue_redraw()
	)
	hbox_deploy_orbit.add_child(btn_deploy_orbit_ccw)
	
	btn_deploy_orbit_cw = Button.new()
	btn_deploy_orbit_cw.text = "Orbit CW"
	btn_deploy_orbit_cw.disabled = true
	btn_deploy_orbit_cw.custom_minimum_size.x = 100
	btn_deploy_orbit_cw.pressed.connect(func():
		if is_deploying_ship or (is_instance_valid(selected_ship) and selected_ship.is_deployed):
			deploy_orbit_dir_val = 1
			if is_instance_valid(selected_ship) and selected_ship.is_deployed:
				selected_ship.orbit_direction = 1
			_update_deployment_ui()
			_update_deploy_preview()
			queue_redraw()
	)
	hbox_deploy_orbit.add_child(btn_deploy_orbit_cw)
	
	dep_vbox.add_child(HSeparator.new())
	
	btn_deploy_ship = Button.new()
	btn_deploy_ship.text = "Set Deployment"
	btn_deploy_ship.disabled = true
	btn_deploy_ship.pressed.connect(_on_deploy_ship_pressed)
	dep_vbox.add_child(btn_deploy_ship)
	
	btn_deploy_mine = Button.new()
	btn_deploy_mine.text = "Place Mine (0 Left)"
	btn_deploy_mine.toggle_mode = true
	btn_deploy_mine.modulate = Color.ORANGE
	btn_deploy_mine.visible = false
	btn_deploy_mine.toggled.connect(func(toggled_on): 
		if current_phase == Phase.DEPLOYMENT:
			state_deployment_mine_placement = toggled_on
			_update_deployment_ui()
			queue_redraw()
	)
	dep_vbox.add_child(btn_deploy_mine)
	
	btn_deploy_seeker = Button.new()
	btn_deploy_seeker.text = "Place Seeker (0 Left)"
	btn_deploy_seeker.toggle_mode = true
	btn_deploy_seeker.modulate = Color.ORANGE
	btn_deploy_seeker.visible = false
	btn_deploy_seeker.toggled.connect(func(toggled_on): 
		if current_phase == Phase.DEPLOYMENT:
			state_deployment_seeker_placement = toggled_on
			_update_deployment_ui()
			queue_redraw()
	)
	dep_vbox.add_child(btn_deploy_seeker)
	
	btn_auto_deploy = Button.new()
	btn_auto_deploy.text = "AUTO DEPLOY"
	btn_auto_deploy.modulate = Color(0.2, 0.6, 1.0) # Light blue
	btn_auto_deploy.pressed.connect(_on_auto_deploy_pressed)
	dep_vbox.add_child(btn_auto_deploy)
	
	btn_deploy_complete = Button.new()
	btn_deploy_complete.text = "COMPLETE DEPLOYMENT"
	btn_deploy_complete.modulate = Color.GREEN
	btn_deploy_complete.pressed.connect(_on_deploy_complete_pressed)
	dep_vbox.add_child(btn_deploy_complete)
	
func _build_repair_panel(parent: Container):
	print("[DEBUG] _build_repair_panel called")
	log_message("[DEBUG] Initializing repair_panel")
	panel_repair = PanelContainer.new()
	panel_repair.custom_minimum_size = Vector2(300, 300)
	panel_repair.visible = false
	parent.add_child(panel_repair)
	
	var vbox = VBoxContainer.new()
	panel_repair.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "DAMAGE CONTROL (DCR)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)
	
	list_repair = VBoxContainer.new()
	list_repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_repair)

@rpc("any_peer", "call_local", "reliable")
func rpc_start_combat_passive():
	start_combat_passive()

	# Connect Minimap Layout Updates
	if not panel_planning.visibility_changed.is_connected(_update_minimap_position):
		panel_planning.visibility_changed.connect(_update_minimap_position)
	if not panel_planning.item_rect_changed.is_connected(_update_minimap_position):
		panel_planning.item_rect_changed.connect(_update_minimap_position)
	
	if not panel_movement.visibility_changed.is_connected(_update_minimap_position):
		panel_movement.visibility_changed.connect(_update_minimap_position)
	if not panel_movement.item_rect_changed.is_connected(_update_minimap_position):
		panel_movement.item_rect_changed.connect(_update_minimap_position)
	
	# Initial Position Update
	_update_minimap_position()

var audio_laser: AudioStreamPlayer
var audio_hit: AudioStreamPlayer
var audio_beep: AudioStreamPlayer
var audio_action_complete: AudioStreamPlayer
var audio_phase_change: AudioStreamPlayer
var audio_ship_select: AudioStreamPlayer
var audio_repair_roll: AudioStreamPlayer
var audio_repair_success: AudioStreamPlayer
var audio_repair_failure: AudioStreamPlayer
var mini_map: MiniMap

var combat_log: RichTextLabel
var panel_log_container: PanelContainer

# Game Over UI
var panel_game_over: PanelContainer
var label_winner: Label
var btn_restart: Button

var label_center_message: Label
var label_player_info: Label
var label_status: Label
var ship_status_panel # Typed as ShipStatusPanel, but checking if weak typing helps CI


func log_message(msg: String):
	# Add Turn Number
	var final_msg = "[Turn %d] %s" % [turn_count, msg]
	
	if combat_log:
		combat_log.append_text(final_msg + "\n")
	print(final_msg)
	_log_to_file(final_msg)
	
	if has_node("/root/ConsoleManager"):
		ConsoleManager.log_message(final_msg)

@rpc("any_peer", "call_local", "reliable")
func rpc_log_message(msg: String):
	log_message(msg)
	
func _init_log_file():
	var f = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	if f:
		f.store_line("=== Game Session Started: %s ===" % Time.get_datetime_string_from_system())
		f.close()
		
func _log_to_file(msg: String):
	var f = FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("[%s] %s" % [Time.get_time_string_from_system(), msg])
		f.close()

func _handle_combat_click(hex: Vector3i):
	if combat_action_taken: return
	
	# NEW LOGIC: Prioritize Targeting over Selection Switching if a valid target exists in the hex
	# Check if clicked hex has a valid target FIRST
	var potential_target = null
	
	# Gather ALL candidates at this hex
	var candidates = []
	for s in ships:
		if is_instance_valid(s) and s.grid_position == hex and s != selected_ship:
			# Check validity as target
			if s.side_id != my_side_id and not s.is_exploding:
				candidates.append(s)
	
	# Sort candidates by Visual Order (Scene Tree Index)
	# Higher index = Drawn on Top = Priority
	candidates.sort_custom(func(a, b): return a.get_index() > b.get_index())
	
	if candidates.size() > 0:
		potential_target = candidates[0] # The "Top" ship
	
	if potential_target:
		# Check if this IS a valid target for current weapon?
		# If we just unconditionally set it, we might set an invalid target (e.g. out of range).
		# But the subsequent "PLAN FIRE" block does validation (Range, Arc, etc).
		# So it's safe to set it as the INTENDED target.
		# If validation fails, it just won't fire.
		combat_target = potential_target
		queue_redraw()
	
	if not potential_target:
		# Check if clicked on a FRIENDLY ship to switch shooter
		# Only checks ships belonging to firing_side_id that haven't fired
		for s in ships:
			if is_instance_valid(s) and s.grid_position == hex and s.side_id == firing_side_id and not s.has_fired:
				# Ownership Check
				if s.side_id != my_side_id and my_side_id != 0:
					continue
					
				if s != selected_ship:
					selected_ship = s
					# Auto-retarget
					combat_target = null
					var targets = _get_valid_targets(selected_ship)
					if targets.size() > 0: combat_target = targets[0]
					
					queue_redraw()
					_update_ship_visuals() # Re-sort stack
					_update_ui_state()
					log_message("Switched to %s" % selected_ship.get_display_name())
					return
	
	# if not combat_target: return # REMOVED: Prevent blocking target selection
	
	# Guard: need a selected ship to interact with targets or plan attacks
	if not selected_ship:
		return
	
	var is_click_on_target = false
	if combat_target:
		var mouse_pos = get_local_mouse_position()
		var dist_to_target = mouse_pos.distance_to(combat_target.position)
		is_click_on_target = (combat_target.grid_position == hex) or (dist_to_target < HexGrid.TILE_SIZE * 0.8)

	# If click on the target's hex OR visual representation, PLAN FIRE
	if is_click_on_target:
		var s = combat_target
		
		
		# Validation
		var weapon = selected_ship.weapons[selected_ship.current_weapon_index]
		
		# DOCKING RULE: Targeting Immunity
		# "Any docked ships except fighters and assault scouts can be attacked while docked."
		# = Fighters/Scouts CANNOT be attacked while docked.
		if s.is_docked and s.ship_class in ["Fighter", "Assault Scout"]:
			log_message("[color=red]Target is docked and cannot be engaged![/color]")
			return

		# Availability Check (Phase Rule)
		if not _is_weapon_available_in_phase(weapon, selected_ship):
			log_message("[color=red]Cannot fire %s in Passive Turn![/color]" % weapon["name"])
			return

		# Calculate valid target hexes based on movement phase
		var target_hexes = [s.grid_position]
		if combat_subphase == 1 and s.side_id != firing_side_id and current_side_id == s.side_id:
			target_hexes.append_array(s.previous_path)
			
		var w_range = weapon["range"]
		var w_arc = weapon["arc"]
		
		# Validation tracking
		var is_in_range_anywhere = false
		var is_in_arc_anywhere = false
		var can_hit = false
		
		for check_hex in target_hexes:
			var d = HexGrid.hex_distance(selected_ship.grid_position, check_hex)
			if d <= w_range:
				is_in_range_anywhere = true
				
				# Planet Masking Check
				var line_hexes = HexGrid.get_line_coords(selected_ship.grid_position, check_hex)
				var blocked = false
				for h in line_hexes:
					if h in planet_hexes:
						if h == selected_ship.grid_position or h == check_hex: continue
						blocked = true
						break
						
				if blocked: continue

				# Arc Check
				var in_arc_for_this_hex = false
				if w_arc == "FF":
					var valid_hexes = _get_ff_arc_hexes(selected_ship, w_range)
					if check_hex in valid_hexes:
						in_arc_for_this_hex = true
				else:
					in_arc_for_this_hex = true # Turret/360
					
				if in_arc_for_this_hex:
					is_in_arc_anywhere = true
					can_hit = true
					break # Found a fully valid firing solution along the path
		
		if not can_hit:
			if not is_in_range_anywhere:
				log_message("[color=red]Target out of range! (Max %d)[/color]" % w_range)
			elif not is_in_arc_anywhere:
				log_message("[color=red]Target not in Forward Firing Arc![/color]")
			else:
				log_message("[color=red]Target line of sight blocked![/color]")
			return

		# Ammo Check (Account for already queued shots)
		var queued_count = 0
		for atk in queued_attacks:
			if atk["source"] == selected_ship and atk["weapon_idx"] == selected_ship.current_weapon_index:
				queued_count += 1
		
		if weapon["ammo"] != -1 and weapon["ammo"] - queued_count <= 0:
			log_message("[color=red]Insufficent Ammo for planned shot![/color]")
			return
			
		# Check if already targeting this specific enemy with this weapon?
		# Rules don't say we can't double tap, so allow it.
		
		# Check for existing plan with THIS weapon and remove it (Overwrite Rule)
		# We must broadcast removals too
		# Check for existing plan with THIS weapon
		var is_toggle_off = false # If true, we are canceling the attack on the SAME target
		
		# First Pass: Check if we are cancelling
		for atk in queued_attacks:
			if atk["source"] == selected_ship and atk["weapon_idx"] == selected_ship.current_weapon_index:
				# Found existing plan for this weapon
				if atk["target"] == s:
					is_toggle_off = true
				break
		
		# Always remove existing plan for this weapon (whether toggling off or overwriting)
		for i in range(queued_attacks.size() - 1, -1, -1):
			var atk = queued_attacks[i]
			if atk["source"] == selected_ship and atk["weapon_idx"] == selected_ship.current_weapon_index:
				# Use RPC to remove locally and remotely
				if _is_networked():
					rpc("rpc_remove_attack", selected_ship.name, selected_ship.current_weapon_index)
				else:
					rpc_remove_attack(selected_ship.name, selected_ship.current_weapon_index)
				break

		if not is_toggle_off:
			# ADD TO PLAN (Broadcast)
			if _is_networked():
				rpc("rpc_add_attack", selected_ship.name, s.name, selected_ship.current_weapon_index)
			else:
				rpc_add_attack(selected_ship.name, s.name, selected_ship.current_weapon_index)
			log_message("Planned: %s -> %s (%s)" % [selected_ship.get_display_name(), s.get_display_name(), weapon["name"]])
		else:
			log_message("Attack Canceled")
		
		log_message("Planned: %s -> %s (%s)" % [selected_ship.get_display_name(), s.get_display_name(), weapon["name"]])
		
		# _update_planning_ui_list() # Handled by RPC callback
		# queue_redraw()

	else:
		# Check if switching target (Enemy)
		for s in ships:
			if is_instance_valid(s) and s.side_id != firing_side_id and s.grid_position == hex:
				var d = HexGrid.hex_distance(selected_ship.grid_position, s.grid_position)
				if d <= Combat.MAX_RANGE:
					combat_target = s
					queue_redraw()
					log_message("Targeting: %s" % s.get_display_name())
					_update_ship_visuals() # Ensure target pops to top
					break

func _check_for_valid_combat_targets() -> bool:
	# Iterate all ships owned by firing_side_id
	var my_ships = ships.filter(func(s): return is_instance_valid(s) and s.side_id == firing_side_id and not s.is_exploding) # Docked check is per-weapon now
	
	print("[DEBUG] TARGET CHECK P%d. Ships: %d" % [firing_side_id, my_ships.size()])
	
	for s in my_ships:
		# Check each weapon
		for w in s.weapons:
			if w.get("fired", false): continue
			
			# Check availability (e.g. Phase/Debuff)
			if not _is_weapon_available_in_phase(w, s):
				print("[DEBUG] Weapon %s N/A for %s (Phase %s, Fired %s)" % [w["name"], s.name, current_phase, w.get("fired", false)])
				continue
			
			# Check for ANY target in range/arc
			var valid_targets = _get_valid_targets_for_weapon(s, w)
			
			if valid_targets.size() > 0:
				print("[DEBUG] VALID: %s found target with %s" % [s.name, w["name"]])
				return true
				
	print("[DEBUG] NO TARGETS FOUND for P%d" % firing_side_id)
	return false

func _get_valid_targets_for_weapon(shooter: Ship, weapon: Dictionary) -> Array[Ship]:
	var valid: Array[Ship] = []
	var targets = ships.filter(func(s): return is_instance_valid(s) and s != shooter and not s.is_exploding and s.side_id != shooter.side_id) # Allow docked ships as targets (rules check later)
	
	for t in targets:
		var dist = HexGrid.hex_distance(shooter.grid_position, t.grid_position)
		
		if dist > weapon["range"]: continue
		
		# Arc Check
		var in_arc = false
		if weapon["arc"] == "360":
			in_arc = true
		elif weapon["arc"] == "FF":
			var dir_to_target = HexGrid.get_hex_direction(shooter.grid_position, t.grid_position)
			if dir_to_target == shooter.facing:
				in_arc = true
			else:
				# Complex FF arc check (3-hex wide)
				var valid_hexes = _get_ff_arc_hexes(shooter, weapon["range"])
				if t.grid_position in valid_hexes:
					in_arc = true
		
		# Planet Masking Check
		var line = HexGrid.get_line_coords(shooter.grid_position, t.grid_position)
		var is_masked = false
		for hex in line:
			# Exclude Shooter and Target from masking check (can fire out of/into planet)
			if hex == shooter.grid_position or hex == t.grid_position: continue
			
			if hex in planet_hexes:
				is_masked = true
				break
		
		if is_masked:
			continue

		if in_arc:
			valid.append(t)
			
	return valid

func _spawn_icm_fx(target: Ship, attacker_pos: Vector2, duration: float = 0.5):
	var start = target.position
	# Intercept point roughly 1 hex towards attacker
	var dir = (attacker_pos - start).normalized()
	var intercept_pos = start + dir * HexGrid.TILE_SIZE * 0.8
	
	# Create multiple small missiles
	for i in range(3):
		var m = Polygon2D.new()
		m.polygon = PackedVector2Array([Vector2(3, 0), Vector2(-2, -1), Vector2(-2, 1)])
		m.color = Color.WHITE
		m.position = start
		m.rotation = dir.angle()
		add_child(m)
		
		var tween = create_tween()
		# Scale timing based on provided duration
		# We want them to arrive slightly before the end of the full duration
		var my_time = duration * 0.8 # Arrive at 80% of travel time (near target)
		
		# Slight spread
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tween.tween_property(m, "position", intercept_pos + offset, my_time + (i * 0.05))
		tween.tween_callback(func():
			m.queue_free()
			# Boom
			var boom = CPUParticles2D.new()
			boom.position = intercept_pos + offset
			boom.emitting = true
			boom.one_shot = true
			boom.explosiveness = 1.0
			boom.amount = 10
			boom.spread = 180
			boom.gravity = Vector2.ZERO
			boom.initial_velocity_min = 20
			boom.initial_velocity_max = 40
			boom.color = Color.YELLOW
			add_child(boom)
			get_tree().create_timer(1.0).timeout.connect(boom.queue_free)
		)

func _spawn_attack_fx(start: Vector2, end: Vector2, type: String) -> float:
	if type == "Mine":
		var container = Node2D.new()
		container.position = start
		container.z_index = 20
		add_child(container)
		
		# Expanding Core
		var core = Polygon2D.new()
		var pts = PackedVector2Array()
		for i in range(16):
			var a = i * PI / 8.0
			pts.append(Vector2(cos(a), sin(a)) * 15.0)
		core.polygon = pts
		core.color = Color(1.0, 0.8, 0.2, 0.9)
		container.add_child(core)
		
		# Expanding Shockwave
		var shock = Polygon2D.new()
		shock.polygon = pts
		shock.color = Color(1.0, 0.3, 0.0, 0.6)
		container.add_child(shock)
		
		# Omni-directional Burst Particles
		var boom = CPUParticles2D.new()
		boom.emitting = false
		boom.amount = 80
		boom.one_shot = true
		boom.explosiveness = 0.95
		boom.spread = 180.0
		boom.gravity = Vector2.ZERO
		boom.initial_velocity_min = 60.0
		boom.initial_velocity_max = 200.0
		boom.scale_amount_min = 3.0
		boom.scale_amount_max = 8.0
		boom.color = Color(1.0, 0.5, 0.1, 0.8)
		container.add_child(boom)
		
		boom.emitting = true
		
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(core, "scale", Vector2(4, 4), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(core, "color:a", 0.0, 0.4)
		t.tween_property(shock, "scale", Vector2(8, 8), 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(shock, "color:a", 0.0, 0.7)
		
		t.chain().tween_callback(container.queue_free)
		
		if audio_hit and audio_hit.stream: audio_hit.play()
		return 1.0 # Duration
		
	elif type == "Rocket" or type == "Rocket Battery":
		# Rocket Visual
		var container = Node2D.new()
		container.position = start
		container.z_index = 20 # Above ships
		add_child(container)
		
		# Projectile (Small white/orange missile)
		var missile = Polygon2D.new()
		missile.polygon = PackedVector2Array([Vector2(5, 0), Vector2(-5, -3), Vector2(-5, 3)])
		missile.color = Color.ORANGE
		container.add_child(missile)
		
		# Smoke Trail
		var smoke = CPUParticles2D.new()
		smoke.amount = 30
		smoke.lifetime = 0.5
		smoke.direction = Vector2(-1, 0)
		smoke.spread = 15.0
		smoke.gravity = Vector2.ZERO
		smoke.initial_velocity_min = 20.0
		smoke.initial_velocity_max = 20.0
		smoke.scale_amount_min = 2.0
		smoke.scale_amount_max = 5.0
		smoke.color = Color(0.8, 0.8, 0.8, 0.5)
		smoke.local_coords = false # Trail effect
		container.add_child(smoke)
		
		# Rotate to face target
		container.rotation = (end - start).angle()
		
		# Tween Movement
		var _dist_px = start.distance_to(end)
		var travel_time = 0.5 # Fast rocket
		
		var tween = create_tween()
		tween.tween_property(container, "position", end, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			# Explosion or impact effect could go here
			missile.visible = false
			smoke.emitting = false
			# Cleanup after smoke fades
			get_tree().create_timer(1.0).timeout.connect(container.queue_free)
		)

		if audio_laser.stream: audio_laser.play()
		return travel_time
		
	elif type == "Torpedo":
		if audio_laser.stream: audio_laser.play()

		var container = Node2D.new()
		container.position = start
		container.z_index = 20
		add_child(container)
		
		# Torpedo Visual (Blue pill shape)
		var proj = Polygon2D.new()
		proj.polygon = PackedVector2Array([Vector2(8, 0), Vector2(4, -4), Vector2(-4, -4), Vector2(-6, 0), Vector2(-4, 4), Vector2(4, 4)])
		proj.color = Color.CYAN
		container.add_child(proj)
		
		# Engine glow
		var glow = CPUParticles2D.new()
		glow.amount = 15
		glow.lifetime = 0.8
		glow.direction = Vector2(-1, 0)
		glow.spread = 10.0
		glow.gravity = Vector2.ZERO
		glow.initial_velocity_min = 10.0
		glow.initial_velocity_max = 10.0
		glow.scale_amount_min = 3.0
		glow.scale_amount_max = 5.0
		glow.color = Color(0, 1, 1, 0.5)
		glow.local_coords = false
		container.add_child(glow)
		
		container.rotation = (end - start).angle()
		
		# TWEEN
		var _dist_px = start.distance_to(end)
		var travel_time = 0.8 # Slower than rocket
		
		var tween = create_tween()
		tween.tween_property(container, "position", end, travel_time).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(func():
			proj.visible = false
			glow.emitting = false
			get_tree().create_timer(1.0).timeout.connect(container.queue_free)
		)
		return travel_time

	else:
		# Laser or Laser Canon or Disruptor Canon
		var line = Line2D.new()
		var is_disruptor = (type == "Disruptor Canon")
		var is_canon = (type == "Laser Canon" or is_disruptor)
		
		line.width = 5.0 if is_canon else 3.0
		
		if type == "Proton Beam Battery":
			line.default_color = Color(0.2, 1.0, 0.5, 1.0) # Bright Green
			line.width = 4.0
		elif type == "Electron Beam Battery":
			line.default_color = Color(0.2, 0.5, 1.0, 1.0) # Bright Blue
			line.width = 4.0
		elif is_disruptor:
			line.default_color = Color(0.8, 0.4, 1.0, 1.0) # Purple/Whiteish
		elif is_canon:
			line.default_color = Color.ORANGE
		else:
			line.default_color = Color(1, 0, 0, 1) # Canon Orange, Battery Red
		line.points = PackedVector2Array([start, end])
		add_child(line)
		
		var tween = create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 2.0)
		tween.tween_callback(line.queue_free)

		if audio_laser.stream: audio_laser.play()
		return 0.1 # Instant

func _on_combat_commit():
	# Authority Check
	if my_side_id > 0 and firing_side_id != my_side_id:
		log_message("Not your turn to fire!")
		return
		
	if current_combat_state != CombatState.PLANNING: return
	
	# SERIALIZE ATTACKS
	# We need: Source Name, Target Name, Weapon Idx, Target Pos (for visuals if target dies)
	var attacks_data = []
	for atk in queued_attacks:
		var s = atk["source"]
		var t = atk["target"]
		# Sanity check
		if not is_instance_valid(s) or not is_instance_valid(t): continue
		
		attacks_data.append({
			"s": s.name,
			"t": t.name,
			"w": atk["weapon_idx"],
			"tp": atk["target_pos"]
		})
	
	var seed_val = randi()
	if _is_networked():
		# Client: Send Request to Server
		rpc_id(1, "execute_commit_combat", attacks_data, seed_val)
	else:
		# Local: Just execute
		_execute_resolution(attacks_data, seed_val)

@rpc("any_peer", "call_local", "reliable")
func execute_commit_combat(attacks_data: Array, rng_seed: int):
	# SECURITY CHECK
	var sender_id = 1
	if _is_networked():
		sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = (multiplayer.get_unique_id() if _is_networked() else 1) # Handle local call
	
	if current_phase != Phase.COMBAT:
		print("[Security] Combat rejected: Wrong Phase (%s)" % current_phase)
		return

	# Validate Sender owns the Firing Side
	if not _validate_rpc_ownership(sender_id, firing_side_id):
		return
		

	if _is_server_or_offline():
		# Broadcast to all clients (Authority -> Clients)
		# We use the SAME seed provided by the client to ensure fairness/sync
		if _is_networked() and multiplayer.get_peers().size() > 0:
			rpc("rpc_resolve_combat", attacks_data, rng_seed)
		else:
			rpc_resolve_combat(attacks_data, rng_seed)
	else:
		# If a client somehow received this (shouldn't happen if we only rpc_id(1)), ignore or log
		pass

@rpc("authority", "call_local", "reliable")
func rpc_resolve_combat(attacks_data: Array, rng_seed: int):
	_execute_resolution(attacks_data, rng_seed)

func _execute_resolution(attacks_data: Array, rng_seed: int):
	current_combat_state = CombatState.RESOLVING
	
	# Sync RNG
	seed(rng_seed)
	
	# Deserialize
	pending_resolutions.clear()
	for data in attacks_data:
		var source = null
		var target = null
		
		for s in ships:
			if not is_instance_valid(s): continue
			if s.name == data["s"]: source = s
			if s.name == data["t"]: target = s
		
		# SECURITY: Verify Source Ownership
		if source and source.side_id != firing_side_id:
			print("[Security] Attack rejected: Source %s (Side %d) != Firing Side %d" % [source.name, source.side_id, firing_side_id])
			continue
			
		if source and target: # Target might be null if we allow ground targeting later, but for now ship-to-ship
			pending_resolutions.append({
				"source": source,
				"target": target,
				"weapon_idx": data["w"],
				"target_pos": data["tp"]
			})
			
	panel_planning.visible = false
	queue_redraw() # Clear planning visuals (Range arcs, target lines)
	
	log_message("Resolving %d attacks..." % pending_resolutions.size())
	_process_next_attack()

# Async recursive-like function (handles sequencing)
func _process_next_attack():
	if pending_resolutions.size() == 0:
		_on_resolution_complete()
		return
		
	var atk = pending_resolutions.pop_front()
	var source = atk["source"]
	var target = atk["target"]
	var weapon_idx: int = atk["weapon_idx"]
	
	# Validate Source FIRST
	if not is_instance_valid(source):
		log_message("Source ship destroyed! Attack fizzles.")
		await get_tree().create_timer(0.5).timeout
		_process_next_attack()
		return

	# If ship exists but is technically dead/dying (hull <= 0)
	if source.hull <= 0:
		log_message("%s destroyed before firing! Attack fizzles." % source.get_display_name())
		source.weapons[weapon_idx]["ammo"] -= 1
		await get_tree().create_timer(0.5).timeout
		_process_next_attack()
		return
		
	# Now safe to assign and focus
	selected_ship = source
	
	# Validate Target for focus (assign null if invalid)
	if is_instance_valid(target):
		combat_target = target
	else:
		combat_target = null
		
	# Focus camera on TARGET if available, otherwise Source
	if is_instance_valid(target):
		_update_camera(target)
	else:
		_update_camera()

	var weapon = source.weapons[weapon_idx]
	# Strict Ammo Consumption (happens now at resolution)
	weapon["ammo"] -= 1
	weapon["fired"] = true
	source.has_ever_fired = true
	
	var start_pos = HexGrid.hex_to_pixel(source.grid_position)
	var target_pos = atk["target_pos"]
	
	if is_instance_valid(target):
		target_pos = target.position

	if not is_instance_valid(target) or target.hull <= 0:
		var w_msg = "%s firing at WRECK of %s! (Wasted)" % [source.get_display_name(), target.get_display_name() if is_instance_valid(target) else "Unknown"]
		if _is_networked() and multiplayer.is_server():
			rpc_log_message.rpc(w_msg)
		else:
			log_message(w_msg)
		_spawn_attack_fx(start_pos, target_pos, weapon.get("type"))
		await get_tree().create_timer(0.75).timeout
		_process_next_attack()


		return

	# DOCKING RULE: Targeting Immunity Check AGAIN (Safety)
	if target.is_docked and target.ship_class in ["Fighter", "Assault Scout"]:
		var d_msg = "%s target is docked and invalid! Attack fizzles." % source.get_display_name()
		if _is_networked() and multiplayer.is_server():
			rpc_log_message.rpc(d_msg)
		else:
			log_message(d_msg)
		source.weapons[weapon_idx]["ammo"] -= 1 # Wasted shot rule? Or refund? Let's burn ammo to be safe.
		await get_tree().create_timer(0.5).timeout
		_process_next_attack()
		return

	# Execute Fire Logic
	var f_msg = "%s firing %s at %s" % [source.get_display_name(), weapon["name"], target.get_display_name()]
	if _is_networked() and multiplayer.is_server():
		rpc_log_message.rpc(f_msg)
	else:
		log_message(f_msg)
	
	# Hit Calc Setup
	var d = HexGrid.hex_distance(source.grid_position, target.grid_position)
	var is_head_on = false
	if weapon["arc"] == "FF":
		if target.grid_position == source.grid_position:
			is_head_on = true
		else:
			var fwd_vec = HexGrid.get_direction_vec(source.facing)
			var check = source.grid_position + fwd_vec
			for i in range(weapon["range"]):
				if check == target.grid_position:
					is_head_on = true
					break
				check += fwd_vec
				
	# If this is Passive Fire (Reactive Fire), we use the best hex along their path
	if combat_subphase == 1 and target.side_id == current_side_id:
		var best_hex_info = Combat.get_best_defensive_fire_hex(source, target, weapon, 0)
		d = best_hex_info["distance"]
		is_head_on = best_hex_info["is_head_on"]
		# The target visually stays where it is, but the odds use the best hex.
	
	# ICM INTERRUPT
	var icm_used = 0
	var w_type = weapon.get("type")
	
	# DOCKING RULE: Docked Ships cannot use ICMs
	# Find ALL friendly ships in the same hex with ICMs available
	var eligible_ships = []
	for s in ships:
		if is_instance_valid(s) and s.side_id == target.side_id and s.grid_position == target.grid_position:
			if s.icm_current > 0 and not s.is_destroyed: # and not s.is_docked? (Rule assumes docked ships cannot use ICMs?)
				# Assuming docked ships cannot use ICMs based on previous rule
				if not s.is_docked:
					eligible_ships.append(s)
					
	# Fallback if no eligible ships
	var can_use_icm = eligible_ships.size() > 0

	if can_use_icm and w_type in ["Torpedo", "Rocket", "Rocket Battery"]:
		# Calculate hit chance to show player
		var raw_chance = Combat.calculate_hit_chance(d, weapon, target, is_head_on, 0, source)
		
		# Prompt UI (Pass array of ships)
		_trigger_icm_decision(source.name, weapon["name"], w_type, raw_chance, target, eligible_ships)
		
		# Wait for state flag instead of raw signal
		while not _icm_decision_received:
			await get_tree().process_frame
			
		var allocations = _icm_current_allocations
		_icm_decision_received = false
		_icm_current_allocations = {}
		
		# Calculate total and deduct from each
		for s_name in allocations.keys():
			var amt = allocations[s_name]
			if amt > 0:
				icm_used += amt
				# Find the ship and deduct
				for s in eligible_ships:
					if s.name == s_name:
						s.icm_current -= amt
						_spawn_icm_fx(s, source.position)
						break
						
		if icm_used > 0:
			log_message("Shared Defense launches %d total ICMs!" % icm_used)
			await get_tree().create_timer(0.5).timeout # Wait for counter-fire FX
	
	
	# Determine if hit (Pass ICM count)
	var result = Combat.get_hit_roll_details(d, weapon, target, is_head_on, icm_used, source)
	var hit = result["success"]
	
	var hit_str = "HIT" if hit else "MISS"
	var hit_msg = "Firing Ship: %s, Weapon: %s, Odds: %d%%, Roll: %d, Result: %s" % [source.get_display_name(), weapon["name"], result["chance"], result["roll"], hit_str]
	if _is_networked() and multiplayer.is_server():
		rpc_log_message.rpc(hit_msg)
	else:
		log_message(hit_msg)
	# Spawn Attack FX (Launch concurrently with ICMs)
	var travel_time = _spawn_attack_fx(start_pos, target_pos, weapon.get("type", "Laser"))
	
	if icm_used > 0:
		# ICMs already fired from each source above, but maybe log again or wait?
		# Original code did _spawn_icm_fx here again. We moved the fx to the allocation loop above.
		pass
	
	if hit:
		# 1. Roll for Hull Damage Amount (Standard, used if result is Hull Hit)
		var dmg_str = "%s+%d" % [weapon.get("damage_dice", "1d10"), weapon.get("damage_bonus", 0)]
		var hull_dmg_roll = Combat.roll_damage(dmg_str)
		
		# 2. Roll for Damage Table Effect
		var dtm = weapon.get("dtm", 0)
		var table_roll = Combat.calculate_damage_roll(dtm)
		var effect = Combat.get_damage_effect(table_roll)
		var dmg_msg = "[color=green]HIT![/color] Rolling Damage Table (d100+%d = %d)" % [dtm, table_roll]
		if _is_networked() and multiplayer.is_server():
			rpc_log_message.rpc(dmg_msg)
		else:
			log_message(dmg_msg)
		# 3. Apply Effect (Ship handles structural vs conditional dmg, we just tell it the base roll if needed)
		# Add fx wait
		await get_tree().create_timer(travel_time).timeout
		
		if is_instance_valid(target):
			# Check for Screen Half Damage Logic
			var w_type_full = weapon.get("type", "")
			var tgt_screen = target.get("active_screen") if (target.get("active_screen") and target.get("active_screen") != "None") else "None"
			if target.get("is_ms_active"): tgt_screen = "MS"
			
			var apply_half = false
			if tgt_screen == "MS" and w_type_full in ["Laser", "Laser Canon"]: apply_half = true
			if tgt_screen == "PS" and w_type_full == "Electron Beam Battery": apply_half = true
			if tgt_screen == "ES" and w_type_full == "Proton Beam Battery": apply_half = true
			
			if apply_half:
				hull_dmg_roll = max(1, int(float(hull_dmg_roll) / 2.0))
				log_message("[color=yellow]Screen reduces hull damage by half![/color]")
				
			var res = target.apply_damage_effect(effect, hull_dmg_roll)
			log_message("%s: %s" % [target.name, res.get("text")])
			
			if res.get("fallback", false):
				log_message("[color=red]System missing/destroyed -> FALLBACK HULL HIT[/color]")
				# Rule: "roll normal hull hit damage" (usually 1d10 for fallback implied?)
				# Prompt said "roll normal hull hit damage". The Damage Table says "Hull hit: roll normal damage".
				# Normal damage depends on weapon? NO. 
				# "If a system is destroyed... that is converted to a hull hit and normal hull damage is rolled and applied."
				# THIS MEANS: Reroll the damage as if it was a Hull Hit (1-45 range).
				# BUT wait, the weapon that CAUSED it has specific damage dice (e.g. 2d10).
				# "roll normal hull hit damage" usually implies standard weapon damage.
				# However, for FIRE, the rule said "If a ... fire damage table roll indicates a hull hit, the damage to the hull is 1d10."
				# But for WEAPON hits converting to hull hits? It likely means "The weapon does hull damage instead."
				# So we should use the `damage` passed into this function?
				# OR reroll it?
				# "roll... damage". Implies action.
				# Using the existing roll is safer/fairer, but "roll" implies new RN.
				# Let's re-roll using the weapon's dice if available?
				# But `_resolve_attack` knows the weapon.
				# Actually, simpler: just pass `damage` (the int) as the fallback?
				# But `damage` was passed into `apply_damage_effect` and ignored if it wasn't Hull type.
				# So we can just use `damage` (the original roll).
				# UNLESS "roll normal hull hit damage" means "Do a hull hit procedure".
				# Let's stick to: Use the same damage amount that triggered the effect, but applied to hull.
				# Actually, explicitly rerolling consistent with "roll" wording.
				
				# ISSUE: I don't have the weapon dice here easily without passing it?
				# `damage` is an INT.
				# Let's just apply `damage` to hull. It's the "Damage Amount" from the attack.
				# "Hull hit: roll normal damage". We did that to get `damage`.
				# So converting means applying it.
				
				# WAIT: The prompt said for FIRE: "is 1d10".
				# For FALLBACK generally: "converted to a hull hit and normal hull damage is rolled".
				# If I hit with a Torpedo (4d10). I roll 25 dmg. Table say Drive Hit. Drive gone.
				# Fallback -> Hull Hit. Should take 4d10 (approx 25).
				# So `target.take_hull_damage(damage)` is correct.
				
				target.take_hull_damage(hull_dmg_roll)
				log_message("%s takes %d Fallback Damage (Converted Effect)" % [target.name, hull_dmg_roll])
			
			# Visuals & Audio
			# Only show hull damage number if it was a hull hit? 
			# Or always show "CRIT" or something?
			# For now, show hull dmg if > 0
				# Check for Screen Half Damage Logic
			if effect.get("type") == "Hull":
				var final_dmg = int(hull_dmg_roll * effect.get("mult", 1.0))
				_spawn_hit_text(target_pos, final_dmg)
			else:
				_spawn_hit_text(target_pos, effect.get("text", "HIT")) # overload spawn_hit_text to accept string?
			
			
			if audio_hit.stream: audio_hit.play()
	else:
		log_message("[color=red]MISS![/color]")
	
	# Wait for animation (travel time + buffer)
	var total_wait = (travel_time + 1.0) * 0.5
	if total_wait < 1.0: total_wait = 1.0
	
	await get_tree().create_timer(total_wait).timeout
	call_deferred("_process_next_attack")

func _on_resolution_complete():
	log_message("Resolution Phase Complete.")
	
	# Mark all ships of this player as "Has Fired" (Actually we tracked individual weapons)
	# But we need to transition phase if no one else can fire?
	# Or just check if we have more ships?
	# Users prompt: "attacks must all be planned out first, then resolved"
	# Implies one big batch for the player.
	
	# We should check if there are ANY OTHER ships for this player that haven't fired?
	# But we just did the planning phase for THE ENTIRE SIDE (conceptually).
	# However `start_combat_active` says "Player Plan".
	
	# If we want to allow "Plan for A, Commit. Plan for B, Commit" -> no, user said "attacks must all be planned out first"
	# So we assume the user has planned EVERYTHING they want to.
	# So we end this player's combat subphase.
	
	call_deferred("end_turn_cycle")

func _spawn_hit_text(pos: Vector2, val: Variant):
	var lbl = Label.new()
	if typeof(val) == TYPE_INT:
		lbl.text = "HIT! -%d" % val
		lbl.modulate = Color.RED
	else:
		lbl.text = str(val)
		lbl.modulate = Color(1.0, 0.6, 0.0) # Orange
		
	lbl.position = pos + Vector2(-20, -40) # Slightly above
	lbl.add_theme_font_size_override("font_size", 20)
	add_child(lbl)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 30, 3.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 3.0)
	tween.chain().tween_callback(lbl.queue_free)


# Helper to clear plotting state when switching ships
# Helper to clear plotting state when switching ships
func _reset_plotting_state():
	current_path = []
	movement_history.clear() # Clear Undo Stack
	
	if selected_ship:
		turns_remaining = selected_ship.mr
		start_speed = selected_ship.speed
		start_ms_active = selected_ship.is_ms_active
		
		# Space Stations can NEVER have speed > 0
		if selected_ship.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
			selected_ship.speed = 0
			start_speed = 0
	else:
		turns_remaining = 0
		start_speed = 0
		start_ms_active = false
		
	can_turn_this_step = false
	turn_taken_this_step = 0
	state_is_orbiting = false
	current_orbit_direction = 0
	has_suffered_gravity_this_turn = false
	gravity_penalty_applied_this_turn = false
	free_gravity_turn_used = false
	mr_expenditures.clear()
	combat_action_taken = false
	if is_instance_valid(selected_ship):
		step_entry_facing = selected_ship.facing # Init to current facing

		# Snapshot State for Undo (if not already moved)
		if not selected_ship.has_moved and selected_ship.turn_start_state.is_empty():
			selected_ship.turn_start_state = {
				"grid_position": selected_ship.grid_position,
				"facing": selected_ship.facing,
				"speed": selected_ship.speed,
				"is_ms_active": selected_ship.is_ms_active,
				"ms_orbit_start_hex": selected_ship.ms_orbit_start_hex
			}


# --- Phase Indicator Helpers ---
func _get_side_name(s_id: int) -> String:
	# Dynamic lookup from ships
	for s in ships:
		if is_instance_valid(s) and s.side_id == s_id:
			return s.faction # e.g. "UPF", "Sathar"
			
	# Fallback if no ships found
	if s_id == 1: return "UPF"
	if s_id == 2: return "Sathar"
	return "Side %d" % s_id

func _get_phase_name(p: int) -> String:
	match p:
		Phase.START: return "Setup"
		Phase.MOVEMENT: return "Movement"
		Phase.COMBAT: return "Combat"
		Phase.REPAIR: return "Repair"
		Phase.END: return "End"
		_: return "Unknown"

func _update_phase_indicator():
	if not label_phase_indicator: return
	
	# Format: "Turn <turn> : <phase> : <side>"
	var side_name = "None"
	var active_id = current_side_id
	if current_phase == Phase.COMBAT:
		active_id = firing_side_id
		
	if active_id != 0:
		side_name = _get_side_name(active_id)
		
	var text = "Turn %d, Active: %s, %s" % [turn_count, side_name, _get_phase_name(current_phase)]
	
	if current_phase == Phase.REPAIR:
		var rep_side = "Executing"
		if repair_subphase != 3:
			rep_side = _get_side_name(repair_subphase)
		text = "End of Turn %d - Repair, Active: %s" % [turn_count, rep_side]
	elif current_phase == Phase.DEPLOYMENT:
		var dep_side = _get_side_name(deployment_subphase)
		text = "Setup: %s" % dep_side
		
	label_phase_indicator.text = text


func _cycle_selection():
	# Authority Check: Cannot cycle selection if it's not my turn (Movement)
	# Combat cycling handle separately below?
	if current_phase == Phase.MOVEMENT:
		var is_my_turn = (my_side_id == current_side_id) or _has_admin_authority()
		if not is_my_turn: return

		# Filter: Active Player, !has_moved
		var available = ships.filter(func(s): return is_instance_valid(s) and s.side_id == current_side_id and not s.has_moved)
		if available.size() <= 1: return
		
		var idx = available.find(selected_ship)
		var next_idx = (idx + 1) % available.size()
		selected_ship = available[next_idx]
		
		# Reset plotting
		_reset_plotting_state()
		
		if audio_ship_select and audio_ship_select.stream: audio_ship_select.play()
		
		_load_plan_visualization(selected_ship)
		
		_update_camera(selected_ship)
		_update_ship_visuals() # Re-sort stack
		_update_ui_state()

	elif current_phase == Phase.COMBAT:
		# Authority Check: Only cycle if it is my turn to fire
		if my_side_id != 0 and my_side_id != firing_side_id: return
		
		# TAB cycles friendly ships if multiple have not fired yet.
		var available = ships.filter(func(s): return is_instance_valid(s) and s.side_id == firing_side_id and not s.has_fired and s.hull > 0)
		if available.size() <= 1: return
		
		var combat_idx = available.find(selected_ship)
		var next_combat_idx = (combat_idx + 1) % available.size()
		selected_ship = available[next_combat_idx]
		
		# Reset combat_target selection
		combat_target = null
		
		if audio_ship_select and audio_ship_select.stream: audio_ship_select.play()
		_update_ui_state()

	elif current_phase == Phase.REPAIR:
		var is_my_repair_phase = (repair_subphase == my_side_id) or (my_side_id == 0)
		if not is_my_repair_phase: return
		
		var my_ships = ships.filter(func(s): return is_instance_valid(s) and s.side_id == repair_subphase and not s.is_exploding and s.hull > 0)
		var damaged_ships = []
		for s in my_ships:
			var has_damage = (s.hull < s.max_hull) or (s.current_adf_modifier > 0) or (s.current_mr_modifier > 0) or s.has_electrical_fire or s.has_disastrous_fire
			if not has_damage:
				for w in s.weapons:
					if w.get("is_crippled", false):
						has_damage = true
						break
			if has_damage:
				damaged_ships.append(s)
		
		if damaged_ships.size() <= 1: return
		
		var idx = damaged_ships.find(selected_ship)
		var next_idx = (idx + 1) % damaged_ships.size()
		selected_ship = damaged_ships[next_idx]
		
		if audio_ship_select and audio_ship_select.stream: audio_ship_select.play()
		_update_ui_state()
		_update_repair_ui()
		_update_camera()
		
func _cycle_targets():
	if current_phase != Phase.COMBAT: return
	if not selected_ship: return
	
	var valid_targets = _get_valid_targets(selected_ship)
	if valid_targets.size() <= 1: return
	
	var target_idx = valid_targets.find(combat_target)
	var next_target_idx = (target_idx + 1) % valid_targets.size()
	combat_target = valid_targets[next_target_idx]
	
	queue_redraw()
	log_message("Targeting: %s" % combat_target.name)
	_update_ship_visuals() # Ensure target pops to top

func _update_ship_visuals():
	var grid_counts = {}
	for s in ships:
		if not is_instance_valid(s) or s.is_exploding: continue
		if not grid_counts.has(s.grid_position):
			grid_counts[s.grid_position] = []
		grid_counts[s.grid_position].append(s)
		
		# Update Selection State
		s.is_selected = (s == selected_ship)
	
	for hex in grid_counts:
		var stack: Array = grid_counts[hex]
		
		# Sorting Logic:
		# 1. Selected Ship moves to Top (Highest priority)
		# 2. Combat Target moves to Top (If no selected ship overlaying it, or same hex?)
		# Actually, if I am targeting someone, THEY should be on top of THEIR stack.
		# My ship should be on top of MY stack.
		
		# Move combat_target to top
		if combat_target and combat_target in stack:
			stack.erase(combat_target)
			stack.append(combat_target)

		# Move selected_ship to top (Overrides target if in same hex, which is rare/weird but okay)
		if selected_ship and selected_ship in stack:
			stack.erase(selected_ship)
			stack.append(selected_ship)
		
		for i in range(stack.size()):
			var s: Ship = stack[i]
			var base_pos = HexGrid.hex_to_pixel(hex)
			# Offset logic: simple diagonal scatter
			var offset = Vector2(5 * i, 5 * i)
			s.position = base_pos + offset
			
			# Z-index: Higher index = on top
			s.z_index = i
			
			# Force Tree Order (Draw Last = Top)
			move_child(s, -1)
			
			# Info: Only show for the top-most ship
			s.show_info = (i == stack.size() - 1)
			s.queue_redraw()
			# print("Hex %s: Ship %s Z=%d Info=%s" % [hex, s.name, s.z_index, s.show_info])

	combat_action_taken = false
	_update_camera()

func start_turn_cycle():
	# Failsafe Cleanup
	if panel_icm:
		panel_icm.queue_free()
		panel_icm = null

	for s in ships:
		if is_instance_valid(s):
			s.reset_weapons()


	# Initial Setup
	turn_order = [1, 2] # Side 1 First
	
	if turn_count == 1:
		for rule in current_scenario_rules:
			if rule.get("type", "") == "random_first_turn":
				var rng = RandomNumberGenerator.new()
				rng.seed = game_seed
				if rng.randf() > 0.5:
					turn_order = [2, 1]
					print("GameManager: Random First Turn rolled. Side 2 goes first.")
				else:
					print("GameManager: Random First Turn rolled. Side 1 goes first.")
			elif rule.get("type", "") == "attacker_first_turn":
				turn_order = [2, 1] # Side 2 (Attacker) Goes First
				print("GameManager: Attacker First Turn rule active. Side 2 goes first.")
					
	current_turn_order_index = 0
	
	# Start Turn for Side 1
	_start_turn_for_side(turn_order[current_turn_order_index])

func _start_turn_for_side(sid: int):
	current_side_id = sid
	# turn_count increment moved to end_turn_cycle to track GAME turns, not individual side turns


	log_message("=== Turn Start: Side %s ===" % _get_side_name(sid))
	
	# Update UI to reflect new Side ID immediately
	_update_ui_state()
	
	# Reset ALL ships (Movement/Fired state) for the new turn
	# This ensures ships can fire again in the new turn (e.g. Defensive Fire)
	for s in ships:
		if is_instance_valid(s):
			s.reset_turn_state()
			
			# Capture Start State for Undo (Redundant if start_movement_phase does it, but good for safety)
			if not s.has_moved and s.turn_start_state.is_empty():
				s.turn_start_state = {
					"grid_position": s.grid_position,
					"facing": s.facing,
					"speed": s.speed,
					"is_ms_active": s.is_ms_active,
					"ms_orbit_start_hex": s.ms_orbit_start_hex
				}
	
	# Check for scenario phase overrides on the first turn
	if turn_count == 1:
		for rule in current_scenario_rules:
			if rule.get("type") == "start_phase_override":
				if rule.get("phase") == Phase.REPAIR:
					start_repair_phase()
					return
					
	start_movement_phase()
	# Fire Damage Phase (after Turn Start reset)
	# Fire Damage Phase (after Turn Start reset)
	# AUTHORITY ONLY: Calculate and broadcast fire damage results to ensure sync
	if not _is_networked() or multiplayer.is_server():
		for s in ships:
			if is_instance_valid(s) and (s.fire_damage_stack > 0 or s.has_electrical_fire or s.has_disastrous_fire):
				var dtm = s.fire_damage_stack
				# Ensure minimum +20 if any fire exists? 
				# Ship.gd sets stack += 20 on fire start.
				
				var roll = Combat.calculate_damage_roll(dtm)
				var effect = Combat.get_damage_effect(roll)
				
				var hull_dmg = Combat.roll_damage("1d10") # For Hull Hit result
				var fb_dmg = Combat.roll_damage("1d10") # For Fallback
				
				if _is_networked():
					rpc_apply_fire_damage.rpc(s.name, dtm, roll, effect, hull_dmg, fb_dmg)
				else:
					rpc_apply_fire_damage(s.name, dtm, roll, effect, hull_dmg, fb_dmg)

@rpc("authority", "call_local", "reliable")
func rpc_apply_fire_damage(ship_name: String, dtm: int, roll: int, effect: Dictionary, hull_dmg: int, fb_dmg: int):
	var s = _find_ship_by_name(ship_name)
	if not is_instance_valid(s): return
	
	log_message("[color=orange]Fire damage on %s![/color]" % s.name)
	log_message("Fire Roll: d100+%d = %d -> %s" % [dtm, roll, effect.get("text")])
	
	# Apply effect using provided hull damage roll
	var res = s.apply_damage_effect(effect, hull_dmg)
	
	_spawn_hit_text(s.position, "FIRE!")
	log_message("%s: %s" % [s.name, res.get("text")])
	
	if res.get("fallback", false):
		log_message("[color=red]System missing/destroyed -> FALLBACK HULL HIT[/color]")
		s.take_hull_damage(fb_dmg)
		log_message("%s takes %d Fallback Damage" % [s.name, fb_dmg])

func start_movement_phase():
	var is_phase_change = (current_phase != Phase.MOVEMENT)
	current_phase = Phase.MOVEMENT
	combat_subphase = 0
	firing_side_id = 0
	combat_action_taken = false # Reset lock
	current_combat_state = CombatState.NONE # AI DEADLOCK FIX: Reset combat state when entering movement
	
	_update_phase_indicator() # NEW: Update UI for Movement Phase
	
	# Sync State at start of turn/phase to ensure damage/flags are correct
	broadcast_game_state()
	
	# Find un-moved ships for ACTIVE side (Current Side Only)
	for s in ships:
		if not is_instance_valid(s): continue
		# Reset Order flag for new phase
		if s.side_id == current_side_id and not s.has_moved:
			s.has_orders = false
			
		if s.side_id == current_side_id and not s.is_exploding and not s.has_moved:
			pass # Accepted
		else:
			print("DEBUG: Rejected ", s.name, " Side:", s.side_id, " CurSide:", current_side_id, " Moved:", s.has_moved)

	var available = ships.filter(func(s): return is_instance_valid(s) and s.side_id == current_side_id and not s.is_exploding and not s.has_moved)
	print("DEBUG: start_movement_phase. Side: ", current_side_id, " Available: ", available.size())
	if available.size() > 0:
		print("DEBUG: First available: ", available[0].name, " ID: ", available[0].side_id, " Moved: ", available[0].has_moved)
	
	if available.size() == 0:
		# Movement Phase COMPLETE for this side (All ships moved)
		# OLD: Auto-advance
		# start_combat_passive()
		# NEW: Just update UI to enable "Execute" button
		_update_ui_state()
		return

	# AUTO-ORBIT LOGIC (Prioritized)
	# Check if ANY available ship is a station in orbit
	var auto_candidate = null
	for s in available:
		if s.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"] and s.orbit_direction != 0:
			auto_candidate = s
			print("DEBUG: Auto-Orbit Candidate Found: %s (Class: %s, Orbit: %d)" % [s.name, s.ship_class, s.orbit_direction])
			break
		else:
			print("DEBUG: Skip Auto-Orbit Check: %s (Class: %s, Orbit: %d)" % [s.name, s.ship_class, s.orbit_direction])
			
	if auto_candidate:
		# Force selection and execute
		selected_ship = auto_candidate
		# Proceed to execute logic block below (Factor out or verify flow)
		# We can't just fall through because of the 'Respect Selection' block.
		# So we handle it here and return.
		
		# Only Authority triggers the auto-move
		var am_authority = (my_side_id == current_side_id) or _is_server_or_offline()
		
		if am_authority:
			_spawn_ghost()
			_reset_plotting_state()
			_on_orbit(auto_candidate.orbit_direction)
			
			_update_camera()
			_update_ui_state()
			# log_message("Station %s maintaining orbit..." % auto_candidate.name) # Silenced for speed
			
			if not state_is_orbiting:
				print("[DEBUG] Auto-Orbit Failed (No planet?). Defaulting to Hold Position.")
				current_path.clear()
				state_is_orbiting = false

			# Instant execution
			_on_commit_move()
			
			# Apply LOCALLY immediately (Authority)
			# This updates state without ending phase for others
			_apply_movement_plan(auto_candidate)
			
			# Remove from available so we don't re-select it
			available.erase(auto_candidate)
			selected_ship = null
			
			_update_camera()
			_update_ui_state()
				

	# FIX: Respect current selection if valid
	# If we already have a selected ship that is VALID (available), don't change selection.
	if selected_ship and selected_ship in available:
		_update_ui_state()
		return
		
	if available.size() == 0:
		_update_ui_state()
		return

	# Default to first available
	selected_ship = available[0]
		

	if audio_ship_select and audio_ship_select.stream:
		audio_ship_select.play()
	
	_spawn_ghost()
	_reset_plotting_state()
	
	# Check for Persistent Orbit
	if selected_ship.orbit_direction != 0:
		_on_orbit(selected_ship.orbit_direction)
		log_message("Auto-plotting Orbit...")
		print("[DEBUG] Orbit plotted for %s" % selected_ship.name)
	else:
		print("[DEBUG] Standard move start for %s" % selected_ship.name)
	
	_update_camera()
	_update_ui_state() # Ensure UI reflects initial selection
	
	if is_phase_change and audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()


func _push_history_state():
	# Save snapshot of current state BEFORE applying a change
	var state = {
		"ghost_pos": ghost_head_pos,
		"ghost_facing": ghost_head_facing,
		"path_size": current_path.size(),
		"turns_rem": turns_remaining,
		"can_turn": can_turn_this_step,
		"turn_taken": turn_taken_this_step,
		"is_orbiting": state_is_orbiting,
		"orbit_dir": current_orbit_direction,
		"has_suffered_gravity": has_suffered_gravity_this_turn
	}
	movement_history.push_back(state)
	btn_undo.visible = true # Ensure undo is visible if history exists
	_update_ui_state()

	log_message("Movement Phase: %s" % get_side_name(current_side_id))

func start_combat_passive():
	current_phase = Phase.COMBAT
	combat_subphase = 1 # Passive First
	# Passive Fire: The NON-ACTIVE side fires
	firing_side_id = 3 - current_side_id # Assuming 2 sides (1 vs 2)
	
	print("[DEBUG] start_combat_passive: Side %d firing (Opponent of Moving Side %d)" % [firing_side_id, current_side_id])
	
	_update_phase_indicator() # NEW: Update UI for Combat Phase (Passive)
	
	if audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()
	
	_start_combat_planning()

func start_combat_active():
	current_phase = Phase.COMBAT
	combat_subphase = 2 # Active Second
	# Active Fire: The ACTIVE side fires
	firing_side_id = current_side_id
	
	_update_phase_indicator() # NEW: Update UI for Combat Phase (Active)
	
	print("[DEBUG] start_combat_active: Side %d firing (Active Side)" % firing_side_id)
	
	if audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()
	
	_start_combat_planning()

func _start_combat_planning():
	current_combat_state = CombatState.PLANNING
	queued_attacks.clear()
	selected_ship = null
	combat_target = null
	
	# Sync State before planning to ensure odds/damage are correct
	broadcast_game_state()
	
	# FIX: Explicitly hide Movement and Repair Panels to prevent overlap
	if panel_movement:
		panel_movement.visible = false
	if panel_repair:
		panel_repair.visible = false
	# Reset "fired" state visually for planning (actual state reset happens differently)

	# Actually, we need to track "planned usage".
	# For now, let's just refresh the UI.
	
	log_message("Combat Planning: Side %d" % firing_side_id)
	
	_update_ship_visuals()
	_update_camera()
	_update_ui_state()
	_update_planning_ui_list()
	queue_redraw()
	
	# Skip Check: If valid targets exist, stay. Else commit/next.
	if not _check_for_valid_combat_targets():
		var msg = "No valid targets for Side %d. Skipping..." % firing_side_id
		log_message(msg)
		
		# Center Message
		label_center_message.text = msg
		label_center_message.visible = true
		
		# Delay slightly for readability
		get_tree().create_timer(2.0).timeout.connect(func():
			label_center_message.visible = false
			_handle_auto_skip_combat()
		)

func _handle_auto_skip_combat():
	# If we are the Server, we have authority to advance the state
	# when there are no valid choices to make.
	if _is_server_or_offline():
		# Bypass _on_combat_commit authority check and call RPC directly
		if _is_networked():
			rpc("execute_commit_combat", [], randi())
		else:
			execute_commit_combat([], randi())

func _update_planning_ui_list():
	# Clear existing
	for c in container_ships.get_children():
		container_ships.remove_child(c)
		c.queue_free()
		
	# Find ships for firing side
	var my_ships = []
	
	# Only populate list if it is MY turn to fire (or I am spectator/server)
	if my_side_id == 0 or my_side_id == firing_side_id:
		my_ships = ships.filter(func(s): return is_instance_valid(s) and s.side_id == firing_side_id and not s.is_exploding)

	
	for s in my_ships:
		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Status Check
		var targets = _get_valid_targets(s)

		var has_targets = targets.size() > 0
		var is_planned = false
		for atk in queued_attacks:
			if atk["source"] == s:
				is_planned = true
				break
		
		var status_str = "[ ]"
		var target_info = ""
		
		if is_planned:
			status_str = "[ORD]" # Ordered
			# Find the target for this ship
			for atk in queued_attacks:
				if atk["source"] == s:
					# target_info = " -> %s (%s)" % [atk["target"].name, atk["weapon_name"]]
					# Reverting detailed info on button as per user request (moved to Left Display)
					target_info = " [ORD]"
					break
		elif not has_targets: status_str = "[NO]"
		else: status_str = "[!]"
		
		# Check if ship has ANY available weapons for this phase
		var any_weapon_available = false
		for w in s.weapons:
			if _is_weapon_available_in_phase(w):
				any_weapon_available = true
				break
		
		if not any_weapon_available:
			status_str = "[N/A]"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.5) # Greyed out
		elif s == selected_ship:
			btn.modulate = Color.YELLOW
		elif is_planned:
			btn.modulate = Color.GREEN
		elif not has_targets:
			btn.modulate = Color.GRAY
		
		btn.text = "%s %s%s" % [status_str, s.name, target_info]

		btn.pressed.connect(func():
			selected_ship = s
			combat_target = null
			_update_planning_ui_list()
			# _update_ui_state() # REMOVED: _update_planning_ui_list now handles its own visibility, and _update_ui_state defaults to hiding it!
			# If we need to update other UI elements (like camera/status), we should ensure they don't clobber this.
			# Better: Let _update_ui_state be the master, and HAVE IT call _update_planning_ui_list.
			
			# Current Fix: Call _update_ui_state FIRST, then refresh list (which sets visibility)
			_update_ui_state()
			_update_planning_ui_list()
			
			_update_camera(selected_ship) # Refocus view on selected ship
			_update_ship_visuals()
			queue_redraw()
		)
		
		
		
		container_ships.add_child(btn)
		
	# FORCE Visibility purely based on content/logic
	# We already checked my_ships.size() > 0 which effectively checks for valid ships to show
	if my_ships.size() > 0:
		# Add Auto-Plan Button
		var sep = HSeparator.new()
		container_ships.add_child(sep)
		
		var auto_plan_btn = Button.new()
		auto_plan_btn.text = "Auto-Plan Attacks"
		auto_plan_btn.modulate = Color(0.6, 0.8, 1.0)
		auto_plan_btn.pressed.connect(_on_auto_plan_attacks_pressed)
		container_ships.add_child(auto_plan_btn)
		
		panel_planning.visible = true
		if panel_repair: panel_repair.visible = false
	
	# Reposition Minimap
	if panel_planning.visible:
		call_deferred("_update_minimap_position")

	var is_my_planning_phase = (firing_side_id == my_side_id) or (my_side_id == 0)
	if not is_my_planning_phase and current_phase == Phase.COMBAT and current_combat_state == CombatState.PLANNING:
		label_status.text += "\n\n(Waiting for Side %d to plan attacks...)" % firing_side_id
		
	_update_attack_queue_ui()

func _on_auto_plan_attacks_pressed():
	if current_phase != Phase.COMBAT or current_combat_state != CombatState.PLANNING:
		return
		
	var temp_ai = ComputerOpponent.new()
	temp_ai.game_manager = self
	temp_ai.side_id = firing_side_id
	temp_ai.setup_faction_details()
	
	var planned_attacks = temp_ai._plan_combat()
	temp_ai.queue_free()
	
	# Clear existing so we don't accidentally double-queue
	_clear_all_attacks()
	
	for atk in planned_attacks:
		if _is_networked():
			rpc_add_attack.rpc(atk["s"], atk["t"], atk["w"])
		else:
			rpc_add_attack(atk["s"], atk["t"], atk["w"])
			
	log_message("[color=cyan]Auto-planning complete for Phase %d.[/color]" % combat_subphase)

func _clear_all_attacks():
	var attacks_to_clear = queued_attacks.duplicate()
	for atk in attacks_to_clear:
		if is_instance_valid(atk["source"]):
			if _is_networked():
				rpc_remove_attack.rpc(atk["source"].name, atk["weapon_idx"])
			else:
				rpc_remove_attack(atk["source"].name, atk["weapon_idx"])
			
func _update_attack_queue_ui():
	# Clear List
	for c in list_attack_queue.get_children():
		c.queue_free()

	if current_phase != Phase.COMBAT or not panel_attack_queue:
		if panel_attack_queue: panel_attack_queue.visible = false
		return

	# Show to ALL players during Combat
	panel_attack_queue.visible = true
	
	# Only Firing Side (or Host/Spectator?) can Clear All
	# Host (1) usually plays Side 1? Spec is 0. 
	# Let's say: Clear All enabled if (my_side_id == firing_side_id) OR (my_side_id == 0)
	if btn_clear_all:
		var can_clear = (my_side_id == firing_side_id) or (my_side_id == 0)
		btn_clear_all.visible = can_clear


	# Populate
	for atk in queued_attacks:
		if not is_instance_valid(atk["source"]) or not is_instance_valid(atk["target"]): continue
		
		var source = atk["source"]
		var target = atk["target"]
		var weapon = source.weapons[atk["weapon_idx"]]
		var weapon_name = atk["weapon_name"]
		
		var chance = 0
		if combat_subphase == 1 and target.side_id == current_side_id:
			var best_hex_info = Combat.get_best_defensive_fire_hex(source, target, weapon, 0)
			chance = best_hex_info["chance"]
		else:
			# Calc Hit Chance standard
			var dist = HexGrid.hex_distance(source.grid_position, target.grid_position)
			
			# Head On Logic (Replicated from Resolution for estimation)
			var is_head_on = false
			if weapon.get("arc") == "FF":
				if target.grid_position == source.grid_position:
					is_head_on = true
				else:
					var fwd_vec = HexGrid.get_direction_vec(source.facing)
					var check = source.grid_position + fwd_vec
					for i in range(weapon["range"]):
						if check == target.grid_position:
							is_head_on = true
							break
						check += fwd_vec
			chance = Combat.calculate_hit_chance(dist, weapon, target, is_head_on, 0, source)
		
		var row = HBoxContainer.new()
		list_attack_queue.add_child(row)
		
		var lbl = Label.new()
		# Format: [ Source ] --> [ Weapon ] --> [ Target ] [ 75% ]
		lbl.text = "[ %s ]  -->  [ %s ]  -->  [ %s ]   [ %d%% ]" % [source.name, weapon_name, target.name, chance]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(lbl)

# _check_combat_availability removed/replaced by explicit planning flow


func end_turn_cycle():
	# Scenario Objective Check: Surprise Attack (Defiant Evacuation)
	# Check before switching player, or after? 
	# "Turns docked" -> implied "Full Turns" or "Turn Cycles"?
	# Let's count at the end of the Cycle (when both players have acted).
	if _is_server_or_offline():
		# Process Special Rules
		for rule in current_scenario_rules:
			if rule["type"] == "docked_turn_counter":
				var t_name = rule["target_name"]
				var prop = rule["counter_property"]
				var log_tmpl = rule["log_template"]
				
				# Find target
				var target_ship = null
				for s in ships:
					if not is_instance_valid(s): continue
					if s.name == t_name:
						target_ship = s
						break
				
				if target_ship and target_ship.is_docked:
					# Use dynamic property access
					var current_val = target_ship.get(prop)
					if current_val != null:
						target_ship.set(prop, current_val + 1)
						var msg = log_tmpl % (current_val + 1)
						log_message(msg)
			
	log_message("Turn Segment Complete.")
	
	# Logic:
	# If Passive Combat just finished -> Start Active Combat
	# If Active Combat just finished -> End Player's Turn -> Start Next Player OR End Round
	
	if combat_subphase == 1:
		# Pasive done, start Active
		start_combat_active()
	elif combat_subphase == 2:
		# Active done, Side's Turn Complete
		current_turn_order_index += 1
		if current_turn_order_index < turn_order.size():
			# Next Side
			_start_turn_for_side(turn_order[current_turn_order_index])
		else:
			# Round Complete
			_end_round_cycle()

func _center_camera_on_deployment_zone(ship: Ship):
	var valid_hexes = ScenarioManager.get_valid_deployment_hexes(deployment_subphase, ships, planet_hexes, ship)
	if valid_hexes.size() > 0:
		var center_pixel = Vector2.ZERO
		for h in valid_hexes:
			center_pixel += HexGrid.hex_to_pixel(h)
		center_pixel /= valid_hexes.size()
		
		# If the deployment zone is a massive perimeter ring, the average drops back to exactly the planet.
		# Rather than misleading the player, force the camera to zoom way out to show the deployment boundary.
		if valid_hexes.size() > 50 and center_pixel.length() < 100:
			camera.position = center_pixel
			target_zoom = Vector2(0.3, 0.3)
		else:
			camera.position = center_pixel
			
		# Automatically snap the zoom right now
		camera.zoom = target_zoom
	elif planet_hexes.size() > 0:
		var center_pixel = Vector2.ZERO
		for h in planet_hexes:
			center_pixel += HexGrid.hex_to_pixel(h)
		center_pixel /= planet_hexes.size()
		camera.position = center_pixel
		target_zoom = Vector2(0.5, 0.5) # Zoom out to see the whole planet system

func _update_deployment_ui():
	print("[DEBUG] _update_deployment_ui called - Subphase: %d, my_side_id: %d" % [deployment_subphase, my_side_id])
	if not is_instance_valid(list_deployment): return
	
	for c in list_deployment.get_children():
		c.queue_free()
		
	if deployment_subphase == 0 or current_phase != Phase.DEPLOYMENT:
		panel_deployment.visible = false
		return
		
	panel_deployment.visible = true
	var is_my_turn = (deployment_subphase == my_side_id or my_side_id == 0)
	
	# Find my undeployed ships
	var my_ships = ships.filter(func(s): return is_instance_valid(s) and s.side_id == deployment_subphase and not s.is_exploding)
	# Docked ships are deployed automatically with their host, so skip them
	var deployable_ships = my_ships.filter(func(s): return not s.is_docked)
	var undeployed = deployable_ships.filter(func(s): return not s.is_deployed)
	
	if not is_my_turn:
		var lbl = Label.new()
		var sn = get_side_name(deployment_subphase)
		lbl.text = "Awaiting %s to Deploy..." % sn
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_deployment.add_child(lbl)
		
		# Hide controls
		btn_deploy_facing_cw.disabled = true
		btn_deploy_facing_ccw.disabled = true
		spin_deploy_speed.editable = false
		if is_instance_valid(btn_deploy_orbit_cw):
			btn_deploy_orbit_cw.disabled = true
			btn_deploy_orbit_ccw.disabled = true
		btn_deploy_ship.disabled = true
		btn_deploy_complete.disabled = true
		if is_instance_valid(btn_auto_deploy):
			btn_auto_deploy.visible = false
		return
		
	if is_instance_valid(btn_auto_deploy):
		btn_auto_deploy.visible = true
		
	if undeployed.is_empty():
		var lbl = Label.new()
		lbl.text = "All ships deployed."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_deployment.add_child(lbl)
		
		btn_deploy_complete.disabled = false
	else:
		btn_deploy_complete.disabled = true # Must deploy all ships first
		
	for s in deployable_ships:
		var btn = Button.new()
		if s == selected_ship:
			btn.text = "> %s <" % s.name
			btn.modulate = Color.YELLOW
		else:
			btn.text = s.name
			if s.is_deployed:
				btn.text += " (Deployed)"
				btn.modulate = Color.GREEN
		
		btn.pressed.connect(func():
			selected_ship = s
			is_deploying_ship = true
			state_deployment_mine_placement = false
			if btn_deploy_mine: btn_deploy_mine.set_pressed_no_signal(false)
			if s.is_deployed:
				deploy_tentative_hex = s.grid_position
				deploy_facing_val = s.facing
				deploy_speed_val = s.speed
				deploy_orbit_dir_val = s.orbit_direction if s.orbit_direction != 0 else 1
				deploy_hex_selected = true
			else:
				deploy_hex_selected = false
				deploy_orbit_dir_val = 1
				
				# Center camera on valid deployment zone
				_center_camera_on_deployment_zone(s)
					
			_update_deployment_ui()
			_update_deploy_preview()
			_update_ui_state()
		)
		list_deployment.add_child(btn)
		
	if is_instance_valid(selected_ship) and selected_ship.side_id == deployment_subphase:
		btn_deploy_facing_cw.disabled = false
		btn_deploy_facing_ccw.disabled = false
		spin_deploy_speed.editable = true
		if is_instance_valid(spin_deploy_speed):
			spin_deploy_speed.min_value = 0
			spin_deploy_speed.max_value = 20
		
		# [SCENARIO RULE] Close Escort - Megasaurus locked speed limits.
		var scen_key = "simple_test"
		if NetworkManager.lobby_data != null:
			scen_key = NetworkManager.lobby_data.get("scenario", "simple_test")
			
		if scen_key == "close_escort" and selected_ship.name == "Megasaurus":
			deploy_speed_val = 5
			deploy_facing_val = 3
			if is_instance_valid(spin_deploy_speed):
				spin_deploy_speed.min_value = 5
				spin_deploy_speed.max_value = 5
				spin_deploy_speed.set_value_no_signal(5.0)
			spin_deploy_speed.editable = false
			btn_deploy_facing_cw.disabled = true
			btn_deploy_facing_ccw.disabled = true
			
		var is_station = selected_ship.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]
		if is_instance_valid(btn_deploy_orbit_cw):
			if is_instance_valid(hbox_deploy_orbit): hbox_deploy_orbit.visible = is_station
			btn_deploy_orbit_cw.visible = is_station
			btn_deploy_orbit_ccw.visible = is_station
			if is_station:
				btn_deploy_orbit_cw.disabled = false
				btn_deploy_orbit_ccw.disabled = false
				btn_deploy_orbit_cw.modulate = Color.GREEN if deploy_orbit_dir_val == 1 else Color.WHITE
				btn_deploy_orbit_ccw.modulate = Color.GREEN if deploy_orbit_dir_val == -1 else Color.WHITE
				
			print("[DEBUG] Orbit UI Visible? CW: %s | CCW: %s | Is Station: %s" % [btn_deploy_orbit_cw.visible, btn_deploy_orbit_ccw.visible, is_station])
		btn_deploy_ship.disabled = false
		btn_deploy_ship.text = "UPDATE DEPLOYMENT" if selected_ship.is_deployed else "DEPLOY SHIP"
	else:
		btn_deploy_facing_cw.disabled = true
		btn_deploy_facing_ccw.disabled = true
		spin_deploy_speed.editable = false
		if is_instance_valid(btn_deploy_orbit_cw):
			if is_instance_valid(hbox_deploy_orbit): hbox_deploy_orbit.visible = false
			btn_deploy_orbit_cw.visible = false
			btn_deploy_orbit_ccw.visible = false
			btn_deploy_orbit_cw.disabled = true
			btn_deploy_orbit_ccw.disabled = true
		btn_deploy_ship.disabled = true
		btn_deploy_ship.text = "DEPLOY SHIP"
		
	# Calculate Deployment Mine Capacity
	var total_mine_capacity = 0
	var total_seeker_capacity = 0
	for s in ships:
		if is_instance_valid(s) and s.side_id == deployment_subphase:
			for w in s.weapons:
				if w.get("type", "") == "Mine":
					total_mine_capacity += w.get("ammo", 0)
				elif w.get("type", "") == "Seeker":
					total_seeker_capacity += w.get("ammo", 0)
					
	if total_mine_capacity > 0:
		btn_deploy_mine.visible = true
		var mines_remaining = total_mine_capacity - deployment_mines_placed.size()
		if state_deployment_mine_placement:
			btn_deploy_mine.text = "Cancel Placement (%d Left)" % mines_remaining
		else:
			btn_deploy_mine.text = "Place Mine (%d Left)" % mines_remaining
		btn_deploy_mine.disabled = (mines_remaining <= 0 and not state_deployment_mine_placement)
	else:
		btn_deploy_mine.visible = false
		state_deployment_mine_placement = false
		
	if total_seeker_capacity > 0:
		btn_deploy_seeker.visible = true
		var seekers_remaining = total_seeker_capacity - deployment_seekers_placed.size()
		if state_deployment_seeker_placement:
			btn_deploy_seeker.text = "Cancel Placement (%d Left)" % seekers_remaining
		else:
			btn_deploy_seeker.text = "Place Seeker (%d Left)" % seekers_remaining
		btn_deploy_seeker.disabled = (seekers_remaining <= 0 and not state_deployment_seeker_placement)
	else:
		btn_deploy_seeker.visible = false
		state_deployment_seeker_placement = false

func _on_auto_deploy_pressed():
	if current_phase != Phase.DEPLOYMENT: return
	
	# First, wipe existing deployments for this side so we can recalculate and redeploy from scratch
	for s in ships:
		if is_instance_valid(s) and s.side_id == deployment_subphase and not s.is_docked:
			s.is_deployed = false
			s.speed = 0
			s.orbit_direction = 0
			s.grid_position = Vector3i.ZERO
			
	# Also clear out any mines or seekers we've placed
	deployment_mines_placed.clear()
	deployment_seekers_placed.clear()
	
	var my_undeployed = []
	for s in ships:
		if is_instance_valid(s) and s.side_id == deployment_subphase and not s.is_docked:
			my_undeployed.append(s)
			
	if my_undeployed.is_empty():
		return
		
	var valid_hexes = ScenarioManager.get_valid_deployment_hexes(deployment_subphase, ships, planet_hexes, null)
	
	var processor = AutoDeployProcessor.new()
	processor.execute(my_undeployed, valid_hexes, self)
	
	_update_deployment_ui()
	queue_redraw()

func _update_deploy_preview():
	if not is_deploying_ship or not is_instance_valid(selected_ship) or not deploy_hex_selected:
		if is_instance_valid(ghost_ship):
			ghost_ship.queue_free()
			ghost_ship = null
		queue_redraw()
		return
		
	if not is_instance_valid(ghost_ship):
		ghost_ship = _create_ghost_ship(selected_ship)
		
	# Update ghost ship stats to preview
	ghost_ship.grid_position = deploy_tentative_hex
	ghost_ship.facing = deploy_facing_val
	ghost_ship.speed = deploy_speed_val
	ghost_ship.position = HexGrid.hex_to_pixel(deploy_tentative_hex)
	ghost_ship.modulate = Color(1, 1, 1, 0.5) # Semi-transparent
	
	queue_redraw()

func _on_deploy_ship_pressed():
	if not is_deploying_ship or not is_instance_valid(selected_ship): return
	
	# Validate bounds / rules
	var valid_hexes = ScenarioManager.get_valid_deployment_hexes(deployment_subphase, ships, planet_hexes, selected_ship)
	if valid_hexes.size() > 0 and not valid_hexes.has(deploy_tentative_hex):
		log_message("[color=red]Invalid deployment location![/color]")
		return
		
	# Check collision with planet
	if planet_hexes.has(deploy_tentative_hex):
		log_message("[color=red]Cannot deploy inside a planet![/color]")
		return
		
	selected_ship.grid_position = deploy_tentative_hex
	selected_ship.facing = deploy_facing_val
	if selected_ship.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
		deploy_speed_val = 0
		selected_ship.orbit_direction = deploy_orbit_dir_val
	else:
		selected_ship.orbit_direction = 0
	selected_ship.speed = deploy_speed_val
	selected_ship.is_deployed = true
	selected_ship.position = HexGrid.hex_to_pixel(selected_ship.grid_position)
	
	log_message("%s deployed at %s, facing %d, speed %d." % [selected_ship.name, str(deploy_tentative_hex), deploy_facing_val, deploy_speed_val])
	
	# Also deploy any ships docked to this one
	for s in ships:
		if is_instance_valid(s) and s.is_docked and s.docked_host == selected_ship:
			s.grid_position = deploy_tentative_hex
			s.facing = deploy_facing_val
			s.speed = deploy_speed_val
			s.is_deployed = true
			s.position = HexGrid.hex_to_pixel(s.grid_position)
			log_message("%s (docked to %s) deployed automatically." % [s.name, selected_ship.name])
	
	is_deploying_ship = false
	deploy_hex_selected = false
	
	if audio_beep and audio_beep.stream: audio_beep.play()
	
	_update_deployment_ui()
	_update_deploy_preview()

func _on_deploy_complete_pressed():
	log_message("Submitting Deployment for Side %d" % deployment_subphase)
	
	var dep_data = {}
	for s in ships:
		if is_instance_valid(s) and s.side_id == deployment_subphase:
			dep_data[s.name] = {
				"grid_position": s.grid_position,
				"facing": s.facing,
				"speed": s.speed,
				"orbit_direction": s.orbit_direction,
				"is_deployed": true
			}
			
	var deployed_mines_data = deployment_mines_placed.duplicate()
	var deployed_seekers_data = deployment_seekers_placed.duplicate()
	
	if _is_networked() and not _is_server_or_offline():
		rpc_submit_deployment.rpc_id(1, deployment_subphase, dep_data, deployed_mines_data, deployed_seekers_data)
	else:
		rpc_submit_deployment(deployment_subphase, dep_data, deployed_mines_data, deployed_seekers_data)


@rpc("any_peer", "call_local", "reliable")
func rpc_submit_deployment(side_id: int, deployment_data: Dictionary, deployed_mines_data: Array = [], deployed_seekers_data: Array = []):
	if not _is_server_or_offline(): return
	
	# Apply and broadcast the final placed positions to everyone
	if _is_networked():
		rpc_apply_deployment_data.rpc(side_id, deployment_data, deployed_mines_data, deployed_seekers_data)
	else:
		rpc_apply_deployment_data(side_id, deployment_data, deployed_mines_data, deployed_seekers_data)

@rpc("authority", "call_local", "reliable")
func rpc_apply_deployment_data(side_id: int, deployment_data: Dictionary, deployed_mines_data: Array = [], deployed_seekers_data: Array = []):
	# Apply final positions locally for UI/render matching
	for s in ships:
		if is_instance_valid(s) and s.side_id == side_id and deployment_data.has(s.name):
			var d = deployment_data[s.name]
			s.grid_position = d["grid_position"]
			s.facing = d["facing"]
			s.speed = d["speed"]
			s.orbit_direction = d.get("orbit_direction", 0)
			s.position = HexGrid.hex_to_pixel(s.grid_position)
			s.is_deployed = true
			
	# Inject deployment mines and charge their ammo cost
	for m_pos in deployed_mines_data:
		active_mines.append({
			"pos": Vector3i(m_pos), # Typecast just in case for ENet deserialization
			"side_id": int(side_id), # Enforce exact int matching for multiplayer eval
			"owner_name": "Deployment"
		})
		
		# Deduct ammo dynamically from side's minelayer(s)
		for s in ships:
			if is_instance_valid(s) and s.side_id == side_id:
				var deducted = false
				for w in s.weapons:
					if w.get("type", "") == "Mine" and w.get("ammo", 0) > 0:
						w["ammo"] -= 1
						deducted = true
						break
				if deducted:
					break
					
	# Inject deployment seekers and charge their ammo cost
	for s_pos in deployed_seekers_data:
		active_seekers.append({
			"pos": Vector3i(s_pos),
			"side_id": int(side_id),
			"owner_name": "Deployment",
			"speed": 0
		})
		
		# Deduct ammo dynamically from side's equipped ships
		for s in ships:
			if is_instance_valid(s) and s.side_id == side_id:
				var deducted = false
				for w in s.weapons:
					if w.get("type", "") == "Seeker" and w.get("ammo", 0) > 0:
						w["ammo"] -= 1
						deducted = true
						break
				if deducted:
					break
			
	if side_id == 1:
		has_deployed_side_1 = true
	elif side_id == 2:
		has_deployed_side_2 = true

	queue_redraw()

	# Only the host determines the state transition logic
	if _is_server_or_offline():
		# Next steps
		if has_deployed_side_1 and has_deployed_side_2:
			# All deployed, start the game
			if _is_networked():
				rpc_finalize_deployment.rpc()
			else:
				rpc_finalize_deployment()
		else:
			# Someone is missing
			var next_side = 1 if side_id == 2 else 2
			if _is_networked():
				rpc_sync_deployment_state.rpc(next_side)
			else:
				rpc_sync_deployment_state(next_side)

@rpc("authority", "call_local", "reliable")
func rpc_sync_deployment_state(subphase: int):
	deployment_subphase = subphase
	log_message("Side %d is now Deploying." % subphase)
	
	if audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()
		
	_update_ui_state()
	_update_deployment_ui()

@rpc("authority", "call_local", "reliable")
func rpc_finalize_deployment():
	log_message("Deployment Complete. Starting Turn 1.")
	panel_deployment.visible = false
	start_turn_cycle()


func start_repair_phase():
	# Only authority orchestrates the transition
	if _is_networked() and (multiplayer.get_unique_id() if _is_networked() else 1) != 1:
		return 

	current_combat_state = CombatState.NONE # AI DEADLOCK FIX: clear resolving state for repair phase
	
	repair_allocations.clear()
	has_submitted_final_repairs = false
	active_repair_animations = 0
	
	if _is_networked():
		rpc_sync_repair_state.rpc(1, repair_allocations)
	else:
		rpc_sync_repair_state(1, repair_allocations)

func _update_repair_ui():
	print("[DEBUG] _update_repair_ui called - Subphase: %d, my_side_id: %d" % [repair_subphase, my_side_id])
	log_message("[DEBUG] Updating Repair UI for Phase: %d" % repair_subphase)
	if not is_instance_valid(list_repair): 
		print("[DEBUG] _update_repair_ui aborted: list_repair is invalid!")
		return
	
	# Clear list
	for c in list_repair.get_children():
		c.queue_free()
		
	if repair_subphase == 3:
		var lbl = Label.new()
		lbl.text = "Executing Repairs..."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_repair.add_child(lbl)
		return
	if not is_instance_valid(selected_ship) or selected_ship.side_id != repair_subphase or selected_ship.hull <= 0:
		var lbl = Label.new()
		lbl.text = "Select a damaged friendly ship to allocate DCR."
		if repair_subphase != my_side_id and my_side_id != 0:
			var sn = get_side_name(repair_subphase)
			lbl.text = "Awaiting %s to finish damage allocation..." % sn
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_repair.add_child(lbl)
		
		if btn_repair_exec:
			btn_repair_exec.disabled = false
		return
		
	var s = selected_ship
	var damaged_systems = []
	
	# Hull
	if s.hull < s.max_hull: damaged_systems.append({"key": "hull", "name": "Hull (%d/%d)" % [s.hull, s.max_hull]})
	for i in range(s.current_adf_modifier): damaged_systems.append({"key": "adf_%d" % i, "name": "ADF Loss"})
	for i in range(s.unrepairable_adf_modifier): damaged_systems.append({"key": "adf_unrep_%d" % i, "name": "ADF Loss"})
	for i in range(s.current_mr_modifier): damaged_systems.append({"key": "mr_%d" % i, "name": "MR Loss"})
	for i in range(s.unrepairable_mr_modifier): damaged_systems.append({"key": "mr_unrep_%d" % i, "name": "MR Loss"})
	if s.has_electrical_fire: damaged_systems.append({"key": "fire_elec", "name": "Electrical Fire"})
	if s.has_disastrous_fire: damaged_systems.append({"key": "fire_dis", "name": "Disastrous Fire"})
	if s.ccs_damaged: damaged_systems.append({"key": "ccs", "name": "CCS (Computer)"})
	if s.icm_max < s.base_icm_max: damaged_systems.append({"key": "icm", "name": "ICM Launcher"})
	if s.ms_max < s.base_ms_max: damaged_systems.append({"key": "ms", "name": "Masking Screen"})
	
	# Weapons
	for i in range(s.weapons.size()):
		if s.weapons[i].get("is_crippled", false) or s.weapons[i].get("unrepairable", false):
			damaged_systems.append({"key": "wpn_%d" % i, "name": "Crippled: %s" % s.weapons[i]["name"]})
			
	if damaged_systems.size() > 0:
		var dcr_avail = s.current_dcr 
		
		var ship_lbl = Label.new()
		ship_lbl.text = "%s (Total DCR: %d)" % [s.name, dcr_avail]
		ship_lbl.modulate = Color.CYAN
		list_repair.add_child(ship_lbl)
		
		if not repair_allocations.has(s.name):
			repair_allocations[s.name] = {}
			
		var ship_budget_used = 0
		for val in repair_allocations[s.name].values():
			ship_budget_used += val
		
		var rem_lbl = Label.new()
		rem_lbl.text = "Budget Remaining: %d" % (dcr_avail - ship_budget_used)
		rem_lbl.add_theme_font_size_override("font_size", 12)
		list_repair.add_child(rem_lbl)
		
		for dmg in damaged_systems:
			var hbox = HBoxContainer.new()
			
			var sys_lbl = Label.new()
			sys_lbl.text = dmg["name"]
			sys_lbl.custom_minimum_size.x = 200
			hbox.add_child(sys_lbl)
			
			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = 90
			spin.step = 1
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.custom_minimum_size.x = 100
			spin.editable = (my_side_id == repair_subphase or my_side_id == 0)
			
			var dk = dmg["key"]
			var is_unrepairable = false
			if dk == "fire_elec" and s.unrepairable_electrical_fire: is_unrepairable = true
			elif dk == "fire_dis" and s.unrepairable_disastrous_fire: is_unrepairable = true
			elif dk == "ccs" and s.unrepairable_ccs: is_unrepairable = true
			elif dk == "icm" and s.unrepairable_icm: is_unrepairable = true
			elif dk == "ms" and s.unrepairable_ms: is_unrepairable = true
			elif dk.begins_with("adf_unrep_") or dk.begins_with("mr_unrep_"): is_unrepairable = true
			elif dk.begins_with("wpn_"):
				var w_idx = int(dk.split("_")[1])
				if s.weapons[w_idx].get("unrepairable", false):
					is_unrepairable = true
			
			if is_unrepairable:
				sys_lbl.modulate = Color(1, 0, 0, 0.5)
				sys_lbl.text += " (DESTROYED)"
				spin.editable = false
				spin.value = 0
			else:
				spin.value = repair_allocations[s.name].get(dmg["key"], 0)
				
			spin.suffix = "%"
			hbox.add_child(spin)
			
			var max_budget_avail = (dcr_avail - ship_budget_used) + spin.value
			
			spin.value_changed.connect(func(v):
				if v > max_budget_avail:
					spin.value = max_budget_avail
					v = max_budget_avail
				repair_allocations[s.name][dmg["key"]] = v
				_update_repair_ui() # Full redraw refreshes limits automatically
			)
			
			list_repair.add_child(hbox)
	else:
		var lbl = Label.new()
		lbl.text = "%s has no damaged systems." % s.name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_repair.add_child(lbl)
		
	if btn_repair_exec:
		btn_repair_exec.disabled = false
		
	print("[DEBUG] _update_repair_ui FINISHED. Items in list_repair: %d" % list_repair.get_child_count())

func _update_repair_ui_list():
	for c in list_movement.get_children():
		c.queue_free()
		
	# Find damaged ships for active side
	var my_ships = []
	if repair_subphase > 0:
		my_ships = ships.filter(func(s): return is_instance_valid(s) and s.side_id == repair_subphase and not s.is_exploding and s.hull > 0)
	
	# Only keep ships that actually have damage to repair
	var damaged_ships = []
	for s in my_ships:
		# Check if ship has ANY damaged system
		var has_damage = (s.hull < s.max_hull) or (s.current_adf_modifier > 0) or (s.current_mr_modifier > 0) or s.has_electrical_fire or s.has_disastrous_fire
		has_damage = has_damage or s.ccs_damaged or (s.icm_max < s.base_icm_max) or (s.ms_max < s.base_ms_max)
		if not has_damage:
			for w in s.weapons:
				if w.get("is_crippled", false):
					has_damage = true
					break
		if has_damage:
			damaged_ships.append(s)
			
	if damaged_ships.size() == 0:
		var lbl = Label.new()
		lbl.text = "No damaged ships."
		list_movement.add_child(lbl)
		
	for s in damaged_ships:
		var btn = Button.new()
		var color_code = Color.ORANGE
		
		# Check if allocation was completed
		var is_fully_allocated = false
		if repair_allocations.has(s.name):
			var allocated = 0
			for val in repair_allocations[s.name].values():
				allocated += val
			is_fully_allocated = (allocated == s.current_dcr)
			
		if is_fully_allocated:
			color_code = Color.GREEN
			
		# Highlight selected
		if s == selected_ship:
			btn.text = "> %s <" % s.name
			btn.modulate = Color.YELLOW
		else:
			btn.text = s.name
			btn.modulate = color_code
			
		btn.pressed.connect(func():
			if current_phase == Phase.REPAIR and (repair_subphase == my_side_id or my_side_id == 0):
				selected_ship = s
				_update_ui_state()
				_update_repair_ui()
				_update_camera()
		)
		list_movement.add_child(btn)
func _on_repair_exec_pressed():
	if repair_subphase == 1 or repair_subphase == 2:
		if btn_repair_exec:
			btn_repair_exec.disabled = true
			
		log_message("Submitting Repair Allocations for Side %d" % repair_subphase)
		
		if _is_networked() and not _is_server_or_offline():
			rpc_submit_repair_allocations.rpc_id(1, repair_subphase, repair_allocations)
		else:
			rpc_submit_repair_allocations(repair_subphase, repair_allocations)


@rpc("any_peer", "call_local", "reliable")
func rpc_submit_repair_allocations(side_id: int, allocations: Dictionary):
	# Allow server to process
	if not _is_server_or_offline(): return
	
	if side_id == 1:
		# Process P1 repairs immediately
		var seed_val = randi()
		# Save P1, move to P2
		repair_allocations = allocations
		repair_subphase = 2
		
		if _is_networked():
			rpc_sync_repair_state.rpc(repair_subphase, repair_allocations)
			rpc_execute_repairs_for_side.rpc(1, allocations, seed_val, false)
		else:
			rpc_sync_repair_state(repair_subphase, repair_allocations)
			rpc_execute_repairs_for_side(1, allocations, seed_val, false)
			
	elif side_id == 2:
		# Merge P2 allocs
		for s_name in allocations:
			repair_allocations[s_name] = allocations[s_name]
			
		repair_subphase = 3
		var seed_val = randi()
		
		if _is_networked():
			rpc_sync_repair_state.rpc(repair_subphase, repair_allocations)
			rpc_execute_repairs_for_side.rpc(2, allocations, seed_val, true)
		else:
			rpc_sync_repair_state(repair_subphase, repair_allocations)
			rpc_execute_repairs_for_side(2, allocations, seed_val, true)

@rpc("authority", "call_local", "reliable")
func rpc_sync_repair_state(subphase: int, allocs: Dictionary):
	if current_phase != Phase.REPAIR:
		current_phase = Phase.REPAIR
		combat_subphase = 0
		log_message("[color=cyan]=== REPAIR TURN Phase ===[/color]")
		
	repair_subphase = subphase
	repair_allocations = allocs
	
	if audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()
		
	_update_ui_state()
	_update_repair_ui()

@rpc("authority", "call_local", "reliable")
func rpc_execute_repairs_for_side(side_id: int, allocs_for_side: Dictionary, rng_seed: int, is_final_side: bool):
	active_repair_animations += 1
	seed(rng_seed)
	# Loop through all ships, try repairs synchronously on both peers.
	for s in ships:
		if not is_instance_valid(s): continue
		if s.side_id != side_id: continue
		if not allocs_for_side.has(s.name): continue
		
		var ship_allocs = allocs_for_side[s.name]
		var total_allocated = 0
		for val in ship_allocs.values(): total_allocated += int(val)
		
		if total_allocated == 0: continue
		
		if not test_force_online:
			_update_camera(s) # Focus on ship being repaired
			await get_tree().create_timer(1.0).timeout
			
		var target_pos = HexGrid.hex_to_pixel(s.grid_position)
		
		if total_allocated > s.current_dcr:
			log_message("[color=red]%s exceeded DCR budget! All repairs failed.[/color]" % s.name)
			_spawn_hit_text(target_pos, "BUDGET EXCEEDED")
			if not test_force_online:
				await get_tree().create_timer(1.5).timeout
			continue
			
		for key in ship_allocs:
			var chance = ship_allocs[key]
			if chance <= 0: continue
			
			var roll = randi() % 100 + 1
			
			var display_name = key.to_upper()
			if key.begins_with("adf_"): display_name = "ADF"
			elif key.begins_with("mr_"): display_name = "MR"
			elif key.begins_with("wpn_"): display_name = "WPN"
			
			var pre_text = "%s (%d%%)\nRoll: %d\n" % [display_name, chance, roll]
			if audio_repair_roll and audio_repair_roll.stream:
				audio_repair_roll.play()
			
			if roll >= 90:
				if roll >= 99:
					var d_msg = "Repairing: %s, System: %s, Odds: %d%%, Roll: %d, Result: PERMANENTLY DESTROYED" % [s.name, display_name, chance, roll]
					if _is_networked() and multiplayer.is_server(): rpc_log_message.rpc(d_msg)
					else: log_message(d_msg)
					if audio_repair_failure and audio_repair_failure.stream:
						audio_repair_failure.play()
					_spawn_hit_text(target_pos, pre_text + "CRITICAL FAIL")
					_mark_unrepairable(s, key)
				else:
					var f_msg = "Repairing: %s, System: %s, Odds: %d%%, Roll: %d, Result: FAILED" % [s.name, display_name, chance, roll]
					if _is_networked() and multiplayer.is_server(): rpc_log_message.rpc(f_msg)
					else: log_message(f_msg)
					if audio_repair_failure and audio_repair_failure.stream:
						audio_repair_failure.play()
					_spawn_hit_text(target_pos, pre_text + "FAILED")
			elif roll <= chance:
				var s_msg = "Repairing: %s, System: %s, Odds: %d%%, Roll: %d, Result: SUCCESS" % [s.name, display_name, chance, roll]
				if _is_networked() and multiplayer.is_server(): rpc_log_message.rpc(s_msg)
				else: log_message(s_msg)
				if audio_repair_success and audio_repair_success.stream:
					audio_repair_success.play()
				_spawn_hit_text(target_pos, pre_text + "REPAIRED!")
				_apply_repair(s, key)
			else:
				var fail_msg = "Repairing: %s, System: %s, Odds: %d%%, Roll: %d, Result: FAILED" % [s.name, display_name, chance, roll]
				if _is_networked() and multiplayer.is_server(): rpc_log_message.rpc(fail_msg)
				else: log_message(fail_msg)
				if audio_repair_failure and audio_repair_failure.stream:
					audio_repair_failure.play()
				_spawn_hit_text(target_pos, pre_text + "FAILED")
			
			if not test_force_online:
				await get_tree().create_timer(2.0).timeout

	if is_final_side:
		has_submitted_final_repairs = true

	active_repair_animations -= 1
	if has_submitted_final_repairs and active_repair_animations <= 0:
		_conclude_repair_phase()

func _conclude_repair_phase():
	if panel_repair: panel_repair.visible = false
	
	turn_count += 1
	log_message("Round Complete (After Repair). Starting New Round.")
	# Reset Turn Order
	current_turn_order_index = 0
	
	# Reset ALL ships (Movement/Fired state)
	for s in ships:
		if is_instance_valid(s):
			s.reset_turn_state()
			
	# Start Side 1 Again
	_start_turn_for_side(turn_order[0])

func _mark_unrepairable(s: Ship, key: String):
	if key == "hull": pass # Can try hull again? Rules: "no further attempts possible".
	elif key.begins_with("adf_"): s.unrepairable_adf_modifier += 1
	elif key.begins_with("mr_"): s.unrepairable_mr_modifier += 1
	elif key == "fire_elec": s.unrepairable_electrical_fire = true
	elif key == "fire_dis": s.unrepairable_disastrous_fire = true
	elif key == "ccs": s.unrepairable_ccs = true
	elif key == "icm": s.unrepairable_icm = true
	elif key == "ms": s.unrepairable_ms = true
	elif key.begins_with("wpn_"):
		var idx = int(key.split("_")[1])
		if idx < s.weapons.size():
			s.weapons[idx]["unrepairable"] = true

func _apply_repair(s: Ship, key: String):
	if key == "hull":
		var restore = randi() % 10 + 1
		s.hull = min(s.max_hull, s.hull + restore)
		s.hull_changed.emit(s.hull)
	elif key.begins_with("adf_"):
		if s.current_adf_modifier > s.unrepairable_adf_modifier: s.current_adf_modifier -= 1
	elif key.begins_with("mr_"):
		if s.current_mr_modifier > s.unrepairable_mr_modifier: s.current_mr_modifier -= 1
	elif key == "fire_elec":
		if not s.unrepairable_electrical_fire: s.has_electrical_fire = false
	elif key == "fire_dis":
		if not s.unrepairable_disastrous_fire: s.has_disastrous_fire = false
	elif key == "ccs":
		if not s.unrepairable_ccs: s.ccs_damaged = false
	elif key == "icm":
		if not s.unrepairable_icm: 
			s.icm_max = s.base_icm_max
			s.icm_current = s.icm_max
	elif key == "ms":
		if not s.unrepairable_ms:
			s.ms_max = s.base_ms_max
			s.ms_current = s.ms_max
	elif key.begins_with("wpn_"):
		var idx = int(key.split("_")[1])
		if idx < s.weapons.size() and not s.weapons[idx].get("unrepairable", false):
			s.weapons[idx]["is_crippled"] = false
	s.state_changed.emit()
	s.queue_redraw()

func _end_round_cycle():
	# Trigger repair phase every 3 turns, before the turn increments.
	if turn_count > 0 and turn_count % 3 == 0:
		if current_phase != Phase.REPAIR:
			call_deferred("start_repair_phase")
		return

	turn_count += 1
	log_message("Round Complete. Starting New Round.")
	# Reset Turn Order
	current_turn_order_index = 0
	
	# Reset ALL ships (Movement/Fired state)
	for s in ships:
		if is_instance_valid(s):
			s.reset_turn_state() # Resets has_moved, has_fired, AP, energy, etc.
			
	# Start Side 1 Again
	_start_turn_for_side(turn_order[0])

func _update_camera(focus_target_override = null):
	var target_pos = Vector2.ZERO
	
	if focus_target_override:
		if focus_target_override is Node2D:
			target_pos = focus_target_override.position
		elif focus_target_override is Vector2:
			target_pos = focus_target_override
	elif combat_target and is_instance_valid(combat_target):
		target_pos = combat_target.position
	elif selected_ship:
		target_pos = HexGrid.hex_to_pixel(selected_ship.grid_position)
	else:
		return

	# Camera moves to target; no need to calculate center offset manually with Camera2D
	camera.position = target_pos


func _spawn_ghost():
	if ghost_ship:
		if test_force_online:
			# Tests pre-instantiate and track the ghost_ship object directly.
			# Destroying it breaks test references.
			ghost_head_pos = ghost_ship.grid_position
			ghost_head_facing = ghost_ship.facing
			path_preview_active = false
			return
			
		ghost_ship.queue_free()
		ghost_ship = null
	
	if not selected_ship or not is_instance_valid(selected_ship):
		return
		
	# Authority Check: Only spawn ghost if it's my turn/ship
	# EXCEPTION: If ship has orders, we allow ghost for visualization (Networked Movement Visualization)
	
	
	# Fix: Host Player (Side 1) should NOT bypass checks. Only Admin (Side 0) or Offline (Hotseat) can bypass.
	var is_offline = (not _is_networked()) and (not test_force_online)
	var is_admin_or_offline = (my_side_id == 0) or is_offline
	
	if not is_admin_or_offline:
		var has_orders = selected_ship.has_orders
		var is_my_turn_active = (current_side_id == my_side_id)
		var is_my_ship = (selected_ship.side_id == my_side_id)
		
		# Allow if:
		# 1. Has Orders (Visualization)
		# 2. My Turn AND My Ship (Plotting)
		var allowed = has_orders or (is_my_turn_active and is_my_ship)
		
		if not allowed:
			return

	ghost_ship = _create_ghost_ship(selected_ship)
	
	# Initialize Head State
	ghost_head_pos = ghost_ship.grid_position
	ghost_head_facing = ghost_ship.facing
	path_preview_active = false
	
	queue_redraw() # Ensure predictive path draws immediately

func _create_ghost_ship(source: Ship) -> Ship:
	var ghost = load("res://Scripts/Ship.gd").new()
	ghost.name = "GhostShip_%s" % source.name
	ghost.side_id = source.side_id
	ghost.ship_class = source.ship_class # Copy visual class
	ghost.faction = source.faction # Copy faction for sprite selection
	ghost.color = source.color
	ghost.grid_position = source.grid_position
	ghost.facing = source.facing
	ghost.speed = source.speed
	ghost.set_ghost(true)
	add_child(ghost)
	return ghost

func _update_ui_state():
	if not ui_layer: return
	
	_update_phase_indicator()
	
	# Reset Panels should be handled per-phase to avoid flicker
	# panel_planning.visible = false 
	# panel_movement.visible = false
	# Update Ship Status Panel
	if ship_status_panel:
		if is_instance_valid(selected_ship):
			ship_status_panel.update_from_ship(selected_ship)
		else:
			ship_status_panel.visible = false

	if current_phase == Phase.MOVEMENT:
		panel_movement.visible = true
		panel_planning.visible = false
		if panel_repair: panel_repair.visible = false
		if panel_attack_queue: panel_attack_queue.visible = false

		_update_movement_ui_list()
		
		# Execute Button: Always visible for active side during movement
		var is_my_movement = (my_side_id == current_side_id) or (my_side_id == 0)
		if btn_exec_move:
			btn_exec_move.visible = is_my_movement
		
		# Default State: HIDE ship controls
		btn_undo.visible = false
		btn_commit.visible = false
		btn_orbit_cw.visible = false
		btn_orbit_ccw.visible = false
		btn_ms_toggle.visible = false
		if btn_dock: btn_dock.visible = false
		if btn_rearm: btn_rearm.visible = false
		if btn_withdraw: btn_withdraw.visible = false
		if btn_drop_mine: btn_drop_mine.visible = false
		if btn_drop_seeker: btn_drop_seeker.visible = false
		if opt_active_screen: opt_active_screen.visible = false
		
		# Turn Restriction: If not my turn, stop here (hide controls)
		# Exception: Server/Offline always sees controls if needed (debug/hotseat)
		if not is_my_movement and not _has_admin_authority():
			return

		if selected_ship:
			# Undo available if plotting path exists OR if ship has orders (to reset)
			# NOT if has_moved (Executed)
			var can_undo = (current_path.size() > 0) or (selected_ship.has_orders)
			btn_undo.visible = can_undo
			
			var steps = current_path.size()
			var eff_adf = selected_ship.get_effective_adf()
			var min_speed = max(0, start_speed - eff_adf)
			var max_speed = start_speed + eff_adf
			var is_valid = (steps >= min_speed and steps <= max_speed)
			
			if state_is_orbiting:
				# Orbit moves are always 1 hex, regardless of ADF/Speed limits
				is_valid = true
				
			var is_locked = selected_ship.has_moved or selected_ship.has_orders
			btn_commit.visible = true
			# Disable if invalid path OR already locked (Orders/Moved)
			# Note: We can re-commit if we Undo first.
			btn_commit.disabled = not is_valid or is_locked
			
			if btn_drop_mine and selected_ship.ship_class == "Minelayer":
				var has_mines = false
				for w in selected_ship.weapons:
					if w["type"] == "Mine" and w["ammo"] > 0:
						has_mines = true
						break
				btn_drop_mine.visible = has_mines
				# Note: Button is always enabled, meaning you can drop mines even after moving.
				# The name is static "Drop Mine"
				
			if btn_drop_seeker:
				var has_seekers = false
				for w in selected_ship.weapons:
					if w["type"] == "Seeker" and w["ammo"] > 0:
						has_seekers = true
						break
				btn_drop_seeker.visible = has_seekers
			
			var is_stationary = (current_path.size() == 0 and start_speed == 0)

			
			# Orbit Check
			var can_orbit = false
			# Must be start of move (stationary)
			if is_stationary:
				for p in planet_hexes:
					if HexGrid.hex_distance(selected_ship.grid_position, p) == 1:
						can_orbit = true
						break
			
			btn_orbit_cw.visible = can_orbit
			btn_orbit_ccw.visible = can_orbit
			
			# Docking UI Check
			if selected_ship.is_docked:
				btn_dock.visible = true
				btn_dock.text = "Undock"
				
				if selected_ship.ship_class in ["Fighter", "Assault Scout"]:
					var can_rearm = selected_ship.turns_docked_since_action >= 1 and selected_ship.rearm_count < 2
					btn_rearm.visible = can_rearm
					if can_rearm:
						btn_rearm.disabled = false
						btn_rearm.tooltip_text = "Restores Assault Rockets"
			else:
				if is_stationary:
					var can_dock = false
					for s in ships:
						if selected_ship.can_dock_with(s):
							can_dock = true
							break
					if can_dock:
						btn_dock.visible = true
						btn_dock.text = "Dock"
			
			# Withdrawal Check
			if btn_withdraw:
				if is_stationary and not is_locked:
					var can_w = _can_withdraw(selected_ship)
					btn_withdraw.visible = can_w
			
			# MS Toggle Check
			# Visible if ship has Max MS > 0
			if selected_ship.ms_max > 0:
				btn_ms_toggle.visible = true
				btn_ms_toggle.set_pressed_no_signal(selected_ship.is_ms_active)
				btn_ms_toggle.text = "Deploy Screen (%d)" % selected_ship.ms_current
				
				# Constraint Check: Maintain Speed and Heading
				# Logic:
				# 1. Calculate validity of current plot for MS (Speed == Start Speed AND Heading == Start Heading)
				#    BUT: Orbit works differently (always valid if orbiting)
				
				var ms_valid_move = false
				if state_is_orbiting:
					ms_valid_move = true
				else:
					var speed_ok = false
					if selected_ship.is_ms_active:
						# Relaxed Persistence Check:
						# Valid if Path <= Start Speed (Partial) AND Heading Matches
						# We only INVALIDATE if Path > Start Speed or Heading Mismatch
						speed_ok = (current_path.size() <= start_speed)
					else:
						# must EXACTLY match to activate fresh
						speed_ok = (current_path.size() == start_speed)
						
					var heading_ok = false
					if ghost_ship:
						heading_ok = (ghost_ship.facing == selected_ship.facing)
					ms_valid_move = (speed_ok and heading_ok)
				
				if selected_ship.is_ms_active:
					# If already active, check if we need to DROP it
					if not ms_valid_move:
						_on_ms_toggled(false) # Auto-drop
						log_message("Maneuver Dropped Screen")
				else:
					# If not active, can we Activate it?
					btn_ms_toggle.disabled = not ms_valid_move
					if not ms_valid_move:
						btn_ms_toggle.tooltip_text = "Requires straight-line movement matching current speed."
					else:
						btn_ms_toggle.tooltip_text = ""
						
			# Regular Energy Screen Check
			if selected_ship.equipped_screens.size() > 0:
				opt_active_screen.visible = true
				var current_sel = "None"
				if selected_ship.active_screen:
					current_sel = selected_ship.active_screen
				
				# Re-populate options safely without disrupting selection unless required
				var options = ["None"]
				for screen in selected_ship.equipped_screens:
					options.append(screen)
				
				# Update dropdown ONLY if items changed or empty to prevent signal looping
				if opt_active_screen.item_count != options.size():
					opt_active_screen.clear()
					for screen in options:
						opt_active_screen.add_item(screen)
						
				# Set selected state
				for i in range(opt_active_screen.item_count):
					if opt_active_screen.get_item_text(i) == current_sel:
						opt_active_screen.select(i)
						break
				
				# Can only change screens during movement planning (unless locked)
				# Rule: "Players select any defense screens they wish to deploy during movement planning."
				# MS disables Energy Screens? The RULES say: "Note that ships cannot combine masking screens with energy screens."
				if selected_ship.is_ms_active:
					opt_active_screen.disabled = true
					# Auto-drop energy screen if MS is active
					if selected_ship.active_screen != "None":
						selected_ship.active_screen = "None"
						opt_active_screen.select(0)
				else:
					opt_active_screen.disabled = is_locked
			else:
				opt_active_screen.visible = false
						
	elif current_phase == Phase.COMBAT:
		panel_movement.visible = false
		if panel_repair: panel_repair.visible = false
		
		btn_undo.visible = false
		btn_commit.visible = false
		btn_orbit_cw.visible = false
		btn_orbit_ccw.visible = false
		
		var phase_name = "Passive" if combat_subphase == 1 else "Active"
		var txt = "Combat (%s Fire)\n%s Firing" % [phase_name, get_side_name(firing_side_id)]
		
		# Ship details are in ShipStatusPanel. 
		# But Hit Chance logic/Target info might be useful here or in Panel?
		# Target info is specific to the selected ship's action.
		
		if selected_ship:
			# Keep Target Info here as it's transient
			if combat_target:
				txt += "\nTarget: %s" % combat_target.get_display_name()
				# Show Hit Chance
				if selected_ship and selected_ship.weapons.size() > 0:
					var w = selected_ship.weapons[selected_ship.current_weapon_index]
					var chance = 0
					if combat_subphase == 1 and combat_target.side_id == current_side_id:
						var best_hex_info = Combat.get_best_defensive_fire_hex(selected_ship, combat_target, w, 0)
						chance = best_hex_info["chance"]
					else:
						# Calc Hit Chance standard
						var dist = HexGrid.hex_distance(selected_ship.grid_position, combat_target.grid_position)
						var is_head_on = false
						if w.get("arc") == "FF":
							if combat_target.grid_position == selected_ship.grid_position:
								is_head_on = true
							else:
								var fwd_vec = HexGrid.get_direction_vec(selected_ship.facing)
								var check = selected_ship.grid_position + fwd_vec
								for i in range(w.get("range", 0)):
									if check == combat_target.grid_position:
										is_head_on = true
										break
									check += fwd_vec
						chance = Combat.calculate_hit_chance(dist, w, combat_target, is_head_on, 0, selected_ship)
						
					txt += "\nHit Chance: %d%%" % chance
		
		# SUMMARY OF PLANNED ATTACKS (Left Side) - Now handled by panel_attack_queue
		_update_attack_queue_ui()
		
		# Ensure planning panel visibility is managed here
		if current_combat_state == CombatState.PLANNING:
			var is_my_planning_phase = (firing_side_id == my_side_id) or (my_side_id == 0)
			panel_planning.visible = is_my_planning_phase
			if is_my_planning_phase:
				call_deferred("_update_minimap_position")
				# Fix for disappearing list on input events (Q, clicks) that call _update_ui_state
				_update_planning_ui_list()
		else:
			panel_planning.visible = false
				
		label_status.text = txt
	elif current_phase == Phase.REPAIR:
		var is_my_repair_phase = (repair_subphase == my_side_id) or (my_side_id == 0)
		panel_movement.visible = is_my_repair_phase
		if is_my_repair_phase:
			_update_repair_ui_list()
			
		panel_planning.visible = false
		panel_attack_queue.visible = false
		if panel_repair:
			panel_repair.visible = is_my_repair_phase
			if is_my_repair_phase:
				panel_repair.move_to_front()
		else:
			print("[DEBUG] ERROR: panel_repair is null in _update_ui_state during Phase.REPAIR")
		btn_undo.visible = false
		btn_commit.visible = false
		btn_orbit_cw.visible = false
		btn_orbit_ccw.visible = false
		
		var side_n = get_side_name(repair_subphase)
		if repair_subphase == 3:
			label_status.text = "Repair Phase (Executing...)"
			if btn_repair_exec: btn_repair_exec.visible = false
		else:
			label_status.text = "Repair Phase (%s Allocating)" % side_n
			if btn_repair_exec:
				btn_repair_exec.visible = (repair_subphase == my_side_id or (my_side_id == 0))
				btn_repair_exec.disabled = false
	elif current_phase == Phase.END:
		panel_movement.visible = false
		panel_planning.visible = false
		if panel_repair:
			panel_repair.visible = false
		
		btn_undo.visible = false
		btn_commit.visible = false
		btn_orbit_cw.visible = false
		label_status.text = "Game Over"

	# Update Player Info Label
	if label_player_info:
		var p_txt = "Side: %d (%s)" % [my_side_id, get_side_name(my_side_id)]
		var pid = 1
		if _is_networked():
			pid = (multiplayer.get_unique_id() if _is_networked() else 1)
			
		label_player_info.text = "%s\nPID: %d" % [p_txt, pid]
		
		# Color
		if my_side_id == 1: label_player_info.modulate = Color(1, 0.5, 0.5) # Red-ish
		elif my_side_id == 2: label_player_info.modulate = Color(0.5, 0.5, 1) # Blue-ish
		else: label_player_info.modulate = Color.GREEN

func _on_undo():
	if not selected_ship: return
	
	# Case 1: Committed Move (Needs RPC / Full Reset)
	if selected_ship.has_moved:
		log_message("Requesting Undo for Committed Move...")
		if _is_networked():
			rpc_undo_move.rpc_id(1, selected_ship.name)
		else:
			rpc_undo_move(selected_ship.name)
		return
		
	# Case 2: Planned Orders (Has Orders but not Moved)
	if selected_ship.has_orders:
		selected_ship.has_orders = false
		selected_ship.planned_path.clear()
		_update_movement_ui_list()
		log_message("Orders cleared for %s" % selected_ship.name)
		# Fallthrough to local reset to ensure UI is clean
		
	# Case 3: Plotting Phase (Local Reset)
	log_message("Resetting Plot...")
	_reset_plotting_state()
	_spawn_ghost()
	_update_ui_state()
	queue_redraw()

@rpc("any_peer", "call_local", "reliable")
func rpc_undo_move(ship_name: String):
	var s_obj = _find_ship_by_name(ship_name)
	if not s_obj: return
	
	# Security: Check Ownership
	var sender = 1
	if _is_networked():
		sender = multiplayer.get_remote_sender_id()
		if sender == 0: sender = (multiplayer.get_unique_id() if _is_networked() else 1)
		
	if not _validate_rpc_ownership(sender, s_obj.side_id):
		return

	log_message("Undoing Move for %s" % s_obj.name)
	
	if not s_obj.turn_start_state.is_empty():
		var state = s_obj.turn_start_state
		s_obj.grid_position = state["grid_position"]
		s_obj.facing = state["facing"]
		s_obj.speed = state["speed"]
		s_obj.is_ms_active = state["is_ms_active"]
		s_obj.ms_orbit_start_hex = state["ms_orbit_start_hex"]
		s_obj.has_moved = false
		s_obj.previous_path.clear()
		
		# Recursively reset docked guests
		if s_obj.docked_guests.size() > 0:
			for guest in s_obj.docked_guests:
				guest.grid_position = s_obj.grid_position
				guest.facing = s_obj.facing
				guest.queue_redraw()
	else:
		log_message("[Error] No turn start state found for undo!")

	# If this is the selected ship on this client, reset UI
	if selected_ship == s_obj:
		_reset_plotting_state()
		_spawn_ghost()
		_update_ui_state()
		queue_redraw()
	else:
		# Remote update
		s_obj.queue_redraw()


var state_is_orbiting: bool = false # Temp state for UI

func _on_orbit(direction: int):
	# Authority Check (Allow Server to override for Auto-Orbit visualization)
	if my_side_id > 0 and current_side_id != my_side_id:
		# If Server, we allow it (for auto-resolution visualization)
		if not _is_server_or_offline():
			print("[DEBUG] _on_orbit REJECTED: Not my turn (Me: %d, Cur: %d)" % [my_side_id, current_side_id])
			return
		
	# direction: 1 (CW), -1 (CCW)
	if not selected_ship: return
	
	# Find adjacent planet
	var planet_hex = Vector3i.ZERO # Default
	var found = false
	for p in planet_hexes:
		if HexGrid.hex_distance(selected_ship.grid_position, p) == 1:
			planet_hex = p
			found = true
			break
	
	if not found:
		print("[DEBUG] _on_orbit: No planet found adjacent to %s at %s" % [selected_ship.name, selected_ship.grid_position])
		state_is_orbiting = false
		return
	
	# Calculate move
	var neighbors = HexGrid.get_neighbors(planet_hex)
	var my_idx = neighbors.find(selected_ship.grid_position)
	
	if my_idx == -1:
		print("[DEBUG] _on_orbit: Ship position not in neighbors list (Geometry Error)")
		return # Should not happen if distance is 1
	
	# HexGrid.directions are ordered East, SE, SW, W, NW, NE (Clockwise!)
	# So if we find our index, +1 is CW, -1 is CCW.
	var next_idx = posmod(my_idx + direction, 6)
	var target_hex = neighbors[next_idx]
	
	# User says: "Each movement phase an orbiting ship moves 1 hex..."
	
	# Reset ghost
	_spawn_ghost()
	if not ghost_ship:
		print("[DEBUG] _on_orbit: Failed to spawn ghost ship. Aborting orbit plot.")
		state_is_orbiting = false
		return
		
	ghost_ship.grid_position = target_hex
	current_path = [target_hex]
	
	# "A ship in orbit can rotate to any facing"
	can_turn_this_step = true # Enable turning
	turns_remaining = 999 # Effective infinite
	state_is_orbiting = true
	current_orbit_direction = direction
	
	_update_camera()
	_update_ui_state()

var current_orbit_direction: int = 0

func _on_active_screen_selected(index: int):
	# Authority check: Only player who owns the ship can change this
	if current_phase != Phase.MOVEMENT or (my_side_id != current_side_id and my_side_id != 0): return
	if not selected_ship or selected_ship.has_moved or selected_ship.has_orders: return
	
	var text = opt_active_screen.get_item_text(index)
	selected_ship.active_screen = text
	
	if _is_networked() and not _is_server_or_offline():
		rpc_update_screen_state.rpc_id(1, selected_ship.name, text)
	elif _is_server_or_offline():
		rpc_update_screen_state(selected_ship.name, text)
	
	log_message("%s set Active Screen: %s" % [selected_ship.name, text])
	
@rpc("any_peer", "call_local", "reliable")
func rpc_update_screen_state(ship_name: String, screen_type: String):
	if _is_networked() and multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		var player_side = 0
		if NetworkManager and NetworkManager.lobby_data.has("teams") and NetworkManager.lobby_data["teams"].has(sender_id):
			player_side = NetworkManager.lobby_data["teams"][sender_id]
			
		var s = _find_ship_by_name(ship_name)
		if s and s.side_id == player_side:
			s.active_screen = screen_type
			rpc_sync_screen_state.rpc(ship_name, screen_type)
	elif not _is_networked():
		# Hotseat
		var s = _find_ship_by_name(ship_name)
		if s: s.active_screen = screen_type

@rpc("authority", "call_local", "reliable")
func rpc_sync_screen_state(ship_name: String, screen_type: String):
	var s = _find_ship_by_name(ship_name)
	if s: s.active_screen = screen_type

func _on_ms_toggled(pressed: bool):
	# Authority Check
	if my_side_id > 0 and current_side_id != my_side_id:
		return
		
	if not selected_ship: return
	
	if pressed:
		# Activate
		if start_ms_active:
			# Was already active, just restoring maintenance (Cost 0)
			selected_ship.is_ms_active = true
		else:
			# New Activation (Cost 1)
			if selected_ship.ms_current > 0:
				selected_ship.is_ms_active = true
				selected_ship.ms_current -= 1
				# Orbit Exception: Capture start
				if state_is_orbiting:
					selected_ship.ms_orbit_start_hex = selected_ship.grid_position
				else:
					selected_ship.ms_orbit_start_hex = Vector3i.MAX
					
				log_message("Masking Screen Deployed")
			else:
				# Failed
				btn_ms_toggle.set_pressed_no_signal(false)
				log_message("No Charges for Screen")
	else:
		# Deactivate
		selected_ship.is_ms_active = false
		if not start_ms_active:
			# Refund if it was a new activation this turn
			selected_ship.ms_current += 1
			log_message("Screen Deployment Cancelled")
		else:
			log_message("Screen Dropped")
			
	selected_ship.queue_redraw()
	selected_ship.queue_redraw()
	_update_ui_state()

func _update_movement_ui_list():
	for c in list_movement.get_children():
		c.queue_free()
		
	# Find ships for active side
	var my_ships = []
	if current_side_id > 0:
		my_ships = ships.filter(func(s): return is_instance_valid(s) and s.side_id == current_side_id and not s.is_exploding)
	
	for s in my_ships:
		var btn = Button.new()
		var status = "WAITING"
		var color_code = Color.WHITE
		
		# STATUS LOGIC
		if s.has_moved:
			status = "MOVED"
			color_code = Color.CYAN # Done
		elif s.has_orders:
			# Check Danger (Planet Collision)
			var is_dangerous = false
			if s.planned_path.size() > 0:
				for hex in s.planned_path:
					if planet_hexes.has(hex):
						is_dangerous = true
						break
			
			if is_dangerous:
				status = "DANGER"
				color_code = Color.RED
			else:
				status = "PLANNED"
				color_code = Color.GREEN # Ready
		
		# Highlight selected
		if s == selected_ship:
			btn.text = "> %s (%s) <" % [s.name, status]
			btn.modulate = Color.YELLOW
		else:
			btn.text = "%s (%s)" % [s.name, status]
			btn.modulate = color_code
			
		btn.pressed.connect(func():
			if s != selected_ship:
				selected_ship = s
				_reset_plotting_state()
				
				selected_ship = s
				_reset_plotting_state()
				
				# Load Plan VISUALIZATION
				_load_plan_visualization(s)
					
				_update_ui_state()
				_update_ship_visuals()
				_update_camera(selected_ship) # Refocus view on selected ship
				queue_redraw()
		)
		
		list_movement.add_child(btn)
		
	# Find unactivated Seekers for active side
	var is_admin_or_owner = (my_side_id == 0) or (my_side_id == current_side_id)
	if is_admin_or_owner:
		var my_inactive_seekers = active_seekers.filter(func(s): return s["side_id"] == current_side_id and s.get("speed", 0) == 0)
		for seeker in my_inactive_seekers:
			var btn = Button.new()
			btn.text = "Activate Seeker @ %v" % seeker["pos"]
			btn.modulate = Color.ORANGE
			btn.pressed.connect(func():
				_on_activate_seeker_pressed(seeker)
			)
			list_movement.add_child(btn)
	
func execute_commit_move(ship_name: String, path: Array, final_facing: int, orbit_dir: int, is_orbiting: bool):
	# Test Compatibility Wrapper
	# Many tests call this directly to bypass UI/Selection state.
	# We map it to the new register_movement_plan logic.
	var typed_path: Array[Vector3i] = []
	typed_path.assign(path)
	register_movement_plan(ship_name, typed_path, final_facing, orbit_dir, is_orbiting)
	
func _on_activate_seeker_pressed(seeker: Dictionary):
	# Confirm the activation and process immediately since it doesn't need to wait for execute step, or we can queue it?
	# We'll immediately process it like turning a shield on.
	if _is_networked():
		rpc_activate_seeker.rpc(seeker["pos"])
	else:
		rpc_activate_seeker(seeker["pos"])
		
@rpc("any_peer", "call_local", "reliable")
func rpc_activate_seeker(pos: Vector3i):
	# Make the seeker active by setting speed to 2
	for s in active_seekers:
		if s["pos"] == pos and s.get("speed", 0) == 0:
			s["speed"] = 2
			log_message("Seeker at %v ACTIVATED." % pos)
			break
	_update_movement_ui_list()
	queue_redraw()

func _on_dock_pressed():
	if not selected_ship: return
	if selected_ship.is_docked:
		selected_ship.undock()
		log_message("%s undocked." % selected_ship.get_display_name())
	else:
		for s in ships:
			if selected_ship.dock_at(s):
				if audio_action_complete: audio_action_complete.play()
				log_message("%s docked at %s." % [selected_ship.get_display_name(), s.get_display_name()])
				break
	_update_ui_state()
	queue_redraw()

func _on_rearm_pressed():
	if not selected_ship: return
	if selected_ship.rearm_assault_rockets():
		if audio_action_complete: audio_action_complete.play()
		log_message("%s rearmed Assault Rockets (Used %d/2)." % [selected_ship.get_display_name(), selected_ship.rearm_count])
		btn_rearm.visible = false 
		if ship_status_panel: ship_status_panel.update_from_ship(selected_ship)

func _on_drop_mine_pressed():
	if not selected_ship or selected_ship.ship_class != "Minelayer": return
	state_mine_placement = not state_mine_placement # Toggle placement mode
	if state_mine_placement:
		log_message("Mine placement mode ON. Click valid path hexes to drop.")
	else:
		log_message("Mine placement mode OFF.")
	queue_redraw()

func _on_drop_seeker_pressed():
	if not selected_ship: return
	state_seeker_placement = not state_seeker_placement # Toggle placement mode
	if state_seeker_placement:
		log_message("Seeker placement mode ON. Click valid path hexes to drop.")
	else:
		log_message("Seeker placement mode OFF.")
	queue_redraw()

func _on_commit_move():
	# Authority Check
	if my_side_id != 0 and current_side_id != my_side_id:
		log_message("Not your turn! (Active: %d, You: %d)" % [current_side_id, my_side_id])
		return
		
	# NETWORK: Send RPC
	# We need to send: Ship Name (Unique ID), Path, Facing, Orbit Dir
	
	var path_data = current_path # Array[Vector3i]
	
	print("DEBUG: _on_commit_move for ", selected_ship.name)
	print("DEBUG: Path size: ", path_data.size())
	
	if _is_networked() and not _is_server_or_offline():
		rpc("register_movement_plan", selected_ship.name, path_data.duplicate(), ghost_ship.facing, current_orbit_direction, state_is_orbiting, selected_ship.planned_mines_to_drop.duplicate(), selected_ship.planned_seekers_to_drop.duplicate())
	else:
		print("DEBUG: Calling register_movement_plan locally")
		register_movement_plan(selected_ship.name, path_data.duplicate(), ghost_ship.facing, current_orbit_direction, state_is_orbiting, selected_ship.planned_mines_to_drop.duplicate(), selected_ship.planned_seekers_to_drop.duplicate())

# --- Security Validation ---
func _validate_rpc_ownership(sender_id: int, required_side_id: int) -> bool:
	# 1. Host (ID 1) always has authority (e.g. for AI or admin actions)
	if sender_id == 1:
		return true
		
	# 2. Map Sender ID to Side ID
	# NetworkManager.lobby_data["teams"] = { peer_id: side_id }
	var sender_side = 0
	if NetworkManager.lobby_data != null and NetworkManager.lobby_data.has("teams"):
		sender_side = NetworkManager.lobby_data["teams"].get(sender_id, 0)
	
	if sender_side == required_side_id:
		return true
		
	print("[Security] Validation Failed: Sender %d (Side %d) tried to control Side %d" % [sender_id, sender_side, required_side_id])
	return false

func _validate_move_path(ship: Ship, path: Array[Vector3i], _final_facing: int, is_orbiting: bool = false) -> bool:
	var start_pos = ship.grid_position
	var current_pos = start_pos
	
	# 1. Path Continuity / Speed / Adjacency
	for hex in path:
		if HexGrid.hex_distance(current_pos, hex) != 1:
			print("[Security] Teleport attempt! %s -> %s (Dist %d)" % [current_pos, hex, HexGrid.hex_distance(current_pos, hex)])
			return false
		current_pos = hex
		
	# 2. Speed / ADF Check
	# Rule: In this game, your SPEED is the number of hexes moved this turn.
	# You can change your speed by up to ADF (Acceleration/Deceleration Factor).
	# So new_speed (path.size()) must be within [old_speed - adf, old_speed + adf].
	
	# EXCEPTION: Orbiting
	if is_orbiting:
		# Orbit moves are always length 1.
		# If we are orbiting, we ignore ADF limits for the "Maintain Orbit" move.
		if path.size() != 1:
			print("[Security] Invalid Orbit Speed! Expected 1, got %d" % path.size())
			return false
		return true

	var old_speed = ship.speed
	# FIX: If docked, effective start speed is 0, regardless of what the ship memory says (bug resilience)
	if ship.is_docked:
		old_speed = 0
		
	var new_speed = path.size()
	var eff_adf = ship.get_effective_adf()
	var min_speed = max(0, old_speed - eff_adf)
	var max_speed = old_speed + eff_adf
	
	if new_speed < min_speed:
		print("[Security] Illegal Deceleration! Speed %d -> %d (Min %d, ADF %d)" % [old_speed, new_speed, min_speed, eff_adf])
		return false
		
	if new_speed > max_speed:
		print("[Security] Illegal Acceleration! Speed %d -> %d (Max %d, ADF %d)" % [old_speed, new_speed, max_speed, eff_adf])
		return false
		
	return true

@rpc("any_peer", "call_local", "reliable")
func register_movement_plan(ship_name: String, path: Array, final_facing: int, orbit_dir: int, is_orbiting: bool, planned_mines: Array = [], planned_seekers: Array = []):
	var ship: Ship = null
	for s in ships:
		if is_instance_valid(s) and s.name == ship_name:
			ship = s
			break
			
	if not ship: return
	
	# SECURITY CHECK
	var sender_id = 1
	if _is_networked():
		sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = (multiplayer.get_unique_id() if _is_networked() else 1) # Handle local call
	
	if not _validate_rpc_ownership(sender_id, ship.side_id):
		return
		
	# Destruct Guard
	if ship.is_destroyed:
		return

	# LOGIC VALIDATION (Anti-Cheat)
	var typed_path: Array[Vector3i] = []
	for p in path:
		typed_path.append(Vector3i(p))
	
	if not _validate_move_path(ship, typed_path, final_facing, is_orbiting):
		log_message("[Security] Move rejected: Invalid Path/Speed for %s" % ship.name)
		return

	log_message("Orders Received for %s" % ship.name)
	
	# Store the Plan
	ship.planned_path = typed_path
	ship.planned_facing = final_facing
	ship.planned_orbit_dir = orbit_dir
	ship.has_orders = true
	
	var typed_mines: Array[Vector3i] = []
	for hex in planned_mines:
		typed_mines.append(Vector3i(hex))
	ship.planned_mines_to_drop = typed_mines
	
	var typed_seekers: Array[Vector3i] = []
	for hex in planned_seekers:
		typed_seekers.append(Vector3i(hex))
	ship.planned_seekers_to_drop = typed_seekers
	
	# Auto-undock on plot
	if ship.is_docked and typed_path.size() > 0:
		ship.undock()
		log_message("%s auto-undocked for maneuver." % ship.get_display_name())
	
	# Logic from original commitment: Update local state if selected
	if selected_ship == ship:
		_reset_plotting_state()
		_update_ui_state()
		
	# SERVER BROADCAST: Ensure all OTHER clients get this plan
	if _is_networked() and multiplayer.is_server():
		# Use duplicate() to prevent end-of-frame execution clearing from emptying the network packet payload!
		rpc_sync_movement_plan.rpc(ship_name, typed_path.duplicate(), final_facing, orbit_dir, is_orbiting, planned_mines.duplicate(), planned_seekers.duplicate())

	# Update List UI
	_update_movement_ui_list()
	ship.queue_redraw()
	queue_redraw() # Trigger map redraw to show new lines

@rpc("authority", "call_remote", "reliable")
func rpc_sync_movement_plan(ship_name: String, path: Array, final_facing: int, orbit_dir: int, is_orbiting: bool, planned_mines: Array = [], planned_seekers: Array = []):
	var ship = _find_ship_by_name(ship_name)
	if not ship: return
	
	var typed_path: Array[Vector3i] = []
	for p in path:
		typed_path.append(Vector3i(p))
	ship.planned_path.assign(typed_path)
	ship.planned_facing = final_facing
	ship.planned_orbit_dir = orbit_dir
	ship.has_orders = true
	
	var typed_mines: Array[Vector3i] = []
	for hex in planned_mines:
		typed_mines.append(Vector3i(hex))
	ship.planned_mines_to_drop = typed_mines
	
	var typed_seekers: Array[Vector3i] = []
	for hex in planned_seekers:
		typed_seekers.append(Vector3i(hex))
	ship.planned_seekers_to_drop = typed_seekers
	
	log_message("Synced Orders for %s" % ship.name)
	
	# Update Visuals
	_update_movement_ui_list()
	ship.queue_redraw()
	queue_redraw()


func _load_plan_visualization(s: Ship):
	if s.has_orders:
		current_path = s.planned_path.duplicate()
		# Re-create ghost for visualization
		_spawn_ghost()
		if is_instance_valid(ghost_ship):
			if s.planned_path.size() > 0:
				ghost_ship.grid_position = s.planned_path.back()
				ghost_ship.facing = s.planned_facing
	else:
		_spawn_ghost()


func _can_withdraw(ship: Ship) -> bool:
	if not ship: return false
	
	# Only allow retreat in Campaign Encounters for now.
	# Or globally if desired, but rules state Campaign specific.
	# Actually, players might want to retreat from standard scenarios too if outside range?
	# Let's check scenario. "campaign_encounter" is the primary one.
	var scen_key = ""
	if NetworkManager.lobby_data != null:
		scen_key = NetworkManager.lobby_data.get("scenario", "")
	if scen_key != "campaign_encounter": 
		print("DEBUG _can_withdraw: rejected bad scen_key: ", scen_key)
		return false
	# Cannot withdraw if they have moved this turn yet (must be starting stationary? "movement planning")
	# If they have plotted a path, the button is hidden above anyway since is_stationary = false.
	
	if ship.is_militia and not ship.has_ever_fired:
		print("DEBUG _can_withdraw: rejected militia that hasn't fired")
		return false # Militia must attack at least once before fleeing

	# Check range to all living enemies
	for enemy in ships:
		if is_instance_valid(enemy) and enemy.side_id != ship.side_id and not enemy.is_destroyed and not enemy.has_withdrawn:
			# Check all enemy weapons
			for w in enemy.weapons:
				if w.get("ammo", 0) > 0 and not w.get("is_crippled", false):
					var dist = HexGrid.hex_distance(ship.grid_position, enemy.grid_position)
					if dist <= w.get("range", 0):
						print("DEBUG _can_withdraw: rejected enemy in range. Dist: ", dist, " Range: ", w.get("range", 0))
						return false # An enemy is in range

	print("DEBUG _can_withdraw: Success!")
	return true

func _on_withdraw_pressed():
	if not is_instance_valid(selected_ship): return
	
	log_message("[color=orange]%s is withdrawing from combat![/color]" % selected_ship.name)
	
	if _is_networked():
		rpc_execute_withdraw.rpc_id(1, selected_ship.name)
	else:
		rpc_execute_withdraw(selected_ship.name)

@rpc("any_peer", "call_local", "reliable")
func rpc_execute_withdraw(ship_name: String):
	# Authority check
	var sender = 1
	if _is_networked():
		sender = multiplayer.get_remote_sender_id()
		if sender == 0: sender = (multiplayer.get_unique_id() if _is_networked() else 1)
	
	var ship = _find_ship_by_name(ship_name)
	if not ship: return
	
	if not _validate_rpc_ownership(sender, ship.side_id):
		return
		
	# Broadcast withdrawal
	if _is_networked():
		rpc_sync_withdraw.rpc(ship_name)
	else:
		rpc_sync_withdraw(ship_name)

@rpc("authority", "call_local", "reliable")
func rpc_sync_withdraw(ship_name: String):
	var ship = _find_ship_by_name(ship_name)
	if not ship: return
	
	if not ship.has_withdrawn:
		ship.has_withdrawn = true
		ship.is_destroyed = true # To trigger logic skipping elsewhere
		log_message("[color=orange]%s has withdrawn and left the tactical area.[/color]" % ship.name)
		ship.visible = false
		_update_movement_ui_list()
		# Needs to be sent back as an event to Campaign? 
		# We'll handle this at battle-end by checking has_withdrawn or surviving ships.
		_check_victory() # Maybe the last ship withdrew?

func _on_exec_move_pressed():
	# Authority Check
	if my_side_id != 0 and my_side_id != current_side_id:
		return
		
	# Auto-Commit pending plot if valid
	if is_instance_valid(selected_ship) and not selected_ship.has_moved and not selected_ship.has_orders:
		var has_user_plot = current_path.size() > 0 or ghost_head_facing != selected_ship.facing or current_orbit_direction != selected_ship.orbit_direction
		if has_user_plot and is_instance_valid(btn_commit) and not btn_commit.disabled and btn_commit.visible:
			log_message("Auto-committing plotted movement for %s..." % selected_ship.name)
			_on_commit_move()
			
	if _is_networked():
		rpc_id(1, "request_execute_movement")
	else:
		execute_all_movement()

@rpc("any_peer", "call_local", "reliable")
func request_execute_movement():
	# Security: Only Active Side can request end
	var sender_id = 1
	if _is_networked():
		sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0: sender_id = (multiplayer.get_unique_id() if _is_networked() else 1)
		
	if not _validate_rpc_ownership(sender_id, current_side_id):
		return
		
	# Call Authority Method and Broadcast
	if _is_networked():
		execute_all_movement.rpc()
	else:
		execute_all_movement()

@rpc("authority", "call_local", "reliable")
func execute_all_movement():
	var peer_id = (multiplayer.get_unique_id() if _is_networked() else 1) if _is_networked() else "Offline"
	print(">>> DIAGNOSTIC: execute_all_movement running for side: ", current_side_id, " on peer: ", peer_id)
	log_message("Executing Movement Phase for Side %s" % _get_side_name(current_side_id))
	
	for s in ships:
		if is_instance_valid(s) and s.side_id == current_side_id and not s.is_destroyed:
			log_message("[color=yellow]EXECUTE LOOP: Checking Ship %s (Class: %s, Mines: %d)[/color]" % [s.name, s.ship_class, s.planned_mines_to_drop.size()])
			# If a ship did not receive orders (player pressed Execute Movement without plotting)
			if not s.has_orders:
				var current_speed = s.speed
				var auto_path: Array[Vector3i] = []
				var current_hex = s.grid_position
				var dir_vec = HexGrid.get_direction_vec(s.facing)
				
				# If the ship is not given orders, it MUST maintain its current speed straight forward
				for i in range(current_speed):
					current_hex += dir_vec
					auto_path.append(current_hex)
					
				s.planned_path = auto_path
				s.planned_facing = s.facing
				s.planned_orbit_dir = s.orbit_direction # Preserve orbit!
				s.has_orders = true
				
			# Apply Plan
			_apply_movement_plan(s)
			
			# Process planned mine drops
			if s.ship_class == "Minelayer" and s.planned_mines_to_drop.size() > 0:
				var drop_hexes = s.planned_mines_to_drop.duplicate()
				s.planned_mines_to_drop.clear()
				var w_mine = null
				for w in s.weapons:
					if w["type"] == "Mine": w_mine = w; break
				if w_mine:
					for hex in drop_hexes:
						if w_mine["ammo"] > 0:
							active_mines.append({
								"pos": Vector3i(hex),
								"side_id": int(s.side_id), # Enforce explicit int for network consistency evaluation
								"owner_name": s.name
							})
							w_mine["ammo"] -= 1
							log_message("%s laid a spatial mine at %v." % [s.name, hex])
							
			# Process planned seeker drops
			if s.planned_seekers_to_drop.size() > 0:
				var drop_hexes = s.planned_seekers_to_drop.duplicate()
				s.planned_seekers_to_drop.clear()
				var w_seeker = null
				for w in s.weapons:
					if w["type"] == "Seeker": w_seeker = w; break
				if w_seeker:
					for hex in drop_hexes:
						if w_seeker["ammo"] > 0:
							active_seekers.append({
								"pos": Vector3i(hex),
								"side_id": int(s.side_id),
								"owner_name": s.name,
								"speed": 0
							})
							w_seeker["ammo"] -= 1
							log_message("%s deployed a seeker at %v." % [s.name, hex])
			
	_reset_plotting_state()
	_update_ui_state()
	_update_movement_ui_list()
	
	# Wait for any mine detonations before starting combat
	await _resolve_mine_detonations()
	
	# Wait for any seeker movement and detonations before starting combat
	await _resolve_seeker_movement_and_detonations()
	
	# Phase Transition Logic
	# Rule: Movement -> Combat (Passive) -> Combat (Active) -> Next Side
	log_message("Movement Phase Complete for Side %d. Starting Combat." % current_side_id)
	start_combat_passive()

func _resolve_mine_detonations():
	var detonated_indices = []
	
	var peer_id = (multiplayer.get_unique_id() if _is_networked() else 1) if _is_networked() else "Offline"
	print(">>> DIAGNOSTIC: Entering Mine Detonations. Active Mines: ", active_mines.size(), " on peer: ", peer_id)
	log_message("[color=cyan]!!! DEBUG !!! Entering Mine Detonations. Active Mines: %d[/color]" % active_mines.size())
	for m in active_mines:
		log_message("[color=cyan]  Mine at %v (Side %d)[/color]" % [m["pos"], m["side_id"]])
		
	for i in range(active_mines.size()):
		var m = active_mines[i]
		# Check all ships on the board
		var hit_ships = []
		for s in ships:
			if is_instance_valid(s) and not s.is_destroyed and s.side_id != int(m["side_id"]): # Only triggers on enemy ships, strict int eval
				# Check if ship's path crossed the mine (or ended on it)
				# A ship's previous_path gets populated during _apply_movement_plan
				log_message("[color=cyan]  Checking ship %s (Side %d) at %v with path %s[/color]" % [s.name, s.side_id, s.grid_position, str(s.previous_path)])
				
				# Explicit type cast verification just in case
				var match_found = (Vector3i(s.grid_position) == Vector3i(m["pos"]))
				for p in s.previous_path:
					if Vector3i(p) == Vector3i(m["pos"]): match_found = true
					
				if match_found:
					hit_ships.append(s)
					log_message("Target %s HIT by mine!" % s.name)
					
		log_message("Mines check complete. Hit ships size: %d" % hit_ships.size())
					
		if hit_ships.size() > 0:
			log_message("MINE DETONATED at %v!" % m["pos"])
			detonated_indices.append(i)
			
			# Construct a fake "Mine" weapon profile
			var mine_weapon = {
				"name": "Mine",
				"type": "Mine",
				"damage_dice": "3d10",
				"damage_bonus": 5,
				"dtm": 0,
				"arc": "360",
				"range": 0
			}
			
			for s in hit_ships:
				# Trigger ICM Defense!
				var eligible_defenders = []
				for ally in ships:
					if is_instance_valid(ally) and ally.side_id == s.side_id and ally.grid_position == s.grid_position and ally.icm_current > 0 and not ally.is_destroyed and not ally.is_docked:
						eligible_defenders.append(ally)
						
				var icm_used = 0
				if eligible_defenders.size() > 0:
					var raw_chance = Combat.calculate_hit_chance(0, mine_weapon, s, false, 0, null)
					print("DEBUG: _trigger_icm_decision called by %d for target %s (Side %d)" % [my_side_id, s.name, s.side_id])
					_trigger_icm_decision("Minefield", "Proximity Mine", "Mine", raw_chance, s, eligible_defenders)
					
					# Instead of await, which drops context on RPCs, we wait for the state flag
					while not _icm_decision_received:
						await get_tree().process_frame
						
					var allocations = _icm_current_allocations
					_icm_decision_received = false # Reset for next
					_icm_current_allocations = {}
					
					for s_name in allocations.keys():
						var amt = allocations[s_name]
						if amt > 0:
							icm_used += amt
							for ally in eligible_defenders:
								if ally.name == s_name:
									ally.icm_current -= amt
									_spawn_icm_fx(ally, HexGrid.hex_to_pixel(ally.grid_position) + Vector2(0, -50)) # Visual flair upwards
									break
									
					if icm_used > 0:
						if _is_networked() and multiplayer.is_server():
							rpc_log_message.rpc("Point defense uses %d ICMs against mine fragment." % icm_used)
						else:
							log_message("Point defense uses %d ICMs against mine fragment." % icm_used)
						await get_tree().create_timer(1.0).timeout
						
				var result = Combat.get_hit_roll_details(0, mine_weapon, s, false, icm_used, null)
				var hit = result["success"]
				var hit_str = "HIT" if hit else "MISS"
				
				var msg1 = "Firing Ship: Spatial Mine, Weapon: Proximity Detonation, Odds: %d%%, Roll: %d, Result: %s" % [result["chance"], result["roll"], hit_str]
				if _is_networked() and multiplayer.is_server():
					rpc_log_message.rpc(msg1)
				else:
					log_message(msg1)
				
				var raw_dmg = 0
				if hit:
					raw_dmg = Combat.roll_damage("3d10+5")
					s.take_hull_damage(raw_dmg)
					var msg2 = "%s took %d damage from spatial mine!" % [s.get_display_name(), raw_dmg]
					if _is_networked() and multiplayer.is_server():
						rpc_log_message.rpc(msg2)
					else:
						log_message(msg2)
				else:
					var msg3 = "Mine exploded harmlessly against %s defenses." % s.get_display_name()
					if _is_networked() and multiplayer.is_server():
						rpc_log_message.rpc(msg3)
					else:
						log_message(msg3)
					
				# Broadcast visual FX for detonation
				if _is_networked() and multiplayer.is_server():
					rpc_play_mine_fx.rpc(m["pos"], s.name, hit, raw_dmg)
				else:
					rpc_play_mine_fx(m["pos"], s.name, hit, raw_dmg)
					
				if not get_tree().root.has_node("GutRunner"):
					await get_tree().create_timer(1.5).timeout
					
	# Clean up detonated mines starting from last to avoid shifting index issues
	detonated_indices.sort()
	detonated_indices.reverse()
	for idx in detonated_indices:
		active_mines.remove_at(idx)

func _resolve_seeker_movement_and_detonations():
	var detonated_indices = []
	var peer_id = (multiplayer.get_unique_id() if _is_networked() else 1) if _is_networked() else "Offline"
	
	log_message("[color=cyan]!!! DEBUG !!! Entering Seeker Movement. Active Seekers: %d[/color]" % active_seekers.size())
	
	for i in range(active_seekers.size()):
		var seeker = active_seekers[i]
		if seeker.get("speed", 0) <= 0:
			continue # Inactive or destroyed
			
		log_message("[color=orange]Seeker at %v activates at speed %d.[/color]" % [seeker["pos"], seeker["speed"]])
		
		# Check max threshold before moving
		if seeker["speed"] > 12:
			log_message("[color=orange]Seeker at %v ran out of fuel and self-destructed.[/color]" % seeker["pos"])
			detonated_indices.append(i)
			if _is_networked() and multiplayer.is_server():
				rpc_play_mine_fx.rpc(seeker["pos"], "", false, 0)
			else:
				rpc_play_mine_fx(seeker["pos"], "", false, 0)
			continue
			
		# Find nearest ship
		var nearest_ship = null
		var min_dist = 9999
		for s in ships:
			if is_instance_valid(s) and not s.is_destroyed and not s.is_docked:
				var dist = HexGrid.hex_distance(seeker["pos"], s.grid_position)
				if dist < min_dist:
					min_dist = dist
					nearest_ship = s
					
		if not nearest_ship:
			continue # No valid targets
			
		# Move towards nearest ship
		var steps_taken = 0
		var current_pos = seeker["pos"]
		var hit_ship = null
		
		while steps_taken < seeker["speed"]:
			# Re-calculate nearest ship if circumstances changed? The rule says "closest ship no matter friend or foe". 
			# We'll just stick to the initially evaluated nearest_ship to avoid oscillation loops unless it's destroyed.
			if not is_instance_valid(nearest_ship) or nearest_ship.is_destroyed:
				break
				
			if current_pos == nearest_ship.grid_position:
				break
				
			var best_next = current_pos
			var best_dist = HexGrid.hex_distance(current_pos, nearest_ship.grid_position)
			
			for dir in range(6):
				var adj = current_pos + HexGrid.get_direction_vec(dir)
				var dist = HexGrid.hex_distance(adj, nearest_ship.grid_position)
				if dist < best_dist:
					best_dist = dist
					best_next = adj
					
			if best_next != current_pos:
				current_pos = best_next
				steps_taken += 1
				
				# Check interception
				for s in ships:
					if is_instance_valid(s) and not s.is_destroyed and not s.is_docked and s.grid_position == current_pos:
						hit_ship = s
						break
				if hit_ship:
					break
			else:
				break
				
		seeker["pos"] = current_pos
		
		# Delay speed increment to apply to next turn phase
		seeker["speed"] += 2
		
		if not hit_ship:
			for s in ships:
				if is_instance_valid(s) and not s.is_destroyed and not s.is_docked and s.grid_position == current_pos:
					hit_ship = s
					break
					
		if hit_ship:
			detonated_indices.append(i)
			log_message("[color=orange]SEEKER INTERCEPT at %v![/color]" % current_pos)
			
			# Identify largest ship in hex
			var hex_ships = []
			for s in ships:
				if is_instance_valid(s) and not s.is_destroyed and not s.is_docked and s.grid_position == current_pos:
					hex_ships.append(s)
			
			var target = hex_ships[0]
			for s in hex_ships:
				if s.hull > target.hull: target = s
				
			var seeker_weapon = {
				"name": "Seeker",
				"type": "Seeker",
				"damage_dice": "5d10",
				"damage_bonus": 0,
				"dtm": -20,
				"arc": "360",
				"range": 0
			}
			
			var eligible_defenders = []
			for ally in ships:
				if is_instance_valid(ally) and ally.side_id == target.side_id and ally.grid_position == target.grid_position and ally.icm_current > 0 and not ally.is_destroyed and not ally.is_docked:
					eligible_defenders.append(ally)
					
			var icm_used = 0
			if eligible_defenders.size() > 0:
				var raw_chance = Combat.calculate_hit_chance(0, seeker_weapon, target, false, 0, null)
				_trigger_icm_decision("Autonomous Seeker", "Seeker Missile", "Seeker", raw_chance, target, eligible_defenders)
				
				while not _icm_decision_received:
					await get_tree().process_frame
					
				var allocations = _icm_current_allocations
				_icm_decision_received = false
				_icm_current_allocations = {}
				
				for s_name in allocations.keys():
					var amt = allocations[s_name]
					if amt > 0:
						icm_used += amt
						for ally in eligible_defenders:
							if ally.name == s_name:
								ally.icm_current -= amt
								_spawn_icm_fx(ally, HexGrid.hex_to_pixel(ally.grid_position) + Vector2(0, -50))
								break
								
				if icm_used > 0:
					var m_icm = "Point defense uses %d ICMs against incoming Seeker." % icm_used
					if _is_networked() and multiplayer.is_server(): rpc_log_message.rpc(m_icm)
					else: log_message(m_icm)
					if get_tree() and not get_tree().root.has_node("GutRunner"):
						await get_tree().create_timer(1.0).timeout
					
			var result = Combat.get_hit_roll_details(0, seeker_weapon, target, false, icm_used, null)
			var hit = result["success"]
			var hit_str = "HIT" if hit else "MISS"
			
			var msg1 = "Firing Ship: Autonomous Seeker, Weapon: Seeker Missile, Odds: %d%%, Roll: %d, Result: %s" % [result["chance"], result["roll"], hit_str]
			if _is_networked() and multiplayer.is_server(): rpc_log_message.rpc(msg1)
			else: log_message(msg1)
			
			var raw_dmg = 0
			if hit:
				raw_dmg = Combat.roll_damage("5d10")
				var dmg_roll = Combat.calculate_damage_roll(-20)
				var effect = Combat.get_damage_effect(dmg_roll)
				
				var dmg_txt = "%s took %d base damage array and %s from Seeker!" % [target.get_display_name(), raw_dmg, effect["text"]]
				
				if _is_networked() and multiplayer.is_server():
					rpc_play_mine_fx.rpc(current_pos, target.name, hit, raw_dmg)
					rpc_log_message.rpc(dmg_txt)
				else:
					rpc_play_mine_fx(current_pos, target.name, hit, raw_dmg)
					log_message(dmg_txt)
					
				var res_fx = target.apply_damage_effect(effect, raw_dmg)
				log_message("%s: %s" % [target.name, res_fx.get("text")])
				if res_fx.get("fallback", false):
					target.take_hull_damage(raw_dmg)
					
			else:
				var msg3 = "Seeker exploded harmlessly against %s defenses." % target.get_display_name()
				if _is_networked() and multiplayer.is_server(): rpc_log_message.rpc(msg3)
				else: log_message(msg3)
				
				if _is_networked() and multiplayer.is_server(): rpc_play_mine_fx.rpc(current_pos, target.name, hit, 0)
				else: rpc_play_mine_fx(current_pos, target.name, hit, 0)
				
			if get_tree() and not get_tree().root.has_node("GutRunner"):
				await get_tree().create_timer(1.5).timeout
				
	detonated_indices.sort()
	detonated_indices.reverse()
	for idx in detonated_indices:
		active_seekers.remove_at(idx)

@rpc("authority", "call_local", "reliable")
func rpc_play_mine_fx(mine_pos_hex: Vector3i, target_name: String, hit: bool, damage: int):
	# Play general sound for explosion
	if audio_hit and audio_hit.stream:
		audio_hit.play()
		
	var target = _find_ship_by_name(target_name)
	if is_instance_valid(target):
		_update_camera(target)
		
	if not get_tree().root.has_node("GutRunner"):
		var pixel_pos = HexGrid.hex_to_pixel(mine_pos_hex)
		_spawn_floating_text("BOOM!", pixel_pos, Color.RED)
		
		# Explode locally on the mine hex (simulate by targeting the exact same hex as source)
		var tgt_pixel = target.position if is_instance_valid(target) else pixel_pos
		_spawn_attack_fx(pixel_pos, pixel_pos, "Mine")
		
		if is_instance_valid(target):
			if hit:
				_spawn_hit_text(tgt_pixel, damage)
			else:
				_spawn_hit_text(tgt_pixel, "MISS")
				
	# If we are a client, we MUST apply the damage locally so the ship dies instantly visually!
	# The Host already applied it in _resolve_mine_detonations.
	if _is_networked() and not multiplayer.is_server():
		if is_instance_valid(target) and hit:
			target.take_hull_damage(damage)

func _calculate_mr_used_for_plan(start_pos: Vector3i, start_facing: int, path: Array[Vector3i], final_facing: int) -> int:
	var mr = 0
	var current_facing = start_facing
	var current_pos = start_pos
	
	if path.size() == 0:
		var diff = posmod(final_facing - start_facing, 6)
		mr += min(diff, 6 - diff)
		return mr
		
	for i in range(path.size()):
		var next_hex = path[i]
		var move_dir = HexGrid.get_hex_direction(current_pos, next_hex)
		
		var diff = posmod(move_dir - current_facing, 6)
		mr += min(diff, 6 - diff)
		
		current_facing = move_dir
		current_pos = next_hex
		
	var final_diff = posmod(final_facing - current_facing, 6)
	mr += min(final_diff, 6 - final_diff)
	
	return mr

func _apply_movement_plan(s: Ship):
	if not is_instance_valid(s): return

	var start_pos = s.grid_position
	var start_facing = s.facing
	var typed_history: Array[Vector3i] = [start_pos]
	for p in s.planned_path: typed_history.append(Vector3i(p))
	s.previous_path = typed_history # History
	var old_speed = s.speed
	if s.is_docked: old_speed = 0
	
	var new_speed = 0
	if s.planned_path.size() > 0:
		s.grid_position = s.planned_path.back()
		s.facing = s.planned_facing
		new_speed = s.planned_path.size()
	else:
		# Hold Position (or invalid empty path treated as hold)
		s.facing = s.planned_facing # Always apply facing change?
		new_speed = max(0, old_speed - s.get_effective_adf())
		
	if s.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
		new_speed = 0
		
	s.speed = new_speed
	
	# Orbit Logic
	if s.has_orders:
		s.orbit_direction = s.planned_orbit_dir
		
	s.has_moved = true
	s.has_orders = false
	
	# HULL INTEGRITY CHECK
	if s.planned_orbit_dir == 0 and not s.is_destroyed:
		var adf_used = abs(old_speed - new_speed)
		var mr_used = _calculate_mr_used_for_plan(start_pos, start_facing, s.planned_path, s.planned_facing)
		
		var risk = s.get_hull_integrity_risk(adf_used, mr_used)
		if risk > 0:
			# Use seeded RNG for multiplayer sync if available, or just randi
			# execute_all_movement is called on Authority.
			var roll = randi() % 100 + 1
			log_message("[color=yellow]Hull Integrity Check for %s: Roll %d vs %d%% Risk[/color]" % [s.name, roll, risk])
			if roll <= risk:
				log_message("[color=red]CRITICAL: %s broke apart due to structural failure during maneuvering![/color]" % s.name)
				s.take_hull_damage(9999)
				return # Stop processing this ship
	
	# Handle Docking
	if s.docked_guests.size() > 0:
		for guest in s.docked_guests:
			guest.grid_position = s.grid_position
			guest.facing = s.facing
			guest.queue_redraw()
			
	# Check Collisions (Planets)
	var destroyed = false
	for hex in s.planned_path:
		if planet_hexes.has(hex):
			destroyed = true
			break
	
	if destroyed:
		log_message("[color=red]%s crashed into a planet![/color]" % s.name)
		s.take_hull_damage(9999)
		s.has_moved = true
		
	# Orbit MS Check
	if s.is_ms_active and s.orbit_direction != 0 and s.ms_orbit_start_hex != Vector3i.MAX:
		if s.grid_position == s.ms_orbit_start_hex:
			s.is_ms_active = false
			s.ms_orbit_start_hex = Vector3i.MAX
			log_message("%s completes orbit; Screen drops." % s.name)
			
	s.queue_redraw()
	
	# FIX: Update Docking State (Auto-Undock/Dock)
	_handle_docking_states(s)


func _handle_docking_states(ship: Ship):
	# 1. Check for Auto-Docking
	var potential_hosts = ships.filter(func(s): return is_instance_valid(s) and s.side_id == ship.side_id and s != ship and s.grid_position == ship.grid_position)
	# Filter for valid hosts
	potential_hosts = potential_hosts.filter(func(s): return s.ship_class in ["Space Station", "Armed Station", "Fortified Station", "Assault Carrier"])
	
	if potential_hosts.size() > 0:
		var host = potential_hosts[0]
		if not ship.is_docked:
			if ship.dock_at(host):
				log_message("%s docked at %s." % [ship.name, host.name])
				if ship.ship_class == "Fighter" and host.ship_class == "Assault Carrier":
					log_message("%s re-armed/refueled." % ship.name)
			else:
				# Failed (Capacity?)
				# Only log if we *just* arrived to avoid spam?
				# Actually this runs every move commit. 
				# If we are effectively "on top" but can't dock, we just stay sharing the hex.
				pass
	else:
		if ship.is_docked:
			if ship.grid_position != ship.docked_host.grid_position:
				log_message("%s undocking from %s." % [ship.name, ship.docked_host.name])
				ship.undock()
	
	# 2. Sync Guests
	if ship.docked_guests.size() > 0:
		for guest in ship.docked_guests:
			guest.grid_position = ship.grid_position
			guest.facing = ship.facing

func _check_boundary(ship: Ship) -> bool:
	var dist = HexGrid.hex_distance(Vector3i.ZERO, ship.grid_position)
	if dist > map_radius:
		log_message("%s drifted into deep space and was lost." % ship.name)
		_on_ship_destroyed(ship) # Handles list removal and victory check
		ship.visible = false
		return true
	return false


func _should_show_movement_plan(s: Ship) -> bool:
	# Show ALL committed plans (Game Design Choice: Open Information once committed)
	# Future: Add Fog of War logic here
	if not s.has_orders: return false
	return true


func _draw_weapon_ranges(ghost: Ship, source: Ship):
	var groups = source.get_active_weapon_groups()
	
	# 1. Calculate Union of Hexes for Uniform Fill
	var all_hexes = {}
	var sorted_keys = groups.keys()
	# Sort by range for labeling order (largest first)
	sorted_keys.sort_custom(func(a, b): return groups[a]["range"] > groups[b]["range"])
	
	for key in sorted_keys:
		var range_val = groups[key]["range"]
		var w_name = groups[key]["name"]
		var is_ff = (w_name == "Laser Canon" or w_name == "Assault Rocket" or w_name == "Disruptor Canon")
		
		var hexes = []
		if is_ff:
			hexes = _get_ff_arc_hexes(ghost, range_val)
		else:
			hexes = _get_hexes_in_range(ghost.grid_position, range_val)
			
		for h in hexes:
			all_hexes[h] = true
			
	# Draw Uniform Fill
	var fill_color = Color(1, 0.2, 0.2, 0.2) # Non-additive uniform fill
	for h in all_hexes:
		_draw_filled_hex(h, fill_color)
		
	# 2. Draw Outlines & Labels per Group
	for key in sorted_keys:
		var range_val = groups[key]["range"]
		var count = groups[key]["count"]
		var w_name = groups[key]["name"]
		
		# Pluralize Label
		var label_text = w_name
		if count > 1:
			if w_name == "Laser Battery": label_text = "Laser Batteries"
			elif w_name == "Rocket Battery": label_text = "Rocket Batteries"
			elif w_name == "Torpedo": label_text = "Torpedoes"
			elif w_name == "Assault Rocket": label_text = "Assault Rockets"
			elif w_name == "Laser Canon": label_text = "Laser Canons"
			elif w_name == "Disruptor Canon": label_text = "Disruptor Canons"
			elif not w_name.ends_with("s"): label_text += "s"
		
		var full_label = "%d %s" % [count, label_text]
		if count == 1: full_label = label_text

		var is_ff = (w_name == "Laser Canon" or w_name == "Assault Rocket" or w_name == "Disruptor Canon")
		var outline_color = Color(1, 0, 0, 0.8) # Bright Red
		var label_pos = Vector2.ZERO
		
		if is_ff:
			# FF Polygon Outline (Wedge/Box)
			# Corners: Start-Left, Start-Right, End-Right, End-Left
			var fwd = HexGrid.get_direction_vec(ghost.facing)
			var left_vec = HexGrid.get_direction_vec((ghost.facing - 1 + 6) % 6)
			var right_vec = HexGrid.get_direction_vec((ghost.facing + 1) % 6)
			
			# Start at Range 1
			var start_center = ghost.grid_position + fwd
			var start_left = start_center + left_vec
			var start_right = start_center + right_vec
			
			# End at Range Max
			var end_center = ghost.grid_position + (fwd * range_val)
			var end_left = end_center + left_vec
			var end_right = end_center + right_vec
			
			var points = PackedVector2Array([
				HexGrid.hex_to_pixel(ghost.grid_position),
				HexGrid.hex_to_pixel(start_left),
				HexGrid.hex_to_pixel(end_left),
				HexGrid.hex_to_pixel(end_right),
				HexGrid.hex_to_pixel(start_right),
				HexGrid.hex_to_pixel(ghost.grid_position) # Close loop
			])
			
			draw_polyline(points, outline_color, 3.0)
			label_pos = HexGrid.hex_to_pixel(end_center)
			
		else:
			# 360 Circle Outline
			var center_pix = HexGrid.hex_to_pixel(ghost.grid_position)
			# Radius: Distance to the center of a hex at 'range_val'
			# Use Direction 0 (East) * range_val to gauge pixel radius
			var radial_hex = ghost.grid_position + (Vector3i(1, 0, -1) * range_val) # Approx direction vector logic might differ
			# Let's use HexGrid dist logic: 
			# Distance center-to-center is  range_val * (sqrt(3) * TILE_SIZE) roughly?
			# Actually HexGrid.hex_to_pixel(Vector3i(range, 0, -range)) gives X-dist.
			# Let's use exact pixel distance to a hex at that range.
			var sample_hex = ghost.grid_position + (HexGrid.get_direction_vec(0) * range_val)
			var sample_pix = HexGrid.hex_to_pixel(sample_hex)
			var radius = center_pix.distance_to(sample_pix)
			
			# Add half a hex size to enclose it?
			radius += HexGrid.TILE_SIZE * 0.866 # sqrt(3)/2
			
			draw_arc(center_pix, radius, 0, TAU, 64, outline_color, 3.0)
			
			# Label Placement: NE Edge (Dir 5)
			var dir_vec = HexGrid.get_direction_vec(5)
			var label_hex = ghost.grid_position + (dir_vec * range_val)
			label_pos = HexGrid.hex_to_pixel(label_hex)

		# Draw Label
		# FIX: Use existing label node to get theme font instead of static ThemeDB access which failed
		var font_ref = label_phase_indicator.get_theme_font("font")
		if not font_ref:
			font_ref = SystemFont.new()
			font_ref.font_names = ["Sans-Serif"]
			
		draw_string_outline(font_ref, label_pos + Vector2(0, 5), full_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, 2, Color.BLACK)
		draw_string(font_ref, label_pos + Vector2(0, 5), full_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 0.9, 0.9, 0.9))

func _draw_orbit_ring(planet_hex: Vector3i, orbit_dir: int, color: Color):
	var center = HexGrid.hex_to_pixel(planet_hex)
	var radius = HexGrid.TILE_SIZE * sqrt(3)
	
	# Draw ring
	draw_arc(center, radius, 0, TAU, 64, color, 3.0)
	
	# Draw arrowheads around the ring (e.g. 4 arrowheads)
	for i in range(4):
		var angle = i * (PI / 2.0)
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		
		# Direction of travel is tangent: +90 deg (PI/2) for CW 
		var tangent_angle = angle + (PI / 2.0 if orbit_dir == 1 else -PI / 2.0)
		
		var arrow_len = 15.0
		var p1 = pos - Vector2(cos(tangent_angle - PI/6.0), sin(tangent_angle - PI/6.0)) * arrow_len
		var p2 = pos - Vector2(cos(tangent_angle + PI/6.0), sin(tangent_angle + PI/6.0)) * arrow_len
		
		var pts = PackedVector2Array([pos, p1, p2])
		draw_polygon(pts, PackedColorArray([color]))


func _draw():
	# transform.origin = center # REMOVED: Camera is now handled by _update_camera
	for q in range(-map_radius, map_radius + 1):
		for r in range(-map_radius, map_radius + 1):
			var s = -q - r
			if abs(s) > map_radius: continue
			var hex = Vector3i(q, r, s)
			draw_hex(hex)
			
	# Draw Deployment Highlights
	if current_phase == Phase.DEPLOYMENT:
		# Always Draw Deployment Mines while in Deployment phase
		if deployment_mines_placed.size() > 0:
			var font = label_phase_indicator.get_theme_font("font")
			for h in deployment_mines_placed:
				var center = HexGrid.hex_to_pixel(h)
				_draw_filled_hex(h, Color(1, 0.5, 0, 0.4)) # Translucent Orange
				if font:
					var text_offset = Vector2(0, 5) 
					draw_string_outline(font, center + text_offset, "MINE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, 2, Color.BLACK)
					draw_string(font, center + text_offset, "MINE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.YELLOW)
					
		if deployment_seekers_placed.size() > 0:
			for h in deployment_seekers_placed:
				var s_pos = HexGrid.hex_to_pixel(h)
				_draw_filled_hex(h, Color(1, 0.5, 0, 0.4)) # Translucent Orange
				draw_circle(s_pos, 10.0, Color(1.0, 0.5, 0.0, 0.9)) # Orange Circle
				draw_circle(s_pos, 4.0, Color(1.0, 1.0, 1.0, 0.9)) # White Center Eye
					
		if is_deploying_ship and is_instance_valid(selected_ship):
			var valid_hexes = ScenarioManager.get_valid_deployment_hexes(deployment_subphase, ships, planet_hexes, selected_ship)
			# Only highlight if there are restrictions (not the whole map)
			if valid_hexes.size() > 0:
				for h in valid_hexes:
					if not planet_hexes.has(h):
						_draw_hex_outline(h, Color(0, 1, 0, 0.5), 2.0)
						
		# Render projected speed for non-station ships during deployment
		if deploy_hex_selected and deploy_speed_val > 0 and not (selected_ship.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]):
			var forward_vec = HexGrid.get_direction_vec(deploy_facing_val)
			var current_check_hex = deploy_tentative_hex
			
			for i in range(deploy_speed_val):
				current_check_hex += forward_vec
				_draw_hex_outline(current_check_hex, Color(0, 1, 1, 0.6), 4.0) # Cyan for deployment speed
				
		# Render orbit preview for stations during deployment
		if deploy_hex_selected and deploy_orbit_dir_val != 0 and (selected_ship.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]):
			var planet = null
			for neighbor in HexGrid.get_neighbors(deploy_tentative_hex):
				if neighbor in planet_hexes:
					planet = neighbor
					break
			if planet != null:
				_draw_orbit_ring(planet, deploy_orbit_dir_val, Color(0.8, 0.8, 0.8, 0.8))
			
	# Draw projected speed vectors for already deployed ships
	if current_phase == Phase.DEPLOYMENT:
		for s in ships:
			if is_instance_valid(s) and s.is_deployed and s.side_id == deployment_subphase:
				if s.ship_class not in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"] and s.speed > 0:
					var start_pos = HexGrid.hex_to_pixel(s.grid_position)
					var forward_vec = HexGrid.get_direction_vec(s.facing)
					var end_pos = HexGrid.hex_to_pixel(s.grid_position + forward_vec * s.speed)
					
					draw_line(start_pos, end_pos, Color(1, 1, 1, 0.6), 3.0, true)
					
					var angle = (end_pos - start_pos).angle()
					var arrow_size = 15.0
					var p1 = end_pos - Vector2(cos(angle - PI/6), sin(angle - PI/6)) * arrow_size
					var p2 = end_pos - Vector2(cos(angle + PI/6), sin(angle + PI/6)) * arrow_size
					var arrow_pts = PackedVector2Array([end_pos, p1, p2])
					draw_polygon(arrow_pts, PackedColorArray([Color(1, 1, 1, 0.6)]))
			
	# Draw orbital rings for all orbiting Space Stations
	for s in ships:
		if is_instance_valid(s) and s.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"] and s.orbit_direction != 0 and s.is_deployed and not s.is_destroyed:
			# Skip drawing the permanent ring if we are actively re-deploying this station (it draws a preview instead)
			if current_phase == Phase.DEPLOYMENT and is_deploying_ship and s == selected_ship:
				continue
				
			var planet = null
			for neighbor in HexGrid.get_neighbors(s.grid_position):
				if neighbor in planet_hexes:
					planet = neighbor
					break
			if planet != null:
				_draw_orbit_ring(planet, s.orbit_direction, Color(0.8, 0.8, 0.8, 0.6))

	# Draw Eligible Hexes for Defensive Fire
	if current_phase == Phase.COMBAT and combat_subphase == 1 and current_combat_state == CombatState.PLANNING:
		var is_my_planning = (firing_side_id == my_side_id) or (my_side_id == 0)
		if is_my_planning:
			for ship in ships:
				if is_instance_valid(ship) and ship.side_id == current_side_id and not ship.is_destroyed:
					# Use `_draw_filled_hex` if available, else a raw poly fill
					var fill_color = Color(1.0, 0.0, 0.0, 0.2)
					_draw_filled_hex(ship.grid_position, fill_color)
					for h in ship.previous_path:
						_draw_filled_hex(h, fill_color)
	
	# Draw Previous Turn Trails (Faint Gray)
	for s in ships:
		if is_instance_valid(s) and s.previous_path.size() > 0:
			var points = PackedVector2Array()
			points.append(HexGrid.hex_to_pixel(s.grid_position - HexGrid.get_direction_vec(s.facing) * s.previous_path.size())) # Rough start calc?
			# Actually, s.grid_position is the END of the path.
			# So we can't easily reconstruct the start without reversing the path or storing it.
			# But wait, previous_path is just the list of hexes *visited*.
			# The stored path in execute_commit_move is the list of hexes *after* the start.
			# So we can just draw lines connecting them.
			# But where did it start?
			# The first hex in 'path' is the first step. The start was the hex BEFORE that.
			# We don't strictly know the start hex unless we store it or deduce it.
			# However, we can just draw the path segments we have.
			
			# Let's try drawing the path hexes themselves.
			# Issue: The path array contains the hexes moved INTO.
			# It does not contain the starting hex.
			# Does it matter? We can draw the trail of where they went.
			# But to look connected, we need the start?
			# Actually, if we just draw lines between the hexes in previous_path, it shows the "tail".
			# It won't connect to the *current* position if they moved again? 
			# 'previous_path' is from the *last* move.
			# If they haven't moved yet this turn, their current position IS the end of previous_path.
			# If they *have* moved this turn, they are somewhere new.
			
			# Let's just draw the polyline of the hexes in previous_path.
			# We might miss the segment from Start -> First Hex.
			# Is that acceptable? It's better than nothing.
			# Creating a proper trail would require saving the Start Hex too.
			
			var trail_points = PackedVector2Array()
			# Issue: We need the start point to draw the first segment.
			# If we don't have it, we skip the first segment.
			# Let's verify if we can get it easily.
			# execute_commit_move doesn't save start.
			# But we can reconstruct it if we assume contiguous?
			# No, we can't easily.
			# Let's just draw what we have for now.
			
			for h in s.previous_path:
				trail_points.append(HexGrid.hex_to_pixel(h))
			
			if trail_points.size() > 1:
				draw_polyline(trail_points, Color(0.5, 0.5, 0.5, 0.4), 2.0)
			elif trail_points.size() == 1:
				# Just a dot? Or finding neighbor?
				pass

	# Draw Planned Paths for OTHER ships (Visualization of Batch Orders)
	# UPDATE: Now handles ANY ship with orders (Selected or not)
	if current_phase == Phase.MOVEMENT:
		for s in ships:
			if not is_instance_valid(s) or s.has_moved or s.is_destroyed: continue
			
			if s.has_orders:
				# Only show my side (or if spectator/host)
				# UDPATE: User requests seeing ALL committed plans
				if not _should_show_movement_plan(s): continue
				
				var plan_points = PackedVector2Array()
				plan_points.append(HexGrid.hex_to_pixel(s.grid_position))
				
				var is_danger = false
				for h in s.planned_path:
					plan_points.append(HexGrid.hex_to_pixel(h))
					if planet_hexes.has(h): is_danger = true
				
				# UPDATED VISUALS: Muted White, Thicker Line
				var path_color = Color(1, 1, 1, 0.4) # Muted White
				if is_danger: path_color = Color(1, 0, 0, 0.4) # Faint Red
				
				if plan_points.size() > 1:
					draw_polyline(plan_points, path_color, 5.0)
					
					# Draw Ghost Ship Sprite at End
					var end_pos = plan_points[plan_points.size() - 1]
					s.draw_sprite_custom(self, end_pos, s.planned_facing, 0.5)
					
			elif s.speed > 0 and s.ship_class not in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
				# User Request: If no new orders are issued, ship will move exactly its speed forward.
				# Draw a translucent arrow projecting this default forward path.
				# Suppress if this is the actively selected/plotting ship (since current_path logic takes over)
				if is_instance_valid(selected_ship) and s == selected_ship and current_path.size() > 0:
					continue
					
				var start_pos = HexGrid.hex_to_pixel(s.grid_position)
				var forward_vec = HexGrid.get_direction_vec(s.facing)
				var end_pos = HexGrid.hex_to_pixel(s.grid_position + forward_vec * s.speed)
				
				draw_line(start_pos, end_pos, Color(1, 1, 1, 0.3), 3.0, true) # Faint translucent white
				
				var angle = (end_pos - start_pos).angle()
				var arrow_size = 12.0
				var p1 = end_pos - Vector2(cos(angle - PI/6), sin(angle - PI/6)) * arrow_size
				var p2 = end_pos - Vector2(cos(angle + PI/6), sin(angle + PI/6)) * arrow_size
				var arrow_pts = PackedVector2Array([end_pos, p1, p2])
				draw_polygon(arrow_pts, PackedColorArray([Color(1, 1, 1, 0.3)]))
	
	# Active Plotting Visualization
	# Only draw if selected ship DOES NOT have orders (i.e. we are actively plotting)
	if current_phase == Phase.MOVEMENT and is_instance_valid(ghost_ship) and current_path.size() > 0 and is_instance_valid(selected_ship) and not selected_ship.has_orders:
		var points = PackedVector2Array()
		points.append(HexGrid.hex_to_pixel(selected_ship.grid_position))
		
		# Collision Check for Visualization
		var collision_detected = false
		var collision_hex = Vector3i.ZERO
		
		for h in current_path:
			points.append(HexGrid.hex_to_pixel(h))
			
			if not collision_detected and h in planet_hexes:
				collision_detected = true
				collision_hex = h
		
		# Hull Integrity Risk Check
		var risk = 0
		if is_instance_valid(selected_ship) and not state_is_orbiting:
			var adf_used = abs(start_speed - current_path.size())
			var mr_used = _calculate_mr_used_for_plan(selected_ship.grid_position, selected_ship.facing, current_path, ghost_ship.facing)
			risk = selected_ship.get_hull_integrity_risk(adf_used, mr_used)

		# Draw Path Line
		var line_color = Color(1, 1, 1, 0.8) # Default White
		if collision_detected:
			line_color = Color(1, 0.5, 0, 0.8) # Orange/Red
		elif risk > 0:
			line_color = Color(1, 0, 0, 0.8) # Red Risk
			
		# Increased width and opacity for better visibility
		draw_polyline(points, line_color, 5.0)
		
		if collision_detected:
			# Highlight Collision Hex
			_draw_hex_outline(collision_hex, Color.RED, 4.0)
			# Highlight Ghost Ship
			ghost_ship.modulate = Color(1, 0.5, 0.5) # Reddish
		elif risk > 0:
			ghost_ship.modulate = Color(1, 0.2, 0.2) # Deep Red
			
			# Draw Risk Label
			var font = ThemeDB.fallback_font
			var tip = points[points.size() - 1]
			draw_string_outline(font, tip + Vector2(-30, -35), "%d%% Breakup Risk" % risk, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, 2, Color.BLACK)
			draw_string(font, tip + Vector2(-30, -35), "%d%% Breakup Risk" % risk, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.RED)
		else:
			ghost_ship.modulate = Color.WHITE
		
	# Predictive Path Highlighting
	# FIX: Ensure we have a ghost ship AND are in movement phase AND ship hasn't moved yet
	# ALSO: Suppress if ship has planned orders (Visualization only) - User Request
	if current_phase == Phase.MOVEMENT and is_instance_valid(ghost_ship) and is_instance_valid(selected_ship) and not selected_ship.has_moved and not selected_ship.has_orders:
		# Re-verify start_speed is set (it should be set in start_movement_phase)
		# But if ghost_ship was respawned, did we lose context?
		# No, start_speed is a GM var.
		var steps_taken = current_path.size()
		
		# VISUAL AID: Draw line from Path End (Head) to Ghost Ship (Preview)
		if ghost_head_pos != ghost_ship.grid_position:
			var start_pix = HexGrid.hex_to_pixel(ghost_head_pos)
			var end_pix = HexGrid.hex_to_pixel(ghost_ship.grid_position)
			draw_line(start_pix, end_pix, Color(1, 1, 1, 0.5), 2.0, true) # Anti-aliased dashed-ish? No, just line.
		
		# Logic:
		# Green (momentum): existing speed - steps taken. Must move at least this many more?
		# Wait, "mandatory momentum" means you must move at least speed - ADF? No.
		# Rules: You must move at least 1/2 speed? Or just cannot STOP unless speed 0.
		# "Decelerate by ADF". So min_speed = start_speed - ADF.
		# If steps < min_speed, we highlight "required" hexes?
		# Basically, if we haven't moved enough, show where we MUST go (straight).
		# Green = "You must go at least this far (straight or turning?)"
		# Usually just show the range. 
		
		# Let's simple check:
		# Green = "Free/Momentum" range?
		# Yellow = "Acceleration" range?
		# Code used:
		# green_count = max(0, start_speed - steps_taken) -> Remaining "Inertia"?
		# If I start at speed 4. I move 1. green_count = 3.
		# It draws 3 green hexes forward.
		# This implies "If I don't change speed, I go here".
		
		# 3-State Highlighting:
		# Orange: Mandatory (0 to Speed - ADF)
		# Green: Coasting (Speed - ADF to Speed)
		# Yellow: Acceleration (Speed to Speed + ADF)
		
		var min_speed = max(0, start_speed - selected_ship.get_effective_adf())
		var max_speed = start_speed + selected_ship.get_effective_adf()
		
		var orange_count = max(0, min_speed - steps_taken)
		var green_count = max(0, start_speed - steps_taken - orange_count)
		var yellow_count = max(0, max_speed - steps_taken - orange_count - green_count)
		
		# FIX: Use ghost_head_facing/pos to anchor the overlay to the COMMITTED path end,
		# NOT the floating preview ghost.
		var forward_vec = HexGrid.get_direction_vec(ghost_head_facing)
		var current_check_hex = ghost_head_pos
		
		# Draw Orange (Mandatory)
		for i in range(orange_count):
			current_check_hex += forward_vec
			_draw_hex_outline(current_check_hex, Color(1, 0.4, 0, 0.8), 4.0)

		# Draw Green (Coasting)
		for i in range(green_count):
			current_check_hex += forward_vec
			_draw_hex_outline(current_check_hex, Color(0, 1, 0, 0.6), 4.0)
			
		# Draw Yellow (Acceleration)
		for i in range(yellow_count):
			current_check_hex += forward_vec
			_draw_hex_outline(current_check_hex, Color(1, 1, 0, 0.6), 4.0)

	# PLAN VISUALIZATION
	if current_phase == Phase.COMBAT and current_combat_state == CombatState.PLANNING:
		# Iterate queued attacks
		for atk in queued_attacks:
			if atk["source"] == selected_ship:
				# Check if this attack corresponds to the currently selected weapon
				if atk["weapon_idx"] == selected_ship.current_weapon_index:
					# Draw line to target
					var visible_target_pos = atk["target_pos"]
					if is_instance_valid(atk["target"]):
						visible_target_pos = atk["target"].position
					
					var start = HexGrid.hex_to_pixel(selected_ship.grid_position)
					draw_line(start, visible_target_pos, Color(1, 1, 0, 0.5), 2.0)
					draw_circle(visible_target_pos, 5.0, Color(1, 1, 0, 0.5))

	# Weapon Range Highlight (Combat Phase) - ONLY IN PLANNING
	if current_phase == Phase.COMBAT and selected_ship and selected_ship.weapons.size() > 0 and current_combat_state == CombatState.PLANNING:
		var weapon = selected_ship.weapons[selected_ship.current_weapon_index]
# [REMOVED LINES for brevity in replacement, will keep standard logic] we rely on context.
# Wait, I am inserting BEFORE this block but the prompt implies I am replacing lines 3230...
# actually I want to KEEP the Combat Phase logic and ADD the Movement Phase logic.
# Step 1: Add the Movement Phase logic inside _draw
# Step 2: Add the helper function
	
	# NEW: Weapon Range Visualization during Movement Planning (Ghost)
	if current_phase == Phase.MOVEMENT and is_instance_valid(ghost_ship) and is_instance_valid(selected_ship) and not selected_ship.has_orders:
		_draw_weapon_ranges(ghost_ship, selected_ship)

	# Weapon Range Highlight (Combat Phase) - ONLY IN PLANNING
	if current_phase == Phase.COMBAT and selected_ship and selected_ship.weapons.size() > 0 and current_combat_state == CombatState.PLANNING:
		var weapon = selected_ship.weapons[selected_ship.current_weapon_index]
		var w_range = weapon["range"]
		var w_arc = weapon["arc"]
		
		# For FF (Forward Firing), we project a 3-hex wide spread
		if w_arc == "FF":
			var valid_hexes = _get_ff_arc_hexes(selected_ship, w_range)
			var forward_vec = HexGrid.get_direction_vec(selected_ship.facing)
			var head_on_hexes = []
			
			# Identify Head-on Hexes (Center Line)
			head_on_hexes.append(selected_ship.grid_position) # Own hex is Head-on
			var trace = selected_ship.grid_position + forward_vec
			for i in range(w_range):
				head_on_hexes.append(trace)
				trace += forward_vec
			
			for hex in valid_hexes:
				if hex in head_on_hexes:
					# Head-on: Orange/Yellow Highlight
					_draw_filled_hex(hex, Color(1, 0.6, 0, 0.4))
				else:
					# Side/Standard: Red Highlight
					_draw_filled_hex(hex, Color(1, 0.2, 0.2, 0.3))
		
		elif w_arc == "360":
			# Highlight Radius
			# Drawing all hexes is expensive. Draw a circle outline at range?
			for hex in _get_hexes_in_range(selected_ship.grid_position, w_range):
				_draw_filled_hex(hex, Color(1, 0.2, 0.2, 0.1)) # Faint red background
			
			# Draw Range Boundary
			var pos = HexGrid.hex_to_pixel(selected_ship.grid_position)
			# Radius approx: (w_range + 0.5) * TILE_SIZE * sqrt(3)
			# Hex width = 2 * size. Distance center-to-center = sqrt(3) * size.
			# Max distance = w_range * sqrt(3) * size
			# Let's just use raw pixel distance for "Visual" circle
			draw_arc(pos, w_range * HexGrid.TILE_SIZE * 1.732, 0, TAU, 64, Color(1, 0.2, 0.2, 0.5), 2.0)

	# Combat Target Highlight
	if current_phase == Phase.COMBAT and combat_target:
		# Draw brackets or circle around target
		var pos = combat_target.position # Use visual position since it accounts for stacks
		var size = HexGrid.TILE_SIZE * 0.8
		draw_arc(pos, size, 0, TAU, 32, Color.RED, 3.0)
		# Draw crosshair
		var length = 10
		draw_line(pos + Vector2(-length, 0), pos + Vector2(length, 0), Color.RED, 2.0)
		draw_line(pos + Vector2(0, -length), pos + Vector2(0, length), Color.RED, 2.0)

	# MR Expenditures Visual Feedback
	if current_phase == Phase.MOVEMENT and mr_expenditures.size() > 0:
		var font = ThemeDB.fallback_font
		for exp_entry in mr_expenditures:
			var center = HexGrid.hex_to_pixel(exp_entry["pos"])
			var offset = Vector2(0, -35) # Draw above the hex
			draw_string_outline(font, center + offset, exp_entry["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 16, 2, Color.BLACK)
			draw_string(font, center + offset, exp_entry["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.RED)

	# Draw Active Mines
	for m in active_mines:
		var is_owner = (my_side_id == 0 or my_side_id == m["side_id"])
		# Only draw mines if we own them, or if we are the server/spectator
		if is_owner:
			var m_pos = HexGrid.hex_to_pixel(m["pos"])
			var spike_count = 8
			var rad_inner = 8.0
			var rad_outer = 14.0
			var mine_color = Color(1.0, 0.8, 0.0, 0.9) # Bright Yellow
			var pts = PackedVector2Array()
			for i in range(spike_count * 2):
				var angle = deg_to_rad(i * (360.0 / (spike_count * 2)))
				var r = rad_outer if i % 2 == 0 else rad_inner
				pts.append(m_pos + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(pts, mine_color)
			draw_circle(m_pos, 4.0, Color.RED) # Red center eye
			
	# Draw Planned Mines (Placeholder/Hologram)
	# Draw Planned Mines (Text Indicator)
	if current_phase == Phase.MOVEMENT and is_instance_valid(selected_ship) and selected_ship.planned_mines_to_drop.size() > 0:
		for hex in selected_ship.planned_mines_to_drop:
			# When placement mode is active, we highlight valid drop hexes
			if state_mine_placement:
				var is_valid_hex = (hex == selected_ship.grid_position) or current_path.has(hex) or selected_ship.planned_path.has(hex)
				if is_valid_hex:
					# Highlight the hex to show it's clickable
					_draw_filled_hex(hex, Color(1.0, 1.0, 0.0, 0.2)) # Faintest Yellow
			
			var m_pos = HexGrid.hex_to_pixel(hex)
			var font = ThemeDB.fallback_font
			# Draw shadow and then text
			draw_string_outline(font, m_pos + Vector2(0, 5), "MINE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, 2, Color.BLACK)
			draw_string(font, m_pos + Vector2(0, 5), "MINE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.YELLOW)
			
	# If Placement mode is on but we have no planned mines yet (or some placed, but we need to highlight the rest of the path)
	if current_phase == Phase.MOVEMENT and is_instance_valid(selected_ship) and state_mine_placement:
		var valid_hexes = [selected_ship.grid_position]
		valid_hexes.append_array(current_path)
		valid_hexes.append_array(selected_ship.planned_path)
		for hex in valid_hexes:
			# Only faintly highlight if a mine isn't already placed there
			if not selected_ship.planned_mines_to_drop.has(hex):
				_draw_filled_hex(hex, Color(1.0, 1.0, 0.0, 0.2))

	# Draw Active Seekers
	for s in active_seekers:
		# Draw if active, or if we own it during deployment/inactivity
		var is_owner = (my_side_id == 0 or my_side_id == s["side_id"])
		if is_owner or s.get("speed", 0) > 0: # Speed > 0 means it's ALIVE and hunting, visible to all
			var s_pos = HexGrid.hex_to_pixel(s["pos"])
			draw_circle(s_pos, 10.0, Color(1.0, 0.5, 0.0, 0.9)) # Orange Circle
			draw_circle(s_pos, 4.0, Color(1.0, 1.0, 1.0, 0.9)) # White Center Eye
			
	# Draw Planned Seekers
	if current_phase == Phase.MOVEMENT and is_instance_valid(selected_ship) and selected_ship.planned_seekers_to_drop.size() > 0:
		for hex in selected_ship.planned_seekers_to_drop:
			if state_seeker_placement:
				var is_valid_hex = (hex == selected_ship.grid_position) or current_path.has(hex) or selected_ship.planned_path.has(hex)
				if is_valid_hex:
					_draw_filled_hex(hex, Color(1.0, 0.5, 0.0, 0.2)) # Faintest Orange
			
			var s_pos = HexGrid.hex_to_pixel(hex)
			draw_circle(s_pos, 10.0, Color(1.0, 0.5, 0.0, 0.9)) # Orange Circle
			draw_circle(s_pos, 4.0, Color(1.0, 1.0, 1.0, 0.9)) # White Center Eye

	# If Placement mode is on but we have no planned seekers yet (or highlighting rest of path)
	if current_phase == Phase.MOVEMENT and is_instance_valid(selected_ship) and state_seeker_placement:
		var valid_hexes = [selected_ship.grid_position]
		valid_hexes.append_array(current_path)
		valid_hexes.append_array(selected_ship.planned_path)
		for hex in valid_hexes:
			var seeker_arr = selected_ship.planned_seekers_to_drop
			if not seeker_arr.has(hex):
				_draw_filled_hex(hex, Color(1.0, 0.5, 0.0, 0.2))


func _draw_hex_outline(hex: Vector3i, color: Color, width: float):
	var center = HexGrid.hex_to_pixel(hex)
	var size = HexGrid.TILE_SIZE
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i + 30)
		points.append(center + Vector2(size * cos(angle), size * sin(angle)))
	points.append(points[0]) # Close loop
	draw_polyline(points, color, width)

func _draw_filled_hex(hex: Vector3i, color: Color):
	var center = HexGrid.hex_to_pixel(hex)
	var size = HexGrid.TILE_SIZE
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i + 30)
		points.append(center + Vector2(size * cos(angle), size * sin(angle)))
	draw_colored_polygon(points, color)

func draw_hex(hex: Vector3i):
	var center = HexGrid.hex_to_pixel(hex)
	var size = HexGrid.TILE_SIZE
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i + 30)
		points.append(center + Vector2(size * cos(angle), size * sin(angle)))
	draw_polyline(points, Color(0.7, 0.7, 0.7, 0.4), 1.0)
	
	# Basic highlighting handled by predictive path now, removing old logic to avoid clutter


func _unhandled_input(event):
	# Universal Global Hotkeys
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			if is_instance_valid(panel_log_container):
				panel_log_container.visible = !panel_log_container.visible
			get_viewport().set_input_as_handled()
			return

	# Client-Side View Controls (Always Allowed)
	if event is InputEventMouseButton and event.pressed:
		# Zoom Handling
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = (target_zoom + Vector2(ZOOM_SPEED, ZOOM_SPEED)).clamp(ZOOM_MIN, ZOOM_MAX)
			return # Consume Input
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = (target_zoom - Vector2(ZOOM_SPEED, ZOOM_SPEED)).clamp(ZOOM_MIN, ZOOM_MAX)
			return # Consume Input

	# Authority Check
	if my_side_id != 0:
		# If it's not my turn (Movement) OR not my firing phase (Combat)
		# Movement: current_side_id must match
		# Combat: firing_side_id must match
		var active_id = current_side_id
		if current_phase == Phase.COMBAT:
			active_id = firing_side_id
		elif current_phase == Phase.REPAIR:
			active_id = repair_subphase
		elif current_phase == Phase.DEPLOYMENT:
			active_id = deployment_subphase
			
		if active_id != my_side_id:
			# print("Input Rejected: Active %d vs Local %d" % [active_id, my_side_id])
			return # Ignore input for other sides
			
	# print("[DEBUG] Input Accepted for Side %d" % my_side_id)
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_mouse = get_local_mouse_position()
			var hex_clicked = HexGrid.pixel_to_hex(local_mouse)
			
			if current_phase == Phase.COMBAT:
				_handle_combat_click(hex_clicked)
			elif current_phase == Phase.MOVEMENT:
				_handle_movement_click(hex_clicked)
			elif current_phase == Phase.DEPLOYMENT:
				_handle_deployment_click(hex_clicked)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if current_phase == Phase.MOVEMENT and not current_path.is_empty():
				log_message("Right Click: Committing Move...")
				_on_commit_move()
			elif current_phase == Phase.DEPLOYMENT and is_deploying_ship and deploy_hex_selected:
				log_message("Right Click: Committing Deployment...")
				_on_deploy_ship_pressed()
				
	if event is InputEventMouseMotion:
		pass # Mouse Logic moved to _process for consistency and to fix frame-lag bugs


	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			if current_phase == Phase.DEPLOYMENT and (deployment_subphase == my_side_id or my_side_id == 0):
				var my_ships = ships.filter(func(s): return is_instance_valid(s) and s.side_id == deployment_subphase and not s.is_exploding)
				var deployable_ships = my_ships.filter(func(s): return not s.is_docked)
				if deployable_ships.size() > 0:
					var current_idx = -1
					if is_instance_valid(selected_ship) and deployable_ships.has(selected_ship):
						current_idx = deployable_ships.find(selected_ship)
						
					var shift_held = Input.is_key_pressed(KEY_SHIFT)
					if shift_held:
						current_idx = (current_idx - 1 + deployable_ships.size()) % deployable_ships.size()
					else:
						current_idx = (current_idx + 1) % deployable_ships.size()
						
					var s = deployable_ships[current_idx]
					
					selected_ship = s
					is_deploying_ship = true
					state_deployment_mine_placement = false
					state_deployment_seeker_placement = false
					if btn_deploy_mine: btn_deploy_mine.set_pressed_no_signal(false)
					if btn_deploy_seeker: btn_deploy_seeker.set_pressed_no_signal(false)
					
					if s.is_deployed:
						deploy_tentative_hex = s.grid_position
						deploy_facing_val = s.facing
						deploy_speed_val = s.speed
						deploy_hex_selected = true
					else:
						deploy_hex_selected = false
						_center_camera_on_deployment_zone(s)
						
					_update_deployment_ui()
					_update_deploy_preview()
					_update_ui_state()
					
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_PAGEUP: # Plus key / Page Up
			target_zoom = (target_zoom + Vector2(ZOOM_SPEED, ZOOM_SPEED)).clamp(ZOOM_MIN, ZOOM_MAX)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_PAGEDOWN: # Minus key / Page Down
			target_zoom = (target_zoom - Vector2(ZOOM_SPEED, ZOOM_SPEED)).clamp(ZOOM_MIN, ZOOM_MAX)

	
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		# Cycle Weapon
		if current_phase == Phase.COMBAT and selected_ship and selected_ship.weapons.size() > 1:
			var idx = selected_ship.current_weapon_index
			var start_idx = idx
			
			# Cycle until we find an available weapon or circle back
			while true:
				idx = (idx + 1) % selected_ship.weapons.size()
				var w = selected_ship.weapons[idx]
				if _is_weapon_available_in_phase(w, selected_ship):
					selected_ship.current_weapon_index = idx # commit
					log_message("Weapon switched to: %s (Ammo: %d, Arc: %s)" % [w["name"], w["ammo"], w["arc"]])
					break
				
				if idx == start_idx:
					log_message("No other weapons available in this phase!")
					break

			queue_redraw()
			_update_ui_state()
			_update_camera(selected_ship)

func _is_weapon_available_in_phase(weapon: Dictionary, ship: Ship = null) -> bool:
	if weapon.get("is_crippled", false):
		return false
		
	var w_type = weapon.get("type")
	# Rule 1: Moving Player Only for Propelled weapons (Assault Rockets, Torpedoes)
	# Rocket Batteries are EXEMPT from this (can be fired defensively)
	var is_propelled_movement_restricted = w_type in ["Rocket", "Torpedo"]
	# Rocket Batteries are EXEMPT from this (can be fired defensively)
	
	if is_propelled_movement_restricted:
		if firing_side_id != current_side_id:
			return false

	# Scenario Debuff Check
	if _check_scenario_debuffs(ship, "no_fire"):
		# We can't log here easily without spamming, but we can return false.
		return false

	# DOCKING RULE: Weapon Restrictions
	# "A docked ship can use it's laser and rocket battery weapons. A docked ship cannot use it's forward firing weapons, torpedoes, or ICMs."
	if ship and ship.is_docked:
		# Allowed: "Laser" (Battery), "Rocket Battery"
		# Disallowed: "Rocket" (Assault), "Torpedo", "Laser Canon" (FF)
		# ICM is handled in ICM logic elsewhere (defense).
		# Logic:
		# - Laser Battery (Type="Laser", Arc="360") -> OK
		# - Rocket Battery (Type="Rocket Battery") -> OK
		# - Laser Canon (Type="Laser Canon", Arc="FF") -> NO
		# - Assault Rocket (Type="Rocket", Arc="FF") -> NO
		# - Torpedo (Type="Torpedo") -> NO
		if w_type == "Laser": return true # Battery
		if w_type == "Rocket Battery": return true
		
		# All others rejected
		return false

	# Rule 2: Limit 1 per Phase for certain types (Rocket Battery, Torpedo, Rocket)
	# User Request: "a ship may only fire 1 rocket battery per combat phase" (and "just like torpedoes")
	# We interpret this as: Unique Weapon Type Usage Limit = 1 per ship per phase.
	if w_type in ["Rocket Battery", "Torpedo", "Rocket"]:
		if ship:
			# Check if ANY other weapon of this type has been fired or planned?
			# Check Planned Attacks
			for atk in queued_attacks:
				if atk["source"] == ship:
					var planned_w_idx = atk["weapon_idx"]
					var planned_w = ship.weapons[planned_w_idx]
					
					# Allow if it's THIS exact weapon (allowing overwrite/edit)
					if planned_w == weapon: continue
					
					# Block if it's a DIFFERENT weapon of SAME type
					if planned_w.get("type") == w_type:
						return false
			
			# Check Fired State (if we support multi-step firing later, or just safety)
			for w in ship.weapons:
				if w == weapon: continue
				if w.get("type") == w_type and w.get("fired", false):
					return false

	return true


func _get_ff_arc_hexes(ship: Ship, w_range: int) -> Array:
	var hexes = [ship.grid_position] # Range 0 is always valid for FF (and is Head-on)
	var fwd_vec = HexGrid.get_direction_vec(ship.facing)
	
	# Directions for "Forward Left" and "Forward Right" (The hexes adjacent to the Forward hex)
	# In hex grid, "Left of Forward" when facing 'i' is usually 'i-1' relative to the center?
	# Let's assume compact packing (Columns share edges).
	# Neighbor of (Shift+Fwd) in direction (Facing-1) is the Forward-Left neighbor.
	
	# Side Lines Visualization:
	# C (Dist 1)
	# L R (Neighbors of C, Dist 2 from Ship)
	# So Left Start is ship.grid + fwd_vec + left_bias
	
	var left_vec = HexGrid.get_direction_vec((ship.facing - 1 + 6) % 6)
	var right_vec = HexGrid.get_direction_vec((ship.facing + 1) % 6)
	
	# Define Start Points for the 3 columns
	# Center starts at Range 1
	var center_start = ship.grid_position + fwd_vec
	
	# Sides start "1 hex away" (interpreted as neighbors of the Range 1 Center hex)
	var left_start = center_start + left_vec
	var right_start = center_start + right_vec
	
	var starts = [center_start, left_start, right_start]
	
	for start_hex in starts:
		var curr = start_hex
		# Trace forward from this start point
		# We check distance constraint for EVERY hex
		
		# Optimization: If the start is already out of range, skip column
		if HexGrid.hex_distance(ship.grid_position, curr) > w_range:
			continue
			
		# Trace
		for i in range(w_range):
			if HexGrid.hex_distance(ship.grid_position, curr) <= w_range:
				if not curr in hexes:
					hexes.append(curr)
			else:
				# Once we exceed range, we stop this column (distance strictly increases)
				break
			curr += fwd_vec
			
	return hexes

func _get_hexes_in_range(center: Vector3i, dist: int) -> Array:
	var results = []
	for q in range(-dist, dist + 1):
		for r in range(max(-dist, -q - dist), min(dist, -q + dist) + 1):
			var s = -q - r
			results.append(center + Vector3i(q, r, s))
	return results

func _get_valid_targets(shooter: Ship) -> Array:
	var valid = []
	for s in ships:
		if is_instance_valid(s) and s.side_id != shooter.side_id and not s.is_exploding:
			# Reactive Fire Tracking: Use previous path if Defensive Fire (Passive)
			var target_hexes = [s.grid_position]
			if combat_subphase == 1 and s.side_id == current_side_id:
				target_hexes.append_array(s.previous_path)
			
			var can_hit = false
			for weapon in shooter.weapons:
				if weapon["ammo"] <= 0: continue
				if weapon.get("fired", false): continue
				
				var w_range = weapon["range"]
				var w_arc = weapon["arc"]
				
				for check_hex in target_hexes:
					var d = HexGrid.hex_distance(shooter.grid_position, check_hex)
					if d > w_range: continue
					
					# LOS Check (Planet Blocking)
					var line_hexes = HexGrid.get_line_coords(shooter.grid_position, check_hex)
					var blocked = false
					for h in line_hexes:
						if h in planet_hexes:
							if h == shooter.grid_position or h == check_hex: continue
							blocked = true
							break
					
					if blocked: continue

					if w_arc == "FF":
						var valid_hexes = _get_ff_arc_hexes(shooter, w_range)
						if check_hex in valid_hexes:
							can_hit = true
							break # Found a valid hex for this FF weapon
					else:
						# Default or Turret (360)
						can_hit = true
						break
				
				if can_hit:
					break # Found a valid weapon for this target
					
			if can_hit:
				valid.append(s)
	return valid

func _handle_deployment_click(hex: Vector3i):
	if state_deployment_mine_placement:
		var valid_hexes = ScenarioManager.get_valid_deployment_hexes(deployment_subphase, ships, planet_hexes, null) # Null ship since we just want general deployment zones
		
		if valid_hexes.size() > 0 and not valid_hexes.has(hex):
			log_message("[color=red]You can only place mines inside your deployment zone![/color]")
			state_deployment_mine_placement = false # Cancel placement
			btn_deploy_mine.set_pressed_no_signal(false)
			_update_deployment_ui()
			queue_redraw()
			return
			
		if planet_hexes.has(hex):
			log_message("[color=red]Cannot deploy a mine inside a planet![/color]")
			return

		# Toggle mine logic
		if deployment_mines_placed.has(hex):
			deployment_mines_placed.erase(hex)
			log_message("Removed planned mine at %v." % hex)
		else:
			var total_capacity = 0
			for s in ships:
				if is_instance_valid(s) and s.side_id == deployment_subphase:
					for w in s.weapons:
						if w.get("type", "") == "Mine":
							total_capacity += w.get("ammo", 0)
			
			if deployment_mines_placed.size() < total_capacity:
				deployment_mines_placed.append(hex)
				log_message("Placed mine at %v." % hex)
			else:
				log_message("[color=red]You have no remaining mines to drop![/color]")
				
		_update_deployment_ui()
		queue_redraw()
		return

	if state_deployment_seeker_placement:
		var valid_hexes = ScenarioManager.get_valid_deployment_hexes(deployment_subphase, ships, planet_hexes, null) # Null ship since we just want general deployment zones
		
		if valid_hexes.size() > 0 and not valid_hexes.has(hex):
			log_message("[color=red]You can only place seekers inside your deployment zone![/color]")
			state_deployment_seeker_placement = false # Cancel placement
			if btn_deploy_seeker: btn_deploy_seeker.set_pressed_no_signal(false)
			_update_deployment_ui()
			queue_redraw()
			return
			
		if planet_hexes.has(hex):
			log_message("[color=red]Cannot deploy a seeker inside a planet![/color]")
			return

		# Toggle seeker logic
		if deployment_seekers_placed.has(hex):
			deployment_seekers_placed.erase(hex)
			log_message("Removed planned seeker at %v." % hex)
		else:
			var total_capacity = 0
			for s in ships:
				if is_instance_valid(s) and s.side_id == deployment_subphase:
					for w in s.weapons:
						if w.get("type", "") == "Seeker":
							total_capacity += w.get("ammo", 0)
			
			if deployment_seekers_placed.size() < total_capacity:
				deployment_seekers_placed.append(hex)
				log_message("Placed seeker at %v." % hex)
			else:
				log_message("[color=red]You have no remaining seekers to drop![/color]")
				
		_update_deployment_ui()
		queue_redraw()
		return


	# Enable implicit UNDO of deployed ordnance if we click an existing token without placement mode active
	if deployment_mines_placed.has(hex):
		deployment_mines_placed.erase(hex)
		log_message("Recovered deployed mine at %v." % hex)
		_update_deployment_ui()
		queue_redraw()
		return
		
	if deployment_seekers_placed.has(hex):
		deployment_seekers_placed.erase(hex)
		log_message("Recovered deployed seeker at %v." % hex)
		_update_deployment_ui()
		queue_redraw()
		return

	if not is_deploying_ship or not is_instance_valid(selected_ship):
		return
	
	# Validate bounds
	# We rely on ScenarioManager.get_valid_deployment_hexes.
	# If valid_hexes is empty, we assume no constraints (deploy anywhere)
	var valid_hexes = ScenarioManager.get_valid_deployment_hexes(deployment_subphase, ships, planet_hexes, selected_ship)
	
	if valid_hexes.size() > 0 and not valid_hexes.has(hex):
		log_message("[color=red]Invalid deployment hex location![/color]")
		return
		
	# Check collision with planet
	if planet_hexes.has(hex):
		log_message("[color=red]Cannot deploy inside a planet![/color]")
		return
	
	# Set tentative hex
	deploy_tentative_hex = hex
	deploy_hex_selected = true
	selected_ship.grid_position = deploy_tentative_hex
	selected_ship.position = HexGrid.hex_to_pixel(selected_ship.grid_position)
	
	if audio_beep and audio_beep.stream: audio_beep.play()
	queue_redraw()
	
	# Auto-commit deployment for stations (they don't need facing/speed dragging)
	if selected_ship.ship_class in ["Space Station", "Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
		_on_deploy_ship_pressed()

func _handle_movement_click(hex: Vector3i):
	print("DEBUG: _handle_movement_click called with hex: ", hex)
	
	if not selected_ship or not is_instance_valid(selected_ship):
		return
		
	# Mine Placement Logic Intercept
	if state_mine_placement:
		# Valid hexes include start position, currently plotting path, and already planned path (if orders active)
		var is_valid_hex = (hex == selected_ship.grid_position) or current_path.has(hex) or selected_ship.planned_path.has(hex)
		if not is_valid_hex:
			log_message("Mines must be dropped along your valid movement path.")
			# Left-clicking outside cancels placement mode
			state_mine_placement = false
			queue_redraw()
			return
			
		# Check if an active mine (from previous turns/ships) already exists here
		for m in active_mines:
			if m["pos"] == hex:
				log_message("A mine already exists at this location!")
				return
				
		# Toggle planned mine
		if selected_ship.planned_mines_to_drop.has(hex):
			selected_ship.planned_mines_to_drop.erase(hex)
			log_message("Removed planned mine at %v." % hex)
		else:
			# Check ammo
			var w_mine = null
			for w in selected_ship.weapons:
				if w["type"] == "Mine":
					w_mine = w
					break
			if w_mine and selected_ship.planned_mines_to_drop.size() < w_mine["ammo"]:
				selected_ship.planned_mines_to_drop.append(hex)
				log_message("Planned mine drop at %v." % hex)
			else:
				log_message("Not enough mine ammo!")
		
		# If the ship hasn't committed orders yet, push history for undo
		if not selected_ship.has_orders:
			_push_history_state()
		
		queue_redraw()
		return
		
	# Seeker Placement Logic Intercept
	if state_seeker_placement:
		var is_valid_hex = (hex == selected_ship.grid_position) or current_path.has(hex) or selected_ship.planned_path.has(hex)
		if not is_valid_hex:
			log_message("Seekers must be dropped along your valid movement path.")
			state_seeker_placement = false
			queue_redraw()
			return
			
		for s in active_seekers:
			if s["pos"] == hex:
				log_message("A seeker already exists at this location!")
				return
				
		if selected_ship.planned_seekers_to_drop.has(hex):
			selected_ship.planned_seekers_to_drop.erase(hex)
			log_message("Removed planned seeker at %v." % hex)
		else:
			var w_seeker = null
			for w in selected_ship.weapons:
				if w["type"] == "Seeker":
					w_seeker = w
					break
			if w_seeker and selected_ship.planned_seekers_to_drop.size() < w_seeker["ammo"]:
				if not "planned_seekers_to_drop" in selected_ship:
					selected_ship.planned_seekers_to_drop = []
				selected_ship.planned_seekers_to_drop.append(hex)
				log_message("Planned seeker drop at %v." % hex)
			else:
				log_message("Not enough seeker ammo!")
		
		if not selected_ship.has_orders:
			_push_history_state()
		
		queue_redraw()
		return
		
	# FIX: Prevent modifying plan if already committed/ordered (unless we were placing mines above)
	if selected_ship.has_orders:
		log_message("Ship has orders. Use Undo to change.")
		return


	# UX IMPROVEMENT 1: Self-Click to Decelerate (Speed 0)
	# If clicking own hex, and we haven't plotted a path yet.
	if hex == selected_ship.grid_position and current_path.is_empty():
		# Check if valid to stop (Speed - ADF <= 0)
		var min_speed = max(0, start_speed - selected_ship.get_effective_adf())
		if min_speed == 0:
			log_message("Requesting Full Stop (Speed 0)...")
			# Commit Empty Path = Stay in place
			_on_commit_move()
			return
		else:
			log_message("Cannot stop! Min speed is %d" % min_speed)
			return

	# UX IMPROVEMENT 2: Ghost-Click to Commit
	# If clicking the ghost (end of plotted path), commit.
	# FIX: Only if NOT previewing (Ghost is confirmed at head)
	if ghost_ship and is_instance_valid(ghost_ship) and hex == ghost_ship.grid_position and not path_preview_active:
		if not current_path.is_empty():
			log_message("Committing move via Ghost click...")
			_on_commit_move()
			return

	# MOVEMENT PRIORITY FIX:
	# MOVEMENT PRIORITY FIX:
	if selected_ship and ghost_ship and not selected_ship.has_moved:
		var forward_vec = HexGrid.get_direction_vec(ghost_head_facing)
		var dist = HexGrid.hex_distance(ghost_head_pos, hex)
		
		# Valid straight line check
		if dist > 0:
			var check_pos = ghost_head_pos + (forward_vec * dist)
			if check_pos == hex:
				_handle_ghost_input(hex)
				return

	# Check if clicked on a friendly available ship (CHANGE SELECTION)
	var clicked_ship = null
	
	# Priority 1: Unmoved Ships
	for s in ships:
		if is_instance_valid(s) and s.grid_position == hex and s.side_id == current_side_id and not s.has_moved:
			clicked_ship = s
			break
			
	# Priority 2: Moved Ships (for inspection)
	if not clicked_ship:
		for s in ships:
			if is_instance_valid(s) and s.grid_position == hex and s.side_id == current_side_id:
				clicked_ship = s
				break
	
	if clicked_ship and clicked_ship != selected_ship:
		_select_ship(clicked_ship)
		return

	# If no ship selected or clicked empty hex...
	_handle_ghost_input(hex)

func _select_ship(ship: Ship):
	selected_ship = ship
	# Reset plot
	_reset_plotting_state()
	
	if audio_ship_select and audio_ship_select.stream: audio_ship_select.play()
	_spawn_ghost()
	_update_camera()
	_update_ship_visuals() # Re-sort stack
	_update_ui_state()
	log_message("Selected %s" % selected_ship.name)


func _handle_ghost_input(hex: Vector3i):
	if not ghost_ship: return
	
	# Rule: If ship has already moved, no new input allowed (it's just for inspection)
	if selected_ship and selected_ship.has_moved:
		# log_message("Ship has already moved.")
		return

	
	# Strict Rule: Must be along Forward Vector
	var forward_vec = HexGrid.get_direction_vec(ghost_head_facing)
	
	var dist = HexGrid.hex_distance(ghost_head_pos, hex)
	print("DEBUG: ghost input dist: ", dist, " | start: ", ghost_head_pos, " | target: ", hex, " | facing: ", ghost_head_facing)
	if dist == 0: return # Clicked itself
	
	# Verify it is exactly in the forward direction
	# We can check direction index matching
	var valid_hex = false
	var check = ghost_head_pos + (forward_vec * dist)
	if check == hex:
		valid_hex = true
		
	if not valid_hex:
		# Implicit Undo / Break Orbit Rule
		# If we are orbiting (auto-plotted) and the user clicks a hex that is INVALID from the ghost,
		# but VALID from the start position (or just implies a new path), we should reset and try again.
		if state_is_orbiting:
			# Check if this click would be valid from the START position (selected_ship)
			# We effectively "Undo" then retry the input from scratch.
			# But we need to be careful not to infinite loop if it's invalid from start too.
			# Let's just Reset and try adding it as a first step?
			# But we need to handle the rotation? 
			# If user rotated the GHOST, we lose that rotation if we reset.
			# But "Break Orbit" usually implies "I want to go THERE instead".
			log_message("Breaking Orbit to move to new heading...")
			_on_undo() # Resets path, ghost, and orbit state
			
			# Now try handling input again (recursion? or just continue?)
			# Ghost is now at start.
			_handle_ghost_input(hex)
			return

		log_message("Invalid Move: Must be in line with Forward Facing")
		return

	# Check Max Speed / Path Limits
	var max_allowed_path = start_speed + selected_ship.get_effective_adf()
	if current_path.size() + dist > max_allowed_path:
		log_message("Target too far! Limit: %d hexes" % max_allowed_path)
		return

	# PUSH HISTORY for UNDO
	_push_history_state()

	# Execute Move (Loop for each step)

	var current_pos = ghost_head_pos
	
	for i in range(dist):
		var prev_hex = current_pos
		var next_hex = current_pos + forward_vec
		
		# Apply Movement First
		current_pos = next_hex
		current_path.append(next_hex)
		
		# ---- GRAVITY EXIT PENALTY LOGIC ----
		# Check if we JUST EXITED a gravity well hex.
		# This happens if `prev_hex` is adjacent to a planet.
		# Cost applies ON the current_pos (the first hex after passing through the well hex).
		if not gravity_penalty_applied_this_turn:
			var prev_is_in_well = false
			var planet_pos = Vector3i.ZERO
			for p in planet_hexes:
				if HexGrid.hex_distance(prev_hex, p) == 1:
					prev_is_in_well = true
					planet_pos = p
					break
			
			if prev_is_in_well:
				gravity_penalty_applied_this_turn = true
				
				# Deduct 1 MR
				turns_remaining -= 1
				
				# Record expenditure text visually at the CURRENT hex (after passing through)
				mr_expenditures.append({"pos": current_pos, "text": "-1 MR (Gravity) (%d of %d)" % [turns_remaining, selected_ship.mr] })
				
				# INVOLUNTARY FACING CHANGE: If MR < 0, forced turn toward planet
				if turns_remaining < 0:
					log_message("Gravity overwhelmed MR! Involuntary Facing Change down gravity well.")
					# Calculate direction to planet from our CURRENT hex
					var line_to_planet = HexGrid.get_line_coords(current_pos, planet_pos)
					var forced_facing = -1
					if line_to_planet.size() > 1:
						forced_facing = HexGrid.get_hex_direction(current_pos, line_to_planet[1])
					
					if forced_facing != -1 and forced_facing != ghost_head_facing:
						# Update the ghost's facing immediately
						ghost_ship.facing = forced_facing
						ghost_head_facing = ghost_ship.facing
						
						# Update the forward vector for the REST of this movement segment.
						# The NEXT loop iteration will use this new vector.
						forward_vec = HexGrid.get_direction_vec(ghost_head_facing)
		
		# "Usage" of turn opportunity:
		# Logic: You only get the turn opportunity for the FINAL hex entered in this sequence.
		# Intermediate hexes: You moved out of them without turning, so opportunity lost.
		# Final hex: You just entered it, so you can turn now.
	
	# Enable turning for the final step
	can_turn_this_step = true
	step_entry_facing = ghost_ship.facing # New step started with this facing
	turn_taken_this_step = 0
	
	if audio_beep.stream: audio_beep.play()
	
	# Update Head State
	ghost_head_pos = current_pos
	ghost_head_facing = ghost_ship.facing
	ghost_ship.grid_position = ghost_head_pos

	queue_redraw()
	queue_redraw()
	_update_ui_state()

# Helper
func posmod(a, b):
	var res = a % b
	if res < 0 and b > 0: res += b
	return res

func _spawn_floating_text(text: String, grid_pos: Vector2, color: Color = Color.WHITE):
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	
	lbl.position = grid_pos - Vector2(100, 40) # Center offset
	lbl.custom_minimum_size = Vector2(200, 50)
	lbl.z_index = 100
	if ui_layer:
		ui_layer.add_child(lbl)
	else:
		add_child(lbl)
	
	var tween = create_tween()
	tween.tween_property(lbl, "position", grid_pos - Vector2(100, 100), 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(lbl.queue_free)

func _trigger_icm_decision(attacker_name: String, weapon_name: String, weapon_type: String, current_chance: int, target: Ship, eligible_ships: Array = []):
	print(">>> TRIGGER ICM TOP. Target=", target.name if target else "NULL")
	var eligible_names = []
	for s in eligible_ships:
		if is_instance_valid(s):
			eligible_names.append(s.name)
			
	if eligible_names.is_empty() and is_instance_valid(target):
		eligible_names.append(target.name)
		
	print(">>> TRIGGER ICM MID: is_networked=", _is_networked())
	if _is_networked() and multiplayer.is_server():
		rpc_trigger_icm_decision.rpc(attacker_name, weapon_name, weapon_type, current_chance, target.name, eligible_names)
	else:
		rpc_trigger_icm_decision(attacker_name, weapon_name, weapon_type, current_chance, target.name, eligible_names)
		
@rpc("authority", "call_local", "reliable")
func rpc_trigger_icm_decision(attacker_name: String, weapon_name: String, weapon_type: String, current_chance: int, target_name: String, eligible_ship_names: Array):
	print(">>> DEBUG RPC ICM: Target Name string = ", target_name)
	var target = _find_ship_by_name(target_name)
	if not target: 
		print(">>> DEBUG RPC ICM: TARGET NOT FOUND!")
		return
	
	var eligible_ships = []
	for n in eligible_ship_names:
		var s = _find_ship_by_name(n)
		if s: eligible_ships.append(s)

	# Fallback if eligible_ships not properly passed
	if eligible_ships.is_empty():
		print(">>> DEBUG RPC ICM: EMPTY ELIGIBLE SHIPS, falling back to target.")
		eligible_ships = [target]
		
	# --- AI AUTO-RESOLUTION HOOK ---
	# Check if the target ship's side is controlled by a ComputerOpponent
	var is_ai_target = false
	for ai in computer_opponents:
		if is_instance_valid(ai) and ai.side_id == target.side_id:
			is_ai_target = true
			break
			
	print(">>> DEBUG RPC ICM: IS AI TARGET = ", is_ai_target)
			
	if is_ai_target and _is_server_or_offline():
		# The server automatically resolves AI ICM decisions without UI
		var icm_script = load("res://Scripts/AutoIcmProcessor.gd")
		var allocations = icm_script.calculate_allocations(weapon_type, current_chance, target, eligible_ships)
		# Add a slight delay for better game feel/pacing so it doesn't instantly blink past
		await get_tree().create_timer(1.0).timeout
		_submit_icm_decision(allocations)
		return
		
	# --- HUMAN UI MODAL ---
	if panel_icm: panel_icm.queue_free()
	
	panel_icm = PanelContainer.new()
	ui_layer.add_child(panel_icm)
	panel_icm.set_anchors_preset(Control.PRESET_CENTER)
	
	# Add style for readability
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.95) # Dark blue opaque
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 0.5, 0) # Orange border
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.expand_margin_left = 10
	style.expand_margin_right = 10
	style.expand_margin_top = 10
	style.expand_margin_bottom = 10
	
	panel_icm.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	panel_icm.add_child(vbox)
	
	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	
	# Network Logic: Who decides?
	var is_target_owner = (target.side_id == my_side_id) or (my_side_id == 0) # Debug/0 can also decide
	
	if is_target_owner and not is_ai_target:
		var ship_spinboxes = {} # Dictionary of ship_name -> SpinBox node
		
		# Initial Text updater
		var update_text = func():
			var total_icm = 0
			for spin in ship_spinboxes.values():
				total_icm += int(spin.value)
				
			var reduction = Combat.calculate_icm_reduction(weapon_type, total_icm)
			var final_chance = max(0, current_chance - reduction)
			lbl.text = "INCOMING FIRE DETECTED!\nTarget: %s\n%s firing %s\nBase Chance: %d%% -> Adjusted: %d%%" % [target.name, attacker_name, weapon_name, current_chance, final_chance]
		
		# Add a row for each eligible ship
		for ship in eligible_ships:
			var hbox = HBoxContainer.new()
			vbox.add_child(hbox)
			
			var lbl_ship = Label.new()
			lbl_ship.text = "%s (Available: %d)" % [ship.name, ship.icm_current]
			lbl_ship.custom_minimum_size = Vector2(200, 0)
			hbox.add_child(lbl_ship)
			
			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = ship.icm_current
			spin.value = 0
			spin.select_all_on_focus = true
			hbox.add_child(spin)
			
			spin.value_changed.connect(func(_val): update_text.call())
			ship_spinboxes[ship.name] = spin
			
		# Call once to set initial text
		update_text.call()

		var btn_box = HBoxContainer.new()
		btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(btn_box)
		
		var btn_fire = Button.new()
		btn_fire.text = "LAUNCH ICM(s)!"
		btn_box.add_child(btn_fire)
		
		var btn_skip = Button.new()
		btn_skip.text = "DO NOT FIRE"
		btn_box.add_child(btn_skip)
		
		# Connect signals
		btn_fire.pressed.connect(func():
			var allocations = {}
			for s_name in ship_spinboxes:
				var val = int(ship_spinboxes[s_name].value)
				if val > 0:
					allocations[s_name] = val
					
			_submit_icm_decision(allocations)
		)
		
		btn_skip.pressed.connect(func(): _submit_icm_decision({}))
		
	else:
		# Waiting Message
		var reduction = Combat.calculate_icm_reduction(weapon_type, 0)
		var final_chance = max(0, current_chance - reduction)
		lbl.text = "INCOMING FIRE DETECTED!\nTarget: %s\n%s firing %s\nBase Chance: %d%% -> Adjusted: %d%%" % [target.name, attacker_name, weapon_name, current_chance, final_chance]
		var lbl_wait = Label.new()
		lbl_wait.text = "\n(Waiting for Defender to decide on ICMs...)"
		lbl_wait.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(lbl_wait)

func get_side_name(side_id: int) -> String:
	# Side ID 1 = Scenario Index 0 (Attackers/P1)
	# Side ID 2 = Scenario Index 1 (Defenders/P2)
	# Assuming 1-based Side ID maps to 0-based Array Index
	var scen_key = "surprise_attack"
	if NetworkManager.lobby_data != null:
		scen_key = NetworkManager.lobby_data.get("scenario", "surprise_attack")
	var scen = ScenarioManager.get_scenario(scen_key)
	if scen and scen.has("sides"):
		var side_idx = side_id - 1
		if scen["sides"].has(side_idx):
			return scen["sides"][side_idx]["name"]
			
	return "Side %d" % side_id

func _submit_icm_decision(allocations: Dictionary):
	# Send RPC to broadcast decision
	if _is_networked() and not _is_server_or_offline():
		broadcast_icm_decision.rpc(allocations)
	elif _is_networked() and _is_server_or_offline():
		broadcast_icm_decision.rpc(allocations)
	else:
		broadcast_icm_decision(allocations)

@rpc("any_peer", "call_local", "reliable")
func broadcast_icm_decision(allocations: Dictionary):
	print("DEBUG: broadcast_icm_decision called on peer %d" % (multiplayer.get_unique_id() if _is_networked() else 1))
	# Close UI on all clients
	if panel_icm:
		panel_icm.queue_free()
		panel_icm = null
		
	# Sync state for the waiting coroutine
	_icm_current_allocations = allocations
	_icm_decision_received = true
	
	# Keep emit for external tests/callbacks
	icm_decision_made.emit(allocations)

func _on_ship_destroyed(ship: Ship):
	if not campaign_casualties.has(ship):
		campaign_casualties.append(ship)
	ships.erase(ship)
	_update_ship_visuals() # Re-calc stacks
	log_message("Ship destroyed: %s" % ship.name)
	_check_victory()

func _check_victory():
	# Check for Victory
	var s1_count = 0
	var s2_count = 0
	for s in ships:
		if not is_instance_valid(s): continue
		if s.is_destroyed: continue # Just in case it's still in the list but destroyed
		if s.side_id == 1: s1_count += 1
		elif s.side_id == 2: s2_count += 1
	
	if s1_count == 0 and s2_count == 0:
		if NetworkManager.lobby_data != null and NetworkManager.lobby_data.get("scenario", "") == "campaign_encounter":
			_show_battle_summary("Draw!", 0)
		else:
			show_game_over("Draw!")
	elif s1_count == 0:
		var winner_name = get_side_name(2)
		if NetworkManager.lobby_data != null and NetworkManager.lobby_data.get("scenario", "") == "campaign_encounter":
			_show_battle_summary("VICTORY", 2)
		else:
			show_game_over("Winner: " + winner_name + "!")
	elif s2_count == 0:
		var winner_name = get_side_name(1)
		if NetworkManager.lobby_data != null and NetworkManager.lobby_data.get("scenario", "") == "campaign_encounter":
			_show_battle_summary("VICTORY", 1)
		else:
			show_game_over("Winner: " + winner_name + "!")

func show_game_over(msg: String):
	current_phase = Phase.END
	label_winner.text = msg
	
	if NetworkManager.lobby_data != null and NetworkManager.lobby_data.get("scenario", "") == "campaign_encounter":
		if is_instance_valid(btn_restart):
			btn_restart.text = "Return to Campaign Map"
		if _is_server_or_offline():
			_sync_campaign_results()
			
	panel_game_over.visible = true
	_update_ui_state()
	log_message(msg)

var panel_summary: PanelContainer
var lbl_summary_title: Label
var vbox_summary_upf: VBoxContainer
var vbox_summary_sathar: VBoxContainer
var btn_summary_return: Button

func _build_summary_panel():
	panel_summary = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	panel_summary.add_theme_stylebox_override("panel", style)
	
	panel_summary.set_anchors_preset(Control.PRESET_CENTER)
	panel_summary.visible = false # Hidden initially
	
	var vbox_main = VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_child(vbox_main)
	panel_summary.add_child(margin)
	
	lbl_summary_title = Label.new()
	lbl_summary_title.add_theme_font_size_override("font_size", 32)
	lbl_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_main.add_child(lbl_summary_title)
	
	var hbox_cols = HBoxContainer.new()
	hbox_cols.add_theme_constant_override("separation", 50)
	hbox_cols.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_main.add_child(hbox_cols)
	
	vbox_summary_upf = VBoxContainer.new()
	var lbl_upf_col = Label.new()
	lbl_upf_col.text = "UPF Casualties"
	lbl_upf_col.add_theme_color_override("font_color", Color.CORNFLOWER_BLUE)
	lbl_upf_col.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_summary_upf.add_child(lbl_upf_col)
	hbox_cols.add_child(vbox_summary_upf)
	
	vbox_summary_sathar = VBoxContainer.new()
	var lbl_sathar_col = Label.new()
	lbl_sathar_col.text = "Sathar Casualties"
	lbl_sathar_col.add_theme_color_override("font_color", Color.CRIMSON)
	lbl_sathar_col.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_summary_sathar.add_child(lbl_sathar_col)
	hbox_cols.add_child(vbox_summary_sathar)
	
	btn_summary_return = Button.new()
	btn_summary_return.text = "Return to Campaign Map"
	btn_summary_return.pressed.connect(func():
		if _is_server_or_offline():
			_sync_campaign_results()
		_on_restart()
	)
	
	var center_btn = CenterContainer.new()
	center_btn.add_child(btn_summary_return)
	vbox_main.add_child(center_btn)
	
	ui_layer.add_child(panel_summary)

func _show_battle_summary(title_text: String, side_id: int):
	current_phase = Phase.END
	_update_ui_state() # Hide standard tactical UI frames
	
	if side_id == 1:
		lbl_summary_title.text = "UPF VICTORY"
		lbl_summary_title.add_theme_color_override("font_color", Color.CORNFLOWER_BLUE)
	elif side_id == 2:
		lbl_summary_title.text = "SATHAR VICTORY"
		lbl_summary_title.add_theme_color_override("font_color", Color.CRIMSON)
	else:
		lbl_summary_title.text = title_text
		lbl_summary_title.add_theme_color_override("font_color", Color.WHITE)
		
	# Clear previous casualty lists (keep the headers)
	for i in range(1, vbox_summary_upf.get_child_count()):
		vbox_summary_upf.get_child(i).queue_free()
	for i in range(1, vbox_summary_sathar.get_child_count()):
		vbox_summary_sathar.get_child(i).queue_free()
		
	var all_ships = []
	all_ships.append_array(ships)
	all_ships.append_array(campaign_casualties)
	
	for s in all_ships:
		if not is_instance_valid(s): continue
		
		# Define status
		var status_str = ""
		var col = Color.WHITE
		if s.is_destroyed or s.hull <= 0:
			status_str = "Destroyed"
			col = Color.RED
		else:
			# Check crippled vs Damaged
			var crippled = false
			if s.adf > 0 and s.get_effective_adf() <= 0:
				crippled = true # Engines broken completely
			else:
				var unrepairable_count = 0
				if "weapons" in s:
					for w in s.weapons:
						if typeof(w) == TYPE_DICTIONARY and w.get("is_crippled", false): unrepairable_count += 1
					if s.weapons.size() > 0 and unrepairable_count == s.weapons.size():
						crippled = true # All weapons broken
					
			if crippled:
				status_str = "Crippled"
				col = Color.ORANGE
			elif (s.hull < s.max_hull) or (s.current_adf_modifier > 0) or (s.current_mr_modifier > 0) or s.has_electrical_fire or s.has_disastrous_fire or s.ccs_damaged or (s.icm_max < s.base_icm_max) or (s.ms_max < s.base_ms_max):
				status_str = "Damaged"
				col = Color.YELLOW
				
		if status_str != "":
			var lbl = Label.new()
			lbl.text = "[%s] %s" % [status_str, s.name]
			lbl.add_theme_color_override("font_color", col)
			if s.side_id == 1:
				vbox_summary_upf.add_child(lbl)
			else:
				vbox_summary_sathar.add_child(lbl)
				
	panel_summary.visible = true

func _get_faction_for_side(side_id: int) -> String:
	# Side 1 is typically UPF in campaigns, Side 2 is Sathar.
	# But we can check scenario data directly
	var scen_key = "surprise_attack"
	if NetworkManager.lobby_data != null:
		scen_key = NetworkManager.lobby_data.get("scenario", "surprise_attack")
	var scen = ScenarioManager.get_scenario(scen_key)
	
	if scen and scen.has("sides"):
		var side_idx = side_id - 1
		if scen["sides"].has(side_idx):
			var faction_str = scen["sides"][side_idx].get("faction", "")
			if faction_str != "":
				return faction_str
			var team_name = scen["sides"][side_idx].get("name", "")
			if "UPF" in team_name or "Militia" in team_name: return "UPF"
			if "Sathar" in team_name: return "Sathar"
			
	return "Sathar" if side_id == 2 else "UPF"

func _sync_campaign_results():
	log_message("[color=cyan]=== AFTERMATH: REPAIRS AND SYNC ===[/color]")
	
	for s in ships:
		if not is_instance_valid(s): continue
		if s.is_destroyed or s.hull <= 0: continue
			
		var damage_keys = AutoRepairProcessor._get_repairable_keys(s)
		for dk in damage_keys:
			var roll = randi() % 100 + 1
			var chance = s.max_dcr
			if roll <= chance:
				_apply_repair(s, dk)
				log_message("[color=green]%s repaired %s (Roll: %d <= %d)[/color]" % [s.name, dk, roll, chance])
			else:
				if roll >= 99:
					_mark_unrepairable(s, dk)
					log_message("[color=red]%s permanently damaged %s (Roll: %d)[/color]" % [s.name, dk, roll])
				else:
					if dk == "hull": s.unrepairable_hull = true
					log_message("[color=yellow]%s failed to repair %s (Roll: %d)[/color]" % [s.name, dk, roll])
					
		if s.has_electrical_fire or s.has_disastrous_fire:
			log_message("[color=red]%s was consumed by unresolved fires and destroyed![/color]" % s.name)
			s.is_destroyed = true
			s.hull = 0
			
	var sys_name = ""
	if NetworkManager.lobby_data != null:
		sys_name = NetworkManager.lobby_data.get("encounter_system", "")
		
	# Process Space Station / Fortress destruction
	var all_ships = ships.duplicate()
	all_ships.append_array(campaign_casualties)
	for s in all_ships:
		if not is_instance_valid(s): continue
		if s.is_destroyed or s.hull <= 0:
			log_message("DEBUG: Processing destroyed ship: %s, class: %s" % [s.name, s.ship_class])
			
			var is_station_node = false
			if "Station" in s.name or "Fortress" in s.name:
				is_station_node = true
			if s.ship_class in ["Space Station", "Armed Station", "Fortified Station", "Space Station (Fortress)"]:
				is_station_node = true
				
			if is_station_node:
				log_message("DEBUG: Ship identified as Station/Fortress!")
				
				# Use substring matching just in case sys_name has trailing spaces or was modified
				var removed = false
				
				# 1. Try Fortresses First
				if not removed:
					for f_name in CampaignManager.UPF_FORTRESSES:
						if f_name in s.name or s.name in f_name or sys_name in f_name:
							# Match found! It's a related fortress.
							if s.ship_class in ["Fortified Station", "Space Station (Fortress)", "Space Station"]:
								CampaignManager.UPF_FORTRESSES.erase(f_name)
								CampaignManager.destroyed_fortresses_count += 1
								log_message("[color=red]Campaign updated: Fortress %s was destroyed![/color]" % f_name)
								removed = true
								break
				
				# 2. Try Armed Stations
				if not removed:
					for i in range(CampaignManager.UPF_ARMED_STATIONS.size() - 1, -1, -1):
						var a_name = CampaignManager.UPF_ARMED_STATIONS[i]
						if a_name in s.name or s.name in a_name or sys_name in a_name:
							# Match found! It's a related armed station.
							if s.ship_class in ["Space Station", "Armed Station"]:
								CampaignManager.UPF_ARMED_STATIONS.remove_at(i)
								CampaignManager.destroyed_stations_count += 1
								log_message("[color=red]Campaign updated: Armed Station at %s was destroyed![/color]" % a_name)
								removed = true
								break
			
	# Update CampaignManager fleets
	log_message("DEBUG: Starting CampaignManager fleets update loop")
	for f in CampaignManager.fleets:
		if f.current_system_id == sys_name and not f.is_moving():
			log_message("DEBUG: Processing fleet at %s: %s" % [sys_name, f.fleet_name])
			for i in range(f.ships.size() - 1, -1, -1):
				var c_ship = f.ships[i]
				var c_name = c_ship.get("name", "")
				var c_faction = f.faction
				
				var tac_ship = null
				for s in all_ships: # CHANGED from ships to all_ships so we can correctly update damage for dead ships before removing them (or we can just use tac_ship to verify death)
					if is_instance_valid(s) and s.name == c_name and _get_faction_for_side(s.side_id) == c_faction:
						tac_ship = s
						break
						
				if tac_ship == null or tac_ship.is_destroyed or tac_ship.hull <= 0:
					log_message("DEBUG: Removing destroyed ship from fleet: %s" % c_name)
					f.ships.remove_at(i)
					log_message("[color=red]Campaign updated: %s destroyed/removed from fleet.[/color]" % c_name)
				else:
					c_ship["hull"] = tac_ship.hull
					c_ship["max_hull"] = tac_ship.max_hull
					c_ship["current_adf_modifier"] = tac_ship.current_adf_modifier
					c_ship["unrepairable_adf_modifier"] = tac_ship.unrepairable_adf_modifier
					c_ship["current_mr_modifier"] = tac_ship.current_mr_modifier
					c_ship["unrepairable_mr_modifier"] = tac_ship.unrepairable_mr_modifier
					c_ship["has_electrical_fire"] = tac_ship.has_electrical_fire
					c_ship["has_disastrous_fire"] = tac_ship.has_disastrous_fire
					c_ship["unrepairable_electrical_fire"] = tac_ship.unrepairable_electrical_fire
					c_ship["unrepairable_disastrous_fire"] = tac_ship.unrepairable_disastrous_fire
					c_ship["ccs_damaged"] = tac_ship.ccs_damaged
					c_ship["unrepairable_ccs"] = tac_ship.unrepairable_ccs
					c_ship["icm_max"] = tac_ship.icm_max
					c_ship["icm_current"] = tac_ship.icm_current
					c_ship["unrepairable_icm"] = tac_ship.unrepairable_icm
					c_ship["ms_max"] = tac_ship.ms_max
					c_ship["ms_current"] = tac_ship.ms_current
					c_ship["unrepairable_ms"] = tac_ship.unrepairable_ms
					
					if c_ship.has("weapons"):
						for w_idx in range(c_ship["weapons"].size()):
							if w_idx < tac_ship.weapons.size():
								var cw = c_ship["weapons"][w_idx]
								var tw = tac_ship.weapons[w_idx]
								if tw != null and typeof(tw) == TYPE_DICTIONARY:
									cw["ammo"] = tw.get("ammo", 0)
									cw["is_crippled"] = tw.get("is_crippled", false)
									cw["unrepairable"] = tw.get("unrepairable", false)
					
	log_message("DEBUG: Finished fleet updates. Cleaning up empty fleets.")
					
	for i in range(CampaignManager.fleets.size() - 1, -1, -1):
		if CampaignManager.fleets[i].ships.size() == 0:
			CampaignManager.fleets.remove_at(i)
			
	if CampaignManager.active_encounters.has(sys_name):
		CampaignManager.active_encounters.erase(sys_name)
		
	if _is_networked():
		NetworkManager.sync_campaign_state.rpc(CampaignManager.serialize_state())
	else:
		CampaignManager.emit_signal("campaign_state_updated")

func _on_restart():
	if NetworkManager.lobby_data != null and NetworkManager.lobby_data.get("scenario", "") == "campaign_encounter":
		# Clear the active encounter from the campaign manager? 
		# If CampaignManager is singletons/autoloads, we might need to remove the resolved encounter.
		# For now, just return to the map. The map might prompt again if the encounter isn't cleared!
		get_tree().change_scene_to_file("res://Scenes/CampaignMap.tscn")
	else:
		get_tree().reload_current_scene()

func end_turn():
	if current_phase == Phase.END: return

	if audio_action_complete and audio_action_complete.stream:
		audio_action_complete.play()
	
	if current_phase == Phase.MOVEMENT:
		start_movement_phase() # Loop to next ship
		
	elif current_phase == Phase.COMBAT:
		# Legacy: Combat flow is now handled by Planning UI and Execute button
		if selected_ship: selected_ship.has_fired = true
		log_message("Turn ending...")
		# If somehow called, just ensure UI is updated
		_update_planning_ui_list()

func _spawn_planets():
	# seed(seed_val) # Reverted to no-arg
	for hex in planet_hexes:
		var pos = HexGrid.hex_to_pixel(hex)
		
		# Visual Container
		var p_node = Node2D.new()
		p_node.position = pos
		p_node.z_index = -1 # Background object
		add_child(p_node)
		
		# Try to load sprite, fallback to shape
		var sprite = Sprite2D.new()
		# Randomly pick from planet1..planet6 if available. For now just planet1.
		# Note: In a real scenario we'd check availability.
		# Assuming texture names: "res://Assets/planet1.png"
		# To be safe against missing files, we check file existence or just TryLoad.
		var tex = load("res://Assets/planet1.png")
		if tex:
			sprite.texture = tex
			# Scale to fit hex? 
			# Tile Size is roughly radius. Planet should probably fit inside or slightly overlap.
			var target_size = HexGrid.TILE_SIZE * 1.8
			var s = target_size / tex.get_size().x
			sprite.scale = Vector2(s, s)
			p_node.add_child(sprite)
		else:
			# Fallback Visual (Circle)
			var poly = Polygon2D.new()
			var points = PackedVector2Array()
			var radius = HexGrid.TILE_SIZE * 0.9
			for i in range(32):
				var angle = i * TAU / 32.0
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			poly.polygon = points
			poly.color = Color(0.2, 0.6, 0.8) # Earth-ish Blue
			p_node.add_child(poly)

			# Label
			var lbl = Label.new()
			lbl.text = "PLANET"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.position = Vector2(-20, -10)
			p_node.add_child(lbl)

func _check_planet_collision(ship: Ship):
	if ship.grid_position in planet_hexes:
		log_message("%s flew into a Planet and was destroyed!" % ship.name)
		
		# Trigger visual explosion (Ship handles self-queue_free after particles)
		ship.trigger_explosion()

		# Play Sound
		if audio_hit.stream: audio_hit.play()
		
		# Logic Removal
		_on_ship_destroyed(ship)
		
		# Stop movement path if this happened mid-move
		return true
	return false

func _update_minimap_position():
	pass

func load_scenario(key: String, seed_val: int = 12345):
	game_seed = seed_val
	# Retrieve Scenario Data
	var scen_dataset = ScenarioManager.generate_scenario(key, seed_val)
	# Handle case where generate_scenario returns empty but SCENARIOS has it (static)
	if scen_dataset.is_empty():
		scen_dataset = ScenarioManager.get_scenario(key)
		
	if scen_dataset.is_empty():
		log_message("Error: Scenario %s not found!" % key)
		return
		
	log_message("Loading Scenario: %s" % scen_dataset.get("name", "Unknown"))
	current_scenario_rules = scen_dataset.get("special_rules", [])
	
	# Clear Existing Ships
	for s in ships:
		if is_instance_valid(s):
			s.queue_free()
	ships.clear()
	
	# Instantiate Ships (Pass 1)
	var ship_list = scen_dataset.get("ships", [])
	for data in ship_list:
		var s = load("res://Scripts/Ship.gd").new()
		add_child(s)
		
		# Configure Class
		var cls = data.get("class", "Fighter")
		match cls:
			"Station", "Space Station": s.configure_space_station()
			"Armed Station": s.configure_armed_station()
			"Fortified Station": s.configure_fortified_station()
			"Fighter": s.configure_fighter()
			"Assault Scout": s.configure_assault_scout()
			"Frigate": s.configure_frigate()
			"Minelayer": s.configure_minelayer()
			"Destroyer": s.configure_destroyer()
			"Light Cruiser": s.configure_light_cruiser()
			"Heavy Cruiser": s.configure_heavy_cruiser()
			"Battleship": s.configure_battleship()
			"Assault Carrier": s.configure_assault_carrier()
			"Civilian": s.configure_civilian_ship()
			"Shuttle": s.configure_shuttle()
			_:
				log_message("Unknown class %s, defaulting to Scout" % cls)
				s.configure_assault_scout()
				
		# Base Properties
		s.name = data.get("name", "Ship")
		s.faction = data.get("faction", "UPF")
		# Handle side/side_index variance
		var s_idx = data.get("side", data.get("side_index", 0))
		s.side_id = s_idx + 1 # 0->1, 1->2
		
		var side_info = scen_dataset.get("sides", {}).get(s_idx, {})

		s.color = side_info.get("color", Color.WHITE)
		if data.has("color"): s.color = data["color"]
		
		# Handle pos/position variance
		s.grid_position = data.get("position", data.get("pos", Vector3i.ZERO))
		s.facing = data.get("facing", 0)
		s.orbit_direction = data.get("orbit_direction", 0)
		if s.orbit_direction != 0:
			print("[DEBUG] Ship %s loaded with Orbit Dir %d" % [s.name, s.orbit_direction])
		s.speed = data.get("start_speed", 0)
		# if s.speed > 0: s.has_moved = true # FIX: Do not skip turn just because we have speed
		
		# Stats Overrides (Crucial for Fortress K'zdit)
		if data.has("overrides"):
			var ov = data["overrides"]
			# Special handling for nested 'weapons' override if needed, 
			# but Ship.gd doesn't auto-merge deep dicts by default.
			# If 'weapons' is in override, we replace the whole list?
			# Yes, set() usually replaces.
			# But for 'weapons', we need to duplicate?
			for k in ov:
				var val = ov[k]
				if val is Array or val is Dictionary:
					s.set(k, val.duplicate(true))
				else:
					s.set(k, val)
				
		s.finalize_configuration()
		
		# Assign Ownership from Lobby
		var owner_pid = 0
		if NetworkManager.lobby_data != null and NetworkManager.lobby_data.has("ship_assignments"):
			owner_pid = NetworkManager.lobby_data["ship_assignments"].get(s.name, 0)
		
		# Default Assignment Logic (Fallback)
		if owner_pid == 0:
			# Try to find a player on this team
			var potential_owners = []
			for pid in NetworkManager.lobby_data["teams"]:
				if NetworkManager.lobby_data["teams"][pid] == s.side_id:
					potential_owners.append(pid)
			
			if potential_owners.size() > 0:
				potential_owners.sort() # Consistent assignment (lowest ID first)
				owner_pid = potential_owners[0]
			else:
				# Fallback to Host (1) if no one on team
				owner_pid = 1
				
		s.owner_peer_id = owner_pid
		
		s.binding_pos_update()
		s.ship_destroyed.connect(func(): _on_ship_destroyed(s))
		ships.append(s)
		
	# Docking (Pass 2)
	for data in ship_list:
		if data.has("docked_at"):
			var host_name = data["docked_at"]
			var host = null
			for cand in ships:
				if not is_instance_valid(cand): continue
				if cand.name == host_name:
					host = cand
					break
			
			if host:
				var s_name = data["name"]
				var s = null
				for cand in ships:
					if not is_instance_valid(cand): continue
					if cand.name == s_name:
						s = cand
						break
				
				if s:
					s.dock_at(host)
					log_message("%s docked at %s" % [s.name, host.name])
					
	# Pass 3: Initialize Space Station Rearm Capacity
	# A space station carries a re-arm capacity of x2 per fighter group stationed
	for s in ships:
		if is_instance_valid(s) and s.ship_class in ["Space Station", "Armed Station", "Fortified Station"]:
			s.rearm_capacity = s.docked_guests.size() * 2

	_update_ship_visuals()

func _check_scenario_debuffs(ship: Ship, action: String) -> bool:
	if not is_instance_valid(ship): return false
	
	for rule in current_scenario_rules:
		if rule["type"] == "linked_state_debuff":
			if rule["target_name"] == ship.name:
				# Check debuff list
				if action in rule["debuffs"]:
					# Check Trigger
					var trigger = null
					for s in ships:
						if is_instance_valid(s) and s.name == rule["trigger_name"]:
							trigger = s
							break
					
					if trigger:
						var condition = rule["trigger_condition"]
						var active = false
						if condition == "undocked":
							active = not trigger.is_docked
						elif condition == "docked":
							active = trigger.is_docked
							
						# Check Secondary Property Condition (if defined)
						if active and rule.has("condition_property"):
							var prop = rule["condition_property"]
							var min_val = rule.get("condition_min_value", 0)
							var actual_val = trigger.get(prop)
							
							if actual_val != null and actual_val < min_val:
								active = false # Condition not met (e.g. not enough turns docked)

							
						if active:
							log_message("Action '%s' blocked by scenario rule!" % action)
							return true # Debuff IS active, so action is blocked
	
	return false

# Sync Logic for Attack Planning
func _find_ship_by_name(n: String) -> Ship:
	for s in ships:
		if is_instance_valid(s) and s.name == n: return s
	return null

@rpc('any_peer', 'call_local', 'reliable')
func rpc_add_attack(source_name: String, target_name: String, weapon_idx: int):
	var s = _find_ship_by_name(source_name)
	var t = _find_ship_by_name(target_name)
	
	if not s or not t:
		print('Error: Could not find ships for rpc_add_attack: %s -> %s' % [source_name, target_name])
		return
		
	var weapon = s.weapons[weapon_idx]
	
	# Check duplicates just in case (though remove should have handled it)
	for i in range(queued_attacks.size() - 1, -1, -1):
		var atk = queued_attacks[i]
		if atk['source'] == s and atk['weapon_idx'] == weapon_idx:
			queued_attacks.remove_at(i)
			break

	queued_attacks.append({
		'source': s,
		'target': t,
		'target_pos': t.position,
		'weapon_idx': weapon_idx,
		'weapon_name': weapon['name']
	})
	
	_update_ui_state()
	_update_planning_ui_list()
	queue_redraw()
	
# STATE SYNC LOGIC
func broadcast_game_state():
	# Only Authority (Server/Host) should broadcast state
	if _is_networked() and not multiplayer.is_server():
		return
		
	var state_data = {}
	for s in ships:
		if is_instance_valid(s):
			state_data[s.name] = s.get_net_state()
			
	if _is_networked():
		rpc_sync_ship_states.rpc(state_data)
	else:
		# Local singleplayer (or just testing)
		pass

@rpc("authority", "call_local", "reliable")
func rpc_sync_ship_states(data: Dictionary):
	# log_message("Syncing Ship States...")
	for ship_name in data:
		var s_data = data[ship_name]
		var s = _find_ship_by_name(ship_name)
		if s:
			s.apply_net_state(s_data)
		else:
			# Ship might be missing (desync?) result of destruction?
			# In full sync we might want to spawn it?
			# For now, just ignore.
			pass

	
	_update_ship_visuals()
	_update_ui_state() # Update Status Label (Planned Attacks List)
	_update_planning_ui_list()
	queue_redraw()

@rpc('any_peer', 'call_local', 'reliable')
func rpc_remove_attack(source_name: String, weapon_idx: int):
	var s = _find_ship_by_name(source_name)
	if not s: return
	
	for i in range(queued_attacks.size() - 1, -1, -1):
		var atk = queued_attacks[i]
		var match_idx = atk['weapon_idx']
		if atk['source'] == s and match_idx == weapon_idx:
			queued_attacks.remove_at(i)
			break
			
	_update_ui_state() # Update Status Label (Planned Attacks List)
	_update_planning_ui_list()
	queue_redraw()

func _load_planets_from_scenario(scen_key: String):
	var scen = ScenarioManager.get_scenario(scen_key)
	
	# Clear existing visual nodes (if any)
	# Assuming planet visuals are named "Planet_X"
	for c in get_children():
		if c.name.begins_with("Planet_"):
			c.queue_free()
	
	planet_hexes = []
	if scen.has("planets"):
		planet_hexes.clear()
		for h in scen["planets"]:
			planet_hexes.append(h)
	elif scen_key == "surprise_attack":
		# Fallback for backward compatibility if ScenarioManager update failed or crossed wires
		planet_hexes = [Vector3i(0, 0, 0)]
		
	_spawn_planets_visuals()

func _spawn_planets_visuals():
	var idx = 0
	for hex in planet_hexes:
		var s = Sprite2D.new()
		s.name = "Planet_%d" % idx
		# Pick random texture or deterministic based on hex?
		# Deterministic for sync?
		var tex_idx = (abs(hex.x + hex.y * 10) % 6) + 1
		s.texture = load("res://Assets/planet%d.png" % tex_idx)
		
		s.position = HexGrid.hex_to_pixel(hex)
		
		# Scale: Texture size unknown, assume 256ish.
		# TILE_SIZE = 65. Diameter = 130.
		# Scale to fill 80% of hex?
		if s.texture:
			var size = s.texture.get_size()
			var target_size = HexGrid.TILE_SIZE * 1.5
			var scale_fac = target_size / max(size.x, size.y)
			s.scale = Vector2(scale_fac, scale_fac)
			
		s.z_index = -1 # Background
		add_child(s)
		idx += 1

func _handle_mouse_facing(hex: Vector3i):
	# Only update if we can turn OR if we are just pivoting before moving?
	if not ghost_ship: return
	
	# Scenario rule lock
	var scen_key = "simple_test"
	if NetworkManager.lobby_data != null:
		scen_key = NetworkManager.lobby_data.get("scenario", "simple_test")
	if scen_key == "close_escort" and is_instance_valid(selected_ship) and selected_ship.name == "Megasaurus":
		return
	
	# Determine relative direction from ghost
	var dist = HexGrid.hex_distance(ghost_ship.grid_position, hex)
	if dist != 1: return # Only react to adjacent hexes for "Look at" logic
	
	var dir_idx = HexGrid.get_hex_direction(ghost_ship.grid_position, hex)
	if dir_idx == -1: return
	
	# Calculate relative turn
	# current facing = f
	# target facing = dir_idx
	# diff = (dir_idx - f + 6) % 6
	# 0 = Forward, 1 = Right, 5 = Left. Others are invalid for standard movement.
	
	# 1. Start of Turn, Speed 1
	# Moving ships start with can_turn_this_step = false (must move first)
	
	# Speed 0 / Orbit Exception: Allow free rotation
	var is_stationary = (current_path.size() == 0 and start_speed == 0)
	if is_stationary or state_is_orbiting:
		if not state_is_orbiting and is_instance_valid(selected_ship) and selected_ship.get_effective_mr() <= 0:
			return # Ships with 0 MR cannot rotate freely
			
		ghost_ship.facing = dir_idx
		ghost_head_facing = ghost_ship.facing # FIX: Ensure logic tracks the new facing!
		ghost_ship.queue_redraw()
		queue_redraw()
		_update_ui_state()
		return

	# Logic:
	
	# RESTRICTION: Moving ships (Speed > 0) cannot turn before moving at least 1 hex.
	if current_path.size() == 0 and start_speed > 0:
		return
		
	# diff 1 = Right, diff 5 = Left
	
	# DERIVED STATE REFACTOR
	# Instead of using 'step_entry_facing' and 'turn_taken_this_step' vars,
	# we calculate limits dynamically.
	
	var entry_facing = _get_step_entry_facing()
	
	# Validate Rotation Limit (1 hex side per step)
	# Allowed facings: Entry, Entry+1 (Right), Entry-1 (Left)
	
	var diff_from_entry = posmod(dir_idx - entry_facing, 6)
	var is_valid_turn = (diff_from_entry == 0) or (diff_from_entry == 1) or (diff_from_entry == 5)
	
	if not is_valid_turn:
		# If speed 0, we might allow more? 
		if start_speed == 0 and current_path.is_empty():
			pass # Allow free rotation
		else:
			return # Block invalid turn
			
	# Cost Calculation
	# Current Cost = abs(diff from entry)
	# BUT we need to know if we *already* paid for a turn this step?
	# We can't know that purely from state unless we track 'mr_spent_on_turn_this_step'.
	# Or we recalculate total cost?
	# Since we push state on every change, we can just look at the *previous* state's remaining turns.
	
	# Logic:
	# 1. Calc checks if this specific target facing is allowed (geometry).
	# 2. Calc cost relative to *current state* (not entry).
	#    If we are at Entry+1 (Cost 1 paid). Target Entry (Cost -1).
	#    If we are at Entry (Cost 0). Target Entry+1 (Cost 1).
	
	# We need 'turn_taken_this_step' to know if we are reversing a turn or making a new one?
	# Actually, we can derive 'turn_taken' from (current_facing - entry_facing).
	
	var current_turn_state = posmod(ghost_ship.facing - entry_facing, 6)
	# 0 = Center, 1 = Right, 5 = Left
	
	var target_turn_state = diff_from_entry
	
	var move_cost = 0
	
	# Transitions:
	# 0 -> 1: Cost 1
	# 0 -> 5: Cost 1
	# 1 -> 0: Cost -1 (Refund)
	# 5 -> 0: Cost -1 (Refund)
	# 1 -> 5: Invalid (Jump) - caught by is_valid_turn check? 
	#    Diff 1 to 5 is 4 steps. Blocked.
	#    Wait, 1 (Right) to 5 (Left) is 2 steps left.
	#    We only allow 1 step turns.
	#    So the user must go 1 -> 0 -> 5.
	
	if current_turn_state == 0:
		if target_turn_state != 0: move_cost = 1
	else:
		if target_turn_state == 0: move_cost = -1
		elif target_turn_state != current_turn_state:
			# 1 -> 5 or 5 -> 1.
			# This implies a 2-step turn.
			# Blocked by Geometry check?
			# 1 is entry+1. 5 is entry-1.
			# Distance is 2.
			# Mouse handling usually calls us with neighbor hexes.
			# But if we call this directly...
			return # Block direct jump from L to R
			
	# Apply
	if move_cost == 1 and turns_remaining <= 0:
		return # No MR
		
	# Undo/Push History
	_push_history_state()
	
	# CONDITIONAL GRAVITY COST: Check if turning inward after a penalty
	var is_inward_gravity_turn = false
	if move_cost == 1 and gravity_penalty_applied_this_turn and not free_gravity_turn_used:
		var closest_planet_pos = Vector3i.ZERO
		var min_dist = 999
		for p in planet_hexes:
			var d = HexGrid.hex_distance(ghost_ship.grid_position, p)
			if d < min_dist:
				min_dist = d
				closest_planet_pos = p
				
		var line_to_planet = HexGrid.get_line_coords(ghost_ship.grid_position, closest_planet_pos)
		if line_to_planet.size() > 1:
			var ideal_facing = HexGrid.get_hex_direction(ghost_ship.grid_position, line_to_planet[1])
			
			# We don't always demand absolute equality. The user can only turn 60 degrees.
			# We need to know if the new direction (dir_idx) is CLOSER to ideal_facing
			# than the previous facing (ghost_ship.facing).
			
			var old_dist = min((ghost_ship.facing - ideal_facing + 6) % 6, (ideal_facing - ghost_ship.facing + 6) % 6)
			var new_dist = min((dir_idx - ideal_facing + 6) % 6, (ideal_facing - dir_idx + 6) % 6)
			
			if new_dist < old_dist:
				is_inward_gravity_turn = true
				move_cost = 0
				free_gravity_turn_used = true
				
				# Refund the -1 MR penalty that was automatically deducted when entering this hex
				turns_remaining += 1

	turns_remaining -= move_cost
	
	if move_cost == 1:
		mr_expenditures.append({"pos": ghost_ship.grid_position, "text": "-1 MR (%d of %d)" % [turns_remaining, selected_ship.mr] })
	elif is_inward_gravity_turn:
		# Remove the previous -1 MR (Gravity) penalty display at this hex so it doesn't overlap
		for i in range(mr_expenditures.size() - 1, -1, -1):
			if mr_expenditures[i]["pos"] == ghost_ship.grid_position and mr_expenditures[i]["text"].begins_with("-1 MR (Gravity)"):
				mr_expenditures.remove_at(i)
				break
		mr_expenditures.append({"pos": ghost_ship.grid_position, "text": "0 MR (Gravity) (%d of %d)" % [turns_remaining, selected_ship.mr] })
	elif move_cost == -1:
		# Find and remove the latest MR expenditure at this location
		var removed_gravity_text = false
		for i in range(mr_expenditures.size() - 1, -1, -1):
			if mr_expenditures[i]["pos"] == ghost_ship.grid_position:
				if mr_expenditures[i]["text"].begins_with("0 MR (Gravity)"):
					removed_gravity_text = true
				mr_expenditures.remove_at(i)
				break
				
		if removed_gravity_text:
			# The turn we just undid was our free inward gravity turn.
			# Restore the usage flag and place the original penalty back.
			free_gravity_turn_used = false
			
			# Since undoing a turn normally grants +1 MR (from move_cost = -1),
			# but this was a free turn, we must deduct 1 MR to negate that faulty refund.
			# We must also deduct an additional 1 MR to re-apply the gravity penalty.
			turns_remaining -= 2
			
			mr_expenditures.append({"pos": ghost_ship.grid_position, "text": "-1 MR (Gravity) (%d of %d)" % [turns_remaining, selected_ship.mr]})
				
	# turn_taken_this_step is no longer needed/maintained!
	# We rely on ghost_ship.facing vs entry_facing.
		
	ghost_ship.facing = dir_idx
		
	# Update Visuals
	ghost_ship.queue_redraw()
	queue_redraw() # Update predictive path
	_update_ui_state() # Update buttons to match
	
	# Update Head State
	ghost_head_pos = ghost_ship.grid_position
	ghost_head_facing = ghost_ship.facing

# HELPER: Derive the facing we entered the current step with.
# This replaces the fragile 'step_entry_facing' variable.
func _get_step_entry_facing() -> int:
	if current_path.size() == 0:
		return selected_ship.facing # Start facing


	# If path has items, the entry facing for the CURRENT tip (ghost pos)
	# is the facing we had when we ENTERED this hex.
	# Which is effectively the facing from the PREVIOUS path step?
	# No, wait.
	# Path: [Hex A, Hex B]
	# Move A -> B.
	# At B, we can turn.
	# The facing we arrived at B with is the facing we had at A?
	# Or rather, the facing we had *during* the move A->B.
	# Which is the facing we had *after* leaving A.
	
	# Let's look at history.
	# validation: diff = current - entry.
	# If we just moved, current = entry. Cost = 0.
	# If we turned once, current = entry + 1. Cost = 1.
	
	# We need the baseline facing for this step.
	# It is the facing stored in the PREVIOUS history state corresponding to the start of this step?
	
	# Alternative:
	# If we have a path, the 'entry facing' is the direction of the segment that led here?
	# Vector = current_hex - prev_hex.
	# derive facing from vector?
	# YES. This is robust.
	# Exception: If we just turned *in place* (speed 0 / orbit), there is no vector.
	
	if current_path.size() >= 1:
		var current_hex = ghost_head_pos
		var prev_hex = selected_ship.grid_position
		if current_path.size() > 1:
			prev_hex = current_path[current_path.size() - 2]
		elif current_path.size() == 1:
			prev_hex = selected_ship.grid_position
			
		var vec = current_hex - prev_hex
		if vec != Vector3i.ZERO:
			# The direction we moved to get here IS the entry facing.
			# Because we move "forward".
			# So entry facing == direction of movement.
			return HexGrid.get_hex_direction(prev_hex, current_hex)
			
	return selected_ship.facing

func _handle_path_hover(hex: Vector3i):
	# Snap ghost ship to the state at this path step
	var target_state = null
	
	if hex == selected_ship.grid_position:
		# Start Position
		# Search history for state at start (before any moves)
		if movement_history.size() > 0:
			target_state = movement_history[0]
		else:
			# No history, so start state is current state (if no moves)
			# Or if we have moves but no history (shouldn't happen), assume start.
			target_state = {"ghost_pos": selected_ship.grid_position, "ghost_facing": selected_ship.facing}
	else:
		# Search history for the LAST entry where ghost_pos == hex
		# This represents the state before leaving that hex
		for i in range(movement_history.size() - 1, -1, -1):
			if movement_history[i]["ghost_pos"] == hex:
				target_state = movement_history[i]
				break
				
		# If not found in history, check if it's the CURRENT tip
		if not target_state:
			if ghost_head_pos == hex:
				target_state = {"ghost_pos": ghost_head_pos, "ghost_facing": ghost_head_facing}
				
	if target_state:
		ghost_ship.grid_position = target_state["ghost_pos"]
		ghost_ship.facing = target_state["ghost_facing"]
		ghost_ship.modulate.a = 0.6 # Semi-transparent
		path_preview_active = true
		queue_redraw()

func _handle_preview_extension(hex: Vector3i):
	# Not on existing path -> Check for valid extension preview
	var forward_vec = HexGrid.get_direction_vec(ghost_head_facing)
	var dist = HexGrid.hex_distance(ghost_head_pos, hex)
	
	# Check Max Speed / Path Limits (Visual Preview should match Logic)
	var max_allowed_path = start_speed + selected_ship.get_effective_adf()
	if current_path.size() + dist > max_allowed_path:
		# Too far
		dist = 0 # Invalid
	
	var is_valid_extension = false
	if dist > 0:
		var check_pos = ghost_head_pos + (forward_vec * dist)
		# Check if hex is ON the line
		if check_pos == hex:
			# Validate range/etc? Assume yes for visual preview if line is straight
			is_valid_extension = true
			
			# Snap Ghost to new tip
			ghost_ship.grid_position = hex
			ghost_ship.facing = ghost_head_facing
			ghost_ship.modulate.a = 0.5 # Preview opacity
			path_preview_active = true # Reuse flag to indicate "not at head"
			queue_redraw()
			
	if not is_valid_extension:
		# If we were previewing, snap back to head state
		if path_preview_active:
			ghost_ship.grid_position = ghost_head_pos
			ghost_ship.facing = ghost_head_facing
			ghost_ship.modulate.a = 1.0 # Reset opacity
			path_preview_active = false
			queue_redraw()

var computer_opponents: Array = []

func _spawn_computer_opponents():
	if not _is_server_or_offline(): return
	
	var assigned_sides = []
	if _is_networked():
		for pid in NetworkManager.lobby_data.get("teams", {}):
			assigned_sides.append(NetworkManager.lobby_data["teams"][pid])
	else:
		assigned_sides.append(my_side_id)
		
	for s_id in [1, 2]:
		if not s_id in assigned_sides:
			# Check if already spawned
			var already_spawned = false
			for ai in computer_opponents:
				if is_instance_valid(ai) and ai.side_id == s_id:
					already_spawned = true
					break
			if already_spawned:
				continue
				
			var ai = load("res://Scripts/ComputerOpponent.gd").new()
			ai.name = "ComputerOpponent_Side" + str(s_id)
			ai.game_manager = self
			ai.side_id = s_id
			add_child(ai)
			computer_opponents.append(ai)

func _is_server_or_offline() -> bool:
	# Server Authority (Logic/State)
	if not _is_networked(): return true
	return multiplayer.is_server()

func _has_admin_authority() -> bool:
	# Admin Authority (Input/UI/Cheats)
	# If simulating online for tests, enforce strict side check
	if test_force_online: return (my_side_id == 0)
	
	# Offline = Full Control
	if not _is_networked(): return true
	
	# Online = Only Side 0 (Spectator/Admin) has full control
	# Host (Side 1) is restricted like a normal player
	return (my_side_id == 0)

func _is_networked() -> bool:
	if not multiplayer.has_multiplayer_peer(): return false
	if multiplayer.multiplayer_peer == null: return false
	if multiplayer.multiplayer_peer.get_class() == "OfflineMultiplayerPeer": return false
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return false
	return true
