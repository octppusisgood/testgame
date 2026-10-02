extends Node

var _failures := 0


func _ready() -> void:
	_test_state()
	_test_inventory()
	_test_survival()
	await _test_melee_3d()
	await _test_infection_3d()
	await _test_gunshot_witness()
	await _test_crisis()
	await _test_phone_messages()
	await _test_station_destroy_repair()
	_test_world_outbreak()
	await _test_echo_city_phase1()
	await _test_weather()
	_test_base_upgrades()
	await _test_base_signal_defense()
	await _test_material_transport()
	await _test_base_claim_rules()
	await _test_workers()
	await _test_followers()
	await _test_interact_menu()
	await _test_bullet_range()
	_test_scopes()
	if _failures == 0:
		print("TEST OK: 所有检查通过")
	else:
		print("TEST FAILED: %d 项失败" % _failures)
	get_tree().quit(_failures)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s" % label)


func _test_state() -> void:
	GameState.money = 100
	_check(GameState.spend_money(40), "spend_money 扣钱成功")
	_check(GameState.money == 60, "金钱变为 60")
	_check(not GameState.spend_money(999), "钱不够时购买失败")
	GameState.add_money(5)
	_check(GameState.money == 65, "add_money 加钱成功")


func _test_inventory() -> void:
	GameState.weapons = {"pistol": 1, "shotgun": 0, "rifle": 0}
	GameState.current_weapon = "pistol"
	GameState.add_weapon("shotgun")
	_check(GameState.weapons["shotgun"] == 1, "拾取武器进入物品栏")
	_check(GameState.current_weapon == "pistol", "已有武器时不会自动切换")
	GameState.select_weapon("shotgun")
	_check(GameState.current_weapon == "shotgun", "可以切换武器")
	_check(GameState.current_weapon_data()["name"] == "霰弹枪", "当前武器数据正确")
	GameState.select_weapon("rifle")
	_check(GameState.current_weapon == "shotgun", "没有的武器不能切换")
	GameState.resources["ammo"] = 0
	GameState.ammo_stock.clear()
	GameState.add_resource("ammo", 999)
	# 口径制：通用弹药均分到持有武器口径，单口径单弹种上限 9999
	_check(
		GameState.total_ammo() == 999 and int(GameState.resources["ammo"]) == 0,
		"弹药按口径入库（通用池清零）"
	)
	GameState.resources["food"] = 0
	GameState.add_resource("food", 999)
	_check(GameState.resources["food"] == GameState.CAPS["food"], "食物上限生效")


func _test_survival() -> void:
	GameState.stamina = 100.0
	GameState.use_stamina(30.0)
	_check(is_equal_approx(GameState.stamina, 70.0), "跑步消耗体力")
	GameState.regen_stamina(25.0)
	_check(is_equal_approx(GameState.stamina, 95.0), "体力会回复")
	GameState.resources["food"] = 0
	_check(not GameState.eat_food(), "没有食物不能进食")
	GameState.resources["food"] = 2
	GameState.satiety = 50.0
	GameState.eat_food()
	_check(
		is_equal_approx(GameState.satiety, 90.0) and GameState.resources["food"] == 1,
		"进食恢复饱食度并消耗食物"
	)


func _test_phone_messages() -> void:
	# 手机已删除：消息即时送达，带位置的消息直接在 M 地图标点
	GameState.news.clear()
	GameState.phase = "outbreak"
	GameState.round_elapsed = 0.0
	GameState.reset_coverage()
	GameState.post_message("目击报告", Vector2(100, 100), "gunfire")
	_check(GameState.knows("gunfire"), "消息即时送达（无信号延迟）")
	_check(GameState.read_markers().size() == 1, "带位置的消息立即在地图标点")
	GameState.post_message("无位置消息", Vector2.ZERO, "")
	_check(GameState.read_markers().size() == 1, "无位置消息不出现在地图")
	GameState.news.clear()
	GameState.phase = "prepare"


func _test_station_destroy_repair() -> void:
	GameState.phase = "prepare"
	GameState.round_elapsed = 0.0
	GameState.reset_coverage()
	var station := Node3D.new()
	station.set_script(load("res://scripts3d/station3d.gd"))
	station.data = {"name": "测试基站", "position": Vector2(2000, 2000)}
	station.position = Vector3(600, 0, 600)
	add_child(station)
	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	player.position = Vector3(601, 0, 600)
	add_child(player)
	player.set_physics_process(false)
	await get_tree().create_timer(0.5).timeout
	_check(GameState.in_coverage, "3D 基站覆盖范围内有信号")
	_check(
		station.interact_options(player).size() == 3,
		"靠近基站交互菜单提供修复/破坏/拆除选项"
	)

	station._player_sabotage()
	_check(station.destroyed, "破坏后基站进入损坏状态")
	_check(not GameState.in_coverage, "基站损坏后区域断信号")

	station._dispatch_timer = 0.05
	await get_tree().create_timer(0.3).timeout
	_check(station._engineer != null, "基站损坏后自动派出工程师")
	if station._engineer != null:
		var engineer = station._engineer
		engineer.global_position = station.global_position + Vector3(1.5, 0, 0)
		for i in 4:
			await get_tree().physics_frame
		_check(engineer.repairing, "工程师到达基站后开始维修")
		engineer._repair_total = 0.1
		engineer.repair_progress = 0.95
		await get_tree().create_timer(0.5).timeout
		_check(not station.destroyed, "维修完成后基站恢复")
		_check(station.hp == GameState.STATION_HP, "修复后基站血量回满")
		await get_tree().create_timer(0.5).timeout
		_check(GameState.in_coverage, "修复后信号恢复")

	for leftover in get_tree().get_nodes_in_group("npcs"):
		if leftover.role == "engineer" and not leftover.is_queued_for_deletion():
			leftover.queue_free()
	player.queue_free()
	station.queue_free()
	await get_tree().process_frame
	GameState.set_wanted(0)
	GameState.reset_coverage()


func _test_melee_3d() -> void:
	GameState.current_weapon = "melee"
	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	add_child(player)
	player.position = Vector3.ZERO
	var zombie = load("res://scenes3d/zombie3d.tscn").instantiate()
	add_child(zombie)
	zombie.position = Vector3(0, 0, -1.6)
	await get_tree().physics_frame
	player._melee(35)
	_check(zombie.hp == 25, "3D 近战命中正前方僵尸")
	player.queue_free()
	zombie.queue_free()
	await get_tree().process_frame
	GameState.current_weapon = "pistol"


func _test_infection_3d() -> void:
	# NPC 感染转尸设定已移除：被丧尸攻击只掉血、死亡，不再转成丧尸
	var civilian = load("res://scenes3d/npc3d.tscn").instantiate()
	civilian.role = "pedestrian"
	add_child(civilian)
	civilian.position = Vector3(900, 0, 900)
	var zombie_source = load("res://scenes3d/zombie3d.tscn").instantiate()
	add_child(zombie_source)
	var count_before := get_tree().get_nodes_in_group("zombies").size()
	civilian.take_damage(9999, zombie_source)
	_check(bool(civilian.get("_dying")), "被丧尸重击后直接死亡（不转尸）")
	var count_after := get_tree().get_nodes_in_group("zombies").size()
	_check(count_after == count_before, "死亡后不会原地变出丧尸")

	var zombie2 = load("res://scenes3d/zombie3d.tscn").instantiate()
	add_child(zombie2)
	zombie2.position = Vector3(0, 0, 0)
	var far_target = load("res://scenes3d/npc3d.tscn").instantiate()
	far_target.role = "pedestrian"
	add_child(far_target)
	far_target.position = Vector3(0, 0, -10)
	await get_tree().create_timer(0.1).timeout
	var near_target = load("res://scenes3d/npc3d.tscn").instantiate()
	near_target.role = "pedestrian"
	add_child(near_target)
	near_target.position = zombie2.global_position + Vector3(0, 0, -1.4)
	await get_tree().create_timer(0.6).timeout
	_check(zombie2._target == near_target, "僵尸会切换追更近的目标")

	GameState.phase = "prepare"
	GameState.outbreak_site = {}
	GameState.outbreak_sites = []
	for leftover in get_tree().get_nodes_in_group("zombies"):
		leftover.queue_free()
	for leftover in get_tree().get_nodes_in_group("npcs"):
		if not leftover.is_queued_for_deletion():
			leftover.queue_free()
	await get_tree().process_frame


func _test_gunshot_witness() -> void:
	GameState.set_wanted(0)
	GameState.phase = "prepare"
	GameState.signal_strength = 1.0
	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	add_child(player)
	player.position = Vector3.ZERO
	var npc = load("res://scenes3d/npc3d.tscn").instantiate()
	npc.role = "pedestrian"
	add_child(npc)
	npc.position = Vector3(6, 0, 0)
	npc.armed = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	GameState.report_gunshot(player.global_position, 25.0)
	await get_tree().create_timer(0.9).timeout
	_check(npc._shot_reported, "NPC 听到枪声后转头并目击指认")
	_check(npc._shot_watch_timer > 0.0, "NPC 注视枪声位置中")
	GameState.set_wanted(0)
	await get_tree().create_timer(1.2).timeout
	var heard_before: int = npc._heard_shot_msec
	GameState.report_gunshot(Vector3(500, 0, 500), 6.0)
	await get_tree().create_timer(0.8).timeout
	_check(npc._heard_shot_msec == heard_before, "消音级小枪声传不到远处 NPC")
	npc.queue_free()
	player.queue_free()
	await get_tree().process_frame
	GameState.set_wanted(0)
	GameState.signal_strength = 0.0


func _test_crisis() -> void:
	GameState.phase = "prepare"
	GameState.round_elapsed = 0.0
	GameState.time_left = 0.05
	GameState.outbreak_elapsed = 0.0
	await get_tree().create_timer(0.2).timeout
	_check(GameState.phase == "outbreak", "倒计时归零自动爆发")
	_check(not GameState.outbreak_site.is_empty(), "随机爆发点已选定")

	var radius0 := GameState.outbreak_radius()
	GameState.outbreak_elapsed = 10.0
	_check(GameState.outbreak_radius() > radius0, "传播半径随时间扩大")
	_check(GameState.expected_zombie_count() > 0, "已有僵尸生成配额")


func _reset_game_state() -> void:
	GameState.phase = "prepare"
	GameState.round_elapsed = 0.0
	GameState.time_left = GameState.PREPARE_MIN
	GameState.outbreak_elapsed = 0.0
	GameState.outbreak_site = {}
	GameState.outbreak_sites.clear()
	GameState._last_world_stage = -1
	GameState.day_number = 1
	GameState.day_elapsed = 0.0
	GameState.debug_time_scale = 1.0
	GameState.home_base = {}
	GameState.run_echoes.clear()
	GameState.echo_offer.clear()
	GameState.boss_sp_bonus = 0
	GameState.weapons = {"pistol": 1, "shotgun": 0, "rifle": 0}
	GameState.current_weapon = "pistol"
	GameState.stamina = GameState.MAX_STAMINA
	GameState.satiety = GameState.MAX_SATIETY
	GameState.news.clear()
	GameState.reset_coverage()


func _test_world_outbreak() -> void:
	GameState.phase = "outbreak"
	GameState.outbreak_elapsed = 0.0
	GameState.outbreak_site = {}
	GameState.outbreak_sites = []
	GameState._last_world_stage = 0
	_check(GameState.world_stage_index() == 0, "爆发开始为世界阶段 0")
	GameState.outbreak_elapsed = 700.0
	_check(GameState.world_stage_index() == 1, "爆发第 1 天进入阶段 1（蔓延）")
	GameState.outbreak_elapsed = 5800.0
	_check(GameState.world_stage_index() == 7, "爆发第 6 天进入阶段 7（天灾）")
	var stats: Dictionary = GameState.world_zombie_stats()
	_check(bool(stats.get("god", false)) and int(stats.get("boss_tier", 0)) == 10, "天灾阶段刷尸神")
	GameState.outbreak_elapsed = 0.0
	GameState._last_world_stage = 0
	GameState.custom_outbreak = false
	GameState.add_outbreak_site(
		{"name": "A", "position": Vector2(1000, 1000), "spread": 1.0}, 0.0
	)
	GameState.outbreak_elapsed = 1300.0
	GameState._update_world_stage()
	_check(GameState.outbreak_sites.size() == 2, "阶段 2 自动追加第二爆发点")
	_check(GameState.outbreak_site["name"] == "A", "首个爆发点保持兼容字段")

	GameState.phase = "survival"
	GameState.boss_sp_bonus = 0
	GameState.boss_killed(9)
	_check(GameState.boss_sp_bonus == 0, "击杀非尸神（tier 9）不加 SP 加成")
	GameState.boss_killed(10)
	_check(GameState.boss_sp_bonus >= GameState.BOSS_SP_BONUS, "击杀尸神获得结算 SP 加成")
	GameState.boss_sp_bonus = 0

	var runtime = load("res://scripts3d/custommap3d.gd")
	var custom := {
		"name": "__test_outbreak__", "width": 100.0, "depth": 100.0,
		"npc_count": 5, "outbreak": {"enabled": true, "intensity": 1.5},
		"buildings": [], "items": [],
	}
	var path: String = runtime.map_path_for("__test_outbreak__")
	_check(runtime.save_map_data(path, custom), "自定义图爆发配置保存")
	var loaded: Dictionary = runtime.load_map_data(path)
	_check(
		bool(loaded.get("outbreak", {}).get("enabled", false))
		and absf(float(loaded["outbreak"]["intensity"]) - 1.5) < 0.01,
		"自定义图爆发配置读取"
	)
	DirAccess.remove_absolute(path)

	GameState.phase = "prepare"
	GameState.outbreak_elapsed = 0.0
	GameState.outbreak_site = {}
	GameState.outbreak_sites = []
	GameState._last_world_stage = 0
	GameState.boss_sp_bonus = 0


var _heard_day := 0
var _echo_offer_seen := 0
var _heard_weather := ""
var _heard_moon := -1.0


func _on_day_changed(n: int) -> void:
	_heard_day = n


func _on_echo_offered(choices: Array) -> void:
	_echo_offer_seen = choices.size()


func _on_weather_changed(w: String, moon: float) -> void:
	_heard_weather = w
	_heard_moon = moon


func _test_weather() -> void:
	# —— 基础查询 ——
	GameState.weather = "clear"
	GameState.moon_phase = 1.0
	_check(not GameState.is_raining(), "晴天 is_raining 为假")
	_check(is_equal_approx(GameState.day_brightness(), 1.0), "晴天白天亮度 1.0")
	GameState.weather = "cloudy"
	_check(is_equal_approx(GameState.day_brightness(), 0.75), "阴天白天亮度 0.75")
	GameState.weather = "rain"
	_check(GameState.is_raining(), "雨天 is_raining 为真")
	_check(is_equal_approx(GameState.day_brightness(), 0.5), "雨天白天亮度 0.5")

	GameState.moon_phase = 0.8
	GameState.weather = "clear"
	var clear_night := GameState.night_brightness()
	GameState.weather = "rain"
	var rain_night := GameState.night_brightness()
	_check(rain_night < clear_night, "雨夜环境亮度低于晴夜（%.2f < %.2f）" % [rain_night, clear_night])
	_check(is_equal_approx(rain_night, 0.8 * 0.3), "雨夜亮度 = 月相 × 0.3")

	# —— 黎明换天气并广播 ——
	_heard_weather = ""
	_heard_moon = -1.0
	GameState.weather_changed.connect(_on_weather_changed)
	GameState.phase = "outbreak"
	GameState.day_number = 1
	GameState.day_elapsed = GameState.DAY_LENGTH - 0.05
	await get_tree().create_timer(0.3).timeout
	GameState.weather_changed.disconnect(_on_weather_changed)
	_check(
		_heard_weather in ["clear", "cloudy", "rain"],
		"黎明广播 weather_changed（%s）" % _heard_weather
	)
	_check(GameState.weather == _heard_weather, "黎明后天气已更新")
	_check(_heard_moon >= 0.2 and _heard_moon <= 1.0, "黎明重roll月相 0.2~1.0（%.2f）" % _heard_moon)
	_check(is_equal_approx(GameState.moon_phase, _heard_moon), "月相与广播一致")

	# —— 手电筒物品 ——
	_check(GameState.LOOT_ITEMS.has("flashlight"), "LOOT_ITEMS 里有手电筒")
	_check(String(GameState.LOOT_ITEMS["flashlight"].get("cat", "")) == "tool", "手电筒分类为 tool")

	# —— reset_run 重置天气 ——
	GameState.weather = "rain"
	GameState.moon_phase = 0.2
	GameState.reset_run()
	_check(
		GameState.weather == "clear" and is_equal_approx(GameState.moon_phase, 1.0),
		"reset_run 重置为晴天满月"
	)
	_check(not GameState.is_raining(), "reset_run 后不在下雨")
	GameState.phase = "prepare"
	GameState.day_number = 1
	GameState.day_elapsed = 0.0


func _test_echo_city_phase1() -> void:
	# —— 时间系统 ——
	GameState.debug_time_scale = 1.0
	GameState.early_entry = 0
	GameState.reset_run()
	_check(
		is_equal_approx(GameState.time_left, 300.0),
		"默认准备期为 5 分钟"
	)
	GameState.early_entry = 10
	GameState.reset_run()
	_check(
		is_equal_approx(GameState.time_left, GameState.PREPARE_MIN + 10 * 60.0),
		"提前入场按分钟拉长准备期"
	)
	GameState.early_entry = 0

	_heard_day = 0
	GameState.day_changed.connect(_on_day_changed)
	GameState.phase = "outbreak"
	GameState.day_number = 1
	GameState.day_elapsed = GameState.DAY_LENGTH - 0.05
	await get_tree().create_timer(0.3).timeout
	GameState.day_changed.disconnect(_on_day_changed)
	_check(GameState.day_number == 2 and _heard_day == 2, "跨天推进并发 day_changed 信号")
	_check(GameState.day_elapsed < 1.0, "跨天后日钟回到黎明")

	GameState.day_elapsed = 700.0
	_check(GameState.is_night(), "入夜后 is_night 为真")
	GameState.day_elapsed = 500.0
	_check(not GameState.is_night(), "白天 is_night 为假")

	GameState.day_number = 3
	GameState.day_elapsed = 700.0
	_check(GameState.sleep_skip_night(), "夜晚可以在据点睡觉跳过")
	_check(
		GameState.day_number == 4 and GameState.day_elapsed < 1.0,
		"睡醒直接到次日黎明"
	)
	GameState.day_elapsed = 100.0
	_check(not GameState.sleep_skip_night(), "白天不能睡觉")

	GameState.phase = "survival"
	GameState.day_number = GameState.FINAL_DAY
	GameState.day_elapsed = GameState.DAY_LENGTH - 0.05
	await get_tree().create_timer(0.3).timeout
	_check(GameState.is_run_over(), "第 7 天结束触发强制回归")

	GameState.phase = "prepare"
	GameState.time_left = 100.0
	GameState.debug_time_scale = 10.0
	await get_tree().create_timer(0.2).timeout
	GameState.debug_time_scale = 1.0
	_check(GameState.time_left < 99.0, "debug_time_scale 加速时间流逝")
	GameState.time_left = GameState.PREPARE_MIN

	# —— 据点系统 ——
	var old_stone := GameState.revival_stone
	GameState.revival_stone = false
	_check(not GameState.claim_home_base("house", Vector3(10, 0, 10)), "没有复活石不能占领据点")
	_check(not GameState.has_home_base(), "占领失败据点为空")
	GameState.revival_stone = true
	_check(GameState.claim_home_base("house", Vector3(10, 0, 10)), "持有复活石可占领据点")
	_check(GameState.has_home_base(), "占领据点后生效")
	GameState.resources["food"] = 10
	var stored := GameState.store_loot("food", 5)
	_check(stored == 5 and GameState.resources["food"] == 5, "存入据点从背包扣减")
	_check(int(GameState.home_base["storage"]["food"]) == 5, "据点储物增加")
	GameState.claim_home_base("warehouse", Vector3(20, 0, 20))
	_check(
		int(GameState.home_base["storage"]["food"]) == 5,
		"换据点时旧储物并入新点"
	)
	var cash := GameState.home_storage_cashout()
	_check(cash == 4, "据点储物按 40% 折现（5 食物 = 10 价值 = 4 SP）")
	_check(int(GameState.home_base["storage"]["food"]) == 0, "折现后储物清空")
	GameState.revival_stone = old_stone

	# —— SP 商店 ——
	var old_energy := GameState.space_energy
	var old_attrs: Dictionary = GameState.attrs.duplicate()
	var old_early := GameState.early_entry
	var old_early_buys := GameState.early_entry_buys
	_check(GameState.attr_cost(0) == 100, "属性升 1 级需 100 SP")
	_check(GameState.attr_cost(1) == 160, "属性升 2 级需 160 SP")
	GameState.attrs = {"vitality": 0, "agility": 0, "perception": 0, "will": 0, "luck": 0}
	GameState.space_energy = 1000
	_check(GameState.buy_attr("vitality"), "SP 足够时可以强化属性")
	_check(
		GameState.attr_level("vitality") == 1 and GameState.space_energy == 900,
		"强化扣 SP 且等级 +1"
	)
	GameState.early_entry = 0
	GameState.early_entry_buys = 0
	GameState.space_energy = 10000
	var cost1 := GameState.early_entry_cost()
	_check(cost1 == 10, "提前入场首购 10 SP")
	_check(
		GameState.buy_early_entry() and GameState.early_entry == 1,
		"首购提前入场 +1 分钟"
	)
	var cost2 := GameState.early_entry_cost()
	_check(cost2 > cost1, "提前入场连购价格递增")
	_check(
		GameState.buy_early_entry() and GameState.early_entry == 2,
		"再购提前入场到 +2 分钟"
	)
	GameState.space_energy = old_energy
	GameState.attrs = old_attrs
	GameState.early_entry = old_early
	GameState.early_entry_buys = old_early_buys

	# —— 回响系统 ——
	GameState.run_echoes.clear()
	GameState.echo_offer.clear()
	_echo_offer_seen = 0
	GameState.echo_offered.connect(_on_echo_offered)
	GameState.offer_echoes()
	GameState.echo_offered.disconnect(_on_echo_offered)
	_check(GameState.echo_offer.size() == 3, "回响三选一")
	_check(_echo_offer_seen == 3, "echo_offered 信号携带 3 个选项")
	var echo_id := String(GameState.echo_offer[0]["id"])
	_check(GameState.pick_echo(echo_id), "可以铭刻回响")
	_check(
		GameState.has_echo(echo_id) and GameState.run_echoes.has(echo_id),
		"回响进入本局生效列表"
	)
	_check(GameState.echo_offer.is_empty(), "选择后回响 Offer 关闭")
	GameState.reset_run()
	_check(
		GameState.run_echoes.is_empty() and not GameState.has_echo(echo_id),
		"reset_run 清空本局回响"
	)

	GameState.home_base = {}
	GameState.phase = "prepare"
	GameState.day_number = 1
	GameState.day_elapsed = 0.0
	GameState.debug_time_scale = 1.0
	GameState.time_left = GameState.PREPARE_MIN
	GameState.boss_sp_bonus = 0


func _test_base_upgrades() -> void:
	# —— 复活石购买与持久 ——
	var old_stone := GameState.revival_stone
	var old_energy := GameState.space_energy
	GameState.revival_stone = false
	GameState.space_energy = 300
	_check(not GameState.buy_revival_stone(), "SP 不足买不了复活石")
	GameState.space_energy = 1000
	_check(GameState.buy_revival_stone(), "复活石购买成功")
	_check(GameState.revival_stone and GameState.space_energy == 600, "复活石扣 400 SP")
	_check(not GameState.buy_revival_stone(), "复活石只能买一次")
	var file := FileAccess.open(GameState.META_PATH, FileAccess.READ)
	var meta_text := ""
	if file != null:
		meta_text = file.get_as_text()
		file.close()
	var meta = JSON.parse_string(meta_text)
	_check(meta is Dictionary and bool(meta.get("revival_stone", false)), "复活石写入 meta.json 持久保存")

	# —— 复活逻辑 ——
	GameState.home_base = {}
	_check(not GameState.can_respawn_at_base(), "无据点不能复活")
	# 批次 248：建筑据点半径按底座推导（专用探针覆盖）；此处用空地建点保持确定性 8m
	GameState.claim_home_base(GameState.OPEN_GROUND_BASE_ID, Vector3(50, 0, 50))
	_check(GameState.can_respawn_at_base(), "有据点有复活石可以复活")
	GameState.revival_stone = false
	_check(not GameState.can_respawn_at_base(), "无复活石不能复活")
	GameState.revival_stone = true

	var dummy := Node3D.new()
	add_child(dummy)
	dummy.global_position = Vector3(999, 0, 999)
	GameState.hp = 10
	GameState.money = 1000
	GameState.revive_count = 0
	GameState.respawn_at_base(dummy)
	_check(GameState.hp == int(GameState.max_hp() * 0.5), "复活后生命恢复 50%")
	_check(GameState.money == 900, "首次复活现金 -10%")
	_check(GameState.revive_count == 1, "复活计数 +1")
	_check(dummy.global_position.distance_to(Vector3(50, 0, 50)) < 5.0, "复活传送回据点")
	GameState.hp = 10
	GameState.respawn_at_base(dummy)
	_check(GameState.money == 720, "第二次复活现金 -20%（惩罚递增）")
	GameState.reset_run()
	_check(GameState.revive_count == 0, "reset_run 清空复活计数")
	dummy.queue_free()

	# —— 建材资源（新语义：玩家可徒手拾取建材随身携带，回据点存入仓库）——
	var old_test_mode := GameState.test_mode
	GameState.test_mode = false
	# 批次 248：建筑据点半径按底座推导（专用探针覆盖）；此处用空地建点保持确定性 8m
	GameState.claim_home_base(GameState.OPEN_GROUND_BASE_ID, Vector3(50, 0, 50))
	_check(GameState.materials_carriable(), "建材可随身携带")
	_check(GameState.base_storage_cap() == 150, "1 级据点仓库容量 150")
	_check(GameState.add_materials_to_base(50) == 50, "建材入仓 50")
	_check(GameState.base_materials() == 50, "仓库建材存量 50")
	_check(GameState.add_materials_to_base(999) == 100, "入仓受容量限制")
	_check(GameState.base_materials() == 150, "仓库装满到容量上限")
	_check(GameState.demolish_yield(Vector2(320, 220)) == 70, "拆除收益换算：320×220 → 70")
	_check(GameState.demolish_yield(Vector2(240, 180)) == 43, "拆除收益换算：240×180 → 43")
	_check(GameState.demolish_yield(Vector2(420, 220)) == 92, "拆除收益换算：420×220 → 92")

	# —— 仓库扩容 ——
	_check(GameState.upgrade_base_storage(), "仓库扩容成功")
	_check(GameState.base_materials() == 135, "扩容从仓库扣建材 ×15")
	_check(GameState.base_storage_cap() == 250, "扩容后容量 +100")
	GameState.home_base["storage"]["materials"] = 0

	# —— 据点升级 ——
	# 批次 248：建筑据点半径按底座推导（专用探针覆盖）；此处用空地建点保持确定性 8m
	GameState.claim_home_base(GameState.OPEN_GROUND_BASE_ID, Vector3(50, 0, 50))
	_check(GameState.home_base_level() == 1, "新据点默认 1 级")
	_check(is_equal_approx(GameState.home_base_radius(), 8.0), "新据点默认半径 8 米")
	_check(is_equal_approx(GameState.home_storage_rate(), 0.4), "1 级折现率 40%")
	_check(GameState.upgrade_base_cost() == 20, "升 2 级需建材 ×20")
	GameState.home_base["storage"]["materials"] = 10
	_check(not GameState.upgrade_home_base(), "仓库建材不够不能升级")
	GameState.home_base["storage"]["materials"] = 100
	_check(GameState.upgrade_home_base(), "升级据点成功")
	_check(
		GameState.base_materials() == 80 and GameState.home_base_level() == 2,
		"升级从仓库扣建材 ×20 且等级 +1"
	)
	_check(is_equal_approx(GameState.home_base_radius(), 10.0), "升级后半径 +2 米")
	_check(is_equal_approx(GameState.home_storage_rate(), 0.45), "2 级折现率 45%")
	GameState.home_base["level"] = GameState.BASE_MAX_LEVEL
	_check(not GameState.upgrade_home_base(), "满级后不能继续升级")
	_check(is_equal_approx(GameState.home_storage_rate(), 0.6), "满级折现率上限 60%")

	# —— 据点扩张 ——
	GameState.home_base["level"] = 1
	GameState.home_base["radius"] = 8.0
	GameState.home_base["storage"]["materials"] = 100
	_check(GameState.expand_home_base(), "扩大据点成功")
	_check(
		GameState.base_materials() == 90 and is_equal_approx(GameState.home_base_radius(), 10.0),
		"扩张从仓库扣建材 ×10 半径 +2"
	)
	GameState.home_base["radius"] = GameState.BASE_MAX_RADIUS
	_check(not GameState.expand_home_base(), "半径到上限后不能扩张")

	# —— 防御设施 ——
	GameState.home_base["radius"] = 8.0
	GameState.home_base["storage"]["materials"] = 100
	_check(GameState.base_defense_slots() == 3, "1 级据点 3 个防御槽位")
	_check(GameState.add_base_defense("barricade", Vector3(52, 0, 52)), "放置路障成功")
	_check(GameState.base_materials() == 92, "路障从仓库扣建材 ×8")
	_check(GameState.add_base_defense("turret", Vector3(48, 0, 52)), "放置炮塔成功")
	_check(GameState.base_materials() == 67, "炮塔从仓库扣建材 ×25")
	_check(GameState.add_base_defense("barricade", Vector3(50, 0, 48)), "第三个设施照常放置（不设上限）")
	_check(GameState.add_base_defense("barricade", Vector3(51, 0, 51)), "第四个设施也不受限（不设上限）")
	_check(not GameState.add_base_defense("barricade", Vector3(90, 0, 90)), "超出半径拒绝放置")

	# —— 发电机唯一性 ——
	GameState.home_base["defenses"] = []
	GameState.home_base["defense_levels"] = {}
	GameState.home_base["storage"]["materials"] = 100
	_check(GameState.add_base_defense("generator", Vector3(52, 0, 52)), "放置发电机成功")
	_check(GameState.add_base_defense("generator", Vector3(48, 0, 52)), "取消上限后发电机可重复建造（不设数量上限）")

	# —— 设施升级 ——
	GameState.home_base["defenses"] = []
	GameState.home_base["defense_levels"] = {}
	GameState.home_base["storage"]["materials"] = 100
	_check(GameState.add_base_defense("barricade", Vector3(52, 0, 52)), "放置待升级路障")
	_check(GameState.defense_upgrade_level(Vector3(52, 0, 52)) == 0, "新设施升级等级 0")
	_check(GameState.upgrade_base_defense(Vector3(52, 0, 52)), "设施升级成功")
	_check(
		GameState.defense_upgrade_level(Vector3(52, 0, 52)) == 1
		and GameState.base_materials() == 77,
		"升级后等级 +1 且从仓库扣建材 ×15"
	)
	_check(GameState.upgrade_base_defense(Vector3(52, 0, 52)), "设施升到 2 级")
	_check(not GameState.upgrade_base_defense(Vector3(52, 0, 52)), "满级设施不能继续升级")

	GameState.home_base["defenses"] = []
	GameState.home_base["defense_levels"] = {}
	GameState.home_base["storage"]["materials"] = 0
	_check(not GameState.add_base_defense("barricade", Vector3(52, 0, 52)), "仓库建材不够拒绝放置")
	GameState.test_mode = old_test_mode

	GameState.home_base = {}
	GameState.money = 200
	GameState.revive_count = 0
	GameState.revival_stone = old_stone
	GameState.space_energy = old_energy
	GameState.save_meta()


func _test_base_signal_defense() -> void:
	# —— 建造模式标志进出 ——
	var old_stone := GameState.revival_stone
	GameState.revival_stone = true
	# 批次 248：建筑据点半径按底座推导（专用探针覆盖）；此处用空地建点保持确定性 8m
	GameState.claim_home_base(GameState.OPEN_GROUND_BASE_ID, Vector3(50, 0, 50))
	_check(not GameState.base_build_mode, "默认不在建造模式")
	var build := Node3D.new()
	build.set_script(load("res://scripts3d/base_build3d.gd"))
	add_child(build)
	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	add_child(player)
	player.position = Vector3(50, 0, 50)
	await get_tree().physics_frame
	_check(build._can_enter(), "玩家在据点半径内可进入建造模式")
	build._open()
	_check(GameState.base_build_mode, "进入建造模式标志置真")
	_check(build.is_active(), "建造模式面板激活")
	build.force_close()
	_check(not GameState.base_build_mode, "退出建造模式标志复位")
	_check(not build.is_active(), "退出建造模式面板关闭")

	# —— 据点信号覆盖 ——
	GameState.reset_coverage()
	var visual := Node3D.new()
	visual.set_script(load("res://scripts3d/base_visual3d.gd"))
	add_child(visual)
	await get_tree().create_timer(0.5).timeout
	_check(GameState.signal_strength > 0.0, "据点旁信号强度大于 0")
	_check(GameState.in_coverage, "据点旁判定在信号覆盖区内")
	_check(GameState.base_signal_strength() > 0.0, "据点信号源登记在案")
	player.global_position = Vector3(50, 0, 50 + GameState.base_signal_radius() + 30.0)
	await get_tree().create_timer(0.5).timeout
	_check(GameState.signal_strength == 0.0, "远离据点超出信号半径后无信号")
	_check(GameState.base_signal_strength() == 0.0, "远离后据点信号源清除")
	GameState.home_base["level"] = 3
	_check(
		is_equal_approx(GameState.base_signal_radius(), 45.0),
		"3 级据点信号半径 45 米（15 + 10×3）"
	)
	GameState.home_base["level"] = 1

	# —— 防御设施 HP 与摧毁 ——
	GameState.home_base["storage"]["materials"] = 100
	_check(GameState.add_base_defense("barricade", Vector3(52, 0, 52)), "放置路障成功")
	_check(GameState.add_base_defense("turret", Vector3(48, 0, 52)), "放置炮塔成功")
	_check(GameState.base_defense_count() == 2, "防御设施登记 2 个")
	for entry in GameState.home_base["defenses"]:
		build._spawn_defense(String(entry["type"]), entry["pos"], 0.0)
	await get_tree().physics_frame
	_check(build._defense_nodes.size() == 2, "防御实体生成 2 个")
	var barricade: Node3D = build._defense_nodes[0]
	var turret: Node3D = build._defense_nodes[1]
	_check(barricade.hp == 200, "路障 HP 200")
	_check(turret.hp == 150, "炮塔 HP 150")
	_check(barricade.is_in_group("base_defense"), "路障在 base_defense 组")
	_check(turret.is_in_group("base_defense"), "炮塔在 base_defense 组")
	barricade.take_damage(120)
	_check(barricade.hp == 80, "路障受击掉血")
	barricade.take_damage(120)
	await get_tree().process_frame
	_check(GameState.base_defense_count() == 1, "路障被打爆后从据点移除")
	# 摧毁触发防御重建，剩余炮塔需重新取引用
	var turret2: Node3D = build._defense_nodes[0]
	_check(turret2.hp == 150, "重建后炮塔仍在且 HP 150")
	turret2.take_damage(999)
	await get_tree().process_frame
	_check(GameState.base_defense_count() == 0, "炮塔被打爆后从据点移除")

	# —— 夜袭丧尸直奔据点 ——
	var zombie = load("res://scenes3d/zombie3d.tscn").instantiate()
	add_child(zombie)
	zombie.global_position = Vector3(50, 0.3, 80)
	zombie.assault_target = Vector3(50, 0, 110)
	await get_tree().physics_frame
	var z_before: float = zombie.global_position.z
	for i in 10:
		await get_tree().physics_frame
	_check(zombie.global_position.z > z_before + 0.3, "袭击丧尸直奔目标点")
	zombie.assault_target = Vector3.ZERO
	zombie.queue_free()

	# —— 清理 ——
	GameState.home_base = {}
	GameState.base_build_mode = false
	GameState.reset_coverage()
	player.queue_free()
	visual.queue_free()
	build.queue_free()
	await get_tree().process_frame
	GameState.revival_stone = old_stone


func _test_material_transport() -> void:
	var old_test_mode := GameState.test_mode
	var old_stone := GameState.revival_stone
	var old_rects: Array = GameState.map_building_rects.duplicate()
	GameState.test_mode = false
	GameState.revival_stone = true

	# —— 拆小楼掉建材堆实体（库存制：每次拆卸 +10，不进背包）——
	var proto_script := GDScript.new()
	proto_script.source_code = "extends Node3D\nvar _building_parts := {}\nvar _street_props := []\n"
	proto_script.reload()
	var proto := Node3D.new()
	proto.set_script(proto_script)
	add_child(proto)
	var demo := Node3D.new()
	demo.set_script(load("res://scripts3d/demolish3d.gd"))
	proto.add_child(demo)
	var bindex := -1
	for i in GameState.BUILDING_LAYOUT.size():
		var entry: Dictionary = GameState.BUILDING_LAYOUT[i]
		if GameState.demolished_buildings.has(entry["position"]):
			continue
		if GameState.demolish_is_big(entry["size"], 1):
			continue
		bindex = i
		break
	_check(bindex >= 0, "找到可拆除的小楼")
	var pos_px: Vector2 = GameState.BUILDING_LAYOUT[bindex]["position"]
	var gain: int = GameState.BUILDING_MATERIAL_PER_DEMOLISH
	# 批次 251：挖取建材直接入背包（不再落地成堆）
	var mats_before := int(GameState.resources.get("materials", 0))
	demo._mine_building(bindex)
	await get_tree().process_frame
	_check(
		int(GameState.resources.get("materials", 0)) == mats_before + gain,
		"拆小楼建材直接入背包（+%d）" % gain
	)
	_check(
		get_tree().get_nodes_in_group("material_piles").is_empty(),
		"挖取不在地面生成建材堆"
	)

	# —— 车辆装载：2.5m 内自动入车斗（手动生成堆供测试） ——
	var pile: Node3D = load("res://scenes3d/material_pile3d.tscn").instantiate()
	add_child(pile)
	pile.global_position = Vector3(600.0, 0.05, 600.0)
	pile.setup(gain)
	var vehicle = load("res://scenes3d/vehicle3d.tscn").instantiate()
	add_child(vehicle)
	vehicle.model = "van"
	vehicle.global_position = pile.global_position + Vector3(1.0, 0, 0)
	for i in 6:
		await get_tree().physics_frame
	_check(vehicle.cargo == gain, "建材堆 2.5m 内自动装入车斗")
	_check(not is_instance_valid(pile) or pile.is_queued_for_deletion(), "装完后建材堆消失")

	# —— 装载不超容量 ——
	var cap: int = vehicle.cargo_cap()
	_check(cap == 120, "面包车斗容量 120")
	vehicle.cargo = cap - 3
	var pile2 = load("res://scenes3d/material_pile3d.tscn").instantiate()
	add_child(pile2)
	pile2.global_position = vehicle.global_position + Vector3(1.0, 0, 0)
	pile2.setup(10)
	for i in 6:
		await get_tree().physics_frame
	_check(vehicle.cargo == cap, "装载不超过车斗容量上限")

	# —— U 卸货：据点半径内入仓库 ——
	GameState.claim_home_base("house", Vector3(500, 0, 500))
	GameState.home_base["storage"]["materials"] = 0
	vehicle.cargo = 20
	vehicle.global_position = Vector3(500, 0, 502)
	vehicle._unload_cargo()
	_check(vehicle.cargo == 0, "据点内 U 卸货清空车斗")
	_check(GameState.base_materials() == 20, "卸货进入据点仓库")

	# —— U 卸货：远离据点在车尾落堆 ——
	vehicle.cargo = 15
	vehicle.global_position = Vector3(500, 0, 600)
	var piles_before := get_tree().get_nodes_in_group("material_piles").size()
	vehicle._unload_cargo()
	await get_tree().process_frame
	_check(vehicle.cargo == 0, "野外 U 卸货清空车斗")
	var piles_now := get_tree().get_nodes_in_group("material_piles")
	_check(piles_now.size() == piles_before + 1, "车尾落下建材堆")
	_check(piles_now.back().amount == 15, "落下的建材堆数量正确")

	# —— 载具油耗：怠速+车速比例消耗，油尽为止 ——
	vehicle.model = "van"
	_check(is_equal_approx(vehicle.tank_cap(), 70.0), "面包车油箱 70 升")
	vehicle.fuel = 10.0
	vehicle._speed = vehicle.max_speed
	vehicle.consume_fuel(10.0)
	_check(
		vehicle.fuel < 10.0 - 2.0 and vehicle.fuel > 10.0 - 3.0,
		"全速行驶 10 秒耗油约 2.5 升（%.2f）" % vehicle.fuel
	)
	vehicle.fuel = 0.05
	vehicle.consume_fuel(10.0)
	_check(vehicle.fuel == 0.0, "油耗不会扣成负数")
	var added: float = vehicle.refuel(999.0)
	_check(
		is_equal_approx(added, vehicle.tank_cap()) and is_equal_approx(vehicle.fuel, vehicle.tank_cap()),
		"加油不超过油箱上限"
	)

	# —— 三类燃料：车型决定燃料类型与油价 ——
	vehicle.model = "van"
	_check(vehicle.fuel_type() == "diesel" and vehicle.fuel_type_name() == "柴油", "面包车烧柴油")
	_check(vehicle.fuel_price() == 2, "柴油 ¥2/升")
	vehicle.model = "taxi"
	_check(vehicle.fuel_type() == "lpg" and vehicle.fuel_price() == 4, "出租车烧燃气 ¥4/升")
	vehicle.model = "sedan"
	_check(vehicle.fuel_type() == "petrol" and vehicle.fuel_price() == 3, "轿车烧汽油 ¥3/升")
	vehicle.model = "van"

	# —— 油泵交互：花钱给最近的载具加油 ——
	var pump = load("res://scripts3d/gas_pump3d.gd").new()
	add_child(pump)
	pump.global_position = vehicle.global_position + Vector3(2.0, 0, 0)
	var fake_player := Node3D.new()
	add_child(fake_player)
	fake_player.global_position = pump.global_position + Vector3(1.0, 0, 0)
	vehicle.fuel = 0.0
	var old_money := GameState.money
	GameState.money = 100
	var opts: Array = pump.interact_options(fake_player)
	_check(opts.size() == 3, "油泵给出加满/加 20 升/灌装三个选项")
	_check(bool(opts[0].get("disabled", false)), "现金不够时加满选项禁用")
	_check(not bool(opts[1].get("disabled", true)), "加 20 升柴油（¥40）付得起")
	pump.interact_choose("add", fake_player)
	_check(
		is_equal_approx(vehicle.fuel, 20.0) and GameState.money == 60,
		"加 20 升柴油扣 ¥40（油量 %.0f，现金 %d）" % [vehicle.fuel, GameState.money]
	)
	pump.interact_choose("fill", fake_player)
	_check(is_equal_approx(vehicle.fuel, 20.0), "现金不够时加满失败")
	vehicle.global_position += Vector3(500, 0, 0)
	var opts2: Array = pump.interact_options(fake_player)
	_check(opts2.size() == 2 and String(opts2[0]["id"]) == "none", "附近没车油泵只剩灌装")
	vehicle.global_position -= Vector3(500, 0, 0)
	GameState.money = old_money
	pump.queue_free()
	fake_player.queue_free()

	# —— 异能量：击杀积累 / 应急治疗 / 结算折算 ——
	var old_anomaly := GameState.anomaly
	GameState.anomaly = 0
	GameState.note_zombie_slain()
	_check(GameState.anomaly == 1, "击杀一只丧尸异能量 +1")
	GameState.anomaly = GameState.ANOMALY_HEAL_COST
	var old_meds := int(GameState.resources.get("meds", 0))
	GameState.resources["meds"] = 0
	var old_hp := GameState.hp
	GameState.hp = 50
	var maxhp := GameState.max_hp()
	_check(GameState.use_medkit(), "没有医疗包时异能量应急治疗")
	_check(
		GameState.hp == 50 + int(maxhp * 0.4) and GameState.anomaly == 0,
		"应急治疗回 40%% 生命并扣 15 异能量"
	)
	GameState.anomaly = 5
	GameState.hp = 50
	_check(not GameState.use_medkit(), "异能量不足 15 应急治疗失败")
	GameState.anomaly = 7
	GameState.day_number = 1
	GameState.boss_sp_bonus = 0
	GameState.home_base = {}
	var sp_before := GameState.space_energy
	GameState.settle_run(false)
	_check(
		GameState.space_energy == sp_before + 7,
		"败北结算异能量 1:1 折算 SP（+%d）" % (GameState.space_energy - sp_before)
	)
	GameState.anomaly = old_anomaly
	GameState.resources["meds"] = old_meds
	GameState.hp = old_hp
	GameState.hp_changed.emit(GameState.hp)

	# —— 燃料：汽油桶拾取 +20 升，背包上限 60 ——
	var old_fuel := int(GameState.resources.get("fuel", 0))
	GameState.resources["fuel"] = 0
	var can = load("res://scenes3d/pickup3d.tscn").instantiate()
	can.kind = "fuel"
	can.amount = 20
	can.item_name = "汽油桶"
	add_child(can)
	var looter := CharacterBody3D.new()
	add_child(looter)
	looter.add_to_group("player")
	can.apply_effect()
	_check(
		int(GameState.resources.get("fuel", 0)) == 20 and can.is_queued_for_deletion(),
		"汽油桶拾取 +20 升"
	)
	looter.remove_from_group("player")
	looter.queue_free()
	GameState.add_resource("fuel", 999)
	_check(int(GameState.resources.get("fuel", 0)) == 60, "背包燃料上限 60 升（3 桶）")

	# —— 燃料周转：抽油 / 用携带燃料加油 / 油泵灌装 / 入仓库 ——
	GameState.resources["fuel"] = 0
	vehicle.fuel = 30.0
	vehicle.interact_choose("siphon", null)
	_check(
		is_equal_approx(vehicle.fuel, 0.0) and int(GameState.resources.get("fuel", 0)) == 30,
		"从车上抽出 30 升"
	)
	vehicle.interact_choose("pour", null)
	_check(
		is_equal_approx(vehicle.fuel, 30.0) and int(GameState.resources.get("fuel", 0)) == 0,
		"携带燃料加回车上"
	)
	GameState.money = 200
	pump = load("res://scripts3d/gas_pump3d.gd").new()
	add_child(pump)
	pump.interact_choose("can", null)
	_check(
		int(GameState.resources.get("fuel", 0)) == 60 and GameState.money == 20,
		"油泵灌装背包 60 升扣 ¥180（现金 %d）" % GameState.money
	)
	GameState.money = old_money
	pump.queue_free()
	GameState.claim_home_base("house", Vector3(500, 0, 500))
	GameState.home_base["storage"]["fuel"] = 0
	var stored_fuel := GameState.store_loot("fuel", 40)
	_check(
		stored_fuel == 40 and int(GameState.home_base["storage"].get("fuel", 0)) == 40,
		"燃料存入据点仓库 40 升"
	)

	# —— 发电机：烧仓库燃料发电（玩家不再回电，电力仅供据点设备）——
	GameState.home_base["defenses"] = [{"type": "generator", "pos": Vector3(500, 0, 500)}]
	_check(GameState.base_has_generator(), "据点登记发电机")
	_check(GameState.generator_running(), "仓库有燃料发电机运转")
	GameState._gen_burn = 0.0
	GameState._gen_stall_notified = false
	var old_viewer := GameState.viewer_active
	GameState.viewer_active = true
	GameState.viewer_position = Vector3(500, 0, 500)
	GameState._tick_generator(61.0)
	_check(
		int(GameState.home_base["storage"].get("fuel", 0)) == 39,
		"发电机 60 秒烧 1 升（剩余 %d）" % int(GameState.home_base["storage"].get("fuel", 0))
	)
	GameState.home_base["storage"]["fuel"] = 0
	GameState._tick_generator(1.0)
	_check(not GameState.generator_running(), "燃料耗尽发电机停机")
	GameState.home_base["defenses"] = []
	GameState.viewer_active = old_viewer
	GameState.resources["fuel"] = old_fuel

	# —— 城市电网：准备期与头两天有电，第 3 天断电，修复发电厂恢复 ——
	var old_phase := GameState.phase
	var old_day := GameState.day_number
	var old_repaired := GameState.grid_repaired
	GameState.phase = "prepare"
	_check(GameState.grid_online(), "准备期电网在线")
	GameState.phase = "survival"
	GameState.day_number = 2
	_check(GameState.grid_online(), "灾变第 2 天电网仍在线")
	GameState.day_number = 3
	_check(not GameState.grid_online(), "第 3 天发电站停运断电")
	GameState.claim_home_base("house", Vector3(500, 0, 500))
	GameState.home_base["storage"]["materials"] = 100
	_check(GameState.repair_power_plant(), "建材足够修复发电厂成功")
	_check(
		int(GameState.home_base["storage"]["materials"]) == 40,
		"修复扣建材 ×60（剩余 %d）" % int(GameState.home_base["storage"]["materials"])
	)
	_check(GameState.grid_online(), "修复后电网恢复")
	GameState.grid_repaired = false
	GameState.day_number = 2
	_check(not GameState.repair_power_plant(), "电网在线时不能修复")
	GameState.phase = old_phase
	GameState.day_number = old_day
	GameState.grid_repaired = old_repaired

	# —— 据点电力（批次 249：无储备池，即发即用——发电≥用电设备才运转）——
	GameState.claim_home_base(GameState.OPEN_GROUND_BASE_ID, Vector3(500, 0, 500))
	GameState.home_base["defenses"] = []
	_check(not GameState.BASE_DEFENSES.has("battery"), "蓄电池已从建造表移除")
	# 电网在线：市电兜底，发电速率 ≥ 用电速率，设备放行
	GameState.phase = "prepare"
	_check(GameState.grid_online(), "准备期电网在线")
	_check(GameState.power_gen_rate() >= GameState.power_use_rate(), "市电期发电覆盖用电")
	_check(GameState.drain_base_power(0.5) == 0.5, "市电期用电请求放行")
	# 电网停运 + 无发电：用电请求被拒（缺电）
	GameState.phase = "survival"
	GameState.day_number = 3
	GameState.grid_repaired = false
	GameState.home_base["defenses"] = [{"type": "turret", "pos": Vector3(500, 0, 500)}]
	_check(GameState.power_gen_rate() < GameState.power_use_rate(), "断电无发电时发电<用电")
	_check(GameState.drain_base_power(0.5) == 0.0, "缺电时用电请求返回 0")
	_check(not GameState.base_devices_powered(), "断电且无发电设备断电")
	# 发电机运转：50kW 覆盖用电，设备放行
	GameState.home_base["defenses"] = [
		{"type": "generator", "pos": Vector3(500, 0, 500)},
		{"type": "turret", "pos": Vector3(501, 0, 500)},
	]
	GameState.home_base["storage"]["fuel"] = 60
	_check(GameState.power_gen_rate() >= GameState.power_use_rate(), "发电机 50kW 覆盖用电")
	_check(GameState.drain_base_power(0.5) == 0.5, "有发电时用电请求放行")
	_check(GameState.base_devices_powered(), "有发电设备有电")
	GameState.home_base["storage"]["fuel"] = 0
	_check(GameState.power_gen_rate() < GameState.power_use_rate(), "燃料耗尽发电归零")
	GameState.home_base["defenses"] = []
	GameState.home_base["power"] = 0.0

	# —— 能源标记（玩家不再用电）——
	_check(GameState.energy_tag_text("generator") == "［燃料+电］", "发电机标记燃料+电")
	_check(GameState.energy_tag_text("flashlight") == "", "手电筒不再标记电")
	_check(GameState.energy_tag_text("bread") == "", "面包无能源标记")

	# —— 异能结晶：道具化拾取（已无结晶感染设定），吸收 +5 ——
	GameState.anomaly = 0
	for leftover in GameState.loot_items.duplicate():
		if String(leftover["id"]) == "anomaly_crystal":
			GameState.loot_items.erase(leftover)
	var crystal = load("res://scenes3d/pickup3d.tscn").instantiate()
	crystal.kind = "anomaly"
	crystal.amount = 1
	crystal.item_name = "异能结晶"
	add_child(crystal)
	var looter2 := CharacterBody3D.new()
	add_child(looter2)
	looter2.add_to_group("player")
	crystal.apply_effect()
	_check(
		GameState.loot_count("anomaly_crystal") == 1 and crystal.is_queued_for_deletion(),
		"异能结晶拾取进入背包"
	)
	_check(GameState.anomaly == 0, "未吸收的结晶不加异能量")
	_check(GameState.use_loot("anomaly_crystal"), "吸收异能结晶")
	_check(GameState.anomaly == 5, "吸收结晶异能量 +5（%d）" % GameState.anomaly)
	looter2.remove_from_group("player")
	looter2.queue_free()
	GameState.add_anomaly(999)
	_check(GameState.anomaly == GameState.ANOMALY_MAX, "异能量上限 100")
	GameState.anomaly = old_anomaly

	# —— 异能储存仓：据点设施登记 ——
	_check(not GameState.base_has_containment(), "初始没有储存仓")
	GameState.home_base["defenses"] = [{"type": "containment", "pos": Vector3(500, 0, 500)}]
	_check(GameState.base_has_containment(), "建造后登记储存仓")
	GameState.home_base["defenses"] = []

	# —— 异能量场：市民在场内不再被感染（感染设定已移除） ——
	GameState.phase = "survival"
	var zone = load("res://scripts3d/anomaly_zone3d.gd").new()
	add_child(zone)
	zone.global_position = Vector3(0, 0, 0)
	var civ = load("res://scenes3d/npc3d.tscn").instantiate()
	civ.role = "pedestrian"
	add_child(civ)
	civ.global_position = Vector3(1.0, 0.1, 0)
	await get_tree().create_timer(0.4).timeout
	zone._tick_effects()
	_check(civ.get("_infected") == null, "异能量场不再感染市民")
	civ.queue_free()
	zone.queue_free()

	# —— 结晶掉落：受异能影响必掉，越强大掉越多 ——
	var zb = load("res://scenes3d/zombie3d.tscn").instantiate()
	add_child(zb)
	zb.zombie_tier = 0
	_check(zb._crystal_drop_count() == 0, "普通丧尸不掉结晶")
	zb.set_meta("anomaly_touched", true)
	_check(zb._crystal_drop_count() == 1, "受异能影响的丧尸必掉 1 颗")
	zb.zombie_tier = 3
	_check(zb._crystal_drop_count() == 2, "精英 tier 3 掉 2 颗")
	zb.zombie_tier = 10
	_check(zb._crystal_drop_count() == 6, "尸神掉 6 颗")
	zb.queue_free()

	# —— 异能量场巢穴：持续刷怪 / 能量等级加成 / 核心摧毁掉结晶 ——
	GameState.viewer_active = true
	GameState.viewer_position = Vector3(50, 0, 0)
	GameState.phase = "survival"
	var zone2 = load("res://scripts3d/anomaly_zone3d.gd").new()
	zone2.zone_id = 90
	zone2.energy = 1
	add_child(zone2)
	zone2.global_position = Vector3(50, 0, 0)
	zone2._spawn_timer = 0.0
	var z_before := get_tree().get_nodes_in_group("zombies").size()
	zone2._tick_spawner()
	_check(
		get_tree().get_nodes_in_group("zombies").size() == z_before + 1,
		"异能量场刷出一只丧尸"
	)
	_check(not zone2.destroyed, "能量场刷怪后不会自动消失")
	var zone_lv3 = load("res://scripts3d/anomaly_zone3d.gd").new()
	zone_lv3.energy = 3
	add_child(zone_lv3)
	_check(
		is_equal_approx(zone_lv3._spawn_interval(), 10.0 / 3.0),
		"3 级能量场刷怪间隔缩短到 1/3"
	)
	_check(zone_lv3._alive_cap() == 5 and zone2._alive_cap() == 3, "能量越高场内同时存活的怪越多")
	zone_lv3.queue_free()
	var zone3 = load("res://scripts3d/anomaly_zone3d.gd").new()
	zone3.zone_id = 91
	zone3.energy = 1
	add_child(zone3)
	zone3.global_position = Vector3(60, 0, 0)
	zone3.hp = 10
	var pickups_before := get_tree().get_nodes_in_group("pickups").size()
	zone3.take_damage(20)
	_check(zone3.destroyed and zone3.is_queued_for_deletion(), "核心打爆能量场摧毁")
	_check(
		get_tree().get_nodes_in_group("pickups").size() > pickups_before,
		"摧毁后逸散出结晶"
	)
	_check(GameState.zones_destroyed.has(91), "摧毁记录进入同步名单")
	GameState.zones_destroyed.clear()
	GameState.phase = "prepare"
	for z in get_tree().get_nodes_in_group("zombies"):
		z.queue_free()
	for p in get_tree().get_nodes_in_group("pickups"):
		p.queue_free()
	zone2.queue_free()

	# —— 联机时钟：主机打包 → 客户端套用 ——
	var old_weather := GameState.weather
	var old_moon := GameState.moon_phase
	GameState.phase = "outbreak"
	GameState.time_left = 123.0
	GameState.day_number = 4
	GameState.day_elapsed = 222.0
	GameState.weather = "rain"
	GameState.moon_phase = 0.5
	GameState.grid_repaired = true
	var payload := GameState.clock_payload()
	GameState.phase = "prepare"
	GameState.time_left = 300.0
	GameState.day_number = 1
	GameState.day_elapsed = 0.0
	GameState.weather = "clear"
	GameState.moon_phase = 1.0
	GameState.grid_repaired = false
	GameState.apply_clock(payload)
	_check(
		GameState.phase == "outbreak" and GameState.day_number == 4 and GameState.grid_repaired,
		"时钟载荷套用阶段/日号/电网"
	)
	_check(
		GameState.weather == "rain" and is_equal_approx(GameState.time_left, 123.0),
		"时钟载荷套用天气/倒计时"
	)
	GameState.phase = "prepare"
	GameState.time_left = 300.0
	GameState.day_number = 1
	GameState.day_elapsed = 0.0
	GameState.weather = old_weather
	GameState.moon_phase = old_moon
	GameState.grid_repaired = false

	# —— 清理 ——
	vehicle.queue_free()
	proto.queue_free()
	for leftover in get_tree().get_nodes_in_group("material_piles"):
		leftover.queue_free()
	await get_tree().process_frame
	GameState.demolished_buildings.erase(pos_px)
	GameState.building_material_pool.erase(pos_px)
	GameState.map_building_rects = old_rects
	GameState.home_base = {}
	GameState.test_mode = old_test_mode
	GameState.revival_stone = old_stone


func _test_base_claim_rules() -> void:
	var old_stone := GameState.revival_stone
	var old_test_mode := GameState.test_mode
	GameState.test_mode = false
	GameState.home_base = {}

	# —— 复活石门槛仍生效 ——
	GameState.revival_stone = false
	_check(not GameState.claim_home_base("house", Vector3(500, 0, 500)), "无复活石占领被拒（门槛仍生效）")
	_check(not GameState.has_home_base(), "无复活石时据点为空")
	GameState.revival_stone = true

	# —— 建筑内有 NPC 时占领被拒，清空后可占 ——
	var entry: Dictionary = GameState.BUILDING_LAYOUT[0]
	var pos_px: Vector2 = entry["position"]
	var size_px: Vector2 = entry["size"]
	var center3 := Vector3(
		pos_px.x * GameState.WORLD_SCALE_3D, 0.0, pos_px.y * GameState.WORLD_SCALE_3D
	)
	var door3 := center3 + Vector3(
		0.0, 0.05, size_px.y * GameState.WORLD_SCALE_3D / 2.0 + 1.2
	)
	var footprint := GameState.building_footprint_at(door3)
	_check(footprint.has_area(), "门口位置可反查建筑 footprint")
	var npc = load("res://scenes3d/npc3d.tscn").instantiate()
	npc.role = "pedestrian"
	add_child(npc)
	npc.global_position = center3
	await get_tree().physics_frame
	_check(GameState.npcs_in_rect(footprint) == 1, "footprint 内统计到存活 NPC")
	_check(not GameState.claim_home_base(String(entry["id"]), door3), "建筑内有 NPC 时占领被拒")
	_check(not GameState.has_home_base(), "被拒后据点仍为空")
	npc.take_damage(9999)
	await get_tree().process_frame
	_check(GameState.npcs_in_rect(footprint) == 0, "清空后 footprint 内无存活 NPC（尸体不算）")
	_check(GameState.claim_home_base(String(entry["id"]), door3), "清空建筑后可占领")
	GameState.home_base = {}

	# —— BaseDoor 占领引导 ——
	var proto_script: GDScript = load("res://scripts3d/proto3d.gd")
	var door = proto_script.BaseDoor.new()
	door.building_id = "house"
	door.building_name = "居民楼"
	add_child(door)
	door.global_position = Vector3(700, 0.05, 700)
	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector3(701, 0.05, 700)
	await get_tree().physics_frame
	_check(is_equal_approx(door.claim_channel_time(), 8.0), "普通模式占领引导 8 秒")
	door._try_interact()
	_check(door.channeling(), "按 E 进入占领引导")
	_check(not GameState.has_home_base(), "引导未完成时据点未生效")
	_check(door.prompt_text().contains("占领中"), "引导中提示占领进度")
	door._channel = 7.9
	await get_tree().create_timer(0.3).timeout
	_check(GameState.has_home_base(), "引导读满后完成占领")
	_check(not door.channeling(), "完成后退出引导状态")

	GameState.home_base = {}
	door._try_interact()
	_check(door.channeling(), "再次按 E 重新进入引导")
	player.global_position = Vector3(720, 0.05, 700)
	# process_frame 信号在节点 _process 之前发出，等两帧确保打断逻辑已跑
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not door.channeling(), "离开门口 4m 打断引导")
	_check(not GameState.has_home_base(), "打断后据点未生效")

	# 建筑里有 NPC 时引导不启动
	door.global_position = door3
	var npc2 = load("res://scenes3d/npc3d.tscn").instantiate()
	npc2.role = "pedestrian"
	add_child(npc2)
	npc2.global_position = center3
	player.global_position = door3 + Vector3(1.0, 0.0, 0.0)
	await get_tree().physics_frame
	door._try_interact()
	_check(not door.channeling(), "建筑内有 NPC 时引导不启动")
	_check(not GameState.has_home_base(), "引导未启动据点仍为空")
	npc2.take_damage(9999)
	await get_tree().process_frame

	# test_mode 引导时间为 0，瞬间占领
	GameState.test_mode = true
	_check(door.claim_channel_time() == 0.0, "test_mode 引导时间为 0")
	door._try_interact()
	_check(GameState.has_home_base() and not door.channeling(), "test_mode 瞬间占领")
	GameState.test_mode = false
	GameState.home_base = {}
	door.queue_free()
	player.queue_free()
	await get_tree().process_frame

	# —— 空地建据点扣建材堆 ——
	var pile = load("res://scenes3d/material_pile3d.tscn").instantiate()
	add_child(pile)
	pile.global_position = Vector3(300, 0.05, 300)
	pile.setup(100)
	var pile_far = load("res://scenes3d/material_pile3d.tscn").instantiate()
	add_child(pile_far)
	pile_far.global_position = Vector3(320, 0.05, 300)
	pile_far.setup(500)
	_check(
		GameState.nearby_pile_materials(Vector3(300, 0.05, 300)) == 100,
		"脚边 3m 内建材堆统计 100（远处堆不计入）"
	)
	_check(
		not GameState.claim_open_ground_base(Vector3(300, 0.05, 300)),
		"建材不足 150 空地建据点被拒"
	)
	_check(not GameState.has_home_base(), "空地建据点被拒后据点仍为空")
	_check(is_instance_valid(pile) and pile.amount == 100, "被拒时建材堆不扣减")
	var pile2 = load("res://scenes3d/material_pile3d.tscn").instantiate()
	add_child(pile2)
	pile2.global_position = Vector3(301.5, 0.05, 300)
	pile2.setup(100)
	_check(GameState.claim_open_ground_base(Vector3(300, 0.05, 300)), "凑够 150 空地建据点成功")
	_check(
		String(GameState.home_base.get("building_id", "")) == "open_ground",
		"空地据点 building_id 为 open_ground"
	)
	_check(
		not is_instance_valid(pile) or pile.is_queued_for_deletion(),
		"第一堆建材耗尽后移除"
	)
	_check(pile2.amount == 50, "第二堆建材扣到 50")
	_check(pile_far.amount == 500, "3m 外的建材堆不扣减")
	_check(not GameState.claim_open_ground_base(Vector3(300, 0.05, 300)), "已有据点时不能重复空地建据点")

	# —— 空地据点装饰照常生成（building_id 反查不到时用半径兜底）——
	var visual := Node3D.new()
	visual.set_script(load("res://scripts3d/base_visual3d.gd"))
	add_child(visual)
	await get_tree().process_frame
	_check(visual.get_child_count() > 0, "空地据点旗帜装饰照常生成")
	visual.queue_free()

	# —— 清理 ——
	for leftover in get_tree().get_nodes_in_group("material_piles"):
		leftover.queue_free()
	for leftover in get_tree().get_nodes_in_group("npcs"):
		if not leftover.is_queued_for_deletion():
			leftover.queue_free()
	await get_tree().process_frame
	GameState.home_base = {}
	GameState.revival_stone = old_stone
	GameState.test_mode = old_test_mode


func _test_workers() -> void:
	var old_stone := GameState.revival_stone
	var old_food: int = GameState.resources["food"]
	GameState.revival_stone = true
	# 批次 248：建筑据点半径按底座推导（专用探针覆盖）；此处用空地建点保持确定性 8m
	GameState.claim_home_base(GameState.OPEN_GROUND_BASE_ID, Vector3(50, 0, 50))

	# —— 招募与容量 ——
	_check(GameState.home_base.has("workers"), "据点数据带 workers 列表")
	_check(GameState.worker_cap() == 2, "1 级据点工人容量为 2（1 + 等级）")
	_check(GameState.recruit_worker_name().length() >= 2, "随机生成中文工人名")
	_check(GameState.add_worker("王建国"), "招募第一名工人")
	_check(GameState.add_worker("李秀英"), "招募第二名工人")
	_check(GameState.worker_count() == 2, "工人数量为 2")
	_check(GameState.add_worker("张铁柱"), "取消工人上限后超出旧容量仍可招募")
	_check(not GameState.add_worker("王建国"), "同名工人不能重复招募")
	var first: Dictionary = GameState.get_worker("王建国")
	_check(
		String(first.get("job", "")) == "idle" and String(first.get("state", "")) == "home",
		"新工人默认待命且在营地"
	)

	# —— 换任务 ——
	_check(GameState.assign_worker("王建国", "guard"), "分配守护营地任务")
	_check(String(GameState.get_worker("王建国")["job"]) == "guard", "任务已切换为守护营地")
	_check(
		GameState.assign_worker("王建国", "goto", {"target": Vector3(5, 0, 10)}),
		"分配前往某地任务（带目标）"
	)
	_check(not GameState.assign_worker("王建国", "fly"), "非法任务被拒绝")
	_check(not GameState.assign_worker("没人", "guard"), "不存在的工人不能派任务")

	# —— goto 目标换算 ——
	GameState.set_map_marker(Vector2(100, 200))
	_check(GameState.map_marker_3d() == Vector3(5, 0, 10), "地图标点换算 3D 坐标（×0.05）")
	GameState.clear_map_marker()

	# —— 管理器同步实体 ——
	var mgr := Node3D.new()
	mgr.set_script(load("res://scripts3d/worker3d.gd"))
	add_child(mgr)
	await get_tree().physics_frame
	_check(mgr._entities.size() == 3, "管理器为 3 名工人生成实体（无上限）")
	var body = mgr._entities["王建国"]
	_check(body.is_in_group("workers") and body.is_in_group("npcs"), "工人实体在 workers/npcs 组")
	_check(body.hp == body.max_hp and body.hp > 0, "工人实体带生命值")

	# —— build 任务产建材（直接调内部函数模拟 60s 到点）——
	GameState.assign_worker("王建国", "build")
	var mats_before := int(GameState.home_base["storage"]["materials"])
	body._build_produce()
	_check(
		int(GameState.home_base["storage"]["materials"]) == mats_before + 3,
		"建造任务给据点仓库 +3 建材"
	)

	# —— scavenge 返回入仓（直接调数据层模拟 3~5 分钟到点）——
	GameState.assign_worker("李秀英", "scavenge")
	var storage: Dictionary = GameState.home_base["storage"]
	var total_before := 0
	for kind in ["food", "meds", "ammo", "materials"]:
		total_before += int(storage.get(kind, 0))
	GameState.worker_scavenge_return("李秀英")
	var total_after := 0
	for kind in ["food", "meds", "ammo", "materials"]:
		total_after += int(storage.get(kind, 0))
	_check(total_after > total_before, "出门寻找物资带回随机物资入仓")
	_check(String(GameState.get_worker("李秀英")["state"]) == "home", "返回后状态归位（home）")

	# —— 黎明口粮：先扣据点仓库，再扣玩家背包 ——
	storage["food"] = 3
	GameState.resources["food"] = 1
	GameState._feed_workers()
	_check(GameState.worker_count() == 2, "仓库 3 + 背包 1 刚好养活 2 名工人")
	_check(int(storage["food"]) == 0 and GameState.resources["food"] == 0, "口粮先扣仓库再扣背包")

	# —— 断粮离队 ——
	GameState.resources["food"] = 2
	GameState._feed_workers()
	_check(GameState.worker_count() == 1, "食物只够 1 人，另一名工人断粮离队")
	_check(not GameState.get_worker("王建国").is_empty(), "先编入的工人优先领到口粮")
	await get_tree().process_frame
	_check(mgr._entities.size() == 1, "离队工人的实体被管理器移除")

	# —— 工人死亡从 workers 移除 ——
	var last = mgr._entities["王建国"]
	last.take_damage(9999)
	_check(GameState.worker_count() == 0, "工人阵亡后从 workers 移除")

	# —— 清理 ——
	mgr.queue_free()
	await get_tree().process_frame
	GameState.home_base = {}
	GameState.resources["food"] = old_food
	GameState.revival_stone = old_stone


func _test_followers() -> void:
	var old_weapons: Dictionary = GameState.weapons.duplicate()
	var old_current := GameState.current_weapon
	var old_armor := GameState.armor_id
	var old_armor_resist := GameState.armor_resist_value
	var old_melee := GameState.melee_item
	var old_melee_damage := GameState.melee_item_damage
	var old_stone := GameState.revival_stone
	GameState.home_base = {}
	GameState.revival_stone = false

	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	player.position = Vector3(300, 0, 300)
	add_child(player)
	var mgr := Node3D.new()
	mgr.set_script(load("res://scripts3d/worker3d.gd"))
	add_child(mgr)
	var civilians: Array = []
	await get_tree().physics_frame

	# —— 无据点招募即跟随 ——
	var civilian = load("res://scenes3d/npc3d.tscn").instantiate()
	civilian.role = "pedestrian"
	civilian.position = player.global_position + Vector3(1.0, 0, 0)
	add_child(civilian)
	for i in 4:
		await get_tree().process_frame
	civilian.recruit_price = 100
	GameState.money = 500
	mgr._update_recruit_target()
	var opts: Array = mgr.interact_options(player)
	_check(
		opts.size() == 2 and not bool(opts[0]["disabled"]),
		"无据点无复活石也能招募市民（菜单有接受/拒绝两项）"
	)
	mgr.interact_choose("recruit", player)
	await get_tree().process_frame
	_check(mgr._followers.size() == 1, "招募后生成跟随者实体")
	_check(not is_instance_valid(civilian), "原市民实体被移除")
	_check(GameState.money == 400, "招募扣除开价 ¥100")
	var follower = mgr._followers[0]
	_check(String(follower.mode) == "follow", "跟随者立即进入跟随状态")
	_check(not GameState.has_home_base(), "全程不需要据点")

	# —— 随从上限 4 人 ——
	for i in 3:
		var extra = load("res://scenes3d/npc3d.tscn").instantiate()
		extra.role = "pedestrian"
		extra.position = player.global_position + Vector3(1.2, 0, 0)
		add_child(extra)
		await get_tree().process_frame
		extra.recruit_price = 0
		mgr._update_recruit_target()
		mgr.interact_choose("recruit", player)
		await get_tree().process_frame
	_check(mgr._followers.size() == 4, "随从招募到 4 人")
	var fifth = load("res://scenes3d/npc3d.tscn").instantiate()
	fifth.role = "pedestrian"
	fifth.position = player.global_position + Vector3(1.0, 0, 0)
	add_child(fifth)
	civilians.append(fifth)
	await get_tree().process_frame
	fifth.recruit_price = 0
	mgr._update_recruit_target()
	opts = mgr.interact_options(player)
	_check(
		not bool(opts[0]["disabled"]),
		"取消随从上限后满 4 人仍可继续招募"
	)

	# —— 随从免疫玩家伤害 ——
	var hp_before: int = follower.hp
	follower.take_damage(50, player)
	_check(follower.hp == hp_before, "随从免疫玩家的子弹和近战")
	follower.take_damage(10, null)
	_check(follower.hp == hp_before - 10, "随从仍会被丧尸伤害")

	# —— 装备系统：给枪 / 给甲 / 给近战工具 ——
	GameState.weapons = {"pistol": 1, "rifle": 1}
	GameState.current_weapon = "rifle"
	GameState.mag_state["rifle"] = 30
	mgr.open_gear_panel(follower)
	_check(mgr.gear_panel_open(), "装备面板打开")
	_check(mgr._gear_list.get_child_count() == 2, "装备面板列出玩家 2 把枪")
	mgr._on_give_gear("weapon", "rifle")
	_check(GameState.weapons["rifle"] == 0, "给枪后玩家失去该武器")
	_check(String(follower.equipped_weapon) == "rifle", "跟随者记录装备步枪")
	_check(GameState.current_weapon == "pistol", "当前武器被给出后自动切换")
	GameState.armor_id = "vest"
	GameState.armor_resist_value = 0.12
	mgr._refresh_gear_panel()
	mgr._on_give_gear("armor", "vest")
	_check(GameState.armor_id == "", "给防弹衣后玩家失去护甲")
	_check(follower.equipped_armor and follower.max_hp == 100, "防弹衣给跟随者 +40 生命上限")
	GameState.melee_item = "axe"
	GameState.melee_item_damage = 48
	mgr._refresh_gear_panel()
	mgr._on_give_gear("melee", "axe")
	_check(GameState.melee_item == "", "给近战工具后玩家失去它")
	_check(follower.melee_damage == 48, "跟随者近战用工具伤害")
	_check(follower._name_label.text.contains("步枪"), "头顶标签显示武器名")
	mgr.close_gear_panel()

	# —— 跟随者按武器数据开火（步枪 34 伤害）——
	var zombie = load("res://scenes3d/zombie3d.tscn").instantiate()
	add_child(zombie)
	zombie.position = follower.global_position + Vector3(3.0, 0, 0)
	GameState.request_spatial_rebuild()
	await get_tree().physics_frame
	await get_tree().process_frame
	var zhp: int = zombie.hp
	follower._next_attack = 0
	follower._try_attack()
	_check(zombie.hp == zhp - 32, "跟随者按武器伤害开火（步枪 32）")
	zombie.queue_free()

	# —— 去营地：步行到据点后转守护 ——
	GameState.revival_stone = true
	GameState.claim_home_base("house", Vector3(320, 0, 300))
	follower.interact_choose("to_base", player)
	_check(String(follower.mode) == "goto_base", "去营地后进入前往状态")
	follower.global_position = Vector3(320, 0, 300)
	follower._decide = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(String(follower.mode) == "guard", "到达营地后转守护")

	# —— 留在营地 / 跟随我召回 ——
	follower.global_position = Vector3(321, 0, 300)
	player.global_position = Vector3(321.5, 0, 300)
	opts = follower.interact_options(player)
	_check(not bool(opts[2]["disabled"]), "玩家在据点半径内可让跟随者留在营地")
	follower.interact_choose("stay", player)
	_check(String(follower.mode) == "stay", "留在营地进入原地警戒")
	opts = follower.interact_options(player)
	_check(not bool(opts[3]["disabled"]), "待命的跟随者可用「跟随我」召回")
	follower.interact_choose("follow", player)
	_check(String(follower.mode) == "follow", "跟随我召回跟随者")
	follower.global_position = Vector3(330, 0, 300)
	player.global_position = Vector3(330.5, 0, 300)
	opts = follower.interact_options(player)
	_check(bool(opts[2]["disabled"]), "离开据点半径后留在营地选项禁用")

	# —— 解散：变回普通市民，装备掉在原地 ——
	player.global_position = follower.global_position + Vector3(1.0, 0, 0)
	var peds_before := get_tree().get_nodes_in_group("pedestrians").size()
	var loot_before := get_tree().get_nodes_in_group("loot_pickups").size()
	follower.interact_choose("dismiss", player)
	await get_tree().process_frame
	_check(mgr._followers.size() == 3, "解散后随从减少")
	_check(
		get_tree().get_nodes_in_group("pedestrians").size() == peds_before + 1,
		"解散后生成普通市民"
	)
	_check(
		get_tree().get_nodes_in_group("loot_pickups").size() == loot_before + 2,
		"解散时防弹衣与近战工具掉在原地"
	)
	var found_rifle := false
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get("weapon_id") == "rifle":
			found_rifle = true
	_check(found_rifle, "解散时枪械掉在原地")

	# —— 死亡掉落装备 ——
	var f2 = mgr._followers[0]
	f2.equipped_weapon = "pistol"
	f2._die()
	await get_tree().process_frame
	_check(mgr._followers.size() == 2, "跟随者阵亡后从队伍移除")
	var found_pistol := false
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get("weapon_id") == "pistol":
			found_pistol = true
	_check(found_pistol, "跟随者死亡掉落武器")

	# —— 清理 ——
	for npc in civilians:
		if is_instance_valid(npc):
			npc.queue_free()
	for npc in get_tree().get_nodes_in_group("pedestrians"):
		npc.queue_free()
	for node in get_tree().get_nodes_in_group("loot_pickups"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get("weapon_id") != null:
			node.queue_free()
	mgr.queue_free()
	player.queue_free()
	await get_tree().process_frame
	GameState.home_base = {}
	GameState.weapons = old_weapons
	GameState.current_weapon = old_current
	GameState.armor_id = old_armor
	GameState.armor_resist_value = old_armor_resist
	GameState.melee_item = old_melee
	GameState.melee_item_damage = old_melee_damage
	GameState.revival_stone = old_stone



# headless 下 warp_mouse 无效：用合成鼠标移动事件把指针挪到目标屏幕位置（交互=鼠标悬停）
func _hover_mouse(target: Node3D, player: Node3D) -> void:
	var cam: Camera3D = player.get("camera")
	player.get_node("HUD").interact_hover_override = cam.unproject_position(target.global_position)

func _test_interact_menu() -> void:
	var old_stone := GameState.revival_stone
	var old_test := GameState.test_mode
	GameState.revival_stone = true
	GameState.home_base = {}
	GameState.set_wanted(0)

	# —— 信号塔菜单：选项生成与选择 ——
	var station := Node3D.new()
	station.set_script(load("res://scripts3d/station3d.gd"))
	station.data = {"name": "测试基站", "position": Vector2(2000, 2000)}
	station.position = Vector3(600, 0, 600)
	add_child(station)
	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	player.position = Vector3(601, 0, 600)
	add_child(player)
	await get_tree().physics_frame
	var opts: Array = station.interact_options(player)
	_check(opts.size() == 3, "信号塔菜单：修复/破坏/拆除 三个选项")
	_check(
		String(opts[0]["id"]) == "repair"
		and String(opts[1]["id"]) == "sabotage"
		and String(opts[2]["id"]) == "demolish",
		"信号塔选项 id 正确"
	)
	_check(
		bool(opts[0]["disabled"]) and not bool(opts[1]["disabled"]),
		"完好时修复选项禁用、破坏选项可用"
	)
	GameState.test_mode = true
	station.interact_choose("sabotage", player)
	_check(station.destroyed, "菜单选择破坏后信号塔进入损坏状态")
	opts = station.interact_options(player)
	_check(
		not bool(opts[0]["disabled"]) and bool(opts[1]["disabled"]),
		"破坏后修复选项可用、破坏选项禁用"
	)
	station.interact_choose("repair", player)
	_check(not station.destroyed, "修复选项恢复原修复效果（test_mode 引导为 0）")
	GameState.test_mode = old_test
	var piles_before := get_tree().get_nodes_in_group("material_piles").size()
	var mats_before_station := int(GameState.resources.get("materials", 0))
	station.interact_choose("demolish", player)
	await get_tree().process_frame
	_check(not is_instance_valid(station), "拆除选项彻底摧毁信号塔")
	_check(
		int(GameState.resources.get("materials", 0)) == mats_before_station + 10
		and get_tree().get_nodes_in_group("material_piles").size() == piles_before,
		"拆除信号塔建材 ×10 直接入背包（不落地）"
	)
	GameState.set_wanted(0)

	# —— 防御设施菜单：升级 / 卖掉 ——
	GameState.test_mode = true
	# 批次 248：建筑据点半径按底座推导（专用探针覆盖）；此处用空地建点保持确定性 8m
	GameState.claim_home_base(GameState.OPEN_GROUND_BASE_ID, Vector3(50, 0, 50))
	var build := Node3D.new()
	build.set_script(load("res://scripts3d/base_build3d.gd"))
	add_child(build)
	player.global_position = Vector3(50, 0, 50)
	await get_tree().physics_frame
	build._open()
	_check(GameState.add_base_defense("barricade", Vector3(52, 0, 52)), "放置待操作路障")
	build._spawn_defense("barricade", Vector3(52, 0, 52), 0.0)
	await get_tree().physics_frame
	var barricade: Node3D = build._defense_nodes[0]
	opts = barricade.interact_options(player)
	_check(
		opts.size() == 2
		and String(opts[0]["id"]) == "upgrade"
		and String(opts[1]["id"]) == "sell",
		"防御设施菜单：升级 + 卖掉 两个选项（路障无操作员位）"
	)
	barricade.interact_choose("upgrade", player)
	_check(
		GameState.defense_upgrade_level(Vector3(52, 0, 52)) == 1,
		"菜单选择升级后设施等级 +1"
	)
	var upgraded: Node3D = build._defense_nodes[0]
	upgraded.interact_choose("sell", player)
	_check(GameState.base_defense_count() == 0, "菜单选择卖掉后设施从据点移除")
	build.force_close()
	GameState.test_mode = old_test

	# —— 招募菜单：跟随我（无需据点/复活石），随从满员禁用 ——
	GameState.home_base = {}
	GameState.revival_stone = false
	var mgr := Node3D.new()
	mgr.set_script(load("res://scripts3d/worker3d.gd"))
	add_child(mgr)
	var civilian = load("res://scenes3d/npc3d.tscn").instantiate()
	civilian.role = "pedestrian"
	civilian.position = player.global_position + Vector3(1.0, 0, 0)
	add_child(civilian)
	for i in 4:
		await get_tree().process_frame
	civilian.recruit_price = 100
	GameState.money = 500
	opts = mgr.interact_options(player)
	_check(
		opts.size() == 2
		and String(opts[0]["id"]) == "recruit"
		and String(opts[0]["label"]).contains("接受开价")
		and String(opts[1]["label"]) == "拒绝"
		and not bool(opts[0]["disabled"]),
		"市民菜单为「接受开价 / 拒绝」两项"
	)
	for i in 4:
		var dummy := Node3D.new()
		mgr.add_child(dummy)
		mgr._followers.append(dummy)
	opts = mgr.interact_options(player)
	_check(
		not bool(opts[0]["disabled"]),
		"取消随从上限后招募选项始终可用"
	)
	mgr._followers.clear()

	# —— 工人菜单：分配任务 / 解散 ——
	GameState.revival_stone = true
	GameState.claim_home_base("house", player.global_position)
	GameState.add_worker("王建国")
	GameState.add_worker("李秀英")
	mgr._sync_workers()
	await get_tree().physics_frame
	var body = mgr._entities.get("王建国")
	_check(body != null, "工人实体已生成")
	if body != null:
		body.global_position = player.global_position + Vector3(1.0, 0, 0)
		opts = body.interact_options(player)
		_check(
			opts.size() == 2
			and String(opts[0]["id"]) == "assign"
			and String(opts[1]["id"]) == "dismiss",
			"工人菜单：分配任务 + 解散 两个选项"
		)
		body.interact_choose("assign", player)
		_check(mgr.panel_open(), "分配任务打开任务面板")
		mgr.close_panel()
		body.interact_choose("dismiss", player)
		_check(GameState.get_worker("王建国").is_empty(), "解散工人后从营地移除")

	# —— HUD 菜单：打开 / 选择 / 关闭 ——
	GameState.home_base = {}
	civilian.queue_free()
	await get_tree().process_frame
	var station2 := Node3D.new()
	station2.set_script(load("res://scripts3d/station3d.gd"))
	station2.data = {"name": "菜单基站", "position": Vector2(2000, 2000)}
	station2.position = Vector3(700, 0, 700)
	add_child(station2)
	player.global_position = Vector3(701, 0, 700)
	await get_tree().physics_frame
	# 交互新规：只对鼠标悬停的目标交互——把鼠标移到信号站屏幕位置
	var hud = player.get_node("HUD")
	_hover_mouse(station2, player)
	hud._try_interact_press()
	_check(GameState.interact_menu_open, "按 E 打开交互菜单")
	_check(hud._menu_options.size() == 3, "菜单列出修复/破坏/拆除三个选项")
	hud._choose_menu_option(1)
	_check(not GameState.interact_menu_open, "选择后菜单关闭")
	_check(station2.destroyed, "选择执行了破坏信号站")
	hud._try_interact_press()
	_check(GameState.interact_menu_open, "损坏信号塔菜单再次打开")
	hud._close_interact_menu()
	_check(not GameState.interact_menu_open, "Esc / 再按 E 关闭菜单")

	# —— 单选项直接执行：拾取不弹菜单 ——
	station2.queue_free()
	var loot = load("res://scenes3d/loot_item3d.tscn").instantiate()
	add_child(loot)
	loot.global_position = player.global_position + Vector3(1.0, 0, 0)
	await get_tree().process_frame
	# 交互新规：鼠标悬停在掉落物上
	_hover_mouse(loot, player)
	# 批次 239：默认掉落物是「食物」，拾取入资源计数（不再进背包 loot_items）
	var food_before := int(GameState.resources.get("food", 0))
	hud._try_interact_press()
	_check(not GameState.interact_menu_open, "只有 1 个选项时不弹菜单")
	_check(int(GameState.resources.get("food", 0)) == food_before + 1, "单选项按 E 直接执行拾取（食物入资源计数）")

	# —— 清理 ——
	mgr.queue_free()
	loot.queue_free()
	player.queue_free()
	for leftover in get_tree().get_nodes_in_group("material_piles"):
		leftover.queue_free()
	for leftover in get_tree().get_nodes_in_group("npcs"):
		if not leftover.is_queued_for_deletion():
			leftover.queue_free()
	await get_tree().process_frame
	GameState.home_base = {}
	GameState.base_build_mode = false
	GameState.interact_menu_open = false
	GameState.set_wanted(0)
	GameState.reset_coverage()
	GameState.revival_stone = old_stone
	GameState.test_mode = old_test


func _test_bullet_range() -> void:
	# —— 直接构造子弹：射程内继续飞、飞到上限即消失 ——
	var bullet = load("res://scenes3d/bullet3d.tscn").instantiate()
	add_child(bullet)
	bullet.setup(Vector3(100, 50, 100), Vector3.RIGHT, 10, null, true, false, 30.0)
	await get_tree().create_timer(0.05).timeout
	_check(is_instance_valid(bullet), "射程内子弹继续飞行")
	await get_tree().create_timer(0.25).timeout
	_check(not is_instance_valid(bullet), "子弹飞到射程上限即消失")

	# —— 玩家射击：方向射击，max_distance = 武器射程（不按瞄准点截断）——
	GameState.weapons = {"pistol": 1}
	GameState.current_weapon = "pistol"
	GameState.mag_state["pistol"] = 12
	GameState.resources["ammo"] = 50
	var player = load("res://scenes3d/fps_player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector3(200, 0, 200)
	await get_tree().physics_frame
	player._aim_point = player.global_position + Vector3(6.0, 0.0, 0.0)
	var children_before := get_children()
	player._try_fire(true)
	var shot = null
	for child in get_children():
		if not children_before.has(child) and "max_distance" in child:
			shot = child
	_check(shot != null, "射击生成子弹")
	if shot != null:
		_check(
			is_equal_approx(shot.max_distance, 45.0),
			"近点瞄准子弹也按武器射程飞到底（方向射击）"
		)
		var flat_dir: Vector3 = shot.direction
		_check(absf(flat_dir.y) < 0.001, "子弹平直飞行不扎地面")
	player._aim_point = player.global_position + Vector3(100.0, 0.0, 0.0)
	player._next_shot_msec = 0
	children_before = get_children()
	player._try_fire(true)
	shot = null
	for child in get_children():
		if not children_before.has(child) and "max_distance" in child:
			shot = child
	if shot != null:
		_check(
			is_equal_approx(shot.max_distance, 45.0),
			"远点瞄准子弹按武器射程 45 米封顶"
		)
	player.queue_free()
	await get_tree().process_frame


func _test_scopes() -> void:
	var saved_scopes: Dictionary = GameState.scopes.duplicate()
	GameState.scopes = {}
	_check(
		GameState.weapon_view_range("rifle") == GameState.DEFAULT_VIEW_RANGE,
		"无瞄准镜视距 18 米"
	)
	_check(GameState.install_scope("rifle", "scope_rds"), "安装红点镜成功")
	_check(GameState.weapon_view_range("rifle") == 25.0, "红点镜视距 25 米")
	_check(GameState.install_scope("rifle", "scope_2x"), "换装二倍镜成功")
	_check(GameState.weapon_view_range("rifle") == 35.0, "二倍镜视距 35 米")
	GameState.install_scope("rifle", "scope_4x")
	_check(GameState.weapon_view_range("rifle") == 50.0, "四倍镜视距 50 米")
	GameState.install_scope("rifle", "scope_8x")
	_check(GameState.weapon_view_range("rifle") == 70.0, "八倍镜视距 70 米")
	_check(not GameState.install_scope("melee", "scope_rds"), "近战武器不能装瞄准镜")
	_check(not GameState.install_scope("rifle", "bread"), "非瞄准镜物品不能当瞄准镜装")
	_check(not GameState.install_scope("", "scope_rds"), "空武器安装失败")

	# —— meta 持久化 ——
	GameState.save_meta()
	GameState.scopes = {}
	GameState._meta_loaded = false
	GameState.load_meta()
	_check(GameState.weapon_view_range("rifle") == 70.0, "读档后瞄准镜配置保留")
	GameState.scopes = saved_scopes
	GameState.save_meta()
