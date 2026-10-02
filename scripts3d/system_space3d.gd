extends Node3D
# 系统空间（批次 222 重写）：局外中枢。
# 大厅 + 4 个设施点（进城市/商城/基因库/强化仓），WASD 走动，走近按 E 开面板。
# 刻意保持简单：无定时器、无延迟切场景、无联机依赖、无自动进城逻辑。

const WALK_SPEED := 5.0
const INTERACT_RANGE := 3.0
const CAM_OFFSET := Vector3(0, 9.0, 7.5)

const STATIONS := [
	{"kind": "enter", "name": "进入城市", "pos": Vector3(0, 0, -7), "color": Color(0.4, 0.9, 0.6)},
	{"kind": "shop", "name": "商城", "pos": Vector3(-7, 0, 0), "color": Color(0.95, 0.8, 0.3)},
	{"kind": "gene", "name": "基因库", "pos": Vector3(7, 0, 0), "color": Color(0.7, 0.5, 0.95)},
	{"kind": "train", "name": "强化仓", "pos": Vector3(0, 0, 7), "color": Color(0.4, 0.7, 1.0)},
]

var _player: CharacterBody3D
var _cam: Camera3D
var _near := ""
var _hint: Label3D = null
var _panel: Control = null
var _panel_layer: CanvasLayer = null
var _energy_label: Label = null


func _ready() -> void:
	GameState.load_meta()
	_build_room()
	_build_stations()
	_build_player()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# —— 大厅 ——

func _build_room() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.7, 0.9)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# 地面
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.08, 0.1, 0.14)
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40, 0.1, 40)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	add_child(floor_body)


func _build_stations() -> void:
	for st in STATIONS:
		var root := Node3D.new()
		root.name = "Station_%s" % String(st["kind"])
		root.position = st["pos"]
		add_child(root)
		# 底座
		var base := MeshInstance3D.new()
		var base_box := BoxMesh.new()
		base_box.size = Vector3(1.6, 0.3, 1.6)
		base.mesh = base_box
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = (st["color"] as Color).darkened(0.5)
		base.material_override = base_mat
		base.position.y = 0.15
		root.add_child(base)
		# 信标柱（发光）
		var beacon := MeshInstance3D.new()
		var beacon_box := BoxMesh.new()
		beacon_box.size = Vector3(0.4, 1.2, 0.4)
		beacon.mesh = beacon_box
		var beacon_mat := StandardMaterial3D.new()
		beacon_mat.albedo_color = st["color"]
		beacon_mat.emission_enabled = true
		beacon_mat.emission = st["color"]
		beacon_mat.emission_energy_multiplier = 1.6
		beacon.material_override = beacon_mat
		beacon.position.y = 0.9
		root.add_child(beacon)
		# 名称牌
		var label := Label3D.new()
		label.text = String(st["name"])
		label.font_size = 28
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = st["color"]
		label.outline_size = 10
		label.outline_modulate = Color(0, 0, 0, 0.9)
		label.position = Vector3(0, 1.9, 0)
		root.add_child(label)


# —— 玩家与相机 ——

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "HubPlayer"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	_player.add_child(shape)
	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.6, 1.4, 0.4)
	body.mesh = body_box
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.6, 0.75)
	body.material_override = body_mat
	body.position.y = 0.7
	_player.add_child(body)
	_player.position = Vector3(0, 0.2, 3)
	add_child(_player)
	_cam = Camera3D.new()
	_cam.current = true
	add_child(_cam)
	_update_camera(0.0)


func _update_camera(_delta: float) -> void:
	var target := _player.global_position + CAM_OFFSET
	_cam.global_position = _cam.global_position.lerp(target, 0.15)
	_cam.look_at(_player.global_position + Vector3(0, 1.0, 0), Vector3.UP)


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	_player.velocity.x = dir.x * WALK_SPEED
	_player.velocity.z = dir.z * WALK_SPEED
	_player.velocity.y -= 9.8 * delta
	_player.move_and_slide()
	_update_camera(delta)


# —— UI 与交互 ——

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_energy_label = Label.new()
	_energy_label.position = Vector2(12, 8)
	_energy_label.add_theme_font_size_override("font_size", 12)
	_energy_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	layer.add_child(_energy_label)
	_hint = Label3D.new()
	_hint.font_size = 28
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.modulate = Color(1.0, 1.0, 0.85)
	_hint.outline_size = 10
	_hint.outline_modulate = Color(0, 0, 0, 0.9)
	_hint.visible = false
	add_child(_hint)


func _process(_delta: float) -> void:
	if _energy_label != null:
		_energy_label.text = "SP：%d" % GameState.space_energy
	# 最近的设施点
	var best := ""
	var best_d := INTERACT_RANGE
	for st in STATIONS:
		var d: float = _player.global_position.distance_to((st["pos"] as Vector3))
		if d < best_d:
			best_d = d
			best = String(st["kind"])
	if best != _near:
		_near = best
		if _near == "":
			_hint.visible = false
		else:
			var st := _station_of(_near)
			_hint.text = "%s · 按 E 打开" % String(st["name"])
			_hint.visible = true
	if _near != "":
		_hint.global_position = _player.global_position + Vector3(0, 2.4, 0)


func _station_of(kind: String) -> Dictionary:
	for st in STATIONS:
		if String(st["kind"]) == kind:
			return st
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE and _panel != null:
		_close_panel()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_E:
		if _panel != null:
			_close_panel()
		elif _near != "":
			_open_panel(_near)
		get_viewport().set_input_as_handled()


# —— 面板 ——

func _open_panel(kind: String) -> void:
	_close_panel()
	# 暗色遮罩 + 居中面板（640×360 逻辑视口内）
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_panel_layer = layer
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(280, 0)
	center.add_child(frame)
	_panel = frame
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)
	var title := Label.new()
	title.text = String(_station_of(kind).get("name", kind))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	box.add_child(title)
	# 内容滚动区（显式高度：ScrollContainer 不会向父级申报内容高度，
	# 给 0 会被 VBox 压扁成 0——批次 224 商城「什么都没有」的根因）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 190)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	match kind:
		"enter":
			_build_enter_panel(content)
		"shop":
			_build_shop_panel(content)
		"gene":
			_build_gene_panel(content)
		"train":
			_build_train_panel(content)
	var close := Button.new()
	close.text = "关闭（Esc）"
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(_close_panel)
	box.add_child(close)


func _close_panel() -> void:
	if _panel_layer != null and is_instance_valid(_panel_layer):
		_panel_layer.queue_free()
	_panel_layer = null
	_panel = null


func _build_enter_panel(box: VBoxContainer) -> void:
	var btn := Button.new()
	btn.text = "进入城市（开始新的一局）"
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func() -> void:
		_close_panel()
		GameState.enter_city()
	)
	box.add_child(btn)


func _build_shop_panel(box: VBoxContainer) -> void:
	if not GameState.TRIAL_SHOP_OPEN:
		# 试玩版：商城整类暂闭（局外成长只开「枪械+身体属性」，都在强化仓）
		var note := Label.new()
		note.text = "试玩版：商城暂未开放（后续版本加入）\n局外成长请前往「强化仓」\n—— 枪械强化 / 身体属性 ——"
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)
		return
	for id in GameState.SHOP.keys():
		var info: Dictionary = GameState.SHOP[id]
		if info.has("panel"):
			continue  # 雇佣随从等分属其他设施
		var btn := Button.new()
		btn.text = "%s — %d SP" % [String(info["name"]), int(info["cost"])]
		btn.add_theme_font_size_override("font_size", 10)
		btn.disabled = GameState.space_energy < int(info["cost"])
		var key := String(id)
		btn.pressed.connect(func() -> void:
			if GameState.buy_shop_item(key):
				_close_panel()
				_open_panel("shop")
		)
		box.add_child(btn)


func _build_gene_panel(box: VBoxContainer) -> void:
	var relics: Dictionary = GameState.boss_relics
	var label := Label.new()
	if relics.is_empty():
		label.text = "还没有收集到 Boss 专属材料\n（击败守关 Boss 掉落，供后续解锁）"
	else:
		var lines: Array = []
		for name in relics.keys():
			lines.append("%s ×%d" % [String(name), int(relics[name])])
		label.text = "已收集 Boss 材料：\n" + "\n".join(lines)
	label.add_theme_font_size_override("font_size", 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	# 雇佣随从：试玩版暂闭；开放后购买进局自动跟随（上限 4 名）
	if not GameState.TRIAL_HIRE_OPEN:
		var note := Label.new()
		note.text = "试玩版：雇佣随从暂未开放（后续版本加入）"
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)
		return
	var hire_info: Dictionary = GameState.SHOP.get("hire_npc", {})
	if hire_info.is_empty():
		return
	var hired: int = GameState.pending_hires.size()
	var hire_btn := Button.new()
	hire_btn.add_theme_font_size_override("font_size", 10)
	hire_btn.text = "%s — %d SP" % [String(hire_info["name"]), int(hire_info["cost"])]
	if hired > 0:
		hire_btn.text += "（已带 %d 名）" % hired
	hire_btn.disabled = GameState.space_energy < int(hire_info["cost"])
	hire_btn.pressed.connect(func() -> void:
		if GameState.buy_shop_item("hire_npc"):
			_close_panel()
			_open_panel("gene")
	)
	box.add_child(hire_btn)


func _build_train_panel(box: VBoxContainer) -> void:
	_add_section_header(box, "身体属性")
	for id in GameState.ATTRS.keys():
		var info: Dictionary = GameState.ATTRS[id]
		var level: int = GameState.attr_level(id)
		var cost: int = GameState.attr_cost(level)
		var btn := Button.new()
		btn.text = "%s Lv.%d — %d SP（%s）" % [
			String(info["name"]), level, cost, String(info["desc"])
		]
		btn.add_theme_font_size_override("font_size", 9)
		btn.disabled = GameState.space_energy < cost
		var key := String(id)
		btn.pressed.connect(func() -> void:
			if GameState.buy_attr(key):
				_close_panel()
				_open_panel("train")
		)
		box.add_child(btn)
	# 枪械强化：10 层技能树逐层购买（跨局持久化，进局自动生效）
	_add_section_header(box, "枪械强化（逐层解锁）")
	for i in GameState.GUN_TREE.size():
		var tier: Dictionary = GameState.GUN_TREE[i]
		var tier_btn := Button.new()
		tier_btn.add_theme_font_size_override("font_size", 9)
		if i < GameState.gun_tree_levels:
			tier_btn.text = "✓ %s（%s）" % [String(tier["name"]), String(tier["desc"])]
			tier_btn.disabled = true
		elif i == GameState.gun_tree_levels:
			var tier_cost := int(tier["cost"])
			tier_btn.text = "%s — %d SP（%s）" % [String(tier["name"]), tier_cost, String(tier["desc"])]
			tier_btn.disabled = GameState.space_energy < tier_cost
			tier_btn.pressed.connect(func() -> void:
				if GameState.buy_gun_tree():
					_close_panel()
					_open_panel("train")
			)
		else:
			tier_btn.text = "%s（先购上一层）" % String(tier["name"])
			tier_btn.disabled = true
		box.add_child(tier_btn)


func _add_section_header(box: VBoxContainer, text: String) -> void:
	var header := Label.new()
	header.text = "—— %s ——" % text
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
