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

var damaged_systems_panel: PanelContainer
var damaged_systems_vbox: VBoxContainer

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

	# --- DAMAGED SYSTEMS SECTION ---
	damaged_systems_panel = PanelContainer.new()
	damaged_systems_panel.visible = false
	main_vbox.add_child(damaged_systems_panel)

	var ds_style = StyleBoxFlat.new()
	ds_style.bg_color = Color(0.1, 0.0, 0.0, 0.8) # Darker red background
	ds_style.border_width_left = 2
	ds_style.border_color = Color.ORANGE
	damaged_systems_panel.add_theme_stylebox_override("panel", ds_style)

	damaged_systems_vbox = VBoxContainer.new()
	damaged_systems_panel.add_child(damaged_systems_vbox)

	var lbl_ds_title = Label.new()
	lbl_ds_title.text = "DAMAGED SYSTEMS"
	lbl_ds_title.add_theme_color_override("font_color", Color.ORANGE)
	damaged_systems_vbox.add_child(lbl_ds_title)

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
	if ship.current_adf_modifier > 0:
		lbl_adf.text = "%d (%d)" % [ship.get_effective_adf(), ship.adf]
		lbl_adf.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	else:
		lbl_adf.text = "%d" % ship.adf
		lbl_adf.remove_theme_color_override("font_color")
	lbl_mr.text = "%d" % ship.mr
	if lbl_effective_mr:
		lbl_effective_mr.text = "%d" % ship.get_effective_mr()
	
	# Weapons
	for c in weapons_vbox.get_children(): c.free()
	
	var idx = 0
	for w in ship.weapons:
		var w_lbl = Label.new()
		var w_name = w.get("name", "Unknown Weapon")
		w_lbl.text = "• %s" % w_name
		
		# Highlight Active Weapon
		if idx == ship.current_weapon_index:
			w_lbl.text = "> %s" % w_name # Prefix
			w_lbl.add_theme_color_override("font_color", Color.GREEN)
		
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
		idx += 1
		
	# Defenses
	for c in defenses_vbox.get_children(): c.free()
	
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

	_update_damaged_systems(ship)

func _update_damaged_systems(ship):
	# Clear previous items (keep title at index 0)
	var children = damaged_systems_vbox.get_children()
	for i in range(1, children.size()):
		children[i].queue_free()

	var damaged_items = []

	# 1. Crippled Weapons
	for w in ship.weapons:
		if w.get("is_crippled", false):
			damaged_items.append("Crippled: %s" % w.get("name", "Weapon"))

	# 2. Reduced ADF (Drive Hit)
	if ship.current_adf_modifier > 0:
		if ship.current_adf_modifier >= ship.adf and ship.adf > 0:
			damaged_items.append("ADF Destroyed")
		else:
			damaged_items.append("ADF Reduced by %d" % ship.current_adf_modifier)

	# 3. Reduced MR (Steering Hit)
	if ship.current_mr_modifier > 0:
		if ship.current_mr_modifier >= ship.mr and ship.mr > 0:
			damaged_items.append("MR Destroyed")
		else:
			damaged_items.append("MR Reduced by %d" % ship.current_mr_modifier)

	# 4. System Damage (CCS, ICM, MS)
	if ship.ccs_damaged:
		damaged_items.append("Combat Control System (CCS)")

	# Logic for ICM/MS destruction checks:
	# If current max is 0, but class suggests it should have them.
	# Fighters/Scouts don't have ICM/MS.
	var has_native_icm = not (ship.ship_class in ["Fighter", "Assault Scout"])
	# Note: Space Station has variable stats, but usually has ICM.
	if has_native_icm and ship.icm_max == 0:
		damaged_items.append("ICM System Destroyed")

	var has_native_ms = not (ship.ship_class in ["Fighter", "Assault Scout"])
	# Frigates+ usually have MS.
	if has_native_ms and ship.ms_max == 0:
		damaged_items.append("Masking Screen Destroyed")
		
	# 5. Fires
	if ship.has_electrical_fire:
		damaged_items.append("ELECTRICAL FIRE (+20 Dmg/Turn)")
	if ship.has_disastrous_fire:
		damaged_items.append("DISASTROUS FIRE (+20 Dmg, Stats Lost)")
		
	# Populate UI
	if damaged_items.size() > 0:
		damaged_systems_panel.visible = true
		for item in damaged_items:
			var l = Label.new()
			l.text = "• " + item
			l.add_theme_color_override("font_color", Color(1, 0.4, 0.4)) # Soft Red
			damaged_systems_vbox.add_child(l)
	else:
		damaged_systems_panel.visible = false


func update_dynamic_status(eff_mr_text: String):
	if lbl_effective_mr:
		lbl_effective_mr.text = eff_mr_text

func _add_alert(msg: String):
	var l = Label.new()
	l.text = msg
	l.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	alerts_vbox.add_child(l)