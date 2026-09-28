extends Node3D

# 背包探针（批次 36）：验证 5 分类分区（食物/药品/弹药/武器/特殊物品）+ 无格子逻辑
var _fails := 0


func _ready() -> void:
	GameState.money = 345
	GameState.resources["food"] = 3
	GameState.resources["meds"] = 2
	GameState.resources["ammo"] = 24
	GameState.weapons = {"pistol": 1, "shotgun": 1, "rifle": 0, "smg": 1}
	GameState.current_weapon = "pistol"
	GameState.loot_items = []
	GameState.add_loot("bread", 2)
	GameState.add_loot("water", 1)
	GameState.add_loot("bandage", 1)
	GameState.add_loot("axe", 1)
	GameState.add_loot("scope_2x", 1)
	GameState.add_loot("plank", 3)

	var items := GameState.backpack_items()
	var by_id := {}
	var counts := {}
	for item in items:
		var iid := String(item["id"])
		_check(item.has("group"), "条目带 group 字段：" + iid)
		var g := String(item.get("group", ""))
		by_id[iid] = g
		counts[g] = int(counts.get(g, 0)) + 1

	# 分类映射
	_check(by_id.get("food", "") == "food", "资源食物 → 食物")
	_check(by_id.get("meds", "") == "med", "资源医疗包 → 药品")
	_check(by_id.get("ammo", "") == "ammo", "资源弹药 → 弹药")
	_check(by_id.get("cash", "") == "special", "现金 → 特殊物品")
	_check(by_id.get("pistol", "") == "weapon", "手枪 → 武器")
	_check(by_id.get("shotgun", "") == "weapon", "霰弹枪 → 武器")
	_check(by_id.has("smg"), "列出全部持有枪械（含 smg）")
	_check(by_id.get("loot_bread", "") == "food", "loot 面包 → 食物")
	_check(by_id.get("loot_water", "") == "food", "loot 饮料 → 食物")
	_check(by_id.get("loot_bandage", "") == "med", "loot 绷带 → 药品")
	_check(by_id.get("loot_axe", "") == "weapon", "loot 近战 → 武器")
	_check(by_id.get("loot_scope_2x", "") == "special", "loot 配件 → 特殊物品")
	_check(by_id.get("loot_plank", "") == "special", "loot 杂物 → 特殊物品")
	_check(not by_id.has("rifle"), "未持有步枪不显示")

	# 5 类齐全 + 计数一致 + 无越界分类
	for group in GameState.BACKPACK_GROUPS:
		var gid := String(group["id"])
		_check(int(counts.get(gid, 0)) > 0, "分区非空：" + gid)
		_check(
			GameState.backpack_group_items(gid).size() == int(counts.get(gid, 0)),
			"backpack_group_items 计数一致：" + gid
		)
	for g in counts:
		_check(
			String(g) in ["food", "med", "ammo", "weapon", "special"],
			"分区取值合法：" + String(g)
		)

	# 格子逻辑已彻底移除（无悬空引用）
	_check(not GameState.has_method("can_place_item"), "can_place_item 已移除")
	_check(not GameState.has_method("move_backpack_item"), "move_backpack_item 已移除")
	_check(not GameState.has_method("ensure_backpack_layout"), "ensure_backpack_layout 已移除")
	_check(GameState.get("backpack_layout") == null, "backpack_layout 变量已移除")

	if _fails > 0:
		print("BACKPACK PROBE FAILED: ", _fails)
		get_tree().quit(1)
	else:
		print("BACKPACK PROBE OK")
		get_tree().quit(0)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("OK ", name)
	else:
		_fails += 1
		print("FAIL ", name)
