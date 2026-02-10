class_name HexGrid
extends Node

# Pointy-top orientation
# Size is the distance from center to corner
const TILE_SIZE = 65.0

# Cube coordinates: q + r + s = 0

# Clockwise starting from East (0)
static var directions = [
	Vector3i(1, 0, -1), # 0: East
	Vector3i(0, 1, -1), # 1: South-East
	Vector3i(-1, 1, 0), # 2: South-West
	Vector3i(-1, 0, 1), # 3: West
	Vector3i(0, -1, 1), # 4: North-West
	Vector3i(1, -1, 0) # 5: North-East
]

static func get_direction_vec(facing_index: int) -> Vector3i:
	return directions[posmod(facing_index, 6)]

# Get all 6 neighbors of a hex
static func get_neighbors(hex: Vector3i) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	for d in directions:
		results.append(hex + d)
	return results

static func get_hex_direction(from_hex: Vector3i, to_hex: Vector3i) -> int:
	var diff = to_hex - from_hex
	var dist = hex_distance(from_hex, to_hex)
	if dist == 0: return 0
	
	for i in range(directions.size()):
		if diff == directions[i] * dist:
			return i
	return -1

# Calculate Manhatten distance on hex grid
static func hex_distance(a: Vector3i, b: Vector3i) -> int:
	var vec = a - b
	return (abs(vec.x) + abs(vec.y) + abs(vec.z)) / 2

# Convert hex coordinates to local pixel position (Pointy Top)
static func hex_to_pixel(hex: Vector3i) -> Vector2:
	var x = TILE_SIZE * (sqrt(3) * hex.x + sqrt(3) / 2 * hex.y)
	var y = TILE_SIZE * (1.5 * hex.y)
	return Vector2(x, y)

# Convert pixel position to hex coordinates
static func pixel_to_hex(local_pos: Vector2) -> Vector3i:
	var q = (sqrt(3) / 3 * local_pos.x - 1.0 / 3 * local_pos.y) / TILE_SIZE
	var r = (2.0 / 3 * local_pos.y) / TILE_SIZE
	return cube_round(Vector3(q, r, -q - r))

# Round floating point cube coordinates to nearest integer hex
static func cube_round(frac: Vector3) -> Vector3i:
	var q = roundi(frac.x)
	var r = roundi(frac.y)
	var s = roundi(frac.z)
	
	var q_diff = abs(q - frac.x)
	var r_diff = abs(r - frac.y)
	var s_diff = abs(s - frac.z)
	
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	else:
		s = -q - r
	return Vector3i(q, r, s)

static func hex_lerp(a: Vector3i, b: Vector3i, t: float) -> Vector3:
	return Vector3(
		lerp(float(a.x), float(b.x), t),
		lerp(float(a.y), float(b.y), t),
		lerp(float(a.z), float(b.z), t)
	)

static func get_line_coords(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	var N = hex_distance(start, end)
	var results: Array[Vector3i] = []
	if N == 0:
		results.append(start)
		return results
		
	for i in range(N + 1):
		var t = float(i) / N
		var cube = hex_lerp(start, end, t)
		var hex = cube_round(cube)
		results.append(hex)
		
	return results
