extends Node3D
# 工人管理器：挂在 proto3d 下，同步 GameState.home_base["workers"] 与场景里的工人实体；
# 处理市民招募（走近行人按 E 即跟随，无需据点）与任务/装备面板（自建 CanvasLayer，不动 hud3d）

const RECRUIT_REACH := 2.5
const FOLLOWER_CAP := 4

var _entities := {}
var _followers: Array = []
var _recruit_target: Node3D = null
var _panel: CanvasLayer = null
var _panel_title: Label = null
var _panel_job: Label = null
var _goto_button: Button = null
var _panel_worker := ""
var _gear_panel: CanvasLayer = null
var _gear_title: Label = null
var _gear_list: VBoxContainer = null
var _gear_follower = null
# 装备面板从 J 总览打开时的临时状态：关闭后恢复总览显示
var _gear_from_squad := false
var _squad_panel: CanvasLayer = null
var _squad_grid: GridContainer = null
var _squad_patrol_button: Button = null
var _squad_defend_button: Button = null
var _squad_base_button: Button = null
var _squad_checked := {}
var _squad_refresh := 0.0
# 载具管理面板（Tab）：全城车辆卡片 + 多选 + 大地图标记
var _vehicle_panel: CanvasLayer = null
var _vehicle_title: Label = null
var _vehicle_grid: GridContainer = null
var _vehicle_checked := {}
var _vehicle_refresh := 0.0


func _ready() -> void:
	add_to_group("interactables")
	GameState.home_base_changed.connect(_sync_workers)
	_build_panel()
	_build_gear_panel()
	_build_squad_panel()
	_build_vehicle_panel()
	_sync_workers()


# —— 数据 ↔ 实体同步 ——

func _sync_workers() -> void:
	var alive := {}
	if GameState.has_home_base():
		for w in GameState.workers():
			var wname := String(w["name"])
			alive[wname] = true
			var body = _entities.get(wname, null)
			if body == null or not is_instance_valid(body):
				_spawn_worker(wname)
			elif String(w.get("state", "home")) != "out" and not body.visible:
				body.recall_to_base()
	for wname in _entities.keys():
		if alive.has(wname):
			continue
		var body = _entities[wname]
		_entities.erase(wname)
		if is_instance_valid(body):
			body.queue_free()
	if _panel_worker != "" and GameState.get_worker(_panel_worker).is_empty():
		close_panel()


func _spawn_worker(wname: String) -> void:
	var body := WorkerBody.new()
	body.worker_name = wname
	body.manager = self
	add_child(body)
	body.recall_to_base()
	_entities[wname] = body


func _forget(wname: String) -> void:
	_entities.erase(wname)


# —— 招募：走近行人 2.5m 内按 E（HUD 统一交互菜单）——

func _update_recruit_target() -> void:
	_recruit_target = null
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var best := RECRUIT_REACH
	for npc in get_tree().get_nodes_in_group("pedestrians"):
		if npc.is_queued_for_deletion() or bool(npc.get("_dying")):
			continue
		var d: float = player.global_position.distance_to(npc.global_position)
		if d < best:
			best = d
			_recruit_target = npc


# 招募条件不满足时的原因（空串 = 可招募）：招募即跟随，只看随从数量上限
func _recruit_block_reason() -> String:
	_prune_followers()
	if _followers.size() >= FOLLOWER_CAP:
		return "随从已满（最多 %d 人）" % FOLLOWER_CAP
	return ""


func prompt_text() -> String:
	if _recruit_target == null or not is_instance_valid(_recruit_target):
		return ""
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return ""
	if player.global_position.distance_to(_recruit_target.global_position) > RECRUIT_REACH:
		return ""
	return "市民"


# —— 统一交互菜单协议：招募市民为跟随者（满员时禁用并附原因）——

func interact_title() -> String:
	return "市民"


func on_interact_menu_open(_player: Node3D) -> void:
	if _recruit_target != null and is_instance_valid(_recruit_target):
		_recruit_target.hold_still = true


func on_interact_menu_close(_player: Node3D) -> void:
	if _recruit_target != null and is_instance_valid(_recruit_target):
		_recruit_target.hold_still = false


func interact_options(player: Node3D) -> Array:
	if panel_open() or gear_panel_open() or squad_panel_open() or vehicle_panel_open():
		return []
	if _recruit_target == null or not is_instance_valid(_recruit_target):
		return []
	if player == null:
		return []
	if player.global_position.distance_to(_recruit_target.global_position) > RECRUIT_REACH:
		return []
	var reason := _recruit_block_reason()
	var price := int(_recruit_target.get("recruit_price"))
	if reason.is_empty() and GameState.money < price:
		reason = "现金不够（需要 ¥%d）" % price
	return [
		{
			"id": "recruit",
			"label": "接受开价 ¥%d（跟随我）" % price,
			"disabled": reason != "",
			"reason": reason,
		},
		{"id": "refuse", "label": "拒绝"},
	]


func interact_choose(id: String, _player: Node3D) -> void:
	if id == "recruit":
		_try_recruit()


func _process(_delta: float) -> void:
	_update_recruit_target()
	_prune_followers()
	if gear_panel_open() and (_gear_follower == null or not is_instance_valid(_gear_follower)):
		close_gear_panel()
	if squad_panel_open():
		_squad_refresh -= _delta
		if _squad_refresh <= 0.0:
			_squad_refresh = 0.5
			_refresh_squad_panel()
	if vehicle_panel_open():
		_vehicle_refresh -= _delta
		if _vehicle_refresh <= 0.0:
			_vehicle_refresh = 0.5
			_refresh_vehicle_panel()
	if _recruit_target != null and is_instance_valid(_recruit_target):
		global_position = _recruit_target.global_position
	else:
		global_position = Vector3(0, -500, 0)


func _prune_followers() -> void:
	for i in range(_followers.size() - 1, -1, -1):
		var f = _followers[i]
		if f == null or not is_instance_valid(f):
			_followers.remove_at(i)


func _forget_follower(follower) -> void:
	_followers.erase(follower)


func _try_recruit() -> void:
	if panel_open() or gear_panel_open() or squad_panel_open() or vehicle_panel_open():
		return
	if _recruit_target == null or not is_instance_valid(_recruit_target):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.global_position.distance_to(_recruit_target.global_position) > RECRUIT_REACH:
		return
	var reason := _recruit_block_reason()
	if reason != "":
		GameState.notify(reason + "，无法再带随从")
		return
	var price := int(_recruit_target.get("recruit_price"))
	if not GameState.spend_money(price):
		GameState.notify("现金不够，开价 ¥%d 付不起" % price)
		return
	GameState.notify("你付了 ¥%d" % price)
	var fname := GameState.recruit_worker_name()
	for i in 20:
		if GameState.get_worker(fname).is_empty():
			break
		fname = GameState.recruit_worker_name()
	var npc := _recruit_target
	_recruit_target = null
	if Network.is_multiplayer():
		Network.unregister_entity(npc)
	# 目标躲在建筑里时先送回门口，随从不能留在内部房间（会追不出门）
	if str(npc.get("sheltered")) != "":
		var interiors_root := get_tree().get_first_node_in_group("building_interiors")
		if interiors_root != null:
			interiors_root.npc_leave(npc)
			npc.set("sheltered", "")
	var follower := FollowerBody.new()
	follower.follower_name = fname
	follower.manager = self
	# 挂在管理器同级（proto3d 下）：管理器自身会跟随招募目标移动，不能当跟随者的父节点
	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(follower)
	follower.global_position = npc.global_position
	npc.queue_free()
	_followers.append(follower)
	GameState.notify("%s 开始跟随你" % fname)


# —— 任务面板 ——

func panel_open() -> bool:
	return _panel != null and _panel.visible


func _build_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 25
	_panel.visible = false
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	_panel.add_child(dim)
	_pin_full_rect(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := PanelContainer.new()
	center.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)
	_panel_title = Label.new()
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_panel_title)
	_panel_job = Label.new()
	_panel_job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_job.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_panel_job)
	for job in GameState.WORKER_JOBS.keys():
		if job == "idle":
			continue
		var button := _make_panel_button(GameState.worker_job_name(job), _on_job_pressed.bind(job))
		vbox.add_child(button)
		if job == "goto":
			_goto_button = button
	var dismiss := _make_panel_button("解散工人", _on_dismiss_pressed)
	vbox.add_child(dismiss)
	var idle_button := _make_panel_button("待命", _on_job_pressed.bind("idle"))
	vbox.add_child(idle_button)
	var close := _make_panel_button("关闭", close_panel)
	vbox.add_child(close)


# 面板按钮统一压缩行高与字号，6 个任务 + 3 个操作也能放进 360 高的画布
# CanvasLayer 直接子节点的锚定布局可能拿不到视口尺寸（变 0 导致面板布局散架、
# 内容挤出屏幕），显式铺满视口并跟随窗口变化
func _pin_full_rect(ctrl: Control) -> void:
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.position = Vector2.ZERO
	ctrl.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(
		func() -> void: ctrl.size = get_viewport().get_visible_rect().size
	)


func _make_panel_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(108, 21)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(handler)
	return button


func open_panel(wname: String) -> void:
	var w := GameState.get_worker(wname)
	if w.is_empty():
		return
	_panel_worker = wname
	_panel_title.text = "工人：%s" % wname
	_panel_job.text = "当前任务：%s" % GameState.worker_job_name(String(w.get("job", "idle")))
	if _goto_button != null:
		var has_marker := GameState.map_marker != Vector2.ZERO
		_goto_button.disabled = not has_marker
		_goto_button.tooltip_text = (
			"前往地图标点" if has_marker else "先在地图上标一个点（M 打开地图）"
		)
	_panel.visible = true
	_sync_panel_flag()


func close_panel() -> void:
	_panel_worker = ""
	if _panel != null:
		_panel.visible = false
	_sync_panel_flag()


# 任一 UI 面板（工人卡片/装备/小队总览）打开时同步 GameState 面板标记，
# 让面板打开期间鼠标点击不会触发攻击
func _sync_panel_flag() -> void:
	GameState.custom_panel_open = (
		(_panel != null and _panel.visible)
		or (_gear_panel != null and _gear_panel.visible)
		or (_squad_panel != null and _squad_panel.visible)
		or (_vehicle_panel != null and _vehicle_panel.visible)
	)


func _on_job_pressed(job: String) -> void:
	if _panel_worker == "":
		return
	if job == "goto":
		if GameState.map_marker == Vector2.ZERO:
			GameState.notify("先在地图上标一个点，再派工人前往")
			return
		GameState.assign_worker(_panel_worker, job, {"target": GameState.map_marker_3d()})
	else:
		GameState.assign_worker(_panel_worker, job)
	GameState.notify("%s 开始执行：%s" % [_panel_worker, GameState.worker_job_name(job)])
	close_panel()


func _on_dismiss_pressed() -> void:
	if _panel_worker == "":
		return
	GameState.remove_worker(_panel_worker)
	GameState.notify("%s 离开了营地" % _panel_worker)
	close_panel()


# —— 装备面板：把玩家的枪械/防弹衣/近战工具交给跟随者 ——

func gear_panel_open() -> bool:
	return _gear_panel != null and _gear_panel.visible


func _build_gear_panel() -> void:
	_gear_panel = CanvasLayer.new()
	# 层级高于 J 总览（25）：从 J 面板点开装备菜单时不被其遮罩压住
	_gear_panel.layer = 26
	_gear_panel.visible = false
	add_child(_gear_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	_gear_panel.add_child(dim)
	_pin_full_rect(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := PanelContainer.new()
	center.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)
	_gear_title = Label.new()
	_gear_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_gear_title)
	_gear_list = VBoxContainer.new()
	_gear_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_gear_list)
	var close := _make_panel_button("关闭", close_gear_panel)
	vbox.add_child(close)


func open_gear_panel(follower) -> void:
	_gear_follower = follower
	_refresh_gear_panel()
	# 从 J 总览打开装备菜单时先收起总览：两层全屏遮罩叠在一起会互相挡点击
	if squad_panel_open():
		_squad_panel.visible = false
		_gear_from_squad = true
	_gear_panel.visible = true
	_sync_panel_flag()


func close_gear_panel() -> void:
	_gear_follower = null
	if _gear_panel != null:
		_gear_panel.visible = false
	if _gear_from_squad:
		_gear_from_squad = false
		if _squad_panel != null:
			_squad_panel.visible = true
	_sync_panel_flag()


func _refresh_gear_panel() -> void:
	if _gear_follower == null or not is_instance_valid(_gear_follower):
		return
	_gear_title.text = "给 %s 配备装备" % _gear_follower.follower_name
	for child in _gear_list.get_children():
		child.queue_free()
	var count := 0
	for id in GameState.weapons.keys():
		if int(GameState.weapons[id]) <= 0 or not GameState.WEAPONS.has(id):
			continue
		var w: Dictionary = GameState.WEAPONS[id]
		if bool(w.get("melee", false)) or bool(w.get("explosive", false)):
			continue
		_gear_list.add_child(_make_panel_button(
			"给予 %s（伤害 %d）" % [String(w["name"]), int(w["damage"])],
			_on_give_gear.bind("weapon", id)
		))
		count += 1
	if GameState.armor_id != "":
		_gear_list.add_child(_make_panel_button(
			"给予 %s（生命上限 +40）" % GameState.loot_name(GameState.armor_id),
			_on_give_gear.bind("armor", GameState.armor_id)
		))
		count += 1
	if GameState.melee_item != "":
		_gear_list.add_child(_make_panel_button(
			"给予 %s（近战 %d 伤害）" % [
				GameState.loot_name(GameState.melee_item), GameState.melee_item_damage,
			],
			_on_give_gear.bind("melee", GameState.melee_item)
		))
		count += 1
	if count == 0:
		var empty := Label.new()
		empty.text = "你没有可给出的装备"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 11)
		_gear_list.add_child(empty)


func _on_give_gear(kind: String, id: String) -> void:
	if _gear_follower == null or not is_instance_valid(_gear_follower):
		close_gear_panel()
		return
	match kind:
		"weapon":
			if int(GameState.weapons.get(id, 0)) <= 0:
				return
			GameState.strip_weapon(id)
			_gear_follower.equip_weapon(id)
			GameState.notify(
				"把 %s 交给了 %s" % [String(GameState.WEAPONS[id]["name"]), _gear_follower.follower_name]
			)
		"armor":
			if GameState.armor_id == "":
				return
			GameState.strip_armor()
			_gear_follower.equip_armor()
			GameState.notify("把 %s 交给了 %s" % [GameState.loot_name(id), _gear_follower.follower_name])
		"melee":
			if GameState.melee_item == "":
				return
			var damage := GameState.melee_item_damage
			GameState.strip_melee()
			_gear_follower.equip_melee(id, damage)
			GameState.notify("把 %s 交给了 %s" % [GameState.loot_name(id), _gear_follower.follower_name])
	_refresh_gear_panel()


# —— 随从队伍：列表查询与批量任务指派 ——

func follower_list() -> Array:
	_prune_followers()
	return _followers.duplicate()


static func follower_task_name(task: String) -> String:
	match task:
		"follow":
			return "跟随"
		"goto_base":
			return "去营地"
		"guard":
			return "守营地"
		"stay":
			return "警戒"
		"scavenge":
			return "拾荒"
		"patrol":
			return "巡逻"
		"defend":
			return "防守"
		"drive":
			return "驾驶中"
	return task


func assign_follower_task(list: Array, task: String, point := Vector3.ZERO) -> void:
	var player = get_tree().get_first_node_in_group("player")
	for f in list:
		if f == null or not is_instance_valid(f):
			continue
		# 驾驶中的随从改指派任务 = 先下车归队（车已失效则直接恢复可见）
		if String(f.get("mode")) == "drive":
			var vref = f.get("vehicle_ref")
			if vref != null and is_instance_valid(vref) and vref.has_method("dismiss_pilot"):
				vref.call("dismiss_pilot")
			else:
				f.visible = true
				f.add_to_group("npcs")
		f.mode = task
		if task == "scavenge":
			f.task_point = player.global_position if player != null else f.global_position
		elif task == "patrol" or task == "defend":
			f.task_point = point
		f._collect_target = null
		f._patrol_moving = false
		f._patrol_wait = 0.0
		if task != "scavenge":
			# 换岗前把背包里的物资结算给玩家，避免指令切换吞掉已捡物资
			if not f._carry.is_empty():
				f._deliver_carry()
			f._deliver_requested = false
		f._refresh_label()
		GameState.notify("%s：%s" % [f.follower_name, follower_task_name(task)])


# —— 随从队伍窗口（J 开关，多选指派）——

func squad_panel_open() -> bool:
	return _squad_panel != null and _squad_panel.visible


func _build_squad_panel() -> void:
	_squad_panel = CanvasLayer.new()
	_squad_panel.layer = 25
	_squad_panel.visible = false
	add_child(_squad_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	_squad_panel.add_child(dim)
	_pin_full_rect(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := PanelContainer.new()
	center.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)
	var title := Label.new()
	title.text = "成员总览（J 关闭）· 点随从卡片勾选后可批量指派"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	# 成员卡片网格：工人 + 随从全部列出
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_squad_grid = GridContainer.new()
	_squad_grid.columns = 3
	_squad_grid.add_theme_constant_override("h_separation", 4)
	_squad_grid.add_theme_constant_override("v_separation", 4)
	_squad_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_squad_grid)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row1)
	row1.add_child(_make_panel_button("全选/全不选", _on_squad_toggle_all))
	row1.add_child(_make_panel_button("跟随我", _on_squad_follow))
	row1.add_child(_make_panel_button("附近拾荒", _on_squad_scavenge))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row2)
	_squad_patrol_button = _make_panel_button("巡逻标点", _on_squad_patrol)
	row2.add_child(_squad_patrol_button)
	_squad_defend_button = _make_panel_button("防守标点", _on_squad_defend)
	row2.add_child(_squad_defend_button)
	_squad_base_button = _make_panel_button("回营地", _on_squad_base)
	row2.add_child(_squad_base_button)
	row2.add_child(_make_panel_button("立即运送", _on_squad_deliver))
	row2.add_child(_make_panel_button("解散", _on_squad_dismiss))
	vbox.add_child(_make_panel_button("关闭", close_squad_panel))


func toggle_squad_panel() -> void:
	if squad_panel_open():
		close_squad_panel()
	else:
		open_squad_panel()


# —— 载具管理面板（Tab）：全城车辆卡片 + 多选 + 大地图标记 ——

func vehicle_panel_open() -> bool:
	return _vehicle_panel != null and _vehicle_panel.visible


func toggle_vehicle_panel() -> void:
	if vehicle_panel_open():
		close_vehicle_panel()
	else:
		open_vehicle_panel()


func open_vehicle_panel() -> void:
	if squad_panel_open():
		close_squad_panel()
	_refresh_vehicle_panel()
	_vehicle_refresh = 0.5
	_vehicle_panel.visible = true
	_sync_panel_flag()


func close_vehicle_panel() -> void:
	if _vehicle_panel != null:
		_vehicle_panel.visible = false
	_sync_panel_flag()


func _build_vehicle_panel() -> void:
	_vehicle_panel = CanvasLayer.new()
	_vehicle_panel.layer = 25
	_vehicle_panel.visible = false
	add_child(_vehicle_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	_vehicle_panel.add_child(dim)
	_pin_full_rect(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := PanelContainer.new()
	center.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)
	_vehicle_title = Label.new()
	_vehicle_title.text = "载具管理"
	_vehicle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vehicle_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_vehicle_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_vehicle_grid = GridContainer.new()
	_vehicle_grid.columns = 3
	_vehicle_grid.add_theme_constant_override("h_separation", 4)
	_vehicle_grid.add_theme_constant_override("v_separation", 4)
	_vehicle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vehicle_grid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)
	row.add_child(_make_panel_button("全选/全不选", _on_vehicle_toggle_all))
	row.add_child(_make_panel_button("标记选中到大地图", _on_vehicle_mark))
	row.add_child(_make_panel_button("委派驾驶员", _on_vehicle_assign_pilot))
	row.add_child(_make_panel_button("开往地图标点", _on_vehicle_goto_marker))
	row.add_child(_make_panel_button("召回身边", _on_vehicle_recall))
	row.add_child(_make_panel_button("关闭", close_vehicle_panel))
	var hint := Label.new()
	hint.text = "勾选后：标记地图 / 委派随从驾驶（变玩家车，可远程指挥）· Tab/Esc 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(hint)
	# Tab 是 Godot 焦点导航默认键：按钮禁用焦点，保证 Tab/Esc 一定能到达 _unhandled_input
	for btn in box.find_children("*", "Button", true, false):
		(btn as Button).focus_mode = Control.FOCUS_NONE


# 每 0.5s 重建卡片；勾选状态按车辆实例保存在 _vehicle_checked，重建后不丢
func _refresh_vehicle_panel() -> void:
	if _vehicle_grid == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	for key in _vehicle_checked.keys():
		if key == null or not is_instance_valid(key) or key.is_queued_for_deletion():
			_vehicle_checked.erase(key)
	for child in _vehicle_grid.get_children():
		child.queue_free()
	# 只列「我方载具」：委派了驾驶员的车（owned）+ 玩家正在驾驶的车——
	# 城市里的野生车不进面板；委派入口 = 驾驶中车辆的卡片（选中后「委派驾驶员」）
	var vehicles: Array = []
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == null or not is_instance_valid(v) or v.is_queued_for_deletion():
			continue
		var mine: bool = bool(v.get("owned")) or (player != null and v.get("driver") == player)
		if mine:
			vehicles.append(v)
	_vehicle_title.text = "我的载具（%d 辆）" % vehicles.size()
	if vehicles.is_empty():
		var empty := Label.new()
		empty.text = "还没有自己的载具——开上一辆车后按 Tab 委派随从驾驶，
委派后即使人不在车上也归你指挥"
		empty.add_theme_font_size_override("font_size", 11)
		empty.modulate = Color(0.8, 0.8, 0.8)
		_vehicle_grid.add_child(empty)
		return
	for v in vehicles:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 1)
		_vehicle_grid.add_child(card)
		var name_text := String(v.call("_vehicle_name")) + "·" + str(v.get_instance_id() % 100)
		var check := CheckBox.new()
		check.text = name_text
		check.focus_mode = Control.FOCUS_NONE
		var wrecked := bool(v.get("destroyed"))
		check.disabled = wrecked
		check.button_pressed = bool(_vehicle_checked.get(v, false)) and not wrecked
		var vref = v
		check.toggled.connect(func(on: bool) -> void: _vehicle_checked[vref] = on)
		card.add_child(check)
		var info := Label.new()
		info.add_theme_font_size_override("font_size", 10)
		if wrecked:
			info.text = "已报废"
			info.modulate = Color(0.6, 0.6, 0.6)
		else:
			var state := "驾驶中" if v.get("driver") != null else "停放"
			if bool(v.get("owned")) and not String(v.get("pilot_name")).is_empty():
				state = "我方·%s 驾驶" % String(v.get("pilot_name"))
				if (v.get("auto_target") as Vector3) != Vector3.ZERO:
					state += "→ 自动驾驶中"
			var dist := ""
			if player != null:
				dist = " · 距你 %dm" % int((v.global_position as Vector3).distance_to(player.global_position))
			var fuel_now := float(v.get("fuel"))
			var fuel_cap := float(v.call("tank_cap"))
			info.text = "%s · 血 %d/%d · 油 %.0f/%.0fL · 斗 %d/%d%s" % [
				state, int(v.get("hp")), int(v.get("max_hp")),
				fuel_now, fuel_cap, int(v.get("cargo")), int(v.call("cargo_cap")), dist,
			]
		card.add_child(info)


func _on_vehicle_toggle_all() -> void:
	var vehicles: Array = get_tree().get_nodes_in_group("vehicles")
	var any_off := false
	for v in vehicles:
		if v != null and is_instance_valid(v) and not bool(v.get("destroyed")):
			if not bool(_vehicle_checked.get(v, false)):
				any_off = true
				break
	for v in vehicles:
		if v != null and is_instance_valid(v) and not bool(v.get("destroyed")):
			_vehicle_checked[v] = any_off
	_refresh_vehicle_panel()


# 选中的车里取离玩家最近的一辆，写大地图标记（M 打开查看）
func _on_vehicle_mark() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var best = null
	var best_dist := INF
	for v in _vehicle_checked.keys():
		if v == null or not is_instance_valid(v) or not bool(_vehicle_checked[v]):
			continue
		if bool(v.get("destroyed")):
			continue
		var dist := (v.global_position as Vector3).distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = v
	if best == null:
		GameState.notify("先勾选至少一辆可用的车")
		return
	var pos: Vector3 = best.global_position
	GameState.map_marker = Vector2(pos.x, pos.z) / GameState.WORLD_SCALE_3D
	GameState.notify("已在大地图标记 %s（按 M 查看）" % String(best.call("_vehicle_name")))


# 选中的车里取第一辆未委派未报废的：派一名随从当驾驶员（消耗随从名额）
func _on_vehicle_assign_pilot() -> void:
	var target = null
	for v in _vehicle_checked.keys():
		if v == null or not is_instance_valid(v) or not bool(_vehicle_checked[v]):
			continue
		if bool(v.get("destroyed")) or bool(v.get("owned")):
			continue
		target = v
		break
	if target == null:
		GameState.notify("先勾选一辆未委派且未报废的车")
		return
	var pilot = null
	for f in _followers:
		if f != null and is_instance_valid(f) and String(f.get("mode")) != "drive":
			pilot = f
			break
	if pilot == null:
		GameState.notify("没有可委派的随从（走近市民按 E 招募）")
		return
	var pname := String(pilot.get("follower_name"))
	pilot.set("mode", "drive")
	pilot.set("vehicle_ref", target)
	pilot.visible = false
	pilot.remove_from_group("npcs")
	target.call("assign_pilot", pname, pilot)
	_refresh_vehicle_panel()


# 选中的玩家车全部开往大地图标记点
func _on_vehicle_goto_marker() -> void:
	if GameState.map_marker == Vector2.ZERO:
		GameState.notify("先在地图上标一个点（M 打开地图左键标点）")
		return
	var n := 0
	for v in _vehicle_checked.keys():
		if v == null or not is_instance_valid(v) or not bool(_vehicle_checked[v]):
			continue
		v.call("command_to", GameState.map_marker_3d())
		n += 1
	if n == 0:
		GameState.notify("先勾选车辆")


# 选中的玩家车全部开回玩家身边
func _on_vehicle_recall() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var n := 0
	for v in _vehicle_checked.keys():
		if v == null or not is_instance_valid(v) or not bool(_vehicle_checked[v]):
			continue
		v.call("command_to", player.global_position)
		n += 1
	if n == 0:
		GameState.notify("先勾选车辆")


func open_squad_panel() -> void:
	if vehicle_panel_open():
		close_vehicle_panel()
	_refresh_squad_panel()
	_squad_refresh = 0.5
	_squad_panel.visible = true
	_sync_panel_flag()


func close_squad_panel() -> void:
	if _squad_panel != null:
		_squad_panel.visible = false
	_sync_panel_flag()


# 每 0.5s 重建卡片；勾选状态按随从实例保存在 _squad_checked，重建后不丢
func _refresh_squad_panel() -> void:
	if _squad_grid == null:
		return
	_prune_followers()
	for key in _squad_checked.keys():
		if key is String:
			# 工人名：工人已不存在则清除勾选
			if GameState.get_worker(key).is_empty():
				_squad_checked.erase(key)
		elif key == null or not is_instance_valid(key) or not _followers.has(key):
			_squad_checked.erase(key)
	for child in _squad_grid.get_children():
		child.queue_free()
	var count := 0
	# 营地工人卡片（含操作员）：与随从共享同一总览，可勾选下达新指令（打断旧岗位）
	for w in GameState.workers():
		count += 1
		var wname := String(w.get("name", ""))
		_squad_grid.add_child(_make_member_card(
			wname,
			"工人",
			GameState.worker_proficiency(wname),
			GameState.worker_skills(wname),
			GameState.worker_job_name(String(w.get("job", "idle"))),
			wname
		))
	# 随从卡片：点击勾选，供下方批量指派
	for f in _followers:
		count += 1
		_squad_grid.add_child(_make_member_card(
			f.follower_name,
			"随从",
			0,
			GameState.skills_for_name(f.follower_name),
			"%s · %s · HP %d/%d" % [follower_task_name(f.mode), f._gear_name(), f.hp, f.max_hp],
			f
		))
	if count == 0:
		var empty := Label.new()
		empty.text = "还没有成员——走近市民按 E 招募"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 11)
		_squad_grid.add_child(empty)
	var has_marker := GameState.map_marker != Vector2.ZERO
	_squad_patrol_button.disabled = not has_marker
	_squad_defend_button.disabled = not has_marker
	var marker_tip := "以地图标点为目标" if has_marker else "先在地图上标一个点（M 打开地图）"
	_squad_patrol_button.tooltip_text = marker_tip
	_squad_defend_button.tooltip_text = marker_tip
	var has_base := GameState.has_home_base()
	_squad_base_button.disabled = not has_base
	_squad_base_button.tooltip_text = "返回营地" if has_base else "先占领一个据点"


# 成员卡片：名字+角色 / 等级+技能 / 当前状态；ref 非空时是随从（点击切换勾选）
func _make_member_card(
	mname: String, role: String, level: int, skills: Array, status: String, ref
) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(124, 50)
	var selectable: bool = ref != null
	card.mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
	var checked := selectable and bool(_squad_checked.get(ref, false))
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.16, 0.24, 0.17, 0.95) if checked else Color(0.08, 0.11, 0.10, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)
	if selectable:
		var border := ReferenceRect.new()
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.border_color = Color(0.9, 0.85, 0.4) if checked else Color(0.25, 0.3, 0.27)
		border.border_width = 1.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(border)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	var name_label := Label.new()
	name_label.text = "%s [%s]" % [mname, role]
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override(
		"font_color", Color(0.95, 0.92, 0.65) if checked else Color(0.88, 0.9, 0.85)
	)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	var skill_label := Label.new()
	skill_label.text = "Lv%d · 技能 %s" % [level, "/".join(skills)]
	skill_label.add_theme_font_size_override("font_size", 9)
	skill_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.72))
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(skill_label)
	var job_label := Label.new()
	job_label.text = status
	job_label.add_theme_font_size_override("font_size", 9)
	job_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.64))
	job_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(job_label)
	if selectable:
		card.tooltip_text = (
			"左键勾选/取消（新指令会打断旧岗位）"
			if ref is String
			else "左键勾选/取消 · 右键装备"
		)
		card.gui_input.connect(
			func(event: InputEvent) -> void:
				if not (event is InputEventMouseButton and event.pressed):
					return
				if event.button_index == MOUSE_BUTTON_LEFT:
					_squad_checked[ref] = not bool(_squad_checked.get(ref, false))
					_refresh_squad_panel()
				elif event.button_index == MOUSE_BUTTON_RIGHT and not (ref is String):
					open_gear_panel(ref)
		)
	return card


func _on_squad_toggle_all() -> void:
	_prune_followers()
	var targets: Array = []
	for f in _followers:
		targets.append(f)
	for w in GameState.workers():
		targets.append(String(w["name"]))
	var all := not targets.is_empty()
	for t in targets:
		if not bool(_squad_checked.get(t, false)):
			all = false
			break
	for t in targets:
		_squad_checked[t] = not all
	_refresh_squad_panel()


func _squad_selected() -> Array:
	var out: Array = []
	for f in _followers:
		if f != null and is_instance_valid(f) and bool(_squad_checked.get(f, false)):
			out.append(f)
	return out


# 选中的营地工人（卡片 ref = 工人名）；新指令打断旧岗位（assign_worker 自动撤出操作员位）
func _squad_selected_workers() -> Array:
	var out: Array = []
	for w in GameState.workers():
		var wname := String(w["name"])
		if bool(_squad_checked.get(wname, false)):
			out.append(wname)
	return out


func _notify_workers(names: Array, text: String) -> void:
	for wname in names:
		GameState.notify("%s：%s" % [wname, text])


func _on_squad_follow() -> void:
	assign_follower_task(_squad_selected(), "follow")
	for wname in _squad_selected_workers():
		GameState.assign_worker(wname, "follow")
	_notify_workers(_squad_selected_workers(), "跟随")


func _on_squad_scavenge() -> void:
	assign_follower_task(_squad_selected(), "scavenge")
	for wname in _squad_selected_workers():
		GameState.assign_worker(wname, "collect")
	_notify_workers(_squad_selected_workers(), "收集战斗掉落")


func _on_squad_patrol() -> void:
	if GameState.map_marker == Vector2.ZERO:
		GameState.notify("先在地图上标一个点（M 打开地图）")
		return
	assign_follower_task(_squad_selected(), "patrol", GameState.map_marker_3d())
	for wname in _squad_selected_workers():
		GameState.assign_worker(wname, "goto", {"target": GameState.map_marker_3d()})
	_notify_workers(_squad_selected_workers(), "前往标点")


func _on_squad_defend() -> void:
	if GameState.map_marker == Vector2.ZERO:
		GameState.notify("先在地图上标一个点（M 打开地图）")
		return
	assign_follower_task(_squad_selected(), "defend", GameState.map_marker_3d())
	for wname in _squad_selected_workers():
		GameState.assign_worker(wname, "goto", {"target": GameState.map_marker_3d()})
	_notify_workers(_squad_selected_workers(), "防守标点")


func _on_squad_base() -> void:
	if not GameState.has_home_base():
		GameState.notify("先占领一个据点")
		return
	assign_follower_task(_squad_selected(), "goto_base")
	for wname in _squad_selected_workers():
		GameState.assign_worker(wname, "idle")
	_notify_workers(_squad_selected_workers(), "回营地待命")


# 手动运送：命令选中的拾荒随从/收集工人立刻把背包里的物资送回（送完继续原任务）
func _on_squad_deliver() -> void:
	var n := 0
	for f in _squad_selected():
		if f == null or not is_instance_valid(f):
			continue
		if f._carry.is_empty():
			continue
		f._deliver_requested = true
		n += 1
	for wname in _squad_selected_workers():
		var body = _entities.get(wname, null)
		if body == null or not is_instance_valid(body):
			continue
		if String(body._job()) != "collect" or body._carry.is_empty():
			continue
		body._deliver_requested = true
		n += 1
	if n > 0:
		GameState.notify("已命令 %d 名成员立即运送物资" % n)
	else:
		GameState.notify("选中的成员背包里没有可运送的物资")


func _on_squad_dismiss() -> void:
	for f in _squad_selected():
		if f != null and is_instance_valid(f):
			f._dismiss()
	for wname in _squad_selected_workers():
		GameState.remove_worker(wname)
		GameState.notify("%s 离开了营地" % wname)
	_refresh_squad_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_J:
		toggle_squad_panel()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_TAB:
		toggle_vehicle_panel()
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_ESCAPE:
		return
	if vehicle_panel_open():
		close_vehicle_panel()
	elif squad_panel_open():
		close_squad_panel()
	elif panel_open():
		close_panel()
	elif gear_panel_open():
		close_gear_panel()


# 工人实体：BlockyRig 市民外观 + 胸前醒目色块；加入 npcs 组后会被丧尸当作攻击目标
class WorkerBody extends CharacterBody3D:
	const GRAVITY := 18.0
	const SPEED := 4.6
	const DECIDE_INTERVAL := 0.2
	const INTERACT_REACH := 2.5
	const FOLLOW_DIST := 2.5
	const SHOOT_RANGE := 15.0
	const SHOOT_DAMAGE := 10
	const SHOOT_COOLDOWN := 0.8
	const COLLECT_RANGE := 30.0
	const COLLECT_MAX := 20
	# 随身背包容量（各类物资合计）：收集装满才背回据点，玩家也可手动命令立即运送
	const CARRY_CAPACITY := 40
	const BUILD_INTERVAL := 60.0
	const SCAVENGE_MIN := 180.0
	const SCAVENGE_MAX := 300.0
	# 熟练度：同岗工作每 PROFICIENCY_INTERVAL 秒升 1 级（占位值，待调优）
	const PROFICIENCY_INTERVAL := 120.0

	var worker_name := ""
	var manager: Node3D = null
	var max_hp := 60
	var hp := 60
	# npcs 组兼容桩：丧尸/小地图/目击逻辑会对 npcs 组成员访问这些成员
	var role := "worker"
	var _killed_by_player := false
	var net_puppet := false
	var _dying := false

	var _limbs := {}
	var _collision: CollisionShape3D = null
	var _name_label: Label3D = null
	var _decide := 0.0
	var _next_shot := 0
	var _build_timer := 0.0
	var _build_anim := 0.0
	var _proficiency_timer := 0.0
	var _move_target := Vector3.ZERO
	var _move_speed := SPEED
	var _has_move := false
	var _collect_target: Node3D = null
	var _carry := {}
	# 手动运送请求（小队面板「立即运送」）：背包未满也先背回据点
	var _deliver_requested := false


	func _ready() -> void:
		add_to_group("npcs")
		add_to_group("workers")
		add_to_group("interactables")
		GameState.request_spatial_rebuild()
		collision_layer = 1
		collision_mask = 1
		_collision = CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		_collision.shape = capsule
		_collision.position = Vector3(0, 0.9, 0)
		add_child(_collision)
		_limbs = BlockyRig.build(self, null, {"model": BlockyRig.random_civilian()})
		_limbs["aiming"] = true
		_add_marker()
		_name_label = Label3D.new()
		_name_label.font_size = 48
		_name_label.modulate = Color(1.0, 0.7, 0.3)
		_name_label.outline_size = 8
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.position = Vector3(0, 2.15, 0)
		add_child(_name_label)
		_refresh_label()


	# 胸前醒目色块：区别于普通市民
	func _add_marker() -> void:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.36, 0.2, 0.1)
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.55, 0.1)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.45, 0.05)
		material.emission_energy_multiplier = 1.5
		mesh.material_override = material
		mesh.position = Vector3(0, 1.32, -0.28)
		add_child(mesh)


	func _refresh_label() -> void:
		if _name_label != null:
			var lv := GameState.worker_proficiency(worker_name)
			_name_label.text = "%s（%s%s）" % [
				worker_name, GameState.worker_job_name(_job()),
				"·熟练%d级" % lv if lv > 0 else "",
			]


	func can_see_node(_node: Node3D) -> bool:
		return false


	func show_alert() -> void:
		pass


	func witness_crime() -> void:
		pass


	func _worker() -> Dictionary:
		return GameState.get_worker(worker_name)


	func _job() -> String:
		return String(_worker().get("job", "idle"))


	func _base_pos() -> Vector3:
		if GameState.has_home_base():
			return GameState.home_base.get("position", global_position)
		return global_position


	# 任务/状态切换后回到据点并恢复可见（例如外出寻找物资途中被改派）
	func recall_to_base() -> void:
		var base := _base_pos()
		global_position = base + Vector3(randf_range(-2.0, 2.0), 0.3, randf_range(-2.0, 2.0))
		visible = true
		if _collision != null:
			_collision.set_deferred("disabled", false)


	func prompt_text() -> String:
		return ""


	# —— 统一交互菜单协议：分配任务 / 解散工人 ——

	func interact_title() -> String:
		return "%s（%s）" % [worker_name, GameState.worker_job_name(_job())]


	func interact_options(player: Node3D) -> Array:
		if _dying or player == null:
			return []
		if global_position.distance_to(player.global_position) > INTERACT_REACH:
			return []
		return [
			{"id": "assign", "label": "分配任务（当前：%s）" % GameState.worker_job_name(_job())},
			{"id": "dismiss", "label": "解散工人"},
		]


	func interact_choose(id: String, _player: Node3D) -> void:
		match id:
			"assign":
				if manager != null and manager.has_method("open_panel"):
					manager.open_panel(worker_name)
			"dismiss":
				GameState.remove_worker(worker_name)
				GameState.notify("%s 离开了营地" % worker_name)


	func _physics_process(delta: float) -> void:
		if _dying:
			return
		_decide -= delta
		if _decide <= 0.0:
			_decide = DECIDE_INTERVAL
			_decide_job()
			_refresh_label()
		# 熟练度：同岗（build/scavenge/collect/guard/operate）累积时间，到间隔升 1 级
		var job := _job()
		if job == "build" or job == "scavenge" or job == "collect" or job == "guard" or job == "operate":
			_proficiency_timer += delta
			if _proficiency_timer >= PROFICIENCY_INTERVAL:
				_proficiency_timer -= PROFICIENCY_INTERVAL
				GameState.worker_gain_proficiency(worker_name)
		if job == "build":
			_build_timer += delta
			var interval := BUILD_INTERVAL / (1.0 + 0.15 * GameState.worker_proficiency(worker_name))
			if _build_timer >= interval:
				_build_produce()
			_build_anim -= delta
			if _build_anim <= 0.0:
				_build_anim = randf_range(3.0, 6.0)
				BlockyRig.play_once(_limbs, "attack-melee-right")
		velocity.y -= GRAVITY * delta
		if _has_move:
			var to := _move_target - global_position
			to.y = 0.0
			if to.length() < 0.4:
				_has_move = false
				velocity.x = 0.0
				velocity.z = 0.0
			else:
				var dir := to.normalized()
				velocity.x = dir.x * _move_speed
				velocity.z = dir.z * _move_speed
				rotation.y = atan2(-dir.x, -dir.z)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		move_and_slide()
		BlockyRig.update(_limbs, delta, Vector2(velocity.x, velocity.z).length())


	# —— 任务决策（每 0.2s 一次）——

	func _decide_job() -> void:
		match _job():
			"guard":
				_job_guard()
			"build":
				_stand_at_base()
			"scavenge":
				_job_scavenge()
			"collect":
				_job_collect()
			"follow":
				_job_follow()
			"goto":
				_job_goto()
			"operate":
				# 操作设施：站在设施外围环带（中心距 2.6~3.2m）——旧逻辑走向距中心
				# 1.5m 的目标会把工人带进设施模型/碰撞体里（视觉消失、被卡死），
				# 太近时反向退出来，换任务后也靠这条自愈
				var opos = _worker().get("data", {}).get("pos", Vector3.ZERO)
				if opos == Vector3.ZERO:
					_stand_at_base()
				else:
					var flat := Vector2(
						global_position.x - opos.x, global_position.z - opos.z
					)
					var flen := flat.length()
					var dir := flat / flen if flen > 0.01 else Vector2(1, 0)
					if flen > 3.2 or flen < 2.6:
						_move_to(opos + Vector3(dir.x, 0.0, dir.y) * 2.9, SPEED)
					else:
						_stop()
			_:
				_stand_at_base()


	func _move_to(target: Vector3, speed := SPEED) -> void:
		_move_target = target
		_move_speed = speed
		_has_move = true


	func _stop() -> void:
		_has_move = false


	func _stand_at_base() -> void:
		var base := _base_pos()
		if global_position.distance_to(base) > 2.0:
			_move_to(base)
		else:
			_stop()


	func _job_guard() -> void:
		_stand_at_base()
		_try_shoot()


	func _job_follow() -> void:
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			_stand_at_base()
			return
		if player.get("vehicle") != null:
			# 玩家上车：工人就近待命
			_stop()
			return
		var dist := global_position.distance_to(player.global_position)
		if dist > FOLLOW_DIST + 0.3:
			_move_to(player.global_position, clampf(dist * 2.0, 2.0, 7.5))
		else:
			_stop()
		_try_shoot()


	func _job_goto() -> void:
		var target = _worker().get("data", {}).get("target", null)
		if not target is Vector3:
			_stand_at_base()
			return
		if global_position.distance_to(target) > 1.2:
			_move_to(target)
		else:
			# 到达后原地警戒
			_stop()
			_try_shoot()


	# —— 守护/跟随/警戒共用：射击 15m 内最近丧尸 ——

	func _try_shoot() -> void:
		if Time.get_ticks_msec() < _next_shot:
			return
		var zombie := GameState.nearest_entity_in_group(
			global_position, "zombies", SHOOT_RANGE
		) as Node3D
		if zombie == null:
			return
		_next_shot = Time.get_ticks_msec() + int(SHOOT_COOLDOWN * 1000.0)
		_face(zombie.global_position)
		var from := global_position + Vector3(0, 1.45, 0)
		var to := zombie.global_position + Vector3(0, 1.0, 0)
		_tracer(from, to)
		BlockyRig.play_once(_limbs, "holding-right-shoot")
		zombie.take_damage(SHOOT_DAMAGE)


	func _face(pos: Vector3) -> void:
		var d := pos - global_position
		if Vector2(d.x, d.z).length() > 0.05:
			rotation.y = atan2(-d.x, -d.z)


	# 曳光：一道短命的亮黄细梁
	func _tracer(from: Vector3, to: Vector3) -> void:
		var parent := get_parent()
		if parent == null:
			return
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, from.distance_to(to))
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.85, 0.35)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.8, 0.3)
		material.emission_energy_multiplier = 2.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		parent.add_child(mesh)
		mesh.global_position = (from + to) / 2.0
		mesh.look_at(to, Vector3.UP)
		var tween := mesh.create_tween()
		tween.tween_property(mesh, "scale:x", 0.05, 0.1)
		tween.parallel().tween_property(mesh, "scale:y", 0.05, 0.1)
		tween.tween_callback(mesh.queue_free)


	# —— 建造营地：每 60s 给据点仓库 +3 建材 ——

	func _build_produce() -> void:
		_build_timer = 0.0
		if GameState.add_materials_to_base(3) > 0:
			GameState.notify("%s 建造营地：建材 +3 入仓" % worker_name)


	# —— 出门寻找物资：走向地图边缘消失，3~5 分钟后回据点带回物资 ——

	func _job_scavenge() -> void:
		var w := _worker()
		if String(w.get("state", "home")) == "out":
			_stop()
			if Time.get_ticks_msec() >= int(w.get("data", {}).get("return_msec", 0)):
				_scavenge_return()
			return
		var edge := _map_edge_point()
		if global_position.distance_to(edge) < 2.5:
			_depart()
		else:
			_move_to(edge)


	func _map_edge_point() -> Vector3:
		var max_x := GameState.CITY_SIZE.x * GameState.WORLD_SCALE_3D
		var max_z := GameState.CITY_SIZE.y * GameState.WORLD_SCALE_3D
		var p := global_position
		var left := p.x
		var right := max_x - p.x
		var top := p.z
		var bottom := max_z - p.z
		var m := minf(minf(left, right), minf(top, bottom))
		if m == left:
			return Vector3(1.0, 0.3, p.z)
		if m == right:
			return Vector3(max_x - 1.0, 0.3, p.z)
		if m == top:
			return Vector3(p.x, 0.3, 1.0)
		return Vector3(p.x, 0.3, max_z - 1.0)


	func _depart() -> void:
		var w := _worker()
		w["state"] = "out"
		var data: Dictionary = w.get("data", {})
		data["return_msec"] = (
			Time.get_ticks_msec() + int(randf_range(SCAVENGE_MIN, SCAVENGE_MAX) * 1000.0)
		)
		w["data"] = data
		visible = false
		global_position = Vector3(0, -100, 0)
		if _collision != null:
			_collision.set_deferred("disabled", true)
		GameState.notify("%s 出门寻找物资去了" % worker_name)


	func _scavenge_return() -> void:
		GameState.worker_scavenge_return(worker_name)
		recall_to_base()


	# —— 收集掉落：捡 30m 内建材堆/掉落物（每次最多 20），背包装满才背回据点入仓，循环 ——

	func _carry_count() -> int:
		var n := 0
		for kind in _carry.keys():
			n += int(_carry[kind])
		return n


	func _carry_full() -> bool:
		return _carry_count() >= CARRY_CAPACITY


	func _job_collect() -> void:
		# 背包装满（或被手动命令运送）才回据点入仓；入仓后继续收集
		if (_carry_full() or _deliver_requested) and not _carry.is_empty():
			var base := _base_pos()
			if global_position.distance_to(base) < 2.5:
				_deposit_carry()
			else:
				_move_to(base)
			return
		if (
			_collect_target == null
			or not is_instance_valid(_collect_target)
			or _collect_target.is_queued_for_deletion()
		):
			_collect_target = _find_collectible()
		if _collect_target == null:
			# 附近捡完了但包里有货：先背回据点，避免压着物资发呆
			if not _carry.is_empty():
				_deliver_requested = true
				return
			_stand_at_base()
			return
		if global_position.distance_to(_collect_target.global_position) < 1.2:
			_pick_up(_collect_target)
			_collect_target = null
		else:
			_move_to(_collect_target.global_position)


	func _find_collectible() -> Node3D:
		var best: Node3D = null
		var best_d := COLLECT_RANGE
		for pile in get_tree().get_nodes_in_group("material_piles"):
			if pile.is_queued_for_deletion() or int(pile.get("amount")) <= 0:
				continue
			var d: float = global_position.distance_to(pile.global_position)
			if d < best_d:
				best_d = d
				best = pile
		for pickup in get_tree().get_nodes_in_group("pickups"):
			if pickup.is_queued_for_deletion():
				continue
			var d: float = global_position.distance_to(pickup.global_position)
			if d < best_d:
				best_d = d
				best = pickup
		return best


	func _pick_up(node: Node3D) -> void:
		if node.is_in_group("material_piles"):
			var take := mini(COLLECT_MAX, int(node.get("amount")))
			if take <= 0:
				return
			var left := int(node.get("amount")) - take
			if left <= 0:
				node.queue_free()
			elif node.has_method("setup"):
				node.setup(left)
			else:
				node.set("amount", left)
			_carry["materials"] = int(_carry.get("materials", 0)) + take
			return
		var kind := String(node.get("kind"))
		if kind == "cash":
			_carry["money"] = int(_carry.get("money", 0)) + int(node.get("cash_amount"))
		else:
			_carry[kind] = int(_carry.get(kind, 0)) + int(node.get("amount"))
		if Network.is_multiplayer():
			Network.unregister_entity(node)
		node.queue_free()


	func _deposit_carry() -> void:
		if not GameState.has_home_base():
			_carry.clear()
			return
		var storage: Dictionary = GameState.home_base["storage"]
		var parts: Array = []
		for kind in _carry.keys():
			storage[kind] = int(storage.get(kind, 0)) + int(_carry[kind])
			parts.append("%s ×%d" % [GameState._supply_name(String(kind)), int(_carry[kind])])
		_carry.clear()
		_deliver_requested = false
		GameState.home_base_changed.emit()
		GameState.notify("%s 把 %s 搬回了据点仓库" % [worker_name, "、".join(parts)])


	# —— 受伤与死亡 ——

	func take_damage(amount: int, _from: Node3D = null, friendly_fire := false) -> void:
		if _dying:
			return
		# 免疫玩家的直射（子弹/近战，操作员被打不到）；爆炸类（friendly_fire）无差别穿透
		if _from != null and _from.is_in_group("player") and not friendly_fire:
			return
		hp -= amount
		if hp <= 0:
			_killed_by_player = _from != null and _from.is_in_group("player")
			_die()


	func _die() -> void:
		if _dying:
			return
		_dying = true
		if _killed_by_player:
			GameState.civilian_kills += 1
		if manager != null and manager.has_method("_forget"):
			manager._forget(worker_name)
		GameState.remove_worker(worker_name)
		GameState.notify("%s 阵亡了" % worker_name)
		if _collision != null:
			_collision.set_deferred("disabled", true)
		if not BlockyRig.play_death(_limbs):
			queue_free()
			return
		set_physics_process(false)
		set_process(false)
		if _name_label != null:
			_name_label.visible = false
		var tween := get_tree().create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(1.5)
		tween.tween_callback(queue_free)


# 跟随者实体：招募市民而来，立即跟随玩家作战；可装备枪械/防弹衣/近战工具。
# 不占用营地工人名额也不消耗口粮；模式：follow 跟随 / goto_base 前往营地 / guard 守护营地 /
# stay 原地警戒 / scavenge 附近拾荒 / patrol 巡逻标点 / defend 防守标点
class FollowerBody extends CharacterBody3D:
	const GRAVITY := 18.0
	const SPEED := 4.6
	const DECIDE_INTERVAL := 0.2
	const INTERACT_REACH := 2.5
	const FOLLOW_DIST := 2.5
	const MELEE_RANGE := 2.2
	const FIST_DAMAGE := 10
	const FIST_COOLDOWN := 0.8
	const ARMOR_HP_BONUS := 40
	const SCAVENGE_RANGE := 25.0
	const SCAVENGE_TAKE_MAX := 20
	# 随身背包容量（各类物资合计）：拾荒装满才送回玩家，玩家也可手动命令立即运送
	const CARRY_CAPACITY := 40
	const PATROL_RADIUS := 8.0

	var follower_name := ""
	var manager: Node3D = null
	var mode := "follow"
	# 驾驶中的载具（委派驾驶员）：随车移动/隐藏，J 面板状态显示「驾驶中」
	var vehicle_ref: Node3D = null
	var task_point := Vector3.ZERO
	var max_hp := 60
	var hp := 60
	var equipped_weapon := ""
	var equipped_armor := false
	var equipped_melee := ""
	var melee_damage := 0
	# npcs 组兼容桩：丧尸/小地图/目击逻辑会对 npcs 组成员访问这些成员
	var role := "follower"
	# 批次 253：藏匿系统状态桩——没有这个属性时 enter_npc 的 set("sheltered") 静默失败，
	# npc_leave 守卫永远早退 → 随从进楼后永久隐形（"丢失模型"的根因）
	var sheltered := ""
	var _killed_by_player := false
	var net_puppet := false
	var _dying := false

	var _limbs := {}
	var _collision: CollisionShape3D = null
	var _name_label: Label3D = null
	var _hp_bar: Label3D = null
	var _decide := 0.0
	var _next_attack := 0
	var _move_target := Vector3.ZERO
	var _move_speed := SPEED
	var _has_move := false
	var _carry := {}
	# 手动运送请求（小队面板「立即运送」）：背包未满也先送回玩家
	var _deliver_requested := false
	var _collect_target: Node3D = null
	var _patrol_point := Vector3.ZERO
	var _patrol_moving := false
	var _patrol_wait := 0.0


	func _ready() -> void:
		add_to_group("npcs")
		add_to_group("followers")
		add_to_group("interactables")
		GameState.request_spatial_rebuild()
		collision_layer = 1
		collision_mask = 1
		_collision = CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		_collision.shape = capsule
		_collision.position = Vector3(0, 0.9, 0)
		add_child(_collision)
		_limbs = BlockyRig.build(self, null, {"model": BlockyRig.random_civilian()})
		_limbs["aiming"] = true
		_add_marker()
		_name_label = Label3D.new()
		_name_label.font_size = 48
		_name_label.modulate = Color(0.5, 0.9, 1.0)
		_name_label.outline_size = 8
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.position = Vector3(0, 2.15, 0)
		add_child(_name_label)
		_refresh_label()
		_hp_bar = Label3D.new()
		_hp_bar.font_size = 36
		_hp_bar.outline_size = 8
		_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hp_bar.position = Vector3(0, 2.55, 0)
		add_child(_hp_bar)
		_refresh_hp_bar()


	# 胸前身份徽标（贴身缩小版）：青色区别于工人（橙）与普通市民
	func _add_marker() -> void:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.2, 0.1, 0.04)
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.75, 0.9)
		material.emission_enabled = true
		material.emission = Color(0.1, 0.65, 0.85)
		material.emission_energy_multiplier = 1.5
		mesh.material_override = material
		mesh.position = Vector3(0, 1.28, -0.2)
		add_child(mesh)


	func _gear_name() -> String:
		var text := "徒手"
		if equipped_weapon != "" and GameState.WEAPONS.has(equipped_weapon):
			text = String(GameState.WEAPONS[equipped_weapon]["name"])
		elif equipped_melee != "":
			text = GameState.loot_name(equipped_melee)
		if equipped_armor:
			text += "·甲"
		return text


	func _refresh_label() -> void:
		if _name_label != null:
			_name_label.text = "%s（%s）（%s）" % [follower_name, mode_name(), _gear_name()]

	# 头顶血条：10 格方块，颜色随比例（>70% 绿 / >30% 黄 / 其余红）
	func _refresh_hp_bar() -> void:
		if _hp_bar == null:
			return
		var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
		var filled := int(round(ratio * 10.0))
		var text := ""
		for _i in 10:
			text += ("█" if _i < filled else "░")
		_hp_bar.text = text
		if ratio > 0.7:
			_hp_bar.modulate = Color(0.45, 0.95, 0.55)
		elif ratio > 0.3:
			_hp_bar.modulate = Color(0.95, 0.85, 0.35)
		else:
			_hp_bar.modulate = Color(1.0, 0.35, 0.3)


	func mode_name() -> String:
		match mode:
			"follow":
				return "跟随"
			"goto_base":
				return "去营地"
			"guard":
				return "守营地"
			"stay":
				return "警戒"
			"scavenge":
				return "拾荒"
			"patrol":
				return "巡逻"
			"defend":
				return "防守"
		return mode


	func can_see_node(_node: Node3D) -> bool:
		return false


	func show_alert() -> void:
		pass


	func witness_crime() -> void:
		pass


	func _base_pos() -> Vector3:
		if GameState.has_home_base():
			return GameState.home_base.get("position", global_position)
		return global_position


	func prompt_text() -> String:
		return ""


	# —— 统一交互菜单协议：给装备 / 去营地 / 留在营地 / 跟随我 / 解散 ——

	func interact_title() -> String:
		return "%s（%s）" % [follower_name, _gear_name()]


	func interact_options(player: Node3D) -> Array:
		if _dying or player == null:
			return []
		if global_position.distance_to(player.global_position) > INTERACT_REACH:
			return []
		var in_base := (
			GameState.has_home_base()
			and player.global_position.distance_to(_base_pos()) <= GameState.home_base_radius()
		)
		return [
			{"id": "gear", "label": "给装备"},
			{
				"id": "to_base",
				"label": "去营地",
				"disabled": not GameState.has_home_base(),
				"reason": "先占领一个据点",
			},
			{
				"id": "stay",
				"label": "留在营地",
				"disabled": not in_base,
				"reason": "需要站在据点半径内",
			},
			{
				"id": "follow",
				"label": "跟随我",
				"disabled": mode == "follow",
				"reason": "正在跟随",
			},
			{"id": "dismiss", "label": "解散"},
		]


	func interact_choose(id: String, player: Node3D) -> void:
		match id:
			"gear":
				if manager != null and manager.has_method("open_gear_panel"):
					manager.open_gear_panel(self)
			"to_base":
				if not GameState.has_home_base():
					return
				mode = "goto_base"
				GameState.notify("%s 前往营地" % follower_name)
			"stay":
				if player == null:
					return
				if (
					not GameState.has_home_base()
					or player.global_position.distance_to(_base_pos()) > GameState.home_base_radius()
				):
					return
				mode = "stay"
				_stop()
				GameState.notify("%s 留在原地警戒" % follower_name)
			"follow":
				mode = "follow"
				GameState.notify("%s 继续跟随你" % follower_name)
			"dismiss":
				_dismiss()


	func _physics_process(delta: float) -> void:
		if _dying:
			return
		_decide -= delta
		if _decide <= 0.0:
			_decide = DECIDE_INTERVAL
			_decide_mode()
			_refresh_label()
		velocity.y -= GRAVITY * delta
		if _has_move:
			var to := _move_target - global_position
			to.y = 0.0
			if to.length() < 0.4:
				_has_move = false
				velocity.x = 0.0
				velocity.z = 0.0
			else:
				var dir := to.normalized()
				velocity.x = dir.x * _move_speed
				velocity.z = dir.z * _move_speed
				rotation.y = atan2(-dir.x, -dir.z)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		move_and_slide()
		BlockyRig.update(_limbs, delta, Vector2(velocity.x, velocity.z).length())


	# —— 模式决策（每 0.2s 一次）——

	func _decide_mode() -> void:
		match mode:
			"follow":
				_mode_follow()
			"goto_base":
				_mode_goto_base()
			"guard":
				_stand_at_base()
				_try_attack()
			"stay":
				_stop()
				_try_attack()
			"scavenge":
				_mode_scavenge()
			"patrol":
				_mode_patrol()
			"defend":
				_mode_defend()
			"drive":
				_mode_drive()


	# 驾驶中：人已在车里——随车移动（不渲染），丧尸/小地图不可见
	func _mode_drive() -> void:
		_stop()
		velocity.x = 0.0
		velocity.z = 0.0
		if vehicle_ref != null and is_instance_valid(vehicle_ref):
			global_position = vehicle_ref.global_position + Vector3(0, 1.2, 0)


	func _move_to(target: Vector3, speed := SPEED) -> void:
		_move_target = target
		_move_speed = speed
		_has_move = true


	func _stop() -> void:
		_has_move = false


	func _stand_at_base() -> void:
		var base := _base_pos()
		if global_position.distance_to(base) > 2.0:
			_move_to(base)
		else:
			_stop()


	func _mode_follow() -> void:
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			_stop()
			return
		if player.get("vehicle") != null:
			# 玩家上车：跟随者就近待命
			_stop()
			return
		var dist := global_position.distance_to(player.global_position)
		if dist > FOLLOW_DIST + 0.3:
			_move_to(player.global_position, clampf(dist * 2.0, 2.0, 7.5))
		else:
			_stop()
		_try_attack()


	func _mode_goto_base() -> void:
		if not GameState.has_home_base():
			mode = "follow"
			return
		var base := _base_pos()
		if global_position.distance_to(base) > 2.0:
			_move_to(base)
		else:
			_stop()
			mode = "guard"
			GameState.notify("%s 到达营地，开始守护" % follower_name)
		_try_attack()


	# —— 拾荒：锚点 25m 内捡掉落物/建材堆，身上背满后送回给玩家，循环 ——

	func _carry_count() -> int:
		var n := 0
		for kind in _carry.keys():
			n += int(_carry[kind])
		return n


	func _carry_full() -> bool:
		return _carry_count() >= CARRY_CAPACITY


	func _mode_scavenge() -> void:
		# 批次 244：拾荒途中主动迎击周围丧尸（12m 内：徒手逼近/有枪原地射）
		var foe := _engage_foe()
		if foe != null:
			if equipped_weapon != "" and GameState.WEAPONS.has(equipped_weapon):
				_stop()
			else:
				_move_to(foe.global_position)
			_try_attack()
			return
		# 批次 243：背包满自动送回【营地仓库】；没有营地才送回玩家；交付后继续拾荒
		if (_carry_full() or _deliver_requested) and not _carry.is_empty():
			var target_pos := Vector3.ZERO
			var deliver_home := false
			if GameState.has_home_base():
				target_pos = _base_pos()
				deliver_home = true
			else:
				var player = get_tree().get_first_node_in_group("player")
				if player == null:
					_stop()
					return
				target_pos = player.global_position
			var dist := global_position.distance_to(target_pos)
			if dist < 2.0:
				_stop()
				_deliver_carry(deliver_home)
				_deliver_requested = false
			else:
				_move_to(target_pos, clampf(dist * 2.0, 2.0, 7.5))
			_try_attack()
			return
		if (
			_collect_target == null
			or not is_instance_valid(_collect_target)
			or _collect_target.is_queued_for_deletion()
		):
			_collect_target = _find_collectible()
		if _collect_target == null:
			# 附近捡完了但包里有货：先送回玩家，避免压着物资发呆
			if not _carry.is_empty():
				_deliver_requested = true
				return
			# 附近没有可捡物：回锚点附近待命
			if global_position.distance_to(task_point) > 3.0:
				_move_to(task_point)
			else:
				_stop()
			_try_attack()
			return
		if global_position.distance_to(_collect_target.global_position) < 1.2:
			_pick_up(_collect_target)
			_collect_target = null
		else:
			_move_to(_collect_target.global_position)
		_try_attack()


	# 只搜锚点 SCAVENGE_RANGE 半径内的掉落物/建材堆，返回离自己最近的一个
	func _find_collectible() -> Node3D:
		var best: Node3D = null
		var best_d := INF
		for pile in get_tree().get_nodes_in_group("material_piles"):
			if pile.is_queued_for_deletion() or int(pile.get("amount")) <= 0:
				continue
			if task_point.distance_to(pile.global_position) > SCAVENGE_RANGE:
				continue
			var d: float = global_position.distance_to(pile.global_position)
			if d < best_d:
				best_d = d
				best = pile
		for pickup in get_tree().get_nodes_in_group("pickups"):
			if pickup.is_queued_for_deletion():
				continue
			if task_point.distance_to(pickup.global_position) > SCAVENGE_RANGE:
				continue
			var d2: float = global_position.distance_to(pickup.global_position)
			if d2 < best_d:
				best_d = d2
				best = pickup
		return best


	func _pick_up(node: Node3D) -> void:
		if node.is_in_group("material_piles"):
			var take := mini(SCAVENGE_TAKE_MAX, int(node.get("amount")))
			if take <= 0:
				return
			var left := int(node.get("amount")) - take
			if left <= 0:
				node.queue_free()
			elif node.has_method("setup"):
				node.setup(left)
			else:
				node.set("amount", left)
			_carry["materials"] = int(_carry.get("materials", 0)) + take
			return
		var kind := String(node.get("kind"))
		if kind == "cash":
			_carry["money"] = int(_carry.get("money", 0)) + int(node.get("cash_amount"))
		else:
			_carry[kind] = int(_carry.get(kind, 0)) + int(node.get("amount"))
		if Network.is_multiplayer():
			Network.unregister_entity(node)
		node.queue_free()


	# 距玩家 2m 内交付：现金→钱包，药品/弹药/食物/建材→资源
	func _deliver_carry(to_base := false) -> void:
		var parts: Array = []
		var stored_base := false
		for kind in _carry.keys():
			var n := int(_carry[kind])
			if n <= 0:
				continue
			match String(kind):
				"money":
					GameState.add_money(n)
				_:
					if to_base and GameState.has_home_base():
						# 批次 243：满包自动回家——物资直接入营地仓库
						var storage: Dictionary = GameState.home_base["storage"]
						storage[String(kind)] = int(storage.get(String(kind), 0)) + n
						stored_base = true
					else:
						GameState.add_resource(String(kind), n)
			parts.append("%s ×%d" % [GameState._supply_name(String(kind)), n])
		_carry.clear()
		if stored_base:
			GameState.home_base_changed.emit()
		if not parts.is_empty():
			if stored_base:
				GameState.notify("%s 把 %s 存入了营地仓库" % [follower_name, "、".join(parts)])
			else:
				GameState.notify("%s 把 %s 交给了你" % [follower_name, "、".join(parts)])


	# —— 巡逻：绕 task_point 半径 8m 随机选点，走到后歇 1~2 秒再选下一个 ——

	func _mode_patrol() -> void:
		# 批次 244：巡逻中主动迎击周围丧尸（12m 内：徒手逼近/有枪原地射）
		var foe := _engage_foe()
		if foe != null:
			if equipped_weapon != "" and GameState.WEAPONS.has(equipped_weapon):
				_stop()
			else:
				_move_to(foe.global_position)
			_try_attack()
			return
		if _patrol_wait > 0.0:
			_patrol_wait -= DECIDE_INTERVAL
			_stop()
		elif _patrol_moving:
			if not _has_move or global_position.distance_to(_patrol_point) < 1.0:
				_stop()
				_patrol_moving = false
				_patrol_wait = randf_range(1.0, 2.0)
		else:
			var angle := randf() * TAU
			var radius := randf_range(2.0, PATROL_RADIUS)
			_patrol_point = task_point + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			_move_to(_patrol_point)
			_patrol_moving = true
		_try_attack()


	# —— 防守：走到 task_point 后原地驻守 ——

	func _mode_defend() -> void:
		if global_position.distance_to(task_point) > 1.5:
			_move_to(task_point)
		else:
			_stop()
		_try_attack()


	# —— 攻击：有枪按武器数据开火，否则用近战工具/拳头打近身丧尸 ——

	# 迎击侦测：12m 内最近的丧尸（拾荒/巡逻岗位的自动战斗，批次 244）
	const AGGRO_RANGE := 12.0

	func _engage_foe() -> Node3D:
		return GameState.nearest_entity_in_group(global_position, "zombies", AGGRO_RANGE) as Node3D

	func _try_attack() -> void:
		if Time.get_ticks_msec() < _next_attack:
			return
		if equipped_weapon != "" and GameState.WEAPONS.has(equipped_weapon):
			var w: Dictionary = GameState.WEAPONS[equipped_weapon]
			var zombie := GameState.nearest_entity_in_group(
				global_position, "zombies", float(w.get("range", 15.0))
			) as Node3D
			if zombie == null:
				return
			_next_attack = Time.get_ticks_msec() + int(float(w.get("cooldown", 0.8)) * 1000.0)
			_face(zombie.global_position)
			var from := global_position + Vector3(0, 1.45, 0)
			var to := zombie.global_position + Vector3(0, 1.0, 0)
			_tracer(from, to)
			BlockyRig.play_once(_limbs, "holding-right-shoot")
			zombie.take_damage(int(w.get("damage", 10)))
			return
		var damage := melee_damage if equipped_melee != "" else FIST_DAMAGE
		var cooldown := 0.45 if equipped_melee != "" else FIST_COOLDOWN
		var zombie := GameState.nearest_entity_in_group(
			global_position, "zombies", MELEE_RANGE
		) as Node3D
		if zombie == null:
			return
		_next_attack = Time.get_ticks_msec() + int(cooldown * 1000.0)
		_face(zombie.global_position)
		BlockyRig.play_once(_limbs, "attack-melee-right")
		zombie.take_damage(damage)


	func _face(pos: Vector3) -> void:
		var d := pos - global_position
		if Vector2(d.x, d.z).length() > 0.05:
			rotation.y = atan2(-d.x, -d.z)


	# 曳光：一道短命的亮黄细梁
	func _tracer(from: Vector3, to: Vector3) -> void:
		var parent := get_parent()
		if parent == null:
			return
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, from.distance_to(to))
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.85, 0.35)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.8, 0.3)
		material.emission_energy_multiplier = 2.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		parent.add_child(mesh)
		mesh.global_position = (from + to) / 2.0
		mesh.look_at(to, Vector3.UP)
		var tween := mesh.create_tween()
		tween.tween_property(mesh, "scale:x", 0.05, 0.1)
		tween.parallel().tween_property(mesh, "scale:y", 0.05, 0.1)
		tween.tween_callback(mesh.queue_free)


	# —— 装备：换下来的旧装备掉在脚边，不会凭空消失 ——

	func equip_weapon(id: String) -> void:
		if equipped_weapon != "":
			_spawn_weapon_drop(equipped_weapon)
		equipped_weapon = id
		_refresh_label()


	func equip_armor() -> void:
		if equipped_armor:
			_spawn_loot_drop("vest")
		else:
			equipped_armor = true
			max_hp += ARMOR_HP_BONUS
			hp += ARMOR_HP_BONUS
		_refresh_label()
		_refresh_hp_bar()


	func equip_melee(id: String, damage: int) -> void:
		if equipped_melee != "":
			_spawn_loot_drop(equipped_melee)
		equipped_melee = id
		melee_damage = damage
		_refresh_label()


	func _drop_all_gear() -> void:
		if equipped_weapon != "":
			_spawn_weapon_drop(equipped_weapon)
			equipped_weapon = ""
		if equipped_melee != "":
			_spawn_loot_drop(equipped_melee)
			equipped_melee = ""
			melee_damage = 0
		if equipped_armor:
			_spawn_loot_drop("vest")


	func _spawn_weapon_drop(id: String) -> void:
		var parent := get_parent()
		if parent == null:
			return
		var drop = load("res://scenes3d/weapon_drop3d.tscn").instantiate()
		drop.weapon_id = id
		drop.ammo = GameState.mag_size(id)
		parent.add_child(drop)
		drop.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6))


	func _spawn_loot_drop(id: String) -> void:
		var parent := get_parent()
		if parent == null:
			return
		var drop = load("res://scenes3d/loot_item3d.tscn").instantiate()
		drop.loot_id = id
		parent.add_child(drop)
		drop.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6))


	# —— 解散：变回普通市民，装备掉在原地 ——

	func _dismiss() -> void:
		if vehicle_ref != null and is_instance_valid(vehicle_ref) and vehicle_ref.has_method("_pilot_gone"):
			vehicle_ref.call("_pilot_gone")
		_drop_all_gear()
		var parent := get_parent()
		if parent != null:
			var npc = load("res://scenes3d/npc3d.tscn").instantiate()
			npc.role = "pedestrian"
			parent.add_child(npc)
			npc.global_position = global_position
		if manager != null and manager.has_method("_forget_follower"):
			manager._forget_follower(self)
		GameState.notify("%s 离开了队伍" % follower_name)
		queue_free()


	# —— 受伤与死亡 ——

	func take_damage(amount: int, _from: Node3D = null, friendly_fire := false) -> void:
		if _dying:
			return
		# 随从免疫玩家的子弹与近战（友军不伤）；爆炸类（friendly_fire）无差别
		if _from != null and _from.is_in_group("player") and not friendly_fire:
			return
		hp -= amount
		_refresh_hp_bar()
		if hp <= 0:
			_killed_by_player = _from != null and _from.is_in_group("player")
			_die()


	func _die() -> void:
		if _dying:
			return
		_dying = true
		if _killed_by_player:
			GameState.civilian_kills += 1
		_drop_all_gear()
		if manager != null and manager.has_method("_forget_follower"):
			manager._forget_follower(self)
		GameState.notify("%s 阵亡了" % follower_name)
		if _collision != null:
			_collision.set_deferred("disabled", true)
		if not BlockyRig.play_death(_limbs):
			queue_free()
			return
		set_physics_process(false)
		set_process(false)
		if _name_label != null:
			_name_label.visible = false
		var tween := get_tree().create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(1.5)
		tween.tween_callback(queue_free)
