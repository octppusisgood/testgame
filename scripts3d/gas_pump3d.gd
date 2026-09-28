extends Node3D
# 油泵：加油站前庭的交互点。把车开到油泵旁，按 E 打开菜单花钱加油。
# 三类燃料（汽油/柴油/燃气）油价不同，油泵自动按最近载具的燃料类型计价

const INTERACT_REACH := 4.0
const VEHICLE_REACH := 9.0
const SMALL_ADD := 20.0
# 灌装背包的油价（站售散油，统一 ¥3/升）
const CAN_PRICE := 3


func _ready() -> void:
	add_to_group("interactables")
	# 自动补给标记：车辆停在油泵 4m 内自动免费加油（批次 153）
	add_to_group("fuel_stations")


func prompt_text() -> String:
	return ""


func interact_title() -> String:
	return "油泵"


# 找油泵旁最近的载具
func _near_vehicle() -> Node3D:
	var best: Node3D = null
	var best_d := VEHICLE_REACH
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if vehicle.is_queued_for_deletion():
			continue
		var d: float = global_position.distance_to(vehicle.global_position)
		if d < best_d:
			best_d = d
			best = vehicle
	return best


func interact_options(player: Node3D) -> Array:
	if player == null or global_position.distance_to(player.global_position) > INTERACT_REACH:
		return []
	var options: Array = []
	var vehicle := _near_vehicle()
	if vehicle == null:
		options.append({
			"id": "none",
			"label": "附近没有载具",
			"disabled": true,
			"reason": "把车开到油泵旁再下车加油",
		})
	else:
		var need: float = vehicle.tank_cap() - vehicle.fuel
		if need < 0.5:
			options.append(
				{"id": "full", "label": "油箱已满", "disabled": true, "reason": "这辆车不需要加油"}
			)
		else:
			var price: int = vehicle.fuel_price()
			var type_name: String = vehicle.fuel_type_name()
			var fill_cost := int(ceil(need * price))
			var add_liters := minf(SMALL_ADD, need)
			var add_cost := int(ceil(add_liters * price))
			options.append({
				"id": "fill",
				"label": "加满（%s ¥%d/升 → ¥%d）" % [type_name, price, fill_cost],
				"disabled": GameState.money < fill_cost,
				"reason": "现金不够",
			})
			options.append({
				"id": "add",
				"label": "加 %.0f 升 %s（¥%d）" % [add_liters, type_name, add_cost],
				"disabled": GameState.money < add_cost,
				"reason": "现金不够",
			})
	# 灌装：买油装进背包（汽油桶按升携带，回据点可入仓库）
	var carry := int(GameState.resources.get("fuel", 0))
	var can_space := int(GameState.CAPS.get("fuel", 60)) - carry
	options.append({
		"id": "can",
		"label": "灌装到背包（¥%d/升，可灌 %d 升）" % [CAN_PRICE, can_space],
		"disabled": can_space <= 0 or GameState.money < CAN_PRICE,
		"reason": "背包燃料已满" if can_space <= 0 else "现金不够",
	})
	return options


func interact_choose(id: String, _player: Node3D) -> void:
	if id == "can":
		var carry := int(GameState.resources.get("fuel", 0))
		var amount := int(GameState.CAPS.get("fuel", 60)) - carry
		if amount <= 0:
			GameState.notify("背包燃料已满")
			return
		var cost := amount * CAN_PRICE
		if not GameState.spend_money(cost):
			GameState.notify("现金不够（需要 ¥%d）" % cost)
			return
		GameState.add_resource("fuel", amount)
		GameState.notify("灌装 %d 升燃料（¥%d）· 背包 %d/%d" % [
			amount, cost, int(GameState.resources.get("fuel", 0)), int(GameState.CAPS["fuel"]),
		])
		return
	var vehicle := _near_vehicle()
	if vehicle == null:
		GameState.notify("附近没有载具")
		return
	var need: float = vehicle.tank_cap() - vehicle.fuel
	if need < 0.05:
		GameState.notify("油箱已满")
		return
	var amount := need
	if id == "add":
		amount = minf(SMALL_ADD, need)
	elif id != "fill":
		return
	var cost := int(ceil(amount * vehicle.fuel_price()))
	if not GameState.spend_money(cost):
		GameState.notify("现金不够（需要 ¥%d）" % cost)
		return
	var added: float = vehicle.refuel(amount)
	GameState.notify(
		"加 %.0f 升%s（¥%d）· 油箱 %d%%" % [
			added, vehicle.fuel_type_name(), cost, int(vehicle.fuel_ratio() * 100.0),
		]
	)
