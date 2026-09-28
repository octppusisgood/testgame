extends Node3D


func _ready() -> void:
	Network.map_seed = 424242
	seed(Network.map_seed)
	var err := Network.host_game(27017)
	print("HOST_ERR ", err)
	var scene = load("res://scenes3d/proto3d.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	scene._spawn_zombie()
	await get_tree().create_timer(1.0).timeout
	print("HOST_ENTITIES_START ", Network._entities.size())
	var waited := 0.0
	while waited < 20.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if multiplayer.get_peers().size() >= 1:
			print("HOST_PEER_JOINED entities=", Network._entities.size())
			var npcs := get_tree().get_nodes_in_group("npcs").size()
			var zombies := get_tree().get_nodes_in_group("zombies").size()
			print("HOST_COUNTS npcs=", npcs, " zombies=", zombies)
			var seen_wanted := false
			for i in 24:
				await get_tree().create_timer(0.5).timeout
				if not Network.wanted_peers.is_empty():
					print("HOST_WANTED_SEEN ", Network.wanted_peers.keys())
					seen_wanted = true
					break
			if not seen_wanted:
				print("HOST_WANTED_MISSED")
			await get_tree().create_timer(2.0).timeout
			print(
				"HOST_AFTER npcs=", get_tree().get_nodes_in_group("npcs").size(),
				" zombies=", get_tree().get_nodes_in_group("zombies").size(),
				" entities=", Network._entities.size()
			)
			get_tree().quit(0 if npcs > 0 else 1)
			return
	print("HOST_TIMEOUT")
	get_tree().quit(1)
