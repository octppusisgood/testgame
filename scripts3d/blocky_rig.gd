class_name BlockyRig
extends RefCounted

const CHAR_DIR := "res://assets/models/characters/"
const RAW_HEIGHT := 2.7

# Synty 角色预制体（全部用末日包：其骨架与官方动画包同名，城市包骨架不同用不了动画）
const APO_CHR := "res://assets/Synty/PolygonApocalypse/Prefabs/Characters/"
const LETTER_MODELS := {
	# 丧尸
	"a": APO_CHR + "SM_Chr_Zombie_Male_01.tscn",
	"l": APO_CHR + "SM_Chr_Zombie_Male_02.tscn",
	"o": APO_CHR + "SM_Chr_Zombie_Female_01.tscn",
	# 平民
	"b": APO_CHR + "SM_Chr_Business_Male_01.tscn",
	"c": APO_CHR + "SM_Chr_Eastern_Female_01.tscn",
	"e": APO_CHR + "SM_Chr_Wanderer_Male_01.tscn",
	"f": APO_CHR + "SM_Chr_Cool_Female_01.tscn",
	"i": APO_CHR + "SM_Chr_Waitress_Female_01.tscn",
	"n": APO_CHR + "SM_Chr_Teen_Male_01.tscn",
	"p": APO_CHR + "SM_Chr_Nerd_Female_01.tscn",
	# 职业/敌人
	"j": APO_CHR + "SM_Chr_RiotCop_Male_01.tscn",
	"q": APO_CHR + "SM_Chr_Sheriff_Male_01.tscn",
	"m": APO_CHR + "SM_Chr_Soldier_Male_01.tscn",
	"r": APO_CHR + "SM_Chr_Criminal_Male_01.tscn",
	"h": APO_CHR + "SM_Chr_Biker_Male_01.tscn",
	"g": APO_CHR + "SM_Chr_Hazmat_Male_01.tscn",
	"k": APO_CHR + "SM_Chr_Mechanic_Female_01.tscn",
}

const CIVILIAN_VARIANTS := ["b", "c", "e", "f", "i", "n", "p"]
const ZOMBIE_VARIANTS := ["l", "o", "a"]

const LOCO_ANIMS := ["idle", "walk", "sprint", "holding-right", "holding-both"]

# Synty 官方动画（基础移动包）：站桩/走/跑，全部角色共用一套骨骼名
const ANIM_SOURCES := {
	"idle": "res://assets/Synty/Animations/A_Idle_Standing_Masc.fbx",
	"walk": "res://assets/Synty/Animations/A_Walk_F_Masc.fbx",
	"sprint": "res://assets/Synty/Animations/A_Run_F_Masc.fbx",
}

static var _scene_cache := {}
static var _anim_library: AnimationLibrary = null
static var _prefab_rest_map := {}   # 骨名 -> {basis, origin, parent, children}（全局静止变换）
static var _prefab_bone_order := []  # 骨名按骨骼索引序（父先子后）


# 预制体骨架的全局静止姿势（取任一末日包角色，同包骨架一致）
static func _prefab_rest() -> Dictionary:
	if not _prefab_rest_map.is_empty():
		return _prefab_rest_map
	var inst: Node = load(APO_CHR + "SM_Chr_Zombie_Male_01.tscn").instantiate()
	var skel: Skeleton3D = null
	for c in inst.find_children("*", "Skeleton3D", true, false):
		skel = c
		break
	_prefab_rest_map = _skeleton_rest_map(skel, _prefab_bone_order)
	inst.free()
	return _prefab_rest_map


# 骨架每根骨的全局静止变换 + 父子关系；order_out 按索引序收集骨名（父先子后）
static func _skeleton_rest_map(skel: Skeleton3D, order_out: Array = []) -> Dictionary:
	var globals := {}
	var names := {}
	var result := {}
	for i in skel.get_bone_count():
		var p := skel.get_bone_parent(i)
		var rest := skel.get_bone_rest(i)
		globals[i] = rest if p < 0 else (globals[p] as Transform3D) * rest
		names[i] = skel.get_bone_name(i)
		order_out.append(names[i])
	for i in skel.get_bone_count():
		var p: int = skel.get_bone_parent(i)
		var pname := String(names.get(p, ""))
		result[names[i]] = {
			"basis": (globals[i] as Transform3D).basis,
			"origin": (globals[i] as Transform3D).origin,
			"parent": pname,
			"children": [],
		}
	for i in skel.get_bone_count():
		var pname := String(result[names[i]]["parent"])
		if not pname.is_empty() and result.has(pname):
			(result[pname]["children"] as Array).append(names[i])
	return result


# 动画骨架与预制体骨架 bone 轴向不同，且动画 FBX 无蒙皮——导入器把 rest 记成了动画首帧。
# 标定：把预制体 T-pose 逐骨骼短弧旋转子树，让每根骨的主方向子骨与动画骨架 rest 的全局方向一致，
# 得到与动画 rest 同一物理姿势的预制体姿势 Rc；重定向常量 D(b) = inv(Rf(b))·Rc(b)，L' = inv(D(p))·q·D(b)
static func _build_retarget_deltas(fbx_skel: Skeleton3D) -> Dictionary:
	var prefab := _prefab_rest()
	var fbx := _skeleton_rest_map(fbx_skel)
	var cal := {}
	for n in prefab:
		cal[n] = {"basis": prefab[n]["basis"], "origin": prefab[n]["origin"]}
	for n in _prefab_bone_order:
		if not fbx.has(n):
			continue
		# 主方向子骨：偏移最大且 >6cm 的子骨（手指等细枝不标定，沿用父级修正）
		var child := ""
		var best := 0.06
		for c in prefab[n]["children"]:
			if not fbx.has(c):
				continue
			var off: Vector3 = (prefab[c]["origin"] as Vector3) - (prefab[n]["origin"] as Vector3)
			if off.length() > best:
				best = off.length()
				child = c
		if child.is_empty():
			continue
		var pivot: Vector3 = cal[n]["origin"]
		var v1: Vector3 = (cal[child]["origin"] as Vector3) - pivot
		var v2: Vector3 = (fbx[child]["origin"] as Vector3) - (fbx[n]["origin"] as Vector3)
		if v1.length() < 0.01 or v2.length() < 0.01:
			continue
		_subtree_rotate(cal, prefab, n, pivot, Basis(Quaternion(v1.normalized(), v2.normalized())))
	var deltas := {}
	for n in prefab:
		if fbx.has(n):
			deltas[n] = (fbx[n]["basis"] as Basis).inverse() * (cal[n]["basis"] as Basis)
	return deltas


static func _subtree_rotate(cal: Dictionary, prefab: Dictionary, bone: String, pivot: Vector3, rot: Basis) -> void:
	var stack := [bone]
	while not stack.is_empty():
		var n: String = stack.pop_back()
		var e: Dictionary = cal[n]
		e["origin"] = pivot + rot * ((e["origin"] as Vector3) - pivot)
		e["basis"] = rot * (e["basis"] as Basis)
		for c in prefab[n]["children"]:
			stack.append(c)


# 重定向动画轨道到预制体骨架：旋转轨道按 L' = inv(D(p))·q·D(b) 逐关键帧换算，
# 位置轨道（仅 Hips，父骨 Root 近似不动）直接沿用；预制体没有的骨骼轨道整条删除
static func _retarget_animation(anim: Animation, deltas: Dictionary) -> void:
	var prefab := _prefab_rest()
	var drop: Array = []
	for i in anim.get_track_count():
		var path := String(anim.track_get_path(i))
		var colon := path.find(":")
		if colon < 0:
			continue
		var bone := path.substr(colon + 1)
		if not prefab.has(bone) or not deltas.has(bone):
			drop.append(i)
			continue
		anim.track_set_path(i, NodePath("Skeleton3D:" + bone))
		if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var pname := String(prefab[bone]["parent"])
		var a_basis := Basis()
		if not pname.is_empty() and deltas.has(pname):
			a_basis = (deltas[pname] as Basis).inverse()
		var b_basis: Basis = deltas[bone]
		for k in anim.track_get_key_count(i):
			var q: Quaternion = anim.track_get_key_value(i, k)
			anim.track_set_key_value(
				i, k, (a_basis * Basis(q) * b_basis).get_rotation_quaternion()
			)
	for i in range(drop.size() - 1, -1, -1):
		anim.remove_track(drop[i])


# 从动画 FBX 提取 Animation 资源，重定向后统一改挂到 "Skeleton3D" 节点路径下
static func _get_anim_library() -> AnimationLibrary:
	if _anim_library != null:
		return _anim_library
	var lib := AnimationLibrary.new()
	for anim_name in ANIM_SOURCES:
		var packed = load(String(ANIM_SOURCES[anim_name]))
		if packed == null:
			continue
		var inst: Node = packed.instantiate()
		var player: AnimationPlayer = null
		for child in inst.find_children("*", "AnimationPlayer", true, false):
			player = child as AnimationPlayer
			break
		var fbx_skel: Skeleton3D = null
		for child in inst.find_children("*", "Skeleton3D", true, false):
			fbx_skel = child as Skeleton3D
			break
		if player != null and not player.get_animation_list().is_empty() and fbx_skel != null:
			var anim: Animation = player.get_animation(player.get_animation_list()[0]).duplicate()
			_retarget_animation(anim, _build_retarget_deltas(fbx_skel))
			lib.add_animation(anim_name, anim)
		inst.free()
	_anim_library = lib
	return lib


# 预热全部角色变体进缓存：避免战斗中某变体首次刷出时同步加载 65 个资源顿卡
static func prewarm() -> void:
	for path in LETTER_MODELS.values():
		if not _scene_cache.has(path):
			var packed = load(path)
			if packed != null:
				_scene_cache[path] = packed


static func variant_path(letter: String) -> String:
	if LETTER_MODELS.has(letter):
		return String(LETTER_MODELS[letter])
	return String(LETTER_MODELS[CIVILIAN_VARIANTS[randi() % CIVILIAN_VARIANTS.size()]])


static func random_civilian() -> String:
	return CIVILIAN_VARIANTS[randi() % CIVILIAN_VARIANTS.size()]


static func random_zombie() -> String:
	return ZOMBIE_VARIANTS[randi() % ZOMBIE_VARIANTS.size()]


static func build(body: Node3D, torso_mesh: MeshInstance3D, style: Dictionary) -> Dictionary:
	var model := String(style.get("model", ""))
	if model.is_empty():
		model = random_civilian()
	if not model.ends_with(".glb") and not model.ends_with(".tscn"):
		model = variant_path(model)
	var synty := model.ends_with(".tscn")
	var rig := {
		"blocky": true,
		"root": null,
		"player": null,
		"meshes": [],
		"hand": null,
		"skeleton": null,
		"current": "",
		"oneshot_until": 0,
		"aiming": false,
		"base_overlay": Color(0, 0, 0, 0),
	}
	if not _scene_cache.has(model):
		var packed = load(model)
		if packed == null:
			return rig
		_scene_cache[model] = packed
	var node: Node3D = _scene_cache[model].instantiate()
	if synty:
		# Synty 预制体：剥掉自带碰撞体与隐藏的角色变体网格（一个预制体含全部角色，只显示一个）
		for collider in node.find_children("*", "CollisionShape3D", true, false):
			collider.free()
		for mesh_child in node.find_children("*", "MeshInstance3D", true, false):
			if not (mesh_child as MeshInstance3D).visible:
				mesh_child.free()
	body.add_child(node)
	if torso_mesh != null:
		torso_mesh.visible = false
	rig["root"] = node
	for child in node.find_children("*", "MeshInstance3D", true, false):
		# 角色/怪物数量多且动态蒙皮：不投射阴影，兼容渲染器下省一半 GPU 蒙皮与阴影 pass
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig["meshes"].append(child)
	var player: AnimationPlayer = null
	for child in node.find_children("*", "AnimationPlayer", true, false):
		player = child as AnimationPlayer
		break
	if synty and player != null:
		player.add_animation_library("", _get_anim_library())
		for bone_child in node.find_children("*", "Skeleton3D", true, false):
			rig["skeleton"] = bone_child
			break
		# Synty 预制体的蒙皮网格 skeleton 路径未序列化（Godot 4.7 默认为空），
		# 不指到 Skeleton3D 的话网格与骨架脱绑，永远渲染绑定姿势（T-Pose）
		var skel: Skeleton3D = rig["skeleton"]
		if skel != null:
			for mesh_child in rig["meshes"]:
				var mi := mesh_child as MeshInstance3D
				if mi != null and mi.skin != null:
					mi.skeleton = mi.get_path_to(skel)
	rig["player"] = player
	if player != null:
		for anim_name in LOCO_ANIMS:
			if player.has_animation(anim_name):
				player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	var aabb := _combined_aabb(node)
	var target_h: float = float(style.get("height", 1.78)) * float(style.get("bulk", 1.0))
	if aabb.size.y > 0.01:
		var factor := target_h / aabb.size.y
		node.scale = Vector3.ONE * factor
		node.position = Vector3(0, -aabb.position.y * factor, 0)
	# 模型正面朝 +Z，而 look_at 以 -Z 为前，转 180 度对齐（GLB 与 Synty 预制体一致）
	node.rotation.y = PI
	var tint: Color = style.get("tint", Color(0, 0, 0, 0))
	if tint.a > 0.0:
		_apply_tint(rig, Color(tint.r, tint.g, tint.b))
	var arm := node.find_child("arm-right", true, false)
	if arm != null:
		rig["hand"] = arm
	if player != null and player.has_animation("idle"):
		player.play("idle")
		rig["current"] = "idle"
	return rig



static func update(rig: Dictionary, _delta: float, speed: float) -> void:
	var player: AnimationPlayer = rig.get("player", null)
	if player == null or not is_instance_valid(player):
		return
	if Time.get_ticks_msec() < int(rig.get("oneshot_until", 0)):
		return
	var anim := "idle"
	var rate := 1.0
	if speed > 4.0:
		anim = "sprint"
		rate = clampf(speed / 6.0, 0.7, 1.6)
	elif speed > 0.2:
		anim = "walk"
		rate = clampf(speed / 2.2, 0.6, 1.8)
	elif bool(rig.get("aiming", false)):
		anim = "holding-right"
	_play(rig, anim)
	player.speed_scale = rate


# LOD2（远距）动画降载：冻结 AnimationPlayer 求值，停在自然姿势帧（骨骼求值趋零）；
# 解冻后 active 恢复，播放状态原样继续。冻结只停求值，不清已写入的骨骼姿势
static func set_lod_frozen(rig: Dictionary, frozen: bool) -> void:
	var player: AnimationPlayer = rig.get("player", null)
	if player == null or not is_instance_valid(player):
		return
	if frozen == bool(rig.get("lod_frozen", false)):
		return
	rig["lod_frozen"] = frozen
	if frozen:
		# 先推进到自然帧再冻结，避免停在动画第 0 帧
		if not player.is_playing() and player.has_animation("idle"):
			player.play("idle")
		player.advance(0.3)
		player.active = false
	else:
		player.active = true


static func play_once(rig: Dictionary, anim: String) -> bool:
	var player: AnimationPlayer = rig.get("player", null)
	if player == null or not is_instance_valid(player):
		return false
	if not player.has_animation(anim):
		return false
	player.speed_scale = 1.0
	player.play(anim)
	rig["current"] = anim
	var length := player.get_animation(anim).length
	rig["oneshot_until"] = Time.get_ticks_msec() + int(length * 1000.0)
	return true


static func play_death(rig: Dictionary) -> bool:
	var player: AnimationPlayer = rig.get("player", null)
	if player != null and is_instance_valid(player) and player.has_animation("die"):
		player.speed_scale = 1.0
		player.play("die")
		rig["current"] = "die"
		rig["oneshot_until"] = Time.get_ticks_msec() + 60000
		return true
	# Synty 角色没有死亡动画：停掉动画并程序化侧倒，尸体保留一小段由调用方定时释放
	var root: Node3D = rig.get("root", null)
	if root == null or not is_instance_valid(root):
		return false
	if player != null and is_instance_valid(player):
		player.stop()
	rig["current"] = "die"
	rig["oneshot_until"] = Time.get_ticks_msec() + 60000
	var tween := root.create_tween()
	tween.tween_property(root, "rotation:z", PI / 2.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return true


static func attach_gun(rig: Dictionary, gun: Node3D, is_rifle: bool) -> bool:
	var hand: Node3D = rig.get("hand", null)
	if hand == null or not is_instance_valid(hand):
		# Synty 骨骼：挂到右手骨（Hand_R）上
		var skeleton: Skeleton3D = rig.get("skeleton", null)
		if skeleton == null or not is_instance_valid(skeleton):
			return false
		if skeleton.find_bone("Hand_R") < 0:
			return false
		var attach := BoneAttachment3D.new()
		attach.bone_name = "Hand_R"
		skeleton.add_child(attach)
		attach.add_child(gun)
		gun.rotation = Vector3(PI / 2.0, 0, 0)
		var root_scale: float = (rig["root"] as Node3D).scale.y if rig.get("root") != null else 1.0
		if root_scale > 0.01:
			gun.scale = Vector3.ONE / root_scale
		return true
	hand.add_child(gun)
	var offset := Vector3(0.0, -0.95, -0.15)
	if hand is MeshInstance3D:
		var box: AABB = (hand as MeshInstance3D).get_aabb()
		offset = Vector3(box.get_center().x, box.position.y + 0.05, box.get_center().z)
	gun.position = offset
	gun.rotation = Vector3(PI / 2.0, 0, 0)
	var factor: float = (rig["root"] as Node3D).scale.y if rig.get("root") != null else 1.0
	if factor > 0.01:
		gun.scale = Vector3.ONE / factor
	if is_rifle:
		gun.position += Vector3(0, 0, -0.35 / maxf(factor, 0.01))
	return true


static func _play(rig: Dictionary, anim: String) -> void:
	var player: AnimationPlayer = rig["player"]
	if String(rig.get("current", "")) == anim:
		return
	if not player.has_animation(anim):
		anim = "idle"
		if String(rig.get("current", "")) == anim or not player.has_animation(anim):
			return
	player.play(anim)
	rig["current"] = anim


static func _apply_tint(rig: Dictionary, tint: Color) -> void:
	var seen := {}
	for mesh in rig.get("meshes", []):
		if mesh == null or not is_instance_valid(mesh):
			continue
		var surfaces: int = mesh.mesh.get_surface_count() if mesh.mesh != null else 0
		for i in surfaces:
			var material: Material = mesh.get_active_material(i)
			if material == null:
				continue
			var key: int = material.get_instance_id()
			if not seen.has(key):
				var dup: Material = material.duplicate()
				if dup is BaseMaterial3D:
					dup.albedo_color = tint
				seen[key] = dup
			mesh.set_surface_override_material(i, seen[key])


static func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var started := false
	var _aabb_meshes: Array = []
	if root is MeshInstance3D:
		_aabb_meshes.append(root)
	_aabb_meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for child in _aabb_meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var box: AABB = mesh_instance.get_aabb()
		for i in 8:
			var point: Vector3 = mesh_instance.global_transform * box.get_endpoint(i)
			if not started:
				result = AABB(point, Vector3.ZERO)
				started = true
			else:
				result = result.expand(point)
	return result
