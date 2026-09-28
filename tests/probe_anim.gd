extends SceneTree
func _initialize() -> void:
	var cinst: Node = load("res://assets/Synty/PolygonApocalypse/Prefabs/Characters/SM_Chr_Zombie_Male_01.tscn").instantiate()
	for c in cinst.find_children("*", "AnimationPlayer", true, false):
		print("预制体自带动画: ", (c as AnimationPlayer).get_animation_list())
		break
	cinst.free()
	# 其它包的角色预制体有没有带动画
	for p in ["res://assets/Synty/PolygonMilitary/Prefabs/Characters"]:
		var dir := DirAccess.open(p)
		if dir != null:
			for f in dir.get_files():
				if f.ends_with(".tscn") and "Chr" in f:
					var inst: Node = load(p + "/" + f).instantiate()
					for c in inst.find_children("*", "AnimationPlayer", true, false):
						var list := (c as AnimationPlayer).get_animation_list()
						if not list.is_empty():
							print(f, ": ", list)
						break
					inst.free()
					break
	quit(0)
