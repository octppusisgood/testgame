extends Node3D

const REMOTE_SCENE := preload("res://scenes3d/remote_player3d.tscn")

var _remotes := {}


func _ready() -> void:
	if not Network.is_multiplayer():
		set_process(false)
		return
	add_to_group("net_players")
	Network.player_state.connect(_on_player_state)
	Network.player_died.connect(_on_player_died)
	Network.spawn_remote.connect(_spawn_remote)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if Network.is_server():
		for id in multiplayer.get_peers():
			_spawn_remote(int(id))
	else:
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		if Network.is_connected_peer():
			_on_connected_to_server()


func _on_connected_to_server() -> void:
	_spawn_remote(1)
	for id in multiplayer.get_peers():
		_spawn_remote(int(id))
	Network.net_request_peers.rpc_id(1)


func _on_peer_connected(id: int) -> void:
	if id == multiplayer.get_unique_id():
		return
	_spawn_remote(id)


func _on_peer_disconnected(id: int) -> void:
	_remove_remote(id)


func _on_player_state(peer_id: int, pos: Vector3, yaw: float, moving: bool) -> void:
	var remote = _remotes.get(peer_id)
	if remote != null and is_instance_valid(remote):
		remote.set_state(pos, yaw, moving)


func _on_player_died(peer_id: int) -> void:
	var remote = _remotes.get(peer_id)
	if remote != null and is_instance_valid(remote):
		remote.die()


func _spawn_remote(id: int) -> void:
	if id == multiplayer.get_unique_id():
		return
	if _remotes.has(id) and is_instance_valid(_remotes[id]):
		return
	var remote = REMOTE_SCENE.instantiate()
	remote.peer_id = id
	add_child(remote)
	remote.global_position = Vector3(
		GameState.SPAWN_POS.x * 0.05 + randf_range(-3.0, 3.0),
		0.3,
		GameState.SPAWN_POS.y * 0.05 + randf_range(-3.0, 3.0)
	)
	_remotes[id] = remote


func _remove_remote(id: int) -> void:
	var remote = _remotes.get(id)
	if remote != null and is_instance_valid(remote):
		remote.queue_free()
	_remotes.erase(id)
