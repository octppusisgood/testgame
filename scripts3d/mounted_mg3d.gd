extends StaticBody3D

# 军营哨戒重机枪：固定不可移动，无限弹药，数值取玩家重机枪（WEAPONS.lmg）。
# 任何进入警戒范围的人（含玩家）和丧尸都会触发 3 秒警告，警告结束开始射击。

const BULLET_SCENE := preload("res://scenes3d/bullet3d.tscn")
const SCAN_INTERVAL := 0.25
# 交战半径：覆盖警戒线外一片区域
const ENGAGE_RANGE := 24.0
const WARNING_SECONDS := 3.0
const MAX_HP := 800

var hp := MAX_HP

var _destroyed := false
var _scan := 0.0
var _cooldown := 0.0
var _target: Node3D = null
# 每个目标的警告截止时刻（msec）：进入范围先警告 3 秒再开火
var _warn_until := {}
var _player_warned := false

var _head: Node3D = null
var _laser: MeshInstance3D = null
var _laser_material: StandardMaterial3D = null
var _alert: Label3D = null


func _ready() -> void:
	# 丧尸可攻击它（沿用据点设施的索敌组），玩家子弹可打爆
	add_to_group("base_defense")
	add_to_group("military_mg")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# 碰撞箱罩住底座+枪头（玩家子弹平射高度 1.35m，矮了会从头顶尖过）
	box.size = Vector3(1.0, 1.7, 1.0)
	shape.shape = box
	shape.position.y = 0.85
	add_child(shape)
	# 三脚底座
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.9, 1.0, 0.9)
	base.mesh = base_box
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.22, 0.26, 0.2)
	base.material_override = base_material
	base.position.y = 0.5
	add_child(base)
	# 旋转枪头
	_head = Node3D.new()
	_head.position.y = 1.3
	add_child(_head)
	var gun := MeshInstance3D.new()
	var gun_box := BoxMesh.new()
	gun_box.size = Vector3(0.28, 0.28, 1.1)
	gun.mesh = gun_box
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_color = Color(0.15, 0.16, 0.18)
	gun.material_override = gun_material
	gun.position = Vector3(0, 0.0, -0.35)
	_head.add_child(gun)
	var eye := MeshInstance3D.new()
	var eye_box := BoxMesh.new()
	eye_box.size = Vector3(0.1, 0.06, 0.05)
	eye.mesh = eye_box
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.25, 0.15)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.2, 0.1)
	eye_material.emission_energy_multiplier = 2.5
	eye.material_override = eye_material
	eye.position = Vector3(0, 0.12, -0.55)
	_head.add_child(eye)
	# 警告激光：细红线，警告期间指向目标
	_laser = MeshInstance3D.new()
	var laser_box := BoxMesh.new()
	laser_box.size = Vector3(0.03, 0.03, 1.0)
	_laser.mesh = laser_box
	_laser_material = StandardMaterial3D.new()
	_laser_material.albedo_color = Color(1.0, 0.1, 0.05, 0.8)
	_laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_material.emission_enabled = true
	_laser_material.emission = Color(1.0, 0.1, 0.05)
	_laser_material.emission_energy_multiplier = 3.0
	_laser.material_override = _laser_material
	_laser.visible = false
	add_child(_laser)
	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 96
	_alert.modulate = Color(1.0, 0.25, 0.15)
	_alert.position = Vector3(0, 2.3, 0)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.visible = false
	add_child(_alert)


func _process(delta: float) -> void:
	if _destroyed or GameState.is_run_over():
		return
	_scan -= delta
	_cooldown -= delta
	if _scan <= 0.0:
		_scan = SCAN_INTERVAL
		_retarget()
	if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		_target = null
		_laser.visible = false
		_alert.visible = false
		return
	var target_pos: Vector3 = _target.global_position + Vector3(0, 1.0, 0)
	var to := target_pos - _head.global_position
	if Vector2(to.x, to.z).length() > ENGAGE_RANGE:
		_target = null
		_laser.visible = false
		_alert.visible = false
		return
	# 枪头指向目标
	_head.look_at(target_pos, Vector3.UP)
	var id := _target.get_instance_id()
	var now := Time.get_ticks_msec()
	if not _warn_until.has(id):
		_warn_until[id] = now + int(WARNING_SECONDS * 1000.0)
		if _target.is_in_group("player") and not _player_warned:
			_player_warned = true
			GameState.notify("警告：你已闯入军营警戒线！机枪 3 秒后开火")
	var warn_end: int = _warn_until[id]
	if now < warn_end:
		# 警告期：激光指向目标 + 头顶感叹号闪烁
		_point_laser(target_pos)
		_alert.visible = now % 500 < 250
		return
	_laser.visible = false
	_alert.visible = false
	if _cooldown <= 0.0:
		_fire(target_pos)


func _retarget() -> void:
	var best: Node3D = null
	var best_dist := ENGAGE_RANGE
	# 丧尸优先（数量最多），其次玩家与闯入的非士兵 NPC
	for zombie in GameState.entities_in_group_in_radius(global_position, "zombies", ENGAGE_RANGE):
		if zombie.is_queued_for_deletion() or bool(zombie.get("_dying")):
			continue
		var d := global_position.distance_squared_to(zombie.global_position)
		if d < best_dist * best_dist:
			best_dist = sqrt(d)
			best = zombie
	var player = get_tree().get_first_node_in_group("player")
	if player != null and not bool(player.get("_dead")):
		var d := global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best = player
	for npc in GameState.entities_in_group_in_radius(global_position, "npcs", ENGAGE_RANGE):
		if npc.is_queued_for_deletion() or bool(npc.get("_dying")):
			continue
		if npc.is_in_group("soldiers"):
			continue
		var d := global_position.distance_squared_to(npc.global_position)
		if d < best_dist * best_dist:
			best_dist = sqrt(d)
			best = npc
	_target = best


func _point_laser(target_pos: Vector3) -> void:
	var from := _head.global_position
	var dist := from.distance_to(target_pos)
	_laser.visible = true
	_laser.global_position = (from + target_pos) / 2.0
	_laser.scale = Vector3(1.0, 1.0, dist)
	_laser.look_at(target_pos, Vector3.UP)


func _fire(target_pos: Vector3) -> void:
	var weapon: Dictionary = GameState.WEAPONS["lmg"]
	_cooldown = float(weapon.get("cooldown", 0.25))
	var from := _head.global_position
	var dir := (target_pos - from).normalized()
	# 重机枪散布
	var spread := float(weapon.get("spread", 0.05))
	dir += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
	dir = dir.normalized()
	var bullet = BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.setup(
		from, dir, int(weapon.get("damage", 70)), self, false,
		int(weapon.get("penetrate", 3)), ENGAGE_RANGE + 4.0
	)


func take_damage(amount: int, _from: Node3D = null) -> void:
	if _destroyed:
		return
	hp -= amount
	if hp > 0:
		return
	_destroyed = true
	_target = null
	_laser.visible = false
	_alert.visible = false
	# 被打爆：枪头歪斜下垂，不再工作
	_head.rotation.z = 0.5
	_head.rotation.x = 0.4
	GameState.notify("一挺军营重机枪被打爆了")
