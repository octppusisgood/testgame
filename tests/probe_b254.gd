extends Node
# 批次 254 探针 v4：定位「驻扎 NPC 看不到人」——
#  (A) 驻扎为操作员后：J 卡片 + WorkerBody 是否可见
#  (B) 藏匿随从被 J 面板指挥后：是否恢复可见/解冻
var _fails := 0
var _passes := 0

func _ready() -> void:
	await _run()

func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
		print("PASS  ", what)
	else:
		_fails += 1
		print("FAIL  ", what)

func _labels(grid: Node) -> Array:
	var out: Array = []
	if grid == null:
		return out
	for c in grid.get_children():
		for lbl in (c as Node).find_children("*", "Label", true, false):
			out.append(String((lbl as Label).text))
	return out

func _visible(grid: Node, who: String) -> bool:
	for t in _labels(grid):
		if t.contains(who):
			return true
	return false

func _run() -> void:
	GameState.test_mode = true
	GameState.rogue_mode = true
	GameState.home_base = {
		"building_id": "x", "position": Vector3(120.0, 0.0, 120.0),
		"storage": {"materials": 0}, "level": 3, "radius": 12.0,
		"defenses": [], "storage_upgrade": 0, "defense_levels": {}, "workers": [], "hp": 600,
	}
	GameState.pending_hires = ["驻扎甲", "驻扎乙"]
	var city: Node3D = (load("res://scenes3d/proto3d.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	var workers: Node = city.get_node_or_null("Workers")
	var followers: Array = workers.get("_followers")
	if followers.size() < 2:
		_check(false, "随从不足 2 名（%d）" % followers.size())
		_finish()
		return

	# (A) 甲→操作员，检查 WorkerBody 可见
	var fA = followers[0]
	var nameA := String(fA.get("follower_name"))
	GameState.add_worker(nameA)
	var assigned := GameState.assign_operator(Vector3(120.0, 0.0, 120.0), nameA, "turret")
	workers.get("_followers").erase(fA)
	workers.call("_sync_workers")
	fA.free()
	await get_tree().process_frame
	await get_tree().process_frame
	var bodyA = (workers.get("_entities") as Dictionary).get(nameA, null)
	_check(bool(assigned), "操作员指派成功")
	_check(bodyA != null and is_instance_valid(bodyA) and bool(bodyA.visible), "操作员 WorkerBody 存在且可见")
	print("DBG 甲 bodyA=", bodyA, " visible=", (bodyA.visible if bodyA != null and is_instance_valid(bodyA) else "N/A"))

	# (B) 乙→藏匿(冻结)，再用 J 面板指派"跟随"，看是否恢复
	var fB = followers[1]
	var nameB := String(fB.get("follower_name"))
	fB.set("sheltered", "door1")
	fB.visible = false
	fB.remove_from_group("npcs")
	fB.set_physics_process(false)
	fB.set_process(false)
	# 模拟 J 面板"跟随我"：assign_follower_task
	workers.call("assign_follower_task", [fB], "follow")
	await get_tree().process_frame
	_check(bool(fB.visible), "藏匿随从被指挥后恢复可见")
	_check(not bool(fB.get("sheltered")), "藏匿随从被指挥后 sheltered 清空")
	print("DBG 乙 visible=", fB.visible, " sheltered=", fB.get("sheltered"), " mode=", fB.get("mode"))

	workers.call("open_squad_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: Node = workers.get("_squad_grid")
	_check(_visible(grid, nameA), "J 卡片(操作员/工人) 可见")
	_check(_visible(grid, nameB), "J 卡片(藏匿随从) 可见")
	print("DBG 全部卡片：", _labels(grid))
	_finish()

func _finish() -> void:
	print("PROBE RESULT pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
