extends Node3D

const REACH := 2.8

var weapon_id := "pistol"
var ammo := 8
var net_id := 0
var net_puppet := false


func net_params() -> Dictionary:
	return {"weapon_id": weapon_id, "ammo": ammo}


func setup_puppet(params: Dictionary) -> void:
	weapon_id = String(params.get("weapon_id", weapon_id))
	ammo = int(params.get("ammo", ammo))


func _ready() -> void:
	add_to_group("interactables")
	_build_visual()
	if (
		not net_puppet
		and not GameState.test_mode
		and Network.is_multiplayer()
		and Network.is_server()
	):
		Network.register_entity(self, "drop", net_params())


func prompt_text() -> String:
	return ""


# —— 统一交互菜单协议：拾取（单选项直接执行）——

func interact_title() -> String:
	return GameState.WEAPONS[weapon_id]["name"]


func interact_options(_player: Node3D) -> Array:
	if not _near_player():
		return []
	return [{"id": "take", "label": "拾取 %s（弹药 %d）" % [GameState.WEAPONS[weapon_id]["name"], ammo]}]


func interact_choose(id: String, _player: Node3D) -> void:
	if id == "take":
		_pick_up()


func _near_player() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	return player != null and global_position.distance_to(player.global_position) <= REACH


func _pick_up() -> void:
	if GameState.is_zombie():
		GameState.notify("丧尸无法使用枪械")
		return
	if int(GameState.weapons.get(weapon_id, 0)) <= 0:
		GameState.add_weapon(weapon_id)
		GameState.notify("拾取 %s（V/1~8 切换）" % GameState.WEAPONS[weapon_id]["name"])
	else:
		GameState.notify("拾取弹药 %d 发" % ammo)
	var caliber := GameState.caliber_of(weapon_id)
	if caliber.is_empty():
		GameState.grant_generic_ammo(ammo)
	else:
		GameState.add_ammo(caliber, "normal", ammo)
	if net_puppet:
		Network.request_entity_remove(net_id)
	else:
		Network.unregister_entity(self)
	queue_free()


func _build_visual() -> void:
	var path := GameState.weapon_model_path(weapon_id)
	if not path.is_empty() and ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		add_child(model)
		var aabb := _combined_aabb(model)
		if aabb.size.z > 0.01:
			# 枪口朝 +Z，放平展示并抬到箱子上方
			var factor := 0.25 / aabb.size.y if weapon_id == "grenade" else 0.9 / aabb.size.z
			model.scale = Vector3.ONE * factor
			model.position = Vector3(0.0, 0.2 - aabb.position.y * factor - aabb.size.y * factor * 0.5, 0.0)
			return
		model.queue_free()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.12, 1.0)
	body.mesh = box
	body.position = Vector3(0, 0.14, 0)
	body.material_override = _make_material(Color(0.14, 0.14, 0.16))
	add_child(body)
	var mag := MeshInstance3D.new()
	var mag_box := BoxMesh.new()
	mag_box.size = Vector3(0.18, 0.12, 0.24)
	mag.mesh = mag_box
	mag.position = Vector3(0.22, 0.08, 0.1)
	mag.material_override = _make_material(Color(0.85, 0.75, 0.3))
	add_child(mag)


func _combined_aabb(root: Node3D) -> AABB:
	var boxes: Array = []
	_collect_aabbs(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var result: AABB = boxes[0]
	for i in range(1, boxes.size()):
		result = result.merge(boxes[i])
	return result


func _collect_aabbs(node: Node, xform: Transform3D, boxes: Array) -> void:
	if node is Node3D:
		xform = xform * node.transform
		if node is MeshInstance3D and node.mesh != null:
			boxes.append(xform * node.get_aabb())
	for child in node.get_children():
		_collect_aabbs(child, xform, boxes)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
