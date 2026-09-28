extends CharacterBody3D

const GRAVITY := 18.0
const WALK_SPEED := 3.6
const ARRIVE_DIST := 2.6
const LEAVE_SPEED := 4.2
const LEAVE_TIMEOUT := 60.0

var station = null
var hp := 45
var role := "engineer"
var repairing := false
var repair_progress := 0.0

var _limbs := {}
var _repair_total := 10.0
var _state := "walk"
var _home := Vector3.ZERO
var _leave_timer := 0.0
var _avoid_angle := 0.0
var _avoid_timer := 0.0
var _dying := false


func _ready() -> void:
	add_to_group("npcs")
	hp = GameState.ENGINEER_HP
	_home = global_position
	_repair_total = randf_range(GameState.ENGINEER_REPAIR_MIN, GameState.ENGINEER_REPAIR_MAX)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)
	var torso := MeshInstance3D.new()
	torso.name = "Mesh"
	add_child(torso)
	_limbs = BlockyRig.build(self, torso, {
		"model": "k",
	})


func can_see_node(_target: Node3D) -> bool:
	return false


func show_alert() -> void:
	pass


func witness_crime() -> void:
	pass


func _physics_process(delta: float) -> void:
	if station == null or not is_instance_valid(station):
		queue_free()
		return
	match _state:
		"walk":
			_walk_to(station.global_position, WALK_SPEED, delta)
			if _flat_distance(station.global_position) <= ARRIVE_DIST:
				_state = "repair"
				repairing = true
				repair_progress = 0.0
				BlockyRig.play_once(_limbs, "pick-up")
				GameState.notify("工程师开始维修 %s" % station.data.get("name", "基站"))
		"repair":
			velocity.x = 0.0
			velocity.z = 0.0
			_face(station.global_position)
			if station.destroyed:
				repair_progress = minf(1.0, repair_progress + delta / _repair_total)
				if repair_progress >= 1.0:
					repairing = false
					station.complete_repair()
					_state = "leave"
					GameState.notify("维修完成，工程师撤离现场")
			else:
				repairing = false
				_state = "leave"
		"leave":
			_leave_timer += delta
			_walk_to(_home, LEAVE_SPEED, delta)
			if _flat_distance(_home) <= 3.0 or _leave_timer >= LEAVE_TIMEOUT:
				queue_free()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	BlockyRig.update(_limbs, delta, speed)


func _flat_distance(target: Vector3) -> float:
	var to: Vector3 = target - global_position
	to.y = 0.0
	return to.length()


func _walk_to(target: Vector3, speed: float, delta: float) -> void:
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() < 0.2:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_move_dir(to.normalized(), speed, delta)
	_face(target)


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
		_avoid_angle = _pick_clear_angle(desired.normalized())
	return desired.rotated(Vector3.UP, _avoid_angle)


func _pick_clear_angle(desired: Vector3) -> float:
	var origin := global_position + Vector3(0, 1.0, 0)
	for angle in [0.0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4, 2.1, -2.1]:
		var dir := desired.rotated(Vector3.UP, angle)
		var query := PhysicsRayQueryParameters3D.create(
			origin, origin + dir * 2.0, 1, [get_rid()]
		)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return angle
	return PI


func _face(pos: Vector3) -> void:
	var flat := Vector3(pos.x, global_position.y, pos.z)
	if flat.distance_to(global_position) > 0.15:
		look_at(flat, Vector3.UP)


func take_damage(amount: int, from: Node3D = null) -> void:
	hp -= amount
	if hp <= 0:
		_die(from)


func _die(from: Node3D) -> void:
	if _dying:
		return
	_dying = true
	if station != null and is_instance_valid(station):
		station.engineer_died()
	if from != null and from.is_in_group("player"):
		GameState.report_kill(global_position, _witnessed_by_other(), 2)
	if not BlockyRig.play_death(_limbs):
		queue_free()
		return
	set_physics_process(false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	var tween := get_tree().create_tween()
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
