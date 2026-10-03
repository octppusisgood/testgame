extends Node3D
# 批次 270：T 键标记指挥——按 T 标记鼠标所指物体（建筑/载具/敌人/空地），
# 弹出指令子菜单，选中后派发给随从执行。标记环常驻显示直到清除/再标记。

const MARK_RANGE := 60.0
const ENEMY_SCAN := 6.0

var _ring: MeshInstance3D = null
var _menu_layer: CanvasLayer = null
var _menu_box: VBoxContainer = null


func _ready() -> void:
	_build_ring()


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.9)
	_ring.material_override = mat
	_ring.visible = false
	add_child(_ring)


func _draw_ring(pos: Vector3, radius: float) -> void:
	_ring.visible = true
	_ring.global_position = Vector3(pos.x, 0.08, pos.z)
	var im := _ring.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var segs := 32
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		im.surface_add_vertex(Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
		im.surface_add_vertex(Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
	im.surface_end()


func clear_mark() -> void:
	GameState.clear_marked_target()
	if _ring != null:
		_ring.visible = false
	_close_menu()


# —— T 键：标记鼠标所指物体 ——
func handle_t_key(player: Node3D) -> void:
	if GameState.is_run_over():
		return
	# 已有标记未下指令 → 再按 T 清除
	if not GameState.marked_target.is_empty():
		clear_mark()
		return
	var camera: Camera3D = player.get("camera")
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return
	var ground_pos: Vector3 = hit
	if ground_pos.distance_to(player.global_position) > MARK_RANGE:
		GameState.notify("标记距离过远（最远 %d 米）" % int(MARK_RANGE))
		return
	# 优先级：敌人 > 载具 > 建筑 > 空地
	var info := _mark_enemy(ground_pos)
	if info.is_empty():
		info = _mark_vehicle(ground_pos)
	if info.is_empty():
		info = _mark_building(ground_pos)
	if info.is_empty():
		info = {
			"type": "ground", "node": null, "pos": ground_pos,
			"label": "空地",
		}
	GameState.set_marked_target(info)
	_draw_ring(info["pos"], 2.0 if info["type"] != "building" else 6.0)
	GameState.notify("已标记 %s——选择指令（Esc 取消）" % String(info["label"]))
	_open_menu()


func _mark_enemy(pos: Vector3) -> Dictionary:
	var z = GameState.nearest_entity_in_group(pos, "zombies", ENEMY_SCAN)
	if z != null:
		return {"type": "enemy", "node": z, "pos": z.global_position, "label": "丧尸"}
	var npc = GameState.nearest_entity_in_group(pos, "npcs", ENEMY_SCAN)
	if npc != null and str(npc.get("role")) != "npc":
		return {"type": "enemy", "node": npc, "pos": npc.global_position, "label": "目标人物"}
	return {}


func _mark_vehicle(pos: Vector3) -> Dictionary:
	var best: Node3D = null
	var best_d := 8.0
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == null or not is_instance_valid(v) or v.is_queued_for_deletion():
			continue
		var d: float = (v.global_position as Vector3).distance_to(pos)
		if d < best_d:
			best_d = d
			best = v
	if best == null:
		return {}
	return {"type": "vehicle", "node": best, "pos": best.global_position, "label": "载具"}


func _mark_building(pos: Vector3) -> Dictionary:
	var flat := Vector2(pos.x, pos.z)
	for index in GameState.BUILDING_LAYOUT.size():
		var entry: Dictionary = GameState.BUILDING_LAYOUT[index]
		var half: Vector2 = entry["size"] * 0.05 * 0.5
		var center: Vector2 = entry["position"] * 0.05
		if Rect2(center - half, half * 2.0).has_point(flat):
			var name := "建筑"
			if GameState.BUILDINGS.has(String(entry.get("id", ""))):
				name = String(GameState.BUILDINGS[String(entry["id"])]["name"])
			return {
				"type": "building", "node": null,
				"pos": Vector3(center.x, 0.0, center.y),
				"label": name, "index": index,
			}
	return {}


# —— 指令子菜单 ——
func _open_menu() -> void:
	_close_menu()
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 22
	add_child(_menu_layer)
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.position = Vector2(250, 90)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var info: Dictionary = GameState.marked_target
	var title := Label.new()
	title.text = "目标：%s" % String(info.get("label", "?"))
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(title)
	for cmd in GameState.mark_commands_for(String(info["type"])):
		var btn := Button.new()
		btn.text = String(cmd["label"])
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size = Vector2(120, 24)
		btn.pressed.connect(_on_command.bind(String(cmd["id"])))
		box.add_child(btn)
	var cancel := Button.new()
	cancel.text = "取消（Esc）"
	cancel.add_theme_font_size_override("font_size", 10)
	cancel.pressed.connect(clear_mark)
	box.add_child(cancel)
	_menu_box = box


func _close_menu() -> void:
	if _menu_layer != null and is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
	_menu_layer = null


func menu_open() -> bool:
	return _menu_layer != null and is_instance_valid(_menu_layer) and _menu_layer.visible


# —— 指令派发：把标记转成我方NPC任务 ——
func _on_command(cmd: String) -> void:
	var info: Dictionary = GameState.marked_target
	if info.is_empty():
		_close_menu()
		return
	var manager = _find_manager()
	var pos: Vector3 = info["pos"]
	var assigned := 0
	if manager != null:
		var followers: Array = manager.call("follower_list")
		match cmd:
			"attack":
				# 进攻：全体优先攻击标记的敌人/载具/建筑（敌人=注入目标，物/建筑=前往并挠）
				if String(info["type"]) == "enemy" and info["node"] != null:
					for f in followers:
						if is_instance_valid(f):
							f.set("assault_target", pos)
							f.set("track_target", null)
							assigned += 1
					GameState.notify("%d 名我方NPC转向进攻目标！" % assigned)
				else:
					assigned = _send_all(manager, pos, "defend", "进攻标记点")
			"harass":
				assigned = _send_all(manager, pos, "patrol", "骚扰目标区域")
			"track":
				if info["node"] != null:
					for f in followers:
						if is_instance_valid(f):
							f.set("assault_target", pos)
							f.set("track_target", info["node"])
							assigned += 1
					GameState.notify("%d 名我方NPC开始跟踪目标" % assigned)
			"drive":
				if manager.has_method("open_vehicle_panel"):
					manager.call("open_vehicle_panel")
					GameState.notify("载具面板已打开——勾选成员后点「委派驾驶员」")
			"enter", "scavenge", "demolish":
				# 建筑：派我方NPC前往门口执行对应意图（搜刮/拆除本体需玩家 E/Z，成员负责护送/驻守）
				assigned = _send_all(manager, pos, "defend", "%s 标记建筑" % cmd)
			"defend":
				assigned = _send_all(manager, pos, "defend", "驻守标记点")
			"patrol":
				assigned = _send_all(manager, pos, "patrol", "巡逻标记区域")
			"attack_move":
				assigned = _send_all(manager, pos, "defend", "进攻标记点")
	if assigned > 0:
		clear_mark()
	else:
		GameState.notify("没有可指挥的我方NPC（先招募）")
		_close_menu()


func _send_all(manager, pos: Vector3, task: String, label: String) -> int:
	var list: Array = manager.call("follower_list")
	if list.is_empty():
		return 0
	manager.call("assign_follower_task", list, task, pos)
	GameState.notify("全体成员：%s" % label)
	return list.size()


func _find_manager() -> Node:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get_script() == load("res://scripts3d/worker3d.gd"):
			return node
	return null
