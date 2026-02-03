class_name GameManager
extends Node2D

@export var map_radius: int = 25

var ships: Array[Ship] = []
var current_turn_index: int = 0
var selected_ship: Ship = null

# Phase Enum
enum Phase { START, MOVEMENT, COMBAT, END }
var current_phase: Phase = Phase.START

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
	start_turn()

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

var audio_laser: AudioStreamPlayer
var audio_hit: AudioStreamPlayer

var combat_log: RichTextLabel


func log_message(msg: String):
	combat_log.append_text(msg + "\n")
	print(msg)

func _handle_combat_click(hex: Vector3i):
	if combat_action_taken: return
	
	for s in ships:
		if s != selected_ship and s.grid_position == hex:
			var start_pos = HexGrid.hex_to_pixel(selected_ship.grid_position)
			var target_pos = HexGrid.hex_to_pixel(s.grid_position)
			
			combat_action_taken = true
			_spawn_laser(start_pos, target_pos)
			if audio_laser.stream: audio_laser.play()
			
			var d = HexGrid.hex_distance(selected_ship.grid_position, s.grid_position)
			if Combat.roll_for_hit(d):
				var dmg = Combat.roll_damage()
				log_message("[color=green]HIT![/color] Range: %d, Damage: %d" % [d, dmg])
				s.take_damage(dmg)
				_spawn_hit_text(target_pos, dmg)
				if audio_hit.stream: audio_hit.play()
				
				# Wait for hit animation (3.0s)
				get_tree().create_timer(3.0).timeout.connect(end_turn)
			else:
				log_message("[color=red]MISS![/color] Range: %d" % d)
				# Wait for laser animation (2.0s)
				get_tree().create_timer(2.0).timeout.connect(end_turn)

func _spawn_laser(start: Vector2, end: Vector2):
	var line = Line2D.new()
	line.width = 3.0
	line.default_color = Color(1, 0, 0, 1) # Red laser
	line.points = PackedVector2Array([start, end])
	add_child(line)
	
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 2.0)
	tween.tween_callback(line.queue_free)

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
	# Ship 1 (Left side) - Player 1
	var s1 = Ship.new()
	s1.name = "Ship_Player1"
	s1.player_id = 1
	s1.color = Color.CYAN
	s1.grid_position = Vector3i(-3, 0, 3)
	s1.facing = 0 # Right
	s1.speed = 0 # Start stopped or 0? User moved from 0 to 1, implies 0 start.
	s1.adf = 5
	s1.mr = 3
	add_child(s1)
	ships.append(s1)
	
	# Ship 2 (Right side) - Player 2
	var s2 = Ship.new()
	s2.name = "Ship_Player2"
	s2.player_id = 2
	s2.color = Color.RED
	s2.grid_position = Vector3i(3, 0, -3)
	s2.facing = 3 # Left
	s2.speed = 0
	s2.adf = 5
	s2.mr = 3
	add_child(s2)
	ships.append(s2)

func start_turn():
	current_phase = Phase.MOVEMENT
	selected_ship = ships[current_turn_index]
	
	_spawn_ghost()
	
	start_speed = selected_ship.speed
	current_path = []
	turns_remaining = selected_ship.mr
	can_turn_this_step = false
	
	_update_ui_state()
	_update_ui_state()
	log_message("Turn Start: Player %d" % selected_ship.player_id)
	
	combat_action_taken = false
	_update_camera()

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
		txt += "Stats: ADF %d | MR %d\n" % [selected_ship.adf, selected_ship.mr]
		txt += "Remaining MR: %d\n" % turns_remaining
		txt += "Speed: %d -> %d / Range: [%d, %d]" % [start_speed, steps, min_speed, max_speed]
		if not is_valid:
			txt += "\n(Invalid Speed)"
		label_status.text = txt
		
	elif current_phase == Phase.COMBAT:
		btn_undo.visible = false
		btn_commit.visible = false
		btn_turn_left.visible = false
		btn_turn_right.visible = false
		label_status.text = "Combat Phase: Click target in range (10)"

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
	
	ghost_ship.queue_free()
	ghost_ship = null
	
	start_combat()

func start_combat():
	current_phase = Phase.COMBAT
	queue_redraw()
	_update_ui_state()
	log_message("Combat Phase Started")

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

func _draw_hex_outline(hex: Vector3i, color: Color, width: float):
	var center = HexGrid.hex_to_pixel(hex)
	var size = HexGrid.TILE_SIZE
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i + 30)
		points.append(center + Vector2(size * cos(angle), size * sin(angle)))
	points.append(points[0]) # Close loop
	draw_polyline(points, color, width)

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

func handle_click(hex: Vector3i):
	if current_phase == Phase.MOVEMENT:
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
	
	queue_redraw()
	_update_ui_state()



func end_turn():
	current_turn_index = (current_turn_index + 1) % ships.size()
	start_turn()
