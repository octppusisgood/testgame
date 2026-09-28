class_name MeleeFx3D
extends RefCounted

const SLASH_OUTER := Color(1.0, 1.0, 1.0, 0.95)
const SLASH_INNER := Color(0.55, 0.75, 1.0, 0.75)
const BLOOD_COLORS := [Color(0.55, 0.05, 0.05), Color(0.75, 0.1, 0.08), Color(0.4, 0.02, 0.02)]
const SPARK_COLORS := [Color(1.0, 0.85, 0.3), Color(1.0, 0.95, 0.6), Color(1.0, 0.6, 0.15)]


static func slash(camera: Camera3D, side: int, inner := SLASH_INNER) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var segments := 18
	var half_arc := 1.25
	var r_mid := 0.5
	var r_out := 0.62
	var r_in := 0.4
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := lerpf(-half_arc, half_arc, t)
		var taper := sin(PI * t)
		var dir := Vector3(cos(angle), sin(angle), 0.0)
		vertices.append(dir * lerpf(r_mid, r_out, taper))
		colors.append(Color(SLASH_OUTER, SLASH_OUTER.a * taper))
		vertices.append(dir * lerpf(r_mid, r_in, taper))
		colors.append(Color(inner, inner.a * taper))
	for i in range(segments):
		var b := i * 2
		indices.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 3
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(0.0, -0.1, -1.35)
	mesh_instance.rotation = Vector3(-0.15, 0.0, 0.9 * side)
	mesh_instance.scale = Vector3.ONE * 0.7
	camera.add_child(mesh_instance)
	var tween := camera.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "rotation:z", -0.9 * side, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * 1.15, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_instance, "transparency", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh_instance.queue_free)


static func blood_burst(parent: Node, pos: Vector3, big := false) -> void:
	_burst(
		parent, pos, 16 if big else 9, BLOOD_COLORS,
		3.2 if big else 2.4, 0.07 if big else 0.05, 0.45 if big else 0.35
	)


static func sparks(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, 8, SPARK_COLORS, 3.0, 0.03, 0.28)


# 碎屑材质按颜色共享缓存（不再每片 new 一个材质；淡出走的是实例 scale/position，不动材质）
static var _burst_mat_cache := {}


static func _burst_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _burst_mat_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_burst_mat_cache[key] = material
	return _burst_mat_cache[key]


static func _burst(
	parent: Node, pos: Vector3, count: int, palette: Array,
	speed: float, size: float, life: float
) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	for i in count:
		var piece := MeshInstance3D.new()
		var shard := BoxMesh.new()
		shard.size = Vector3(size, size * 0.6, size * 0.5) * randf_range(0.7, 1.4)
		piece.mesh = shard
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		piece.material_override = _burst_material(palette[randi() % palette.size()])
		root.add_child(piece)
		piece.position = Vector3(
			randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)
		)
		var dir := Vector3(
			randf_range(-1.0, 1.0), randf_range(-0.2, 1.0), randf_range(-1.0, 1.0)
		).normalized()
		var tween := piece.create_tween()
		tween.set_parallel(true)
		tween.tween_property(
			piece, "position",
			piece.position + dir * speed * life * randf_range(0.7, 1.3),
			life
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "scale", Vector3.ONE * 0.05, life)
		tween.tween_property(
			piece, "rotation",
			Vector3(randf() * TAU, randf() * TAU, randf() * TAU), life
		)
		tween.chain().tween_callback(piece.queue_free)
	var cleanup := root.create_tween()
	cleanup.tween_interval(life + 0.05)
	cleanup.tween_callback(root.queue_free)
