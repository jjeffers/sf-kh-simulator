extends GutTest

var HexGrid = preload("res://Scripts/HexGrid.gd")

func test_cube_round_trip():
	var hex = Vector3i(1, -3, 2)
	var pixel = HexGrid.hex_to_pixel(hex)
	var result = HexGrid.pixel_to_hex(pixel)
	assert_eq(result, hex, "Pixel to Hex should round trip correctly")

func test_hex_distance():
	var a = Vector3i(0, 0, 0)
	var b = Vector3i(2, -2, 0)
	var dist = HexGrid.hex_distance(a, b)
	assert_eq(dist, 2, "Distance should generally be max(|dq|, |dr|, |ds|)")

func test_get_neighbors():
	var center = Vector3i(0, 0, 0)
	var neighbors = HexGrid.get_neighbors(center)
	assert_eq(neighbors.size(), 6, "Hex should have 6 neighbors")
	
	# Check specific neighbor (1, -1, 0) -> East?
	# Using verify logic: check if neighbor is distance 1
	for n in neighbors:
		assert_eq(HexGrid.hex_distance(center, n), 1, "Neighbor must be distance 1")

func test_get_line_coords():
	var start = Vector3i(0, 0, 0)
	var end = Vector3i(3, -3, 0)
	var line = HexGrid.get_line_coords(start, end)
	
	assert_eq(line.size(), 4, "Line of length 3 should contain 4 hexes (inclusive)")
	assert_eq(line[0], start, "Line start")
	assert_eq(line[3], end, "Line end")
