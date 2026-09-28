extends Node3D

const SCENES := {
	"npc": preload("res://scenes3d/npc3d.tscn"),
	"zombie": preload("res://scenes3d/zombie3d.tscn"),
	"drop": preload("res://scenes3d/weapon_drop3d.tscn"),
	"pickup": preload("res://scenes3d/pickup3d.tscn"),
	"police_car": preload("res://scenes3d/police_car3d.tscn"),
}

var _puppets := {}


func _ready() -> void:
	if not Network.is_multiplayer() or Network.is_server():
		set_process(false)
		return
	Network.entity_spawned.connect(_on_spawn)
	Network.entity_removed.connect(_on_remove)
	Network.entity_state.connect(_on_state)
	# 场景就绪：向主机请求全量世界状态（迟到者/重进也能拿到所有实体）
	Network.request_world()


func _on_spawn(id: int, kind: String, params: Dictionary) -> void:
	if _puppets.has(id) or not SCENES.has(kind):
		return
	var node = SCENES[kind].instantiate()
	node.net_puppet = true
	node.net_id = id
	if node.has_method("setup_puppet"):
		node.setup_puppet(params)
	add_child(node)
	var pos = params.get("pos", null)
	if pos is Array and pos.size() >= 3:
		node.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	node.rotation.y = float(params.get("yaw", 0.0))
	if node.has_method("apply_net_state"):
		node.apply_net_state(
			PackedFloat32Array([
				node.global_position.x,
				node.global_position.y,
				node.global_position.z,
				node.rotation.y,
				0.0,
			]),
			0
		)
	_puppets[id] = node


func _on_remove(id: int) -> void:
	var node = _puppets.get(id, null)
	if node != null and is_instance_valid(node):
		node.queue_free()
	_puppets.erase(id)


func _on_state(ids: PackedInt32Array, data: PackedFloat32Array) -> void:
	for i in ids.size():
		var node = _puppets.get(ids[i], null)
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("apply_net_state"):
			node.apply_net_state(data, i * Network.STATE_FLOATS)
