extends Node3D

const PLAYER_SCENE := preload("res://scenes3d/fps_player.tscn")
const NPC_SCENE := preload("res://scenes3d/npc3d.tscn")
const ZOMBIE_SCENE := preload("res://scenes3d/zombie3d.tscn")
const TRAINING_TARGET_SCENE := preload("res://scenes3d/training_target3d.tscn")

const MAP_SIZE := 80.0

var _units: Array = []
var _panel: PanelContainer
var _player: Node3D
var _faction_option: OptionButton
var _unit_option: OptionButton
var _ability_labels := {}
var _ability_rows: Array = []
var _category_option: OptionButton


func _ready() -> void:
	GameState.home_scene = "res://scenes3d/unitrange3d.tscn"
	GameState.reset_coverage()
	GameState.test_mode = true
	GameState.training_ground = true
	GameState.apply_test_loadout()
	# 训练场：能力/变异等级进场归零，SP 给足，用召唤面板里的 +/- 主动调整
	for skill in GameState.SKILLS:
		GameState.skills[String(skill["id"])] = 0
	for id in GameState.attrs.keys():
		GameState.attrs[id] = 0
	for id in GameState.mutation_levels.keys():
		GameState.mutation_levels[id] = 0
	GameState.mutations_taken = 0
	GameState.space_energy = 9999
	GameState.skills_changed.emit()
	GameState.mutations_changed.emit()
	GameState.phase = "survival"
	GameState.custom_panel_close_requested.connect(_close_panel)
	_setup_environment()
	_build_arena()
	_build_shooting_range()
	_spawn_player()
	_build_panel()
	GameState.notify("训练场：按 U 打开面板，可召唤单位并用 +/- 调整能力等级")


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


func _build_arena() -> void:
	_add_box(Vector3(MAP_SIZE / 2.0, -0.5, MAP_SIZE / 2.0), Vector3(MAP_SIZE, 1.0, MAP_SIZE), Color(0.25, 0.27, 0.24))
	var wall_color := Color(0.35, 0.35, 0.38)
	var t := 0.6
	var h := 3.0
	_add_box(Vector3(MAP_SIZE / 2.0, h / 2.0, -t / 2.0), Vector3(MAP_SIZE + t * 2.0, h, t), wall_color)
	_add_box(Vector3(MAP_SIZE / 2.0, h / 2.0, MAP_SIZE + t / 2.0), Vector3(MAP_SIZE + t * 2.0, h, t), wall_color)
	_add_box(Vector3(-t / 2.0, h / 2.0, MAP_SIZE / 2.0), Vector3(t, h, MAP_SIZE), wall_color)
	_add_box(Vector3(MAP_SIZE + t / 2.0, h / 2.0, MAP_SIZE / 2.0), Vector3(t, h, MAP_SIZE), wall_color)
	# 中线：左人类右丧尸的提示标线
	_add_box(Vector3(MAP_SIZE / 2.0, 0.02, MAP_SIZE / 2.0), Vector3(0.3, 0.05, MAP_SIZE - 4.0), Color(0.6, 0.6, 0.3))
	# 固定刷怪点标记：场中亮绿色召唤平台
	var pad := _spawn_point()
	_add_box(pad + Vector3(0, 0.03, 0), Vector3(2.4, 0.06, 2.4), Color(0.2, 0.9, 0.4))
	var pad_label := Label3D.new()
	pad_label.text = "刷怪点"
	pad_label.font_size = 64
	pad_label.position = pad + Vector3(0, 2.2, 0)
	pad_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(pad_label)
	var title := Label3D.new()
	title.text = "训练场"
	title.font_size = 96
	title.position = Vector3(MAP_SIZE / 2.0, 3.4, 2.0)
	add_child(title)


# 射击场（现实靶场式）：一个射击点，4 条横向展开的靶道，各道假人 5/10/15/20m
func _build_shooting_range() -> void:
	var start := Vector3(14.0, 0.0, 64.0)
	# 射击点标记
	_add_box(start + Vector3(0, 0.04, 0), Vector3(1.6, 0.08, 1.6), Color(0.9, 0.75, 0.2))
	var start_label := Label3D.new()
	start_label.text = "射击点"
	start_label.font_size = 64
	start_label.position = start + Vector3(0, 2.2, 0)
	start_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(start_label)
	# 每条靶道：横向 x 偏移 + 纵深距离
	var lanes := [
		{"d": 5, "x": -7.5},
		{"d": 10, "x": -2.5},
		{"d": 15, "x": 2.5},
		{"d": 20, "x": 7.5},
	]
	for lane in lanes:
		var pos := start + Vector3(float(lane["x"]), 0, -float(lane["d"]))
		# 从射击点到靶子的引导线
		var mid := (start + pos) / 2.0
		var dir: Vector3 = pos - start
		var guide_len := dir.length()
		var guide := _add_box(
			mid + Vector3(0, 0.02, 0), Vector3(0.12, 0.04, guide_len), Color(0.5, 0.5, 0.45)
		)
		guide.rotation.y = atan2(dir.x, dir.z)
		var target = TRAINING_TARGET_SCENE.instantiate()
		add_child(target)
		target.global_position = pos
		var label := Label3D.new()
		label.text = "%dm" % int(lane["d"])
		label.font_size = 72
		label.position = pos + Vector3(0, 2.2, 1.2)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)


func _add_box(center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	body.position = center
	add_child(body)
	return body


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector3(MAP_SIZE / 2.0, 0.1, MAP_SIZE - 8.0)
	add_child(_player)


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelContainer.new()
	# 左上角紧凑面板：阵营下拉 + 单位下拉，整体始终在屏幕内
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 12.0
	_panel.offset_top = 12.0
	layer.add_child(_panel)
	# 左右两栏：左边召唤 + 技能/属性，右边变异调整
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	_panel.add_child(columns)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	columns.add_child(box)

	var title := Label.new()
	title.text = "单位召唤（固定刷怪点生成）"
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)

	var faction_label := Label.new()
	faction_label.text = "阵营"
	faction_label.add_theme_font_size_override("font_size", 11)
	box.add_child(faction_label)
	_faction_option = OptionButton.new()
	_faction_option.custom_minimum_size = Vector2(280, 30)
	_faction_option.add_item("丧尸阵营", 0)
	_faction_option.add_item("人类阵营", 1)
	_faction_option.item_selected.connect(_on_faction_selected)
	box.add_child(_faction_option)

	var unit_label := Label.new()
	unit_label.text = "单位（下拉选择）"
	unit_label.add_theme_font_size_override("font_size", 11)
	box.add_child(unit_label)
	_unit_option = OptionButton.new()
	_unit_option.custom_minimum_size = Vector2(280, 30)
	_unit_option.clip_contents = true
	box.add_child(_unit_option)

	var summon := Button.new()
	summon.text = "召唤所选单位"
	summon.pressed.connect(_on_summon_pressed)
	box.add_child(summon)

	var clear := Button.new()
	clear.text = "清空所有已召唤单位"
	clear.pressed.connect(_clear_units)
	box.add_child(clear)

	var sep := HSeparator.new()
	box.add_child(sep)

	# 右栏：能力 / 变异调整（下拉切换类别）
	var vsep := VSeparator.new()
	columns.add_child(vsep)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)

	var mut_title := Label.new()
	mut_title.text = "能力 / 变异调整（- / + 等级，SP 9999）"
	mut_title.add_theme_font_size_override("font_size", 14)
	right.add_child(mut_title)

	_category_option = OptionButton.new()
	_category_option.custom_minimum_size = Vector2(310, 30)
	_category_option.add_item("技能", 0)
	_category_option.add_item("属性", 1)
	_category_option.add_item("玩家变异", 2)
	_category_option.add_item("丧尸变异", 3)
	_category_option.item_selected.connect(_on_category_selected)
	right.add_child(_category_option)

	var no_cd_check := CheckBox.new()
	no_cd_check.text = "技能无 CD（右键特殊技能可连续释放）"
	no_cd_check.button_pressed = GameState.no_skill_cd
	no_cd_check.toggled.connect(func(on: bool) -> void: GameState.no_skill_cd = on)
	right.add_child(no_cd_check)

	var mut_scroll := ScrollContainer.new()
	mut_scroll.custom_minimum_size = Vector2(310, 480)
	right.add_child(mut_scroll)
	var mut_list := VBoxContainer.new()
	mut_list.add_theme_constant_override("separation", 4)
	mut_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mut_scroll.add_child(mut_list)

	for skill in GameState.SKILLS:
		var row := _ability_row(String(skill["id"]), String(skill["name"]), "skill")
		mut_list.add_child(row)
		_ability_rows.append({"row": row, "cat": 0})
	for id in GameState.ATTRS.keys():
		var row := _ability_row(String(id), String(GameState.ATTRS[id]["name"]), "attr")
		mut_list.add_child(row)
		_ability_rows.append({"row": row, "cat": 1})
	for id in GameState.MUTATIONS.keys():
		var row := _ability_row(String(id), String(GameState.MUTATIONS[id]["name"]), "mutation")
		mut_list.add_child(row)
		_ability_rows.append({"row": row, "cat": 2})
	for id in GameState.ZOMBIE_MUTATIONS.keys():
		var row := _ability_row(String(id), String(GameState.ZOMBIE_MUTATIONS[id]["name"]), "mutation")
		mut_list.add_child(row)
		_ability_rows.append({"row": row, "cat": 3})

	_on_category_selected(0)
	_refresh_ability_panel()
	_panel.visible = false
	_refresh_unit_options()


# 一行能力调整：[名字] [-] [等级] [+]，kind 为 skill / attr / mutation
func _ability_row(id: String, label_text: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(name_label)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(30, 26)
	row.add_child(minus)
	var level_label := Label.new()
	level_label.custom_minimum_size = Vector2(90, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(level_label)
	_ability_labels["%s:%s" % [kind, id]] = {"label": level_label, "kind": kind, "id": id}
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(30, 26)
	row.add_child(plus)
	match kind:
		"skill":
			minus.pressed.connect(_adjust_skill.bind(id, -1))
			plus.pressed.connect(_adjust_skill.bind(id, 1))
		"attr":
			minus.pressed.connect(_adjust_attr.bind(id, -1))
			plus.pressed.connect(_adjust_attr.bind(id, 1))
		"mutation":
			minus.pressed.connect(_adjust_mutation.bind(id, -1))
			plus.pressed.connect(_adjust_mutation.bind(id, 1))
	return row


func _adjust_skill(id: String, delta: int) -> void:
	var level := clampi(GameState.skill_level(id) + delta, 0, GameState.skill_max(id))
	GameState.skills[id] = level
	GameState.skills_changed.emit()
	_refresh_ability_panel()


func _adjust_attr(id: String, delta: int) -> void:
	GameState.attrs[id] = maxi(0, GameState.attr_level(id) + delta)
	GameState.skills_changed.emit()
	_refresh_ability_panel()


# 下拉切换调整类别：技能 / 属性 / 玩家变异 / 丧尸变异
func _on_category_selected(index: int) -> void:
	for entry in _ability_rows:
		(entry["row"] as Control).visible = int(entry["cat"]) == index


func _adjust_mutation(id: String, delta: int) -> void:
	var level := clampi(
		int(GameState.mutation_levels.get(id, 0)) + delta, 0, GameState.MUTATION_MAX_RANK
	)
	GameState.mutation_levels[id] = level
	GameState.mutations_changed.emit()
	_refresh_ability_panel()


func _refresh_ability_panel() -> void:
	for key in _ability_labels.keys():
		var entry: Dictionary = _ability_labels[key]
		var kind := String(entry["kind"])
		var id := String(entry["id"])
		var level := 0
		var suffix := ""
		match kind:
			"skill":
				level = GameState.skill_level(id)
				suffix = " / %d" % GameState.skill_max(id)
			"attr":
				level = GameState.attr_level(id)
			"mutation":
				level = int(GameState.mutation_levels.get(id, 0))
				suffix = " / %d" % GameState.MUTATION_MAX_RANK
		(entry["label"] as Label).text = "Lv.%d%s" % [level, suffix]


func _faction_kind() -> String:
	return "human" if _faction_option.selected == 1 else "zombie"


func _on_faction_selected(_index: int) -> void:
	_refresh_unit_options()


func _refresh_unit_options() -> void:
	_unit_option.clear()
	var kind := _faction_kind()
	for tier in range(1, 11):
		var info: Dictionary = (
			GameState.human_tier_info(tier) if kind == "human" else GameState.zombie_tier_info(tier)
		)
		if info.is_empty():
			continue
		_unit_option.add_item(
			"%d %s HP%d 伤%d" % [tier, String(info["name"]), int(info["hp"]), int(info["damage"])],
			tier
		)


func _on_summon_pressed() -> void:
	var tier := _unit_option.get_selected_id()
	if tier <= 0:
		return
	_summon(_faction_kind(), tier)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		_panel.visible = not _panel.visible
		GameState.custom_panel_open = _panel.visible
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
		)


# ESC 经 GameState.close_all_panels 转到这里：优先关闭召唤面板而不是开暂停菜单
func _close_panel() -> void:
	_panel.visible = false
	GameState.custom_panel_open = false


func _summon(kind: String, tier: int) -> void:
	var pos := _spawn_point()
	var unit: Node3D
	var info: Dictionary
	if kind == "human":
		unit = NPC_SCENE.instantiate()
		unit.human_tier = tier
		info = GameState.human_tier_info(tier)
	else:
		unit = ZOMBIE_SCENE.instantiate()
		unit.zombie_tier = tier
		info = GameState.zombie_tier_info(tier)
	add_child(unit)
	unit.global_position = pos
	_units.append(unit)
	GameState.notify("已召唤：%s（%d/%d 个在场）" % [String(info["name"]), _alive_count(), _units.size()])


# 固定刷怪点：场地中央的召唤平台，不再跟随准星
func _spawn_point() -> Vector3:
	return Vector3(MAP_SIZE / 2.0, 0.1, MAP_SIZE / 2.0 - 10.0)


func _aim_point() -> Vector3:
	if _player != null and is_instance_valid(_player):
		var camera: Camera3D = _player.get_node_or_null("Camera3D")
		if camera != null:
			var origin := camera.global_position
			var dir := -camera.global_transform.basis.z
			if dir.y < -0.05:
				var hit := origin + dir * (origin.y / -dir.y)
				if origin.distance_to(hit) <= 60.0:
					return _clamp_to_arena(Vector3(hit.x, 0.1, hit.z))
			var forward := -_player.global_transform.basis.z
			forward.y = 0.0
			return _clamp_to_arena(_player.global_position + forward.normalized() * 8.0)
	return Vector3(MAP_SIZE / 2.0, 0.1, MAP_SIZE / 2.0)


func _clamp_to_arena(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, 2.0, MAP_SIZE - 2.0), pos.y, clampf(pos.z, 2.0, MAP_SIZE - 2.0))


func _alive_count() -> int:
	var count := 0
	for unit in _units:
		if is_instance_valid(unit):
			count += 1
	return count


func _clear_units() -> void:
	for unit in _units:
		if is_instance_valid(unit):
			unit.queue_free()
	_units.clear()
	GameState.notify("已清空所有召唤单位")
