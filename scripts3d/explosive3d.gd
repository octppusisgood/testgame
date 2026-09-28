extends Node3D

const GRAVITY := 12.0
const SPEED := 26.0
# 手榴弹落地后引爆延迟（秒）
const LAND_FUSE := 2.0

var direction := Vector3.FORWARD
var damage := 90
var radius := 6.5
var rocket := false
var shooter = null
# 目标落点距离（米），0 = 不限；按 min(武器射程, 瞄准点距离) 传入，飞到点即爆
var target_distance := 0.0

var _life := 0.0
var _traveled := 0.0
var _landed := false
var _land_timer := 0.0
# 瞬爆模式：命中或飞到目标点立即爆炸，无落地引信（步枪枪榴弹）
var instant := false
# 爆炸闪光颜色与半球形态（枪榴弹为显眼红色半圆扩散）
var flash_color := Color(1.0, 0.65, 0.25, 0.45)
var dome := false


func setup(
	pos: Vector3, dir: Vector3, dmg: int, rad: float, is_rocket: bool, shooter_node,
	target_dist := 0.0, is_instant := false, flash_col := Color(0.0, 0.0, 0.0, 0.0),
	is_dome := false
) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	radius = rad
	rocket = is_rocket
	shooter = shooter_node
	target_distance = target_dist
	instant = is_instant
	if flash_col.a > 0.0:
		flash_color = flash_col
	dome = is_dome


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	if rocket:
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.14, 0.55)
		mesh.mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.3, 0.25)
	mesh.material_override = material
	add_child(mesh)
	if rocket:
		var flame := MeshInstance3D.new()
		var flame_box := BoxMesh.new()
		flame_box.size = Vector3(0.1, 0.1, 0.3)
		flame.mesh = flame_box
		var flame_material := StandardMaterial3D.new()
		flame_material.albedo_color = Color(1.0, 0.6, 0.2)
		flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.material_override = flame_material
		flame.position = Vector3(0, 0, 0.45)
		add_child(flame)


func _physics_process(delta: float) -> void:
	if _landed:
		_land_timer += delta
		if _land_timer >= LAND_FUSE:
			_explode()
		return
	_life += delta
	if not rocket:
		direction.y -= GRAVITY * delta / SPEED
		direction = direction.normalized()
	var from := global_position
	var to := from + direction * SPEED * delta
	var exclude: Array[RID] = []
	if shooter != null and is_instance_valid(shooter):
		exclude.append(shooter.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_traveled += from.distance_to(to)
		if target_distance > 0.0 and _traveled >= target_distance:
			if rocket or instant:
				_explode()
			else:
				_land(global_position)
			return
	else:
		if rocket or instant:
			global_position = hit["position"]
			_explode()
		else:
			_land(hit["position"])
		return
	if _life >= 6.0:
		_explode()


# 手榴弹落地：向下找地面停住，LAND_FUSE 秒后引爆
func _land(pos: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(
		pos + Vector3(0.0, 0.2, 0.0), pos + Vector3(0.0, -30.0, 0.0), 1
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	global_position = hit["position"] if not hit.is_empty() else pos
	_landed = true


func _explode() -> void:
	var pos := global_position
	var parent := get_parent()
	if parent != null:
		var flash := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		flash.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = flash_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash.material_override = material
		parent.add_child(flash)
		flash.global_position = pos
		flash.scale = Vector3(0.3, 0.3, 0.3)
		var tween := flash.create_tween()
		# 球体网格半径 1.0，放大到 radius 米，动画范围 = 实际伤害范围；半球形态压扁为半圆扩散
		var peak := Vector3(radius, radius * (0.55 if dome else 1.0), radius)
		tween.tween_property(flash, "scale", peak, 0.18)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.22)
		tween.tween_callback(flash.queue_free)
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if pos.distance_to(zombie.global_position) <= radius:
			zombie.take_damage(damage)
			DamagePopup.show_damage(parent, zombie.global_position + Vector3(0, 1.0, 0), damage, true)
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_queued_for_deletion():
			continue
		if pos.distance_to(npc.global_position) <= radius:
			npc.take_damage(damage, shooter)
			DamagePopup.show_damage(parent, npc.global_position + Vector3(0, 1.0, 0), damage, true)
	for camera in get_tree().get_nodes_in_group("surveillance_cameras"):
		if pos.distance_to(camera.global_position) <= radius:
			camera.take_damage(damage)
	for core in get_tree().get_nodes_in_group("anomaly_zone_core"):
		if pos.distance_to(core.global_position) <= radius:
			var zone = core.get_meta("zone", null)
			if zone != null and is_instance_valid(zone):
				zone.take_damage(damage)
	for target in get_tree().get_nodes_in_group("training_targets"):
		if pos.distance_to(target.global_position) <= radius:
			target.take_damage(damage)
			DamagePopup.show_damage(parent, target.global_position + Vector3(0, 2.2, 0), damage, true)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and shooter != player and pos.distance_to(player.global_position) <= radius:
		player.take_damage(damage)
	# 爆炸也能打坏建筑/塔楼：扣结构耐久，血尽即炸毁并只掉小额建材
	var demolisher = get_tree().get_first_node_in_group("demolisher")
	if demolisher != null:
		demolisher.damage_structure_at(pos, damage)
	GameState.noise_at(pos, 60.0)
	GameState.record_gunshot(pos, 60.0)
	GameState.police_alert(pos, "听到爆炸声")
	queue_free()
