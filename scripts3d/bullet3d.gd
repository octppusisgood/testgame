extends Node3D

const SPEED := 260.0
const LIFETIME := 2.0

var direction := Vector3.FORWARD
var damage := 10
var shooter = null
var from_player := false
var penetrate := 0
# 龙息弹标记：命中丧尸时点燃（持续灼烧）
var burn := false
# 弹种（枪械改装）：normal/ap/hp/inc，命中时按目标护甲类型计算伤害系数
var ammo_type := "normal"
# 飞行上限距离（米），0 = 不限（只受寿命约束）；玩家子弹按 min(武器射程, 瞄准点距离) 截断
var max_distance := 0.0
# 伤害衰减表 [[距离, 倍率]...]，空 = 不衰减
var falloff: Array = []
# 允许爆头的最大距离（超过后只算普通伤害）
var headshot_range := 999.0
# 飞行速度倍率（技能弹可减速）
var speed_mult := 1.0
# 弹道拖影与弹头颜色
var trail_color := Color(1.0, 0.85, 0.35)
# 弹道与弹头加粗倍率（技能弹用）
var width_mult := 1.0
# 出生瞬间射手的移动速度（子弹继承人物动量，移动射击时跟着人物走）
var inherit_velocity := Vector3.ZERO

var _life := 0.0
var _traveled := 0.0
# 拖影分段起点：每飞过 TRAIL_STEP 米生成一段首尾相接的光痕
var _last_trail_pos := Vector3.ZERO
# 出生点所在建筑/墙体的豁免列表（进入建筑后对外开火用）
var _indoor_exclude: Array[RID] = []

const TRAIL_STEP := 2.0


func setup(
	pos: Vector3, dir: Vector3, dmg: int, shooter_node, is_player: bool,
	can_penetrate := 0, max_dist := 0.0, falloff_arr: Array = [], headshot_max := 999.0
) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	shooter = shooter_node
	from_player = is_player
	penetrate = can_penetrate
	max_distance = max_dist
	falloff = falloff_arr
	headshot_range = headshot_max
	_last_trail_pos = pos
	# 在建筑内开火：枪口若位于某个建筑/墙体碰撞体内部，该碰撞体对这颗子弹
	# 整体豁免——角色进屋后依旧可以对外开火，子弹不会在出生点撞墙消失
	var point_shape := SphereShape3D.new()
	point_shape.radius = 0.15
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = point_shape
	shape_query.transform = Transform3D(Basis(), pos)
	shape_query.collision_mask = 1
	shape_query.exclude = _exclude()
	for hit in get_world_3d().direct_space_state.intersect_shape(shape_query, 4):
		var col = hit.get("collider")
		if col is CollisionObject3D:
			_indoor_exclude.append(col.get_rid())
	var up := Vector3.UP
	if absf(direction.dot(Vector3.UP)) > 0.98:
		up = Vector3.RIGHT
	look_at(global_position + direction, up)


# 按已飞行距离查衰减倍率（表外取最后一档）
func _falloff_mult() -> float:
	if falloff.is_empty():
		return 1.0
	var mult := 1.0
	for entry in falloff:
		if _traveled <= float(entry[0]):
			return float(entry[1])
		mult = float(entry[1])
	return mult


# 当前伤害（含距离衰减）
func _dmg() -> int:
	return maxi(1, int(damage * _falloff_mult()))


func _ready() -> void:
	# 拉长的曳光弹：一道明亮的弹头光条，飞行中始终可见
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = (
		Vector3(0.06, 0.06, 2.4) if from_player else Vector3(0.07, 0.07, 1.6)
	) * Vector3(width_mult, width_mult, 1.0)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = trail_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = trail_color
	material.emission_energy_multiplier = 4.5
	mesh.material_override = material
	add_child(mesh)


func _physics_process(delta: float) -> void:
	var start := global_position
	var from := global_position
	var step := SPEED * speed_mult * delta
	if max_distance > 0.0 and _traveled + step > max_distance:
		step = maxf(max_distance - _traveled, 0.0)
	# 继承射手动量：水平方向附加人物移动速度，垂直弹道不受影响
	var to := from + direction * step + Vector3(inherit_velocity.x, 0.0, inherit_velocity.z) * delta
	var exclude := _exclude()
	var budget := maxi(penetrate, 1)
	while true:
		# 丧尸命中改手动扫掠：怪多时丧尸可能没有碰撞体（crowd 禁用碰撞），
		# 射线只管世界/建筑/玩家/NPC（层 1）
		var zombie_hit := _sweep_zombies(from, to)
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if zombie_hit.is_empty() and hit.is_empty():
			global_position = to
			break
		if (
			not zombie_hit.is_empty()
			and (hit.is_empty() or zombie_hit["distance"] < from.distance_to(hit["position"]))
		):
			global_position = zombie_hit["position"]
			var zombie: Node3D = zombie_hit["zombie"]
			if _impact_zombie(zombie, zombie_hit["position"]) or budget <= 1:
				queue_free()
				return
			budget -= 1
			from = global_position + direction * 0.15
			if from.distance_to(to) < 0.15:
				break
			continue
		global_position = hit["position"]
		var collider = hit.get("collider")
		if collider is CollisionObject3D:
			exclude.append(collider.get_rid())
		budget -= 1
		if _impact(hit) or budget <= 0:
			queue_free()
			return
		from = hit["position"] + direction * 0.15
		if from.distance_to(to) < 0.15:
			break
	_traveled += start.distance_to(global_position)
	_life += delta
	# 拖影：每飞过 TRAIL_STEP 米生成一段与上一段首尾相接的光痕，弹道不断线
	if global_position.distance_squared_to(_last_trail_pos) >= TRAIL_STEP * TRAIL_STEP:
		_spawn_trail(_last_trail_pos, global_position)
		_last_trail_pos = global_position
	# 射程耗尽判定留 1cm 容差：浮点累积误差会让 traveled 永远差一点到不了 max_distance
	if max_distance > 0.0 and _traveled >= max_distance - 0.01:
		queue_free()
		return
	elif _life >= LIFETIME:
		queue_free()


func _exclude() -> Array[RID]:
	var exclude: Array[RID] = []
	if shooter != null and is_instance_valid(shooter):
		exclude.append(shooter.get_rid())
	exclude.append_array(_indoor_exclude)
	return exclude


# 爆头判定：带 headshot_range 的武器（手枪）按"命中上 1/3 身体 + 距离内"判定，
# 其他武器沿用头部高度线（1.42×scale）
func _is_crit(hit_pos: Vector3, target: Node3D) -> bool:
	if _traveled > headshot_range:
		return false
	if headshot_range < 999.0:
		var scale_y := target.scale.y if absf(target.scale.y) > 0.01 else 1.0
		return hit_pos.y >= target.global_position.y + 1.78 * scale_y * 2.0 / 3.0
	return DamagePopup.is_headshot(hit_pos, target)


func _impact(hit: Dictionary) -> bool:
	_spark(hit["position"])
	var collider = hit.get("collider")
	if collider == null or not is_instance_valid(collider) or collider == shooter:
		return false
	if from_player:
		if collider.is_in_group("zombies"):
			var crit := _is_crit(hit["position"], collider)
			var head_mult := float(collider.get("headshot_mult")) if crit else 1.0
			# 弹种系数：按目标护甲类型计算（穿甲打装甲、空尖打无甲）
			var armored := false
			if collider.has_method("is_armored"):
				armored = collider.is_armored()
			var ammo_mult := GameState.ammo_damage_mult(ammo_type, armored)
			var final_damage := int(_dmg() * head_mult * ammo_mult)
			# 燃烧弹（弹种）或龙息弹（技能）都会点燃
			if (GameState.ammo_causes_burn(ammo_type) or burn) and collider.has_method("apply_bleed"):
				collider.apply_bleed(3.0, 6.0)
			var hp_before: int = collider.hp
			collider.take_damage(final_damage)
			DamagePopup.show_damage(collider.get_parent(), hit["position"], final_damage, crit)
			if hp_before > 0 and collider.hp <= 0 and shooter != null and is_instance_valid(shooter):
				if "kills" in shooter:
					shooter.kills += 1
					GameState.award_skill_point()
					GameState.on_player_kill()
			return penetrate <= 0
		elif collider.is_in_group("remote_players"):
			collider.take_damage(damage, shooter)
			return penetrate <= 0
		elif collider.is_in_group("surveillance_cameras"):
			collider.take_damage(damage)
			return penetrate <= 0
		elif collider.is_in_group("military_mg"):
			collider.take_damage(damage)
			return penetrate <= 0
		elif collider.is_in_group("vehicles"):
			# 玩家子弹也能打爆车辆（坦克子弹 shooter=自身车辆，已被 ==shooter 跳过）
			collider.take_damage(damage, shooter)
			return penetrate <= 0
		elif collider.is_in_group("anomaly_zone_core"):
			var zone = collider.get_meta("zone", null)
			if zone != null and is_instance_valid(zone):
				zone.take_damage(damage)
			return penetrate <= 0
		elif collider.is_in_group("training_targets"):
			var crit := _is_crit(hit["position"], collider)
			var final_damage := _dmg() * 2 if crit else _dmg()
			collider.take_damage(final_damage)
			DamagePopup.show_damage(collider.get_parent(), hit["position"], final_damage, crit)
			return penetrate <= 0
		elif collider.is_in_group("npcs"):
			var crit := _is_crit(hit["position"], collider)
			var final_damage := _dmg() * 2 if crit else _dmg()
			collider.take_damage(final_damage, shooter)
			DamagePopup.show_damage(collider.get_parent(), hit["position"], final_damage, crit)
			return penetrate <= 0
		if penetrate > 0:
			damage = maxi(int(damage * 0.65), 1)
			return false
		return true
	elif (
		collider.is_in_group("player")
		or collider.is_in_group("zombies")
		or collider.is_in_group("remote_players")
	):
		collider.take_damage(damage)
		return penetrate <= 0
	return true


# 手动丧尸扫掠：沿线段找最近的丧尸球体命中（不依赖物理体，crowd 也可命中）
func _sweep_zombies(from: Vector3, to: Vector3) -> Dictionary:
	var mid := (from + to) / 2.0
	var reach := from.distance_to(to) / 2.0 + 1.5
	var best := {}
	var best_t := INF
	for zombie in GameState.entities_in_group_in_radius(mid, "zombies", reach):
		if zombie.is_queued_for_deletion() or bool(zombie.get("_dying")) or zombie == shooter:
			continue
		var center: Vector3 = zombie.global_position + Vector3(0, 1.0, 0)
		var seg := to - from
		var seg_len := seg.length()
		var t := 0.0
		if seg_len > 0.001:
			t = clampf((center - from).dot(seg / seg_len) / seg_len, 0.0, 1.0)
		var closest: Vector3 = from + seg * t
		if closest.distance_to(center) > 0.65 * zombie.scale.x:
			continue
		var dist := from.distance_to(closest)
		if dist < best_t:
			best_t = dist
			best = {"zombie": zombie, "position": closest, "distance": dist}
	return best


# 丧尸命中结算（与 _impact 的丧尸分支一致）
func _impact_zombie(zombie: Node3D, pos: Vector3) -> bool:
	_spark(pos)
	if not from_player:
		zombie.take_damage(damage)
		return penetrate <= 0
	var crit := _is_crit(pos, zombie)
	var head_mult := float(zombie.headshot_mult) if crit else 1.0
	var final_damage := int(_dmg() * head_mult)
	if burn and zombie.has_method("apply_bleed"):
		zombie.apply_bleed(3.0, 6.0)
	var hp_before: int = zombie.hp
	zombie.take_damage(final_damage)
	DamagePopup.show_damage(zombie.get_parent(), pos, final_damage, crit)
	if hp_before > 0 and zombie.hp <= 0 and shooter != null and is_instance_valid(shooter):
		if "kills" in shooter:
			shooter.kills += 1
			GameState.award_skill_point()
			GameState.on_player_kill()
	if penetrate > 0:
		damage = maxi(int(damage * 0.65), 1)
		return false
	return true


# 生成一段从 from 到 to 的完整光痕，快速淡出
# 拖影/火花共享材质缓存：不再每段拖影 new 一个 StandardMaterial3D（兼容渲染器下
# 材质即渲染状态，共享后可省大量状态切换；逐段淡出改走 MeshInstance3D.transparency 实例属性）
static var _trail_mat_cache := {}
static var _spark_mat: StandardMaterial3D = null


static func _trail_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _trail_mat_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color, 0.7)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.6
		_trail_mat_cache[key] = material
	return _trail_mat_cache[key]


func _spawn_trail(from: Vector3, to: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.035 * width_mult, 0.035 * width_mult, length)
	mesh.mesh = box
	mesh.material_override = _trail_material(trail_color)
	parent.add_child(mesh)
	mesh.global_position = (from + to) / 2.0
	var up := Vector3.UP
	if absf((to - from).normalized().dot(Vector3.UP)) > 0.98:
		up = Vector3.RIGHT
	mesh.look_at(to, up)
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "transparency", 1.0, 0.12)
	tween.tween_callback(mesh.queue_free)


func _spark(pos: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.albedo_color = Color(1.0, 0.9, 0.55)
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.emission_enabled = true
		_spark_mat.emission = Color(1.0, 0.85, 0.5)
		_spark_mat.emission_energy_multiplier = 2.5
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.1, 0.1)
	mesh.mesh = box
	mesh.material_override = _spark_mat
	parent.add_child(mesh)
	mesh.global_position = pos
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale", Vector3(0.02, 0.02, 0.02), 0.06)
	tween.tween_callback(mesh.queue_free)
