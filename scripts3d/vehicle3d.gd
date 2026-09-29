extends CharacterBody3D

const GRAVITY := 18.0
const SCALE := 0.05
const ARRIVE_DIST := 2.0
# Synty 车辆预制体（城市包轿车/出租/面包车，末日包跑车/货车，军事包坦克见 _build_tank_visual）
const CITY_VEH := "res://assets/Synty/PolygonCity/Prefabs/Vehicles/"
const APOCO_VEH := "res://assets/Synty/PolygonApocalypse/Prefabs/Vehicles/"
const CAR_MODELS := [
	"sedan", "sedan-sports", "suv", "taxi", "van", "truck", "delivery", "hatchback-sports", "tank",
	"light_tank", "apc", "apc_heavy", "armored_car", "technical", "rocket_truck", "radar_tank",
]
const CAR_MODEL_PATHS := {
	"sedan": CITY_VEH + "SM_Veh_Car_Sedan_01.tscn",
	"sedan-sports": APOCO_VEH + "SM_Veh_Muscle_01.tscn",
	"suv": CITY_VEH + "SM_Veh_Car_Medium_01.tscn",
	"taxi": CITY_VEH + "SM_Veh_Car_Taxi_01.tscn",
	"van": CITY_VEH + "SM_Veh_Car_Van_01.tscn",
	"truck": APOCO_VEH + "SM_Veh_BigRig_01.tscn",
	"delivery": APOCO_VEH + "SM_Veh_NewsVan_01.tscn",
	"hatchback-sports": APOCO_VEH + "SM_Veh_HotRod_01.tscn",
	# 军用车（PolygonMilitary 包，批次 182）
	"tank": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Tank_USA_01.tscn",
	"light_tank": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Light_Tank_01.tscn",
	"apc": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_APC_01.tscn",
	"apc_heavy": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_APC_Heavy_01.tscn",
	"armored_car": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Light_Armored_Car_01.tscn",
	"technical": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Pickup_Technical_01.tscn",
	"rocket_truck": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Rocket_Truck_01.tscn",
	"radar_tank": "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Radar_Tank_01.tscn",
}
# APC 二号皮肤（同车型随机外观）与其对应击毁版
const APC_ALT_PATH := "res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_APC_02.tscn"
# 模型路径 → 击毁版路径（报废换壳；民用车无击毁版，沿用变灰）
const DESTROYED_MODELS := {
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Tank_USA_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_Tank_USA_Destroyed_01.tscn",
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Light_Tank_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_Light_Tank_01_Destroyed.tscn",
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_APC_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_APC_01_Destroyed.tscn",
	APC_ALT_PATH:
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_APC_02_Destroyed.tscn",
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_APC_Heavy_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_APC_Heavy_01_Destroyed.tscn",
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Light_Armored_Car_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_Light_Armored_Car_01_Destroyed.tscn",
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Pickup_Technical_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_Pickup_Technical_Destroyed_01.tscn",
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Rocket_Truck_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_Rocket_Truck_01_Destroyed.tscn",
	"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/SM_Veh_Radar_Tank_01.tscn":
		"res://assets/Synty/PolygonMilitary/Prefabs/Vehicles/Destroyed/SM_Veh_Radar_Tank_01_Destroyed.tscn",
}
# 车辆血量（设计：普通轿车 1000 / 集装箱车 5000 / 坦克 10000）
const VEHICLE_HP := {
	"sedan": 1000, "sedan-sports": 1000, "suv": 1000, "taxi": 1000, "hatchback-sports": 1000,
	"van": 5000, "truck": 5000, "delivery": 5000,
	"tank": 10000, "apc_heavy": 4500, "rocket_truck": 5000, "light_tank": 4000,
	"apc": 3000, "radar_tank": 3000, "armored_car": 1500, "technical": 1200,
}
# 坦克炮管/机枪威力（等同火箭炮/重机枪）
const TANK_CANNON_DAMAGE := 200
const TANK_CANNON_RADIUS := 8.0
const TANK_CANNON_CD := 1.2
const TANK_MG_DAMAGE := 70
const TANK_MG_CD := 0.25
const CAR_WIDTH := 2.0
const MATERIAL_PILE_SCENE := preload("res://scenes3d/material_pile3d.tscn")
const PILE_REACH := 2.5
# 建材磁吸：此半径内的建材堆会被车吸过来
const PILE_MAGNET_RADIUS := 8.0
const PILE_MAGNET_SPEED := 10.0
# 油箱容量（升）按车型；行驶中怠速 0.03 升/秒 + 按车速比例最多 0.22 升/秒
const FUEL_TANK := {
	"sedan": 55.0, "sedan-sports": 50.0, "suv": 65.0, "taxi": 55.0,
	"van": 70.0, "truck": 90.0, "delivery": 80.0, "hatchback-sports": 45.0,
	"tank": 120.0, "light_tank": 90.0, "apc": 80.0, "apc_heavy": 95.0,
	"armored_car": 60.0, "technical": 60.0, "rocket_truck": 90.0, "radar_tank": 80.0,
}
# 三类燃料：轿车/跑车汽油、货运车柴油、出租车燃气；油价按类区分
const FUEL_TYPES := {"petrol": "汽油", "diesel": "柴油", "lpg": "燃气"}
const FUEL_TYPE_BY_MODEL := {
	"sedan": "petrol", "sedan-sports": "petrol", "suv": "petrol",
	"hatchback-sports": "petrol",
	"van": "diesel", "truck": "diesel", "delivery": "diesel",
	"taxi": "lpg",
	# 军用车统一柴油（武装皮卡除外，跟民用车一样烧汽油）
	"tank": "diesel", "light_tank": "diesel", "apc": "diesel", "apc_heavy": "diesel",
	"armored_car": "diesel", "technical": "petrol", "rocket_truck": "diesel", "radar_tank": "diesel",
}
const FUEL_PRICE := {"petrol": 3, "diesel": 2, "lpg": 4}
const FUEL_IDLE_RATE := 0.03
const FUEL_DRIVE_RATE := 0.22

@export var max_speed := 30.0
@export var acceleration := 24.0
@export var friction := 22.0
@export var turn_speed := 4.8

var driver: Node3D = null
var net_id := 0
var net_puppet := false
var model := ""
var cargo := 0
# 燃油：负数表示未初始化（_ready 时按油箱 30~80% 随机）
var fuel := -1.0
# 车辆血量：被怪物/玩家攻击掉血，到 0 爆炸报废
var hp := 0
var max_hp := 0
var destroyed := false
# 委派驾驶员（Tab 载具面板）：委派后成为玩家的车，可远程指挥自动驾驶
var owned := false
var pilot_name := ""
# 驾驶员随从实体（FollowerBody）：在车上随车移动/隐藏，J 面板保留栏位显示「驾驶中」
var pilot: Node3D = null
# 自动驾驶目标（ZERO = 待命）；由载具面板「开往地图标点 / 召回身边」设置
var auto_target := Vector3.ZERO
# 坦克炮塔（可旋转）与开火冷却
var _turret: Node3D = null
# 当前视觉模型（击毁版换壳用）与实际使用的模型路径（查击毁版）
var _visual_root: Node3D = null
var _visual_path := ""
var _tank_fire_cd := 0.0

var _speed := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_timer := 0.0
var _full_notify_msec := 0
var _fuel_warn_msec := 0
# 车头灯开关（夜间自动点亮）：只做判定圈，不设真实光源
var headlights_on := false


func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("interactables")
	_build_visual()
	max_hp = int(VEHICLE_HP.get(model, 1000))
	hp = max_hp
	if fuel < 0.0:
		fuel = tank_cap() * randf_range(0.3, 0.8)
	_net_pos = global_position
	_net_yaw = rotation.y
	if Network.is_multiplayer():
		Network.vehicle_state.connect(_on_vehicle_state)
		Network.vehicle_claim_denied.connect(_on_claim_denied)


# 认领被主机拒绝（车已有主）：本地先上的车被踢下
func _on_claim_denied(id: int) -> void:
	if id != net_id:
		return
	if driver != null and driver.has_method("exit_vehicle"):
		GameState.notify("这辆车已经有人了")
		driver.exit_vehicle()


func _on_vehicle_state(id: int, pos: Vector3, yaw: float) -> void:
	if id != net_id:
		return
	_net_pos = pos
	_net_yaw = yaw


func _is_puppet() -> bool:
	if not Network.is_multiplayer():
		return false
	var owner := Network.vehicle_owner(net_id)
	return owner != 0 and owner != Network.my_id()


func _build_visual() -> void:
	model = CAR_MODELS[absi(net_id) % CAR_MODELS.size()]
	var car_path := String(CAR_MODEL_PATHS.get(model, ""))
	# APC 用一号/二号两套皮肤随机
	if model == "apc" and randf() < 0.5:
		car_path = APC_ALT_PATH
	var packed: PackedScene = load(car_path) if not car_path.is_empty() else null
	if packed != null:
		var visual: Node3D = packed.instantiate()
		# Synty 预制体自带碰撞体：车辆物理由本脚本 CharacterBody3D 负责，剥掉
		for static_body in visual.find_children("*", "StaticBody3D", true, false):
			static_body.free()
		add_child(visual)
		var aabb := _combined_aabb(visual)
		if aabb.size.x > 0.01:
			var factor := CAR_WIDTH / aabb.size.x
			visual.scale = Vector3.ONE * factor
			visual.position = Vector3(0.0, -aabb.position.y * factor, 0.0)
			_visual_root = visual
			_visual_path = car_path
			# 坦克：把模型自带炮塔节点接进瞄准系统（批次 182 换真模型）
			if model == "tank":
				var turret_nodes := visual.find_children(
					"SM_Veh_Tank_USA_Turret_01", "Node3D", true, false
				)
				if turret_nodes.size() > 0:
					_turret = turret_nodes[0]
			return
		visual.queue_free()
	# 模型加载失败的手搓后备：坦克用旧手搓外观，其余给个盒子
	if model == "tank":
		_build_tank_visual()
		return
	var body_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.9, 4.2)
	body_mesh.mesh = box
	body_mesh.position = Vector3(0, 0.55, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.25, 0.22)
	body_mesh.material_override = material
	add_child(body_mesh)


# 坦克外观（程序生成）：车体 + 履带 + 可旋转炮塔 + 炮管
func _build_tank_visual() -> void:
	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(2.4, 0.9, 4.4)
	body.mesh = body_box
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.32, 0.36, 0.28)
	body.material_override = body_mat
	body.position = Vector3(0, 0.55, 0)
	add_child(body)
	for side in [-1.0, 1.0]:
		var tread := MeshInstance3D.new()
		var tread_box := BoxMesh.new()
		tread_box.size = Vector3(0.5, 0.7, 4.6)
		tread.mesh = tread_box
		var tread_mat := StandardMaterial3D.new()
		tread_mat.albedo_color = Color(0.2, 0.2, 0.2)
		tread.material_override = tread_mat
		tread.position = Vector3(side * 1.3, 0.35, 0)
		add_child(tread)
	# 炮塔（可随鼠标旋转）
	_turret = Node3D.new()
	_turret.position = Vector3(0, 1.15, -0.3)
	add_child(_turret)
	var turret_mesh := MeshInstance3D.new()
	var turret_box := BoxMesh.new()
	turret_box.size = Vector3(1.4, 0.6, 1.8)
	turret_mesh.mesh = turret_box
	var turret_mat := StandardMaterial3D.new()
	turret_mat.albedo_color = Color(0.38, 0.42, 0.3)
	turret_mesh.material_override = turret_mat
	_turret.add_child(turret_mesh)
	var barrel := MeshInstance3D.new()
	var barrel_box := BoxMesh.new()
	barrel_box.size = Vector3(0.16, 0.16, 2.2)
	barrel.mesh = barrel_box
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.24, 0.27, 0.24)
	barrel.material_override = barrel_mat
	barrel.position = Vector3(0, 0.1, -1.9)
	_turret.add_child(barrel)


func _vehicle_name() -> String:
	match model:
		"tank":
			return "坦克"
		"light_tank":
			return "轻型坦克"
		"apc":
			return "装甲运兵车"
		"apc_heavy":
			return "重型装甲车"
		"armored_car":
			return "装甲侦察车"
		"technical":
			return "武装皮卡"
		"rocket_truck":
			return "火箭卡车"
		"radar_tank":
			return "雷达车"
	if int(VEHICLE_HP.get(model, 1000)) >= 5000:
		return "集装箱车"
	return "轿车"


# 车辆受击：被怪物（驾驶时由玩家 take_damage 转入）或玩家子弹/近战打掉血
func take_damage(amount: int, _from: Node3D = null) -> void:
	if destroyed:
		return
	hp -= amount
	if hp <= 0:
		_explode()


# 血量归零：弹出司机 + 范围爆炸 + 报废变灰
func _explode() -> void:
	if destroyed:
		return
	if owned and not pilot_name.is_empty():
		GameState.notify("驾驶员 %s 随车阵亡……" % pilot_name)
		var dead_pilot = pilot
		_pilot_gone()
		if dead_pilot != null and is_instance_valid(dead_pilot):
			var mgr = dead_pilot.get("manager")
			if mgr != null and mgr.has_method("_forget_follower"):
				mgr.call("_forget_follower", dead_pilot)
			dead_pilot.queue_free()
	destroyed = true
	if driver != null and driver.has_method("exit_vehicle"):
		driver.exit_vehicle()
	var exp_scene := load("res://scenes3d/explosive3d.tscn")
	var blast = exp_scene.instantiate()
	get_parent().add_child(blast)
	blast.setup(
		global_position + Vector3(0, 0.5, 0), Vector3.UP, 150, 7.0, true, self,
		0.0, true, Color(1.0, 0.4, 0.1, 0.6), true
	)
	GameState.noise_at(global_position, 30.0)
	# 军用车换官方击毁版模型；民用车沿用整体变灰
	var wreck_path := String(DESTROYED_MODELS.get(_visual_path, ""))
	var wreck_packed: PackedScene = load(wreck_path) if not wreck_path.is_empty() else null
	if wreck_packed != null and _visual_root != null and is_instance_valid(_visual_root):
		var wreck_scale := _visual_root.scale
		var wreck_pos := _visual_root.position
		_visual_root.queue_free()
		_visual_root = null
		_turret = null
		var wreck: Node3D = wreck_packed.instantiate()
		for static_body in wreck.find_children("*", "StaticBody3D", true, false):
			static_body.free()
		add_child(wreck)
		wreck.scale = wreck_scale
		wreck.position = wreck_pos
		_visual_root = wreck
	else:
		for mesh in find_children("*", "MeshInstance3D", true, false):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.22, 0.22, 0.22)
			mesh.material_override = mat
	GameState.notify("%s 被打爆了！" % _vehicle_name())


# 坦克瞄准点：司机相机射线与地面求交（驾驶时玩家 _update_aim 不运行，须自行计算）
func _tank_aim_point() -> Vector3:
	var fallback := global_position - global_transform.basis.z * 12.0
	var camera = driver.get("camera") if driver != null else null
	if not (camera is Camera3D):
		return fallback
	var mouse := get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var normal: Vector3 = camera.project_ray_normal(mouse)
	if absf(normal.y) < 0.001:
		return fallback
	var ground_t: float = (global_position.y - origin.y) / normal.y
	if ground_t <= 0.0:
		return fallback
	return origin + normal * ground_t


# 坦克主炮：发射等同火箭炮威力的炮弹（explosive3d 火箭弹）
func _tank_fire_cannon(aim_point: Vector3) -> void:
	var from := global_position + Vector3(0, 1.5, 0)
	var dir := aim_point - from
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -global_transform.basis.z
	dir = dir.normalized()
	var shell = load("res://scenes3d/explosive3d.tscn").instantiate()
	get_parent().add_child(shell)
	shell.setup(
		from, dir, TANK_CANNON_DAMAGE, TANK_CANNON_RADIUS, true, self,
		from.distance_to(aim_point), false, Color(1.0, 0.5, 0.2, 0.5), true
	)
	GameState.noise_at(global_position, 22.0)


# 坦克机枪：发射等同重机枪威力的子弹（bullet3d，shooter=自身避免打到自己）
func _tank_fire_mg(aim_point: Vector3) -> void:
	var from := global_position + Vector3(0, 1.5, 0)
	var dir := aim_point - from
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -global_transform.basis.z
	dir = dir.normalized()
	var bullet = load("res://scenes3d/bullet3d.tscn").instantiate()
	get_parent().add_child(bullet)
	bullet.setup(from, dir, TANK_MG_DAMAGE, self, true, 0, 0.0, [], 999.0)
	GameState.noise_at(global_position, 12.0)


# 坦克驾驶态：炮塔随鼠标旋转，左键主炮、右键机枪
func _tick_tank(delta: float) -> void:
	if model != "tank" or destroyed:
		return
	_tank_fire_cd -= delta
	var aim_point := _tank_aim_point()
	if _turret != null:
		var to_aim := aim_point - _turret.global_position
		to_aim.y = 0.0
		if to_aim.length() > 0.3:
			var target_yaw := atan2(-to_aim.x, -to_aim.z)
			_turret.global_rotation.y = lerp_angle(
				_turret.global_rotation.y, target_yaw, minf(1.0, delta * 8.0)
			)
	if GameState.attack_blocked_by_ui():
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _tank_fire_cd <= 0.0:
		_tank_fire_cd = TANK_CANNON_CD
		_tank_fire_cannon(aim_point)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _tank_fire_cd <= 0.0:
		_tank_fire_cd = TANK_MG_CD
		_tank_fire_mg(aim_point)


func _combined_aabb(root: Node3D) -> AABB:
	var boxes: Array = []
	_collect_aabbs(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var result: AABB = boxes[0]
	for i in range(1, boxes.size()):
		result = result.merge(boxes[i])
	return result


func _collect_aabbs(node: Node, xform: Transform3D, boxes: Array) -> void:
	if node is Node3D:
		xform = xform * node.transform
		if node is MeshInstance3D and node.mesh != null:
			boxes.append(xform * node.get_aabb())
	for child in node.get_children():
		_collect_aabbs(child, xform, boxes)


func _physics_process(delta: float) -> void:
	if _is_puppet():
		global_position = global_position.lerp(_net_pos, minf(1.0, delta * 8.0))
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 8.0))
		return
	if destroyed:
		# 报废车辆：不再驾驶/碾压/吸附建材
		return
	_auto_refuel(delta)
	if driver != null:
		_drive(delta)
		_tick_tank(delta)
		if Network.is_multiplayer() and Network.vehicle_owner(net_id) == Network.my_id():
			_net_timer -= delta
			if _net_timer <= 0.0:
				_net_timer = 0.066
				Network.broadcast_vehicle_state(net_id, global_position, rotation.y)
	elif owned and not pilot_name.is_empty() and auto_target != Vector3.ZERO:
		# 委派驾驶员的玩家车：远程指挥自动驾驶
		_autopilot(delta)
	else:
		_speed = move_toward(_speed, 0.0, friction * delta)
		_apply_speed()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_ram_check()
	_collect_material_piles()
	_deposit_timer -= delta
	if _deposit_timer <= 0.0:
		_deposit_timer = 0.5
		_auto_deposit_cargo()


# 车斗建材在据点半径内自动入仓（无需按 U）
func _auto_deposit_cargo() -> void:
	if cargo <= 0 or not _in_home_base_range():
		return
	var stored := GameState.add_materials_to_base(cargo)
	if stored <= 0:
		return
	cargo -= stored
	GameState.notify("建材自动入仓 +%d（车斗剩余 %d）" % [stored, cargo])


func _drive(delta: float) -> void:
	consume_fuel(delta)
	# 车辆自身坐标系：W 前进（车头方向）/ S 倒车 / A D 转向
	if driver != null and driver.has_method("drive_input"):
		var input: Vector2 = driver.drive_input()
		var steer := input.x
		var throttle := input.y
		var target := 0.0
		if absf(throttle) > 0.1:
			target = max_speed * throttle
		if fuel <= 0.0:
			target = 0.0
			_notify_no_fuel()
		var rate := acceleration if absf(target) > absf(_speed) else friction
		_speed = move_toward(_speed, target, rate * delta)
		var direction := 1.0 if _speed >= 0.0 else -1.0
		var turn_factor := clampf(absf(_speed) / max_speed, 0.25, 1.0)
		rotate_y(-steer * turn_speed * turn_factor * delta * direction)
		_apply_speed()
		return
	var throttle := Input.get_axis("move_down", "move_up")
	var steer := Input.get_axis("move_left", "move_right")
	var target := 0.0
	if throttle > 0.0:
		target = max_speed * throttle
	elif throttle < 0.0:
		target = (max_speed * 0.45) * throttle
	if fuel <= 0.0:
		target = 0.0
		_notify_no_fuel()
	var rate := acceleration if absf(target) > 0.0 else friction
	_speed = move_toward(_speed, target, rate * delta)
	var direction := 1.0 if _speed >= 0.0 else -1.0
	var turn_factor := clampf(absf(_speed) / max_speed, 0.25, 1.0)
	rotate_y(-steer * turn_speed * turn_factor * delta * direction)
	_apply_speed()


# —— 委派驾驶员与远程指挥（Tab 载具面板） ——

# 委派一名随从当驾驶员：车成为玩家的车（面板显示/可远程指挥）
func assign_pilot(fname: String, pilot_node: Node3D = null) -> void:
	owned = true
	pilot_name = fname
	pilot = pilot_node
	auto_target = Vector3.ZERO
	GameState.notify("%s 已委派为 %s 的驾驶员" % [fname, _vehicle_name()])


# 驾驶员下车：恢复随从（可见/回 npcs 组/转跟随），车失去归属与指令
func dismiss_pilot() -> void:
	if pilot == null or not is_instance_valid(pilot):
		_pilot_gone()
		return
	GameState.notify("%s 从 %s 下来，重新归队" % [pilot_name, _vehicle_name()])
	pilot.set("mode", "follow")
	pilot.set("vehicle_ref", null)
	pilot.visible = true
	pilot.add_to_group("npcs")
	_pilot_gone()


# 驾驶员离开（下车/阵亡/解散）：只清车侧引用，不动随从实体
func _pilot_gone() -> void:
	pilot = null
	pilot_name = ""
	owned = false
	auto_target = Vector3.ZERO


# 远程指挥：设置自动驾驶目标（开往标点 / 召回身边）
func command_to(target: Vector3) -> void:
	if not owned or pilot_name.is_empty():
		GameState.notify("先在载具面板给这辆车委派驾驶员")
		return
	if destroyed:
		GameState.notify("这辆车已经报废了")
		return
	if fuel <= 0.0:
		GameState.notify("%s 没油了，先去加油" % _vehicle_name())
		return
	auto_target = target


# 自动驾驶：朝目标转向 + 全油门，到达即停；油尽/报废由上层分支拦住
func _autopilot(delta: float) -> void:
	consume_fuel(delta)
	if fuel <= 0.0:
		_notify_no_fuel()
		_speed = move_toward(_speed, 0.0, friction * delta)
		_apply_speed()
		return
	var to := auto_target - global_position
	to.y = 0.0
	if to.length() <= ARRIVE_DIST:
		auto_target = Vector3.ZERO
		_speed = 0.0
		_apply_speed()
		GameState.notify("%s（%s 驾驶）已到达目的地" % [_vehicle_name(), pilot_name])
		return
	var want_yaw := atan2(to.x, to.z)
	var diff := wrapf(want_yaw - rotation.y, -PI, PI)
	_speed = move_toward(_speed, max_speed * 0.7, acceleration * delta)
	var turn_factor := clampf(absf(_speed) / max_speed, 0.25, 1.0)
	# 绕 y 正方向旋转使 yaw（atan2(forward.x, forward.z)）增大；diff>0 需 yaw 增大
	rotate_y(clampf(diff * 2.0, -1.0, 1.0) * turn_speed * turn_factor * delta)
	_apply_speed()


# —— 燃油：怠速微耗 + 按车速比例消耗；油尽断油，加油站油泵补给 ——
# 自动补给（批次 153）：停到加油站油泵/营地油库旁自动免费加油；
# 玩家背包有燃料时也自动注入（每次 1 单位 = 10 升）
const AUTO_REFUEL_REACH := 4.0
const AUTO_REFUEL_TICK := 0.5
const AUTO_REFUEL_LITERS := 20.0
const CAN_LITERS := 10.0

var _auto_refuel_tick := 0.0
var _auto_refuel_notified := false


func _auto_refuel(delta: float) -> void:
	_auto_refuel_tick -= delta
	if _auto_refuel_tick > 0.0:
		return
	_auto_refuel_tick = AUTO_REFUEL_TICK
	if fuel >= tank_cap() - 0.05:
		if _auto_refuel_notified:
			_auto_refuel_notified = false
			GameState.notify("油箱已满（%d 升）" % int(tank_cap()))
		return
	# 1) 加油站油泵旁（4m 内）→ 免费涓流加油
	var near_supply := false
	for st in get_tree().get_nodes_in_group("fuel_stations"):
		if is_instance_valid(st) and global_position.distance_to(st.global_position) <= AUTO_REFUEL_REACH:
			near_supply = true
			break
	# 2) 营地油库（据点半径内）→ 免费涓流加油
	if not near_supply and GameState.has_home_base():
		var home_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
		var flat := Vector2(global_position.x - home_pos.x, global_position.z - home_pos.z)
		if flat.length() <= GameState.home_base_radius():
			near_supply = true
	if near_supply:
		fuel = minf(tank_cap(), fuel + AUTO_REFUEL_LITERS)
		if not _auto_refuel_notified:
			_auto_refuel_notified = true
			GameState.notify("自动加油中…")
		return
	# 3) 玩家背包燃料：玩家在车内或车旁 4m 内时自动注入（1 单位 = 10 升）
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var near_player := (
		driver != null
		or global_position.distance_to(player.global_position) <= AUTO_REFUEL_REACH
	)
	if not near_player:
		return
	if int(GameState.resources.get("fuel", 0)) <= 0:
		return
	GameState.resources["fuel"] = int(GameState.resources["fuel"]) - 1
	GameState.resources_changed.emit()
	fuel = minf(tank_cap(), fuel + CAN_LITERS)
	if not _auto_refuel_notified:
		_auto_refuel_notified = true
		GameState.notify("用背包燃料自动加油…")


func tank_cap() -> float:
	return float(FUEL_TANK.get(model, 55.0))


func fuel_type() -> String:
	return String(FUEL_TYPE_BY_MODEL.get(model, "petrol"))


func fuel_type_name() -> String:
	return String(FUEL_TYPES.get(fuel_type(), "汽油"))


func fuel_price() -> int:
	return int(FUEL_PRICE.get(fuel_type(), 3))


func fuel_ratio() -> float:
	return clampf(fuel / maxf(1.0, tank_cap()), 0.0, 1.0)


func consume_fuel(delta: float) -> void:
	fuel = maxf(0.0, fuel - (FUEL_IDLE_RATE + FUEL_DRIVE_RATE * absf(_speed) / max_speed) * delta)


# 加油，返回实际加入的升数
func refuel(amount: float) -> float:
	var added := minf(amount, tank_cap() - fuel)
	if added <= 0.0:
		return 0.0
	fuel += added
	return added


func _notify_no_fuel() -> void:
	var now := Time.get_ticks_msec()
	if now < _fuel_warn_msec:
		return
	_fuel_warn_msec = now + 3000
	GameState.notify("燃油耗尽！把车开到加油站用油泵加油")


func _apply_speed() -> void:
	var forward := global_transform.basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed


const RAM_MIN_SPEED := 4.0
const RAM_HIT_COOLDOWN_MSEC := 600

var _ram_cooldowns := {}
# 车斗建材自动入仓计时
var _deposit_timer := 0.0


func _ram_check() -> void:
	var speed := absf(_speed)
	if speed < RAM_MIN_SPEED:
		return
	var now := Time.get_ticks_msec()
	var damage := int(clampf(speed / max_speed, 0.3, 1.2) * 150.0)
	var hit := false
	for zombie in GameState.entities_in_group_in_radius(global_position, "zombies", 3.0):
		if zombie.is_queued_for_deletion() or _ram_on_cooldown(zombie, now):
			continue
		hit = true
		zombie.take_damage(damage)
		var push: Vector3 = zombie.global_position - global_position
		push.y = 0.0
		if push.length() > 0.1:
			zombie.velocity += push.normalized() * (4.0 + speed * 0.3)
	for npc in GameState.entities_in_group_in_radius(global_position, "npcs", 3.0):
		if npc.is_queued_for_deletion() or _ram_on_cooldown(npc, now):
			continue
		hit = true
		npc.take_damage(damage, driver)
	if hit:
		_speed = move_toward(_speed, 0.0, speed * 0.15)


func _ram_on_cooldown(target: Node, now: int) -> bool:
	var id := target.get_instance_id()
	if now < int(_ram_cooldowns.get(id, 0)):
		return true
	_ram_cooldowns[id] = now + RAM_HIT_COOLDOWN_MSEC
	return false


func cargo_cap() -> int:
	return GameState.vehicle_cargo_cap(model)


# 建材磁吸装车：8m 内建材堆飞向车辆，2.5m 内自动装入车斗（测试模式无视容量上限）
func _collect_material_piles() -> void:
	for pile in get_tree().get_nodes_in_group("material_piles"):
		if pile.is_queued_for_deletion():
			continue
		var dist := global_position.distance_to(pile.global_position)
		if dist > PILE_MAGNET_RADIUS:
			continue
		var cap := cargo_cap()
		if not GameState.test_mode and cargo >= cap:
			if dist <= PILE_REACH:
				_notify_cargo_full()
			continue
		if dist > PILE_REACH:
			# 磁吸：建材堆飞向车辆
			pile.global_position = pile.global_position.move_toward(
				Vector3(global_position.x, pile.global_position.y, global_position.z),
				PILE_MAGNET_SPEED * get_physics_process_delta_time()
			)
			continue
		var take: int = pile.amount if GameState.test_mode else mini(pile.amount, cap - cargo)
		if take <= 0:
			continue
		cargo += take
		pile.queue_free()
		GameState.notify("装载建材 +%d（车斗 %d/%d）" % [take, cargo, cap])


func _notify_cargo_full() -> void:
	var now := Time.get_ticks_msec()
	if now < _full_notify_msec:
		return
	_full_notify_msec = now + 2000
	GameState.notify("车斗已满（%d/%d）" % [cargo, cargo_cap()])


func _unhandled_input(event: InputEvent) -> void:
	if driver == null or _is_puppet():
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_U
	):
		_unload_cargo()


# U 卸货：据点半径内入仓库，否则在车尾落下建材堆
func _unload_cargo() -> void:
	if cargo <= 0:
		GameState.notify("车斗是空的")
		return
	if _in_home_base_range():
		var stored := GameState.add_materials_to_base(cargo)
		if stored > 0:
			GameState.notify("建材已入据点仓库 +%d" % stored)
		cargo -= stored
		if cargo <= 0:
			return
		GameState.notify("仓库已满，剩余建材卸在车尾")
	else:
		GameState.notify("卸下建材 ×%d" % cargo)
	_drop_cargo_pile(cargo)
	cargo = 0


func _in_home_base_range() -> bool:
	if not GameState.has_home_base():
		return false
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	var flat := Vector2(global_position.x, global_position.z) - Vector2(base_pos.x, base_pos.z)
	return flat.length() <= GameState.home_base_radius()


func _drop_cargo_pile(p_amount: int) -> void:
	var pile: Node3D = MATERIAL_PILE_SCENE.instantiate()
	pile.setup(p_amount)
	get_parent().add_child(pile)
	pile.global_position = global_position - global_transform.basis.z * 3.0


func prompt_text() -> String:
	return ""


# —— 统一交互菜单协议：上车（单选项直接执行）——

func interact_title() -> String:
	return "载具"


func interact_options(player: Node3D) -> Array:
	if driver != null or _is_puppet():
		return []
	if player == null or global_position.distance_to(player.global_position) >= 3.5:
		return []
	var options: Array = [{"id": "board", "label": "上车"}]
	var carry := int(GameState.resources.get("fuel", 0))
	var cap := int(GameState.CAPS.get("fuel", 60))
	# 抽油：把这辆车油箱里的油抽进背包（升）
	var siphon := mini(int(fuel), cap - carry)
	options.append({
		"id": "siphon",
		"label": "抽油到背包（可抽 %d 升）" % siphon,
		"disabled": siphon <= 0,
		"reason": "油箱是空的" if fuel < 1.0 else "背包燃料已满",
	})
	# 加油：把背包里的燃料倒进这辆车油箱
	var pour := mini(carry, int(tank_cap() - fuel))
	options.append({
		"id": "pour",
		"label": "用携带燃料加油（可加 %d 升，背包 %d 升）" % [pour, carry],
		"disabled": pour <= 0,
		"reason": "背包没有燃料" if carry <= 0 else "油箱已满",
	})
	return options


func interact_choose(id: String, player: Node3D) -> void:
	match id:
		"board":
			if player != null and driver == null:
				player.enter_vehicle(self)
		"siphon":
			var cap := int(GameState.CAPS.get("fuel", 60))
			var take := mini(int(fuel), cap - int(GameState.resources.get("fuel", 0)))
			if take <= 0:
				return
			fuel -= take
			GameState.add_resource("fuel", take)
			GameState.notify("从车上抽出 %d 升燃料（背包 %d/%d）" % [
				take, int(GameState.resources.get("fuel", 0)), cap,
			])
		"pour":
			var pour := mini(
				int(GameState.resources.get("fuel", 0)), int(tank_cap() - fuel)
			)
			if pour <= 0:
				return
			GameState.resources["fuel"] = int(GameState.resources["fuel"]) - pour
			GameState.resources_changed.emit()
			fuel += pour
			GameState.notify("给车加了 %d 升%s（油箱 %d%%）" % [
				pour, fuel_type_name(), int(fuel_ratio() * 100.0),
			])


func _process(_delta: float) -> void:
	headlights_on = GameState.is_night()


func enter(player: Node3D) -> void:
	driver = player
	if Network.is_multiplayer():
		Network.claim_vehicle(net_id, Network.my_id())


func leave() -> void:
	driver = null
	_speed = 0.0
	if Network.is_multiplayer():
		Network.claim_vehicle(net_id, 0)
