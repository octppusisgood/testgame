extends StaticBody3D

# 训练场标靶：无限生命，永不击倒
var hp := 300

var _body: MeshInstance3D
var _head: MeshInstance3D


func _ready() -> void:
	add_to_group("training_targets")
	_body = _part(Vector3(1.0, 1.6, 0.3), Vector3(0, 0.9, 0), Color(0.75, 0.55, 0.35))
	_head = _part(Vector3(0.45, 0.45, 0.45), Vector3(0, 1.95, 0), Color(0.85, 0.65, 0.4))
	var base := _part(Vector3(1.4, 0.2, 0.6), Vector3(0, 0.1, 0), Color(0.35, 0.35, 0.38))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 2.2
	shape.shape = capsule
	shape.position = Vector3(0, 1.1, 0)
	add_child(shape)
	base.name = "Base"


func _part(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	return mesh


func take_damage(_amount: int) -> void:
	# 训练场标靶：无限生命，永不击倒（伤害数值由子弹端的伤害弹窗显示）
	pass


func _process(_delta: float) -> void:
	pass
