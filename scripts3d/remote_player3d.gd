extends CharacterBody3D

const LERP_SPEED := 12.0

var peer_id := 0
var alive := true

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _moving := false
var _limbs := {}
var _fallen := false


func _ready() -> void:
	add_to_group("remote_players")
	_limbs = BlockyRig.build(self, $Mesh as MeshInstance3D, {
		"model": BlockyRig.random_civilian(),
	})
	_target_pos = global_position


func set_state(pos: Vector3, yaw: float, moving: bool) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_moving = moving


func take_damage(amount: int, _from = null) -> void:
	if not alive or not Network.is_multiplayer():
		return
	Network.request_damage(peer_id, amount)


func die() -> void:
	if _fallen:
		return
	_fallen = true
	alive = false
	if BlockyRig.play_death(_limbs):
		return
	rotation.z = PI / 2.0
	_target_pos.y = 0.25


func _physics_process(delta: float) -> void:
	if _fallen:
		global_position = global_position.lerp(_target_pos, minf(1.0, delta * LERP_SPEED))
		return
	global_position = global_position.lerp(_target_pos, minf(1.0, delta * LERP_SPEED))
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(1.0, delta * LERP_SPEED))
	BlockyRig.update(_limbs, delta, 3.0 if _moving else 0.0)
