class_name XianiiRig
extends RefCounted

# 程序化 chibi 少女模型（4 头身，总高约 1.15m）：粉长卷发 + 白夹克 + 黑百褶裙 + 黑猫发夹
# 正面朝 -Z（与 fps_player 身体朝向一致），纯 BoxMesh/CylinderMesh 图元 + StandardMaterial3D 纯色

const HAIR := Color("F49BC2")
const HAIR_DARK := Color("D44487")
const SKIN := Color("FFE3D6")
const EYE := Color("601B54")
const WHITE := Color("FFFFFF")
const JACKET := Color("FAF8FB")
const TRIM := Color("353556")
const BOW := Color("D44487")
const SKIRT := Color("3F3F4F")
const SOCK := Color("2B2B38")
const BOOT := Color("3F3F4F")
const SOLE := Color("232330")
const PACK := Color("26262E")
const MOUTH := Color("C04A6E")
const CLIP := Color("1B1B22")

const HEAD_Y := 0.99
const ARM_RAISE := 1.45

static var _mat_cache := {}


static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mat_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		_mat_cache[key] = material
	return _mat_cache[key]


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat(color)
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


static func _cylinder(
	parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat(color)
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


static func build(body: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "XianiiRig"
	body.add_child(root)
	var rig := {
		"xianii": true,
		"root": root,
		"head": null,
		"torso": null,
		"arm_left": null,
		"arm_right": null,
		"leg_left": null,
		"leg_right": null,
		"skirt": null,
		"backpack": null,
		"hair_back": [],
		"hand_right": null,
		"aiming": false,
		"dead": false,
		"time": 0.0,
		"phase": 0.0,
		"aim_raise": 0.0,
	}
	_build_legs(root, rig)
	_build_skirt(root, rig)
	_build_torso(root, rig)
	_build_arms(root, rig)
	_build_head(root, rig)
	return rig


static func _build_legs(root: Node3D, rig: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.08, 0.44, 0.0)
		root.add_child(pivot)
		# 黑袜 + 粉条纹
		_box(pivot, Vector3(0.08, 0.26, 0.09), Vector3(0.0, -0.17, 0.0), SOCK)
		_box(pivot, Vector3(0.085, 0.025, 0.095), Vector3(0.0, -0.09, 0.0), HAIR_DARK)
		# 厚底靴：鞋身 + 鞋底 + 粉色鞋带
		_box(pivot, Vector3(0.10, 0.11, 0.16), Vector3(0.0, -0.355, 0.02), BOOT)
		_box(pivot, Vector3(0.105, 0.035, 0.17), Vector3(0.0, -0.425, 0.02), SOLE)
		_box(pivot, Vector3(0.055, 0.07, 0.012), Vector3(0.0, -0.345, -0.062), HAIR_DARK)
		if side < 0.0:
			rig["leg_left"] = pivot
		else:
			rig["leg_right"] = pivot


static func _build_skirt(root: Node3D, rig: Dictionary) -> void:
	var skirt := Node3D.new()
	skirt.position = Vector3(0.0, 0.53, 0.0)
	root.add_child(skirt)
	# 百褶裙（喇叭圆柱剪影）+ 裙摆粉色线条
	_cylinder(skirt, 0.17, 0.26, 0.16, Vector3(0.0, -0.02, 0.0), SKIRT)
	_cylinder(skirt, 0.255, 0.265, 0.02, Vector3(0.0, -0.10, 0.0), HAIR_DARK)
	rig["skirt"] = skirt


static func _build_torso(root: Node3D, rig: Dictionary) -> void:
	var torso := Node3D.new()
	torso.position = Vector3(0.0, 0.68, 0.0)
	root.add_child(torso)
	# 白色开襟夹克 + 深藏青饰边
	_box(torso, Vector3(0.30, 0.30, 0.19), Vector3.ZERO, JACKET)
	_box(torso, Vector3(0.30, 0.025, 0.195), Vector3(0.0, -0.14, 0.0), TRIM)
	_box(torso, Vector3(0.028, 0.26, 0.02), Vector3(-0.045, 0.0, -0.095), TRIM)
	_box(torso, Vector3(0.028, 0.26, 0.02), Vector3(0.045, 0.0, -0.095), TRIM)
	# 黑色水手领（白领条）
	_box(torso, Vector3(0.33, 0.06, 0.23), Vector3(0.0, 0.145, 0.02), CLIP)
	_box(torso, Vector3(0.33, 0.014, 0.23), Vector3(0.0, 0.178, 0.02), JACKET)
	# 胸前大粉色蝴蝶结：结 + 双翼 + 双飘带
	_box(torso, Vector3(0.035, 0.035, 0.03), Vector3(0.0, 0.03, -0.105), BOW)
	var wing_l := _box(torso, Vector3(0.075, 0.05, 0.02), Vector3(-0.055, 0.03, -0.10), BOW)
	wing_l.rotation.z = 0.3
	var wing_r := _box(torso, Vector3(0.075, 0.05, 0.02), Vector3(0.055, 0.03, -0.10), BOW)
	wing_r.rotation.z = -0.3
	_box(torso, Vector3(0.028, 0.07, 0.015), Vector3(-0.022, -0.045, -0.10), BOW)
	_box(torso, Vector3(0.028, 0.07, 0.015), Vector3(0.022, -0.045, -0.10), BOW)
	# 黑色小背包：包体（露出长发外）+ 粉色前袋 + 肩带带扣
	var backpack := Node3D.new()
	torso.add_child(backpack)
	_box(backpack, Vector3(0.22, 0.26, 0.12), Vector3(0.0, -0.01, 0.20), PACK)
	_box(backpack, Vector3(0.14, 0.10, 0.02), Vector3(0.0, -0.06, 0.265), HAIR_DARK)
	_box(backpack, Vector3(0.10, 0.03, 0.02), Vector3(0.0, 0.06, 0.265), HAIR_DARK)
	_box(backpack, Vector3(0.045, 0.20, 0.018), Vector3(-0.095, 0.02, -0.098), CLIP)
	_box(backpack, Vector3(0.045, 0.20, 0.018), Vector3(0.095, 0.02, -0.098), CLIP)
	_box(backpack, Vector3(0.05, 0.03, 0.022), Vector3(-0.095, -0.05, -0.10), HAIR_DARK)
	_box(backpack, Vector3(0.05, 0.03, 0.022), Vector3(0.095, -0.05, -0.10), HAIR_DARK)
	rig["torso"] = torso
	rig["backpack"] = backpack


static func _build_arms(root: Node3D, rig: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.19, 0.79, 0.0)
		pivot.rotation.z = -side * 0.10
		root.add_child(pivot)
		# 白夹克袖 + 深色袖口 + 手
		_box(pivot, Vector3(0.09, 0.22, 0.11), Vector3(0.0, -0.12, 0.0), JACKET)
		_box(pivot, Vector3(0.095, 0.03, 0.115), Vector3(0.0, -0.225, 0.0), TRIM)
		_box(pivot, Vector3(0.07, 0.08, 0.08), Vector3(0.0, -0.29, 0.0), SKIN)
		if side < 0.0:
			rig["arm_left"] = pivot
		else:
			rig["arm_right"] = pivot
			var hand := Node3D.new()
			hand.position = Vector3(0.0, -0.31, 0.0)
			pivot.add_child(hand)
			rig["hand_right"] = hand


static func _build_head(root: Node3D, rig: Dictionary) -> void:
	var head := Node3D.new()
	head.position = Vector3(0.0, HEAD_Y, 0.0)
	root.add_child(head)
	# 大头方脸
	_box(head, Vector3(0.30, 0.28, 0.28), Vector3.ZERO, SKIN)
	# 大深紫眼睛 + 白色高光
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.055, 0.085, 0.012), Vector3(side * 0.075, -0.01, -0.143), EYE)
		_box(head, Vector3(0.02, 0.026, 0.014), Vector3(side * 0.062, 0.012, -0.145), WHITE)
		# 脸颊红晕
		_box(head, Vector3(0.045, 0.02, 0.012), Vector3(side * 0.115, -0.06, -0.143), HAIR_DARK)
	# 小嘴微笑
	_box(head, Vector3(0.045, 0.014, 0.012), Vector3(0.0, -0.085, -0.143), MOUTH)
	# 粉色长发：头顶 + 高发际线留大额头 + 两侧垂发
	_box(head, Vector3(0.34, 0.13, 0.33), Vector3(0.0, 0.135, 0.015), HAIR)
	_box(head, Vector3(0.30, 0.045, 0.04), Vector3(0.0, 0.10, -0.15), HAIR)
	_box(head, Vector3(0.35, 0.22, 0.10), Vector3(0.0, 0.0, 0.155), HAIR)
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.07, 0.36, 0.13), Vector3(side * 0.155, -0.09, -0.02), HAIR)
		_box(head, Vector3(0.072, 0.06, 0.13), Vector3(side * 0.155, -0.28, -0.02), HAIR_DARK)
	# 黑猫发夹（角色左侧发际线上）：方头 + 两三角耳 + 粉腮红
	var clip := Node3D.new()
	clip.position = Vector3(-0.115, 0.085, -0.155)
	head.add_child(clip)
	_box(clip, Vector3(0.055, 0.05, 0.03), Vector3.ZERO, CLIP)
	var ear_l := _box(clip, Vector3(0.022, 0.028, 0.02), Vector3(-0.016, 0.034, 0.0), CLIP)
	ear_l.rotation.z = 0.35
	var ear_r := _box(clip, Vector3(0.022, 0.028, 0.02), Vector3(0.016, 0.034, 0.0), CLIP)
	ear_r.rotation.z = -0.35
	_box(clip, Vector3(0.011, 0.008, 0.006), Vector3(-0.014, -0.008, -0.016), HAIR_DARK)
	_box(clip, Vector3(0.011, 0.008, 0.006), Vector3(0.014, -0.008, -0.016), HAIR_DARK)
	# 及腰长发（多片，随移动摆动）：中片 + 两侧片，发尾深色
	for i in 3:
		var pivot := Node3D.new()
		var side_x := (float(i) - 1.0) * 0.115
		pivot.position = Vector3(side_x, 0.03, 0.17)
		head.add_child(pivot)
		var width := 0.20 if i == 1 else 0.09
		var length := 0.56 if i == 1 else 0.48
		_box(pivot, Vector3(width, length, 0.08), Vector3(0.0, -length * 0.5, 0.01), HAIR)
		_box(
			pivot,
			Vector3(width + 0.005, 0.10, 0.085),
			Vector3(0.0, -length + 0.04, 0.01),
			HAIR_DARK
		)
		rig["hair_back"].append(pivot)
	rig["head"] = head


static func update(rig: Dictionary, delta: float, speed: float) -> void:
	var root: Node3D = rig.get("root", null)
	if root == null or not is_instance_valid(root):
		return
	# 死亡：前倾倒地，其余姿态冻结
	if bool(rig.get("dead", false)):
		root.rotation.x = lerpf(root.rotation.x, -PI * 0.46, minf(1.0, delta * 4.0))
		return
	root.rotation.x = lerpf(root.rotation.x, 0.0, minf(1.0, delta * 6.0))
	rig["time"] = float(rig.get("time", 0.0)) + delta
	var t: float = rig["time"]
	var moving := speed > 0.2
	var sprint := speed > 4.5
	if moving:
		rig["phase"] = fmod(float(rig.get("phase", 0.0)) + delta * speed * 2.6, TAU)
	var phase: float = rig["phase"]
	var amp := 0.0
	if moving:
		amp = clampf(speed / 5.0, 0.45, 1.0) * (0.95 if sprint else 0.6)
	var swing := sin(phase) * amp
	# 双腿交替摆动
	var leg_left: Node3D = rig["leg_left"]
	var leg_right: Node3D = rig["leg_right"]
	leg_left.rotation.x = swing
	leg_right.rotation.x = -swing
	# 瞄准：右臂平滑前举持枪，左臂小幅抬起；否则双臂随步伐自然摆动
	var want := 1.0 if bool(rig.get("aiming", false)) else 0.0
	rig["aim_raise"] = move_toward(float(rig.get("aim_raise", 0.0)), want, delta * 6.0)
	var raise: float = rig["aim_raise"]
	var arm_left: Node3D = rig["arm_left"]
	var arm_right: Node3D = rig["arm_right"]
	arm_right.rotation.x = lerpf(-swing * 0.75, ARM_RAISE, raise)
	arm_right.rotation.z = lerpf(-0.10, 0.0, raise)
	arm_left.rotation.x = lerpf(swing * 0.75, 0.4, raise * 0.7)
	arm_left.rotation.z = lerpf(0.10, 0.15, raise)
	# 身体起伏：走路小步弹动 + 待机呼吸
	var bob := absf(cos(phase)) * 0.035 * (1.0 if moving else 0.0)
	root.position.y = bob + sin(t * 1.8) * 0.006
	# 头部微动
	var head: Node3D = rig["head"]
	head.rotation.z = sin(t * 0.9) * 0.025
	head.rotation.x = sin(t * 1.8) * 0.015
	# 长发随移动摆动（逐片相位错开），奔跑时向后扬起
	var speed_k := clampf(speed / 5.0, 0.0, 1.0)
	var hair: Array = rig.get("hair_back", [])
	for i in hair.size():
		var piece: Node3D = hair[i]
		if piece == null or not is_instance_valid(piece):
			continue
		piece.rotation.x = (
			-(0.04 + 0.16 * speed_k)
			+ sin(phase - float(i) * 0.7) * 0.10 * speed_k
			+ sin(t * 1.6 + float(i) * 1.3) * 0.02
		)
		piece.rotation.z = (float(i) - 1.0) * 0.06 + sin(t * 1.2 + float(i)) * 0.015


static func play_death(rig: Dictionary) -> bool:
	if rig.is_empty():
		return false
	rig["dead"] = true
	return true


static func attach_gun(rig: Dictionary, gun: Node3D) -> bool:
	var hand: Node3D = rig.get("hand_right", null)
	if hand == null or not is_instance_valid(hand):
		return false
	hand.add_child(gun)
	# 枪口沿手臂指向：垂手时枪口朝下，右臂前举时枪口朝身体正前方
	gun.position = Vector3(0.0, -0.02, -0.03)
	gun.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	gun.scale = Vector3.ONE * 0.8
	return true
