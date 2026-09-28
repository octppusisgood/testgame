extends Node3D

const ENDING_QUALIFIED := "合格"
const EGG_SECONDS := 300.0
const BRIEF_INTERVAL := 1.2
const BRIEFING := [
	"【收容所 · 观测员终端】",
	"巡检任务：观测目标城市「回响之城」的灾变全程，记录回响数据。",
	"",
	"请在左侧选择观测点（社区 / 商业中心 / 工业区）。",
	"协议第 7 条：观测员不得入场，不得干预，不得被知晓。",
	"终端备注：本舱段物资充足，等待也是一种工作。",
]


# 第 3 行是动态倒计时分钟数（基础 5 分钟 + 系统空间购买的提前入场）
func _briefing_lines() -> Array:
	var lines := BRIEFING.duplicate()
	lines[2] = "灾变预计于 %d 分钟后发生：异变雨。" % int(round(GameState.prep_duration() / 60.0))
	return lines
# 观测点出生区（2D 像素坐标，proto3d 按 WORLD_SCALE_3D 换算）
const POD_SPAWNS := {
	"起始社区": Vector2(3036, 1960),
	"商业中心": Vector2(6640, 1900),
	"工业区": Vector2(11000, 3700),
}

var _energy_label: Label
var _stats_label: Label
var _log_label: Label
var _terminal_label: Label
var _shop_buttons := {}
var _attr_buttons := {}
var _early_label: Label
var _early_button: Button
var _spawn_option: OptionButton
var _enter_dialog: ConfirmationDialog
var _holo: Node3D
var _pod_elapsed := 0.0
var _type_timer := 0.0
var _brief_index := 0
var _ending := false


func _ready() -> void:
	GameState.load_meta()
	if GameState.spawn_point_override == Vector2.ZERO:
		GameState.spawn_point_override = POD_SPAWNS["起始社区"]
	_build_room()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _process(delta: float) -> void:
	if _holo != null:
		_holo.rotation.y += delta * 0.5
	if _ending:
		return
	_pod_elapsed += delta
	_type_timer += delta
	if _brief_index < BRIEFING.size() and _type_timer >= BRIEF_INTERVAL:
		_type_timer = 0.0
		_brief_index += 1
		_terminal_label.text = "\n".join(_briefing_lines().slice(0, _brief_index))
	if _pod_elapsed >= EGG_SECONDS:
		_trigger_ending()


func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.7, 0.95)
	env.ambient_light_energy = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_box(Vector3(0, -0.1, 0), Vector3(20, 0.2, 20), Color(0.1, 0.13, 0.18))
	_box(Vector3(0, 3, -10), Vector3(20, 6, 0.4), Color(0.14, 0.18, 0.26))
	_box(Vector3(0, 3, 10), Vector3(20, 6, 0.4), Color(0.14, 0.18, 0.26))
	_box(Vector3(-10, 3, 0), Vector3(0.4, 6, 20), Color(0.14, 0.18, 0.26))
	_box(Vector3(10, 3, 0), Vector3(0.4, 6, 20), Color(0.14, 0.18, 0.26))
	_box(Vector3(0, 0.6, -2.0), Vector3(3.0, 1.2, 1.4), Color(0.16, 0.3, 0.42))
	_box(Vector3(-4, 0.6, 1.5), Vector3(1.6, 1.2, 1.6), Color(0.22, 0.26, 0.34))
	_box(Vector3(-5.5, 0.5, 2.5), Vector3(1.2, 1.0, 1.2), Color(0.2, 0.23, 0.3))
	_box(Vector3(4.5, 0.7, 1.2), Vector3(1.8, 1.4, 1.2), Color(0.18, 0.22, 0.3))
	# 观察窗：整面发光玻璃，透出冷蓝色虚空
	_glow_box(Vector3(0, 3.0, -9.75), Vector3(14, 3.6, 0.1), Color(0.45, 0.7, 1.0), 1.6)
	_glow_box(Vector3(0, 1.35, -2.0), Vector3(2.2, 0.3, 1.0), Color(0.4, 0.85, 1.0), 1.2)

	# 城市全息投影：控制台上缓慢旋转的楼群剪影
	_holo = Node3D.new()
	_holo.position = Vector3(0, 1.7, -2.0)
	add_child(_holo)
	for i in 12:
		var gx := float(i % 4 - 1) * 0.42
		var gz := float(i / 4 - 1) * 0.42
		var h := 0.12 + float((i * 37) % 5) * 0.09
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, h, 0.16)
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.75, 0.95, 0.8)
		material.emission_enabled = true
		material.emission = Color(0.3, 0.75, 0.95)
		material.emission_energy_multiplier = 1.5
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = material
		mesh.position = Vector3(gx, h * 0.5, gz)
		_holo.add_child(mesh)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.6, 5.0)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	add_child(camera)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 5, 2)
	light.light_energy = 1.4
	light.light_color = Color(0.75, 0.85, 1.0)
	light.omni_range = 20.0
	add_child(light)


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _glow_box(pos: Vector3, size: Vector3, color: Color, energy: float) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)


func _make_button(text: String, handler: Callable, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(handler)
	return button


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.02, 0.06, 0.28)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var title := Label.new()
	title.text = "观测舱 · 回响之城观测站"
	title.position = Vector2(24, 12)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	root.add_child(title)

	_energy_label = Label.new()
	_energy_label.position = Vector2(24, 42)
	_energy_label.add_theme_font_size_override("font_size", 14)
	_energy_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	root.add_child(_energy_label)

	_stats_label = Label.new()
	_stats_label.position = Vector2(24, 62)
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	root.add_child(_stats_label)

	var spawn_label := Label.new()
	spawn_label.text = "观测点："
	spawn_label.position = Vector2(24, 86)
	spawn_label.add_theme_font_size_override("font_size", 12)
	spawn_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	root.add_child(spawn_label)
	_spawn_option = OptionButton.new()
	_spawn_option.position = Vector2(86, 82)
	_spawn_option.custom_minimum_size = Vector2(140, 24)
	_spawn_option.add_theme_font_size_override("font_size", 12)
	for spawn_name in POD_SPAWNS.keys():
		_spawn_option.add_item(spawn_name)
	_spawn_option.item_selected.connect(_on_spawn_selected)
	root.add_child(_spawn_option)

	_terminal_label = Label.new()
	_terminal_label.position = Vector2(24, 116)
	_terminal_label.custom_minimum_size = Vector2(290, 120)
	_terminal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terminal_label.add_theme_font_size_override("font_size", 11)
	_terminal_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	root.add_child(_terminal_label)

	_log_label = Label.new()
	_log_label.position = Vector2(24, 292)
	_log_label.add_theme_font_size_override("font_size", 11)
	_log_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	root.add_child(_log_label)
	GameState.notified.connect(_on_notified)

	var enter := Button.new()
	enter.text = "进入世界"
	enter.position = Vector2(24, 316)
	enter.custom_minimum_size = Vector2(230, 32)
	enter.add_theme_font_size_override("font_size", 14)
	enter.pressed.connect(_on_enter_pressed)
	root.add_child(enter)

	var sell := Button.new()
	sell.text = "出售杂物与贵重品"
	sell.position = Vector2(266, 316)
	sell.custom_minimum_size = Vector2(150, 32)
	sell.add_theme_font_size_override("font_size", 12)
	sell.pressed.connect(_sell_junk)
	root.add_child(sell)

	var back := Button.new()
	back.text = "返回主菜单"
	back.position = Vector2(428, 316)
	back.custom_minimum_size = Vector2(110, 32)
	back.add_theme_font_size_override("font_size", 12)
	back.pressed.connect(_back_to_menu)
	root.add_child(back)

	_enter_dialog = ConfirmationDialog.new()
	_enter_dialog.title = "观测协议警告"
	_enter_dialog.dialog_text = (
		"离开观测舱将违反观测协议。确认进入？\n"
		+ "协议要求卸下随身物品（违规携带仅作提示，不强制）。"
	)
	_enter_dialog.ok_button_text = "确认进入"
	_enter_dialog.cancel_button_text = "再想想"
	_enter_dialog.confirmed.connect(_confirm_enter_world)
	root.add_child(_enter_dialog)

	var shop_title := Label.new()
	shop_title.text = "观测舱补给"
	shop_title.position = Vector2(330, 12)
	shop_title.add_theme_font_size_override("font_size", 14)
	shop_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	root.add_child(shop_title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(330, 34)
	scroll.custom_minimum_size = Vector2(150, 268)
	scroll.size = Vector2(150, 268)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(box)
	for key in GameState.SHOP.keys():
		var button := _make_button("", _buy.bind(String(key)), Vector2(136, 24))
		box.add_child(button)
		_shop_buttons[String(key)] = button

	var attr_title := Label.new()
	attr_title.text = "属性强化"
	attr_title.position = Vector2(494, 12)
	attr_title.add_theme_font_size_override("font_size", 14)
	attr_title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	root.add_child(attr_title)

	var attr_box := VBoxContainer.new()
	attr_box.position = Vector2(494, 34)
	attr_box.add_theme_constant_override("separation", 3)
	attr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(attr_box)
	for id in GameState.ATTRS.keys():
		var info: Dictionary = GameState.ATTRS[id]
		var button := _make_button("", _buy_attr.bind(String(id)), Vector2(140, 24))
		button.tooltip_text = String(info["desc"])
		attr_box.add_child(button)
		_attr_buttons[String(id)] = button

	_early_label = Label.new()
	_early_label.position = Vector2(494, 196)
	_early_label.add_theme_font_size_override("font_size", 12)
	_early_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	root.add_child(_early_label)
	_early_button = _make_button("", _buy_early, Vector2(140, 26))
	_early_button.position = Vector2(494, 216)
	root.add_child(_early_button)


func _on_notified(text: String) -> void:
	_log_label.text = text


func _on_spawn_selected(index: int) -> void:
	var spawn_name := _spawn_option.get_item_text(index)
	GameState.spawn_point_override = POD_SPAWNS[spawn_name]
	_terminal_hint("观测点已设定：%s" % spawn_name)


func _terminal_hint(text: String) -> void:
	_brief_index = BRIEFING.size()
	_terminal_label.text = "\n".join(_briefing_lines()) + "\n> " + text


func _buy(id: String) -> void:
	GameState.buy_shop_item(id)
	_refresh()


func _buy_attr(id: String) -> void:
	GameState.buy_attr(id)
	_refresh()


func _buy_early() -> void:
	GameState.buy_early_entry()
	_refresh()


func _refresh() -> void:
	_energy_label.text = "SP：%d" % GameState.space_energy
	_stats_label.text = (
		"强化点 %d · 出战 %d 次 · 完成轮回 %d 次 · 结局 %d 个"
		% [
			GameState.skill_points,
			GameState.runs_played,
			GameState.extractions,
			GameState.endings_seen.size(),
		]
	)
	for key in _shop_buttons.keys():
		var button: Button = _shop_buttons[key]
		var info: Dictionary = GameState.SHOP[key]
		button.text = "%s — %d SP" % [info["name"], info["cost"]]
		if key in ["pistol", "shotgun", "rifle", "smg", "sniper", "lmg", "grenade", "rpg"]:
			var owned: bool = int(GameState.meta_weapons.get(key, 0)) > 0
			button.disabled = owned
			if owned:
				button.text = "%s（已解锁）" % info["name"]
			elif GameState.space_energy < int(info["cost"]):
				button.disabled = true
		elif key == "revival_stone":
			button.disabled = GameState.revival_stone
			if GameState.revival_stone:
				button.text = "%s（已持有）" % info["name"]
			elif GameState.space_energy < int(info["cost"]):
				button.disabled = true
		else:
			button.disabled = GameState.space_energy < int(info["cost"])
	for id in _attr_buttons.keys():
		var button: Button = _attr_buttons[id]
		var info: Dictionary = GameState.ATTRS[id]
		var level := GameState.attr_level(id)
		var cost := GameState.attr_cost(level)
		button.text = "%s Lv.%d — %d SP" % [String(info["name"]), level, cost]
		button.disabled = GameState.space_energy < cost
	var next := GameState.next_early_entry()
	_early_label.text = "提前入场：+%d 分钟" % GameState.early_entry
	if next <= 0:
		_early_button.text = "已达上限（+%d 分钟）" % GameState.EARLY_ENTRY_MAX
		_early_button.disabled = true
	else:
		var cost := GameState.early_entry_cost()
		_early_button.text = "→ +1 分钟（共 +%d）— %d SP" % [next, cost]
		_early_button.disabled = GameState.space_energy < cost
	for i in _spawn_option.item_count:
		if POD_SPAWNS[_spawn_option.get_item_text(i)] == GameState.spawn_point_override:
			_spawn_option.select(i)
			break


func _on_enter_pressed() -> void:
	_enter_dialog.popup_centered()


func _confirm_enter_world() -> void:
	GameState.enter_city()


func _sell_junk() -> void:
	GameState.sell_junk()
	_refresh()


func _back_to_menu() -> void:
	GameState.save_meta()
	get_tree().change_scene_to_file("res://scenes3d/menu3d.tscn")


# 彩蛋结局「合格」：全程留在观测舱、从未进入世界
func _trigger_ending() -> void:
	if _ending:
		return
	_ending = true
	if not GameState.endings_seen.has(ENDING_QUALIFIED):
		GameState.endings_seen.append(ENDING_QUALIFIED)
	GameState.save_meta()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 1.0)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "观测完成"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var body := Label.new()
	body.text = "城市已毁灭，无人知晓。\n你履行了观测员的职责，仅此而已。"
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)

	var record := Label.new()
	record.text = "—— 结局「%s」已记录" % ENDING_QUALIFIED
	record.add_theme_font_size_override("font_size", 12)
	record.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(record)

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes3d/menu3d.tscn")
