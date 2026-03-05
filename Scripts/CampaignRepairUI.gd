extends PopupPanel
class_name CampaignRepairUI

var campaign: Node
var system_id: String
var faction: String

var ship_list: ItemList
var repair_hull_btn: Button
var repair_sys_btn: Button
var details_lbl: RichTextLabel

var local_ships: Array = []
var selected_ship_idx: int = -1

func _init(p_system_id: String, p_faction: String):
	campaign = Engine.get_main_loop().root.get_node("CampaignManager")
	system_id = p_system_id
	faction = p_faction
	
	min_size = Vector2i(600, 400)
	exclusive = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	var header = Label.new()
	header.text = "Starship Construction Center: " + system_id
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	vbox.add_child(header)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)
	
	ship_list = ItemList.new()
	ship_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_list.size_flags_stretch_ratio = 1.0
	ship_list.item_selected.connect(_on_ship_selected)
	hbox.add_child(ship_list)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	hbox.add_child(right_vbox)
	
	details_lbl = RichTextLabel.new()
	details_lbl.bbcode_enabled = true
	details_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(details_lbl)
	
	repair_hull_btn = Button.new()
	repair_hull_btn.text = "Repair Hull"
	repair_hull_btn.disabled = true
	repair_hull_btn.pressed.connect(_on_repair_hull)
	right_vbox.add_child(repair_hull_btn)
	
	repair_sys_btn = Button.new()
	repair_sys_btn.text = "Repair Critical System"
	repair_sys_btn.disabled = true
	repair_sys_btn.pressed.connect(_on_repair_sys)
	right_vbox.add_child(repair_sys_btn)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): queue_free())
	vbox.add_child(close_btn)
	
	_refresh_data()

func _refresh_data():
	local_ships.clear()
	ship_list.clear()
	selected_ship_idx = -1
	_update_details()
	
	for f in campaign.fleets:
		if f.faction == faction and f.current_system_id == system_id and not f.is_moving():
			for i in range(f.ships.size()):
				local_ships.append({"fleet": f, "ship_idx": i, "ship": f.ships[i]})
				var s = f.ships[i]
				var hp = s.get("hull", s.get("max_hull", 100))
				var m_hp = s.get("max_hull", 100)
				ship_list.add_item("%s (%d/%d)" % [s.get("name", "Ship"), hp, m_hp])
				
func _on_ship_selected(idx: int):
	selected_ship_idx = idx
	_update_details()
	
func _update_details():
	if selected_ship_idx < 0 or selected_ship_idx >= local_ships.size():
		details_lbl.text = "Select a ship to view damage and repair options."
		repair_hull_btn.disabled = true
		repair_sys_btn.disabled = true
		if faction == "Sathar":
			repair_sys_btn.visible = false
			repair_hull_btn.text = "Enter 6-Day Construction Queue"
		return
		
	var entry = local_ships[selected_ship_idx]
	var s = entry["ship"]
	var txt = "[b]%s[/b]\n" % s.get("name", "Ship")
	
	var is_damaged = false
	var has_critical = false
	
	var hp = s.get("hull", s.get("max_hull", 100))
	var m_hp = s.get("max_hull", 100)
	txt += "Hull: %d / %d" % [hp, m_hp]
	if hp < m_hp: 
		txt += " [color=red](Damaged)[/color]"
		is_damaged = true
	if s.get("unrepairable_hull", false):
		txt += " [color=red](Permanent)[/color]"
	txt += "\n"
	
	if s.get("unrepairable_adf_modifier", 0) > 0:
		txt += "[color=red]ADF engines permanently crippled.[/color]\n"
		has_critical = true
	if s.get("unrepairable_mr_modifier", 0) > 0:
		txt += "[color=red]MR engines permanently crippled.[/color]\n"
		has_critical = true
	if s.get("unrepairable_electrical_fire", false) or s.get("unrepairable_disastrous_fire", false):
		txt += "[color=red]Structural Fires persisting.[/color]\n"
		has_critical = true
	if s.get("unrepairable_ccs", false):
		txt += "[color=red]Computer system destroyed.[/color]\n"
		has_critical = true
	if s.get("unrepairable_icm", false) or s.get("unrepairable_ms", false):
		txt += "[color=red]Defensive screens destroyed.[/color]\n"
		has_critical = true
		
	if s.has("weapons"):
		for w in s["weapons"]:
			if w.get("unrepairable", false):
				txt += "[color=red]Weapon destroyed: %s[/color]\n" % w.get("name", "Unknown")
				has_critical = true
				
	if not is_damaged and not has_critical:
		txt += "\n[color=green]Ship is fully operational.[/color]"
		
	details_lbl.text = txt
	
	if faction == "Sathar":
		repair_sys_btn.visible = false
		repair_hull_btn.text = "Enter 6-Day Construction Queue"
		# Check if already queued
		var is_queued = false
		for q in campaign.sathar_repair_queue:
			if q["ship"] == s:
				is_queued = true
				break
		if is_queued:
			repair_hull_btn.text = "(Currently in Queue)"
			repair_hull_btn.disabled = true
			details_lbl.text += "\n\n[color=yellow]This ship is currently undergoing repairs in the SCC queue.[/color]"
		else:
			repair_hull_btn.disabled = not (is_damaged or has_critical)
	else:
		# UPF Logic
		var cap = campaign.UPF_SCC_CAPACITIES.get(system_id, 0)
		var used = campaign.upf_scc_capacity_used.get(system_id, 0)
		var avail = cap - used
		
		txt += "\n\n[color=aqua]SCC Daily Capacity: %d / %d[/color]" % [avail, cap]
		details_lbl.text = txt
		
		repair_hull_btn.disabled = (not is_damaged) or (avail <= 0) or s.get("unrepairable_hull", false)
		if hp >= m_hp: repair_hull_btn.disabled = true
		
		repair_sys_btn.disabled = (not has_critical) or (avail < cap) # Repairing a system uses FULL daily capacity
		
func _on_repair_hull():
	if selected_ship_idx < 0: return
	
	if faction == "Sathar":
		# Add to queue
		var entry = local_ships[selected_ship_idx]
		var s = entry["ship"]
		var f = entry["fleet"]
		
		f.ships.remove_at(entry["ship_idx"])
		if f.ships.size() == 0:
			campaign.remove_fleet(f)
			
		campaign.sathar_repair_queue.append({
			"fleet_name": f.fleet_name,
			"ship": s,
			"days_remaining": 6,
			"system_id": system_id
		})
		
		ConsoleManager.log_message("[color=green]Sathar command queued %s for 6 days of SCC repairs.[/color]" % s.get("name", "Ship"))
		campaign.emit_signal("campaign_state_updated")
		_refresh_data()
	else:
		# UPF Hull Repair
		var entry = local_ships[selected_ship_idx]
		var s = entry["ship"]
		var hp = s.get("hull", s.get("max_hull", 100))
		var m_hp = s.get("max_hull", 100)
		
		var cap = campaign.UPF_SCC_CAPACITIES.get(system_id, 0)
		var used = campaign.upf_scc_capacity_used.get(system_id, 0)
		var avail = cap - used
		
		var needed = m_hp - hp
		var restored = min(needed, avail)
		
		s["hull"] = hp + restored
		campaign.upf_scc_capacity_used[system_id] = used + restored
		
		ConsoleManager.log_message("[color=green]UPF SCC at %s patched %d hull points on %s.[/color]" % [system_id, restored, s.get("name", "Ship")])
		campaign.emit_signal("campaign_state_updated")
		_refresh_data()

func _on_repair_sys():
	if selected_ship_idx < 0 or faction == "Sathar": return
	
	var entry = local_ships[selected_ship_idx]
	var s = entry["ship"]
	var cap = campaign.UPF_SCC_CAPACITIES.get(system_id, 0)
	
	# Uses full capacity
	campaign.upf_scc_capacity_used[system_id] = cap
	
	# Repair one critical system (remove unrepairable flag)
	var repaired_something = false
	if s.get("unrepairable_adf_modifier", 0) > 0:
		s["unrepairable_adf_modifier"] -= 1
		repaired_something = true
	elif s.get("unrepairable_mr_modifier", 0) > 0:
		s["unrepairable_mr_modifier"] -= 1
		repaired_something = true
	elif s.get("unrepairable_electrical_fire", false):
		s["unrepairable_electrical_fire"] = false
		repaired_something = true
	elif s.get("unrepairable_disastrous_fire", false):
		s["unrepairable_disastrous_fire"] = false
		repaired_something = true
	elif s.get("unrepairable_ccs", false):
		s["unrepairable_ccs"] = false
		repaired_something = true
	elif s.get("unrepairable_icm", false):
		s["unrepairable_icm"] = false
		repaired_something = true
	elif s.get("unrepairable_ms", false):
		s["unrepairable_ms"] = false
		repaired_something = true
	else:
		if s.has("weapons"):
			for w in s["weapons"]:
				if w.get("unrepairable", false):
					w["unrepairable"] = false
					w["is_crippled"] = false # also fix the cripple state if making it repairable
					repaired_something = true
					break
					
	if repaired_something:
		ConsoleManager.log_message("[color=green]UPF SCC at %s dedicated full daily capacity to clear a critical damage lock on %s.[/color]" % [system_id, s.get("name", "Ship")])
		campaign.emit_signal("campaign_state_updated")
		_refresh_data()
