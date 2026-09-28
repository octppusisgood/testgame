extends Node3D

const REACH := 2.8
const HOLD_SECONDS := 1.6

var loot_table := "house"
var searched := false

var _progress := 0.0
var _model: Node3D
var _outline: MeshInstance3D = null


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("loot_containers")
	_build_model()


func _build_model() -> void:
	var path := String(GameState.CONTAINER_MODELS.get(loot_table, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if packed == null:
		return
	_model = packed.instantiate()
	# Synty 预制体自带碰撞体：容器用下方自建盒式碰撞
	for static_body in _model.find_children("*", "StaticBody3D", true, false):
		static_body.free()
	add_child(_model)
	var aabb := _combined_aabb(_model)
	var factor := 1.0
	if aabb.size.y > 0.01:
		factor = randf_range(0.9, 1.3) / aabb.size.y
		_model.scale = Vector3.ONE * factor
		_model.position = Vector3(0, -aabb.position.y * factor, 0)
	_model.rotation.y = (PI / 2.0) * float(randi() % 4)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(
		maxf(aabb.size.x * factor, 0.4),
		maxf(aabb.size.y * factor, 0.4),
		maxf(aabb.size.z * factor, 0.4)
	)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, box.size.y / 2.0, 0)
	add_child(body)
	# 未搜刮金色描边：外扩背面壳（正面剔除），搜刮后隐藏
	var outline := MeshInstance3D.new()
	var outline_box := BoxMesh.new()
	outline_box.size = box.size * 1.1
	outline.mesh = outline_box
	var outline_material := StandardMaterial3D.new()
	outline_material.albedo_color = Color(1.0, 0.78, 0.2)
	outline_material.emission_enabled = true
	outline_material.emission = Color(1.0, 0.72, 0.15)
	outline_material.emission_energy_multiplier = 1.6
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.material_override = outline_material
	outline.position = body.position
	add_child(outline)
	_outline = outline


func prompt_text() -> String:
	if searched:
		return ""
	if not _near_player():
		return ""
	if _progress > 0.01:
		return "搜刮中 %d%%（长按 E）" % int(_progress * 100.0)
	return "长按 E 搜刮"


func _process(delta: float) -> void:
	if searched:
		return
	if not _near_player() or GameState.interact_menu_open:
		_progress = 0.0
		return
	if Input.is_action_pressed("interact"):
		_progress += delta / HOLD_SECONDS
		if _progress >= 1.0:
			_search()
	else:
		_progress = maxf(0.0, _progress - delta * 1.5)


func _near_player() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	return player != null and global_position.distance_to(player.global_position) <= REACH


func _search() -> void:
	searched = true
	_progress = 0.0
	if _outline != null:
		_outline.visible = false
	var names: Array = []
	for i in randi_range(2, 3):
		var id := GameState.roll_loot(loot_table)
		GameState.add_loot(id)
		names.append(GameState.loot_name(id))
	GameState.notify("搜刮到：" + "、".join(names))
	if _model != null and is_instance_valid(_model):
		_model.rotate_y(0.4)
		_model.scale *= 0.94


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
