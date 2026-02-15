extends PanelContainer


var header_box: HBoxContainer
var icon_rect: TextureRect
var name_label: Label
var class_label: Label
var faction_label: Label

var stats_grid: GridContainer
var hull_bar: ProgressBar
var hull_label: Label

# Labels for stats
var lbl_speed: Label
var lbl_adf: Label
var lbl_mr: Label
var lbl_effective_mr: Label


var systems_container: HBoxContainer
var weapons_vbox: VBoxContainer
var defenses_vbox: VBoxContainer

var alerts_panel: PanelContainer
var alerts_vbox: VBoxContainer

func _init():
	_setup_ui()

func _setup_ui():
	# Main Vertical Layout
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# --- HEADER SECTION ---
	# [ ICON ]  NAME
	#           Class
	var header_panel = PanelContainer.new()
	main_vbox.add_child(header_panel)
	
	header_box = HBoxContainer.new()
	header_panel.add_child(header_box)
	
	# Icon
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_box.add_child(icon_rect)
	
	# Name/Class Info
	var info_vbox = VBoxContainer.new()
	header_box.add_child(info_vbox)
	
	name_label = Label.new()
	name_label.text = "SHIP NAME"
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.YELLOW)
	info_vbox.add_child(name_label)
	
	class_label = Label.new()
	class_label.text = "Ship Class"
	class_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	info_vbox.add_child(class_label)
	
	faction_label = Label.new()
	faction_label.text = "Faction"
	faction_label.add_theme_font_size_override("font_size", 12)
	faction_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_vbox.add_child(faction_label)

	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# --- STATS SECTION ---
	# Hull Bar | Speed | ADF | MR
	var stats_panel = MarginContainer.new()
	stats_panel.add_theme_constant_override("margin_top", 5)
	stats_panel.add_theme_constant_override("margin_bottom", 5)
	main_vbox.add_child(stats_panel)
	
	var stats_vbox = VBoxContainer.new()
	stats_panel.add_child(stats_vbox)
	
	# Hull Row
	var hull_hbox = HBoxContainer.new()
	stats_vbox.add_child(hull_hbox)
	
	var lbl_hull_title = Label.new()
	lbl_hull_title.text = "HULL:"
	hull_hbox.add_child(lbl_hull_title)
	
	hull_bar = ProgressBar.new()
	hull_bar.custom_minimum_size = Vector2(150, 20)
	hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hull_bar.show_percentage = false
	hull_hbox.add_child(hull_bar)
	
	hull_label = Label.new()
	hull_label.text = "15/15"
	hull_hbox.add_child(hull_label)
	
	# Stats Grid
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_vbox.add_child(stats_grid)
	
	_create_stat_row(stats_grid, "SPEED:", "lbl_speed")
	_create_stat_row(stats_grid, "ADF:", "lbl_adf")
	_create_stat_row(stats_grid, "MR:", "lbl_mr")
	_create_stat_row(stats_grid, "EFF. MR:", "lbl_effective_mr")

	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# --- SYSTEMS SECTION ---
	# Offensive | Defensive
	systems_container = HBoxContainer.new()
	main_vbox.add_child(systems_container)
	
	# Offensive Column
	var off_vbox = VBoxContainer.new()
	off_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	systems_container.add_child(off_vbox)
	
	var lbl_off = Label.new()
	lbl_off.text = "OFFENSIVE"
	lbl_off.add_theme_color_override("font_color", Color.SALMON)
	off_vbox.add_child(lbl_off)
	
	weapons_vbox = VBoxContainer.new()
	off_vbox.add_child(weapons_vbox)
	
	# Defensive Column
	var def_vbox = VBoxContainer.new()
	def_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	systems_container.add_child(def_vbox)
	
	var lbl_def = Label.new()
	lbl_def.text = "DEFENSIVE"
	lbl_def.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	def_vbox.add_child(lbl_def)
	
	defenses_vbox = VBoxContainer.new()
	def_vbox.add_child(defenses_vbox)
	
	# --- ALERTS SECTION ---
	alerts_panel = PanelContainer.new()
	alerts_panel.visible = false # Hidden directly
	main_vbox.add_child(alerts_panel)
	
	var alerts_style = StyleBoxFlat.new()
	alerts_style.bg_color = Color(0.2, 0.0, 0.0, 0.8)
	alerts_style.border_width_left = 2
	alerts_style.border_color = Color.RED
	alerts_panel.add_theme_stylebox_override("panel", alerts_style)
	
	alerts_vbox = VBoxContainer.new()
	alerts_panel.add_child(alerts_vbox)
	
	var lbl_alert_title = Label.new()
	lbl_alert_title.text = "! SYSTEM ALERTS"
	lbl_alert_title.add_theme_color_override("font_color", Color.RED)
	alerts_vbox.add_child(lbl_alert_title)

func _create_stat_row(parent, title, var_name):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)
	
	var lbl_t = Label.new()
	lbl_t.text = title
	lbl_t.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(lbl_t)
	
	var lbl_v = Label.new()
	lbl_v.text = "-"
	set(var_name, lbl_v) # Assign to member var
	hbox.add_child(lbl_v)

func update_from_ship(ship):
	if not ship or not is_instance_valid(ship):
		visible = false
		return
		
	visible = true
	
	# Header
	name_label.text = ship.name.to_upper()
	class_label.text = ship.ship_class
	faction_label.text = ship.faction
	icon_rect.texture = ship.get_texture()
	
	# Stats
	hull_bar.max_value = ship.max_hull
	hull_bar.value = ship.hull
	hull_label.text = "%d/%d" % [ship.hull, ship.max_hull]
	
	# Hull Bar Color
	var pct = float(ship.hull) / float(ship.max_hull)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color.RED.lerp(Color.GREEN, pct)
	

	hull_bar.add_theme_stylebox_override("fill", sb)
	
	lbl_speed.text = "%d" % ship.speed # Assuming km/s logic is game unit
	lbl_adf.text = "%d" % ship.adf
	lbl_mr.text = "%d" % ship.mr
	
	# Weapons
	for c in weapons_vbox.get_children(): c.queue_free()
	
	for i in range(ship.weapons.size()):
		var w = ship.weapons[i]
		var w_lbl = Label.new()
		var w_name = w.get("name", "Unknown Weapon")
		
		# Highlight Logic
		var prefix = "• "
		var is_selected = (i == ship.current_weapon_index)
		
		if is_selected:
			prefix = "> "
			w_lbl.add_theme_color_override("font_color", Color.YELLOW)
			
		w_lbl.text = "%s%s" % [prefix, w_name]
		
		var max_ammo = w.get("max_ammo", 999)
		var current_ammo = w.get("ammo", 0)
		
		if max_ammo < 900: # Not infinite
			w_lbl.text += " (%d)" % current_ammo
		else:
			w_lbl.text += " (∞)"


		if w.get("fired", false):
			w_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			w_lbl.text += " [FIRED]"

			
		weapons_vbox.add_child(w_lbl)
		
	# Defenses
	for c in defenses_vbox.get_children(): c.queue_free()
	
	# Base Defense (RH, etc)
	var def_lbl = Label.new()
	def_lbl.text = "• Hull: %s" % ship.defense
	defenses_vbox.add_child(def_lbl)
	
	# ICM
	if ship.icm_max > 0:
		var icm_lbl = Label.new()
		icm_lbl.text = "• ICMs (%d/%d)" % [ship.icm_current, ship.icm_max]
		defenses_vbox.add_child(icm_lbl)
		
	# Masking Screen
	if ship.ms_max > 0:
		var ms_lbl = Label.new()
		ms_lbl.text = "• Masking Screen"
		if ship.is_ms_active:
			ms_lbl.text += " (ACTIVE)"
			ms_lbl.add_theme_color_override("font_color", Color.CYAN)
		else:
			ms_lbl.text += " (%d)" % ship.ms_current
		defenses_vbox.add_child(ms_lbl)

		
	# Alerts
	# Clear old alerts (keep title)
	var alert_children = alerts_vbox.get_children()
	for i in range(1, alert_children.size()):
		alert_children[i].queue_free()
		
	var has_alerts = false
	
	# Critical Hull Alert
	if pct < 0.5:
		_add_alert("> HULL INTEGRITY CRITICAL")
		has_alerts = true
		
	if ship.speed == 0 and ship.has_moved:
		# Maybe stopped warning?
		pass
		
	alerts_panel.visible = has_alerts


func update_dynamic_status(eff_mr_text: String):
	if lbl_effective_mr:
		lbl_effective_mr.text = eff_mr_text

func _add_alert(msg: String):
	var l = Label.new()
	l.text = msg
	l.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	alerts_vbox.add_child(l)