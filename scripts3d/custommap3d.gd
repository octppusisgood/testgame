extends Node3D

const MAP_DIR := "user://maps/"
const PLAYER_SCENE := preload("res://scenes3d/fps_player.tscn")
const NPC_SCENE := preload("res://scenes3d/npc3d.tscn")
const ZOMBIE_SCENE := preload("res://scenes3d/zombie3d.tscn")
const LOOT_ITEM_SCENE := preload("res://scenes3d/loot_item3d.tscn")
const PICKUP_SCENE := preload("res://scenes3d/pickup3d.tscn")

const WALL_T := 0.4
const DOOR_W := 2.6
const DOOR_H := 3.0
const BOUNDARY_H := 4.0
const ZOMBIE_CAP := 40
const ZOMBIE_SPAWN_STEP := 0.7

const BUILDING_SIZES := {
	"food": Vector2(16.0, 11.0),
	"gun": Vector2(16.0, 11.0),
	"bank": Vector2(18.0, 13.0),
	"hospital": Vector2(16.0, 11.0),
	"police": Vector2(20.0, 12.0),
	"house": Vector2(12.0, 9.0),
	"prison": Vector2(18.0, 12.0),
}

# 旧版已下架物品 → 现存物品（读取旧自定义地图时迁移）
const LEGACY_LOOT_MAP := {
	"pills": "bandage",
	"medkit": "heal_potion",
	"painkiller": "heal_potion",
	"serum": "heal_potion",
	"jammer": "money_bag",
	"mask": "money_bag",
	"sat_phone": "money_bag",
	"charger": "money_bag",
}

const ITEM_CHOICES := [
	{"id": "bread", "kind": "loot"},
	{"id": "can", "kind": "loot"},
	{"id": "meat", "kind": "loot"},
	{"id": "water", "kind": "loot"},
	{"id": "soda", "kind": "loot"},
	{"id": "bandage", "kind": "loot"},
	{"id": "heal_potion", "kind": "loot"},
	{"id": "axe", "kind": "loot"},
	{"id": "pistol_loot", "kind": "loot"},
	{"id": "shotgun_loot", "kind": "loot"},
	{"id": "rifle_loot", "kind": "loot"},
	{"id": "sniper_loot", "kind": "loot"},
	{"id": "grenade_loot", "kind": "loot"},
	{"id": "vest", "kind": "loot"},
	{"id": "money_bag", "kind": "loot"},
	{"id": "ammo", "kind": "pickup", "amount": 30},
	{"id": "meds", "kind": "pickup", "amount": 2},
	{"id": "food", "kind": "pickup", "amount": 3},
	{"id": "cash", "kind": "pickup", "cash": 80},
]

var _data: Dictionary = {}
var _building_rects: Array = []
var _outbreak_enabled := false
var _outbreak_intensity := 1.0
var _zombie_timer := 0.0
var _zombie_count := 0
var _zombie_count_timer := 0.0
var _boss_timer := 0.0
var _god_spawned := false


static func map_width(data: Dictionary) -> float:
	return clampf(float(data.get("width", 120.0)), 50.0, 400.0)


static func map_depth(data: Dictionary) -> float:
	return clampf(float(data.get("depth", 120.0)), 50.0, 400.0)


static func building_size(id: String, rot := 0) -> Vector2:
	var size: Vector2 = BUILDING_SIZES.get(id, Vector2(12.0, 9.0))
	if rot % 2 == 1:
		return Vector2(size.y, size.x)
	return size


static func building_height(id: String) -> float:
	match id:
		"bank":
			return 12.0
		"police":
			return 10.0
		"house":
			return 6.0
		_:
			return 8.0


static func item_display_name(entry: Dictionary) -> String:
	if String(entry.get("kind", "loot")) == "loot":
		return GameState.loot_name(String(entry.get("id", "can")))
	match String(entry.get("id", "")):
		"ammo":
			return "弹药 ×%d" % int(entry.get("amount", 30))
		"meds":
			return "医疗包 ×%d" % int(entry.get("amount", 2))
		"food":
			return "食物 ×%d" % int(entry.get("amount", 3))
		"cash":
			return "现金 ¥%d" % int(entry.get("cash", 80))
	return String(entry.get("id", "?"))


static func map_path_for(map_name: String) -> String:
	var safe := map_name.strip_edges()
	if safe.is_empty():
		safe = "未命名地图"
	for ch in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(ch, "_")
	return MAP_DIR + safe + ".json"


static func load_map_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}


static func save_map_data(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func list_saved_maps() -> Array:
	var out: Array = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_DIR))
	var dir := DirAccess.open(MAP_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var path := MAP_DIR + file
		var label := file.get_basename()
		var data := load_map_data(path)
		if not data.is_empty():
			label = String(data.get("name", label))
		out.append({"name": label, "path": path})
	out.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
	return out


func _ready() -> void:
	GameState.home_scene = "res://scenes3d/custommap3d.tscn"
	GameState.reset_coverage()
	_data = load_map_data(GameState.custom_map_path)
	if _data.is_empty():
		_data = {
			"name": "空白沙盒",
			"width": 120.0,
			"depth": 120.0,
			"npc_count": 10,
			"buildings": [],
			"items": [],
		}
	_setup_environment()
	_build_ground()
	_build_boundaries()
	_build_buildings()
	_build_items()
	_spawn_npcs()
	_spawn_player()
	var outbreak: Dictionary = _data.get("outbreak", {})
	_outbreak_enabled = bool(outbreak.get("enabled", false))
	_outbreak_intensity = clampf(float(outbreak.get("intensity", 1.0)), 0.6, 1.5)
	if _outbreak_enabled:
		GameState.custom_outbreak = true
		GameState.custom_map_size = Vector2(map_width(_data), map_depth(_data))
		GameState.custom_outbreak_site_needed.connect(_on_outbreak_site_needed)
		GameState.notify(
			"自定义地图：%s · 丧尸危机即将爆发（强度 ×%.1f）" % [
				String(_data.get("name", "?")), _outbreak_intensity,
			]
		)
	else:
		GameState.notify("自定义地图：%s（自由沙盒，无丧尸爆发）" % String(_data.get("name", "?")))


func _exit_tree() -> void:
	if GameState.custom_outbreak_site_needed.is_connected(_on_outbreak_site_needed):
		GameState.custom_outbreak_site_needed.disconnect(_on_outbreak_site_needed)
	GameState.custom_outbreak = false


func _process(delta: float) -> void:
	if not _outbreak_enabled or not Network.is_server():
		return
	if GameState.phase == "outbreak" and GameState.outbreak_sites.is_empty():
		_add_random_site()
	if not GameState.zombies_active():
		return
	var stats := GameState.world_zombie_stats()
	_boss_timer += delta
	if int(stats.get("boss_tier", 0)) > 0 and _boss_timer >= 180.0:
		_boss_timer = 0.0
		_spawn_boss(int(stats["boss_tier"]))
	if bool(stats.get("god", false)) and not _god_spawned:
		_god_spawned = true
		_spawn_boss(10)
		GameState.post_message("尸神·天灾降临！击杀它可获得高额 SP 结算加成", Vector2.ZERO, "zombie", true)
		GameState.notify("尸神·天灾降临！")
	_zombie_count_timer -= delta
	if _zombie_count_timer <= 0.0:
		_zombie_count_timer = 0.5
		_zombie_count = get_tree().get_nodes_in_group("zombies").size()
	var cap := int(ZOMBIE_CAP * float(stats["cap_mult"]) * _outbreak_intensity)
	if _zombie_count >= cap:
		return
	_zombie_timer -= delta
	if _zombie_timer > 0.0:
		return
	_zombie_timer = ZOMBIE_SPAWN_STEP / maxf(float(stats["spawn_mult"]) * _outbreak_intensity, 0.1)
	_zombie_count += 1
	_spawn_zombie()


func _on_outbreak_site_needed(_stage: int) -> void:
	_add_random_site()


func _add_random_site() -> void:
	var w := map_width(_data)
	var d := map_depth(_data)
	var pos := Vector3(randf_range(10.0, w - 10.0), 0.0, randf_range(10.0, d - 10.0))
	if not _building_rects.is_empty() and randf() < 0.7:
		var rect: Rect2 = _building_rects[randi() % _building_rects.size()]
		pos = Vector3(
			clampf(rect.get_center().x + randf_range(-10.0, 10.0), 5.0, w - 5.0),
			0.0,
			clampf(rect.get_center().y + randf_range(-10.0, 10.0), 5.0, d - 5.0)
		)
	GameState.add_outbreak_site(
		{"name": "爆发点", "position": pos, "spread": 1.2, "metric": true}, -1, true
	)


func _spawn_zombie() -> void:
	if GameState.outbreak_sites.is_empty():
		return
	var site: Dictionary = GameState.outbreak_sites[randi() % GameState.outbreak_sites.size()]
	var center: Vector3 = GameState.site_pos3(site)
	var radius := clampf(GameState.site_radius_m(site), 2.0, 120.0)
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = Vector3(
		clampf(center.x + cos(angle) * dist, 1.0, map_width(_data) - 1.0),
		0.2,
		clampf(center.z + sin(angle) * dist, 1.0, map_depth(_data) - 1.0)
	)
	zombie.zombie_tier = GameState.pick_zombie_tier()
	add_child(zombie)


func _spawn_boss(tier: int) -> void:
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.is_boss = true
	zombie.zombie_tier = tier
	zombie.position = _random_free_pos() + Vector3(0, 0.2, 0)
	add_child(zombie)
	var boss_name := String(GameState.zombie_tier_info(tier).get("name", "尸王"))
	GameState.post_message("%s 降临，小心！" % boss_name, Vector2.ZERO, "zombie", true)
	GameState.notify("%s 出现了！" % boss_name)


func _setup_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_ground() -> void:
	var w := map_width(_data)
	var d := map_depth(_data)
	_add_static_box(Vector3(w / 2.0, -0.5, d / 2.0), Vector3(w, 1.0, d), Color(0.22, 0.24, 0.2))


func _build_boundaries() -> void:
	var w := map_width(_data)
	var d := map_depth(_data)
	var t := 0.6
	var color := Color(0.3, 0.3, 0.3)
	_add_static_box(Vector3(w / 2.0, BOUNDARY_H / 2.0, -t / 2.0), Vector3(w + t * 2.0, BOUNDARY_H, t), color)
	_add_static_box(Vector3(w / 2.0, BOUNDARY_H / 2.0, d + t / 2.0), Vector3(w + t * 2.0, BOUNDARY_H, t), color)
	_add_static_box(Vector3(-t / 2.0, BOUNDARY_H / 2.0, d / 2.0), Vector3(t, BOUNDARY_H, d), color)
	_add_static_box(Vector3(w + t / 2.0, BOUNDARY_H / 2.0, d / 2.0), Vector3(t, BOUNDARY_H, d), color)


func _build_buildings() -> void:
	for entry in _data.get("buildings", []):
		_build_building(entry)


func _build_building(entry: Dictionary) -> void:
	var id := String(entry.get("id", "house"))
	if not GameState.BUILDINGS.has(id):
		return
	var cfg: Dictionary = GameState.BUILDINGS[id]
	var rot := int(entry.get("rot", 0)) % 4
	var size2d := building_size(id, rot)
	var width := size2d.x
	var depth := size2d.y
	var height := building_height(id)
	var color: Color = cfg["color"]
	var center := Vector3(float(entry.get("x", 0.0)), 0.0, float(entry.get("z", 0.0)))
	var front_z := depth / 2.0 - WALL_T / 2.0

	_building_rects.append(Rect2(
		center.x - width / 2.0, center.z - depth / 2.0, width, depth
	))

	_add_static_box(
		center + Vector3(0, 0.1, 0),
		Vector3(width, 0.2, depth),
		color.darkened(0.3)
	)
	_add_static_box(
		center + Vector3(0, height / 2.0, -depth / 2.0 + WALL_T / 2.0),
		Vector3(width, height, WALL_T),
		color
	)
	_add_static_box(
		center + Vector3(-width / 2.0 + WALL_T / 2.0, height / 2.0, 0),
		Vector3(WALL_T, height, depth),
		color
	)
	_add_static_box(
		center + Vector3(width / 2.0 - WALL_T / 2.0, height / 2.0, 0),
		Vector3(WALL_T, height, depth),
		color
	)
	var side_w := (width - DOOR_W) / 2.0
	_add_static_box(
		center + Vector3(-DOOR_W / 2.0 - side_w / 2.0, height / 2.0, front_z),
		Vector3(side_w, height, WALL_T),
		color
	)
	_add_static_box(
		center + Vector3(DOOR_W / 2.0 + side_w / 2.0, height / 2.0, front_z),
		Vector3(side_w, height, WALL_T),
		color
	)
	_add_static_box(
		center + Vector3(0, DOOR_H + (height - DOOR_H) / 2.0, front_z),
		Vector3(DOOR_W, height - DOOR_H, WALL_T),
		color
	)
	_add_visual_box(
		center + Vector3(0, height + 0.4, 0),
		Vector3(width + 0.6, 0.8, depth + 0.6),
		color.darkened(0.35)
	)
	_add_visual_box(
		center + Vector3(0, DOOR_H / 2.0, front_z + 0.03),
		Vector3(DOOR_W, DOOR_H, 0.06),
		Color(0.08, 0.08, 0.1)
	)
	_add_visual_box(
		center + Vector3(0, 0.05, depth / 2.0 + 0.8),
		Vector3(DOOR_W + 1.4, 0.1, 1.8),
		color.lightened(0.18)
	)
	var sign_label := Label3D.new()
	sign_label.text = cfg["name"]
	sign_label.font_size = 96
	sign_label.position = center + Vector3(0, height + 2.0, depth / 2.0 + 0.1)
	add_child(sign_label)


func _build_items() -> void:
	for entry in _data.get("items", []):
		var pos := Vector3(float(entry.get("x", 0.0)), 0.1, float(entry.get("z", 0.0)))
		if String(entry.get("kind", "loot")) == "pickup":
			var pickup = PICKUP_SCENE.instantiate()
			pickup.kind = String(entry.get("id", "ammo"))
			pickup.amount = int(entry.get("amount", 10))
			pickup.cash_amount = int(entry.get("cash", 40))
			match pickup.kind:
				"ammo":
					pickup.item_name = "弹药"
				"meds":
					pickup.item_name = "医疗包"
				"food":
					pickup.item_name = "食物"
				_:
					pickup.item_name = "现金"
			add_child(pickup)
			pickup.global_position = pos
		else:
			var loot_id := String(entry.get("id", "can"))
			# 旧版医疗物品已下架，读旧地图时迁移为现存两种医疗物品
			loot_id = String(LEGACY_LOOT_MAP.get(loot_id, loot_id))
			if not GameState.LOOT_ITEMS.has(loot_id):
				continue
			var item = LOOT_ITEM_SCENE.instantiate()
			item.loot_id = loot_id
			add_child(item)
			item.global_position = pos


func _spawn_npcs() -> void:
	var count := clampi(int(_data.get("npc_count", 0)), 0, 200)
	for i in count:
		var npc = NPC_SCENE.instantiate()
		npc.role = "pedestrian"
		npc.position = _random_free_pos()
		add_child(npc)


func _spawn_player() -> void:
	var player = PLAYER_SCENE.instantiate()
	player.position = _random_free_pos() + Vector3(0, 0.1, 0)
	add_child(player)


func _random_free_pos() -> Vector3:
	var w := map_width(_data)
	var d := map_depth(_data)
	for attempt in 80:
		var p := Vector2(randf_range(3.0, w - 3.0), randf_range(3.0, d - 3.0))
		if not _inside_building(p):
			return Vector3(p.x, 0.1, p.y)
	return Vector3(w / 2.0, 0.1, d / 2.0)


func _inside_building(p: Vector2) -> bool:
	for rect: Rect2 in _building_rects:
		if rect.grow(1.0).has_point(p):
			return true
	return false


func _add_static_box(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _make_material(color)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	body.position = center
	add_child(body)


func _add_visual_box(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _make_material(color)
	mesh_instance.position = center
	add_child(mesh_instance)
	return mesh_instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
