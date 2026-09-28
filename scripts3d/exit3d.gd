extends Node3D

const SCALE := 0.05
const HOLD_SECONDS := 4.0
const RADIUS := 3.0
const STRUCTURES_SCRIPT := preload("res://scripts3d/exit_structures3d.gd")

var data: Dictionary = {}

var _progress := 0.0
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _pillar_material: StandardMaterial3D
var _sign: Label3D
var _open := true


func _ready() -> void:
	add_to_group("interactables")
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = 0.08
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.position = Vector3(0, 0.06, 0)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.95, 0.75, 0.2, 0.6)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _material
	add_child(_mesh)
	_build_landmark()
	_refresh_state()


func _build_landmark() -> void:
	var structure := Node3D.new()
	structure.set_script(STRUCTURES_SCRIPT)
	add_child(structure)
	structure.build(_exit_kind())
	# 撤离点指示光柱（9 米高，半透明自发光，远处可见）
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.45
	pillar_mesh.bottom_radius = 0.45
	pillar_mesh.height = 9.0
	var pillar := MeshInstance3D.new()
	pillar.mesh = pillar_mesh
	pillar.position = Vector3(0, 4.5, 0)
	_pillar_material = StandardMaterial3D.new()
	_pillar_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar.material_override = _pillar_material
	add_child(pillar)
	# 招牌立柱（仅视觉，不挡路）
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.18, 6.4, 0.18)
	var pole := MeshInstance3D.new()
	pole.mesh = pole_mesh
	pole.position = Vector3(3.4, 3.2, -3.4)
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.35, 0.35, 0.38)
	pole.material_override = pole_material
	add_child(pole)
	# 出口名大招牌（面向玩家，远处可读）
	_sign = Label3D.new()
	_sign.text = "出口·%s" % String(data.get("name", "未知"))
	_sign.font_size = 140
	_sign.outline_size = 24
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = Vector3(0, 7.4, 0)
	add_child(_sign)


func _exit_kind() -> String:
	var kind := String(data.get("kind", ""))
	if kind != "":
		return kind
	var exit_name := String(data.get("name", ""))
	if exit_name.contains("机场"):
		return "airport"
	if exit_name.contains("火车"):
		return "train"
	if exit_name.contains("巴士") or exit_name.contains("公交"):
		return "bus"
	if exit_name.contains("码头"):
		return "dock"
	if exit_name.contains("高速"):
		return "highway"
	if exit_name.contains("小路") or exit_name.contains("小径"):
		return "path"
	return "road"


func _refresh_state() -> void:
	var open := true if data.is_empty() else GameState.exit_open(data)
	_open = open
	if open:
		_material.albedo_color = Color(0.3, 0.9, 0.4, 0.6)
		_pillar_material.albedo_color = Color(0.35, 1.0, 0.45, 0.4)
		_pillar_material.emission_enabled = true
		_pillar_material.emission = Color(0.3, 1.0, 0.4)
		_pillar_material.emission_energy_multiplier = 1.6
		_sign.modulate = Color(0.5, 1.0, 0.55)
		_sign.outline_modulate = Color(0.05, 0.12, 0.05)
	else:
		_material.albedo_color = Color(0.85, 0.25, 0.2, 0.5)
		_pillar_material.albedo_color = Color(0.9, 0.2, 0.18, 0.25)
		_pillar_material.emission_enabled = true
		_pillar_material.emission = Color(0.8, 0.15, 0.12)
		_pillar_material.emission_energy_multiplier = 0.8
		_sign.modulate = Color(1.0, 0.4, 0.35)
		_sign.outline_modulate = Color(0.15, 0.05, 0.05)


func prompt_text() -> String:
	if data.is_empty():
		return ""
	var player = get_tree().get_first_node_in_group("player")
	if player == null or global_position.distance_to(player.global_position) > 6.0:
		return ""
	if not GameState.exit_open(data):
		if global_position.distance_to(player.global_position) < 12.0:
			return "出口：%s（已关闭）" % data["name"]
		return ""
	var requirement := GameState.exit_requirement_text(data)
	var suffix := " · %s" % requirement if not requirement.is_empty() else ""
	if global_position.distance_to(player.global_position) < RADIUS:
		var blocked := GameState.exit_blocked_reason(data, player)
		if not blocked.is_empty():
			return "出口：%s · %s" % [data["name"], blocked]
		return "出口：%s%s" % [data["name"], suffix]
	return "出口：%s · 站入圈内提前撤离%s" % [data["name"], suffix]


func _process(delta: float) -> void:
	if data.is_empty():
		return
	var player = get_tree().get_first_node_in_group("player")
	var open := GameState.exit_open(data)
	if open != _open:
		_refresh_state()
	if not open:
		GameState.exit_progress_active = false
		_progress = 0.0
		return
	if player == null:
		return
	var inside := global_position.distance_to(player.global_position) < RADIUS
	if inside and GameState.is_zombie():
		if GameState.exit_progress_active:
			GameState.exit_progress_active = false
			GameState.exit_progress = 0.0
		_progress = 0.0
		return
	if inside and not GameState.exit_blocked_reason(data, player).is_empty():
		if GameState.exit_progress_active:
			GameState.exit_progress_active = false
			GameState.exit_progress = 0.0
		_progress = 0.0
		return
	if not inside:
		if GameState.exit_progress_active:
			GameState.exit_progress_active = false
			GameState.exit_progress = 0.0
		_progress = 0.0
		return
	var civilians := _civilians_inside()
	GameState.exit_progress_active = true
	_progress = minf(1.0, _progress + delta / HOLD_SECONDS / (1.0 + civilians * 0.6))
	GameState.exit_progress = _progress
	if _progress >= 1.0:
		if not GameState.pay_exit_cost(data):
			_progress = 0.0
			return
		GameState.end_run(true, "你从「%s」提前撤离了城市" % data["name"])


func _civilians_inside() -> int:
	var count := 0
	for npc in get_tree().get_nodes_in_group("pedestrians"):
		if global_position.distance_to(npc.global_position) < RADIUS:
			count += 1
	return count
