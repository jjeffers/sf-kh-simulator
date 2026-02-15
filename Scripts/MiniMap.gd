class_name MiniMap
extends PanelContainer


var game_manager # : GameManager - Weak ref to avoid cyclic dependency


# Configuration
const MAP_SIZE = Vector2(200, 200)
const PADDING = 10.0
var scale_factor: float = 1.0

var center_offset: Vector2

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

func _process(_delta):
	queue_redraw()

func _gui_input(event):
	if not game_manager or not game_manager.camera: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Convert click to world pos
		# map_pos = (world_pos * scale_factor) + center_offset
		# world_pos = (map_pos - center_offset) / scale_factor
		if scale_factor > 0:
			var click_pos = event.position
			var world_pos = (click_pos - center_offset) / scale_factor
			game_manager.camera.position = world_pos

func recalculate_layout():
	if not game_manager: return
	
	center_offset = size / 2.0
	
	var world_radius = game_manager.map_radius * HexGrid.TILE_SIZE * 2.0
	if world_radius > 0:
		scale_factor = (min(size.x, size.y) / 2.0 - PADDING) / world_radius

func _draw():
	if not game_manager: return
	
	recalculate_layout()
	
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
		if s.side_id == 1: color = Color.GREEN
		elif s.side_id == 2: color = Color.RED
		
		var radius = 3.0
		if s.ship_class == "Space Station":
			radius = 5.0
			color = Color.WHITE
		
		draw_circle(map_pos, radius, color)
		
		# Draw Current Target Highlight
		if game_manager.combat_target == s:
			draw_arc(map_pos, radius + 2, 0, TAU, 16, Color.RED, 1.0)
			
	# 3. Draw Camera View Rect
	# Use active camera position and zoom
	var cam = game_manager.camera
	if not cam: return
	
	var viewport_size = get_viewport_rect().size
	# World View Size = Screen Size / Zoom
	var view_world_size = viewport_size / cam.zoom
	
	# Camera position is center of view
	var view_tl_world = cam.position - (view_world_size / 2.0)
	
	var map_view_tl = (view_tl_world * scale_factor) + center_offset
	var map_view_size = view_world_size * scale_factor
	
	draw_rect(Rect2(map_view_tl, map_view_size), Color(1, 1, 1, 0.3), false, 1.0)
