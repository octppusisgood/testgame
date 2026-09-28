class_name DamagePopup
extends RefCounted

# 同屏飘字上限：扫射怪群时每秒几十个 Label3D 全是独立 draw call，超出直接丢弃（暴击不受限）
const MAX_ACTIVE := 24
static var _active := 0


static func show_damage(parent: Node, pos: Vector3, amount: int, crit := false) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not crit and _active >= MAX_ACTIVE:
		return
	_active += 1
	var label := Label3D.new()
	label.text = ("%d 暴击" % amount) if crit else str(amount)
	label.font_size = 96 if crit else 48
	label.modulate = Color(1.0, 0.5, 0.12) if crit else Color(1.0, 0.95, 0.85)
	label.outline_size = 18
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = pos + Vector3(
		randf_range(-0.15, 0.15), 0.4, randf_range(-0.15, 0.15)
	)
	parent.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.75)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	tween.tween_callback(func() -> void:
		_active -= 1
		label.queue_free()
	)


static func is_headshot(hit_pos: Vector3, target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var scale_y := target.scale.y if absf(target.scale.y) > 0.01 else 1.0
	var head_line := 1.42 * scale_y
	return hit_pos.y >= target.global_position.y + head_line
