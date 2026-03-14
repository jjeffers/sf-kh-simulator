extends PanelContainer

signal transfer_confirmed

@onready var source_lbl = $VBoxContainer/HBoxContainer/SourceVBox/SourceFleetLabel
@onready var source_list = $VBoxContainer/HBoxContainer/SourceVBox/SourceShipsList

@onready var target_dropdown = $VBoxContainer/HBoxContainer/TargetVBox/TargetFleetDropdown
@onready var target_name_edit = $VBoxContainer/HBoxContainer/TargetVBox/TargetFleetNameEdit
@onready var target_list = $VBoxContainer/HBoxContainer/TargetVBox/TargetShipsList

@onready var transfer_right_btn = $VBoxContainer/HBoxContainer/CenterBox/TransferRightBtn
@onready var transfer_left_btn = $VBoxContainer/HBoxContainer/CenterBox/TransferLeftBtn

@onready var confirm_btn = $VBoxContainer/BottomHBox/ConfirmBtn
@onready var cancel_btn = $VBoxContainer/BottomHBox/CancelBtn

var campaign: Node
var source_fleet: CampaignFleet
var available_target_fleets: Array[CampaignFleet] = []

# Staging definitions
# These arrays hold references to the ship dictionaries matching the fleet
var staging_source_ships: Array = []
var staging_target_ships: Array = []
var initial_source_ships: Array = []
var target_existing_ships: Array = []

func _ready():
	campaign = CampaignManager
	
	transfer_right_btn.pressed.connect(_on_transfer_right)
	transfer_left_btn.pressed.connect(_on_transfer_left)
	target_dropdown.item_selected.connect(_on_target_dropdown_selected)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	
	source_list.set_drag_forwarding(_source_get_drag_data, _source_can_drop_data, _source_drop_data)
	target_list.set_drag_forwarding(_target_get_drag_data, _target_can_drop_data, _target_drop_data)

func setup(p_source_fleet: CampaignFleet):
	source_fleet = p_source_fleet
	source_lbl.text = source_fleet.fleet_name
	
	# Initial staging population
	staging_source_ships.clear()
	staging_target_ships.clear()
	initial_source_ships.clear()
	target_existing_ships.clear()
	
	for s in source_fleet.ships:
		staging_source_ships.append(s)
		initial_source_ships.append(s)
		
	_populate_target_dropdown()
	_update_lists()

func _populate_target_dropdown():
	target_dropdown.clear()
	available_target_fleets.clear()
	
	# Add the "New Fleet" Option
	target_dropdown.add_item("--- New Fleet ---")
	
	# Find other valid fleets in the exact same system for the same faction
	for f in campaign.fleets:
		if f != source_fleet and f.faction == source_fleet.faction and f.current_system_id == source_fleet.current_system_id and not f.is_moving():
			available_target_fleets.append(f)
			target_dropdown.add_item(f.fleet_name)
			
	_on_target_dropdown_selected(0)

func _on_target_dropdown_selected(idx: int):
	target_existing_ships.clear()
	if idx == 0:
		target_name_edit.visible = true
	else:
		target_name_edit.visible = false
		var target_f = available_target_fleets[idx - 1]
		target_existing_ships = target_f.ships.duplicate()
		
	_update_lists()

func _format_ship_item(item_list: ItemList, ship, is_existing_target: bool = false) -> int:
	var s_name = "Unknown Ship"
	var health_pct = 1.0
	var ShipScript = load("res://Scripts/Ship.gd")
	var max_hull_val = 100.0
	
	if typeof(ship) == TYPE_DICTIONARY:
		s_name = ship.get("name", ship.get("ship_name", "Ship")) + " (" + ship.get("class", ship.get("ship_class", "Unknown")) + ")"
		if ShipScript:
			var dummy = ShipScript.new()
			var s_class_name = ship.get("class", ship.get("ship_class", ""))
			var method_name = "configure_" + s_class_name.replace(" ", "_").to_lower()
			if dummy.has_method(method_name):
				dummy.call(method_name)
				max_hull_val = float(dummy.hull)
			dummy.free()
		health_pct = float(ship.get("hull", max_hull_val)) / max_hull_val
	elif typeof(ship) == TYPE_OBJECT and ship.has_method("get_ship_name"):
		s_name = ship.get_ship_name()
		var real_max = ship.get("max_hull", max_hull_val)
		if ship.get("hull"):
			health_pct = float(ship.hull) / float(real_max)
			
	if is_existing_target:
		s_name = "[Existing] " + s_name
			
	item_list.add_item(s_name)
	var item_idx = item_list.item_count - 1
	item_list.set_item_metadata(item_idx, ship)
	
	if health_pct >= 0.75:
		item_list.set_item_custom_fg_color(item_idx, Color(0.2, 1.0, 0.2)) # Green
	elif health_pct >= 0.25:
		item_list.set_item_custom_fg_color(item_idx, Color(1.0, 0.6, 0.2)) # Orange
	else:
		item_list.set_item_custom_fg_color(item_idx, Color(1.0, 0.2, 0.2)) # Red
		
	if is_existing_target:
		item_list.set_item_custom_bg_color(item_idx, Color(0.2, 0.2, 0.2, 0.5))
		# Dim the text slightly
		var current_color = item_list.get_item_custom_fg_color(item_idx)
		item_list.set_item_custom_fg_color(item_idx, current_color.darkened(0.3))
		
	return item_idx
		
func _update_lists():
	source_list.clear()
	target_list.clear()
	
	for s in staging_source_ships:
		_format_ship_item(source_list, s)
		
	for s in target_existing_ships:
		_format_ship_item(target_list, s, true)
		
	for s in staging_target_ships:
		_format_ship_item(target_list, s)
		
	confirm_btn.disabled = staging_target_ships.is_empty()

func _on_transfer_right():
	var selected = source_list.get_selected_items()
	if selected.is_empty(): return
	
	# Start pushing from highest index to lowest to avoid changing the indexes of items not processed yet 
	selected.reverse()
	
	for idx in selected:
		var ship = source_list.get_item_metadata(idx)
		staging_source_ships.erase(ship)
		staging_target_ships.append(ship)
		
	_update_lists()

func _on_transfer_left():
	var selected = target_list.get_selected_items()
	if selected.is_empty(): return
	
	selected.reverse()
	for idx in selected:
		var ship = target_list.get_item_metadata(idx)
		if staging_target_ships.has(ship):
			staging_target_ships.erase(ship)
			staging_source_ships.append(ship)
		
	_update_lists()

func _on_confirm_pressed():
	if staging_target_ships.is_empty():
		return
		
	# Check if source fleet will be completely empty
	var source_idx = campaign.fleets.find(source_fleet)
	if source_idx == -1:
		queue_free()
		return
		
	# Identify the actual target
	var is_new_fleet = target_dropdown.selected == 0
	
	# Get the correct indices mapping to original ships array in CampaignManager
	var ship_indices = []
	for st_ship in staging_target_ships:
		var original_idx = source_fleet.ships.find(st_ship)
		if original_idx != -1:
			ship_indices.append(original_idx)
			
	if is_new_fleet:
		var new_name = target_name_edit.text.strip_edges()
		if new_name == "":
			new_name = "New Fleet"
		campaign.rpc_create_fleet_from_transfer.rpc(source_idx, ship_indices, new_name)
	else:
		var target_f = available_target_fleets[target_dropdown.selected - 1]
		var target_idx = campaign.fleets.find(target_f)
		campaign.rpc_transfer_ships.rpc(source_idx, target_idx, ship_indices)
		
	emit_signal("transfer_confirmed")
	queue_free()

func _on_cancel_pressed():
	queue_free()

func _source_get_drag_data(at_position: Vector2):
	var selected = source_list.get_selected_items()
	if selected.is_empty(): return null
	
	var data = {"source": "source_list", "items": selected}
	
	var preview = Label.new()
	preview.text = "Moving %d ships" % selected.size()
	set_drag_preview(preview)
	
	return data

func _source_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("source") and data["source"] == "target_list":
		return true
	return false

func _source_drop_data(at_position: Vector2, data: Variant):
	_on_transfer_left()

func _target_get_drag_data(at_position: Vector2):
	var selected = target_list.get_selected_items()
	if selected.is_empty(): return null
	
	# Filter out ships that are already in the target fleet natively
	var valid_items = []
	for idx in selected:
		var ship = target_list.get_item_metadata(idx)
		if staging_target_ships.has(ship):
			valid_items.append(idx)
			
	if valid_items.is_empty(): return null
	
	var data = {"source": "target_list", "items": valid_items}
	
	var preview = Label.new()
	preview.text = "Moving %d ships" % valid_items.size()
	set_drag_preview(preview)
	
	return data

func _target_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("source") and data["source"] == "source_list":
		return true
	return false

func _target_drop_data(at_position: Vector2, data: Variant):
	_on_transfer_right()

