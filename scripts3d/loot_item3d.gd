extends Node3D

const REACH := 2.4

var loot_id := "food"

var _model: Node3D


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("loot_pickups")
	_build_model()


func _build_model() -> void:
	var info := GameState.loot_info(loot_id)
	var path := String(info.get("model", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if packed == null:
		return
	_model = packed.instantiate()
	# Synty 预制体自带碰撞体：掉落物不需要物理
	for static_body in _model.find_children("*", "StaticBody3D", true, false):
		static_body.free()
	add_child(_model)
	var aabb := _combined_aabb(_model)
	if aabb.size.y > 0.01:
		var factor := randf_range(0.3, 0.42) / aabb.size.y
		_model.scale = Vector3.ONE * factor
		_model.position = Vector3(0, -aabb.position.y * factor, 0)


func prompt_text() -> String:
	return ""


# —— 统一交互菜单协议：拾取（单选项直接执行）——

func interact_title() -> String:
	return GameState.loot_name(loot_id)


func interact_options(player: Node3D) -> Array:
	if player == null or global_position.distance_to(player.global_position) > REACH:
		return []
	return [{"id": "take", "label": "拾取 %s" % GameState.loot_name(loot_id)}]


func interact_choose(id: String, _player: Node3D) -> void:
	if id == "take":
		GameState.add_loot(loot_id)
		queue_free()


func _near_player() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	return player != null and global_position.distance_to(player.global_position) <= REACH


func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var started := false
	var _aabb_meshes: Array = []
	if root is MeshInstance3D:
		_aabb_meshes.append(root)
	_aabb_meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for child in _aabb_meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var box: AABB = mesh_instance.get_aabb()
		for i in 8:
			var point: Vector3 = mesh_instance.global_transform * box.get_endpoint(i)
			if not started:
				result = AABB(point, Vector3.ZERO)
				started = true
			else:
				result = result.expand(point)
	return result
