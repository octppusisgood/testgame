extends Node3D
# 拆除玩法：准星对准建筑/塔楼/模型城市建筑墙体（5m 内）或街道杂物后按 Z 触发，
# 触发后本轮拆除自动进行直到完成（无需长按，也不要求准星保持对准）。
# 建筑/大楼改为「库存提取」：每次拆卸从 GameState.building_material_pool 取 +10 建材，
# 建筑总库存 10000，在门口掉建材堆实体（scenes3d/material_pile3d.tscn），库存取尽才真正坍塌移除；
# 街道杂物仍是按体积随机掉落（2~5）。
# 触发时长由 GameState.demolish_hold_seconds 决定（大楼更久，镐/斧/锤加速）；
# 动静很大：普通建筑 30m、大楼 120m 噪声，大楼拆除目击举报 severity 2 并广播消息。
# 据点建筑不可拆；拆完留 3~6 个低矮碎块作为废墟痕迹。
#
# 批次 34：三种建筑统一成同一套「可拆除结构」流程——
#   手建建筑 GameState.BUILDING_LAYOUT（墙体带 demolish_building meta）
#   塔楼 GameState.TOWERS（按命中点占地识别）
#   模型城市建筑（_place_model 的碰撞盒带 demolish_model meta + proto._model_structures 登记表）
# 瞄准 → 按 Z → 挖库存 → 取尽/血尽坍塌 全部走 _descriptor / _mine_structure / _collapse_structure，
# 三种建筑都同时支持：占领（各自的 BaseDoor）· Z 触发拆除挖建材 · 爆炸扣结构 HP。

const SCALE := 0.05
const RANGE := 5.0
# 射线长度多给 1m 余量，命中点仍按与玩家的水平距离限制在 RANGE 内
const AIM_RAY_EXTRA := 1.0  # 已废弃（拆除改相机-鼠标射线），保留占位兼容
const PROP_YIELD_MIN := 2
const PROP_YIELD_MAX := 5
const PROP_NOISE := 10.0
const AIM_DOT := 0.9
const DEBRIS_COLORS := [Color(0.5, 0.48, 0.45), Color(0.4, 0.36, 0.32), Color(0.62, 0.56, 0.5)]
const MaterialPileScene: PackedScene = preload("res://scenes3d/material_pile3d.tscn")

var _prompt := ""
# 当前瞄准的结构种类与下标（空串 = 没瞄准建筑）
var _target_kind := ""
var _target_ref := -1
var _target_prop: Node3D = null
var _hold := 0.0
# Z 触发后本轮自动进行（true 时不再要求准星保持对准）
var _running := false
# 已拆塔楼记录在 GameState.demolished_towers（像素中心坐标，与 demolished_buildings 同构），
# 这样小地图也能读到；节点本地不再各存一份，避免两份状态不同步。


func _ready() -> void:
	# 接入 HUD 的交互提示体系（hud3d 扫描 interactables 组的 prompt_text）
	add_to_group("interactables")
	# 供爆炸物查找并在建筑占地内结算结构伤害
	add_to_group("demolisher")


func prompt_text() -> String:
	return _prompt


# 提示优先级：准星正对着可拆的建筑/大楼/模型建筑（或拆除进行中）时拆除提示参与显示，
# 与门口的「E 交互」提示两行共存（拆除按 Z、交互按 E，互不顶掉）
func prompt_priority() -> bool:
	# 拆除进行中（含街道杂物）提示也保持最高优先级，进度不被 E 提示顶掉
	return _running or _target_kind != ""


func _process(delta: float) -> void:
	_prompt = ""
	var player = get_tree().get_first_node_in_group("player")
	if player == null or GameState.is_run_over():
		_reset_hold()
		_running = false
		return
	# 提示距离按自身位置算，跟随玩家保证拆除提示能显示
	global_position = player.global_position
	# 已触发：本轮自动拆完，不再跟随准星
	if _running:
		_tick_run(delta)
		return
	var s := _aim_structure(player)
	var prop: Node3D = null
	if s.is_empty():
		prop = _aim_prop(player)
	_target_kind = String(s.get("kind", ""))
	_target_ref = int(s.get("ref", -1))
	_target_prop = prop
	if not s.is_empty():
		_idle_prompt_structure(s)
	elif prop != null:
		_prompt = "按 Z 拆除"


# 待机提示：对准可拆建筑时提示按 Z 触发，只显示剩余库存（据点建筑静默跳过）
func _idle_prompt_structure(s: Dictionary) -> void:
	if _is_home_at(s["pos"], s["size"]):
		return
	_prompt = "按 Z 拆除（库存 %d）" % GameState.building_pool_remaining(s["pos"])


func _reset_hold() -> void:
	_hold = 0.0
	_target_kind = ""
	_target_ref = -1
	_target_prop = null


# Z 触发拆除：准星对准可拆目标时按 Z 开始，本轮自动拆完，无需长按
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_Z or _running:
		return
	# 交互菜单打开时按 Z 不触发拆除（拆除是独立按键的交互，互不抢占）
	if GameState.is_run_over() or GameState.any_panel_open() or GameState.interact_menu_open:
		return
	if _target_kind != "":
		var s := _descriptor(_target_kind, _target_ref)
		if s.is_empty() or _is_demolished(s) or _is_home_at(s["pos"], s["size"]):
			return
		_running = true
		_hold = 0.0
		get_viewport().set_input_as_handled()
	elif _target_prop != null and is_instance_valid(_target_prop):
		_running = true
		_hold = 0.0
		get_viewport().set_input_as_handled()


# 触发后本轮自动进行（不再要求准星保持对准），完成或目标失效后复位
func _tick_run(delta: float) -> void:
	if _target_kind != "":
		var s := _descriptor(_target_kind, _target_ref)
		if s.is_empty() or _is_demolished(s):
			_reset_hold()
			_running = false
			return
		var seconds := GameState.demolish_hold_seconds(s["size"], "", int(s["floors"]))
		_hold += delta
		_prompt = _hold_prompt(seconds) + "（库存 %d）" % GameState.building_pool_remaining(s["pos"])
		if _hold >= seconds:
			_reset_hold()
			_running = false
			_mine_structure(s)
		return
	if _target_prop == null or not is_instance_valid(_target_prop) or _target_prop.is_queued_for_deletion():
		_reset_hold()
		_running = false
		return
	var seconds := GameState.demolish_hold_seconds(Vector2(60, 60), "", 1)
	_hold += delta
	_prompt = _hold_prompt(seconds)
	if _hold >= seconds:
		var prop := _target_prop
		_reset_hold()
		_running = false
		_demolish_prop(prop)


# —— 结构描述：三种建筑归一成同一个字典 ——
# {kind: "building"|"tower"|"model", ref: 下标, pos: 中心像素坐标, size: 像素尺寸, floors: 层数}
func _descriptor(kind: String, ref: int) -> Dictionary:
	if kind == "building":
		if ref < 0 or ref >= GameState.BUILDING_LAYOUT.size():
			return {}
		var entry: Dictionary = GameState.BUILDING_LAYOUT[ref]
		return {
			"kind": kind, "ref": ref,
			"pos": entry["position"], "size": entry["size"], "floors": 1,
		}
	if kind == "tower":
		if ref < 0 or ref >= GameState.TOWERS.size():
			return {}
		var tower: Dictionary = GameState.TOWERS[ref]
		return {
			"kind": kind, "ref": ref,
			"pos": tower["position"], "size": tower["size"], "floors": _tower_floors(tower),
		}
	if kind == "model":
		var list := _model_list()
		if ref < 0 or ref >= list.size():
			return {}
		var item: Dictionary = list[ref]
		return {
			"kind": kind, "ref": ref,
			"pos": item["pos"], "size": item["size"], "floors": 1,
		}
	return {}


# 模型城市建筑登记表（proto3d._place_model 写入）；proto 没有该字段（如测试里的假 proto）返回空表
func _model_list() -> Array:
	var list = get_parent().get("_model_structures")
	if list is Array:
		return list
	return []


func _is_demolished(s: Dictionary) -> bool:
	if String(s.get("kind", "")) == "tower":
		return _tower_demolished(int(s["ref"]))
	return GameState.demolished_buildings.has(s["pos"])


# 塔楼是否已拆（按塔楼中心像素坐标查全局记录）
func _tower_demolished(index: int) -> bool:
	return GameState.demolished_towers.has(GameState.TOWERS[index]["position"])


# 进度提示，带最好拆除工具的名字（镐/消防斧/铁锤）
func _hold_prompt(seconds: float) -> String:
	var text := "拆除中… %d%%" % mini(99, int(_hold / seconds * 100.0))
	var tool_name := _tool_name()
	if tool_name != "":
		text += "（%s加速中）" % tool_name
	return text


func _tool_name() -> String:
	var id := GameState.best_demolish_tool()
	if id == "":
		return ""
	return String(GameState.LOOT_ITEMS.get(id, {}).get("name", id))


func _tower_floors(tower: Dictionary) -> int:
	return maxi(1, int(roundf(float(tower["height"]) / 10.0)))


# 准星命中可拆结构：手建建筑/模型建筑看碰撞体元数据，塔楼按命中点占地识别
func _aim_structure(player: Node3D) -> Dictionary:
	var hit := _aim_ray(player)
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider")
	if collider == null:
		return {}
	var s := {}
	if collider.has_meta("demolish_building"):
		s = _descriptor("building", int(collider.get_meta("demolish_building")))
	elif collider.has_meta("demolish_model"):
		s = _descriptor("model", int(collider.get_meta("demolish_model")))
	elif collider is StaticBody3D:
		# 塔楼墙体与模型建筑的 GLB 外壳都没打元数据时，退回按命中点是否落在占地内识别
		var hit_pos: Vector3 = hit["position"]
		var flat := Vector2(hit_pos.x, hit_pos.z)
		var ti := _tower_at(flat)
		if ti >= 0:
			s = _descriptor("tower", ti)
		else:
			var mi := _model_at(flat)
			if mi >= 0:
				s = _descriptor("model", mi)
	if s.is_empty() or _is_demolished(s):
		return {}
	return s


# 命中点是否落在某塔楼占地内（世界 xz 米制）
func _tower_at(flat: Vector2) -> int:
	for i in GameState.TOWERS.size():
		if _tower_demolished(i):
			continue
		var tower: Dictionary = GameState.TOWERS[i]
		if _footprint_contains(tower["position"], tower["size"], flat):
			return i
	return -1


# 命中点是否落在某栋未拆模型城市建筑占地内
func _model_at(flat: Vector2) -> int:
	var list := _model_list()
	for i in list.size():
		var item: Dictionary = list[i]
		if GameState.demolished_buildings.has(item["pos"]):
			continue
		if _footprint_contains(item["pos"], item["size"], flat):
			return i
	return -1


# 拆除射线：从相机穿过鼠标位置打射线，命中点即鼠标指着的建筑部位——
# 与交互（E）的鼠标悬停判定同一套语义，两者的判定位置完全重合；
# 仍保留离玩家 5m 的贴脸限制（hit 点距玩家超 RANGE 不算）
func _aim_ray(player: Node3D) -> Dictionary:
	var camera: Camera3D = player.get("camera")
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if dir.length() < 0.001:
		return {}
	var from := origin
	var to := origin + dir * 300.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	# 命中点离玩家超过 5m（准星指得远）不算贴脸拆除
	var hit_pos: Vector3 = hit["position"]
	var flat := Vector2(hit_pos.x - player.global_position.x, hit_pos.z - player.global_position.z)
	if flat.length() > RANGE:
		return {}
	return hit


# 街道杂物没有碰撞体，按距离 + 准星夹角挑最近的一个
func _aim_prop(player: Node3D) -> Node3D:
	var camera: Camera3D = player.camera
	if camera == null:
		return null
	var forward := -camera.global_transform.basis.z
	var best: Node3D = null
	var best_dist := RANGE
	for prop in get_parent()._street_props:
		if prop == null or not is_instance_valid(prop):
			continue
		var flat := Vector2(
			prop.global_position.x - player.global_position.x,
			prop.global_position.z - player.global_position.z
		)
		if flat.length() > RANGE or flat.length() >= best_dist:
			continue
		var to: Vector3 = prop.global_position + Vector3(0, 0.8, 0) - camera.global_position
		if forward.dot(to.normalized()) < AIM_DOT:
			continue
		best = prop
		best_dist = flat.length()
	return best


# 据点保护：据点位置（门口点，落在占地边缘）与该结构中心同处一栋楼时不可拆。
# 手建建筑/塔楼/模型建筑统一按「占地尺度」判定（与批次 27/33 的手建建筑判定同公式）。
func _is_home_at(pos_px: Vector2, size_px: Vector2) -> bool:
	if not GameState.has_home_base():
		return false
	var home_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	var center: Vector2 = pos_px * SCALE
	var size2d: Vector2 = size_px * SCALE
	var flat := Vector2(home_pos.x - center.x, home_pos.z - center.y)
	return flat.length() < maxf(size2d.x, size2d.y)


# 命中点是否落在某建筑的占地矩形内（世界 xz 米制）
func _footprint_contains(pos_px: Vector2, size_px: Vector2, flat: Vector2) -> bool:
	var center := pos_px * SCALE
	var half: Vector2 = size_px * SCALE / 2.0 + Vector2(0.4, 0.4)
	var offset := flat - center
	return absf(offset.x) <= half.x and absf(offset.y) <= half.y


# 爆炸物对外入口：命中点落在未拆建筑/塔楼/模型建筑占地内则扣结构耐久（与挖掘库存独立），
# 血尽即触发爆炸坍塌，掉落体积换算的小额建材（剩余库存作废）；据点建筑免疫
func damage_structure_at(pos: Vector3, dmg: int) -> void:
	if dmg <= 0:
		return
	var flat := Vector2(pos.x, pos.z)
	for index in GameState.BUILDING_LAYOUT.size():
		var s := _descriptor("building", index)
		if GameState.demolished_buildings.has(s["pos"]) or _is_home_at(s["pos"], s["size"]):
			continue
		if not _footprint_contains(s["pos"], s["size"], flat):
			continue
		if GameState.damage_building_hp(s["pos"], dmg):
			_collapse_structure(s, GameState.demolish_yield(s["size"], 1))
		return
	for index in GameState.TOWERS.size():
		if _tower_demolished(index):
			continue
		var s := _descriptor("tower", index)
		if _is_home_at(s["pos"], s["size"]):
			continue
		if not _footprint_contains(s["pos"], s["size"], flat):
			continue
		if GameState.damage_building_hp(s["pos"], dmg):
			_collapse_structure(s, GameState.demolish_yield(s["size"], int(s["floors"])))
		return
	for index in _model_list().size():
		var s := _descriptor("model", index)
		if s.is_empty():
			continue
		if GameState.demolished_buildings.has(s["pos"]) or _is_home_at(s["pos"], s["size"]):
			continue
		if not _footprint_contains(s["pos"], s["size"], flat):
			continue
		if GameState.damage_building_hp(s["pos"], dmg):
			_collapse_structure(s, GameState.demolish_yield(s["size"], 1))
		return


# 每次拆卸：从建筑库存提取一次建材并在门口掉堆；库存取尽才触发最终坍塌
func _mine_structure(s: Dictionary) -> void:
	if s.is_empty():
		return
	var pos_px: Vector2 = s["pos"]
	var size_px: Vector2 = s["size"]
	var got := GameState.mine_building_materials(pos_px)
	if got > 0:
		_drop_material_pile(_door_pos(pos_px, size_px), got)
	var remaining := GameState.building_pool_remaining(pos_px)
	if remaining <= 0:
		_collapse_structure(s)
	else:
		GameState.notify("拆除建材 +%d（库存 %d）" % [got, remaining])


# 手建建筑单次拆卸（测试与旧的直接调用入口）
func _mine_building(index: int) -> void:
	_mine_structure(_descriptor("building", index))


# 塔楼单次拆卸（key 用塔楼中心像素坐标，与手建建筑同一条库存路径）
func _mine_tower(index: int) -> void:
	_mine_structure(_descriptor("tower", index))


func _door_pos(pos_px: Vector2, size_px: Vector2) -> Vector3:
	var center := Vector3(pos_px.x * SCALE, 0.0, pos_px.y * SCALE)
	return center + Vector3(0.0, 0.05, size_px.y * SCALE / 2.0 + 1.5)


func _structure_noun(kind: String) -> String:
	if kind == "tower":
		return "大楼"
	return "建筑"


# 该结构坍塌时要一并移除的节点：手建建筑取部件表，塔楼按占地收集（含登记的门口交互点），
# 模型建筑取 _place_model 登记的 [模型, 碰撞盒, 门口交互点]
func _structure_nodes(s: Dictionary) -> Array:
	var kind := String(s["kind"])
	if kind == "building":
		return get_parent()._building_parts.get(int(s["ref"]), [])
	if kind == "tower":
		var nodes := _nodes_in_footprint(s["pos"], s["size"], Vector2(0.6, 0.6))
		var doors := _tower_doors()
		var ref := int(s["ref"])
		if ref >= 0 and ref < doors.size():
			var door = doors[ref]
			if door != null and is_instance_valid(door):
				nodes.append(door)
		return nodes
	var list := _model_list()
	var entry: Dictionary = list[int(s["ref"])]
	return entry.get("parts", [])


# 塔楼门口交互点登记表（proto3d._build_tower 写入）；假 proto 返回空表
func _tower_doors() -> Array:
	var doors = get_parent().get("_tower_doors")
	if doors is Array:
		return doors
	return []


# 占地范围内的全部节点（NPC/丧尸除外），塔楼没登记部件表时用来收走整栋
func _nodes_in_footprint(pos_px: Vector2, size_px: Vector2, pad: Vector2) -> Array:
	var out: Array = []
	var proto := get_parent()
	var center := Vector3(pos_px.x * SCALE, 0.0, pos_px.y * SCALE)
	var half: Vector2 = size_px * SCALE / 2.0 + pad
	for node in proto.get_children():
		if node == self or not node is Node3D:
			continue
		if node.is_in_group("npcs") or node.is_in_group("zombies"):
			continue
		var p: Vector3 = node.global_position
		var offset := Vector2(p.x - center.x, p.z - center.z)
		if absf(offset.x) <= half.x and absf(offset.y) <= half.y:
			out.append(node)
	return out


# 坍塌：移除建筑、留废墟。drop_pile > 0 表示被爆炸摧毁（掉体积换算的小额建材，
# 未挖出的库存作废）；挖掘取尽时传 0（建材已逐次挖走，不再掉堆）
func _collapse_structure(s: Dictionary, drop_pile := 0) -> void:
	var proto := get_parent()
	var kind := String(s["kind"])
	var ref := int(s["ref"])
	var pos_px: Vector2 = s["pos"]
	var size_px: Vector2 = s["size"]
	var floors := int(s["floors"])
	var center := Vector3(pos_px.x * SCALE, 0.0, pos_px.y * SCALE)
	var door_pos := _door_pos(pos_px, size_px)
	var nodes := _structure_nodes(s)
	# 先把建筑内的 NPC（店员/警察）移出到门口
	for node in nodes:
		if node != null and is_instance_valid(node) and node.is_in_group("npcs"):
			node.global_position = door_pos + Vector3(
				randf_range(-1.2, 1.2), 0.0, randf_range(0.4, 1.2)
			)
	var big := GameState.demolish_is_big(size_px, floors)
	_witness_report(2 if big else 1)
	if kind == "tower":
		GameState.demolished_towers.append(pos_px)
	else:
		GameState.demolished_buildings.append(pos_px)
	_remove_map_rect(pos_px, size_px)
	if kind == "model":
		_remove_model_rect(s)
	GameState.noise_at(center, GameState.demolish_noise_radius(size_px, floors))
	if big:
		_broadcast_collapse(center)
	var fx := _collapse_fx(kind)
	MeleeFx3D._burst(proto, center + Vector3(0, fx[0], 0), fx[1], DEBRIS_COLORS, fx[2], 0.3, fx[3])
	if kind == "building":
		proto._building_parts.erase(ref)
	for node in nodes:
		if node != null and is_instance_valid(node) and not node.is_in_group("npcs"):
			node.queue_free()
	_leave_rubble(center, maxf(size_px.x, size_px.y) * SCALE / 2.0)
	var noun := _structure_noun(kind)
	if drop_pile > 0:
		_drop_material_pile(door_pos, drop_pile)
		GameState.notify("%s被炸毁，掉落建材堆（%d 建材）——未挖出的库存已作废" % [noun, drop_pile])
	else:
		GameState.notify("%s建材已取尽，%s坍塌成废墟" % [noun, noun])


# 坍塌特效参数按结构种类：[爆心高度, 碎块数, 扩散半径, 碎块尺寸]
func _collapse_fx(kind: String) -> Array:
	if kind == "tower":
		return [3.0, 40, 9.0, 1.2]
	return [2.0, 26, 6.0, 0.8]


# 手建建筑坍塌（保留旧入口，语义同 _collapse_structure）
func _demolish_building(index: int, drop_pile := 0) -> void:
	_collapse_structure(_descriptor("building", index), drop_pile)


# 塔楼坍塌（保留旧入口）
func _demolish_tower(index: int, drop_pile := 0) -> void:
	_collapse_structure(_descriptor("tower", index), drop_pile)


func _demolish_prop(prop: Node3D) -> void:
	var proto := get_parent()
	_witness_report(1)
	var gain := randi_range(PROP_YIELD_MIN, PROP_YIELD_MAX)
	GameState.noise_at(prop.global_position, PROP_NOISE)
	MeleeFx3D._burst(proto, prop.global_position + Vector3(0, 0.8, 0), 10, DEBRIS_COLORS, 3.5, 0.12, 0.5)
	proto._street_props.erase(prop)
	var pile_pos := prop.global_position + Vector3(0.0, 0.05, 0.0)
	prop.queue_free()
	_drop_material_pile(pile_pos, gain)
	GameState.notify("杂物已拆除，掉落建材堆（%d 建材）" % gain)


# 拆除产物落在地上：在废墟位置生成建材堆实体
func _drop_material_pile(pos: Vector3, amount: int) -> void:
	var pile := MaterialPileScene.instantiate()
	get_parent().add_child(pile)
	pile.global_position = pos
	pile.setup(amount)


# 废墟痕迹：3~6 个带碰撞的低矮碎块（高度 <0.5m，不挡路）
func _leave_rubble(center: Vector3, radius: float) -> void:
	var proto := get_parent()
	for i in randi_range(3, 6):
		var size := Vector3(randf_range(0.5, 1.3), randf_range(0.2, 0.45), randf_range(0.5, 1.3))
		var body := StaticBody3D.new()
		var mesh_instance := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		mesh_instance.mesh = box_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DEBRIS_COLORS[randi() % DEBRIS_COLORS.size()].darkened(randf_range(0.0, 0.25))
		mesh_instance.material_override = mat
		body.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
		body.add_child(collision)
		proto.add_child(body)
		body.position = center + Vector3(
			randf_range(-radius * 0.6, radius * 0.6), size.y / 2.0, randf_range(-radius * 0.6, radius * 0.6)
		)
		body.rotation.y = randf() * TAU


# 大楼坍塌动静太大，人类阵营也会收到消息
func _broadcast_collapse(center: Vector3) -> void:
	GameState.post_message(
		"巨大坍塌声吸引了注意",
		Vector2(center.x / SCALE, center.z / SCALE),
		"horde",
		true
	)


func _remove_map_rect(pos_px: Vector2, size_px: Vector2) -> void:
	var target := Rect2(pos_px - size_px / 2.0, size_px)
	var rects: Array = GameState.map_building_rects
	for i in range(rects.size() - 1, -1, -1):
		if (rects[i] as Rect2).intersects(target):
			rects.remove_at(i)


# 模型城市建筑坍塌后同步撤掉 proto._model_rects 登记（堵路/随机落点判定用），小地图矩形由
# _remove_map_rect 处理
func _remove_model_rect(s: Dictionary) -> void:
	var rects = get_parent().get("_model_rects")
	if not (rects is Array):
		return
	var target: Rect2 = Rect2(s["pos"] - s["size"] / 2.0, s["size"])
	for i in range(rects.size() - 1, -1, -1):
		if (rects[i] as Rect2).intersects(target):
			rects.remove_at(i)


# 破坏公物：附近有 NPC 目击到玩家就报案（参考 station3d 的目击逻辑）；
# 拆大楼是重罪，severity 提为 2
func _witness_report(severity := 1) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or GameState.is_zombie():
		return
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.can_see_node(player):
			npc.show_alert()
			if npc.has_method("witness_crime"):
				npc.witness_crime()
			GameState.report_crime(severity, npc)
			return
