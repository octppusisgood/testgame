extends Node3D

const SCALE := 0.05
const ENGINEER_SCRIPT := preload("res://scripts3d/engineer3d.gd")
const MATERIAL_PILE_SCENE := preload("res://scenes3d/material_pile3d.tscn")
const REPAIR_COST := 10
const REPAIR_CHANNEL := 4.0
const DEMOLISH_YIELD := 10

var data: Dictionary = {}
var hp := 100
var destroyed := false

var _coverage_active := false
var _coverage_timer := 0.0
var _hit_timer := 0.0
var _blink_timer := 0.0
var _beacon_on := true
var _tower: Node3D
var _beacon: MeshInstance3D
var _tint_materials: Array = []
var _engineer = null
var _dispatch_timer := -1.0
var _repair_channel := -1.0


func _ready() -> void:
	add_to_group("base_stations")
	add_to_group("interactables")
	hp = GameState.STATION_HP
	_build_model()


func prompt_text() -> String:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or global_position.distance_to(player.global_position) >= 3.0:
		return ""
	var station_name: String = data.get("name", "基站")
	if _repair_channel >= 0.0:
		return "%s · 修复中 %d%%" % [
			station_name,
			int(clampf(_repair_channel / maxf(repair_channel_time(), 0.01), 0.0, 1.0) * 100.0),
		]
	if not destroyed:
		return "%s · 信号正常" % station_name
	if _engineer != null and is_instance_valid(_engineer):
		if _engineer.repairing:
			return "%s · 维修中 %d%%" % [station_name, int(_engineer.repair_progress * 100.0)]
		return "%s · 工程师正在赶来" % station_name
	return "%s · 已损坏（工程师约 %d 秒后到达）" % [station_name, int(ceil(maxf(_dispatch_timer, 0.0)))]


# —— 统一交互菜单协议（hud3d 按 E 出菜单，W/S 上下选择、E 确认）——

func interact_title() -> String:
	return String(data.get("name", "基站"))


func interact_options(player: Node3D) -> Array:
	if player == null or global_position.distance_to(player.global_position) >= 3.0:
		return []
	if _repair_channel >= 0.0:
		return []
	var repair_reason := ""
	if not destroyed:
		repair_reason = "信号塔未损坏"
	elif GameState.base_materials() < REPAIR_COST:
		repair_reason = "据点仓库建材不足"
	return [
		{
			"id": "repair",
			"label": "修复信号塔（建材 ×%d，引导 %d 秒）" % [REPAIR_COST, int(repair_channel_time())],
			"disabled": repair_reason != "",
			"reason": repair_reason,
		},
		{
			"id": "sabotage",
			"label": "破坏信号站",
			"disabled": destroyed,
			"reason": "已被破坏" if destroyed else "",
		},
		{"id": "demolish", "label": "拆除（掉建材堆 ×%d）" % DEMOLISH_YIELD},
	]


func interact_choose(id: String, _player: Node3D) -> void:
	match id:
		"repair":
			_start_repair()
		"sabotage":
			if not destroyed:
				_player_sabotage()
		"demolish":
			_demolish_station()


func repair_channel_time() -> float:
	return 0.0 if GameState.test_mode else REPAIR_CHANNEL


# 玩家修复：消耗据点仓库建材，引导读条期间离开 3m 打断（建材不退）；完成效果同工程师修复
func _start_repair() -> void:
	if not destroyed or _repair_channel >= 0.0:
		return
	if not GameState.spend_materials(REPAIR_COST):
		return
	if repair_channel_time() <= 0.0:
		complete_repair()
		return
	_repair_channel = 0.0
	GameState.notify("修复中：保持在信号塔旁，引导完成即修复")


func _update_repair_channel(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or global_position.distance_to(player.global_position) >= 3.0:
		_repair_channel = -1.0
		GameState.notify("修复被打断：离开了信号塔")
		return
	_repair_channel += delta
	if _repair_channel >= repair_channel_time():
		_repair_channel = -1.0
		complete_repair()


# 拆除：任意状态可用，彻底摧毁并掉建材堆；目击按重罪 severity 2 举报
func _demolish_station() -> void:
	var witness := _any_witness()
	if witness != null and not GameState.is_zombie():
		GameState.report_crime(2, witness)
	GameState.clear_signal(get_instance_id())
	GameState.noise_at(global_position, 25.0)
	var parent := get_parent()
	if parent != null:
		var pile: Node3D = MATERIAL_PILE_SCENE.instantiate()
		parent.add_child(pile)
		pile.global_position = global_position + Vector3(1.2, 0.05, 1.2)
		pile.setup(DEMOLISH_YIELD)
	GameState.post_message(
		"%s 被彻底拆除" % data.get("name", "基站"), _world_to_map(global_position), "station", true
	)
	GameState.notify("信号塔已拆除，废墟上留下建材堆（%d 建材）" % DEMOLISH_YIELD)
	queue_free()


func _process(delta: float) -> void:
	_update_beacon(delta)
	if _repair_channel >= 0.0:
		_update_repair_channel(delta)
	if destroyed:
		_update_dispatch(delta)
		return
	_coverage_timer -= delta
	if _coverage_timer <= 0.0:
		_coverage_timer = 0.2
		_update_coverage()
	_hit_timer -= delta
	if _hit_timer <= 0.0:
		_hit_timer = 1.0
		for zombie in get_tree().get_nodes_in_group("zombies"):
			if global_position.distance_to(zombie.global_position) < 3.0:
				take_damage(8)
				break


func _update_beacon(delta: float) -> void:
	_blink_timer += delta
	var on := not destroyed and fmod(_blink_timer, 1.2) < 0.75
	if on != _beacon_on:
		_beacon_on = on
		_beacon.visible = on


func _update_dispatch(delta: float) -> void:
	if _engineer != null:
		if is_instance_valid(_engineer):
			return
		_engineer = null
	if _dispatch_timer < 0.0:
		return
	_dispatch_timer -= delta
	if _dispatch_timer <= 0.0:
		_dispatch_timer = -1.0
		_dispatch_engineer()


func _dispatch_engineer() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var engineer = CharacterBody3D.new()
	engineer.set_script(ENGINEER_SCRIPT)
	engineer.station = self
	engineer.position = _edge_spawn_pos()
	parent.add_child(engineer)
	_engineer = engineer
	GameState.post_message(
		"维修工程师已出发前往 %s" % data.get("name", "基站"),
		_world_to_map(global_position),
		"station"
	)


# 出口系统已废除：工程师改为从地图边缘随机点出发进城
func _edge_spawn_pos() -> Vector3:
	var w := GameState.CITY_SIZE.x * SCALE
	var h := GameState.CITY_SIZE.y * SCALE
	var margin := 4.0
	match randi() % 4:
		0:
			return Vector3(randf_range(margin, w - margin), 0.0, margin)
		1:
			return Vector3(randf_range(margin, w - margin), 0.0, h - margin)
		2:
			return Vector3(margin, 0.0, randf_range(margin, h - margin))
		_:
			return Vector3(w - margin, 0.0, randf_range(margin, h - margin))
	return global_position + Vector3(120.0, 0.0, 0.0)


func engineer_died() -> void:
	_engineer = null
	_dispatch_timer = randf_range(GameState.ENGINEER_DELAY_MIN, GameState.ENGINEER_DELAY_MAX)
	GameState.post_message(
		"前往 %s 的维修工程师失联，正在重新派遣" % data.get("name", "基站"),
		_world_to_map(global_position),
		"station"
	)


func complete_repair() -> void:
	if not destroyed:
		return
	destroyed = false
	hp = GameState.STATION_HP
	_engineer = null
	_repair_channel = -1.0
	_tower.rotation = Vector3.ZERO
	for entry in _tint_materials:
		entry[0].albedo_color = entry[1]
	GameState.post_message(
		"%s 已修复，信号恢复" % data.get("name", "基站"),
		_world_to_map(global_position),
		"station"
	)


func _world_to_map(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.z) / SCALE


func _update_coverage() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var strength := 0.0
	if player != null and not destroyed:
		var dist := global_position.distance_to(player.global_position)
		strength = clampf(1.0 - dist / (GameState.STATION_COVERAGE * 0.05), 0.0, 1.0)
	# 信号塔靠市电运行：发电站停运后信号衰减到三成（备用电池），修复发电厂恢复
	if not GameState.grid_online():
		strength *= 0.3
	GameState.report_signal(get_instance_id(), strength)
	_coverage_active = strength > 0.0


func take_damage(amount: int) -> void:
	if destroyed:
		return
	hp -= amount
	if hp <= 0:
		_destroy()


func _player_sabotage() -> void:
	var witness := _any_witness()
	if witness != null and not GameState.is_zombie():
		GameState.report_crime(1, witness)
	_destroy()


func _any_witness() -> Node3D:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.can_see_node(player):
			npc.show_alert()
			if npc.has_method("witness_crime"):
				npc.witness_crime()
			return npc
	return null


func _destroy() -> void:
	destroyed = true
	hp = 0
	_coverage_active = false
	for entry in _tint_materials:
		var base: Color = entry[1]
		entry[0].albedo_color = Color(base.r * 0.3, base.g * 0.3, base.b * 0.3)
	_tower.rotation = Vector3(-0.05, 0.0, 0.1)
	_dispatch_timer = randf_range(GameState.ENGINEER_DELAY_MIN, GameState.ENGINEER_DELAY_MAX)
	GameState.clear_signal(get_instance_id())
	GameState.post_message("%s 被破坏，附近信号中断" % data.get("name", "基站"), Vector2.ZERO, "station")


# —— 基站塔模型（共享静态构建器）——
# 地图基站与玩家建造的信号塔共用同一套外观（批次 145）。
# 返回 {root, tower, beacon}；几何用独立材质实例，调用方可安全做染色/闪烁。

static func build_station_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "StationVisual"
	# 混凝土地基
	_sbox(root, Vector3(4.2, 0.35, 3.4), Vector3(0, 0.175, 0), Color(0.5, 0.5, 0.52))
	# 设备机柜与柜门
	_sbox(root, Vector3(1.1, 2.0, 0.9), Vector3(1.55, 1.35, 0), Color(0.3, 0.42, 0.38))
	_sbox(root, Vector3(0.04, 1.5, 0.6), Vector3(2.12, 1.25, 0), Color(0.24, 0.34, 0.3))
	_sbox(root, Vector3(0.5, 0.35, 0.7), Vector3(1.55, 2.55, 0), Color(0.26, 0.36, 0.32))

	var tower := Node3D.new()
	tower.name = "Tower"
	root.add_child(tower)
	var metal := Color(0.62, 0.64, 0.68)
	var levels := [0.35, 2.35, 4.35, 6.35, 8.0]
	for i in 4:
		var sx := 1.0 if i % 2 == 0 else -1.0
		var sz := 1.0 if i < 2 else -1.0
		for s in levels.size() - 1:
			_sbeam(
				tower,
				_sleg_pos(sx, sz, levels[s]), _sleg_pos(sx, sz, levels[s + 1]),
				0.06, metal
			)
	for s in range(1, levels.size()):
		var y: float = levels[s]
		var corners := [
			_sleg_pos(1.0, 1.0, y), _sleg_pos(-1.0, 1.0, y),
			_sleg_pos(-1.0, -1.0, y), _sleg_pos(1.0, -1.0, y),
		]
		for i in 4:
			_sbeam(tower, corners[i], corners[(i + 1) % 4], 0.035, metal)
	for s in levels.size() - 1:
		var low := [
			_sleg_pos(1.0, 1.0, levels[s]), _sleg_pos(-1.0, 1.0, levels[s]),
			_sleg_pos(-1.0, -1.0, levels[s]), _sleg_pos(1.0, -1.0, levels[s]),
		]
		var high := [
			_sleg_pos(1.0, 1.0, levels[s + 1]), _sleg_pos(-1.0, 1.0, levels[s + 1]),
			_sleg_pos(-1.0, -1.0, levels[s + 1]), _sleg_pos(1.0, -1.0, levels[s + 1]),
		]
		for i in 4:
			_sbeam(tower, low[i], high[(i + 1) % 4], 0.028, metal)
	# 顶部平台
	_sbox(tower, Vector3(1.3, 0.1, 1.3), Vector3(0, 8.05, 0), Color(0.45, 0.46, 0.5))
	# 主桅杆
	_sbeam(tower, Vector3(0, 8.1, 0), Vector3(0, 9.9, 0), 0.06, Color(0.7, 0.7, 0.72))
	# 三面定向天线板
	for i in 3:
		var angle := TAU * float(i) / 3.0 + PI / 2.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var panel := _sbox(
			tower, Vector3(0.12, 1.2, 0.55),
			Vector3(dir.x * 0.5, 8.8, dir.z * 0.5), Color(0.85, 0.86, 0.88)
		)
		panel.rotation.y = -angle
		_sbeam(tower, Vector3(0, 8.6, 0), Vector3(dir.x * 0.45, 8.6, dir.z * 0.45), 0.03, metal)
	# 微波锅
	var dish := MeshInstance3D.new()
	var dish_mesh := SphereMesh.new()
	dish_mesh.radius = 0.42
	dish_mesh.height = 0.84
	dish.mesh = dish_mesh
	dish.material_override = _smat(Color(0.8, 0.8, 0.78))
	dish.scale = Vector3(1.0, 1.0, 0.32)
	dish.position = Vector3(0.55, 7.3, 0)
	dish.rotation.y = -PI / 2.0
	tower.add_child(dish)
	_sbeam(tower, Vector3(0.1, 7.3, 0), Vector3(0.5, 7.3, 0), 0.03, metal)
	# 顶部红色警示灯
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.11
	beacon_mesh.height = 0.22
	beacon.mesh = beacon_mesh
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(1.0, 0.15, 0.12)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.1, 0.08)
	beacon_mat.emission_energy_multiplier = 3.0
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = beacon_mat
	beacon.position = Vector3(0, 10.0, 0)
	tower.add_child(beacon)
	return root


static func _sleg_pos(sx: float, sz: float, y: float) -> Vector3:
	var t := clampf((y - 0.35) / 7.65, 0.0, 1.0)
	var r := lerpf(0.85, 0.26, t)
	return Vector3(sx * r, y, sz * r)


static func _smat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


static func _sbox(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _smat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


static func _sbeam(
	parent: Node3D, from: Vector3, to: Vector3, thickness: float, color: Color
) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = thickness
	cylinder.bottom_radius = thickness
	cylinder.height = maxf(from.distance_to(to), 0.02)
	mesh.mesh = cylinder
	mesh.material_override = _smat(color)
	mesh.position = (from + to) / 2.0
	var dir := to - from
	if dir.length() > 0.001:
		mesh.quaternion = Quaternion(Vector3.UP, dir.normalized())
	parent.add_child(mesh)
	return mesh


# —— 基站实例的模型装配：用共享构建器，并收集材质供损坏染色/闪烁 ——

func _build_model() -> void:
	var visual := build_station_visual()
	add_child(visual)
	_tower = visual.get_node("Tower")
	_beacon = _tower.get_node("Beacon")
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Beacon":
			continue
		var mat = mi.material_override
		if mat is StandardMaterial3D:
			_tint_materials.append([mat, (mat as StandardMaterial3D).albedo_color])
