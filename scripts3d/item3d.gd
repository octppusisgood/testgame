extends Node3D

@export var item_name := "物品"
@export var kind := "food"
@export var price := 10
@export var cash_amount := 40
@export var weapon_id := ""
@export var crime_level := 1

const HOLD_SECONDS := 1.2
const REACH := 2.6

var _progress := 0.0


func _ready() -> void:
	add_to_group("interactables")


func _process(delta: float) -> void:
	if GameState.is_zombie() or GameState.interact_menu_open:
		_progress = 0.0
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) > REACH:
		_progress = 0.0
		return
	# 搜刮（原购买/偷窃/抢夺已删除）：长按 E
	if Input.is_action_pressed("interact"):
		_progress += delta / HOLD_SECONDS
		if _progress >= 1.0:
			GameState.notify("搜刮到 %s" % item_name)
			_take()
	else:
		_progress = maxf(0.0, _progress - delta * 1.5)


func prompt_text() -> String:
	if GameState.is_zombie():
		return ""
	var player = get_tree().get_first_node_in_group("player")
	if player == null or global_position.distance_to(player.global_position) > REACH:
		return ""
	if _progress > 0.01:
		return "%s · 搜刮中 %d%%" % [item_name, int(minf(_progress, 1.0) * 100.0)]
	return "%s · 长按 E 搜刮" % item_name


func _take() -> void:
	match kind:
		"cash":
			GameState.add_money(cash_amount)
			GameState.notify("拿到 ¥%d" % cash_amount)
		"weapon":
			GameState.add_weapon(weapon_id)
			GameState.notify("获得 %s（V/1/2/3 切换）" % item_name)
		_:
			GameState.add_resource(kind)
			GameState.notify("获得 %s" % item_name)
	queue_free()
