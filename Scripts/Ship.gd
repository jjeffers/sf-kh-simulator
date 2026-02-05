class_name Ship
extends Node2D

const MAX_HULL = 15

@export var player_id: int = 1
@export var adf: int = 5
@export var mr: int = 3
@export var color: Color = Color.WHITE

var hull: int = MAX_HULL
var grid_position: Vector3i = Vector3i.ZERO : set = _set_grid_position
var facing: int = 0 : set = _set_facing # 0 to 5, direction index
var speed: int = 0
var has_moved: bool = false
var has_fired: bool = false
var orbit_direction: int = 0 # 0=None, 1=CW, -1=CCW

# Class and Weapons
var ship_class: String = "Scout"
var defense: String = "None"
# Weapon Dictionary: {name, type, range, arc, ammo, max_ammo, damage_dice, damage_bonus}
var weapons: Array = [] 
var current_weapon_index: int = 0

signal ship_moved(new_pos)
signal ship_destroyed
signal hull_changed(new_value)

func configure_fighter():
	ship_class = "Fighter"
	defense = "RH" # Reflective Hull
	hull = 8
	adf = 5
	mr = 5
	
	weapons.clear()
	# Assault Rockets: Range 4, Forward Firing (FF), Ammo 3, 2d10+4
	weapons.append({
		"name": "Assault Rockets",
		"type": "Rocket",
		"range": 4,
		"arc": "FF",
		"ammo": 3,
		"max_ammo": 3,
		"damage_dice": "2d10",
		"damage_bonus": 4,
		"fired": false
	})
	current_weapon_index = 0

func configure_assault_scout():
	ship_class = "Assault Scout"
	defense = "RH"
	hull = 15
	adf = 5
	mr = 4
	
	weapons.clear()
	# Laser Battery: Range 9, 360 Arc, 1d10
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
		"arc": "360",
		"ammo": 999, # Infinite
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Assault Rockets: Range 4, FF, Ammo 4, 2d10+4
	weapons.append({
		"name": "Assault Rockets",
		"type": "Rocket",
		"range": 4,
		"arc": "FF",
		"ammo": 4,
		"max_ammo": 4,
		"damage_dice": "2d10",
		"damage_bonus": 4,
		"fired": false
	})
	current_weapon_index = 0 # Default to Laser

func configure_frigate():
	ship_class = "Frigate"
	defense = "RH"
	hull = 40
	adf = 3
	mr = 3
	
	weapons.clear()
	# Laser Battery: Range 10 (User said Laser Canon is 10, Battery usually 9? Keeping Battery as 9 for consistency or standard?)
	# User: "laser battery, 4 assault rockets, and 2 new weapons - a laser canon and 2 torpedoes"
	# Standard Laser Battery (from Scout):
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 10, # User might have meant Canon is 10? Standard Battery is 10? Code has 9 usually.
		# Let's assume Standard Battery (Range 10 is common in Star Frontiers).
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Laser Canon: Range 10, FF, 2d10. 
	weapons.append({
		"name": "Laser Canon",
		"type": "Laser Canon",
		"range": 10,
		"arc": "FF",
		"ammo": 999, # Canons usually infinite? Or limited? Assuming infinite unless specified.
		"max_ammo": 999,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Assault Rockets: Range 4, FF, Ammo 4, 2d10+4
	weapons.append({
		"name": "Assault Rockets",
		"type": "Rocket",
		"range": 4,
		"arc": "FF",
		"ammo": 4,
		"max_ammo": 4,
		"damage_dice": "2d10",
		"damage_bonus": 4,
		"fired": false
	})
	
	# Torpedoes: Range 4, FF (Propelled), Ammo 2, 4d10
	weapons.append({
		"name": "Torpedo",
		"type": "Torpedo",
		"range": 4,
		"arc": "360",
		"ammo": 2,
		"max_ammo": 2,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	current_weapon_index = 0

func reset_weapons():
	has_fired = false
	for w in weapons:
		w["fired"] = false
	queue_redraw()

func _ready():
	hull = MAX_HULL
	queue_redraw()

func _set_facing(v: int):
	facing = v
	queue_redraw()

func _set_grid_position(v: Vector3i):
	grid_position = v
	# Position update is now handled by GameManager's stack update or explicit call
	# But we set a default here just in case, though it might be overridden immediately
	position = HexGrid.hex_to_pixel(v)
	ship_moved.emit(v)

func take_damage(amount: int):
	hull -= amount
	hull_changed.emit(hull)
	queue_redraw() # Update health bar

	if hull <= 0:
		hull = 0
		ship_destroyed.emit()
		trigger_explosion()

var is_ghost: bool = false
var is_exploding: bool = false
var show_info: bool = true

func set_ghost(val: bool):
	is_ghost = val
	if is_ghost:
		modulate.a = 0.5
		z_index = 10 # Draw on top
	else:
		modulate.a = 1.0
		z_index = 0
	queue_redraw()

func binding_pos_update():
	position = HexGrid.hex_to_pixel(grid_position)

func _draw():
	if is_exploding: return

	# Draw simple representation based on class
	var size = HexGrid.TILE_SIZE * 0.6
	var points = PackedVector2Array()
	
	match ship_class:
		"Assault Scout":
			# Heavier, multi-faceted shape (Bullet/Hex-like)
			# Nose, Right Shoulder, Right Rear, Rear Center, Left Rear, Left Shoulder
			points = PackedVector2Array([
				Vector2(size, 0),
				Vector2(size * 0.2, -size * 0.5),
				Vector2(-size * 0.5, -size * 0.5),
				Vector2(-size * 0.3, 0), # Engine notch
				Vector2(-size * 0.5, size * 0.5),
				Vector2(size * 0.2, size * 0.5)
			])
		"Fighter", _:
			# Sleek Delta / Dart
			# Nose, Right Wing, Rear Notch, Left Wing
			points = PackedVector2Array([
				Vector2(size, 0),
				Vector2(-size * 0.5, -size * 0.5),
				Vector2(-size * 0.2, 0), # Rear Notch
				Vector2(-size * 0.5, size * 0.5)
			])
		"Frigate":
			# Large Heavy Shape (Pentagon/Hammerhead)
			size = HexGrid.TILE_SIZE * 0.8
			points = PackedVector2Array([
				Vector2(size, 0), # Nose
				Vector2(size * 0.5, -size * 0.5), # R Fwd
				Vector2(-size * 0.5, -size * 0.6), # R Rear
				Vector2(-size * 0.8, 0), # Engine
				Vector2(-size * 0.5, size * 0.6), # L Rear
				Vector2(size * 0.5, size * 0.5) # L Fwd
			])
	# Rotate points based on facing (each facing is 60 degrees = PI/3)
	var angle = facing * (PI / 3.0)
	var rotated_points = PackedVector2Array()
	for p in points:
		rotated_points.append(p.rotated(angle))
		
	draw_colored_polygon(rotated_points, color)
	# Draw outline
	var outline = rotated_points.duplicate()
	outline.append(rotated_points[0]) # Close the loop
	draw_polyline(outline, Color.BLACK, 2.0)
	
	# Draw Info (Name and Health) - Only for real ships AND if show_info is true
	if not is_ghost and show_info:
		# Draw Name
		var default_font = ThemeDB.fallback_font
		var font_size = 14
		var name_pos = Vector2(-size, -size - 10)
		draw_string(default_font, name_pos, name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
		
		# Draw Health Bar
		var bar_width = HexGrid.TILE_SIZE * 0.8
		var bar_height = 6.0
		var bar_pos = Vector2(-bar_width / 2, size/2 + 10)
		
		# Background/Border (Black)
		var bg_rect = Rect2(bar_pos, Vector2(bar_width, bar_height))
		draw_rect(bg_rect, Color.BLACK, false, 2.0) # Border
		
		# Health Fill
		var pct = float(hull) / float(MAX_HULL)
		var fill_width = bar_width * pct
		var fill_rect = Rect2(bar_pos, Vector2(fill_width, bar_height))
		var health_color = Color.DARK_RED.lerp(Color.GREEN, pct)
		draw_rect(fill_rect, health_color, true)

func trigger_explosion():
	is_exploding = true
	queue_redraw()
	
	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 50
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color.ORANGE
	
	# Color gradient for fire effect
	var gradient = Gradient.new()
	gradient.set_color(0, Color.YELLOW)
	gradient.set_color(1, Color(1, 0, 0, 0)) # Fade to red transparent
	particles.color_ramp = gradient
	
	add_child(particles)
	particles.emitting = true
	
	# Wait for particles to finish before freeing
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(queue_free)

func reset_turn_state():
	has_moved = false
	has_fired = false
	reset_weapons()
