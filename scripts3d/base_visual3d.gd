extends Node3D
# 据点外观成长：占领瞬间屋顶竖旗 + 门口暖光（夜间自动增亮）；随等级逐级追加
# Lv3 大旗帜 + 探照灯 / Lv4 四角瞭望塔 / Lv5 要塞铭牌。
# 营地不自带围墙/沙袋：防御墙体一律由玩家通过建造栏自行摆放。
# 全部为装饰性可视节点（无碰撞），换据点时监听 home_base_changed 整体重建。
# 同时承担据点信号覆盖：每 0.2 秒按玩家距离向 GameState 上报信号强度（替代信号塔）。

const SCALE := 0.05
const FLAG_COLOR := Color(1.0, 0.42, 0.12)

var _flag_joints: Array = []
var _anim_time := 0.0
var _spot_pivot: Node3D = null
var _signal_timer := 0.0


func _ready() -> void:
	GameState.home_base_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	GameState.clear_signal(GameState.BASE_SIGNAL_ID)


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	_flag_joints.clear()
	_spot_pivot = null
	if not GameState.has_home_base():
		GameState.clear_signal(GameState.BASE_SIGNAL_ID)
		return
	var level := GameState.home_base_level()
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	var geo := _base_geometry(base_pos)
	var center: Vector3 = geo["center"]
	_build_flag(center, float(geo["height"]), level)
	if level >= 3:
		_build_spotlight(center, float(geo["height"]))
	if level >= 4:
		_build_watchtowers(center, float(geo["width"]), float(geo["depth"]))
	_build_plate(base_pos, level)


func _process(delta: float) -> void:
	_signal_timer -= delta
	if _signal_timer <= 0.0:
		_signal_timer = 0.2
		_update_signal()
	if _flag_joints.is_empty() and _spot_pivot == null:
		return
	_anim_time += delta
	for i in _flag_joints.size():
		var joint: Node3D = _flag_joints[i]
		if is_instance_valid(joint):
			joint.rotation.y = sin(_anim_time * 4.0 - float(i) * 0.9) * 0.26
	if _spot_pivot != null and is_instance_valid(_spot_pivot):
		_spot_pivot.rotation.y = _anim_time * 0.7


# 据点信号覆盖：按玩家到据点的平面距离线性衰减，超出半径自动清除信号源
func _update_signal() -> void:
	if not GameState.has_home_base():
		return
	var strength := 0.0
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
		var flat := Vector2(
			player.global_position.x - base_pos.x, player.global_position.z - base_pos.z
		)
		strength = clampf(1.0 - flat.length() / GameState.base_signal_radius(), 0.0, 1.0)
	GameState.report_signal(GameState.BASE_SIGNAL_ID, strength)


# 按据点门口位置反查 BUILDING_LAYOUT 拿到建筑体量；找不到（自定义图等）用半径兜底
func _base_geometry(base_pos: Vector3) -> Dictionary:
	for entry in GameState.BUILDING_LAYOUT:
		var pos: Vector2 = entry["position"]
		var size2d: Vector2 = entry["size"]
		var center := Vector3(pos.x * SCALE, 0.0, pos.y * SCALE)
		var door := center + Vector3(0.0, 0.05, size2d.y * SCALE / 2.0 + 1.2)
		if door.distance_to(base_pos) < 2.5:
			return {
				"center": center,
				"width": size2d.x * SCALE,
				"depth": size2d.y * SCALE,
				"height": _building_height(String(entry["id"])),
			}
	var radius := GameState.home_base_radius()
	return {"center": base_pos, "width": radius, "depth": radius, "height": 6.0}


func _building_height(id: String) -> float:
	match id:
		"bank":
			return 12.0
		"police":
			return 10.0
		"house":
			return 6.0
		_:
			return 8.0


# Lv1：屋顶旗帜（Lv3 起变大），旗面 4 段串联薄片相位错开形成波浪
func _build_flag(center: Vector3, height: float, level: int) -> void:
	var big := level >= 3
	var pole_h := 4.4 if big else 3.0
	var roof_y := height + 0.8
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.05
	pole_mesh.bottom_radius = 0.07
	pole_mesh.height = pole_h
	pole.mesh = pole_mesh
	pole.material_override = _mat(Color(0.75, 0.75, 0.78))
	pole.position = center + Vector3(0.0, roof_y + pole_h / 2.0, 0.0)
	add_child(pole)
	var seg_w := 0.42 if big else 0.3
	var seg_h := 0.62 if big else 0.45
	var pivot := Node3D.new()
	pivot.position = center + Vector3(0.0, roof_y + pole_h - seg_h / 2.0 - 0.08, 0.0)
	add_child(pivot)
	var parent := pivot
	for i in 4:
		var joint := Node3D.new()
		joint.position = Vector3(seg_w if i > 0 else seg_w / 2.0 + 0.05, 0.0, 0.0)
		parent.add_child(joint)
		var cloth := MeshInstance3D.new()
		var cloth_mesh := BoxMesh.new()
		cloth_mesh.size = Vector3(seg_w, seg_h, 0.04)
		cloth.mesh = cloth_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = FLAG_COLOR
		material.emission_enabled = true
		material.emission = FLAG_COLOR
		material.emission_energy_multiplier = 0.4
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cloth.material_override = material
		cloth.position = Vector3(seg_w / 2.0, 0.0, 0.0)
		joint.add_child(cloth)
		_flag_joints.append(joint)
		parent = joint


# Lv3：屋顶探照灯，缓慢扫动
func _build_spotlight(center: Vector3, height: float) -> void:
	_spot_pivot = Node3D.new()
	_spot_pivot.position = center + Vector3(0.0, height + 1.7, 0.0)
	add_child(_spot_pivot)
	_box_at(_spot_pivot, Vector3(0.0, -0.25, 0.0), Vector3(0.5, 0.5, 0.5), Color(0.3, 0.3, 0.34))


# Lv4：四角瞭望塔（细柱 + 小平台 + 栏杆）
func _build_watchtowers(center: Vector3, width: float, depth: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_build_watchtower(
				center + Vector3(sx * (width / 2.0 + 1.4), 0.0, sz * (depth / 2.0 + 1.4))
			)


func _build_watchtower(pos: Vector3) -> void:
	var leg := MeshInstance3D.new()
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.12
	leg_mesh.bottom_radius = 0.16
	leg_mesh.height = 5.0
	leg.mesh = leg_mesh
	leg.material_override = _mat(Color(0.45, 0.4, 0.34))
	leg.position = pos + Vector3(0.0, 2.5, 0.0)
	add_child(leg)
	_box(pos + Vector3(0.0, 5.05, 0.0), Vector3(1.6, 0.15, 1.6), Color(0.5, 0.44, 0.36))
	var rail_color := Color(0.35, 0.32, 0.28)
	for i in 4:
		var angle := PI / 2.0 * float(i)
		var off := Vector3(sin(angle), 0.0, cos(angle)) * 0.72
		_box(
			pos + Vector3(off.x, 5.45, off.z),
			Vector3(1.5, 0.6, 0.08) if i % 2 == 0 else Vector3(0.08, 0.6, 1.5),
			rail_color
		)


func _build_plate(base_pos: Vector3, level: int) -> void:
	var plate := Label3D.new()
	var text := "据点 Lv%d · 要塞" % level if level >= 5 else "据点 Lv%d" % level
	plate.text = text + " · 信号覆盖 %d米" % int(GameState.base_signal_radius())
	plate.font_size = 72
	plate.modulate = Color(1.0, 0.8, 0.3)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position = base_pos + Vector3(0.0, 4.4, 0.0)
	add_child(plate)


func _box(center: Vector3, size: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	mesh.position = center
	mesh.rotation.y = yaw
	add_child(mesh)
	return mesh


func _box_at(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
