extends Control

# 瘦身版主菜单：只保留肉鸽模式入口（单人 / 测试 / 联机 / 编辑器已移除）

var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.09)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)

	var title := Label.new()
	title.text = "回响之城"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var info := Label.new()
	info.text = "灾变预计于 %d 分钟后发生。进入与否，是你的选择。" % int(round(GameState.prep_duration() / 60.0))
	info.add_theme_font_size_override("font_size", 12)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)

	box.add_child(_make_button("肉鸽模式（割草升级）", _on_rogue))

	_status = Label.new()
	_status.text = "活下去，或者带走能带走的一切。"
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func _fit_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	if size != viewport_size:
		size = viewport_size


func _make_button(text: String, handler: Callable, min_width := 0.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 30)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(handler)
	return button


# 肉鸽模式入口：纯割草，击破城市四周 10 个异常能量点获胜，局内击杀升级三选一
func _on_rogue() -> void:
	Network.leave()
	GameState.rogue_mode = true
	GameState.custom_map_path = ""
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes3d/proto3d.tscn")
