extends Node3D
# 建筑藏匿系统（无内部空间）：城市建筑为实心模型，「进入建筑」= 藏匿——
# 市民从世界上隐藏（模型不可见、移出 npcs 组让丧尸哈希查不到、碰撞关闭、AI 静止），
# 玩家藏匿（模型隐藏、免伤、锁移动锁攻击），建筑门口上方挂「藏匿 N/20」计数标记。
# 容量 20（市民 + 玩家共享）；离开时恢复显示，位置就在门口原地。


const CAP := 20

# building_id -> {"count": int, "label": Label3D}
var _shelters := {}


func _ready() -> void:
	add_to_group("building_interiors")


func count_for(building_id: String) -> int:
	var entry: Dictionary = _shelters.get(building_id, {})
	return int(entry.get("count", 0))


func has_space(door: Node) -> bool:
	var bid := _door_id(door)
	return count_for(bid) < CAP


# 门口的计数标记（懒建，挂 BaseDoor 上方；0 人时隐藏）
func _marker_for(door: Node) -> Label3D:
	var bid := _door_id(door)
	var entry: Dictionary = _shelters.get(bid, {})
	if entry.has("label"):
		return entry["label"]
	var label := Label3D.new()
	label.name = "ShelterLabel"
	label.text = ""
	label.font_size = 44
	label.modulate = Color(0.55, 1.0, 0.75)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 5.2, 0)
	label.visible = false
	door.add_child(label)
	_shelters[bid] = {"count": 0, "label": label}
	return label


func _refresh_marker(door: Node) -> void:
	var bid := _door_id(door)
	var label := _marker_for(door)
	var count := count_for(bid)
	label.visible = count > 0
	label.text = "藏匿 %d/%d" % [count, CAP]


func _door_id(door: Node) -> String:
	var bid = door.get("building_id")
	if bid == null or str(bid).is_empty():
		return "door_%d" % door.get_instance_id()
	return str(bid)


func _adjust(door: Node, delta: int) -> void:
	var bid := _door_id(door)
	var label := _marker_for(door)
	var entry: Dictionary = _shelters[bid]
	entry["count"] = clampi(int(entry.get("count", 0)) + delta, 0, CAP)
	_refresh_marker(door)


# 市民/随从藏匿（批次 253：整个人从地图上消失）——隐藏 + 冻结处理（AI/动画/可见性管理全停）
# + 移出 npcs 组（丧尸空间哈希/池化按组扫描，天然排除）+ 关碰撞；叫出时完整恢复
func enter_npc(door: Node, npc: Node3D) -> bool:
	if not has_space(door):
		return false
	var prev = npc.get("sheltered")
	if prev != null and not str(prev).is_empty():
		return true
	_adjust(door, 1)
	npc.set("sheltered", _door_id(door))
	npc.visible = false
	npc.remove_from_group("npcs")
	npc.set_physics_process(false)
	npc.set_process(false)
	var collision := npc.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	return true


func npc_leave(npc: Node3D) -> void:
	var bid_value = npc.get("sheltered")
	if bid_value == null or str(bid_value).is_empty():
		return
	var bid := str(bid_value)
	npc.set("sheltered", "")
	npc.visible = true
	npc.add_to_group("npcs")
	npc.set_physics_process(true)
	npc.set_process(true)
	var collision := npc.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", false)
	var door := _door_by_id(bid)
	if door != null:
		_adjust(door, -1)


# 玩家藏匿：模型隐藏（相机/交互不受影响），免伤与锁行动在 GameState/fps_player 判定
func enter_player(door: Node, player: Node3D) -> bool:
	if player == null:
		return false
	if not has_space(door):
		GameState.notify("这栋楼已藏满（%d/%d 人），进不去" % [count_for(_door_id(door)), CAP])
		return false
	if not GameState.player_in_building.is_empty():
		return false
	_adjust(door, 1)
	GameState.player_in_building = _door_id(door)
	var body = player.get("_body_root")
	if body != null:
		body.visible = false
	var gun = player.get("_tp_gun_root")
	if gun != null:
		gun.visible = false
	GameState.notify(
		"藏进建筑（%d/%d 人）——不会被发现与攻击，移动暂停（仍可对外开火）；再按 E 直接离开"
		% [count_for(_door_id(door)), CAP]
	)
	return true


func player_leave(player: Node3D) -> void:
	if player == null or GameState.player_in_building.is_empty():
		return
	var bid := GameState.player_in_building
	var body = player.get("_body_root")
	if body != null:
		body.visible = true
	var gun = player.get("_tp_gun_root")
	if gun != null:
		gun.visible = true
	GameState.player_in_building = ""
	var door := _door_by_id(bid)
	if door != null:
		_adjust(door, -1)
		GameState.notify("离开建筑（楼内 %d/%d 人）" % [count_for(bid), CAP])


# 最近的还有空位的建筑门（市民恐慌避难用）
func nearest_enterable_door(pos3: Vector3) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for door in get_tree().get_nodes_in_group("building_doors"):
		if door == null or not is_instance_valid(door) or door.is_queued_for_deletion():
			continue
		if not has_space(door):
			continue
		var dist := (door.global_position as Vector3).distance_to(pos3)
		if dist < best_dist:
			best_dist = dist
			best = door
	return best


func _door_by_id(bid: String) -> Node3D:
	for door in get_tree().get_nodes_in_group("building_doors"):
		if door != null and is_instance_valid(door) and _door_id(door) == bid:
			return door
	return null
