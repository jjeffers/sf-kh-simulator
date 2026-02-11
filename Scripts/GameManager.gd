class_name GameManager
extends Node2D

@export var map_radius: int = 25

var ships: Array[Ship] = []
const LOG_FILE = "user://game_log.txt"
var current_player_id: int = 1 # The "Active" moving player
var firing_player_id: int = 0 # The player currently firing in Combat Phase
var my_local_player_id: int = 0 # 0 = All/Debug, otherwise specific ID
var selected_ship: Ship = null
var combat_target: Ship = null

@export var camera_speed: float = 500.0

# Phase Enum
enum Phase {START, MOVEMENT, COMBAT, END}
# Combat State Enum
enum CombatState {NONE, PLANNING, RESOLVING}

var current_phase: Phase = Phase.START
var current_combat_state: CombatState = CombatState.NONE

# Combat Subphase: 0 = None, 1 = Passive Fire (First), 2 = Active Fire (Second)
var combat_subphase: int = 0

# ... (UI Nodes omitted, they remain)

# Movement State references need to be reset properly

# Movement State references need to be reset properly

# UI Nodes

# UI Nodes
var ui_layer: CanvasLayer
var label_status: Label
var btn_commit: Button
var btn_undo: Button
var btn_turn_left: Button
var btn_turn_right: Button
var btn_orbit_cw: Button
var btn_orbit_ccw: Button
var btn_ms_toggle: CheckBox

# Movement State
var ghost_ship: Ship = null
var current_path: Array[Vector3i] = [] # List of hexes visited
var turns_remaining: int = 0
var start_speed: int = 0
var can_turn_this_step: bool = false # "Use it or lose it" flag
var combat_action_taken: bool = false # Lock to prevent click spam
var start_ms_active: bool = false # Track initial state for cost logic

# Combat State
var queued_attacks: Array = [] # Objects: {source, target, weapon_idx}
var pending_resolutions: Array = []

# Environment
var planet_hexes: Array[Vector3i] = [Vector3i(0, 0, 0)] # Center hex

# Scenario Rules
var current_scenario_rules: Array = []

# Planning UI
var panel_planning: PanelContainer
var container_ships: VBoxContainer

# ICM UI
signal icm_decision_made(count: int)
var panel_icm: PanelContainer


func _ready():
	_init_log_file()
	_setup_ui()
	queue_redraw()
	_spawn_planets()
	
	# Network Setup
	var setup = NetworkManager.game_setup_data
	var scen_key = "the_last_stand"
	
	if setup and not setup.is_empty():
		scen_key = setup.get("scenario", "the_last_stand")
		var h_side = setup.get("host_side", 0)
		var h_pid = h_side + 1
		
		# Determine Identity
		if multiplayer.is_server():
			my_local_player_id = h_pid
			log_message("Network: Host playing as Player %d" % my_local_player_id)
		else:
			# Assuming 2 player for now
			my_local_player_id = 3 - h_pid
			log_message("Network: Client playing as Player %d" % my_local_player_id)
	else:
		# Fallback / Debug
		my_local_player_id = -1 # Default to Spectator if network data missing
		log_message("Network: Offline/Debug Mode (Spectator)")
		
	if multiplayer.is_server():
		# Host: Generate random seed and broadcast
		var seed_val = randi()
		setup_game.rpc(seed_val, scen_key)
	else:
		log_message("Waiting for Game Setup from Host...")

@rpc("authority", "call_local", "reliable")
func setup_game(seed_val: int, scen_key: String):
	log_message("Game Setup Received: Seed %d" % seed_val)
	load_scenario(scen_key, seed_val)
	start_turn_cycle()

func _process(delta):
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y -= 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x += 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x -= 1
	
	if move_vec != Vector2.ZERO:
		position += move_vec.normalized() * camera_speed * delta
		
	if Input.is_key_pressed(KEY_SPACE):
		_update_camera()

	if Input.is_action_just_pressed("ui_focus_next"): # TAB usually
		_cycle_selection()

func _setup_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	ui_layer.add_child(vbox)
	
	label_status = Label.new()
	label_status.text = "Initializing..."
	vbox.add_child(label_status)
	
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
	
	# Turn Buttons
	var turn_box = HBoxContainer.new()
	vbox.add_child(turn_box)
	
	btn_turn_left = Button.new()
	btn_turn_left.text = "< Port"
	btn_turn_left.pressed.connect(func(): _on_turn(-1))
	turn_box.add_child(btn_turn_left)
	
	btn_turn_right = Button.new()
	btn_turn_right.text = "Starbd >"
	btn_turn_right.pressed.connect(func(): _on_turn(1))
	turn_box.add_child(btn_turn_right)
	
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
	
	# MS Toggle
	btn_ms_toggle = CheckBox.new()
	btn_ms_toggle.text = "Deploy Screen"
	btn_ms_toggle.toggled.connect(_on_ms_toggled)
	btn_ms_toggle.visible = false
	vbox.add_child(btn_ms_toggle)
	
	# Planning UI (Right Side)
	panel_planning = PanelContainer.new()
	panel_planning.anchor_left = 0.8
	panel_planning.anchor_right = 1.0
	panel_planning.anchor_top = 0.0
	# panel_planning.anchor_bottom = 0.75 # Allow auto-sizing
	panel_planning.visible = false
	ui_layer.add_child(panel_planning)
	
	var pp_vbox = VBoxContainer.new()
	panel_planning.add_child(pp_vbox)
	
	var pp_lbl = Label.new()
	pp_lbl.text = "Attack Planning"
	pp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pp_vbox.add_child(pp_lbl)
	
	container_ships = VBoxContainer.new()
	pp_vbox.add_child(container_ships)
	
	# Execute Button
	var btn_exec = Button.new()
	btn_exec.text = "EXECUTE ATTACK"
	btn_exec.modulate = Color(1, 0.5, 0.5)
	btn_exec.pressed.connect(_on_combat_commit)
	pp_vbox.add_child(btn_exec)

	# Combat Log
	# Combat Log
	var log_panel = PanelContainer.new()
	# Explicit anchors for bottom 25% of screen
	log_panel.anchor_left = 0.0
	log_panel.anchor_right = 1.0
	log_panel.anchor_top = 0.75
	log_panel.anchor_bottom = 1.0
	log_panel.modulate.a = 0.8
	ui_layer.add_child(log_panel)
	
	combat_log = RichTextLabel.new()
	combat_log.scroll_following = true
	combat_log.bbcode_enabled = true
	combat_log.text = "[color=yellow]System Initialized.[/color]\n" # Debug text
	combat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(combat_log)
	
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
	
	# Audio Setup
	var audio_node = Node.new()
	audio_node.name = "AudioParams"
	add_child(audio_node)
	
	audio_laser = AudioStreamPlayer.new()
	audio_laser.stream = load("res://Assets/Audio/laser.mp3")
	add_child(audio_laser)
	
	audio_hit = AudioStreamPlayer.new()
	audio_hit.stream = load("res://Assets/Audio/hit.mp3")
	add_child(audio_hit)

	audio_beep = AudioStreamPlayer.new()
	audio_beep.stream = load("res://Assets/Audio/short-low-beep.mp3")
	add_child(audio_beep)

	audio_action_complete = AudioStreamPlayer.new()
	audio_action_complete.stream = load("res://Assets/Audio/short-next-selection.mp3")
	add_child(audio_action_complete)
	
	audio_phase_change = AudioStreamPlayer.new()
	# 'short-sound.mp3' was missing, using 'short-computer.mp3'
	audio_phase_change.stream = load("res://Assets/Audio/short-computer.mp3")
	add_child(audio_phase_change)

	audio_ship_select = AudioStreamPlayer.new()
	audio_ship_select.stream = load("res://Assets/Audio/short-departure.mp3")
	add_child(audio_ship_select)

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

var audio_laser: AudioStreamPlayer
var audio_hit: AudioStreamPlayer
var audio_beep: AudioStreamPlayer
var audio_action_complete: AudioStreamPlayer
var audio_phase_change: AudioStreamPlayer
var audio_ship_select: AudioStreamPlayer
var mini_map: MiniMap

var combat_log: RichTextLabel

# Game Over UI
var panel_game_over: PanelContainer
var label_winner: Label
var btn_restart: Button

var label_center_message: Label

func log_message(msg: String):
	combat_log.append_text(msg + "\n")
	print(msg)
	_log_to_file(msg)
	
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
	
	# Check if clicked on a FRIENDLY ship to switch shooter
	# Only checks ships belonging to firing_player_id that haven't fired
	for s in ships:
		if s.grid_position == hex and s.player_id == firing_player_id and not s.has_fired:
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

		var w_range = weapon["range"]
		var w_arc = weapon["arc"]
		var d = HexGrid.hex_distance(selected_ship.grid_position, s.grid_position)
		
		# Range Check
		if d > w_range:
			log_message("[color=red]Target out of range! (Max %d)[/color]" % w_range)
			return

		# Arc Check
		if w_arc == "FF":
			var valid_hexes = _get_ff_arc_hexes(selected_ship, w_range)
			if not s.grid_position in valid_hexes:
				log_message("[color=red]Target not in Forward Firing Arc![/color]")
				return

		# Ammo Check (Account for already queued shots)
		var queued_count = 0
		for atk in queued_attacks:
			if atk["source"] == selected_ship and atk["weapon_idx"] == selected_ship.current_weapon_index:
				queued_count += 1
		
		if weapon["ammo"] - queued_count <= 0:
			log_message("[color=red]Insufficent Ammo for planned shot![/color]")
			return
			
		# Check if already targeting this specific enemy with this weapon?
		# Rules don't say we can't double tap, so allow it.
		
		# Check for existing plan with THIS weapon and remove it (Overwrite Rule)
		for i in range(queued_attacks.size() - 1, -1, -1):
			var atk = queued_attacks[i]
			if atk["source"] == selected_ship and atk["weapon_idx"] == selected_ship.current_weapon_index:
				queued_attacks.remove_at(i)
				# log_message("Command updated.") # Optional feedback
				break

		# ADD TO PLAN
		queued_attacks.append({
			"source": selected_ship,
			"target": s,
			"target_pos": s.position, # Store visual position for FX if target dies
			"weapon_idx": selected_ship.current_weapon_index,
			"weapon_name": weapon["name"]
		})
		
		log_message("Planned: %s -> %s (%s)" % [selected_ship.get_display_name(), s.get_display_name(), weapon["name"]])
		
		_update_planning_ui_list()
		queue_redraw()

	else:
		# Check if switching target (Enemy)
		for s in ships:
			if s.player_id != firing_player_id and s.grid_position == hex:
				var d = HexGrid.hex_distance(selected_ship.grid_position, s.grid_position)
				if d <= Combat.MAX_RANGE:
					combat_target = s
					queue_redraw()
					log_message("Targeting: %s" % s.get_display_name())
					_update_ship_visuals() # Ensure target pops to top
					break

func _check_for_valid_combat_targets() -> bool:
	# Iterate all ships owned by firing_player_id
	var my_ships = ships.filter(func(s): return s.player_id == firing_player_id and not s.is_exploding and not s.is_docked) # Docked ships cant fire? Usually true.
	
	print("[DEBUG] TARGET CHECK P%d. Ships: %d" % [firing_player_id, my_ships.size()])
	
	for s in my_ships:
		# Check each weapon
		for w in s.weapons:
			if w.get("fired", false): continue
			
			# Check availability (e.g. Phase/Debuff)
			if not _is_weapon_available_in_phase(w, s): continue
			
			# Check for ANY target in range/arc
			var valid_targets = _get_valid_targets_for_weapon(s, w)
			
			if valid_targets.size() > 0:
				print("[DEBUG] VALID: %s found target with %s" % [s.name, w["name"]])
				return true
				
	print("[DEBUG] NO TARGETS FOUND for P%d" % firing_player_id)
	return false

func _get_valid_targets_for_weapon(shooter: Ship, weapon: Dictionary) -> Array[Ship]:
	var valid: Array[Ship] = []
	var targets = ships.filter(func(s): return s != shooter and not s.is_exploding and s.player_id != shooter.player_id and not s.is_docked)
	
	for t in targets:
		var dist = HexGrid.hex_distance(shooter.grid_position, t.grid_position)
		print("[DEBUG] %s -> %s Dist: %d Range: %d" % [shooter.name, t.name, dist, weapon["range"]])
		
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
			if hex in planet_hexes:
				is_masked = true
				break
		
		if is_masked:
			# print("[DEBUG] Masked by Planet: %s -> %s" % [shooter.name, t.name])
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
	if type == "Rocket" or type == "Rocket Battery":
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
		# Laser or Laser Canon
		var line = Line2D.new()
		var is_canon = (type == "Laser Canon")
		
		line.width = 5.0 if is_canon else 3.0
		line.default_color = Color.ORANGE if is_canon else Color(1, 0, 0, 1) # Canon Orange, Battery Red
		line.points = PackedVector2Array([start, end])
		add_child(line)
		
		var tween = create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 2.0)
		tween.tween_callback(line.queue_free)

		if audio_laser.stream: audio_laser.play()
		return 0.1 # Instant

func _on_combat_commit():
	# Authority Check
	if my_local_player_id > 0 and firing_player_id != my_local_player_id:
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
	
	rpc("execute_commit_combat", attacks_data, randi())

@rpc("any_peer", "call_local", "reliable")
func execute_commit_combat(attacks_data: Array, rng_seed: int):
	current_combat_state = CombatState.RESOLVING
	
	# Sync RNG
	seed(rng_seed)
	
	# Deserialize
	pending_resolutions.clear()
	for data in attacks_data:
		var source = null
		var target = null
		
		for s in ships:
			if s.name == data["s"]: source = s
			if s.name == data["t"]: target = s
		
		if source and target: # Target might be null if we allow ground targeting later, but for now ship-to-ship
			pending_resolutions.append({
				"source": source,
				"target": target,
				"weapon_idx": data["w"],
				"target_pos": data["tp"]
			})
			
	panel_planning.visible = false
	
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
		await get_tree().create_timer(1.0).timeout
		_process_next_attack()
		return

	# If ship exists but is technically dead/dying (hull <= 0)
	if source.hull <= 0:
		log_message("%s destroyed before firing! Attack fizzles." % source.get_display_name())
		source.weapons[weapon_idx]["ammo"] -= 1
		await get_tree().create_timer(1.0).timeout
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
	
	var start_pos = HexGrid.hex_to_pixel(source.grid_position)
	var target_pos = atk["target_pos"]
	
	if is_instance_valid(target):
		target_pos = target.position

	if not is_instance_valid(target) or target.hull <= 0:
		log_message("%s firing at WRECK of %s! (Wasted)" % [source.get_display_name(), target.get_display_name() if is_instance_valid(target) else "Unknown"])
		_spawn_attack_fx(start_pos, target_pos, weapon.get("type"))
		await get_tree().create_timer(1.5).timeout
		_process_next_attack()


		return

	# DOCKING RULE: Targeting Immunity Check AGAIN (Safety)
	if target.is_docked and target.ship_class in ["Fighter", "Assault Scout"]:
		log_message("%s target is docked and invalid! Attack fizzles." % source.get_display_name())
		source.weapons[weapon_idx]["ammo"] -= 1 # Wasted shot rule? Or refund? Let's burn ammo to be safe.
		await get_tree().create_timer(1.0).timeout
		_process_next_attack()
		return

	# Execute Fire Logic
	log_message("%s firing %s at %s" % [source.get_display_name(), weapon["name"], target.get_display_name()])
	
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
	
	# ICM INTERRUPT
	var icm_used = 0
	var w_type = weapon.get("type")
	
	# DOCKING RULE: Docked Ships cannot use ICMs
	var can_use_icm = (target.icm_current > 0)
	# if target.is_docked: can_use_icm = false # User requested prompt even if docked.

	if can_use_icm and w_type in ["Torpedo", "Rocket", "Rocket Battery"]:
		# Calculate hit chance to show player
		var raw_chance = Combat.calculate_hit_chance(d, weapon, target, is_head_on, 0, source)
		
		# Prompt UI
		_trigger_icm_decision(source.name, weapon["name"], w_type, raw_chance, target)
		
		# Wait for signal
		var decision_count = await icm_decision_made
		
		if decision_count > 0:
			icm_used = decision_count
			target.icm_current -= icm_used
			log_message("%s launches %d ICMs!" % [target.name, icm_used])
			_spawn_icm_fx(target, source.position)
			await get_tree().create_timer(1.0).timeout # Wait for counter-fire FX
	
	
	# Determine if hit (Pass ICM count)
	var result = Combat.get_hit_roll_details(d, weapon, target, is_head_on, icm_used, source)
	var hit = result["success"]
	
	var hit_str = "HIT" if hit else "MISS"
	log_message("Rolled %d vs %d%% -> %s" % [result["roll"], result["chance"], hit_str])
	
	# Spawn Attack FX (Launch concurrently with ICMs)
	var travel_time = _spawn_attack_fx(start_pos, target_pos, weapon.get("type", "Laser"))
	
	if icm_used > 0:
		log_message("%s launches %d ICMs!" % [target.name, icm_used])
		# Launch ICMs to intercept near target
		# They should arrive slightly before the full travel time (e.g. at 80% marks)
		_spawn_icm_fx(target, source.position, travel_time)
	
	if hit:
		var dmg_str = "%s+%d" % [weapon["damage_dice"], weapon["damage_bonus"]]
		var dmg = Combat.roll_damage(dmg_str)
		
		# Masking Screen Damage Reduction (Halved)
		# Applies if Target OR Source has MS active, and weapon is Laser/Canon
		var target_ms = target.get("is_ms_active")
		var source_ms = source.get("is_ms_active")
		if (target_ms or source_ms) and w_type in ["Laser", "Laser Canon"]:
			dmg = floor(dmg / 2)
			log_message("Masking Screen reduces damage!")
			
		log_message("[color=green]HIT![/color] Dmg: %d" % dmg)
		
		# Delay damage for FX arrival
		var damage_delay = travel_time
		if damage_delay == 0: damage_delay = 0.5 # Safety for instant lasers
		
		await get_tree().create_timer(damage_delay).timeout
		
		if is_instance_valid(target):
			target.take_damage(dmg)
			_spawn_hit_text(target_pos, dmg)
			if audio_hit.stream: audio_hit.play()
	else:
		log_message("[color=red]MISS![/color]")
	
	# Wait for animation (travel time + buffer)
	var total_wait = travel_time + 1.0
	if total_wait < 2.0: total_wait = 2.0
	
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
	
	if combat_subphase == 1:
		start_combat_active()
	else:
		end_turn_cycle()

func _spawn_hit_text(pos: Vector2, damage: int):
	var lbl = Label.new()
	lbl.text = "HIT! -%d" % damage
	lbl.position = pos + Vector2(-20, -40) # Slightly above
	lbl.modulate = Color.RED
	lbl.add_theme_font_size_override("font_size", 20)
	add_child(lbl)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 30, 3.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 3.0)
	tween.chain().tween_callback(lbl.queue_free)


# Helper to clear plotting state when switching ships
func _reset_plotting_state():
	current_path = []
	if selected_ship:
		turns_remaining = selected_ship.mr
		start_speed = selected_ship.speed
		start_ms_active = selected_ship.is_ms_active
	else:
		turns_remaining = 0
		start_speed = 0
		start_ms_active = false
		
	can_turn_this_step = false
	current_orbit_direction = 0
	state_is_orbiting = false
	combat_action_taken = false

func _cycle_selection():
	if current_phase == Phase.MOVEMENT:
		# Filter: Active Player, !has_moved
		var available = ships.filter(func(s): return s.player_id == current_player_id and not s.has_moved)
		if available.size() <= 1: return
		
		var idx = available.find(selected_ship)
		var next_idx = (idx + 1) % available.size()
		selected_ship = available[next_idx]
		
		# Reset plotting
		_reset_plotting_state()
		
		if audio_ship_select and audio_ship_select.stream: audio_ship_select.play()
		_spawn_ghost()
		_update_camera()
		_update_ship_visuals() # Re-sort stack
		_update_ui_state()

	elif current_phase == Phase.COMBAT:
		# Cycling TARGETS? Or Cycling SHOOTERS?
		# Standard UI implies we have a "Selected Ship" that is acting.
		# But combat cycling usually means cycling TARGETS for the selected shooter.
		# Let's support BOTH via context? No, TAB usually cycles what you "control".
		# Actually, user might want to switch which ship is FIRING if they have multiple available.
		# But `_check_combat_availability` locks us into one.
		# Let's allow cycling the SHOOTER if multiple are available?
		# Or cycling the TARGET if a shooter is selected?
		# Consistent UI: TAB cycles controllable units. 
		# If we want to cycle targets, we need a different key or context.
		# EXISTING logic cycled targets. Let's keep that for now if a shooter is locked?
		# BUT wait, the previous code cycled TARGETS.
		# Let's split: TAB cycles SHOOTERS (if we allow changing shooter). click cycles targets?
		# Or TAB cycles targets if we have a shooter?
		# DECISION: Tab cycles TARGETS for the current shooter.
		# Changing shooter: Click on friendly ship?
		# Update target cycling
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
		if s.is_exploding: continue
		if not grid_counts.has(s.grid_position):
			grid_counts[s.grid_position] = []
		grid_counts[s.grid_position].append(s)
	
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
		s.reset_weapons()
	start_movement_phase()

func start_movement_phase():
	var is_phase_change = (current_phase != Phase.MOVEMENT)
	current_phase = Phase.MOVEMENT
	combat_subphase = 0
	firing_player_id = 0
	combat_action_taken = false # Reset lock
	
	# Find un-moved ships for ACTIVE player
	# Allow docked ships to be selected (so they can undock)
	# Added safety check for instance validity
	var available = ships.filter(func(s): return is_instance_valid(s) and s.player_id == current_player_id and not s.is_exploding and not s.has_moved)
	
	print("[DEBUG] start_movement_phase: Player %d. Available Ships: %d" % [current_player_id, available.size()])
	
	if available.size() == 0:
		print("[DEBUG] No ships to move. Starting Passive Combat.")
		start_combat_passive()
		return

	# Select first available
	selected_ship = available[0]
	
	if audio_ship_select and audio_ship_select.stream:
		audio_ship_select.play()
	
	_spawn_ghost()
	_reset_plotting_state()
	
	# Check for Persistent Orbit
	if selected_ship.orbit_direction != 0:
		_on_orbit(selected_ship.orbit_direction)
		# This effectively pre-plans the move.
		# User can then just hit Engage.
		log_message("Auto-plotting Orbit...")
		print("[DEBUG] Orbit plotted for %s" % selected_ship.name)
	else:
		print("[DEBUG] Standard move start for %s" % selected_ship.name)
	
	_update_camera()
	
	# If start speed is 0 or just spawned? Speed 0 rotation check happens in UI update.
	
	_update_camera()
	_update_ui_state()
	log_message("Movement Phase: Player %d" % current_player_id)
	
	if is_phase_change and audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()

func start_combat_passive():
	current_phase = Phase.COMBAT
	combat_subphase = 1 # Passive First
	firing_player_id = 3 - current_player_id # The Non-Active Player
	
	print("[DEBUG] start_combat_passive: P%d firing (Passive)" % firing_player_id)
	
	if audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()
	
	_start_combat_planning()

func start_combat_active():
	current_phase = Phase.COMBAT
	combat_subphase = 2 # Active Second
	firing_player_id = current_player_id # The Active Player
	
	if audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()
	
	_start_combat_planning()

func _start_combat_planning():
	current_combat_state = CombatState.PLANNING
	queued_attacks.clear()
	selected_ship = null
	combat_target = null
	
	# Reset "fired" state visually for planning (actual state reset happens differently)
	# Actually, we need to track "planned usage".
	# For now, let's just refresh the UI.
	
	log_message("Combat Planning: Player %d" % firing_player_id)
	
	_update_camera()
	_update_ui_state()
	_update_camera()
	_update_ui_state()
	_update_planning_ui_list()
	queue_redraw()
	
	# Skip Check: If valid targets exist, stay. Else commit/next.
	# Skip Check: If valid targets exist, stay. Else commit/next.
	if not _check_for_valid_combat_targets():
		var msg = "No valid targets for Player %d. Skipping..." % firing_player_id
		log_message(msg)
		
		# Center Message
		label_center_message.text = msg
		label_center_message.visible = true
		
		# Delay slightly for readability
		get_tree().create_timer(2.0).timeout.connect(func():
			label_center_message.visible = false
			_on_combat_commit()
		)

func _update_planning_ui_list():
	# Clear existing
	for c in container_ships.get_children():
		c.queue_free()
		
	# Find ships for firing player
	var my_ships = ships.filter(func(s): return s.player_id == firing_player_id and not s.is_exploding)
	
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
			_update_ui_state()
			_update_ship_visuals()
			queue_redraw()
		)
		
		container_ships.add_child(btn)
	
	# Only show planning panel if it's THIS player's turn to fire
	var is_my_planning_phase = (firing_player_id == my_local_player_id) or (my_local_player_id == 0)
	var show_planning = (current_phase == Phase.COMBAT and current_combat_state == CombatState.PLANNING and is_my_planning_phase)
	panel_planning.visible = show_planning
	
	if show_planning:
		# Reposition Minimap below the planning panel
		call_deferred("_update_minimap_position")
	else:
		# Reset Minimap
		if mini_map:
			mini_map.anchors_preset = Control.PRESET_TOP_RIGHT
			mini_map.position = Vector2(get_viewport_rect().size.x - 220, 20)
			# mini_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 20)

	if not is_my_planning_phase and current_phase == Phase.COMBAT and current_combat_state == CombatState.PLANNING:
		label_status.text += "\n\n(Waiting for Player %d to plan attacks...)" % firing_player_id

# _check_combat_availability removed/replaced by explicit planning flow


func end_turn_cycle():
	# Scenario Objective Check: Surprise Attack (Defiant Evacuation)
	# Check before switching player, or after? 
	# "Turns docked" -> implied "Full Turns" or "Turn Cycles"?
	# Let's count at the end of the Cycle (when both players have acted).
	if multiplayer.is_server():
		# Process Special Rules
		for rule in current_scenario_rules:
			if rule["type"] == "docked_turn_counter":
				var t_name = rule["target_name"]
				var prop = rule["counter_property"]
				var log_tmpl = rule["log_template"]
				
				# Find target
				var target_ship = null
				for s in ships:
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
			
	log_message("Turn Complete. Switching Active Player.")
	current_player_id = 3 - current_player_id
	
	# Reset ALL ships
	for s in ships:
		if is_instance_valid(s):
			s.reset_turn_state()
		
	print("[DEBUG] Calling start_movement_phase from end_turn_cycle")
	start_movement_phase()

func _update_camera(focus_target_override = null):
	var target_pos = Vector2.ZERO
	
	if focus_target_override:
		if focus_target_override is Node2D:
			target_pos = focus_target_override.position
		elif focus_target_override is Vector2:
			target_pos = focus_target_override
	elif selected_ship:
		target_pos = HexGrid.hex_to_pixel(selected_ship.grid_position)
	else:
		return

	var center = get_viewport_rect().size / 2
	# Center ship on screen
	position = center - target_pos

func _spawn_ghost():
	if ghost_ship:
		ghost_ship.queue_free()
	
	ghost_ship = Ship.new()
	ghost_ship.name = "GhostShip"
	ghost_ship.player_id = selected_ship.player_id
	ghost_ship.ship_class = selected_ship.ship_class # Copy visual class
	ghost_ship.faction = selected_ship.faction # Copy faction for sprite selection
	ghost_ship.color = selected_ship.color
	ghost_ship.grid_position = selected_ship.grid_position
	ghost_ship.facing = selected_ship.facing
	ghost_ship.set_ghost(true)
	add_child(ghost_ship)
	queue_redraw() # Ensure predictive path draws immediately

func _update_ui_state():
	if current_phase == Phase.MOVEMENT:
		btn_undo.visible = (current_path.size() > 0)
		
		var steps = current_path.size()
		var min_speed = max(0, start_speed - selected_ship.adf)
		var max_speed = start_speed + selected_ship.adf
		var is_valid = (steps >= min_speed and steps <= max_speed)
		
		if state_is_orbiting:
			# Orbit moves are always 1 hex, regardless of ADF/Speed limits
			is_valid = true
		
		btn_commit.visible = true
		btn_commit.disabled = not is_valid
		
		btn_turn_left.visible = true
		btn_turn_right.visible = true
		
		# Can only turn if we just moved, haven't turned yet, and have MR left
		# OR if we are stationary (Speed 0 Rule)
		# OR if we are Orbiting
		
		var is_stationary = (current_path.size() == 0)
		var allow_turn = false
		
		if is_stationary or state_is_orbiting:
			allow_turn = true
		else:
			allow_turn = (can_turn_this_step and turns_remaining > 0)
			
		btn_turn_left.disabled = not allow_turn
		btn_turn_right.disabled = not allow_turn
		
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
					# Strict Activation Check:
					# must EXACTLY match to activate fresh
					speed_ok = (current_path.size() == start_speed)
					
				var heading_ok = (ghost_ship.facing == selected_ship.facing)
				ms_valid_move = (speed_ok and heading_ok)
			
			if selected_ship.is_ms_active:
				# If already active, check if we need to DROP it
				if not ms_valid_move:
					_on_ms_toggled(false) # Auto-drop
					log_message("Maneuver Dropped Screen")
			else:
				# If not active, can we Activate it?
				# Only if move is valid (Straight line) OR if we haven't moved yet (Stationary start is valid?)
				# Actually, user plans move then activates. If plot is invalid, disable button.
				btn_ms_toggle.disabled = not ms_valid_move
				if not ms_valid_move:
					btn_ms_toggle.tooltip_text = "Must maintain Speed and Heading to deploy"
				else:
					btn_ms_toggle.tooltip_text = "Deploy Masking Screen (Cost: 1)"
		else:
			btn_ms_toggle.visible = false
		
		var txt = "Player %d Plotting\n" % selected_ship.player_id
		txt += "Ship: %s (%s)\n" % [selected_ship.name, selected_ship.ship_class]
		txt += "Hull: %d\n" % selected_ship.hull
		txt += "Stats: ADF %d | MR %d\n" % [selected_ship.adf, selected_ship.mr]
		if is_stationary:
			txt += "Speed 0: Free Rotation Mode\n"
		elif state_is_orbiting:
			txt += "Orbiting: Free Rotation Mode\n"
		else:
			txt += "Remaining MR: %d\n" % turns_remaining
			
		txt += "Speed: %d -> %d / Range: [%d, %d]\n" % [start_speed, current_path.size(), min_speed, max_speed]
		
		if selected_ship.is_ms_active:
			txt += "[COLOR=blue]Masking Screen ACTIVE[/COLOR]\n"
		
		txt += "Weapons:\n"
		for w in selected_ship.weapons:
			txt += "- %s (Ammo: %d)\n" % [w["name"], w["ammo"]]

		if not is_valid and not state_is_orbiting: # Orbit is always valid move of 1
			# Special case: Orbit move is size 1. Does it respect ADF?
			# User: "moves 1 hex". Usually Speed is irrelevant for Orbit or it SETS speed to 1?
			# Assuming specific mechanic overrides speed limits or fits within them (1 is usually valid).
			txt += "\n(Invalid Speed)"
		
		if state_is_orbiting:
			# Orbit validity overrides speed check? 1 is valid usually.
			# But commit button relies on is_valid.
			# Let's assume 1 is valid. 
			pass
			
		label_status.text = txt
		
	elif current_phase == Phase.COMBAT:
		btn_undo.visible = false
		btn_commit.visible = false
		btn_turn_left.visible = false
		btn_turn_right.visible = false
		btn_orbit_cw.visible = false
		btn_orbit_ccw.visible = false
		
		var phase_name = "Passive" if combat_subphase == 1 else "Active"
		var txt = "Combat (%s Fire)\nPlayer %d Firing" % [phase_name, firing_player_id]
		
		if selected_ship:
			txt += "\nShip: %s" % selected_ship.get_display_name()
			if selected_ship.weapons.size() > 0:
				var w = selected_ship.weapons[selected_ship.current_weapon_index]
				txt += "\nWeapon: %s" % w["name"]
				txt += "\nAmmo: %d | Rng: %d | Arc: %s" % [w["ammo"], w["range"], w["arc"]]
				if w.get("fired", false):
					txt += " (FIRED)"
					
			if combat_target:
				txt += "\nTarget: %s" % combat_target.get_display_name()
				# Show Hit Chance
				if selected_ship and selected_ship.weapons.size() > 0:
					var w = selected_ship.weapons[selected_ship.current_weapon_index]
					var dist = HexGrid.hex_distance(selected_ship.grid_position, combat_target.grid_position)
					# Quick Calc (ignoring partial implementation details for UI speed, or use Combat lib)
					# We should use Combat.calculate_hit_chance(dist, w, target, head_on, 0, shooter)
					# Need head_on check
					var is_head_on = false # Simplified for UI hint, actual calc in resolve
					var chance = Combat.calculate_hit_chance(dist, w, combat_target, is_head_on, 0, selected_ship)
					txt += "\nHit Chance: %d%%" % chance
		
		# SUMMARY OF PLANNED ATTACKS (Left Side)
		if queued_attacks.size() > 0:
			txt += "\n\n-- Planned Attacks --"
			for atk in queued_attacks:
				var s = atk["source"]
				if s.player_id == firing_player_id:
					var t = atk["target"]
					var w_name = atk["weapon_name"]
					# Recalculate chance for display
					var dist = HexGrid.hex_distance(s.grid_position, t.grid_position)
					var w_idx = atk["weapon_idx"]
					var w = s.weapons[w_idx]
					var chance = Combat.calculate_hit_chance(dist, w, t, false, 0, s)
					
					txt += "\n%s -> %s: %s (%d%%)" % [s.get_display_name(), t.get_display_name(), w_name, chance]
		
		label_status.text = txt
	elif current_phase == Phase.END:
		btn_undo.visible = false
		btn_commit.visible = false
		btn_turn_left.visible = false
		btn_turn_right.visible = false
		label_status.text = "Game Over"

func _on_undo():
	if current_path.size() > 0:
		# Full Reset for simplicity
		_spawn_ghost()
		current_path.clear()
		turns_remaining = selected_ship.mr
		can_turn_this_step = false
		state_is_orbiting = false
		current_orbit_direction = 0
		queue_redraw()
		_update_ui_state()

func _on_turn(direction: int):
	# Authority Check
	if my_local_player_id > 0 and current_player_id != my_local_player_id:
		return
		
	# direction: -1 (left), 1 (right)
	# Rule: If Speed 0 (stationary) OR Orbiting, free rotation.
	var is_stationary = (current_path.size() == 0)
	
	if not is_stationary and not state_is_orbiting:
		if not can_turn_this_step or turns_remaining <= 0:
			return
		turns_remaining -= 1
		can_turn_this_step = false # Used it
		
	ghost_ship.facing = posmod(ghost_ship.facing + direction, 6)
	
	ghost_ship.queue_redraw()
	queue_redraw() # Redraw GameManager to update grid highlight
	_update_ui_state()

var state_is_orbiting: bool = false # Temp state for UI

func _on_orbit(direction: int):
	# Authority Check
	if my_local_player_id > 0 and current_player_id != my_local_player_id:
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

func _on_ms_toggled(pressed: bool):
	# Authority Check
	if my_local_player_id > 0 and current_player_id != my_local_player_id:
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
	_update_ui_state()

func _on_commit_move():
	# Authority Check
	if my_local_player_id != 0 and current_player_id != my_local_player_id:
		log_message("Not your turn!")
		return
		
	# NETWORK: Send RPC
	# We need to send: Ship Name (Unique ID), Path, Facing, Orbit Dir
	var path_data = current_path # Array[Vector3i]
	# Optimization: Could just send Path? Facing is derived from ghost.
	# But ghost is local. We need to send ghost.facing.
	
	rpc("execute_commit_move", selected_ship.name, path_data, ghost_ship.facing, current_orbit_direction, state_is_orbiting)

@rpc("any_peer", "call_local", "reliable")
func execute_commit_move(ship_name: String, path: Array, final_facing: int, orbit_dir: int, is_orbiting: bool):
	# Find Ship
	var ship: Ship = null
	for s in ships:
		if s.name == ship_name:
			ship = s
			break
			
	if not ship:
		print("Error: Ship %s not found for move commit!" % ship_name)
		return
		
	# Apply State
	ship.orbit_direction = orbit_dir
	if not is_orbiting:
		ship.orbit_direction = 0
		
	# Apply Move
	ship.facing = final_facing
	ship.speed = path.size()
	
	# Current Path for this client (for visual/logic if needed, though we just teleport usually)
	# NOTE: collision checks happened on planner side. We assume valid if sent?
	# Or we should re-validate? For now, trust the sender (simpler).
	
	# Teleport/Animate
	# For "instant" update:
	ship.grid_position = path.back() if path.size() > 0 else ship.grid_position
	
	# COLLISION / BOUNDARY CHECKS (Must run on all to sync death?)
	# Use the logic from original _on_commit_move but applied to `ship` instead of `selected_ship`
	
	if _check_planet_collision(ship) or _check_boundary(ship):
		# Ship Died
		# Handle death logic (e.g. remove from list)
		pass
	
	# DOCKING LOGIC
	_handle_docking_states(ship)
	
	# CLEANUP (If this was the active client, clear ghost)
	if ship == selected_ship:
		if is_instance_valid(ghost_ship):
			ghost_ship.queue_free()
			ghost_ship = null
		combat_action_taken = false
		state_is_orbiting = false
		current_path.clear()
		
	_update_ship_visuals()
	
	# END TURN
	# If I am the one moving, this triggers my local end_turn -> selects next or phases
	# If I am remote, this updates state, then `end_turn` checks if more ships available?
	# `end_turn` logic needs to see whose turn it is.
	
	# We need to ensure `selected_ship` updating happens correctly for the NEXT ship.
	# If we just moved P1 Ship A. Next is P1 Ship B.
	# `end_turn` calls `start_movement_phase` which picks `available[0]`.
	# Since Ship A now has `has_moved = true` (Wait, we need to set that!), it won't be picked.
	
	ship.has_moved = true
	
	# Force Phase Check / Next Ship
	if current_phase == Phase.MOVEMENT:
		# If this client is the ACTIVE player, they select next.
		# If this client is PASSIVE, they just wait?
		# `start_movement_phase` handles "If no ships left, go to Combat".
		# We should ALL call end_turn() to advance state?
		# Yes, because end_turn() -> start_movement_phase() -> checks for next ship.
		# If P1 has ships left, they become selected.
		# If not, switch to Combat.
		end_turn()

func _handle_docking_states(ship: Ship):
	# 1. Check for Auto-Docking
	var potential_hosts = ships.filter(func(s): return s.player_id == ship.player_id and s != ship and s.grid_position == ship.grid_position)
	# Filter for valid hosts
	potential_hosts = potential_hosts.filter(func(s): return s.ship_class in ["Space Station", "Assault Carrier"])
	
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
		ship.queue_free()
		return true
	return false


func _draw():
	# transform.origin = center # REMOVED: Camera is now handled by _update_camera
	for q in range(-map_radius, map_radius + 1):
		for r in range(-map_radius, map_radius + 1):
			var s = -q - r
			if abs(s) > map_radius: continue
			var hex = Vector3i(q, r, s)
			draw_hex(hex)
	
	if ghost_ship and current_path.size() > 0:
		var points = PackedVector2Array()
		points.append(HexGrid.hex_to_pixel(selected_ship.grid_position))
		for h in current_path:
			points.append(HexGrid.hex_to_pixel(h))
		draw_polyline(points, Color(1, 1, 1, 0.5), 3.0)
		
	# Predictive Path Highlighting
	# FIX: Ensure we have a ghost ship AND are in movement phase
	if current_phase == Phase.MOVEMENT and is_instance_valid(ghost_ship):
		# Re-verify start_speed is set (it should be set in start_movement_phase)
		# But if ghost_ship was respawned, did we lose context?
		# No, start_speed is a GM var.
		var steps_taken = current_path.size()
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
		
		var min_speed = max(0, start_speed - selected_ship.adf)
		var max_speed = start_speed + selected_ship.adf
		
		var orange_count = max(0, min_speed - steps_taken)
		var green_count = max(0, start_speed - steps_taken - orange_count)
		var yellow_count = max(0, max_speed - steps_taken - orange_count - green_count)
		
		var forward_vec = HexGrid.get_direction_vec(ghost_ship.facing)
		var current_check_hex = ghost_ship.grid_position
		
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
		var len = 10
		draw_line(pos + Vector2(-len, 0), pos + Vector2(len, 0), Color.RED, 2.0)
		draw_line(pos + Vector2(0, -len), pos + Vector2(0, len), Color.RED, 2.0)

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
	draw_polyline(points, Color(0.2, 0.2, 0.2), 1.0)
	
	# Basic highlighting handled by predictive path now, removing old logic to avoid clutter


func _unhandled_input(event):
	# Authority Check
	if my_local_player_id != 0:
		# If it's not my turn (Movement) OR not my firing phase (Combat)
		# Movement: current_player_id must match
		# Combat: firing_player_id must match
		var active_id = current_player_id
		if current_phase == Phase.COMBAT:
			active_id = firing_player_id
			
		if active_id != my_local_player_id:
			# print("Input Rejected: Active %d vs Local %d" % [active_id, my_local_player_id])
			return # Ignore input for other players
			
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_mouse = get_local_mouse_position()
		var hex_clicked = HexGrid.pixel_to_hex(local_mouse)
		handle_click(hex_clicked)
	
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
			_update_camera()

func _is_weapon_available_in_phase(weapon: Dictionary, ship: Ship = null) -> bool:
	var w_type = weapon.get("type")
	# Rule 1: Moving Player Only for Propelled weapons (Assault Rockets, Torpedoes)
	# Rocket Batteries are EXEMPT from this (can be fired defensively)
	var is_propelled_movement_restricted = w_type in ["Rocket", "Torpedo"]
	
	if is_propelled_movement_restricted:
		if firing_player_id != current_player_id:
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
		if s.player_id != shooter.player_id and not s.is_exploding:
			# Check against ALL available weapons (or just current? usually any valid weapon means ship is active)
			# Let's check if ANY weapon can hit the target
			var can_hit = false
			for weapon in shooter.weapons:
				if weapon["ammo"] <= 0: continue
				if weapon.get("fired", false): continue
				
				var w_range = weapon["range"]
				var w_arc = weapon["arc"]
				var d = HexGrid.hex_distance(shooter.grid_position, s.grid_position)
				
				if d > w_range: continue
				
				# LOS Check (Planet Blocking)
				var line_hexes = HexGrid.get_line_coords(shooter.grid_position, s.grid_position)
				var blocked = false
				for h in line_hexes:
					if h in planet_hexes:
						# "Firing through". 
						# Usually, if shooter or target is IN the planet, it's weird, but technically blocked too?
						# Or is it only blocked if an INTERMEDIATE hex mimics blocking?
						# Prompt: "A ship may not fire through a hex containing a planet."
						# Exclude Start and End? 
						# If Start is inside, you can't fire out? If End is inside, you can't fire in?
						# Let's assume strict blocking: If ANY hex in the line is a planet, it's blocked.
						# Unless the ship is magically "above" it? No, collisions imply same plane.
						blocked = true
						break
				
				if blocked: continue

				if w_arc == "FF":
					var valid_hexes = _get_ff_arc_hexes(shooter, w_range)
					if s.grid_position in valid_hexes:
						can_hit = true
						break # Found a valid weapon for this target
				else:
					# Default or Turret (360)
					can_hit = true
					break
			
			if can_hit:
				valid.append(s)
	return valid

func handle_click(hex: Vector3i):
	if current_phase == Phase.MOVEMENT:
		# Check if clicked on a friendly available ship (CHANGE SELECTION)
		var clicked_ship = null
		for s in ships:
			if s.grid_position == hex and s.player_id == current_player_id and not s.has_moved:
				clicked_ship = s
				break
		
		if clicked_ship and clicked_ship != selected_ship:
			selected_ship = clicked_ship
			# Reset plot
			_reset_plotting_state()
			
			if audio_ship_select and audio_ship_select.stream: audio_ship_select.play()
			_spawn_ghost()
			_update_camera()
			_update_ship_visuals() # Re-sort stack
			_update_ui_state()
			log_message("Selected %s" % selected_ship.name)
			return

		_handle_ghost_input(hex)
	elif current_phase == Phase.COMBAT:
		_handle_combat_click(hex)

func _handle_ghost_input(hex: Vector3i):
	if not ghost_ship: return
	
	# Strict Rule: Must be along Forward Vector
	var forward_vec = HexGrid.get_direction_vec(ghost_ship.facing)
	var diff = hex - ghost_ship.grid_position
	
	# Check if straight line
	# A diff is a multiple of forward_vec if:
	# For hexes, we must check if the distance matches the magnitude of diff in that direction.
	# Simplest: Distance between them equals the dot-like check or loop.
	# Since grid is discrete, checking if hex is in the path of repeated forward_vec additions.
	
	var dist = HexGrid.hex_distance(ghost_ship.grid_position, hex)
	if dist == 0: return # Clicked itself
	
	# Verify it is exactly in the forward direction
	# We can check direction index matching
	var valid_hex = false
	var check = ghost_ship.grid_position + (forward_vec * dist)
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
	var max_allowed_path = start_speed + selected_ship.adf
	if current_path.size() + dist > max_allowed_path:
		log_message("Target too far! Limit: %d hexes" % max_allowed_path)
		return

	# Execute Move (Loop for each step)
	for i in range(dist):
		var next_hex = ghost_ship.grid_position + forward_vec
		ghost_ship.grid_position = next_hex
		current_path.append(next_hex)
		# "Usage" of turn opportunity:
		# Logic: You only get the turn opportunity for the FINAL hex entered in this sequence.
		# Intermediate hexes: You moved out of them without turning, so opportunity lost.
		# Final hex: You just entered it, so you can turn now.
	
	# Enable turning for the final step
	can_turn_this_step = true
	
	if audio_beep.stream: audio_beep.play()

	queue_redraw()
	queue_redraw()
	_update_ui_state()

# Helper
func posmod(a, b):
	var res = a % b
	if res < 0 and b > 0: res += b
	return res

func _trigger_icm_decision(attacker_name: String, weapon_name: String, weapon_type: String, current_chance: int, target: Ship):
	# Create modal UI
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
	# Initial Text
	var update_text = func(icm_count: int):
		var reduction = Combat.calculate_icm_reduction(weapon_type, icm_count)
		var final_chance = max(0, current_chance - reduction)
		lbl.text = "INCOMING FIRE DETECTED!\n%s firing %s\nBase Chance: %d%% -> Adjusted: %d%%" % [attacker_name, weapon_name, current_chance, final_chance]
	
	update_text.call(0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	
	# Network Logic: Who decides?
	var is_target_owner = (target.player_id == my_local_player_id) or (my_local_player_id == 0) # Debug/0 can also decide
	
	if is_target_owner:
		var lbl_ammo = Label.new()
		lbl_ammo.text = "ICMs Available: %d" % target.icm_current
		vbox.add_child(lbl_ammo)
		
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)
		
		var btn_fire = Button.new()
		btn_fire.text = "LAUNCH ICM !"
		hbox.add_child(btn_fire)
		
		var spin = SpinBox.new()
		spin.min_value = 0
		spin.max_value = target.icm_current
		spin.value = 0
		spin.select_all_on_focus = true
		hbox.add_child(spin)
		
		spin.value_changed.connect(func(val):
			update_text.call(int(val))
		)
		
		var btn_skip = Button.new()
		btn_skip.text = "DO NOT FIRE"
		vbox.add_child(btn_skip)
		
		# Connect signals
		btn_fire.pressed.connect(func():
			var count = int(spin.value)
			if count > 0:
				_submit_icm_decision(count)
			else:
				_submit_icm_decision(0)
		)
		
		btn_skip.pressed.connect(func(): _submit_icm_decision(0))
		
	else:
		# Waiting Message
		var lbl_wait = Label.new()
		lbl_wait.text = "\n(Waiting for Defender to decide on ICMs...)"
		lbl_wait.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(lbl_wait)

func _submit_icm_decision(count: int):
	# Send RPC to broadcast decision
	rpc("broadcast_icm_decision", count)

@rpc("any_peer", "call_local", "reliable")
func broadcast_icm_decision(count: int):
	# Close UI on all clients
	if panel_icm:
		panel_icm.queue_free()
		panel_icm = null
		
	# Resume combat resolution logic on all clients (locally)
	icm_decision_made.emit(count)

func _on_ship_destroyed(ship: Ship):
	ships.erase(ship)
	_update_ship_visuals() # Re-calc stacks
	log_message("Ship destroyed: %s" % ship.name)
	
	# Check for Victory
	var p1_count = 0
	var p2_count = 0
	for s in ships:
		if s.player_id == 1: p1_count += 1
		elif s.player_id == 2: p2_count += 1
	
	if p1_count == 0 and p2_count == 0:
		show_game_over("Draw!")
	elif p1_count == 0:
		show_game_over("Winner: Player 2!")
	elif p2_count == 0:
		show_game_over("Winner: Player 1!")

func show_game_over(msg: String):
	current_phase = Phase.END
	label_winner.text = msg
	panel_game_over.visible = true
	_update_ui_state()
	log_message(msg)

func _on_restart():
	get_tree().reload_current_scene()

func end_turn():
	if current_phase == Phase.END: return

	if audio_action_complete and audio_action_complete.stream:
		audio_action_complete.play()
	
	if current_phase == Phase.MOVEMENT:
		if selected_ship:
			selected_ship.has_moved = true
			
			# Orbit MS Check: Did we complete the loop?
			# If MS active AND Orbiting AND Position == Start Hex
			if selected_ship.is_ms_active and selected_ship.orbit_direction != 0:
				if selected_ship.ms_orbit_start_hex != Vector3i.MAX:
					if selected_ship.grid_position == selected_ship.ms_orbit_start_hex:
						selected_ship.is_ms_active = false
						selected_ship.ms_orbit_start_hex = Vector3i.MAX
						log_message("%s completes orbit; Screen drops." % selected_ship.name)
					
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
	if panel_planning and panel_planning.visible and mini_map:
		var pp_rect = panel_planning.get_global_rect()
		var new_y = pp_rect.end.y + 20
		# Clamp to screen?
		var screen_h = get_viewport_rect().size.y
		if new_y + 200 > screen_h:
			new_y = screen_h - 220
			
		mini_map.position = Vector2(get_viewport_rect().size.x - 220, new_y)

func load_scenario(key: String, seed_val: int = 12345):
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
		var s = Ship.new()
		add_child(s)
		
		# Configure Class
		var cls = data.get("class", "Fighter")
		match cls:
			"Station", "Space Station": s.configure_space_station()
			"Fighter": s.configure_fighter()
			"Assault Scout": s.configure_assault_scout()
			"Frigate": s.configure_frigate()
			"Destroyer": s.configure_destroyer()
			"Heavy Cruiser": s.configure_heavy_cruiser()
			"Battleship": s.configure_battleship()
			"Assault Carrier": s.configure_assault_carrier()
			_:
				log_message("Unknown class %s, defaulting to Scout" % cls)
				s.configure_assault_scout()
		
		# Base Properties
		s.name = data.get("name", "Ship")
		s.faction = data.get("faction", "UPF")
		# Handle side/side_index variance
		var s_idx = data.get("side", data.get("side_index", 0))
		s.player_id = s_idx + 1 # 0->1, 1->2
		
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
		if s.speed > 0: s.has_moved = true
		
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
				
		s.binding_pos_update()
		s.ship_destroyed.connect(func(ship): _on_ship_destroyed(ship))
		ships.append(s)
		
	# Docking (Pass 2)
	for data in ship_list:
		if data.has("docked_at"):
			var host_name = data["docked_at"]
			var host = null
			for cand in ships:
				if cand.name == host_name:
					host = cand
					break
			
			if host:
				var s_name = data["name"]
				var s = null
				for cand in ships:
					if cand.name == s_name:
						s = cand
						break
				
				if s:
					s.dock_at(host)
					log_message("%s docked at %s" % [s.name, host.name])

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
						if s.name == rule["trigger_name"]:
							trigger = s
							break
					
					if trigger:
						var condition = rule["trigger_condition"]
						var active = false
						if condition == "undocked":
							active = not trigger.is_docked
						elif condition == "docked":
							active = trigger.is_docked
							
						if active:
							log_message("Action '%s' blocked by scenario rule!" % action)
							return true # Debuff IS active, so action is blocked
	
	return false
