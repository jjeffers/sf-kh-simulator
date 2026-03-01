extends SceneTree

func _init():
    var gm = load("res://Scripts/GameManager.gd").new()
    var Ship = load("res://Scripts/Ship.gd")
    var target = Ship.new()
    target.name = "USSEnterprise"
    target.side_id = 1
    target.icm_max = 3
    target.icm_current = 3
    
    gm.add_child(target)
    gm.ships.append(target)
    
    gm.my_side_id = 1
    gm.ui_layer = CanvasLayer.new()
    gm.add_child(gm.ui_layer)
    
    print("BEFORE TRIGGER: target_name = ", target.name)
    gm._trigger_icm_decision("Enemy Ship", "Torpedo", "Torpedo", 80, target, [target])
    print("AFTER TRIGGER: panel_icm = ", gm.panel_icm)
    
    quit()
