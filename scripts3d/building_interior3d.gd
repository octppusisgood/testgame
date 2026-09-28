extends Node3D
# 建筑内部系统：城市建筑为 SYNTY 实心模型（无门洞/内构），
# 「进入建筑」= 传送到地下懒生成的内部房间（y=-60，网格排布在城市远处）。
# 每栋建筑一个房间，容量 20（玩家 + 市民共享）；市民恐慌时自动躲入（npc3d 调用）。
# 躲入即物理远离丧尸（空间哈希查询按 3D 距离，天然打不到屋内的人）。


const CAP := 20
const ROOM_W := 14.0
const ROOM_D := 10.0
const ROOM_H := 3.2
# 房间网格起点与步长：远离城市（3000m 外），互不重叠
const GRID_ORIGIN := Vector3(3000.0, -60.0, 3000.0)
const GRID_STEP := 40.0

# building_id -> BuildingInterior
var _rooms := {}
var _next_index := 0


func _ready() -> void:
	add_to_group("building_interiors")


# 取（或懒生成）门口对应的房间
func room_for(door: Node) -> BuildingInterior:
	var bid := str(door.get("building_id"))
	if bid.is_empty():
		bid = "door_%d" % door.get_instance_id()
	if _rooms.has(bid):
		return _rooms[bid]
	var room := BuildingInterior.new()
	room.building_id = bid
	var door_name = door.get("building_name")
	room.building_name = str(door_name) if door_name != null else "建筑"
	room.door_pos = (door.global_position as Vector3) + Vector3(0, 0.4, 2.0)
	room.root = self
	var col := _next_index % 50
	var row := _next_index / 50
	_next_index += 1
	room.room_center = GRID_ORIGIN + Vector3(col * GRID_STEP, 0.0, row * GRID_STEP)
	add_child(room)
	_rooms[bid] = room
	return room


func occupant_count_for(building_id: String) -> int:
	var room: BuildingInterior = _rooms.get(building_id, null)
	return room.occupant_count() if room != null else 0


# 最近的还有空位的建筑门（市民恐慌避难用）
func nearest_enterable_door(pos3: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for door in get_tree().get_nodes_in_group("building_doors"):
		if door == null or not is_instance_valid(door) or door.is_queued_for_deletion():
			continue
		var room: BuildingInterior = _rooms.get(str(door.get("building_id")), null)
		if room != null and not room.has_space():
			continue
		var dist := (door.global_position as Vector3).distance_to(pos3)
		if dist < best_dist:
			best_dist = dist
			best = door
	return best


func enter_player(door: Node, player: Node3D) -> bool:
	if player == null:
		return false
	var room := room_for(door)
	if not room.has_space():
		GameState.notify("%s 已满（%d/%d 人），进不去" % [room.building_name, room.occupant_count(), CAP])
		return false
	room.enter(player)
	GameState.player_in_building = room.building_id
	GameState.notify(
		"进入 %s（%d/%d 人）——屋内不受丧尸攻击，走到出口垫按 E 离开"
		% [room.building_name, room.occupant_count(), CAP]
	)
	return true


func player_leave(player: Node3D) -> void:
	if player == null:
		return
	var room := _room_of(player)
	if room == null:
		GameState.player_in_building = ""
		return
	room.remove_occupant(player)
	player.global_position = room.door_pos
	GameState.player_in_building = ""
	GameState.notify("离开 %s" % room.building_name)


func enter_npc(door: Node, npc: Node3D) -> bool:
	var room := room_for(door)
	if not room.has_space():
		return false
	room.enter(npc)
	return true


func npc_leave(npc: Node3D) -> void:
	var room := _room_of(npc)
	if room == null:
		return
	room.remove_occupant(npc)
	npc.global_position = room.door_pos


func _room_of(entity: Node3D) -> BuildingInterior:
	for room in _rooms.values():
		if room != null and is_instance_valid(room) and room.has_occupant(entity):
			return room
	return null


# ————————————————— 单个建筑内部房间 —————————————————

class BuildingInterior extends Node3D:
	var building_id := ""
	var building_name := "建筑"
	var door_pos := Vector3.ZERO
	var room_center := Vector3.ZERO
	var root: Node3D = null
	var occupants: Array = []


	func _ready() -> void:
		_build_room()


	func _build_room() -> void:
		var floor_body := StaticBody3D.new()
		var floor_shape := CollisionShape3D.new()
		var floor_box := BoxShape3D.new()
		floor_box.size = Vector3(ROOM_W, 0.2, ROOM_D)
		floor_shape.shape = floor_box
		floor_body.add_child(floor_shape)
		var floor_mesh := MeshInstance3D.new()
		var floor_box_mesh := BoxMesh.new()
		floor_box_mesh.size = Vector3(ROOM_W, 0.2, ROOM_D)
		floor_mesh.mesh = floor_box_mesh
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.42, 0.38, 0.34)
		floor_mesh.material_override = floor_mat
		floor_body.add_child(floor_mesh)
		add_child(floor_body)
		# 地板顶面 = room_center.y
		floor_body.global_position = room_center + Vector3(0, -0.1, 0)

		# 四面墙（前墙留 2.4m 门口缺口，出口垫在缺口处）
		var wall_mat := StandardMaterial3D.new()
		wall_mat.albedo_color = Color(0.62, 0.58, 0.54)
		_add_wall(Vector3(0, 0, -ROOM_D / 2.0), Vector3(ROOM_W, ROOM_H, 0.4), wall_mat)
		_add_wall(Vector3(-ROOM_W / 2.0, 0, 0), Vector3(0.4, ROOM_H, ROOM_D), wall_mat)
		_add_wall(Vector3(ROOM_W / 2.0, 0, 0), Vector3(0.4, ROOM_H, ROOM_D), wall_mat)
		var seg_w := (ROOM_W - 2.4) / 2.0
		_add_wall(
			Vector3(-(2.4 / 2.0 + seg_w / 2.0), 0, ROOM_D / 2.0),
			Vector3(seg_w, ROOM_H, 0.4), wall_mat
		)
		_add_wall(
			Vector3(2.4 / 2.0 + seg_w / 2.0, 0, ROOM_D / 2.0),
			Vector3(seg_w, ROOM_H, 0.4), wall_mat
		)

		# 沿墙装饰箱（纯视觉件，无碰撞）
		var crate_mat := StandardMaterial3D.new()
		crate_mat.albedo_color = Color(0.55, 0.45, 0.3)
		for offset in [
			Vector3(-ROOM_W / 2.0 + 1.2, 0.5, -ROOM_D / 2.0 + 1.2),
			Vector3(-ROOM_W / 2.0 + 1.2, 1.5, -ROOM_D / 2.0 + 1.2),
			Vector3(ROOM_W / 2.0 - 1.2, 0.5, -ROOM_D / 2.0 + 1.2),
			Vector3(ROOM_W / 2.0 - 1.5, 0.5, -ROOM_D / 2.0 + 2.8),
			Vector3(ROOM_W / 2.0 - 1.5, 0.5, ROOM_D / 2.0 - 1.4),
		]:
			var crate := MeshInstance3D.new()
			var crate_box := BoxMesh.new()
			crate_box.size = Vector3(1.0, 1.0, 1.0)
			crate.mesh = crate_box
			crate.material_override = crate_mat
			add_child(crate)
			crate.global_position = room_center + offset

		# 出口垫：前墙缺口处，E 离开
		var pad := ExitPad.new()
		pad.room = self
		add_child(pad)
		pad.global_position = room_center + Vector3(0, 0.02, ROOM_D / 2.0 - 0.8)


	func _add_wall(offset: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		mesh.mesh = box_mesh
		mesh.material_override = mat
		body.add_child(mesh)
		add_child(body)
		body.global_position = room_center + Vector3(0, ROOM_H / 2.0, 0) + offset


	func has_space() -> bool:
		return occupant_count() < CAP


	func occupant_count() -> int:
		var count := 0
		for occ in occupants:
			if occ != null and is_instance_valid(occ) and not occ.is_queued_for_deletion():
				count += 1
		return count


	func has_occupant(entity: Node3D) -> bool:
		return occupants.has(entity)


	func enter(entity: Node3D) -> void:
		if not occupants.has(entity):
			occupants.append(entity)
		var angle := randf() * TAU
		var r := sqrt(randf()) * 2.5
		entity.global_position = room_center + Vector3(cos(angle) * r, 0.4, sin(angle) * r * 0.6)


	func remove_occupant(entity: Node3D) -> void:
		occupants.erase(entity)


# 出口垫：玩家按 E 离开建筑（市民离开走代码不走交互）
class ExitPad extends Node3D:
	const REACH := 4.0
	var room: BuildingInterior = null


	func _ready() -> void:
		add_to_group("interactables")
		var pad_mesh := MeshInstance3D.new()
		var pad_box := BoxMesh.new()
		pad_box.size = Vector3(2.4, 0.04, 1.2)
		pad_mesh.mesh = pad_box
		var pad_mat := StandardMaterial3D.new()
		pad_mat.albedo_color = Color(0.3, 0.9, 0.5)
		pad_mat.emission_enabled = true
		pad_mat.emission = Color(0.2, 0.8, 0.4)
		pad_mesh.material_override = pad_mat
		add_child(pad_mesh)
		var label := Label3D.new()
		label.text = "出口"
		label.font_size = 48
		label.modulate = Color(0.5, 1.0, 0.7)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 1.4, 0)
		add_child(label)


	func within_reach(player: Node3D) -> bool:
		return player != null and global_position.distance_to(player.global_position) <= REACH


	func interact_title() -> String:
		return "%s · 出口" % (room.building_name if room != null else "建筑")


	func interact_options(player: Node3D) -> Array:
		if player == null or not within_reach(player):
			return []
		return [{"id": "leave", "label": "离开建筑（回到门口）"}]


	func interact_choose(id: String, player: Node3D) -> void:
		if id == "leave" and room != null and room.root != null:
			room.root.player_leave(player)
