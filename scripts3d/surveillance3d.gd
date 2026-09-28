extends StaticBody3D

const RANGE := 22.0
const FOV_DEG := 70.0
const MAX_HP := 30

var destroyed := false
var hp := MAX_HP

var _camera: MeshInstance3D
var _cone: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group("surveillance_cameras")
	add_to_group("interactables")
	_build()


func _build() -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.16, 5.0, 0.16)
	pole.mesh = pole_mesh
	pole.position = Vector3(0, -2.5, 0)
	pole.material_override = _mat(Color(0.35, 0.37, 0.4))
	add_child(pole)

	_camera = MeshInstance3D.new()
	var head := BoxMesh.new()
	head.size = Vector3(0.5, 0.4, 0.8)
	_camera.mesh = head
	_camera.material_override = _mat(Color(0.2, 0.22, 0.26))
	add_child(_camera)
	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.12
	lens_mesh.bottom_radius = 0.12
	lens_mesh.height = 0.1
	lens.mesh = lens_mesh
	lens.rotation.x = PI / 2.0
	lens.position = Vector3(0, 0, -0.45)
	lens.material_override = _mat(Color(0.8, 0.2, 0.2))
	_camera.add_child(lens)

	_cone = MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = RANGE * 0.5
	disc_mesh.bottom_radius = RANGE * 0.5
	disc_mesh.height = 0.06
	_cone.mesh = disc_mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.95, 0.85, 0.3, 0.09)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone.material_override = _material
	_cone.position = Vector3(0, -4.94, -RANGE * 0.3)
	add_child(_cone)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.6, 1.0)
	collision.shape = shape
	add_child(collision)


func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func is_watching(pos: Vector3) -> bool:
	if destroyed or not is_inside_tree():
		return false
	var to := pos - global_position
	var dist := to.length()
	if dist > RANGE:
		return false
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < 0.1:
		return false
	var forward := -global_transform.basis.z
	if forward.dot(flat.normalized()) < cos(deg_to_rad(FOV_DEG / 2.0)):
		return false
	var from := global_position
	var target := pos + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, target, 1, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider = result.get("collider")
	return collider != null and collider.is_in_group("player")


func take_damage(amount: int) -> void:
	if destroyed:
		return
	hp -= amount
	if _material != null:
		_material.albedo_color = Color(0.95, 0.3, 0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(_material, "albedo_color", Color(0.95, 0.85, 0.3, 0.09), 0.3)
	if hp <= 0:
		_destroy()


func _destroy() -> void:
	destroyed = true
	remove_from_group("surveillance_cameras")
	if _camera != null:
		_camera.rotation.z = 1.2
	if _cone != null:
		_cone.visible = false
	GameState.notify("监控摄像头被破坏")


func prompt_text() -> String:
	if destroyed:
		return ""
	var player = get_tree().get_first_node_in_group("player")
	if player == null or global_position.distance_to(player.global_position) > 3.5:
		return ""
	return "监控摄像头 · 射击或近战破坏（被拍到犯罪直接报警）"
