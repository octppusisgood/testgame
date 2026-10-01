extends Node3D
# 掉落物（纯数据节点）：无网格、无物理 Area、无逐帧逻辑。
# 视觉由 proto3d 的 PickupRenderer 用 MultiMesh 按类统一绘制（每种 1 个 draw call）；
# 拾取由管理器做玩家近距离扫描。单个掉落物零性能开销，数量不设硬上限。

# 掉落物生成：不合并（满地掉落才有割草手感），超过 2000 时回收最旧的
# 掉落物实体上限：地面同屏 400 个发光球已足够（2000 时每帧组遍历+磁吸
# 快照分桶的主线程成本明显，尸潮清场会卡）
const DROP_CAP := 400

var cash_amount := 40
var item_name := "钱包"
var kind := "cash"
var amount := 1
var net_id := 0
var net_puppet := false


static func spawn_merged(
	parent: Node, kind: String, pos: Vector3, amount: int, item_name: String, cash := 0
) -> void:
	var tree := parent.get_tree()
	if tree == null:
		return
	# 不做合并，只在上限时回收最旧的一个
	var oldest: Node3D = null
	var oldest_msec := 0
	var count := 0
	for node in tree.get_nodes_in_group("pickups"):
		if node.is_queued_for_deletion():
			continue
		count += 1
		var msec := int(node.get_meta("spawn_msec", 0))
		if oldest == null or msec < oldest_msec:
			oldest = node
			oldest_msec = msec
	if count >= DROP_CAP and oldest != null:
		oldest.queue_free()
	var drop = load("res://scenes3d/pickup3d.tscn").instantiate()
	drop.kind = kind
	drop.amount = amount
	drop.item_name = item_name
	if cash > 0:
		drop.cash_amount = cash
	parent.add_child(drop)
	drop.global_position = pos


func net_params() -> Dictionary:
	return {
		"kind": kind,
		"cash_amount": cash_amount,
		"item_name": item_name,
		"amount": amount,
	}


func setup_puppet(params: Dictionary) -> void:
	kind = String(params.get("kind", kind))
	cash_amount = int(params.get("cash_amount", cash_amount))
	item_name = String(params.get("item_name", item_name))
	amount = int(params.get("amount", amount))


func _ready() -> void:
	set_meta("spawn_msec", Time.get_ticks_msec())
	add_to_group("pickups")
	if (
		not net_puppet
		and not GameState.test_mode
		and Network.is_multiplayer()
		and Network.is_server()
	):
		Network.register_entity(self, "pickup", net_params())


# 拾取结算（由管理器的近距离扫描调用；联机傀儡向主机申请移除）
func apply_effect() -> void:
	match kind:
		"cash":
			GameState.add_money(cash_amount)
			GameState.notify("拾取 %s ¥%d" % [item_name, cash_amount])
		"meds":
			GameState.add_resource("meds", amount)
			GameState.notify("拾取 %s ×%d" % [item_name, amount])
		"ammo":
			GameState.add_resource("ammo", amount)
			GameState.notify("拾取 %s ×%d" % [item_name, amount])
		"food":
			GameState.add_resource("food", amount)
			GameState.notify("拾取 %s ×%d" % [item_name, amount])
		"fuel":
			GameState.add_resource("fuel", amount)
			GameState.notify("拾取 %s +%d 升（背包燃料 %d/%d）" % [
				item_name, amount, int(GameState.resources.get("fuel", 0)), int(GameState.CAPS["fuel"]),
			])
		"anomaly":
			GameState.add_loot("anomaly_crystal", maxi(1, amount))
			GameState.notify("收集了异能结晶（背包可吸收或存进储存仓）")
		"relic":
			GameState.collect_boss_relic(item_name)
			GameState.notify("获得 Boss 专属材料：%s" % item_name)
	if net_puppet:
		Network.request_entity_remove(net_id)
	else:
		Network.unregister_entity(self)
	queue_free()
