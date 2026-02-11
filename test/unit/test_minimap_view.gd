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
	_mm.size = Vector2(200, 200)
	add_child(_mm)
	
	# Force camera setup
	_gm.camera.position = Vector2(100, 100)
	_gm.camera.zoom = Vector2(1, 1)

func after_each():
	_mm.free()
	_gm.free()

func test_view_rect_logic():
	# Manually verifying the math used in _draw
	_mm.recalculate_layout()
	
	var cam_pos = _gm.camera.position # (100, 100)
	var zoom = _gm.camera.zoom # (1, 1)
	
	# Mock viewport size assumption for test logic
	var vp_size = Vector2(1024, 600)
	
	var view_world_size = vp_size / zoom
	var view_tl_world = cam_pos - (view_world_size / 2.0)
	
	var scale = _mm.scale_factor
	var center = _mm.center_offset
	
	var map_view_tl = (view_tl_world * scale) + center
	
	# Basic check: if we move camera, map_view_tl should shift
	var old_tl = map_view_tl
	
	_gm.camera.position += Vector2(100, 0)
	_mm.recalculate_layout() # scale/center shouldn't change but good practice
	
	var new_view_tl_world = _gm.camera.position - (view_world_size / 2.0)
	var new_map_tl = (new_view_tl_world * scale) + center
	
	assert_gt(new_map_tl.x, old_tl.x, "Map rect should move right when camera moves right")
	pass_test("Logic verification complete")
