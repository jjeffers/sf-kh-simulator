extends SceneTree
func _init():
    var script = load("res://Scripts/ComputerOpponent.gd")
    if script:
        var inst = script.new()
        if inst:
            print("ComputerOpponent instantiated successfully")
        else:
            print("ComputerOpponent failed to instantiate")
    else:
        print("ComputerOpponent failed to load")
    quit()
