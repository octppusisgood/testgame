extends Node3D
# 系统空间（2.5D）：局外中枢——入口（进城市）/ 基因库 / 商城 / 交易所 / 强化仓。
# 轻量小玩家（WASD 行走 + 正交俯视相机），走近设施按 E 打开对应面板。
# 替代旧观测舱（hub3d 的全按钮界面），撤离/死亡后回到这里。


const WALK_SPEED := 5.0
const INTERACT_RANGE := 3.2

var _player: CharacterBody3D
var _cam: Camera3D
var _points: Array = []
var _near_point: Dictionary = {}
var _hint_label: Label3D = null
var _panel: Control = null
var _panel_kind := ""
var _energy_label: Label
var _tree_rows := {}


func _ready() -> void:
	print("SYSTEM_SPACE: _ready fired")
	GameState.load_meta()
	if GameState.spawn_point_override == Vector2.ZERO:
		GameState.spawn_point_override = Vector2(3036, 1960)
	_build_world()
	_build_player()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_update_near_point()
	if _energy_label != null:
		_energy_label.text = "SP：%d" % GameState.space_energy


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and not _panel_kind.is_empty():
			pass
		if event.keycode == KEY_ESCAPE and not _panel_kind.is_empty():
			close_panel()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E and _panel_kind.is_empty() and not _near_point.is_empty():
		open_panel(String(_near_point["kind"]))
		get_viewport().set_input_as_handled()


# ————————————————— 世界搭建 —————————————————

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 1.0
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.9
	add_child(sun)

	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	add_child(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)
	var floor_mesh := MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(60, 1, 40)
	floor_mesh.mesh = fbox
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.13, 0.15, 0.2)
	floor_mesh.material_override = fmat
	floor_body.add_child(floor_mesh)

	_hint_label = Label3D.new()
	_hint_label.font_size = 44
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.modulate = Color(1.0, 0.9, 0.5)
	_hint_label.visible = false
	add_child(_hint_label)

	# 五个设施：入口 / 基因库 / 商城 / 交易所 / 强化仓
	_add_station("exit", "城市入口", Vector3(0, 0, -12), Color(0.95, 0.75, 0.3))
	_add_station("gene", "基因库", Vector3(-18, 0, 4), Color(0.5, 0.95, 0.7))
	_add_station("shop", "蓝图商城", Vector3(-9, 0, 8), Color(0.55, 0.75, 1.0))
	_add_station("trade", "交易所", Vector3(9, 0, 8), Color(1.0, 0.6, 0.4))
	_add_station("train", "强化仓", Vector3(18, 0, 4), Color(0.85, 0.55, 1.0))


func _add_station(kind: String, title: String, pos: Vector3, color: Color) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.6, 1.2, 3.6)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.55)
	body.material_override = mat
	body.position = Vector3(0, 0.6, 0)
	root.add_child(body)
	var cap := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(4.0, 0.25, 4.0)
	cap.mesh = cap_box
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = color
	cap_mat.emission_enabled = true
	cap_mat.emission = color
	cap_mat.emission_energy_multiplier = 0.6
	cap.material_override = cap_mat
	cap.position = Vector3(0, 1.3, 0)
	root.add_child(cap)
	var label := Label3D.new()
	label.text = title
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = Vector3(0, 2.6, 0)
	root.add_child(label)
	_points.append({"kind": kind, "title": title, "pos": pos, "label": label})


func _build_player() -> void:
	_player = CharacterBody3D.new()
	add_child(_player)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	_player.add_child(col)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.8, 1.0)
	body.material_override = mat
	body.position = Vector3(0, 0.85, 0)
	_player.add_child(body)
	_player.position = Vector3(0, 0.2, 0)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 16.0
	_cam.rotation_degrees = Vector3(-55, 0, 0)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, 0.0)
	_player.velocity.x = dir.x * WALK_SPEED
	_player.velocity.z = dir.z * WALK_SPEED
	if not _player.is_on_floor():
		_player.velocity.y -= 18.0 * delta
	_player.move_and_slide()
	if _cam != null:
		_cam.position = _player.global_position + Vector3(0, 12, 8)


func _update_near_point() -> void:
	_near_point = {}
	var best := INTERACT_RANGE
	for pt in _points:
		var d: float = _player.global_position.distance_to(Vector3(pt["pos"].x, _player.global_position.y, pt["pos"].z))
		if d < best:
			best = d
			_near_point = pt
	if _panel_kind.is_empty() and not _near_point.is_empty():
		_hint_label.visible = true
		_hint_label.global_position = _player.global_position + Vector3(0, 2.2, 0)
		_hint_label.text = "按 E：%s" % String(_near_point["title"])
	else:
		_hint_label.visible = false


# ————————————————— UI 面板 —————————————————

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var title := Label.new()
	title.text = "回响之城 · 系统空间"
	title.position = Vector2(20, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	root.add_child(title)
	_energy_label = Label.new()
	_energy_label.position = Vector2(20, 38)
	_energy_label.add_theme_font_size_override("font_size", 14)
	_energy_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	root.add_child(_energy_label)
	var hint := Label.new()
	hint.text = "WASD 走动 · 走近设施按 E 交互 · Esc 关闭面板"
	hint.position = Vector2(20, 60)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	root.add_child(hint)
	_panel = root


func open_panel(kind: String) -> void:
	close_panel()
	_panel_kind = kind
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match kind:
		"exit":
			_panel_exit()
		"gene":
			_panel_gene()
		"shop":
			_panel_shop()
		"trade":
			_panel_trade()
		"train":
			_panel_train()


func close_panel() -> void:
	_panel_kind = ""
	if _panel == null or not is_instance_valid(_panel):
		return
	for child in _panel.get_children():
		if child.name.begins_with("PANEL"):
			child.queue_free()
	_tree_rows.clear()


func _make_panel_frame(title_text: String) -> Control:
	var dim := ColorRect.new()
	dim.name = "PANEL_DIM"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(dim)
	var frame := PanelContainer.new()
	frame.name = "PANEL_FRAME"
	var center := CenterContainer.new()
	center.name = "PANEL_CENTER"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	center.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	frame.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	box.add_child(title)
	var close := Button.new()
	close.text = "关闭（Esc）"
	close.pressed.connect(close_panel)
	box.add_child(close)
	return box


func _panel_exit() -> void:
	var box := _make_panel_frame("城市入口 · 进入本局")
	var tip := Label.new()
	tip.text = "离开系统空间进入城市。当前观测点：出生点由城内默认位置决定。"
	tip.add_theme_font_size_override("font_size", 12)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)
	var go := Button.new()
	go.text = "进入城市"
	go.custom_minimum_size = Vector2(200, 36)
	go.pressed.connect(_enter_world)
	box.add_child(go)
	# SP 面板中买好的技能树会自动带上（gun_tree_levels 局内生效）


func _panel_gene() -> void:
	var box := _make_panel_frame("基因库 · 幸存者档案")
	if GameState.gene_pool.is_empty():
		var empty := Label.new()
		empty.text = "还没有存入的 NPC——局内招募的随从在撤离时会自动登记入库。"
		empty.add_theme_font_size_override("font_size", 12)
		empty.modulate = Color(0.8, 0.85, 0.9)
		box.add_child(empty)
		return
	for person in GameState.gene_pool:
		var row := Label.new()
		row.text = "· %s（%s）%s" % [
			String(person.get("name", "?")),
			String(person.get("role", "市民")),
			String(person.get("note", "")),
		]
		row.add_theme_font_size_override("font_size", 12)
		box.add_child(row)


func _panel_shop() -> void:
	var box := _make_panel_frame("蓝图商城（SP 解锁，永久有效）")
	for key in GameState.SHOP.keys():
		var item: Dictionary = GameState.SHOP[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = String(item.get("name", key))
		name_label.custom_minimum_size = Vector2(180, 0)
		name_label.add_theme_font_size_override("font_size", 12)
		row.add_child(name_label)
		var btn := Button.new()
		var owned: bool = String(key) == "revival_stone" and GameState.revival_stone
		if String(key) in ["suppressor", "scope_rds", "scope_2x", "scope_4x", "scope_8x"]:
			owned = int(GameState.meta_supplies.get(String(key), 0)) > 0
		elif String(key) in GameState.meta_weapons.keys():
			owned = int(GameState.meta_weapons[String(key)]) > 0
		btn.text = ("已解锁" if owned else "SP %d" % int(item.get("cost", 0)))
		btn.disabled = owned
		var k := String(key)
		btn.pressed.connect(func() -> void:
			if GameState.buy_shop_item(k):
				GameState.notify("蓝图已解锁：%s" % String(item.get("name", k)))
				close_panel()
				open_panel("shop")
		)
		row.add_child(btn)


func _panel_trade() -> void:
	var box := _make_panel_frame("交易所 · 战绩与结余")
	var stats: Dictionary = GameState.meta_stats if "meta_stats" in GameState else {}
	for line in [
		"系统点数（SP）：%d" % GameState.space_energy,
		"出战次数：%d · 完成轮回：%d" % [
			int(stats.get("runs", 0)) if not stats.is_empty() else int(GameState.war_runs if "war_runs" in GameState else 0),
			int(stats.get("clears", 0)) if not stats.is_empty() else 0,
		],
		"局内撤离时带回的物资已按 1:1 自动折算为 SP（观测舱结算规则不变）。",
	]:
		var row := Label.new()
		row.text = line
		row.add_theme_font_size_override("font_size", 12)
		box.add_child(row)


func _panel_train() -> void:
	var box := _make_panel_frame("强化仓 · 枪械技能树（当局生效，逐层解锁）")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 300)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in GameState.GUN_TREE.size():
		var node: Dictionary = GameState.GUN_TREE[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var idx_label := Label.new()
		idx_label.text = "L%d" % (i + 1)
		idx_label.custom_minimum_size = Vector2(30, 0)
		idx_label.add_theme_font_size_override("font_size", 12)
		row.add_child(idx_label)
		var info := Label.new()
		info.text = "%s  %s" % [String(node["name"]), String(node["desc"])]
		info.custom_minimum_size = Vector2(230, 0)
		info.add_theme_font_size_override("font_size", 12)
		row.add_child(info)
		var btn := Button.new()
		var bought := GameState.gun_tree_levels > i
		var locked := GameState.gun_tree_levels < i
		if bought:
			btn.text = "已激活"
			btn.disabled = true
		elif locked:
			btn.text = "需先解锁 L%d" % i
			btn.disabled = true
		else:
			btn.text = "SP %d" % int(node["cost"])
			btn.disabled = GameState.space_energy < int(node["cost"])
		var idx := i
		btn.pressed.connect(func() -> void:
			var cost := int(GameState.GUN_TREE[idx]["cost"])
			if GameState.spend_energy(cost):
				GameState.gun_tree_levels = idx + 1
				GameState.save_meta()
				GameState.notify("技能树 L%d 已激活：%s（本局生效）" % [idx + 1, String(GameState.GUN_TREE[idx]["name"])])
				close_panel()
				open_panel("train")
		)
		row.add_child(btn)
	var tip := Label.new()
	tip.text = "已激活 %d/10 层——进入城市后自动生效，本局结束清空。" % GameState.gun_tree_levels
	tip.add_theme_font_size_override("font_size", 11)
	tip.modulate = Color(0.8, 0.9, 0.8)
	box.add_child(tip)


func _enter_world() -> void:
	GameState.reset_run(false)
	_do_enter.call_deferred()


func _do_enter() -> void:
	get_tree().change_scene_to_file("res://scenes3d/proto3d.tscn")
