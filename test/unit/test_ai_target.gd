extends SceneTree

func _init():
	var HexGrid = load("res://Scripts/HexGrid.gd").new()
	var pos1 = Vector3i(0, 0, 0)
	var facing1 = 0
	var pos2 = Vector3i(0, -1, 1) # 1 hex perfectly forward (direction 0)
	
	print("Distance: ", HexGrid.hex_distance(pos1, pos2))
	var dir_to_target = HexGrid.get_hex_direction(pos1, pos2)
	print("Direction: ", dir_to_target, " (Facing: ", facing1, ")")
	
	if dir_to_target == facing1:
		print("In FF Arc (Direct) - SUCCESS")
	else:
		print("In FF Arc (Complex) - checking...")
		var valid_hexes = get_ff_arc_hexes(HexGrid, pos1, facing1, 4)
		if pos2 in valid_hexes:
			print("SUCCESS in complex arc")
		else:
			print("FAILED arc")
			
	quit()

func get_ff_arc_hexes(hexgrid_ref, pos, facing, rng):
	var hexes = []
	var current_center = pos
	var fwd_vec = hexgrid_ref.get_direction_vec(facing)
	var left_vec = hexgrid_ref.get_direction_vec((facing - 1 + 6) % 6)
	var right_vec = hexgrid_ref.get_direction_vec((facing + 1) % 6)
	
	for dist in range(1, rng + 1):
		current_center += fwd_vec
		hexes.append(current_center)
		# Expanding width
		var width = dist
		var left_hex = current_center
		var right_hex = current_center
		for w in range(width):
			left_hex += left_vec
			right_hex += right_vec
			hexes.append(left_hex)
			hexes.append(right_hex)
	return hexes
	

	
	quit()
