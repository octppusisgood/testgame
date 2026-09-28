extends Node3D

const RUNTIME := preload("res://scripts3d/custommap3d.gd")
const MENU_SCENE := "res://scenes3d/menu3d.tscn"
const PLAY_SCENE := "res://scenes3d/custommap3d.tscn"
const MIN_SIZE := 50.0
const MAX_SIZE := 400.0
const GRID_STEP := 10.0

var _map_name := "我的地图"
var _map_width := 120.0
var _map_depth := 120.0
var _npc_count := 10
var _outbreak_enabled := false
var _outbreak_intensity := 1.0
var _buildings: Array = []
var _items: Array = []
var _sel_kind := ""
var _sel_id := ""
var _sel_rot := 0
var _sel_item: Dictionary = {}
var _anchor := Vector3.ZERO
var _cam_height := 80.0
var _cam: Camera3D
var _ground_root: Node3D
var _world_root: Node3D
var _name_edit: LineEdit
var _width_spin: SpinBox
var _depth_spin: SpinBox
var _npc_spin: SpinBox
var _outbreak_check: CheckBox
var _outbreak_option: OptionButton
var _status: Label
var _sel_label: Label
var _map_panel: Control
var _map_list: VBoxContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_environment()
	_world_root = Node3D.new()
	_world_root.name = "PlacedObjects"
	add_child(_world_root)
	_ground_root = Node3D.new()
	_ground_root.name = "Ground"
	add_child(_ground_root)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.far = 1200.0
	add_child(_cam)
	_anchor = Vector3(_map_width / 2.0, 0.0, _map_depth / 2.0)
	_rebuild_ground()
	_update_camera()
	_build_ui()
	_update_sel_label()


func _setup_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() == null:
		var move := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move.x += 1.0
		if move != Vector2.ZERO:
			var speed := _cam_height * 0.9 * delta
			_anchor += Vector3(move.x, 0.0, move.y).normalized() * speed
			_anchor.x = clampf(_anchor.x, -20.0, _map_width + 20.0)
			_anchor.z = clampf(_anchor.z, -20.0, _map_depth + 20.0)
			_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse := get_viewport().get_mouse_position()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_cam_height = clampf(_cam_height * 0.85, 12.0, 300.0)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_cam_height = clampf(_cam_height * 1.18, 12.0, 300.0)
				_update_camera()
			MOUSE_BUTTON_LEFT:
				_place_at(_ground_point(mouse))
			MOUSE_BUTTON_RIGHT:
				_delete_near(_ground_point(mouse))
	elif event is InputEventKey and event.pressed and not event.echo:
		if get_viewport().gui_get_focus_owner() != null:
			return
		if event.keycode == KEY_R and _sel_kind == "building":
			_sel_rot = (_sel_rot + 1) % 4
			_update_sel_label()
		elif event.keycode == KEY_ESCAPE:
			_back_to_menu()


func _update_camera() -> void:
	_cam.position = _anchor + Vector3(0.0, _cam_height, _cam_height * 0.55)
	_cam.look_at(_anchor, Vector3.UP)


func _ground_point(mouse_pos: Vector2) -> Vector3:
	var from := _cam.project_ray_origin(mouse_pos)
	var dir := _cam.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.001:
		return _anchor
	var t := -from.y / dir.y
	return from + dir * maxf(t, 0.0)


func _place_at(p: Vector3) -> void:
	if _sel_kind == "":
		_set_status("先在右侧面板选择要放置的建筑或物品")
		return
	if p.x < 0.0 or p.x > _map_width or p.z < 0.0 or p.z > _map_depth:
		_set_status("超出地图边界，无法放置")
		return
	if _sel_kind == "building":
		var size := RUNTIME.building_size(_sel_id, _sel_rot)
		var x := clampf(p.x, size.x / 2.0, _map_width - size.x / 2.0)
		var z := clampf(p.z, size.y / 2.0, _map_depth - size.y / 2.0)
		var entry := {"id": _sel_id, "x": x, "z": z, "rot": _sel_rot}
		entry["node"] = _make_building_preview(entry)
		_buildings.append(entry)
		_set_status("已放置建筑：%s（共 %d 座）" % [
			GameState.BUILDINGS[_sel_id]["name"], _buildings.size(),
		])
	else:
		var entry := _sel_item.duplicate()
		entry["x"] = p.x
		entry["z"] = p.z
		entry["node"] = _make_item_preview(entry)
		_items.append(entry)
		_set_status("已放置物品：%s（共 %d 个）" % [
			RUNTIME.item_display_name(entry), _items.size(),
		])


func _delete_near(p: Vector3) -> void:
	var best_list: Array = []
	var best_index := -1
	var best_dist := 6.0
	for i in _buildings.size():
		var entry: Dictionary = _buildings[i]
		var size := RUNTIME.building_size(String(entry["id"]), int(entry.get("rot", 0)))
		var dx := maxf(absf(p.x - float(entry["x"])) - size.x / 2.0, 0.0)
		var dz := maxf(absf(p.z - float(entry["z"])) - size.y / 2.0, 0.0)
		var dist := Vector2(dx, dz).length()
		if dist < best_dist:
			best_dist = dist
			best_list = _buildings
			best_index = i
	for i in _items.size():
		var entry: Dictionary = _items[i]
		var dist := Vector2(p.x - float(entry["x"]), p.z - float(entry["z"])).length()
		if dist < best_dist:
			best_dist = dist
			best_list = _items
			best_index = i
	if best_index < 0:
		_set_status("附近没有可删除的对象")
		return
	var removed: Dictionary = best_list[best_index]
	if removed.get("node") != null and is_instance_valid(removed["node"]):
		removed["node"].queue_free()
	best_list.remove_at(best_index)
	_set_status("已删除一个对象")


func _make_building_preview(entry: Dictionary) -> Node3D:
	var id := String(entry["id"])
	var rot := int(entry.get("rot", 0))
	var size := RUNTIME.building_size(id, rot)
	var height := RUNTIME.building_height(id)
	var color: Color = GameState.BUILDINGS[id]["color"]
	var root := Node3D.new()
	root.position = Vector3(float(entry["x"]), 0.0, float(entry["z"]))
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, height, size.y)
	mesh.mesh = box
	mesh.position = Vector3(0.0, height / 2.0, 0.0)
	mesh.material_override = _ghost_material(color)
	root.add_child(mesh)
	var roof := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(size.x + 0.6, 0.5, size.y + 0.6)
	roof.mesh = roof_box
	roof.position = Vector3(0.0, height + 0.25, 0.0)
	roof.material_override = _ghost_material(color.darkened(0.35))
	root.add_child(roof)
	var label := Label3D.new()
	label.text = String(GameState.BUILDINGS[id]["name"])
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, height + 2.0, 0.0)
	root.add_child(label)
	_world_root.add_child(root)
	return root


func _make_item_preview(entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(float(entry["x"]), 0.0, float(entry["z"]))
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	mesh.mesh = box
	mesh.position = Vector3(0.0, 0.3, 0.0)
	mesh.material_override = _ghost_material(_item_color(entry))
	root.add_child(mesh)
	var label := Label3D.new()
	label.text = RUNTIME.item_display_name(entry)
	label.font_size = 40
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(label)
	_world_root.add_child(root)
	return root


func _item_color(entry: Dictionary) -> Color:
	if String(entry.get("kind", "loot")) == "pickup":
		match String(entry.get("id", "")):
			"ammo":
				return Color(0.9, 0.85, 0.3)
			"meds":
				return Color(0.9, 0.3, 0.3)
			"food":
				return Color(0.3, 0.8, 0.35)
			_:
				return Color(0.95, 0.75, 0.2)
	match String(GameState.loot_info(String(entry.get("id", ""))).get("cat", "")):
		"food", "drink":
			return Color(0.3, 0.8, 0.35)
		"med":
			return Color(0.9, 0.3, 0.3)
		"ranged":
			return Color(0.6, 0.6, 0.7)
		"melee":
			return Color(0.7, 0.55, 0.35)
		"armor":
			return Color(0.4, 0.5, 0.7)
		_:
			return Color(0.95, 0.75, 0.2)


func _ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _rebuild_ground() -> void:
	for child in _ground_root.get_children():
		child.queue_free()
	var ground := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_map_width, 1.0, _map_depth)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.23, 0.2)
	mesh.material_override = material
	ground.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	ground.add_child(collision)
	ground.position = Vector3(_map_width / 2.0, -0.5, _map_depth / 2.0)
	_ground_root.add_child(ground)

	var grid_color := Color(0.32, 0.35, 0.32)
	var x := GRID_STEP
	while x < _map_width:
		_add_ground_line(Vector3(x, 0.02, _map_depth / 2.0), Vector3(0.08, 0.04, _map_depth), grid_color)
		x += GRID_STEP
	var z := GRID_STEP
	while z < _map_depth:
		_add_ground_line(Vector3(_map_width / 2.0, 0.02, z), Vector3(_map_width, 0.04, 0.08), grid_color)
		z += GRID_STEP
	var frame_color := Color(0.9, 0.5, 0.2)
	var t := 0.25
	_add_ground_line(Vector3(_map_width / 2.0, 0.05, -t / 2.0), Vector3(_map_width + t, 0.1, t), frame_color)
	_add_ground_line(Vector3(_map_width / 2.0, 0.05, _map_depth + t / 2.0), Vector3(_map_width + t, 0.1, t), frame_color)
	_add_ground_line(Vector3(-t / 2.0, 0.05, _map_depth / 2.0), Vector3(t, 0.1, _map_depth), frame_color)
	_add_ground_line(Vector3(_map_width + t / 2.0, 0.05, _map_depth / 2.0), Vector3(t, 0.1, _map_depth), frame_color)


func _add_ground_line(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = center
	_ground_root.add_child(mesh)


func _clamp_placed() -> void:
	for entry in _buildings:
		var size := RUNTIME.building_size(String(entry["id"]), int(entry.get("rot", 0)))
		entry["x"] = clampf(float(entry["x"]), size.x / 2.0, _map_width - size.x / 2.0)
		entry["z"] = clampf(float(entry["z"]), size.y / 2.0, _map_depth - size.y / 2.0)
		if entry.get("node") != null and is_instance_valid(entry["node"]):
			entry["node"].position = Vector3(float(entry["x"]), 0.0, float(entry["z"]))
	for entry in _items:
		entry["x"] = clampf(float(entry["x"]), 1.0, _map_width - 1.0)
		entry["z"] = clampf(float(entry["z"]), 1.0, _map_depth - 1.0)
		if entry.get("node") != null and is_instance_valid(entry["node"]):
			entry["node"].position = Vector3(float(entry["x"]), 0.0, float(entry["z"]))


func _clear_placed() -> void:
	for child in _world_root.get_children():
		child.queue_free()
	_buildings.clear()
	_items.clear()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var hint := Label.new()
	hint.text = "WASD/方向键 平移 · 滚轮 缩放 · 左键 放置 · 右键 删除 · R 旋转建筑 · Esc 返回菜单"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	hint.position = Vector2(12, 8)
	layer.add_child(hint)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -310.0
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var title := Label.new()
	title.text = "地图编辑器"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_make_label("地图名"))
	_name_edit = LineEdit.new()
	_name_edit.text = _map_name
	_name_edit.text_changed.connect(func(text): _map_name = text.strip_edges())
	box.add_child(_name_edit)

	box.add_child(_make_label("地图宽度（米）"))
	_width_spin = _make_spin(_map_width, MIN_SIZE, MAX_SIZE, 10.0)
	_width_spin.value_changed.connect(func(value):
		_map_width = float(value)
		_clamp_placed()
		_rebuild_ground()
	)
	box.add_child(_width_spin)

	box.add_child(_make_label("地图深度（米）"))
	_depth_spin = _make_spin(_map_depth, MIN_SIZE, MAX_SIZE, 10.0)
	_depth_spin.value_changed.connect(func(value):
		_map_depth = float(value)
		_clamp_placed()
		_rebuild_ground()
	)
	box.add_child(_depth_spin)

	box.add_child(_make_label("NPC 人数（0~200）"))
	_npc_spin = _make_spin(_npc_count, 0.0, 200.0, 1.0)
	_npc_spin.value_changed.connect(func(value): _npc_count = int(value))
	box.add_child(_npc_spin)

	_outbreak_check = CheckBox.new()
	_outbreak_check.text = "丧尸爆发"
	_outbreak_check.button_pressed = _outbreak_enabled
	_outbreak_check.toggled.connect(func(value): _outbreak_enabled = value)
	box.add_child(_outbreak_check)

	box.add_child(_make_label("爆发强度"))
	_outbreak_option = OptionButton.new()
	_outbreak_option.add_item("简单（0.6×）", 0)
	_outbreak_option.add_item("标准（1.0×）", 1)
	_outbreak_option.add_item("困难（1.5×）", 2)
	_outbreak_option.selected = 1
	_outbreak_option.item_selected.connect(func(index):
		_outbreak_intensity = [0.6, 1.0, 1.5][index]
	)
	box.add_child(_outbreak_option)

	box.add_child(_make_label("建筑（点击选择，R 旋转 90°）"))
	for id in GameState.BUILDINGS.keys():
		var cfg: Dictionary = GameState.BUILDINGS[id]
		var button := _make_button(String(cfg["name"]), _select_building.bind(String(id)))
		box.add_child(button)

	box.add_child(_make_label("物品（食物 / 药品 / 武器 / 弹药）"))
	for choice in RUNTIME.ITEM_CHOICES:
		var button := _make_button(RUNTIME.item_display_name(choice), _select_item.bind(choice))
		box.add_child(button)

	box.add_child(_make_label("操作"))
	box.add_child(_make_button("新建（清空）", _on_new))
	box.add_child(_make_button("保存", _on_save))
	box.add_child(_make_button("打开", _show_map_panel))
	box.add_child(_make_button("删除地图", _show_map_panel))
	box.add_child(_make_button("试玩（先自动保存）", _on_play))
	box.add_child(_make_button("返回菜单", _back_to_menu))

	_sel_label = Label.new()
	_sel_label.add_theme_font_size_override("font_size", 12)
	_sel_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_sel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_sel_label)

	_status = Label.new()
	_status.text = "从右侧选择建筑或物品，然后在地面左键放置"
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	_build_map_panel(layer)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	return label


func _make_spin(value: float, min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	return spin


func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(handler)
	return button


func _build_map_panel(layer: CanvasLayer) -> void:
	_map_panel = Control.new()
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.visible = false
	layer.add_child(_map_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	_map_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.add_child(center)
	_map_list = VBoxContainer.new()
	_map_list.add_theme_constant_override("separation", 6)
	center.add_child(_map_list)


func _show_map_panel() -> void:
	for child in _map_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "已保存的地图（user://maps/）"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_list.add_child(title)
	var maps := RUNTIME.list_saved_maps()
	if maps.is_empty():
		var empty := Label.new()
		empty.text = "还没有保存过地图"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_map_list.add_child(empty)
	for entry in maps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var open_button := _make_button("打开：%s" % entry["name"], _open_map.bind(String(entry["path"])))
		open_button.custom_minimum_size = Vector2(220, 30)
		row.add_child(open_button)
		row.add_child(_make_button("删除", _delete_map.bind(String(entry["path"]))))
		_map_list.add_child(row)
	_map_list.add_child(_make_button("返回", func(): _map_panel.visible = false))
	_map_panel.visible = true


func _select_building(id: String) -> void:
	_sel_kind = "building"
	_sel_id = id
	_update_sel_label()


func _select_item(choice: Dictionary) -> void:
	_sel_kind = "item"
	_sel_item = choice.duplicate()
	_sel_id = String(choice.get("id", ""))
	_update_sel_label()


func _update_sel_label() -> void:
	if _sel_label == null:
		return
	if _sel_kind == "building":
		_sel_label.text = "当前选中：建筑 · %s（朝向 %d°，按 R 旋转）" % [
			GameState.BUILDINGS[_sel_id]["name"], _sel_rot * 90,
		]
	elif _sel_kind == "item":
		_sel_label.text = "当前选中：物品 · %s" % RUNTIME.item_display_name(_sel_item)
	else:
		_sel_label.text = "当前选中：无"


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _collect_data() -> Dictionary:
	var buildings: Array = []
	for entry in _buildings:
		buildings.append({
			"id": String(entry["id"]),
			"x": snappedf(float(entry["x"]), 0.1),
			"z": snappedf(float(entry["z"]), 0.1),
			"rot": int(entry.get("rot", 0)),
		})
	var items: Array = []
	for entry in _items:
		var item := {
			"id": String(entry["id"]),
			"kind": String(entry.get("kind", "loot")),
			"x": snappedf(float(entry["x"]), 0.1),
			"z": snappedf(float(entry["z"]), 0.1),
		}
		if entry.has("amount"):
			item["amount"] = int(entry["amount"])
		if entry.has("cash"):
			item["cash"] = int(entry["cash"])
		items.append(item)
	return {
		"name": _map_name if not _map_name.is_empty() else "未命名地图",
		"width": _map_width,
		"depth": _map_depth,
		"npc_count": _npc_count,
		"outbreak": {"enabled": _outbreak_enabled, "intensity": _outbreak_intensity},
		"buildings": buildings,
		"items": items,
	}


func _on_new() -> void:
	_clear_placed()
	_map_name = "我的地图"
	_map_width = 120.0
	_map_depth = 120.0
	_npc_count = 10
	_outbreak_enabled = false
	_outbreak_intensity = 1.0
	_name_edit.text = _map_name
	_width_spin.value = _map_width
	_depth_spin.value = _map_depth
	_npc_spin.value = _npc_count
	_outbreak_check.button_pressed = false
	_outbreak_option.selected = 1
	_anchor = Vector3(_map_width / 2.0, 0.0, _map_depth / 2.0)
	_rebuild_ground()
	_update_camera()
	_set_status("已新建空白地图")


func _on_save() -> void:
	var data := _collect_data()
	var path := RUNTIME.map_path_for(String(data["name"]))
	if RUNTIME.save_map_data(path, data):
		_set_status("已保存：%s" % path)
	else:
		_set_status("保存失败：%s" % path)


func _open_map(path: String) -> void:
	var data := RUNTIME.load_map_data(path)
	if data.is_empty():
		_set_status("打开失败：%s" % path)
		return
	_map_panel.visible = false
	_clear_placed()
	_map_name = String(data.get("name", "未命名地图"))
	_map_width = RUNTIME.map_width(data)
	_map_depth = RUNTIME.map_depth(data)
	_npc_count = clampi(int(data.get("npc_count", 0)), 0, 200)
	_name_edit.text = _map_name
	_width_spin.value = _map_width
	_depth_spin.value = _map_depth
	_npc_spin.value = _npc_count
	var outbreak: Dictionary = data.get("outbreak", {})
	_outbreak_enabled = bool(outbreak.get("enabled", false))
	_outbreak_intensity = clampf(float(outbreak.get("intensity", 1.0)), 0.6, 1.5)
	_outbreak_check.button_pressed = _outbreak_enabled
	_outbreak_option.selected = maxi(0, [0.6, 1.0, 1.5].find(_outbreak_intensity))
	for entry in data.get("buildings", []):
		var building := {
			"id": String(entry.get("id", "house")),
			"x": float(entry.get("x", 0.0)),
			"z": float(entry.get("z", 0.0)),
			"rot": int(entry.get("rot", 0)),
		}
		if not GameState.BUILDINGS.has(building["id"]):
			continue
		building["node"] = _make_building_preview(building)
		_buildings.append(building)
	for entry in data.get("items", []):
		var item: Dictionary = entry.duplicate()
		item["node"] = _make_item_preview(item)
		_items.append(item)
	_clamp_placed()
	_anchor = Vector3(_map_width / 2.0, 0.0, _map_depth / 2.0)
	_rebuild_ground()
	_update_camera()
	_set_status("已打开地图：%s" % _map_name)


func _delete_map(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_show_map_panel()
	_set_status("已删除地图文件：%s" % path)


func _on_play() -> void:
	var data := _collect_data()
	var path := RUNTIME.map_path_for(String(data["name"]))
	if not RUNTIME.save_map_data(path, data):
		_set_status("保存失败，无法试玩")
		return
	GameState.custom_map_path = path
	Network.leave()
	GameState.reset_run()
	get_tree().change_scene_to_file(PLAY_SCENE)


func _back_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
