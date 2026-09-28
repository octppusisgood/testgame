extends Node3D

# 出口地标结构：按 kind 程序化拼装，全部立于撤离圈（半径 3 米）之外

const CLEAR_RADIUS := 3.4


func build(kind: String) -> void:
	match kind:
		"airport":
			_build_airport()
		"train":
			_build_train()
		"bus":
			_build_bus()
		"dock":
			_build_dock()
		"highway":
			_build_highway()
		"path":
			_build_path()
		_:
			_build_road()


func _build_airport() -> void:
	var asphalt := Color(0.15, 0.15, 0.17)
	# 跑道 + 白色中线
	_add_visual_box(Vector3(0, 0.03, -4.5), Vector3(24.0, 0.06, 5.0), asphalt)
	for i in 7:
		_add_visual_box(
			Vector3(-10.5 + i * 3.5, 0.07, -4.5),
			Vector3(1.4, 0.02, 0.35),
			Color(0.9, 0.9, 0.88)
		)
	# 航站楼 + 玻璃色带
	var wall := Color(0.75, 0.77, 0.8)
	_add_static_box(Vector3(0, 1.8, 8.5), Vector3(10.0, 3.6, 5.0), wall)
	var glass := _add_visual_box(
		Vector3(0, 2.2, 5.94), Vector3(9.6, 1.0, 0.12), Color(0.45, 0.7, 0.85)
	)
	glass.material_override.metallic = 0.6
	glass.material_override.roughness = 0.15
	_add_visual_box(Vector3(0, 3.8, 8.5), Vector3(10.6, 0.4, 5.6), wall.darkened(0.3))
	# 控制塔
	_add_static_box(Vector3(-8.5, 3.5, 4.5), Vector3(1.0, 7.0, 1.0), Color(0.6, 0.62, 0.65))
	_add_static_box(Vector3(-8.5, 7.9, 4.5), Vector3(2.6, 1.8, 2.6), Color(0.5, 0.55, 0.6))
	_add_visual_box(Vector3(-8.5, 9.2, 4.5), Vector3(0.3, 0.9, 0.3), Color(0.3, 0.3, 0.32))


func _build_train() -> void:
	# 道床 + 两条铁轨 + 枕木
	_add_visual_box(Vector3(0, 0.03, -3.0), Vector3(22.0, 0.06, 2.6), Color(0.3, 0.28, 0.26))
	for z in [-3.7, -2.3]:
		_add_visual_box(Vector3(0, 0.09, z), Vector3(22.0, 0.08, 0.14), Color(0.55, 0.56, 0.6))
	for i in 11:
		_add_visual_box(
			Vector3(-10.0 + i * 2.0, 0.06, -3.0),
			Vector3(0.3, 0.05, 2.2),
			Color(0.35, 0.28, 0.2)
		)
	# 站台
	_add_static_box(Vector3(0, 0.45, 5.5), Vector3(14.0, 0.9, 3.6), Color(0.6, 0.6, 0.62))
	# 雨棚：立柱 + 顶板
	for x in [-5.0, 0.0, 5.0]:
		_add_static_box(Vector3(x, 1.75, 6.6), Vector3(0.25, 3.5, 0.25), Color(0.4, 0.42, 0.45))
	_add_visual_box(Vector3(0, 3.6, 5.8), Vector3(13.0, 0.25, 4.2), Color(0.5, 0.3, 0.25))


func _build_bus() -> void:
	var steel := Color(0.45, 0.5, 0.55)
	# 候车亭：两柱 + 顶 + 玻璃背板
	for x in [-2.0, 2.0]:
		_add_static_box(Vector3(x, 1.4, 6.0), Vector3(0.2, 2.8, 0.2), steel)
	_add_visual_box(Vector3(0, 2.9, 6.0), Vector3(5.2, 0.2, 2.4), Color(0.3, 0.5, 0.7))
	_add_visual_box(Vector3(0, 1.4, 7.1), Vector3(4.6, 2.6, 0.12), Color(0.5, 0.7, 0.85))
	# 长凳
	_add_static_box(Vector3(0, 0.5, 6.6), Vector3(3.6, 0.12, 0.5), Color(0.55, 0.4, 0.25))
	for x in [-1.5, 1.5]:
		_add_visual_box(Vector3(x, 0.22, 6.6), Vector3(0.15, 0.44, 0.45), steel)
	# 站牌
	_add_static_box(Vector3(4.0, 1.5, -3.8), Vector3(0.15, 3.0, 0.15), steel)
	_add_visual_box(Vector3(4.0, 2.7, -3.8), Vector3(0.9, 0.7, 0.08), Color(0.9, 0.85, 0.3))


func _build_dock() -> void:
	var wood := Color(0.5, 0.38, 0.24)
	# 伸向水边的木板栈桥
	_add_static_box(Vector3(0, 0.3, 8.5), Vector3(3.2, 0.3, 9.0), wood)
	for z in [5.0, 8.5, 12.0]:
		for x in [-1.4, 1.4]:
			_add_visual_box(Vector3(x, 0.075, z), Vector3(0.25, 0.45, 0.25), wood.darkened(0.25))
	# 吊机：立柱 + 横臂 + 吊索吊钩
	var crane := Color(0.85, 0.6, 0.15)
	_add_static_box(Vector3(-4.5, 3.0, -4.5), Vector3(0.7, 6.0, 0.7), crane)
	_add_static_box(Vector3(-4.5, 5.8, -2.2), Vector3(0.5, 0.5, 5.5), crane)
	_add_visual_box(Vector3(-4.5, 3.9, -0.3), Vector3(0.08, 3.4, 0.08), Color(0.2, 0.2, 0.2))
	_add_visual_box(Vector3(-4.5, 2.0, -0.3), Vector3(0.5, 0.4, 0.5), crane.darkened(0.3))


func _build_highway() -> void:
	# 路面 + 车道白线
	_add_visual_box(Vector3(0, 0.03, 0), Vector3(12.0, 0.06, 16.0), Color(0.14, 0.14, 0.15))
	for i in 4:
		_add_visual_box(
			Vector3(0, 0.07, -6.0 + i * 4.0),
			Vector3(0.25, 0.02, 1.6),
			Color(0.9, 0.9, 0.85)
		)
	# 龙门架收费站：两立柱 + 横梁 + 顶棚
	var steel := Color(0.55, 0.57, 0.6)
	for x in [-5.5, 5.5]:
		_add_static_box(Vector3(x, 2.75, -3.0), Vector3(0.5, 5.5, 0.5), steel)
	_add_visual_box(Vector3(0, 5.3, -3.0), Vector3(11.6, 0.5, 0.8), steel)
	_add_visual_box(Vector3(0, 5.9, -3.0), Vector3(12.4, 0.3, 2.2), Color(0.3, 0.45, 0.6))
	# 收费亭
	for x in [-3.4, 3.4]:
		_add_static_box(Vector3(x, 1.1, -3.0), Vector3(1.6, 2.2, 1.8), Color(0.7, 0.72, 0.75))


func _build_road() -> void:
	# 路面
	_add_visual_box(Vector3(0, 0.03, 0), Vector3(9.0, 0.06, 14.0), Color(0.16, 0.16, 0.17))
	# 路拱：两柱 + 横牌
	var steel := Color(0.5, 0.52, 0.55)
	for x in [-4.2, 4.2]:
		_add_static_box(Vector3(x, 2.5, -3.5), Vector3(0.4, 5.0, 0.4), steel)
	_add_visual_box(Vector3(0, 4.6, -3.5), Vector3(9.2, 1.4, 0.25), Color(0.2, 0.45, 0.3))


func _build_path() -> void:
	# 土路
	_add_visual_box(Vector3(0, 0.03, 0), Vector3(3.0, 0.05, 14.0), Color(0.45, 0.35, 0.22))
	# 木指示牌
	var wood := Color(0.5, 0.38, 0.24)
	_add_static_box(Vector3(3.4, 1.1, -3.4), Vector3(0.18, 2.2, 0.18), wood)
	_add_visual_box(Vector3(3.4, 2.0, -3.4), Vector3(1.4, 0.5, 0.1), wood.lightened(0.15))
	_add_visual_box(Vector3(3.4, 1.5, -3.4), Vector3(1.1, 0.4, 0.1), wood.lightened(0.1))


func _add_static_box(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _make_material(color)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	body.position = center
	add_child(body)


func _add_visual_box(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _make_material(color)
	mesh_instance.position = center
	add_child(mesh_instance)
	return mesh_instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
