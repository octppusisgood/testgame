extends Node3D

const CAR_SCENE := preload("res://scenes3d/police_car3d.tscn")

const COOLDOWN_MSEC := 18000
const MAX_ACTIVE_CARS := 3
const SPAWN_DIST_M := 55.0
const SCALE := 0.05

var _last_dispatch := -COOLDOWN_MSEC


func _ready() -> void:
	if Network.is_multiplayer() and not Network.is_server():
		return
	GameState.police_alerted.connect(_on_alert)


func _on_alert(pos: Vector3) -> void:
	if GameState.test_mode:
		return
	if Time.get_ticks_msec() - _last_dispatch < COOLDOWN_MSEC:
		return
	var active := 0
	for car in get_tree().get_nodes_in_group("police_cars"):
		if is_instance_valid(car) and not car.deployed:
			active += 1
	if active >= MAX_ACTIVE_CARS:
		return
	_last_dispatch = Time.get_ticks_msec()
	_dispatch(pos)


func _dispatch(pos: Vector3) -> void:
	var car = CAR_SCENE.instantiate()
	add_child(car)
	car.global_position = _pick_spawn(pos)
	car.setup(pos)


func _pick_spawn(target: Vector3) -> Vector3:
	var t2 := Vector2(target.x, target.z) / SCALE
	var best_road: Rect2 = Rect2()
	var best_dist := INF
	for road in GameState.ROADS:
		var center: Vector2 = road.position + road.size / 2.0
		var dist: float = (t2 - center).length()
		if dist < best_dist:
			best_dist = dist
			best_road = road
	if best_road.size == Vector2.ZERO:
		return target + Vector3(SPAWN_DIST_M, 0.2, 0.0)
	var along := Vector2(1, 0)
	var length := best_road.size.x
	if best_road.size.y > best_road.size.x:
		along = Vector2(0, 1)
		length = best_road.size.y
	var center2: Vector2 = best_road.position + best_road.size / 2.0
	var offset := (t2 - center2).dot(along)
	var side := -1.0 if randf() < 0.5 else 1.0
	offset += side * (SPAWN_DIST_M / SCALE)
	offset = clampf(offset, -length * 0.5, length * 0.5)
	var point := center2 + along * offset
	return Vector3(point.x * SCALE, 0.2, point.y * SCALE)
