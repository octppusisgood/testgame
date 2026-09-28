extends StaticBody3D

const REACH := 3.2

var _opened := false


func _ready() -> void:
	add_to_group("interactables")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 3.4, 0.3)
	mesh.mesh = box
	mesh.position = Vector3(0, 1.7, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.45, 0.5)
	material.metallic = 0.6
	mesh.material_override = material
	add_child(mesh)
	var wheel := MeshInstance3D.new()
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.45
	wheel_mesh.bottom_radius = 0.45
	wheel_mesh.height = 0.12
	wheel.mesh = wheel_mesh
	wheel.rotation.x = PI / 2.0
	wheel.position = Vector3(0, 1.7, 0.24)
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.85, 0.7, 0.25)
	wheel_material.metallic = 0.7
	wheel.material_override = wheel_material
	add_child(wheel)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.9, 3.4, 0.5)
	collision.shape = shape
	collision.position = Vector3(0, 1.7, 0)
	add_child(collision)


func _process(_delta: float) -> void:
	if _opened:
		return
	if Input.is_action_just_pressed("interact") and _near_player():
		if GameState.vault_key:
			_open()
		else:
			GameState.notify("金库门锁着——需要警卫身上的金库钥匙")


func prompt_text() -> String:
	if _opened or not _near_player():
		return ""
	if GameState.vault_key:
		return "E 打开金库门"
	return "金库门锁着 · 需要武装警卫的金库钥匙"


func _near_player() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	return player != null and global_position.distance_to(player.global_position) <= REACH


func _open() -> void:
	_opened = true
	remove_from_group("interactables")
	GameState.notify("金库门开了！里面全是现金")
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 2.9, 0.5).set_trans(
		Tween.TRANS_CUBIC
	)
	tween.tween_callback(queue_free)
