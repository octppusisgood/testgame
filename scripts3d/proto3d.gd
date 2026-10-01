extends Node3D

const SCALE := 0.05
const PLAYER_SCENE := preload("res://scenes3d/fps_player.tscn")
const NPC_SCENE := preload("res://scenes3d/npc3d.tscn")
const ZOMBIE_SCENE := preload("res://scenes3d/zombie3d.tscn")
const VEHICLE_SCENE := preload("res://scenes3d/vehicle3d.tscn")
const STATION_SCRIPT := preload("res://scripts3d/station3d.gd")
const GAS_PUMP_SCRIPT := preload("res://scripts3d/gas_pump3d.gd")
const MATERIAL_PILE_SCENE := preload("res://scenes3d/material_pile3d.tscn")
const PICKUP_SCENE := preload("res://scenes3d/pickup3d.tscn")
# Synty 素材：模型城市全部使用 PolygonCity / PolygonApocalypse 的预制体
const CITY_BLD := "res://assets/Synty/PolygonCity/Prefabs/Buildings/"
const APOCO_BLD := "res://assets/Synty/PolygonApocalypse/Prefabs/Buildings/"
const CITY_PROP := "res://assets/Synty/PolygonCity/Prefabs/Props/"
const APOCO_PROP := "res://assets/Synty/PolygonApocalypse/Prefabs/Props/"
const SHOPS_BLD := "res://assets/Synty/PolygonShops/Prefabs/Buildings/"
const MIL_BLD := "res://assets/Synty/PolygonMilitary/Prefabs/Buildings/"
const SKYSCRAPER_MODELS := [
	CITY_BLD + "SM_Bld_OfficeOctagon_01.tscn",
	CITY_BLD + "SM_Bld_OfficeRound_01.tscn",
	CITY_BLD + "SM_Bld_OfficeRound_02.tscn",
	CITY_BLD + "SM_Bld_OfficeRound_03.tscn",
	CITY_BLD + "SM_Bld_OfficeRound_04.tscn",
	CITY_BLD + "SM_Bld_OfficeSquare_01.tscn",
	CITY_BLD + "SM_Bld_OfficeSquare_02.tscn",
	CITY_BLD + "SM_Bld_OfficeSquare_03.tscn",
	CITY_BLD + "SM_Bld_OfficeSquare_04.tscn",
	CITY_BLD + "SM_Bld_OfficeOld_Large_01.tscn",
	CITY_BLD + "SM_Bld_OfficeOld_Large_02.tscn",
	CITY_BLD + "SM_Bld_Spire_01.tscn",
]
const COMMERCIAL_MODELS := [
	APOCO_BLD + "SM_Bld_Commercial_Large_01.tscn",
	APOCO_BLD + "SM_Bld_Commercial_Medium_01.tscn",
	APOCO_BLD + "SM_Bld_Commercial_Small_01.tscn",
	APOCO_BLD + "SM_Bld_Shop_Large_01.tscn",
	APOCO_BLD + "SM_Bld_Shop_Large_02.tscn",
	APOCO_BLD + "SM_Bld_Shop_Medium_01.tscn",
	APOCO_BLD + "SM_Bld_Shop_Medium_02.tscn",
	APOCO_BLD + "SM_Bld_Shop_Small_01.tscn",
	APOCO_BLD + "SM_Bld_Shop_Small_02.tscn",
	APOCO_BLD + "SM_Bld_Shop_Small_03.tscn",
	APOCO_BLD + "SM_Bld_Market_Large_01.tscn",
	APOCO_BLD + "SM_Bld_Market_Medium_01.tscn",
	APOCO_BLD + "SM_Bld_Motel_01.tscn",
	APOCO_BLD + "SM_Bld_Diner_01.tscn",
	APOCO_BLD + "SM_Bld_Cafe_01.tscn",
	APOCO_BLD + "SM_Bld_AutoRepair_01.tscn",
	APOCO_BLD + "SM_Bld_Church_01.tscn",
	CITY_BLD + "SM_Bld_Shop_01.tscn",
	CITY_BLD + "SM_Bld_Shop_02.tscn",
	CITY_BLD + "SM_Bld_Shop_03.tscn",
	CITY_BLD + "SM_Bld_Shop_04.tscn",
	CITY_BLD + "SM_Bld_Shop_05.tscn",
	CITY_BLD + "SM_Bld_Shop_06.tscn",
	CITY_BLD + "SM_Bld_Shop_Corner_01.tscn",
	CITY_BLD + "SM_Bld_Shop_Corner_02.tscn",
	CITY_BLD + "SM_Bld_Station_01.tscn",
	CITY_BLD + "SM_Bld_Station_02.tscn",
	CITY_BLD + "SM_Bld_Station_03.tscn",
	# 批次 37：PolygonShops 里唯一实测完整的店面（其余 ShopFront 是进深 <1.5m 的立面片）
	SHOPS_BLD + "SM_Bld_ShopFront_05.tscn",
]
# 批次 37：五分类模型池——只收完整建筑（命名过滤 + 探针实测 AABB 双重校验）。
# 注：Apocalypse HighRise_*_Base/Stack 是高层拼接段（宽 26~29m、高仅 5~6m），
# 独栋缩放后呈薄片，不收入；Apartment_01~03 是单层模块，改用三层 Apartment_Stack。
const DOWNTOWN_MODELS := SKYSCRAPER_MODELS + [
	CITY_BLD + "SM_Bld_OfficeOld_Small_01.tscn",
	CITY_BLD + "SM_Bld_OfficeOld_Small_02.tscn",
	CITY_BLD + "SM_Bld_Apartment_Stack_01.tscn",
	CITY_BLD + "SM_Bld_Apartment_Stack_02.tscn",
	CITY_BLD + "SM_Bld_Apartment_Stack_03.tscn",
	CITY_BLD + "SM_Bld_CityHall_01.tscn",
]
const RESIDENTIAL_MODELS := [
	APOCO_BLD + "SM_Bld_House_01.tscn",
	APOCO_BLD + "SM_Bld_House_02.tscn",
	APOCO_BLD + "SM_Bld_House_03.tscn",
	APOCO_BLD + "SM_Bld_House_Burnt_01.tscn",
	APOCO_BLD + "SM_Bld_Trailer_01.tscn",
	APOCO_BLD + "SM_Bld_Trailer_02.tscn",
	APOCO_BLD + "SM_Bld_Junk_Shelter_01.tscn",
	APOCO_BLD + "SM_Bld_Junk_Shelter_02.tscn",
	APOCO_BLD + "SM_Bld_Junk_Shelter_03.tscn",
	APOCO_BLD + "SM_Bld_Junk_Shelter_04.tscn",
	APOCO_BLD + "SM_Bld_Junk_Shelter_05.tscn",
	APOCO_BLD + "SM_Bld_Junk_Shelter_06.tscn",
]
# 工业区：厂房/仓储/配套塔罐（Warehouse 从 COMMERCIAL 移入此处）
const INDUSTRIAL_MODELS := [
	APOCO_BLD + "SM_Bld_Warehouse_Brick_01.tscn",
	APOCO_BLD + "SM_Bld_Warehouse_Concrete_01.tscn",
	APOCO_BLD + "SM_Bld_Industrial_Large_01.tscn",
	APOCO_BLD + "SM_Bld_Industrial_Medium_01.tscn",
	APOCO_BLD + "SM_Bld_Industrial_Small_01.tscn",
	APOCO_BLD + "SM_Bld_Cooling_Tower_01.tscn",
	APOCO_BLD + "SM_Bld_Cooling_Tower_02.tscn",
	APOCO_BLD + "SM_Bld_SmokeStack_01.tscn",
	APOCO_BLD + "SM_Bld_WaterTower_01.tscn",
	APOCO_BLD + "SM_Bld_WaterTank_01.tscn",
]
# 军事前哨：均经探针确认文件存在且比例正常；
# CamoNet_Tent_06 实测是 0.47m 高的平面伪装网（按高度缩放会铺成 50m 巨网），不收入
const MILITARY_MODELS := [
	MIL_BLD + "SM_Bld_Barracks_01.tscn",
	MIL_BLD + "SM_Bld_CamoNet_Tent_01.tscn",
	MIL_BLD + "SM_Bld_CamoNet_Tent_02.tscn",
	MIL_BLD + "SM_Bld_CamoNet_Tent_03.tscn",
	MIL_BLD + "SM_Bld_CamoNet_Tent_04.tscn",
	MIL_BLD + "SM_Bld_CamoNet_Tent_05.tscn",
	MIL_BLD + "SM_Bld_ControlTower_01.tscn",
	MIL_BLD + "SM_Bld_Clock_Tower_01.tscn",
]
# 批次 38：手建地标 → SYNTY 模型映射（按功能挑最接近的楼；坐标/占地/物资表不变）。
# house 按栋号在 _landmark_model_path 里轮换 House_01~03
const LANDMARK_MODELS := {
	"food": APOCO_BLD + "SM_Bld_Market_Medium_01.tscn",
	"gun": APOCO_BLD + "SM_Bld_Shop_Medium_01.tscn",
	"hospital": CITY_BLD + "SM_Bld_CityHall_01.tscn",
	"bank": CITY_BLD + "SM_Bld_OfficeOld_Large_01.tscn",
	"police": CITY_BLD + "SM_Bld_Station_01.tscn",
	"prison": MIL_BLD + "SM_Bld_Barracks_01.tscn",
	"gas": MIL_BLD + "SM_Bld_GasStation_01.tscn",
	"power": APOCO_BLD + "SM_Bld_Industrial_Large_01.tscn",
	"military": MIL_BLD + "SM_Bld_Hangar_01.tscn",
}
const PROP_CLUTTER := [
	APOCO_PROP + "SM_Prop_Dumpster_01.tscn",
	APOCO_PROP + "SM_Prop_Dumpster_02.tscn",
	APOCO_PROP + "SM_Prop_TrashBag_01.tscn",
	APOCO_PROP + "SM_Prop_TrashBag_03.tscn",
	APOCO_PROP + "SM_Prop_TrashCan_01.tscn",
	APOCO_PROP + "SM_Prop_Cone_01.tscn",
	APOCO_PROP + "SM_Prop_Barrier_Plastic_01.tscn",
	APOCO_PROP + "SM_Prop_Barrel_Old_01.tscn",
	APOCO_PROP + "SM_Prop_Tire_Pile_01.tscn",
	APOCO_PROP + "SM_Prop_Crate_01.tscn",
]
const PROP_TRAFFIC := APOCO_PROP + "SM_Prop_TrafficLight_01.tscn"
# 街道家具：额外一批可拆的街道小物（路灯/垃圾桶/栏杆），收益与杂物同档
const PROP_STREET_FURNITURE := [
	APOCO_PROP + "SM_Prop_LightPole_01.tscn",
	APOCO_PROP + "SM_Prop_LightPole_01.tscn",
	CITY_PROP + "SM_Prop_Trashbin_01.tscn",
	CITY_PROP + "SM_Prop_Hydrant_01.tscn",
	CITY_PROP + "SM_Prop_Barrier_01.tscn",
]
const STREET_FURNITURE_COUNT := 30
# 批次 37：SYNTY 真实路面件（平铺在纯色路底之上，纯视觉无碰撞）
const APOCO_ENV := "res://assets/Synty/PolygonApocalypse/Prefabs/Environment/"
const ROAD_STRAIGHT_MODELS := [
	APOCO_ENV + "SM_Env_Road_01.tscn",
	APOCO_ENV + "SM_Env_Road_02.tscn",
	APOCO_ENV + "SM_Env_Road_03.tscn",
	APOCO_ENV + "SM_Env_Road_04.tscn",
]
const ROAD_CROSSING_MODELS := [
	APOCO_ENV + "SM_Env_Road_Crossing_01.tscn",
	APOCO_ENV + "SM_Env_Road_Crossing_02.tscn",
	APOCO_ENV + "SM_Env_Road_Crossing_03.tscn",
]
const ROAD_LINE_MODELS := [
	APOCO_ENV + "SM_Env_Road_Lines_01.tscn",
	APOCO_ENV + "SM_Env_Road_Lines_02.tscn",
]
# 路面件实测 5x5（_combined_aabb 量得），沿长轴按 5m(100px) 步进平铺；
# 略高于 0.04 厚的纯色路底，避免 z-fighting
const ROAD_TILE_STEP_PX := 100.0
const ROAD_TILE_Y := 0.045
# 批次 37：模型建筑限宽——宽体模型（商场/厂房/冷却塔）按目标高度缩放后会溢出格位，
# 统一把占地宽钳在 15m(300px，格距 320px 留缝) 内，实际高度等比下调
const MODEL_MAX_FOOTPRINT := 15.0
# 批次 37(A4)：沿人行道成排摆放的 SYNTY 街具。
# 可拆子集：入 _street_props，走既有 _aim_prop/_demolish_prop（收益 2~5 不变）
const CITY_VEH := "res://assets/Synty/PolygonCity/Prefabs/Vehicles/"
const PROP_SIDEWALK_DEMOLISH := [
	APOCO_PROP + "SM_Prop_LightPole_01.tscn",
	CITY_PROP + "SM_Prop_Trashbin_01.tscn",
	CITY_PROP + "SM_Prop_Trashbin_02.tscn",
	CITY_PROP + "SM_Prop_Hydrant_01.tscn",
	APOCO_PROP + "SM_Prop_DustBin_01.tscn",
	CITY_PROP + "SM_Prop_ParkBench_01.tscn",
	CITY_PROP + "SM_Prop_Mailbox_01.tscn",
]
# 纯装饰子集：只建节点不入组（大件/招牌/停放车辆）
const PROP_SIDEWALK_DECOR := [
	CITY_PROP + "SM_Prop_BusStop_01.tscn",
	CITY_PROP + "SM_Prop_Phones_01.tscn",
	CITY_PROP + "SM_Prop_ATM_01.tscn",
	CITY_PROP + "SM_Prop_Planter_01.tscn",
	CITY_PROP + "SM_Prop_Planter_02.tscn",
	CITY_PROP + "SM_Prop_Sign_Stop_01.tscn",
	CITY_PROP + "SM_Prop_Sign_Street_01.tscn",
	CITY_VEH + "SM_Veh_Car_Sedan_01.tscn",
	CITY_VEH + "SM_Veh_Car_Taxi_01.tscn",
	CITY_VEH + "SM_Veh_Car_Small_01.tscn",
	CITY_VEH + "SM_Veh_Car_Van_01.tscn",
]

var _model_rects: Array = []
# 批次 37：_place_model 失败（跳过）的模型路径，供探针核对
var _model_failures: Array = []
# 批次 37：已铺路面件的水平投影（px），供探针抽样校验落在 ROADS 内
var _road_tile_rects: Array = []
var _road_piece_cache := {}
# 批次 37：路面瓦片变换按件型累积（合批 MultiMesh 用）：path -> Array[Transform3D]
var _road_mm := {}

const ZOMBIE_CAP := 240
const ZOMBIE_SPAWN_STEP := 0.6
const CITIZEN_COUNT := 400

var _zombie_timer := 0.0
var _boss_timer := 0.0
var _debug_hide_characters := false
var _hunter_timer := 20.0
# 肉鸽模式：准备倒计时
var _rogue_prep := 60.0
var _rogue_won := false
var _rogue_retarget_timer := 0.0
# 肉鸽顺序关卡（设计文档 4.1/4.2）：一次一个能量场+守关 Boss，拆场→发育期→下一关
# 关卡强度表：能量等级随关卡提升（能量 1/2/3 → 守关 Boss 尸王/尸皇/尸神，由能量点自身映射）
const ROGUE_STAGES := [
	{"energy": 1, "boss_name": "尸王", "dev_days": 3.0, "radius_min": 6.0, "radius_max": 8.0},
	{"energy": 2, "boss_name": "尸皇", "dev_days": 3.0, "radius_min": 8.0, "radius_max": 10.0},
	{"energy": 3, "boss_name": "尸神", "dev_days": 2.0, "radius_min": 10.0, "radius_max": 12.0},
]
var _rogue_stage := 0
var _rogue_phase := "prep"  # prep / active / dev / won
var _rogue_dev_timer := 0.0
var _rogue_zone: Node3D = null
# 肉鸽普通能量场：灾变后随机刷在营地附近，同时最多 3 个，尸群袭营（不强化）；
# 拆掉一个后 60 秒才会补生新的
const ROGUE_FIELD_CAP := 3
const ROGUE_FIELD_MIN_DIST := 20.0
const ROGUE_FIELD_MAX_DIST := 50.0
const ROGUE_FIELD_RESPAWN_DELAY := 60.0
var _rogue_field_timer := 15.0
var _last_field_count := 0
# 肉鸽新手提示：准备期按间隔逐条弹出核心规则（设计文档 2.3）
const ROGUE_HINTS := [
	"击杀不给经验：收益在掉落物，谁捡归谁，别忘了收经验球。",
	"每个能量点有守关 Boss，先击败 Boss 才能打爆核心。",
	"Boss 靠近营地会释放干扰磁场，沉默机枪塔与设备。",
	"撤离分档：回营地 ×150%，信号区跑路身上100%+营地50%，战斗中50%，死亡按信号 0~50%。",
]
const ROGUE_HINT_INTERVAL := 10.0
var _rogue_hint_index := 0
var _rogue_hint_timer := 5.0
# 肉鸽守关 Boss 干扰磁场：Boss 靠近营地时沉默范围内的机枪塔/设备（设计文档 5.2）
const BOSS_JAM_RADIUS := 18.0
const BOSS_JAM_INTERVAL := 0.5
var _boss_jam_timer := 0.0
var _boss_jam_notified := false

var _zombie_count := 0
var _zombie_count_timer := 0.0
var _god_spawned := false
var _sun: DirectionalLight3D
var _env: Environment
var _rain: GPUParticles3D
var _moon: MeshInstance3D
var _moon_material: StandardMaterial3D
# 据点夜袭：入夜瞬间从地图边缘刷一波直奔据点的丧尸
var _was_night := false
var _assault_active := false
var _assault_zombies: Array = []
var _assault_until_msec := 0
var _assault_batch_timer := 0.0
var _base_aggro_timer := 0.0
# 拆除玩法：BUILDING_LAYOUT 索引 -> 该建筑的全部节点；街道杂物节点列表
var _building_parts: Dictionary = {}
# 批次 34：模型城市建筑登记表（demolish3d 统一拆除/爆炸用），下标写入碰撞盒 demolish_model 元数据
var _model_structures: Array = []
# 批次 34：塔楼门口交互点登记（下标 = TOWERS 索引），塔楼坍塌时一并移除
var _tower_doors: Array = []
# 建筑遮挡轮廓（世界 xz 米制矩形 + 部件列表），供矩形相交式透视淡出用
var occl_buildings: Array = []
var _street_props: Array = []


func _ready() -> void:
	GameState.home_scene = "res://scenes3d/proto3d.tscn"
	GameState.reset_coverage()
	GameState.custom_outbreak = false
	GameState.custom_map_size = Vector2.ZERO
	# 建筑内部系统：进入建筑 = 传送到地下懒生成的内部房间（容量 20）
	var interiors := preload("res://scripts3d/building_interior3d.gd").new()
	add_child(interiors)
	if GameState.test_mode:
		_build_test_hint()
	_setup_environment()
	_build_weather()
	_build_light_rings()
	_build_ground()
	_build_roads()
	_build_buildings()
	_build_towers()
	_cache_building_collision_rects()
	_build_model_city()
	_build_street_props()
	_build_boundaries()
	_build_stations()
	_build_vehicles()
	if GameState.test_mode:
		_spawn_vehicle_showcase()
	_build_horde_renderer()
	_build_pickup_renderers()
	# 预热角色变体缓存：消灭战斗中首次刷出某变体时的同步加载顿卡
	BlockyRig.prewarm()
	if GameState.rogue_mode:
		_init_rogue_stages()
	else:
		_spawn_anomaly_crystals()
	if not _client_mode():
		_spawn_civilians()
		if GameState.rogue_mode:
			_spawn_rogue_civilians_indoors()
		# 通缉系统已彻底删除：不再生成警察（_spawn_cops 不再调用）
	_spawn_player()
	var base_build := Node3D.new()
	base_build.name = "BaseBuild"
	base_build.set_script(load("res://scripts3d/base_build3d.gd"))
	add_child(base_build)
	GameState.demolished_buildings.clear()
	GameState.demolished_towers.clear()
	var demolish := Node3D.new()
	demolish.name = "Demolish"
	demolish.set_script(load("res://scripts3d/demolish3d.gd"))
	add_child(demolish)
	var base_visual := Node3D.new()
	base_visual.name = "BaseVisual"
	base_visual.set_script(load("res://scripts3d/base_visual3d.gd"))
	add_child(base_visual)
	var net_players := Node3D.new()
	net_players.name = "NetPlayers"
	net_players.set_script(load("res://scripts3d/net_players3d.gd"))
	add_child(net_players)
	var net_entities := Node3D.new()
	net_entities.name = "NetEntities"
	net_entities.set_script(load("res://scripts3d/net_entities3d.gd"))
	add_child(net_entities)
	# 通缉系统已彻底删除：不再添加 PoliceDispatch（警察调度/警车刷新）
	var workers := Node3D.new()
	workers.name = "Workers"
	workers.set_script(load("res://scripts3d/worker3d.gd"))
	add_child(workers)
	# 系统空间雇佣的随从：必须在 workers 管理器就位后再生成
	# （此前在 _spawn_player 后就调用，管理器尚未创建 → 查找落空 → 静默不生成）
	_spawn_hired_npcs()
	if GameState.rogue_mode:
		# 肉鸽模式：直接进入灾变阶段（平民逃难/能量场活性都依赖它），1 分钟准备期由 _tick_rogue 管
		GameState.phase = "outbreak"
		GameState.phase_changed.emit("outbreak")
		GameState.rogue_prep_left = _rogue_prep
		GameState.notify("肉鸽模式：1 分钟准备，之后第 1 关能量场出现。逐关击败守关 Boss 并拆核心，通关第 %d 关即胜利！" % ROGUE_STAGES.size())


func _client_mode() -> bool:
	return Network.is_multiplayer() and not Network.is_server()



# —— NPC 池化：超 150m 的市民拆成轻量记录休眠，回到 130m 内重新激活 ——
# 活跃 NPC 数量从此只与玩家周边密度有关，总人口可以随便加（池外：随从/工人/感染者/恐慌者）

const NPC_POOL_RESPAWN := 130.0
const NPC_POOL_DESPAWN := 150.0
const NPC_POOL_INTERVAL := 0.5

var _dormant_npcs: Array = []
var _pool_timer := 0.0
# 建筑碰撞矩形（供丧尸 worker 移动推挤用，建城后缓存一次）
var _building_collision_rects: Array = []
# 矩形的 20m 格索引：Vector2i → 矩形下标数组，推挤只测附近的几个
var _building_rect_index := {}


func _cache_building_collision_rects() -> void:
	_building_collision_rects.clear()
	_building_rect_index.clear()
	var i := 0
	for entry in occl_buildings:
		# 缓存时预扩张怪半径，推挤时不再逐只 grow（省 ~1.8 万次/秒的重复分配）
		var rect: Rect2 = (entry["rect"] as Rect2).grow(0.35)
		_building_collision_rects.append({
			"rect": rect, "cx": rect.get_center().x,
		})
		var min_cell := Vector2i(
			floori(rect.position.x / 20.0), floori(rect.position.y / 20.0)
		)
		var max_cell := Vector2i(
			floori(rect.end.x / 20.0), floori(rect.end.y / 20.0)
		)
		for cx in range(min_cell.x, max_cell.x + 1):
			for cz in range(min_cell.y, max_cell.y + 1):
				var key := Vector2i(cx, cz)
				if not _building_rect_index.has(key):
					_building_rect_index[key] = []
				_building_rect_index[key].append(i)
		i += 1


# 建筑矩形推挤（纯数据，worker 线程也可调用）：穿透则沿最浅轴推出。
# 批次 38：楼体全部实心（无门洞），原"前墙门洞放行"分支删除。返回 [pos, edge]，edge：0 未穿透 / 1 沿 x / 2 沿 z
static func building_push_out(
	rects: Array, index: Dictionary, pos: Vector3, radius: float
) -> Array:
	var p := Vector2(pos.x, pos.z)
	var edge := 0
	var cc := Vector2i(floori(pos.x / 20.0), floori(pos.z / 20.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var ids: Array = index.get(cc + Vector2i(dx, dz), [])
			for id in ids:
				var e: Dictionary = rects[int(id)]
				var rect: Rect2 = e["rect"]
				if not rect.has_point(p):
					continue
				var dl: float = p.x - rect.position.x
				var dr: float = rect.end.x - p.x
				var dt: float = p.y - rect.position.y
				var db: float = rect.end.y - p.y
				var m := minf(minf(dl, dr), minf(dt, db))
				if m == dl:
					p.x = rect.position.x
					edge = 1
				elif m == dr:
					p.x = rect.end.x
					edge = 1
				elif m == dt:
					p.y = rect.position.y
					edge = 2
				else:
					p.y = rect.end.y
					edge = 2
	return [Vector3(p.x, pos.y, p.y), edge]


func _tick_npc_pool(delta: float) -> void:
	_pool_timer -= delta
	if _pool_timer > 0.0:
		return
	_pool_timer = NPC_POOL_INTERVAL
	if not GameState.viewer_active:
		return
	var viewer := GameState.viewer_position
	# 休眠：远离玩家且无战斗/转化状态的市民
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_queued_for_deletion() or npc.get("_dying") == true:
			continue
		if npc.is_in_group("followers") or npc.is_in_group("workers"):
			continue
		# 军营驻军不休眠：池化会丢掉特种兵等定制属性，且驻军是固定编制
		if npc.is_in_group("soldiers"):
			continue
		if npc.get("_panicked") == true:
			continue
		if npc.global_position.distance_to(viewer) <= NPC_POOL_DESPAWN:
			continue
		var role_value = npc.get("role")
		var hp_value = npc.get("hp")
		_dormant_npcs.append({
			"role": String(role_value) if role_value != null else "pedestrian",
			"pos": npc.global_position,
			"armed": npc.get("armed") == true,
			"hp": int(hp_value) if hp_value != null else 40,
			"anomaly": npc.has_meta("anomaly_touched"),
			"patrol_offset": npc.get("patrol_offset"),
		})
		npc.queue_free()
	# 唤醒：回到玩家周边的休眠记录
	for i in range(_dormant_npcs.size() - 1, -1, -1):
		var rec: Dictionary = _dormant_npcs[i]
		var pos: Vector3 = rec["pos"]
		if Vector2(pos.x - viewer.x, pos.z - viewer.z).length() > NPC_POOL_RESPAWN:
			continue
		_dormant_npcs.remove_at(i)
		_respawn_npc(rec)


func _respawn_npc(rec: Dictionary) -> void:
	var npc = NPC_SCENE.instantiate()
	npc.role = String(rec["role"])
	add_child(npc)
	npc.global_position = rec["pos"]
	npc.armed = bool(rec.get("armed", false))
	npc.hp = int(rec.get("hp", 40))
	if bool(rec.get("anomaly", false)):
		npc.set_meta("anomaly_touched", true)
	var offset = rec.get("patrol_offset", null)
	if offset is Vector3 and offset != Vector3.ZERO:
		npc.patrol_offset = offset


# 联机客户端：按主机同步的名单摧毁对应能量场（两端同种子，zone_id 一致）
func apply_zone_destruction(ids: Array) -> void:
	for zone in get_tree().get_nodes_in_group("anomaly_zones"):
		if ids.has(int(zone.get("zone_id"))):
			zone.apply_destroyed()


# —— 尸潮系统：英雄位 + MultiMesh 群演 ——
# 最近的 HORDE_HERO_CAP 只（以及全部精英/BOSS）保留完整模型与 AI；
# 其余 crowd 丧尸隐藏骨架、由单个 MultiMeshInstance 一次绘制（全场只 +1 draw call），
# AI 极简（直奔玩家免碰撞直移）——满屏几百只怪的主要成本由此压平

# 英雄位（全骨骼模型）上限与距离：实测角色蒙皮+网格是 GPU 瓶颈，
# 45→22 / 40m→30m，超出的一律走 6 draw call 的 MultiMesh 群演，怪海场景帧率翻倍级提升
const HORDE_HERO_CAP := 22
const HORDE_HERO_DIST := 30.0
const HORDE_ASSIGN_INTERVAL := 0.25

var _horde_timer := 0.0
var _horde_render_timer := 0.0
var _crowd_parts: Array = []
var _crowd_list: Array = []


func _build_horde_renderer() -> void:
	# 群演渲染：与丧尸同款比例的盒子小人（躯干/头/双臂/双腿），
	# 每个部件一个 MultiMesh（全场共 6 个 draw call），摆动由变换合成，CPU 零动画开销
	_crowd_parts = [
		_make_crowd_part("torso", BoxMesh.new(), Vector3(0.36, 0.55, 0.24), Vector3(0, 0.95, 0), Vector3(0, 0.95, 0), 0.0, 0.0),
		_make_crowd_part("head", BoxMesh.new(), Vector3(0.26, 0.26, 0.26), Vector3(0, 1.42, 0), Vector3(0, 1.42, 0), 0.0, 0.0),
		_make_crowd_part("arm_l", BoxMesh.new(), Vector3(0.11, 0.48, 0.11), Vector3(0.27, 1.18, 0), Vector3(0.27, 0.98, 0), 0.6, 0.0),
		_make_crowd_part("arm_r", BoxMesh.new(), Vector3(0.11, 0.48, 0.11), Vector3(-0.27, 1.18, 0), Vector3(-0.27, 0.98, 0), 0.6, PI),
		_make_crowd_part("leg_l", BoxMesh.new(), Vector3(0.13, 0.5, 0.13), Vector3(0.09, 0.6, 0), Vector3(0.09, 0.35, 0), 0.7, PI),
		_make_crowd_part("leg_r", BoxMesh.new(), Vector3(0.13, 0.5, 0.13), Vector3(-0.09, 0.6, 0), Vector3(-0.09, 0.35, 0), 0.7, 0.0),
	]


func _make_crowd_part(
	part_name: String, mesh: BoxMesh, size: Vector3,
	pivot: Vector3, center: Vector3, swing_amp: float, swing_shift: float
) -> Dictionary:
	mesh.size = size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	inst.material_override = material
	add_child(inst)
	return {
		"name": part_name, "inst": inst,
		"pivot": pivot, "center": center,
		"amp": swing_amp, "shift": swing_shift,
	}


func _tick_horde(delta: float) -> void:
	_horde_timer -= delta
	if _horde_timer <= 0.0:
		_horde_timer = HORDE_ASSIGN_INTERVAL
		_assign_horde_modes()
	_horde_render_timer -= delta
	if _horde_render_timer <= 0.0:
		_horde_render_timer = 1.0 / 30.0
		_update_crowd_multimesh()


func _assign_horde_modes() -> void:
	if not GameState.viewer_active:
		return
	var viewer := GameState.viewer_position
	var entries: Array = []
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.is_queued_for_deletion() or bool(zombie.get("_dying")):
			continue
		var elite := (
			int(zombie.get("zombie_tier")) >= 1
			or bool(zombie.get("is_boss"))
			or bool(zombie.get("is_acid"))
			or bool(zombie.get("showcase"))
		)
		var dist: float = zombie.global_position.distance_to(viewer)
		entries.append({"z": zombie, "elite": elite, "dist": dist})
	entries.sort_custom(
		func(a, b):
			if bool(a["elite"]) != bool(b["elite"]):
				return bool(a["elite"])
			return float(a["dist"]) < float(b["dist"])
	)
	_crowd_list.clear()
	var heroes := 0
	for entry in entries:
		var z: Node3D = entry["z"]
		# 英雄位总数封顶 + 距离门：40m 外的一律转群演（GLB 动画只在近处烧钱）
		var hero := (
			heroes < HORDE_HERO_CAP
			and (bool(entry["elite"]) or float(entry["dist"]) <= HORDE_HERO_DIST)
		)
		if hero:
			heroes += 1
			z.set_horde_mode("hero")
		else:
			z.set_horde_mode("crowd")
			_crowd_list.append(z)


func _update_crowd_multimesh() -> void:
	if _crowd_parts.is_empty():
		return
	for i in range(_crowd_list.size() - 1, -1, -1):
		var z = _crowd_list[i]
		if z == null or not is_instance_valid(z) or z.is_queued_for_deletion():
			_crowd_list.remove_at(i)
	var t := float(Time.get_ticks_msec()) / 1000.0
	for part in _crowd_parts:
		var mm: MultiMesh = (part["inst"] as MultiMeshInstance3D).multimesh
		mm.instance_count = _crowd_list.size()
		var pivot: Vector3 = part["pivot"]
		var center: Vector3 = part["center"]
		var amp: float = part["amp"]
		var shift: float = part["shift"]
		for i in _crowd_list.size():
			var z: Node3D = _crowd_list[i]
			var s: Vector3 = z.scale
			var base := Transform3D(Basis(Vector3.UP, z.rotation.y).scaled(s), z.global_position)
			var rot := Basis()
			if amp > 0.0:
				var move := clampf(
					Vector2(z.velocity.x, z.velocity.z).length() / 4.5, 0.0, 1.0
				)
				var phase := float(int(z.get_instance_id()) % 8) * 0.785
				rot = Basis(Vector3.RIGHT, sin(t * 8.0 + phase + shift) * amp * move)
			var local := Transform3D(rot, pivot + rot * (center - pivot))
			mm.set_instance_transform(i, base * local)
			mm.set_instance_color(i, z.crowd_color())


# —— 掉落物渲染与拾取：纯数据节点 + MultiMesh 单绘制 + 近距离扫描 ——

const PICKUP_RENDER_INTERVAL := 0.5
const PICKUP_COLLECT_RADIUS := 1.0
const PICKUP_MAGNET_RADIUS := 3.5
const PICKUP_MAGNET_SPEED := 11.0
# 玩家徒手拾取建材堆的接触半径（与车辆 PILE_REACH 一致）
const PLAYER_PILE_REACH := 2.5

var _pickup_sweep_timer := 0.0
var _pickup_render_timer := 0.0
var _pickup_render_dirty := false
var _pickup_renderers := {}
var _pile_full_notify_msec := 0


# 掉落物统一球形，只用颜色区分种类
func _pickup_mesh_for(kind: String) -> Mesh:
	var m := SphereMesh.new()
	match kind:
		"anomaly":
			m.radius = 0.14
			m.height = 0.28
		"relic":
			m.radius = 0.13
			m.height = 0.26
		"fuel":
			m.radius = 0.13
			m.height = 0.24
		_:
			m.radius = 0.11
			m.height = 0.2
	return m


func _pickup_color_for(kind: String) -> Color:
	match kind:
		"ammo":
			return Color(0.85, 0.68, 0.28)
		"food":
			return Color(0.95, 0.92, 0.8)
		"meds":
			return Color(0.92, 0.92, 0.95)
		"fuel":
			return Color(0.8, 0.16, 0.1)
		"anomaly":
			return Color(0.65, 0.3, 0.95)
		"relic":
			return Color(1.0, 0.78, 0.2)
		_:
			return Color(0.3, 0.62, 0.32)


func _build_pickup_renderers() -> void:
	for kind in ["cash", "ammo", "food", "meds", "fuel", "anomaly", "relic"]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _pickup_mesh_for(kind)
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var material := StandardMaterial3D.new()
		var color := _pickup_color_for(kind)
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.5
		inst.material_override = material
		add_child(inst)
		_pickup_renderers[kind] = {"inst": inst, "count": -1}


# 磁吸拾取：3.5m 内掉落物自动飞向玩家，碰到立即结算；
# 飞行中的掉落物触发渲染器即时刷新（取代原来每 0.12s 才扫一次的"慢半拍"）
func _tick_pickups(delta: float) -> void:
	_pickup_render_timer -= delta
	var player = get_tree().get_first_node_in_group("player")
	if player != null and not GameState.is_run_over():
		var player_pos: Vector3 = player.global_position
		for node in get_tree().get_nodes_in_group("pickups"):
			if node.is_queued_for_deletion():
				continue
			var d := player_pos.distance_to(node.global_position)
			if d <= PICKUP_COLLECT_RADIUS:
				# 拾取当帧先隐藏实例：不等下一次异步刷新，立刻消失
				_hide_pickup_instance(node)
				node.apply_effect()
				_pickup_render_dirty = true
			elif d <= PICKUP_MAGNET_RADIUS * GameState.rogue_magnet_mult():
				node.global_position = node.global_position.move_toward(
					Vector3(player_pos.x, node.global_position.y, player_pos.z),
					PICKUP_MAGNET_SPEED * delta
				)
				# 飞行轨迹当帧直写，卡顿时不等异步刷新，动画不会断
				_patch_pickup_transform(node)
				_pickup_render_dirty = true
		# 玩家徒手拾取建材堆：2.5m 内随身建材 +N（上限 CAPS.materials），未拿完保留余量# 开车时跳过（车辆 _collect_material_piles 负责装车斗）
		if player.get("vehicle") == null:
			var carry_cap: int = int(GameState.CAPS.get("materials", 200))
			for pile in get_tree().get_nodes_in_group("material_piles"):
				if pile.is_queued_for_deletion():
					continue
				if player_pos.distance_to(pile.global_position) > PLAYER_PILE_REACH:
					continue
				var have: int = int(GameState.resources.get("materials", 0))
				var take: int = pile.amount if GameState.test_mode else mini(pile.amount, carry_cap - have)
				if take <= 0:
					var now := Time.get_ticks_msec()
					if now - _pile_full_notify_msec > 2500:
						_pile_full_notify_msec = now
						GameState.notify("随身建材已满（%d/%d），回据点存入" % [have, carry_cap])
					continue
				GameState.resources["materials"] = have + take
				GameState.resources_changed.emit()
				var left: int = pile.amount - take
				if left <= 0:
					pile.queue_free()
				else:
					pile.setup(left)
				GameState.notify("拾取建材 +%d（随身 %d/%d）" % [take, have + take, carry_cap])
	if _pickup_render_dirty:
		if _pickup_render_timer <= 0.0:
			_pickup_render_timer = 0.1
			_pickup_render_dirty = false
			_refresh_pickup_renderers()
	elif _pickup_render_timer <= 0.0:
		_pickup_render_timer = PICKUP_RENDER_INTERVAL
		_refresh_pickup_renderers()


# 掉落物分桶计算交给 WorkerThreadPool 的另一颗核：
# 主线程只负责快照（场景树不可跨线程）与应用结果，纯数学在 worker 上跑
var _pickup_worker_busy := false


# 快照只收玩家/相机 120m 内的掉落：磁吸范围外本来也拾取不到，
# 尸潮战场留下的几百个远掉落不再进 MultiMesh 分桶（主线程快照与实例数双降）
const PICKUP_RENDER_RANGE := 120.0


func _refresh_pickup_renderers() -> void:
	if _pickup_worker_busy:
		return
	var viewer := GameState.viewer_position
	var snapshot: Array = []
	for node in get_tree().get_nodes_in_group("pickups"):
		if node.is_queued_for_deletion():
			continue
		if (node.global_position as Vector3).distance_to(viewer) > PICKUP_RENDER_RANGE:
			continue
		snapshot.append({"kind": String(node.get("kind")), "node": node, "pos": node.global_position})
	_pickup_worker_busy = true
	if OS.has_feature("threads"):
		WorkerThreadPool.add_task(_compute_pickup_buckets.bind(snapshot))
	else:
		# Web 无线程环境：主线程内联执行同一计算
		_compute_pickup_buckets(snapshot)


# worker 线程：纯数学分桶，不碰场景树与渲染服务器（只搬运节点引用，不调用方法）
func _compute_pickup_buckets(snapshot: Array) -> void:
	var buckets := {}
	for item in snapshot:
		var kind: String = item["kind"]
		if not buckets.has(kind):
			buckets[kind] = []
		buckets[kind].append(item["node"])
	call_deferred("_apply_pickup_buckets", buckets)


# 主线程：把 worker 分好的引用写进 MultiMesh，并记录 节点→实例下标 映射，
# 供磁吸飞行中的掉落物当帧直写变换（卡顿时不依赖异步刷新，不会"突然消失"）
func _apply_pickup_buckets(buckets: Dictionary) -> void:
	_pickup_worker_busy = false
	if not is_inside_tree():
		return
	for kind in _pickup_renderers.keys():
		var entry: Dictionary = _pickup_renderers[kind]
		var list: Array = buckets.get(kind, [])
		entry["count"] = list.size()
		var mm: MultiMesh = (entry["inst"] as MultiMeshInstance3D).multimesh
		mm.instance_count = list.size()
		var index := {}
		for i in list.size():
			var node: Node3D = list[i]
			mm.set_instance_transform(
				i, Transform3D(Basis(), node.global_position + Vector3(0, 0.1, 0))
			)
			index[node] = i
		entry["index"] = index


# 磁吸飞行中的掉落物：当帧直写 MultiMesh 变换（少量，主线程成本可忽略）
func _patch_pickup_transform(node: Node3D) -> void:
	var entry: Dictionary = _pickup_renderers.get(String(node.get("kind")), {})
	if entry.is_empty():
		return
	var idx: int = int(entry.get("index", {}).get(node, -1))
	if idx < 0:
		return
	(entry["inst"] as MultiMeshInstance3D).multimesh.set_instance_transform(
		idx, Transform3D(Basis(), node.global_position + Vector3(0, 0.1, 0))
	)


# 拾取当帧隐藏实例：缩放到零（等价的即时消失），不用等异步刷新清点
func _hide_pickup_instance(node: Node3D) -> void:
	var entry: Dictionary = _pickup_renderers.get(String(node.get("kind")), {})
	if entry.is_empty():
		return
	var idx: int = int(entry.get("index", {}).get(node, -1))
	if idx < 0:
		return
	(entry["inst"] as MultiMeshInstance3D).multimesh.set_instance_transform(
		idx, Transform3D(Basis().scaled(Vector3.ZERO), node.global_position)
	)
# —— crowd 批量移动：快照 → worker 线程 → 回收应用（每只 crowd 的主线程成本趋零）——

const CROWD_MOVE_STEP := 2
const ZOMBIE_SCRIPT := preload("res://scripts3d/zombie3d.gd")

var _crowd_move_worker_busy := false
var _crowd_move_frames := 0


func _tick_crowd_move(delta: float) -> void:
	_crowd_move_frames += 1
	if _crowd_move_frames % CROWD_MOVE_STEP != 0 or _crowd_move_worker_busy:
		return
	if _crowd_list.is_empty():
		return
	var player = get_tree().get_first_node_in_group("player")
	var player_pos := Vector3.ZERO
	if player != null and not GameState.is_bad_zombie():
		player_pos = player.global_position
	var step_delta := delta * CROWD_MOVE_STEP
	var speed: float = ZOMBIE_SCRIPT.SPEED
	var snapshot: Array = []
	for z in _crowd_list:
		if (
			z == null or not is_instance_valid(z) or z.is_queued_for_deletion()
			or bool(z.get("_dying")) or bool(z.get("net_puppet"))
		):
			continue
		var assault := Vector3.ZERO
		var av = z.get("assault_target")
		if av is Vector3:
			assault = av
		snapshot.append([
			z, z.global_position, z.velocity, assault,
			speed * float(z.get("_speed_mult")), z.rotation.y,
		])
	if snapshot.is_empty():
		return
	_crowd_move_worker_busy = true
	if OS.has_feature("threads"):
		WorkerThreadPool.add_task(
			_crowd_move_compute.bind(
				snapshot, player_pos, step_delta,
				_building_collision_rects, _building_rect_index
			)
		)
	else:
		# Web 无线程环境：主线程内联执行同一计算
		_crowd_move_compute(
			snapshot, player_pos, step_delta,
			_building_collision_rects, _building_rect_index
		)


# worker 线程：纯数学移动 + 建筑推挤 + 贴墙滑动 + 软分散（不调用任何节点方法）
func _crowd_move_compute(
	snapshot: Array, player_pos: Vector3, delta: float, rects: Array, rect_index: Dictionary
) -> void:
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var yaws := PackedFloat32Array()
	var attackers := PackedInt32Array()
	for i in snapshot.size():
		var entry: Array = snapshot[i]
		var pos: Vector3 = entry[1]
		var vel: Vector3 = entry[2]
		var assault: Vector3 = entry[3]
		var speed: float = entry[4]
		var target := Vector3.ZERO
		if assault != Vector3.ZERO:
			target = assault
		elif player_pos != Vector3.ZERO:
			target = player_pos
		if target == Vector3.ZERO:
			pos += vel * delta
		else:
			var to := target - pos
			to.y = 0.0
			var dist := to.length()
			if dist >= 0.05:
				vel = (to / dist) * speed
				pos += vel * delta
		# 建筑矩形推挤 + 贴墙滑动（不穿楼，也不面壁卡死）
		var push: Array = building_push_out(rects, rect_index, pos, 0.35)
		var edge := int(push[1])
		if edge != 0:
			pos = push[0]
			var speed_len := Vector2(vel.x, vel.z).length()
			if speed_len > 0.05:
				if edge == 1:
					var s := 1.0
					if absf(vel.z) > 0.05:
						s = signf(vel.z)
					elif target != Vector3.ZERO:
						s = signf(target.z - pos.z)
					vel = Vector3(0, 0, s * speed_len)
				else:
					var s := 1.0
					if absf(vel.x) > 0.05:
						s = signf(vel.x)
					elif target != Vector3.ZERO:
						s = signf(target.x - pos.x)
					vel = Vector3(s * speed_len, 0, 0)
		positions.append(pos)
		velocities.append(vel)
	# 软分散：格哈希互斥，尸群不挤成一坨
	var cells := {}
	var cell_size := 0.9
	for i in positions.size():
		var c := Vector2i(floori(positions[i].x / cell_size), floori(positions[i].z / cell_size))
		if not cells.has(c):
			cells[c] = []
		cells[c].append(i)
	for i in positions.size():
		var pi: Vector3 = positions[i]
		var repel := Vector3.ZERO
		var checked := 0
		var cc := Vector2i(floori(pi.x / cell_size), floori(pi.z / cell_size))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var cell: Array = cells.get(cc + Vector2i(dx, dz), [])
				for j in cell:
					if j == i or checked >= 3:
						continue
					var d := pi - positions[j]
					d.y = 0.0
					var dist := d.length()
					if dist > 0.9 or dist < 0.001:
						continue
					repel += (d / dist) * (0.9 - dist)
					checked += 1
		if repel.length() > 0.01:
			if repel.length() > 0.9:
				repel = repel.normalized() * 0.9
			positions[i] = pi + repel * delta * 6.0
			velocities[i] += repel * 2.0
	# 贴身攻击判定与朝向
	for i in positions.size():
		var vel: Vector3 = velocities[i]
		var yaw: float = snapshot[i][5]
		if player_pos != Vector3.ZERO and (player_pos - positions[i]).length() < 1.8:
			velocities[i] = Vector3.ZERO
			attackers.append(i)
		elif Vector2(vel.x, vel.z).length() > 0.05:
			yaw = atan2(-vel.x, -vel.z)
		yaws.append(yaw)
	call_deferred("_crowd_move_apply", snapshot, positions, velocities, yaws, attackers)


# 主线程：应用位置/速度/朝向；贴身攻击在这里结算（伤害只能主线程做）
func _crowd_move_apply(
	snapshot: Array,
	positions: PackedVector3Array,
	velocities: PackedVector3Array,
	yaws: PackedFloat32Array,
	attackers: PackedInt32Array
) -> void:
	_crowd_move_worker_busy = false
	if not is_inside_tree():
		return
	for i in snapshot.size():
		var z = snapshot[i][0]
		if z == null or not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		z.global_position = positions[i]
		z.velocity = velocities[i]
		z.rotation.y = yaws[i]
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	for idx in attackers:
		var z = snapshot[idx][0]
		if z == null or not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		if float(z.get("_attack_cooldown")) > 0.0:
			continue
		z.set("_attack_cooldown", 1.0 / maxf(float(z.get("_attack_speed")), 0.2))
		GameState.noise_at(z.global_position, 12.0)
		player.take_damage(int(z.get("_damage")))


func _process(delta: float) -> void:
	_update_viewer()
	_cull_distant_props()
	_update_light_rings()
	_tick_pickups(delta)
	_tick_horde(delta)
	_tick_crowd_move(delta)
	_update_daynight()
	_update_weather()
	if not Network.is_server():
		return
	_tick_npc_pool(delta)
	# 据点夜袭：仅在主机端跑（联机 puppet 端由网络同步丧尸位置）
	var night := GameState.is_night()
	if night and not _was_night and GameState.has_home_base():
		_start_base_assault()
	_was_night = night
	if _assault_active:
		_update_base_assault(delta)
	_update_base_aggro(delta)
	if GameState.rogue_mode:
		# 肉鸽模式：丧尸只从能量点刷，跳过 Boss/猎杀小队/全图游荡刷怪
		_tick_rogue(delta)
		return
	if not GameState.zombies_active():
		return
	var stats := GameState.world_zombie_stats()
	_boss_timer += delta
	if int(stats.get("boss_tier", 0)) > 0 and _boss_timer >= 180.0:
		_boss_timer = 0.0
		_spawn_boss()
	if bool(stats.get("god", false)) and not _god_spawned:
		_god_spawned = true
		_spawn_god()
	_hunter_timer -= delta
	if _hunter_timer <= 0.0:
		var threat := GameState.human_threat_level()
		var stage_high := GameState.world_stage_index() >= 3
		var engaged := threat >= 2 or stage_high
		_hunter_timer = 30.0 if threat >= 2 else (90.0 if stage_high else 150.0)
		if engaged and get_tree().get_nodes_in_group("human_hunters").size() < 6:
			_spawn_human_squad(threat if threat >= 2 else 4)
	_zombie_count_timer -= delta
	if _zombie_count_timer <= 0.0:
		_zombie_count_timer = 0.5
		_zombie_count = get_tree().get_nodes_in_group("zombies").size()
		GameState.zombie_horde_size = _zombie_count
	var cap := int(float(ZOMBIE_CAP) * float(stats["cap_mult"]))
	if _zombie_count >= cap:
		return
	_zombie_timer -= delta
	if _zombie_timer > 0.0:
		return
	_zombie_timer = ZOMBIE_SPAWN_STEP / maxf(float(stats["spawn_mult"]), 0.1)
	_zombie_count += 1
	_spawn_zombie()


func _update_viewer() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		GameState.viewer_position = player.global_position
		GameState.viewer_active = true


# 远距离渲染剔除：楼体/装饰物（occludable 组）超出相机视野范围的隐藏显示，
# 直接砍掉城市远景的绘制调用（兼容渲染器不支持遮挡剔除，用距离近似）。
# 只隐藏渲染节点可见性，碰撞体保留（不影响物理与 AI 寻路）。
const CULL_DIST := 160.0
const CULL_EVERY := 8
var _cull_frame := 0
var _cull_player: Node3D = null


func _cull_distant_props() -> void:
	_cull_frame += 1
	if _cull_frame % CULL_EVERY != 0:
		return
	if _cull_player == null or not is_instance_valid(_cull_player):
		_cull_player = get_tree().get_first_node_in_group("player")
		if _cull_player == null:
			return
	var pp := _cull_player.global_position
	var lim := CULL_DIST * CULL_DIST
	for node in get_tree().get_nodes_in_group("occludable"):
		var d2 := Vector2(
			node.global_position.x - pp.x, node.global_position.z - pp.z
		).length_squared()
		var show := d2 <= lim
		if node.visible != show:
			node.visible = show


func _spawn_human_squad(tier: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var count := 1
	if tier >= 6:
		count = 2
	if tier >= 9:
		count = 3
	for i in count:
		var npc = NPC_SCENE.instantiate()
		npc.human_tier = tier
		npc.position = _elite_spawn_pos(player.global_position)
		add_child(npc)
	var info := GameState.human_tier_info(tier)
	var tier_name := String(info.get("name", "?"))
	GameState.notify("人类阵营出动：%s！" % tier_name)
	GameState.post_message(
		"人类阵营出动：%s" % tier_name, Vector2.ZERO, "crime", tier >= 4
	)


func _elite_spawn_pos(player_pos: Vector3) -> Vector3:
	for attempt in 30:
		var angle := randf() * TAU
		var dist := randf_range(16.0, 28.0)
		var pos := player_pos + Vector3(cos(angle) * dist, 0.3, sin(angle) * dist)
		if pos.x < 2.0 or pos.z < 2.0:
			continue
		if (
			pos.x > GameState.CITY_SIZE.x * SCALE - 2.0
			or pos.z > GameState.CITY_SIZE.y * SCALE - 2.0
		):
			continue
		if _inside_any_building(Vector2(pos.x / SCALE, pos.z / SCALE)):
			continue
		return pos
	return _random_free_pos() + Vector3(0, 0.3, 0)


func _spawn_boss() -> void:
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.is_boss = true
	zombie.zombie_tier = GameState.pick_boss_tier()
	var pos := _random_free_pos()
	zombie.position = Vector3(pos.x, 0.3, pos.z)
	add_child(zombie)
	var boss_name := String(GameState.zombie_tier_info(zombie.zombie_tier).get("name", "尸王"))
	GameState.post_message("%s 降临，小心！" % boss_name, Vector2.ZERO, "zombie", true)
	GameState.notify("%s 出现了！" % boss_name)


# 据点袭击：开始后持续 ASSAULT_DURATION 秒，期间按批补刷，保持约 ASSAULT_ALIVE_CAP 只在场
const ASSAULT_DURATION := 150.0
const ASSAULT_BATCH_INTERVAL := 6.0
const ASSAULT_ALIVE_CAP := 24
const BASE_AGGRO_RADIUS := 80.0


func _start_base_assault(count := -1) -> void:
	if not GameState.has_home_base():
		return
	_assault_until_msec = Time.get_ticks_msec() + int(ASSAULT_DURATION * 1000.0)
	_assault_batch_timer = 0.0
	_assault_zombies.clear()
	_assault_active = true
	_spawn_assault_batch(count if count > 0 else 10 + 2 * GameState.day_number)
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	var pos_px := Vector2(base_pos.x, base_pos.z) / SCALE
	GameState.post_message(
		"尸群正在逼近据点！持续约 %d 秒" % int(ASSAULT_DURATION), pos_px, "horde"
	)
	GameState.notify("尸潮来袭！守住据点 %d 秒！" % int(ASSAULT_DURATION))


func _spawn_assault_batch(count: int) -> void:
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	for i in count:
		var zombie = ZOMBIE_SCENE.instantiate()
		zombie.zombie_tier = GameState.pick_zombie_tier()
		zombie.assault_target = base_pos
		add_child(zombie)
		zombie.global_position = _assault_spawn_pos(base_pos)
		_assault_zombies.append(zombie)


# 袭击刷怪点：据点半径 40~70 米的环形带（快速接敌），收进地图边界并避开建筑内部
func _assault_spawn_pos(base_pos: Vector3) -> Vector3:
	for attempt in 20:
		var angle := randf() * TAU
		var dist := randf_range(40.0, 70.0)
		var pos := Vector3(
			clampf(base_pos.x + cos(angle) * dist, 2.0, GameState.CITY_SIZE.x * SCALE - 2.0),
			0.3,
			clampf(base_pos.z + sin(angle) * dist, 2.0, GameState.CITY_SIZE.y * SCALE - 2.0)
		)
		if not _inside_any_building_3d(pos):
			return pos
	return base_pos + Vector3(randf_range(-30.0, 30.0), 0.3, randf_range(-30.0, 30.0))


func _inside_any_building_3d(pos: Vector3) -> bool:
	var px := pos.x / SCALE
	var pz := pos.z / SCALE
	for entry in GameState.BUILDING_LAYOUT:
		var center: Vector2 = entry["position"]
		var half: Vector2 = entry["size"] / 2.0 + Vector2(40, 40)
		if absf(px - center.x) < half.x and absf(pz - center.y) < half.y:
			return true
	for tower in GameState.TOWERS:
		var center: Vector2 = tower["position"]
		var half: Vector2 = tower["size"] / 2.0 + Vector2(40, 40)
		if absf(px - center.x) < half.x and absf(pz - center.y) < half.y:
			return true
	return false


# 袭击波维护：持续期内按批补刷；时间到且全灭则广播守住；据点消失或本局结束则终止
func _update_base_assault(delta: float) -> void:
	for i in range(_assault_zombies.size() - 1, -1, -1):
		var zombie = _assault_zombies[i]
		if zombie == null or not is_instance_valid(zombie) or zombie.is_queued_for_deletion():
			_assault_zombies.remove_at(i)
	if not GameState.has_home_base() or GameState.is_run_over():
		_assault_zombies.clear()
		_assault_active = false
		return
	if Time.get_ticks_msec() < _assault_until_msec:
		_assault_batch_timer -= delta
		if _assault_batch_timer <= 0.0:
			_assault_batch_timer = ASSAULT_BATCH_INTERVAL
			var missing := ASSAULT_ALIVE_CAP - _assault_zombies.size()
			if missing > 0:
				_spawn_assault_batch(mini(missing, 8))
		return
	if _assault_zombies.is_empty():
		_assault_active = false
		var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
		GameState.post_message(
			"据点守住了", Vector2(base_pos.x, base_pos.z) / SCALE, "horde", true
		)
		GameState.notify("据点守住了！")


# 据点仇恨：附近游荡的丧尸进入据点半径后主动进攻
func _update_base_aggro(delta: float) -> void:
	_base_aggro_timer -= delta
	if _base_aggro_timer > 0.0:
		return
	_base_aggro_timer = 2.5
	if not GameState.has_home_base():
		return
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	for zombie in GameState.entities_in_group_in_radius(base_pos, "zombies", BASE_AGGRO_RADIUS):
		if zombie.assault_target != Vector3.ZERO:
			continue
		zombie.assault_target = base_pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		_try_open_ground_base()
	# F4：方向光阴影开关（性能测试用，兼容渲染器下阴影是二次绘制大头）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		if _sun != null:
			_sun.shadow_enabled = not _sun.shadow_enabled
			GameState.notify("方向光阴影：%s（F4 切换）" % ("开" if _sun.shadow_enabled else "关"))
		return
	# F5：3D 渲染分辨率循环（100% → 67% → 50%），现场试帧率/清晰度平衡点
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		var vp := get_viewport()
		var next_scale := 1.0 if vp.scaling_3d_scale < 0.6 else (
			0.5 if vp.scaling_3d_scale > 0.6 else 0.67
		)
		vp.scaling_3d_scale = next_scale
		GameState.notify("3D 渲染分辨率：%d%%（F5 循环）" % int(next_scale * 100.0))
		return
	# F2：隐藏/显示全部丧尸与 NPC 模型（A/B 实测：FPS 大涨=渲染瓶颈，不变=逻辑瓶颈）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		_debug_hide_characters = not _debug_hide_characters
		var show := not _debug_hide_characters
		for group in ["zombies", "npcs"]:
			for node in get_tree().get_nodes_in_group(group):
				for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
					mesh_node.visible = show
		GameState.notify("角色模型：%s（F2 切换，看 FPS 变化）" % ("显示" if show else "隐藏"))
		return
	if not GameState.test_mode:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F6:
			GameState.debug_start_outbreak()
			GameState.notify("测试：灾变立即爆发")
		KEY_F7:
			GameState.debug_next_stage()
			GameState.notify("测试：推进到下一灾变阶段")
		KEY_F8:
			if not _god_spawned:
				_god_spawned = true
				_spawn_god()
		KEY_F9:
			GameState.debug_toggle_daynight()
		KEY_F10:
			GameState.debug_time_scale = (
				1.0 if GameState.debug_time_scale > 1.0 else 10.0
			)
			GameState.notify("测试：时间流速 ×%d" % int(GameState.debug_time_scale))
		KEY_F11:
			if GameState.has_home_base():
				_start_base_assault(30)
			else:
				GameState.notify("测试：先占领一个据点再召唤尸潮")


# 空地建据点：无据点时按 X，消耗脚边 3m 内建材堆 ×150；
# 有据点或据点半径内时 X 由建造模式接管，有通缉时 X 留给投降
func _try_open_ground_base() -> void:
	if GameState.has_home_base() or GameState.is_run_over() or GameState.base_build_mode:
		return
	if GameState.any_panel_open() or GameState.pause_menu_open:
		return
	if GameState.wanted > 0 or GameState.is_outlaw():
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var pos: Vector3 = player.global_position
	pos.y = 0.05
	GameState.claim_open_ground_base(pos)


func _build_test_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var label := Label.new()
	label.text = "测试模式 · F6 灾变 · F7 下一阶段 · F8 尸神 · F9 昼夜 · F10 时间×10 · F11 尸潮"
	# 右下角按键提示行的上方，避免压到底部热键栏
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -440.0
	label.offset_right = -12.0
	label.offset_top = -140.0
	label.offset_bottom = -124.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 0.9))
	layer.add_child(label)
	# 加 NPC 按钮：每次点击向全图撒 50 个市民（池化自动管理活跃数）
	var button := Button.new()
	button.text = "＋NPC ×50"
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -140.0
	button.offset_right = -12.0
	button.offset_top = -172.0
	button.offset_bottom = -146.0
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_on_test_add_npc.bind(button))
	layer.add_child(button)


# 测试模式加人：全图随机撒 count 个市民（避开建筑），返回当前总人口
func spawn_civilians_extra(count := 50) -> int:
	for i in count:
		var npc = NPC_SCENE.instantiate()
		npc.role = "pedestrian"
		add_child(npc)
		npc.global_position = _random_free_pos()
	return get_tree().get_nodes_in_group("npcs").size() + _dormant_npcs.size()


func _on_test_add_npc(button: Button) -> void:
	var total := spawn_civilians_extra(50)
	button.text = "＋NPC ×50（总人口 %d）" % total
	GameState.notify("测试模式：市民 +50（总人口 %d，池化自动休眠远距个体）" % total)


func _spawn_god() -> void:
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.is_boss = true
	zombie.zombie_tier = 9
	var pos := _random_free_pos()
	zombie.position = Vector3(pos.x, 0.3, pos.z)
	add_child(zombie)
	var pos_px := Vector2(pos.x, pos.z) / SCALE
	GameState.post_message(
		"尸神·天灾降临！击杀它可获得高额 SP 结算加成", pos_px, "zombie", true
	)
	GameState.notify("尸神·天灾降临！")


func _setup_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	# 阴影默认关闭：兼容渲染器下方向光阴影是二次绘制，弱显卡上成本远超观感收益；
	# 想对比/找回阴影随时按 F4 切换
	sun.shadow_enabled = false
	sun.light_energy = 1.1
	# 阴影只渲染相机附近区域：兼容渲染器下方向光阴影是二次绘制，
	# 缩小距离能成倍砍掉远处的阴影 pass（400 → 120 米，观感几乎不变）
	sun.directional_shadow_max_distance = 120.0
	_sun = sun
	add_child(sun)


# 昼夜循环：白天太阳按当天进度东升西落，夜晚转入地平线以下、环境光调暗、路灯点亮；
# 准备期固定为白天。天气缩放亮度：白天 ×day_brightness()（雨天明显变暗），
# 夜晚环境光按 night_brightness()（月相×雨）在 0.04~0.2 间过渡
func _update_daynight() -> void:
	if _sun == null or _env == null:
		return
	var elevation := 55.0
	if GameState.zombies_active():
		if GameState.is_night():
			var span := GameState.DAY_LENGTH - GameState.NIGHT_START
			var n := clampf((GameState.day_elapsed - GameState.NIGHT_START) / span, 0.0, 1.0)
			elevation = -(6.0 + sin(n * PI) * 40.0)
		else:
			var d := clampf(GameState.day_elapsed / GameState.NIGHT_START, 0.0, 1.0)
			elevation = 6.0 + sin(d * PI) * 64.0
	_sun.rotation_degrees = Vector3(-elevation, -35.0, 0.0)
	var day_factor := clampf(elevation / 60.0, 0.0, 1.0)
	var day_b := GameState.day_brightness()
	_sun.visible = elevation > 0.0
	_sun.light_energy = 1.1 * day_factor * day_b
	if elevation > 0.0:
		# 白天/黄昏：保留原有正弦过渡，按天气整体压暗
		_env.ambient_light_energy = lerpf(0.12, 0.7, day_factor) * day_b
	else:
		# 夜晚：真黑暗——无光照处基本全黑，满月晴夜也只能看清近处轮廓
		var night_depth := clampf(-elevation / 46.0, 0.0, 1.0)
		var night_ambient := lerpf(0.008, 0.06, GameState.night_brightness())
		_env.ambient_light_energy = lerpf(0.12 * day_b, night_ambient, night_depth)
	_update_entity_visibility()


# 雨景与月亮：GPUParticles3D 雨点跟随玩家头顶竖直下坠（gl_compatibility 用最简设置），
# 月亮是天上一个自发光圆盘，亮度随月相，雨夜隐藏
func _build_weather() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 700
	particles.lifetime = 0.6
	particles.local_coords = false
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-20.0, -16.0, -20.0), Vector3(40.0, 30.0, 40.0))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 2.0
	process.initial_velocity_min = 22.0
	process.initial_velocity_max = 26.0
	process.gravity = Vector3.ZERO
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(15.0, 0.2, 15.0)
	particles.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.02, 0.4, 0.02)
	particles.draw_pass_1 = drop
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.6, 0.7, 0.85, 0.45)
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = drop_material
	_rain = particles
	add_child(particles)

	_moon_material = StandardMaterial3D.new()
	_moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_moon_material.emission_enabled = true
	_moon_material.emission = Color(0.85, 0.9, 1.0)
	_moon_material.emission_energy_multiplier = 1.2
	var moon := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 4.0
	disc.height = 8.0
	moon.mesh = disc
	moon.material_override = _moon_material
	moon.visible = false
	_moon = moon
	add_child(moon)


func _update_weather() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if _rain != null:
		_rain.emitting = GameState.is_raining()
		if _rain.emitting and player != null:
			_rain.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
	if _moon != null:
		var show_moon := GameState.is_night() and not GameState.is_raining()
		_moon.visible = show_moon
		if show_moon and player != null:
			_moon.global_position = player.global_position + Vector3(-70.0, 48.0, -70.0)
			var glow := 0.35 + 0.65 * GameState.moon_phase
			_moon_material.albedo_color = Color(0.9, 0.93, 1.0) * glow
			_moon_material.emission_energy_multiplier = 1.2 * glow


# 夜晚实体可见性：只有被光源照到的丧尸/NPC 才可见，黑暗中的实体隐藏
const VIS_PLAYER_RADIUS := 6.0

var _vis_timer := 0.0

# —— 地面光圈：夜间所有照明设备在地面画出与照明判定范围一致的光圈 ——
# 所有光圈先做多边形并集再整体绘制：重叠区域只画一次，全图亮度严格一致
const LIGHT_RING_CAPACITY := 48
const RING_SEGMENTS := 14
# 统一亮度与颜色
const LIGHT_RING_COLOR := Color(1.0, 0.85, 0.6, 0.18)

var _ring_mesh: ImmediateMesh = null
# 光圈重建节流：20Hz 足够平滑，避免每帧跑布尔并集
var _ring_rebuild_timer := 0.0


func _build_light_rings() -> void:
	_ring_mesh = ImmediateMesh.new()
	var inst := MeshInstance3D.new()
	inst.mesh = _ring_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = LIGHT_RING_COLOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


# 每帧同步光圈：数据源与实体可见性判定（_collect_light_zones）完全一致
func _update_light_rings() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var night := GameState.is_night() and player != null
	if not night:
		if _ring_mesh.get_surface_count() > 0:
			_ring_mesh.clear_surfaces()
		return
	_ring_rebuild_timer -= get_process_delta_time()
	if _ring_rebuild_timer > 0.0:
		return
	_ring_rebuild_timer = 0.05
	var rings: Array = []
	# 主角脚下光圈：半径 = 夜间实体可见判定半径
	rings.append(_make_ring(player.global_position, VIS_PLAYER_RADIUS, VIS_PLAYER_RADIUS))
	var zones := _collect_light_zones(player)
	for point in zones["points"]:
		var radius := float(point["radius"])
		rings.append(_make_ring(point["pos"], radius, radius))
	for cone in zones["cones"]:
		var dir: Vector3 = cone["dir"]
		dir.y = 0.0
		dir = dir.normalized()
		var range: float = cone["range"]
		var half_width := range * tan(deg_to_rad(float(cone["angle"]) * 0.5))
		var center: Vector3 = cone["pos"] + dir * range * 0.5
		rings.append(_make_ring(center, half_width, range * 0.55, atan2(dir.x, dir.z)))
	if rings.size() > LIGHT_RING_CAPACITY:
		rings = rings.slice(0, LIGHT_RING_CAPACITY)
	_rebuild_ring_mesh(rings)


func _make_ring(pos: Vector3, sx: float, sz: float, yaw := 0.0) -> Dictionary:
	return {
		"pos": Vector2(pos.x, pos.z),
		"sx": sx,
		"sz": sz,
		"yaw": yaw,
		"reach": maxf(sx, sz),
	}


func _ring_polygon(ring: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var center: Vector2 = ring["pos"]
	var cy := cos(ring["yaw"])
	var sy := sin(ring["yaw"])
	for i in RING_SEGMENTS:
		var angle := TAU * float(i) / RING_SEGMENTS
		var lx := cos(angle) * float(ring["sx"])
		var lz := sin(angle) * float(ring["sz"])
		# 与 Basis(Vector3.UP, yaw) 相同的旋转：local (lx, lz) → world XZ
		pts.append(center + Vector2(lx * cy + lz * sy, -lx * sy + lz * cy))
	return pts


func _rings_overlap(a: Dictionary, b: Dictionary) -> bool:
	return a["pos"].distance_to(b["pos"]) < float(a["reach"]) + float(b["reach"])


# 并集合并后三角化：任何地面位置只被一个三角形覆盖，亮度不叠加。
# 先按接触关系并查集分组；组内逐个并入：两个凸多边形相交时并集必为单个多边形，
# 每次成功合并都会让暂存集规模减一，循环有界
func _rebuild_ring_mesh(rings: Array) -> void:
	_ring_mesh.clear_surfaces()
	if rings.is_empty():
		return
	var parent: Array = []
	for i in rings.size():
		parent.append(i)
	for i in rings.size():
		for j in range(i + 1, rings.size()):
			if _rings_overlap(rings[i], rings[j]):
				_set_union(parent, i, j)
	var clusters := {}
	for i in rings.size():
		var root := _set_find(parent, i)
		if not clusters.has(root):
			clusters[root] = []
		clusters[root].append(i)
	_ring_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for indices in clusters.values():
		var acc: Array = []
		for k in indices:
			var poly := _ring_polygon(rings[k])
			var rect := _poly_rect(poly)
			var i := 0
			while i < acc.size():
				if not rect.intersects(acc[i]["rect"], true):
					i += 1
					continue
				var parts := Geometry2D.merge_polygons(poly, acc[i]["poly"])
				if parts.size() == 1:
					# 真正相交：合并为一个，从头再查（合并体可能覆盖之前跳过的多边形）
					poly = parts[0]
					rect = _poly_rect(poly)
					acc.remove_at(i)
					i = 0
				else:
					# 不相交：merge 原样返回两者，跳过
					i += 1
			acc.append({"poly": poly, "rect": rect})
		for entry in acc:
			var poly: PackedVector2Array = entry["poly"]
			var tri := Geometry2D.triangulate_polygon(poly)
			for j in tri:
				_ring_mesh.surface_add_vertex(Vector3(poly[j].x, 0.12, poly[j].y))
	_ring_mesh.surface_end()


func _poly_rect(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		rect = rect.expand(p)
	return rect


func _set_find(parent: Array, i: int) -> int:
	var root := i
	while int(parent[root]) != root:
		root = int(parent[root])
	while int(parent[i]) != root:
		var next := int(parent[i])
		parent[i] = root
		i = next
	return root


func _set_union(parent: Array, a: int, b: int) -> void:
	var ra := _set_find(parent, a)
	var rb := _set_find(parent, b)
	if ra != rb:
		parent[rb] = ra


func _update_entity_visibility() -> void:
	_vis_timer -= get_process_delta_time()
	if _vis_timer > 0.0:
		return
	_vis_timer = 0.25
	var player = get_tree().get_first_node_in_group("player")
	if not GameState.is_night() or player == null:
		_restore_all_visible()
		return
	var zones := _collect_light_zones(player)
	_vis_restored = false
	for group in ["zombies", "npcs"]:
		for entity in get_tree().get_nodes_in_group(group):
			if entity.is_queued_for_deletion():
				continue
			entity.visible = _is_entity_lit(entity, zones, player)


func _restore_all_visible() -> void:
	if _vis_restored:
		return
	_vis_restored = true
	for group in ["zombies", "npcs"]:
		for entity in get_tree().get_nodes_in_group(group):
			if is_instance_valid(entity):
				entity.visible = true


var _vis_restored := true


# 收集当前所有发光判定区域：{pos, radius} 点光 + {pos, dir, range, angle} 锥光（手电筒）
# 纯数据判定，不依赖真实光源节点
func _collect_light_zones(player: Node3D) -> Dictionary:
	var points: Array = []
	if bool(player.get("_nv_on")):
		points.append({"pos": player.global_position, "radius": 12.0})
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if not bool(vehicle.get("headlights_on")):
			continue
		var fwd: Vector3 = vehicle.global_transform.basis.z
		points.append({
			"pos": vehicle.global_position + fwd * 4.0, "radius": 11.0
		})
	for defense in get_tree().get_nodes_in_group("base_defense"):
		if bool(defense.get_meta("lamp_on", false)):
			points.append({"pos": defense.global_position, "radius": 9.0})
	var cones: Array = []
	if (
		bool(player.get("_flashlight_on"))
		and not bool(player.get("_dead"))
		and player.get("vehicle") == null
	):
		cones.append({
			"pos": player.global_position,
			"dir": -player.global_transform.basis.z,
			"range": 20.0,
			"angle": 40.0,
		})
	return {"points": points, "cones": cones}


func _is_entity_lit(entity: Node3D, zones: Dictionary, player: Node3D) -> bool:
	var pos: Vector3 = entity.global_position
	if pos.distance_to(player.global_position) <= VIS_PLAYER_RADIUS:
		return true
	for zone in zones["points"]:
		if pos.distance_to(zone["pos"]) <= float(zone["radius"]):
			return true
	for cone in zones["cones"]:
		var to_entity: Vector3 = pos - cone["pos"]
		to_entity.y = 0.0
		var dist: float = to_entity.length()
		if dist > float(cone["range"]) or dist < 0.1:
			continue
		var dir: Vector3 = cone["dir"]
		dir.y = 0.0
		dir = dir.normalized()
		if rad_to_deg(acos(clampf(dir.dot(to_entity / dist), -1.0, 1.0))) <= float(cone["angle"]):
			return true
	return false


func _build_ground() -> void:
	var size := Vector3(GameState.CITY_SIZE.x * SCALE, 1.0, GameState.CITY_SIZE.y * SCALE)
	_add_static_box(Vector3(size.x / 2.0, -0.5, size.z / 2.0), size, Color(0.22, 0.24, 0.2))


func _build_roads() -> void:
	for r: Rect2 in GameState.ROADS:
		var center := Vector3(
			(r.position.x + r.size.x / 2.0) * SCALE,
			0.02,
			(r.position.y + r.size.y / 2.0) * SCALE
		)
		_add_visual_box(center, Vector3(r.size.x * SCALE, 0.04, r.size.y * SCALE), Color(0.12, 0.12, 0.13))
		var sidewalk := Color(0.52, 0.52, 0.55)
		if r.size.x > r.size.y:
			var top_z := r.position.y * SCALE + 0.4
			var bot_z := (r.position.y + r.size.y) * SCALE - 0.4
			_add_visual_box(Vector3(center.x, 0.035, top_z), Vector3(r.size.x * SCALE, 0.07, 0.8), sidewalk)
			_add_visual_box(Vector3(center.x, 0.035, bot_z), Vector3(r.size.x * SCALE, 0.07, 0.8), sidewalk)
		else:
			var left_x := r.position.x * SCALE + 0.4
			var right_x := (r.position.x + r.size.x) * SCALE - 0.4
			_add_visual_box(Vector3(left_x, 0.035, center.z), Vector3(0.8, 0.07, r.size.y * SCALE), sidewalk)
			_add_visual_box(Vector3(right_x, 0.035, center.z), Vector3(0.8, 0.07, r.size.y * SCALE), sidewalk)
		_build_road_tiles(r)
	_build_road_multimeshes()

# 批次 37：在纯色路底+人行道之上平铺 SYNTY 路面网格（只加视觉，不加碰撞；
# GameState.ROADS、小地图、刷怪判定一律不动）。直道沿长轴按实测件尺寸(5m=100px)重复，
# 交叉口区放 Crossing 斑马线件，直道 12% 概率撒 Lines 车道线件。
# 性能：3700+ 瓦片若逐块建 MeshInstance3D 节点，FPS 93.9→42.7（实测）；
# 改按件型合批为 MultiMeshInstance3D（9 种件 = 9 个节点，路面件均为单表面单材质，
# material_override 即可还原配色），瓦片变换累积在 _road_mm
func _build_road_tiles(r: Rect2) -> void:
	var horizontal := r.size.x > r.size.y
	# 路面件落在人行道条之间：净宽 = 路宽 506 − 2×16px 人行道
	var net := (r.size.y if horizontal else r.size.x) - 32.0
	var lanes := maxi(1, int(floor(net / ROAD_TILE_STEP_PX)))
	var lane_w := net / float(lanes)
	var along := r.size.x if horizontal else r.size.y
	var start := r.position.x if horizontal else r.position.y
	var cross_start := (r.position.y if horizontal else r.position.x) + 16.0
	var t := start
	while t < start + along - 0.01:
		var c := t + ROAD_TILE_STEP_PX / 2.0
		for lane in lanes:
			var center := Vector2(
				c if horizontal else cross_start + lane_w * (float(lane) + 0.5),
				cross_start + lane_w * (float(lane) + 0.5) if horizontal else c
			)
			# 瓦片中心落在垂直方向另一条路内 = 交叉口区
			var inside_perp := false
			for other: Rect2 in GameState.ROADS:
				if other == r:
					continue
				if (other.size.x < other.size.y) != horizontal and other.has_point(center):
					inside_perp = true
					break
			if not horizontal and inside_perp:
				# 交叉口由横向路的斑马线件覆盖，纵向路跳过避免双层叠瓦
				continue
			_place_road_tile(center, 0.0 if horizontal else PI / 2.0, lane_w, inside_perp, r)
		t += ROAD_TILE_STEP_PX


func _place_road_tile(center_px: Vector2, rot_y: float, lane_w: float, crossing: bool, road: Rect2) -> void:
	var pool: Array = ROAD_STRAIGHT_MODELS
	if crossing:
		pool = ROAD_CROSSING_MODELS
	elif randf() < 0.12:
		pool = ROAD_LINE_MODELS
	var path: String = pool[randi() % pool.size()]
	if not ResourceLoader.exists(path):
		return
	var cross_scale := lane_w / ROAD_TILE_STEP_PX
	# 与节点版一致：transform = T * R * S，横向按车道宽微拉伸吸附人行道内缘
	var t := Transform3D(
		Basis(Vector3.UP, rot_y).scaled(Vector3(1.0, 1.0, cross_scale)),
		Vector3(center_px.x * SCALE, ROAD_TILE_Y, center_px.y * SCALE)
	)
	# 按 (所在路, 件型) 分桶：每条路一个 MultiMesh，AABB 与路矩形一致，
	# 镜头外整条路的实例被视锥剔除一次跳过（全图一桶时永不剔除）。
	# 注：曾试按 36m 段细分（~576 个 MultiMesh），节点开销抵消剔除收益，回退到按路
	var key := "%s|%s" % [road, path]
	if not _road_mm.has(key):
		_road_mm[key] = []
	_road_mm[key].append(t)
	_road_tile_rects.append(Rect2(
		center_px - Vector2(ROAD_TILE_STEP_PX / 2.0, lane_w / 2.0),
		Vector2(ROAD_TILE_STEP_PX, lane_w)
	))


# 全部 ROADS 平铺完成后，按 (路, 件型) 合批建 MultiMeshInstance3D
func _build_road_multimeshes() -> void:
	for key in _road_mm:
		var path := String(key).split("|")[1]
		var data := _road_piece_data(path)
		if data.is_empty():
			continue
		var transforms: Array = _road_mm[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data["mesh"]
		mm.instance_count = transforms.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mats: Array = data["mats"]
		if not mats.is_empty() and mats[0] != null:
			mmi.material_override = mats[0]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])


# 路面件的 mesh/材质只从预制体提取一次（避免几千次实例化+剥碰撞）
func _road_piece_data(path: String) -> Dictionary:
	if _road_piece_cache.has(path):
		return _road_piece_cache[path]
	var data := {}
	if ResourceLoader.exists(path):
		var packed = load(path)
		if packed != null:
			var node: Node3D = packed.instantiate()
			var mi := node as MeshInstance3D
			if mi == null:
				var found := node.find_children("*", "MeshInstance3D", true, false)
				if not found.is_empty():
					mi = found[0] as MeshInstance3D
			if mi != null and mi.mesh != null:
				var mats: Array = []
				for s in mi.mesh.get_surface_count():
					mats.append(mi.get_surface_override_material(s))
				data = {"mesh": mi.mesh, "mats": mats}
			node.free()
	_road_piece_cache[path] = data
	return data


func _build_buildings() -> void:
	for i in GameState.BUILDING_LAYOUT.size():
		_build_building(GameState.BUILDING_LAYOUT[i], i)


# 批次 38：地标 id → SYNTY 模型路径（house 按栋号轮换三种民居）
func _landmark_model_path(id: String, index: int) -> String:
	if id == "house":
		return APOCO_BLD + ["SM_Bld_House_01.tscn", "SM_Bld_House_02.tscn", "SM_Bld_House_03.tscn"][index % 3]
	return String(LANDMARK_MODELS.get(id, APOCO_BLD + "SM_Bld_Commercial_Medium_01.tscn"))


# 批次 39：SYNTY 预制体的 AABB 多数不在原点上（实测偏 1~8 米），直接把节点原点摆到目标点
# 会让视觉楼体相对碰撞盒偏移好几米。这里先设缩放/旋转 → 量一次实际世界 AABB → 平移到
# 「XZ 中心对齐目标、底贴地」，并返回最终 AABB，供盒式碰撞/遮挡矩形/招牌精确贴合。
func _snap_model_to(node: Node3D, target_xz: Vector2, factor: float, yaw: float) -> AABB:
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	node.position = Vector3.ZERO
	var m := _combined_aabb(node)
	# target_xz 是 Vector2：.x = 世界 X、.y = 世界 Z
	node.position = Vector3(
		target_xz.x - (m.position.x + m.size.x * 0.5),
		-m.position.y,
		target_xz.y - (m.position.z + m.size.z * 0.5)
	)
	return AABB(
		Vector3(target_xz.x - m.size.x * 0.5, 0.0, target_xz.y - m.size.z * 0.5),
		m.size
	)


# 批次 38：加载 SYNTY 模型铺满给定占地（等比缩放 + 限高），楼体实心——
# 剥掉自带凹面碰撞，改用与模型视觉**精确贴合**的盒式碰撞（批次 39：不再铺满整块占地，
# 消除"模型缩到贴合、碰撞却铺满占地"造成的隐形墙；批次 39 同时修复模型不居中的偏移）。
# 返回模型最终世界 AABB（供招牌定位与遮挡矩形对齐）；模型缺失时退回纯色盒子，语义不丢
func _place_landmark_model(path: String, center: Vector3, footprint: Vector2, max_h: float) -> AABB:
	var node: Node3D = null
	if ResourceLoader.exists(path):
		var packed = load(path)
		if packed != null:
			node = packed.instantiate()
	var aabb := AABB()
	if node != null:
		for b in node.find_children("*", "StaticBody3D", true, false):
			b.free()
		add_child(node)
		aabb = _combined_aabb(node)
		if aabb.size.y <= 0.01:
			node.queue_free()
			node = null
	if node == null:
		_add_static_box(
			center + Vector3(0.0, max_h / 2.0, 0.0),
			Vector3(footprint.x, max_h, footprint.y),
			Color(0.5, 0.5, 0.55)
		)
		return AABB(
			center - Vector3(footprint.x * 0.5, 0.0, footprint.y * 0.5),
			Vector3(footprint.x, max_h, footprint.y)
		)
	# 占地长宽比不一致时转 90° 贴合（等比缩放不拉伸模型）
	var wide := aabb.size.x
	var deep := aabb.size.z
	var yaw := 0.0
	if (footprint.x > footprint.y) != (wide > deep):
		yaw = PI / 2.0
		var tmp := wide
		wide = deep
		deep = tmp
	var factor := minf(footprint.x / wide, footprint.y / deep)
	if aabb.size.y * factor > max_h:
		factor = max_h / aabb.size.y
	var final_aabb := _snap_model_to(node, Vector2(center.x, center.z), factor, yaw)
	node.add_to_group("occludable")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = final_aabb.size
	shape.shape = box
	body.add_child(shape)
	body.position = final_aabb.get_center()
	add_child(body)
	return final_aabb


func _build_building(entry: Dictionary, index: int) -> void:
	var before := get_child_count()
	var id: String = entry["id"]
	var cfg: Dictionary = GameState.BUILDINGS[id]
	var pos: Vector2 = entry["position"]
	var size2d: Vector2 = entry["size"]
	var center := Vector3(pos.x * SCALE, 0.0, pos.y * SCALE)
	var width := size2d.x * SCALE
	var depth := size2d.y * SCALE
	var height := _building_height(id)

	# 批次 38：整栋换 SYNTY 模型——实心楼，没有门洞/内构；
	# 坐标/占地/物资表/角色沿用 BUILDING_LAYOUT 与 BUILDINGS 配置不变
	var model_aabb := _place_landmark_model(
		_landmark_model_path(id, index), center, Vector2(width, depth), height
	)

	var sign_label := Label3D.new()
	sign_label.text = cfg["name"]
	sign_label.font_size = 96
	# 批次 39：招牌贴模型实际前沿（模型常比占地小，按占地摆会悬在楼前半空）
	sign_label.position = Vector3(center.x, model_aabb.size.y + 1.2, model_aabb.end.z + 0.1)
	add_child(sign_label)

	var door := BaseDoor.new()
	door.building_id = id
	door.building_name = String(cfg["name"])
	# 批次 42：搜刮建筑——门挂上本栋的 loot 表与一次性标记 key（像素坐标）
	door.loot_table = _loot_table_for(id)
	door.scavenge_key = pos
	add_child(door)
	door.position = center + Vector3(0, 0.05, depth / 2.0 + 1.2)
	# 交互占地用模型实际包围盒（视觉=碰撞=交互三者对齐）：
	# 模型可能因长宽比换向转 90°，按配置占地算会让门口落到空地上
	door.footprint_half = Vector2(model_aabb.size.x, model_aabb.size.z) / 2.0 + Vector2(0.6, 0.6)
	door.reach_center_offset = model_aabb.get_center() - door.position

	# 功能性生成保留（批次 38 起全部在楼外）：商品/店员/警察在门前，加油站前庭保留油泵，
	# 军营保留警戒线/哨戒机枪/驻军（在楼外一圈）
	_fill_building(cfg, center, width, depth)
	if id == "gas":
		_build_gas_forecourt(center, depth)
	if id == "military":
		_furnish_military(center, width, depth)
	_add_loot_spots(id, center, width, depth)
	# 登记本栋建筑的全部节点，碰撞体打上索引供拆除玩法识别
	var parts: Array = []
	for i in range(before, get_child_count()):
		var child := get_child(i)
		parts.append(child)
		if child is StaticBody3D:
			child.set_meta("demolish_building", index)
	_building_parts[index] = parts
	# 批次 39：遮挡/推挤矩形用模型实际范围（按占地算会比视觉大一圈，推挤作用在空地上）
	occl_buildings.append({
		"rect": Rect2(model_aabb.position.x, model_aabb.position.z, model_aabb.size.x, model_aabb.size.z),
		"parts": parts,
		"shells": [],
	})
	# 斜俯视角遮挡标记：整栋登记，挡住玩家相机时整体淡出
	for part in parts:
		if part is StaticBody3D or part is MeshInstance3D:
			part.add_to_group("occludable")


# 批次 42：战利品改由 BaseDoor 的"搜刮建筑"一次性产出（loot_table_for 给门挂上 loot 表），
# 本函数只保留肉鸽建材堆；max_containers/max_items 形参保留以兼容既有调用签名，已不使用
func _add_loot_spots(id: String, center: Vector3, width: float, depth: float, max_containers := 3, max_items := 2) -> void:
	# 肉鸽模式：每栋建筑额外放 1~2 个建材堆（守营建造消耗大）
	if GameState.rogue_mode:
		for i in randi_range(1, 2):
			var pile = MATERIAL_PILE_SCENE.instantiate()
			pile.amount = randi_range(10, 25)
			add_child(pile)
			pile.global_position = _loot_outside_pos(center, width, depth)


# 建筑 id → loot 表映射（批次 42 从 _add_loot_spots 抽出，供 BaseDoor.loot_table 使用）
func _loot_table_for(id: String) -> String:
	match id:
		"food":
			return "market"
		"gun":
			return "gun"
		"hospital":
			return "medical"
		"police":
			return "gun"
		"bank", "prison":
			return "valuable"
		"house":
			return "house"
		"gas":
			return "market"
		"power":
			return "warehouse"
		"tower":
			# 塔楼是公寓楼/写字楼/酒店，用办公室物资表（咖啡/现金/金盒/杂物）
			return "office"
	return "house"


# 批次 38：楼体改为实心 SYNTY 模型（无内构），搜刮点挪到占地矩形外一圈——
# 四条边随机取点、外扩 1.2~3.0m，保证实心楼/模型楼也够得到
func _loot_outside_pos(center: Vector3, width: float, depth: float) -> Vector3:
	var pos := center
	var out := randf_range(1.2, 3.0)
	var along := randf_range(-0.45, 0.45)
	match randi() % 4:
		0:
			pos += Vector3(along * width, 0.0, depth / 2.0 + out)
		1:
			pos += Vector3(along * width, 0.0, -depth / 2.0 - out)
		2:
			pos += Vector3(width / 2.0 + out, 0.0, along * depth)
		_:
			pos += Vector3(-width / 2.0 - out, 0.0, along * depth)
	return pos


# 批次 41：删除 _add_outdoor_loot（30% 额外户外容器 + 散落 loot_item）——
# 建筑战利品改由 BaseDoor 的"搜刮建筑"一次性产出（批次 42），不再有第二处散落来源。


# 批次 38：实心楼没有室内——货架商品沿前门外侧摆一排，店员/警察站门口外侧（离墙 1.6~2.6m）
func _fill_building(cfg: Dictionary, center: Vector3, width: float, depth: float) -> void:
	# 批次 41：货架商品/柜子不再作为独立道具摆到楼外（其战利品并入建筑搜刮，批次 42 起挂在门上），
	# 实心楼外只保留店员/警察站在门口
	for i in int(cfg["clerks"]):
		_spawn_npc_at(Vector3(center.x - 2.0 + i * 2.0, 0.05, center.z + depth / 2.0 + 2.2), "clerk")
	for i in int(cfg["cops"]):
		_spawn_npc_at(Vector3(center.x + 2.0 + i * 2.0, 0.05, center.z + depth / 2.0 + 2.6), "cop")


# 军营：警戒线 + 四角哨戒重机枪 + 驻军（独立脚本）
func _furnish_military(center: Vector3, width: float, depth: float) -> void:
	var base := Node3D.new()
	base.set_script(load("res://scripts3d/military_base3d.gd"))
	base.setup(center, width, depth)
	add_child(base)


# 加油站前庭：雨棚 + 双油泵岛 + 立式招牌，全部在店门外的空地上
func _build_gas_forecourt(center: Vector3, depth: float) -> void:
	var fore_z := center.z + depth / 2.0 + 4.2
	var red := Color(0.8, 0.18, 0.1)
	var white := Color(0.9, 0.9, 0.88)
	var steel := Color(0.55, 0.57, 0.6)
	# 雨棚：四根立柱 + 平顶
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_static_box(
				Vector3(center.x + sx * 3.4, 2.0, fore_z + sz * 1.9),
				Vector3(0.28, 4.0, 0.28),
				steel
			)
	_add_visual_box(
		Vector3(center.x, 4.15, fore_z),
		Vector3(8.2, 0.3, 5.0),
		white
	)
	_add_visual_box(
		Vector3(center.x, 4.0, fore_z),
		Vector3(8.2, 0.14, 5.0),
		red
	)
	# 双油泵岛：基座 + 红白泵体 + 黑色显示屏
	for sx in [-1.0, 1.0]:
		var px: float = center.x + sx * 2.2
		_add_static_box(
			Vector3(px, 0.1, fore_z),
			Vector3(1.4, 0.2, 2.2),
			Color(0.45, 0.45, 0.48)
		)
		_add_static_box(
			Vector3(px, 0.95, fore_z),
			Vector3(0.7, 1.5, 0.5),
			red
		)
		_add_visual_box(
			Vector3(px, 1.35, fore_z),
			Vector3(0.74, 0.3, 0.54),
			white
		)
		_add_visual_box(
			Vector3(px, 1.0, fore_z + 0.26),
			Vector3(0.4, 0.3, 0.02),
			Color(0.08, 0.08, 0.1)
		)
	# 路边立式招牌：高杆 + 橙红灯箱
	_add_static_box(
		Vector3(center.x + 4.6, 2.6, fore_z + 2.2),
		Vector3(0.22, 5.2, 0.22),
		steel
	)
	_add_visual_box(
		Vector3(center.x + 4.6, 5.4, fore_z + 2.2),
		Vector3(1.5, 1.1, 0.3),
		Color(0.95, 0.45, 0.1)
	)
	# 油泵交互点：车开到雨棚下，下车按 E 加油
	var pump := Node3D.new()
	pump.set_script(GAS_PUMP_SCRIPT)
	add_child(pump)
	pump.position = Vector3(center.x, 0.0, fore_z)
	# 前庭角落刷两桶汽油（燃料来源之一）
	for i in 2:
		var can = PICKUP_SCENE.instantiate()
		can.kind = "fuel"
		can.amount = 20
		can.item_name = "汽油桶"
		add_child(can)
		can.global_position = Vector3(center.x - 4.2 + i * 0.7, 0.05, fore_z + 1.6)


func _building_height(id: String) -> float:
	match id:
		"bank":
			return 12.0
		"police":
			return 10.0
		"house":
			return 6.0
		"gas":
			return 5.0
		"power":
			return 9.0
		_:
			return 8.0


func _build_towers() -> void:
	for i in GameState.TOWERS.size():
		_build_tower(GameState.TOWERS[i], i)


func _build_tower(tower: Dictionary, index: int) -> void:
	var before := get_child_count()
	var pos: Vector2 = tower["position"]
	var size2d: Vector2 = tower["size"]
	var height: float = tower["height"]
	var width := size2d.x * SCALE
	var depth := size2d.y * SCALE
	var center := Vector3(pos.x * SCALE, 0.0, pos.y * SCALE)

	# 批次 38：塔楼整栋换 SYNTY 摩天楼模型——实心楼，没有大堂/楼梯间/外壳；
	# 坐标/占地/高度沿用 TOWERS 配置不变（限高沿用塔楼 height）
	var model_aabb := _place_landmark_model(
		SKYSCRAPER_MODELS[index % SKYSCRAPER_MODELS.size()],
		center, Vector2(width, depth), height
	)

	var tower_name := "%s %d号" % [["公寓楼", "写字楼", "酒店"][index % 3], index + 1]
	var sign_label := Label3D.new()
	sign_label.text = tower_name
	sign_label.font_size = 64
	sign_label.position = center + Vector3(0, 3.5, depth / 2.0 + 0.1)
	add_child(sign_label)
	# 批次 34：塔楼据点交互点。距离按塔楼占地矩形算——塔楼体量大，只认门口点会让侧面接近失效
	var tower_door := BaseDoor.new()
	tower_door.building_id = "tower"
	tower_door.building_name = tower_name
	# 占地用模型实际包围盒（模型可能换向旋转，配置尺寸会错位）
	tower_door.footprint_half = Vector2(model_aabb.size.x, model_aabb.size.z) / 2.0 + Vector2(0.6, 0.6)
	tower_door.reach_center_offset = model_aabb.get_center() - (
		center + Vector3(0.0, 0.05, depth / 2.0 + 1.2)
	)
	# 批次 42：搜刮建筑——塔楼用 office 表，一次性标记 key 为像素坐标
	tower_door.loot_table = _loot_table_for("tower")
	tower_door.scavenge_key = pos
	add_child(tower_door)
	tower_door.position = center + Vector3(0.0, 0.05, depth / 2.0 + 1.2)
	_tower_doors.append(tower_door)

	# 斜俯视角遮挡标记：整栋登记，挡住玩家相机时整体淡出（实心楼 shells 留空）
	var tower_parts: Array = []
	for i in range(before, get_child_count()):
		var child := get_child(i)
		tower_parts.append(child)
		if child is StaticBody3D or child is MeshInstance3D:
			child.add_to_group("occludable")
	# 批次 39：遮挡/推挤矩形用模型实际范围（同地标）
	occl_buildings.append({
		"rect": Rect2(model_aabb.position.x, model_aabb.position.z, model_aabb.size.x, model_aabb.size.z),
		"parts": tower_parts,
		"shells": [],
	})
	# 肉鸽建材堆（批次 42 起战利品改由门的"搜刮建筑"产出，这里只剩建材堆）。
	_add_loot_spots("tower", center, width, depth)


func _build_model_city() -> void:
	var reserved: Array = []
	for entry in GameState.BUILDING_LAYOUT:
		reserved.append(Rect2(
			entry["position"] - entry["size"] / 2.0 - Vector2(70, 70),
			entry["size"] + Vector2(140, 140)
		))
	for tower in GameState.TOWERS:
		reserved.append(Rect2(
			tower["position"] - tower["size"] / 2.0 - Vector2(50, 50),
			tower["size"] + Vector2(100, 100)
		))
	# 批次 172：道路禁建带收窄（grow 50→20px）——建筑贴街沿街排满；
	# 20px 缓冲防止建筑碰撞体压到路面（道路本体 Rect 已含 506px 路宽）
	for r: Rect2 in GameState.ROADS:
		reserved.append(r.grow(20.0))
	for station in GameState.BASE_STATIONS:
		reserved.append(Rect2(station["position"] - Vector2(130, 130), Vector2(260, 260)))
	for spot in [Vector2(1265, 1739), Vector2(2846, 1739), Vector2(6640, 1739),
			Vector2(2213, 3573), Vector2(6640, 3573), Vector2(9450, 1739),
			Vector2(12750, 3573), Vector2(2846, 7450)]:
		reserved.append(Rect2(spot - Vector2(90, 90), Vector2(180, 180)))
	reserved.append(Rect2(GameState.SPAWN_POS - Vector2(180, 180), Vector2(360, 360)))

	# 批次 37：加密建筑——slot 520→320、grow(40)→20。
	# 注意 320+2×20=360 仍大于格距 320，相邻格互斥（隔一放一）依旧成立；
	# 该密度下模拟落位 117 栋（探针 _tmp_probe_sim 实测），满足 ≥100
	var slot := 320.0
	var half := slot / 2.0
	var y := 260.0
	var dbg_attempt := 0
	var dbg_overlap := 0
	var dbg_fail := 0
	var dbg_ok := 0
	while y < GameState.CITY_SIZE.y - 260.0:
		var x := 260.0
		while x < GameState.CITY_SIZE.x - 260.0:
			var rect := Rect2(Vector2(x - half, y - half), Vector2(slot, slot))
			dbg_attempt += 1
			if _overlaps_any(rect, reserved):
				dbg_overlap += 1
			# 批次 172：全城小建筑沿街排布（不再留 old_core 空区）——
			# 手建地标/道路/基站等保留区照常避让；slot+grow 的互斥保证
			# 相邻格隔一放一，即「建筑之间相隔一个建筑的距离」。
			# 分区落位：南侧=住宅（掺 20% 商业）；东北带=军事前哨；中带=工业；其余=商业。
			# 原东侧商务高楼（DOWNTOWN 20~44m）已删除，全城统一为小建筑（≤16m）。
			if not _overlaps_any(rect, reserved):
				var south := y > 5700.0
				var path := ""
				var height := 10.0
				var loot_id := "house"
				if south:
					if randf() < 0.8:
						path = RESIDENTIAL_MODELS[randi() % RESIDENTIAL_MODELS.size()]
						height = randf_range(6.0, 11.0)
						loot_id = "house"
					else:
						path = COMMERCIAL_MODELS[randi() % COMMERCIAL_MODELS.size()]
						height = randf_range(9.0, 16.0)
						loot_id = "food"
				elif x >= 8100.0 and x <= 9150.0 and y < 4560.0:
					path = MILITARY_MODELS[randi() % MILITARY_MODELS.size()]
					height = randf_range(3.5, 9.0)
					loot_id = "police"
				elif y >= 4560.0 and x <= 9700.0:
					path = INDUSTRIAL_MODELS[randi() % INDUSTRIAL_MODELS.size()]
					height = randf_range(8.0, 16.0)
					loot_id = "power"
				else:
					path = COMMERCIAL_MODELS[randi() % COMMERCIAL_MODELS.size()]
					height = randf_range(9.0, 16.0)
					loot_id = "food"
				if _place_model(path, Vector2(x, y), height, loot_id):
					reserved.append(rect.grow(20.0))
					dbg_ok += 1
				else:
					_model_failures.append(path)
					dbg_fail += 1
			x += slot
		y += slot
	print("MODELCITY attempt=%d overlap=%d ok=%d fail=%d" % [dbg_attempt, dbg_overlap, dbg_ok, dbg_fail])


func _place_model(path: String, pos_px: Vector2, target_height: float, loot_id := "house") -> bool:
	if not ResourceLoader.exists(path):
		return false
	var packed = load(path)
	if packed == null:
		return false
	var node: Node3D = packed.instantiate()
	# Synty 预制体自带凹面碰撞体，几百栋楼全挂上去物理开销太大；
	# 这里剥掉，统一用下方自建的盒式碰撞
	for body in node.find_children("*", "StaticBody3D", true, false):
		body.free()
	add_child(node)
	# 批次 37：模型楼不投影——百余栋楼进阴影Pass是 FPS 成本主项（实测 +9 FPS），
	# 手建楼/塔楼的盒式阴影保持原样
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for _mi in node.find_children("*", "MeshInstance3D", true, false):
		(_mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var aabb := _combined_aabb(node)
	if aabb.size.y <= 0.01:
		node.queue_free()
		return false
	var factor := target_height / aabb.size.y
	# 批次 37：限宽——宽体模型按目标高度缩放后占地会溢出格位压到邻楼，钳宽后高度等比下调
	var wide := maxf(aabb.size.x, aabb.size.z)
	if wide * factor > MODEL_MAX_FOOTPRINT:
		factor = MODEL_MAX_FOOTPRINT / wide
	# 批次 39：先定朝向再精确落位——原实现有两处 bug：
	# ① rotated 随机数与实际旋转角是两次独立随机，footprint 换向可能与真实旋转对不上；
	# ② 只把节点原点摆过去、未补偿模型 AABB 偏移，视觉楼体偏离碰撞盒数米。
	var yaw := (PI / 2.0) * float(randi() % 4)
	var final_aabb := _snap_model_to(node, Vector2(pos_px.x * SCALE, pos_px.y * SCALE), factor, yaw)
	node.add_to_group("occludable")
	var footprint := Vector2(final_aabb.size.x, final_aabb.size.z)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = final_aabb.size
	shape.shape = box
	body.add_child(shape)
	body.position = final_aabb.get_center()
	add_child(body)
	var rect_size := footprint / SCALE
	_model_rects.append(Rect2(pos_px - rect_size / 2.0, rect_size))
	GameState.map_building_rects.append(Rect2(pos_px - rect_size / 2.0, rect_size))
	occl_buildings.append({
		"rect": Rect2(final_aabb.position.x, final_aabb.position.z, footprint.x, footprint.y),
		"parts": [node, body],
	})
	# 模型城市建筑补交互点：原先只有碰撞盒，玩家走到这样的楼房跟前既没有 E 提示也无法交互。
	# 复用建筑门口的 BaseDoor 协议（占领为据点 / 据点睡觉存物），距离按占地矩形算——
	# 模型是随机朝向的 .glb，只认一个门口点会让大部分侧面接近都失效
	var door := BaseDoor.new()
	door.building_id = "model"
	door.building_name = _model_building_name(path)
	door.footprint_half = footprint / 2.0 + Vector2(0.6, 0.6)
	# 门放在楼前（据点旗子/建造圆心落在楼外），占地中心对齐碰撞盒实际中心
	door.reach_center_offset = final_aabb.get_center() - Vector3(
		pos_px.x * SCALE, 0.05, pos_px.y * SCALE + footprint.y / 2.0 + 1.2
	)
	# 批次 42：搜刮建筑——模型楼挂 loot 表与一次性标记 key（像素坐标）
	door.loot_table = _loot_table_for(loot_id)
	door.scavenge_key = pos_px
	add_child(door)
	door.position = Vector3(
		pos_px.x * SCALE, 0.05, pos_px.y * SCALE + footprint.y / 2.0 + 1.2
	)
	# 批次 34：登记为可拆除结构（碰撞盒 meta 供拆除瞄准命中，登记表供挖库存/爆炸扣血/坍塌共用）
	body.set_meta("demolish_model", _model_structures.size())
	_model_structures.append({
		"pos": pos_px,
		"size": rect_size,
		"parts": [node, body, door],
	})
	# 批次 42：模型楼战利品改由门上"搜刮建筑"产出（loot 表沿用 _loot_table_for 既有 match 分支：
	# 住宅 house / 商务 office(经 tower) / 商业 market(经 food) / 工业 warehouse(经 power) / 军事 gun(经 police)）。
	# _add_loot_spots 现只负责肉鸽建材堆；阴影关闭循环保留（建材堆小件进阴影 Pass 仍有开销）
	var loot_before := get_child_count()
	_add_loot_spots(loot_id, Vector3(pos_px.x * SCALE, 0.0, pos_px.y * SCALE), footprint.x, footprint.y, 2, 1)
	for i in range(loot_before, get_child_count()):
		var child := get_child(i)
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for mi in child.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 批次 41/42：删除 30% 概率的额外户外容器+散落物（_add_outdoor_loot）、删除搜刮容器——
	# 建筑战利品统一由 BaseDoor 的"搜刮建筑"一次性产出，地图上不再有箱子/散落物
	return true


# 模型城市建筑在交互菜单里的显示名（按模型来源分类）
func _model_building_name(path: String) -> String:
	if RESIDENTIAL_MODELS.has(path):
		return "居民楼"
	if DOWNTOWN_MODELS.has(path):
		return "写字楼"
	if INDUSTRIAL_MODELS.has(path):
		return "工业楼"
	if MILITARY_MODELS.has(path):
		return "军事设施"
	return "商业楼"


func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var started := false
	var _aabb_meshes: Array = []
	if root is MeshInstance3D:
		_aabb_meshes.append(root)
	_aabb_meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for child in _aabb_meshes:
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var box: AABB = mi.get_aabb()
		for i in 8:
			var point: Vector3 = mi.global_transform * box.get_endpoint(i)
			if not started:
				result = AABB(point, Vector3.ZERO)
				started = true
			else:
				result = result.expand(point)
	return result


func _overlaps_any(rect: Rect2, list: Array) -> bool:
	for other in list:
		if rect.intersects(other):
			return true
	return false


func _build_street_props() -> void:
	for i in 46:
		var p := Vector2(
			randf_range(300.0, GameState.CITY_SIZE.x - 300.0),
			randf_range(300.0, GameState.CITY_SIZE.y - 300.0)
		)
		if _inside_any_building(p):
			continue
		var clutter := _place_prop(PROP_CLUTTER[randi() % PROP_CLUTTER.size()], p, randf_range(0.8, 1.5))
		if clutter != null:
			_street_props.append(clutter)
	# 额外一批街道家具：路灯挑高，垃圾桶/栏杆按小物高度
	for i in STREET_FURNITURE_COUNT:
		var p := Vector2(
			randf_range(300.0, GameState.CITY_SIZE.x - 300.0),
			randf_range(300.0, GameState.CITY_SIZE.y - 300.0)
		)
		if _inside_any_building(p):
			continue
		var path: String = PROP_STREET_FURNITURE[randi() % PROP_STREET_FURNITURE.size()]
		var height := randf_range(0.9, 1.4)
		if path.contains("LightPole"):
			height = randf_range(4.0, 5.0)
		var furniture := _place_prop(path, p, height)
		if furniture != null:
			_street_props.append(furniture)
	_build_sidewalk_props()


# 批次 37(A4)：沿每条 ROADS 两侧人行道成排摆 SYNTY 街具（固定步进 ~220px，左右各一列）。
# 避开路口交叉区与 手建楼/塔楼/基站/刷点/出生点；可拆子集入 _street_props，
# 纯装饰只建节点不入组。总量由放置概率(0.40)控制，探针报实际数
func _build_sidewalk_props() -> void:
	var avoid: Array = []
	for entry in GameState.BUILDING_LAYOUT:
		avoid.append(Rect2(
			entry["position"] - entry["size"] / 2.0 - Vector2(60, 60),
			entry["size"] + Vector2(120, 120)
		))
	for tower in GameState.TOWERS:
		avoid.append(Rect2(
			tower["position"] - tower["size"] / 2.0 - Vector2(40, 40),
			tower["size"] + Vector2(80, 80)
		))
	for station in GameState.BASE_STATIONS:
		avoid.append(Rect2(station["position"] - Vector2(140, 140), Vector2(280, 280)))
	for spot in [Vector2(1265, 1739), Vector2(2846, 1739), Vector2(6640, 1739),
			Vector2(2213, 3573), Vector2(6640, 3573), Vector2(9450, 1739),
			Vector2(12750, 3573), Vector2(2846, 7450)]:
		avoid.append(Rect2(spot - Vector2(100, 100), Vector2(200, 200)))
	avoid.append(Rect2(GameState.SPAWN_POS - Vector2(200, 200), Vector2(400, 400)))
	var step := 220.0
	var placed_demolish := 0
	var placed_decor := 0
	for r: Rect2 in GameState.ROADS:
		var horizontal := r.size.x > r.size.y
		var along := r.size.x if horizontal else r.size.y
		var start := r.position.x if horizontal else r.position.y
		var t := start + step / 2.0
		while t < start + along - step / 2.0 + 0.01:
			for side in [-1.0, 1.0]:
				# 人行道条中线：路边缘内退 9px
				var p := Vector2(
					t if horizontal else r.position.x + r.size.x / 2.0 + side * (r.size.x / 2.0 - 9.0),
					r.position.y + r.size.y / 2.0 + side * (r.size.y / 2.0 - 9.0) if horizontal else t
				)
				# 路口交叉区留空（垂直方向另一条路外扩 30px）
				var blocked := false
				for other: Rect2 in GameState.ROADS:
					if other == r:
						continue
					if (other.size.x < other.size.y) != horizontal and other.grow(30.0).has_point(p):
						blocked = true
						break
				if not blocked and _overlaps_any(Rect2(p - Vector2(20, 20), Vector2(40, 40)), avoid):
					blocked = true
				if blocked or randf() > 0.40:
					continue
				var demolishable := randf() < 0.6
				var path := ""
				if demolishable:
					path = PROP_SIDEWALK_DEMOLISH[randi() % PROP_SIDEWALK_DEMOLISH.size()]
				else:
					path = PROP_SIDEWALK_DECOR[randi() % PROP_SIDEWALK_DECOR.size()]
				var node := _place_prop(path, p, _sidewalk_prop_height(path))
				if node == null:
					continue
				# 小物件不投影：几百个街具全投影会让阴影Pass绘制翻倍（实测 FPS 成本主项之一）
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for child in node.find_children("*", "MeshInstance3D", true, false):
					(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if demolishable:
					_street_props.append(node)
					placed_demolish += 1
				else:
					node.remove_from_group("street_props")
					# 大件（尤其停放车辆）沿道路走向摆放
					node.rotation.y = PI / 2.0 if horizontal else 0.0
					placed_decor += 1
			t += step
	print("SIDEWALK_PROPS demolish=%d decor=%d" % [placed_demolish, placed_decor])


func _sidewalk_prop_height(path: String) -> float:
	var file := path.get_file()
	if file.contains("LightPole"):
		return randf_range(4.2, 4.8)
	if file.contains("BusStop"):
		return randf_range(2.8, 3.1)
	if file.contains("Phones"):
		return 2.5
	if file.contains("Sign"):
		return randf_range(2.0, 2.3)
	if file.contains("Veh"):
		return randf_range(1.5, 1.7)
	if file.contains("ParkBench") or file.contains("Planter"):
		return randf_range(0.8, 1.0)
	if file.contains("DustBin"):
		return 0.6
	return randf_range(1.0, 1.3)


func _place_prop(path: String, pos_px: Vector2, target_height: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed = load(path)
	if packed == null:
		return null
	var node: Node3D = packed.instantiate()
	# 同 _place_model：剥掉 Synty 预制体自带碰撞，街道杂物不需要物理
	for body in node.find_children("*", "StaticBody3D", true, false):
		body.free()
	add_child(node)
	var aabb := _combined_aabb(node)
	if aabb.size.y <= 0.01:
		node.queue_free()
		return null
	# 扁平薄板件（Synty 招牌只有面板没有杆）：按高度缩放会放大几十倍糊满街区，
	# 立正后改按最大边缩放
	var max_xz := maxf(aabb.size.x, aabb.size.z)
	if aabb.size.y < 0.15 * max_xz:
		node.rotation.x = -PI / 2.0
		node.force_update_transform()
		aabb = _combined_aabb(node)
		max_xz = maxf(aabb.size.x, aabb.size.z)
		var flat_factor := target_height / maxf(max_xz, 0.01)
		node.scale = Vector3.ONE * flat_factor
		node.rotation.y = (PI / 2.0) * float(randi() % 4)
		node.position = Vector3(pos_px.x * SCALE, -aabb.position.y * flat_factor, pos_px.y * SCALE)
		node.add_to_group("street_props")
		return node
	var factor := target_height / aabb.size.y
	node.scale = Vector3.ONE * factor
	node.rotation.y = (PI / 2.0) * float(randi() % 4)
	node.position = Vector3(pos_px.x * SCALE, -aabb.position.y * factor, pos_px.y * SCALE)
	node.add_to_group("street_props")
	return node


func _build_boundaries() -> void:
	var w := GameState.CITY_SIZE.x * SCALE
	var h := GameState.CITY_SIZE.y * SCALE
	var t := 0.6
	var high := 6.0
	var color := Color(0.3, 0.3, 0.3)
	_add_static_box(Vector3(w / 2.0, high / 2.0, -t / 2.0), Vector3(w + t * 2.0, high, t), color)
	_add_static_box(Vector3(w / 2.0, high / 2.0, h + t / 2.0), Vector3(w + t * 2.0, high, t), color)
	_add_static_box(Vector3(-t / 2.0, high / 2.0, h / 2.0), Vector3(t, high, h), color)
	_add_static_box(Vector3(w + t / 2.0, high / 2.0, h / 2.0), Vector3(t, high, h), color)


func _build_stations() -> void:
	# 批次 145：地图自带基站（信号塔）已移除，信号塔改由玩家建造（任意位置）；
	# 玩家建造的信号塔与原基站同款模型（station3d.build_station_visual 共享）
	return


# 测试模式专用：出生地召唤全部车辆模型（含 APC 双皮肤）排开供查验
# 展示位是否无静态障碍：在离地 1.2m 处探一个 3×1.5×3 的盒（避开地面本身）
func _showcase_spot_clear(pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.5, 3.0)
	q.shape = box
	q.transform = Transform3D(Basis(), pos + Vector3(0, 1.2, 0))
	q.collide_with_areas = false
	return space.intersect_shape(q, 4).is_empty()


func _spawn_vehicle_showcase() -> void:
	var origin := Vector3(
		GameState.SPAWN_POS.x * SCALE, 0.1, GameState.SPAWN_POS.y * SCALE
	) + Vector3(0, 0, 12.0)
	var script := load("res://scripts3d/vehicle3d.gd")
	var ids: Array = script.CAR_MODELS.duplicate()
	# APC 追加一辆二号皮肤
	ids.append("apc")
	for i in ids.size():
		var id: String = ids[i]
		var car = VEHICLE_SCENE.instantiate()
		# _build_visual 在 add_child 时按 net_id 定车型：先指到目标槽位再入树
		var slot := int(script.CAR_MODELS.find(id))
		car.net_id = slot if slot >= 0 else i
		# APC 展示双皮肤：原生那辆强制一号皮肤，追加一辆强制二号皮肤
		if id == "apc":
			car.force_visual_path = (
				script.APC_ALT_PATH if i >= script.CAR_MODELS.size()
				else String(script.CAR_MODEL_PATHS["apc"])
			)
		var place := origin + Vector3(
			(i % 4) * 6.5 - 9.75, 0.0, (i / 4) * 7.0
		)
		# 落位避障：格子被街道杂物等静态碰撞体占着就顺移让位，
		# 否则 spawn 即重叠、物理去重叠会把车挤进地下（直升机最宽最吃亏）
		for try_shift in 6:
			if _showcase_spot_clear(place):
				break
			place += Vector3(2.5, 0.0, 2.5)
		car.position = place
		car.set_meta("showcase", true)
		add_child(car)
		var label := Label3D.new()
		label.text = "%s (%s)" % [car.call("_vehicle_name"), id]
		label.font_size = 40
		label.modulate = Color(1.0, 0.9, 0.5)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = car.position + Vector3(0, 3.2, 0)
		add_child(label)
	GameState.notify("测试模式：出生地前方已召唤全部 %d 辆载具模型" % ids.size())


func _build_vehicles() -> void:
	var spots := [
		Vector2(1265, 1739), Vector2(2846, 1739), Vector2(6640, 1739),
		Vector2(2213, 3573), Vector2(6640, 3573), Vector2(9450, 1739),
		Vector2(12750, 3573), Vector2(2846, 7450),
	]
	for i in spots.size():
		var car = VEHICLE_SCENE.instantiate()
		car.position = Vector3(spots[i].x * SCALE, 0.1, spots[i].y * SCALE)
		car.net_id = (1 << 20) + i
		add_child(car)


# 批次 41：删除 _create_item / _shop_item_model / _item_color ——
# 楼外的货架商品柜子不再生成，战利品改由 BaseDoor 的"搜刮建筑"产出（批次 42）。
# 连带删除其独占常量 ITEM_SCRIPT 与 LOOT_ITEM_SCENE。


func _spawn_npc_at(pos: Vector3, role: String) -> void:
	if _client_mode():
		return
	var npc = NPC_SCENE.instantiate()
	npc.role = role
	npc.position = pos
	add_child(npc)


# 异能量场：全城随机 6 处异常区域（同种子确定，两端都建视觉）；
# 高浓度处在场中心凝结 1~2 颗异能结晶（仅主机生成，客户端走傀儡）
func _spawn_anomaly_crystals() -> void:
	var zone_script := load("res://scripts3d/anomaly_zone3d.gd")
	for i in 6:
		var pos := _random_free_pos()
		var zone := Node3D.new()
		zone.set_script(zone_script)
		zone.radius = randf_range(6.0, 9.0)
		zone.zone_id = i
		# 能量等级 1~3：越高刷怪越快越多越强，核心也更硬
		zone.energy = randi_range(1, 3)
		add_child(zone)
		zone.global_position = Vector3(pos.x, 0.0, pos.z)
		if _client_mode():
			continue
		for j in randi_range(1, 2):
			var crystal = PICKUP_SCENE.instantiate()
			crystal.kind = "anomaly"
			crystal.amount = 1
			crystal.item_name = "异能结晶"
			add_child(crystal)
			crystal.global_position = zone.global_position + Vector3(
				randf_range(-1.5, 1.5), 0.05, randf_range(-1.5, 1.5)
			)


# 肉鸽顺序关卡初始化：不预生成能量场，关卡 1 在准备期结束后由 _tick_rogue 生成
func _init_rogue_stages() -> void:
	_rogue_stage = 0
	_rogue_phase = "prep"
	_rogue_dev_timer = 0.0
	_rogue_zone = null
	_rogue_field_timer = 15.0
	_last_field_count = 0
	GameState.rogue_stage = 0
	GameState.rogue_phase = "prep"
	GameState.rogue_dev_left = 0.0
	GameState.rogue_cores_left = ROGUE_STAGES.size()


# 生成第 n 关的能量场（守关 Boss 由能量点激活后自生成）；超出最后一关则通关
func _start_rogue_stage(n: int) -> void:
	if n > ROGUE_STAGES.size():
		_win_rogue()
		return
	_rogue_stage = n
	_rogue_phase = "active"
	_rogue_zone = null
	GameState.rogue_stage = n
	GameState.rogue_phase = "active"
	GameState.rogue_cores_left = ROGUE_STAGES.size() - n + 1
	GameState.rogue_prep_left = 0.0
	GameState.rogue_dev_left = 0.0
	var cfg: Dictionary = ROGUE_STAGES[n - 1]
	var zone := Node3D.new()
	zone.set_script(load("res://scripts3d/anomaly_zone3d.gd"))
	zone.radius = randf_range(float(cfg["radius_min"]), float(cfg["radius_max"]))
	zone.zone_id = n - 1
	zone.energy = int(cfg["energy"])
	zone.active = true  # 立即激活：守关 Boss 由能量点自生成并锁定核心（批次1）
	zone.boss_field = true  # Boss 能量场：血量×50、刷怪留守并持续强化
	add_child(zone)
	# 生成在距主角 4 个街区（约64m）以上的位置，避免开局贴脸
	var min_dist := 64.0
	var player = get_tree().get_first_node_in_group("player")
	var pos := _random_free_pos()
	for attempt in 200:
		if player == null:
			break
		var d := Vector2(pos.x, pos.z).distance_to(
			Vector2(player.global_position.x, player.global_position.z)
		)
		if d >= min_dist:
			break
		pos = _random_free_pos()
	zone.global_position = Vector3(pos.x, 0.0, pos.z)
	_rogue_zone = zone
	GameState.notify("第 %d 关：%s 镇守的异常能量场出现了，先击败 Boss 再拆核心！" % [
		n, String(cfg["boss_name"])
	])
	GameState.rogue_progress_changed.emit()


# 当前关是否已清：守关 Boss 死 + 核心被拆（能量点 _shatter 后 queue_free）
func _rogue_stage_cleared() -> bool:
	if _rogue_zone == null:
		return false
	if not is_instance_valid(_rogue_zone):
		return true
	return bool(_rogue_zone.get("destroyed"))


# 进入发育期：安全窗口，刷怪停止（能量场已拆，下一关未生成）
func _enter_rogue_dev() -> void:
	_rogue_phase = "dev"
	GameState.rogue_phase = "dev"
	var cfg: Dictionary = ROGUE_STAGES[_rogue_stage - 1]
	_rogue_dev_timer = float(cfg["dev_days"]) * GameState.DAY_LENGTH
	GameState.rogue_dev_left = _rogue_dev_timer
	GameState.notify("第 %d 关已清除！发育期 %d 天：安全窗口，抓紧建设备战。" % [
		_rogue_stage, int(cfg["dev_days"])
	])
	GameState.rogue_progress_changed.emit()


# 发育期结束 → 推进到下一关
func _advance_rogue_stage() -> void:
	_start_rogue_stage(_rogue_stage + 1)


# 当前存活的普通能量场数量（不含 Boss 场）
func _rogue_field_count() -> int:
	var count := 0
	for zone in get_tree().get_nodes_in_group("anomaly_zones"):
		if zone.is_queued_for_deletion() or bool(zone.get("destroyed")):
			continue
		if bool(zone.get("boss_field")):
			continue
		count += 1
	return count


# 在营地附近随机刷一个普通能量场：持续刷怪袭营，不强化（区别于 Boss 场）
func _spawn_rogue_field() -> void:
	if not GameState.has_home_base():
		return
	var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
	var zone := Node3D.new()
	zone.set_script(load("res://scripts3d/anomaly_zone3d.gd"))
	zone.radius = randf_range(6.0, 9.0)
	zone.zone_id = 100 + randi() % 900
	zone.energy = randi_range(1, 2)
	zone.active = true
	add_child(zone)
	var placed := false
	# 能量场必须整圈落在城内：中心连同半径一起 clamp 进边界
	# （此前只查「不压建筑」，营地靠近地图边时会刷到城外）
	var margin: float = zone.radius + 1.5
	var max_x: float = GameState.CITY_SIZE.x * SCALE - margin
	var max_z: float = GameState.CITY_SIZE.y * SCALE - margin
	for attempt in 40:
		var angle := randf() * TAU
		var dist := randf_range(ROGUE_FIELD_MIN_DIST, ROGUE_FIELD_MAX_DIST)
		var p := Vector3(
			clampf(base_pos.x + cos(angle) * dist, margin, max_x),
			0.0,
			clampf(base_pos.z + sin(angle) * dist, margin, max_z)
		)
		if not _inside_any_building(Vector2(p.x / SCALE, p.z / SCALE)):
			zone.global_position = p
			placed = true
			break
	if not placed:
		zone.global_position = Vector3(
			clampf(base_pos.x + ROGUE_FIELD_MIN_DIST + 10.0, margin, max_x),
			0.0,
			clampf(base_pos.z, margin, max_z)
		)
	GameState.notify("营地附近出现新的异常能量场——尸群正在逼近营地！")


func _win_rogue() -> void:
	_rogue_won = true
	_rogue_phase = "won"
	GameState.rogue_phase = "won"
	GameState.end_run(true, "已清除全部能量场——第 %d 关通关，城市安全了！" % ROGUE_STAGES.size())


# 肉鸽模式：一半平民直接躲在建筑里（另一半照常散布室外，灾变后会自己逃进楼）
func _spawn_rogue_civilians_indoors() -> void:
	var rects: Array = GameState.map_building_rects
	if rects.is_empty():
		return
	for i in CITIZEN_COUNT / 2:
		var rect: Rect2 = rects[randi() % rects.size()]
		var center_px := rect.get_center()
		var npc = NPC_SCENE.instantiate()
		npc.role = "pedestrian"
		# 批次 38：楼体实心，市民刷在楼外街边（原楼心会卡进实心碰撞盒）
		var edge := center_px + Vector2(rect.size.x / 2.0 + 40.0, 0.0)
		npc.position = Vector3(edge.x * SCALE, 0.1, edge.y * SCALE)
		add_child(npc)


# 肉鸽节拍：准备期 → 第1关 →（拆场→发育期→下一关）→ 通关
func _tick_rogue(delta: float) -> void:
	if _rogue_won:
		return
	_tick_boss_jam(delta)
	if _rogue_phase == "prep":
		_rogue_prep -= delta
		GameState.rogue_prep_left = maxf(_rogue_prep, 0.0)
		if not GameState.rogue_hints_seen:
			if _rogue_hint_index < ROGUE_HINTS.size():
				_rogue_hint_timer -= delta
				if _rogue_hint_timer <= 0.0:
					GameState.notify("[新手提示] " + ROGUE_HINTS[_rogue_hint_index])
					_rogue_hint_index += 1
					_rogue_hint_timer = ROGUE_HINT_INTERVAL
			else:
				# 全部提示展示完 → 标记已看（仅首局显示）
				GameState.rogue_hints_seen = true
				GameState.save_meta()
		if _rogue_prep <= 0.0:
			# 准备期结束：提示若未播完也一并标记完成（首局引导）
			if not GameState.rogue_hints_seen:
				GameState.rogue_hints_seen = true
				GameState.save_meta()
			GameState.notify("异常能量点已激活——第 1 关开启！")
			_start_rogue_stage(1)
	elif _rogue_phase == "active":
		# 当前关进行中：丧尸随时间变强（反龟缩）；已建营地则定期给无目标丧尸补设袭营目标
		GameState.rogue_active_elapsed += delta
		_rogue_retarget_timer -= delta
		if _rogue_retarget_timer <= 0.0:
			_rogue_retarget_timer = 2.0
			if GameState.has_home_base():
				var base_pos: Vector3 = GameState.home_base.get("position", Vector3.ZERO)
				for zombie in get_tree().get_nodes_in_group("zombies"):
					if zombie.is_queued_for_deletion():
						continue
					# 守关 Boss 和 Boss 场留守怪不改目标（留守场边）
					if zombie.has_method("_guarding") and zombie._guarding():
						continue
					if zombie.get("assault_target") == Vector3.ZERO:
						zombie.assault_target = base_pos
		# 普通能量场：同时最多 3 个；检测到有场被拆 → 补生冷却 60 秒
		var field_alive := _rogue_field_count()
		if field_alive < _last_field_count:
			_rogue_field_timer = maxf(_rogue_field_timer, ROGUE_FIELD_RESPAWN_DELAY)
		_last_field_count = field_alive
		_rogue_field_timer -= delta
		if _rogue_field_timer <= 0.0:
			_rogue_field_timer = randf_range(20.0, 40.0)
			if _rogue_field_count() < ROGUE_FIELD_CAP:
				_spawn_rogue_field()
		if _rogue_stage_cleared():
			_enter_rogue_dev()
	elif _rogue_phase == "dev":
		# 发育期：安全窗口，刷怪停止；倒计时结束自动推进下一关
		_rogue_dev_timer -= delta
		GameState.rogue_dev_left = maxf(_rogue_dev_timer, 0.0)
		if _rogue_dev_timer <= 0.0:
			_advance_rogue_stage()


# Boss 干扰磁场：周期扫描 Boss 位置，沉默其附近的营地设备（炮塔停火/机器停产）。
# 用 set_process 开关实现通用沉默，不必逐个改设施子类的逻辑。
func _tick_boss_jam(delta: float) -> void:
	_boss_jam_timer -= delta
	if _boss_jam_timer > 0.0:
		return
	_boss_jam_timer = BOSS_JAM_INTERVAL
	var boss_positions: Array = []
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.is_queued_for_deletion():
			continue
		if bool(z.get("is_boss")):
			boss_positions.append(z.global_position)
	if boss_positions.is_empty():
		_boss_jam_notified = false
	var any_jammed := false
	for defense in get_tree().get_nodes_in_group("base_defense"):
		if defense.is_queued_for_deletion():
			continue
		if str(defense.get("defense_type")) == "signal_tower":
			# 信号塔是被动天线，不属"机枪塔/生产线/支援设备"，干扰磁场不沉默它
			continue
		var near := false
		for bp in boss_positions:
			if defense.global_position.distance_to(bp) <= BOSS_JAM_RADIUS:
				near = true
				break
		var currently: bool = defense.get("jammed") == true
		if near and not currently:
			defense.set("jammed", true)
			defense.set_process(false)
			any_jammed = true
		elif not near and currently:
			defense.set("jammed", false)
			defense.set_process(true)
	if any_jammed and not _boss_jam_notified:
		_boss_jam_notified = true
		GameState.notify("Boss 干扰磁场：附近营地的机枪塔与设备被沉默了！")


func _spawn_civilians() -> void:
	for i in CITIZEN_COUNT:
		var npc = NPC_SCENE.instantiate()
		npc.role = "pedestrian"
		npc.position = _random_free_pos()
		add_child(npc)


func _spawn_cops() -> void:
	var cop_a = NPC_SCENE.instantiate()
	cop_a.role = "cop"
	cop_a.patrol_offset = Vector3(42.0, 0.0, 0.0)
	cop_a.position = Vector3(1644 * SCALE, 0.1, 2024 * SCALE)
	add_child(cop_a)

	var cop_b = NPC_SCENE.instantiate()
	cop_b.role = "cop"
	cop_b.patrol_offset = Vector3(-36.0, 0.0, 0.0)
	cop_b.position = Vector3(4364 * SCALE, 0.1, 2213 * SCALE)
	add_child(cop_b)


func _spawn_player() -> void:
	var player = PLAYER_SCENE.instantiate()
	var spawn := GameState.SPAWN_POS
	if GameState.spawn_point_override != Vector2.ZERO:
		spawn = GameState.spawn_point_override
		GameState.spawn_point_override = Vector2.ZERO
	player.position = Vector3(spawn.x * SCALE, 0.2, spawn.y * SCALE)
	add_child(player)



# 系统空间雇佣的 NPC：进局后在玩家旁自动成为随从
func _spawn_hired_npcs() -> void:
	if GameState.pending_hires.is_empty():
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var worker_manager: Node = null
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.get_script() == load("res://scripts3d/worker3d.gd"):
			worker_manager = node
			break
	if worker_manager == null:
		return
	for i in mini(GameState.pending_hires.size(), 4):
		var fname: String = String(GameState.pending_hires[i])
		var npc = NPC_SCENE.instantiate()
		npc.role = "pedestrian"
		add_child(npc)
		npc.global_position = player.global_position + Vector3(
			randf_range(-2.0, 2.0), 0.1, randf_range(1.5, 3.0)
		)
		# 直接生成 FollowerBody 随从（不走招募链——系统空间已付费）
		var follower = load("res://scripts3d/worker3d.gd").FollowerBody.new()
		follower.follower_name = fname
		follower.manager = worker_manager
		add_child(follower)
		follower.global_position = npc.global_position
		npc.queue_free()
		worker_manager._followers.append(follower)
		GameState.notify("雇佣随从 %s 已就位" % fname)
	GameState.pending_hires.clear()

func _spawn_zombie() -> void:
	var pos := Vector3.ZERO
	if randf() < 0.4:
		# 全图散布的游荡者，让地图各处都有丧尸
		pos = Vector3(
			randf_range(2.0, GameState.CITY_SIZE.x * SCALE - 2.0),
			0.2,
			randf_range(2.0, GameState.CITY_SIZE.y * SCALE - 2.0)
		)
	else:
		var site := _pick_outbreak_site()
		var center: Vector3 = GameState.site_pos3(site)
		var radius := clampf(GameState.site_radius_m(site), 2.0, 220.0)
		var angle := randf() * TAU
		var dist := sqrt(randf()) * radius
		pos = Vector3(
			clampf(center.x + cos(angle) * dist, 1.0, GameState.CITY_SIZE.x * SCALE - 1.0),
			0.2,
			clampf(center.z + sin(angle) * dist, 1.0, GameState.CITY_SIZE.y * SCALE - 1.0)
		)
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = pos
	zombie.zombie_tier = GameState.pick_zombie_tier()
	add_child(zombie)


func _pick_outbreak_site() -> Dictionary:
	var sites: Array = GameState.outbreak_sites
	if sites.is_empty():
		return {"position": GameState.SPAWN_POS, "activated_at": 0.0}
	var total := 0.0
	for site in sites:
		total += 1.0 + maxf(0.0, GameState.outbreak_elapsed - float(site.get("activated_at", 0.0))) * 0.05
	var roll := randf() * total
	for site in sites:
		roll -= 1.0 + maxf(0.0, GameState.outbreak_elapsed - float(site.get("activated_at", 0.0))) * 0.05
		if roll <= 0.0:
			return site
	return sites[0]


func _random_free_pos() -> Vector3:
	for attempt in 80:
		var p := Vector2(
			randf_range(60.0, GameState.CITY_SIZE.x - 60.0),
			randf_range(60.0, GameState.CITY_SIZE.y - 60.0)
		)
		if not _inside_any_building(p):
			return Vector3(p.x * SCALE, 0.1, p.y * SCALE)
	return Vector3(GameState.SPAWN_POS.x * SCALE, 0.1, GameState.SPAWN_POS.y * SCALE)


func _inside_any_building(p: Vector2) -> bool:
	for rect in _model_rects:
		if rect.has_point(p):
			return true
	for entry in GameState.BUILDING_LAYOUT:
		var half: Vector2 = entry["size"] / 2.0 + Vector2(30, 30)
		var center: Vector2 = entry["position"]
		if absf(p.x - center.x) < half.x and absf(p.y - center.y) < half.y:
			return true
	for tower in GameState.TOWERS:
		var tower_half: Vector2 = tower["size"] / 2.0 + Vector2(20, 20)
		var tower_center: Vector2 = tower["position"]
		if (
			absf(p.x - tower_center.x) < tower_half.x
			and absf(p.y - tower_center.y) < tower_half.y
		):
			return true
	return false


func _add_static_box(center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
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
	return body


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


# 建筑门口的据点交互点：未占领时交互菜单选「占领为据点」引导 8 秒（走出交互范围打断，
# 建筑里有存活 NPC 拒绝），已是据点时可睡觉跳夜 / 存入全部物资；测试模式引导时间为 0
# 距离判定默认按「门口点 4m」，模型城市建筑（_place_model）把 footprint_half 设成占地半尺寸，
# 改成「走到建筑占地外围 4m 内」——模型是随机朝向的 .glb，只认一个门口点会让大部分侧面接近失效
class BaseDoor extends Node3D:
	const REACH := 4.0
	const CLAIM_CHANNEL := 8.0

	var building_id := ""
	var building_name := "建筑"
	# >0 时按占地矩形（xz 半尺寸）判距离，Vector2.ZERO 时按门口点判距离
	var footprint_half := Vector2.ZERO
	# 占地中心相对本节点的偏移（只在 footprint_half > 0 时生效：门口在前墙，占地中心在楼心）
	var reach_center_offset := Vector3.ZERO
	# 批次 42：搜刮建筑——本栋的 loot 表与一次性标记 key（像素坐标中心点）
	var loot_table := ""
	var scavenge_key := Vector2.ZERO
	var _plate: Label3D
	var _channel := -1.0
	var _channel_label: Label3D


	func _ready() -> void:
		add_to_group("interactables")
		add_to_group("building_doors")
		_plate = Label3D.new()
		_plate.text = "据点"
		_plate.font_size = 64
		_plate.modulate = Color(1.0, 0.85, 0.3)
		_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_plate.position = Vector3(0, 3.8, 0)
		add_child(_plate)
		GameState.home_base_changed.connect(_refresh_plate)
		_refresh_plate()


	# 玩家是否走到了可交互范围（门口点 4m 内，或占地矩形外围 4m 内）
	func within_reach(player: Node3D) -> bool:
		if player == null:
			return false
		var base := global_position + reach_center_offset
		var flat := Vector2(
			player.global_position.x - base.x,
			player.global_position.z - base.z
		)
		if footprint_half == Vector2.ZERO:
			return flat.length() <= REACH
		var outside := Vector2(
			maxf(absf(flat.x) - footprint_half.x, 0.0),
			maxf(absf(flat.y) - footprint_half.y, 0.0)
		)
		return outside.length() <= REACH


	func claim_channel_time() -> float:
		return 0.0 if GameState.test_mode else CLAIM_CHANNEL


	func channeling() -> bool:
		return _channel >= 0.0


	func _is_home() -> bool:
		if not GameState.has_home_base():
			return false
		var home_pos = GameState.home_base.get("position", Vector3.ZERO)
		if not (home_pos is Vector3):
			return false
		# 据点中心在楼心：模型/塔楼按楼心偏移比对，手建建筑按占地矩形包含判定
		if footprint_half != Vector2.ZERO:
			return (global_position + reach_center_offset).distance_to(home_pos) < 2.0
		var footprint := GameState.building_footprint_at(global_position)
		if footprint.has_area():
			return footprint.has_point(Vector2(home_pos.x, home_pos.z))
		return global_position.distance_to(home_pos) < 2.0


	func _refresh_plate() -> void:
		if _plate != null:
			_plate.visible = _is_home()


	func prompt_text() -> String:
		var player = get_tree().get_first_node_in_group("player")
		if player == null or not within_reach(player):
			return ""
		if channeling():
			return _channel_text()
		return ""


	func _channel_text() -> String:
		var need := maxf(claim_channel_time(), 0.01)
		return "占领中… %d%%" % int(clampf(_channel / need, 0.0, 1.0) * 100.0)


	# —— 统一交互菜单协议 ——

	func interact_title() -> String:
		return "据点 · %s" % building_name if _is_home() else building_name


	func interact_options(player: Node3D) -> Array:
		if player == null or not within_reach(player):
			return []
		if channeling():
			return []
		var options: Array = []
		# 进入/离开建筑（藏匿，容量 20：玩家 + 市民）
		var interiors_root := get_tree().get_first_node_in_group("building_interiors")
		var room_used := 0
		if interiors_root != null:
			room_used = interiors_root.count_for(building_id)
		if GameState.player_in_building == building_id:
			options.append({
				"id": "leave",
				"label": "离开建筑（楼内藏匿 %d/%d 人）" % [room_used, 20],
			})
		else:
			options.append({
				"id": "enter",
				"label": "进入建筑藏匿（%d/%d 人）" % [room_used, 20],
				"disabled": room_used >= 20,
				"reason": "楼内已藏满（20 人）",
			})
		if building_id == "power":
			# 发电厂：专属修复交互（发电站停运后恢复全城供电）
			if GameState.grid_repaired:
				options.append({"id": "repaired", "label": "发电厂运转中（全城供电已恢复）", "disabled": true, "reason": ""})
			elif GameState.grid_online():
				options.append({"id": "running", "label": "发电厂仍在运转", "disabled": true, "reason": "等停运后再来修复"})
			else:
				options.append({
					"id": "repair",
					"label": "修复发电厂（建材 ×%d，从据点仓库扣）" % GameState.POWER_PLANT_REPAIR_COST,
					"disabled": GameState.base_materials() < GameState.POWER_PLANT_REPAIR_COST,
					"reason": "据点仓库建材不够",
				})
		elif _is_home():
			if GameState.is_night():
				options.append({"id": "sleep", "label": "睡觉跳到清晨"})
			var carry := (
				int(GameState.resources.get("food", 0))
				+ int(GameState.resources.get("meds", 0))
				+ GameState.total_ammo()
				+ int(GameState.resources.get("fuel", 0))
				+ int(GameState.resources.get("materials", 0))
				+ GameState.money
				+ GameState.loot_count("anomaly_crystal")
			)
			var stored := 0
			var storage: Dictionary = GameState.home_base.get("storage", {})
			for kind in GameState.STORAGE_KINDS:
				stored += int(storage.get(kind, 0))
			options.append({
				"id": "store_all",
				"label": "存入所有物品",
				"disabled": carry <= 0,
				"reason": "背包是空的" if carry <= 0 else "",
			})
			options.append({
				"id": "storage",
				"label": "打开仓库（存取物资）",
				"disabled": carry <= 0 and stored <= 0,
				"reason": "仓库和背包都是空的" if carry <= 0 and stored <= 0 else "",
			})
		else:
			options.append({
				"id": "claim",
				"label": "占领为据点（引导 %d 秒）" % int(claim_channel_time()),
			})
		# 批次 100：非据点建筑追加"搜刮建筑"——每栋楼一池总物资，每次从池里提取，
		# 2 分钟一次，池尽即止；据点（自己家）没有"搜刮"这回事，不加该项
		if not _is_home():
			if GameState.scavenge_depleted(scavenge_key):
				options.append({"id": "scavenge", "label": "搜刮建筑", "disabled": true, "reason": "楼内物资已取尽"})
			elif GameState.scavenge_cooldown_left(scavenge_key) > 0.0:
				options.append({
					"id": "scavenge",
					"label": "搜刮建筑（库存 %d）" % GameState.scavenge_pool_remaining(scavenge_key),
					"disabled": true,
					"reason": "搜刮冷却中（%d 秒）" % int(ceilf(GameState.scavenge_cooldown_left(scavenge_key))),
				})
			else:
				options.insert(0, {
					"id": "scavenge",
					"label": "搜刮建筑（库存 %d）" % GameState.scavenge_pool_remaining(scavenge_key),
				})
		return options


	func interact_choose(id: String, _player: Node3D) -> void:
		var interiors_root := get_tree().get_first_node_in_group("building_interiors")
		match id:
			"enter":
				if interiors_root != null:
					interiors_root.enter_player(self, _player)
			"leave":
				if interiors_root != null:
					interiors_root.player_leave(_player)
			"claim":
				_try_interact()
			"repair":
				GameState.repair_power_plant()
			"sleep":
				if not GameState.sleep_skip_night():
					GameState.notify("现在不是夜晚")
			"storage":
				pass  # 由 HUD 拦截打开仓库面板
			"store_all":
				var crystals := GameState.loot_count("anomaly_crystal")
				if crystals > 0 and not GameState.base_has_containment():
					GameState.notify("没有异能储存仓，%d 颗结晶仍留在背包" % crystals)
				var summary := GameState.store_all_loot()
				GameState.notify("身上没有可存入的物资" if summary.is_empty() else summary)
			"scavenge":
				_scavenge()


	# 批次 100：搜刮建筑——每栋楼一池总物资（默认 20 件），每次从池里提取 2~3 件 × loot_mult，
	# 提取后进入 2 分钟冷却，池尽即止；结果直接进背包，不生成任何地面节点。
	# 批次 137：每次搜刮固定保底 制造材料 ×SCAVENGE_CRAFT_MAT（不占池），随机物资照旧
	func _scavenge() -> void:
		if GameState.scavenge_depleted(scavenge_key):
			GameState.notify("这栋建筑的物资已经取尽了")
			return
		if GameState.scavenge_cooldown_left(scavenge_key) > 0.0:
			GameState.notify("刚搜刮过，%d 秒后再来" % int(ceilf(GameState.scavenge_cooldown_left(scavenge_key))))
			return
		var table := loot_table if loot_table != "" else "house"
		var mult := GameState.echo_loot_mult() * GameState.loot_amount_mult()
		var want: int = maxi(1, int(roundf(float(randi_range(2, 3)) * mult)))
		var got := GameState.mine_scavenge_pool(scavenge_key, want)
		GameState.add_loot("craft_mat", GameState.SCAVENGE_CRAFT_MAT)
		var names: Array = ["制造材料 ×%d" % GameState.SCAVENGE_CRAFT_MAT]
		for i in got:
			var loot_id := GameState.roll_loot(table)
			# 批次 161：搜刮得到的制造材料数量 ×10
			GameState.add_loot(loot_id, 10 if loot_id == "craft_mat" else 1)
			names.append(GameState.loot_name(loot_id))
		var remaining := GameState.scavenge_pool_remaining(scavenge_key)
		GameState.notify("搜刮到：" + "、".join(names) + "（库存 %d）" % remaining)
		if remaining <= 0:
			GameState.notify("楼内物资已取尽")


	func _process(delta: float) -> void:
		if not channeling():
			return
		var player = get_tree().get_first_node_in_group("player")
		if player == null or not within_reach(player):
			_cancel_channel()
			return
		_channel += delta
		_update_channel_label()
		if _channel >= claim_channel_time():
			_channel = -1.0
			_clear_channel_label()
			GameState.claim_home_base(building_id, _claim_pos())


	# 据点中心 = 建筑占地中心（模型/塔楼按楼心偏移，手建建筑按占地矩形中心），建造范围以楼为中心外扩
	func _claim_pos() -> Vector3:
		if footprint_half != Vector2.ZERO:
			return global_position + reach_center_offset
		var fp := GameState.building_footprint_at(global_position)
		if fp.has_area():
			var c := fp.get_center()
			return Vector3(c.x, global_position.y, c.y)
		return global_position


	# 按 E 开始占领：建筑里有存活 NPC 时拒绝；引导时间随测试模式归零
	func _try_interact() -> void:
		var footprint := GameState.building_footprint_at(global_position)
		if footprint.has_area() and GameState.npcs_in_rect(footprint) > 0:
			GameState.notify("建筑里还有人，先清空再占领")
			return
		if claim_channel_time() <= 0.0:
			GameState.claim_home_base(building_id, _claim_pos())
			return
		_channel = 0.0
		_update_channel_label()
		var near_text := "门口" if footprint_half == Vector2.ZERO else "建筑"
		GameState.notify("占领中：保持在%s 4 米内，引导完成即占领" % near_text)


	func _cancel_channel() -> void:
		_channel = -1.0
		_clear_channel_label()
		var near_text := "门口" if footprint_half == Vector2.ZERO else "建筑"
		GameState.notify("占领被打断：离开了%s" % near_text)


	func _update_channel_label() -> void:
		if _channel_label == null:
			_channel_label = Label3D.new()
			_channel_label.font_size = 72
			_channel_label.modulate = Color(0.5, 0.95, 1.0)
			_channel_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_channel_label.outline_size = 8
			_channel_label.position = Vector3(0, 3.0, 0)
			add_child(_channel_label)
		_channel_label.text = _channel_text()


	func _clear_channel_label() -> void:
		if _channel_label != null:
			_channel_label.queue_free()
			_channel_label = null
