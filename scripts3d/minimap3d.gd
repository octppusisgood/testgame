class_name MapView3D
extends Control

const LOCAL_RANGE := 2400.0
const SCALE := 0.05

const GROUND_COLOR := Color(0.07, 0.08, 0.085, 1.0)
const ROAD_COLOR := Color(0.27, 0.28, 0.31, 1.0)
const BLOCK_FILL := Color(0.78, 0.77, 0.72, 1.0)
const BLOCK_LINE := Color(0.12, 0.12, 0.14, 0.9)
const BOUNDARY_COLOR := Color(0.45, 0.5, 0.55, 0.6)

var full := false
var force_visible := false
# 无信号（肉鸽）：小地图降级——地形与自身位置可见，但不画敌我实时情报点
var _signal_blind := false
# 大地图「信号区」按钮开关：连通网络合并轮廓，孤立塔单独圈
var _show_signal := false
var _signal_btn: Button = null

var _update_timer := 0.0
var _rotating := false
var _origin := Vector2.ZERO
var _scale := 1.0
var _center := Vector2.ZERO
var _forward := Vector2.UP
var _right := Vector2.RIGHT
var _player_map := Vector2.ZERO
var _circle := false
var _radius := 0.0
var _circle_poly := PackedVector2Array()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.map_marker_changed.connect(queue_redraw)
	if full:
		set_anchors_preset(Control.PRESET_CENTER_TOP)
		offset_left = -280
		offset_top = 6
		offset_right = 280
		offset_bottom = 306
		visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)
		# 按钮挂在 HUD 层（地图框正下方）：地图自身恢复裁剪，热力图不会溢出框外
		var sig_btn := Button.new()
		sig_btn.text = "信号区"
		sig_btn.custom_minimum_size = Vector2(72, 24)
		sig_btn.toggle_mode = true
		sig_btn.visible = false
		sig_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
		sig_btn.offset_left = -36
		sig_btn.offset_right = 36
		sig_btn.offset_top = 310
		sig_btn.offset_bottom = 334
		sig_btn.toggled.connect(func(on: bool) -> void:
			_show_signal = on
			queue_redraw()
		)
		var host := get_parent()
		if host == null:
			host = self
		host.add_child(sig_btn)
		_signal_btn = sig_btn
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -160
		offset_top = 8
		offset_right = -8
		offset_bottom = 160
		modulate = Color(1, 1, 1, 0.85)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var world: Vector2 = event.position / _scale + _origin
		if event.button_index == MOUSE_BUTTON_LEFT:
			if (
				world.x >= 0.0 and world.x <= GameState.CITY_SIZE.x
				and world.y >= 0.0 and world.y <= GameState.CITY_SIZE.y
			):
				GameState.set_map_marker(world)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			GameState.clear_map_marker()


func _process(delta: float) -> void:
	if full:
		# 信号区按钮挂在 HUD 层，显隐跟随大地图
		if _signal_btn != null:
			_signal_btn.visible = visible
		if visible:
			queue_redraw()
		return
	if GameState.map_open:
		visible = false
		return
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("is_scoped") and player.is_scoped():
		# 开镜瞄准时暂时隐藏小地图，避免瞄准圈与其重叠
		visible = false
		return
	# 无信号区（肉鸽）：不再整块隐藏小地图，改为降级——
	# 地形/建筑/自身位置照常，敌我实时情报点不画（设计 5.5：信号 = 情报线）
	_signal_blind = GameState.rogue_mode and GameState.signal_strength <= 0.01
	visible = force_visible or _in_scene()
	if not visible:
		return
	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = 0.05
		queue_redraw()


func _in_scene() -> bool:
	var current := get_tree().current_scene
	if current == null:
		return false
	return current.scene_file_path == "res://scenes3d/proto3d.tscn"


func _to2(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.z) / SCALE


func _project(p: Vector2) -> Vector2:
	if _rotating:
		var d := p - _player_map
		return _center + Vector2(d.dot(_right), -d.dot(_forward)) * _scale
	return (p - _origin) * _scale


func _project3(pos: Vector3) -> Vector2:
	return _project(_to2(pos))


func _rect_points(pos: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		_project(pos),
		_project(pos + Vector2(sz.x, 0.0)),
		_project(pos + sz),
		_project(pos + Vector2(0.0, sz.y)),
	])


func _in_circle(p: Vector2, margin := 6.0) -> bool:
	if not _circle:
		return true
	return p.distance_to(_center) <= _radius - margin


func _draw_rect_map(pos: Vector2, sz: Vector2, color: Color) -> void:
	var points := _rect_points(pos, sz)
	if not _circle:
		draw_colored_polygon(points, color)
		return
	for piece in Geometry2D.intersect_polygons(points, _circle_poly):
		if piece.size() >= 3:
			draw_colored_polygon(piece, color)


func _draw_rect_outline_map(pos: Vector2, sz: Vector2, color: Color, width: float) -> void:
	var points := _rect_points(pos, sz)
	if points.size() < 4:
		return
	points.append(points[0])
	if not _circle:
		draw_polyline(points, color, width)
		return
	for piece in Geometry2D.intersect_polyline_with_polygon(points, _circle_poly):
		if piece.size() >= 2:
			draw_polyline(piece, color, width)


func _draw() -> void:
	if full:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.06, 0.92))
		_rotating = false
		_circle = false
		_scale = minf(size.x / GameState.CITY_SIZE.x, size.y / GameState.CITY_SIZE.y)
		var content := GameState.CITY_SIZE * _scale
		_origin = -(size - content) * 0.5 / _scale
		_draw_content(false)
		if _show_signal:
			_draw_signal_zones()
		_draw_building_labels()
		_draw_marker()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.7, 0.8, 0.8), false, 2.0)
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_circle = true
	_rotating = false
	_center = size * 0.5
	_radius = minf(size.x, size.y) * 0.5 - 3.0
	_circle_poly = PackedVector2Array()
	for i in 48:
		var angle := TAU * float(i) / 48.0
		_circle_poly.append(_center + Vector2(cos(angle), sin(angle)) * _radius)
	draw_circle(_center, _radius, Color(0.05, 0.05, 0.07, 0.78))
	_scale = _radius / (LOCAL_RANGE * 0.5)
	_player_map = _to2(player.global_position)
	# 固定朝北：地图方向不变，玩家居中，只有玩家箭头随朝向旋转
	_origin = _player_map - _center / _scale
	var forward: Vector3 = -player.global_transform.basis.z
	_forward = Vector2(forward.x, forward.z)
	if _forward.length() < 0.05:
		_forward = Vector2.UP
	else:
		_forward = _forward.normalized()
	_right = Vector2(-_forward.y, _forward.x)
	_draw_content(not _signal_blind)
	# 藏匿在建筑里：小地图不显示玩家箭头
	if GameState.player_in_building.is_empty():
		_draw_player_arrow()
	_draw_marker()
	if _signal_blind:
		# 无信号角标：告知当前地图没有实时情报
		draw_string(
			ThemeDB.fallback_font, _center + Vector2(-24.0, -_radius + 14.0), "无信号",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.75, 0.4, 0.9)
		)
	draw_arc(_center, _radius + 1.0, 0.0, TAU, 64, Color(0.65, 0.75, 0.85, 0.85), 2.0)
	draw_arc(_center, _radius - 1.0, 0.0, TAU, 64, Color(0.1, 0.12, 0.15, 0.6), 1.0)


func _draw_player_arrow() -> void:
	# 固定朝北地图：箭头随玩家朝向旋转（玩家始终居中）
	var spin := atan2(_forward.y, _forward.x) + PI / 2.0
	var arrow := PackedVector2Array()
	for point in [
		Vector2(0.0, -6.5), Vector2(-4.2, 4.4), Vector2(0.0, 2.2), Vector2(4.2, 4.4),
	]:
		arrow.append(_center + point.rotated(spin))
	draw_colored_polygon(arrow, Color(0.4, 1.0, 0.5, 1.0))
	var outline := PackedVector2Array(arrow)
	outline.append(arrow[0])
	draw_polyline(outline, Color(0.05, 0.25, 0.1, 0.9), 1.0)


var _cjk_font: Font = null


# 大地图文字字体：引擎 fallback 不含中文（Web 上全乱码），统一用内嵌中文字体
func _map_font() -> Font:
	if _cjk_font == null:
		_cjk_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	return _cjk_font


func _draw_building_labels() -> void:
	var font := _map_font()
	var placed: Array = []
	for entry in GameState.BUILDING_LAYOUT:
		# 住宅楼太多不标，只标有名字的功能建筑（商店/警察局/医院等）
		if String(entry["id"]) == "house":
			continue
		var building_name := String(
			GameState.BUILDINGS.get(String(entry["id"]), {}).get("name", "")
		)
		if building_name.is_empty():
			continue
		var center: Vector2 = _project(entry["position"])
		var text_size := font.get_string_size(
			building_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11
		)
		var text_pos := center + Vector2(-text_size.x * 0.5, 4.0)
		var overlaps := false
		for prev in placed:
			if absf(prev.x - text_pos.x) < (text_size.x + prev.z) * 0.5 + 4.0 \
				and absf(prev.y - text_pos.y) < 12.0:
				overlaps = true
				break
		if overlaps:
			continue
		placed.append(Vector3(text_pos.x, text_pos.y, text_size.x))
		draw_string(
			font, text_pos + Vector2(1, 1), building_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.0, 0.0, 0.0, 0.8)
		)
		draw_string(
			font, text_pos, building_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.9, 0.95)
		)


func _draw_marker() -> void:
	if GameState.map_marker == Vector2.ZERO:
		return
	var marker_pos := _project(GameState.map_marker)
	if not _circle:
		# 大地图：红色图钉
		draw_line(
			marker_pos + Vector2(0, -7), marker_pos + Vector2(0, 3),
			Color(1.0, 0.3, 0.25, 1.0), 2.0
		)
		draw_circle(marker_pos + Vector2(0, -7), 3.0, Color(1.0, 0.3, 0.25, 1.0))
		return
	# 小地图：范围内画点，范围外在圆盘边缘画方向箭头
	var offset := marker_pos - _center
	if offset.length() <= _radius - 8.0:
		draw_circle(marker_pos, 2.6, Color(1.0, 0.3, 0.25, 1.0))
		return
	var dir := offset.normalized()
	var tip := _center + dir * (_radius - 5.0)
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([
		tip + dir * 5.0,
		tip - dir * 3.0 + side * 3.4,
		tip - dir * 1.2,
		tip - dir * 3.0 - side * 3.4,
	])
	draw_colored_polygon(arrow, Color(1.0, 0.3, 0.25, 0.95))


func _draw_content(show_people: bool) -> void:
	_draw_rect_map(Vector2.ZERO, GameState.CITY_SIZE, GROUND_COLOR)
	_draw_rect_outline_map(Vector2.ZERO, GameState.CITY_SIZE, BOUNDARY_COLOR, 1.0)

	for r in GameState.ROADS:
		_draw_rect_map(r.position, r.size, ROAD_COLOR)

	for entry in GameState.BUILDING_LAYOUT:
		if GameState.demolished_buildings.has(entry["position"]):
			continue
		var pos: Vector2 = entry["position"]
		var sz: Vector2 = entry["size"]
		_draw_rect_map(pos - sz / 2.0, sz, BLOCK_FILL)
		_draw_rect_outline_map(pos - sz / 2.0, sz, BLOCK_LINE, 1.0)

	for rect in GameState.map_building_rects:
		_draw_rect_map(rect.position, rect.size, BLOCK_FILL)
		_draw_rect_outline_map(rect.position, rect.size, BLOCK_LINE, 1.0)

	for tower in GameState.TOWERS:
		if GameState.demolished_towers.has(tower["position"]):
			continue
		var tower_pos: Vector2 = tower["position"]
		var tower_size: Vector2 = tower["size"]
		_draw_rect_map(tower_pos - tower_size / 2.0, tower_size, BLOCK_FILL)
		_draw_rect_outline_map(tower_pos - tower_size / 2.0, tower_size, BLOCK_LINE, 1.0)

	if GameState.has_home_base():
		var home_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
		_draw_home(_project3(home_pos))

	for station in get_tree().get_nodes_in_group("base_stations"):
		var station_pos: Vector2 = _project3(station.global_position)
		if not _in_circle(station_pos, 8.0):
			continue
		var station_color := Color(0.35, 0.85, 0.95, 0.95)
		if station.destroyed:
			station_color = Color(0.4, 0.4, 0.4, 0.7)
		_draw_tower(station_pos, station_color)

	# 异能量场：紫色空心环（持续刷丧尸的巢穴，可被摧毁）
	for zone in get_tree().get_nodes_in_group("anomaly_zones"):
		if zone.is_queued_for_deletion() or bool(zone.get("destroyed")):
			continue
		var zone_pos: Vector2 = _project3(zone.global_position)
		if _in_circle(zone_pos, 6.0):
			draw_arc(zone_pos, 2.4, 0.0, TAU, 20, Color(0.7, 0.35, 0.95, 0.95), 1.2, true)

	# 事件标记只在大地图（M）显示，小地图上不画（避免与丧尸红点混淆）
	if not _circle:
		for entry in GameState.read_markers():
			var kind: String = entry["kind"]
			# 能量场/泄漏的位置圈由能量场区域节点直接绘制，消息不再重复画紫圈
			if kind == "anomaly":
				continue
			var marker_color := Color(1, 1, 1, 0.9)
			var ring := true
			match kind:
				"outbreak":
					marker_color = Color(1.0, 0.45, 0.2, 1.0)
				"accident":
					marker_color = Color(1.0, 0.6, 0.2, 0.95)
				"gunfire":
					marker_color = Color(1.0, 0.9, 0.35, 0.95)
					ring = false
				"horde":
					marker_color = Color(0.9, 0.2, 0.45, 0.95)
				"station":
					marker_color = Color(0.6, 0.6, 0.6, 0.9)
			var marker_pos: Vector2 = _project(entry["pos"])
			if not _in_circle(marker_pos, 4.0):
				continue
			if ring:
				# 事件标记画空心环，与实心红点的丧尸区分开
				draw_arc(marker_pos, 2.6, 0.0, TAU, 20, marker_color, 1.2, true)
			else:
				draw_circle(marker_pos, 1.6, marker_color)

	if show_people:
		# 本帧的"玩家在楼外"判定数据：建筑外壳列表 + 玩家地面坐标（见 _inside_closed_building）
		var occl: Array = []
		var scene := get_tree().current_scene
		if scene != null and scene.get("occl_buildings") is Array:
			occl = scene.occl_buildings
		var viewer = get_tree().get_first_node_in_group("player")
		var viewer_p := Vector2.ZERO
		var camera: Camera3D = null
		if viewer != null:
			viewer_p = Vector2(viewer.global_position.x, viewer.global_position.z)
			camera = viewer.get_node_or_null("Camera3D") as Camera3D
		for npc in get_tree().get_nodes_in_group("npcs"):
			# 夜间黑暗中没被照亮的市民/丧尸会被 proto3d._update_entity_visibility 隐藏
			# （visible=false，模型完全不渲染）；小地图不再给看不见的实体画点，
			# 否则会出现"地图上有点、走到跟前却找不到人"的假信息
			if (
				npc.is_queued_for_deletion() or bool(npc.get("_dying"))
				or not npc.visible
			):
				continue
			# 白天同理：店员/警察/驻军这类楼内岗位 NPC，玩家在楼外时被屋顶外墙挡着，
			# 屏幕上那一块只有屋顶、没有人 —— 小地图也不画；玩家进楼后外壳隐藏，点自动出现
			if _inside_closed_building(npc.global_position, occl, viewer_p):
				continue
			# 再补一层：街道行人站到某栋楼后面（不在该楼矩形内）时，画面上那一格也只有楼。
			# 只对"当前在屏幕上"的点打一条相机→胸口的射线判定（实测屏幕内的点平均每帧
			# 只有 1~2 个，代价可忽略；全量打射线才有性能问题）
			if _occluded_by_building(camera, viewer, npc.global_position, occl):
				continue
			var npc_pos: Vector2 = _project3(npc.global_position)
			if not _in_circle(npc_pos, 4.0):
				continue
			if npc.role == "cop":
				_draw_badge(npc_pos)
				continue
			var color := Color(0.75, 0.75, 0.8, 0.9)
			if npc.role == "soldier":
				color = Color(0.4, 0.75, 0.35, 0.95)
			draw_circle(npc_pos, 1.4, color)
		for zombie in get_tree().get_nodes_in_group("zombies"):
			# 死亡动画中的尸体不再显示红点（暂停时死亡 tween 可能延迟释放）；
			# 黑暗中隐藏的丧尸同理不画点（见上方市民注释）
			# 注：丧尸不做"楼内不画"过滤——它们是移动目标，红点是来袭预警，
			# 楼内只是一段过渡，藏起来反而丢掉告警
			if (
				zombie.is_queued_for_deletion() or bool(zombie.get("_dying"))
				or not zombie.visible
			):
				continue
			var zombie_pos: Vector2 = _project3(zombie.global_position)
			if _in_circle(zombie_pos, 4.0):
				draw_circle(zombie_pos, 1.4, Color(0.9, 0.25, 0.25, 0.95))
		for vehicle in get_tree().get_nodes_in_group("vehicles"):
			var car_pos: Vector2 = _project3(vehicle.global_position)
			if not _in_circle(car_pos, 9.0):
				continue
			var car_forward: Vector3 = vehicle.global_transform.basis.z
			var dir := Vector2(car_forward.x, car_forward.z)
			var screen_dir := (
				dir if not _rotating
				else Vector2(dir.dot(_right), -dir.dot(_forward))
			)
			_draw_car(car_pos, atan2(screen_dir.y, screen_dir.x))

	var player = get_tree().get_first_node_in_group("player")
	# 藏匿在建筑里：地图上不暴露位置
	if player != null and not show_people and GameState.player_in_building.is_empty():
		draw_circle(_project3(player.global_position), 4.0, Color(0.4, 1.0, 0.5, 1.0))


# 该位置是否落在某栋"外壳仍然可见"的建筑里——即玩家在楼外、屋顶与外墙挡着里面的人。
# 与 fps_player._update_occlusion 同源：矩形内缩 0.6m 判定玩家已进楼（此时外壳被隐藏、
# 里面的人看得见 → 不算遮挡）；其余情况按外壳自身 visible 标记判定，避免时序不同步
func _inside_closed_building(pos: Vector3, occl: Array, viewer_p: Vector2) -> bool:
	if occl.is_empty():
		return false
	var p := Vector2(pos.x, pos.z)
	for entry in occl:
		var rect: Rect2 = entry["rect"]
		if not rect.has_point(p):
			continue
		var shells: Array = entry.get("shells", [])
		if shells.is_empty():
			# 纯模型建筑（proto3d._place_model）：没有外壳列表，外壳就是模型本身，
			# 永远不会被 occlusion 隐藏，里面的人从任何角度都看不到 → 一律算封闭
			return true
		if rect.grow(-0.6).has_point(viewer_p):
			return false
		for shell in shells:
			if is_instance_valid(shell) and (shell as Node3D).visible:
				return true
	return false


# 建筑挡在"相机 → 实体"之间吗：只在实体位于相机视锥内时才判定（调用方先判视锥），
# 用一条射线实测，遮挡体必须是"已登记建筑/塔的部件"（见 _is_building_part）且不透明——
# 这样细杆/车辆/其它实体挡住的单条射线不会被误当成"楼挡住了"，也天然处理了
# "射线从屋顶上方掠过""从门洞看进去"这些矩形判定算不准的情况
func _occluded_by_building(camera: Camera3D, viewer, pos: Vector3, occl: Array) -> bool:
	if camera == null or viewer == null or not (viewer is Node3D):
		return false
	if not camera.is_position_in_frustum(pos + Vector3(0, 1.0, 0)):
		return false
	var space: PhysicsDirectSpaceState3D = (viewer as Node3D).get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, pos + Vector3(0, 0.9, 0))
	q.exclude = [(viewer as Node3D).get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return false
	var col = hit["collider"]
	if not (col is Node3D):
		return false
	var node: Node3D = col
	if not _is_building_part(node, occl):
		return false
	return _is_opaque(node)


# 是否为某栋已登记建筑/塔的部件（occl_buildings 的 parts）。
# 用 parts 判定而不是 "occludable" 组：模型城市（_place_model）的碰撞体没进那个组，
# 但同样在 parts 里；反过来组里也不会混入车辆/道具这类不该算遮挡的东西
func _is_building_part(node: Node3D, occl: Array) -> bool:
	for entry in occl:
		if (entry.get("parts", []) as Array).has(node):
			return true
	return false


# 外壳是否不透明：被 occlusion 淡成 0.22 剪影或外壳已隐藏（玩家进楼）的楼能看穿，不算遮挡；
# 没有自绘网格的纯碰撞体（模型城市 _place_model 的碰撞盒）算实心
func _is_opaque(node: Node3D) -> bool:
	var meshes: Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	if meshes.is_empty():
		return true
	for m in meshes:
		if not (m as MeshInstance3D).is_visible_in_tree():
			continue
		var mat: Material = (m as MeshInstance3D).material_override
		var mesh: Mesh = (m as MeshInstance3D).mesh
		if mat == null and mesh != null and mesh.get_surface_count() > 0:
			mat = (m as MeshInstance3D).get_active_material(0)
		if mat == null:
			return true
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_color.a >= 0.5:
			return true
	return false


# 信号热力图（大地图「信号区」按钮）：按信号强度分层渲染——
# 源中心最强（红热），边缘最弱（冷蓝），多源重叠自然叠加成热感渐变；
# 连通网络用暖色热感，孤立信号塔（独立区）用灰冷色调区分
const HEAT_LAYERS := 10


func _draw_signal_zones() -> void:
	var radar_list: Array = GameState.radar_vehicles()
	if not GameState.has_home_base() and radar_list.is_empty():
		return
	if GameState.has_home_base():
		var home: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
		_draw_signal_heat(home, GameState.base_signal_radius(), true)
		for entry in GameState.home_base.get("defenses", []):
			if String(entry.get("type", "")) != "signal_tower":
				continue
			var tp: Vector3 = entry["pos"]
			_draw_signal_heat(tp, GameState.SIGNAL_TOWER_RANGE, GameState.point_in_signal_coverage(tp))
	# 雷达车（移动信号站）：半塔距暖色热圈，随车移动
	for v in radar_list:
		_draw_signal_heat(v.global_position, GameState.RADAR_VEHICLE_RANGE, true)


# 分层热度：由外向内画同心圆，越靠内颜色越热、透明度越高；
# 与地图矩形求交裁剪，热力图不溢出地图框
func _draw_signal_heat(world: Vector3, radius_m: float, connected: bool) -> void:
	var c := _project3(world)
	var r := radius_m / SCALE * _scale
	var rect := Rect2(Vector2.ZERO, size)
	var rect_poly := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	for i in range(HEAT_LAYERS, 0, -1):
		var f := float(i) / float(HEAT_LAYERS)  # 1.0=最外层 → 0.1=最内层
		var strength := 1.0 - f  # 外缘弱（0），中心强（≈0.9）
		var circle := PackedVector2Array()
		for k in 32:
			var a := TAU * float(k) / 32.0
			circle.append(c + Vector2(cos(a), sin(a)) * (r * f))
		for piece in Geometry2D.intersect_polygons(circle, rect_poly):
			if piece.size() >= 3:
				draw_colored_polygon(piece, _heat_color(strength, connected))


# 热感渐变：冷蓝 → 黄 → 红热（连通）；孤立区混入灰色调
func _heat_color(strength: float, connected: bool) -> Color:
	var cold := Color(0.18, 0.42, 0.95)
	var mid := Color(1.0, 0.82, 0.18)
	var warm := Color(1.0, 0.28, 0.1)
	var col: Color
	if strength < 0.5:
		col = cold.lerp(mid, strength * 2.0)
	else:
		col = mid.lerp(warm, (strength - 0.5) * 2.0)
	if not connected:
		col = col.lerp(Color(0.55, 0.55, 0.6), 0.65)
	return Color(col.r, col.g, col.b, 0.05 + 0.12 * strength)


# 据点标记：家形图标（屋顶三角 + 屋身方块），center 为投影后的 2D 坐标
func _draw_home(center: Vector2) -> void:
	if not _in_circle(center, 8.0):
		return
	var color := Color(1.0, 0.85, 0.35, 0.95)
	var line := Color(0.2, 0.12, 0.0, 0.9)
	var roof := PackedVector2Array([
		center + Vector2(-4.4, 0.4),
		center + Vector2(0.0, -4.2),
		center + Vector2(4.4, 0.4),
	])
	draw_colored_polygon(roof, color)
	var roof_outline := PackedVector2Array(roof)
	roof_outline.append(roof[0])
	draw_polyline(roof_outline, line, 1.0)
	var body := PackedVector2Array([
		center + Vector2(-3.0, 0.4),
		center + Vector2(3.0, 0.4),
		center + Vector2(3.0, 4.0),
		center + Vector2(-3.0, 4.0),
	])
	draw_colored_polygon(body, color)
	var body_outline := PackedVector2Array(body)
	body_outline.append(body[0])
	draw_polyline(body_outline, line, 1.0)


func _draw_car(center: Vector2, angle: float) -> void:
	var body := PackedVector2Array([
		center + Vector2(-4.0, -2.0).rotated(angle),
		center + Vector2(4.0, -2.0).rotated(angle),
		center + Vector2(4.0, 2.0).rotated(angle),
		center + Vector2(-4.0, 2.0).rotated(angle),
	])
	draw_colored_polygon(body, Color(0.95, 0.85, 0.45, 0.95))
	var outline := PackedVector2Array(body)
	outline.append(body[0])
	draw_polyline(outline, Color(0.35, 0.3, 0.1, 0.9), 1.0)
	var cabin := PackedVector2Array([
		center + Vector2(-1.2, -1.6).rotated(angle),
		center + Vector2(1.2, -1.6).rotated(angle),
		center + Vector2(1.2, 1.6).rotated(angle),
		center + Vector2(-1.2, 1.6).rotated(angle),
	])
	draw_colored_polygon(cabin, Color(0.3, 0.3, 0.35, 0.95))


func _draw_tower(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-3.0, 3.0), center + Vector2(0.0, -3.0), color, 1.4)
	draw_line(center + Vector2(3.0, 3.0), center + Vector2(0.0, -3.0), color, 1.4)
	draw_line(center + Vector2(-1.8, 0.5), center + Vector2(1.8, 0.5), color, 1.0)
	draw_circle(center + Vector2(0.0, -3.5), 1.2, color)
	draw_arc(center + Vector2(0.0, -4.0), 4.0, PI + 0.4, TAU - 0.4, 10, color, 1.0)


func _draw_badge(center: Vector2) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + PI * float(i) / 5.0
		var radius := 4.2 if i % 2 == 0 else 1.9
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0.35, 0.55, 1.0, 0.95))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.95, 0.98, 1.0, 0.9), 1.0)
