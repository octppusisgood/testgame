extends CharacterBody3D

const SCALE := 0.05
const GRAVITY := 18.0
# AI 分级（LOD）：按与观察者距离降扫描与动画频率
const LOD_MID_DIST := 28.0
const LOD_FAR_DIST := 55.0
const BULLET_SCENE := preload("res://scenes3d/bullet3d.tscn")
const PICKUP_DROP := preload("res://scripts3d/pickup3d.gd")
const WEAPON_DROP_SCENE := preload("res://scenes3d/weapon_drop3d.tscn")

@export var role := "cop"
@export var patrol_offset := Vector3.ZERO
# 驻军模式（军营）：以营地为中心随机巡逻，追击/战斗不超出 leash 范围
var has_garrison := false
var garrison_center := Vector3.ZERO
var garrison_radius := 25.0
var _garrison_target := Vector3.ZERO
var _garrison_idle := 0.0
@export var patrol_speed := 2.8
@export var vision_range := 16.0
@export var shoot_range := 12.0
@export var damage := 10
@export var max_hp := 40
@export var fire_cooldown := 0.7
@export var bank_guard := false
@export var elite := false
@export var human_tier := 0
@export var showcase := false

var hp := 40
var recruit_price := 0
var hold_still := false
var hostile := false
var armed := false
var _tier_resist := 0.0
var _fly_height := 0.0
var _spin_parts: Array = []
var _hunt_timer := 0.0
var _hunt_target: Node3D = null
var _investigate_pos := Vector3.ZERO
var _investigate_timer := 0.0
var _alert_scan := 0.0
var _bar_root: Node3D = null
var _bar_fill: MeshInstance3D = null
var _bar_label: Label3D = null

var _patrol_a := Vector3.ZERO
var _patrol_b := Vector3.ZERO
var _patrol_target_b := true
var _next_shot_msec := 0
var _wander_dir := Vector3(1, 0, 0)
var _wander_timer := 0.0
var _idle_timer := 0.0
var _flee_target := Vector3.INF
var _flee_done := false
var _alert: Label3D
var _alert_timer := 0.0
var _base_color := Color.WHITE
var _panicked := false
var _panic_timer := 0.0
var _saw_crime_msec := 0
var _limbs := {}
var _avoid_angle := 0.0
var _avoid_timer := 0.0
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _aim_ready_msec := 0
var _aim_target = null
var _look_timer := 0.0
var _look_angle := 0.0
var _flee_from := Vector3.ZERO
var _flee_from_timer := 0.0
var _panic_scan := 0.0
var _share_msec := 0
var net_id := 0
var net_puppet := false
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_moving := false
var _aggro_target: Node3D = null
var _aggro_until_msec := 0
var _aggro_wanted_at_msec := 0
var _aggro_peer := 0
var _shot_scan := 0.0
var _shot_watch_pos := Vector3.ZERO
var _shot_watch_timer := 0.0
var _shot_reported := false
var _heard_shot_msec := 0
var _dying := false
var _lod_level := 0
var _lod_phase := 0


func _ready() -> void:
	add_to_group("npcs")
	GameState.request_spatial_rebuild()
	if showcase:
		set_physics_process(false)
	if human_tier > 0:
		role = "soldier"
	match role:
		"clerk":
			max_hp = 30
			vision_range = 13.0
		"cop":
			max_hp = 30
			vision_range = 13.0
			if bank_guard:
				add_to_group("bank_guards")
				max_hp = 70
				damage = 14
				vision_range = 16.0
				shoot_range = 16.0
		"pedestrian":
			add_to_group("pedestrians")
			max_hp = 25
			vision_range = 12.0
			if recruit_price <= 0:
				recruit_price = randi_range(80, 400)
			if not net_puppet:
				armed = randf() < 0.35
			if armed:
				max_hp = 35
				damage = 8
				vision_range = 13.0
				shoot_range = 14.0
				fire_cooldown = 0.9
				recruit_price = randi_range(200, 600)
		"soldier":
			add_to_group("soldiers")
			max_hp = 80
			damage = 12
			vision_range = 19.0
			shoot_range = 30.0
			if elite:
				add_to_group("human_elites")
				max_hp = 160
				damage = 18
				vision_range = 22.0
				shoot_range = 34.0
				fire_cooldown = minf(fire_cooldown, 0.35)
	hp = max_hp
	if human_tier > 0:
		var stats := GameState.human_tier_info(human_tier)
		if not stats.is_empty():
			max_hp = int(stats["hp"])
			damage = int(stats["damage"])
			shoot_range = float(stats["range"])
			fire_cooldown = float(stats["cooldown"])
			_tier_resist = float(stats["resist"])
			vision_range = maxf(16.0, shoot_range * 0.7)
			hp = max_hp
			scale = Vector3.ONE * float(stats["scale"])
		if human_tier == 9:
			fire_cooldown = 0.12
			damage = 12
			shoot_range = 30.0
			_fly_height = 2.4
		elif human_tier == 10:
			_fly_height = 3.0
			shoot_range = 34.0
		add_to_group("human_hunters")
		if human_tier >= 8:
			add_to_group("human_elites")
	_patrol_a = global_position
	_patrol_b = global_position + patrol_offset
	var style := _make_style()
	_limbs = BlockyRig.build(self, $Mesh as MeshInstance3D, style)
	_base_color = style.get("shirt", Color.WHITE)
	if human_tier == 9:
		_add_gatling()
	elif human_tier > 0:
		_add_gun(human_tier >= 4)
	elif role == "soldier" or (role == "cop" and bank_guard):
		_add_gun(true)
	elif role == "cop" or (role == "pedestrian" and armed):
		_add_gun(false)
	_limbs["aiming"] = (
		human_tier > 0
		or role == "soldier"
		or role == "cop"
		or (role == "pedestrian" and armed)
	)

	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 96
	_alert.modulate = Color(1.0, 0.3, 0.25)
	_alert.position = Vector3(0, 2.2, 0)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.visible = false
	add_child(_alert)

	_net_pos = global_position
	_net_yaw = rotation.y
	_lod_phase = randi() % 4
	if (
		not net_puppet
		and not GameState.test_mode
		and Network.is_multiplayer()
		and Network.is_server()
	):
		Network.register_entity(self, "npc", net_params())


func net_params() -> Dictionary:
	return {
		"role": role,
		"human_tier": human_tier,
		"elite": elite,
		"bank_guard": bank_guard,
		"armed": armed,
	}


func setup_puppet(params: Dictionary) -> void:
	role = String(params.get("role", role))
	human_tier = int(params.get("human_tier", human_tier))
	elite = bool(params.get("elite", elite))
	bank_guard = bool(params.get("bank_guard", bank_guard))
	armed = bool(params.get("armed", armed))


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
	BlockyRig.update(_limbs, delta, 3.0 if _net_moving else 0.0)


func _make_style() -> Dictionary:
	var style := {
		"shirt": Color(0.25, 0.42, 0.88),
		"model": BlockyRig.random_civilian(),
	}
	if human_tier > 0:
		match human_tier:
			2:
				style["model"] = "j"
			3:
				style["model"] = "r"
			4:
				style["model"] = "m"
			5:
				style["model"] = "m"
				style["tint"] = Color(0.7, 0.8, 0.65, 1.0)
			6:
				style["model"] = "r"
				style["tint"] = Color(0.55, 0.55, 0.6, 1.0)
			7:
				style["model"] = "r"
				style["tint"] = Color(0.38, 0.38, 0.42, 1.0)
			8:
				style["model"] = "h"
				style["bulk"] = 1.25
			9:
				style["model"] = "g"
				style["bulk"] = 1.35
			10:
				style["model"] = "g"
				style["tint"] = Color(1.25, 1.05, 0.5, 1.0)
				style["bulk"] = 1.3
		return style
	match role:
		"cop":
			style["model"] = "q" if bank_guard else "j"
		"clerk":
			style["model"] = "q" if randf() < 0.5 else "i"
		"soldier":
			style["model"] = "m"
	return style


func _update_report_bar() -> void:
	var progress := GameState.report_progress_for(self)
	if progress <= 0.0:
		if _bar_root != null:
			_bar_root.visible = false
		return
	if _bar_root == null:
		_build_report_bar()
	_bar_root.visible = true
	_bar_fill.scale = Vector3(maxf(progress, 0.03), 1.0, 1.0)
	_bar_fill.position = Vector3(-0.6 * (1.0 - progress), 0.0, 0.01)
	_bar_label.text = "报警中 %d%%" % int(progress * 100.0)


func _build_report_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, 2.5, 0)
	add_child(_bar_root)
	_quad(Vector3(1.28, 0.22, 0.0), Vector3.ZERO, Color(0.05, 0.05, 0.05, 0.85))
	_bar_fill = _quad(Vector3(1.2, 0.16, 0.0), Vector3(-0.6, 0, 0.01), Color(0.95, 0.25, 0.2))
	_bar_label = Label3D.new()
	_bar_label.font_size = 44
	_bar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_label.position = Vector3(0, 0.4, 0)
	_bar_label.modulate = Color(1.0, 0.65, 0.55)
	_bar_label.outline_size = 10
	_bar_label.outline_modulate = Color(0, 0, 0, 0.85)
	_bar_root.add_child(_bar_label)


func _quad(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x, size.y)
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	mesh.material_override = material
	mesh.position = pos
	_bar_root.add_child(mesh)
	return mesh


func _add_gun(is_rifle: bool) -> void:
	var gun := Node3D.new()
	gun.add_child(_mesh_part(
		Vector3(0.09, 0.11, 1.2) if is_rifle else Vector3(0.08, 0.15, 0.42),
		Vector3.ZERO,
		Color(0.12, 0.12, 0.14)
	))
	if is_rifle:
		gun.add_child(_mesh_part(Vector3(0.08, 0.1, 0.35), Vector3(0, 0, 0.55), Color(0.32, 0.22, 0.14)))
	else:
		gun.add_child(_mesh_part(Vector3(0.08, 0.18, 0.1), Vector3(0, -0.1, 0.06), Color(0.2, 0.2, 0.22)))
	if BlockyRig.attach_gun(_limbs, gun, is_rifle):
		return
	add_child(gun)
	gun.position = Vector3(0.3, 1.0, -0.35)


func _mesh_part(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	mesh.position = pos
	return mesh


func _process(delta: float) -> void:
	# 名牌/血条/警戒标距离隐藏：>45m 不画（每个 Label3D 都是独立 draw call，怪群时可观）
	if _bar_root != null:
		if _lod_level >= 1:
			if _bar_root.visible:
				_bar_root.visible = false
			if _alert != null and _alert.visible:
				_alert.visible = false
		elif not _bar_root.visible:
			_bar_root.visible = true
	if (
		GameState.viewer_active
		and global_position.distance_to(GameState.viewer_position) > 150.0
	):
		return
	# 远距降载：与物理同频隔帧（感染转化计时在跳过帧也持续推进）
	var proc_step := 1
	if _lod_level == 1:
		proc_step = 2
	elif _lod_level == 2:
		proc_step = 4
	if proc_step > 1 and (Engine.get_process_frames() + _lod_phase) % proc_step != 0:
		return
	if proc_step > 1:
		delta *= float(proc_step)
	_update_report_bar()
	for part in _spin_parts:
		if part != null and is_instance_valid(part):
			part.rotate_z(delta * 9.0)
	if _alert_timer > 0.0:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			_alert.visible = false
	if role == "pedestrian" and not _panicked and GameState.zombies_active():
		_panic_timer -= delta
		if _panic_timer <= 0.0:
			_panic_timer = 0.6 * _scan_mult()
			var zombie := _nearest_zombie(vision_range)
			if zombie != null and can_see_node(zombie):
				_panicked = true
				show_alert()


func witness_crime() -> void:
	_saw_crime_msec = Time.get_ticks_msec()
	show_alert()


func _civilian_hostile() -> bool:
	if not armed:
		return false
	if GameState.wanted > 0 or GameState.is_outlaw():
		return true
	return _saw_crime_msec > 0 and Time.get_ticks_msec() - _saw_crime_msec < 20000


func show_alert() -> void:
	_alert.visible = true
	_alert_timer = 2.5


func _physics_process(delta: float) -> void:
	if net_puppet:
		_puppet_tick(delta)
		return
	if hold_still:
		# 玩家打开交互菜单时站定不动
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if (
		GameState.viewer_active
		and global_position.distance_to(GameState.viewer_position) > 150.0
	):
		velocity = Vector3.ZERO
		return
	var viewer_dist := (
		global_position.distance_to(GameState.viewer_position)
		if GameState.viewer_active
		else 0.0
	)
	_lod_level = 0 if viewer_dist < LOD_MID_DIST else (1 if viewer_dist < LOD_FAR_DIST else 2)
	BlockyRig.set_lod_frozen(_limbs, _lod_level == 2)
	# 远距降载：非战斗/非恐慌状态隔帧跑完整逻辑（LOD1 1/2、LOD2 1/4，相位错开），
	# 跳过的帧速度与姿势冻结——远处市民没有必要每帧做决策和碰撞
	var ai_step := 1
	if _lod_level == 1:
		ai_step = 2
	elif _lod_level == 2:
		ai_step = 4
	if ai_step > 1 and not _panicked and not _civilian_hostile():
		if (Engine.get_physics_frames() + _lod_phase) % ai_step != 0:
			return
		delta *= float(ai_step)
	var player = (
		null
		if GameState.test_mode
		else get_tree().get_first_node_in_group("player")
	)
	_gunshot_attention(delta)
	match role:
		"cop":
			var aggro := _aggro_active()
			var hunted_player := _wanted_player_target()
			if aggro != null:
				_combat_player(aggro, 3.4, 0.8, delta)
				_check_aggro_wanted()
			elif hunted_player != null:
				if GameState.phase == "prepare" and not GameState.is_outlaw():
					_arrest_chase(hunted_player, delta)
				else:
					_combat_player(hunted_player, 3.2, 0.9, delta)
			elif _investigate_walk(delta):
				pass
			else:
				var hunted := _cached_visible_zombie(12.0, delta)
				if hunted != null:
					_shoot_at(hunted, 0.9)
					_face(hunted.global_position)
					velocity.x = 0.0
					velocity.z = 0.0
					_share_zombie_alert(hunted)
				else:
					_patrol(delta)
		"soldier":
			# 士兵独立交战模式：不受测试模式 player 置空影响，直接取真实玩家
			var intruder := get_tree().get_first_node_in_group("player")
			if GameState.wanted > 0 or GameState.is_outlaw():
				hostile = true
			if has_garrison and _garrison_overextended():
				# 追出营地太远：脱战，掉头回营（不会一直追击）
				hostile = false
				var home := garrison_center - global_position
				home.y = 0.0
				_move_dir(home.normalized(), 2.6, delta)
				_face(garrison_center)
			elif hostile and intruder != null and not bool(intruder.get("_dead")):
				_soldier_combat(intruder, delta)
			else:
				var hunted := _cached_visible_zombie(shoot_range, delta)
				if hunted != null:
					# 士兵打丧尸：射程外主动推进，射程内站定开火
					var zdist := global_position.distance_to(hunted.global_position)
					_face(hunted.global_position)
					_share_zombie_alert(hunted)
					if zdist > shoot_range * 0.8:
						var to_z: Vector3 = hunted.global_position - global_position
						to_z.y = 0.0
						_move_dir(to_z.normalized(), 2.8, delta)
					else:
						_shoot_at(hunted, fire_cooldown)
						velocity.x = 0.0
						velocity.z = 0.0
				elif has_garrison:
					_garrison_patrol(delta)
				else:
					velocity.x = 0.0
					velocity.z = 0.0
		"pedestrian":
			if armed and _civilian_hostile():
				if player != null and not GameState.jail_active:
					_combat_player(player, 2.6, fire_cooldown, delta)
				else:
					_wander_or_flee(delta)
			else:
				_wander_or_flee(delta)
		_:
			_idle_wander(delta)
	if _shot_watch_timer > 0.0:
		_face(_shot_watch_pos)
	if not is_on_floor() and _fly_height <= 0.0:
		velocity.y -= GRAVITY * delta
	elif _fly_height > 0.0:
		var target_y := _fly_height + sin(Time.get_ticks_msec() * 0.002) * 0.25
		velocity.y = (target_y - global_position.y) * 3.0
	else:
		velocity.y = 0.0
	# 兜底：万一已经穿过地面（旧逻辑残留 / 被物理推挤），拉回地面，
	# 否则它会在地底一路下坠，小地图却一直画着它的点（"有点没人"）
	if global_position.y < -1.0:
		global_position.y = 0.2
		velocity.y = 0.0
	if _lod_level == 2 and not _panicked and not _civilian_hostile():
		# 超远市民免碰撞直移：不做物理查询，近处恢复 LOD 后由 move_and_slide 接管。
		# 直移不过物理，竖直方向必须自己钉死：NPC 池化唤醒/新建出来的 CharacterBody3D
		# 尚未调用过 move_and_slide，is_on_floor() 仍是 false，照常吃重力再直移（无碰撞）
		# 就会一路穿过地面沉到地图下方——小地图照画它的点，世界里却永远找不到人
		# （只在玩家走动触发池化唤醒后出现）
		if _fly_height <= 0.0:
			velocity.y = 0.0
		global_position += velocity * delta
	else:
		move_and_slide()
	# 远距市民降动画频率：隔帧更新，跳过的帧保留当前姿势
	var anim_step := 1
	if _lod_level == 1:
		anim_step = 2
	elif _lod_level == 2:
		anim_step = 4
	if anim_step == 1 or (Engine.get_physics_frames() + _lod_phase) % anim_step == 0:
		var speed := Vector2(velocity.x, velocity.z).length()
		BlockyRig.update(_limbs, delta * anim_step, speed)


# LOD 扫描频率倍率：近全频，中 ×2，远 ×4
func _scan_mult() -> float:
	return 1.0 if _lod_level == 0 else (2.0 if _lod_level == 1 else 4.0)


func _investigate_walk(delta: float) -> bool:
	_alert_scan -= delta
	if _alert_scan <= 0.0:
		_alert_scan = 0.5
		if _investigate_timer <= 0.0:
			var shot := GameState.recent_gunshot(global_position)
			if shot != Vector3.ZERO:
				_investigate_pos = shot
				_investigate_timer = 12.0
	if _investigate_timer <= 0.0:
		return false
	_investigate_timer -= delta
	var to := _investigate_pos - global_position
	to.y = 0.0
	if to.length() < 2.0:
		if _look_timer <= 0.0:
			_look_timer = randf_range(2.5, 4.0)
			_look_angle = 0.0
		_look_timer -= delta
		_look_angle += delta * 1.7
		velocity.x = 0.0
		velocity.z = 0.0
		_face(global_position + Vector3(sin(_look_angle), 0.0, cos(_look_angle)) * 6.0)
		if _look_timer <= 0.0:
			_investigate_timer = 0.0
		return true
	_look_timer = 0.0
	_move_dir(to.normalized(), 3.0, delta)
	_face(_investigate_pos)
	return true


func _arrest_chase(target: Node3D, delta: float) -> void:
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	_face(target.global_position)
	if dist > 0.1:
		_move_dir(to_target.normalized(), 3.4, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if dist <= 2.6:
		GameState.jail_player(GameState.JAIL_SECONDS)


func _combat_player(player: Node3D, speed: float, cooldown_sec: float, delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if can_see_node(player):
		GameState.mark_seen()
		show_alert()
	_face(player.global_position)
	if _line_of_sight(player) and dist <= shoot_range:
		_shoot_at(player, cooldown_sec)
		if dist < 5.0:
			var back := global_position - player.global_position
			back.y = 0.0
			_move_dir(back.normalized(), speed * 0.7, delta)
		elif dist > 9.5:
			var forward := player.global_position - global_position
			forward.y = 0.0
			_move_dir(forward.normalized(), speed * 0.6, delta)
		else:
			_strafe(delta, speed * 0.55)
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		_move_dir(to_player.normalized(), speed, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _shoot_at(target: Node3D, cooldown_sec: float) -> void:
	if not _line_of_sight(target):
		_aim_target = null
		return
	if target != _aim_target:
		_aim_target = target
		_aim_ready_msec = Time.get_ticks_msec() + int(randf_range(250.0, 700.0))
	if Time.get_ticks_msec() < _aim_ready_msec:
		return
	if Time.get_ticks_msec() < _next_shot_msec:
		return
	var dist := global_position.distance_to(target.global_position)
	if human_tier == 10:
		if dist < 2.8:
			_next_shot_msec = Time.get_ticks_msec() + 700
			target.take_damage(35)
			BlockyRig.play_once(_limbs, "attack-melee-right")
		else:
			_next_shot_msec = Time.get_ticks_msec() + int(maxf(cooldown_sec, 1.1) * 1000.0)
			target.take_damage(45)
			_laser_beam(target)
			BlockyRig.play_once(_limbs, "holding-right-shoot")
		return
	_next_shot_msec = Time.get_ticks_msec() + int(cooldown_sec * 1000.0)
	var from := global_position + Vector3(0, 1.45, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)
	var dir := (to - from).normalized()
	var spread := 0.06 if human_tier == 9 else 0.02
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var muzzle := from + dir * 0.7
	_flash(muzzle)
	var bullet = BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.setup(muzzle, dir, damage, self, false)
	BlockyRig.play_once(_limbs, "holding-right-shoot")


func _laser_beam(target: Node3D) -> void:
	var from := global_position + Vector3(0, 1.75, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, from.distance_to(to))
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.15, 0.15)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.2, 0.2)
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	get_parent().add_child(mesh)
	mesh.global_position = (from + to) / 2.0
	mesh.look_at(to, Vector3.UP)
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale:x", 0.05, 0.12)
	tween.parallel().tween_property(mesh, "scale:y", 0.05, 0.12)
	tween.tween_callback(mesh.queue_free)


func _add_gatling() -> void:
	var gun := Node3D.new()
	gun.add_child(_mesh_part(Vector3(0.14, 0.16, 0.5), Vector3.ZERO, Color(0.15, 0.15, 0.17)))
	var barrel_root := Node3D.new()
	barrel_root.position = Vector3(0, 0, -0.45)
	gun.add_child(barrel_root)
	for i in 4:
		var barrel := _mesh_part(
			Vector3(0.04, 0.04, 0.55), Vector3.ZERO, Color(0.22, 0.22, 0.24)
		)
		var angle := TAU * float(i) / 4.0
		barrel.position = Vector3(cos(angle) * 0.05, sin(angle) * 0.05, 0)
		barrel_root.add_child(barrel)
	_spin_parts.append(barrel_root)
	if BlockyRig.attach_gun(_limbs, gun, true):
		return
	add_child(gun)
	gun.position = Vector3(0.3, 1.0, -0.45)


func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _flash(pos: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.16)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.5)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.global_position = pos
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale", Vector3(0.05, 0.05, 0.05), 0.07)
	tween.tween_callback(mesh.queue_free)


func _move_dir(dir: Vector3, speed: float, delta: float) -> void:
	var d := _avoid_tick(dir, delta)
	velocity.x = d.x * speed
	velocity.z = d.z * speed


func _avoid_tick(desired: Vector3, delta: float) -> Vector3:
	if desired.length() < 0.05:
		return Vector3.ZERO
	_avoid_timer -= delta
	if _avoid_timer <= 0.0:
		_avoid_timer = randf_range(0.12, 0.22)
		# 远距市民不做避障射线检测，中距只测 3 个方向
		if _lod_level == 2:
			_avoid_angle = 0.0
		elif _lod_level == 1:
			_avoid_angle = _pick_clear_angle(desired.normalized(), [0.0, 0.45, -0.45])
		else:
			_avoid_angle = _pick_clear_angle(desired.normalized())
	return desired.rotated(Vector3.UP, _avoid_angle)


func _pick_clear_angle(desired: Vector3, angles: Array = [0.0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4, 2.1, -2.1]) -> float:
	var origin := global_position + Vector3(0, 1.0, 0)
	for angle in angles:
		var dir := desired.rotated(Vector3.UP, angle)
		var query := PhysicsRayQueryParameters3D.create(
			origin, origin + dir * 2.0, 1, [get_rid()]
		)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return angle
	return PI


func _strafe(delta: float, speed: float) -> void:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.8, 1.8)
		if randf() < 0.35:
			_strafe_sign = -_strafe_sign
	_move_dir(global_transform.basis.x * _strafe_sign, speed, delta)


func _share_zombie_alert(zombie: Node3D) -> void:
	if Time.get_ticks_msec() - _share_msec < 4000:
		return
	_share_msec = Time.get_ticks_msec()
	for npc in GameState.entities_in_group_in_radius(global_position, "npcs", 30.0):
		if npc == self:
			continue
		if npc.role != "cop" and npc.role != "soldier":
			continue
		npc.receive_zombie_alert(zombie.global_position)


func receive_zombie_alert(pos: Vector3) -> void:
	if _investigate_timer > 0.0:
		return
	_investigate_pos = pos
	_investigate_timer = 8.0


func _patrol(delta: float) -> void:
	if patrol_offset == Vector3.ZERO:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target := _patrol_b if _patrol_target_b else _patrol_a
	if global_position.distance_to(target) < 0.5:
		_patrol_target_b = not _patrol_target_b
		target = _patrol_b if _patrol_target_b else _patrol_a
	var dir := (target - global_position)
	dir.y = 0.0
	_move_dir(dir.normalized(), patrol_speed, delta)
	_face(target)


# 驻军 leash：离营地中心超过巡逻半径 +8m 视为追出太远
func _garrison_overextended() -> bool:
	var flat := Vector2(
		global_position.x - garrison_center.x, global_position.z - garrison_center.z
	)
	return flat.length() > garrison_radius + 8.0


# 驻军巡逻：营地半径内随机选点走动，到点歇 1~3 秒再选下一点
func _garrison_patrol(delta: float) -> void:
	if _garrison_target == Vector3.ZERO or global_position.distance_to(_garrison_target) < 0.8:
		_garrison_idle -= delta
		if _garrison_idle <= 0.0:
			_garrison_idle = randf_range(1.0, 3.0)
			var angle := randf() * TAU
			var r := sqrt(randf()) * garrison_radius * 0.8
			_garrison_target = garrison_center + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := _garrison_target - global_position
	dir.y = 0.0
	_move_dir(dir.normalized(), patrol_speed, delta)
	_face(_garrison_target)


func _idle_wander(delta: float) -> void:
	if _shot_watch_timer > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(1.5, 3.5)
		if randf() < 0.4:
			_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		else:
			_wander_dir = Vector3.ZERO
	_move_dir(_wander_dir, 0.9, delta)
	if _wander_dir.length() > 0.1:
		_face(global_position + _wander_dir)


func _wander_or_flee(delta: float) -> void:
	_scan_gunshots(delta)
	if _shot_watch_timer > 0.0:
		# 先转头看一眼枪声方向，再逃跑
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if not _panicked:
		_wander(delta)
		return
	if _flee_done:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if _flee_target == Vector3.INF:
		_flee_target = _pick_shelter()
	if _flee_target != Vector3.INF:
		if global_position.distance_to(_flee_target) < 3.0:
			_flee_done = true
			velocity.x = 0.0
			velocity.z = 0.0
			return
		var dir := (_flee_target - global_position)
		dir.y = 0.0
		_move_dir(dir.normalized(), 4.0, delta)
		_face(_flee_target)
		return
	var threat := _nearest_zombie(18.0)
	if threat != null:
		var away := (global_position - threat.global_position)
		away.y = 0.0
		_move_dir(away.normalized(), 4.2, delta)
		return
	if _flee_from_timer > 0.0:
		_flee_from_timer -= delta
		var away := global_position - _flee_from
		away.y = 0.0
		if away.length() < 0.5:
			away = Vector3(1, 0, 0)
		_move_dir(away.normalized(), 4.4, delta)
		_face(global_position + away)
		return
	_wander(delta)


# 逃向避难处：玩家据点优先，否则最近的建筑
func _pick_shelter() -> Vector3:
	if GameState.has_home_base():
		return GameState.home_base["position"]
	return _nearest_building_pos()


func _nearest_building_pos() -> Vector3:
	var best := Vector3.INF
	var best_dist := INF
	for entry in GameState.BUILDING_LAYOUT:
		var pos := _vec2_to_3d(entry["position"])
		var dist := global_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best = pos
	return best


func _scan_gunshots(delta: float) -> void:
	_panic_scan -= delta
	if _panic_scan > 0.0:
		return
	_panic_scan = randf_range(0.4, 0.7)
	var shot := GameState.recent_gunshot(global_position, 45.0)
	if shot == Vector3.ZERO or _flee_from_timer > 0.0:
		return
	_flee_from = shot
	_flee_from_timer = 6.0
	_panicked = true
	if _panic_timer <= 0.0:
		_panic_timer = 6.0


# 士兵专用交战（与警察的保持距离打法不同）：主动向射程推进，进入射程站定齐射
func _soldier_combat(player: Node3D, delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	if can_see_node(player):
		show_alert()
	_face(player.global_position)
	if _line_of_sight(player) and dist <= shoot_range:
		_shoot_at(player, fire_cooldown)
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		_move_dir(to_player.normalized(), 3.4, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


# 士兵不受枪声惊吓/分心（机枪就在头顶开火，免疫枪声注意机制）
func _gunshot_attention(delta: float) -> void:
	if role == "soldier":
		return
	if _shot_watch_timer > 0.0:
		if _in_combat():
			_shot_watch_timer = 0.0
			return
		_shot_watch_timer -= delta
		if not _shot_reported:
			_shot_reported = true
			_try_identify_shooter()
		return
	_shot_scan -= delta
	if _shot_scan > 0.0:
		return
	_shot_scan = randf_range(0.3, 0.6)
	if _in_combat():
		return
	var alert := GameState.recent_gunshot_entry(global_position, 999.0)
	if alert.is_empty():
		return
	var msec := int(alert.get("time", 0))
	if msec <= _heard_shot_msec:
		return
	_heard_shot_msec = msec
	_shot_watch_pos = alert["pos"]
	_shot_watch_timer = randf_range(1.0, 1.5)
	_shot_reported = false


func _in_combat() -> bool:
	match role:
		"cop":
			return _aggro_active() != null or _wanted_player_target() != null
		"soldier":
			return hostile
		"pedestrian":
			return armed and _civilian_hostile()
	return false


func _try_identify_shooter() -> void:
	if GameState.test_mode or GameState.is_run_over():
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if not can_see_node(player):
		return
	GameState.report_crime(1, self)
	show_alert()


func _wander(delta: float) -> void:
	var speed := 2.2
	if GameState.is_night():
		# 夜里减少游荡，优先朝最近的建筑走
		speed *= 0.5
		var shelter := _nearest_building_pos()
		if shelter != Vector3.INF:
			var to_shelter := shelter - global_position
			to_shelter.y = 0.0
			if to_shelter.length() > 2.0:
				_move_dir(to_shelter.normalized(), speed, delta)
				_face(shelter)
				return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.5, 3.5)
		_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_move_dir(_wander_dir, speed, delta)
	if _wander_dir.length() > 0.1:
		_face(global_position + _wander_dir)


func _nearest_zombie(radius: float) -> Node3D:
	return GameState.nearest_entity_in_group(global_position, "zombies", radius) as Node3D


func _wanted_player_target() -> Node3D:
	if GameState.test_mode:
		return null
	var best: Node3D = null
	var best_dist := 60.0
	var player = get_tree().get_first_node_in_group("player")
	var player_wanted := (
		GameState.wanted > 0 or GameState.is_outlaw() or GameState.is_bad_zombie()
	)
	if Network.is_multiplayer() and Network.is_wanted(Network.my_id()):
		player_wanted = true
	if player != null and player_wanted:
		var d := global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best = player
	if not Network.is_multiplayer():
		return best
	for remote in get_tree().get_nodes_in_group("remote_players"):
		if not Network.is_wanted(remote.peer_id):
			continue
		var rd := global_position.distance_to(remote.global_position)
		if rd < best_dist:
			best_dist = rd
			best = remote
	return best


func _cached_visible_zombie(radius: float, delta: float) -> Node3D:
	_hunt_timer -= delta
	if (
		_hunt_timer <= 0.0
		or _hunt_target == null
		or not is_instance_valid(_hunt_target)
	):
		_hunt_timer = randf_range(0.3, 0.5) * _scan_mult()
		_hunt_target = _visible_zombie(radius)
	return _hunt_target


func _visible_zombie(radius: float) -> Node3D:
	var nearest := _nearest_zombie(radius)
	if nearest == null:
		return null
	if not _line_of_sight(nearest):
		return null
	return nearest


func _vec2_to_3d(pos: Vector2) -> Vector3:
	return Vector3(pos.x * SCALE, 0.1, pos.y * SCALE)


func _face(pos: Vector3) -> void:
	var flat := Vector3(pos.x, global_position.y, pos.z)
	if flat.distance_to(global_position) > 0.15:
		look_at(flat, Vector3.UP)


func can_see_node(target: Node3D) -> bool:
	if global_position.distance_to(target.global_position) > vision_range:
		return false
	return _line_of_sight(target)


func _line_of_sight(target: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.45, 0)
	var to := target.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == target


func take_damage(amount: int, from: Node3D = null) -> void:
	if net_puppet:
		if Network.is_multiplayer():
			Network.request_entity_damage(net_id, amount)
		return
	if _dying:
		return
	hp -= amount
	if _tier_resist > 0.0:
		hp += int(round(float(amount) * _tier_resist))
	if hp <= 0:
		_die(from)
		return
	if role == "soldier":
		for soldier in get_tree().get_nodes_in_group("soldiers"):
			soldier.hostile = true
	if (
		from != null
		and is_instance_valid(from)
		and (from.is_in_group("player") or from.is_in_group("remote_players"))
		and not GameState.test_mode
		and (role == "cop" or role == "soldier")
	):
		_start_player_aggro(from)
	var mesh := $Mesh as MeshInstance3D
	var material := mesh.material_override as StandardMaterial3D
	if not _limbs.get("meshes", []).is_empty():
		Humanoid.set_overlay(_limbs, Color(1.0, 0.35, 0.3, 0.55))
		var tween := create_tween()
		tween.tween_method(
			_overlay_flash.bind(_limbs.get("base_overlay", Color(0, 0, 0, 0))),
			Color(1.0, 0.35, 0.3, 0.55),
			_limbs.get("base_overlay", Color(0, 0, 0, 0)),
			0.25
		)
	elif material != null:
		material.albedo_color = Color(1.0, 0.4, 0.4)
		var tween := create_tween()
		tween.tween_method(
			func(color: Color) -> void: material.albedo_color = color,
			Color(1.0, 0.4, 0.4),
			_base_color,
			0.2
		)


func _overlay_flash(color: Color, base: Color) -> void:
	Humanoid.set_overlay(_limbs, color if color.a > base.a else base)


func _start_player_aggro(attacker: Node3D) -> void:
	if _aggro_target == null or not is_instance_valid(_aggro_target):
		_aggro_target = attacker
		_aggro_until_msec = Time.get_ticks_msec() + 12000
		_aggro_wanted_at_msec = Time.get_ticks_msec() + 3000
		_aggro_peer = int(attacker.peer_id) if attacker.is_in_group("remote_players") else 0
		show_alert()
		GameState.notify("警察遭到攻击，直接还击！3 秒内没放倒你就会被直接通缉")
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self or not is_instance_valid(npc) or npc.net_puppet:
			continue
		if npc.role != "cop" and npc.role != "soldier":
			continue
		if global_position.distance_to(npc.global_position) > 25.0:
			continue
		npc.receive_player_aggro(attacker, _aggro_peer)


func receive_player_aggro(attacker: Node3D, peer: int) -> void:
	if _aggro_target != null and is_instance_valid(_aggro_target):
		return
	_aggro_target = attacker
	_aggro_until_msec = Time.get_ticks_msec() + 12000
	_aggro_wanted_at_msec = Time.get_ticks_msec() + 3000
	_aggro_peer = peer
	show_alert()


func _aggro_active() -> Node3D:
	if _aggro_target == null or not is_instance_valid(_aggro_target):
		return null
	if Time.get_ticks_msec() > _aggro_until_msec:
		return null
	return _aggro_target


func _check_aggro_wanted() -> void:
	if _aggro_wanted_at_msec <= 0:
		return
	if Time.get_ticks_msec() < _aggro_wanted_at_msec:
		return
	_aggro_wanted_at_msec = 0
	if _aggro_target == null or not is_instance_valid(_aggro_target):
		return
	if _aggro_target.is_in_group("remote_players"):
		if Network.is_multiplayer() and Network.is_server() and _aggro_peer != 0:
			Network.mark_wanted(_aggro_peer)
			Network.net_sync_wanted.rpc(Network.wanted_peers.keys())
		return
	GameState.crime_points += 3
	GameState.set_wanted(3)
	GameState.notify("3 秒内没能击毙你——警方直接下发通缉令（3 星）")


func take_damage_authoritative(amount: int, _from_peer: int) -> void:
	take_damage(amount)


func _die(from: Node3D) -> void:
	if _dying:
		return
	_dying = true
	Network.unregister_entity(self)
	if bank_guard and not GameState.vault_key:
		GameState.take_vault_key()
	_drop_loot()
	if from != null and from.is_in_group("player"):
		var witness := _witnessed_by_other()
		GameState.report_kill(global_position, witness, 3 if role == "cop" else 2)
	if not BlockyRig.play_death(_limbs):
		queue_free()
		return
	set_physics_process(false)
	set_process(false)
	_alert.visible = false
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	# 暂停中也照常释放尸体，避免尸体节点滞留组里
	var tween := get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.5)
	tween.tween_callback(queue_free)


func _witnessed_by_other() -> Node3D:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	for other in get_tree().get_nodes_in_group("npcs"):
		if other == self or other.is_queued_for_deletion():
			continue
		if other.can_see_node(player):
			other.show_alert()
			if other.has_method("witness_crime"):
				other.witness_crime()
			return other
	return null


func _drop_loot() -> void:
	var cash := 0
	var wallet_name := ""
	match role:
		"cop":
			cash = 80
			wallet_name = "警察钱包"
		"pedestrian":
			cash = 30 + randi_range(0, 40)
			wallet_name = "路人的钱包"
		"clerk":
			cash = 50
			wallet_name = "店员钱包"
		_:
			cash = 0
			wallet_name = "军用物资"
	PICKUP_DROP.spawn_merged(get_parent(), "cash", position + Vector3(0, 0.1, 0), 0, wallet_name, cash)
	if human_tier > 0:
		var drop = WEAPON_DROP_SCENE.instantiate()
		if human_tier >= 4:
			drop.weapon_id = "rifle"
			drop.ammo = 12 + human_tier * 2
		else:
			drop.weapon_id = "pistol"
			drop.ammo = 6
		drop.position = position + Vector3(0.5, 0.0, 0.5)
		get_parent().add_child(drop)
	elif role == "soldier" or role == "cop" or (role == "pedestrian" and armed):
		var drop = WEAPON_DROP_SCENE.instantiate()
		if role == "soldier" or bank_guard:
			drop.weapon_id = "rifle"
			drop.ammo = 12
		else:
			drop.weapon_id = "pistol"
			drop.ammo = 8 if role == "pedestrian" else 6
		drop.position = position + Vector3(0.5, 0.0, 0.5)
		get_parent().add_child(drop)
