extends Node

var canvas: CanvasLayer
var panel: PanelContainer
var output: RichTextLabel
var max_lines: int = 200
var _logs: Array[String] = []

var _last_log_time: int = 0
var _is_headless_bot: bool = false
var _deadlock_timeout_ms: int = 60000 # 60 seconds

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_last_log_time = Time.get_ticks_msec()
	var args = OS.get_cmdline_args()
	if "--headless" in args and "--bot" in args:
		_is_headless_bot = true
		print("[ConsoleManager] Headless Bot Mode detected. Deadlock detection enabled (60s).")
	
	canvas = CanvasLayer.new()
	canvas.layer = 100 # Ensure it draws on top of everything
	
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 300)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Transparent black background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	
	output = RichTextLabel.new()
	output.scroll_following = true
	output.bbcode_enabled = true
	output.selection_enabled = true
	output.custom_minimum_size = Vector2(0, 300)
	output.add_theme_font_size_override("normal_font_size", 14)
	
	# Apply some margins inside the panel
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	
	margin.add_child(output)
	panel.add_child(margin)
	
	canvas.add_child(panel)
	
	# Start hidden
	canvas.visible = false
	
	# We must add the canvas to the root so it persists across scene changes
	get_tree().root.call_deferred("add_child", canvas)
	
	log_message("[color=green]Console Initialized. Press ~ to collapse.[/color]")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ASCIITILDE or event.keycode == KEY_QUOTELEFT:
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console():
	canvas.visible = not canvas.visible

func _process(_delta):
	if _is_headless_bot:
		if Time.get_ticks_msec() - _last_log_time > _deadlock_timeout_ms:
			log_message("\n[color=red][DEADLOCK DETECTED] No log messages received for %d seconds. Exiting...[/color]\n" % (_deadlock_timeout_ms / 1000))
			# Allow a tiny bit of time for print buffers to flush
			await get_tree().create_timer(0.1).timeout
			get_tree().quit(1)

@rpc("any_peer", "call_local", "reliable")
func log_message(msg: String):
	_last_log_time = Time.get_ticks_msec()
	print(msg.strip_edges()) # Still print to standard stdout
	_logs.append(msg)
	if _logs.size() > max_lines:
		_logs.pop_front()
	
	if output:
		output.text = "\n".join(_logs)
