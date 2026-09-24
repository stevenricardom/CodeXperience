@tool
extends SceneTree
func _init():
    for key in HTTPRequest.Result.keys():
        print(key, " = ", HTTPRequest.Result[key])
    quit()
