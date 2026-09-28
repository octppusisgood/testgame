extends Node3D

# 军营：建筑外围一圈警戒线（立柱+红白警戒带），四角哨戒重机枪，
# 20 名全副武装士兵（步枪/防弹衣/防化服，无限弹药）+ 1 名特种兵（狙击）

const NPC_SCENE := preload("res://scenes3d/npc3d.tscn")
const MOUNTED_MG := preload("res://scripts3d/mounted_mg3d.gd")
const CORDON_MARGIN := 5.0
const SOLDIER_COUNT := 20

var _center := Vector3.ZERO
var _half := Vector2.ZERO
# 驻军编制与玩家闯入计时：玩家在警戒线内停留超过 3 秒，士兵转为敌对
var _soldiers: Array = []
var _trespass_timer := 0.0


func setup(center: Vector3, width: float, depth: float) -> void:
	_center = center
	_half = Vector2(width, depth) / 2.0 + Vector2(CORDON_MARGIN, CORDON_MARGIN)


func _ready() -> void:
	_build_cordon()
	_build_mgs()
	_spawn_garrison()


# 警戒线：四角+沿边立柱，柱间红白相间警戒带
func _build_cordon() -> void:
	var corners := [
		Vector2(-_half.x, -_half.y),
		Vector2(_half.x, -_half.y),
		Vector2(_half.x, _half.y),
		Vector2(-_half.x, _half.y),
	]
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color(0.2, 0.2, 0.22)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.1)
	red.emission_enabled = true
	red.emission = Color(0.8, 0.1, 0.08)
	red.emission_energy_multiplier = 0.6
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var length := a.distance_to(b)
		var posts := int(length / 4.0) + 1
		for i in posts + 1:
			var p: Vector2 = a.lerp(b, float(i) / posts)
			_add_post(_center + Vector3(p.x, 0.0, p.y), post_material)
		# 警戒带：每 1 米一段红白交替，挂在 y0.85
		var dir := (b - a).normalized()
		var segments := int(length)
		for i in segments:
			var mid: Vector2 = a + dir * (float(i) + 0.5)
			_add_tape(
				_center + Vector3(mid.x, 0.85, mid.y),
				atan2(dir.x, dir.y),
				red if i % 2 == 0 else white
			)


func _add_post(pos: Vector3, material: StandardMaterial3D) -> void:
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 1.1, 0.12)
	post.mesh = box
	post.material_override = material
	post.position = pos + Vector3(0, 0.55, 0)
	add_child(post)


func _add_tape(pos: Vector3, yaw: float, material: StandardMaterial3D) -> void:
	var tape := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.14, 1.0)
	tape.mesh = box
	tape.material_override = material
	tape.position = pos
	tape.rotation.y = yaw
	add_child(tape)


# 四角哨戒重机枪
func _build_mgs() -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var mg := StaticBody3D.new()
			mg.set_script(MOUNTED_MG)
			mg.position = _center + Vector3(sx * _half.x, 0.0, sz * _half.y)
			add_child(mg)


# 驻军：20 士兵在警戒线内巡逻，1 名特种兵守营门
func _spawn_garrison() -> void:
	var radius := maxf(_half.x, _half.y) + 6.0
	for i in SOLDIER_COUNT:
		var npc = NPC_SCENE.instantiate()
		npc.role = "soldier"
		add_child(npc)
		npc.global_position = _center + Vector3(
			randf_range(-_half.x * 0.7, _half.x * 0.7), 0.1, randf_range(-_half.y * 0.7, _half.y * 0.7)
		)
		_enlist(npc, radius)
	var elite = NPC_SCENE.instantiate()
	elite.role = "soldier"
	elite.elite = true
	add_child(elite)
	elite.global_position = _center + Vector3(0.0, 0.1, _half.y - CORDON_MARGIN - 2.0)
	elite.patrol_offset = Vector3(4.0, 0.0, 0.0)
	_enlist(elite, radius)


func _enlist(npc: Node3D, radius: float) -> void:
	npc.has_garrison = true
	npc.garrison_center = _center
	npc.garrison_radius = radius
	_soldiers.append(npc)


# 玩家在警戒线内停留超过 3 秒 → 驻军转为敌对；离开即解除（不会一直追击，leash 在 npc3d 里）
func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var inside := (
		absf(player.global_position.x - _center.x) <= _half.x
		and absf(player.global_position.z - _center.z) <= _half.y
	)
	if inside:
		_trespass_timer += delta
		if _trespass_timer > 3.0:
			for soldier in _soldiers:
				if is_instance_valid(soldier) and not soldier.is_queued_for_deletion():
					soldier.hostile = true
	elif _trespass_timer > 0.0:
		_trespass_timer = 0.0
		for soldier in _soldiers:
			if is_instance_valid(soldier) and not soldier.is_queued_for_deletion():
				soldier.hostile = false
