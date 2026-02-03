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

signal ship_moved(new_pos)
signal ship_destroyed
signal hull_changed(new_value)

func _ready():
	hull = MAX_HULL
	queue_redraw()

func _set_facing(v: int):
	facing = v
	queue_redraw()

func _set_grid_position(v: Vector3i):
	grid_position = v
	# Snap visual position to grid
	position = HexGrid.hex_to_pixel(v)
	ship_moved.emit(v)

func take_damage(amount: int):
	hull -= amount
	hull_changed.emit(hull)
	queue_redraw() # Update health bar

	if hull <= 0:
		hull = 0
		ship_destroyed.emit()
		queue_free()

var is_ghost: bool = false

func set_ghost(val: bool):
	is_ghost = val
	if is_ghost:
		modulate.a = 0.5
		z_index = 10 # Draw on top
	else:
		modulate.a = 1.0
		z_index = 0
	queue_redraw()

func _draw():
	# Draw simple triangle for ship representation
	var size = HexGrid.TILE_SIZE * 0.6
	# Triangle pointing right (0 degrees)
	var points = PackedVector2Array([
		Vector2(size, 0),
		Vector2(-size/2, -size/2),
		Vector2(-size/2, size/2)
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
	
	# Draw Health Bar (Only for real ships)
	if not is_ghost:
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
