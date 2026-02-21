extends Control

func _ready():
    var panel_repair = PanelContainer.new()
    panel_repair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel_repair.custom_minimum_size = Vector2(800, 600)
    add_child(panel_repair)
    
    var vbox = VBoxContainer.new()
    panel_repair.add_child(vbox)
    
    var lbl = Label.new()
    lbl.text = "DAMAGE CONTROL (DCR)"
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_font_size_override("font_size", 24)
    vbox.add_child(lbl)
    
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(scroll)
    
    var list_repair = VBoxContainer.new()
    list_repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list_repair)
    
    # Mocking single ship with damage
    var ship_lbl = Label.new()
    ship_lbl.text = "TestShip (DCR: 3)"
    ship_lbl.modulate = Color.CYAN
    list_repair.add_child(ship_lbl)

    var rem_lbl = Label.new()
    rem_lbl.text = "Budget Remaining: 3"
    rem_lbl.add_theme_font_size_override("font_size", 12)
    list_repair.add_child(rem_lbl)

    # Mocking single damaged system
    var hbox = HBoxContainer.new()
    var sys_lbl = Label.new()
    sys_lbl.text = "Hull (10/20)"
    sys_lbl.custom_minimum_size.x = 200
    hbox.add_child(sys_lbl)
    
    var slider = HSlider.new()
    slider.min_value = 0
    slider.max_value = 100
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.custom_minimum_size.x = 150
    slider.value = 0
    hbox.add_child(slider)
    
    var val_lbl = Label.new()
    val_lbl.text = "0%"
    val_lbl.custom_minimum_size.x = 40
    hbox.add_child(val_lbl)

    list_repair.add_child(hbox)

    # Execute button
    var btn_repair_exec = Button.new()
    btn_repair_exec.text = "EXECUTE REPAIRS"
    btn_repair_exec.modulate = Color(0.2, 1.0, 0.2)
    vbox.add_child(btn_repair_exec)
    
    # Wait for Godot to setup the Viewport and process the scene tree
    await get_tree().create_timer(1.0).timeout
    
    var img = get_viewport().get_texture().get_image()
    # Explicit absolute path using OS, to the artifact brain directly
    var path = "/home/jdjeffers/.gemini/antigravity/brain/0bf7e67c-a9f1-4166-b9e0-6f0b12032f04/repair_panel_mockup.png"
    img.save_png(path)
    print("SAVED TO: ", path)
    get_tree().quit()
