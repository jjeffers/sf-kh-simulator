class_name GameManager
extends Node2D

@export var map_radius: int = 25

var ships: Array[Ship] = []
var current_player_id: int = 1 # The "Active" moving player
var firing_player_id: int = 0 # The player currently firing in Combat Phase
var selected_ship: Ship = null
var combat_target: Ship = null

@export var camera_speed: float = 500.0

# Phase Enum
enum Phase { START, MOVEMENT, COMBAT, END }
# Combat State Enum
enum CombatState { NONE, PLANNING, RESOLVING }

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

# Planning UI
var panel_planning: PanelContainer
var container_ships: VBoxContainer

# ICM UI
signal icm_decision_made(count: int)
var panel_icm: PanelContainer


func _ready():
	_setup_ui()
	queue_redraw()
	_spawn_planets()
	spawn_ships()
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
	panel_planning.anchor_bottom = 0.75
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
	
	# Audio Setup
	var audio_node = Node.new()
	audio_node.name = "AudioParams"
	add_child(audio_node)
	
	audio_laser = AudioStreamPlayer.new()
	if FileAccess.file_exists("res://Assets/Audio/laser.wav"):
		audio_laser.stream = load("res://Assets/Audio/laser.wav")
	elif FileAccess.file_exists("res://Assets/Audio/laser.mp3"):
		audio_laser.stream = load("res://Assets/Audio/laser.mp3")
	add_child(audio_laser)
	
	audio_hit = AudioStreamPlayer.new()
	if FileAccess.file_exists("res://Assets/Audio/hit.wav"):
		audio_hit.stream = load("res://Assets/Audio/hit.wav")
	elif FileAccess.file_exists("res://Assets/Audio/hit.mp3"):
		audio_hit.stream = load("res://Assets/Audio/hit.mp3")
	add_child(audio_hit)

	audio_beep = AudioStreamPlayer.new()
	if FileAccess.file_exists("res://Assets/Audio/short-low-beep.mp3"):
		audio_beep.stream = load("res://Assets/Audio/short-low-beep.mp3")
	add_child(audio_beep)

	audio_action_complete = AudioStreamPlayer.new()
	if FileAccess.file_exists("res://Assets/Audio/short-next-selection.mp3"):
		audio_action_complete.stream = load("res://Assets/Audio/short-next-selection.mp3")
	add_child(audio_action_complete)
	
	audio_phase_change = AudioStreamPlayer.new()
	if FileAccess.file_exists("res://Assets/Audio/short-sound.mp3"):
		audio_phase_change.stream = load("res://Assets/Audio/short-sound.mp3")
	add_child(audio_phase_change)

	audio_ship_select = AudioStreamPlayer.new()
	if FileAccess.file_exists("res://Assets/Audio/short-departure.mp3"):
		audio_ship_select.stream = load("res://Assets/Audio/short-departure.mp3")
	add_child(audio_ship_select)

var audio_laser: AudioStreamPlayer
var audio_hit: AudioStreamPlayer
var audio_beep: AudioStreamPlayer
var audio_action_complete: AudioStreamPlayer
var audio_phase_change: AudioStreamPlayer
var audio_ship_select: AudioStreamPlayer

var combat_log: RichTextLabel

# Game Over UI
var panel_game_over: PanelContainer
var label_winner: Label
var btn_restart: Button

func log_message(msg: String):
	combat_log.append_text(msg + "\n")
	print(msg)

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
				log_message("Switched to %s" % selected_ship.name)
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
		
		log_message("Planned: %s -> %s (%s)" % [selected_ship.name, s.name, weapon["name"]])
		
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
					log_message("Targeting: %s" % s.name)
					_update_ship_visuals() # Ensure target pops to top
					break

func _spawn_icm_fx(target: Ship, attacker_pos: Vector2, duration: float = 0.5):
	var start = target.position
	# Intercept point roughly 1 hex towards attacker
	var dir = (attacker_pos - start).normalized()
	var intercept_pos = start + dir * HexGrid.TILE_SIZE * 0.8
	
	# Create multiple small missiles
	for i in range(3):
		var m = Polygon2D.new()
		m.polygon = PackedVector2Array([Vector2(3,0), Vector2(-2, -1), Vector2(-2, 1)])
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
		tween.tween_property(m, "position", intercept_pos + offset, my_time + (i*0.05))
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
		var dist_px = start.distance_to(end)
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
		var dist_px = start.distance_to(end)
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
	if current_combat_state != CombatState.PLANNING: return
	
	current_combat_state = CombatState.RESOLVING
	pending_resolutions = queued_attacks.duplicate()
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
		log_message("%s destroyed before firing! Attack fizzles." % source.name)
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
		log_message("%s firing at WRECK of %s! (Wasted)" % [source.name, target.name if is_instance_valid(target) else "Unknown"])
		_spawn_attack_fx(start_pos, target_pos, weapon.get("type"))
		await get_tree().create_timer(1.5).timeout
		_process_next_attack()
		return

	# Execute Fire Logic
	log_message("%s firing %s at %s" % [source.name, weapon["name"], target.name])
	
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
	if target.icm_current > 0 and w_type in ["Torpedo", "Rocket", "Rocket Battery"]:
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
	var hit = Combat.roll_for_hit(d, weapon, target, is_head_on, icm_used, source)
	
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
	_process_next_attack()

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

func spawn_station(player_id: int):
	var s = Ship.new()
	add_child(s)
	s.configure_space_station() # Random hull
	s.player_id = player_id
	s.color = Color.RED if player_id == 2 else Color.GREEN
	s.name = "Station Alpha"
	
	# Placement: Orbit if possible
	var placed = false
	if planet_hexes.size() > 0:
		# Pick random planet hex (excluding 0,0,0 if it's reserved? current array has 0,0,0)
		var p_hex = planet_hexes.pick_random()
		# Pick random neighbor for orbit
		var neighbors = HexGrid.get_neighbors(p_hex)
		var orbit_hex = neighbors.pick_random()
		
		# Check if occupied?
		# Simple check: Just place it. Collisions handled later?
		# Better: Check existing ships
		s.grid_position = orbit_hex
		s.facing = randi() % 6
		s.orbit_direction = 1 # CW Orbit default
		s.orbit_direction = 1 # CW Orbit default
		# state_is_orbiting is a GM transient var, not on Ship. 
		# Setting orbit_direction is sufficient for persistence.
		# For now, just placing it in orbit hex + orbit_dir is enough for GM to pick up "orbit" logic next turn.
		placed = true
		
	if not placed:
		s.grid_position = Vector3i(0, 0, 0) # Center if no planets (though planet logic usually destroys ships at center!)
		# User said "place near middle". If Planet at 0,0,0, placing at 0,0,0 dies.
		# Place at 1,0,-1 (Neighbor of center)
		s.grid_position = Vector3i(1, 0, -1)
	
	ships.append(s)
	log_message("Station Alpha online. Hull: %d" % s.hull)

func spawn_ships():
	# Player 1 (Left side)
	for i in range(3):
		var s = Ship.new()
		s.name = "P1_Fighter_%d" % (i + 1)
		
		# Make the 3rd ship an Assault Scout for testing
		if i == 2:
			s.configure_assault_scout()
			s.name = "P1_Scout_1"
		else:
			s.configure_fighter() # Set stats and weapons
			
		s.player_id = 1
		s.color = Color.CYAN
		s.grid_position = Vector3i(-3, i, 3 - i) # Staggered positions or stack if desired. Let's stack 2 and 3?
		# User asked to stack. Let's stack them all on one hex for test, or adjacent? 
		# "Add 2 more ships per side". Let's put them nearby.
		if i == 0: s.grid_position = Vector3i(-3, 0, 3)
		if i == 1: s.grid_position = Vector3i(-3, 1, 2)
		if i == 2: s.grid_position = Vector3i(-4, 1, 3) 
		
		s.binding_pos_update() # Call helper to set initial position immediately
		
		s.ship_destroyed.connect(func(): _on_ship_destroyed(s))
		add_child(s)
		ships.append(s)

	# Player 2 (Right side)
	# Heavy Cruiser
	var hc = Ship.new()
	hc.name = "Heavy Cruiser"
	hc.configure_heavy_cruiser()
	hc.player_id = 2
	hc.color = Color.RED
	hc.grid_position = Vector3i(4, -8, 4)
	hc.facing = 3
	hc.binding_pos_update()
	hc.ship_destroyed.connect(func(): _on_ship_destroyed(hc))
	add_child(hc)
	ships.append(hc)
	
	# Destroyer
	var dd = Ship.new()
	dd.name = "Destroyer"
	dd.configure_destroyer()
	dd.player_id = 2
	dd.color = Color.RED
	dd.grid_position = Vector3i(3, -1, -2) # Near centerish or flank?
	# Let's place it roughly opposite P1
	dd.facing = 3
	dd.binding_pos_update()
	dd.ship_destroyed.connect(func(): _on_ship_destroyed(dd))
	add_child(dd)
	ships.append(dd)
	
	spawn_station(2) # Spawn Station
	
	_update_ship_visuals()

func _cycle_selection():
	if current_phase == Phase.MOVEMENT:
		# Filter: Active Player, !has_moved
		var available = ships.filter(func(s): return s.player_id == current_player_id and not s.has_moved)
		if available.size() <= 1: return
		
		var idx = available.find(selected_ship)
		var next_idx = (idx + 1) % available.size()
		selected_ship = available[next_idx]
		
		# Reset plotting
		current_path = []
		turns_remaining = selected_ship.mr
		turns_remaining = selected_ship.mr
		can_turn_this_step = false
		start_speed = selected_ship.speed
		start_ms_active = selected_ship.is_ms_active
		
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
	for s in ships:
		s.reset_weapons()
	start_movement_phase()

func start_movement_phase():
	var is_phase_change = (current_phase != Phase.MOVEMENT)
	current_phase = Phase.MOVEMENT
	combat_subphase = 0
	firing_player_id = 0
	
	# Find un-moved ships for ACTIVE player
	var available = ships.filter(func(s): return s.player_id == current_player_id and not s.has_moved)
	
	if available.size() == 0:
		start_combat_passive()
		return

	# Select first available
	selected_ship = available[0]
	
	if audio_ship_select and audio_ship_select.stream:
		audio_ship_select.play()
	
	_spawn_ghost()
	current_path = []
	start_speed = selected_ship.speed
	turns_remaining = selected_ship.mr
	can_turn_this_step = false
	state_is_orbiting = false
	current_orbit_direction = 0
	start_ms_active = selected_ship.is_ms_active
	
	# Check for Persistent Orbit
	if selected_ship.orbit_direction != 0:
		_on_orbit(selected_ship.orbit_direction) 
		# This effectively pre-plans the move.
		# User can then just hit Engage.
		log_message("Auto-plotting Orbit...")
	
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
	_update_planning_ui_list()
	queue_redraw()

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
		if is_planned: status_str = "[ORD]" # Ordered
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
		
		btn.text = "%s %s" % [status_str, s.name]

		btn.pressed.connect(func():
			selected_ship = s
			combat_target = null
			_update_planning_ui_list()
			_update_ui_state()
			_update_ship_visuals()
			queue_redraw()
		)
		
		container_ships.add_child(btn)
	
	panel_planning.visible = (current_phase == Phase.COMBAT and current_combat_state == CombatState.PLANNING)

# _check_combat_availability removed/replaced by explicit planning flow


func end_turn_cycle():
	log_message("Turn Complete. Switching Active Player.")
	current_player_id = 3 - current_player_id
	
	# Reset ALL ships
	for s in ships:
		s.reset_turn_state()
		
	start_movement_phase()

func _update_camera():
	if not selected_ship: return
	var center = get_viewport_rect().size / 2
	var target_pos = HexGrid.hex_to_pixel(selected_ship.grid_position)
	# Center ship on screen
	position = center - target_pos

func _spawn_ghost():
	if ghost_ship:
		ghost_ship.queue_free()
	
	ghost_ship = Ship.new()
	ghost_ship.name = "GhostShip"
	ghost_ship.player_id = selected_ship.player_id
	ghost_ship.ship_class = selected_ship.ship_class # Copy visual class
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
			txt += "\nShip: %s" % selected_ship.name
			if selected_ship.weapons.size() > 0:
				var w = selected_ship.weapons[selected_ship.current_weapon_index]
				txt += "\nWeapon: %s" % w["name"]
				txt += "\nAmmo: %d | Rng: %d | Arc: %s" % [w["ammo"], w["range"], w["arc"]]
				if w.get("fired", false):
					txt += " (FIRED)"
		
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
	
	if not found: return
	
	# Calculate move
	var neighbors = HexGrid.get_neighbors(planet_hex)
	var my_idx = neighbors.find(selected_ship.grid_position)
	
	if my_idx == -1: return # Should not happen if distance is 1
	
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
	state_is_orbiting = false
	
	# Update Persistent Orbit State
	if current_orbit_direction != 0:
		# If we used the orbit button this turn, set it.
		# Check if we actually executed the orbit move?
		# Logic: current_orbit_direction is set by _on_orbit or start_movement auto-plan.
		# If current_path matches the orbit move (length 1), we confirm it.
		if current_path.size() == 1:
			selected_ship.orbit_direction = current_orbit_direction
		else:
			selected_ship.orbit_direction = 0 # Broke orbit
	else:
		selected_ship.orbit_direction = 0 # Normal move clears orbit
		
	current_orbit_direction = 0 # Reset for next ship
	
	# selected_ship.grid_position = ghost_ship.grid_position # OLD IMMEDIATE JUMP
	# selected_ship.facing = ghost_ship.facing
	# selected_ship.speed = current_path.size()
	
	# 1. Update facing effectively immediately (for the whole move? Or should we simulate steps?)
	# 2. Update speed.
	# 3. Simulate movement step by step for collision check.
	
	# Final MS Constraint Check (Duration/Commit)
	if selected_ship.is_ms_active and not state_is_orbiting:
		if current_path.size() != start_speed:
			_on_ms_toggled(false) # Drop
			log_message("Screen Dropped: Speed Changed")
	
	selected_ship.facing = ghost_ship.facing
	selected_ship.speed = current_path.size()
	
	for hex in current_path:
		selected_ship.grid_position = hex # Teleport step
		# Collision Check
		if _check_planet_collision(selected_ship):
			# Ship died. Stop moving.
			combat_action_taken = false
			# Cleanup Ghosts and UI before ending turn
			ghost_ship.queue_free()
			ghost_ship = null
			
			end_turn() # Will select next ship or switch phase
			
			# No need to reset selected_ship = null or update_ui here, 
			# as end_turn -> start_movement_phase handles everything.
			return # Exit function
			
		# Boundary Check
		if _check_boundary(selected_ship):
			combat_action_taken = false
			ghost_ship.queue_free()
			ghost_ship = null
			end_turn()
			return

	_update_ship_visuals() # Ensure we re-stack after movement
	
	ghost_ship.queue_free()
	ghost_ship = null
	
	end_turn()

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
	if current_phase == Phase.MOVEMENT and ghost_ship:
		var steps_taken = current_path.size()
		var green_count = max(0, start_speed - steps_taken)
		var max_dist = start_speed + selected_ship.adf
		var yellow_count = max(0, max_dist - steps_taken - green_count)
		
		var forward_vec = HexGrid.get_direction_vec(ghost_ship.facing)
		var current_check_hex = ghost_ship.grid_position
		
		# Draw Green Hexes (Mandatory Momentum)
		for i in range(green_count):
			current_check_hex += forward_vec
			_draw_hex_outline(current_check_hex, Color(0, 1, 0, 0.6), 4.0)
			
		# Draw Yellow Hexes (Potential Acceleration)
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_mouse = get_local_mouse_position()
		var hex_clicked = HexGrid.pixel_to_hex(local_mouse)
		handle_click(hex_clicked)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_W:
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
			start_speed = selected_ship.speed
			current_path = []
			current_path = []
			turns_remaining = selected_ship.mr
			can_turn_this_step = false
			start_ms_active = selected_ship.is_ms_active
			
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

func _submit_icm_decision(count: int):
	if panel_icm:
		panel_icm.queue_free()
		panel_icm = null
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
