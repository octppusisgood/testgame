class_name Humanoid
extends RefCounted

const CHAR_DIR := "res://assets/models/characters/"

static var _mesh_cache := {}
static var _mat_cache := {}
static var _emissive_cache := {}
static var _overlay_cache := {}
static var _capsule_cache := {}
static var _sphere_cache := {}
static var _cylinder_cache := {}


static func _get_capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "%.3f_%.3f" % [radius, height]
	if not _capsule_cache.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = maxf(height, radius * 2.0)
		_capsule_cache[key] = mesh
	return _capsule_cache[key]


static func _get_sphere(radius: float) -> SphereMesh:
	var key := "%.3f" % radius
	if not _sphere_cache.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		_sphere_cache[key] = mesh
	return _sphere_cache[key]


static func _get_cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var key := "%.3f_%.3f_%.3f" % [top, bottom, height]
	if not _cylinder_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = bottom
		mesh.height = height
		_cylinder_cache[key] = mesh
	return _cylinder_cache[key]


static func _part_mesh(
	parent: Node3D, mesh: Mesh, pos: Vector3, color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _get_material(color)
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


static func _part_mesh_emissive(
	parent: Node3D, mesh: Mesh, pos: Vector3, color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _get_emissive(color)
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


static func _limb_mesh(
	parent: Node3D, pivot: Vector3, mesh: Mesh, offset: Vector3, color: Color
) -> Node3D:
	var pivot_node := Node3D.new()
	pivot_node.position = pivot
	parent.add_child(pivot_node)
	_part_mesh(pivot_node, mesh, offset, color)
	return pivot_node


static func build(
	body: Node3D,
	torso_mesh: MeshInstance3D,
	shirt: Color,
	pants: Color,
	skin: Color,
	cap_color: Color = Color(0, 0, 0, 0)
) -> Dictionary:
	return build_styled(body, torso_mesh, {
		"shirt": shirt,
		"pants": pants,
		"skin": skin,
		"cap": cap_color,
	})


static func build_styled(
	body: Node3D, torso_mesh: MeshInstance3D, style: Dictionary
) -> Dictionary:
	var model_path: String = style.get("model", "")
	if model_path.is_empty():
		return _build_boxes(body, torso_mesh, style)
	var packed = load(model_path)
	if packed == null:
		return _build_boxes(body, torso_mesh, style)
	var node: Node3D = packed.instantiate()
	body.add_child(node)
	torso_mesh.visible = false
	var aabb := _combined_aabb(node)
	var target_h: float = style.get("height", 1.78)
	if aabb.size.y > 0.01:
		var factor := target_h / aabb.size.y
		node.scale = Vector3.ONE * factor
		node.position = Vector3(0, -aabb.position.y * factor, 0)
	var skeleton: Skeleton3D = null
	for child in node.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
		break
	var meshes: Array = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child)
	var rig := {
		"skeleton": skeleton,
		"root": node,
		"meshes": meshes,
		"bones": {},
		"rest": {},
		"zombie": bool(style.get("zombie", false)),
		"pose": String(style.get("pose", "")),
		"base_overlay": Color(0, 0, 0, 0),
	}
	if bool(style.get("rotten", false)):
		var overlay := Color(0.35, 0.75, 0.3, 0.45)
		rig["base_overlay"] = overlay
		set_overlay(rig, overlay)
	if skeleton != null:
		for bone_name in [
			"UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R",
			"UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R",
			"Chest", "Torso", "Hips", "Head",
		]:
			var idx := skeleton.find_bone(bone_name)
			if idx >= 0:
				rig["bones"][bone_name] = idx
				rig["rest"][bone_name] = skeleton.get_bone_pose_rotation(idx)
	return rig


static func _build_boxes(
	body: Node3D, torso_mesh: MeshInstance3D, style: Dictionary
) -> Dictionary:
	var shirt: Color = style.get("shirt", Color(0.5, 0.5, 0.5))
	var pants: Color = style.get("pants", Color(0.3, 0.3, 0.3))
	var skin: Color = style.get("skin", Color(0.85, 0.7, 0.58))
	var cap: Color = style.get("cap", Color(0, 0, 0, 0))
	var torso_size: Vector3 = style.get("torso", Vector3(0.46, 0.6, 0.26))
	var scale_body: float = style.get("bulk", 1.0)
	torso_mesh.visible = true

	var torso_radius := torso_size.x * 0.36 * scale_body
	var torso_material := StandardMaterial3D.new()
	torso_material.albedo_color = shirt
	torso_mesh.mesh = _get_capsule(torso_radius, torso_size.y * 1.35)
	torso_mesh.position = Vector3(0, 1.14, 0)
	torso_mesh.material_override = torso_material

	_part_mesh(body, _get_sphere(0.135 * scale_body), Vector3(0, 1.57, 0), skin)
	if cap.a > 0.0:
		_part_mesh(body, _get_cylinder(0.15, 0.15, 0.09), Vector3(0, 1.7, 0), cap)

	var limbs := {"arms": [], "legs": []}
	var arm_radius := 0.056 * scale_body
	var right_arm := _limb_mesh(
		body, Vector3(0.26 * scale_body, 1.4, 0), _get_capsule(arm_radius, 0.46),
		Vector3(0, -0.25, 0), shirt
	)
	var left_arm := _limb_mesh(
		body, Vector3(-0.26 * scale_body, 1.4, 0), _get_capsule(arm_radius, 0.46),
		Vector3(0, -0.25, 0), shirt
	)
	_part_mesh(left_arm, _get_sphere(0.07), Vector3(0, -0.5, 0), skin)
	_part_mesh(right_arm, _get_sphere(0.07), Vector3(0, -0.5, 0), skin)
	limbs["arms"].append(left_arm)
	limbs["arms"].append(right_arm)
	for side in [-1.0, 1.0]:
		var leg := _limb_mesh(
			body, Vector3(side * 0.12 * scale_body, 0.6, 0),
			_get_capsule(0.075 * scale_body, 0.6), Vector3(0, -0.3, 0), pants
		)
		_part_mesh(leg, _get_box(Vector3(0.15, 0.08, 0.26)), Vector3(0, -0.6, 0.04), Color(0.15, 0.14, 0.13))
		limbs["legs"].append(leg)

	if style.has("vest"):
		var vest: Color = style["vest"]
		_add_rounded_part(
			body, _get_capsule(torso_radius + 0.03, torso_size.y * 1.2),
			Vector3(0, 1.16, 0), vest
		)
	if style.has("pads"):
		var pads: Color = style["pads"]
		for side in [-1.0, 1.0]:
			_part_mesh(body, _get_sphere(0.09), Vector3(side * 0.28 * scale_body, 1.45, 0), pads)
	if style.has("backpack"):
		var backpack: Color = style["backpack"]
		_part_mesh(body, _get_box(Vector3(0.3, 0.4, 0.18)), Vector3(0, 1.15, 0.22), backpack)
	if style.has("belly"):
		var belly: Color = style["belly"]
		var belly_mesh := _get_sphere(0.24)
		var belly_part := _part_mesh(body, belly_mesh, Vector3(0, 0.94, -0.06), belly)
		belly_part.scale = Vector3(1.15, 0.85, 1.0)
	if style.has("belt"):
		var belt: Color = style["belt"]
		_part_mesh(body, _get_cylinder(torso_radius + 0.04, torso_radius + 0.04, 0.09), Vector3(0, 0.83, 0), belt)
	if style.has("claws"):
		var claws: Color = style["claws"]
		for arm in limbs["arms"]:
			_part_mesh(arm, _get_capsule(0.06, 0.2), Vector3(0, -0.56, -0.02), claws)
	if style.has("spikes"):
		var spikes: Color = style["spikes"]
		for side in [-1.0, 0.0, 1.0]:
			_part_mesh(
				body, _get_cylinder(0.0, 0.05, 0.22),
				Vector3(side * 0.2, 1.68, 0), spikes
			)
	if style.has("crest"):
		var crest: Color = style["crest"]
		_part_mesh(body, _get_cylinder(0.05, 0.19, 0.16), Vector3(0, 1.72, 0), crest)
	if style.has("antenna"):
		var antenna: Color = style["antenna"]
		_part_mesh(body, _get_cylinder(0.015, 0.015, 0.34), Vector3(0.26, 1.68, 0.1), antenna)
	if style.has("cape"):
		var cape: Color = style["cape"]
		_part_mesh(body, _get_box(Vector3(0.46, 0.7, 0.05)), Vector3(0, 1.05, 0.2), cape)
	if style.has("eyes"):
		var eyes: Color = style["eyes"]
		for side in [-1.0, 1.0]:
			_part_mesh_emissive(
				body, _get_sphere(0.035), Vector3(side * 0.06, 1.59, -0.125), eyes
			)
	return limbs


static func _add_rounded_part(
	body: Node3D, mesh: Mesh, pos: Vector3, color: Color
) -> void:
	_part_mesh(body, mesh, pos, color)


static func animate(rig: Dictionary, phase: float, moving: bool) -> void:
	var skeleton: Skeleton3D = rig.get("skeleton", null)
	if skeleton == null or not is_instance_valid(skeleton):
		_animate_pivots(rig, phase, moving)
		return
	var bones: Dictionary = rig.get("bones", {})
	var swing := sin(phase) * 0.55 if moving else 0.0
	var pose := String(rig.get("pose", ""))
	var zombie := bool(rig.get("zombie", false))
	if pose == "gun":
		_pose(rig, skeleton, "UpperArm.L", Vector3(-0.85, 0.15, 0.1))
		_pose(rig, skeleton, "UpperArm.R", Vector3(-0.95, -0.1, -0.1))
		_pose(rig, skeleton, "LowerArm.L", Vector3(-0.5, 0.3, 0.0))
		_pose(rig, skeleton, "LowerArm.R", Vector3(-0.6, -0.2, 0.0))
	elif zombie:
		_pose(rig, skeleton, "Chest", Vector3(0.3, 0, 0))
		_pose(rig, skeleton, "UpperArm.L", Vector3(-1.3 + swing * 0.25, 0.2, 0))
		_pose(rig, skeleton, "UpperArm.R", Vector3(-1.3 - swing * 0.25, -0.2, 0))
		_pose(rig, skeleton, "LowerArm.L", Vector3(0.5, 0, 0))
		_pose(rig, skeleton, "LowerArm.R", Vector3(0.5, 0, 0))
	else:
		_pose(rig, skeleton, "UpperArm.L", Vector3(-swing * 0.8, 0.08, 0))
		_pose(rig, skeleton, "UpperArm.R", Vector3(swing * 0.8, -0.08, 0))
		_pose(rig, skeleton, "LowerArm.L", Vector3(maxf(swing, 0.0) * 0.5, 0, 0))
		_pose(rig, skeleton, "LowerArm.R", Vector3(maxf(-swing, 0.0) * 0.5, 0, 0))
		if not moving:
			_pose(rig, skeleton, "Chest", Vector3(sin(phase * 0.35) * 0.03, 0, 0))
	_pose(rig, skeleton, "UpperLeg.L", Vector3(swing, 0, 0))
	_pose(rig, skeleton, "UpperLeg.R", Vector3(-swing, 0, 0))
	_pose(rig, skeleton, "LowerLeg.L", Vector3(maxf(-swing, 0.0) * 0.8, 0, 0))
	_pose(rig, skeleton, "LowerLeg.R", Vector3(maxf(swing, 0.0) * 0.8, 0, 0))


static func _pose(
	rig: Dictionary, skeleton: Skeleton3D, bone_name: String, euler: Vector3
) -> void:
	var bones: Dictionary = rig.get("bones", {})
	if not bones.has(bone_name):
		return
	var idx := int(bones[bone_name])
	var rest: Quaternion = rig.get("rest", {}).get(bone_name, Quaternion.IDENTITY)
	skeleton.set_bone_pose_rotation(idx, rest * Quaternion.from_euler(euler))


static func _animate_pivots(rig: Dictionary, phase: float, moving: bool) -> void:
	var swing := sin(phase) * 0.55 if moving else 0.0
	var arms: Array = rig.get("arms", [])
	var legs: Array = rig.get("legs", [])
	if arms.size() >= 2:
		arms[0].rotation.x = swing
		arms[1].rotation.x = -swing
	if legs.size() >= 2:
		legs[0].rotation.x = -swing
		legs[1].rotation.x = swing


static func attach_to_hand(rig: Dictionary, node: Node3D) -> bool:
	var skeleton: Skeleton3D = rig.get("skeleton", null)
	if skeleton == null or not is_instance_valid(skeleton):
		return false
	var hand := skeleton.find_bone("Hand.R")
	if hand < 0:
		return false
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Hand.R"
	skeleton.add_child(attach)
	attach.add_child(node)
	node.rotation = Vector3(PI / 2.0, 0, 0)
	return true


static func set_overlay(rig: Dictionary, color: Color) -> void:
	var material := _get_overlay(color)
	for mesh in rig.get("meshes", []):
		if mesh != null and is_instance_valid(mesh):
			mesh.material_overlay = material


static func _get_overlay(color: Color) -> StandardMaterial3D:
	var key := "%.2f_%.2f_%.2f_%.2f" % [color.r, color.g, color.b, color.a]
	if not _overlay_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay_cache[key] = material
	return _overlay_cache[key]


static func _get_box(size: Vector3) -> BoxMesh:
	var key := "%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if not _mesh_cache.has(key):
		var box := BoxMesh.new()
		box.size = size
		_mesh_cache[key] = box
	return _mesh_cache[key]


static func _get_material(color: Color) -> StandardMaterial3D:
	var key := "%.3f_%.3f_%.3f_%.3f" % [color.r, color.g, color.b, color.a]
	if not _mat_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_mat_cache[key] = material
	return _mat_cache[key]


static func _get_emissive(color: Color) -> StandardMaterial3D:
	var key := "%.3f_%.3f_%.3f" % [color.r, color.g, color.b]
	if not _emissive_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_emissive_cache[key] = material
	return _emissive_cache[key]


static func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _get_box(size)
	mesh_instance.material_override = _get_material(color)
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


static func _limb(parent: Node3D, pivot: Vector3, size: Vector3, offset: Vector3, color: Color) -> Node3D:
	var pivot_node := Node3D.new()
	pivot_node.position = pivot
	parent.add_child(pivot_node)
	_part(pivot_node, size, offset, color)
	return pivot_node


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
