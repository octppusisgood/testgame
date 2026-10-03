extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_MULT := 1.7
const GRAVITY := 30.0
const STAMINA_DRAIN := 22.0
const STAMINA_REGEN := 16.0
const SPRINT_SATIETY_DRAIN := 1.6
const MAX_RANGE := 120.0
const MELEE_REACH := 2.4
const JUMP_VELOCITY := 8.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN_MSEC := 1000
const DASH_GHOST_INTERVAL := 0.03
const KATA_RADIUS := 8.0
const HUNGER_STAMINA_FACTOR := 1.5
# 2.5D 斜俯视角：正交相机固定在 (-52°, 45°) 方向，斜上方跟随玩家
const CAM_YAW := PI / 4.0
const CAM_ROTATION := Vector3(-0.9076, 0.7854, 0.0)
const CAM_OFFSET := Vector3(17.39, 31.51, 17.39)
const CAM_SIZE := 24.0
const CAM_FOLLOW := 8.0
const SCOPE_FOLLOW := 6.0
const OCCLUSION_ALPHA := 0.2
const VM_GUN_SCALE := 0.55
const BODY_COLOR := Color(0.16, 0.16, 0.18)
const ACCENT_COLOR := Color(0.3, 0.3, 0.33)
const WOOD_COLOR := Color(0.35, 0.25, 0.18)
const BLADE_COLOR := Color(0.75, 0.78, 0.82)
const BULLET_SCENE := preload("res://scenes3d/bullet3d.tscn")
const WEAPON_DROP_SCENE := preload("res://scenes3d/weapon_drop3d.tscn")
const EXPLOSIVE_SCENE := preload("res://scenes3d/explosive3d.tscn")

@onready var camera: Camera3D = $Camera3D
# 正交相机基准尺寸（狙击专注模式放大用）
var _base_cam_size := 0.0
@onready var viewmodel: Node3D = $Camera3D/Viewmodel

var kills := 0
var vehicle: Node3D = null

var _aim_point := Vector3.ZERO
var _dash_left := 0.0
var _dash_dir := Vector3.ZERO
var _dash_next_msec := 0
var _dash_boost_until := 0
var _dash_regen_until := 0
# 本次闪避的距离倍率（疾风强化闪避为 2.0）
var _dash_dist_mult := 1.0
var _dash_hits := {}
var _ghost_timer := 0.0
var _kata_shots_left := 0
# 手枪·清空弹匣：剩余速射发数与下一发时刻（0 = 未激活）
var _fan_shots_left := 0
var _fan_next_msec := 0
var _kata_timer := 0.0
var _kata_flick := 0.0
var _sprint_held := false
var _last_tap := {
	"move_left": -999999, "move_right": -999999,
	"move_up": -999999, "move_down": -999999,
}
var _scoping := false
# 狙击右键·专注模式：5 秒视野扩大+贯穿（限时技能，不是状态切换）
var _sniper_focus_until := 0
var _aim_ring: MeshInstance3D = null
var _aim_laser: MeshInstance3D = null
# 近战旋风斩：本次挥击跳过扇形角度判定（360°）
var _spin_attack := false
# 重机枪架设状态：不能移动，无限子弹
var _deployed := false
var _occl_timer := 0.0
var _faded := {}
# 玩家所在楼的外壳件（墙/顶/窗）→ 登记的矩形，离开后恢复
var _hidden_shells := {}
var _next_shot_msec := 0
var _notice_msec := 0
var _invulnerable_until := 0
var _dead := false
var _vehicle_switch_msec := 0
var _weapon_models := {}
var _weapon_flashes := {}
var _muzzle_flash: MeshInstance3D = null
var _recoil := 0.0
# 连射扩散：每发 +0.35，每秒回落 1.4，封顶 2.0
var _bloom := 0.0
var _flash_timer := 0.0
var _net_timer := 0.0
var _raise := 0.0
var _trigger_down := false
var _body_root: Node3D
var _body_mesh: MeshInstance3D
var _body_limbs := {}
var _tp_gun_root: Node3D = null
var _gun_defs := {}
var _shirt_color := Color(0.2, 0.4, 0.7)
var _pants_color := Color(0.2, 0.2, 0.25)
var _jail_barrier: StaticBody3D = null
var _swing_side := 1
var _swing_tween: Tween = null
var _shake := 0.0
var _jab := 0.0
var _melee_tool_id := ""
var _nv_on := false
var _flashlight_on := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.player_died.connect(_on_died)
	GameState.weapons_changed.connect(_refresh_viewmodel)
	GameState.disguise_changed.connect(_on_disguise_changed)
	GameState.jailed.connect(_on_jailed)
	if Network.is_multiplayer():
		Network.player_hit.connect(_on_network_hit)
	_build_viewmodels()
	_refresh_viewmodel()
	if GameState.melee_item != "":
		_refresh_melee_tool()
	_body_root = Node3D.new()
	add_child(_body_root)
	_body_mesh = MeshInstance3D.new()
	_body_root.add_child(_body_mesh)
	_shirt_color = Color.from_hsv(randf(), 0.35, 0.8)
	_pants_color = Color.from_hsv(randf(), 0.25, 0.45)
	_body_limbs = BlockyRig.build(_body_root, null, {"model": "f"})
	_tp_gun_root = Node3D.new()
	if BlockyRig.attach_gun(_body_limbs, _tp_gun_root, true):
		_refresh_tp_gun()
	else:
		_tp_gun_root = null
	_setup_camera()
	_build_aim_ring()
	_build_lights()
	if GameState.test_mode:
		GameState.notify("测试模式：无敌 · 全武器 · 全能力 · 出生点旁展示全部 20 种单位")


func _process(delta: float) -> void:
	# 完美闪避缓速：玩家所有逻辑按真实时间走，不随全局减速
	if GameState.slowmo_active and Engine.time_scale > 0.001:
		delta /= Engine.time_scale
	# 切到非狙击枪时强制退出瞄准与专注
	if _scoping and GameState.current_weapon != "sniper":
		_scoping = false
	if _sniper_focus_until > 0 and GameState.current_weapon != "sniper":
		_sniper_focus_until = 0
	if Network.is_multiplayer():
		_net_timer -= delta
		if _net_timer <= 0.0:
			_net_timer = 1.0 / 12.0
			var moving := Vector2(velocity.x, velocity.z).length() > 0.3
			Network.broadcast_state(global_position, rotation.y, moving)
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	_raise = move_toward(_raise, 0.0, delta * 4.0)
	_shake = move_toward(_shake, 0.0, delta * 6.0)
	_jab = move_toward(_jab, 0.0, delta * 4.5)
	if GameState.melee_item != _melee_tool_id:
		_refresh_melee_tool()
	_update_camera(delta)
	_update_lights()
	if _aim_ring != null:
		_aim_ring.visible = (
			vehicle == null
			and not _dead
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		)
		if _aim_ring.visible:
			_aim_ring.global_position = Vector3(_aim_point.x, 0.0, _aim_point.z) + Vector3(0.0, 0.08, 0.0)
	# 瞄准激光线：开镜时从枪口连到红圈
	if _aim_laser != null:
		var laser_on := (
			_scoping and not _dead and vehicle == null and _aim_ring != null and _aim_ring.visible
		)
		_aim_laser.visible = laser_on
		if laser_on:
			var laser_from := _muzzle_world_pos(_aim_dir_3d())
			var laser_to := Vector3(_aim_point.x, _aim_point.y + 0.15, _aim_point.z)
			var laser_len := laser_from.distance_to(laser_to)
			_aim_laser.global_position = (laser_from + laser_to) / 2.0
			_aim_laser.scale = Vector3(1.0, 1.0, laser_len)
			_aim_laser.look_at(laser_to, Vector3.UP)
	if _tp_gun_root != null:
		_tp_gun_root.visible = vehicle == null and not _dead
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var weapon_id := GameState.current_weapon
	_body_limbs["aiming"] = (
		weapon_id in GameState.WEAPONS
		and not bool(GameState.WEAPONS[weapon_id].get("melee", false))
	)
	BlockyRig.update(_body_limbs, delta, flat_speed)
	_pose_tp_arms(delta)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and _muzzle_flash != null:
			_muzzle_flash.visible = false
	# 连射扩散回落
	_bloom = maxf(_bloom - delta * 1.4, 0.0)


func _setup_camera() -> void:
	camera.top_level = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAM_SIZE
	_base_cam_size = CAM_SIZE
	camera.global_position = global_position + CAM_OFFSET
	camera.global_rotation = CAM_ROTATION
	viewmodel.visible = false


func _build_aim_ring() -> void:
	_aim_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.38
	torus.rings = 24
	torus.ring_segments = 6
	_aim_ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.4, 0.3, 0.85)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_ring.material_override = material
	_aim_ring.top_level = true
	_aim_ring.visible = false
	add_child(_aim_ring)
	# 瞄准激光线：枪口到红圈的红色指示线，无视一切遮挡
	_aim_laser = MeshInstance3D.new()
	var laser_box := BoxMesh.new()
	laser_box.size = Vector3(0.025, 0.025, 1.0)
	_aim_laser.mesh = laser_box
	var laser_material := StandardMaterial3D.new()
	laser_material.albedo_color = Color(1.0, 0.15, 0.1, 0.85)
	laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_material.emission_enabled = true
	laser_material.emission = Color(1.0, 0.1, 0.05)
	laser_material.emission_energy_multiplier = 3.0
	laser_material.no_depth_test = true
	laser_material.render_priority = 10
	_aim_laser.material_override = laser_material
	_aim_laser.top_level = true
	_aim_laser.visible = false
	add_child(_aim_laser)


# 照明手段：只做判定圈（proto3d 读取标志绘制），不设真实光源
func _build_lights() -> void:
	pass


# 夜视：夜晚且持有回响·夜视时生效；手电筒按 T 开关，跟随身体朝向瞄准方向
func _update_lights() -> void:
	_nv_on = GameState.is_night() and GameState.has_echo("e_night_vision")


func _toggle_flashlight() -> void:
	if GameState.loot_count("flashlight") <= 0:
		GameState.notify("背包里没有手电筒（民居、办公室、仓库的柜子里可能翻到）")
		return
	_flashlight_on = not _flashlight_on
	GameState.notify("手电筒%s" % ("已打开" if _flashlight_on else "已关闭"))


# 狙击专注是否生效中（5 秒限时）
func _sniper_focused() -> bool:
	return Time.get_ticks_msec() < _sniper_focus_until


# 狙击专注放大倍率：无镜 1.4×，红点 ~2.0×，二倍 ~2.2×，四倍 ~2.5×，八倍 3.0×
func _sniper_zoom() -> float:
	var view := float(GameState.scopes.get("sniper", 0.0))
	return 1.4 + view / 70.0 * 1.6


# 开镜时相机视野中心直接对齐实际瞄准点，松开右键回到跟随玩家
func _update_camera(delta: float) -> void:
	var focus := _aim_point if _scoping else global_position
	var follow := SCOPE_FOLLOW if _scoping else CAM_FOLLOW
	var target := focus + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * follow))
	camera.global_rotation = CAM_ROTATION
	# 狙击专注模式：正交尺寸按瞄准镜倍率放大（无镜 1.4× ~ 八倍镜 3.0×）
	var size_target := _base_cam_size * (_sniper_zoom() if _sniper_focused() else 1.0)
	camera.size = lerpf(camera.size, size_target, minf(1.0, delta * 6.0))
	if _shake > 0.001:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.012
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.012
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


# 右键特殊技能分派（各武器独立冷却，CD 由 GameState.use_skill 统一管理）
func _try_special() -> void:
	match GameState.current_weapon:
		"melee", "":
			_special_spin()
		"pistol":
			_special_fan_fire()
		"smg":
			_special_smg_wind()
		"rifle":
			_special_rifle_grenade()
		"shotgun":
			_special_dragon_breath()
		"sniper":
			# 狙击：5 秒专注模式——视野扩大 + 子弹贯穿（限时技能）
			if GameState.use_skill("sniper"):
				_sniper_focus_until = Time.get_ticks_msec() + 5000
				GameState.notify("狙击专注 5 秒：视野扩大+贯穿")
		"lmg":
			_special_deploy()


# 近战·旋风斩：360° 一圈攻击周围所有敌人
func _special_spin() -> void:
	if not GameState.use_skill("melee"):
		return
	_spin_attack = true
	# 旋风斩：150% 近战伤害
	var base := GameState.melee_base_damage()
	_start_melee(int(base * GameState.melee_damage_mult() * 1.5))
	_animate_spin()
	GameState.notify("旋风斩！")


# 旋风斩武器动画：近战武器模型原地旋转一整圈（覆盖普通挥砍动作）
func _animate_spin() -> void:
	var model: Node3D = _weapon_models.get("melee")
	if model == null or not model.visible:
		return
	if _swing_tween != null and is_instance_valid(_swing_tween) and _swing_tween.is_valid():
		_swing_tween.kill()
	model.rotation = Vector3.ZERO
	_swing_tween = model.create_tween()
	_swing_tween.tween_property(
		model, "rotation:y", TAU, 0.3
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_callback(func() -> void: model.rotation = Vector3.ZERO)


# 手枪·清空弹匣：一次性打空所有子弹，锁定前方 180° 最近的敌人，必定暴击
func _special_fan_fire() -> void:
	var rounds := GameState.mag_rounds("pistol")
	if rounds <= 0:
		GameState.notify("弹匣已空")
		return
	if not GameState.use_skill("pistol"):
		return
	# 连续速射：以 150% 射速逐发打空弹匣，每发自动锁定前方 180° 最近敌人（20m 内）
	_fan_shots_left = rounds
	_fan_next_msec = 0
	_recoil = 1.0
	GameState.notify("清空弹匣 ×%d！" % rounds)


# 清空弹匣速射推进：每 0.2s/1.5 一发（150% 射速），打空或切枪即停
func _tick_fan_fire() -> void:
	if Time.get_ticks_msec() < _fan_next_msec:
		return
	if GameState.current_weapon != "pistol" or not GameState.consume_round("pistol"):
		_fan_shots_left = 0
		return
	_fire_fan_shot()
	_fan_shots_left -= 1
	var cd := float(GameState.WEAPONS["pistol"].get("cooldown", 0.2)) * GameState.gun_cooldown_mult() / 1.5
	_fan_next_msec = Time.get_ticks_msec() + int(cd * 1000.0)


# 单发：锁定角色正面 180° 最近敌人（与瞄准位置无关），红色加粗弹道、150% 伤害、150% 弹速
func _fire_fan_shot() -> void:
	# 以角色身体朝向为正面基准
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var weapon := GameState.current_weapon_data()
	var target: Node3D = null
	var best := INF
	for zombie in GameState.entities_in_group_in_radius(global_position, "zombies", 20.0):
		if zombie.is_queued_for_deletion() or bool(zombie.get("_dying")):
			continue
		var to: Vector3 = zombie.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.1 and forward.dot(to / dist) > 0.0 and dist < best:
			best = dist
			target = zombie
	# 训练场标靶同样参与正面最近锁定（标靶不进空间网格，直接遍历组）
	for t in get_tree().get_nodes_in_group("training_targets"):
		if t.is_queued_for_deletion():
			continue
		var to: Vector3 = t.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 20.0:
			continue
		if dist > 0.1 and forward.dot(to / dist) > 0.0 and dist < best:
			best = dist
			target = t
	var dir := forward
	if target != null:
		dir = (target.global_position + Vector3(0, 1.2, 0) - _muzzle_world_pos(dir)).normalized()
	var bullet = BULLET_SCENE.instantiate()
	bullet.from_player = true
	bullet.speed_mult = 1.5
	bullet.trail_color = Color(1.0, 0.25, 0.2)
	bullet.width_mult = 2.5
	get_parent().add_child(bullet)
	bullet.ammo_type = GameState.weapon_ammo_type(GameState.current_weapon)
	bullet.setup(
		_muzzle_world_pos(dir), dir,
		int(
			int(weapon["damage"]) * GameState.gun_damage_mult()
			* GameState.weapon_damage_mult(GameState.current_weapon) * 1.5
		),
		self, true, 0, 30.0,
		weapon.get("falloff", []), float(weapon.get("headshot_range", 999.0))
	)
	_recoil = 1.0


# 冲锋枪·疾风：5 秒内闪避距离翻倍、闪避 CD 缩短为 1/3、每次仅耗 5 点体力 + 换弹加速
func _special_smg_wind() -> void:
	if not GameState.use_skill("smg"):
		return
	GameState.free_dash_until_msec = Time.get_ticks_msec() + 5000
	GameState.wind_dashes_left = 3
	GameState.reload_haste_until_msec = Time.get_ticks_msec() + 5000
	GameState.notify("疾风 5 秒：前 3 次闪避距离翻倍、CD 1/3、耗 10 体力；之后 CD 2/3；换弹加速！")


# 步枪·枪榴弹：发射一枚小型瞬爆榴弹（红色半圆扩散特效）
func _special_rifle_grenade() -> void:
	if not GameState.use_skill("rifle"):
		return
	var dir := _aim_dir_3d()
	var explosive = EXPLOSIVE_SCENE.instantiate()
	get_parent().add_child(explosive)
	explosive.setup(
		_muzzle_world_pos(dir), dir, 60, 4.0, false, self, minf(40.0, _aim_distance()),
		true, Color(0.9, 0.08, 0.04, 0.85), true
	)
	GameState.notify("枪榴弹！")


# G 键直接扔手雷（不切换当前武器），1 秒 CD 由 GameState.consume_grenade 管理
func _throw_grenade() -> void:
	if GameState.interact_menu_open:
		return
	if not GameState.consume_grenade():
		if GameState.grenade_count() <= 0:
			GameState.notify("没有手榴弹了")
		return
	var weapon: Dictionary = GameState.WEAPONS["grenade"]
	var dir := _aim_dir_3d()
	var target_dist := minf(
		float(weapon.get("range", 35.0)),
		(_aim_point - global_position - Vector3(0.0, 1.35, 0.0)).length()
	)
	var explosive = EXPLOSIVE_SCENE.instantiate()
	get_parent().add_child(explosive)
	explosive.setup(
		_muzzle_world_pos(dir), dir, int(weapon["damage"]), float(weapon.get("radius", 6.5)),
		false, self, target_dist
	)
	GameState.notify("手雷！")


# 霰弹枪·爆破弹：装填 2 发爆破弹（图标变红、弹量显示 2/2），打完回到普通弹药
func _special_dragon_breath() -> void:
	if not GameState.use_skill("shotgun"):
		return
	GameState.shotgun_breach_left = 2
	GameState.notify("爆破弹已装填 ×2：前方 20m 90° 扇形 100 伤害 + 强击退")


# 爆破弹射击：前方 20m 90° 扇形全覆盖 100 伤害，附带强击退
func _fire_breach_round() -> void:
	_recoil = 1.4
	_raise = 1.0
	var forward := _aim_dir_3d()
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var muzzle := _muzzle_world_pos(forward)
	var origin := global_position
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.is_queued_for_deletion() or bool(zombie.get("_dying")):
			continue
		var flat: Vector3 = zombie.global_position - origin
		flat.y = 0.0
		var dist := flat.length()
		if dist > 20.0 or dist < 0.01:
			continue
		if flat_forward.dot(flat / dist) < 0.7071:
			continue
		zombie.take_damage(100)
		# 强击退：沿远离人物方向推出 4 米
		var push := zombie.create_tween()
		push.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		push.tween_property(
			zombie, "global_position", zombie.global_position + flat.normalized() * 4.0, 0.15
		)
		DamagePopup.show_damage(
			get_parent(), zombie.global_position + Vector3(0, 1.5, 0), 100, true
		)
	for target in get_tree().get_nodes_in_group("training_targets"):
		var flat: Vector3 = target.global_position - origin
		flat.y = 0.0
		var dist := flat.length()
		if dist > 20.0 or dist < 0.01:
			continue
		if flat_forward.dot(flat / dist) < 0.7071:
			continue
		target.take_damage(100)
		DamagePopup.show_damage(
			get_parent(), target.global_position + Vector3(0, 2.2, 0), 100, true
		)
	_spawn_breach_cone(muzzle, flat_forward)
	GameState.shotgun_breach_left -= 1
	if GameState.shotgun_breach_left <= 0:
		GameState.shotgun_breach_left = 0
		GameState.notify("爆破弹耗尽，回到普通弹药")


# 爆破弹特效：从枪口向前方 90° 扇形扫出一片橙红火光，快速淡出
func _spawn_breach_cone(muzzle: Vector3, flat_forward: Vector3) -> void:
	for i in range(9):
		var angle := lerpf(-PI / 4.0, PI / 4.0, float(i) / 8.0)
		var dir := flat_forward.rotated(Vector3.UP, angle)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35, 0.35, 8.0)
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.55, 0.05, 0.03, 0.85)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color(0.6, 0.04, 0.02)
		material.emission_energy_multiplier = 3.0
		mesh.material_override = material
		get_parent().add_child(mesh)
		# 中心放在枪口前 10~12m：火光只覆盖身前 20m 扇形，不会扩散到人物身后
		mesh.global_position = muzzle + dir * (10.0 + randf() * 2.0)
		mesh.look_at(mesh.global_position + dir, Vector3.UP)
		var tween := mesh.create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.6, 1.6, 2.2), 0.18)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.25)
		tween.tween_callback(mesh.queue_free)


# 重机枪·架设：趴下不能移动，无限子弹；再按右键收起
func _special_deploy() -> void:
	if _deployed:
		_deployed = false
		GameState.infinite_ammo = false
		GameState.notify("收起机枪")
		return
	if not GameState.use_skill("lmg"):
		return
	_deployed = true
	GameState.infinite_ammo = true
	GameState.notify("架设机枪：无法移动，无限子弹（再按右键收起）")


# 鼠标射线与地面（玩家脚底高度平面）求交，身体平滑转向瞄准点
func _update_aim(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	if absf(normal.y) < 0.001:
		return
	var ground_t := (global_position.y - origin.y) / normal.y
	if ground_t > 0.0:
		_aim_point = origin + normal * ground_t
	# 开镜时实际瞄准点钳制在视距范围内——镜孔/准星/瞄准环都以它为准（不再各自对齐鼠标）
	if _scoping or _sniper_focused():
		var view_range := GameState.weapon_view_range(GameState.current_weapon)
		if _sniper_focused():
			# 专注模式：视野范围扩大 50%
			view_range *= 1.5
		var offset := _aim_point - global_position
		offset.y = 0.0
		if offset.length() > view_range:
			_aim_point = global_position + offset.normalized() * view_range
	# 枪斗术自旋期间角色原地转圈，不跟瞄准点
	if _kata_shots_left > 0:
		return
	var to_aim := _aim_point - global_position
	to_aim.y = 0.0
	if to_aim.length() > 0.35:
		var target_yaw := atan2(-to_aim.x, -to_aim.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 14.0))


# 冲刺：向当前移动方向（无输入朝瞄准方向）快速滑步，消耗体力，冷却 1s
func _try_dash() -> void:
	if _dead or vehicle != null or GameState.is_run_over() or _deployed:
		return
	# 冲锋枪·疾风窗口：前 3 次闪避强化（距离×2、CD 1/3、耗 10 体力）；窗口内其余闪避 CD 2/3
	var wind := Time.get_ticks_msec() < GameState.free_dash_until_msec
	var enhanced := wind and GameState.wind_dashes_left > 0
	if Time.get_ticks_msec() < _dash_next_msec:
		return
	var info := GameState.dash_info()
	var cost := 10.0 if enhanced else float(info["cost"])
	if GameState.stamina < cost:
		GameState.notify("体力不足，无法冲刺")
		return
	GameState.use_stamina(cost)
	if enhanced:
		GameState.wind_dashes_left -= 1
	var cd_msec := DASH_COOLDOWN_MSEC
	if enhanced:
		cd_msec = DASH_COOLDOWN_MSEC / 3
	elif wind:
		cd_msec = DASH_COOLDOWN_MSEC * 2 / 3
	_dash_next_msec = Time.get_ticks_msec() + cd_msec
	_dash_dist_mult = 2.0 if enhanced else 1.0
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.5:
		_dash_dir = Vector3(flat.x, 0.0, flat.y).normalized()
	else:
		_dash_dir = _aim_dir()
	_dash_left = DASH_DURATION
	_dash_hits.clear()
	_ghost_timer = 0.0
	_spawn_dash_flash()
	if GameState.dash_level >= 2:
		# Lv2：冲刺期间无敌帧
		_invulnerable_until = Time.get_ticks_msec() + 250
	if GameState.dash_level >= 3:
		_dash_boost_until = Time.get_ticks_msec() + 2000
	if GameState.dash_level >= 5:
		_dash_regen_until = Time.get_ticks_msec() + 3000
	GameState.noise_at(global_position, 10.0)


# 冲刺起步闪光：脚下一小团白闪瞬间放大淡出
func _spawn_dash_flash() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.1, 0.5)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.95, 1.0, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.7, 0.9, 1.0)
	material.emission_energy_multiplier = 2.5
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.global_position = global_position + Vector3(0, 0.15, 0)
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale", Vector3(2.2, 1.0, 2.2), 0.12)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(mesh.queue_free)


# 冲刺残影：半透明青色人形剪影（躯干+头），0.25s 淡出销毁
func _spawn_dash_ghost() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ghost := Node3D.new()
	ghost.transform = global_transform
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.85, 1.0, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.3, 0.8, 1.0)
	material.emission_energy_multiplier = 1.5
	for part in [
		[Vector3(0.36, 0.55, 0.24), Vector3(0, 0.95, 0)],
		[Vector3(0.26, 0.26, 0.26), Vector3(0, 1.42, 0)],
	]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.material_override = material
		mesh.position = part[1]
		ghost.add_child(mesh)
	parent.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)


# Lv4：冲刺路径上的敌人吃 20 伤害并被击退（每只怪一次冲刺只结算一次）
func _dash_damage_pass() -> void:
	for zombie in GameState.entities_in_group_in_radius(global_position, "zombies", 1.4):
		if zombie.is_queued_for_deletion() or bool(zombie.get("_dying")):
			continue
		var id: int = zombie.get_instance_id()
		if _dash_hits.has(id):
			continue
		_dash_hits[id] = true
		zombie.take_damage(20)
		# 直接位移击退（crowd 的速度由批处理驱动，位移比冲量可靠）
		zombie.global_position += _dash_dir * 0.8


func _aim_dir() -> Vector3:
	var dir := _aim_point - global_position
	dir.y = 0.0
	if dir.length() < 0.3:
		dir = -global_transform.basis.z
		dir.y = 0.0
	return dir.normalized()


# 射击方向：朝鼠标指向的地面方向平直飞出（不低头扎地面），
# 子弹一路飞到武器射程尽头——路径上扫到什么打什么，无需逐帧做实体瞄准计算
func _aim_dir_3d() -> Vector3:
	var dir := _aim_point - global_position
	dir.y = 0.0
	if dir.length() < 0.3:
		dir = -global_transform.basis.z
		dir.y = 0.0
	return dir.normalized()


# 玩家到鼠标瞄准点的平面距离
func _aim_distance() -> float:
	var offset := _aim_point - global_position
	offset.y = 0.0
	return offset.length()


func _unhandled_input(event: InputEvent) -> void:
	# 手柄按键适配：映射手柄按键/十字键到对应功能
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B:
				GameState.select_weapon("melee")
			JOY_BUTTON_Y:
				GameState.toggle_backpack()
			JOY_BUTTON_LEFT_SHOULDER:
				GameState.toggle_skills()
			JOY_BUTTON_RIGHT_SHOULDER:
				GameState.toggle_map()
			JOY_BUTTON_START:
				if GameState.any_panel_open():
					GameState.close_all_panels()
				else:
					GameState.toggle_pause_menu()
			JOY_BUTTON_BACK:
				GameState.toggle_map()
			JOY_BUTTON_DPAD_UP:
				GameState.cycle_weapon_slot(1)
			JOY_BUTTON_DPAD_DOWN:
				GameState.cycle_weapon_slot(-1)
			JOY_BUTTON_DPAD_LEFT:
				GameState.start_reload()
			JOY_BUTTON_DPAD_RIGHT:
				GameState.use_medkit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键 = 当前武器的特殊技能（狙击枪为开镜）；任何 UI 面板打开时禁用
			if (
				event.pressed
				and vehicle == null
				and not _dead
				and not GameState.attack_blocked_by_ui()
			):
				_try_special()
			return
		if vehicle == null and event.pressed:
			# 切换武器改为数字按键：不再用鼠标滚轮切枪（避免滚轮误触换武器）
			pass
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# 批次 269：可改键功能优先于固定 match（is_action_key 查映射表）；
		# 数字切枪/F10 补点等固定键仍在下方 match
		if GameState.is_action_key(event, "reload"):
			GameState.start_reload()
			return
		if GameState.is_action_key(event, "flashlight"):
			_toggle_flashlight()
			return
		if GameState.is_action_key(event, "melee"):
			GameState.select_weapon("melee")
			return
		if GameState.is_action_key(event, "grenade"):
			_throw_grenade()
			return
		if GameState.is_action_key(event, "artillery"):
			# 远程炮击：直接指挥场景中最近的迫击炮
			var hud := get_node_or_null("HUD")
			if hud != null and hud.has_method("quick_mortar_command"):
				hud.quick_mortar_command()
			return
		if GameState.is_action_key(event, "meds"):
			# 使用药品（医疗包/仓库药/异能量应急）；UI 打开时不响应
			if not _dead and not GameState.attack_blocked_by_ui():
				GameState.use_medkit()
			return
		if GameState.is_action_key(event, "map"):
			GameState.toggle_map()
			return
		if GameState.is_action_key(event, "backpack"):
			GameState.toggle_backpack()
			return
		if GameState.is_action_key(event, "skills"):
			GameState.toggle_skills()
			return
		if GameState.is_action_key(event, "build"):
			var build := _build_controller()
			if build != null and build.handles_x_key(self):
				return
			_try_surrender()
			return
		match event.keycode:
			KEY_ESCAPE:
				# 炮击指挥/远程打击圆盘打开时 Esc 由对应 UI 接管（不开暂停菜单）
				if GameState.mortar_command != null or GameState.strike_dial_open:
					return
				var build := _build_controller()
				if build != null and build.is_active():
					return
				if GameState.any_panel_open():
					GameState.close_all_panels()
				else:
					GameState.toggle_pause_menu()
			KEY_1:
					GameState.select_weapon(GameState.weapon_at_slot(0))
			KEY_2:
					GameState.select_weapon(GameState.weapon_at_slot(1))
			KEY_F10:
				if GameState.test_mode:
					GameState.skill_points = GameState.test_points
					GameState.skill_points_changed.emit(GameState.skill_points)
					GameState.notify("测试模式：强化点已补满")


# ===== 手柄按键适配 =====
const GAMEPAD_AIM_SPEED := 900.0
const GAMEPAD_DEADZONE := 0.22
var _lt_held := false


# 每帧手柄处理：右摇杆瞄准（模拟鼠标移动）、RT 开火、LT 开镜/特殊
func _process_gamepad(delta: float) -> void:
	if _dead or GameState.is_run_over():
		return
	# 右摇杆 → 瞄准（移动鼠标指针，瞄准环/准星跟随）
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > GAMEPAD_DEADZONE:
		var vp := get_viewport()
		vp.warp_mouse(vp.get_mouse_position() + stick * GAMEPAD_AIM_SPEED * delta)
	# RT（右扳机）= 开火（按住连发，射速由武器冷却限制）
	var rt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	if rt > 0.5 and vehicle == null and not GameState.reloading:
		_try_fire()
	# LT（左扳机）= 开镜/特殊（按下沿触发一次）
	var lt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if lt > 0.5:
		if not _lt_held:
			_lt_held = true
			if vehicle == null and not _dead and not GameState.attack_blocked_by_ui():
				_try_special()
	else:
		_lt_held = false


func _physics_process(delta: float) -> void:
	# 完美闪避缓速：玩家不受 time_scale 影响，按真实时间行动
	if GameState.slowmo_active and Engine.time_scale > 0.001:
		delta /= Engine.time_scale
	_process_gamepad(delta)
	_occl_timer -= delta
	if _occl_timer <= 0.0:
		_occl_timer = 0.1
		_update_occlusion()
	if _dead or GameState.is_run_over():
		return
	if vehicle != null:
		global_position = vehicle.global_position + Vector3(0, 0.9, 0)
		velocity = Vector3.ZERO
		rotation.y = lerp_angle(
			rotation.y, vehicle.global_rotation.y + PI, minf(1.0, delta * 6.0)
		)
		if (
			Time.get_ticks_msec() >= _vehicle_switch_msec
			and not GameState.interact_menu_open
			and Input.is_action_just_pressed("interact")
		):
			exit_vehicle()
		return
	_update_aim(delta)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 交互菜单打开时锁死移动（W/S 在菜单里用于上下选择；Input.get_vector 是轮询，
	# hud 的 set_input_as_handed 拦不住，必须在这里归零）；藏匿在建筑中同样锁移动
	if GameState.interact_menu_open or not GameState.player_in_building.is_empty():
		input = Vector2.ZERO
	# 架设状态：不能移动；切到非重机枪自动收起
	if _deployed:
		if GameState.current_weapon != "lmg":
			_deployed = false
			GameState.infinite_ammo = false
		else:
			input = Vector2.ZERO
	# 相机相对移动：屏幕上 = 世界 (-1,0,-1) 方向（相机 yaw 45°）
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, CAM_YAW).normalized()
	# 双击方向键进入疾跑（方向键全部松开即退出）
	for dir_name in _last_tap.keys():
		if Input.is_action_just_pressed(dir_name):
			var now := Time.get_ticks_msec()
			if now - int(_last_tap[dir_name]) <= 300:
				_sprint_held = true
			_last_tap[dir_name] = now
	if input == Vector2.ZERO:
		_sprint_held = false
	# Shift 按下瞬间冲刺（藏匿在建筑中禁用）
	if Input.is_action_just_pressed("sprint") and GameState.player_in_building.is_empty():
		_try_dash()
	var sprinting := (
		_sprint_held
		and input != Vector2.ZERO
		and GameState.satiety > 0.0
		and GameState.has_stamina()
	)
	var speed := WALK_SPEED * GameState.walk_speed_mult() * (SPRINT_MULT if sprinting else 1.0)
	if _scoping:
		speed *= 0.5
	# Lv3：冲刺后 2 秒移速 +20%
	if Time.get_ticks_msec() < _dash_boost_until:
		speed *= 1.2
	# 枪斗状态推进：自旋+闪烁+按射速逐发锁定
	if _kata_shots_left > 0:
		_tick_gun_kata(delta)
	elif _fan_shots_left > 0:
		_tick_fan_fire()
	elif _body_root != null and not _body_root.visible and GameState.player_in_building.is_empty():
		# 枪斗结束恢复模型可见（闪烁的最后一帧可能停在隐藏态）；
		# 藏匿建筑中的隐藏态不在此恢复（否则每帧把藏匿模型翻回可见）
		_body_root.visible = true
	# 冲刺：跳跃键改为冲刺（覆盖普通移动，撞墙即停）
	if _dash_left > 0.0:
		_dash_left -= delta
		var dash_speed: float = GameState.dash_info()["dist"] / DASH_DURATION * _dash_dist_mult
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		# 残影：冲刺期间每 0.03s 在身后留一道剪影
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = DASH_GHOST_INTERVAL
			_spawn_dash_ghost()
		# Lv4：冲刺路径上的敌人吃伤害并被击退
		if GameState.dash_level >= 4:
			_dash_damage_pass()
	else:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
		if (
			Input.is_action_just_pressed("jump")
			and vehicle == null
			and _dash_left <= 0.0
			and GameState.player_in_building.is_empty()
		):
			velocity.y = JUMP_VELOCITY * GameState.jump_mult()
	else:
		velocity.y -= GRAVITY * delta
	if sprinting:
		var hunger := 1.0 - clampf(
			GameState.satiety / GameState.MAX_SATIETY, 0.0, 1.0
		)
		var drain := STAMINA_DRAIN * (1.0 + hunger * HUNGER_STAMINA_FACTOR)
		GameState.use_stamina(drain * GameState.stamina_drain_mult() * delta)
		GameState.drain_satiety(
			SPRINT_SATIETY_DRAIN * GameState.sprint_satiety_mult() * delta
		)
	else:
		var standing := input == Vector2.ZERO and is_on_floor()
		GameState.regen_stamina(GameState.stamina_regen(standing) * delta)
	# Lv5：冲刺后 3 秒体力快速回复
	if Time.get_ticks_msec() < _dash_regen_until:
		GameState.regen_stamina(10.0 * delta)
	if GameState.stamina <= 0.0:
		var burst := GameState.take_second_wind()
		if burst > 0.0:
			GameState.regen_stamina(burst)
			GameState.notify("第二口气：体力 +%d" % int(burst))
	# 完美闪避缓速：move_and_slide 内部积分步长也被 time_scale 缩放，速度向量反向补偿
	if GameState.slowmo_active and Engine.time_scale > 0.001:
		velocity /= Engine.time_scale
		move_and_slide()
		velocity *= Engine.time_scale
	else:
		move_and_slide()
	var firing := (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and get_viewport().gui_get_hovered_control() == null
		and not GameState.reloading
		and not GameState.attack_blocked_by_ui()
	)
	if firing:
		var fresh := not _trigger_down
		_trigger_down = true
		_try_fire(fresh)
	else:
		_trigger_down = false


func enter_vehicle(v: Node3D) -> void:
	if vehicle != null:
		return
	vehicle = v
	_scoping = false
	v.enter(self)
	rotation.y = v.global_rotation.y + PI
	_vehicle_switch_msec = Time.get_ticks_msec() + 250
	visible = false
	$CollisionShape3D.set_deferred("disabled", true)
	velocity = Vector3.ZERO


func exit_vehicle() -> void:
	if vehicle == null:
		return
	var v := vehicle
	vehicle = null
	v.leave()
	global_position = v.global_position + Vector3(0, 0.2, 3.2)
	_vehicle_switch_msec = Time.get_ticks_msec() + 250
	visible = true
	$CollisionShape3D.set_deferred("disabled", false)
	velocity = Vector3.ZERO


# 载具驾驶：WASD 映射为相机相对的地面行驶方向（vehicle3d._drive 调用）
# 驾驶输入：x = 转向（A 左 / D 右），y = 油门（W 前进 / S 倒车），车辆自身坐标系
func drive_input() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up")
	)


func _try_fire(fresh := true) -> void:
	# 任何菜单/面板打开期间禁用开火（菜单只认自己的按键，鼠标点击/扳机不该走火）
	if GameState.attack_blocked_by_ui():
		return
	if Time.get_ticks_msec() < _next_shot_msec or GameState.reloading:
		return
	# 枪斗状态中不能普通开火
	if _kata_shots_left > 0:
		return
	# 清空弹匣速射期间不能普通开火
	if _fan_shots_left > 0:
		return
	# 冲刺滑行中按开火：触发武器连携技（打断普通开火）
	if _dash_left > 0.0 and _try_dash_combo():
		return
	var weapon: Dictionary = GameState.current_weapon_data()
	if weapon.is_empty():
		_next_shot_msec = Time.get_ticks_msec() + int(450.0 * GameState.melee_cooldown_mult())
		var base := GameState.melee_base_damage()
		var mult := GameState.melee_damage_mult()
		if GameState.is_zombie():
			mult *= GameState.zombie_claw_mult()
		_start_melee(int(base * mult))
		return
	var is_melee := bool(weapon.get("melee", false))
	if is_melee:
		_next_shot_msec = Time.get_ticks_msec() + int(
			float(weapon.get("cooldown", 0.4)) * GameState.melee_cooldown_mult() * 1000.0
		)
		_start_melee(int(int(weapon.get("damage", 35)) * GameState.melee_damage_mult()))
		return
	if not bool(weapon.get("auto", false)) and not fresh:
		return
	var id := GameState.current_weapon
	# 霰弹枪爆破弹：优先消耗爆破弹（不占普通弹匣）
	if id == "shotgun" and GameState.shotgun_breach_left > 0:
		_next_shot_msec = Time.get_ticks_msec() + int(
			float(weapon.get("cooldown", 0.8)) * GameState.gun_cooldown_mult() * 1000.0
		)
		_fire_breach_round()
		return
	if not GameState.consume_round(id):
		if Time.get_ticks_msec() >= _next_shot_msec:
			_next_shot_msec = Time.get_ticks_msec() + 250
			GameState.start_reload()
		return
	_next_shot_msec = Time.get_ticks_msec() + int(
		float(weapon.get("cooldown", 0.4)) * GameState.gun_cooldown_mult() * 1000.0
	)
	_raise = 1.0
	if bool(weapon.get("explosive", false)):
		var is_rocket := bool(weapon.get("rocket", false))
		var dir := _aim_dir_3d()
		var origin := _muzzle_world_pos(dir) + dir * (0.4 if is_rocket else 0.0)
		var target_dist := minf(
			float(weapon.get("range", 80.0)),
			(_aim_point - global_position - Vector3(0.0, 1.35, 0.0)).length()
		)
		var explosive = EXPLOSIVE_SCENE.instantiate()
		get_parent().add_child(explosive)
		explosive.setup(
			origin, dir, int(weapon["damage"]), float(weapon.get("radius", 6.0)),
			is_rocket, self, target_dist
		)
		if is_rocket:
			_recoil = 1.6
		return
	_recoil = 1.0
	var pellets := int(weapon.get("pellets", 1))
	# 动态散布：基础散布 × 移动惩罚 × 开镜收敛 + 连射扩散（绝对值，狙击枪也会飘）
	var moving := Vector2(velocity.x, velocity.z).length() > 2.0
	var spread := (
		float(weapon.get("spread", 0.0))
		* GameState.gun_spread_mult()
		* (1.5 if moving else 1.0)
		* (0.6 if _scoping else 1.0)
		+ _bloom * 0.025
	)
	_bloom = minf(_bloom + 0.35, 2.0)
	# 距离散布：按瞄准距离查表叠加（如手枪 10m 内为零，15/20m 渐显）
	var dist_spread: Array = weapon.get("dist_spread", [])
	if not dist_spread.is_empty():
		var aim_dist := _aim_distance()
		var extra := 0.0
		for entry in dist_spread:
			if aim_dist <= float(entry[0]):
				extra = float(entry[1])
				break
			extra = float(entry[1])
		spread += extra
	var pellet_damage := int(
		int(weapon["damage"]) * GameState.gun_damage_mult()
		* GameState.weapon_damage_mult(GameState.current_weapon)
		* GameState.echo_mod_damage_mult(GameState.current_weapon)
	)
	if GameState.roll_crit():
		pellet_damage = int(pellet_damage * GameState.crit_mult())
	var penetrate := int(weapon.get("penetrate", 0)) + GameState.rogue_rank("pierce")
	# 狙击开镜：子弹贯穿视野内所有目标（专注模式）
	if GameState.current_weapon == "sniper" and _sniper_focused():
		penetrate = 99
	var range := float(weapon.get("range", MAX_RANGE))
	for i in pellets:
		_fire_pellet(pellet_damage, spread, penetrate, range)


func _build_viewmodels() -> void:
	var defs := {
		"melee": {
			"muzzle": Vector3.ZERO,
			"parts": [
				[Vector3(0.05, 0.05, 0.16), Vector3(0.0, -0.02, 0.06), WOOD_COLOR],
				[Vector3(0.02, 0.12, 0.4), Vector3(0.0, 0.03, -0.2), BLADE_COLOR],
			],
		},
	}
	for id in GameState.WEAPON_MODELS:
		defs[id] = {"muzzle": Vector3.ZERO, "model": GameState.weapon_model_path(String(id))}
	_gun_defs = defs
	for id in defs:
		var model := _make_gun_model(String(id), true)
		var muzzle_pos: Vector3 = defs[id].get("muzzle", Vector3.ZERO)
		if muzzle_pos != Vector3.ZERO:
			_attach_muzzle(model, muzzle_pos, String(id))
		else:
			_weapon_models[id] = model
		viewmodel.add_child(model)


func _make_gun_model(id: String, overlay: bool) -> Node3D:
	var def: Dictionary = _gun_defs.get(id, {})
	var model := Node3D.new()
	var glb_path := String(def.get("model", ""))
	if not glb_path.is_empty():
		var packed: PackedScene = load(glb_path)
		if packed != null:
			var gun: Node3D = packed.instantiate()
			# Synty 武器预制体自带碰撞体：第一人称视角模型不需要物理
			for static_body in gun.find_children("*", "StaticBody3D", true, false):
				static_body.free()
			model.add_child(gun)
			var aabb := _combined_aabb(model)
			# Kenney blaster 枪口朝 +Z，视角前方是 -Z，旋转 180°
			gun.rotation.y = PI
			# 第一人称模型缩小并前推，避免枪身怼到镜头
			var gun_scale := 1.0
			var gun_offset := Vector3.ZERO
			if overlay:
				gun_scale = 1.0 if id == "grenade" else VM_GUN_SCALE
				gun_offset = Vector3(0.0, -0.05, -0.2) if id == "grenade" else Vector3(0.0, -0.02, -0.22)
				gun.scale = Vector3.ONE * gun_scale
				gun.position = gun_offset
			if id != "grenade":
				def["muzzle"] = gun_offset + Vector3(
					0.0, aabb.end.y * 0.5 * gun_scale, (-aabb.end.z - 0.02) * gun_scale
				)
			if overlay:
				_apply_overlay(gun)
	else:
		for part in def.get("parts", []):
			model.add_child(_make_part(part[0], part[1], part[2], overlay))
	var muzzle_pos: Vector3 = def.get("muzzle", Vector3.ZERO)
	if muzzle_pos != Vector3.ZERO:
		var suppressor: Node3D
		if not glb_path.is_empty():
			# silencer 从原点向 -Z 延伸，正好接在枪口上
			suppressor = load(GameState.SUPPRESSOR_MODEL).instantiate()
			for static_body in suppressor.find_children("*", "StaticBody3D", true, false):
				static_body.free()
			suppressor.position = muzzle_pos
			if overlay:
				suppressor.scale = Vector3.ONE * VM_GUN_SCALE
				_apply_overlay(suppressor)
		else:
			suppressor = _make_part(
				Vector3(0.09, 0.09, 0.26),
				muzzle_pos + Vector3(0.0, 0.0, 0.15),
				Color(0.14, 0.14, 0.16),
				overlay
			)
		suppressor.name = "Suppressor"
		suppressor.visible = false
		model.add_child(suppressor)
	return model


func _apply_overlay(root: Node3D) -> void:
	var _aabb_meshes: Array = []
	if root is MeshInstance3D:
		_aabb_meshes.append(root)
	_aabb_meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for child in _aabb_meshes:
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i)
			var material: Material
			if source != null:
				material = source.duplicate()
			else:
				var fallback := StandardMaterial3D.new()
				fallback.albedo_color = Color(0.75, 0.75, 0.78)
				material = fallback
			if material is BaseMaterial3D:
				material.no_depth_test = true
			material.render_priority = 2
			mi.set_surface_override_material(i, material)


func _combined_aabb(root: Node3D) -> AABB:
	var boxes: Array = []
	_collect_aabbs(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var result: AABB = boxes[0]
	for i in range(1, boxes.size()):
		result = result.merge(boxes[i])
	return result


func _collect_aabbs(node: Node, xform: Transform3D, boxes: Array) -> void:
	if node is Node3D:
		xform = xform * node.transform
		if node is MeshInstance3D and node.mesh != null:
			boxes.append(xform * node.get_aabb())
	for child in node.get_children():
		_collect_aabbs(child, xform, boxes)


func _make_part(size: Vector3, pos: Vector3, color: Color, overlay := true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.no_depth_test = overlay
	material.render_priority = 2 if overlay else 0
	mesh_instance.material_override = material
	mesh_instance.position = pos
	return mesh_instance


func _attach_muzzle(model: Node3D, pos: Vector3, weapon_id: String) -> void:
	var muzzle := Node3D.new()
	muzzle.position = pos
	var flash := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.1, 0.1)
	flash.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.4)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 3
	flash.material_override = material
	flash.visible = false
	muzzle.add_child(flash)
	model.add_child(muzzle)
	_weapon_models[weapon_id] = model
	_weapon_flashes[weapon_id] = flash


func _refresh_viewmodel() -> void:
	for id in _weapon_models:
		var model: Node3D = _weapon_models[id]
		model.visible = GameState.current_weapon == id
		if model.visible:
			var suppressor = model.get_node_or_null("Suppressor")
			if suppressor != null:
				suppressor.visible = GameState.has_suppressor(String(id))
	_muzzle_flash = _weapon_flashes.get(GameState.current_weapon, null)
	_refresh_tp_gun()


func _refresh_tp_gun() -> void:
	if _tp_gun_root == null:
		return
	for child in _tp_gun_root.get_children():
		child.queue_free()
	var id := GameState.current_weapon
	if id == "" or not _gun_defs.has(id):
		return
	var model := _make_gun_model(id, false)
	model.scale = Vector3(1.25, 1.25, 1.25)
	_tp_gun_root.add_child(model)
	var suppressor = model.get_node_or_null("Suppressor")
	if suppressor != null:
		suppressor.visible = GameState.has_suppressor(id)


func _start_melee(damage: int) -> void:
	_swing_side = -_swing_side
	_recoil = 0.5
	_animate_melee_swing(_swing_side)
	_resolve_melee_swing(damage, _swing_side)


func _resolve_melee_swing(damage: int, side: int) -> void:
	await get_tree().create_timer(0.05).timeout
	if not is_inside_tree() or _dead:
		return
	# 旋风斩：360° 环形刀光；普通挥击：扇形弧光
	if _spin_attack:
		_spawn_spin_ring()
	else:
		_spawn_melee_arc(side)
	await get_tree().create_timer(0.05).timeout
	if not is_inside_tree() or _dead:
		return
	_melee(damage)


# 旋风斩刀光：以玩家为中心铺开一圈 360° 环形弧光，扩张后淡出
func _spawn_spin_ring() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# 旋风斩刀光：红色
	var outer := Color(1.0, 0.2, 0.15, 0.9)
	var inner := Color(1.0, 0.55, 0.45, 0.75)
	var segments := 48
	var reach := MELEE_REACH + GameState.melee_reach_bonus()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		var dir := Vector3(cos(angle), 0.0, -sin(angle))
		vertices.append(dir * reach)
		colors.append(outer)
		vertices.append(dir * reach * 0.55)
		colors.append(inner)
	for i in range(segments):
		var b := i * 2
		indices.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 3
	mesh_instance.material_override = material
	var root := Node3D.new()
	root.add_child(mesh_instance)
	# 挂在玩家节点下：环形刀光跟随人物移动（旋转对称，无需对朝向）
	add_child(root)
	root.position = Vector3(0.0, 0.15, 0.0)
	mesh_instance.scale = Vector3(0.3, 1.0, 0.3)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3(1.15, 1.0, 1.15), 0.22)
	tween.tween_property(mesh_instance, "transparency", 1.0, 0.22).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(root.queue_free)


# 斜俯视角下的近战刀光：平铺在玩家脚边、朝瞄准方向的扇形弧光
func _spawn_melee_arc(side: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var inner := MeleeFx3D.SLASH_INNER
	if GameState.is_zombie():
		inner = Color(0.5, 1.0, 0.55, 0.75)
	var segments := 18
	var half_arc := 1.25
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := lerpf(-half_arc, half_arc, t)
		var taper := sin(PI * t)
		var dir := Vector3(cos(angle), 0.0, -sin(angle))
		vertices.append(dir * lerpf(1.1, 1.6, taper))
		colors.append(Color(MeleeFx3D.SLASH_OUTER, MeleeFx3D.SLASH_OUTER.a * taper))
		vertices.append(dir * lerpf(0.6, 0.9, taper))
		colors.append(Color(inner, inner.a * taper))
	for i in range(segments):
		var b := i * 2
		indices.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 3
	mesh_instance.material_override = material
	var root := Node3D.new()
	root.add_child(mesh_instance)
	# 挂在玩家节点下：刀光跟随人物移动与转身（身体 -Z 朝瞄准方向，弧光沿 +X 展开，故固定偏转 90°）
	add_child(root)
	root.position = Vector3(0.0, 0.15, 0.0)
	root.rotation.y = PI / 2.0
	mesh_instance.scale = Vector3(0.7, 1.0, 0.7 * side)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3(1.1, 1.0, 1.1 * side), 0.18)
	tween.tween_property(mesh_instance, "transparency", 1.0, 0.18).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(root.queue_free)


func _animate_melee_swing(side: int) -> void:
	var model: Node3D = _weapon_models.get("melee")
	if model == null or not model.visible:
		_jab = 1.0
		return
	if _swing_tween != null and is_instance_valid(_swing_tween) and _swing_tween.is_valid():
		_swing_tween.kill()
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	_swing_tween = model.create_tween()
	_swing_tween.set_parallel(true)
	_swing_tween.tween_property(
		model, "position", Vector3(0.2 * side, 0.1, 0.04), 0.06
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(
		model, "rotation", Vector3(-0.25, -0.45 * side, 0.6 * side), 0.06
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.chain().set_parallel(true)
	_swing_tween.tween_property(
		model, "position", Vector3(-0.34 * side, -0.08, -0.16), 0.09
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_swing_tween.tween_property(
		model, "rotation", Vector3(0.2, 0.55 * side, -0.95 * side), 0.09
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_swing_tween.chain().set_parallel(true)
	_swing_tween.tween_property(
		model, "position", Vector3.ZERO, 0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_swing_tween.tween_property(
		model, "rotation", Vector3.ZERO, 0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _refresh_melee_tool() -> void:
	_melee_tool_id = GameState.melee_item
	var model: Node3D = _weapon_models.get("melee")
	if model == null:
		return
	for child in model.get_children():
		child.queue_free()
	var path := ""
	if GameState.LOOT_ITEMS.has(_melee_tool_id):
		path = String(GameState.LOOT_ITEMS[_melee_tool_id].get("model", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		var tool: Node3D = packed.instantiate()
		# sur-tool 模型原点在握柄底部，长轴朝 +Y，前倾后刃口朝前上方
		tool.rotation = Vector3(-0.95, 0.0, 0.35)
		tool.scale = Vector3.ONE * 2.4
		tool.position = Vector3(0.04, -0.18, -0.04)
		model.add_child(tool)
		_apply_overlay(tool)
	else:
		for part in _gun_defs["melee"].get("parts", []):
			model.add_child(_make_part(part[0], part[1], part[2], true))


func _knockback(target: Node3D, dir: Vector3) -> void:
	if not is_instance_valid(target):
		return
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	var tween := target.create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# 击退距离压短：硬直必须短于攻击间隔，否则近战能无限风筝
	tween.tween_property(
		target, "global_position", target.global_position + dir.normalized() * 0.35, 0.1
	)


func is_scoped() -> bool:
	return _scoping


# 瞄准镜暗角圆孔半径（像素）：倍镜越高视野越窄
func scope_hole_radius() -> float:
	match int(GameState.weapon_view_range(GameState.current_weapon)):
		25:
			return 130.0
		35:
			return 110.0
		50:
			return 90.0
		70:
			return 70.0
		_:
			return 150.0


# 瞄准模式：低倍（无镜/红点）= 柔焦环；狙击枪或 2x 及以上镜子 = 狙击镜黑边
func scope_mode() -> String:
	if GameState.current_weapon == "sniper":
		return "hard"
	return "hard" if GameState.weapon_view_range(GameState.current_weapon) >= 35.0 else "soft"


func is_sighted() -> bool:
	return false


func _on_disguise_changed() -> void:
	var old_shirt := _shirt_color
	var old_pants := _pants_color
	_shirt_color = Color.from_hsv(randf(), 0.35, 0.8)
	_pants_color = Color.from_hsv(randf(), 0.25, 0.45)
	_retint(_body_root, old_shirt, _shirt_color)
	_retint(_body_root, old_pants, _pants_color)


func _retint(node: Node, from: Color, to: Color) -> void:
	if node is MeshInstance3D:
		var material = node.material_override
		if material is StandardMaterial3D and material.albedo_color.is_equal_approx(from):
			material.albedo_color = to
	for child in node.get_children():
		_retint(child, from, to)


func _pose_tp_arms(delta: float) -> void:
	var arms: Array = _body_limbs.get("arms", [])
	if arms.size() < 2 or _tp_gun_root == null:
		return
	var weapon_id := GameState.current_weapon
	var armed := weapon_id in GameState.WEAPONS and not bool(
		GameState.WEAPONS[weapon_id].get("melee", false)
	)
	var arm_target := -0.7
	var yaw_target := 0.5
	var pitch_target := -0.05
	if armed:
		arm_target = -1.4
		yaw_target = 0.0
		pitch_target = 0.0
	elif _raise > 0.05:
		arm_target = -1.15
		yaw_target = 0.22 * (1.0 - _raise)
	if armed:
		arms[1].rotation.x = lerpf(arms[1].rotation.x, arm_target, minf(1.0, delta * 14.0))
		arms[0].rotation.x = lerpf(arms[0].rotation.x, arm_target * 0.65, minf(1.0, delta * 14.0))
	_tp_gun_root.rotation.y = lerpf(
		_tp_gun_root.rotation.y, yaw_target if armed else 0.0, minf(1.0, delta * 10.0)
	)
	_tp_gun_root.rotation.x = -arms[1].rotation.x + (pitch_target if armed else 0.0) + _raise * 0.15


func _fire_pellet(damage: int, spread: float, penetrate := 0, range := MAX_RANGE) -> void:
	var forward := _aim_dir_3d()
	# 子弹从第三人称枪口的实际位置射出（散布前取基准朝向定枪口，散布只影响弹道）
	var from := _muzzle_world_pos(forward)
	if spread > 0.0:
		var right := forward.cross(Vector3.UP).normalized()
		forward = (
			forward
			+ right * randf_range(-spread, spread)
			+ Vector3.UP * randf_range(-spread, spread) * 0.35
		).normalized()
	# 方向射击：不按瞄准点截断，一路飞到武器射程尽头
	var max_dist := range
	var weapon := GameState.current_weapon_data()
	var bullet = BULLET_SCENE.instantiate()
	bullet.from_player = true
	bullet.inherit_velocity = velocity
	# 狙击专注模式：子弹附加红色特效，弹道加粗到约 2/3 玩家身宽
	if GameState.current_weapon == "sniper" and _sniper_focused():
		bullet.trail_color = Color(1.0, 0.2, 0.15)
		bullet.width_mult = 7.0
	get_parent().add_child(bullet)
	bullet.ammo_type = GameState.weapon_ammo_type(GameState.current_weapon)
	bullet.setup(
		from, forward, damage, self, true, penetrate, max_dist,
		weapon.get("falloff", []), float(weapon.get("headshot_range", 999.0))
	)


# 枪口世界坐标：第三人称枪模型挂点（手部）+ 沿朝向一段枪管长度；无挂点时退回角色胸前。
# 弹道高度下限 1.3m：挂在腰部的枪也要让弹道打到上 1/3 身体（爆头判定区间）
func _muzzle_world_pos(forward: Vector3) -> Vector3:
	# 枪口即第三人称枪模挂点（右手骨）沿瞄准方向前伸；下限只防贴地，不再垫高
	if _tp_gun_root != null and is_instance_valid(_tp_gun_root) and _tp_gun_root.visible:
		var pos := _tp_gun_root.global_position + forward * 0.8
		pos.y = maxf(pos.y, global_position.y + 0.5)
		return pos
	return global_position + Vector3(0.0, 1.35, 0.0) + forward * 0.8


# 冲刺连携技分派：按当前武器触发（冲刺本身无伤害，伤害全在连携里）
func _try_dash_combo() -> bool:
	match GameState.current_weapon:
		"smg":
			return _gun_kata()
	return false


# 冲锋枪连携 · 枪斗术：以武器自身射速逐发扫射弹匣内所有子弹，
# 每发自动锁定周围随机敌人且全部暴击；期间人物持续自旋+身影闪烁，火光随射速同步
func _gun_kata() -> bool:
	var mag := GameState.mag_rounds("smg")
	if mag <= 0:
		return false
	var found := false
	for zombie in GameState.entities_in_group_in_radius(global_position, "zombies", KATA_RADIUS):
		if not zombie.is_queued_for_deletion() and not bool(zombie.get("_dying")):
			found = true
			break
	if not found:
		# 训练场标靶也可作为枪斗术目标（标靶不进空间网格，直接遍历组）
		for t in get_tree().get_nodes_in_group("training_targets"):
			if (
				not t.is_queued_for_deletion()
				and global_position.distance_squared_to(t.global_position) <= KATA_RADIUS * KATA_RADIUS
			):
				found = true
				break
	if not found:
		return false
	_kata_shots_left = mag
	_kata_timer = 0.0
	_dash_left = 0.0
	_raise = 1.0
	GameState.notify("枪斗术！")
	return true


# 枪斗状态推进（在 _physics_process 调用）：自旋+闪烁+按射速逐发
func _tick_gun_kata(delta: float) -> void:
	# 自旋约 1.25 圈/秒
	rotation.y += delta * (TAU / 0.8)
	# 身影 12Hz 轻微跳动闪烁
	_kata_flick += delta * 12.0
	if _body_root != null:
		_body_root.visible = sin(_kata_flick * PI) > -0.2
	_kata_timer -= delta
	if _kata_timer > 0.0:
		return
	_kata_timer = float(GameState.WEAPONS["smg"].get("cooldown", 0.1))
	_kata_fire_one()


func _kata_fire_one() -> void:
	if not GameState.consume_round("smg"):
		_kata_shots_left = 0
		return
	_kata_shots_left -= 1
	var targets: Array = []
	for zombie in GameState.entities_in_group_in_radius(global_position, "zombies", KATA_RADIUS):
		if not zombie.is_queued_for_deletion() and not bool(zombie.get("_dying")):
			targets.append(zombie)
	# 训练场标靶也纳入随机锁定池（标靶不进空间网格，直接遍历组）
	for t in get_tree().get_nodes_in_group("training_targets"):
		if (
			not t.is_queued_for_deletion()
			and global_position.distance_squared_to(t.global_position) <= KATA_RADIUS * KATA_RADIUS
		):
			targets.append(t)
	if targets.is_empty():
		# 没目标提前收手，剩余子弹保留
		_kata_shots_left = 0
		if _body_root != null:
			_body_root.visible = true
		return
	var zombie: Node3D = targets[randi() % targets.size()]
	var center: Vector3 = zombie.global_position + Vector3(0, 1.0, 0)
	var damage := int(GameState.WEAPONS["smg"].get("damage", 10)) * 2
	_kata_tracer(global_position + Vector3(0, 1.35, 0), center)
	zombie.take_damage(damage)
	DamagePopup.show_damage(get_parent(), center, damage, true)
	GameState.noise_at(global_position, 20.0)


# 枪斗术曳光：到每个目标的一道亮条（与工人 tracer 同款）
func _kata_tracer(from: Vector3, to: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, from.distance_to(to))
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.4)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.35)
	material.emission_energy_multiplier = 2.5
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.global_position = (from + to) / 2.0
	mesh.look_at(to, Vector3.UP)
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale:x", 0.05, 0.12)
	tween.parallel().tween_property(mesh, "scale:y", 0.05, 0.12)
	tween.tween_callback(mesh.queue_free)


func _melee(damage: int) -> void:
	# 近战扇形以身体朝向为准（身体持续转向鼠标瞄准点）
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.05:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var reach := MELEE_REACH + GameState.melee_reach_bonus()
	var hit_any := false
	for zombie in get_tree().get_nodes_in_group("zombies"):
		var to_zombie: Vector3 = zombie.global_position - global_position
		to_zombie.y = 0.0
		var dist := to_zombie.length()
		if dist > reach:
			continue
		# 旋风斩跳过扇形角度判定（360° 全向）
		if not _spin_attack and dist > 0.1 and forward.dot(to_zombie / dist) < 0.3:
			continue
		hit_any = true
		var hp_before: int = zombie.hp
		# 近战命中：猎犬会被打断并僵直 0.5 秒
		if zombie.has_method("take_melee_damage"):
			zombie.take_melee_damage(damage)
		else:
			zombie.take_damage(damage)
		var killed: bool = hp_before > 0 and zombie.hp <= 0
		MeleeFx3D.blood_burst(
			zombie.get_parent(), zombie.global_position + Vector3(0, 1.0, 0), killed
		)
		if not zombie.net_puppet:
			_knockback(zombie, to_zombie)
		DamagePopup.show_damage(zombie.get_parent(), zombie.global_position + Vector3(0, 1.0, 0), damage)
		if GameState.has_mutation("bleed") and hp_before > 0:
			zombie.apply_bleed(
				GameState.mut_value("bleed", 0), GameState.mut_value("bleed", 1)
			)
		if killed:
			kills += 1
			GameState.award_skill_point()
			if GameState.is_zombie():
				GameState.on_zombie_kill()
			else:
				GameState.on_melee_kill()
	# 近战也能砍到车辆（玩家近战攻击车辆掉血；驾驶时不会触发近战，无需跳过本车）
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if vehicle.is_queued_for_deletion() or bool(vehicle.get("destroyed")):
			continue
		var to_v: Vector3 = vehicle.global_position - global_position
		to_v.y = 0.0
		var dist_v := to_v.length()
		if dist_v > reach:
			continue
		if not _spin_attack and dist_v > 0.1 and forward.dot(to_v / dist_v) < 0.3:
			continue
		hit_any = true
		vehicle.take_damage(damage, self)
		DamagePopup.show_damage(get_parent(), vehicle.global_position + Vector3(0, 1.0, 0), damage)
	# 旋风斩只影响本次挥击
	_spin_attack = false
	# 只有装备近战武器时，挥舞才能拍碎狼蛛的毒液（空手不行）
	if GameState.melee_item != "":
		for shot in get_tree().get_nodes_in_group("venom_shot"):
			var to_shot: Vector3 = shot.global_position - global_position
			to_shot.y = 0.0
			var dist_shot := to_shot.length()
			if dist_shot > reach + 0.5:
				continue
			if dist_shot > 0.1 and forward.dot(to_shot / dist_shot) < 0.2:
				continue
			shot.take_damage(0)
	for core in get_tree().get_nodes_in_group("anomaly_zone_core"):
		var to_core: Vector3 = core.global_position - global_position
		to_core.y = 0.0
		var dist_core := to_core.length()
		if dist_core > reach + 0.7:
			continue
		if dist_core > 0.1 and forward.dot(to_core / dist_core) < 0.3:
			continue
		hit_any = true
		var zone = core.get_meta("zone", null)
		if zone != null and is_instance_valid(zone):
			zone.take_damage(damage)
			DamagePopup.show_damage(get_parent(), core.global_position, damage)
	for npc in get_tree().get_nodes_in_group("npcs"):
		var to_npc: Vector3 = npc.global_position - global_position
		to_npc.y = 0.0
		var dist := to_npc.length()
		if dist > reach:
			continue
		if dist > 0.1 and forward.dot(to_npc / dist) < 0.3:
			continue
		hit_any = true
		npc.take_damage(damage, self)
		MeleeFx3D.blood_burst(npc.get_parent(), npc.global_position + Vector3(0, 1.0, 0))
		if not npc.net_puppet:
			_knockback(npc, to_npc)
		DamagePopup.show_damage(npc.get_parent(), npc.global_position + Vector3(0, 1.0, 0), damage)
		if GameState.is_good_zombie():
			GameState.become_bad_zombie()
	for camera in get_tree().get_nodes_in_group("surveillance_cameras"):
		var to_camera: Vector3 = camera.global_position - global_position
		to_camera.y = 0.0
		if to_camera.length() > reach + 1.0:
			continue
		if to_camera.length() > 0.1 and forward.dot(to_camera.normalized()) < 0.2:
			continue
		hit_any = true
		camera.take_damage(damage)
		MeleeFx3D.sparks(camera.get_parent(), camera.global_position)
	if hit_any:
		_shake = 0.8


func take_damage(amount: int) -> void:
	if _dead or GameState.is_run_over():
		return
	if vehicle != null:
		# 驾驶时：怪物攻击由车辆承受（车辆血量），车辆被打爆前玩家不受伤
		if not bool(vehicle.get("destroyed")):
			vehicle.take_damage(amount)
		return
	if Time.get_ticks_msec() < _invulnerable_until:
		return
	_invulnerable_until = Time.get_ticks_msec() + 400
	GameState.damage_player(amount)


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_scoping = false
	BlockyRig.play_death(_body_limbs)
	if Network.is_multiplayer():
		Network.broadcast_died()
		_drop_weapons()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.end_run(false, "你被击倒了，没能撑到撤离")
		return
	if GameState.can_respawn_at_base():
		# 单机复活石：不结算，回到据点复活，保留武器
		_dead = false
		_body_limbs["dead"] = false
		# BlockyRig 死亡是程序化侧倒：复活时复位姿态并回到站立动画
		var rig_root: Node3D = _body_limbs.get("root", null)
		if rig_root != null:
			rig_root.rotation = Vector3.ZERO
		var rig_player: AnimationPlayer = _body_limbs.get("player", null)
		if rig_player != null and rig_player.has_animation("idle"):
			rig_player.play("idle")
		_body_limbs["oneshot_until"] = 0
		GameState.respawn_at_base(self)
		_invulnerable_until = Time.get_ticks_msec() + 2000
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var build := _build_controller()
		if build != null:
			build.force_close()
		return
	_drop_weapons()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.end_run(false, "你被击倒了，没能撑到撤离")


# 据点建造模式控制器（proto3d 挂载，base_build 组）
func _build_controller() -> Node:
	return get_tree().get_first_node_in_group("base_build")


func _on_network_hit(_peer_id: int, damage: int) -> void:
	if _dead or GameState.is_run_over():
		return
	GameState.damage_player(damage)


func _try_surrender() -> void:
	# 通缉系统已彻底删除：不再有投降
	return


func _on_jailed(active: bool) -> void:
	if active:
		if vehicle != null:
			exit_vehicle()
		global_position = GameState.prison_cell_3d()
		velocity = Vector3.ZERO
		_spawn_jail_barrier()
		GameState.notify("越狱没用，老实待着吧")
	else:
		_remove_jail_barrier()
		global_position = GameState.prison_cell_3d() + Vector3(0, 0.3, 3.4)


func _spawn_jail_barrier() -> void:
	if _jail_barrier != null and is_instance_valid(_jail_barrier):
		return
	_jail_barrier = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 3.0, 0.25)
	shape.shape = box
	_jail_barrier.add_child(shape)
	var mesh := MeshInstance3D.new()
	var mesh_box := BoxMesh.new()
	mesh_box.size = Vector3(1.5, 3.0, 0.25)
	mesh.mesh = mesh_box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.57, 0.62)
	mesh.material_override = material
	_jail_barrier.add_child(mesh)
	get_parent().add_child(_jail_barrier)
	_jail_barrier.global_position = GameState.prison_barrier_3d()


func _remove_jail_barrier() -> void:
	if _jail_barrier != null and is_instance_valid(_jail_barrier):
		_jail_barrier.queue_free()
	_jail_barrier = null


# G 举报功能已删除（关联的警察/通缉系统已移除）
func _try_report() -> void:
	return


func _drop_weapons() -> void:
	var owned: Array = []
	for id in ["pistol", "shotgun", "rifle"]:
		if int(GameState.weapons.get(id, 0)) > 0:
			owned.append(id)
	if owned.is_empty():
		return
	var parent := get_parent()
	if parent == null:
		return
	for i in owned.size():
		var drop = WEAPON_DROP_SCENE.instantiate()
		drop.weapon_id = owned[i]
		drop.ammo = maxi(1, GameState.ammo_count(GameState.caliber_of(owned[i])))
		var angle := TAU * float(i) / float(owned.size())
		parent.add_child(drop)
		drop.global_position = global_position + Vector3(cos(angle) * 1.3, 0.2, sin(angle) * 1.3)


# —— 高楼遮挡淡出：每 0.1s 从相机向玩家做分段射线（最多取前 3 个命中）——
func _update_occlusion() -> void:
	var proto := get_parent()
	if proto == null or not (proto.get("occl_buildings") is Array):
		return
	# 矩形相交法：相机→玩家的地面线段与建筑轮廓相交的建筑整体淡出，可靠不依赖射线命中
	var a := Vector2(camera.global_position.x, camera.global_position.z)
	var b := Vector2(global_position.x, global_position.z)
	var wanted := {}
	for entry in proto.occl_buildings:
		var raw: Rect2 = entry["rect"]
		# 玩家真正进入建筑内部才隐藏外壳：矩形内缩 0.6m 判定，贴外墙/站门口坡道不算进楼
		# 窄于 1.2m 的轮廓（细长构筑物）不做内缩判定，避免负尺寸 Rect2
		if raw.size.x > 1.2 and raw.size.y > 1.2 and raw.grow(-0.6).has_point(b):
			for shell in entry.get("shells", []):
				if is_instance_valid(shell) and not _hidden_shells.has(shell):
					_hidden_shells[shell] = raw
					shell.set_meta("occl_hidden", true)
					shell.visible = false
			continue
		var rect: Rect2 = raw.grow(0.15)
		# 只有建筑真的挡在相机与玩家之间才淡出：命中区间必须明显结束在玩家之前，
		# 玩家贴着楼外墙面（命中区间顶到线段末端）不算遮挡
		if not _segment_blocks_view(a, b, rect):
			continue
		for part in entry["parts"]:
			if is_instance_valid(part):
				wanted[part] = true
	for shell in _hidden_shells.keys():
		# 离开该栋后恢复外壳：内缩 0.2m 判定，进出阈值错开避免边界抖动
		var rect: Rect2 = _hidden_shells[shell]
		if not is_instance_valid(shell) or not rect.grow(-0.2).has_point(b):
			if is_instance_valid(shell):
				shell.set_meta("occl_hidden", false)
				shell.visible = true
			_hidden_shells.erase(shell)
	for root in _faded.keys():
		if not is_instance_valid(root) or not wanted.has(root):
			_restore_occluder(root)
	for root in wanted:
		if is_instance_valid(root) and not _faded.has(root):
			_fade_occluder(root)


# 遮挡判定：相机→玩家线段与建筑矩形的相交区间必须真实存在且结束在玩家之前。
# 贴前墙：矩形在玩家身后，相交区间完全落在线段之外 → 不淡出（正确）；
# 贴后墙/在楼后：相交区间结束在玩家之前 → 淡出（人被挡住了）。
func _segment_blocks_view(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var d := b - a
	var tmin := 0.0
	var tmax := 1.0
	for axis in 2:
		var o: float = a[axis]
		var dir: float = d[axis]
		var mn: float = rect.position[axis]
		var mx: float = rect.end[axis]
		if absf(dir) < 0.0001:
			if o < mn or o > mx:
				return false
		else:
			var t1 := (mn - o) / dir
			var t2 := (mx - o) / dir
			tmin = maxf(tmin, minf(t1, t2))
			tmax = minf(tmax, maxf(t1, t2))
			if tmin > tmax:
				return false
	# 相交区间必须严格落在玩家之前（出口离玩家 0.05m 以上）
	return (1.0 - tmax) * d.length() >= 0.05 and tmax > 0.0


func _fade_occluder(root: Node) -> void:
	var entries: Array = []
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	for mi in meshes:
		# 剪影式淡出：统一换成深色半透明无光照材质——遮挡建筑变成干净的影子轮廓，
		# 玩家和地面清晰可见，不会像半透明 X 光那样露出杂乱的内部结构
		var faded := StandardMaterial3D.new()
		faded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		faded.albedo_color = Color(0.09, 0.11, 0.15, 0.22)
		entries.append([mi, mi.material_override])
		mi.material_override = faded
	_faded[root] = entries


func _restore_occluder(root: Node) -> void:
	var entries: Array = _faded.get(root, [])
	for entry in entries:
		var mi = entry[0]
		if is_instance_valid(mi):
			mi.material_override = entry[1]
	_faded.erase(root)
