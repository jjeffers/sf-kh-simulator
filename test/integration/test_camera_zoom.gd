extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")

var _gm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)

func after_each():
	_gm.free()

func test_camera_exists():
	assert_not_null(_gm.camera, "Camera2D should be created in _ready")
	assert_true(_gm.camera is Camera2D, "Camera should be of type Camera2D")
	assert_eq(_gm.camera.name, "MainCamera", "Camera name should be Set")

func test_zoom_initialization():
	assert_eq(_gm.target_zoom, Vector2.ONE, "Target zoom should start at 1.0")
	# Camera zoom might not be exactly 1.0 immediately if lerp runs, but start is 1.0
	assert_eq(_gm.camera.zoom, Vector2.ONE, "Camera zoom should start at 1.0")

func test_zoom_in_input():
	# Simulate Zoom In (Wheel Up)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	
	_gm._unhandled_input(event)
	
	# Target zoom should increase
	# Default speed 0.1
	var expected = Vector2(1.1, 1.1)
	assert_eq(_gm.target_zoom, expected, "Target zoom should increase by 0.1")
	
func test_zoom_out_input():
	# Simulate Zoom Out (Wheel Down)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	
	_gm._unhandled_input(event)
	
	# Target zoom should decrease
	var expected = Vector2(0.9, 0.9)
	assert_eq(_gm.target_zoom, expected, "Target zoom should decrease by 0.1")

func test_zoom_clamping():
	# Zoom way in
	for i in range(20):
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP
		event.pressed = true
		_gm._unhandled_input(event)
		
	assert_true(_gm.target_zoom.x <= _gm.ZOOM_MAX.x, "Zoom should not exceed MAX")
	
	# Zoom way out
	for i in range(30):
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		_gm._unhandled_input(event)
		
	assert_true(_gm.target_zoom.x >= _gm.ZOOM_MIN.x, "Zoom should not drop below MIN")

func test_camera_process_zoom_smoothing():
	_gm.target_zoom = Vector2(2.0, 2.0)
	
	# Run process frame
	_gm._process(0.1)
	
	# Camera zoom should have moved towards target
	# Lerp 0.1 means it moved 10% of the way
	assert_gt(_gm.camera.zoom.x, 1.0, "Camera zoom should increase towards target")
	assert_lt(_gm.camera.zoom.x, 2.0, "Camera zoom should not snap instantly")
