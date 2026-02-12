class_name Ship
extends Node2D


@export var side_id: int = 1
@export var adf: int = 5
@export var mr: int = 3
@export var color: Color = Color.WHITE

var texture_fighter = preload("res://Assets/upf_fighter.png")
var texture_assault_scout = preload("res://Assets/upf_assault_scout.png")
var texture_frigate = preload("res://Assets/upf_frigate.png")
var texture_space_station = preload("res://Assets/upf_space_station.png")
var texture_sathar_destroyer = preload("res://Assets/sathar_destroyer.png")
var texture_sathar_heavy_cruiser = preload("res://Assets/sathar_heavy_cruiser.png")
var texture_sathar_frigate = preload("res://Assets/sathar_frigate.png")
var texture_sathar_fighter = preload("res://Assets/sathar_fighter.png")
var texture_sathar_assault_carrier = preload("res://Assets/sathar_assault_carrier.png")

var texture_upf_destroyer = preload("res://Assets/upf_destroyer.png")
var texture_upf_heavy_cruiser = preload("res://Assets/upf_heavy_cruiser.png")
var texture_upf_battleship = preload("res://Assets/upf_battleship.png")
var texture_upf_assault_carrier = preload("res://Assets/upf_assault_carrier.png")


var faction: String = "UPF"
var agility: int = 1

# Multiplayer Ownership
var owner_peer_id: int = 0 # 0 = Server/AI, >0 = Player Peer ID

var max_hull: int = 15
var hull: int = 15
var icm_max: int = 0
var icm_current: int = 0
var ms_max: int = 0
var ms_current: int = 0
var is_ms_active: bool = false: set = _set_ms_active
var ms_orbit_start_hex: Vector3i = Vector3i.MAX # Sentinel for orbit MS logic

var is_selected: bool = false: set = _set_is_selected

var ms_particles: CPUParticles2D = null

# Docking State
var is_docked: bool = false
var docked_host: Ship = null
var docked_guests: Array[Ship] = []

# Scenario Specific
var evacuation_turns: int = 0
var previous_path: Array[Vector3i] = []


var grid_position: Vector3i = Vector3i.ZERO: set = _set_grid_position
var facing: int = 0: set = _set_facing # 0 to 5, direction index
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
	icm_max = 0
	icm_current = 0
	ms_max = 0
	ms_current = 0
	
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
	ms_max = 0
	ms_current = 0
	
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
	icm_max = 4
	icm_current = 4
	ms_max = 1
	ms_current = 1
	
	weapons.clear()
	# Laser Battery: Range 9
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
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
	icm_max = 4
	icm_current = 4
	ms_max = 2
	ms_current = 2
	
	weapons.clear()
	# Laser Battery: Range 9, 360 Arc, 1d10
	weapons.append({
		"name": "Laser Battery",
		"type": "Laser",
		"range": 9,
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
	icm_max = 8
	icm_current = 8
	ms_max = 1
	ms_current = 1
	
	weapons.clear()
	# Laser Batteries (x3 - Separate entries)
	for i in range(3):
		weapons.append({
			"name": "Laser Battery %d" % (i + 1),
			"type": "Laser",
			"range": 9,
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
	
func configure_battleship():
	ship_class = "Battleship"
	defense = "RH"
	max_hull = 120
	hull = max_hull
	adf = 2
	mr = 2
	icm_max = 20
	icm_current = 20
	ms_max = 4
	ms_current = 4
	
	weapons.clear()
	# Laser Canons (x2)
	for i in range(2):
		weapons.append({
			"name": "Laser Canon %d" % (i + 1),
			"type": "Laser Canon",
			"range": 10,
			"arc": "FF",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "2d10",
			"damage_bonus": 0,
			"fired": false
		})
		
	# Laser Batteries (x4)
	for i in range(4):
		weapons.append({
			"name": "Laser Battery %d" % (i + 1),
			"type": "Laser",
			"range": 9,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"fired": false
		})
		
	# Rocket Batteries (x10)
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": 10,
		"max_ammo": 10,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	# Torpedoes (x8)
	weapons.append({
		"name": "Torpedoes",
		"type": "Torpedo",
		"range": 4, # Standard Range?
		"arc": "360",
		"ammo": 8,
		"max_ammo": 8,
		"damage_dice": "4d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	current_weapon_index = 0
	
func configure_assault_carrier():
	ship_class = "Assault Carrier"
	defense = "RH"
	max_hull = 75
	hull = max_hull
	adf = 2
	mr = 1
	icm_max = 8
	icm_current = 8
	ms_max = 1
	ms_current = 1
	
	weapons.clear()
	# Laser Batteries (x2)
	for i in range(2):
		weapons.append({
			"name": "Laser Battery %d" % (i + 1),
			"type": "Laser",
			"range": 9,
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"fired": false
		})
		
	# Rocket Batteries (x6)
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
	
	current_weapon_index = 0

func configure_space_station(force_hull: int = -1):
	ship_class = "Space Station"
	defense = "RH"
	
	if force_hull > 0:
		hull = force_hull
	else:
		# Random Hull 20-200, Normal Distribution around 100
		# randfn(mean, deviation). 
		# Range 20-200 is roughly +/- 2.5 sigma if sigma is 30?
		var h = randfn(100.0, 40.0)
		hull = int(clamp(h, 20, 200))
		
	max_hull = hull
	adf = 0
	mr = 0
	
	# ICM Scaling: floor(H / 25), clmap 2-8
	icm_max = int(clamp(floor(hull / 25.0), 2, 8))
	icm_current = icm_max
	
	# MS Scaling: 1-4. floor(H/50)?
	# Prompt: "1 to 4".
	# 20 -> 1. 200 -> 4.
	# H/60? 20/60 = 0 -> 1. 200/60 = 3 -> 4.
	ms_max = int(clamp(floor(hull / 50.0) + 1, 1, 4))
	ms_current = ms_max
	
	weapons.clear()
	
	# Laser Batteries: floor(H / 60) + 1, clamp 1-3
	var lb_count = int(clamp(floor(hull / 60.0) + 1, 1, 3))
	for i in range(lb_count):
		weapons.append({
			"name": "Laser Battery %d" % (i + 1),
			"type": "Laser",
			"range": 9, # Station batteries might have better range? keeping standard 10 -> Now 9
			"arc": "360",
			"ammo": 999,
			"max_ammo": 999,
			"damage_dice": "1d10",
			"damage_bonus": 0,
			"fired": false
		})
		
	# Rocket Batteries: floor(H / 15), clamp 2-12
	var rb_count = int(clamp(floor(hull / 15.0), 2, 12))
	# Consolidate into one entry? Or separate? 
	# "2 to 12 rocket batteries". If consolidated, max_ammo = count.
	# "1 shot per phase" rule usually applies "per weapon TYPE" or "per mount"?
	# If we have 12 mounts, can we fire 12 times? 
	# User rules: "a ship may only fire 1 rocket battery per combat phase".
	# If a station has 12, surely it can fire more than 1? 
	# A Space Station is likely an exception or "multi-mount" means multiple attacks.
	# However, to avoid complexity, let's group them or allow them as separate entries?
	# If `_is_weapon_available_in_phase` checks TYPE, it blocks ALL.
	# We might need to flag them as separate weapons to allow multi-fire if they are separate mounts.
	# But `Rocket Battery` restriction was specific.
	# Let's assume for a STATION (Orbiting Fortress), it can fire ALL of them.
	# Logic update needed in GameManager if "Type" check blocks it.
	# For now, let's add them as a single entry with AMMO = Count, 
	# assuming the specific rule "1 per phase" applies to standard ships.
	# If the user wants 12 shots per turn, we need 12 entries or code changes.
	# Given "2 to 12", 12 line items is messy.
	# Let's add ONE entry "Rocket Battery Array" with Ammo = Count.
	# But `GameManager` enforces 1 firing per phase.
	# Prompt says "They have from... 2 to 12 rocket batteries".
	# Effect: Station should be scary. Limiting to 1 shot is weak.
	# Let's treat them as separate entries if feasible, OR special rule for Stations.
	# Let's stick to the user's explicit rule for now: "1 RB per phase".
	# If the station is huge, maybe it has multiple FACINGS?
	# Simpler: One entry "Rocket Battery Swarm" with Ammo = RB Count.
	# But wait, user said "varying from 2 to 12".
	# Let's just create ONE entry with `rb_count` Ammo.
	weapons.append({
		"name": "Rocket Batteries",
		"type": "Rocket Battery",
		"range": 3,
		"arc": "360",
		"ammo": rb_count,
		"max_ammo": rb_count,
		"damage_dice": "2d10",
		"damage_bonus": 0,
		"fired": false
	})
	
	current_weapon_index = 0

func reset_weapons():
	has_fired = false
	for w in weapons:
		w["fired"] = false
		
	# MS maintenance handled in GM (if constraints broken), but here we can just ensure persistence?
	# "A masking screen remains in place once activated as long as the ship remains moving in a straight line at its current speed."
	# So we don't reset it here manually unless we want to clear it on turn start?
	# Actually, if it remains "once activated", we shouldn't clear it.
	
	queue_redraw()

func _ready():
	_setup_particles()
	queue_redraw()

func _setup_particles():
	ms_particles = CPUParticles2D.new()
	ms_particles.name = "MSParticles"
	ms_particles.emitting = false
	ms_particles.amount = 32
	ms_particles.lifetime = 1.5
	# Emission Shape: Sphere
	ms_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	ms_particles.emission_sphere_radius = HexGrid.TILE_SIZE * 0.7
	
	# Physics
	ms_particles.gravity = Vector2.ZERO
	ms_particles.direction = Vector2(0, -1)
	ms_particles.spread = 180.0
	ms_particles.initial_velocity_min = 5.0
	ms_particles.initial_velocity_max = 15.0
	ms_particles.damping_min = 5.0
	ms_particles.damping_max = 10.0
	
	# Visuals
	ms_particles.scale_amount_min = 2.0
	ms_particles.scale_amount_max = 4.0
	ms_particles.color = Color(0.4, 0.7, 1.0, 0.6) # Light Blue Vapor
	ms_particles.local_coords = true # Ensure they stick to the ship during "camera" (GameManager) movement
	
	add_child(ms_particles)
	# Ensure it draws behind the ship? 
	# Z-index is relative. Ship is parent. 
	# To draw behind, we can specific z_index or just order?
	# CanvasItems draw children on top.
	# We want particles BEHIND? Then use show_behind_parent = true
	ms_particles.show_behind_parent = true

func _set_ms_active(val: bool):
	is_ms_active = val
	if ms_particles:
		ms_particles.emitting = val
	queue_redraw()

func _set_is_selected(val: bool):
	is_selected = val
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
		is_destroyed = true
		ship_destroyed.emit()
		trigger_explosion()

var is_ghost: bool = false
var is_exploding: bool = false
var is_destroyed: bool = false
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

	# If Masking Screen active, we rely on particles now.
	# But maybe a faint outline is still good?
	if is_ms_active:
		# Draw a very faint outline to define the "screen" boundary
		draw_arc(Vector2.ZERO, HexGrid.TILE_SIZE * 0.8, 0, TAU, 32, Color(0.4, 0.7, 1.0, 0.3), 1.0)

	if is_selected:
		# Draw bright selection ring
		# Pulse width or brightness? Simple bright outline for now.
		draw_arc(Vector2.ZERO, HexGrid.TILE_SIZE * 0.9, 0, TAU, 32, Color(1.0, 1.0, 0.0, 0.8), 3.0)

	var color_to_use = color
	if is_exploding:
		color_to_use = Color.ORANGE
	elif is_destroyed:
		color_to_use = Color.WEB_GRAY

	# Draw simple representation based on class
	var size = HexGrid.TILE_SIZE * 0.6
	var points = PackedVector2Array()
	
	match ship_class:
		"Assault Scout":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.7 # 0.7x Tile Size (28px)
			
			var ref_size = max(texture_assault_scout.get_width(), texture_assault_scout.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = texture_assault_scout.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(texture_assault_scout, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
			points = PackedVector2Array()
		"Frigate":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.9
			
			var tex = texture_frigate # UPF Default
			if faction == "Sathar":
				tex = texture_sathar_frigate
				target_size = HexGrid.TILE_SIZE * 0.9 # Adjust if needed
			
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = tex.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(tex, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
		"Destroyer":
			if faction == "Sathar":
				# Sathar Destroyer Sprite
				var target_size = HexGrid.TILE_SIZE * 1.1 # 1.1x Tile Size (44px)
				var ref_size = max(texture_sathar_destroyer.get_width(), texture_sathar_destroyer.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_sathar_destroyer.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_sathar_destroyer, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
			else:
				# UPF Destroyer Sprite
				var target_size = HexGrid.TILE_SIZE * 1.1
				var ref_size = max(texture_upf_destroyer.get_width(), texture_upf_destroyer.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_upf_destroyer.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_upf_destroyer, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
		"Heavy Cruiser":
			if faction == "Sathar":
				# Sathar Heavy Cruiser Sprite
				var target_size = HexGrid.TILE_SIZE * 1.4 # 1.4x Tile Size (56px)
				var ref_size = max(texture_sathar_heavy_cruiser.get_width(), texture_sathar_heavy_cruiser.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_sathar_heavy_cruiser.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_sathar_heavy_cruiser, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
			else:
				# UPF Heavy Cruiser Sprite
				var target_size = HexGrid.TILE_SIZE * 1.4
				var ref_size = max(texture_upf_heavy_cruiser.get_width(), texture_upf_heavy_cruiser.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_upf_heavy_cruiser.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_upf_heavy_cruiser, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
		"Battleship":
			if faction == "Sathar":
				# No Sathar BB asset? Use fallback vector for now.
				size = HexGrid.TILE_SIZE * 0.85
				points = PackedVector2Array([
					Vector2(size, 0),
					Vector2(-size * 0.8, -size * 0.4),
					Vector2(-size * 0.5, 0),
					Vector2(-size * 0.8, size * 0.4)
				])
			else:
				# UPF Battleship Sprite
				var target_size = HexGrid.TILE_SIZE * 1.7 # Massive
				var ref_size = max(texture_upf_battleship.get_width(), texture_upf_battleship.get_height())
				var scale_factor = target_size / ref_size
				
				var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
				draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
				
				var tex_size = texture_upf_battleship.get_size()
				var rect = Rect2(-tex_size / 2, tex_size)
				
				draw_texture_rect(texture_upf_battleship, rect, false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
				points = PackedVector2Array()
		"Space Station":
			# Sprite Rendering
			# Scale based on Hull Points: 1.0 + (max_hull / 200.0) -> Max ~2.0x
			# Examples: 100 HP -> 1.5x, 200 HP -> 2.0x relative to Tile Size
			var hp_scale_bonus = float(max_hull) / 200.0
			var target_size = HexGrid.TILE_SIZE * (1.0 + hp_scale_bonus)
			
			var ref_size = max(texture_space_station.get_width(), texture_space_station.get_height())
			var scale_factor = target_size / ref_size
			
			# Rotation: Stations might rotate or be fixed. 
			# Let's align with facing for now (it has a facing index).
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = texture_space_station.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(texture_space_station, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
		"Assault Carrier":
			var target_size = HexGrid.TILE_SIZE * 2.0 # Huge
			
			var tex = texture_upf_assault_carrier # Default
			if faction == "Sathar":
				tex = texture_sathar_assault_carrier
				
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			var tex_size = tex.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			draw_texture_rect(tex, rect, false, Color.WHITE)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			points = PackedVector2Array()
		"Fighter":
			# Sprite Rendering
			var target_size = HexGrid.TILE_SIZE * 0.5 # 0.5x Tile Size (20px)
			
			var tex = texture_fighter # Default UPF
			if faction == "Sathar":
				tex = texture_sathar_fighter
			
			var ref_size = max(tex.get_width(), tex.get_height())
			var scale_factor = target_size / ref_size
			
			# Rotation: Facing 0 = East?
			# If Sprite points UP (-Y), we need +90 deg to face East (0).
			# hex angle = facing * 60 deg.
			var draw_angle = facing * (PI / 3.0) + (PI / 2.0)
			
			draw_set_transform(Vector2.ZERO, draw_angle, Vector2(scale_factor, scale_factor))
			
			# Draw centered
			var tex_size = texture_fighter.get_size()
			var rect = Rect2(-tex_size / 2, tex_size)
			
			# Draw with color modulation? 
			# User didn't specify, but usually team color is good.
			# Or keep original? white modulation = original colors.
			# Let's use slight tint of team color + white? 
			# Or just color?
			# If sprite is colored, modulate mixes.
			# Let's assume white sprite or user wants team color.
			# Let's assume white sprite or user wants team color.
			draw_texture_rect(tex, rect, false, Color.WHITE)
			
			# Reset transform
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 1))
			
			# Skip polygon
			points = PackedVector2Array()
		_:
			# Default / Fallback (Sleek Delta / Dart)
			points = PackedVector2Array([
				Vector2(size, 0),
				Vector2(-size * 0.5, -size * 0.5),
				Vector2(-size * 0.2, 0),
				Vector2(-size * 0.5, size * 0.5)
			])
	# Rotate points based on facing (each facing is 60 degrees = PI/3)
	if not points.is_empty():
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
		draw_string(default_font, name_pos, get_display_name(), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
		
		# Draw Health Bar
		var bar_width = HexGrid.TILE_SIZE * 0.8
		var bar_height = 6.0
		var bar_pos = Vector2(-bar_width / 2, size / 2 + 10)
		
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
	is_ms_active = false # Kill systems
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

func get_docking_capacity() -> int:
	if ship_class == "Space Station": return 999
	if ship_class == "Assault Carrier": return 10
	return 0

func replenish_ammo():
	for w in weapons:
		w["ammo"] = w["max_ammo"]
	# Also refill ICM/MS? Prompt says "replenishment of ammuniation". 
	# Usually implies weapons. Let's stick to weapons for now.


func get_display_name() -> String:
	var abbrev = ""
	match ship_class:
		"Fighter": abbrev = "F"
		"Frigate": abbrev = "FG"
		"Destroyer": abbrev = "DD"
		"Heavy Cruiser": abbrev = "C"
		"Battleship": abbrev = "BB"
		"Space Station": abbrev = "SS"
		"Assault Scout": abbrev = "AS"
		"Assault Carrier": abbrev = "AC"
		_: abbrev = "?"
	
	return "%s %s" % [abbrev, name]

func dock_at(station: Ship) -> bool:
	if is_instance_valid(station) and station != self:
		# Capacity Check
		if station.docked_guests.size() >= station.get_docking_capacity():
			return false
			
		is_docked = true
		docked_host = station
		if not station.docked_guests.has(self):
			station.docked_guests.append(self)
		
		# Re-arm Logic
		if ship_class == "Fighter" and station.ship_class in ["Assault Carrier", "Space Station"]:
			replenish_ammo()
		
		# Align position purely for visuals/logic consistency
		grid_position = station.grid_position
		# Visual tweak: maybe slight offset or smaller scale? 
		# For now, just sharing the hex is enough. z_index handles visibility.
		# Ships are drawn in tree order. Active player ships usually last.
		return true
	return false
		
func undock():
	if is_instance_valid(docked_host):
		docked_host.docked_guests.erase(self)
	
	is_docked = false
	docked_host = null
