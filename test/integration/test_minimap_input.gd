extends GutTest

var GameManagerScript = preload("res://Scripts/GameManager.gd")
var MiniMapScript = preload("res://Scripts/MiniMap.gd")

var _gm = null
var _mm = null

func before_each():
	_gm = GameManagerScript.new()
	add_child(_gm)
	_gm._ready()
	
	_mm = MiniMapScript.new()
	_mm.game_manager = _gm
	# Set a fixed size for testing
	_mm.size = Vector2(200, 200)
	add_child(_mm)

func after_each():
	_mm.free()
	_gm.free()

func test_minimap_click_updates_camera():
	# Force layout calc
	_mm.recalculate_layout()
	
	# Initial camera pos might not be zero depending on ship setup
	# var initial_pos = _gm.camera.position
	
	# Simulate Click
	# Center is (100, 100). Click at (150, 100) -> Should be +X relative to where we were?
	# Wait, MiniMap is absolute representation of world.
	# Center of MiniMap corresponds to world (0,0) (offset by game_manager.position usually, but we are setting camera.position)
	# calculated world_pos = (click - center) / scale
	# If we click RIGHT of center, world_pos.x will be POSITIVE.
	# So camera.position should become POSITIVE X.
	
	var click_pos = Vector2(150, 100)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = click_pos
	
	_mm._gui_input(event)
	
	# Verify
	assert_gt(_gm.camera.position.x, 0, "Camera position X should be positive")
	assert_eq(_gm.camera.position.y, 0, "Camera position Y should be 0 (center Y clicked)")

func test_minimap_ignores_other_input():
	var initial_pos = _gm.camera.position
	
	# Right click
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = Vector2(150, 150)
	
	_mm._gui_input(event)
	
	assert_eq(_gm.camera.position, initial_pos, "Right click should be ignored")
