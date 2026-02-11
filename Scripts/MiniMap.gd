class_name MiniMap
extends PanelContainer

var game_manager: GameManager

# Configuration
const MAP_SIZE = Vector2(200, 200)
const PADDING = 10.0
var scale_factor: float = 1.0

func _ready():
	custom_minimum_size = MAP_SIZE
	
	# Style for background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	add_theme_stylebox_override("panel", style)

func _process(delta):
	queue_redraw()

func _draw():
	if not game_manager: return
	
	var center_offset = size / 2.0
	
	# Determine Scale
	# Map Radius is hex distance. 
	# Max pixel distance approx = map_radius * TILE_SIZE * 2 (roughly)
	# We want to fit (-map_radius to +map_radius) into (size.x - padding)
	
	var world_radius = game_manager.map_radius * HexGrid.TILE_SIZE * 2.0 # Approximation
	if world_radius > 0:
		scale_factor = (min(size.x, size.y) / 2.0 - PADDING) / world_radius
	
	# 1. Draw Planets
	for hex in game_manager.planet_hexes:
		var world_pos = HexGrid.hex_to_pixel(hex)
		var map_pos = (world_pos * scale_factor) + center_offset
		draw_circle(map_pos, 4.0, Color.SADDLE_BROWN)
		
	# 2. Draw Ships
	for s in game_manager.ships:
		if not is_instance_valid(s) or s.is_exploding: continue
		
		var world_pos = s.position # Use visual position
		var map_pos = (world_pos * scale_factor) + center_offset
		
		var color = Color.GRAY
		if s.player_id == 1: color = Color.GREEN
		elif s.player_id == 2: color = Color.RED
		
		var radius = 3.0
		if s.ship_class == "Space Station":
			radius = 5.0
			color = Color.WHITE
		
		draw_circle(map_pos, radius, color)
		
		# Draw Current Target Highlight
		if game_manager.combat_target == s:
			draw_arc(map_pos, radius + 2, 0, TAU, 16, Color.RED, 1.0)
			
	# 3. Draw Camera View Rect
	# GameManager position is inverted camera.
	# World View Center = -game_manager.position
	# View Size = get_viewport_rect().size
	var viewport_size = get_viewport_rect().size
	# Top-Left of view in world space
	# Node2D position is the offset of (0,0) from Top-Left.
	# So World(0,0) is at Screen(position).
	# Screen(0,0) is at World(-position).
	var view_tl_world = - game_manager.position
	var view_rect_size_world = viewport_size
	
	var map_view_tl = (view_tl_world * scale_factor) + center_offset
	var map_view_size = view_rect_size_world * scale_factor
	
	draw_rect(Rect2(map_view_tl, map_view_size), Color(1, 1, 1, 0.3), false, 1.0)
