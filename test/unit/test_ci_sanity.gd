extends GutTest

func test_can_load_all_scripts():
    var dir = DirAccess.open("res://Scripts")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".gd"):
                var path = "res://Scripts/" + file_name
                var res = load(path)
                assert_not_null(res, "Failed to load script: " + path)
                if res == null:
                    gut.p("ERROR: Could not load " + path)
            file_name = dir.get_next()
    else:
        fail_test("Could not open res://Scripts")
