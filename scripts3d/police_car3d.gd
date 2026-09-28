extends CharacterBody3D

const NPC_SCENE := preload("res://scenes3d/npc3d.tscn")
const CAR_MODEL := "res://assets/Synty/PolygonCity/Prefabs/Vehicles/SM_Veh_Car_Police_01.tscn"
const CAR_WIDTH := 2.0

const SPEED := 17.0
const DEPLOY_DIST := 7.0
const STUCK_DEPLOY_SEC := 14.0

var target_pos := Vector3.ZERO
var deployed := false
var net_id := 0
var net_puppet := false

var _speed := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _flash_timer := 0.0
var _avoid_timer := 0.0
var _avoid_angle := 0.0
var _red: MeshInstance3D
var _blue: MeshInstance3D
var _light_state := false
var _age := 0.0


func setup(pos: Vector3) -> void:
	target_pos = pos
	target_pos.y = 0.0


func _ready() -> void:
	add_to_group("police_cars")
	add_to_group("vehicles")
	_build_visual()
	_net_pos = global_position
	_net_yaw = rotation.y
	if (
		not net_puppet
		and not GameState.test_mode
		and Network.is_multiplayer()
		and Network.is_server()
	):
		Network.register_entity(self, "police_car", {})


func setup_puppet(_params: Dictionary) -> void:
	pass


func net_state() -> Array:
	return [
		global_position.x,
		global_position.y,
		global_position.z,
		rotation.y,
		0.0,
	]


func apply_net_state(data: PackedFloat32Array, base: int) -> void:
	_net_pos = Vector3(data[base], data[base + 1], data[base + 2])
	_net_yaw = data[base + 3]


func _build_visual() -> void:
	var packed: PackedScene = load(CAR_MODEL)
	if packed != null:
		var model: Node3D = packed.instantiate()
		add_child(model)
		var aabb := _combined_aabb(model)
		if aabb.size.x > 0.01:
			var factor := CAR_WIDTH / aabb.size.x
			model.scale = Vector3.ONE * factor
			# GLB 车头朝 +Z，警车移动时 -Z 朝前，需旋转 180°
			model.rotation.y = PI
			model.position = Vector3(0.0, -aabb.position.y * factor, 0.0)
			var top := aabb.end.y * factor
			var bar := MeshInstance3D.new()
			var bar_box := BoxMesh.new()
			bar_box.size = Vector3(1.1, 0.12, 0.3)
			bar.mesh = bar_box
			bar.position = Vector3(0, top + 0.03, 0.1)
			var bar_mat := StandardMaterial3D.new()
			bar_mat.albedo_color = Color(0.15, 0.15, 0.18)
			bar.material_override = bar_mat
			add_child(bar)
			_red = _lamp(Vector3(-0.28, top + 0.13, 0.1), Color(1.0, 0.15, 0.15))
			_blue = _lamp(Vector3(0.28, top + 0.13, 0.1), Color(0.25, 0.45, 1.0))
			return
		model.queue_free()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.9, 4.4)
	body.mesh = box
	body.position = Vector3(0, 0.55, 0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.08, 0.1, 0.16)
	body.material_override = body_mat
	add_child(body)
	var stripe := MeshInstance3D.new()
	var stripe_box := BoxMesh.new()
	stripe_box.size = Vector3(2.02, 0.22, 4.42)
	stripe.mesh = stripe_box
	stripe.position = Vector3(0, 0.66, 0)
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.9, 0.92, 0.95)
	stripe.material_override = stripe_mat
	add_child(stripe)
	var bar := MeshInstance3D.new()
	var bar_box := BoxMesh.new()
	bar_box.size = Vector3(1.1, 0.14, 0.3)
	bar.mesh = bar_box
	bar.position = Vector3(0, 1.08, -0.2)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.15, 0.15, 0.18)
	bar.material_override = bar_mat
	add_child(bar)
	_red = _lamp(Vector3(-0.28, 1.18, -0.2), Color(1.0, 0.15, 0.15))
	_blue = _lamp(Vector3(0.28, 1.18, -0.2), Color(0.25, 0.45, 1.0))


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


func _lamp(pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.16, 0.26)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	return mesh


func _physics_process(delta: float) -> void:
	_age += delta
	if net_puppet:
		global_position = global_position.lerp(_net_pos, minf(1.0, delta * 9.0))
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 9.0))
		_flash(delta)
		return
	if deployed:
		_speed = move_toward(_speed, 0.0, 14.0 * delta)
		velocity.x = 0.0
		velocity.z = 0.0
		_flash(delta)
		if _age > 20.0 and not Network.is_multiplayer():
			pass
		return
	var to := target_pos - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= DEPLOY_DIST or _age > STUCK_DEPLOY_SEC:
		deployed = true
		_deploy()
		return
	_avoid_timer -= delta
	if _avoid_timer <= 0.0:
		_avoid_timer = 0.15
		_avoid_angle = _pick_clear_angle(to.normalized())
	var dir := to.normalized().rotated(Vector3.UP, _avoid_angle)
	_speed = move_toward(_speed, SPEED, 20.0 * delta)
	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed
	look_at(global_position + dir, Vector3.UP)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_flash(delta)


func _pick_clear_angle(desired: Vector3) -> float:
	var origin := global_position + Vector3(0, 1.0, 0)
	for angle in [0.0, 0.35, -0.35, 0.7, -0.7, 1.1, -1.1, 1.6, -1.6]:
		var dir := desired.rotated(Vector3.UP, angle)
		var query := PhysicsRayQueryParameters3D.create(
			origin, origin + dir * 5.0, 1, [get_rid()]
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit["collider"] is Node3D and hit["collider"].is_in_group("police_cars")):
			return angle
	return PI


func _flash(delta: float) -> void:
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_timer = 0.22
		_light_state = not _light_state
		_red.visible = _light_state
		_blue.visible = not _light_state


func _deploy() -> void:
	for i in 4:
		var cop = NPC_SCENE.instantiate()
		cop.role = "cop"
		get_parent().add_child(cop)
		var angle := TAU * float(i) / 4.0
		cop.global_position = global_position + Vector3(cos(angle) * 2.4, 0.05, sin(angle) * 2.4)
		cop._investigate_pos = target_pos
		cop._investigate_timer = 14.0
	GameState.notify("警车抵达现场，4 名警察下车搜查")
