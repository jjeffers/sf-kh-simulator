class_name Ship
extends Node2D


@export var player_id: int = 1
@export var adf: int = 5
@export var mr: int = 3
@export var color: Color = Color.WHITE

var max_hull: int = 15
var hull: int = 15
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
	max_hull = 8
	hull = max_hull
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
	max_hull = 15
	hull = max_hull
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
	max_hull = 40
	hull = max_hull
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
	
	# Rocket Batteries: 4 Batteries total
	# Consolidated into one entry for UI clarity and "1 per turn" enforcement.
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery", 
		"range": 3,
		"arc": "360",
		"ammo": 4, 
		"max_ammo": 4,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Torpedoes: 2 Torpedoes
	weapons.append({
		"name": "Torpedoes",
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
	
func configure_destroyer():
	ship_class = "Destroyer"
	defense = "RH"
	max_hull = 50
	hull = max_hull
	adf = 3
	mr = 2
	
	weapons.clear()
	# Laser Battery: Range 10, 360 Arc, 1d10
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 10,
		"arc": "360",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "1d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Laser Canon: Range 10, FF, 2d10
	weapons.append({
		"name": "Laser Canon",
		"type": "Laser Canon",
		"range": 10,
		"arc": "FF",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Rocket Batteries (x6)
	# Consolidated: Ammo 6
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 6, 
		"max_ammo": 6, 
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Torpedoes (x2)
	# Consolidated: Ammo 2
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4,
		"arc": "360",
		"ammo": 2, # Standard?
		"max_ammo": 2,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"fired": false
	})
		
	current_weapon_index = 0
	
func configure_heavy_cruiser():
	ship_class = "Heavy Cruiser"
	defense = "RH"
	max_hull = 80
	hull = max_hull
	adf = 1
	mr = 1
	
	weapons.clear()
	# Laser Batteries (x3 - Separate entries)
	for i in range(3):
		weapons.append({
			"name": "Laser Battery %d" % (i+1),
			"type": "Laser",
			"range": 10,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"fired": false
		})
		
	# Laser Canon
	weapons.append({
		"name": "Laser Canon",
		"type": "Laser Canon",
		"range": 10,
		"arc": "FF",
		"ammo": 999,
		"max_ammo": 999,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Rocket Batteries (x8 - Consolidated)
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 8,
		"max_ammo": 8,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Torpedoes (x4 - Consolidated)
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4,
		"arc": "360",
		"ammo": 4,
		"max_ammo": 4,
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
	# hull = max_hull # Do NOT reset hull here, as configure() is called before add_child() -> _ready()
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
		"Frigate":
			# Large Heavy Cruiser Shape
			size = HexGrid.TILE_SIZE * 0.9
			points = PackedVector2Array([
				Vector2(size, 0), # Long Nose
				Vector2(size * 0.3, -size * 0.3), # Shoulder R
				Vector2(-size * 0.4, -size * 0.7), # Wing/Engine Pod R
				Vector2(-size * 0.9, -size * 0.4), # Rear R
				Vector2(-size * 0.7, 0), # Engine Exhaust Notch
				Vector2(-size * 0.9, size * 0.4), # Rear L
				Vector2(-size * 0.4, size * 0.7), # Wing/Engine Pod L
				Vector2(size * 0.3, size * 0.3) # Shoulder L
			])
		"Destroyer":
			# Even Larger, elongated Battleship/Destroyer shape
			size = HexGrid.TILE_SIZE * 0.95
			# Long central spine with side pods
			points = PackedVector2Array([
				Vector2(size, 0), # Nose tip
				Vector2(size * 0.6, -size * 0.3), # Front R
				Vector2(size * 0.2, -size * 0.3), # Mid R indent
				Vector2(0, -size * 0.6), # Side pod R front
				Vector2(-size * 0.6, -size * 0.6), # Side pod R rear
				Vector2(-size * 0.4, -size * 0.2), # Rear fuselage R
				Vector2(-size * 0.9, -size * 0.2), # Engine R
				Vector2(-size * 0.8, 0), # Engine Center (exhaust)
				Vector2(-size * 0.9, size * 0.2), # Engine L
				Vector2(-size * 0.4, size * 0.2), # Rear fuselage L
				Vector2(-size * 0.6, size * 0.6), # Side pod L rear
				Vector2(0, size * 0.6), # Side pod L front
				Vector2(size * 0.2, size * 0.3), # Mid L indent
				Vector2(size * 0.6, size * 0.3) # Front L
			
			])
		"Heavy Cruiser":
			# Massive Dreadnought Shape
			size = HexGrid.TILE_SIZE * 1.1 # Slightly overfill tile? 
			# Or just full tile
			
			# Broad Arrow / Star Destroyer-ish but bulkier
			points = PackedVector2Array([
				Vector2(size, 0), # Nose
				Vector2(size * 0.4, -size * 0.4), # R Shoulder
				Vector2(size * 0.2, -size * 0.7), # R Wingtip Fwd
				Vector2(-size * 0.6, -size * 0.8), # R Wingtip Rear
				Vector2(-size * 0.4, -size * 0.3), # R Cutout
				Vector2(-size * 0.8, -size * 0.3), # R Engine Outer
				Vector2(-size * 0.9, 0), # Rear Center
				Vector2(-size * 0.8, size * 0.3), # L Engine Outer
				Vector2(-size * 0.4, size * 0.3), # L Cutout
				Vector2(-size * 0.6, size * 0.8), # L Wingtip Rear
				Vector2(size * 0.2, size * 0.7), # L Wingtip Fwd
				Vector2(size * 0.4, size * 0.4) # L Shoulder
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
		var pct = float(hull) / float(max_hull)
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
