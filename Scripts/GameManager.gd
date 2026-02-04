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
var current_phase: Phase = Phase.START

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

# Movement State
var ghost_ship: Ship = null
var current_path: Array[Vector3i] = [] # List of hexes visited
var turns_remaining: int = 0
var start_speed: int = 0
var can_turn_this_step: bool = false # "Use it or lose it" flag
var combat_action_taken: bool = false # Lock to prevent click spam

func _ready():
	_setup_ui()
	queue_redraw()
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
	
	var is_click_on_target = false
	if combat_target:
		var mouse_pos = get_local_mouse_position()
		var dist_to_target = mouse_pos.distance_to(combat_target.position)
		is_click_on_target = (combat_target.grid_position == hex) or (dist_to_target < HexGrid.TILE_SIZE * 0.8)

	# If click on the target's hex OR visual representation, FIRE
	if is_click_on_target:
		var s = combat_target
		var start_pos = HexGrid.hex_to_pixel(selected_ship.grid_position)
		var target_pos = s.position # Use actual visual position for laser end
		
		combat_action_taken = true
		# Validate Range and Arc for specific weapon
		var weapon = selected_ship.weapons[selected_ship.current_weapon_index]
		var w_range = weapon["range"]
		var w_arc = weapon["arc"]
		var d = HexGrid.hex_distance(selected_ship.grid_position, s.grid_position)
		
		# Basic Range Check
		if d > w_range:
			log_message("[color=red]Target out of range! (Max %d)[/color]" % w_range)
			return

		# Arc Check (FF)
		if w_arc == "FF":
			var valid_hexes = _get_ff_arc_hexes(selected_ship, w_range)
			if not s.grid_position in valid_hexes:
				log_message("[color=red]Target not in Forward Firing Arc![/color]")
				return
				log_message("[color=red]Target not in Forward Firing Arc![/color]")
				return

		# Ammo Check
		if weapon["ammo"] <= 0:
			log_message("[color=red]Weapon Empty![/color]")
			return

		# FIRE!
		weapon["ammo"] -= 1
		combat_action_taken = true
		
		# FX
		_spawn_attack_fx(start_pos, target_pos, weapon.get("type", "Laser"))
		
		# Log shot
		var is_head_on = false
		if w_arc == "FF":
			if s.grid_position == selected_ship.grid_position:
				is_head_on = true
			else:
				var fwd_vec = HexGrid.get_direction_vec(selected_ship.facing)
				var check = selected_ship.grid_position + fwd_vec
				for i in range(w_range):
					if check == s.grid_position:
						is_head_on = true
						break
					check += fwd_vec
		
		if is_head_on:
			log_message("Heads On Bonus! +10% Hit Chance")
		
		log_message("Firing %s at %s..." % [weapon["name"], s.name])
		
		# Roll to Hit
		if Combat.roll_for_hit(d, weapon, s, is_head_on):
			# Construct Damage String: 2d10+4
			var dmg_str = "%s+%d" % [weapon["damage_dice"], weapon["damage_bonus"]]
			var dmg = Combat.roll_damage(dmg_str)
			
			log_message("[color=green]HIT![/color] Range: %d, Damage: %d" % [d, dmg])
			
			# Delay damage application to match FX? 
			# Simple approach: Apply now, showing floating text with delay matching FX
			
			# Wait for travel time (approx 0.5s for rockets)
			var delay = 0.5
			if weapon.get("type", "Laser") == "Laser": delay = 0.1
			
			get_tree().create_timer(delay).timeout.connect(func():
				s.take_damage(dmg)
				_spawn_hit_text(target_pos, dmg)
				if audio_hit.stream: audio_hit.play()
			)

			# Mark Weapon as Fired
			weapon["fired"] = true

			# Wait for turn end (Total animation time)
			get_tree().create_timer(3.0).timeout.connect(_post_fire_check)
		else:
			log_message("[color=red]MISS![/color] Range: %d" % d)
			# Mark Weapon as Fired (Even on miss?)
			# Standard rules: A shot is a shot.
			weapon["fired"] = true
			
			# Wait for animation (2.0s)
			get_tree().create_timer(2.0).timeout.connect(_post_fire_check)


	else:
		# Check if valid enemies at this hex to switch target
		for s in ships:
			if s.player_id != firing_player_id and s.grid_position == hex:
				var d = HexGrid.hex_distance(selected_ship.grid_position, s.grid_position)
				if d <= Combat.MAX_RANGE:
					combat_target = s
					queue_redraw()
					log_message("Targeting: %s" % s.name)
					_update_ship_visuals() # Ensure target pops to top
					break

func _spawn_attack_fx(start: Vector2, end: Vector2, type: String):
	if type == "Rocket":
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

		if audio_laser.stream: audio_laser.play() # Use existing sound like a launch
		
	else:
		# Default Laser
		var line = Line2D.new()
		line.width = 3.0
		line.default_color = Color(1, 0, 0, 1) # Red laser
		line.points = PackedVector2Array([start, end])
		add_child(line)
		
		var tween = create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 2.0)
		tween.tween_callback(line.queue_free)

		if audio_laser.stream: audio_laser.play()

func _post_fire_check():
	# Check if selected_ship has ANY valid targets remaining with UNFIRED, LOADED weapons
	var targets = _get_valid_targets(selected_ship)
	
	if targets.size() > 0:
		# Continue Turn
		combat_action_taken = false
		log_message("Attack Complete. Select next weapon [W] or target.")
		
		# Auto-switch to next available weapon if current is done?
		var weapon = selected_ship.weapons[selected_ship.current_weapon_index]
		if weapon.get("fired", false) or weapon["ammo"] <= 0:
			# Find next valid weapon
			for i in range(selected_ship.weapons.size()):
				var w = selected_ship.weapons[i]
				if not w.get("fired", false) and w["ammo"] > 0:
					selected_ship.current_weapon_index = i
					log_message("Auto-switched to %s" % w["name"])
					break
		
		queue_redraw()
		_update_ui_state()
		_update_camera() # Ensure camera stays valid
	else:
		# No more valid attacks
		end_turn()

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
	for i in range(3):
		var s = Ship.new()
		s.name = "P2_Fighter_%d" % (i + 1)
		s.configure_fighter() # Set stats and weapons
		s.player_id = 2
		s.color = Color.RED
		if i == 0: s.grid_position = Vector3i(3, 0, -3)
		if i == 1: s.grid_position = Vector3i(3, -1, -2)
		if i == 2: s.grid_position = Vector3i(4, -1, -3)
		
		s.facing = 3
		s.binding_pos_update()
		
		s.ship_destroyed.connect(func(): _on_ship_destroyed(s))
		add_child(s)
		ships.append(s)
	
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
		can_turn_this_step = false
		start_speed = selected_ship.speed
		
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
	
	_check_combat_availability()

func start_combat_active():
	current_phase = Phase.COMBAT
	combat_subphase = 2 # Active Second
	firing_player_id = current_player_id # The Active Player
	
	if audio_phase_change and audio_phase_change.stream:
		audio_phase_change.play()
	
	_check_combat_availability()

func _check_combat_availability():
	# Find un-fired ships for FIRING player
	# Loop until we find a ship with targets OR perform phase transition
	var found_valid_shooter = false
	
	while not found_valid_shooter:
		var available = ships.filter(func(s): return s.player_id == firing_player_id and not s.has_fired and not s.is_exploding)
		
		if available.size() == 0:
			if combat_subphase == 1:
				start_combat_active()
			else:
				end_turn_cycle()
			return

		# Check the first available ship
		# We must iterate through them because available[0] might have no targets, 
		# but available[1] might have targets.
		# THE RULE: "If no ships have any targets then end that turn" -> implicaiton: we skip useless ships.
		# "display a message indicating that no targets were avaialble."
		
		# Let's iterate through the available list
		var candidate = null
		
		for s in available:
			var targets = _get_valid_targets(s)
			if targets.size() > 0:
				candidate = s
				break
			else:
				# Mark as fired (Skipped)
				log_message("Skipping %s (No valid targets)" % s.name)
				s.has_fired = true
				
		if candidate:
			found_valid_shooter = true
			selected_ship = candidate
			
			# Ensure we start with a valid, unfired weapon
			var cur_w = selected_ship.weapons[selected_ship.current_weapon_index]
			if cur_w["ammo"] <= 0 or cur_w.get("fired", false):
				for i in range(selected_ship.weapons.size()):
					var w = selected_ship.weapons[i]
					if w["ammo"] > 0 and not w.get("fired", false):
						selected_ship.current_weapon_index = i
						break
		
			# Reset action lock
			combat_action_taken = false
			
			# Auto-target logic
			combat_target = null
			var targets = _get_valid_targets(selected_ship)
			if targets.size() > 0:
				combat_target = targets[0]
			
			queue_redraw()
			_update_ui_state()
			_update_camera()
			log_message("Combat: Player %d Firing (%s)" % [firing_player_id, "Passive" if combat_subphase == 1 else "Active"])
			
			# Ensure visual stack is updated
			_update_ship_visuals()
		else:
			# Loop will continue, checking 'available' again.
			# Since we marked ships with no targets as 'has_fired', the list size will shrink.
			# Eventually it hits 0 and changes phase.
			continue

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
		
		btn_commit.visible = true
		btn_commit.disabled = not is_valid
		
		btn_turn_left.visible = true
		btn_turn_right.visible = true
		
		# Can only turn if we just moved, haven't turned yet, and have MR left
		var allow_turn = can_turn_this_step and turns_remaining > 0
		btn_turn_left.disabled = not allow_turn
		btn_turn_right.disabled = not allow_turn
		
		var txt = "Player %d Plotting\n" % selected_ship.player_id
		txt += "Ship: %s (%s)\n" % [selected_ship.name, selected_ship.ship_class]
		txt += "Hull: %d\n" % selected_ship.hull
		txt += "Stats: ADF %d | MR %d\n" % [selected_ship.adf, selected_ship.mr]
		txt += "Remaining MR: %d\n" % turns_remaining
		txt += "Speed: %d -> %d / Range: [%d, %d]\n" % [start_speed, steps, min_speed, max_speed]
		
		txt += "Weapons:\n"
		for w in selected_ship.weapons:
			txt += "- %s (Ammo: %d)\n" % [w["name"], w["ammo"]]

		if not is_valid:
			txt += "\n(Invalid Speed)"
		label_status.text = txt
		
	elif current_phase == Phase.COMBAT:
		btn_undo.visible = false
		btn_commit.visible = false
		btn_turn_left.visible = false
		btn_turn_right.visible = false
		
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
		queue_redraw()
		_update_ui_state()

func _on_turn(direction: int):
	# direction: -1 (left), 1 (right)
	if not can_turn_this_step or turns_remaining <= 0:
		return
		
	ghost_ship.facing = posmod(ghost_ship.facing + direction, 6)
	turns_remaining -= 1
	can_turn_this_step = false # Used it
	
	ghost_ship.queue_redraw()
	queue_redraw() # Redraw GameManager to update grid highlight
	_update_ui_state()

func _on_commit_move():
	selected_ship.grid_position = ghost_ship.grid_position
	selected_ship.facing = ghost_ship.facing
	selected_ship.speed = current_path.size()
	
	_update_ship_visuals() # Ensure we re-stack after movement
	
	ghost_ship.queue_free()
	ghost_ship = null
	
	end_turn()

	combat_action_taken = false
	_update_camera()

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

	# Weapon Range Highlighting (Combat Phase)
	if current_phase == Phase.COMBAT and selected_ship and selected_ship.weapons.size() > 0:
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


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_mouse = get_local_mouse_position()
		var hex_clicked = HexGrid.pixel_to_hex(local_mouse)
		handle_click(hex_clicked)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_W:
		# Cycle Weapon
		if current_phase == Phase.COMBAT and selected_ship and selected_ship.weapons.size() > 1:
			var idx = selected_ship.current_weapon_index
			idx = (idx + 1) % selected_ship.weapons.size()
			selected_ship.current_weapon_index = idx
			var w = selected_ship.weapons[idx]
			log_message("Weapon switched to: %s (Ammo: %d, Arc: %s)" % [w["name"], w["ammo"], w["arc"]])
			queue_redraw()
			_update_ui_state()
			_update_camera()

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
			turns_remaining = selected_ship.mr
			can_turn_this_step = false
			
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
	_update_ui_state()



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
		if selected_ship: selected_ship.has_moved = true
		start_movement_phase() # Loop to next ship
		
	elif current_phase == Phase.COMBAT:
		if selected_ship: selected_ship.has_fired = true
		_check_combat_availability() # Loop to next ship or next subphase
