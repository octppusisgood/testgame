extends Node3D


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var err := Network.join_game("127.0.0.1", 27017)
	print("CLIENT_ERR ", err)
	var scene = load("res://scenes3d/proto3d.tscn").instantiate()
	add_child(scene)
	var waited := 0.0
	while waited < 15.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if (
			multiplayer.multiplayer_peer != null
			and multiplayer.multiplayer_peer.get_connection_status()
			== MultiplayerPeer.CONNECTION_CONNECTED
		):
			await get_tree().create_timer(3.0).timeout
			var npcs := get_tree().get_nodes_in_group("npcs").size()
			var zombies := get_tree().get_nodes_in_group("zombies").size()
			var player = get_tree().get_first_node_in_group("player")
			print("CLIENT_AI npcs=", npcs, " zombies=", zombies, " player=", player != null)
			if zombies > 0:
				var victim = get_tree().get_nodes_in_group("zombies")[0]
				var before := zombies
				victim.take_damage(99999)
				await get_tree().create_timer(2.0).timeout
				var after := get_tree().get_nodes_in_group("zombies").size()
				print("CLIENT_KILL before=", before, " after=", after)
			print("CLIENT_PRE_WANTED ", GameState.wanted)
			GameState.set_wanted(2)
			await get_tree().create_timer(0.5).timeout
			print(
				"CLIENT_WANTED_SET myid=", multiplayer.get_unique_id(),
				" local=", GameState.wanted,
				" peers=", Network.wanted_peers
			)
			get_tree().quit(0 if npcs > 0 and zombies > 0 else 1)
			return
	print("CLIENT_TIMEOUT")
	get_tree().quit(1)
