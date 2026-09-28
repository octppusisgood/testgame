extends Node

const DEFAULT_PORT := 27015
const MAX_PLAYERS := 8
const WANTED_DURATION_MSEC := 20000
const SNAPSHOT_INTERVAL := 0.1
const STATE_FLOATS := 5
const CLOCK_INTERVAL := 1.0
const MENU_SCENE := "res://scenes3d/menu3d.tscn"

var mode := "single"
var wanted_peers := {}
var map_seed := 0
var target_scene := "res://scenes3d/proto3d.tscn"

var _next_entity_id := 1
var _entities := {}
var _entity_meta := {}
var _snapshot_timer := 0.0
var _clock_timer := 0.0
var _vehicle_owners := {}

signal player_state(peer_id: int, pos: Vector3, yaw: float, moving: bool)
signal player_died(peer_id: int)
signal player_hit(peer_id: int, damage: int)
signal report_feedback(text: String)
signal spawn_remote(peer_id: int)
signal map_ready(seed_value: int)
signal entity_spawned(id: int, kind: String, params: Dictionary)
signal entity_removed(id: int)
signal entity_state(ids: PackedInt32Array, data: PackedFloat32Array)
signal vehicle_owner_changed(id: int, peer: int)
signal vehicle_state(id: int, pos: Vector3, yaw: float)
signal vehicle_claim_denied(id: int)


func is_multiplayer() -> bool:
	return mode != "single"


func is_server() -> bool:
	if mode == "single":
		return true
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return multiplayer.is_server()


func my_id() -> int:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return 1
	return multiplayer.get_unique_id()


func is_connected_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func host_game(port := DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	return OK


func join_game(ip: String, port := DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = "single"
	wanted_peers.clear()


func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(id: int) -> void:
	if not is_server():
		return
	# 只发种子：实体/时钟重放等客户端场景就绪后主动 net_request_world 再发
	net_hello.rpc_id(id, map_seed, target_scene)


func _on_peer_disconnected(id: int) -> void:
	wanted_peers.erase(id)
	for entity_id in _vehicle_owners.keys():
		if int(_vehicle_owners[entity_id]) == id:
			set_vehicle_owner(int(entity_id), 0)


# 客户端进城（傀儡管理器就绪）后调用：向主机请求全量世界状态
func request_world() -> void:
	if not is_multiplayer() or not is_connected_peer() or is_server():
		return
	net_request_world.rpc_id(1)


# 主机端：把现存实体与当前时钟重发给指定客户端
func _replay_world_to(peer_id: int) -> void:
	for entity_id in _entities.keys():
		var node = _entities[entity_id]
		if not is_instance_valid(node):
			continue
		var meta: Dictionary = _entity_meta.get(entity_id, {})
		if meta.is_empty():
			continue
		net_entity_spawn.rpc_id(
			peer_id, int(entity_id), String(meta["kind"]), meta["params"]
		)
	net_clock.rpc_id(peer_id, GameState.clock_payload())


func register_entity(node: Node3D, kind: String, params: Dictionary = {}) -> int:
	if not is_multiplayer() or not is_server() or node == null:
		return 0
	var id := _next_entity_id
	_next_entity_id += 1
	var data := params.duplicate()
	data["pos"] = [node.global_position.x, node.global_position.y, node.global_position.z]
	data["yaw"] = node.rotation.y
	node.net_id = id
	_entities[id] = node
	_entity_meta[id] = {"kind": kind, "params": data}
	net_entity_spawn.rpc(id, kind, data)
	return id


func unregister_entity(node: Node3D) -> void:
	if not is_multiplayer() or not is_server() or node == null:
		return
	var id: int = node.net_id
	if id == 0 or not _entities.has(id):
		return
	_entities.erase(id)
	_entity_meta.erase(id)
	net_entity_remove.rpc(id)


func request_entity_damage(id: int, amount: int) -> void:
	if id == 0 or not is_multiplayer():
		return
	if is_server():
		_apply_entity_damage(id, amount, my_id())
	else:
		net_entity_damage.rpc_id(1, id, amount)


func request_entity_remove(id: int) -> void:
	if id == 0 or not is_multiplayer():
		return
	if is_server():
		_remove_entity_by_id(id)
	else:
		net_entity_remove_request.rpc_id(1, id)


func _remove_entity_by_id(id: int) -> void:
	if not _entities.has(id):
		return
	var node = _entities[id]
	_entities.erase(id)
	_entity_meta.erase(id)
	net_entity_remove.rpc(id)
	if is_instance_valid(node):
		node.queue_free()


func _apply_entity_damage(id: int, amount: int, from_peer: int) -> void:
	var node = _entities.get(id, null)
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("take_damage_authoritative"):
		node.take_damage_authoritative(amount, from_peer)


func claim_vehicle(id: int, peer: int) -> void:
	if id == 0:
		return
	if is_multiplayer() and is_connected_peer():
		net_vehicle_claim.rpc(id, peer)
	else:
		set_vehicle_owner(id, peer)


func set_vehicle_owner(id: int, peer: int) -> void:
	if peer == 0:
		_vehicle_owners.erase(id)
	else:
		_vehicle_owners[id] = peer
	vehicle_owner_changed.emit(id, peer)


func vehicle_owner(id: int) -> int:
	return int(_vehicle_owners.get(id, 0))


func broadcast_vehicle_state(id: int, pos: Vector3, yaw: float) -> void:
	if not is_multiplayer() or not is_connected_peer():
		return
	net_vehicle_state.rpc(id, pos, yaw)


func send_entity_state(id: int, floats: Array) -> void:
	if not is_multiplayer() or not is_connected_peer() or floats.is_empty():
		return
	var ids := PackedInt32Array([id])
	var data := PackedFloat32Array()
	for value in floats:
		data.append(float(value))
	net_entity_snapshot.rpc(ids, data)


func _on_server_disconnected() -> void:
	if mode == "client":
		GameState.notify("与主机断开连接，已返回主菜单")
		leave()
		# 客户端带不回定格傀儡的世界：直接回主菜单，可重新加入
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path != MENU_SCENE:
			get_tree().change_scene_to_file(MENU_SCENE)


func mark_wanted(peer_id: int) -> void:
	wanted_peers[peer_id] = Time.get_ticks_msec() + WANTED_DURATION_MSEC


func sync_wanted(ids: Array) -> void:
	for id in ids:
		wanted_peers[int(id)] = Time.get_ticks_msec() + WANTED_DURATION_MSEC


func is_wanted(peer_id: int) -> bool:
	var until: int = int(wanted_peers.get(peer_id, 0))
	return until > Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not is_multiplayer():
		return
	var now := Time.get_ticks_msec()
	for peer_id in wanted_peers.keys():
		if int(wanted_peers[peer_id]) <= now:
			wanted_peers.erase(peer_id)
	if not is_server():
		return
	# 世界时钟广播：阶段/倒计时/日钟/天气/电网，客户端套用而不是本地推进
	_clock_timer -= _delta
	if _clock_timer <= 0.0:
		_clock_timer = CLOCK_INTERVAL
		net_clock.rpc(GameState.clock_payload())
	_snapshot_timer -= _delta
	if _snapshot_timer > 0.0 or _entities.is_empty():
		return
	_snapshot_timer = SNAPSHOT_INTERVAL
	var ids := PackedInt32Array()
	var data := PackedFloat32Array()
	for id in _entities.keys():
		var node = _entities[id]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_entities.erase(id)
			_entity_meta.erase(id)
			net_entity_remove.rpc(int(id))
			continue
		if not node.has_method("net_state"):
			continue
		var owner := vehicle_owner(int(id))
		if owner != 0:
			continue
		var state: Array = node.net_state()
		if state.is_empty():
			continue
		ids.append(int(id))
		for value in state:
			data.append(float(value))
	if not ids.is_empty():
		net_entity_snapshot.rpc(ids, data)


func broadcast_state(pos: Vector3, yaw: float, moving: bool) -> void:
	if not is_multiplayer() or not is_connected_peer():
		return
	net_state.rpc(pos, yaw, moving)


func broadcast_died() -> void:
	if not is_multiplayer() or not is_connected_peer():
		return
	net_died.rpc(my_id())


func report_player(target_peer: int) -> void:
	if not is_multiplayer():
		GameState.notify("单人模式没有可举报的对象")
		return
	if not is_connected_peer():
		GameState.notify("还没连上主机")
		return
	if multiplayer.is_server():
		mark_wanted(target_peer)
		net_sync_wanted.rpc(wanted_peers.keys())
		net_report_announce.rpc()
	else:
		net_report.rpc_id(1, target_peer)
	GameState.notify("已提交匿名举报，警察会去调查")


func request_damage(peer_id: int, damage: int) -> void:
	if not is_multiplayer() or not is_connected_peer():
		return
	net_damage.rpc_id(peer_id, damage)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_state(pos: Vector3, yaw: float, moving: bool) -> void:
	player_state.emit(multiplayer.get_remote_sender_id(), pos, yaw, moving)


@rpc("any_peer", "call_remote", "reliable")
func net_died(peer_id: int) -> void:
	player_died.emit(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func net_damage(damage: int) -> void:
	player_hit.emit(multiplayer.get_remote_sender_id(), damage)


@rpc("any_peer", "call_remote", "reliable")
func net_report(target_peer: int) -> void:
	if not multiplayer.is_server():
		return
	if not multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
		return
	mark_wanted(target_peer)
	net_sync_wanted.rpc(wanted_peers.keys())
	net_report_announce.rpc()


@rpc("authority", "call_remote", "reliable")
func net_sync_wanted(ids: Array) -> void:
	sync_wanted(ids)


@rpc("any_peer", "call_remote", "reliable")
func net_request_peers() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	for id in multiplayer.get_peers():
		if id != sender:
			net_spawn_peer.rpc_id(sender, int(id))
	net_sync_wanted.rpc_id(sender, wanted_peers.keys())


@rpc("authority", "call_remote", "reliable")
func net_spawn_peer(id: int) -> void:
	spawn_remote.emit(id)


@rpc("authority", "call_remote", "reliable")
func net_report_announce() -> void:
	GameState.post_message(
		"匿名举报：有市民形迹可疑，警方已出动", Vector2.ZERO, "crime", true
	)
	report_feedback.emit("警方接到匿名举报，正在追查")


@rpc("any_peer", "call_remote", "reliable")
func net_request_wanted() -> void:
	if not multiplayer.is_server():
		return
	mark_wanted(multiplayer.get_remote_sender_id())
	net_sync_wanted.rpc(wanted_peers.keys())


@rpc("authority", "call_remote", "reliable")
func net_hello(seed_value: int, scene_path := "res://scenes3d/proto3d.tscn") -> void:
	map_seed = seed_value
	target_scene = scene_path
	map_ready.emit(seed_value)


@rpc("authority", "call_remote", "reliable")
func net_entity_spawn(id: int, kind: String, params: Dictionary) -> void:
	entity_spawned.emit(id, kind, params)


@rpc("authority", "call_remote", "reliable")
func net_entity_remove(id: int) -> void:
	entity_removed.emit(id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_entity_snapshot(ids: PackedInt32Array, data: PackedFloat32Array) -> void:
	entity_state.emit(ids, data)


@rpc("any_peer", "call_remote", "reliable")
func net_entity_damage(id: int, amount: int) -> void:
	if multiplayer.is_server():
		_apply_entity_damage(id, amount, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func net_entity_remove_request(id: int) -> void:
	if multiplayer.is_server():
		_remove_entity_by_id(id)


@rpc("any_peer", "call_remote", "reliable")
func net_vehicle_claim(id: int, peer: int) -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		if peer != 0 and peer != sender:
			return
		# 占用仲裁：车已有主且不是认领者本人时拒绝并回执
		var current := vehicle_owner(id)
		if peer != 0 and current != 0 and current != peer:
			net_vehicle_claim_denied.rpc_id(sender, id)
			return
	set_vehicle_owner(id, peer)
	if multiplayer.is_server():
		net_vehicle_claim.rpc(id, peer)


@rpc("authority", "call_remote", "reliable")
func net_vehicle_claim_denied(id: int) -> void:
	vehicle_claim_denied.emit(id)


@rpc("any_peer", "call_remote", "reliable")
func net_request_world() -> void:
	if not multiplayer.is_server():
		return
	_replay_world_to(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "unreliable_ordered")
func net_clock(payload: Dictionary) -> void:
	if multiplayer.is_server():
		return
	GameState.apply_clock(payload)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_vehicle_state(id: int, pos: Vector3, yaw: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var owner := vehicle_owner(id)
	if owner != 0 and sender != owner:
		return
	vehicle_state.emit(id, pos, yaw)
