extends Node3D

const PLANKS_MODEL := "res://assets/Synty/PolygonApocalypse/Prefabs/Weapons/Melee/SM_Wep_Plank_01.tscn"
const MAX_LAYERS := 4
const LAYER_HEIGHT := 0.17

var amount := 0

var _label: Label3D


func _ready() -> void:
	add_to_group("material_piles")
	_rebuild()


func setup(p_amount: int) -> void:
	amount = maxi(p_amount, 0)
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var layers := clampi(1 + amount / 50, 1, MAX_LAYERS)
	var packed: PackedScene = load(PLANKS_MODEL)
	for i in layers:
		var layer: Node3D = null
		if packed != null:
			layer = packed.instantiate()
			var aabb := _combined_aabb(layer)
			if aabb.size.y > 0.01:
				var factor := 0.15 / aabb.size.y
				layer.scale = Vector3.ONE * factor
				layer.position = Vector3(
					0, 0.075 + i * LAYER_HEIGHT - aabb.position.y * factor, 0
				)
				layer.rotation.y = (0.4 if i % 2 == 1 else 0.0) + randf_range(-0.06, 0.06)
			else:
				layer.queue_free()
				layer = null
		if layer == null:
			layer = _make_fallback_box(i)
		add_child(layer)
	_label = Label3D.new()
	_label.text = "建材 ×%d" % amount
	_label.font_size = 64
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 8
	_label.position = Vector3(0, 0.45 + layers * LAYER_HEIGHT, 0)
	add_child(_label)


func _make_fallback_box(index: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.15, 0.6)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0, 0.075 + index * LAYER_HEIGHT, 0)
	mesh_instance.rotation.y = 0.4 if index % 2 == 1 else 0.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.45, 0.28)
	mesh_instance.material_override = material
	return mesh_instance


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
