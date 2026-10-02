extends Node3D
# 异能量场：随机出现在城市中的异常区域。紫色辉光池 + 漂浮碎晶 + 中央紫色核心。
# 持续影响：场内市民被感染尸变（灾变后生效），玩家有感染风险并触发 HUD 警示；
# 范围内的物体外观异常化（紫变发光）。
# 巢穴机制：灾变后持续刷出丧尸，永不自行消失——只能打爆核心。
# 能量等级（1~3）越高：刷怪越快、场内同时存活的怪越多、精英 tier 加成越高；
# 打爆核心后能量逸散凝成 2~4 颗异能结晶（等级越高掉得越多）。

const TICK := 0.5
# 信号干扰区半径：能量场周边 25m 内信号强制 <10%（设计文档 5.5）
const JAM_RADIUS := 25.0
const ZONE_HP := 240
const SPAWN_INTERVAL := 10.0
const SPAWN_VIEW_DIST := 100.0

var radius := 7.0
var zone_id := -1
var energy := 1
var destroyed := false
# 休眠状态（肉鸽模式准备期）：不刷怪、盘体微光
var active := true
# 肉鸽 Boss 能量场：血量×50，刷出的怪留守场边且持续强化（每秒+5血）
var boss_field := false

var hp := ZONE_HP
var _spawn_timer := SPAWN_INTERVAL
var _tick := 0.0
var _pulse := 0.0
var _disc_material: StandardMaterial3D = null
var _core_mesh: MeshInstance3D = null
var _player_inside := false
# 肉鸽守关 Boss：核心被护盾锁定，击败 Boss 才能打爆核心（设计文档 4.1/4.4）
var _guard_boss: Node3D = null
var _core_locked := false
# Boss 能量场：Boss 头顶名牌 + 场内怪物强化节拍（+2/+3 交替 ≈ 每秒+5血）
var _boss_plate: Label3D = null
var _boss_name := ""
var _buff_flip := false


func _ready() -> void:
	add_to_group("anomaly_zones")
	# 能量等级体现在外观上：场更大、核心更亮更硬
	radius *= 1.0 + 0.15 * (energy - 1)
	hp = ZONE_HP + 80 * (energy - 1)
	if boss_field:
		hp *= 50
	_spawn_timer = randf_range(3.0, _spawn_interval())
	_build_visual()
	_build_core()
	_anomalize_surroundings()


func _spawn_interval() -> float:
	# 批次 261：夜间刷怪速度翻倍（间隔减半）
	var night_mult := 0.5 if GameState.is_night() else 1.0
	return SPAWN_INTERVAL * night_mult / float(energy)


func _alive_cap() -> int:
	return 2 + energy


func _build_visual() -> void:
	# 地面辉光池
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.9
	cyl.bottom_radius = radius * 0.9
	cyl.height = 0.04
	disc.mesh = cyl
	_disc_material = StandardMaterial3D.new()
	_disc_material.albedo_color = Color(0.5, 0.2, 0.8, 0.35)
	_disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_material.emission_enabled = true
	_disc_material.emission = Color(0.55, 0.25, 0.9)
	_disc_material.emission_energy_multiplier = 1.2
	_disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = _disc_material
	disc.position = Vector3(0, 0.06, 0)
	add_child(disc)
	# 漂浮的碎晶
	for i in 5:
		var shard := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = randf_range(0.08, 0.16)
		cone.height = randf_range(0.25, 0.5)
		shard.mesh = cone
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.65, 0.3, 0.95)
		material.emission_enabled = true
		material.emission = Color(0.6, 0.3, 0.95)
		material.emission_energy_multiplier = 1.5
		shard.material_override = material
		var angle := randf() * TAU
		var r := randf_range(radius * 0.2, radius * 0.7)
		shard.position = Vector3(cos(angle) * r, randf_range(0.15, 0.6), sin(angle) * r)
		shard.rotation = Vector3(randf() * 0.6, randf() * TAU, randf() * 0.6)
		add_child(shard)


# 可被攻击的核心：紫色光球 + 碰撞体（子弹/近战/爆炸的目标）
func _build_core() -> void:
	_core_mesh = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.5 + 0.1 * (energy - 1)
	orb.height = 1.0 + 0.2 * (energy - 1)
	_core_mesh.mesh = orb
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.35, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.65, 0.3, 1.0)
	material.emission_energy_multiplier = 1.8 + 0.5 * (energy - 1)
	_core_mesh.material_override = material
	_core_mesh.position = Vector3(0, 1.1, 0)
	add_child(_core_mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("anomaly_zone_core")
	body.set_meta("zone", self)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	shape.position = Vector3(0, 1.1, 0)
	body.add_child(shape)
	add_child(body)


# 物体异常化：范围内的拾取物/街道道具变成紫变发光的外观
func _anomalize_surroundings() -> void:
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.is_queued_for_deletion():
			continue
		if global_position.distance_to(pickup.global_position) <= radius:
			anomalize_node(pickup)
	for prop in get_tree().get_nodes_in_group("street_props"):
		if prop.is_queued_for_deletion():
			continue
		if global_position.distance_to(prop.global_position) <= radius:
			anomalize_node(prop)


static func anomalize_node(node: Node) -> void:
	if node == null or bool(node.get_meta("anomalized", false)):
		return
	node.set_meta("anomalized", true)
	_anomalize_recursive(node, 0)


static func _anomalize_recursive(node: Node, depth: int) -> void:
	if depth > 3:
		return
	if node is MeshInstance3D and node.mesh != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.25, 0.75)
		material.emission_enabled = true
		material.emission = Color(0.5, 0.25, 0.85)
		material.emission_energy_multiplier = 0.9
		node.material_override = material
	for child in node.get_children():
		_anomalize_recursive(child, depth + 1)


func _process(delta: float) -> void:
	_pulse += delta
	if _disc_material != null:
		if active:
			_disc_material.emission_energy_multiplier = 1.0 + sin(_pulse * 1.6) * 0.5
		else:
			_disc_material.emission_energy_multiplier = 0.25
	if _core_mesh != null:
		_core_mesh.position.y = 1.1 + sin(_pulse * 2.2) * 0.12
	# Boss 头顶名牌：名字 + 当前血量
	if _boss_plate != null and is_instance_valid(_boss_plate):
		if _boss_alive():
			_boss_plate.text = "%s  HP %d/%d" % [_boss_name, int(_guard_boss.hp), 1000]
		else:
			_boss_plate = null
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	# 信号干扰区：25m 内信号强制压到 10% 以下（设计文档 5.5），所有端都上报/清除
	if destroyed:
		GameState.clear_interference(get_instance_id())
	else:
		GameState.report_interference(get_instance_id(), global_position, JAM_RADIUS)
	_tick_effects()


func _tick_effects() -> void:
	if destroyed:
		return
	var player = get_tree().get_first_node_in_group("player")
	# HUD 警示标记：任一能量场覆盖玩家即置位
	var inside := false
	if player != null:
		inside = global_position.distance_to(player.global_position) <= radius
	_player_inside = inside
	if player != null:
		if _player_inside:
			GameState.in_anomaly_zone = true
		elif GameState.in_anomaly_zone:
			GameState.in_anomaly_zone = _any_zone_covers(player)
	# 感染与刷怪判定只在单机/主机端执行
	if Network.is_multiplayer() and not Network.is_server():
		return
	_tick_guard()
	# Boss 能量场持续强化：场内怪物血量每秒 +5（0.5s 一拍，+2/+3 交替）
	if boss_field and active and not destroyed:
		_buff_flip = not _buff_flip
		var gain := 3 if _buff_flip else 2
		for z in GameState.entities_in_group_in_radius(global_position, "zombies", radius * 2.0):
			if z.is_queued_for_deletion() or bool(z.get("_dying")) or bool(z.get("is_boss")):
				continue
			z.hp = int(z.get("hp")) + gain
	if GameState.zombies_active():
		_tick_spawner()


# 巢穴：持续刷丧尸，永不耗尽——只能打爆核心
func _tick_spawner() -> void:
	if destroyed or not active:
		return
	if not GameState.viewer_active:
		return
	if global_position.distance_to(GameState.viewer_position) > SPAWN_VIEW_DIST:
		return
	_spawn_timer -= TICK
	if _spawn_timer > 0.0:
		return
	var alive := GameState.entities_in_group_in_radius(
		global_position, "zombies", radius * 2.0
	).size()
	if alive >= _alive_cap():
		return
	_spawn_timer = _spawn_interval()
	_spawn_zone_zombie()


func _spawn_zone_zombie() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var zombie = preload("res://scenes3d/zombie3d.tscn").instantiate()
	zombie.set_meta("anomaly_touched", true)
	var angle := randf() * TAU
	parent.add_child(zombie)
	zombie.global_position = global_position + Vector3(cos(angle), 0.1, sin(angle)) * radius * 0.4
	if GameState.has_method("pick_zombie_tier"):
		var tier := mini(GameState.pick_zombie_tier() + energy - 1, 9)
		if GameState.rogue_mode:
			# 肉鸽：激活后每 2 分钟丧尸强化 1 级
			tier = mini(tier + int(GameState.rogue_active_elapsed / 120.0), 10)
		zombie.zombie_tier = tier
	if boss_field:
		# Boss 能量场：刷出的怪留守场边徘徊，不主动进攻玩家和营地（只反击进圈目标）
		zombie.guard_home = global_position
		zombie.hold_home = global_position
		zombie.hold_radius = radius + 4.0
	elif GameState.rogue_mode:
		# 普通能量场：先守场徘徊 15~25 秒，期满散入城市游荡/袭扰市民；
		# 游荡进营地 20m 才会被 proto3d 转为袭营（不再出生直奔营地）
		zombie.guard_home = global_position
		zombie.hold_home = global_position
		zombie.hold_radius = radius + 4.0
		zombie.hold_timer = randf_range(15.0, 25.0)


# 肉鸽守关：Boss 能量场激活后生成守关 Boss；Boss 存活期间核心无敌，死亡后解锁
func _tick_guard() -> void:
	if not GameState.rogue_mode or not boss_field or destroyed or not active:
		return
	if _guard_boss == null:
		_spawn_guard_boss()
		return
	if not _boss_alive():
		_guard_boss = null
		_core_locked = false
		if not destroyed:
			GameState.notify("守关 Boss 已击杀——能量场核心暴露！")


func _boss_alive() -> bool:
	return (
		_guard_boss != null
		and is_instance_valid(_guard_boss)
		and not _guard_boss.is_queued_for_deletion()
		and not bool(_guard_boss.get("_dying"))
	)


func _spawn_guard_boss() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var zombie = preload("res://scenes3d/zombie3d.tscn").instantiate()
	zombie.is_boss = true
	# 尸王(7)/尸皇(8)/尸神(9)：随能量点等级提升，同局不同能量点守关 Boss 不同
	zombie.zombie_tier = 7 + (energy - 1)
	zombie.set_meta("anomaly_touched", true)
	parent.add_child(zombie)
	# 守关 Boss 固定 1000 血（覆盖 tier 血量），模型上方显示名字和血量
	zombie.hp = 1000
	var angle := randf() * TAU
	zombie.global_position = global_position + Vector3(cos(angle), 0.1, sin(angle)) * (radius + 1.0)
	zombie.guard_zone = self
	zombie.guard_home = global_position
	var tier: Dictionary = GameState.zombie_tier_info(zombie.zombie_tier)
	_boss_name = String(tier.get("name", "Boss"))
	var plate := Label3D.new()
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.font_size = 64
	plate.outline_size = 12
	plate.modulate = Color(1.0, 0.45, 0.45)
	plate.outline_modulate = Color(0.2, 0.0, 0.0)
	plate.position = Vector3(0, 2.4 / maxf(zombie.scale.y, 0.2), 0)
	plate.text = "%s  HP 1000/1000" % _boss_name
	zombie.add_child(plate)
	_boss_plate = plate
	_guard_boss = zombie
	_core_locked = true
	GameState.notify("异常能量点出现守关 Boss，先击败它才能拆核心！")


# 核心被打：单机/主机端才结算（联机客户端等主机同步摧毁）
func take_damage(amount: int, _from: Node3D = null) -> void:
	if destroyed:
		return
	if _core_locked and _boss_alive():
		# 守关 Boss 护盾保护核心：伤害无效（Boss 生成时已有提示）
		return
	if Network.is_multiplayer() and not Network.is_server():
		return
	hp -= amount
	if _disc_material != null:
		_disc_material.emission_energy_multiplier = 2.6
	if _core_mesh != null:
		_core_mesh.scale = Vector3.ONE * clampf(float(hp) / float(ZONE_HP), 0.35, 1.0)
	if hp <= 0:
		_shatter()


# 核心摧毁：能量逸散凝成结晶，场上少一处巢穴
func _shatter() -> void:
	if destroyed:
		return
	destroyed = true
	GameState.clear_interference(get_instance_id())
	GameState.note_zone_destroyed(zone_id)
	GameState.notify("异能量场被摧毁！能量逸散凝成了结晶")
	GameState.post_message("观测到一处异常区域被强行击溃，能量逸散", Vector2.ZERO, "", true)
	var parent := get_parent()
	if parent != null:
		# 能量越高的场，打爆后逸散的结晶越多
		for i in randi_range(energy + 1, energy + 3):
			var crystal = preload("res://scenes3d/pickup3d.tscn").instantiate()
			crystal.kind = "anomaly"
			crystal.amount = 1
			crystal.item_name = "异能结晶"
			parent.add_child(crystal)
			var angle := randf() * TAU
			crystal.global_position = global_position + Vector3(
				cos(angle), 0.05, sin(angle)
			) * randf_range(0.5, 1.5)
	queue_free()


# 联机客户端：主机同步过来的摧毁/消散（不掉落不提示，实体由主机补发）
func apply_destroyed() -> void:
	if destroyed:
		return
	destroyed = true
	GameState.clear_interference(get_instance_id())
	queue_free()


func _any_zone_covers(player: Node3D) -> bool:
	for zone in get_tree().get_nodes_in_group("anomaly_zones"):
		if zone.is_queued_for_deletion():
			continue
		if zone.global_position.distance_to(player.global_position) <= float(zone.get("radius")):
			return true
	return false
