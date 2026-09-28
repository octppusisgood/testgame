extends Node3D

@export var label_text := "按 E 进入"
@export var target_position := Vector3.ZERO
@export var use_return_point := false

var _label: Label3D


func _ready() -> void:
	add_to_group("interactables")
	_label = Label3D.new()
	_label.font_size = 64
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.6, 0)
	_label.text = label_text
	_label.visible = false
	add_child(_label)


func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		_label.visible = false
		return
	_label.visible = global_position.distance_to(player.global_position) < 3.0


# —— 统一交互菜单协议：进入（单选项直接执行）——

func interact_title() -> String:
	return _door_name()


func _door_name() -> String:
	var name := label_text.trim_prefix("按 E ").trim_prefix("按 E")
	return name if name != "" else "进入"


func interact_options(player: Node3D) -> Array:
	if player == null or global_position.distance_to(player.global_position) >= 3.0:
		return []
	return [{"id": "enter", "label": _door_name()}]


func interact_choose(id: String, player: Node3D) -> void:
	if id != "enter" or player == null:
		return
	if use_return_point:
		player.global_position = GameState.return_point_3d
	else:
		GameState.return_point_3d = global_position + Vector3(0, 0, 1.5)
		player.global_position = target_position
	player.velocity = Vector3.ZERO
