extends CanvasLayer

var _crosshair: Label
var _scope_view: ScopeView
var _sight_view: SightView
var _status: Label
var _toast: Label
var _toast_tween: Tween
var _interact_label: Label
var _hp_bar: ProgressBar
var _hp_value: Label
var _stamina_bar: ProgressBar
var _stamina_value: Label
var _satiety_bar: ProgressBar
var _satiety_value: Label
# 载具血量显示（驾驶时显示）
var _vehicle_row: HBoxContainer
var _vehicle_bar: ProgressBar
var _vehicle_value: Label
var _res_strip: HBoxContainer
var _res_strip_labels := {}
var _perf_label: Label

# 顶部资源条定义：id / 悬停名 / 图标形状 / 颜色（身上 + 营地仓库合计）
const RES_STRIP_DEFS := [
	{"id": "money", "name": "现金", "icon": "coin", "color": Color(0.95, 0.8, 0.3)},
	{"id": "food", "name": "食物", "icon": "circle", "color": Color(0.55, 0.85, 0.45)},
	{"id": "meds", "name": "药品", "icon": "cross", "color": Color(0.92, 0.42, 0.42)},
	{"id": "ammo", "name": "弹药", "icon": "bullet", "color": Color(0.9, 0.85, 0.35)},
	{"id": "materials", "name": "建材", "icon": "square", "color": Color(0.8, 0.68, 0.45)},
	{"id": "fuel", "name": "燃料", "icon": "drop", "color": Color(0.95, 0.6, 0.25)},
	{"id": "craft_mat", "name": "制造材料", "icon": "gear", "color": Color(0.7, 0.78, 0.85)},
	{"id": "anomaly", "name": "异能量", "icon": "diamond", "color": Color(0.75, 0.5, 0.95)},
]
# 资源 id → 营地仓库键（空串 = 营地不存该类）
const RES_STRIP_BASE_KEY := {
	"money": "money", "food": "food", "meds": "meds", "ammo": "ammo",
	"materials": "materials", "fuel": "fuel", "anomaly": "crystals",
}
var _wanted: Label
var _cargo_label: Label
var _hint: Label
var _debug_label: Label
var _extract: Label
var _signal_value: Label
var _signal_timer := 0.0
var _eye_icon: Control
var _eye_timer := 0.0
var _watched := false
var _backpack_panel: Control
var _backpack_dim: ColorRect
var _inv_list: VBoxContainer
var _backpack_scroll: ScrollContainer
var _inv_echo_title: Label
var _inv_slots := {}
var _res_labels := {}
var _res_row: HBoxContainer
var _inv_grenade_label: Label
# 武器改装面板（从背包进入）
var _gunmod_panel: Control
var _gunmod_dim: ColorRect
var _gunmod_title: Label
var _gunmod_body: VBoxContainer
var _gunmod_scroll: ScrollContainer
var _gunmod_open := false
var _gunmod_weapon := ""
var _weapon_menu: PopupMenu = null
var _weapon_menu_id := ""
var _drag_item_id := ""
var _hotbar_bar: Control
var _skills_panel: Control
var _skills_dim: ColorRect
var _skills_title: Label
var _skills_rows := {}
var _dash_desc_label: Label = null
var _help_panel: Control = null
var _help_badge: Label = null
var _mutation_panel: Control
var _mutation_dim: ColorRect
var _mutation_title: Label
var _mutation_box: VBoxContainer
var _infection_overlay: ColorRect
var _nv_overlay: ColorRect
var _news_box: Control
var _news_label: Label
var _news_timer := 0.0
var _news_index := 9999
var _hotbar_slots: Array = []
var _full_map: MapView3D
var _map_hidden_nodes: Array = []
# 手机消息面板已删除：消息即时送达，重大消息在 M 地图上标点
var _end_panel: Control
var _end_title: Label
var _end_info: Label
var _last_phase := ""
var _pause_panel: Control
var _time_label: Label
var _day_bar: ProgressBar
var _echo_panel: Control
var _echo_title: Label
var _echo_options: Label
var _echo_choices: Array = []
var _echo_timer := 0.0
# 肉鸽模式：状态行（准备倒计时/剩余能量点/等级经验）+ 升级三选一横条
var _rogue_label: Label
var _rogue_panel: Control
var _rogue_title: Label
var _rogue_options: Label
var _rogue_choices: Array = []
var _rogue_timer := 0.0
const ROGUE_AUTO_PICK_SECONDS := 10.0
# 完美闪避：CD 图标（血条右侧小方框）+ 缓速变暗遮罩 + 玩家旁的逆时针秒表
var _dodge_icon: Control
var _dodge_was_cd := false
var _slowmo_overlay: ColorRect
var _stopwatch: Control
# 中毒状态：人物身旁的紫色水滴倒计时图标
var _poison_icon: Control
var _echo_list: Label
var _menu_panel: PanelContainer
var _menu_title: Label
var _menu_box: VBoxContainer
# 制作台数量滑条（仅制作台交互菜单显示）
var _qty_row: HBoxContainer = null
var _qty_slider: HSlider = null
var _qty_label: Label = null
var _menu_target: Node = null
var _menu_options: Array = []
var _menu_index := 0
var _menu_render_key := ""
var _last_menu_index := -1

const ECHO_AUTO_PICK_SECONDS := 3.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_crosshair.offset_left = -12
	_crosshair.offset_top = -18
	_crosshair.offset_right = 12
	_crosshair.offset_bottom = 18
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.add_theme_font_size_override("font_size", 24)
	_crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	add_child(_crosshair)

	_scope_view = ScopeView.new()
	_scope_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_view.visible = false
	add_child(_scope_view)

	_sight_view = SightView.new()
	_sight_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sight_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sight_view.visible = false
	add_child(_sight_view)

	_news_box = Control.new()
	_news_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_news_box.offset_left = 12
	_news_box.offset_top = 2
	_news_box.offset_right = 250
	_news_box.offset_bottom = 14
	_news_box.clip_contents = true
	_news_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_news_box)

	_news_label = Label.new()
	_news_label.position = Vector2(250, 0)
	_news_label.add_theme_font_size_override("font_size", 10)
	_news_label.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	_news_box.add_child(_news_label)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_toast.offset_left = 12
	_toast.offset_top = 176
	_toast.offset_right = 430
	_toast.offset_bottom = 194
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toast.add_theme_font_size_override("font_size", 12)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	add_child(_toast)

	_interact_label = Label.new()
	_interact_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interact_label.offset_left = -220
	_interact_label.offset_right = 220
	_interact_label.offset_top = -96
	_interact_label.offset_bottom = -72
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_label.add_theme_font_size_override("font_size", 12)
	_interact_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_interact_label.add_theme_constant_override("outline_size", 4)
	_interact_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_child(_interact_label)

	var box := VBoxContainer.new()
	box.position = Vector2(14, 44)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var hp_stat := _make_stat_bar(box, "生命", Color(0.35, 0.85, 0.4), "hp")
	_hp_bar = hp_stat["bar"]
	_hp_value = hp_stat["value"]
	var stamina_stat := _make_stat_bar(box, "体力", Color(0.85, 0.8, 0.35))
	_stamina_bar = stamina_stat["bar"]
	_stamina_value = stamina_stat["value"]
	var satiety_stat := _make_stat_bar(box, "饱食", Color(0.9, 0.62, 0.3))
	_satiety_bar = satiety_stat["bar"]
	_satiety_value = satiety_stat["value"]
	# 载具血量条（驾驶时显示）
	var vehicle_stat := _make_stat_bar(box, "载具", Color(0.55, 0.65, 0.85))
	_vehicle_bar = vehicle_stat["bar"]
	_vehicle_value = vehicle_stat["value"]
	_vehicle_row = box.get_child(box.get_child_count() - 1) as HBoxContainer
	_vehicle_row.visible = false
	_wanted = _make_label(box, 14, Color(1.0, 0.8, 0.2))
	_cargo_label = _make_label(box, 13, Color(0.9, 0.8, 0.55))
	var signal_row := HBoxContainer.new()
	signal_row.add_theme_constant_override("separation", 6)
	box.add_child(signal_row)
	_signal_value = _make_label(signal_row, 12, Color(0.8, 0.9, 1.0))
	_eye_icon = EyeIcon.new()
	_eye_icon.custom_minimum_size = Vector2(24, 14)
	_eye_icon.visible = false
	_eye_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	signal_row.add_child(_eye_icon)

	var minimap := MapView3D.new()
	add_child(minimap)
	var full_map := MapView3D.new()
	full_map.full = true
	full_map.z_index = 2
	add_child(full_map)
	_full_map = full_map

	_extract = Label.new()
	_extract.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_extract.offset_left = -200
	_extract.offset_top = -164
	_extract.offset_right = 200
	_extract.offset_bottom = -142
	_extract.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extract.add_theme_font_size_override("font_size", 14)
	_extract.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_child(_extract)

	_time_label = Label.new()
	_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_label.offset_left = -160
	_time_label.offset_top = 26
	_time_label.offset_right = 160
	_time_label.offset_bottom = 46
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_label.add_theme_font_size_override("font_size", 15)
	_time_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	_time_label.add_theme_constant_override("outline_size", 4)
	_time_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_child(_time_label)

	_day_bar = ProgressBar.new()
	_day_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_day_bar.offset_left = -100
	_day_bar.offset_top = 48
	_day_bar.offset_right = 100
	_day_bar.offset_bottom = 56
	_day_bar.min_value = 0.0
	_day_bar.max_value = 100.0
	_day_bar.show_percentage = false
	_day_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var day_fill := StyleBoxFlat.new()
	day_fill.bg_color = Color(0.95, 0.85, 0.45)
	_day_bar.add_theme_stylebox_override("fill", day_fill)
	var day_bg := StyleBoxFlat.new()
	day_bg.bg_color = Color(0, 0, 0, 0.55)
	_day_bar.add_theme_stylebox_override("background", day_bg)
	_day_bar.visible = false
	add_child(_day_bar)

	# 顶部资源条：小图标 +（身上）总数，总数含营地仓库
	_res_strip = HBoxContainer.new()
	_res_strip.position = Vector2(14, 6)
	_res_strip.add_theme_constant_override("separation", 10)
	_res_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_res_strip)
	# F3 性能监视悬浮窗（帧率/帧耗时/物理耗时/节点数/绘制调用）
	_perf_label = Label.new()
	_perf_label.position = Vector2(14, 28)
	_perf_label.add_theme_font_size_override("font_size", 9)
	_perf_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	_perf_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 黑色背景底，方便在任何画面上读数
	var perf_bg := StyleBoxFlat.new()
	perf_bg.bg_color = Color(0, 0, 0, 0.75)
	perf_bg.content_margin_left = 6
	perf_bg.content_margin_right = 6
	perf_bg.content_margin_top = 3
	perf_bg.content_margin_bottom = 3
	perf_bg.corner_radius_top_left = 3
	perf_bg.corner_radius_top_right = 3
	perf_bg.corner_radius_bottom_left = 3
	perf_bg.corner_radius_bottom_right = 3
	_perf_label.add_theme_stylebox_override("normal", perf_bg)
	_perf_label.visible = false
	add_child(_perf_label)
	for def in RES_STRIP_DEFS:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 3)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 资源名用文字不用图标，颜色区分种类
		var name_lbl := Label.new()
		name_lbl.text = String(def["name"])
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", def["color"])
		name_lbl.add_theme_constant_override("outline_size", 3)
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(name_lbl)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.9))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(lbl)
		_res_strip.add_child(entry)
		_res_strip_labels[String(def["id"])] = lbl

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -400
	_hint.offset_top = -122
	_hint.offset_right = -12
	_hint.offset_bottom = -100
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.75))
	_hint.text = "WASD 移动 · 双击方向 疾跑 · Shift 冲刺 · 空格 跳跃 · 左键 攻击 · 右键 开镜 · 1~2 武器槽 · R 换弹 · V 近战 · G 手雷 · B 背包 · C 能力\nE 交互 · Q 炮击指挥 · M 地图 · H 医疗 · U 车斗卸货 · J 随从 · T 手电 · N 摘面具 · Esc 鼠标"
	_hint.visible = false
	add_child(_hint)

	_build_hotbar()
	_build_interact_menu()
	_build_help_panel()
	_build_backpack_panel()
	_build_storage_panel()
	_build_operator_panel()
	_build_gunmod_panel()
	_build_skills_panel()
	_build_mutation_panel()
	_build_pause_panel()
	_build_echo_panel()
	_build_rogue_ui()
	_infection_overlay = ColorRect.new()
	_infection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_infection_overlay.color = Color(0.2, 0.9, 0.3, 0.0)
	_infection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_infection_overlay.z_index = 5
	add_child(_infection_overlay)
	# 夜视回响：夜晚+回响时的全屏绿色滤镜
	_nv_overlay = ColorRect.new()
	_nv_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nv_overlay.color = Color(0.2, 1.0, 0.4, 0.06)
	_nv_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nv_overlay.z_index = 4
	_nv_overlay.visible = false
	add_child(_nv_overlay)
	# 完美闪避缓速：全屏轻微变暗提示
	_slowmo_overlay = ColorRect.new()
	_slowmo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slowmo_overlay.color = Color(0.0, 0.0, 0.05, 0.28)
	_slowmo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slowmo_overlay.z_index = 3
	_slowmo_overlay.visible = false
	add_child(_slowmo_overlay)
	# 缓速期间玩家身边的逆时针秒表
	_stopwatch = StopwatchView.new()
	_stopwatch.custom_minimum_size = Vector2(44, 44)
	_stopwatch.size = Vector2(44, 44)
	_stopwatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stopwatch.z_index = 13
	_stopwatch.visible = false
	add_child(_stopwatch)
	# 中毒水滴倒计时图标（人物左侧）
	_poison_icon = PoisonIconView.new()
	_poison_icon.custom_minimum_size = Vector2(30, 30)
	_poison_icon.size = Vector2(30, 30)
	_poison_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poison_icon.z_index = 13
	_poison_icon.visible = false
	add_child(_poison_icon)
	# 闪避 CD 图标：生命行（VBox 14,20 起，行宽约 204）右侧，大小与行高一致
	_dodge_icon = DodgeIconView.new()
	_dodge_icon.position = Vector2(180, 20)
	_dodge_icon.custom_minimum_size = Vector2(14, 14)
	_dodge_icon.size = Vector2(14, 14)
	_dodge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dodge_icon)
	_build_end_panel()

	GameState.notified.connect(_show_toast)
	GameState.wanted_changed.connect(_refresh_wanted)
	GameState.weapons_changed.connect(_refresh_hotbar)
	GameState.map_toggled.connect(_on_map_toggled)
	GameState.backpack_toggled.connect(_on_backpack_toggled)
	GameState.skills_toggled.connect(_on_skills_toggled)
	GameState.skills_changed.connect(_refresh_skills)
	GameState.mutations_changed.connect(_refresh_skills)
	GameState.mutation_offered.connect(_on_mutation_offered)
	GameState.echo_offered.connect(_on_echo_offered)
	GameState.rogue_levelup_offered.connect(_on_rogue_offered)
	GameState.faction_changed.connect(_on_faction_changed)
	GameState.infection_changed.connect(_on_infection_changed)
	GameState.skill_points_changed.connect(_on_skill_points_changed)
	GameState.pause_toggled.connect(_on_pause_toggled)
	GameState.resources_changed.connect(_on_inventory_changed)
	GameState.weapons_changed.connect(_on_inventory_changed)
	GameState.home_base_changed.connect(_on_inventory_changed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.news_posted.connect(_on_news_posted)
	GameState.coverage_changed.connect(_on_coverage_changed)
	GameState.run_ended.connect(_on_run_ended)

	_refresh_wanted(GameState.wanted)
	_debug_label = Label.new()
	_debug_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_debug_label.offset_left = 8
	_debug_label.offset_top = -90
	_debug_label.add_theme_font_size_override("font_size", 10)
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_debug_label.visible = false
	add_child(_debug_label)
	_refresh_hotbar()
	_refresh_signal()
	_refresh_news()



func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var scoped: bool = (
		player != null and player.has_method("is_scoped") and player.is_scoped()
	)
	var sighted: bool = (
		player != null and player.has_method("is_sighted") and player.is_sighted()
	)
	_scope_view.visible = scoped and not GameState.map_open
	_sight_view.visible = sighted and not GameState.map_open
	# 2D 准星停用：地面瞄准环就是准星（任何坐标空间下都精确）
	_crosshair.visible = false
	if _debug_label != null and _debug_label.visible and player != null:
		_debug_label.text = "win=%s m=%s" % [
			str(DisplayServer.window_get_size()),
			str(get_viewport().get_mouse_position()),
		]
	if _perf_label != null and _perf_label.visible:
		var vram_mb := Performance.get_monitor(
			Performance.RENDER_VIDEO_MEM_USED
		) / 1048576.0
		_perf_label.text = (
			"FPS %d（帧时间 %.1fms）· 脚本 %.2fms · 物理 %.2fms · 节点 %d · 绘制调用 %d · 物理对象 %d\n"
			% [
				Engine.get_frames_per_second(),
				1000.0 / maxf(1.0, float(Engine.get_frames_per_second())),
				Performance.get_monitor(Performance.TIME_PROCESS),
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
			]
			+ "图元 %d · 显存 %.1fMB" % [
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				vram_mb,
			]
		)
	if scoped:
		if player.has_method("scope_hole_radius"):
			_scope_view.hole_radius = player.scope_hole_radius()
		if player.has_method("scope_mode"):
			_scope_view.mode = player.scope_mode()
		_scope_view.queue_redraw()
	if sighted:
		_sight_view.queue_redraw()
	_refresh_hotbar_ammo()
	_update_hotbar_cd()
	# 建造模式打开时隐藏武器栏（底部让给建造栏）
	if _hotbar_bar != null and not _overlay_hud_hidden:
		_hotbar_bar.visible = not GameState.base_build_mode
	_hp_bar.max_value = GameState.max_hp()
	_hp_bar.value = GameState.hp
	_hp_value.text = "%d/%d" % [GameState.hp, GameState.max_hp()]
	_stamina_bar.max_value = GameState.max_stamina()
	_stamina_bar.value = GameState.stamina
	_stamina_value.text = "%d/%d" % [
		int(GameState.stamina), int(GameState.max_stamina())
	]
	_satiety_bar.value = GameState.satiety
	_satiety_value.text = "%d/%d" % [int(GameState.satiety), int(GameState.MAX_SATIETY)]
	# 载具血量条：驾驶时显示载具 HP，否则隐藏
	if player != null and player.get("vehicle") != null:
		var veh = player.get("vehicle")
		_vehicle_row.visible = true
		_vehicle_bar.max_value = int(veh.get("max_hp"))
		_vehicle_bar.value = int(veh.get("hp"))
		_vehicle_value.text = "%d/%d" % [int(veh.get("hp")), int(veh.get("max_hp"))]
	else:
		_vehicle_row.visible = false
	_refresh_res_strip()
	if player != null and "vehicle" in player and player.vehicle != null:
		var vehicle = player.vehicle
		_cargo_label.visible = true
		var fuel_pct := int(vehicle.fuel_ratio() * 100.0)
		var fuel_text := "%s %d%%" % [vehicle.fuel_type_name(), fuel_pct]
		if fuel_pct <= 20:
			fuel_text += "（低油量！）"
		_cargo_label.text = "%s · 车斗建材 %d/%d" % [fuel_text, vehicle.cargo, vehicle.cargo_cap()]
	else:
		_cargo_label.visible = false
	if GameState.infected:
		_infection_overlay.color.a = 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.006)
	else:
		_infection_overlay.color.a = 0.0
	_nv_overlay.visible = GameState.is_night() and GameState.has_echo("e_night_vision")
	# 完美闪避：缓速变暗 + 玩家身旁逆时针秒表 + CD 倒计时
	_slowmo_overlay.visible = GameState.slowmo_active
	if GameState.slowmo_active and player != null:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var screen := camera.unproject_position(
				player.global_position + Vector3(0, 1.8, 0)
			)
			_stopwatch.position = screen + Vector2(30, -72)
			_stopwatch.set("progress", GameState.slowmo_progress())
			_stopwatch.queue_redraw()
			_stopwatch.visible = true
	else:
		_stopwatch.visible = false
	# 中毒图标：人物左侧紫色水滴，外圈逆时针倒计时
	if GameState.poison_timer > 0.0 and player != null:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var screen := camera.unproject_position(
				player.global_position + Vector3(0, 1.8, 0)
			)
			_poison_icon.position = screen + Vector2(-76, -72)
			_poison_icon.set("progress", GameState.poison_progress())
			_poison_icon.queue_redraw()
			_poison_icon.visible = true
	else:
		_poison_icon.visible = false
	var dodge_cd := GameState.slowmo_cd_left()
	_dodge_icon.set("cd_left", dodge_cd)
	if dodge_cd > 0.0:
		_dodge_was_cd = true
	elif _dodge_was_cd:
		# CD 走完：边缘高光闪一下提示就绪
		_dodge_was_cd = false
		_dodge_icon.set("flash", 0.7)
	_dodge_icon.set("flash", maxf(0.0, float(_dodge_icon.get("flash")) - delta))
	_dodge_icon.queue_redraw()
	if GameState.reloading:
		_extract.text = "换弹中 %d%%" % int(GameState.reload_progress() * 100.0)
	elif GameState.infected:
		_extract.text = "感染中 %d 秒 · 按 H 用医疗包治疗" % int(ceil(GameState.infection_timer))
	elif GameState.jail_active:
		_extract.text = "坐牢中 %d 秒…" % int(ceil(GameState.jail_timer))
	else:
		_extract.text = ""
	_refresh_time_display()
	_refresh_interact_prompt()
	_update_interact_menu()
	if _echo_panel != null and _echo_panel.visible and not get_tree().paused:
		_echo_timer -= delta
		if _echo_timer <= 0.0:
			_on_echo_chosen(0)
		else:
			_refresh_echo_title()
	if _rogue_label != null:
		if GameState.rogue_mode:
			_rogue_label.visible = true
			var phase := String(GameState.rogue_phase)
			if phase == "prep":
				_rogue_label.text = "准备时间 %d 秒 · 能量点休眠中" % int(ceil(GameState.rogue_prep_left))
			elif phase == "dev":
				_rogue_label.text = "第 %d 关已清除 · 发育期安全窗口 %d 秒" % [
					GameState.rogue_stage, int(ceil(GameState.rogue_dev_left))
				]
			elif phase == "won":
				_rogue_label.text = "已通关第 %d 关" % GameState.rogue_stage
			else:
				var parts: Array = [
					"第 %d 关 / 共 %d 关" % [GameState.rogue_stage, GameState.rogue_cores_left + GameState.rogue_stage - 1],
					"Lv.%d 经验 %d/%d" % [
						GameState.rogue_level, GameState.rogue_xp, GameState.rogue_xp_need()
					],
					"威胁 %d 级" % mini(1 + int(GameState.rogue_active_elapsed / 120.0), 10),
				]
				if GameState.has_home_base():
					parts.append(
						"营地 %d/%d" % [GameState.home_base_hp(), GameState.home_base_hp_max()]
					)
				_rogue_label.text = " · ".join(parts)
		else:
			_rogue_label.visible = false
	if _rogue_panel != null and _rogue_panel.visible and not get_tree().paused:
		_rogue_timer -= delta
		if _rogue_timer <= 0.0:
			_on_rogue_chosen(0)
		else:
			_refresh_rogue_title()
	_news_label.position.x -= delta * 55.0
	if _news_label.position.x + _news_label.get_minimum_size().x < 0.0:
		_news_label.position.x = _news_box.size.x
		_refresh_news()
	_signal_timer -= delta
	if _signal_timer <= 0.0:
		_signal_timer = 0.3
		_refresh_signal()
	_eye_timer -= delta
	if _eye_timer <= 0.0:
		_eye_timer = 0.15
		_watched = player != null and GameState.camera_watching(player.global_position)
	if _eye_icon != null:
		_eye_icon.visible = _watched
		if _watched:
			_eye_icon.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		_eye_icon.queue_redraw()


func _exit_tree() -> void:
	# HUD 随玩家销毁时复位菜单标志，避免泄漏到下一个场景
	if GameState.interact_menu_open:
		GameState.interact_menu_open = false


func _refresh_time_display() -> void:
	if GameState.phase == "prepare":
		var left := int(ceil(GameState.time_left))
		_time_label.text = "灾变倒计时 %02d:%02d" % [left / 60, left % 60]
		_time_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
		_day_bar.visible = false
	elif GameState.zombies_active():
		var night := GameState.is_night()
		_time_label.text = "第 %d 天 · %s" % [GameState.day_number, "夜" if night else "昼"]
		_time_label.add_theme_color_override(
			"font_color",
			Color(0.65, 0.75, 1.0) if night else Color(0.95, 0.92, 0.8)
		)
		_day_bar.visible = true
		_day_bar.value = GameState.day_progress() * 100.0
		var fill: StyleBoxFlat = _day_bar.get_theme_stylebox("fill")
		fill.bg_color = Color(0.45, 0.55, 0.95) if night else Color(0.95, 0.85, 0.45)
	else:
		_time_label.text = ""
		_day_bar.visible = false


func _refresh_wanted(_level: int) -> void:
	# 通缉系统已彻底删除：通缉标签永远隐藏
	_wanted.visible = false


# 顶部资源条刷新：（身上）总数，总数 = 身上 + 营地仓库
func _refresh_res_strip() -> void:
	if _res_strip == null:
		return
	var storage: Dictionary = (
		GameState.home_base.get("storage", {}) if GameState.has_home_base() else {}
	)
	for def in RES_STRIP_DEFS:
		var id := String(def["id"])
		var lbl: Label = _res_strip_labels.get(id)
		if lbl == null:
			continue
		var own := 0
		match id:
			"money":
				own = GameState.money
			"ammo":
				own = GameState.total_ammo()
			"anomaly":
				own = GameState.anomaly
			"craft_mat":
				own = GameState.loot_count("craft_mat")
			_:
				own = int(GameState.resources.get(id, 0))
		var base_key := String(RES_STRIP_BASE_KEY.get(id, ""))
		var total := own + (int(storage.get(base_key, 0)) if base_key != "" else 0)
		var text := "(%d) %d" % [own, total]
		if lbl.text != text:
			lbl.text = text


func _refresh_signal() -> void:
	var percent := int(round(GameState.reception_strength() * 100.0))
	var status := ""
	if GameState.is_jammer_active():
		status += " · 干扰开启中"
	if GameState.is_mask_active():
		status += " · 面具 %ds" % int(ceil(GameState.mask_seconds_left()))
	if GameState.is_sat_phone_active():
		status += " · 卫星通话中"
	if GameState.base_signal_strength() > 0.0:
		status += " · 据点信号覆盖中"
	_signal_value.text = "信号强度 %d%%%s" % [percent, status]
	if percent >= 66:
		_signal_value.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	elif percent >= 33:
		_signal_value.add_theme_color_override("font_color", Color(0.95, 0.9, 0.5))
	elif percent >= 10:
		_signal_value.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4))
	else:
		_signal_value.add_theme_color_override("font_color", Color(0.85, 0.6, 0.55))


func _refresh_news() -> void:
	var news: Array = GameState.news
	if news.is_empty():
		_news_label.text = ""
		return
	var recent: Array = news.slice(maxi(0, news.size() - 4))
	var parts: Array = []
	for entry in recent:
		parts.append(entry["text"])
	_news_label.text = "  ◆  ".join(parts) + "  ◆  "
	_news_label.position.x = _news_box.size.x


func _on_news_posted(_text: String) -> void:
	_news_index = 9999
	_news_timer = 4.0
	_refresh_news()
	_refresh_signal()


func _on_coverage_changed(_in_coverage: bool) -> void:
	_news_index = 9999
	_news_timer = 4.0
	_refresh_news()
	_refresh_signal()


func _on_map_toggled(open: bool) -> void:
	_full_map.visible = open
	if open:
		if GameState.backpack_open:
			GameState.toggle_backpack()
		if GameState.skills_open:
			GameState.toggle_skills()
		# 大地图打开时隐藏其他所有 HUD 元素，不遮挡地图
		_map_hidden_nodes.clear()
		for child in get_children():
			if child != _full_map and child.visible:
				child.visible = false
				_map_hidden_nodes.append(child)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		for child in _map_hidden_nodes:
			if is_instance_valid(child):
				child.visible = true
		_map_hidden_nodes.clear()
		if (
			not GameState.backpack_open
			and not GameState.skills_open
			and not GameState.pause_menu_open
		):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# 面板尺寸自适应：高度不超过屏幕 90%，分区滚动区随高度收缩，回响区贴着滚动区底部，资源栏贴面板底
func _fit_backpack_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	var h := minf(444.0, vp.y * 0.9)
	if _backpack_scroll == null:
		return
	_backpack_panel.offset_top = -h * 0.5
	_backpack_panel.offset_bottom = h * 0.5
	var list_h := maxf(90.0, h - 144.0)
	_backpack_scroll.size = Vector2(INV_LIST_W, list_h)
	var echo_y := INV_GRID_Y + list_h
	if _inv_echo_title != null:
		_inv_echo_title.position = Vector2(INV_PAD_X, echo_y + 6)
	if _echo_list != null:
		_echo_list.position = Vector2(INV_PAD_X, echo_y + 24)
		_echo_list.size = Vector2(INV_LIST_W, maxf(24.0, h - echo_y - 32.0))
	if _res_row != null:
		_res_row.position = Vector2(INV_PAD_X, h - 30)


func _on_backpack_toggled(open: bool) -> void:
	_backpack_panel.visible = open
	_backpack_dim.visible = open
	_set_overlay_hud_hidden(open or GameState.skills_open)
	if open:
		if GameState.map_open:
			GameState.toggle_map()
		if GameState.skills_open:
			GameState.toggle_skills()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_fit_backpack_panel()
		_refresh_backpack()
	elif (
		not GameState.map_open
		and not GameState.skills_open
		and not GameState.pause_menu_open
	):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


var _overlay_hud_hidden := false


func _set_overlay_hud_hidden(hidden: bool) -> void:
	_overlay_hud_hidden = hidden
	if _hotbar_bar != null:
		_hotbar_bar.visible = not hidden and not GameState.base_build_mode
	# 玩法提示改为 F1 打开，常态隐藏
	_hint.visible = false


# F1 玩法帮助：简介 + 按键，平时只留右下角一个小提示
func _build_help_panel() -> void:
	_help_badge = Label.new()
	_help_badge.text = "F1 玩法"
	_help_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_help_badge.offset_left = -64
	_help_badge.offset_top = -140
	_help_badge.offset_right = -12
	_help_badge.offset_bottom = -124
	_help_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help_badge.add_theme_font_size_override("font_size", 10)
	_help_badge.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7, 0.8))
	add_child(_help_badge)

	_help_panel = Control.new()
	_help_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help_panel.visible = false
	_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_help_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := PanelContainer.new()
	center.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	box.add_child(vbox)
	var title := Label.new()
	title.text = "玩法简介（F1 关闭）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	vbox.add_child(title)
	var intro := Label.new()
	intro.text = (
		"灾变倒计时 5 分钟：囤物资、买装备、选好据点。\n"
		+ "异变雨降临后活过 7 天并撤离：白天搜刮，夜晚守家。\n"
		+ "击杀丧尸攒异能量与物资；加油站给车加油；第 3 天全城断电后，\n"
		+ "靠发电机（烧燃料）/太阳能/风力给据点设备供电，或修复发电厂。\n"
		+ "紫色异能量场会不断刷怪——打爆核心掉结晶（收集要穿防化服）。\n"
		+ "走近市民按 E 招募随从，J 打开随从面板指派拾荒/巡逻/防守。"
	)
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", Color(0.85, 0.88, 0.9))
	vbox.add_child(intro)
	var keys := Label.new()
	keys.text = _hint.text
	keys.add_theme_font_size_override("font_size", 11)
	keys.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	vbox.add_child(keys)


func _build_pause_panel() -> void:
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_panel.visible = false
	add_child(_pause_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	_pause_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = "游戏暂停"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := Button.new()
	resume.text = "继续游戏"
	resume.custom_minimum_size = Vector2(220, 36)
	resume.add_theme_font_size_override("font_size", 16)
	resume.pressed.connect(GameState.toggle_pause_menu)
	box.add_child(resume)
	var quit := Button.new()
	quit.text = "返回主界面"
	quit.custom_minimum_size = Vector2(220, 36)
	quit.add_theme_font_size_override("font_size", 16)
	quit.pressed.connect(GameState.quit_to_menu)
	box.add_child(quit)
	var tip := Label.new()
	tip.text = "Esc 继续游戏"
	tip.add_theme_font_size_override("font_size", 11)
	tip.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)


func _on_pause_toggled(open: bool) -> void:
	_pause_panel.visible = open
	_set_overlay_hud_hidden(open)
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif (
		not GameState.backpack_open
		and not GameState.skills_open
		and not GameState.map_open
		and not GameState.pause_menu_open
	):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_skills_toggled(open: bool) -> void:
	_skills_panel.visible = open
	_skills_dim.visible = open
	_set_overlay_hud_hidden(open or GameState.backpack_open)
	if open:
		if GameState.map_open:
			GameState.toggle_map()
		if GameState.backpack_open:
			GameState.toggle_backpack()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_skills()
	elif (
		not GameState.map_open
		and not GameState.backpack_open
		and not GameState.pause_menu_open
	):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_skill_points_changed(_value: int) -> void:
	if GameState.skills_open:
		_refresh_skills()


func _on_infection_changed(_infected: bool) -> void:
	if not GameState.infected:
		_infection_overlay.color.a = 0.0


func _on_faction_changed(_faction: String, _alignment: String) -> void:
	GameState.notify(
		"你现在是：%s" % ("好丧尸" if GameState.is_good_zombie() else "坏丧尸")
	)


func _on_inventory_changed() -> void:
	if GameState.backpack_open:
		_refresh_backpack()


func _on_money_changed(_value: int) -> void:
	if GameState.backpack_open:
		_refresh_backpack()



func _refresh_interact_prompt() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		_interact_label.text = ""
		_update_hover_highlight(null)
		return
	if _menu_target != null:
		_interact_label.text = ""
		_update_hover_highlight(null)
		return
	# 拆除（Z）与交互（E）提示共存：准星对着可拆目标显示拆除提示，
	# 附近有交互目标同时显示 E 提示——两条互不顶掉，各按各的键
	var lines: Array = []
	var aim_text := _priority_prompt(player)
	if aim_text != "":
		lines.append(aim_text)
	# 统一交互菜单协议：附近有 interact_options 非空的节点时提示按 E 出菜单
	var found := _find_interact_target(player)
	_update_hover_highlight(found.get("node") if not found.is_empty() else null)
	if not found.is_empty():
		lines.append("%s · E 交互" % _interact_title(found["node"]))
	if not lines.is_empty():
		_interact_label.text = "\n".join(lines)
		return
	var best_text := ""
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactables"):
		var text: String = node.prompt_text()
		if text == "":
			continue
		var dist: float = player.global_position.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best_text = text
	_interact_label.text = best_text


# —— 统一交互菜单：按 E 出菜单，W/S 上下选择、E 确认，其它键关闭 ——
# 协议：节点实现 interact_options(player) -> Array[{id, label, disabled?, reason?}]
# （空数组 = 不可交互）与 interact_choose(id, player)；可选 interact_title() 作为菜单标题。
# 只有 1 个可用选项时按 E 直接执行不弹菜单；禁用项灰色不可选并附原因。

func _interact_title(node: Node) -> String:
	if node.has_method("interact_title"):
		var title: String = node.interact_title()
		if title != "":
			return title
	return "交互"


# 声明了 prompt_priority() 且返回 true 的节点（拆除玩法：准星正对着可拆目标），
# 其 prompt_text 与「E 交互」提示同时显示（两行共存，各按各的键）
func _priority_prompt(player: Node3D) -> String:
	var best_text := ""
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactables"):
		if not node.has_method("prompt_priority"):
			continue
		if not bool(node.prompt_priority()):
			continue
		var text: String = node.prompt_text()
		if text == "":
			continue
		var dist: float = player.global_position.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best_text = text
	return best_text


# 交互对象选取：只与鼠标悬停位置上的、且处于交互距离内的单位交互
# （interact_options 返回非空即视为「在交互距离内且可用」，节点自行判定距离/状态）
const INTERACT_MOUSE_PX := 28.0  # 鼠标吸附阈值（按 360p 画布缩放）
# 带占地的建筑交互点（BaseDoor）：鼠标射线与占地棱柱求交即算悬停，
# 与拆除射线命中楼体认同一区域，消除「拆除认、交互不认」的判定偏差
const INTERACT_FOOTPRINT_HEIGHT := 14.0
# 测试钩子：headless 无法移动真实鼠标时，测试可写入该坐标替代鼠标位置
var interact_hover_override := Vector2.INF


func _find_interact_target(player: Node3D) -> Dictionary:
	var camera: Camera3D = player.get("camera")
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var use_override := interact_hover_override != Vector2.INF
	var mouse := (
		interact_hover_override if use_override else get_viewport().get_mouse_position()
	)
	var px_threshold := INTERACT_MOUSE_PX * get_viewport().get_visible_rect().size.y / 360.0
	var mouse_best: Node = null
	var mouse_best_px := INF
	var mouse_options: Array = []
	for node in get_tree().get_nodes_in_group("interactables"):
		if not node.has_method("interact_options"):
			continue
		var options: Array = node.interact_options(player)
		if options.is_empty():
			continue
		if not use_override and camera.is_position_behind(node.global_position):
			continue
		var footprint = node.get("footprint_half")
		if footprint is Vector2 and footprint != Vector2.ZERO:
			# 建筑：鼠标指着占地棱柱（楼体）就算悬停，对齐拆除的命中区域
			var center: Vector3 = node.global_position + node.get("reach_center_offset")
			if not _mouse_ray_hits_footprint(camera, mouse, center, footprint):
				continue
			var fpx := 0.0
			if not camera.is_position_behind(center):
				fpx = camera.unproject_position(center).distance_to(mouse)
			if fpx < mouse_best_px:
				mouse_best_px = fpx
				mouse_best = node
				mouse_options = options
			continue
		var px := camera.unproject_position(node.global_position).distance_to(mouse)
		if px < px_threshold and px < mouse_best_px:
			mouse_best_px = px
			mouse_best = node
			mouse_options = options
	if mouse_best != null:
		return {"node": mouse_best, "options": mouse_options}
	return {}


# 鼠标射线与建筑占地棱柱（xz 矩形 × 固定高度）求交，slab 法
func _mouse_ray_hits_footprint(
	camera: Camera3D, mouse: Vector2, center: Vector3, half: Vector2
) -> bool:
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var bmin := Vector3(center.x - half.x, 0.0, center.z - half.y)
	var bmax := Vector3(center.x + half.x, INTERACT_FOOTPRINT_HEIGHT, center.z + half.y)
	var t_near := 0.0
	var t_far := 1e9
	for axis in 3:
		var o := origin[axis]
		var d := dir[axis]
		if absf(d) < 1e-8:
			if o < bmin[axis] or o > bmax[axis]:
				return false
			continue
		var ta := (bmin[axis] - o) / d
		var tb := (bmax[axis] - o) / d
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t_near = maxf(t_near, ta)
		t_far = minf(t_far, tb)
		if t_near > t_far:
			return false
	return true


# —— 悬停金色光晕：鼠标指着可交互对象时，沿其网格轮廓描一圈很淡的金色 ——
var _hover_mat: StandardMaterial3D = null
var _hover_node: Node = null
var _hover_meshes: Array = []


func _hover_material() -> StandardMaterial3D:
	if _hover_mat == null:
		_hover_mat = StandardMaterial3D.new()
		_hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hover_mat.albedo_color = Color(1.0, 0.84, 0.35, 0.45)
		_hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hover_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		# 反面外扩描边（ inverted hull ）：只勾勒轮廓一圈光晕
		_hover_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		_hover_mat.grow_enabled = true
		_hover_mat.grow_amount = 0.05
		_hover_mat.no_depth_test = true
	return _hover_mat


func _update_hover_highlight(node: Node) -> void:
	if _hover_node != null and not is_instance_valid(_hover_node):
		_hover_node = null
		_hover_meshes.clear()
	if node == _hover_node:
		return
	for mesh in _hover_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
	_hover_meshes.clear()
	_hover_node = node
	if node == null:
		return
	for mesh in _hover_meshes_of(node):
		mesh.material_overlay = _hover_material()
		_hover_meshes.append(mesh)


# 收集要描边的网格：节点自身与子孙；带占地的建筑门（BaseDoor）描整栋楼
func _hover_meshes_of(node: Node) -> Array:
	var out: Array = []
	_collect_meshes(node, out)
	var footprint = node.get("footprint_half")
	if footprint is Vector2 and footprint != Vector2.ZERO:
		var center: Vector3 = node.global_position + node.get("reach_center_offset")
		var root := node.get_parent()
		if root != null:
			for child in root.get_children():
				if child == node or not child is Node3D:
					continue
				var p: Vector3 = child.global_position
				if (
					absf(p.x - center.x) <= footprint.x + 1.0
					and absf(p.z - center.z) <= footprint.y + 1.0
				):
					_collect_meshes(child, out)
	return out


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _menu_blocked() -> bool:
	if (
		GameState.is_run_over()
		or GameState.any_panel_open()
		or GameState.pause_menu_open
	):
		return true
	# 拆除进行中按 E 不开交互菜单（拆除是独立按键的交互，互不抢占）
	var demolisher := get_tree().get_first_node_in_group("demolisher")
	return demolisher != null and bool(demolisher.get("_running"))


func _try_interact_press() -> void:
	if _menu_blocked():
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("vehicle") != null:
		return
	var found := _find_interact_target(player)
	if found.is_empty():
		return
	var options: Array = found["options"]
	if options.size() == 1 and not bool(options[0].get("disabled", false)):
		if String(options[0]["id"]) == "storage":
			open_storage_panel()
		else:
			found["node"].interact_choose(String(options[0]["id"]), player)
		return
	_open_interact_menu(found["node"], options)


func _open_interact_menu(target: Node, options: Array) -> void:
	_menu_target = target
	_menu_options = options
	_menu_index = 0
	_menu_render_key = ""
	GameState.interact_menu_open = true
	_menu_panel.visible = true
	_refresh_interact_menu()
	# 交互期间让目标停住（市民站定，不会菜单没选完就走远）
	if target.has_method("on_interact_menu_open"):
		target.on_interact_menu_open(get_tree().get_first_node_in_group("player"))


func _close_interact_menu() -> void:
	if _menu_target != null and is_instance_valid(_menu_target):
		if _menu_target.has_method("on_interact_menu_close"):
			_menu_target.on_interact_menu_close(
				get_tree().get_first_node_in_group("player")
			)
	_menu_target = null
	_menu_options = []
	GameState.interact_menu_open = false
	if _menu_panel != null:
		_menu_panel.visible = false


func _choose_menu_option(index: int) -> void:
	if _menu_target == null or not is_instance_valid(_menu_target):
		_close_interact_menu()
		return
	if index < 0 or index >= _menu_options.size():
		return
	var option: Dictionary = _menu_options[index]
	if bool(option.get("disabled", false)):
		var reason := String(option.get("reason", ""))
		if reason != "":
			GameState.notify(reason)
		return
	var player = get_tree().get_first_node_in_group("player")
	var target := _menu_target
	_close_interact_menu()
	if String(option["id"]) == "storage":
		open_storage_panel()
	elif player != null:
		target.interact_choose(String(option["id"]), player)


# 菜单开着时每帧重取选项：走远/状态变化（如引导开始）自动关闭，禁用态随资源刷新
func _update_interact_menu() -> void:
	if _menu_target == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	var options: Array = []
	if (
		player != null
		and player.get("vehicle") == null
		and is_instance_valid(_menu_target)
		and not _menu_blocked()
	):
		options = _menu_target.interact_options(player)
	if options.is_empty():
		_close_interact_menu()
		return
	_menu_options = options
	_refresh_interact_menu()


# 制作数量滑条回调：写入目标台子的 qty_sel（999 = 持续制作）
func _on_qty_changed(value: float) -> void:
	var qty := int(value)
	if _menu_target != null and _menu_target.has_method("fabricator_choose"):
		_menu_target.set("qty_sel", qty)
	if _qty_label != null:
		_qty_label.text = "持续" if qty >= 999 else "×%d" % qty


func _refresh_interact_menu() -> void:
	if _menu_panel == null or _menu_target == null:
		return
	# _update_interact_menu 每帧都会调到这里：标题、选项集合、选中项都没变就不重建——
	# 既省掉每帧新建 Label 的开销，也避免 queue_free 延迟到帧末才释放导致的同帧重影
	var key := "%s|%s" % [_interact_title(_menu_target), _options_key()]
	if key == _menu_render_key and _last_menu_index == _menu_index:
		return
	_menu_render_key = key
	_last_menu_index = _menu_index
	_menu_title.text = _interact_title(_menu_target)
	# 制作数量滑条：仅制作台显示；打开时读台子的上次选择
	var is_fab := _menu_target.has_method("fabricator_choose")
	if _qty_row != null:
		_qty_row.visible = is_fab
		if is_fab and _qty_slider != null:
			var qty := int(_menu_target.get("qty_sel"))
			if _qty_slider.value != float(qty):
				_qty_slider.set_value_no_signal(float(qty))
				_qty_label.text = "持续" if qty >= 999 else "×%d" % qty
	for child in _menu_box.get_children():
		_menu_box.remove_child(child)
		child.queue_free()
	for i in mini(_menu_options.size(), 9):
		var option: Dictionary = _menu_options[i]
		var label := Label.new()
		var disabled := bool(option.get("disabled", false))
		var selected := i == _menu_index
		var body := "[%d] %s" % [i + 1, String(option.get("label", option.get("id", "?")))]
		var reason := String(option.get("reason", ""))
		if disabled and reason != "":
			body += "（%s）" % reason
		# W/S 上下选择：当前项加 ▶ 前缀 + 高亮底色（序号仅作参照，选中由 W/S 决定）
		var text := ("▶ " if selected else "　 ") + body
		label.text = text
		label.add_theme_font_size_override("font_size", 12)
		var col: Color
		if disabled:
			col = Color(0.55, 0.58, 0.6)
		elif selected:
			col = Color(1.0, 0.9, 0.4)
		else:
			col = Color(0.92, 0.95, 0.92)
		label.add_theme_color_override("font_color", col)
		if selected:
			var hl := StyleBoxFlat.new()
			hl.bg_color = Color(1.0, 0.85, 0.3, 0.18)
			hl.set_corner_radius_all(3)
			hl.content_margin_left = 4
			hl.content_margin_right = 4
			label.add_theme_stylebox_override("normal", hl)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_box.add_child(label)
	var hint := Label.new()
	hint.text = "W/S 上下选择 · E 确认 · 其它键关闭"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box.add_child(hint)


# 菜单内容签名：用于跳过无变化的每帧重建（id/label/禁用态 变了才重画）
func _options_key() -> String:
	var parts := PackedStringArray()
	for o in _menu_options:
		parts.append("%s|%s|%s" % [
			String(o.get("id", "")), String(o.get("label", "")), str(bool(o.get("disabled", false)))
		])
	return ";".join(parts)


func _build_interact_menu() -> void:
	# 屏幕下方居中竖排选项面板（交互提示上方，不遮挡热键栏）
	_menu_panel = PanelContainer.new()
	_menu_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_menu_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu_panel.offset_left = -170
	_menu_panel.offset_right = 170
	_menu_panel.offset_top = -104
	_menu_panel.offset_bottom = -104
	_menu_panel.visible = false
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.09, 0.88)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_menu_panel.add_theme_stylebox_override("panel", style)
	add_child(_menu_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(box)
	_menu_title = Label.new()
	_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_title.add_theme_font_size_override("font_size", 13)
	_menu_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_menu_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_menu_title)
	# 制造数量滑条（仅制作台显示）：拖到 999 = 持续制作
	_qty_row = HBoxContainer.new()
	_qty_row.visible = false
	_qty_row.add_theme_constant_override("separation", 4)
	box.add_child(_qty_row)
	var qty_name := Label.new()
	qty_name.text = "制作数量"
	qty_name.add_theme_font_size_override("font_size", 11)
	qty_name.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	_qty_row.add_child(qty_name)
	_qty_slider = HSlider.new()
	_qty_slider.min_value = 1.0
	_qty_slider.max_value = 999.0
	_qty_slider.step = 1.0
	_qty_slider.value = 1.0
	_qty_slider.custom_minimum_size = Vector2(120, 0)
	_qty_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_qty_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qty_row.add_child(_qty_slider)
	_qty_label = Label.new()
	_qty_label.text = "×1"
	_qty_label.custom_minimum_size = Vector2(34, 0)
	_qty_label.add_theme_font_size_override("font_size", 11)
	_qty_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_qty_row.add_child(_qty_label)
	_qty_slider.value_changed.connect(_on_qty_changed)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 2)
	_menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_menu_box)


func _input(event: InputEvent) -> void:
	# 右键点建造物：打开其交互菜单（升级/卖掉/操作员），抢占开镜
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _try_open_defense_menu_at_mouse():
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _menu_target != null:
		match event.keycode:
			KEY_W, KEY_UP:
				_move_menu_selection(-1)
			KEY_S, KEY_DOWN:
				_move_menu_selection(1)
			KEY_E:
				_choose_menu_option(_menu_index)
			_:
				_close_interact_menu()
		get_viewport().set_input_as_handled()
		return
	if _storage_panel != null and _storage_panel.visible:
		# 数量弹窗打开时按键归输入框：Esc 只关弹窗，其余放行（回车确认由 LineEdit 处理）
		if _storage_qty_panel.visible:
			if event.keycode == KEY_ESCAPE:
				_storage_qty_panel.visible = false
				get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_ESCAPE, KEY_E, KEY_TAB, KEY_B:
				close_storage_panel()
				get_viewport().set_input_as_handled()
				return
	if _operator_panel != null and _operator_panel.visible:
		match event.keycode:
			KEY_ESCAPE, KEY_E:
				close_operator_panel()
				get_viewport().set_input_as_handled()
				return
	if event.keycode == KEY_E:
		_try_interact_press()
		if _menu_target != null:
			get_viewport().set_input_as_handled()


# W/S 上下移动选中项（环绕到首尾），并立即刷新高亮
func _move_menu_selection(dir: int) -> void:
	if _menu_options.is_empty():
		return
	_menu_index = wrapi(_menu_index + dir, 0, _menu_options.size())
	_refresh_interact_menu()


# 右键点建造物打开交互菜单：鼠标 40px 吸附 + 距玩家 4m 内，抢占开镜
func _try_open_defense_menu_at_mouse() -> bool:
	if _menu_blocked() or _menu_target != null:
		return false
	if _operator_panel != null and _operator_panel.visible:
		return false
	# 建造模式放置中：右键留给取消放置
	var bb := get_tree().get_first_node_in_group("base_build")
	if bb != null and String(bb.get("_placing")) != "":
		return false
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.get("vehicle") != null:
		return false
	var camera: Camera3D = player.get("camera")
	if camera == null:
		return false
	var mouse := get_viewport().get_mouse_position()
	var threshold := 40.0 * get_viewport().get_visible_rect().size.y / 360.0
	var best: Node3D = null
	var best_px := INF
	for node in get_tree().get_nodes_in_group("base_defense"):
		if node.is_queued_for_deletion():
			continue
		if player.global_position.distance_to(node.global_position) > 4.0:
			continue
		if camera.is_position_behind(node.global_position):
			continue
		var px := camera.unproject_position(node.global_position + Vector3(0, 0.8, 0)).distance_to(mouse)
		if px < threshold and px < best_px:
			best_px = px
			best = node
	if best == null:
		return false
	var options: Array = best.interact_options(player)
	if options.is_empty():
		return false
	_open_interact_menu(best, options)
	return true


# —— 操作员面板：从营地工人中为设施指派/撤出操作员，展示等级与技能 ——
var _operator_panel: Control = null
var _operator_list: VBoxContainer = null
var _operator_title: Label = null
var _operator_node: Node3D = null


func _build_operator_panel() -> void:
	_operator_panel = Control.new()
	_operator_panel.set_anchors_preset(Control.PRESET_CENTER)
	_operator_panel.offset_left = -180
	_operator_panel.offset_top = -120
	_operator_panel.offset_right = 180
	_operator_panel.offset_bottom = 120
	_operator_panel.visible = false
	_operator_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_operator_panel.z_index = 12
	add_child(_operator_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.05, 0.98)
	_operator_panel.add_child(bg)
	_operator_title = Label.new()
	_operator_title.position = Vector2(14, 8)
	_operator_title.size = Vector2(332, 32)
	_operator_title.add_theme_font_size_override("font_size", 12)
	_operator_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_operator_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_operator_panel.add_child(_operator_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 42)
	scroll.size = Vector2(340, 164)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_operator_panel.add_child(scroll)
	_operator_list = VBoxContainer.new()
	_operator_list.add_theme_constant_override("separation", 3)
	_operator_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_operator_list)
	var close_btn := Button.new()
	close_btn.text = "关闭 [Esc]"
	close_btn.position = Vector2(268, 212)
	close_btn.custom_minimum_size = Vector2(80, 22)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(close_operator_panel)
	_operator_panel.add_child(close_btn)


func open_operator_panel(node: Node3D) -> void:
	if _operator_panel == null or node == null:
		return
	_operator_node = node
	_operator_panel.visible = true
	GameState.custom_panel_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_operator_panel()


func close_operator_panel() -> void:
	if _operator_panel == null:
		return
	_operator_panel.visible = false
	_operator_node = null
	GameState.custom_panel_open = false


func _refresh_operator_panel() -> void:
	if _operator_node == null or not is_instance_valid(_operator_node):
		close_operator_panel()
		return
	for child in _operator_list.get_children():
		child.queue_free()
	var type := String(_operator_node.get("defense_type"))
	var pos: Vector3 = _operator_node.global_position
	var defense_name := String(GameState.BASE_DEFENSES.get(type, {}).get("name", type))
	var ops: Array = GameState.defense_operators(pos)
	var slots := GameState.operator_slots(type)
	_operator_title.text = "%s · 操作员（%d/%d）\n%s" % [
		defense_name, ops.size(), slots, GameState.operator_desc(type)
	]
	var workers: Array = GameState.workers()
	var followers := get_tree().get_nodes_in_group("followers")
	if workers.is_empty() and followers.is_empty():
		var empty := Label.new()
		empty.text = "（营地没有工人：先走近市民按 E 招募）"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
		_operator_list.add_child(empty)
		return
	for w in workers:
		var wname := String(w.get("name", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.custom_minimum_size = Vector2(216, 20)
		var skills: Array = GameState.worker_skills(wname)
		var job := String(w.get("job", "idle"))
		var job_text := ""
		if job == "operate":
			job_text = " · 操作中" if ops.has(wname) else " · 操作中（其它设施）"
		label.text = "%s · 等级%d · 技能 %s%s" % [
			wname,
			GameState.worker_proficiency(wname),
			"/".join(skills),
			job_text if job_text != "" else " · %s" % GameState.worker_job_name(job),
		]
		label.add_theme_font_size_override("font_size", 10)
		# 对口技能高亮（与该设施技能匹配的显示为亮色）
		var match_skill := GameState.operator_skill(type) in skills
		label.add_theme_color_override(
			"font_color", Color(0.75, 0.95, 0.75) if match_skill else Color(0.85, 0.88, 0.85)
		)
		row.add_child(label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(52, 20)
		btn.add_theme_font_size_override("font_size", 10)
		if ops.has(wname):
			btn.text = "撤出"
			btn.pressed.connect(
				func() -> void:
					GameState.unassign_operator(pos, wname)
					_refresh_operator_panel()
			)
		else:
			btn.text = "指派"
			btn.disabled = ops.size() >= slots
			btn.tooltip_text = "工作位已满" if ops.size() >= slots else "指派到该设施操作"
			btn.pressed.connect(
				func() -> void:
					GameState.assign_operator(pos, wname, type)
					_refresh_operator_panel()
			)
		row.add_child(btn)
		_operator_list.add_child(row)
	# 随从（招募的跟随者）也能指派：指派后转为营地工人并停下手头工作
	for follower in followers:
		if follower.is_queued_for_deletion():
			continue
		var fname := String(follower.get("follower_name"))
		if fname == "":
			continue
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 6)
		var flabel := Label.new()
		flabel.custom_minimum_size = Vector2(216, 20)
		var fskills: Array = GameState.skills_for_name(fname)
		flabel.text = "%s · 新兵 · 技能 %s · 随从" % [fname, "/".join(fskills)]
		flabel.add_theme_font_size_override("font_size", 10)
		flabel.add_theme_color_override(
			"font_color",
			Color(0.75, 0.95, 0.75) if GameState.operator_skill(type) in fskills else Color(0.8, 0.85, 0.95)
		)
		frow.add_child(flabel)
		var fbtn := Button.new()
		fbtn.text = "指派"
		fbtn.custom_minimum_size = Vector2(52, 20)
		fbtn.add_theme_font_size_override("font_size", 10)
		fbtn.disabled = ops.size() >= slots
		fbtn.tooltip_text = "工作位已满" if ops.size() >= slots else "转为工人并指派到该设施"
		fbtn.pressed.connect(_assign_follower_as_operator.bind(follower, pos, type))
		frow.add_child(fbtn)
		_operator_list.add_child(frow)


# 把随从转为营地工人并指派为设施操作员（停止其当前跟随任务）
func _assign_follower_as_operator(follower: Node3D, pos: Vector3, type: String) -> void:
	var fname := String(follower.get("follower_name"))
	if fname == "":
		return
	if GameState.get_worker(fname).is_empty() and not GameState.add_worker(fname):
		return  # 工人已满，add_worker 已提示
	if not GameState.assign_operator(pos, fname, type):
		return
	# 从随从队伍移除，实体由工人系统接管——原地交接，不要让人凭空消失
	var old_pos := follower.global_position
	var mgr = follower.get("manager")
	if mgr != null and mgr.get("_followers") is Array:
		mgr._followers.erase(follower)
		mgr._sync_workers()
		var body = mgr._entities.get(fname)
		if body != null:
			body.global_position = old_pos
	follower.queue_free()
	_refresh_operator_panel()


func _build_hotbar() -> void:
	var bar := HBoxContainer.new()
	_hotbar_bar = bar
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -260
	bar.offset_top = -62
	bar.offset_right = 260
	bar.offset_bottom = -6
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var slots := [{"id": "melee", "key": "V", "index": -1}]
	for i in 2:
		slots.append({"id": "", "key": str(i + 1), "index": i})
	for slot_data in slots:
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(54, 46)
		box.color = Color(0.08, 0.1, 0.12, 0.75)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(box)
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		# 技能冷却遮罩：灰色从满格向左衰减（DNF 风格）
		var cd := ColorRect.new()
		cd.color = Color(0.05, 0.05, 0.05, 0.6)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd.anchor_bottom = 1.0
		cd.visible = false
		box.add_child(cd)
		# 倒计时数字：固定在格子左上角，小号字，不遮挡武器名
		var cd_label := Label.new()
		cd_label.position = Vector2(2, 0)
		cd_label.add_theme_font_size_override("font_size", 9)
		cd_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cd_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		cd_label.add_theme_constant_override("shadow_offset_x", 1)
		cd_label.add_theme_constant_override("shadow_offset_y", 1)
		cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_label.visible = false
		box.add_child(cd_label)
		_hotbar_slots.append({
			"box": box,
			"label": label,
			"cd": cd,
			"cd_label": cd_label,
			"id": slot_data["id"],
			"key": slot_data["key"],
			"index": int(slot_data.get("index", -1)),
		})


# 取槽位当前显示的武器 id：数字槽按动态 weapon_slots 取，近战固定 melee
func _slot_weapon_id(slot: Dictionary) -> String:
	var idx := int(slot.get("index", -1))
	if idx >= 0:
		return GameState.weapon_at_slot(idx)
	return String(slot.get("id", ""))


func _hotbar_slot_text(id: String, key: String) -> String:
	if id == "":
		return ""
	if id != "melee" and id == GameState.current_weapon:
		# 霰弹枪爆破弹：弹量显示 爆破弹 ×/2
		if id == "shotgun" and GameState.shotgun_breach_left > 0:
			return "[%s]\n%s\n爆破%d/2" % [
				key, GameState.WEAPONS[id]["name"], GameState.shotgun_breach_left
			]
		var reserve := "∞" if (
			GameState.infinite_ammo or GameState.infinite_reserve or GameState.test_mode
		) else str(
			GameState.ammo_count(
				GameState.caliber_of(id), GameState.weapon_ammo_type(id)
			)
		)
		return "[%s]\n%s\n%d/%d·%s" % [
			key,
			GameState.WEAPONS[id]["name"],
			GameState.mag_rounds(id),
			GameState.mag_size(id),
			reserve,
		]
	return "[%s]\n%s" % [key, GameState.WEAPONS[id]["name"]]


func _refresh_hotbar() -> void:
	for slot in _hotbar_slots:
		var id: String = _slot_weapon_id(slot)
		var owned: bool = id != "" and (id == "melee" or GameState.weapons.get(id, 0) > 0)
		var current: bool = GameState.current_weapon == id
		var box: ColorRect = slot["box"]
		var label: Label = slot["label"]
		if not owned:
			# 未拥有/空槽：隐藏，HBox 自动折叠不留空位
			label.text = ""
			box.visible = false
			continue
		box.visible = true
		label.text = _hotbar_slot_text(id, slot["key"])
		if current:
			# 当前使用：高亮
			box.color = Color(0.25, 0.36, 0.46, 0.95)
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			# 其他武器：灰色图标
			box.color = Color(0.15, 0.15, 0.17, 0.85)
			label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))


func _refresh_hotbar_ammo() -> void:
	for slot in _hotbar_slots:
		var id: String = _slot_weapon_id(slot)
		if id == "" or id == "melee":
			continue
		var owned: bool = GameState.weapons.get(id, 0) > 0
		if not owned:
			continue
		var label: Label = slot["label"]
		var text := _hotbar_slot_text(id, slot["key"])
		if label.text != text:
			label.text = text
		# 霰弹枪爆破弹装填中：槽位整体变红提示
		var box: ColorRect = slot["box"]
		if id == "shotgun" and GameState.shotgun_breach_left > 0:
			box.color = Color(0.5, 0.1, 0.08, 0.95)
			label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		elif GameState.current_weapon == id:
			box.color = Color(0.25, 0.36, 0.46, 0.95)
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			box.color = Color(0.15, 0.15, 0.17, 0.85)
			label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))


# 有右键技能的武器槽位
const HOTBAR_SKILL_SLOTS := ["melee", "pistol", "smg", "shotgun", "rifle", "sniper", "lmg"]


# 每帧刷新技能冷却遮罩：灰色宽度 = 剩余CD / 总CD，从右往左耗尽
func _update_hotbar_cd() -> void:
	for slot in _hotbar_slots:
		var cd: ColorRect = slot["cd"]
		if cd == null:
			continue
		var id: String = _slot_weapon_id(slot)
		var owned: bool = id != "" and (id == "melee" or GameState.weapons.get(id, 0) > 0)
		var left := GameState.skill_cd_left(id)
		if GameState.no_skill_cd:
			left = 0.0
		var cd_label: Label = slot["cd_label"]
		if not owned or not HOTBAR_SKILL_SLOTS.has(id) or left <= 0.0:
			cd.visible = false
			cd_label.visible = false
			continue
		var total := float(GameState.SKILL_CD.get(id, 15.0))
		cd.visible = true
		cd_label.visible = true
		# 灰色贴右侧，剩余比例越小左边界越靠右 → 从左到右衰减
		var frac := clampf(left / total, 0.0, 1.0)
		cd.anchor_left = 1.0 - frac
		cd.anchor_right = 1.0
		var sec := str(int(ceili(left)))
		if cd_label.text != sec:
			cd_label.text = sec


func _build_end_panel() -> void:
	_end_panel = Control.new()
	_end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_panel.visible = false
	add_child(_end_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.68)
	_end_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	_end_title = Label.new()
	_end_title.add_theme_font_size_override("font_size", 28)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	# 物资清单较长时进滚动区，保证面板整体不超出 360 高
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_end_info = Label.new()
	_end_info.add_theme_font_size_override("font_size", 13)
	_end_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_info.custom_minimum_size = Vector2(420, 0)
	_end_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_end_info)
	var end_hint := Label.new()
	end_hint.text = "按 Enter 重新开始"
	end_hint.add_theme_font_size_override("font_size", 12)
	end_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	box.add_child(end_hint)


func _on_run_ended(won: bool, reason: String) -> void:
	_close_echo_panel()
	_end_panel.visible = true
	_end_title.text = "观测完成" if won else "观测结束"
	_end_title.add_theme_color_override(
		"font_color",
		Color(0.45, 1.0, 0.55) if won else Color(1.0, 0.4, 0.4)
	)
	var r: Dictionary = GameState.resources
	var owned: Array = []
	for id in GameState.WEAPONS:
		if GameState.weapons.get(id, 0) > 0:
			owned.append(GameState.WEAPONS[id]["name"])
	var weapon_text := "无" if owned.is_empty() else "、".join(owned)
	_end_info.text = "%s\n\n带走的物资：食物 %d · 药品 %d · 弹药 %d\n武器：%s · 剩余现金 ¥%d\n\n按回车返回观测舱（本局收获会结算成 SP）" % [
		reason, r["food"], r["meds"], GameState.total_ammo(), weapon_text, GameState.money,
	]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_help_panel.visible = not _help_panel.visible
		_help_badge.visible = not _help_panel.visible
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		_debug_label.visible = not _debug_label.visible
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if _perf_label != null:
			_perf_label.visible = not _perf_label.visible
		return
	# 炮击圆盘：Esc 关闭；松开 Q 时若悬停在某个选项上则选中，否则直接关闭
	if GameState.strike_dial_open and event is InputEventKey and not event.echo:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_close_strike_dial()
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and event.keycode == KEY_Q:
			if _strike_dial != null:
				_strike_dial.release_pick()
			get_viewport().set_input_as_handled()
			return
	if (
		_rogue_panel != null
		and _rogue_panel.visible
		and event is InputEventKey
		and event.pressed
		and not event.echo
	):
		var rogue_index := -1
		match event.keycode:
			KEY_1:
				rogue_index = 0
			KEY_2:
				rogue_index = 1
			KEY_3:
				rogue_index = 2
		if rogue_index >= 0:
			_on_rogue_chosen(rogue_index)
		get_viewport().set_input_as_handled()
		return
	if (
		_echo_panel != null
		and _echo_panel.visible
		and event is InputEventKey
		and event.pressed
		and not event.echo
	):
		var echo_index := -1
		match event.keycode:
			KEY_1:
				echo_index = 0
			KEY_2:
				echo_index = 1
			KEY_3:
				echo_index = 2
		if echo_index >= 0:
			_on_echo_chosen(echo_index)
		get_viewport().set_input_as_handled()
		return
	if (
		GameState.pause_menu_open
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	):
		GameState.toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if GameState.is_run_over() and event.is_action_pressed("ui_accept"):
		GameState.return_to_hub()


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_stat_bar(parent: Node, title: String, color: Color, threshold_kind := "") -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.custom_minimum_size = Vector2(28, 0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(130, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	var value := Label.new()
	value.set_anchors_preset(Control.PRESET_FULL_RECT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 10)
	value.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(value)
	# 自动使用阈值游标：拖动白条设置比例，拖到 0 关闭
	if threshold_kind != "":
		var cursor := ThresholdCursor.new()
		cursor.threshold_kind = threshold_kind
		cursor.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.add_child(cursor)
	return {"bar": bar, "value": value}


const INV_PAD_X := 16.0
const INV_GRID_Y := 36.0
const INV_LIST_W := 340.0
const INV_LIST_H := 300.0
const INV_EQUIP_X := 372.0


func _build_backpack_panel() -> void:
	_backpack_dim = ColorRect.new()
	_backpack_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backpack_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_backpack_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backpack_dim.z_index = 9
	_backpack_dim.visible = false
	add_child(_backpack_dim)

	_backpack_panel = Control.new()
	_backpack_panel.set_anchors_preset(Control.PRESET_CENTER)
	_backpack_panel.offset_left = -262
	_backpack_panel.offset_top = -222
	_backpack_panel.offset_right = 262
	_backpack_panel.offset_bottom = 222
	_backpack_panel.visible = false
	_backpack_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_backpack_panel.z_index = 10
	add_child(_backpack_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.05)
	_backpack_panel.add_child(bg)
	var title := Label.new()
	title.text = "背包 · 双击武器入槽，右键武器改装"
	title.position = Vector2(INV_PAD_X, 12)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_backpack_panel.add_child(title)

	# 手雷指示（物品列表上方标题行右侧）：小图标 + 数量，G 键直接投掷
	var nade_box := HBoxContainer.new()
	nade_box.position = Vector2(296, 15)
	nade_box.add_theme_constant_override("separation", 4)
	nade_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backpack_panel.add_child(nade_box)
	var nade_icon := ColorRect.new()
	nade_icon.custom_minimum_size = Vector2(10, 10)
	nade_icon.color = Color(0.45, 0.58, 0.4)
	nade_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nade_box.add_child(nade_icon)
	_inv_grenade_label = Label.new()
	_inv_grenade_label.add_theme_font_size_override("font_size", 11)
	_inv_grenade_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	_inv_grenade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nade_box.add_child(_inv_grenade_label)

	# 左栏：5 个分区（食物/药品/弹药/武器/特殊物品），分区竖排 + 内部 chip 横向 wrap
	# 内容可能超出面板高度，包一层滚动区保证不溢出屏幕
	_backpack_scroll = ScrollContainer.new()
	_backpack_scroll.position = Vector2(INV_PAD_X, INV_GRID_Y)
	_backpack_scroll.size = Vector2(INV_LIST_W, INV_LIST_H)
	_backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_backpack_panel.add_child(_backpack_scroll)
	_inv_list = VBoxContainer.new()
	_inv_list.add_theme_constant_override("separation", 8)
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_scroll.add_child(_inv_list)

	var equip_title := Label.new()
	equip_title.text = "人物装备"
	equip_title.position = Vector2(INV_EQUIP_X, 12)
	equip_title.add_theme_font_size_override("font_size", 13)
	equip_title.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_backpack_panel.add_child(equip_title)
	# 角色立绘：位于装备槽上方（expand_mode 必须先于 texture 设置，否则尺寸被贴图冲掉）
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load("res://assets/ui/player_portrait.png")
	portrait.position = Vector2(INV_EQUIP_X, INV_GRID_Y)
	portrait.custom_minimum_size = Vector2(146, 130)
	portrait.size = Vector2(146, 130)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backpack_panel.add_child(portrait)
	var eq_box := VBoxContainer.new()
	eq_box.position = Vector2(INV_EQUIP_X, INV_GRID_Y + 134)
	eq_box.add_theme_constant_override("separation", 3)
	_backpack_panel.add_child(eq_box)
	for slot_data in [
		{"id": "primary", "label": "武器槽 1"},
		{"id": "secondary", "label": "武器槽 2"},
		{"id": "melee", "label": "近战"},
		{"id": "armor", "label": "防具"},
	]:
		var slot := EquipSlot.new()
		slot.hud = self
		slot.slot_id = slot_data["id"]
		slot.custom_minimum_size = Vector2(146, 24)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_bg := ColorRect.new()
		slot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_bg.color = Color(0.1, 0.14, 0.12, 0.95)
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_bg)
		var slot_label := Label.new()
		slot_label.name = "Label"
		slot_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_label)
		eq_box.add_child(slot)
		_inv_slots[slot_data["id"]] = slot

	_inv_echo_title = Label.new()
	_inv_echo_title.text = "回响（本局）"
	_inv_echo_title.position = Vector2(INV_PAD_X, INV_GRID_Y + INV_LIST_H + 8)
	_inv_echo_title.add_theme_font_size_override("font_size", 12)
	_inv_echo_title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_backpack_panel.add_child(_inv_echo_title)
	_echo_list = Label.new()
	_echo_list.position = Vector2(INV_PAD_X, INV_GRID_Y + INV_LIST_H + 26)
	_echo_list.size = Vector2(INV_LIST_W, 44)
	_echo_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_echo_list.add_theme_font_size_override("font_size", 10)
	_echo_list.add_theme_color_override("font_color", Color(0.75, 0.68, 0.9))
	_backpack_panel.add_child(_echo_list)
	# 改装入口按钮：从背包进入武器改装面板
	var gunmod_btn := Button.new()
	gunmod_btn.text = "改装当前武器"
	gunmod_btn.position = Vector2(INV_EQUIP_X, INV_GRID_Y + 134 + 4 * 27 + 5)
	gunmod_btn.custom_minimum_size = Vector2(146, 22)
	gunmod_btn.add_theme_font_size_override("font_size", 11)
	gunmod_btn.pressed.connect(_open_gunmod)
	_backpack_panel.add_child(gunmod_btn)

	# 底部资源栏：小图标 + 数字（食物/医疗包/建材/燃料），不显示子弹
	_res_row = HBoxContainer.new()
	_res_row.position = Vector2(INV_PAD_X, 414)
	_res_row.add_theme_constant_override("separation", 14)
	_backpack_panel.add_child(_res_row)
	for res_data in [
		{"id": "food", "name": "食物", "color": Color(1.0, 0.65, 0.3)},
		{"id": "meds", "name": "医疗", "color": Color(0.4, 0.9, 0.5)},
		{"id": "materials", "name": "建材", "color": Color(0.8, 0.7, 0.5)},
		{"id": "fuel", "name": "燃料", "color": Color(0.95, 0.85, 0.3)},
	]:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(10, 10)
		icon.color = res_data["color"]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(icon)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(lbl)
		_res_row.add_child(entry)
		_res_labels[res_data["id"]] = lbl


# ===== 武器改装面板（配件栏 / 子弹栏 / 异能改装槽 + 武器升级）=====

func _build_gunmod_panel() -> void:
	_gunmod_dim = ColorRect.new()
	_gunmod_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gunmod_dim.color = Color(0.0, 0.0, 0.0, 0.5)
	_gunmod_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gunmod_dim.z_index = 11
	_gunmod_dim.visible = false
	add_child(_gunmod_dim)
	_gunmod_panel = Control.new()
	_gunmod_panel.set_anchors_preset(Control.PRESET_CENTER)
	_gunmod_panel.offset_left = -190
	_gunmod_panel.offset_top = -235
	_gunmod_panel.offset_right = 190
	_gunmod_panel.offset_bottom = 235
	_gunmod_panel.visible = false
	_gunmod_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_gunmod_panel.z_index = 12
	add_child(_gunmod_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.06)
	_gunmod_panel.add_child(bg)
	_gunmod_title = Label.new()
	_gunmod_title.position = Vector2(16, 10)
	_gunmod_title.add_theme_font_size_override("font_size", 14)
	_gunmod_title.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_gunmod_panel.add_child(_gunmod_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 36)
	scroll.size = Vector2(360, 424)
	_gunmod_panel.add_child(scroll)
	_gunmod_scroll = scroll
	_gunmod_body = VBoxContainer.new()
	_gunmod_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_gunmod_body)
	GameState.custom_panel_close_requested.connect(_close_gunmod)


func _open_gunmod(id := "", section := "") -> void:
	if id == "":
		id = GameState.current_weapon
	if id == "" or bool(GameState.WEAPONS.get(id, {}).get("melee", false)):
		GameState.notify("先装备一把枪械再改装")
		return
	_gunmod_weapon = id
	# 面板尺寸按屏幕自适应：不超过屏幕的 92% 宽 / 85% 高
	var vp := get_viewport().get_visible_rect().size
	var w := minf(380.0, vp.x * 0.92)
	var h := minf(470.0, vp.y * 0.85)
	_gunmod_panel.offset_left = -w / 2.0
	_gunmod_panel.offset_right = w / 2.0
	_gunmod_panel.offset_top = -h / 2.0
	_gunmod_panel.offset_bottom = h / 2.0
	_gunmod_scroll.size = Vector2(w - 20.0, h - 46.0)
	_gunmod_open = true
	GameState.custom_panel_open = true
	_gunmod_panel.visible = true
	_gunmod_dim.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_gunmod()
	# 分区跳转：升级/配件/子弹
	if section != "":
		var target := _gunmod_body.find_child("sec_" + section, true, false)
		if target != null:
			await get_tree().process_frame
			_gunmod_scroll.ensure_control_visible(target)


func _close_gunmod() -> void:
	if not _gunmod_open:
		return
	_gunmod_open = false
	_gunmod_weapon = ""
	GameState.custom_panel_open = false
	_gunmod_panel.visible = false
	_gunmod_dim.visible = false


# 武器右键菜单：升级 / 替换模组 / 子弹（就地打开改装面板并跳转分区）
func _open_weapon_menu(id: String, pos: Vector2) -> void:
	if _weapon_menu == null:
		_weapon_menu = PopupMenu.new()
		_weapon_menu.add_item("升级", 0)
		_weapon_menu.add_item("替换模组（配件）", 1)
		_weapon_menu.add_item("子弹", 2)
		_weapon_menu.id_pressed.connect(func(idx: int):
			var section: String = ["upgrade", "attach", "ammo"][idx]
			_open_gunmod(_weapon_menu_id, section)
		)
		add_child(_weapon_menu)
	_weapon_menu_id = id
	_weapon_menu.position = Vector2i(pos)
	_weapon_menu.popup()


func _gunmod_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	return l


func _gunmod_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(344, 30)
	b.add_theme_font_size_override("font_size", 11)
	return b


func _refresh_gunmod() -> void:
	for child in _gunmod_body.get_children():
		child.queue_free()
	var id := _gunmod_weapon if _gunmod_weapon != "" else GameState.current_weapon
	if id == "" or not GameState.WEAPONS.has(id):
		return
	var wname := String(GameState.WEAPONS[id].get("name", id))
	var lv := GameState.weapon_level(id)
	_gunmod_title.text = "武器改装：%s  Lv.%d/%d" % [wname, lv, GameState.WEAPON_LEVEL_MAX]
	# 武器升级
	var upcost: Dictionary = GameState.weapon_upgrade_cost(id)
	var up_text := "已满级 MAX"
	if lv < GameState.WEAPON_LEVEL_MAX:
		up_text = "升级（制造材料×%d → Lv.%d）" % [int(upcost["craft"]), lv + 1]
	var up_btn := _gunmod_btn(up_text)
	up_btn.name = "sec_upgrade"
	up_btn.disabled = lv >= GameState.WEAPON_LEVEL_MAX
	up_btn.pressed.connect(func():
		GameState.weapon_upgrade(id)
		_refresh_gunmod()
	)
	_gunmod_body.add_child(up_btn)
	# 配件栏
	var _sec_attach := _gunmod_label("配件栏")
	_sec_attach.name = "sec_attach"
	_gunmod_body.add_child(_sec_attach)
	for kind in ["scope", "muzzle", "mag"]:
		var installed: bool = GameState.attachment_installed(id, kind)
		var cname := String(GameState.ATTACH_COSTS[kind]["name"])
		var text := "%s（已装备，点击卸下）" % cname
		if not installed:
			text = "＋ %s（制造材料×%d）" % [
				cname, int(GameState.ATTACH_COSTS[kind]["craft"])
			]
		var b := _gunmod_btn(text)
		b.pressed.connect(func():
			if GameState.attachment_installed(id, kind):
				GameState.uninstall_attachment(id, kind)
			else:
				GameState.install_attachment(id, kind)
			_refresh_gunmod()
		)
		_gunmod_body.add_child(b)
	# 子弹栏
	var _sec_ammo := _gunmod_label(
		"子弹栏（当前弹种：%s）" % GameState.ammo_type_name(GameState.weapon_ammo_type(id))
	)
	_sec_ammo.name = "sec_ammo"
	_gunmod_body.add_child(_sec_ammo)
	for t in GameState.AMMO_TYPE_ORDER:
		var cur: bool = GameState.weapon_ammo_type(id) == t
		var b := _gunmod_btn(
			("● " if cur else "○ ") + GameState.ammo_type_name(t)
			+ " ×%d" % GameState.ammo_count(GameState.caliber_of(id), t)
		)
		b.pressed.connect(func():
			GameState.set_weapon_ammo(id, t)
			_refresh_gunmod()
		)
		_gunmod_body.add_child(b)
	# 异能改装槽
	_gunmod_body.add_child(_gunmod_label("异能改装槽"))
	var has_echo: bool = GameState.has_echo_mod(id)
	var echo_text := "＋ 嵌入异能结晶 ×1（伤害 +%d%%）" % int(GameState.ECHO_MOD_DMG * 100.0)
	if has_echo:
		echo_text = "异能结晶已嵌入（伤害 +%d%%，点击取出）" % int(GameState.ECHO_MOD_DMG * 100.0)
	var echo_btn := _gunmod_btn(echo_text)
	echo_btn.pressed.connect(func():
		if GameState.has_echo_mod(id):
			GameState.uninstall_echo_mod(id)
		else:
			GameState.install_echo_mod(id)
		_refresh_gunmod()
	)
	_gunmod_body.add_child(echo_btn)
	# 关闭
	var close_btn := _gunmod_btn("关闭（Esc）")
	close_btn.pressed.connect(_close_gunmod)
	_gunmod_body.add_child(close_btn)


func _refresh_backpack() -> void:
	if _inv_list == null:
		return
	for child in _inv_list.get_children():
		child.queue_free()
	# 魔兽式单一网格：全部分区物品按顺序排进一个方形格阵列
	var cells: Array = []
	for group in GameState.BACKPACK_GROUPS:
		cells.append_array(GameState.backpack_group_items(String(group["id"])))
	_inv_list.add_child(_build_inv_grid(cells))

	var slot1 := GameState.weapon_at_slot(0)
	var slot2 := GameState.weapon_at_slot(1)
	var cur := GameState.current_weapon
	_set_slot_text(
		"primary",
		"（空槽）" if slot1 == "" else (
			("▶ " if cur == slot1 else "") + String(GameState.WEAPONS[slot1]["name"])
		)
	)
	_set_slot_text(
		"secondary",
		"（空槽）" if slot2 == "" else (
			("▶ " if cur == slot2 else "") + String(GameState.WEAPONS[slot2]["name"])
		)
	)
	var melee_text := "拳脚"
	if GameState.melee_item_damage > 0:
		melee_text = "%s（%d）" % [
			GameState.loot_name(GameState.melee_item), GameState.melee_item_damage
		]
	_set_slot_text("melee", melee_text)
	_set_slot_text(
		"armor",
		GameState.loot_name(GameState.armor_id) if not GameState.armor_id.is_empty() else "无"
	)
	# 手雷小图标 + 数量（物品列表上方）
	if _inv_grenade_label != null:
		_inv_grenade_label.text = "手雷 ×%d" % GameState.grenade_count()
	# 资源栏（背包底部小图标 + 数字）：食物/医疗包/建材/燃料，不显示子弹
	_set_res_label("food", "×%d" % int(GameState.resources.get("food", 0)))
	_set_res_label("meds", "×%d" % int(GameState.resources.get("meds", 0)))
	if GameState.has_home_base():
		_set_res_label("materials", "随身 %d · 据点 %d/%d" % [
			int(GameState.resources.get("materials", 0)),
			GameState.base_materials(), GameState.base_storage_cap(),
		])
	else:
		_set_res_label("materials", "×%d" % int(GameState.resources.get("materials", 0)))
	_set_res_label("fuel", "%d/%d" % [
		int(GameState.resources.get("fuel", 0)), int(GameState.CAPS.get("fuel", 60)),
	])
	_refresh_echo_list()


# 单个背包分区：标题 + 分隔线 + 物品 chip 横向 wrap 排布
func _build_inv_section(title: String, items: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 3)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Label.new()
	head.text = "%s（%d）" % [title, items.size()]
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Color(0.82, 0.9, 0.84))
	section.add_child(head)
	section.add_child(HSeparator.new())
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(flow)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.5, 0.56, 0.5))
		flow.add_child(empty)
	else:
		for item in items:
			flow.add_child(_make_inv_chip(item))
	return section


# 物品 chip：固定 1 格大小，不随物品种类变化
# 物品数量（从 id 反查资源）
func _inv_qty(item: Dictionary) -> int:
	var id := String(item.get("id", ""))
	if id == "cash":
		return GameState.money
	if id == "food":
		return int(GameState.resources.get("food", 0))
	if id == "meds":
		return int(GameState.resources.get("meds", 0))
	if id.begins_with("ammo_"):
		return GameState.ammo_count(id.trim_prefix("ammo_"))
	if item.has("loot_id"):
		return GameState.loot_count(String(item["loot_id"]))
	return 1


# 物品图标形状与颜色（物品类别 → ResIcon kind）
func _inv_icon(item: Dictionary) -> Array:
	if bool(item.get("weapon", false)):
		return ["gun", item["color"]]
	var id := String(item.get("id", ""))
	if id == "cash":
		return ["coin", Color(0.95, 0.85, 0.3)]
	if id == "food":
		return ["circle", Color(0.4, 0.9, 0.5)]
	if id == "meds":
		return ["cross", Color(0.95, 0.4, 0.4)]
	if id.begins_with("ammo_"):
		return ["bullet", Color(0.9, 0.85, 0.4)]
	if item.has("loot_id"):
		var cat := String(
			GameState.LOOT_ITEMS.get(String(item["loot_id"]), {}).get("cat", "")
		)
		match cat:
			"food", "drink":
				return ["circle", Color(0.4, 0.9, 0.5)]
			"meds", "medical":
				return ["cross", Color(0.95, 0.4, 0.4)]
			"ammo":
				return ["bullet", Color(0.9, 0.85, 0.4)]
			"valuable":
				return ["coin", Color(0.95, 0.85, 0.3)]
			"armor":
				return ["hex", Color(0.7, 0.78, 0.88)]
			"attach":
				return ["gear", Color(0.6, 0.75, 0.9)]
			"crystal":
				return ["diamond", Color(0.8, 0.5, 0.95)]
			"fuel":
				return ["drop", Color(0.95, 0.6, 0.3)]
			"tool":
				return ["square", Color(0.8, 0.7, 0.5)]
	return ["square", item["color"]]


# 魔兽式方形物品格：深色格底 + 边框 + 类别图标 + 右下角数量
func _make_inv_chip(item: Dictionary) -> ItemChip:
	var chip := ItemChip.new()
	chip.hud = self
	chip.item = item
	chip.custom_minimum_size = Vector2(36, 36)
	chip.tooltip_text = (
		"%s\n双击入武器槽 · 右键改装" % String(item["label"])
		if bool(item.get("weapon", false))
		else "%s\n点击使用" % String(item["label"])
	)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var chip_bg := ColorRect.new()
	chip_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip_bg.color = Color(0.07, 0.09, 0.08, 0.95)
	chip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(chip_bg)
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.28, 0.34, 0.28)
	border.border_width = 1.0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(border)
	var icon_def: Array = _inv_icon(item)
	var glyph := ResIcon.new()
	glyph.kind = String(icon_def[0])
	glyph.tint = icon_def[1]
	glyph.set_anchors_preset(Control.PRESET_CENTER)
	glyph.custom_minimum_size = Vector2(22, 22)
	glyph.size = Vector2(22, 22)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(glyph)
	var qty := _inv_qty(item)
	if qty > 1:
		var qty_label := Label.new()
		qty_label.text = str(qty)
		qty_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		qty_label.offset_left = -26
		qty_label.offset_top = -15
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.add_theme_font_size_override("font_size", 9)
		qty_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		qty_label.add_theme_constant_override("outline_size", 2)
		qty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(qty_label)
	return chip


# 空槽（补齐整行的暗格，凑出魔兽式网格感）
func _make_empty_cell() -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(36, 36)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.075, 0.065, 0.9)
	cell.add_child(bg)
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.24, 0.3, 0.24)
	border.border_width = 1.0
	cell.add_child(border)
	return cell


# 整包一个连续网格：物品按分区顺序排，末尾空槽补齐整行
func _build_inv_grid(items: Array) -> Control:
	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override("h_separation", 3)
	wrap.add_theme_constant_override("v_separation", 3)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		wrap.add_child(_make_inv_chip(item))
	var cols := 8
	var pad := 0
	if items.size() % cols != 0:
		pad = cols - items.size() % cols
	for i in pad:
		wrap.add_child(_make_empty_cell())
	return wrap


func _refresh_echo_list() -> void:
	if _echo_list == null:
		return
	var names: Array = []
	var tips: Array = []
	for id in GameState.run_echoes:
		var info := GameState.echo_info(String(id))
		names.append(String(info.get("name", id)))
		tips.append("%s（%s）：%s" % [
			String(info.get("name", id)),
			String(info.get("school", "")),
			String(info.get("desc", "")),
		])
	_echo_list.text = "（尚未铭刻回响）" if names.is_empty() else "、".join(names)
	_echo_list.tooltip_text = "\n".join(tips)


func _set_slot_text(slot_id: String, text: String) -> void:
	var slot = _inv_slots.get(slot_id)
	if slot == null:
		return
	slot.get_node("Label").text = text


func _set_res_label(res_id: String, text: String) -> void:
	var lbl = _res_labels.get(res_id)
	if lbl == null:
		return
	lbl.text = text


func _make_drag_preview(item: Dictionary) -> Control:
	var preview := ColorRect.new()
	preview.color = item["color"]
	preview.custom_minimum_size = Vector2(96, 26)
	var label := Label.new()
	label.text = String(item["label"])
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.06, 0.06, 0.06))
	preview.add_child(label)
	return preview


func _can_equip(slot_id: String, item_id: String) -> bool:
	if slot_id != "primary" and slot_id != "secondary":
		return false
	return (
		GameState.WEAPONS.has(item_id)
		and item_id != "melee"
		and item_id != "grenade"
		and int(GameState.weapons.get(item_id, 0)) > 0
	)


func _equip_item(slot_id: String, item_id: String) -> void:
	if _can_equip(slot_id, item_id):
		GameState.equip_weapon(item_id)
		GameState.select_weapon(item_id)
	_refresh_backpack()


func _click_slot(slot_id: String) -> void:
	match slot_id:
		"armor":
			_equip_first_of("armor")
		"melee":
			_equip_first_of("melee")
	_refresh_backpack()


func _equip_first_of(cat: String) -> void:
	for entry in GameState.loot_items:
		var info := GameState.loot_info(String(entry["id"]))
		if String(info.get("cat", "")) == cat:
			GameState.use_loot(String(entry["id"]))
			return
	GameState.notify("背包里没有可装备的物品")


func _use_chip(loot_id: String) -> void:
	GameState.use_loot(loot_id)
	_refresh_backpack()


func _build_skills_panel() -> void:
	_skills_dim = ColorRect.new()
	_skills_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skills_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_skills_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skills_dim.z_index = 9
	_skills_dim.visible = false
	add_child(_skills_dim)

	_skills_panel = Control.new()
	_skills_panel.set_anchors_preset(Control.PRESET_CENTER)
	_skills_panel.offset_left = -240
	_skills_panel.offset_top = -140
	_skills_panel.offset_right = 240
	_skills_panel.offset_bottom = 140
	_skills_panel.visible = false
	_skills_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_skills_panel.z_index = 10
	add_child(_skills_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08)
	_skills_panel.add_child(bg)
	_skills_title = Label.new()
	_skills_title.position = Vector2(16, 12)
	_skills_title.add_theme_font_size_override("font_size", 14)
	_skills_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_skills_panel.add_child(_skills_title)
	var hint := Label.new()
	hint.text = "击杀丧尸或每存活 60 秒获得 SP · 某项满级触发变异"
	hint.position = Vector2(16, 240)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	_skills_panel.add_child(hint)

	var rows := VBoxContainer.new()
	rows.position = Vector2(16, 40)
	rows.add_theme_constant_override("separation", 3)
	_skills_panel.add_child(rows)
	for skill in GameState.SKILLS:
		var id := String(skill["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		rows.add_child(row)
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(96, 24)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		row.add_child(name_label)
		var level_label := Label.new()
		level_label.custom_minimum_size = Vector2(60, 24)
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		row.add_child(level_label)
		var desc_label := Label.new()
		desc_label.custom_minimum_size = Vector2(180, 24)
		desc_label.text = String(skill["desc"]) + "/级"
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		row.add_child(desc_label)
		var button := Button.new()
		button.text = "+"
		button.custom_minimum_size = Vector2(46, 24)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_skill_upgrade.bind(id))
		row.add_child(button)
		_skills_rows[id] = {
			"name": name_label,
			"level": level_label,
			"button": button,
		}
	# 冲刺技能行：等级 / 效果 / 升级（独立于属性技能的专技）
	var dash_row := HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 8)
	rows.add_child(dash_row)
	var dash_name := Label.new()
	dash_name.custom_minimum_size = Vector2(96, 24)
	dash_name.add_theme_font_size_override("font_size", 12)
	dash_name.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
	dash_row.add_child(dash_name)
	var dash_level_label := Label.new()
	dash_level_label.custom_minimum_size = Vector2(60, 24)
	dash_level_label.add_theme_font_size_override("font_size", 12)
	dash_level_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	dash_row.add_child(dash_level_label)
	_dash_desc_label = Label.new()
	_dash_desc_label.custom_minimum_size = Vector2(180, 24)
	_dash_desc_label.add_theme_font_size_override("font_size", 11)
	_dash_desc_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	dash_row.add_child(_dash_desc_label)
	var dash_button := Button.new()
	dash_button.custom_minimum_size = Vector2(46, 24)
	dash_button.add_theme_font_size_override("font_size", 14)
	dash_button.pressed.connect(GameState.upgrade_dash)
	dash_row.add_child(dash_button)
	dash_name.text = "冲刺"
	_skills_rows["__dash__"] = {
		"level": dash_level_label, "button": dash_button,
	}


func _on_skill_upgrade(id: String) -> void:
	GameState.upgrade_skill(id)


func _refresh_skills() -> void:
	if _skills_panel == null:
		return
	_skills_title.text = "个人能力（C 关闭） · SP：%d" % GameState.skill_points
	for skill in GameState.SKILLS:
		var id := String(skill["id"])
		var row: Dictionary = _skills_rows.get(id, {})
		if row.is_empty():
			continue
		var level := GameState.skill_level(id)
		var max_level := GameState.skill_max(id)
		row["name"].text = String(skill["name"])
		if GameState.mutation_rank(id) > 0:
			row["level"].text = "已变异 %s" % GameState._roman(GameState.mutation_rank(id))
		else:
			row["level"].text = "Lv%d/%d" % [level, max_level]
		row["button"].disabled = not GameState.can_upgrade_skill(id)
	# 冲刺技能行刷新
	var dash_row: Dictionary = _skills_rows.get("__dash__", {})
	if not dash_row.is_empty():
		dash_row["level"].text = "Lv%d/%d" % [GameState.dash_level, GameState.DASH_MAX_LEVEL]
		var cost := GameState.dash_upgrade_cost()
		if cost <= 0:
			_dash_desc_label.text = String(GameState.dash_info()["desc"]) + "（已满级）"
			dash_row["button"].text = "满"
			dash_row["button"].disabled = true
		else:
			var next_info: Dictionary = GameState.DASH_LEVELS[GameState.dash_level + 1]
			_dash_desc_label.text = "下级：%s" % String(next_info["desc"])
			dash_row["button"].text = "%d点" % cost
			dash_row["button"].disabled = GameState.skill_points < cost


func _build_mutation_panel() -> void:
	_mutation_dim = ColorRect.new()
	_mutation_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mutation_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_mutation_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mutation_dim.z_index = 11
	_mutation_dim.visible = false
	add_child(_mutation_dim)

	_mutation_panel = Control.new()
	_mutation_panel.set_anchors_preset(Control.PRESET_CENTER)
	_mutation_panel.offset_left = -230
	_mutation_panel.offset_top = -120
	_mutation_panel.offset_right = 230
	_mutation_panel.offset_bottom = 120
	_mutation_panel.visible = false
	_mutation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_mutation_panel.z_index = 12
	add_child(_mutation_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.04, 0.1)
	_mutation_panel.add_child(bg)
	_mutation_title = Label.new()
	_mutation_title.position = Vector2(16, 12)
	_mutation_title.add_theme_font_size_override("font_size", 14)
	_mutation_title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	_mutation_panel.add_child(_mutation_title)
	var hint := Label.new()
	hint.text = "该属性已满级，觉醒变异——选择一项能力（本局永久生效）"
	hint.position = Vector2(16, 202)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	_mutation_panel.add_child(hint)
	_mutation_box = VBoxContainer.new()
	_mutation_box.position = Vector2(16, 40)
	_mutation_box.add_theme_constant_override("separation", 8)
	_mutation_panel.add_child(_mutation_box)


func _on_mutation_offered() -> void:
	for child in _mutation_box.get_children():
		child.queue_free()
	_mutation_title.text = "变异觉醒 · %s系" % GameState.skill_name(GameState.pending_mutation)
	for entry in GameState.mutation_offer:
		var button := Button.new()
		button.text = GameState.mut_label(String(entry["id"]))
		button.custom_minimum_size = Vector2(0, 46)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_mutation_chosen.bind(String(entry["id"])))
		_mutation_box.add_child(button)
	_mutation_panel.visible = true
	_mutation_dim.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_mutation_chosen(id: String) -> void:
	GameState.choose_mutation(id)
	_mutation_panel.visible = false
	_mutation_dim.visible = false
	if (
		not GameState.skills_open
		and not GameState.backpack_open
		and not GameState.map_open
		and not GameState.pause_menu_open
	):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_echo_panel() -> void:
	# 非阻塞回响横条：顶部居中（避开左上状态条与右上小地图），
	# 不暂停游戏、不遮罩全屏，倒计时结束自动铭刻第 1 个
	_echo_panel = Control.new()
	_echo_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_echo_panel.offset_left = -140
	_echo_panel.offset_top = 40
	_echo_panel.offset_right = 140
	_echo_panel.offset_bottom = 70
	_echo_panel.visible = false
	_echo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo_panel.z_index = 14
	add_child(_echo_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.03, 0.1, 0.82)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo_panel.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 3
	box.offset_right = -8
	box.offset_bottom = -3
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo_panel.add_child(box)
	_echo_title = Label.new()
	_echo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_echo_title.add_theme_font_size_override("font_size", 11)
	_echo_title.add_theme_color_override("font_color", Color(0.9, 0.78, 1.0))
	_echo_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_echo_title)
	_echo_options = Label.new()
	_echo_options.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_echo_options.add_theme_font_size_override("font_size", 10)
	_echo_options.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	_echo_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_echo_options)


func _on_echo_offered(choices: Array) -> void:
	_echo_choices = choices
	_echo_timer = ECHO_AUTO_PICK_SECONDS
	var parts: Array = []
	for i in choices.size():
		var short := String(choices[i].get("name", "")).trim_prefix("回响·")
		parts.append("[%d] %s" % [i + 1, short])
	_echo_options.text = "%s · 按 1/2/3 改选" % " ".join(parts)
	_refresh_echo_title()
	_echo_panel.visible = true


func _refresh_echo_title() -> void:
	var first := ""
	if not _echo_choices.is_empty():
		first = String(_echo_choices[0].get("name", "")).trim_prefix("回响·")
	_echo_title.text = "回响浮现：%d 秒后自动铭刻 [1] %s" % [int(ceil(_echo_timer)), first]


func _on_echo_chosen(index: int) -> void:
	if index < 0 or index >= _echo_choices.size():
		return
	var id := String(_echo_choices[index].get("id", ""))
	if not GameState.pick_echo(id):
		# Offer 已被外部消费（如联机同步），直接收起避免倒计时卡在失败状态
		_close_echo_panel()
		return
	_close_echo_panel()
	if GameState.backpack_open:
		_refresh_backpack()


func _close_echo_panel() -> void:
	_echo_panel.visible = false
	_echo_choices = []
	_echo_timer = 0.0


# 肉鸽模式 UI：顶部状态行 + 升级三选一横条（不暂停，10 秒自动选第一项）
func _build_rogue_ui() -> void:
	_rogue_label = Label.new()
	_rogue_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_rogue_label.offset_left = -260
	_rogue_label.offset_right = 260
	_rogue_label.offset_top = 58
	_rogue_label.offset_bottom = 74
	_rogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rogue_label.add_theme_font_size_override("font_size", 13)
	_rogue_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_rogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rogue_label.visible = false
	add_child(_rogue_label)

	_rogue_panel = Control.new()
	_rogue_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_rogue_panel.offset_left = -260
	_rogue_panel.offset_top = 50
	_rogue_panel.offset_right = 260
	_rogue_panel.offset_bottom = 82
	_rogue_panel.visible = false
	_rogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rogue_panel.z_index = 14
	add_child(_rogue_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.08, 0.1, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rogue_panel.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 3
	box.offset_right = -8
	box.offset_bottom = -3
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rogue_panel.add_child(box)
	_rogue_title = Label.new()
	_rogue_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rogue_title.add_theme_font_size_override("font_size", 12)
	_rogue_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.85))
	_rogue_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_rogue_title)
	_rogue_options = Label.new()
	_rogue_options.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rogue_options.add_theme_font_size_override("font_size", 11)
	_rogue_options.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95))
	_rogue_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_rogue_options)


func _on_rogue_offered(choices: Array) -> void:
	_rogue_choices = choices
	_rogue_timer = ROGUE_AUTO_PICK_SECONDS
	var parts: Array = []
	for i in choices.size():
		parts.append(
			"[%d] %s（%s）" % [i + 1, String(choices[i]["name"]), String(choices[i]["desc"])]
		)
	_rogue_options.text = "  ".join(parts)
	_refresh_rogue_title()
	_rogue_panel.visible = true


func _refresh_rogue_title() -> void:
	_rogue_title.text = "升级！Lv.%d · %d 秒后自动选 [1] · 按 1/2/3 选择" % [
		GameState.rogue_level, int(ceil(_rogue_timer))
	]


func _on_rogue_chosen(index: int) -> void:
	if index < 0 or index >= _rogue_choices.size():
		return
	GameState.rogue_pick(String(_rogue_choices[index].get("id", "")))
	_rogue_choices = []
	_rogue_timer = 0.0
	_rogue_panel.visible = false


class SightView extends Control:
	func _draw() -> void:
		var center := get_viewport_rect().size * 0.5
		draw_arc(center, 13.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 1.0, true)
		draw_arc(center, 11.0, 0.0, TAU, 48, Color(0.05, 0.05, 0.05, 0.9), 1.5, true)
		draw_circle(center, 1.8, Color(0.05, 0.05, 0.05, 0.95))


# 2.5D 开镜暗角：全屏黑色，只有以鼠标位置为中心的圆孔可见，倍镜越高孔越小
class ScopeView extends Control:
	var hole_radius := 150.0
	var mode := "hard"

	func _draw() -> void:
		# 开镜时相机已把瞄准点移到画面中心，镜孔固定取画布中心
		var center := size * 0.5
		if mode == "soft":
			# 低倍瞄准：中心清楚，四周渐变模糊变暗（无黑边）
			var outer := 0.0
			for corner in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
				outer = maxf(outer, center.distance_to(corner))
			for i in 4:
				var alpha := 0.12 + i * 0.13
				draw_arc(
					center, hole_radius + i * outer / 5.0, 0.0, TAU, 96,
					Color(0.02, 0.02, 0.03, alpha), outer / 5.0 + 2.0, true
				)
			return
		# 高倍狙击镜：圆孔外全部纯黑（环形遮罩外扩 12px 兜底，任何鼠标位置不漏光）
		var outer := 0.0
		for corner in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
			outer = maxf(outer, center.distance_to(corner))
		draw_arc(
			center, hole_radius + (outer - hole_radius + 12.0) * 0.5, 0.0, TAU, 128,
			Color(0.01, 0.01, 0.01, 1.0), outer - hole_radius + 12.0, true
		)
		var reticle := Color(0.02, 0.02, 0.02, 0.9)
		draw_line(
			Vector2(center.x, center.y - hole_radius), Vector2(center.x, center.y + hole_radius),
			reticle, 1.0, true
		)
		draw_line(
			Vector2(center.x - hole_radius, center.y), Vector2(center.x + hole_radius, center.y),
			reticle, 1.0, true
		)
		draw_circle(center, 2.5, Color(0.9, 0.15, 0.1, 0.95))
		draw_arc(center, hole_radius, 0.0, TAU, 96, Color(0.05, 0.05, 0.05, 0.9), 2.0, true)


class EyeIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var center := Vector2(w * 0.5, h * 0.5)
		var points := PackedVector2Array()
		var segs := 16
		for i in segs + 1:
			var t := float(i) / float(segs)
			var x := lerpf(-1.0, 1.0, t)
			var y := -0.55 * sqrt(maxf(0.0, 1.0 - x * x))
			points.append(center + Vector2(x * w * 0.46, y * h))
		for i in segs + 1:
			var t := float(segs - i) / float(segs)
			var x := lerpf(-1.0, 1.0, t)
			var y := 0.55 * sqrt(maxf(0.0, 1.0 - x * x))
			points.append(center + Vector2(x * w * 0.46, y * h))
		draw_colored_polygon(points, Color(1.0, 0.95, 0.9, 0.92))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color(0.05, 0.05, 0.05, 0.85), 1.6)
		draw_circle(center, h * 0.34, Color(0.95, 0.25, 0.2))
		draw_circle(center, h * 0.14, Color(0.05, 0.05, 0.05))


# —— 据点仓库面板：与背包同款分区 UI（标题+分隔线+chip 流），双击全存/全取，右键输入数量，一键存放 ——
var _storage_panel: Control
var _storage_base_grid: VBoxContainer
var _storage_pack_grid: VBoxContainer
var _storage_qty_panel: Control
var _storage_qty_title: Label
var _storage_qty_edit: LineEdit
var _storage_qty_kind := ""
var _storage_qty_to_base := false
var _storage_qty_max := 0

# kind → [图标形状, 颜色]（形状由 ResIcon 绘制）
const STORAGE_CELL_DEFS := {
	"food": ["circle", Color(0.4, 0.9, 0.5)],
	"meds": ["cross", Color(0.95, 0.4, 0.4)],
	"ammo": ["bullet", Color(0.9, 0.85, 0.4)],
	"materials": ["square", Color(0.8, 0.7, 0.5)],
	"fuel": ["drop", Color(0.95, 0.6, 0.3)],
	"money": ["coin", Color(0.95, 0.85, 0.3)],
	"crystals": ["diamond", Color(0.8, 0.5, 0.95)],
}
# 仓库分区（与背包分类同款）：标题 + 包含的种类
const STORAGE_SECTIONS := [
	{"title": "食物", "kinds": ["food"]},
	{"title": "药品", "kinds": ["meds"]},
	{"title": "弹药", "kinds": ["ammo"]},
	{"title": "资源", "kinds": ["materials", "fuel", "money", "crystals"]},
]


func _build_storage_panel() -> void:
	_storage_panel = Control.new()
	_storage_panel.set_anchors_preset(Control.PRESET_CENTER)
	_storage_panel.offset_left = -230
	_storage_panel.offset_top = -132
	_storage_panel.offset_right = 230
	_storage_panel.offset_bottom = 132
	_storage_panel.visible = false
	_storage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_storage_panel.z_index = 11
	add_child(_storage_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.05, 0.98)
	_storage_panel.add_child(bg)
	var title := Label.new()
	title.text = "据点仓库 · 双击全存/全取 · 右键输入数量"
	title.position = Vector2(16, 10)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_storage_panel.add_child(title)
	var base_label := Label.new()
	base_label.text = "仓库"
	base_label.position = Vector2(16, 34)
	base_label.add_theme_font_size_override("font_size", 11)
	base_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_storage_panel.add_child(base_label)
	var pack_label := Label.new()
	pack_label.text = "背包"
	pack_label.position = Vector2(240, 34)
	pack_label.add_theme_font_size_override("font_size", 11)
	pack_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_storage_panel.add_child(pack_label)
	var base_scroll := ScrollContainer.new()
	base_scroll.position = Vector2(16, 52)
	base_scroll.size = Vector2(210, 168)
	base_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_storage_panel.add_child(base_scroll)
	_storage_base_grid = VBoxContainer.new()
	_storage_base_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_storage_base_grid.add_theme_constant_override("separation", 6)
	base_scroll.add_child(_storage_base_grid)
	var pack_scroll := ScrollContainer.new()
	pack_scroll.position = Vector2(240, 52)
	pack_scroll.size = Vector2(204, 168)
	pack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_storage_panel.add_child(pack_scroll)
	_storage_pack_grid = VBoxContainer.new()
	_storage_pack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_storage_pack_grid.add_theme_constant_override("separation", 6)
	pack_scroll.add_child(_storage_pack_grid)
	var store_btn := Button.new()
	store_btn.text = "一键存放全部"
	store_btn.position = Vector2(16, 230)
	store_btn.custom_minimum_size = Vector2(120, 24)
	store_btn.add_theme_font_size_override("font_size", 11)
	store_btn.pressed.connect(_on_storage_store_all)
	_storage_panel.add_child(store_btn)
	var close_btn := Button.new()
	close_btn.text = "关闭 [Esc]"
	close_btn.position = Vector2(368, 230)
	close_btn.custom_minimum_size = Vector2(76, 24)
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func() -> void: close_storage_panel())
	_storage_panel.add_child(close_btn)
	_build_storage_qty_popup()


# 数量输入弹窗：右键格子弹出，输入数量后回车/确认
func _build_storage_qty_popup() -> void:
	_storage_qty_panel = Control.new()
	_storage_qty_panel.set_anchors_preset(Control.PRESET_CENTER)
	_storage_qty_panel.offset_left = -100
	_storage_qty_panel.offset_top = -60
	_storage_qty_panel.offset_right = 100
	_storage_qty_panel.offset_bottom = 60
	_storage_qty_panel.visible = false
	_storage_qty_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_storage_qty_panel.z_index = 5
	_storage_panel.add_child(_storage_qty_panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.09, 0.08)
	_storage_qty_panel.add_child(bg)
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.4, 0.55, 0.45)
	border.border_width = 1.0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storage_qty_panel.add_child(border)
	_storage_qty_title = Label.new()
	_storage_qty_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_storage_qty_title.offset_top = 8
	_storage_qty_title.offset_bottom = 26
	_storage_qty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storage_qty_title.add_theme_font_size_override("font_size", 12)
	_storage_qty_title.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_storage_qty_panel.add_child(_storage_qty_title)
	_storage_qty_edit = LineEdit.new()
	_storage_qty_edit.position = Vector2(20, 34)
	_storage_qty_edit.size = Vector2(160, 24)
	_storage_qty_edit.placeholder_text = "输入数量"
	_storage_qty_edit.add_theme_font_size_override("font_size", 12)
	_storage_qty_edit.text_submitted.connect(func(_t: String) -> void: _confirm_storage_qty())
	_storage_qty_panel.add_child(_storage_qty_edit)
	var max_btn := Button.new()
	max_btn.text = "最大"
	max_btn.position = Vector2(20, 70)
	max_btn.custom_minimum_size = Vector2(48, 22)
	max_btn.add_theme_font_size_override("font_size", 11)
	max_btn.pressed.connect(func() -> void: _storage_qty_edit.text = str(_storage_qty_max))
	_storage_qty_panel.add_child(max_btn)
	var ok_btn := Button.new()
	ok_btn.text = "确认"
	ok_btn.position = Vector2(76, 70)
	ok_btn.custom_minimum_size = Vector2(48, 22)
	ok_btn.add_theme_font_size_override("font_size", 11)
	ok_btn.pressed.connect(_confirm_storage_qty)
	_storage_qty_panel.add_child(ok_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(132, 70)
	cancel_btn.custom_minimum_size = Vector2(48, 22)
	cancel_btn.add_theme_font_size_override("font_size", 11)
	cancel_btn.pressed.connect(func() -> void: _storage_qty_panel.visible = false)
	_storage_qty_panel.add_child(cancel_btn)


func _open_storage_qty(kind: String, to_base: bool) -> void:
	var max_amount := _storage_owned(kind) if to_base else int(
		GameState.home_base.get("storage", {}).get(kind, 0)
	)
	if max_amount <= 0:
		return
	_storage_qty_kind = kind
	_storage_qty_to_base = to_base
	_storage_qty_max = max_amount
	_storage_qty_title.text = "%s %s（最多 %d）" % [
		"存入" if to_base else "取出", _storage_kind_name(kind), max_amount
	]
	_storage_qty_edit.text = str(max_amount)
	_storage_qty_panel.visible = true
	_storage_qty_edit.grab_focus()
	_storage_qty_edit.select_all()


func _confirm_storage_qty() -> void:
	var amount := int(_storage_qty_edit.text)
	amount = clampi(amount, 0, _storage_qty_max)
	_storage_qty_panel.visible = false
	if amount <= 0:
		return
	if _storage_qty_to_base:
		_storage_deposit(_storage_qty_kind, amount)
	else:
		_storage_withdraw(_storage_qty_kind, amount)


func open_storage_panel() -> void:
	if _storage_panel == null or not GameState.has_home_base():
		return
	_storage_panel.visible = true
	GameState.custom_panel_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_storage_panel()


func close_storage_panel() -> void:
	if _storage_panel == null:
		return
	_storage_qty_panel.visible = false
	_storage_panel.visible = false
	GameState.custom_panel_open = false


func _storage_kind_name(kind: String) -> String:
	return "异能结晶" if kind == "crystals" else GameState._supply_name(kind)


func _storage_owned(kind: String) -> int:
	match kind:
		"money":
			return GameState.money
		"ammo":
			return GameState.total_ammo()
		"crystals":
			return GameState.loot_count("anomaly_crystal")
		_:
			return int(GameState.resources.get(kind, 0))


# 仓库物品 chip：与背包 chip 同款（固定格、彩色底、深色字），保留存取交互
func _make_storage_cell(kind: String, amount: int, to_base: bool) -> Control:
	var def: Array = STORAGE_CELL_DEFS.get(kind, ["square", Color.WHITE])
	var tint: Color = def[1]
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(96, 26)
	cell.tooltip_text = "%s（双击%s，右键输入数量）" % [
		_storage_kind_name(kind), "存入" if to_base else "取出"
	]
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = tint
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(bg)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = "%s ×%d" % [_storage_kind_name(kind), amount]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.06, 0.06, 0.06))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	cell.gui_input.connect(
		func(event: InputEvent) -> void:
			if not (event is InputEventMouseButton and event.pressed):
				return
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				if to_base:
					_storage_deposit(kind, _storage_owned(kind))
				else:
					_storage_withdraw(kind, int(GameState.home_base.get("storage", {}).get(kind, 0)))
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_open_storage_qty(kind, to_base)
	)
	return cell


# 单侧（仓库/背包）的分区构建：标题 + 分隔线 + chip 横向 wrap，与背包分区同款
func _build_storage_section(title: String, entries: Array) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 3)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Label.new()
	var total := 0
	for e in entries:
		total += 1
	head.text = "%s（%d）" % [title, total]
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Color(0.82, 0.9, 0.84))
	section.add_child(head)
	section.add_child(HSeparator.new())
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(flow)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.5, 0.56, 0.5))
		flow.add_child(empty)
	else:
		for e in entries:
			flow.add_child(_make_storage_cell(String(e["kind"]), int(e["amount"]), bool(e["to_base"])))
	return section


func _refresh_storage_panel() -> void:
	if _storage_base_grid == null:
		return
	for child in _storage_base_grid.get_children():
		child.queue_free()
	for child in _storage_pack_grid.get_children():
		child.queue_free()
	var storage: Dictionary = GameState.home_base.get("storage", {})
	for sec in STORAGE_SECTIONS:
		var base_entries: Array = []
		var pack_entries: Array = []
		for kind in sec["kinds"]:
			var base_amount := int(storage.get(kind, 0))
			if base_amount > 0:
				base_entries.append({"kind": kind, "amount": base_amount, "to_base": false})
			var pack_amount := _storage_owned(kind)
			if pack_amount > 0:
				pack_entries.append({"kind": kind, "amount": pack_amount, "to_base": true})
		_storage_base_grid.add_child(_build_storage_section(String(sec["title"]), base_entries))
		_storage_pack_grid.add_child(_build_storage_section(String(sec["title"]), pack_entries))


func _storage_deposit(kind: String, amount: int) -> void:
	amount = mini(amount, _storage_owned(kind))
	if amount <= 0:
		return
	if kind == "crystals":
		if not GameState.base_has_containment():
			GameState.notify("没有异能储存仓，结晶无法存放")
			return
		for i in amount:
			GameState.remove_loot("anomaly_crystal")
		var storage: Dictionary = GameState.home_base["storage"]
		storage["crystals"] = int(storage.get("crystals", 0)) + amount
		GameState.home_base_changed.emit()
	else:
		if GameState.store_loot(kind, amount) <= 0:
			return
	GameState.notify("已存入 %s ×%d" % [_storage_kind_name(kind), amount])
	_refresh_storage_panel()


func _storage_withdraw(kind: String, amount: int) -> void:
	var storage: Dictionary = GameState.home_base.get("storage", {})
	amount = mini(amount, int(storage.get(kind, 0)))
	if amount <= 0:
		return
	var got := GameState.withdraw_loot(kind, amount)
	if got > 0:
		GameState.notify("已取出 %s ×%d" % [_storage_kind_name(kind), got])
	_refresh_storage_panel()


func _on_storage_store_all() -> void:
	var crystals := GameState.loot_count("anomaly_crystal")
	if crystals > 0 and not GameState.base_has_containment():
		GameState.notify("没有异能储存仓，%d 颗结晶仍留在背包" % crystals)
	var summary := GameState.store_all_loot()
	GameState.notify("身上没有可存入的物资" if summary.is_empty() else summary)
	_refresh_storage_panel()


class ItemChip extends Control:
	var hud
	var item: Dictionary = {}
	var _press_pos := Vector2.ZERO

	# 已无格子：拖拽仅用于把武器拖到右侧装备栏
	func _get_drag_data(_pos: Vector2):
		hud._drag_item_id = String(item.get("id", ""))
		set_drag_preview(hud._make_drag_preview(item))
		return {"item": String(item.get("id", ""))}

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		# 武器 chip：双击入武器槽（挤位下压），右键打开 升级/配件/子弹 菜单
		if event.pressed and bool(item.get("weapon", false)):
			var wid := String(item.get("id", ""))
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				GameState.equip_weapon(wid)
				GameState.select_weapon(wid)
				hud._refresh_backpack()
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				hud._open_weapon_menu(wid, get_global_mouse_position())
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
			elif event.position.distance_to(_press_pos) < 6.0 and item.has("loot_id"):
				hud._use_chip(String(item["loot_id"]))


class EquipSlot extends Control:
	var hud
	var slot_id := ""

	func _can_drop_data(_pos: Vector2, data) -> bool:
		return (
			data is Dictionary
			and data.has("item")
			and hud._can_equip(slot_id, String(data["item"]))
		)

	func _drop_data(_pos: Vector2, data) -> void:
		hud._equip_item(slot_id, String(data["item"]))

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed):
			return
		# 武器槽：左键选中 / 双击退回背包 / 右键改装菜单
		if slot_id == "primary" or slot_id == "secondary":
			var wid := GameState.weapon_at_slot(0 if slot_id == "primary" else 1)
			if wid == "":
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				hud._open_weapon_menu(wid, get_global_mouse_position())
			elif event.double_click:
				GameState.unequip_weapon(wid)
				hud._refresh_backpack()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				GameState.select_weapon(wid)
				hud._refresh_backpack()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			hud._click_slot(slot_id)


# 顶部资源条小图标：纯形状绘制，不用文字
# 血条上的自动用药阈值游标：拖动设置比例（0 = 关闭）
class ThresholdCursor extends Control:
	var threshold_kind := "hp"
	var _dragging := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ratio() -> float:
		return GameState.auto_heal_ratio

	func _set_ratio(value: float) -> void:
		# 拖到最左端（<4%）视为关闭
		if value < 0.04:
			value = 0.0
		GameState.auto_heal_ratio = value

	func _process(_delta: float) -> void:
		var r := _ratio()
		tooltip_text = (
			"自动用药：生命低于 %d%% 时使用医疗包（拖到最左关闭）" % int(r * 100.0)
			if r > 0.0
			else "自动用药：关闭（拖动此白条设置阈值）"
		)
		queue_redraw()

	func _draw() -> void:
		var r := _ratio()
		if r <= 0.0:
			# 关闭状态：左端画一条暗色小竖条提示可拖
			draw_rect(Rect2(0, 0, 2.0, size.y), Color(1, 1, 1, 0.25))
			return
		var x := clampf(r, 0.0, 1.0) * size.x
		draw_rect(Rect2(x - 1.5, -2.0, 3.0, size.y + 4.0), Color(1, 1, 1, 0.9))
		draw_rect(Rect2(x - 1.5, -2.0, 3.0, 2.0), Color(0.4, 0.9, 1.0, 0.95))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if _dragging:
				_set_ratio(clampf(event.position.x / size.x, 0.0, 1.0))
		elif event is InputEventMouseMotion and _dragging:
			_set_ratio(clampf(event.position.x / size.x, 0.0, 1.0))


class ResIcon extends Control:
	var kind := "circle"
	var tint := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"circle":
				draw_circle(c, size.x * 0.4, tint)
			"cross":
				var w := size.x * 0.26
				draw_rect(Rect2(c.x - w * 0.5, 1.0, w, size.y - 2.0), tint)
				draw_rect(Rect2(1.0, c.y - w * 0.5, size.x - 2.0, w), tint)
			"bullet":
				var w2 := size.x * 0.34
				draw_rect(Rect2(c.x - w2 * 0.5, c.y, w2, c.y - 1.0), tint)
				draw_colored_polygon(
					PackedVector2Array(
						[
							Vector2(c.x - w2 * 0.5, c.y),
							Vector2(c.x + w2 * 0.5, c.y),
							Vector2(c.x, 1.0),
						]
					),
					tint
				)
			"square":
				var s := size.x * 0.72
				draw_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), tint)
			"drop":
				draw_circle(c + Vector2(0, size.y * 0.14), size.x * 0.3, tint)
				draw_colored_polygon(
					PackedVector2Array(
						[
							Vector2(c.x - size.x * 0.24, c.y + size.y * 0.1),
							Vector2(c.x + size.x * 0.24, c.y + size.y * 0.1),
							Vector2(c.x, 1.0),
						]
					),
					tint
				)
			"hex":
				var pts := PackedVector2Array()
				for i in 6:
					var a := PI / 6.0 + i * PI / 3.0
					pts.append(c + Vector2(cos(a), sin(a)) * size.x * 0.42)
				draw_colored_polygon(pts, tint)
			"gear":
				draw_circle(c, size.x * 0.2, tint)
				for i in 4:
					var a2 := PI / 4.0 + i * PI / 2.0
					var d := Vector2(cos(a2), sin(a2))
					draw_line(c + d * size.x * 0.18, c + d * size.x * 0.44, tint, 2.5)
			"coin":
				draw_circle(c, size.x * 0.42, tint)
				draw_circle(c, size.x * 0.22, Color(0.0, 0.0, 0.0, 0.35))
			"diamond":
				var r := size.x * 0.42
				draw_colored_polygon(
					PackedVector2Array(
						[
							c + Vector2(0, -r),
							c + Vector2(r, 0),
							c + Vector2(0, r),
							c + Vector2(-r, 0),
						]
					),
					tint
				)
			"gun":
				# 简易枪械：枪身横条 + 枪管 + 握把
				var gw := size.x * 0.72
				draw_rect(Rect2(c.x - gw * 0.5, c.y - size.y * 0.16, gw, size.y * 0.2), tint)
				draw_rect(Rect2(c.x - gw * 0.5, c.y - size.y * 0.3, gw * 0.32, size.y * 0.14), tint)
				draw_rect(Rect2(c.x + gw * 0.1, c.y, gw * 0.16, size.y * 0.3), tint)


# 中毒状态图标：紫色水滴 + 外圈逆时针倒计时（progress 归零中毒结束）
class PoisonIconView extends Control:
	var progress := 1.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.26
		# 水滴外形：尖顶 + 圆弧底
		var pts := PackedVector2Array([
			c + Vector2(0, -r * 1.7),
			c + Vector2(-r * 0.85, -r * 0.1),
			c + Vector2(-r * 0.7, r * 0.75),
			c + Vector2(0, r * 1.0),
			c + Vector2(r * 0.7, r * 0.75),
			c + Vector2(r * 0.85, -r * 0.1),
			c + Vector2(0, -r * 1.7),
		])
		draw_polyline(pts, Color(0.75, 0.45, 1.0, 0.95), 1.5, true)
		draw_circle(c + Vector2(0, r * 0.25), r * 0.55, Color(0.5, 0.18, 0.8, 0.35)
		)
		# 外圈逆时针倒计时
		if progress > 0.0:
			var top := -PI / 2.0
			var ring_r := minf(size.x, size.y) * 0.45
			draw_arc(c, ring_r, top - progress * TAU, top, 32, Color(0.7, 0.3, 0.95, 0.9), 2.5, true)
class StopwatchView extends Control:
	var progress := 1.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		draw_arc(c, r, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 2.0, true)
		var angle := -PI / 2.0 - (1.0 - progress) * TAU
		draw_line(
			c, c + Vector2(cos(angle), sin(angle)) * r * 0.85, Color(1.0, 0.85, 0.35), 2.5, true
		)
		draw_circle(c, 1.8, Color(1.0, 1.0, 1.0, 0.9))


# 完美闪避 CD 方框图标：与秒表相似的表盘（方底、无表冠以作区分）；
# CD 中绿色扇形从正上方逆时针倒扣褪色，就绪瞬间边缘高光闪烁
class DodgeIconView extends Control:
	var cd_left := 0.0
	var cd_total := 40.0
	var flash := 0.0

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.05, 0.06, 0.08, 0.75), true)
		var ready := cd_left <= 0.0
		var border := Color(0.4, 0.42, 0.5)
		if flash > 0.0:
			border = Color(0.65, 1.0, 0.7).lerp(Color(1.0, 1.0, 1.0), 0.5 + 0.5 * sin(flash * 18.0))
		elif ready:
			border = Color(0.5, 0.95, 0.6)
		draw_rect(rect, border, false, 1.5)
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.28
		var icon_col := Color(0.85, 0.9, 0.85) if ready else Color(0.5, 0.55, 0.5)
		draw_arc(c, r, 0.0, TAU, 24, icon_col, 1.5, true)
		draw_line(c, c + Vector2(0.0, -r * 0.7), icon_col, 1.5, true)
		draw_line(c, c + Vector2(r * 0.5, 0.0), icon_col, 1.5, true)
		if not ready:
			var progress := clampf(cd_left / cd_total, 0.0, 1.0)
			var top := -PI / 2.0
			draw_arc(
				c, r + 3.0, top - progress * TAU, top, 32, Color(0.35, 0.95, 0.45), 3.0, true
			)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


# —— Q 远程炮击圆盘：按住 Q 显示，环形等分选炮种，圆心是联合打击（全部齐射） ——
var _strike_dial: Control = null
var _dial_prev_mouse := Input.MOUSE_MODE_VISIBLE


# 整棵场景树递归找指定类型的炮（不信任组标记，有实体就能指挥）
func _available_artillery(kind: String) -> Array:
	var out: Array = []
	_collect_artillery(get_tree().root, kind, out)
	return out


func _collect_artillery(node: Node, kind: String, out: Array) -> void:
	if str(node.get("defense_type")) == kind:
		out.append(node)
	for child in node.get_children():
		_collect_artillery(child, kind, out)


# Q：开圆盘（圆盘打开时玩家侧 Q 不重复触发，关闭由 HUD 的按键分支负责）
func quick_mortar_command() -> void:
	if GameState.is_run_over():
		return
	if _strike_dial != null:
		return
	if GameState.mortar_command != null or GameState.attack_blocked_by_ui():
		return
	var mortars := _available_artillery("mortar")
	var cannons := _available_artillery("cannon")
	if mortars.is_empty() and cannons.is_empty():
		GameState.notify("没有迫击炮/火炮（在营地防御类建造后按 Q 指挥）")
		return
	# 玩家不在信号覆盖内：圆盘照常弹出，但全部置灰并显示「无信号无法使用」
	var covered := true
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		covered = GameState.point_in_signal_coverage(player.global_position)
	_strike_dial = StrikeDial.new()
	_strike_dial.options = [
		{
			"label": _artillery_label("迫击炮", mortars),
			"kind": "mortar", "disabled": mortars.is_empty() or not covered,
		},
		{
			"label": _artillery_label("火炮", cannons),
			"kind": "cannon", "disabled": cannons.is_empty() or not covered,
		},
	]
	if not covered:
		_strike_dial.banner = "无信号无法使用"
		_show_toast("不在据点信号网络内：孤立信号塔是独立信号区，不与据点互通")
	_strike_dial.on_pick = _on_strike_pick
	# 圆盘期间释放鼠标让悬停/点击生效（游戏内鼠标锁定模式下 GUI 收不到输入）
	_dial_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(_strike_dial)
	GameState.strike_dial_open = true


func _artillery_label(title: String, nodes: Array) -> String:
	if nodes.is_empty():
		return "%s · 未建造" % title
	var status := "被干扰"
	var min_cd := INF
	for n in nodes:
		if bool(n.get("jammed")):
			continue
		var cd := float(n.get("_cooldown"))
		if cd <= 0.0:
			status = "就绪"
			break
		min_cd = minf(min_cd, cd)
	if status != "就绪" and min_cd < INF:
		status = "装填 %ds" % int(ceil(min_cd))
	return "%s ×%d · %s" % [title, nodes.size(), status]


func _on_strike_pick(index: int) -> void:
	if _strike_dial == null:
		return
	var options: Array = _strike_dial.options
	_close_strike_dial()
	if index < 0:
		return
	var player = get_tree().get_first_node_in_group("player")
	# 圆心（index == options.size()）：联合打击——指挥时左键选点，所有就绪火炮齐射
	if index == options.size():
		var all_nodes := _available_artillery("mortar") + _available_artillery("cannon")
		if all_nodes.is_empty():
			return
		var hub = _nearest_artillery(all_nodes, player)
		GameState.mortar_command = hub
		GameState.mortar_remote = false
		GameState.mortar_volley = true
		GameState.mortar_command_kind = ""
		GameState.mortar_command_remote = true
		GameState.notify("联合打击指挥中：左键选点，所有就绪火炮齐射 · 右键/Esc 退出")
		return
	if index > options.size():
		return
	if bool(options[index].get("disabled", false)):
		return
	var nodes := _available_artillery(String(options[index]["kind"]))
	if nodes.is_empty():
		return
	GameState.mortar_command = _nearest_artillery(nodes, player)
	GameState.mortar_remote = false
	GameState.mortar_command_kind = String(options[index]["kind"])
	GameState.mortar_command_remote = true
	GameState.notify("炮击指挥中：左键选择打击点（绿环=可打，红环=超程/装填）· 右键/Esc 退出")


func _nearest_artillery(nodes: Array, player: Node) -> Node:
	var best = nodes[0]
	if player != null and nodes.size() > 1:
		var best_d := INF
		for n in nodes:
			var d: float = (n as Node3D).global_position.distance_to(
				(player as Node3D).global_position
			)
			if d < best_d:
				best_d = d
				best = n
	return best


func _close_strike_dial() -> void:
	if _strike_dial != null:
		_strike_dial.queue_free()
		_strike_dial = null
		Input.mouse_mode = _dial_prev_mouse
	GameState.strike_dial_open = false


# 圆盘本体：按住 Q 显示在屏幕正中的小型轮盘——圆环按炮种数等分（2 种各 180°、
# 3 种各 120°……），扇区间有分隔线；圆心是「联合打击」（所有就绪火炮齐射）。
# 松开 Q 选中悬停项（未悬停则直接消失），未建造的选项灰色不可选
class StrikeDial extends Control:
	const RADIUS := 96.0
	const INNER := 34.0
	const CENTER_PICK := 999  # _hover 取值：圆心联合打击

	var options: Array = []
	var banner := ""  # 非空时圆盘只读展示（如无信号），全部选项与圆心不可选
	var on_pick: Callable
	var _hover := -1


	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		# CanvasLayer 子节点锚定布局有时拿不到视口尺寸（size 变 0 导致点击全落空），
		# 直接显式铺满视口并跟随窗口变化
		_sync_rect()
		get_viewport().size_changed.connect(_sync_rect)


	func _sync_rect() -> void:
		position = Vector2.ZERO
		size = get_viewport_rect().size


	# 始终取视口中心（节点自身 size 首帧未布局，不能用作圆心）
	func _center() -> Vector2:
		return get_viewport_rect().size / 2.0


	# 松开 Q：悬停在可用选项/圆心上 = 选中，否则取消
	func release_pick() -> void:
		on_pick.call(_hover)


	# 圆心返回 CENTER_PICK；扇区从正上方起顺时针数；圆盘外 = -1
	func _pick_at(pos: Vector2) -> int:
		if options.is_empty():
			return -1
		var d := pos - _center()
		if d.length() <= INNER:
			return CENTER_PICK
		if d.length() > RADIUS + 22.0:
			return -1
		var angle := atan2(d.y, d.x) + PI / 2.0
		if angle < 0.0:
			angle += TAU
		return mini(int(angle / TAU * options.size()), options.size() - 1)


	func _pickable(idx: int) -> bool:
		if banner != "":
			return false
		if idx == CENTER_PICK:
			return true
		return idx >= 0 and idx < options.size() and not bool(options[idx].get("disabled", false))


	# 用 _input 而不是 _gui_input：CanvasLayer 下锚定布局可能拿不到尺寸（矩形变 0、
	# GUI 命中测试全落空），_input 不经过矩形命中测试，视口坐标直接判定，必定生效
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var idx := _pick_at(event.position)
			if idx != -1 and not _pickable(idx):
				idx = -1
			if idx != _hover:
				_hover = idx
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var idx := _pick_at(event.position)
				if idx != -1 and _pickable(idx):
					# 圆心映射为 options.size() 传给外层
					on_pick.call(options.size() if idx == CENTER_PICK else idx)
				elif idx == -1:
					on_pick.call(-1)
				get_viewport().set_input_as_handled()


	func _draw() -> void:
		var c := _center()
		var n := options.size()
		var font := ThemeDB.fallback_font
		# 圆环背后的柔光底衬，不遮挡游戏画面
		draw_circle(c, RADIUS + 18.0, Color(0.0, 0.0, 0.0, 0.25))
		# 环形扇区（内圈留给圆心联合打击），从正上方起顺时针等分
		for i in n:
			var a0 := -PI / 2.0 + TAU * i / n
			var a1 := -PI / 2.0 + TAU * (i + 1) / n
			var disabled := bool(options[i].get("disabled", false))
			var col := (
				Color(0.22, 0.28, 0.23, 0.94) if i != _hover else Color(0.55, 0.6, 0.26, 0.96)
			)
			if disabled:
				col = Color(0.13, 0.13, 0.13, 0.88)
			_draw_ring_sector(c, a0, a1, col)
			var mid := (a0 + a1) / 2.0
			var label_pos := c + Vector2(cos(mid), sin(mid)) * ((INNER + RADIUS) * 0.5)
			var text_col := (
				Color(0.5, 0.5, 0.48) if disabled else Color(0.95, 0.95, 0.9)
			)
			draw_string(
				font, label_pos + Vector2(-52, 4), String(options[i]["label"]),
				HORIZONTAL_ALIGNMENT_CENTER, 104, 12, text_col
			)
		# 扇区分隔线
		for i in n:
			var a := -PI / 2.0 + TAU * i / n
			draw_line(
				c + Vector2(cos(a), sin(a)) * INNER,
				c + Vector2(cos(a), sin(a)) * RADIUS,
				Color(0.05, 0.06, 0.05, 0.9), 2.0
			)
		# 圆心：联合打击（banner 非空时改为状态提示，如无信号）
		var center_col := (
			Color(0.1, 0.12, 0.1, 0.96) if _hover != CENTER_PICK
			else Color(0.5, 0.42, 0.16, 0.97)
		)
		draw_circle(c, INNER, center_col)
		draw_arc(c, INNER, 0.0, TAU, 24, Color(0.7, 0.68, 0.5, 0.8), 1.5)
		if banner != "":
			draw_string(
				font, c + Vector2(-60, 4), banner, HORIZONTAL_ALIGNMENT_CENTER, 120, 12,
				Color(1.0, 0.45, 0.35)
			)
		else:
			draw_string(
				font, c + Vector2(-20, -1), "联合", HORIZONTAL_ALIGNMENT_CENTER, 40, 11,
				Color(0.92, 0.88, 0.7)
			)
			draw_string(
				font, c + Vector2(-20, 12), "打击", HORIZONTAL_ALIGNMENT_CENTER, 40, 11,
				Color(0.92, 0.88, 0.7)
			)


	# 内圈到外圈的环形扇面
	func _draw_ring_sector(c: Vector2, a0: float, a1: float, col: Color) -> void:
		var pts := PackedVector2Array()
		var steps := 24
		for s in steps + 1:
			var a := lerpf(a0, a1, float(s) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * RADIUS)
		for s in range(steps, -1, -1):
			var a := lerpf(a0, a1, float(s) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * INNER)
		draw_colored_polygon(pts, col)
