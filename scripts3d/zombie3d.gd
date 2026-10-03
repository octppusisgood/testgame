extends CharacterBody3D

const SPEED := 2.3
const WANDER_SPEED := 0.8
const DETECT_RANGE := 12.0
const ATTACK_RANGE := 1.7
# 攻击前摇（秒）：动作出手到伤害结算的窗口，玩家冲刺可闪避
const WINDUP_SECONDS := 0.35
# 玩家基础移速 5.0 m/s，丧尸基础 SPEED 2.3 → 基础丧尸移速 = 玩家 80%
const PLAYER_SPEED_MATCH := 5.0 * 0.8 / 2.3
const ATTACK_COOLDOWN := 1.0
const GRAVITY := 18.0
const NOISE_MEMORY := 8.0
const PICKUP_SCENE := preload("res://scenes3d/pickup3d.tscn")
const PICKUP_DROP := preload("res://scripts3d/pickup3d.gd")
const MATERIAL_PILE_SCENE := preload("res://scenes3d/material_pile3d.tscn")
const TITAN_AOE_RADIUS := 9.0
const TITAN_SHOCK_RADIUS := 16.0
const TITAN_DETECT_MULT := 2.5
const ASSAULT_ARRIVE_DIST := 5.0
const ASSAULT_ROAM_RADIUS := 7.0
# AI 分级（LOD）：按与观察者距离降扫描/动画/物理频率
const LOD_MID_DIST := 28.0
const LOD_FAR_DIST := 55.0

var hp := 60
var is_boss := false
var is_acid := false
var zombie_tier := 0
var showcase := false
var _tier_knockback := false
var _summon_timer := 20.0

var _speed_mult := 1.0
var _stuck_time := 0.0
var _stuck_total := 0.0
var _detour_time := 0.0
var _detour_angle := 0.0
var _damage := 8
var _attack_speed := 1.0
var _resist := 0.0
var _bleed_time := 0.0
var _bleed_dps := 0.0
var _bleed_accum := 0.0
# 减速效果：剩余时间与倍率（1.0 = 无减速）
var _slow_time := 0.0
var _slow_mult := 1.0
var _acid_timer := 2.0
# 攻击判定距离/追踪范围：默认用常量，基础丧尸在 _apply_evolution 里按规则覆盖
var _attack_range := ATTACK_RANGE
var _detect_range := DETECT_RANGE
# 爆头伤害倍率（猎犬头部更脆）
var headshot_mult := 2.0


# 护甲类型（枪械改装弹种判定）：装甲丧尸(tier6)与 Boss 视为装甲，吃穿甲弹加成
func is_armored() -> bool:
	return zombie_tier >= 6 or is_boss
# —— 变异猎犬（tier 2）：低护甲、高速、突进攻击 ——
var is_hound := false
const HOUND_POUNCE_RANGE := 14.0
const HOUND_POUNCE_DIST := 14.0
const HOUND_POUNCE_SPEED := 28.0
const HOUND_POUNCE_WINDUP := 0.5
const HOUND_POUNCE_DAMAGE := 20
const HOUND_POUNCE_CD := 2.0
const HOUND_CLAW_RANGE := 1.0
const HOUND_CLAW_WINDUP := 0.3
const HOUND_CLAW_CD := 1.0
const HOUND_CLAW_DAMAGE := 15
const HOUND_TRACK_RANGE := 10.5
var _pounce_cd := 0.0
var _pounce_windup := 0.0
var _pounce_leap := 0.0
var _pounce_leap_total := 0.0
var _pounce_dist := 0.0
var _pounce_dir := Vector3.ZERO
var _pounce_hit_done := false
var _pounce_leap_elapsed := 0.0
var _claw_windup := 0.0
var _claw_cd := 0.0
var _claw_swipe := 0.0
var _claw_target: Node3D = null
var _stagger := 0.0
var _dog_root: Node3D = null
var _head_root: Node3D = null
var _paw_l: MeshInstance3D = null
var _paw_r: MeshInstance3D = null
# 前爪基准位置（无动作时）
const PAW_BASE_L := Vector3(-0.11, 0.14, -0.3)
const PAW_BASE_R := Vector3(0.11, 0.14, -0.3)
# —— 异变狼蛛：枪械减伤 80%、近战增伤 120%、喷毒+近战爪 ——
var is_spider := false
const SPIDER_TRACK_RANGE := 8.4
const SPIDER_POUNCE_RANGE := 4.2
const SPIDER_POUNCE_WINDUP := 0.4
const SPIDER_POUNCE_SPEED := 10.0
const SPIDER_POUNCE_DIST := 3.0
const SPIDER_POUNCE_CD := 1.5
const SPIDER_MELEE_DAMAGE := 20
const SPIDER_MELEE_POISON_CHANCE := 0.05
const SPIDER_MELEE_POISON_SECONDS := 5.0
const SPIDER_SPIT_RANGE := 2.8
const SPIDER_SPIT_WINDUP := 0.3
const SPIDER_SPIT_CD := 3.0
const SPIDER_SPIT_COUNT := 3
const SPIDER_SPIT_INTERVAL := 0.31
const SPIDER_SPIT_SPEED := 9.0
const SPIDER_SPIT_DIST := 8.4
const SPIDER_SPIT_DAMAGE := 5
const SPIDER_SPIT_POISON := 10.0
var _spider_root: Node3D = null
var _spit_cd := 0.0
var _spit_windup := 0.0
var _spit_left := 0
var _spit_timer := 0.0
var _spit_dir := Vector3.ZERO
var _venom_shots: Array = []
var _sp_pounce_windup := 0.0
var _sp_pounce_leap := 0.0
var _sp_pounce_elapsed := 0.0
var _sp_pounce_dir := Vector3.ZERO
var _sp_pounce_hit := false
var _sp_pounce_cd := 0.0
var _shock_timer := 5.0
var _target_timer := 0.0

var _attack_cooldown := 0.0
# 攻击前摇计时与目标
var _windup := 0.0
var _windup_target: Node3D = null
var _wander_angle := 0.0
var _wander_timer := 0.0
var _target: Node3D = null
var _investigate_pos := Vector3.ZERO
var _investigate_timer := 0.0
var _has_investigation := false
# 据点袭击目标（proto3d 夜袭波设置）：Vector3.ZERO 表示无袭击任务
var assault_target := Vector3.ZERO
# 守关 Boss：绑定能量点，点存活期间只在点附近徘徊；点被摧毁后主动进攻（玩家/营地取更近者）
var guard_zone: Node = null
var guard_home := Vector3.ZERO
# 肉鸽 Boss 能量场留守怪：非 Boss 也可留守——绕场徘徊、只反击进圈目标，不主动出击
var hold_home := Vector3.ZERO
var hold_radius := 0.0
# 普通能量场守场期限：>0 倒计时，归零即解除守场散入城市（Boss 场留守怪不设=永久留守）
var hold_timer := 0.0
var _guard_roam_pos := Vector3.ZERO
const GUARD_ROAM_RADIUS := 10.0
const GUARD_LEASH := 22.0
# 挠营地本体的攻击计时
var _base_attack_timer := 0.0
var _assault_roam_pos := Vector3.ZERO
# 批次 261：城市漫游——白天普通丧尸（含能量点刷出的非留守怪）定期脱队去城市远处游走
var _roam_target := Vector3.ZERO
var _roam_timer := 0.0
var _sight_timer := 0.0
var _lod_level := 0
var _lod_phase := 0
var _limbs := {}
# 尸潮群演模式：hero = 完整模型+完整 AI（最近的少量个体）；crowd = MultiMesh 单绘制+极简 AI
var horde_mode := "hero"
var net_id := 0
var net_puppet := false
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_moving := false
var _dying := false


func _ready() -> void:
	add_to_group("zombies")
	# 丧尸放独立物理层：怪与怪/玩家之间零碰撞（割草式穿模），
	# 只与世界（层 1）碰撞；子弹射线掩码已配套改为 1|2
	collision_layer = 2
	collision_mask = 1
	GameState.request_spatial_rebuild()
	if showcase:
		set_physics_process(false)
	_apply_evolution()
	_limbs = BlockyRig.build(self, $Mesh as MeshInstance3D, _make_style())
	if is_hound:
		_build_hound_model()
	if is_spider:
		_build_spider_model()
	_wander_angle = randf() * TAU
	_wander_timer = randf_range(1.0, 3.0)
	_lod_phase = randi() % 4
	_net_pos = global_position
	_net_yaw = rotation.y
	if (
		not net_puppet
		and not GameState.test_mode
		and Network.is_multiplayer()
		and Network.is_server()
	):
		Network.register_entity(self, "zombie", net_params())


func net_params() -> Dictionary:
	return {
		"zombie_tier": zombie_tier,
		"is_boss": is_boss,
		"is_acid": is_acid,
	}


func setup_puppet(params: Dictionary) -> void:
	zombie_tier = int(params.get("zombie_tier", zombie_tier))
	is_boss = bool(params.get("is_boss", is_boss))
	is_acid = bool(params.get("is_acid", is_acid))


func net_state() -> Array:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	return [
		global_position.x,
		global_position.y,
		global_position.z,
		rotation.y,
		1.0 if moving else 0.0,
	]


func apply_net_state(data: PackedFloat32Array, base: int) -> void:
	_net_pos = Vector3(data[base], data[base + 1], data[base + 2])
	_net_yaw = data[base + 3]
	_net_moving = data[base + 4] > 0.5


func _puppet_tick(delta: float) -> void:
	global_position = global_position.lerp(_net_pos, minf(1.0, delta * 10.0))
	rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 10.0))
	if _net_moving:
		BlockyRig.update(_limbs, delta, 2.5)
	else:
		BlockyRig.update(_limbs, delta, 0.0)


func _make_style() -> Dictionary:
	var style := {
		"model": BlockyRig.random_zombie(),
		"tint": Color(0.72, 1.05, 0.66, 1.0),
	}
	match zombie_tier:
		2:
			# 变异猎犬：瘦长、土棕色
			style["bulk"] = 0.85
			style["tint"] = Color(0.75, 0.55, 0.35, 1.0)
		3:
			style["bulk"] = 1.05
			style["tint"] = Color(1.05, 1.0, 0.8, 1.0)
		4:
			style["bulk"] = 1.25
		5:
			style["tint"] = Color(0.5, 1.15, 0.4, 1.0)
		6:
			style["tint"] = Color(1.1, 1.05, 0.88, 1.0)
		7:
			style["bulk"] = 1.15
			style["tint"] = Color(1.05, 0.55, 0.5, 1.0)
		8:
			style["bulk"] = 1.25
			style["tint"] = Color(0.72, 0.58, 0.9, 1.0)
		9:
			style["bulk"] = 1.4
			style["tint"] = Color(0.85, 0.5, 1.05, 1.0)
	if is_acid:
		style["tint"] = Color(0.5, 1.2, 0.35, 1.0)
	return style


func _apply_evolution() -> void:
	if zombie_tier > 0:
		var tier: Dictionary = GameState.zombie_tier_info(zombie_tier)
		if tier.is_empty():
			tier = GameState.zombie_tier_info(1)
		hp = int(tier["hp"])
		_damage = int(tier["damage"])
		_speed_mult = float(tier["speed"])
		_attack_speed = 1.0 / maxf(float(tier["cooldown"]), 0.1)
		_resist = float(tier["resist"])
		scale = Vector3.ONE * float(tier["scale"])
		is_acid = bool(tier["acid"])
		_tier_knockback = bool(tier["knockback"])
		if zombie_tier == 1:
			# 普通丧尸（召唤 tier 1）：与野外基础丧尸同规则
			_attack_range = 1.0
			_detect_range = 7.0
		elif zombie_tier == 2:
			# 变异猎犬：低护甲、追踪 15 身位、突进触发 2 身位
			is_hound = true
			headshot_mult = 2.2
			_attack_range = HOUND_POUNCE_RANGE
			_detect_range = HOUND_TRACK_RANGE
		elif bool(tier.get("spider", false)):
			# 异变狼蛛：无爆头、枪械减伤、追踪 12 身位、攻击触发 4 身位
			is_spider = true
			headshot_mult = 1.0
			_attack_range = SPIDER_SPIT_RANGE
			_detect_range = SPIDER_TRACK_RANGE
		return
	var stats := GameState.zombie_stats()
	# 基础丧尸规则：60血 / 10伤 / 1.5秒一抓 / 速度为玩家基础移速 80% /
	# 纯近战抓挠，判定 1.0m（约 1/3 身位超出接触面）/ 追踪范围 7m（约 10 身位）
	hp = int(100.0 * float(stats["hp"]))
	_damage = int(10.0 * float(stats["damage"]))
	_attack_speed = float(stats["attack_speed"]) / 1.5
	_resist = float(stats["resist"])
	_speed_mult = float(stats["speed"]) * PLAYER_SPEED_MATCH
	_attack_range = 1.0
	_detect_range = 7.0
	scale = Vector3.ONE * float(stats["scale"])
	if randf() < float(stats["runner_chance"]):
		_speed_mult *= float(stats["runner_speed"])
	if bool(stats["acid"]) and randf() < 0.3:
		is_acid = true
	if is_boss:
		hp *= 5
		_damage = int(_damage * 1.5)
		scale = Vector3.ONE * maxf(float(stats["scale"]), 1.6) * 1.3


func apply_bleed(duration: float, dps: float) -> void:
	_bleed_time = maxf(_bleed_time, duration)
	_bleed_dps = maxf(_bleed_dps, dps)


# 减速：duration 秒内移动速度 ×mult（重复命中刷新时间，取最强效果）
func apply_slow(duration: float, mult: float) -> void:
	_slow_time = maxf(_slow_time, duration)
	_slow_mult = minf(_slow_mult, mult)


func hear_noise(pos: Vector3) -> void:
	if _target != null:
		return
	_investigate_pos = pos
	_investigate_timer = NOISE_MEMORY
	_has_investigation = true


func _physics_process(delta: float) -> void:
	if net_puppet:
		_puppet_tick(delta)
		return
	# 守场期满释放：放在早退分支之前，远距/群演模式下也照常到期解除
	if hold_timer > 0.0:
		hold_timer -= delta
		if hold_timer <= 0.0:
			hold_timer = 0.0
			hold_radius = 0.0
			guard_home = Vector3.ZERO
			hold_home = Vector3.ZERO
	if (
		GameState.viewer_active
		and global_position.distance_to(GameState.viewer_position) > 130.0
	):
		velocity = Vector3.ZERO
		return
	if horde_mode == "crowd":
		_crowd_tick(delta)
		return
	var viewer_dist := (
		global_position.distance_to(GameState.viewer_position)
		if GameState.viewer_active
		else 0.0
	)
	_lod_level = 0 if viewer_dist < LOD_MID_DIST else (1 if viewer_dist < LOD_FAR_DIST else 2)
	BlockyRig.set_lod_frozen(_limbs, _lod_level == 2)
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	# 攻击前摇结算：动作出手 0.35 秒后才判定伤害，期间玩家冲刺可无伤闪避
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_resolve_windup()
	if _bleed_time > 0.0:
		_bleed_time -= delta
		_bleed_accum += _bleed_dps * delta
		if _bleed_accum >= 1.0:
			var tick := int(_bleed_accum)
			_bleed_accum -= float(tick)
			take_damage(tick)
			if hp <= 0:
				return
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_mult = 1.0
	if is_acid:
		_acid_timer -= delta
		if _acid_timer <= 0.0:
			_acid_timer = 3.0
			_try_spit()
	if zombie_tier == 9:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = 20.0
			_summon_minions()
		_shock_timer -= delta
		if _shock_timer <= 0.0 and _target != null:
			var target_dist := global_position.distance_to(_target.global_position)
			if target_dist < 26.0:
				_shock_timer = 6.0
				_shockwave()
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = 0.8 * _scan_mult()
		_check_sighting()
	_target_timer -= delta
	if (
		_target_timer <= 0.0
		or _target == null
		or not is_instance_valid(_target)
	):
		_target_timer = (0.15 if _target != null else randf_range(0.4, 0.6)) * _scan_mult()
		# 批次 262：锁定追到底——已有目标时只在「目标死亡/无效」时才重扫；
		# 跑出侦测圈不再丢失目标（脱离战斗），直到一方死亡才算结束
		if _target != null and is_instance_valid(_target):
			# 贴脸抢仇恨：侦测圈一半内有别的目标（如玩家贴到丧尸背后）→ 直接切换，
			# 避免死咬旧目标显得"瞎"；扫描仍走节流，无额外开销
			var current: Node3D = _target
			var close_dist: float = _detect_range * 0.5
			var closer := GameState.nearest_entity_in_group(global_position, "npcs", close_dist) as Node3D
			var pl := get_tree().get_first_node_in_group("player") as Node3D
			if (
				pl != null
				and not GameState.is_bad_zombie()
				and GameState.player_in_building.is_empty()
				and global_position.distance_to(pl.global_position) < close_dist
				and pl != current
			):
				_target = pl
			elif closer != null and closer != current:
				_target = closer
		else:
			_target = _find_target()
	if _target == null and _has_investigation:
		_investigate_timer -= delta
		if _investigate_timer <= 0.0:
			_has_investigation = false
	var moving := false
	if is_hound:
		moving = _hound_move(delta)
	elif is_spider:
		moving = _spider_move(delta)
	elif _roam_target != Vector3.ZERO:
		# 批次 261：城市漫游中——白天没目标时去城市远处游走（遇敌/夜间立即放弃）
		if GameState.is_night() or _target != null:
			_roam_target = Vector3.ZERO
		else:
			var to_roam := _roam_target - global_position
			to_roam.y = 0.0
			if to_roam.length() < 2.0:
				_roam_target = Vector3.ZERO
			else:
				moving = _move_toward(_roam_target, WANDER_SPEED * 1.4 * _speed_mult * _slow_mult)
	elif _target != null:
		moving = _chase_target()
	elif _has_investigation:
		moving = _move_toward(_investigate_pos, SPEED * 0.8 * _speed_mult * _slow_mult)
	elif _guarding():
		# 守关 Boss：绕能量点徘徊，不远离
		if (
			_guard_roam_pos == Vector3.ZERO
			or global_position.distance_to(_guard_roam_pos) < 1.5
		):
			_guard_roam_pos = guard_home + Vector3(
				randf_range(-GUARD_ROAM_RADIUS, GUARD_ROAM_RADIUS),
				0.0,
				randf_range(-GUARD_ROAM_RADIUS, GUARD_ROAM_RADIUS)
			)
		moving = _move_toward(_guard_roam_pos, WANDER_SPEED * _speed_mult * _slow_mult)
	elif assault_target != Vector3.ZERO:
		# 夜袭丧尸：直奔据点；抵达后围绕据点徘徊，就近目标（设施/玩家/NPC）交给 _find_target
		var to_base := assault_target - global_position
		to_base.y = 0.0
		if to_base.length() > ASSAULT_ARRIVE_DIST:
			moving = _move_toward(assault_target, SPEED * 1.3 * _speed_mult * _slow_mult)
		else:
			if (
				_assault_roam_pos == Vector3.ZERO
				or global_position.distance_to(_assault_roam_pos) < 1.2
			):
				_assault_roam_pos = assault_target + Vector3(
					randf_range(-ASSAULT_ROAM_RADIUS, ASSAULT_ROAM_RADIUS),
					0.0,
					randf_range(-ASSAULT_ROAM_RADIUS, ASSAULT_ROAM_RADIUS)
				)
			moving = _move_toward(_assault_roam_pos, WANDER_SPEED * _speed_mult * _slow_mult)
			# 打不到设施/人就挠营地本体（肉鸽守营：营地有生命值）
			_base_attack_timer -= delta
			if _base_attack_timer <= 0.0 and GameState.has_home_base():
				_base_attack_timer = 1.0
				var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
				if global_position.distance_to(base_pos) <= GameState.home_base_radius():
					GameState.damage_home_base(3 + zombie_tier * 2)
	if not moving:
		_wander(delta)
	# 远距丧尸隔帧跑物理与动画：跳过的帧 velocity 保留，不乘速度补偿
	# 英雄位也减半到 30Hz——尸潮规模下 move_and_slide 是逐只计费的大头
	var physics_step := 2
	if (Engine.get_physics_frames() + _lod_phase) % physics_step == 0:
		if _lod_level == 2 and _target == null:
			# 超远游荡丧尸免碰撞直移：不做物理查询，但过一遍建筑矩形推挤（不穿楼）
			global_position += velocity * delta * physics_step
			var proto = get_parent()
			if proto != null and proto.has_method("building_push_out"):
				var res: Array = proto.building_push_out(
					proto.get("_building_collision_rects"),
					proto.get("_building_rect_index"), global_position, 0.35
				)
				global_position = res[0]
		else:
			if not is_on_floor():
				velocity.y -= GRAVITY * delta * physics_step
			else:
				velocity.y = 0.0
			var intended := Vector2(velocity.x, velocity.z).length()
			# move_and_slide 内部按物理 delta 积分：30Hz 节拍下速度翻倍调用，
			# 保证实际移动速度与全帧率一致
			var vx := velocity.x
			var vz := velocity.z
			velocity.x = vx * physics_step
			velocity.z = vz * physics_step
			move_and_slide()
			velocity.x = vx
			velocity.z = vz
			_update_stuck(delta * physics_step, intended)
	# 丧尸动画统一 20~30Hz（GLB AnimationPlayer 是尸潮开销大户），LOD2 再减半
	var anim_step := 3
	if _lod_level == 2:
		anim_step = 4
	if anim_step == 1 or (Engine.get_physics_frames() + _lod_phase) % anim_step == 0:
		var speed := Vector2(velocity.x, velocity.z).length()
		BlockyRig.update(_limbs, delta * anim_step, speed)


# —— 尸潮双模式 ——

# 管理器切换模式：隐藏/停用 GLB 骨架（crowd 由 proto3d 的 MultiMesh 统一绘制）
func set_horde_mode(mode: String) -> void:
	if mode == horde_mode:
		return
	horde_mode = mode
	# crowd：碰撞体整个禁用，物理世界完全不知道这些怪存在（宽相/接触/同步全免），
	# 子弹改用手动扫掠命中（bullet3d._sweep_zombies），命中判定不受影响
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = horde_mode == "crowd"
	var rig_root := _limbs.get("root", null) as Node3D
	if rig_root != null:
		rig_root.visible = horde_mode == "hero"
		rig_root.process_mode = (
			Node.PROCESS_MODE_INHERIT if horde_mode == "hero" else Node.PROCESS_MODE_DISABLED
		)


# 群演极简行为：只跑计时器（流血/攻击冷却）；
# 移动/朝向/贴身攻击由 proto3d 的批量驱动统一处理（快照 → worker → 回收）
func _crowd_tick(delta: float) -> void:
	if _dying:
		return
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _bleed_time > 0.0:
		_bleed_time -= delta
		_bleed_accum += _bleed_dps * delta
		if _bleed_accum >= 1.0:
			var tick := int(_bleed_accum)
			_bleed_accum -= float(tick)
			take_damage(tick)
			if hp <= 0:
				return
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_mult = 1.0


# 群演 MultiMesh 用的颜色（按 tier 着色，酸性更绿）
func crowd_color() -> Color:
	var color := Color(0.45, 0.62, 0.4)
	if is_acid:
		return Color(0.35, 0.8, 0.25)
	match zombie_tier:
		3:
			color = Color(0.5, 0.55, 0.45)
		4:
			color = Color(0.75, 0.72, 0.55)
		6:
			color = Color(0.35, 0.8, 0.3)
		8:
			color = Color(0.75, 0.4, 0.38)
		9:
			color = Color(0.55, 0.42, 0.7)
		10:
			color = Color(0.65, 0.35, 0.8)
	return color


# LOD 扫描频率倍率：近全频，中 ×2，远 ×4；尸潮规模（>100）时再 ×2
func _scan_mult() -> float:
	var mult := 1.0 if _lod_level == 0 else (2.0 if _lod_level == 1 else 4.0)
	if GameState.zombie_horde_size > 100:
		mult *= 2.0
	return mult


# 卡墙脱困：意图速度高但实际位移很低时，短暂侧向绕行
func _update_stuck(delta: float, intended: float) -> void:
	if _detour_time > 0.0:
		_detour_time -= delta
	if intended < 0.5:
		_stuck_time = 0.0
		return
	var actual := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if actual < intended * 0.25:
		_stuck_time += delta
		_stuck_total += delta
		if _stuck_time > 0.8:
			_detour_angle = randf_range(PI / 4.0, PI / 2.0) * (1.0 if randf() < 0.5 else -1.0)
			_detour_time = randf_range(0.6, 1.1)
			_stuck_time = 0.0
		if _stuck_total > 2.5:
			_stuck_total = 0.0
			_teleport_nudge()
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
		_stuck_total = 0.0


# 持续卡死 2.5 秒以上：向前方小幅瞬移脱困（只在目标位置无碰撞时）
func _teleport_nudge() -> void:
	var dir := -global_transform.basis.z
	dir.y = 0.0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	for dist in [0.8, 0.5, 0.3]:
		var params := PhysicsTestMotionParameters3D.new()
		params.from = global_transform
		params.motion = dir * dist
		if not PhysicsServer3D.body_test_motion(get_rid(), params):
			global_position += dir * dist
			return


func _chase_target() -> bool:
	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist < 0.05:
		return false
	var speed := SPEED * _speed_mult * _slow_mult
	var dir := to_target / dist
	if _detour_time > 0.0:
		dir = dir.rotated(Vector3.UP, _detour_angle)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	look_at(
		Vector3(_target.global_position.x, global_position.y, _target.global_position.z),
		Vector3.UP
	)
	if dist < _attack_range:
		_try_attack(_target)
	return true


func _move_toward(pos: Vector3, speed: float) -> bool:
	var to_pos := pos - global_position
	to_pos.y = 0.0
	if to_pos.length() < 1.0:
		return false
	var dir := to_pos.normalized()
	# 批次 274：前瞻绕障——目标方向近处有建筑挡路时，沿建筑边缘切向绕行
	# （比卡墙后才随机转向可靠；绕行中每 0.4s 重估，绕过楼角立即恢复直奔）
	var avoid := _avoid_angle(dir)
	if avoid != 0.0:
		dir = dir.rotated(Vector3.UP, avoid)
	if _detour_time > 0.0:
		dir = dir.rotated(Vector3.UP, _detour_angle)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	look_at(Vector3(pos.x, global_position.y, pos.z), Vector3.UP)
	return true


# 前瞻探测：目标方向 6m 处有建筑矩形 → 返回绕行角（朝最近边切向 ±90° 内），无遮挡返回 0
const AVOID_PROBE := 6.0

func _avoid_angle(dir: Vector3) -> float:
	var proto = get_parent()
	if proto == null or not proto.has_method("building_push_out"):
		return 0.0
	var probe := global_position + dir * AVOID_PROBE
	var rects: Array = proto.get("_building_collision_rects")
	var index: Dictionary = proto.get("_building_rect_index")
	var flat := Vector2(probe.x, probe.z)
	var cc := Vector2i(floori(flat.x / 20.0), floori(flat.y / 20.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for id in index.get(cc + Vector2i(dx, dz), []):
				var e: Dictionary = rects[int(id)]
				var rect: Rect2 = e["rect"]
				if not rect.has_point(flat):
					continue
				# 探针点落在建筑内 → 朝最近的边避让（x 边绕横向，z 边绕纵向）
				var dl: float = flat.x - rect.position.x
				var dr: float = rect.end.x - flat.x
				var dt: float = flat.y - rect.position.y
				var db: float = rect.end.y - flat.y
				var side := signf(dir.x) if minf(dl, dr) < minf(dt, db) else -signf(dir.z)
				# 沿选择轴的切向转 ±80°，配合原方向保留一点向目标的分量
				var angle := deg_to_rad(80.0) * (1.0 if side >= 0.0 else -1.0)
				return angle
	return 0.0


func _wander(delta: float) -> void:
	# 批次 261：白天（无目标、非留守、非袭营）按概率发起城市漫游——
	# 目标点 = 自身位置 ± 60~140m 的城市内随机点，让怪物散布全城而非聚在能量点
	_roam_timer -= delta
	if (
		_roam_target == Vector3.ZERO
		and _roam_timer <= 0.0
		and not GameState.is_night()
		and not _guarding()
		and assault_target == Vector3.ZERO
	):
		_roam_timer = randf_range(20.0, 40.0)
		if randf() < 0.5:
			var size := GameState.CITY_SIZE * 0.05
			var margin := 8.0
			_roam_target = Vector3(
				clampf(global_position.x + randf_range(-140.0, 140.0), margin, size.x - margin),
				0.0,
				clampf(global_position.z + randf_range(-140.0, 140.0), margin, size.y - margin)
			)
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.5, 4.0)
		if randf() < 0.5:
			_wander_angle = randf() * TAU
		else:
			_wander_angle = -1.0
	if _wander_angle < 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		velocity.x = cos(_wander_angle) * WANDER_SPEED * _speed_mult * _slow_mult
		velocity.z = sin(_wander_angle) * WANDER_SPEED * _speed_mult * _slow_mult
		# 游荡也面向行进方向（否则模型一直朝初始方向滑行）
		look_at(
			global_position + Vector3(cos(_wander_angle), 0.0, sin(_wander_angle)),
			Vector3.UP
		)


func _check_sighting() -> void:
	for npc in GameState.entities_in_group_in_radius(global_position, "npcs", 18.0):
		if npc.can_see_node(self):
			GameState.report_zombie_sighting(global_position)
			return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var camera = player.get_node_or_null("Camera3D")
	var from: Vector3 = player.global_position + Vector3(0, 1.6, 0)
	if camera != null:
		from = camera.global_position
	var to := global_position + Vector3(0, 1.0, 0)
	if from.distance_to(to) > 18.0:
		return
	if camera != null:
		var dir := (to - from).normalized()
		if camera.global_transform.basis.z.dot(dir) > -0.4:
			return
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty() and result.collider == self:
		GameState.report_zombie_sighting(global_position)


# 守关 Boss / Boss 能量场留守怪是否仍在守点
func _guarding() -> bool:
	if hold_radius > 0.0:
		return true
	return (
		is_boss
		and guard_zone != null
		and is_instance_valid(guard_zone)
		and not bool(guard_zone.get("destroyed"))
	)


func _find_target() -> Node3D:
	var best: Node3D = null
	var detect := _detect_range
	if zombie_tier == 9:
		detect *= TITAN_DETECT_MULT
	if _guarding():
		# 守点时侦测覆盖整个警戒圈（绕点徘徊半径 + 警戒圈）
		detect = GUARD_LEASH + GUARD_ROAM_RADIUS
	var best_dist := detect
	var player = get_tree().get_first_node_in_group("player")
	# 玩家藏匿在建筑里时不可被发现（藏匿市民已移出 npcs 组，哈希天然查不到）
	if player != null and not GameState.is_bad_zombie() and GameState.player_in_building.is_empty():
		var player_dist := global_position.distance_to(player.global_position)
		if player_dist < best_dist:
			best_dist = player_dist
			best = player
	var npc := GameState.nearest_entity_in_group(global_position, "npcs", best_dist) as Node3D
	if npc != null:
		var npc_dist := global_position.distance_to(npc.global_position)
		if npc_dist < best_dist:
			best_dist = npc_dist
			best = npc
	for remote in get_tree().get_nodes_in_group("remote_players"):
		var remote_dist := global_position.distance_to(remote.global_position)
		if remote_dist < best_dist:
			best_dist = remote_dist
			best = remote
	if assault_target != Vector3.ZERO:
		# 夜袭途中遇到据点防御设施（路障/炮塔）优先拆除
		var defense := GameState.nearest_entity_in_group(
			global_position, "base_defense", best_dist
		) as Node3D
		if defense != null:
			var defense_dist := global_position.distance_to(defense.global_position)
			if defense_dist < best_dist:
				best_dist = defense_dist
				best = defense
	if _guarding():
		# 守点期间只反击进入警戒圈（以能量点为圆心）的目标，圈外一概不理
		var leash := hold_radius if hold_radius > 0.0 else GUARD_LEASH
		if best != null and best.global_position.distance_to(guard_home) > leash:
			return null
		return best
	if best == null and is_boss and guard_zone != null:
		# 能量点已毁：主动进攻玩家/营地，取更近者
		var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
		var player_dist2 := INF
		if player != null and not GameState.is_bad_zombie():
			player_dist2 = global_position.distance_to(player.global_position)
		var base_dist := INF
		if GameState.has_home_base():
			base_dist = global_position.distance_to(base_pos)
		if player != null and player_dist2 <= base_dist:
			best = player
		elif GameState.has_home_base():
			assault_target = base_pos
	return best


func _try_attack(target: Node3D) -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_COOLDOWN / maxf(_attack_speed, 0.1)
	if zombie_tier == 9:
		_damage_area(TITAN_AOE_RADIUS, _damage)
		_spawn_ring(TITAN_AOE_RADIUS * 0.7)
		BlockyRig.play_once(_limbs, "attack-melee-right")
		return
	if is_hound:
		# 贴身用爪击，距离较远且扑击 CD 就绪用突进
		var hound_dist := global_position.distance_to(target.global_position)
		if hound_dist <= HOUND_CLAW_RANGE and _claw_cd <= 0.0:
			_start_claw(target)
		elif _pounce_cd <= 0.0:
			_start_pounce(target)
		return
	if is_spider:
		# 贴身用弱化扑击，4 身位内且喷毒 CD 就绪用喷毒
		var spider_dist := global_position.distance_to(target.global_position)
		if spider_dist <= SPIDER_POUNCE_RANGE and _sp_pounce_cd <= 0.0:
			_start_spider_pounce(target)
		elif spider_dist <= SPIDER_SPIT_RANGE and _spit_cd <= 0.0:
			_start_spit(target)
		return
	BlockyRig.play_once(
		_limbs, "attack-melee-left" if randf() < 0.5 else "attack-melee-right"
	)
	# 前摇 0.35 秒后才结算：给玩家反应窗口，冲刺（dash）期间闪过则本次无伤
	_windup = WINDUP_SECONDS
	_windup_target = target


# 变异猎犬突进：向后蓄力 0.5 秒，固定扑 10 身位（7m）
func _start_pounce(target: Node3D) -> void:
	if _pounce_cd > 0.0:
		return
	_pounce_cd = HOUND_POUNCE_CD
	_pounce_windup = HOUND_POUNCE_WINDUP
	_pounce_dist = HOUND_POUNCE_DIST
	_pounce_dir = target.global_position - global_position
	_pounce_dir.y = 0.0
	if _pounce_dir.length() < 0.05:
		_pounce_dir = -global_transform.basis.z
	_pounce_dir = _pounce_dir.normalized()


# 贴身爪击：前摇 0.3 秒的挥爪，可以被玩家近战打断
func _start_claw(target: Node3D) -> void:
	_claw_cd = HOUND_CLAW_CD
	_claw_windup = HOUND_CLAW_WINDUP
	_claw_target = target


# 爪击结算：玩家冲刺闪过则无伤（触发完美闪避）
func _resolve_claw() -> void:
	var target := _claw_target
	_claw_target = null
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if global_position.distance_to(target.global_position) > HOUND_CLAW_RANGE + 0.5:
		return
	if target.is_in_group("player") and float(target.get("_dash_left")) > 0.0:
		GameState.trigger_slowmo()
		return
	target.take_damage(HOUND_CLAW_DAMAGE)


# 猎犬移动状态机：硬直（仅爪击可被打断）> 爪击前摇 > 扑跃 > 扑击蓄力 > 追击
func _hound_move(delta: float) -> bool:
	_pounce_cd = maxf(_pounce_cd - delta, 0.0)
	_claw_cd = maxf(_claw_cd - delta, 0.0)
	if _stagger > 0.0:
		# 近战打断：只对爪子攻击生效，蓄力扑击不可打断
		_stagger -= delta
		_claw_windup = 0.0
		_claw_target = null
		_reset_dog_pose()
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	if _claw_windup > 0.0:
		# 啃咬前摇 0.3 秒：头部抬高后仰并放大，读招清晰
		_claw_windup -= delta
		var raise_t := clampf(1.0 - _claw_windup / HOUND_CLAW_WINDUP, 0.0, 1.0)
		if _head_root != null:
			_head_root.position = Vector3(0, 0.55 * raise_t, 0.1 * raise_t)
			_head_root.rotation.x = -0.25 * raise_t
			var head_scale := 1.0 + 0.35 * raise_t
			_head_root.scale = Vector3.ONE * head_scale
		velocity.x = 0.0
		velocity.z = 0.0
		if _claw_windup <= 0.0:
			_claw_swipe = 0.12
			_resolve_claw()
		return true
	if _claw_swipe > 0.0:
		# 啃咬：头部快速下砸收小
		_claw_swipe -= delta
		var swipe_t := clampf(1.0 - _claw_swipe / 0.12, 0.0, 1.0)
		if _head_root != null:
			_head_root.position = Vector3(0, 0.55 - swipe_t * 0.8, 0.1 - swipe_t * 0.15)
			_head_root.rotation.x = -0.25 + swipe_t * 0.7
			_head_root.scale = Vector3.ONE * (1.35 - swipe_t * 0.35)
		if _claw_swipe <= 0.0:
			_reset_dog_pose()
		return true
	if _pounce_leap > 0.0:
		# 扑跃中：带轻微跟踪修正，狗身在空中划出弧线
		_pounce_leap -= delta
		_pounce_leap_elapsed += delta
		if _dog_root != null and _pounce_leap_total > 0.0:
			var progress := clampf(_pounce_leap_elapsed / _pounce_leap_total, 0.0, 1.0)
			_dog_root.position.y = sin(progress * PI) * 0.9
		if _target != null and is_instance_valid(_target):
			var want := _target.global_position - global_position
			want.y = 0.0
			if want.length() > 0.05:
				_pounce_dir = _pounce_dir.lerp(want.normalized(), minf(1.0, delta * 3.0)).normalized()
		velocity.x = _pounce_dir.x * HOUND_POUNCE_SPEED
		velocity.z = _pounce_dir.z * HOUND_POUNCE_SPEED
		look_at(global_position + _pounce_dir, Vector3.UP)
		if not _pounce_hit_done:
			_try_pounce_hit()
		if _pounce_leap <= 0.0:
			_reset_dog_pose()
		return true
	if _pounce_windup > 0.0:
		# 蓄力：身体后缩下压，且持续朝玩家位置转向修正
		_pounce_windup -= delta
		if _target != null and is_instance_valid(_target):
			var want := _target.global_position - global_position
			want.y = 0.0
			if want.length() > 0.05:
				_pounce_dir = _pounce_dir.lerp(want.normalized(), minf(1.0, delta * 6.0)).normalized()
		if _dog_root != null:
			_dog_root.scale.y = 0.7
			_dog_root.position.y = -0.08
		velocity.x = -_pounce_dir.x * 1.2
		velocity.z = -_pounce_dir.z * 1.2
		look_at(global_position + _pounce_dir, Vector3.UP)
		if _pounce_windup <= 0.0:
			_reset_dog_pose()
			_pounce_leap_total = _pounce_dist / HOUND_POUNCE_SPEED
			_pounce_leap = _pounce_leap_total
			_pounce_leap_elapsed = 0.0
			_pounce_hit_done = false
		return true
	if _target == null:
		return false
	# 追击：进入触发范围且扑跃 CD 就绪才发起突进（由 _try_attack 触发）
	return _chase_target()


# 扑跃命中判定：贴身瞬间，玩家冲刺则无伤并触发完美闪避
func _try_pounce_hit() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or bool(player.get("_dead")):
		return
	if global_position.distance_to(player.global_position) > 1.0:
		return
	_pounce_hit_done = true
	_pounce_leap = 0.0
	_reset_dog_pose()
	if float(player.get("_dash_left")) > 0.0:
		GameState.trigger_slowmo()
		return
	player.take_damage(HOUND_POUNCE_DAMAGE)


# 猎犬丧尸犬模型（参考图：黑皮下裸露红肉与肋骨、獠牙大嘴、尖立耳、骨瘦四肢）
func _build_hound_model() -> void:
	var rig_root = _limbs.get("root")
	if rig_root != null and is_instance_valid(rig_root):
		rig_root.visible = false
	_dog_root = Node3D.new()
	add_child(_dog_root)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.09, 0.07, 0.09)
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.5, 0.11, 0.09)
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.78, 0.74, 0.64)
	var add_part := func(size: Vector3, pos: Vector3, material: StandardMaterial3D, rot := Vector3.ZERO) -> void:
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		part.mesh = box
		part.material_override = material
		part.position = pos
		part.rotation = rot
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dog_root.add_child(part)
	# 躯干（头朝 -Z）
	add_part.call(Vector3(0.34, 0.3, 0.95), Vector3(0, 0.45, 0.0), fur)
	# 两侧裸露的红肉 + 白骨肋条
	for side in [-1.0, 1.0]:
		add_part.call(Vector3(0.06, 0.2, 0.55), Vector3(side * 0.17, 0.47, 0.08), flesh)
		for i in 3:
			add_part.call(
				Vector3(0.03, 0.2, 0.08), Vector3(side * 0.2, 0.47, -0.1 + i * 0.18), bone
			)
	# 头部独立成组：啃咬动作时整组抬头/下砸
	_head_root = Node3D.new()
	_dog_root.add_child(_head_root)
	var add_head := func(size: Vector3, pos: Vector3, material: StandardMaterial3D, rot := Vector3.ZERO) -> void:
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		part.mesh = box
		part.material_override = material
		part.position = pos
		part.rotation = rot
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head_root.add_child(part)
	# 头 + 张开的血红下颚 + 獠牙
	add_head.call(Vector3(0.26, 0.2, 0.28), Vector3(0, 0.6, -0.55), fur)
	add_head.call(Vector3(0.16, 0.09, 0.18), Vector3(0, 0.49, -0.68), flesh)
	add_head.call(Vector3(0.13, 0.045, 0.16), Vector3(0, 0.55, -0.71), bone)
	# 尖立耳（参考图的大耳朵）
	add_head.call(Vector3(0.07, 0.2, 0.05), Vector3(-0.1, 0.8, -0.5), fur, Vector3(0.0, 0.0, 0.25))
	add_head.call(Vector3(0.07, 0.2, 0.05), Vector3(0.1, 0.8, -0.5), fur, Vector3(0.0, 0.0, -0.25))
	# 骨瘦四肢 + 红色关节
	for sx in [-1.0, 1.0]:
		for sz in [-0.3, 0.32]:
			add_part.call(Vector3(0.1, 0.14, 0.1), Vector3(sx * 0.11, 0.32, sz), flesh)
			add_part.call(Vector3(0.07, 0.28, 0.07), Vector3(sx * 0.11, 0.14, sz), fur)
	# 细骨尾
	add_part.call(Vector3(0.05, 0.05, 0.4), Vector3(0, 0.6, 0.62), fur, Vector3(-0.7, 0.0, 0.0))
	# 两只前爪（可动部件：挥爪动作时抬放）
	_paw_l = MeshInstance3D.new()
	var paw_l_box := BoxMesh.new()
	paw_l_box.size = Vector3(0.09, 0.2, 0.09)
	_paw_l.mesh = paw_l_box
	_paw_l.material_override = flesh
	_paw_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paw_l.position = PAW_BASE_L
	_dog_root.add_child(_paw_l)
	_paw_r = MeshInstance3D.new()
	var paw_r_box := BoxMesh.new()
	paw_r_box.size = Vector3(0.09, 0.2, 0.09)
	_paw_r.mesh = paw_r_box
	_paw_r.material_override = flesh
	_paw_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paw_r.position = PAW_BASE_R
	_dog_root.add_child(_paw_r)


# 玩家近战命中：猎犬扑击中不可打断（其他状态硬直 0.5s）；狼蛛吃 120% 近战伤害且硬直 0.6s
func take_melee_damage(amount: int) -> void:
	if is_spider:
		amount = maxi(1, int(amount * 1.2))
	take_damage(amount, true)
	if is_hound and not _dying and _pounce_windup <= 0.0 and _pounce_leap <= 0.0:
		_stagger = 0.5
	# 狼蛛：硬直更短（0.3s）；已经做出攻击动作（喷毒前摇/连发/扑击）时不可打断
	if (
		is_spider
		and not _dying
		and _spit_windup <= 0.0
		and _spit_left <= 0
		and _sp_pounce_windup <= 0.0
		and _sp_pounce_leap <= 0.0
	):
		_stagger = 0.3


# 恢复狗身姿态（扑跃/蓄力/啃咬结束或被僵直打断后）
func _reset_dog_pose() -> void:
	if _dog_root == null:
		return
	_dog_root.position.y = 0.0
	_dog_root.scale.y = 1.0
	_dog_root.rotation.x = 0.0
	if _head_root != null:
		_head_root.rotation.x = 0.0
		_head_root.position = Vector3.ZERO
		_head_root.scale = Vector3.ONE
	_pose_paws(0.0, 0.0)


# 前爪位置驱动：up 抬起高度、fwd 前伸距离
func _pose_paws(up: float, fwd: float) -> void:
	if _paw_l != null:
		_paw_l.position = PAW_BASE_L + Vector3(0, up, fwd)
		_paw_l.rotation.x = -up * 2.5
	if _paw_r != null:
		_paw_r.position = PAW_BASE_R + Vector3(0, up, fwd)
		_paw_r.rotation.x = -up * 2.5


# 异变狼蛛模型（参考图：球腹尖刺、黑壳红缝、四只分节长腿）
func _build_spider_model() -> void:
	var rig_root = _limbs.get("root")
	if rig_root != null and is_instance_valid(rig_root):
		rig_root.visible = false
	_spider_root = Node3D.new()
	add_child(_spider_root)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.07, 0.06, 0.08)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.85, 0.15, 0.05)
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.12, 0.03)
	glow.emission_energy_multiplier = 1.8
	var add_part := func(size: Vector3, pos: Vector3, material: StandardMaterial3D, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		part.mesh = box
		part.material_override = material
		part.position = pos
		part.rotation = rot
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(parent if parent != null else _spider_root).add_child(part)
		return part
	# 球腹（后部隆起）+ 背刺 + 红色裂缝
	add_part.call(Vector3(0.55, 0.42, 0.55), Vector3(0, 0.5, 0.3), shell)
	add_part.call(Vector3(0.12, 0.22, 0.1), Vector3(-0.15, 0.78, 0.3), shell, Vector3(0.0, 0.0, 0.4))
	add_part.call(Vector3(0.12, 0.26, 0.1), Vector3(0.0, 0.82, 0.32), shell)
	add_part.call(Vector3(0.12, 0.22, 0.1), Vector3(0.15, 0.78, 0.3), shell, Vector3(0.0, 0.0, -0.4))
	add_part.call(Vector3(0.5, 0.05, 0.08), Vector3(0, 0.55, 0.28), glow)
	add_part.call(Vector3(0.08, 0.05, 0.45), Vector3(0.18, 0.56, 0.3), glow)
	# 头胸部 + 红色口器
	add_part.call(Vector3(0.34, 0.26, 0.32), Vector3(0, 0.42, -0.25), shell)
	add_part.call(Vector3(0.16, 0.1, 0.12), Vector3(0, 0.34, -0.44), glow)
	# 四只分节长腿：上段外展、下段垂地
	var leg_defs := [
		{"root": Vector3(-0.25, 0.45, -0.2), "dir": -1.0},
		{"root": Vector3(0.25, 0.45, -0.2), "dir": 1.0},
		{"root": Vector3(-0.28, 0.45, 0.35), "dir": -1.0},
		{"root": Vector3(0.28, 0.45, 0.35), "dir": 1.0},
	]
	for leg in leg_defs:
		var root_pos: Vector3 = leg["root"]
		var dir_sign: float = leg["dir"]
		var leg_node := Node3D.new()
		leg_node.position = root_pos
		_spider_root.add_child(leg_node)
		# 上段：斜向上外展
		add_part.call(
			Vector3(0.09, 0.5, 0.09), Vector3(dir_sign * 0.28, 0.18, 0.0), shell,
			Vector3(0.0, 0.0, dir_sign * 0.9), leg_node
		)
		# 下段：垂到地面
		add_part.call(
			Vector3(0.07, 0.55, 0.07), Vector3(dir_sign * 0.5, -0.22, 0.0), shell,
			Vector3(0.0, 0.0, dir_sign * -0.15), leg_node
		)
		# 关节红缝
		add_part.call(Vector3(0.1, 0.08, 0.1), Vector3(dir_sign * 0.47, 0.02, 0.0), glow, Vector3.ZERO, leg_node)
	_reset_spider_pose()


func _reset_spider_pose() -> void:
	if _spider_root == null:
		return
	_spider_root.rotation.x = 0.0
	_spider_root.position.y = 0.0
	_spider_root.scale.y = 1.0


# 狼蛛移动状态机：硬直 > 弱化扑击 > 喷毒（前摇+三连发）> 追击
func _spider_move(delta: float) -> bool:
	_spit_cd = maxf(_spit_cd - delta, 0.0)
	_sp_pounce_cd = maxf(_sp_pounce_cd - delta, 0.0)
	if _stagger > 0.0:
		_stagger -= delta
		_sp_pounce_windup = 0.0
		_sp_pounce_leap = 0.0
		_reset_spider_pose()
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	if _sp_pounce_leap > 0.0:
		# 弱化扑击：比猎犬慢，短距前扑
		_sp_pounce_leap -= delta
		_sp_pounce_elapsed += delta
		if _spider_root != null:
			var progress := clampf(_sp_pounce_elapsed / (SPIDER_POUNCE_DIST / SPIDER_POUNCE_SPEED), 0.0, 1.0)
			_spider_root.position.y = sin(progress * PI) * 0.5
		velocity.x = _sp_pounce_dir.x * SPIDER_POUNCE_SPEED
		velocity.z = _sp_pounce_dir.z * SPIDER_POUNCE_SPEED
		look_at(global_position + _sp_pounce_dir, Vector3.UP)
		if not _sp_pounce_hit:
			_try_spider_pounce_hit()
		if _sp_pounce_leap <= 0.0:
			_reset_spider_pose()
		return true
	if _sp_pounce_windup > 0.0:
		# 蓄力 0.4 秒：压低蓄势
		_sp_pounce_windup -= delta
		if _spider_root != null:
			_spider_root.scale.y = 0.75
			_spider_root.position.y = -0.05
		velocity.x = -_sp_pounce_dir.x * 0.8
		velocity.z = -_sp_pounce_dir.z * 0.8
		look_at(global_position + _sp_pounce_dir, Vector3.UP)
		if _sp_pounce_windup <= 0.0:
			_reset_spider_pose()
			_sp_pounce_leap = SPIDER_POUNCE_DIST / SPIDER_POUNCE_SPEED
			_sp_pounce_elapsed = 0.0
			_sp_pounce_hit = false
		return true
	if _spit_left > 0:
		# 喷毒中：缩起，按间隔连发
		_spit_timer -= delta
		if _spider_root != null:
			_spider_root.position.y = -0.06
		velocity.x = 0.0
		velocity.z = 0.0
		if _spit_timer <= 0.0:
			_spit_timer = SPIDER_SPIT_INTERVAL
			_spit_left -= 1
			_fire_venom()
		if _spit_left <= 0:
			_reset_spider_pose()
		return true
	if _spit_windup > 0.0:
		# 喷毒前摇 0.3 秒：四足站立撑起（前身抬起）
		_spit_windup -= delta
		if _spider_root != null:
			_spider_root.rotation.x = -0.45 * clampf(1.0 - _spit_windup / SPIDER_SPIT_WINDUP, 0.0, 1.0)
		velocity.x = 0.0
		velocity.z = 0.0
		if _spit_windup <= 0.0:
			_spit_left = SPIDER_SPIT_COUNT
			_spit_timer = 0.0
		return true
	if _target == null:
		return false
	return _chase_target()


func _start_spit(target: Node3D) -> void:
	if _spit_cd > 0.0:
		return
	_spit_cd = SPIDER_SPIT_CD
	_spit_windup = SPIDER_SPIT_WINDUP
	_spit_dir = target.global_position - global_position
	_spit_dir.y = 0.0
	if _spit_dir.length() < 0.05:
		_spit_dir = -global_transform.basis.z
	_spit_dir = _spit_dir.normalized()


# 可被普通攻击击破的毒液实体：完全自驱动（不依赖喷吐者的物理处理，
# 喷吐者死亡/远距离 LOD 停跑时毒液照常飞行、撞物/超程/超时消失，不会残留在地图上）
class VenomShot extends StaticBody3D:
	const SPEED := 9.0
	const MAX_DIST := 8.4
	const DAMAGE := 5
	const POISON := 10.0
	const MAX_LIFE := 1.6  # 兜底寿命：任何情况下都不会永久残留

	var _dir := Vector3.FORWARD
	var _traveled := 0.0
	var _life := 0.0


	func take_damage(_amount: int) -> void:
		queue_free()


	func _physics_process(delta: float) -> void:
		_life += delta
		if _life >= MAX_LIFE:
			queue_free()
			return
		var player = get_tree().get_first_node_in_group("player")
		# 追踪修正：朝玩家位置缓慢转向
		if player != null:
			var want: Vector3 = player.global_position - global_position
			want.y = 0.0
			if want.length() > 0.05:
				_dir = _dir.lerp(want.normalized(), minf(1.0, delta * 2.5)).normalized()
		var step: Vector3 = _dir * SPEED * delta
		# 撞到任何场景物体（墙/建筑/道具）立即消失，不穿墙（玩家除外）
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step)
		query.collision_mask = 1
		if player != null:
			query.exclude = [player.get_rid()]
		if not space.intersect_ray(query).is_empty():
			queue_free()
			return
		global_position += step
		_traveled += step.length()
		# 命中：5 伤害 + 10 秒中毒
		if player != null and not bool(player.get("_dead")):
			if global_position.distance_to(player.global_position + Vector3(0, 1.0, 0)) <= 1.0:
				if float(player.get("_dash_left")) > 0.0:
					GameState.trigger_slowmo()
				else:
					player.take_damage(DAMAGE)
					GameState.apply_poison(POISON)
				queue_free()
				return
		if _traveled >= MAX_DIST:
			queue_free()


# 喷出一发紫色毒液：水滴状小球（可被打破），飞行中带追踪修正
func _fire_venom() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var want: Vector3 = player.global_position - global_position
		want.y = 0.0
		if want.length() > 0.05:
			_spit_dir = want.normalized()
	var drop := VenomShot.new()
	drop.collision_layer = 1
	drop.collision_mask = 0
	drop.add_to_group("venom_shot")
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.3
	shape.shape = sphere_shape
	drop.add_child(shape)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	# 水滴大小约为角色的一半
	sphere.radius = 0.3
	sphere.height = 0.75
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.2, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.5, 0.15, 0.8)
	material.emission_energy_multiplier = 2.0
	mesh.material_override = material
	drop.add_child(mesh)
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector3(0, 0.4, 0) + _spit_dir * 0.4
	mesh.rotation.x = PI / 2.0
	drop._dir = _spit_dir
	# 只记录引用供喷吐者死亡时一并清理；移动/消失全由 VenomShot 自身驱动
	_venom_shots.append(drop)


# 清理所有飞行中的毒液（狼蛛死亡/场景切换时调用）
func _clear_venom() -> void:
	for node in _venom_shots:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_venom_shots.clear()


# 弱化扑击（猎犬扑击的削弱版：速度慢、距离短）
func _start_spider_pounce(target: Node3D) -> void:
	if _sp_pounce_cd > 0.0:
		return
	_sp_pounce_cd = SPIDER_POUNCE_CD
	_sp_pounce_windup = SPIDER_POUNCE_WINDUP
	_sp_pounce_dir = target.global_position - global_position
	_sp_pounce_dir.y = 0.0
	if _sp_pounce_dir.length() < 0.05:
		_sp_pounce_dir = -global_transform.basis.z
	_sp_pounce_dir = _sp_pounce_dir.normalized()


# 扑击命中：20 伤害 + 5% 概率 5 秒中毒；玩家冲刺闪过则无伤
func _try_spider_pounce_hit() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or bool(player.get("_dead")):
		return
	if global_position.distance_to(player.global_position) > 1.1:
		return
	_sp_pounce_hit = true
	_sp_pounce_leap = 0.0
	_reset_spider_pose()
	if float(player.get("_dash_left")) > 0.0:
		GameState.trigger_slowmo()
		return
	player.take_damage(SPIDER_MELEE_DAMAGE)
	if randf() < SPIDER_MELEE_POISON_CHANCE:
		GameState.apply_poison(SPIDER_MELEE_POISON_SECONDS)


func _resolve_windup() -> void:
	var target := _windup_target
	_windup_target = null
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	# 冲刺无敌帧：伤害结算瞬间玩家在冲刺 → 无伤闪过，触发完美闪避缓速
	if target.is_in_group("player") and float(target.get("_dash_left")) > 0.0:
		GameState.trigger_slowmo()
		return
	if global_position.distance_to(target.global_position) > _attack_range + 0.6:
		return
	# 批次 263：目标玩家藏匿在建筑里 → 抓挠转攻建筑本体（围攻）；
	# 建筑血尽坍塌会把藏匿者全部驱赶到门口（demolish3d.siege_damage_at）
	if target.is_in_group("player") and not GameState.player_in_building.is_empty():
		var city := get_parent()
		if city != null:
			var dm = city.get_node_or_null("Demolish")
			if dm != null and dm.has_method("siege_damage_at"):
				dm.call("siege_damage_at", target.global_position, _damage)
				BlockyRig.play_once(_limbs, "attack-melee-right")
		return
	target.take_damage(_damage)
	# 普通丧尸与猎犬（tier 0/1/2）抓挠不感染；高阶怪保留感染
	if target.is_in_group("player") and not GameState.is_zombie() and zombie_tier > 2:
		GameState.try_infect_player()
	if is_boss and target.has_method("take_damage"):
		var push := target.global_position - global_position
		push.y = 0.0
		if push.length() > 0.1 and "velocity" in target:
			target.velocity += push.normalized() * 6.0
	elif _tier_knockback and "velocity" in target:
		var push := target.global_position - global_position
		push.y = 0.0
		if push.length() > 0.1:
			target.velocity += push.normalized() * 4.0


func _shockwave() -> void:
	_damage_area(TITAN_SHOCK_RADIUS, int(_damage * 1.2))
	_spawn_ring(TITAN_SHOCK_RADIUS)
	GameState.noise_at(global_position, 45.0)


func _damage_area(radius: float, dmg: int) -> void:
	for npc in GameState.entities_in_group_in_radius(global_position, "npcs", radius):
		if npc == self:
			continue
		npc.take_damage(dmg, self)
	var player = get_tree().get_first_node_in_group("player")
	if (
		player != null
		and not GameState.is_bad_zombie()
		and global_position.distance_to(player.global_position) <= radius
	):
		player.take_damage(dmg)
		GameState.try_infect_player()
	for remote in get_tree().get_nodes_in_group("remote_players"):
		if global_position.distance_to(remote.global_position) <= radius:
			remote.take_damage(dmg)


func _spawn_ring(radius: float) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 0.3
	mesh.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.3, 0.6, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	get_parent().add_child(mesh)
	mesh.global_position = global_position + Vector3(0, 0.5, 0)
	mesh.scale = Vector3(radius * 0.4, 1.0, radius * 0.4)
	var tween := mesh.create_tween()
	tween.tween_property(
		mesh, "scale", Vector3(radius, 1.0, radius), 0.45
	).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(mesh.queue_free)


func _summon_minions() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in 2:
		var zombie = preload("res://scenes3d/zombie3d.tscn").instantiate()
		zombie.zombie_tier = 1
		parent.add_child(zombie)
		zombie.global_position = global_position + Vector3(
			randf_range(-3.0, 3.0), 0.3, randf_range(-3.0, 3.0)
		)


func _try_spit() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or GameState.is_bad_zombie():
		return
	var dist := global_position.distance_to(player.global_position)
	if dist > 12.0 or not _line_to(player):
		return
	player.take_damage(5)
	GameState.use_stamina(22.0)
	GameState.notify("被酸液喷中，体力下降")


func _line_to(target: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.2, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == target


func take_damage(amount: int, is_melee := false) -> void:
	if net_puppet:
		if Network.is_multiplayer():
			Network.request_entity_damage(net_id, amount)
		return
	if _dying:
		return
	# 狼蛛：枪械类伤害 80%（近战入口单独乘 120%，不走这里）
	if is_spider and not is_melee:
		amount = maxi(1, int(amount * 0.8))
	# 正护甲减伤、负护甲（猎犬）增伤
	if _resist != 0.0:
		amount = maxi(1, int(round(float(amount) * (1.0 - _resist))))
	hp -= amount
	if hp <= 0:
		_dying = true
		# 死亡时清掉还在飞行中的毒液，否则永远留在地图上
		_clear_venom()
		if _dog_root != null:
			# 猎犬死亡：狗身侧倒（简单可靠，不播人形骨架的死亡动画）
			_dog_root.rotation.z = PI / 2.0
			_dog_root.position.y = 0.1
		Network.unregister_entity(self)
		if not Network.is_multiplayer() or Network.is_server():
			GameState.boss_killed(zombie_tier)
			GameState.note_zombie_slain()
		_drop_loot()
		if not BlockyRig.play_death(_limbs):
			queue_free()
			return
		set_physics_process(false)
		var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", true)
		# 暂停中也照常释放尸体，避免尸体节点滞留组里（小地图红点残留）
		var tween := get_tree().create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(1.4)
		tween.tween_callback(queue_free)


func take_damage_authoritative(amount: int, _from_peer: int) -> void:
	take_damage(amount)


func _drop_loot() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# 批次 281：怪物只掉 异常结晶 / 经验球 / 特殊素材（Boss 专属材料），不掉其它物品
	# 经验球：击杀经验改为掉落拾取（谁捡归谁）
	var exp_orbs := 1 + zombie_tier / 3
	for i in exp_orbs:
		var ea := randf() * TAU
		var er := randf_range(0.2, 0.5)
		PICKUP_DROP.spawn_merged(
			parent, "exp",
			global_position + Vector3(cos(ea) * er, 0.1, sin(ea) * er),
			1, "经验球"
		)
	# 异常结晶：受异能影响的个体必掉；异界精英按 tier 递增，越强大掉越多
	var drops := _crystal_drop_count()
	for i in drops:
		var angle := randf() * TAU
		var r := randf_range(0.3, 0.6 + drops * 0.15)
		PICKUP_DROP.spawn_merged(
			parent, "anomaly",
			global_position + Vector3(cos(angle) * r, 0.1, sin(angle) * r),
			1, "异能结晶"
		)
	# Boss 专属材料：每种 Boss 掉落不同的专属材料，供后续图纸解锁（设计文档 4.4）
	if is_boss:
		var relic := _boss_relic_name()
		if not relic.is_empty():
			PICKUP_DROP.spawn_merged(
				parent, "relic",
				global_position + Vector3(0, 0.2, 0),
				1, relic
			)


func _boss_relic_name() -> String:
	match zombie_tier:
		7:
			return "尸王核心"
		8:
			return "尸皇之血"
		9:
			return "尸神之息"
		_:
			return ""


# 结晶掉落数：被异能量感染的必掉 1；精英 tier 1+ 递增，尸神 6 颗
func _crystal_drop_count() -> int:
	if zombie_tier >= 10:
		return 6
	if zombie_tier >= 6:
		return 3
	if zombie_tier >= 3:
		return 2
	if zombie_tier >= 1:
		return 1
	if has_meta("anomaly_touched"):
		return 1
	return 0
