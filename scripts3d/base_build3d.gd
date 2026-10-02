extends Node3D
# 据点建造模式：已占领据点且玩家在据点半径内时按 X 进入，
# 打开建造面板（升级/扩大/扩容仓库/放置防御设施），Esc 或 X 退出。
# 点面板按钮进入放置模式：幽灵跟随鼠标光标贴地，左键点地图确认放置，右键取消；
# 走近已放置设施（3 米内）按 E 走 HUD 统一交互菜单（升级/卖掉）。
# 建材检查走 GameState.base_materials_available()（仓库+据点旁建材堆/车斗），扣料见 spend_materials；测试模式永不缺料。

const GHOST_ALPHA := 0.45
const INTERACT_RANGE := 3.0
const BARRICADE_SIZE := Vector3(0.4, 2.0, 2.0)
# 信号塔外观与地图基站同款（批次 145）
const STATION_MODEL_SCRIPT := preload("res://scripts3d/station3d.gd")

var _active := false
var _placing := ""
var _layer: CanvasLayer = null
var _info_label: Label = null
var _upgrade_button: Button = null
var _expand_button: Button = null
var _hint_label: Label = null
var _ghost: MeshInstance3D = null
var _ghost_material: StandardMaterial3D = null
var _ghost_height := 1.0
var _ghost_ok := false
var _ghost_yaw := 0.0
# 批次 248：建造摆放时的可建范围虚线圈（营地边界可视化）
var _range_ring: MeshInstance3D = null
var _range_ring_r := -1.0
var _defense_root: Node3D = null
var _defense_nodes: Array = []
# 底部建造栏：9 格可见，滚轮循环滚动，左侧分类页签
const BAR_SLOTS := 9
const BUILD_CATEGORIES := [
	{"id": "defense", "name": "防御类"},
	{"id": "base", "name": "基建类"},
	{"id": "craft", "name": "制作类"},
	{"id": "storage", "name": "仓库"},
]
const BUILD_CATEGORY_ITEMS := {
	"defense": ["barricade", "turret", "mortar", "cannon", "spikes", "wall"],
	"base": ["lamp", "generator", "solar", "windmill", "anomaly_gen", "signal_tower"],
	"craft": ["fabricator", "med_station", "food_synth", "workbench", "converter"],
	"storage": ["containment", "upgrade_storage"],
}
var _bar_category := "defense"
var _bar_scroll := 0
var _bar_slots: Array = []
var _cat_buttons := {}
var _last_in_range := true
var _regen_timer := 0.0
# 放置足迹半径（防堆叠摆放的碰撞圈）
const DEFENSE_FOOTPRINT_RADIUS := {
	"barricade": 1.1,
	"turret": 0.55,
	"mortar": 0.7,
	"cannon": 0.95,
	"spikes": 0.5,
	"wall": 1.6,
	"lamp": 0.3,
	"generator": 0.6,
	"solar": 0.8,
	"windmill": 0.4,
	"anomaly_gen": 0.7,
	"containment": 0.7,
	"workbench": 0.7,
	"converter": 0.7,
	"fabricator": 0.8,
	"food_synth": 0.8,
	"med_station": 0.8,
	"potion_brewer": 0.7,
	"signal_tower": 2.2,
}


func _ready() -> void:
	add_to_group("base_build")
	_defense_root = Node3D.new()
	_defense_root.name = "BaseDefenses"
	add_child(_defense_root)
	GameState.home_base_changed.connect(_on_home_base_changed)
	GameState.money_changed.connect(_on_state_changed)
	GameState.resources_changed.connect(_on_state_changed)
	# 场景启动时据点已有登记（读档/换场景回来）：补生成全部防御实体
	_respawn_defenses()


func _exit_tree() -> void:
	# 场景切换时强制复位，避免状态泄漏
	if _active:
		_active = false
		GameState.base_build_mode = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_active() -> bool:
	return _active


# fps_player 的 X 键（投降）让位：建造模式激活或可进入时由本脚本接管
func handles_x_key(_player: Node) -> bool:
	return _active or _can_enter()


func force_close() -> void:
	if not _active:
		return
	_active = false
	_placing = ""
	GameState.base_build_mode = false
	_clear_ghost()
	if _layer != null:
		_layer.queue_free()
		_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# 任意位置都能打开建造界面（有据点即可）；据点范围外物品置灰、不能放置
func _can_enter() -> bool:
	if GameState.is_run_over() or not GameState.has_home_base():
		return false
	return _player() != null


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _open() -> void:
	_active = true
	_placing = ""
	GameState.base_build_mode = true
	_last_in_range = GameState.player_in_base_radius()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_refresh_panel()
	GameState.notify("建造模式：点面板选设施后鼠标点地放置（右键取消），走近设施按 E 升级/卖掉，Esc/X 退出")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			if _active:
				force_close()
				get_viewport().set_input_as_handled()
			elif _can_enter():
				_open()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _active:
			force_close()
			get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseButton
		and event.pressed
		and _active
		and _placing != ""
		and (
			event.button_index == MOUSE_BUTTON_WHEEL_UP
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		)
	):
		# 放置中滚轮旋转幽灵朝向（8 向，45° 步进）
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_ghost_yaw += PI / 4.0
		else:
			_ghost_yaw -= PI / 4.0
		if _ghost != null:
			_ghost.rotation.y = _ghost_yaw
		get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and _active
		and _placing != ""
	):
		# 走到这里说明点击未被建造面板等 GUI 消费，视为点地图确认放置
		_confirm_place()
		get_viewport().set_input_as_handled()


# 右键取消放在 _input（先于 GUI 与 _unhandled_input 分发）：光标停在面板上时右键也能取消放置
func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and _placing != "":
			_placing = ""
			_clear_ghost()
			_refresh_panel()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _active:
		return
	if _placing != "":
		_update_ghost()
	_update_range_ring()
	# 玩家进出据点半径时刷新置灰状态（任意位置都能打开界面）
	var in_range := GameState.player_in_base_radius()
	if in_range != _last_in_range:
		_last_in_range = in_range
		_refresh_panel()
	# 驻守效果：有操作员的设施每秒回复 1 HP/人（不超过初始上限）
	_regen_timer -= _delta
	if _regen_timer <= 0.0:
		_regen_timer = 1.0
		for node in _defense_nodes:
			if not is_instance_valid(node):
				continue
			var ops := GameState.defense_operator_count(node.global_position)
			if ops <= 0:
				continue
			if not node.has_meta("max_hp"):
				node.set_meta("max_hp", int(node.get("hp")))
			node.set("hp", mini(int(node.get_meta("max_hp")), int(node.get("hp")) + ops))


func _build_ui() -> void:
	# 重复打开时清空上次的栏控件引用（旧 CanvasLayer 已随 force_close 释放）
	_bar_slots.clear()
	_cat_buttons.clear()
	_bar_category = "defense"
	_bar_scroll = 0
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	# 左下：领地数据（贴建造栏左侧，不遮地图）
	var left := PanelContainer.new()
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 4
	left.offset_right = 102
	left.offset_top = -118
	left.offset_bottom = -2
	_layer.add_child(left)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	left.add_child(box)

	var title := Label.new()
	title.text = "据点建造"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	box.add_child(title)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 8)
	_info_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info_label)

	_hint_label = Label.new()
	_hint_label.text = "Esc/X 退出\nE 升级/卖掉"
	_hint_label.add_theme_font_size_override("font_size", 7)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	box.add_child(_hint_label)

	# 右下：升级/扩建按钮（贴建造栏右侧）
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_left = -102
	right.offset_right = -4
	right.offset_top = -58
	right.offset_bottom = -2
	_layer.add_child(right)
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 3)
	right.add_child(btn_col)
	_upgrade_button = _make_button("", _on_upgrade)
	_upgrade_button.custom_minimum_size = Vector2(94, 22)
	_upgrade_button.add_theme_font_size_override("font_size", 8)
	btn_col.add_child(_upgrade_button)
	_expand_button = _make_button("", _on_expand)
	_expand_button.custom_minimum_size = Vector2(94, 22)
	_expand_button.add_theme_font_size_override("font_size", 8)
	btn_col.add_child(_expand_button)

	_build_bar()


# 底部建造栏：上方横向分页（防御/基建/建造/仓库），下方一排物品槽（9 格），
# 滚轮循环翻页；点槽位选中进入放置（幽灵跟随鼠标，左键点地确认，右键取消），再点一次取消选中
func _build_bar() -> void:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -215
	bar.offset_right = 215
	bar.offset_top = -48
	bar.offset_bottom = -2
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(bar)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.06, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	# 分页：顶部横排在 bar 上方外侧（tabs 压 bar 顶边）
	var tab_box := HBoxContainer.new()
	tab_box.position = Vector2(4, -13)
	tab_box.add_theme_constant_override("separation", 2)
	bar.add_child(tab_box)
	for cat in BUILD_CATEGORIES:
		var cat_id := String(cat["id"])
		var btn := Button.new()
		btn.text = String(cat["name"])
		btn.custom_minimum_size = Vector2(46, 12)
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_pick_category.bind(cat_id))
		tab_box.add_child(btn)
		_cat_buttons[cat_id] = btn
	# 9 格物品槽：下方一排撑满（图标 + 名称 + 造价）
	var slot_box := HBoxContainer.new()
	slot_box.position = Vector2(4, 3)
	slot_box.add_theme_constant_override("separation", 3)
	slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(slot_box)
	for i in BAR_SLOTS:
		var slot := BuildSlot.new()
		slot.index = i
		slot.mgr = self
		slot.custom_minimum_size = Vector2(44, 38)
		slot_box.add_child(slot)
		_bar_slots.append(slot)
	# 滚轮循环翻页（悬停在建造栏上时）
	bar.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if _placing != "":
					return  # 放置中滚轮用于旋转朝向，不翻页
				var items: Array = BUILD_CATEGORY_ITEMS[_bar_category]
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					_bar_scroll = posmod(_bar_scroll - 1, items.size())
					_refresh_bar()
					bar.accept_event()
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_bar_scroll = posmod(_bar_scroll + 1, items.size())
					_refresh_bar()
					bar.accept_event()
	)


func _on_pick_category(cat_id: String) -> void:
	_bar_category = cat_id
	_bar_scroll = 0
	_refresh_bar()


func _on_bar_slot(i: int) -> void:
	var items: Array = BUILD_CATEGORY_ITEMS[_bar_category]
	var id := String(items[posmod(_bar_scroll + i, items.size())])
	if id == "upgrade_storage":
		# 仓库分类里的动作项：直接扩建，不进入放置
		GameState.upgrade_base_storage()
		_refresh_panel()
		return
	if _placing == id:
		_placing = ""
		_clear_ghost()
	else:
		_placing = id
		_make_ghost(id)
	_refresh_panel()


func _refresh_bar() -> void:
	if _bar_slots.is_empty():
		return
	var items: Array = BUILD_CATEGORY_ITEMS[_bar_category]
	# 据点范围外：全部置灰可浏览但不能建造
	var in_range := GameState.player_in_base_radius()
	# 不足 9 项时只显示实际物品，不重复填充；超过 9 项才滚轮循环
	var wrap := items.size() > BAR_SLOTS
	for i in BAR_SLOTS:
		var slot: BuildSlot = _bar_slots[i]
		if not wrap and i >= items.size():
			slot.visible = false
			continue
		slot.visible = true
		var id := String(items[posmod(_bar_scroll + i, items.size())])
		if id == "upgrade_storage":
			slot.set_item(
				"upgrade_storage",
				"扩建仓库",
				"建材×%d" % GameState.upgrade_storage_cost(),
				"仓库容量 +100（%d→%d）" % [
					GameState.base_storage_cap(), GameState.base_storage_cap() + 100
				],
				(
					not in_range
					or GameState.base_materials_available() < GameState.upgrade_storage_cost()
				),
				false
			)
			continue
		var info: Dictionary = GameState.BASE_DEFENSES[id]
		# 信号塔任意位置可建；其余设施据点范围外置灰
		slot.set_item(
			id,
			String(info["name"]),
			GameState.defense_cost_text(id),
			"%s（%s）" % [String(info["name"]), GameState.defense_cost_text(id)]
				+ GameState.energy_tag_text(id),
			(id != "signal_tower" and not in_range) or not GameState.defense_affordable(id),
			_placing == id
		)
	for cat_id in _cat_buttons.keys():
		var btn: Button = _cat_buttons[cat_id]
		btn.modulate = Color(1.3, 1.25, 0.7) if cat_id == _bar_category else Color(1.0, 1.0, 1.0)


func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(176, 18)
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(handler)
	return button


func _on_state_changed(_value = null) -> void:
	if _active:
		_refresh_panel()


func _refresh_panel() -> void:
	if _info_label == null or not GameState.has_home_base():
		return
	_info_label.text = (
		"Lv.%d/%d · 半径 %.0fm · 建材 %d/%d（含周边 %d） · 设施 %d 座 · 信号 %.0fm · 折现 %d%% · 电力 发电%dkW/用电%dkW"
		% [
			GameState.home_base_level(),
			GameState.BASE_MAX_LEVEL,
			GameState.home_base_radius(),
			GameState.base_materials(),
			GameState.base_storage_cap(),
			GameState.base_materials_available(),
			GameState.base_defense_count(),
			GameState.base_signal_radius(),
			int(GameState.home_storage_rate() * 100.0),
			int(GameState.power_gen_rate() * 10.0),
			int(GameState.power_use_rate() * 10.0),
		]
	)
	_upgrade_button.text = "升级据点 — 建材 ×%d" % GameState.upgrade_base_cost()
	_upgrade_button.disabled = (
		not GameState.player_in_base_radius()
		or GameState.home_base_level() >= GameState.BASE_MAX_LEVEL
		or GameState.base_materials_available() < GameState.upgrade_base_cost()
	)
	if GameState.home_base_level() >= GameState.BASE_MAX_LEVEL:
		_upgrade_button.text = "已满级"
	_expand_button.text = "扩大据点 +2m — 建材 ×%d" % GameState.expand_base_cost()
	_expand_button.disabled = (
		not GameState.player_in_base_radius()
		or GameState.home_base_radius() >= GameState.BASE_MAX_RADIUS
		or GameState.base_materials_available() < GameState.expand_base_cost()
	)
	if GameState.home_base_radius() >= GameState.BASE_MAX_RADIUS:
		_expand_button.text = "半径已达上限"
	_refresh_bar()
	if not GameState.player_in_base_radius() and _placing == "":
		_hint_label.text = "（据点范围外：只有信号塔可以建造，其余需在据点范围内）"
	elif _placing != "":
		var info: Dictionary = GameState.BASE_DEFENSES[_placing]
		_hint_label.text = "放置中：%s（左键确认 / 右键取消）" % String(info["name"])
	else:
		_hint_label.text = "Esc / X 退出 · 滚轮翻页 · E 升级/卖掉设施"


# HUD 统一交互菜单的选项：升级（下一级效果与造价 / MAX / 不可升级）与卖掉
func defense_options(node: Node3D) -> Array:
	var type := String(node.defense_type)
	# 制造台类走自己的配方菜单
	if node.has_method("recipe_options"):
		return node.recipe_options()
	var defense_name := String(GameState.BASE_DEFENSES.get(type, {}).get("name", type))
	var level := GameState.defense_upgrade_level(node.global_position)
	var info := GameState.defense_upgrade_info(type, level)
	var upgrade := {"id": "upgrade", "label": "", "disabled": false, "reason": ""}
	if not GameState.DEFENSE_UPGRADES.has(type):
		upgrade["label"] = "升级 %s" % defense_name
		upgrade["disabled"] = true
		upgrade["reason"] = "不可升级"
	elif info.is_empty():
		upgrade["label"] = "升级 %s" % defense_name
		upgrade["disabled"] = true
		upgrade["reason"] = "已满级 MAX"
	else:
		upgrade["label"] = "升级 %s Lv.%d→%d（建材 ×%d）" % [
			defense_name, level, level + 1, int(info["cost"]),
		]
		if GameState.base_materials_available() < int(info["cost"]):
			upgrade["disabled"] = true
			upgrade["reason"] = "建材不足"
	upgrade["label"] = String(upgrade["label"]) + GameState.energy_tag_text(type)
	var refund := GameState.base_defense_cost(type) / 2
	var options := [
		upgrade,
		{"id": "sell", "label": "卖掉 %s（返还建材 ×%d）" % [defense_name, refund]},
	]
	# 迫击炮/火炮：远程炮击指挥入口
	if type == "mortar" or type == "cannon":
		options.insert(0, {
			"id": "command_mortar",
			"label": "指挥炮击（远程选打击点，射程 %d 米）" % int(
				GameState.BASE_DEFENSES[type].get("range", 40.0)
			),
		})
	# 操作员工作位：只有炮塔与制造/生产类设施有（基建/围墙/灯等不需要）
	var op_slots := GameState.operator_slots(type)
	if op_slots > 0:
		options.append({
			"id": "operators",
			"label": "操作员（%d/%d）· %s" % [
				GameState.defense_operator_count(node.global_position),
				op_slots, GameState.operator_desc(type)
			],
		})
	return options


# HUD 统一交互菜单的选择回调
func defense_choose(node: Node3D, id: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	# 制造台配方/投料选项
	if id.begins_with("fab_") and node.has_method("fabricator_choose"):
		node.fabricator_choose(id)
		if _active:
			_refresh_panel()
		return
	match id:
		"command_mortar":
			# 进入炮击指挥：左键在射程内选打击点，右键/Esc 退出（迫击炮节点接管输入）
			GameState.mortar_command = node
			GameState.mortar_remote = false
			GameState.mortar_command_kind = String(node.defense_type)
			GameState.mortar_command_remote = false
			GameState.notify("炮击指挥中：左键选择打击点（绿环=可打，红环=超程/装填）· 右键/Esc 退出")
		"upgrade":
			_upgrade_defense(node)
		"sell":
			_sell_defense(node)
		"operators":
			# 打开市民选择面板：指派/撤出该设施的操作员
			var player := get_tree().get_first_node_in_group("player")
			if player != null:
				var hud = player.get_node_or_null("HUD")
				if hud != null and hud.has_method("open_operator_panel"):
					hud.open_operator_panel(node)
	if _active:
		_refresh_panel()


# 升级指定设施：成功后按新等级重建该设施外观（保留位置与朝向）
func _upgrade_defense(node: Node3D) -> void:
	var type := String(node.defense_type)
	var pos := node.global_position
	var yaw := node.rotation.y
	if GameState.upgrade_base_defense(pos):
		var idx := _defense_nodes.find(node)
		if idx >= 0:
			_defense_nodes.remove_at(idx)
		node.queue_free()
		_spawn_defense(type, pos, yaw)


# 卖掉指定设施：返还一半造价建材到据点仓库，播放碎片效果后移除节点与据点登记
func _sell_defense(node: Node3D) -> void:
	var type := String(node.defense_type)
	var defense_name := String(GameState.BASE_DEFENSES.get(type, {}).get("name", type))
	var pos := node.global_position
	var refund := GameState.base_defense_cost(type) / 2
	var idx := _defense_nodes.find(node)
	if idx >= 0:
		_defense_nodes.remove_at(idx)
	GameState.remove_base_defense(pos)
	var got := GameState.add_materials_to_base(refund)
	node._spawn_debris(node.debris_size, node.debris_color)
	node.queue_free()
	GameState.notify("已卖掉%s，返还建材 ×%d" % [defense_name, got])


func _on_upgrade() -> void:
	GameState.upgrade_home_base()
	_refresh_panel()


func _on_expand() -> void:
	GameState.expand_home_base()
	_refresh_panel()


func _make_ghost(type: String) -> void:
	_clear_ghost()
	# 初始朝向取玩家朝向吸附到最近的 45°（8 向），放置中滚轮再微调
	var player := _player()
	if player != null:
		_ghost_yaw = snappedf(player.rotation.y, PI / 4.0)
	_ghost = MeshInstance3D.new()
	var box := BoxMesh.new()
	match type:
		"barricade":
			box.size = BARRICADE_SIZE
		"turret":
			box.size = Vector3(0.9, 1.5, 0.9)
		"spikes":
			box.size = Vector3(0.8, 0.15, 0.8)
		"wall":
			box.size = Vector3(3.0, 2.5, 0.3)
		"lamp":
			box.size = Vector3(0.4, 3.0, 0.4)
		"generator":
			box.size = Vector3(1.0, 0.9, 0.7)
		"solar":
			box.size = Vector3(1.4, 1.0, 1.2)
		"windmill":
			box.size = Vector3(0.6, 3.4, 0.6)
		"anomaly_gen":
			box.size = Vector3(1.2, 1.8, 1.2)
		"containment":
			box.size = Vector3(1.2, 1.6, 1.2)
		"workbench":
			box.size = Vector3(1.2, 0.8, 0.8)
		"converter":
			box.size = Vector3(1.2, 0.8, 0.8)
		"fabricator":
			box.size = Vector3(1.4, 0.9, 0.9)
		"food_synth":
			box.size = Vector3(1.4, 0.9, 0.9)
		"med_station":
			box.size = Vector3(1.4, 0.9, 0.9)
		"potion_brewer":
			box.size = Vector3(1.1, 1.0, 0.9)
		_:
			box.size = Vector3(0.9, 1.5, 0.9)
	_ghost.mesh = box
	_ghost_height = box.size.y
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = Color(0.3, 1.0, 0.4, GHOST_ALPHA)
	_ghost_material.emission_enabled = true
	_ghost_material.emission = Color(0.3, 1.0, 0.4)
	_ghost_material.emission_energy_multiplier = 0.6
	_ghost.material_override = _ghost_material
	add_child(_ghost)


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
		_ghost_material = null
	_ghost_ok = false


# 幽灵跟随鼠标光标：从相机向光标位置发射线，与地面（y=0 平面）求交作为落点
func _update_ghost() -> void:
	var player := _player()
	if player == null or _ghost == null:
		return
	var camera: Camera3D = player.camera
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		_ghost.visible = false
		_ghost_ok = false
		return
	var pos: Vector3 = hit
	pos.y = 0.0
	_ghost.visible = true
	_ghost.global_position = pos + Vector3(0, _ghost_height * 0.5, 0)
	_ghost.rotation.y = _ghost_yaw
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	var flat := Vector2(pos.x - base_pos.x, pos.z - base_pos.z)
	# 信号塔任意位置可建（不占据点半径限制）
	_ghost_ok = (
		(_placing == "signal_tower" or flat.length() <= GameState.home_base_radius())
		and not _position_blocked(pos)
	)
	var color := Color(0.3, 1.0, 0.4, GHOST_ALPHA) if _ghost_ok else Color(1.0, 0.3, 0.3, GHOST_ALPHA)
	_ghost_material.albedo_color = color
	_ghost_material.emission = Color(color.r, color.g, color.b)


# 放置碰撞：与已建设施的足迹圈重叠则不能堆叠摆放
func _position_blocked(pos: Vector3) -> bool:
	var need_self := _footprint_radius(_placing)
	for node in _defense_nodes:
		if not is_instance_valid(node):
			continue
		var need := need_self + _footprint_radius(String(node.get("defense_type")))
		var flat := Vector2(node.global_position.x - pos.x, node.global_position.z - pos.z)
		if flat.length() < need:
			return true
	return false


func _footprint_radius(type: String) -> float:
	return float(DEFENSE_FOOTPRINT_RADIUS.get(type, 0.55))


# 批次 248：建造摆放时在地面画营地可建范围虚线圈（绿色，隔段虚线）
func _update_range_ring() -> void:
	if _placing == "" or not GameState.has_home_base():
		if _range_ring != null:
			_range_ring.visible = false
		return
	if _range_ring == null or not is_instance_valid(_range_ring):
		var mi := MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.4, 1.0, 0.5, 0.8)
		mi.material_override = mat
		_range_ring = mi
		add_child(mi)
	_range_ring.visible = true
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	var r := GameState.home_base_radius()
	_range_ring.global_position = Vector3(base_pos.x, 0.07, base_pos.z)
	if absf(_range_ring_r - r) > 0.01:
		_range_ring_r = r
		var im := _range_ring.mesh as ImmediateMesh
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var segs := 48
		for i in segs:
			if i % 2 == 1:
				continue  # 隔一段画一段 = 虚线
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			im.surface_add_vertex(Vector3(cos(a0) * r, 0.0, sin(a0) * r))
			im.surface_add_vertex(Vector3(cos(a1) * r, 0.0, sin(a1) * r))
		im.surface_end()


func _confirm_place() -> void:
	if _placing == "":
		return
	if not _ghost_ok or _ghost == null or not _ghost.visible:
		GameState.notify("此处无法放置：需要在据点半径内（信号塔除外）且不与已有设施重叠")
		return
	var pos := _ghost.global_position - Vector3(0, _ghost_height * 0.5, 0)
	var type := _placing
	var yaw := _ghost_yaw
	if GameState.add_base_defense(type, pos):
		_spawn_defense(type, pos, yaw)
	_refresh_panel()


# 据点更换/清空时重建防御实体（新增由放置流程直接生成；升级/存钱数量不变，不重建以保留朝向）
func _on_home_base_changed() -> void:
	if _active:
		_refresh_panel()
	if GameState.base_defense_count() >= _defense_nodes.size():
		return
	_respawn_defenses()


# 全量重建防御实体：场景启动补生成（读档/换场景后登记还在、实体不在）与据点清空时用
func _respawn_defenses() -> void:
	for node in _defense_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_defense_nodes.clear()
	if not GameState.has_home_base():
		return
	for entry in GameState.home_base.get("defenses", []):
		_spawn_defense(String(entry["type"]), entry["pos"], 0.0)


func _spawn_defense(type: String, pos: Vector3, yaw: float) -> void:
	var node: Node3D
	match type:
		"barricade":
			node = Barricade.new()
		"turret":
			node = Turret.new()
		"mortar", "cannon":
			node = Mortar.new()
		"spikes":
			node = Spikes.new()
		"wall":
			node = Wall.new()
		"lamp":
			node = Lamp.new()
		"generator":
			node = Generator.new()
		"solar":
			node = SolarPanel.new()
		"windmill":
			node = Windmill.new()
		"anomaly_gen":
			node = AnomalyGenerator.new()
		"containment":
			node = ContainmentUnit.new()
		"workbench":
			node = Workbench.new()
		"converter":
			node = Converter.new()
		"fabricator":
			node = Fabricator.new()
		"food_synth":
			node = FoodSynthesizer.new()
		"med_station":
			node = MedStation.new()
		"potion_brewer":
			node = PotionBrewer.new()
		"signal_tower":
			node = SignalTower.new()
		_:
			return
	node.defense_type = type
	node.upgrade_level = GameState.defense_upgrade_level(pos)
	node.add_to_group("interactables")
	_defense_root.add_child(node)
	node.global_position = pos
	node.rotation.y = yaw
	_defense_nodes.append(node)


# 建造栏物品槽：图标 + 名称 + 造价，点击选中/再点取消，置灰仅可浏览
class BuildSlot extends Control:
	var index := 0
	var mgr: Node = null
	var icon_kind := ""
	var title := ""
	var cost := ""
	var disabled_slot := false
	var selected := false


	func set_item(kind: String, name_text: String, cost_text: String, tip: String, disabled: bool, sel: bool) -> void:
		icon_kind = kind
		title = name_text
		cost = cost_text
		tooltip_text = tip
		disabled_slot = disabled
		selected = sel
		queue_redraw()


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP


	func _gui_input(event: InputEvent) -> void:
		if disabled_slot:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			mgr._on_bar_slot(index)


	func _draw() -> void:
		var bg := Color(0.12, 0.16, 0.14, 0.95)
		if selected:
			bg = Color(0.36, 0.33, 0.15, 0.95)
		draw_rect(Rect2(Vector2.ZERO, size), bg)
		if selected:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.9, 0.4), false, 1.5)
		var dim := 0.45 if disabled_slot else 1.0
		_draw_icon(Vector2((size.x - 24.0) / 2.0, 3.0), dim)
		var font := ThemeDB.fallback_font
		var name_color := Color(0.88, 0.92, 0.88) if not disabled_slot else Color(0.45, 0.48, 0.45)
		var cost_color := Color(0.72, 0.76, 0.68) if not disabled_slot else Color(0.4, 0.43, 0.4)
		draw_string(font, Vector2(0, 27), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 7, name_color)
		draw_string(font, Vector2(0, 36), cost, HORIZONTAL_ALIGNMENT_CENTER, size.x, 6, cost_color)


	func _icon_color() -> Color:
		match icon_kind:
			"barricade", "workbench":
				return Color(0.65, 0.55, 0.4)
			"turret":
				return Color(0.6, 0.62, 0.66)
			"mortar":
				return Color(0.38, 0.45, 0.3)
			"cannon":
				return Color(0.45, 0.38, 0.28)
			"spikes":
				return Color(0.72, 0.72, 0.74)
			"wall":
				return Color(0.62, 0.56, 0.5)
			"lamp":
				return Color(1.0, 0.9, 0.45)
			"generator":
				return Color(0.5, 0.6, 0.55)
			"solar":
				return Color(0.35, 0.5, 0.85)
			"windmill":
				return Color(0.7, 0.75, 0.7)
			"anomaly_gen":
				return Color(0.6, 0.4, 0.95)
			"containment", "converter":
				return Color(0.75, 0.6, 0.9)
			"fabricator":
				return Color(0.55, 0.6, 0.7)
			"food_synth":
				return Color(1.0, 0.65, 0.3)
			"med_station", "potion_brewer":
				return Color(0.95, 0.5, 0.5)
			"signal_tower":
				return Color(0.6, 0.7, 0.85)
			"upgrade_storage":
				return Color(0.85, 0.75, 0.4)
			_:
				return Color(0.7, 0.7, 0.7)


	# 各设施的简笔图案（24×16 区域内）
	func _draw_icon(origin: Vector2, dim: float) -> void:
		var c: Color = _icon_color() * dim
		var o := origin
		match icon_kind:
			"barricade":
				draw_rect(Rect2(o + Vector2(2, 8), Vector2(20, 7)), c)
				draw_rect(Rect2(o + Vector2(2, 4), Vector2(20, 2)), Color(0.9, 0.75, 0.2) * dim)
			"turret":
				draw_rect(Rect2(o + Vector2(9, 9), Vector2(6, 6)), c)
				draw_rect(Rect2(o + Vector2(6, 5), Vector2(12, 4)), c)
				draw_rect(Rect2(o + Vector2(11, 0), Vector2(2, 5)), c)
			"mortar":
				draw_rect(Rect2(o + Vector2(7, 11), Vector2(10, 3)), c)
				draw_line(o + Vector2(10, 11), o + Vector2(15, 3), c, 2.5)
			"cannon":
				draw_rect(Rect2(o + Vector2(6, 11), Vector2(12, 3)), c)
				draw_line(o + Vector2(9, 11), o + Vector2(16, 2), c, 3.5)
				draw_circle(o + Vector2(8, 14), 1.5, c)
				draw_circle(o + Vector2(16, 14), 1.5, c)
			"spikes":
				for i in 3:
					var x := 3.0 + i * 6.5
					draw_colored_polygon(
						[o + Vector2(x, 13), o + Vector2(x + 3, 4), o + Vector2(x + 6, 13)], c
					)
			"wall":
				draw_rect(Rect2(o + Vector2(1, 5), Vector2(22, 9)), c)
				draw_line(o + Vector2(8, 5), o + Vector2(8, 14), c.darkened(0.4), 1.0)
				draw_line(o + Vector2(16, 5), o + Vector2(16, 14), c.darkened(0.4), 1.0)
			"lamp":
				draw_line(o + Vector2(12, 5), o + Vector2(12, 14), c, 2.0)
				draw_circle(o + Vector2(12, 3), 3.0, Color(1.0, 0.9, 0.4) * dim)
			"generator":
				draw_rect(Rect2(o + Vector2(5, 5), Vector2(14, 9)), c)
				draw_polyline(
					[o + Vector2(13, 6), o + Vector2(10, 10), o + Vector2(13, 10), o + Vector2(11, 14)],
					Color(1.0, 0.85, 0.2) * dim, 1.5
				)
			"solar":
				draw_rect(Rect2(o + Vector2(4, 5), Vector2(16, 8)), c)
				for i in 3:
					draw_line(
						o + Vector2(4.0 + i * 5.3, 5), o + Vector2(4.0 + i * 5.3, 13),
						Color(0.7, 0.85, 1.0) * dim, 0.8
					)
				draw_line(o + Vector2(4, 9), o + Vector2(20, 9), Color(0.7, 0.85, 1.0) * dim, 0.8)
			"windmill":
				draw_line(o + Vector2(12, 8), o + Vector2(12, 15), c, 1.5)
				for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
					draw_line(
						o + Vector2(12, 6), o + Vector2(12 + cos(a) * 6, 6 + sin(a) * 6), c, 1.5
					)
			"anomaly_gen":
				# 紫色圆核 + 两侧能量弧
				draw_circle(o + Vector2(12, 9), 4.5, c)
				draw_arc(o + Vector2(12, 9), 7.0, 0.0, TAU, 16, Color(0.6, 0.4, 0.95) * dim, 1.2)
			"containment":
				draw_rect(Rect2(o + Vector2(6, 3), Vector2(12, 12)), c, false, 1.5)
				draw_circle(o + Vector2(12, 9), 3.0, Color(0.8, 0.5, 0.95) * dim)
			"workbench":
				draw_rect(Rect2(o + Vector2(3, 8), Vector2(18, 3)), c)
				draw_line(o + Vector2(6, 11), o + Vector2(6, 15), c, 1.5)
				draw_line(o + Vector2(18, 11), o + Vector2(18, 15), c, 1.5)
			"converter":
				draw_circle(o + Vector2(12, 9), 5.0, c)
				draw_circle(o + Vector2(12, 9), 2.0, Color(0.8, 0.5, 0.95) * dim)
			"fabricator":
				draw_rect(Rect2(o + Vector2(4, 6), Vector2(13, 6)), c)
				draw_rect(Rect2(o + Vector2(15, 8), Vector2(6, 2)), c)
				draw_rect(Rect2(o + Vector2(8, 12), Vector2(4, 3)), c)
			"food_synth":
				draw_circle(o + Vector2(12, 9), 5.0, c)
				draw_rect(Rect2(o + Vector2(11, 2), Vector2(2, 3)), Color(0.4, 0.8, 0.3) * dim)
			"med_station":
				draw_rect(Rect2(o + Vector2(9, 3), Vector2(6, 12)), c)
				draw_rect(Rect2(o + Vector2(6, 6), Vector2(12, 6)), c)
			"potion_brewer":
				draw_colored_polygon(
					[o + Vector2(8, 14), o + Vector2(16, 14), o + Vector2(13, 6)], c
				)
				draw_rect(Rect2(o + Vector2(11, 3), Vector2(2, 4)), c)
			"signal_tower":
				draw_colored_polygon(
					[o + Vector2(8, 15), o + Vector2(16, 15), o + Vector2(12, 3)], c
				)
				draw_arc(o + Vector2(12, 3), 4.0, -2.4, -0.7, 6, Color(0.7, 0.85, 1.0) * dim, 1.2)
				draw_arc(o + Vector2(12, 3), 6.5, -2.4, -0.7, 8, Color(0.7, 0.85, 1.0) * dim, 1.0)
			"upgrade_storage":
				draw_rect(Rect2(o + Vector2(4, 5), Vector2(16, 10)), c)
				draw_rect(Rect2(o + Vector2(9, 2), Vector2(6, 3)), c)
				draw_line(o + Vector2(12, 7), o + Vector2(12, 12), Color(0.2, 0.2, 0.15), 1.5)
				draw_line(o + Vector2(9.5, 9.5), o + Vector2(14.5, 9.5), Color(0.2, 0.2, 0.15), 1.5)


# 防御设施基类：base_defense 组 + HP + 被摧毁通用流程（噪音/通知/残骸/从据点登记移除）
class DefenseBase extends StaticBody3D:
	var defense_type := ""
	var upgrade_level := 0
	var hp := 100
	var debris_size := Vector3.ONE
	var debris_color := Color(0.4, 0.4, 0.4)
	var debris_noise := 20.0
	# Boss 干扰磁场：被沉默期间 set_process(false)，炮塔停火/机器停产（设计文档 5.2）
	var jammed := false


	func _defense_name() -> String:
		return String(GameState.BASE_DEFENSES.get(defense_type, {}).get("name", "设施"))


	# 接入 HUD 交互提示体系：玩家走近 3 米内提示按 E 升级/拆除（无需进入建造模式）
	func prompt_text() -> String:
		var player = get_tree().get_first_node_in_group("player")
		if player == null or global_position.distance_to(player.global_position) > 3.0:
			return ""
		return "E 升级/拆除 %s" % _defense_name()


	# —— 统一交互菜单协议：升级 / 卖掉（选项文案由建造管理器生成）——

	func interact_title() -> String:
		return _defense_name()


	func interact_options(player: Node3D) -> Array:
		if player == null or global_position.distance_to(player.global_position) > 3.0:
			return []
		var mgr := get_tree().get_first_node_in_group("base_build")
		if mgr == null or not mgr.has_method("defense_options"):
			return []
		return mgr.defense_options(self)


	func interact_choose(id: String, _player: Node3D) -> void:
		var mgr := get_tree().get_first_node_in_group("base_build")
		if mgr != null and mgr.has_method("defense_choose"):
			mgr.defense_choose(self, id)


	func take_damage(amount: int) -> void:
		hp -= amount
		if hp <= 0:
			_destroy()


	func _destroy() -> void:
		GameState.noise_at(global_position, debris_noise)
		GameState.notify("%s被丧尸摧毁了！" % _defense_name())
		_spawn_debris(debris_size, debris_color)
		GameState.remove_base_defense(global_position)
		queue_free()


	# 残骸效果：几块碎片散落缩小淡出
	func _spawn_debris(size: Vector3, color: Color) -> void:
		var parent := get_parent()
		if parent == null:
			return
		for i in 4:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = size * randf_range(0.2, 0.35)
			mesh.mesh = box
			var material := StandardMaterial3D.new()
			material.albedo_color = color * 0.6
			mesh.material_override = material
			parent.add_child(mesh)
			mesh.global_position = global_position + Vector3(
				randf_range(-0.4, 0.4), randf_range(0.2, size.y * 0.6), randf_range(-0.4, 0.4)
			)
			mesh.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
			var tween := mesh.create_tween()
			tween.tween_property(mesh, "scale", Vector3.ONE * 0.25, 0.9)
			tween.tween_callback(mesh.queue_free)


# 路障：挡丧尸与玩家的盒墙，可被丧尸打爆；升级后加高加宽、HP 提高
class Barricade extends DefenseBase:
	const SIZE := Vector3(0.4, 2.0, 2.0)


	func _size() -> Vector3:
		return Vector3(
			SIZE.x,
			SIZE.y * (1.0 + 0.25 * upgrade_level),
			SIZE.z * (1.0 + 0.3 * upgrade_level)
		)


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("barricade")
		var ups: Array = GameState.DEFENSE_UPGRADES.get("barricade", [])
		for i in mini(upgrade_level, ups.size()):
			hp += int(ups[i].get("hp_bonus", 0))
		var size := _size()
		debris_size = size
		debris_color = Color(0.5, 0.42, 0.3)
		debris_noise = 20.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position.y = size.y * 0.5
		add_child(shape)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.42, 0.3)
		mesh.material_override = material
		mesh.position.y = size.y * 0.5
		add_child(mesh)
		# 顶部警示条
		var stripe := MeshInstance3D.new()
		var stripe_box := BoxMesh.new()
		stripe_box.size = Vector3(size.x + 0.02, 0.16, size.z)
		stripe.mesh = stripe_box
		var stripe_material := StandardMaterial3D.new()
		stripe_material.albedo_color = Color(0.9, 0.75, 0.2)
		stripe_material.emission_enabled = true
		stripe_material.emission = Color(0.9, 0.7, 0.15)
		stripe_material.emission_energy_multiplier = 0.8
		stripe.material_override = stripe_material
		stripe.position.y = size.y - 0.1
		add_child(stripe)


# 哨戒炮塔：底座 + 旋转头，自动索敌射击最近的丧尸，可被丧尸打爆；
# 升级后加双管/变色、伤害与射程提高；据点内有发电机时射程 +3 米
class Turret extends DefenseBase:
	const SCAN_INTERVAL := 0.3
	const FIRE_INTERVAL := 0.8
	const RANGE := 15.0
	const DAMAGE := 12

	var _head: Node3D = null
	var _scan := 0.0
	var _cooldown := 0.0
	var _target: Node3D = null


	func _damage() -> int:
		if upgrade_level >= 1:
			var ups: Array = GameState.DEFENSE_UPGRADES.get("turret", [])
			return int(ups[mini(upgrade_level, ups.size()) - 1].get("damage", DAMAGE))
		return int(GameState.BASE_DEFENSES["turret"].get("damage", DAMAGE))


	func _range() -> float:
		var reach := RANGE
		if upgrade_level >= 1:
			var ups: Array = GameState.DEFENSE_UPGRADES.get("turret", [])
			reach = float(ups[mini(upgrade_level, ups.size()) - 1].get("range", reach))
		else:
			reach = float(GameState.BASE_DEFENSES["turret"].get("range", RANGE))
		return reach + _generator_bonus()


	# 发电机光环：据点防御列表里有 generator 时炮塔射程 +3 米
	func _generator_bonus() -> float:
		if not GameState.has_home_base():
			return 0.0
		for entry in GameState.home_base.get("defenses", []):
			if String(entry.get("type", "")) == "generator":
				return float(GameState.BASE_DEFENSES["generator"].get("range_aura", 3.0))
		return 0.0


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("turret")
		debris_size = Vector3(0.7, 1.2, 0.7)
		debris_color = Color(0.3, 0.32, 0.36)
		debris_noise = 24.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.7, 1.0, 0.7)
		shape.shape = box_shape
		shape.position.y = 0.5
		add_child(shape)
		var base := MeshInstance3D.new()
		var base_box := BoxMesh.new()
		base_box.size = Vector3(0.7, 1.0, 0.7)
		base.mesh = base_box
		var base_material := StandardMaterial3D.new()
		base_material.albedo_color = Color(0.3, 0.32, 0.36)
		base.material_override = base_material
		base.position.y = 0.5
		add_child(base)
		_head = Node3D.new()
		_head.position.y = 1.15
		add_child(_head)
		var head_mesh := MeshInstance3D.new()
		var head_box := BoxMesh.new()
		head_box.size = Vector3(0.5, 0.3, 0.6)
		head_mesh.mesh = head_box
		var head_material := StandardMaterial3D.new()
		# 升级变色：Lv1 黄铜色，Lv2 深红色
		head_material.albedo_color = [
			Color(0.45, 0.5, 0.55), Color(0.6, 0.52, 0.28), Color(0.62, 0.3, 0.24)
		][mini(upgrade_level, 2)]
		head_mesh.material_override = head_material
		_head.add_child(head_mesh)
		# 枪管：Lv1 起双管
		var barrel_offsets := [0.0] if upgrade_level < 1 else [-0.12, 0.12]
		for offset_x in barrel_offsets:
			var barrel := MeshInstance3D.new()
			var barrel_box := BoxMesh.new()
			barrel_box.size = Vector3(0.08, 0.08, 0.55)
			barrel.mesh = barrel_box
			var barrel_material := StandardMaterial3D.new()
			barrel_material.albedo_color = Color(0.2, 0.2, 0.22)
			barrel.material_override = barrel_material
			barrel.position = Vector3(offset_x, 0.02, -0.5)
			_head.add_child(barrel)
		var eye := MeshInstance3D.new()
		var eye_box := BoxMesh.new()
		eye_box.size = Vector3(0.12, 0.08, 0.05)
		eye.mesh = eye_box
		var eye_material := StandardMaterial3D.new()
		eye_material.albedo_color = Color(1.0, 0.3, 0.2)
		eye_material.emission_enabled = true
		eye_material.emission = Color(1.0, 0.25, 0.15)
		eye_material.emission_energy_multiplier = 2.0
		eye.material_override = eye_material
		eye.position = Vector3(0, 0.1, -0.3)
		_head.add_child(eye)


	func _process(delta: float) -> void:
		if GameState.is_run_over():
			return
		if not GameState.base_devices_powered():
			_target = null
			return
		_scan -= delta
		_cooldown -= delta
		if _scan <= 0.0:
			_scan = SCAN_INTERVAL
			_target = _nearest_zombie()
		if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
			_target = null
			return
		var to: Vector3 = _target.global_position - global_position
		to.y = 0.0
		if to.length() > _range():
			_target = null
			return
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 10.0))
		if _cooldown <= 0.0:
			# 操作员加成：每名操作员射速 +25%
			_cooldown = FIRE_INTERVAL / (1.0 + 0.25 * GameState.defense_operator_count(global_position))
			_fire(_target)


	func _nearest_zombie() -> Node3D:
		return GameState.nearest_entity_in_group(global_position, "zombies", _range()) as Node3D


	func _fire(target: Node3D) -> void:
		var from := _head.global_position + Vector3(0, 0.05, 0)
		var to := target.global_position + Vector3(0, 1.0, 0)
		target.take_damage(_damage())
		_tracer(from, to)
		_flash(from)


	func _tracer(from: Vector3, to: Vector3) -> void:
		var parent := get_parent()
		if parent == null:
			return
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, from.distance_to(to))
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.8, 0.3)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.75, 0.25)
		material.emission_energy_multiplier = 3.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		parent.add_child(mesh)
		mesh.global_position = (from + to) / 2.0
		mesh.look_at(to, Vector3.UP)
		var tween := mesh.create_tween()
		tween.tween_property(mesh, "scale:x", 0.05, 0.1)
		tween.parallel().tween_property(mesh, "scale:y", 0.05, 0.1)
		tween.tween_callback(mesh.queue_free)


	func _flash(pos: Vector3) -> void:
		var parent := get_parent()
		if parent == null:
			return
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.12, 0.12)
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.9, 0.5)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		parent.add_child(mesh)
		mesh.global_position = pos
		var tween := mesh.create_tween()
		tween.tween_property(mesh, "scale", Vector3(0.04, 0.04, 0.04), 0.07)
		tween.tween_callback(mesh.queue_free)


# 迫击炮/火炮：远程曲射火力（同一套实体，数据按 defense_type 从 BASE_DEFENSES 读取）。
# E 交互选「指挥炮击」进入指挥模式：左键在射程内选打击点（炮弹 1.2 秒后落点爆炸，
# AoE 伤害），右键/Esc 退出指挥；每名操作员装填 +25%；
# 指挥时打击环跟随准星（绿=可打，红=超程/装填中）
class Mortar extends DefenseBase:
	const SHELL_SPEED := 33.0  # 米/秒：炮弹飞行时间随距离增长（40m≈1.2s，80m≈2.4s）

	var _barrel: Node3D = null
	var _cooldown := 0.0
	var _marker: MeshInstance3D = null


	func _range() -> float:
		return float(GameState.BASE_DEFENSES.get(defense_type, {}).get("range", 40.0))


	func _damage() -> int:
		return int(GameState.BASE_DEFENSES.get(defense_type, {}).get("damage", 80))


	func _fire_cd() -> float:
		return float(GameState.BASE_DEFENSES.get(defense_type, {}).get("cooldown", 6.0))


	func _blast() -> float:
		return float(GameState.BASE_DEFENSES.get(defense_type, {}).get("blast", 4.0))


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp(defense_type)
		var heavy := defense_type == "cannon"
		debris_size = Vector3(1.0, 0.8, 1.0) if not heavy else Vector3(1.4, 1.0, 1.4)
		debris_color = Color(0.3, 0.35, 0.28)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.0, 0.6, 1.0) if not heavy else Vector3(1.4, 0.7, 1.4)
		shape.shape = box_shape
		shape.position.y = 0.3
		add_child(shape)
		# 底座 + 倾斜炮管（火炮更粗更长）
		var base := MeshInstance3D.new()
		var base_box := BoxMesh.new()
		base_box.size = Vector3(1.0, 0.25, 1.0) if not heavy else Vector3(1.4, 0.3, 1.4)
		base.mesh = base_box
		var base_material := StandardMaterial3D.new()
		base_material.albedo_color = Color(0.32, 0.36, 0.3) if not heavy else Color(0.36, 0.3, 0.24)
		base.material_override = base_material
		base.position.y = 0.125
		add_child(base)
		_barrel = Node3D.new()
		_barrel.position.y = 0.3
		add_child(_barrel)
		var tube := MeshInstance3D.new()
		var tube_box := BoxMesh.new()
		tube_box.size = Vector3(0.22, 0.22, 1.2) if not heavy else Vector3(0.3, 0.3, 1.9)
		tube.mesh = tube_box
		var tube_material := StandardMaterial3D.new()
		tube_material.albedo_color = Color(0.2, 0.22, 0.2)
		tube.material_override = tube_material
		tube.position = Vector3(0, 0.35, -0.35) if not heavy else Vector3(0, 0.45, -0.55)
		tube.rotation.x = -0.7
		_barrel.add_child(tube)
		# 指挥打击环（指挥模式才显示）
		_marker = MeshInstance3D.new()
		var marker_mesh := CylinderMesh.new()
		marker_mesh.top_radius = 1.0
		marker_mesh.bottom_radius = 1.0
		marker_mesh.height = 0.06
		_marker.mesh = marker_mesh
		var marker_material := StandardMaterial3D.new()
		marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker_material.no_depth_test = true
		marker_material.albedo_color = Color(0.4, 1.0, 0.4, 0.5)
		_marker.material_override = marker_material
		_marker.visible = false
		add_child(_marker)


	func _exit_tree() -> void:
		if GameState.mortar_command == self:
			GameState.mortar_command = null
			GameState.mortar_volley = false
			GameState.mortar_command_kind = ""
			GameState.mortar_command_remote = false
			GameState.mortar_remote = false


	func _commanding() -> bool:
		return GameState.mortar_command == self


	func _process(delta: float) -> void:
		if GameState.is_run_over():
			if _commanding():
				GameState.mortar_command = null
				GameState.mortar_volley = false
				GameState.mortar_command_kind = ""
				GameState.mortar_command_remote = false
				GameState.mortar_remote = false
			return
		_cooldown = maxf(0.0, _cooldown - delta)
		if not _commanding():
			_marker.visible = false
			return
		var player = get_tree().get_first_node_in_group("player")
		if player == null or bool(player.get("_dead")):
			GameState.mortar_command = null
			GameState.mortar_volley = false
			GameState.mortar_command_kind = ""
			GameState.mortar_command_remote = false
			GameState.mortar_remote = false
			_marker.visible = false
			return
		# Q 远程指挥中玩家离开信号覆盖区：立即中断；
		# E 站在炮边的本地指挥不受信号限制（standalone 控制）
		if (
			GameState.mortar_command_remote
			and not GameState.point_in_signal_coverage(player.global_position)
		):
			_exit_command("离开信号区，远程炮击指挥已中断")
			return
		var aim = player.get("_aim_point")
		if not (aim is Vector3):
			_marker.visible = false
			return
		_marker.visible = true
		_marker.global_position = Vector3(aim.x, 0.1, aim.z)
		_marker.scale = Vector3(_blast(), 1.0, _blast())
		var ready := false
		var kind := GameState.mortar_command_kind
		if kind != "":
			# 单类型指挥：该类型任一门就绪且射程覆盖瞄准点即为可打
			GameState.refresh_artillery_cache()
			for n in GameState.artillery_cache:
				if str(n.get("defense_type")) != kind or bool(n.get("jammed")):
					continue
				if float(n.get("_cooldown")) <= 0.0 and n._in_range(aim) and n._coverage_ok(aim):
					ready = true
					break
		else:
			ready = (
				not jammed and _cooldown <= 0.0 and _in_range(aim) and _coverage_ok(aim)
			)
		var marker_material: StandardMaterial3D = _marker.material_override
		marker_material.albedo_color = (
			Color(0.4, 1.0, 0.4, 0.5) if ready else Color(1.0, 0.35, 0.3, 0.5)
		)


	func _in_range(point: Vector3) -> bool:
		var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
		return flat.length() <= _range()


	# 远程打击（Tab 圆盘）：打击点还必须在信号覆盖内；本地指挥不做此限制
	func _coverage_ok(point: Vector3) -> bool:
		return not GameState.mortar_remote or GameState.point_in_signal_coverage(point)


	func _unhandled_input(event: InputEvent) -> void:
		if not _commanding():
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_exit_command("退出炮击指挥")
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				var player = get_tree().get_first_node_in_group("player")
				var aim = player.get("_aim_point") if player != null else null
				if aim is Vector3:
					_try_fire(aim)
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_exit_command("退出炮击指挥")
			get_viewport().set_input_as_handled()


	func _exit_command(text: String) -> void:
		GameState.mortar_command = null
		GameState.mortar_volley = false
		GameState.mortar_command_kind = ""
		GameState.mortar_command_remote = false
		GameState.mortar_remote = false
		_marker.visible = false
		GameState.notify(text)


	func _try_fire(point: Vector3) -> void:
		# 联合打击：所有就绪的迫击炮/火炮齐射同一点（装填中/超程/被干扰/没炮弹的跳过）
		if GameState.mortar_volley:
			var fired := 0
			var skipped := 0
			GameState.refresh_artillery_cache()
			for n in GameState.artillery_cache:
				if bool(n.get("jammed")) or float(n.get("_cooldown")) > 0.0 or not n._in_range(point):
					skipped += 1
					continue
				if not n._consume_shell():
					skipped += 1
					continue
				n._fire_now(point, false)
				fired += 1
			if fired == 0:
				GameState.notify("没有可开火的炮（装填中/超程/被干扰）")
			elif skipped == 0:
				GameState.notify("联合打击：%d 门炮齐射！" % fired)
			else:
				GameState.notify("联合打击：%d 门炮齐射（%d 门未就绪）" % [fired, skipped])
			return
		if jammed:
			GameState.notify("%s被 Boss 干扰磁场沉默，无法开火" % _defense_name())
			return
		# 单类型指挥：每次点击只发射该类型中一门就绪的炮（优先自己，
		# 自己装填中则找下一门就绪的），直到全部进入装填
		var kind := GameState.mortar_command_kind
		if kind != "":
			var shooter: Node = null
			if _cooldown <= 0.0 and _in_range(point) and _coverage_ok(point):
				shooter = self
			else:
				GameState.refresh_artillery_cache()
				for n in GameState.artillery_cache:
					if n == self or str(n.get("defense_type")) != kind:
						continue
					if bool(n.get("jammed")) or float(n.get("_cooldown")) > 0.0:
						continue
					if not n._in_range(point) or not n._coverage_ok(point):
						continue
					shooter = n
					break
			if shooter == null:
				GameState.notify(
					"没有可开火的%s（全部装填中/超程/被干扰）" % _defense_name()
				)
				return
			if not shooter._consume_shell():
				GameState.notify("炮弹用尽（%s 在弹药加工台制造）" % shooter._shell_item_name())
				return
			shooter._fire_now(point, true)
			return
		if _cooldown > 0.0:
			GameState.notify("%s装填中… %d 秒" % [_defense_name(), int(ceil(_cooldown))])
			return
		if not _in_range(point):
			GameState.notify("打击点超出%s射程（%d 米）" % [_defense_name(), int(_range())])
			return
		if not _coverage_ok(point):
			GameState.notify("打击点不在信号覆盖内（据点或信号塔范围内才可远程打击）")
			return
		if not _consume_shell():
			GameState.notify("炮弹用尽（%s 在弹药加工台制造）" % _shell_item_name())
			return
		_fire_now(point, true)


	# 炮弹补给：开火消耗背包里的炮弹（弹药加工台制造）
	func _shell_item_id() -> String:
		return "mortar_shell" if String(defense_type) == "mortar" else "cannon_shell"


	func _shell_item_name() -> String:
		return String(GameState.ITEM_DEFS.get(_shell_item_id(), {}).get("name", "炮弹"))


	func _consume_shell() -> bool:
		# 测试模式炮弹无限（与枪械弹药/制造材料的测试模式免耗规则一致）
		if GameState.test_mode:
			return true
		if GameState.loot_count(_shell_item_id()) <= 0:
			return false
		GameState.remove_loot(_shell_item_id(), 1)
		return true


	# 实际开火：装填计时（操作员每人 +25% 装填速度）、炮口转向、噪音、出膛
	func _fire_now(point: Vector3, announce: bool) -> void:
		_cooldown = _fire_cd() / (1.0 + 0.25 * GameState.defense_operator_count(global_position))
		var target := Vector3(point.x, 0.0, point.z)
		var to := target - global_position
		_barrel.rotation.y = atan2(-to.x, -to.z)
		GameState.noise_at(global_position, 30.0)
		if announce:
			GameState.notify("%s开火！炮弹飞行中…" % _defense_name())
		_shell_to(target)


	# 炮弹曲射飞行（延迟落点爆炸）
	# 炮弹曲射飞行：飞行时间 = 距离 ÷ 速度（越远越久），抛物线可视化
	func _shell_to(target: Vector3) -> void:
		var from := global_position + Vector3(0, 1.2, 0)
		var dist := from.distance_to(target)
		var time := maxf(0.25, dist / SHELL_SPEED)
		var shell := MeshInstance3D.new()
		var shell_mesh := BoxMesh.new()
		shell_mesh.size = Vector3(0.18, 0.18, 0.36)
		shell.mesh = shell_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.25, 0.22, 0.18)
		shell.material_override = mat
		get_parent().add_child(shell)
		var apex := maxf(3.0, dist * 0.18)
		var land := target + Vector3(0, 0.3, 0)
		var flight := func(v: float) -> void:
			if is_instance_valid(shell):
				shell.global_position = from.lerp(land, v) + Vector3(0, sin(PI * v) * apex, 0.0)
		var tween := shell.create_tween()
		tween.tween_method(flight, 0.0, 1.0, time)
		await get_tree().create_timer(time).timeout
		if is_instance_valid(shell):
			shell.queue_free()
		if is_queued_for_deletion():
			return
		_explode(target)


	func _explode(center: Vector3) -> void:
		GameState.noise_at(center, 60.0)
		MeleeFx3D._burst(
			get_parent(), center + Vector3(0, 0.5, 0), 24,
			[Color(1.0, 0.7, 0.3), Color(0.9, 0.4, 0.15), Color(0.3, 0.3, 0.3)],
			6.0, 0.25, 0.6
		)
		var player = get_tree().get_first_node_in_group("player")
		for z in GameState.entities_in_group_in_radius(center, "zombies", _blast()):
			if z.is_queued_for_deletion() or bool(z.get("_dying")):
				continue
			# zombie3d 的 take_damage 第二参是「是否近战」布尔，不能传玩家节点
			z.take_damage(_damage())
		for npc in GameState.entities_in_group_in_radius(center, "npcs", _blast()):
			if npc.is_queued_for_deletion() or bool(npc.get("_dying")):
				continue
			if npc.has_method("take_damage"):
				# 炮击无差别：友军（随从免伤被 friendly_fire 穿透）、市民、工人一视同仁
				npc.take_damage(_damage(), player, true)
		# 炮击同样会炸到玩家（自己叫的炮也一样；藏匿/测试模式免伤在伤害入口内部判定）
		if player != null and player.has_method("take_damage"):
			if center.distance_to(player.global_position) <= _blast():
				player.take_damage(_damage())
		# 炮弹也会震伤建筑结构
		var demolisher := get_tree().get_first_node_in_group("demolisher")
		if demolisher != null and demolisher.has_method("damage_structure_at"):
			demolisher.damage_structure_at(center, _damage())


# 尖刺陷阱：0.8 米见方地刺板，丧尸踩中每秒 15 伤害；
# 碰撞在层 2（不挡丧尸/玩家走位，仅供建造模式准星选取），可被丧尸打爆
class Spikes extends DefenseBase:
	const SIZE := Vector3(0.8, 0.12, 0.8)

	var _tick := 0.0


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		collision_layer = 2
		collision_mask = 0
		hp = GameState.base_defense_hp("spikes")
		debris_size = Vector3(0.8, 0.3, 0.8)
		debris_color = Color(0.3, 0.3, 0.33)
		debris_noise = 14.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = SIZE
		shape.shape = box_shape
		shape.position.y = SIZE.y * 0.5
		add_child(shape)
		var plate := MeshInstance3D.new()
		var plate_box := BoxMesh.new()
		plate_box.size = Vector3(SIZE.x, 0.06, SIZE.z)
		plate.mesh = plate_box
		var plate_material := StandardMaterial3D.new()
		plate_material.albedo_color = Color(0.26, 0.26, 0.28)
		plate.material_override = plate_material
		plate.position.y = 0.03
		add_child(plate)
		var spike_material := StandardMaterial3D.new()
		spike_material.albedo_color = Color(0.62, 0.62, 0.66)
		for gx in 3:
			for gz in 3:
				var spike := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.055
				cone.height = 0.24
				spike.mesh = cone
				spike.material_override = spike_material
				spike.position = Vector3(-0.25 + gx * 0.25, 0.17, -0.25 + gz * 0.25)
				add_child(spike)


	func _process(delta: float) -> void:
		if GameState.is_run_over():
			return
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = 1.0
		# 操作员加成：每名操作员伤害 +25%
		var dps := int(
			GameState.BASE_DEFENSES["spikes"].get("dps", 15)
			* (1.0 + 0.25 * GameState.defense_operator_count(global_position))
		)
		for zombie in GameState.entities_in_group_in_radius(global_position, "zombies", 0.8):
			zombie.take_damage(dps)


# 围墙段：3 米长 2.5 米高的实体墙，挡丧尸与玩家，可被丧尸打爆
class Wall extends DefenseBase:
	const SIZE := Vector3(3.0, 2.5, 0.3)


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("wall")
		debris_size = SIZE
		debris_color = Color(0.5, 0.5, 0.53)
		debris_noise = 22.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = SIZE
		shape.shape = box_shape
		shape.position.y = SIZE.y * 0.5
		add_child(shape)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = SIZE
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.5, 0.53)
		mesh.material_override = material
		mesh.position.y = SIZE.y * 0.5
		add_child(mesh)
		# 墙顶压顶条
		var cap := MeshInstance3D.new()
		var cap_box := BoxMesh.new()
		cap_box.size = Vector3(SIZE.x + 0.06, 0.12, SIZE.z + 0.06)
		cap.mesh = cap_box
		var cap_material := StandardMaterial3D.new()
		cap_material.albedo_color = Color(0.36, 0.36, 0.39)
		cap.material_override = cap_material
		cap.position.y = SIZE.y + 0.05
		add_child(cap)


# 照明灯：3 米灯杆 + 发光灯泡，夜间自动点亮判定圈（meta lamp_on），可被丧尸打爆
class Lamp extends DefenseBase:
	var _bulb_material: StandardMaterial3D = null


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("lamp")
		debris_size = Vector3(0.4, 3.0, 0.4)
		debris_color = Color(0.32, 0.33, 0.36)
		debris_noise = 16.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.22, 3.0, 0.22)
		shape.shape = box_shape
		shape.position.y = 1.5
		add_child(shape)
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.09
		pole_mesh.height = 3.0
		pole.mesh = pole_mesh
		var pole_material := StandardMaterial3D.new()
		pole_material.albedo_color = Color(0.32, 0.33, 0.36)
		pole.material_override = pole_material
		pole.position.y = 1.5
		add_child(pole)
		var head := MeshInstance3D.new()
		var head_box := BoxMesh.new()
		head_box.size = Vector3(0.42, 0.14, 0.42)
		head.mesh = head_box
		var head_material := StandardMaterial3D.new()
		head_material.albedo_color = Color(0.25, 0.26, 0.28)
		head.material_override = head_material
		head.position.y = 3.02
		add_child(head)
		var bulb := MeshInstance3D.new()
		var bulb_box := BoxMesh.new()
		bulb_box.size = Vector3(0.3, 0.05, 0.3)
		bulb.mesh = bulb_box
		_bulb_material = StandardMaterial3D.new()
		_bulb_material.albedo_color = Color(0.9, 0.85, 0.6)
		_bulb_material.emission_enabled = true
		_bulb_material.emission = Color(1.0, 0.92, 0.6)
		_bulb_material.emission_energy_multiplier = 0.15
		bulb.material_override = _bulb_material
		bulb.position.y = 2.93
		add_child(bulb)


	func _process(_delta: float) -> void:
		var on: bool = GameState.is_night() and GameState.base_devices_powered()
		set_meta("lamp_on", on)
		_bulb_material.emission_energy_multiplier = 3.0 if on else 0.15


# 信号塔：把营地信号覆盖圈接力延伸出去（设计文档 5.5）。
# 自带电源（不耗营地电），300 HP，可被怪物摧毁；半径 40m，信号强度线性衰减。
class SignalTower extends DefenseBase:
	const RANGE := 400.0  # 信号覆盖半径（批次 151 扩大 10 倍）
	const TICK := 0.2

	var _signal_tick := 0.0

	func _ready() -> void:
		add_to_group("base_defense")
		hp = GameState.base_defense_hp("signal_tower")
		debris_size = Vector3(1.2, 1.6, 1.2)
		debris_color = Color(0.5, 0.55, 0.6)
		debris_noise = 16.0
		# 外观与地图基站同款（共享构建器，批次 145）
		var visual := STATION_MODEL_SCRIPT.build_station_visual()
		add_child(visual)
		# 碰撞体随塔基占地（可被怪物攻击）
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(3.2, 3.2, 2.8)
		shape.shape = box_shape
		shape.position.y = 1.6
		add_child(shape)

	func _process(delta: float) -> void:
		_signal_tick -= delta
		if _signal_tick > 0.0:
			return
		_signal_tick = TICK
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			GameState.report_signal(get_instance_id(), 0.0)
			return
		var dist := global_position.distance_to(player.global_position)
		# 操作员加成：每名操作员信号半径 +5 米
		var range := RANGE + 5.0 * GameState.defense_operator_count(global_position)
		var strength := clampf(1.0 - dist / range, 0.0, 1.0)
		GameState.report_signal(get_instance_id(), strength)

	func _destroy() -> void:
		GameState.clear_signal(get_instance_id())
		super._destroy()


# 基础工作台：黄色四方桌，有人（玩家/NPC）在旁操作时，
# 每 5 秒生产 10 金属 + 5 配件自动入玩家背包（上限 9999），无需电力
# 弹药加工台（原基础工作台，批次 156）：黄桌。制造全口径弹药 + 迫击炮弹/火炮弹
# （炮弹为 loot 物品，炮击开火时消耗）；材料统一为制造材料
class Workbench extends Fabricator:
	func _recipes() -> Dictionary:
		return {
			"pistol_ammo": {"name": "手枪弹药 ×6", "kind": "ammo", "craft": 5, "time": 10.0, "ammo": 6, "caliber": "pistol"},
			"smg_ammo": {"name": "冲锋枪弹药 ×30", "kind": "ammo", "craft": 10, "time": 20.0, "ammo": 30, "caliber": "smg"},
			"shotgun_ammo": {"name": "霰弹枪弹药 ×8", "kind": "ammo", "craft": 10, "time": 20.0, "ammo": 8, "caliber": "shotgun"},
			"rifle_ammo": {"name": "步枪弹药 ×30", "kind": "ammo", "craft": 15, "time": 30.0, "ammo": 30, "caliber": "rifle"},
			"sniper_ammo": {"name": "狙击枪弹药 ×5", "kind": "ammo", "craft": 15, "time": 30.0, "ammo": 5, "caliber": "sniper"},
			"lmg_ammo": {"name": "重机枪弹药 ×50", "kind": "ammo", "craft": 25, "time": 45.0, "ammo": 50, "caliber": "lmg"},
			"mortar_shell": {"name": "迫击炮弹 ×2", "kind": "loot", "loot": "mortar_shell", "qty": 2, "craft": 16, "time": 24.0},
			"cannon_shell": {"name": "火炮弹 ×2", "kind": "loot", "loot": "cannon_shell", "qty": 2, "craft": 30, "time": 36.0},
			"tank_shell": {"name": "坦克炮弹 ×3", "kind": "loot", "loot": "tank_shell", "qty": 3, "craft": 24, "time": 30.0},
			"grenade_round": {"name": "榴弹 ×5", "kind": "loot", "loot": "grenade_round", "qty": 5, "craft": 12, "time": 18.0},
			"rocket_round": {"name": "火箭弹 ×4", "kind": "loot", "loot": "rocket_round", "qty": 4, "craft": 18, "time": 25.0},
		}


	func _table_color() -> Color:
		return Color(0.85, 0.72, 0.15)


	func _progress_color() -> Color:
		return Color(0.3, 0.95, 0.4)
# 异能转换台（批次 250 改纯制作）：紫色四方桌——专做异能宝石
# （伤害 +10%/生命上限 +25 每颗，最多 3 颗）；发电职责移交异能发电机。
class Converter extends Fabricator:
	func _recipes() -> Dictionary:
		return {
			"anomaly_gem": {
				"name": "异能宝石 ×1（伤害+10% 生命+25，最多3颗）",
				"kind": "loot", "loot": "anomaly_gem", "craft": 30, "time": 45.0,
			},
		}


	func _table_color() -> Color:
		return Color(0.45, 0.25, 0.7)


	func _progress_color() -> Color:
		return Color(0.7, 0.35, 0.95)


	func _ready() -> void:
		super._ready()
		add_to_group("power_converters")


# 装备制作台：枪械蓝工作台。制造所有枪械与防具（防弹衣），
# 每秒耗 0.5 电力（批次 236 降 10 倍，原 5.0），需有人在场操作；材料统一为城市里搜刮来的「制造材料」（从背包直接扣除）
class Fabricator extends DefenseBase:
	const OPERATE_RANGE := 2.5
	const POWER_DRAIN := 0.5
	const RECIPES := {
		"pistol": {"name": "手枪", "kind": "weapon", "requires": "pistol", "craft": 40, "time": 30.0},
		"smg": {"name": "冲锋枪", "kind": "weapon", "requires": "smg", "craft": 80, "time": 60.0},
		"shotgun": {"name": "霰弹枪", "kind": "weapon", "requires": "shotgun", "craft": 100, "time": 90.0},
		"rifle": {"name": "步枪", "kind": "weapon", "requires": "rifle", "craft": 120, "time": 120.0},
		"sniper": {"name": "狙击枪", "kind": "weapon", "requires": "sniper", "craft": 180, "time": 150.0},
		"lmg": {"name": "重机枪", "kind": "weapon", "requires": "lmg", "craft": 240, "time": 180.0},
		"vest": {"name": "防弹衣（伤害抗性 +12%）", "kind": "loot", "loot": "vest", "craft": 30, "time": 40.0},
	}

	var _job := ""
	var _job_recipe := ""
	var _job_left := 0.0
	var _job_total := 1.0
	var _no_power_notify := 0
	var _progress_bg: MeshInstance3D = null
	var _progress_fill: MeshInstance3D = null
	var _gear: Node3D = null
	# 制作数量（菜单滑条设置）：999 = 持续制作直到材料/电力断
	var qty_sel := 1
	var _queue_left := 0
	var _queue_inf := false
	var _wait_notify := 0


	func _recipes() -> Dictionary:
		return RECIPES


	func _table_color() -> Color:
		return Color(0.35, 0.45, 0.65)


	func _progress_color() -> Color:
		return Color(0.35, 0.6, 1.0)


	func _decorate() -> void:
		pass


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp(String(defense_type))
		debris_size = Vector3(2.8, 1.8, 1.8)
		debris_color = Color(0.35, 0.45, 0.65)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(2.8, 1.8, 1.8)
		shape.shape = box_shape
		shape.position.y = 0.9
		add_child(shape)
		_build_body()
		_build_progress_bar()
		_build_gear()
		_decorate()


	func _build_body() -> void:
		# 工作台（桌面 + 四腿 + 虎钳）——批次 157 尺寸加大一倍
		var table_material := StandardMaterial3D.new()
		table_material.albedo_color = _table_color()
		var table := MeshInstance3D.new()
		var table_box := BoxMesh.new()
		table_box.size = Vector3(2.8, 0.16, 1.8)
		table.mesh = table_box
		table.material_override = table_material
		table.position.y = 1.68
		add_child(table)
		for sx in [-1.2, 1.2]:
			for sz in [-0.7, 0.7]:
				var leg := MeshInstance3D.new()
				var leg_box := BoxMesh.new()
				leg_box.size = Vector3(0.2, 1.6, 0.2)
				leg.mesh = leg_box
				leg.material_override = table_material
				leg.position = Vector3(sx, 0.8, sz)
				add_child(leg)
		var vice := MeshInstance3D.new()
		var vice_box := BoxMesh.new()
		vice_box.size = Vector3(0.6, 0.4, 0.4)
		vice.mesh = vice_box
		var vice_material := StandardMaterial3D.new()
		vice_material.albedo_color = Color(0.2, 0.22, 0.25)
		vice.material_override = vice_material
		vice.position = Vector3(0.7, 1.96, 0)
		add_child(vice)


	func _build_progress_bar() -> void:
		_progress_bg = MeshInstance3D.new()
		var bg_box := BoxMesh.new()
		bg_box.size = Vector3(2.0, 0.12, 0.06)
		_progress_bg.mesh = bg_box
		var bg_material := StandardMaterial3D.new()
		bg_material.albedo_color = Color(0.05, 0.05, 0.05, 0.8)
		bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_progress_bg.material_override = bg_material
		_progress_bg.position = Vector3(0, 2.7, 0)
		add_child(_progress_bg)
		_progress_fill = MeshInstance3D.new()
		var fill_box := BoxMesh.new()
		fill_box.size = Vector3(2.0, 0.09, 0.07)
		_progress_fill.mesh = fill_box
		var fill_material := StandardMaterial3D.new()
		fill_material.albedo_color = _progress_color()
		fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_progress_fill.material_override = fill_material
		_progress_fill.position = Vector3(0, 2.7, 0.01)
		add_child(_progress_fill)
		_progress_bg.visible = false
		_progress_fill.visible = false


	# 工作动效：制造进行中时台面上方有齿轮旋转（批次 157）
	func _build_gear() -> void:
		_gear = Node3D.new()
		_gear.position = Vector3(0, 3.3, 0)
		add_child(_gear)
		var gear_mat := StandardMaterial3D.new()
		gear_mat.albedo_color = Color(0.78, 0.74, 0.6)
		gear_mat.metallic = 0.5
		gear_mat.roughness = 0.45
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.3
		torus.outer_radius = 0.52
		ring.mesh = torus
		ring.material_override = gear_mat
		_gear.add_child(ring)
		for i in 8:
			var tooth := MeshInstance3D.new()
			var tooth_box := BoxMesh.new()
			tooth_box.size = Vector3(0.18, 0.12, 0.3)
			tooth.mesh = tooth_box
			tooth.material_override = gear_mat
			var a := TAU * float(i) / 8.0
			tooth.position = Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62)
			tooth.rotation.y = -a
			_gear.add_child(tooth)
		_gear.visible = true  # 批次 162：齿轮常驻可见，仅制造时转动


	func _process(delta: float) -> void:
		if GameState.is_run_over():
			return
		# 齿轮常驻可见（批次 162）；仅真正在制造时转动
		if _gear != null:
			_gear.visible = true  # 批次 162：齿轮常驻可见，仅制造时转动
		if _job == "":
			_show_progress(0.0)
			# 队列续做：材料够即自动开工；不齐则等待，料/电恢复后继续
			if _queue_inf or _queue_left > 0:
				_try_start_next()
			return
		var ops := GameState.defense_operator_count(global_position)
		if ops <= 0 and not _operator_nearby():
			return
		# 耗电：缺电暂停
		var rate := _power_drain_rate()
		var got := GameState.drain_base_power(rate * delta)
		if got < rate * delta * 0.5:
			if Time.get_ticks_msec() > _no_power_notify:
				_no_power_notify = Time.get_ticks_msec() + 5000
				GameState.notify("制造台缺电，制造暂停（需要电力驱动）")
			return
		# 正在制造：齿轮显示并转动
		if _gear != null:
			_gear.visible = true
			_gear.rotation.y += delta * 2.2
		_job_left -= delta * (1.0 + 0.25 * ops)
		_show_progress(clampf(1.0 - _job_left / _job_total, 0.0, 1.0))
		if _job_left <= 0.0:
			_finish_job()


	# 耗电速率（子类可改）
	func _power_drain_rate() -> float:
		return POWER_DRAIN


	func _operator_nearby() -> bool:
		var player = get_tree().get_first_node_in_group("player")
		if player != null and not bool(player.get("_dead")):
			if global_position.distance_to(player.global_position) <= OPERATE_RANGE:
				return true
		for npc in GameState.entities_in_group_in_radius(global_position, "npcs", OPERATE_RANGE):
			if not npc.is_queued_for_deletion() and not bool(npc.get("_dying")):
				return true
		return false


	func recipe_check(id: String) -> Array:
		var r: Dictionary = _recipes()[id]
		if _job != "":
			return [false, "制造中"]
		var craft := int(r.get("craft", 0))
		# 测试模式：制造材料无上限，不检查不消耗
		if craft > 0 and not GameState.test_mode and GameState.loot_count("craft_mat") < craft:
			return [false, "制造材料不足（需 ×%d）" % craft]
		return [true, ""]


	# 交互菜单：配方 + 卖掉（材料统一为背包里的制造材料，开工时直接扣除）
	func recipe_options() -> Array:
		var options: Array = []
		for id in _recipes():
			var r: Dictionary = _recipes()[id]
			var check := recipe_check(id)
			options.append({
				"id": "fab_make:" + id,
				"label": "制造 %s（制造材料×%d %d秒）" % [
					String(r["name"]), int(r.get("craft", 0)), int(r["time"])
				],
				"disabled": not check[0],
				"reason": String(check[1]),
			})
		var refund := GameState.base_defense_cost(String(defense_type)) / 2
		var machine_name := String(
			GameState.BASE_DEFENSES.get(String(defense_type), {}).get("name", "制造台")
		)
		options.append({"id": "sell", "label": "卖掉 %s（返还建材 ×%d）" % [machine_name, refund]})
		var op_count := GameState.defense_operator_count(global_position)
		var op_slots := GameState.operator_slots(String(defense_type))
		options.append({
			"id": "operators",
			"label": "操作员（%d/%d）· %s" % [
				op_count, op_slots, GameState.operator_desc(String(defense_type))
			],
		})
		return options


	func fabricator_choose(id: String) -> void:
		if id.begins_with("fab_make:"):
			var recipe_id := id.trim_prefix("fab_make:")
			var r: Dictionary = _recipes()[recipe_id]
			_job_recipe = recipe_id
			# 队列：qty_sel=999 视为持续制作直到材料/电力断；其余做 qty_sel 个
			_queue_inf = qty_sel >= 999
			_queue_left = qty_sel
			var check := recipe_check(recipe_id)
			if not check[0]:
				# 材料/电力不齐：排队等待，恢复后自动续做
				GameState.notify("排队等待材料/电力：%s" % String(check[1]))
				return
			if int(r.get("craft", 0)) > 0 and not GameState.test_mode:
				GameState.remove_loot("craft_mat", int(r["craft"]))
			_job = recipe_id
			_job_total = float(r["time"])
			_job_left = _job_total
			GameState.notify("开始制造：%s（%d 秒）" % [String(r["name"]), int(r["time"])])


	func _finish_job() -> void:
		var r: Dictionary = _recipes()[_job]
		match String(r["kind"]):
			"weapon":
				GameState.weapons[String(r.get("requires", _job))] = 1
				GameState.weapons_changed.emit()
			"ammo":
				GameState.add_ammo(String(r.get("caliber", "pistol")), "normal", int(r["ammo"]))
			"resource":
				GameState.add_resource(String(r["resource"]), int(r["qty"]))
			"loot":
				GameState.add_loot(String(r["loot"]), int(r.get("qty", 1)))
		GameState.notify("制造完成：%s" % String(r["name"]))
		_job = ""
		_show_progress(0.0)
		# 队列递减；持续模式（999）不清
		if _queue_left > 0:
			_queue_left -= 1


	# 队列续做：材料够即开工，不够则等待（料/电恢复后自动继续）
	func _try_start_next() -> void:
		if _job_recipe == "" or not _recipes().has(_job_recipe):
			_queue_left = 0
			_queue_inf = false
			return
		var check := recipe_check(_job_recipe)
		if not check[0]:
			if Time.get_ticks_msec() > _wait_notify:
				_wait_notify = Time.get_ticks_msec() + 5000
				GameState.notify("等待材料/电力继续制作：%s" % String(check[1]))
			return
		var r: Dictionary = _recipes()[_job_recipe]
		if int(r.get("craft", 0)) > 0 and not GameState.test_mode:
			GameState.remove_loot("craft_mat", int(r["craft"]))
		_job = _job_recipe
		_job_total = float(r["time"])
		_job_left = _job_total


	func _show_progress(ratio: float) -> void:
		var r := clampf(ratio, 0.0, 1.0)
		var on := r > 0.01
		_progress_bg.visible = on
		_progress_fill.visible = on
		if on:
			_progress_fill.scale.x = maxf(r, 0.02)
			_progress_fill.position.x = -0.5 * (1.0 - r)


# 食品加工台：绿桌，产食物（罐头/面包）
class FoodSynthesizer extends Fabricator:
	func _recipes() -> Dictionary:
		return {
			"food": {"name": "食物 ×5", "kind": "resource", "resource": "food", "qty": 5, "craft": 3, "time": 6.0},
		}


	func _table_color() -> Color:
		return Color(0.3, 0.7, 0.35)


# 药品制作台：白桌红十字，产医疗用品（绷带/恢复药水）
class MedStation extends Fabricator:
	func _recipes() -> Dictionary:
		return {
			"bandage": {"name": "绷带 ×1（瞬间+50）", "kind": "loot", "loot": "bandage", "craft": 6, "time": 10.0},
			"heal_potion": {"name": "恢复药水 ×1（10秒回100）", "kind": "loot", "loot": "heal_potion", "craft": 10, "time": 30.0},
		}


	func _table_color() -> Color:
		return Color(0.9, 0.9, 0.92)


	func _decorate() -> void:
		var cross_material := StandardMaterial3D.new()
		cross_material.albedo_color = Color(0.85, 0.15, 0.15)
		var bar_a := MeshInstance3D.new()
		var box_a := BoxMesh.new()
		box_a.size = Vector3(0.4, 0.06, 0.12)
		bar_a.mesh = box_a
		bar_a.material_override = cross_material
		bar_a.position = Vector3(-0.7, 1.84, 0)
		add_child(bar_a)
		var bar_b := MeshInstance3D.new()
		var box_b := BoxMesh.new()
		box_b.size = Vector3(0.12, 0.06, 0.4)
		bar_b.mesh = box_b
		bar_b.material_override = cross_material
		bar_b.position = Vector3(-0.7, 1.84, 0)
		add_child(bar_b)


# 医疗台（旧设施，已不在建造栏）：配方与药品制作台一致（绷带/恢复药水）
class PotionBrewer extends Fabricator:
	func _recipes() -> Dictionary:
		return {
			"bandage": {"name": "绷带 ×1（瞬间+50）", "kind": "loot", "loot": "bandage", "craft": 6, "time": 10.0},
			"heal_potion": {"name": "恢复药水 ×1（10秒回100）", "kind": "loot", "loot": "heal_potion", "craft": 10, "time": 30.0},
		}


	func _power_drain_rate() -> float:
		return 1.0  # 批次 236 降 10 倍（原 10.0）：仍是普通制作台的 2 倍重载


	func _progress_color() -> Color:
		return Color(0.9, 0.2, 0.2)


	func _build_body() -> void:
		# 绿白箱子：白色箱体 + 绿色顶盖
		var white_material := StandardMaterial3D.new()
		white_material.albedo_color = Color(0.9, 0.92, 0.9)
		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(2.2, 1.7, 1.7)
		box.mesh = box_mesh
		box.material_override = white_material
		box.position.y = 0.85
		add_child(box)
		var green_material := StandardMaterial3D.new()
		green_material.albedo_color = Color(0.25, 0.7, 0.35)
		var lid := MeshInstance3D.new()
		var lid_mesh := BoxMesh.new()
		lid_mesh.size = Vector3(2.3, 0.2, 1.8)
		lid.mesh = lid_mesh
		lid.material_override = green_material
		lid.position.y = 1.8
		add_child(lid)


# 发电机：小箱体 + 指示灯 + 低鸣震动；据点内有它时炮塔射程 +3 米（每据点限 1 个）
class Generator extends DefenseBase:
	var _body: MeshInstance3D = null
	var _lamp_material: StandardMaterial3D = null
	var _time := 0.0


	func _ready() -> void:
		add_to_group("base_defense")
		hp = GameState.base_defense_hp("generator")
		debris_size = Vector3(1.0, 0.9, 0.7)
		debris_color = Color(0.3, 0.36, 0.3)
		debris_noise = 26.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.0, 0.9, 0.7)
		shape.shape = box_shape
		shape.position.y = 0.45
		add_child(shape)
		_body = MeshInstance3D.new()
		var body_box := BoxMesh.new()
		body_box.size = Vector3(1.0, 0.9, 0.7)
		_body.mesh = body_box
		var body_material := StandardMaterial3D.new()
		body_material.albedo_color = Color(0.3, 0.36, 0.3)
		_body.material_override = body_material
		_body.position.y = 0.45
		add_child(_body)
		var panel := MeshInstance3D.new()
		var panel_box := BoxMesh.new()
		panel_box.size = Vector3(0.7, 0.3, 0.04)
		panel.mesh = panel_box
		var panel_material := StandardMaterial3D.new()
		panel_material.albedo_color = Color(0.2, 0.22, 0.24)
		panel.material_override = panel_material
		panel.position = Vector3(0.0, 0.55, -0.37)
		add_child(panel)
		var lamp := MeshInstance3D.new()
		var lamp_box := BoxMesh.new()
		lamp_box.size = Vector3(0.08, 0.08, 0.03)
		lamp.mesh = lamp_box
		_lamp_material = StandardMaterial3D.new()
		_lamp_material.albedo_color = Color(0.3, 1.0, 0.4)
		_lamp_material.emission_enabled = true
		_lamp_material.emission = Color(0.25, 1.0, 0.35)
		_lamp_material.emission_energy_multiplier = 2.0
		lamp.material_override = _lamp_material
		lamp.position = Vector3(0.24, 0.58, -0.4)
		add_child(lamp)


	func _process(delta: float) -> void:
		_time += delta
		# 低鸣：箱体轻微震动 + 指示灯呼吸闪烁
		if is_instance_valid(_body):
			_body.position.x = sin(_time * 31.0) * 0.012
			_body.position.y = 0.45 + sin(_time * 47.0) * 0.006
		if _lamp_material != null:
			_lamp_material.emission_energy_multiplier = 1.6 + sin(_time * 5.0) * 1.2


# 太阳能板：斜置电池板 + 边框，白天供电
class SolarPanel extends DefenseBase:
	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("solar")
		debris_size = Vector3(1.2, 0.15, 0.9)
		debris_color = Color(0.16, 0.2, 0.38)
		debris_noise = 14.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.3, 0.9, 1.1)
		shape.shape = box_shape
		shape.position.y = 0.45
		add_child(shape)
		var leg_material := StandardMaterial3D.new()
		leg_material.albedo_color = Color(0.35, 0.36, 0.4)
		for leg_x in [-0.45, 0.45]:
			var leg := MeshInstance3D.new()
			var leg_box := BoxMesh.new()
			leg_box.size = Vector3(0.08, 0.55, 0.08)
			leg.mesh = leg_box
			leg.material_override = leg_material
			leg.position = Vector3(leg_x, 0.27, 0.3)
			add_child(leg)
		var panel := MeshInstance3D.new()
		var panel_box := BoxMesh.new()
		panel_box.size = Vector3(1.3, 0.06, 1.0)
		panel.mesh = panel_box
		var panel_material := StandardMaterial3D.new()
		panel_material.albedo_color = Color(0.13, 0.18, 0.4)
		panel_material.emission_enabled = true
		panel_material.emission = Color(0.08, 0.12, 0.3)
		panel_material.emission_energy_multiplier = 0.4
		panel.material_override = panel_material
		panel.position.y = 0.62
		panel.rotation_degrees.x = -25.0
		add_child(panel)
		# 板面边框
		var frame := MeshInstance3D.new()
		var frame_box := BoxMesh.new()
		frame_box.size = Vector3(1.36, 0.04, 1.06)
		frame.mesh = frame_box
		var frame_material := StandardMaterial3D.new()
		frame_material.albedo_color = Color(0.55, 0.58, 0.62)
		frame.material_override = frame_material
		frame.position.y = 0.6
		frame.rotation_degrees.x = -25.0
		add_child(frame)


# 自制风力发电机：立杆 + 三叶旋转叶片（有无电都缓慢转动，纯视觉）
class Windmill extends DefenseBase:
	const ROTOR_SPEED := 1.2

	var _rotor: Node3D = null


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("windmill")
		debris_size = Vector3(0.3, 3.0, 0.3)
		debris_color = Color(0.5, 0.52, 0.55)
		debris_noise = 22.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.3, 3.2, 0.3)
		shape.shape = box_shape
		shape.position.y = 1.6
		add_child(shape)
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.05
		pole_mesh.bottom_radius = 0.1
		pole_mesh.height = 3.2
		pole.mesh = pole_mesh
		var pole_material := StandardMaterial3D.new()
		pole_material.albedo_color = Color(0.5, 0.52, 0.55)
		pole.material_override = pole_material
		pole.position.y = 1.6
		add_child(pole)
		# 机头舱
		var nacelle := MeshInstance3D.new()
		var nacelle_box := BoxMesh.new()
		nacelle_box.size = Vector3(0.22, 0.18, 0.4)
		nacelle.mesh = nacelle_box
		var nacelle_material := StandardMaterial3D.new()
		nacelle_material.albedo_color = Color(0.6, 0.6, 0.62)
		nacelle.material_override = nacelle_material
		nacelle.position = Vector3(0, 3.2, 0.08)
		add_child(nacelle)
		# 叶片转子：三片窄板绕中心排开，面向 -z
		_rotor = Node3D.new()
		_rotor.position = Vector3(0, 3.2, -0.18)
		add_child(_rotor)
		var hub := MeshInstance3D.new()
		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = 0.07
		hub_mesh.bottom_radius = 0.07
		hub_mesh.height = 0.1
		hub.mesh = hub_mesh
		hub.rotation_degrees.x = 90.0
		var hub_material := StandardMaterial3D.new()
		hub_material.albedo_color = Color(0.4, 0.42, 0.45)
		hub.material_override = hub_material
		_rotor.add_child(hub)
		var blade_material := StandardMaterial3D.new()
		blade_material.albedo_color = Color(0.72, 0.74, 0.78)
		for i in 3:
			var blade := MeshInstance3D.new()
			var blade_box := BoxMesh.new()
			blade_box.size = Vector3(0.09, 0.75, 0.03)
			blade.mesh = blade_box
			blade.material_override = blade_material
			var arm := Node3D.new()
			arm.rotation.z = TAU * float(i) / 3.0
			blade.position.y = 0.44
			arm.add_child(blade)
			_rotor.add_child(arm)


	func _process(delta: float) -> void:
		if _rotor != null:
			_rotor.rotation.z += delta * ROTOR_SPEED


# 异能发电机（批次 250）：吞玩家携带的异能量发电——
# 1 异能 = 30 电入缓冲，缓冲有电时输出 5.0/s（=50kW，与燃油发电机同档）。
class AnomalyGenerator extends DefenseBase:
	const POWER_CAP := 9999.0
	const ANOMALY_CAP := 9999
	const RATE := 30.0
	const OUTPUT := 5.0
	const POWER_TICK := 0.5

	var stored_power := 0.0
	var anomaly_buffer := 0
	var _power_tick := 0.0
	var _core: MeshInstance3D = null


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("anomaly_gen")
		debris_size = Vector3(1.2, 1.4, 1.2)
		debris_color = Color(0.25, 0.15, 0.35)
		debris_noise = 18.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.2, 1.8, 1.2)
		shape.shape = box_shape
		shape.position.y = 0.9
		add_child(shape)
		# 底座
		var base_mesh := MeshInstance3D.new()
		var base_box := BoxMesh.new()
		base_box.size = Vector3(1.2, 0.3, 1.2)
		base_mesh.mesh = base_box
		var base_material := StandardMaterial3D.new()
		base_material.albedo_color = Color(0.24, 0.2, 0.3)
		base_mesh.material_override = base_material
		base_mesh.position.y = 0.15
		add_child(base_mesh)
		# 发光核心柱：有缓冲电时亮紫，空了转暗
		_core = MeshInstance3D.new()
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = 0.22
		core_mesh.bottom_radius = 0.3
		core_mesh.height = 1.3
		_core.mesh = core_mesh
		var core_material := StandardMaterial3D.new()
		core_material.albedo_color = Color(0.55, 0.3, 0.85)
		core_material.emission_enabled = true
		core_material.emission = Color(0.6, 0.3, 0.95)
		core_material.emission_energy_multiplier = 1.6
		_core.material_override = core_material
		_core.position.y = 1.0
		add_child(_core)
		# 顶部护环
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.45
		ring_mesh.bottom_radius = 0.45
		ring_mesh.height = 0.12
		ring.mesh = ring_mesh
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = Color(0.3, 0.28, 0.38)
		ring.material_override = ring_material
		ring.position.y = 1.72
		add_child(ring)


	func _process(delta: float) -> void:
		if GameState.is_run_over():
			return
		# 连续放电：作为发电源放出 OUTPUT/s，缓冲同步消耗
		if stored_power > 0.0:
			stored_power = maxf(0.0, stored_power - OUTPUT * delta)
		_power_tick -= delta
		if _power_tick > 0.0:
			return
		_power_tick = POWER_TICK
		# 1. 玩家携带的异能进缓冲（上限 9999）
		var take := mini(GameState.anomaly, ANOMALY_CAP - anomaly_buffer)
		if take > 0:
			anomaly_buffer += take
			GameState.anomaly -= take
		# 2. 即时转换：1 异能 = 30 电
		var convert := mini(anomaly_buffer, int((POWER_CAP - stored_power) / RATE))
		if convert > 0:
			anomaly_buffer -= convert
			stored_power = minf(POWER_CAP, stored_power + convert * RATE)
		# 视觉反馈：缓冲电量驱动核心亮度
		if _core != null:
			var mat := _core.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 1.6 if stored_power > 0.0 else 0.15


	# 作为发电源的当前输出：缓冲有电 = 5.0/s（=50kW），空了为 0
	func power_output_rate() -> float:
		return OUTPUT if stored_power > 0.0 else 0.0


# 异能储存仓：力场玻璃罐，存异能结晶
class ContainmentUnit extends DefenseBase:
	var _field_material: StandardMaterial3D = null
	var _spin := 0.0


	func _ready() -> void:
		add_to_group("base_defense")
		GameState.request_spatial_rebuild()
		hp = GameState.base_defense_hp("containment")
		debris_size = Vector3(1.0, 0.6, 1.0)
		debris_color = Color(0.4, 0.3, 0.5)
		debris_noise = 14.0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.2, 1.6, 1.2)
		shape.shape = box_shape
		shape.position.y = 0.8
		add_child(shape)
		var base_material := StandardMaterial3D.new()
		base_material.albedo_color = Color(0.3, 0.32, 0.36)
		var base := MeshInstance3D.new()
		var base_box := BoxMesh.new()
		base_box.size = Vector3(1.1, 0.3, 1.1)
		base.mesh = base_box
		base.material_override = base_material
		base.position.y = 0.15
		add_child(base)
		var cap := MeshInstance3D.new()
		var cap_box := BoxMesh.new()
		cap_box.size = Vector3(1.1, 0.15, 1.1)
		cap.mesh = cap_box
		cap.material_override = base_material
		cap.position.y = 1.45
		add_child(cap)
		# 力场玻璃罐
		var field := MeshInstance3D.new()
		var field_cyl := CylinderMesh.new()
		field_cyl.top_radius = 0.42
		field_cyl.bottom_radius = 0.42
		field_cyl.height = 1.05
		field.mesh = field_cyl
		_field_material = StandardMaterial3D.new()
		_field_material.albedo_color = Color(0.55, 0.3, 0.85, 0.3)
		_field_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_field_material.emission_enabled = true
		_field_material.emission = Color(0.55, 0.3, 0.9)
		_field_material.emission_energy_multiplier = 0.8
		_field_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		field.material_override = _field_material
		field.position.y = 0.85
		add_child(field)


	func _process(delta: float) -> void:
		_spin += delta
		if _field_material != null:
			_field_material.emission_energy_multiplier = 0.7 + sin(_spin * 2.0) * 0.3
