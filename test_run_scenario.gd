extends SceneTree

func _init():
    var gm = load("res://Scripts/GameManager.gd").new()
    root.add_child(gm)
    
    # Needs a UI layer to prevent null crashes
    gm.ui_layer = CanvasLayer.new()
    gm.add_child(gm.ui_layer)
    gm._setup_ui()
    gm._setup_repair_ui()
    
    print("----------------------------")
    print("Starting repair_test...")
    gm.setup_game(12345, "repair_test")
    
    print("Phase is now: ", gm.current_phase)
    print("Repair Subphase: ", gm.repair_subphase)
    print("UI lists in movement panel: ", gm.list_movement.get_child_count())
    print("----------------------------")
    
    quit()
