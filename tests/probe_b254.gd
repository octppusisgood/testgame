extends Node
# 批次 254 探针：复现「驻扎随从在 J 面板看不到」——守营地/驻守/驾驶/藏匿四种驻扎态的卡片数。

var _fails: int = 0
var _passes: int = 0


func _ready() -> void:
	await _run()


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
		print("PASS  ", what)
	else:
		_fails += 1
		print("FAIL  ", what)


func _run() -> void:
	GameState.test_mode = true
	GameState.rogue_mode = true
	GameState.home_base = {
		"building_id": "x", "position": Vector3(120.0, 0.0, 120.0),
		"storage": {"materials": 0}, "level": 1, "radius": 12.0,
		"defenses": [], "storage_upgrade": 0, "defense_levels": {}, "workers": [], "hp": 600,
	}
	GameState.pending_hires = ["驻扎甲", "驻扎乙", "驻扎丙"]
	var city: Node3D = (load("res://scenes3d/proto3d.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	var workers := city.get_node_or_null("Workers")
	var followers: Array = workers.get("_followers")
	if followers.size() < 3:
		_check(false, "随从不足 3 名（%d）" % followers.size())
		_finish()
		return
	# 分别指派：守营地（goto_base→guard）、驻守标点（defend）、跟随（对照）
	GameState.map_marker = Vector2(3000.0, 3000.0)
	workers.call("assign_follower_task", [followers[0]], "goto_base")
	workers.call("assign_follower_task", [followers[1]], "defend", Vector3(150.0, 0.0, 150.0))
	workers.call("assign_follower_task", [followers[2]], "follow")
	await get_tree().physics_frame
	# 打开 J 面板并统计随从卡片
	workers.call("open_squad_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	var names := ["驻扎甲", "驻扎乙", "驻扎丙"]
	var found := {}
	var grid: Node = workers.get("_squad_grid")
	if grid != null:
		for c in grid.get_children():
			for lbl in (c as Node).find_children("*", "Label", true, false):
				var t := (lbl as Label).text
				for n in names:
					if t.contains(n):
						found[n] = true
	for n in names:
		_check(bool(found.get(n, false)), "J 面板可见：%s（mode=%s）" % [n, str((followers[names.find(n)] as Node).get("mode"))])
	print("DBG followers=", followers.size())
	_finish()


func _finish() -> void:
	print("PROBE RESULT pass=%d fail=%d" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
