extends Node

signal money_changed(value: int)
signal hp_changed(value: int)
signal wanted_changed(level: int)
signal resources_changed()
signal weapons_changed()
signal notified(text: String)
signal player_died
signal phase_changed(phase: String)
signal run_ended(won: bool, reason: String)
signal stamina_changed(value: float)
signal satiety_changed(value: float)
signal news_posted(text: String)
signal coverage_changed(in_coverage: bool)
signal map_toggled(open: bool)
signal map_marker_changed()

var map_marker := Vector2.ZERO


func set_map_marker(pos: Vector2) -> void:
	map_marker = pos
	map_marker_changed.emit()


func clear_map_marker() -> void:
	if map_marker == Vector2.ZERO:
		return
	map_marker = Vector2.ZERO
	map_marker_changed.emit()



signal backpack_toggled(open: bool)
signal skills_toggled(open: bool)
signal skills_changed()
signal skill_points_changed(value: int)
signal mutation_offered()
signal mutations_changed()
signal jailed(active: bool)
signal faction_changed(faction: String, alignment: String)
signal infection_changed(infected: bool)
signal disguise_changed()
signal pause_toggled(open: bool)
signal police_alerted(pos: Vector3)
# 开枪事件：用于灯光闪烁等氛围效果（不参与通缉逻辑）
signal gunshot_fired(pos: Vector3)
signal day_changed(day_number: int)
signal weather_changed(weather: String, moon: float)
signal home_base_changed()
signal echo_offered(choices: Array)

const MAX_HP := 100
const SKILLS := [
	{"id": "vitality", "name": "生命强化", "max": 100, "desc": "生命上限 +2"},
	{"id": "endurance", "name": "耐力强化", "max": 100, "desc": "体力上限 +2"},
	{"id": "recovery", "name": "恢复强化", "max": 100, "desc": "体力恢复 +0.5/秒"},
	{"id": "agility", "name": "疾跑强化", "max": 100, "desc": "移动速度 +1%"},
	{"id": "gunnery", "name": "枪械精通", "max": 100, "desc": "枪械伤害 +1.5%"},
	{"id": "melee", "name": "近战精通", "max": 100, "desc": "近战伤害 +2%"},
	{"id": "medic", "name": "医疗精通", "max": 100, "desc": "医疗包治疗 +1"},
]

const MUTATIONS := {
	"self_heal": {
		"name": "自愈", "desc": "脱战 5 秒后，每秒回复 %s 生命",
		"from": [1.0], "to": [10.0],
	},
	"regeneration": {
		"name": "再生", "desc": "生命低于 %s%% 时，每秒回复 %s 生命",
		"from": [30.0, 1.5], "to": [50.0, 12.0],
	},
	"tough_skin": {
		"name": "坚韧皮肤", "desc": "受到伤害 -%s%%",
		"from": [5.0], "to": [35.0],
	},
	"lifesteal": {
		"name": "生命虹吸", "desc": "击杀回复 %s 生命",
		"from": [3.0], "to": [30.0],
	},
	"iron_lungs": {
		"name": "铁肺", "desc": "体力消耗 -%s%%",
		"from": [10.0], "to": [55.0],
	},
	"robust": {
		"name": "壮硕", "desc": "体力上限 +%s",
		"from": [20.0], "to": [180.0],
	},
	"second_wind": {
		"name": "第二口气", "desc": "体力见底时立即回复 %s 体力（冷却 30 秒）",
		"from": [15.0], "to": [100.0],
	},
	"light_legs": {
		"name": "铁腿", "desc": "冲刺饱食消耗 -%s%%",
		"from": [20.0], "to": [100.0],
	},
	"rest": {
		"name": "静息", "desc": "站立时体力恢复 +%s%%",
		"from": [60.0], "to": [450.0],
	},
	"metabolism": {
		"name": "代谢", "desc": "饱食消耗 -%s%%",
		"from": [10.0], "to": [70.0],
	},
	"nap": {
		"name": "小憩", "desc": "每分钟回复 %s 体力和 %s 生命",
		"from": [5.0, 2.0], "to": [40.0, 15.0],
	},
	"combat_regen": {
		"name": "战斗恢复", "desc": "击杀后 %s 秒内，每秒回复 %s 生命",
		"from": [2.0, 1.0], "to": [6.0, 8.0],
	},
	"cheetah": {
		"name": "猎豹", "desc": "移动速度 +%s%%",
		"from": [3.0], "to": [32.0],
	},
	"silent_step": {
		"name": "无声脚步", "desc": "发出的噪音 -%s%%",
		"from": [20.0], "to": [85.0],
	},
	"cat_step": {
		"name": "猫步", "desc": "跳跃高度 +%s%%",
		"from": [10.0], "to": [100.0],
	},
	"dodge": {
		"name": "闪避直觉", "desc": "%s%% 概率完全免伤",
		"from": [3.0], "to": [25.0],
	},
	"accuracy": {
		"name": "弹道校准", "desc": "散布 -%s%%",
		"from": [10.0], "to": [70.0],
	},
	"grip": {
		"name": "稳定握把", "desc": "后坐力 -%s%%",
		"from": [20.0], "to": [90.0],
	},
	"crit": {
		"name": "致命一击", "desc": "%s%% 概率造成 %s 倍伤害",
		"from": [5.0, 1.5], "to": [25.0, 3.0],
	},
	"quickdraw": {
		"name": "快枪手", "desc": "射速冷却 -%s%%",
		"from": [8.0], "to": [50.0],
	},
	"claws": {
		"name": "利爪", "desc": "近战伤害 +%s%%",
		"from": [15.0], "to": [150.0],
	},
	"bleed": {
		"name": "撕裂", "desc": "近战命中附加 %s 秒流血（每秒 %s 伤害）",
		"from": [3.0, 3.5], "to": [5.0, 18.0],
	},
	"bloodthirst": {
		"name": "嗜血", "desc": "近战击杀回复 %s 生命",
		"from": [3.0], "to": [35.0],
	},
	"swift": {
		"name": "迅捷", "desc": "近战攻速 +%s%%，距离 +%s 米",
		"from": [8.0, 0.05], "to": [70.0, 0.8],
	},
	"elixir": {
		"name": "秘药", "desc": "医疗包治疗量 +%s",
		"from": [10.0], "to": [90.0],
	},
	"field_aid": {
		"name": "战地急救", "desc": "医疗包回复 %s%% 体力",
		"from": [25.0], "to": [100.0],
	},
	"serum": {
		"name": "再生血清", "desc": "用包后 8 秒持续回复 %s 生命",
		"from": [15.0], "to": [100.0],
	},
	"energizer": {
		"name": "强心针", "desc": "生命上限 +%s",
		"from": [15.0], "to": [150.0],
	},
}

const MUTATION_POOLS := {
	"vitality": ["self_heal", "regeneration", "tough_skin", "lifesteal"],
	"endurance": ["iron_lungs", "robust", "second_wind", "light_legs"],
	"recovery": ["rest", "metabolism", "nap", "combat_regen"],
	"agility": ["cheetah", "silent_step", "cat_step", "dodge"],
	"gunnery": ["accuracy", "grip", "crit", "quickdraw"],
	"melee": ["claws", "bleed", "bloodthirst", "swift"],
	"medic": ["elixir", "field_aid", "serum", "energizer"],
}

const ZOMBIE_STAGES := [
	{"at": 2, "name": "强化尸体", "hp": 1.3, "damage": 1.1},
	{"at": 4, "name": "疾行者", "runner_chance": 0.3, "runner_speed": 1.4},
	{"at": 6, "name": "厚甲尸", "hp": 1.6, "resist": 0.15},
	{"at": 8, "name": "撕裂者", "damage": 1.32, "attack_speed": 1.4},
	{"at": 10, "name": "酸液尸", "acid": true},
	{"at": 14, "name": "精英尸", "hp": 2.0, "scale": 1.35, "damage": 1.5},
	{"at": 18, "name": "尸王", "boss": true},
	{"at": 24, "name": "尸潮", "spawn_mult": 2.0, "cap_mult": 1.5},
]

const MUTATION_CHOICES := 3
const MUTATION_MAX_RANK := 10
const SURVIVAL_POINT_SECONDS := 60.0
const FACTION_HUMAN := "human"
const FACTION_ZOMBIE := "zombie"
const ALIGN_GOOD := "good"
const ALIGN_BAD := "bad"
const INFECTION_SECONDS := 60.0
const INFECTION_BITE_CHANCE := 0.35
# 感染已删除：原感染入口改为直接扣生命值时的伤害量（数值待调）
const INFECTION_DAMAGE := 15
const ZOMBIE_BASE_HP := 160
const ZOMBIE_CLAW_DAMAGE := 26
const ZOMBIE_REDEEM_KILLS := 5

const ZOMBIE_MUTATIONS := {
	"z_claws": {
		"name": "利爪", "desc": "丧尸近战伤害 +%s%%",
		"from": [10.0], "to": [120.0],
	},
	"z_hide": {
		"name": "腐化皮肤", "desc": "受到伤害 -%s%%",
		"from": [5.0], "to": [40.0],
	},
	"z_regen": {
		"name": "腐肉再生", "desc": "每秒回复 %s 生命",
		"from": [1.0], "to": [9.0],
	},
	"z_plague": {
		"name": "尸毒", "desc": "爪击命中人类有 %s%% 概率使其感染",
		"from": [15.0], "to": [80.0],
	},
}
const ZOMBIE_POOL := ["z_claws", "z_hide", "z_regen", "z_plague"]

const ZOMBIE_TIERS := [
	{"name": "普通丧尸", "hp": 100, "damage": 10, "speed": 1.74, "cooldown": 1.5, "resist": 0.0, "scale": 1.0, "acid": false, "knockback": false, "summon": false},
	{"name": "变异猎犬", "hp": 120, "damage": 30, "speed": 2.83, "cooldown": 1.5, "resist": -0.2, "scale": 1.35, "acid": false, "knockback": false, "summon": false, "hound": true},
	{"name": "撕裂者", "hp": 120, "damage": 15, "speed": 1.1, "cooldown": 0.65, "resist": 0.1, "scale": 1.1, "acid": false, "knockback": false, "summon": false},
	{"name": "暴食尸", "hp": 220, "damage": 16, "speed": 0.9, "cooldown": 1.0, "resist": 0.15, "scale": 1.25, "acid": false, "knockback": false, "summon": false},
	{"name": "异变狼蛛", "hp": 120, "damage": 20, "speed": 2.61, "cooldown": 1.0, "resist": 0.0, "scale": 1.0, "acid": false, "knockback": false, "summon": false, "spider": true},
	{"name": "装甲尸", "hp": 300, "damage": 18, "speed": 0.85, "cooldown": 0.9, "resist": 0.35, "scale": 1.2, "acid": false, "knockback": false, "summon": false},
	{"name": "尸王", "hp": 500, "damage": 26, "speed": 1.05, "cooldown": 0.7, "resist": 0.3, "scale": 1.35, "acid": false, "knockback": true, "summon": false},
	{"name": "尸皇", "hp": 850, "damage": 34, "speed": 1.1, "cooldown": 0.6, "resist": 0.4, "scale": 1.5, "acid": true, "knockback": true, "summon": false},
	{"name": "尸神·天灾", "hp": 3000, "damage": 60, "speed": 1.0, "cooldown": 0.8, "resist": 0.5, "scale": 14.0, "acid": true, "knockback": true, "summon": true},
]

# 世界疫情阶段：按爆发后总秒数递进（7 个游戏日，1 日 = 960 秒），与玩家变异体系（ZOMBIE_STAGES）解耦
const WORLD_STAGES := [
	{"at": 0.0, "name": "初发", "tier_min": 1, "tier_max": 1},
	{"at": 600.0, "name": "蔓延", "tier_min": 1, "tier_max": 2, "spawn_mult": 1.3},
	{"at": 1200.0, "name": "扩散", "tier_min": 1, "tier_max": 3, "runner_chance": 0.3, "new_site": true},
	{"at": 2160.0, "name": "失控", "tier_min": 2, "tier_max": 4, "cap_mult": 1.3, "new_site": true},
	{"at": 3120.0, "name": "重度感染", "tier_min": 3, "tier_max": 6, "acid": true},
	{"at": 4080.0, "name": "尸潮", "tier_min": 4, "tier_max": 7, "spawn_mult": 1.8, "cap_mult": 1.5},
	{"at": 5040.0, "name": "尸王降临", "tier_min": 5, "tier_max": 8, "boss_tier": 7},
	{"at": 5760.0, "name": "天灾", "tier_min": 6, "tier_max": 9, "spawn_mult": 2.0, "cap_mult": 1.5, "boss_tier": 9, "god": true},
]

const META_PATH := "user://meta.json"
const HUB_SCENE := "res://scenes3d/hub3d.tscn"
const FOOD_DIR := "res://assets/models/items/food/"
const SUR_DIR := "res://assets/models/items/survival/"
const WEAPON_DIR := "res://assets/models/weapons/"
# Synty 素材路径（末日包物品/武器/道具、商店包食物、帮派包钞票）
const APO_ITEM := "res://assets/Synty/PolygonApocalypse/Prefabs/Item/"
const APO_PROP_S := "res://assets/Synty/PolygonApocalypse/Prefabs/Props/"
const APO_GUN := "res://assets/Synty/PolygonApocalypse/Prefabs/Weapons/Guns/"
const APO_MELEE := "res://assets/Synty/PolygonApocalypse/Prefabs/Weapons/Melee/"
const APO_MISC := "res://assets/Synty/PolygonApocalypse/Prefabs/Weapons/Misc/"
const APO_MOD := "res://assets/Synty/PolygonApocalypse/Prefabs/Weapons/Modular/"
const SHOP_FOOD := "res://assets/Synty/PolygonShops/Prefabs/Food/"
const GW_PROP := "res://assets/Synty/PolygonGangWarfare/Prefabs/Props/"
const WEAPON_MODELS := {
	"pistol": APO_GUN + "SM_Wep_Pistol_01.tscn",
	"smg": APO_GUN + "SM_Wep_SubMGun_01.tscn",
	"shotgun": APO_GUN + "SM_Wep_Shotgun_01.tscn",
	"rifle": APO_GUN + "SM_Wep_AssaultRifle_01.tscn",
	"sniper": APO_GUN + "SM_Wep_SniperRifle_01.tscn",
	"lmg": APO_GUN + "SM_Wep_MachineGun_01.tscn",
	"grenade": APO_MISC + "SM_Wep_Grenade_01.tscn",
	"rpg": APO_GUN + "SM_Wep_RocketLauncher_01.tscn",
}
const SUPPRESSOR_MODEL := APO_MOD + "SM_Wep_Mod_Attach_Silencer_01.tscn"
# 无瞄准镜时的默认开镜视距（米）
const DEFAULT_VIEW_RANGE := 18.0
const CONTAINER_MODELS := {
	"house": APO_PROP_S + "SM_Prop_KitchenCabinet_01.tscn",
	"market": APO_PROP_S + "SM_Prop_Bookshelf_01.tscn",
	"gun": APO_ITEM + "SM_Item_Ammo_Crate_01.tscn",
	"medical": APO_PROP_S + "SM_Prop_Medical_Shelf_01.tscn",
	"office": APO_PROP_S + "SM_Prop_Bookshelf_01.tscn",
	"warehouse": APO_PROP_S + "SM_Prop_Crate_Large_01.tscn",
	"valuable": GW_PROP + "SM_Prop_Money_Stack_01.tscn",
}
const LOOT_ITEMS := {
	"bread": {"name": "面包", "cat": "food", "model": SHOP_FOOD + "SM_Prop_Food_Baguette_01.tscn", "value": 8, "satiety": 30.0},
	"can": {"name": "罐头", "cat": "food", "model": APO_ITEM + "SM_Item_Can_01.tscn", "value": 10, "satiety": 40.0},
	"cheese": {"name": "奶酪", "cat": "food", "model": SHOP_FOOD + "SM_Prop_Food_Cheese_Slice_01.tscn", "value": 12, "satiety": 25.0},
	"meat": {"name": "熟肉", "cat": "food", "model": APO_ITEM + "SM_Item_Meat_Cooked_01.tscn", "value": 16, "satiety": 45.0},
	"apple": {"name": "苹果", "cat": "food", "model": SHOP_FOOD + "SM_Prop_Food_Apple_01.tscn", "value": 6, "satiety": 14.0},
	"banana": {"name": "香蕉", "cat": "food", "model": SHOP_FOOD + "SM_Prop_Food_Banana_01.tscn", "value": 6, "satiety": 14.0},
	"cookie": {"name": "饼干", "cat": "food", "model": SHOP_FOOD + "SM_Prop_Food_Cookie_01.tscn", "value": 5, "satiety": 15.0},
	"candy": {"name": "能量棒", "cat": "food", "model": SHOP_FOOD + "SM_Prop_Food_Donut_01.tscn", "value": 7, "satiety": 20.0, "stamina": 15.0},
	"chocolate": {"name": "巧克力", "cat": "food", "model": SHOP_FOOD + "SM_Prop_Food_Muffin_01.tscn", "value": 9, "satiety": 18.0, "stamina": 10.0},
	"water": {"name": "矿泉水", "cat": "drink", "model": APO_ITEM + "SM_Item_Bottle_01.tscn", "value": 6, "satiety": 25.0},
	"soda": {"name": "汽水", "cat": "drink", "model": APO_ITEM + "SM_Item_Drink_01.tscn", "value": 7, "satiety": 20.0, "stamina": 15.0},
	"soda_big": {"name": "大瓶汽水", "cat": "drink", "model": APO_ITEM + "SM_Item_Drink_Bottle_01.tscn", "value": 12, "satiety": 35.0, "stamina": 25.0},
	"coffee": {"name": "咖啡", "cat": "drink", "model": APO_ITEM + "SM_Item_BeerCup_01.tscn", "value": 14, "satiety": 10.0, "stamina": 45.0},
	"water_big": {"name": "桶装水", "cat": "drink", "model": APO_PROP_S + "SM_Prop_Barrel_Water_01.tscn", "value": 18, "satiety": 50.0},
	"bandage": {"name": "绷带", "cat": "med", "model": APO_PROP_S + "SM_Prop_MedicalBox_01.tscn", "value": 15, "heal": 50},
	"heal_potion": {"name": "恢复药水", "cat": "med", "model": APO_ITEM + "SM_Item_Pills_01.tscn", "value": 60, "hot_total": 100, "hot_duration": 10.0},
	"axe": {"name": "消防斧", "cat": "melee", "model": APO_MELEE + "SM_Wep_FireAxe_01.tscn", "value": 130, "damage": 48},
	"pickaxe": {"name": "镐", "cat": "melee", "model": APO_MELEE + "SM_Wep_PipeWrench_01.tscn", "value": 100, "damage": 42},
	"shovel": {"name": "工兵铲", "cat": "melee", "model": APO_MELEE + "SM_Wep_Spade_01.tscn", "value": 80, "damage": 36},
	"hammer": {"name": "铁锤", "cat": "melee", "model": APO_MELEE + "SM_Wep_Hammer_01.tscn", "value": 55, "damage": 30},
	"pistol_loot": {"name": "手枪", "cat": "ranged", "model": WEAPON_MODELS["pistol"], "value": 150, "weapon": "pistol"},
	"smg_loot": {"name": "冲锋枪", "cat": "ranged", "model": WEAPON_MODELS["smg"], "value": 260, "weapon": "smg"},
	"shotgun_loot": {"name": "霰弹枪", "cat": "ranged", "model": WEAPON_MODELS["shotgun"], "value": 320, "weapon": "shotgun"},
	"rifle_loot": {"name": "步枪", "cat": "ranged", "model": WEAPON_MODELS["rifle"], "value": 480, "weapon": "rifle"},
	"sniper_loot": {"name": "狙击枪", "cat": "ranged", "model": WEAPON_MODELS["sniper"], "value": 620, "weapon": "sniper"},
	"lmg_loot": {"name": "重机枪", "cat": "ranged", "model": WEAPON_MODELS["lmg"], "value": 800, "weapon": "lmg"},
	"grenade_loot": {"name": "手榴弹", "cat": "ranged", "model": WEAPON_MODELS["grenade"], "value": 120, "weapon": "grenade"},
	"rpg_loot": {"name": "火箭炮", "cat": "ranged", "model": WEAPON_MODELS["rpg"], "value": 900, "weapon": "rpg"},
	"suppressor": {"name": "消音器", "cat": "attach", "model": SUPPRESSOR_MODEL, "value": 220},
	"scope_rds": {"name": "红点镜", "cat": "attach", "model": APO_MOD + "SM_Wep_Mod_Attach_IronSight_01.tscn", "value": 150, "view": 25.0},
	"scope_2x": {"name": "二倍镜", "cat": "attach", "model": APO_MOD + "SM_Wep_Mod_Attach_Scope_01.tscn", "value": 260, "view": 35.0},
	"scope_4x": {"name": "四倍镜", "cat": "attach", "model": APO_MOD + "SM_Wep_Mod_Attach_Scope_03.tscn", "value": 420, "view": 50.0},
	"scope_8x": {"name": "八倍镜", "cat": "attach", "model": APO_MOD + "SM_Wep_Mod_Attach_Scope_06.tscn", "value": 680, "view": 70.0},
	"power_bank": {"name": "充电宝", "cat": "tool", "model": APO_ITEM + "SM_Item_Battery_02.tscn", "value": 90},
	"hazmat": {"name": "防化服", "cat": "tool", "model": APO_ITEM + "SM_Item_Shop_Goods_01.tscn", "value": 300},
	"anomaly_crystal": {"name": "异能结晶", "cat": "tool", "model": APO_ITEM + "SM_Item_Jar_01.tscn", "value": 150},
	"flashlight": {"name": "手电筒", "cat": "tool", "model": APO_PROP_S + "SM_Prop_Flashlight_01.tscn", "value": 140},
	"clothes": {"name": "换洗衣物", "cat": "tool", "model": APO_ITEM + "SM_Item_Shop_Goods_02.tscn", "value": 260},
	"vest": {"name": "防弹插板", "cat": "armor", "model": APO_MISC + "SM_Wep_Sign_Shield_01.tscn", "value": 180, "resist": 0.12},
	"plank": {"name": "木板", "cat": "junk", "model": APO_MELEE + "SM_Wep_Plank_01.tscn", "value": 10},
	"wood": {"name": "木料", "cat": "junk", "model": APO_ITEM + "SM_Item_Log_01.tscn", "value": 8},
	"stone": {"name": "石料", "cat": "junk", "model": "res://assets/Synty/PolygonApocalypse/Prefabs/Generic/SM_Generic_Small_Rocks_01.tscn", "value": 6},
	"bucket": {"name": "水桶", "cat": "junk", "model": APO_PROP_S + "SM_Prop_Tool_Bucket_01.tscn", "value": 12},
	"money_bag": {"name": "现金袋", "cat": "valuable", "model": GW_PROP + "SM_Prop_Money_Roll_01.tscn", "value": 160},
	"gold_box": {"name": "金条箱", "cat": "valuable", "model": GW_PROP + "SM_Prop_Money_Stack_01.tscn", "value": 320},
	# 制造材料：搜刮获得的通用制作素材，制造子弹/枪械/药品等的必需材料
	"craft_mat": {"name": "制造材料", "cat": "tool", "model": APO_ITEM + "SM_Item_Battery_02.tscn", "value": 20},
	# 弹药加工台产物：迫击炮弹/火炮弹（炮击开火消耗）
	"mortar_shell": {"name": "迫击炮弹", "cat": "tool", "model": APO_ITEM + "SM_Item_Battery_01.tscn", "value": 30},
	"cannon_shell": {"name": "火炮弹", "cat": "tool", "model": APO_ITEM + "SM_Item_Battery_01.tscn", "value": 50},
	# 异能宝石：异能转换台产物，随身携带强化能力（每颗伤害 +10%、生命上限 +25，最多 3 颗）
	"anomaly_gem": {"name": "异能宝石", "cat": "tool", "model": APO_ITEM + "SM_Item_Jar_01.tscn", "value": 400},
}

const LOOT_TABLES := {
	"house": ["bread", "can", "water", "soda", "apple", "banana", "cookie", "bandage", "plank", "hammer", "money_bag", "craft_mat", "craft_mat"],
	"market": ["can", "bread", "cheese", "meat", "water", "soda_big", "coffee", "cookie", "chocolate", "money_bag", "craft_mat", "craft_mat"],
	"gun": ["pistol_loot", "smg_loot", "shotgun_loot", "rifle_loot", "sniper_loot", "lmg_loot", "grenade_loot", "rpg_loot", "suppressor", "scope_rds", "scope_2x", "scope_4x", "scope_8x", "hammer", "axe", "vest", "money_bag", "craft_mat", "craft_mat", "craft_mat"],
	"medical": ["bandage", "bandage", "heal_potion", "water", "money_bag", "hazmat", "craft_mat", "craft_mat"],
	"office": ["coffee", "soda", "cookie", "money_bag", "gold_box", "plank", "vest", "power_bank", "flashlight", "craft_mat", "craft_mat"],
	"warehouse": ["plank", "wood", "stone", "bucket", "hammer", "shovel", "pickaxe", "axe", "vest", "flashlight", "power_bank", "craft_mat", "craft_mat", "craft_mat"],
	"valuable": ["gold_box", "money_bag", "gold_box", "heal_potion", "vest", "craft_mat"],
}
const SHOP := {
	"skill_point": {"name": "SP ×1", "cost": 10},
	"ammo10": {"name": "弹药 ×10", "cost": 30},
	"meds1": {"name": "医疗包 ×1", "cost": 40},
	"food3": {"name": "食物 ×3", "cost": 30},
	"pistol": {"name": "解锁手枪", "cost": 120},
	"shotgun": {"name": "解锁霰弹枪", "cost": 400},
	"rifle": {"name": "解锁步枪", "cost": 600},
	"smg": {"name": "解锁冲锋枪", "cost": 500},
	"sniper": {"name": "解锁狙击枪", "cost": 900},
	"lmg": {"name": "解锁重机枪", "cost": 1200},
	"grenade": {"name": "解锁手榴弹", "cost": 150},
	"rpg": {"name": "解锁火箭炮", "cost": 1500},
	"suppressor": {"name": "消音器 ×1", "cost": 220},
	"scope_rds": {"name": "红点镜 ×1", "cost": 150},
	"scope_2x": {"name": "二倍镜 ×1", "cost": 260},
	"scope_4x": {"name": "四倍镜 ×1", "cost": 420},
	"scope_8x": {"name": "八倍镜 ×1", "cost": 680},
	"clothes": {"name": "换洗衣物 ×1", "cost": 260},
	"revival_stone": {"name": "复活石", "cost": REVIVE_STONE_COST},
}

# 能源系统：玩家不再用电（设备由信号塔供能）；异能量（击杀丧尸积累，应急治疗/局末折算 SP）
const ANOMALY_MAX := 100
const ANOMALY_HEAL_COST := 15
const ANOMALY_HEAL_RATIO := 0.4

# 据点系统：复活石（观测舱一次性购买）+ 建造模式参数
const REVIVE_STONE_COST := 400
const BASE_MAX_LEVEL := 5
const BASE_BASE_RADIUS := 8.0
const BASE_MAX_RADIUS := 20.0
# 信号塔覆盖半径（原 40m，批次 151 扩大 10 倍）
const SIGNAL_TOWER_RANGE := 400.0
# 据点建造消耗建材（拆除建筑/街道杂物获得），不再消耗现金
const BASE_EXPAND_COST := 10
# 建造目录（cost 均为建材）：照明灯纯功能，发电机是炮塔射程光环、每据点限 1 个
const BASE_DEFENSES := {
	"barricade": {"name": "路障", "cost": 8, "hp": 200},
	"turret": {"name": "哨戒炮塔", "cost": 25, "hp": 150, "damage": 12, "range": 14.0, "cap": 6},
	"spikes": {"name": "尖刺陷阱", "cost": 12, "hp": 80, "dps": 15},
	"wall": {"name": "围墙段", "cost": 10, "hp": 300},
	"lamp": {"name": "照明灯", "cost": 15, "hp": 50},
	"generator": {"name": "发电机", "cost": 30, "hp": 100, "range_aura": 3.0, "unique": true},
	"solar": {"name": "太阳能电池板", "cost": 20, "hp": 60},
	"windmill": {"name": "自制风力发电机", "cost": 25, "hp": 80},
	"battery": {"name": "大型蓄电池组", "cost": 20, "hp": 100, "unique": true},
	"containment": {"name": "异能储存仓", "cost": 25, "hp": 120, "unique": true},
	"workbench": {"name": "弹药加工台", "cost": 5, "hp": 100},
	"converter": {"name": "异能转换台", "cost": 5, "hp": 120, "craft": 5},
	"fabricator": {"name": "装备制作台", "cost": 20, "hp": 150, "craft": 40},
	"food_synth": {"name": "食品加工台", "cost": 20, "hp": 120, "craft": 30},
	"med_station": {"name": "药品制作台", "cost": 20, "hp": 120, "craft": 30},
	"potion_brewer": {"name": "医疗台", "cost": 15, "hp": 120, "craft": 30},
	"signal_tower": {"name": "信号塔", "cost": 15, "hp": 300, "craft": 20},
	# 迫击炮：远程曲射火力，E 交互进入炮击指挥，左键远程选打击点，AoE 爆炸伤害
	"mortar": {"name": "迫击炮", "cost": 40, "hp": 150, "range": 40.0, "damage": 80, "cooldown": 6.0, "blast": 4.0},
	# 火炮：重型远程火力，射程为迫击炮两倍，威力与爆炸范围更大、装填更慢
	"cannon": {"name": "火炮", "cost": 80, "hp": 200, "range": 80.0, "damage": 120, "cooldown": 8.0, "blast": 6.0},
}
# 据点发电机：烧仓库燃料发电，1 升燃料发电 60 秒
const GEN_FUEL_SECONDS := 60.0
# 据点电力：储备 0~上限（基础 100，每组蓄电池 +200）；发电设备充入，用电设备（炮塔/照明灯）消耗
const BASE_POWER_CAP := 100.0
const BASE_POWER_PER_BATTERY := 200.0
const GEN_POWER_RATE := 1.0
const SOLAR_POWER_RATE := 0.6
const WIND_POWER_RATE := 0.25
const TURRET_POWER_DRAIN := 0.05
const LAMP_POWER_DRAIN := 0.02
# 城市电网：准备期与灾变后头两天有电，第 3 天发电站停运（修复发电厂后恢复）
const GRID_FAILURE_DAY := 3
const POWER_PLANT_REPAIR_COST := 60
# 设施升级（cost 为建材，从据点仓库扣）：两级，等级记进 home_base["defense_levels"]
const DEFENSE_UPGRADES := {
	"barricade": [{"cost": 15, "hp_bonus": 150}, {"cost": 30, "hp_bonus": 300}],
	"turret": [{"cost": 30, "damage": 24, "range": 18.0}, {"cost": 50, "damage": 40, "range": 22.0}],
}
# 据点仓库扩容花费（建材，从仓库存量扣），每次 +100 容量
const STORAGE_UPGRADE_COST := 15
# 车辆后备箱容量（车型 id → 储物格数），储物状态存在车辆节点上，这里只提供容量表
const VEHICLE_CARGO := {
	"sedan": 40, "sedan-sports": 40, "hatchback-sports": 30, "taxi": 40,
	"suv": 60, "police": 60, "ambulance": 80, "van": 120, "delivery": 150,
	"firetruck": 150, "garbage-truck": 250, "truck": 200,
}
const VEHICLE_CARGO_DEFAULT := 60
# 拆除规则：大楼 = 占地 > 150000 像素² 或 3 层及以上
const DEMOLISH_BIG_AREA := 150000.0
const DEMOLISH_NOISE_SMALL := 30.0
const DEMOLISH_NOISE_BIG := 120.0
const DEMOLISH_HOLD_SMALL := 2.0
const DEMOLISH_HOLD_BIG := 6.0
# 建筑拆除改为库存提取：每次拆卸 +10 建材，建筑总库存 10000，取尽才真正坍塌
const BUILDING_MATERIAL_POOL := 10000
const BUILDING_MATERIAL_PER_DEMOLISH := 10
# 建筑结构耐久：与 10000 材料库存是两条独立进度。爆炸物按伤害扣血，归零即炸毁，
# 但只掉体积换算的小额建材（demolish_yield），剩余库存作废（远少于挖满 10000）。
# 取值理由：手榴弹 95 / 火箭炮 200，1000 血约 11 发手榴弹或 5 发火箭炮可炸毁一栋，够慢。
const BUILDING_HP := 1000
# 拆除工具加速倍率（best_demolish_tool 取玩家持有的最好一把）
const DEMOLISH_TOOL_MULT := {"axe": 0.7, "pickaxe": 0.5, "hammer": 0.8}
# 据点自带信号覆盖：固定信号源 id + 半径 = 15m + 10m×等级
const BASE_SIGNAL_ID := -100
const BASE_SIGNAL_BASE_RADIUS := 15.0
const BASE_SIGNAL_LEVEL_RADIUS := 10.0
# 空地据点：无建筑，消耗脚边 3m 内地面建材堆合计 150 建材
const OPEN_GROUND_BASE_ID := "open_ground"
const OPEN_GROUND_BASE_COST := 150
const OPEN_GROUND_PILE_REACH := 3.0

const HUMAN_TIERS := [	{"name": "普通人", "hp": 25, "damage": 6, "range": 10.0, "cooldown": 1.2, "resist": 0.0, "scale": 1.0},
	{"name": "警察", "hp": 45, "damage": 10, "range": 14.0, "cooldown": 0.9, "resist": 0.0, "scale": 1.0},
	{"name": "特警", "hp": 70, "damage": 13, "range": 18.0, "cooldown": 0.7, "resist": 0.05, "scale": 1.02},
	{"name": "士兵", "hp": 90, "damage": 15, "range": 30.0, "cooldown": 0.6, "resist": 0.08, "scale": 1.03},
	{"name": "精英士兵", "hp": 130, "damage": 18, "range": 32.0, "cooldown": 0.5, "resist": 0.12, "scale": 1.05},
	{"name": "特种兵", "hp": 170, "damage": 22, "range": 34.0, "cooldown": 0.45, "resist": 0.16, "scale": 1.07},
	{"name": "精英特种兵", "hp": 220, "damage": 26, "range": 36.0, "cooldown": 0.4, "resist": 0.2, "scale": 1.1},
	{"name": "机甲士兵", "hp": 320, "damage": 30, "range": 32.0, "cooldown": 0.5, "resist": 0.28, "scale": 1.2},
	{"name": "精英机甲", "hp": 480, "damage": 38, "range": 34.0, "cooldown": 0.45, "resist": 0.36, "scale": 1.3},
	{"name": "人类救世主", "hp": 800, "damage": 50, "range": 38.0, "cooldown": 0.35, "resist": 0.45, "scale": 1.5},
]
const SPAWN_POS := Vector2(3036, 1960)
const WANTED_DECAY_SEC := 10.0
const CRIME_SIGNAL_MIN := 0.15
const JAIL_SECONDS := 30.0
const FINE_PER_WANTED := 200
const FINE_PER_CRIME := 30
const OUTLAW_KILLS := 3

# 开局准备期：基础 5 分钟，提前入场购买与死亡补偿（每次 +1 分钟）在此基础上累加
const PREPARE_MIN := 300.0
const PREPARE_MAX := 300.0
# 生存期时间结构：7 个游戏日，1 日 = 960 秒（昼 600 秒 + 夜 360 秒）
const DAY_LENGTH := 960.0
const NIGHT_START := 600.0
const FINAL_DAY := 7
const WORLD_SCALE_3D := 0.05
const MEDKIT_HEAL := 45

const SPREAD_BASE_SPEED := 26.0
const OUTBREAK_CONVERT_RADIUS := 30.0
const ZOMBIE_SPAWN_INTERVAL := 1.8
const ZOMBIE_MAX := 80
const PEDESTRIAN_COUNT := 100
const FIRST_WAVE_RADIUS := 1200.0

const BOSS_SP_BONUS := 500

# SP 属性强化：五维，无上限，每级 +2%
const ATTRS := {
	"vitality": {"name": "体魄", "desc": "生命上限 +2%/级"},
	"agility": {"name": "敏捷", "desc": "移动速度 +2%/级"},
	"perception": {"name": "感知", "desc": "射程与视野 +2%/级"},
	"will": {"name": "意志", "desc": "异能与信号抗性 +2%/级（占位）"},
	"luck": {"name": "幸运", "desc": "掉落率 +2%/级"},
}
const ATTR_COST_BASE := 100
const ATTR_COST_MULT := 1.6
# 提前入场：系统空间（观测舱）购买，每次 +1 分钟，价格基础价 ×1.1^连购次数，额外时间上限 +55 分钟
const EARLY_ENTRY_FIRST := 1
const EARLY_ENTRY_STEP := 1
const EARLY_ENTRY_MAX := 55
const EARLY_ENTRY_BASE_COST := 10
const EARLY_ENTRY_COST_MULT := 1.1

# 回响池：灾变降临与每日黎明各触发一次三选一，仅本局生效
const ECHO_POOL := [
	{"id": "e_gun_dmg", "name": "回响·枪口余温", "school": "战斗", "desc": "枪械伤害 +15%", "gun_mult": 1.15},
	{"id": "e_melee_lifesteal", "name": "回响·血饮", "school": "战斗", "desc": "近战击杀回复 5% 生命上限", "melee_lifesteal": 0.05},
	{"id": "e_crit", "name": "回响·破绽", "school": "战斗", "desc": "暴击率 +10%", "crit_chance": 0.10},
	{"id": "e_reload", "name": "回响·快手", "school": "战斗", "desc": "换弹时间 -25%", "reload_mult": 0.75},
	{"id": "e_move", "name": "回响·风行", "school": "生存", "desc": "移动速度 +8%", "move_mult": 1.08},
	{"id": "e_hunger", "name": "回响·缓饥", "school": "生存", "desc": "饥饿衰减 -30%", "hunger_mult": 0.7},
	{"id": "e_hp", "name": "回响·铁躯", "school": "生存", "desc": "生命上限 +20%", "hp_mult": 1.2},
	{"id": "e_stamina", "name": "回响·长跑者", "school": "生存", "desc": "体力上限 +25%", "stamina_mult": 1.25},
	{"id": "e_night_vision", "name": "回响·夜视", "school": "异能", "desc": "夜晚视野不再受限", "night_vision": true},
	{"id": "e_signal", "name": "回响·静默", "school": "异能", "desc": "信号盲区内犯罪不留痕迹", "crime_ghost": true},
	{"id": "e_sense", "name": "回响·尸感", "school": "异能", "desc": "感知附近丧尸方位", "zombie_sense": true},
	{"id": "e_regen", "name": "回响·微光愈合", "school": "异能", "desc": "每秒回复 0.5 生命", "regen": 0.5},
	{"id": "e_ammo_drop", "name": "回响·弹雨", "school": "诡道", "desc": "丧尸掉落弹药率 +10%", "ammo_drop": 0.10},
	{"id": "e_luck", "name": "回响·偏财", "school": "诡道", "desc": "掉落价值 +20%", "loot_mult": 1.2},
	{"id": "e_shadow", "name": "回响·潜影", "school": "诡道", "desc": "发出的噪音 -25%", "noise_mult": 0.75},
	{"id": "e_scavenger", "name": "回响·拾荒直觉", "school": "诡道", "desc": "据点储物折现比例 +10%", "cashout_bonus": 0.10},
]

const STATION_COVERAGE := 1140.0
const STATION_HP := 100
const ENGINEER_DELAY_MIN := 20.0
const ENGINEER_DELAY_MAX := 40.0
const ENGINEER_REPAIR_MIN := 8.0
const ENGINEER_REPAIR_MAX := 12.0
const ENGINEER_HP := 45

const CITY_SIZE := Vector2(14400, 9000)
const ROADS := [
	Rect2(0, 1486, 14400, 506),
	Rect2(0, 3320, 14400, 506),
	Rect2(0, 5200, 14400, 506),
	Rect2(0, 7200, 14400, 506),
	Rect2(1581, 0, 506, 9000),
	Rect2(5533, 0, 506, 9000),
	Rect2(9200, 0, 506, 9000),
	Rect2(12500, 0, 506, 9000),
]

const BUILDING_LAYOUT := [
	{"id": "food", "position": Vector2(1012, 822), "size": Vector2(320, 220)},
	{"id": "gun", "position": Vector2(4427, 822), "size": Vector2(320, 220)},
	{"id": "hospital", "position": Vector2(1012, 2624), "size": Vector2(320, 220)},
	{"id": "bank", "position": Vector2(4427, 2624), "size": Vector2(320, 220)},
	{"id": "police", "position": Vector2(3036, 2783), "size": Vector2(420, 220)},
	{"id": "prison", "position": Vector2(3800, 4050), "size": Vector2(360, 240)},
	{"id": "house", "position": Vector2(6798, 696), "size": Vector2(240, 180), "color": Color(0.44, 0.35, 0.28, 1.0)},
	{"id": "house", "position": Vector2(7652, 696), "size": Vector2(240, 180), "color": Color(0.5, 0.42, 0.36, 1.0)},
	{"id": "house", "position": Vector2(6798, 3004), "size": Vector2(240, 180), "color": Color(0.4, 0.37, 0.34, 1.0)},
	{"id": "house", "position": Vector2(7652, 3004), "size": Vector2(240, 180), "color": Color(0.46, 0.4, 0.3, 1.0)},
	{"id": "house", "position": Vector2(949, 4174), "size": Vector2(240, 180), "color": Color(0.43, 0.36, 0.31, 1.0)},
	{"id": "house", "position": Vector2(2530, 4174), "size": Vector2(240, 180), "color": Color(0.48, 0.41, 0.33, 1.0)},
	{"id": "house", "position": Vector2(4427, 4174), "size": Vector2(240, 180), "color": Color(0.41, 0.35, 0.3, 1.0)},
	{"id": "house", "position": Vector2(6956, 4174), "size": Vector2(240, 180), "color": Color(0.47, 0.39, 0.32, 1.0)},
	{"id": "house", "position": Vector2(2846, 632), "size": Vector2(240, 180), "color": Color(0.45, 0.38, 0.33, 1.0)},
	{"id": "house", "position": Vector2(3320, 4111), "size": Vector2(240, 180), "color": Color(0.42, 0.34, 0.29, 1.0)},
	{"id": "gas", "position": Vector2(2600, 1330), "size": Vector2(320, 220)},
	{"id": "gas", "position": Vector2(9880, 2624), "size": Vector2(320, 220)},
	{"id": "power", "position": Vector2(13300, 2624), "size": Vector2(420, 260)},
	{"id": "military", "position": Vector2(12500, 7000), "size": Vector2(560, 420)},
]

const BASE_STATIONS := [
	{"name": "城北基站", "position": Vector2(2213, 632)},
	{"name": "城西基站", "position": Vector2(632, 1265)},
	{"name": "中心基站", "position": Vector2(4047, 2087)},
	{"name": "城东基站", "position": Vector2(6956, 2213)},
	{"name": "东区基站", "position": Vector2(11000, 1100)},
	{"name": "南区基站", "position": Vector2(3000, 6300)},
]

const OUTBREAK_SITES := [
	{"name": "地铁站口", "position": Vector2(3036, 1138), "spread": 1.4},
	{"name": "医院急诊部", "position": Vector2(1012, 2624), "spread": 1.9},
	{"name": "西侧集市", "position": Vector2(569, 1960), "spread": 1.15},
	{"name": "东侧码头", "position": Vector2(7589, 1960), "spread": 0.95},
	{"name": "新住宅区", "position": Vector2(6640, 3889), "spread": 1.25},
	{"name": "东区工地", "position": Vector2(11000, 3700), "spread": 1.3},
	{"name": "南部住宅区", "position": Vector2(2400, 6300), "spread": 1.4},
]

const TOWERS := [
	{"position": Vector2(420, 380), "size": Vector2(360, 360), "height": 40.0, "color": Color(0.55, 0.58, 0.62)},
	{"position": Vector2(420, 1150), "size": Vector2(360, 300), "height": 30.0, "color": Color(0.6, 0.55, 0.5)},
	{"position": Vector2(3600, 400), "size": Vector2(400, 400), "height": 55.0, "color": Color(0.5, 0.54, 0.6)},
	{"position": Vector2(3600, 1150), "size": Vector2(400, 300), "height": 34.0, "color": Color(0.58, 0.55, 0.52)},
	{"position": Vector2(6350, 1200), "size": Vector2(350, 300), "height": 45.0, "color": Color(0.52, 0.56, 0.6)},
	{"position": Vector2(400, 2200), "size": Vector2(360, 320), "height": 36.0, "color": Color(0.6, 0.56, 0.5)},
	{"position": Vector2(400, 3050), "size": Vector2(360, 260), "height": 28.0, "color": Color(0.55, 0.52, 0.48)},
	{"position": Vector2(2500, 2250), "size": Vector2(380, 380), "height": 60.0, "color": Color(0.48, 0.52, 0.58)},
	{"position": Vector2(3600, 3000), "size": Vector2(400, 300), "height": 42.0, "color": Color(0.56, 0.53, 0.5)},
	{"position": Vector2(6700, 2250), "size": Vector2(400, 350), "height": 50.0, "color": Color(0.5, 0.55, 0.58)},
	{"position": Vector2(7500, 4350), "size": Vector2(350, 300), "height": 38.0, "color": Color(0.57, 0.54, 0.5)},
	{"position": Vector2(400, 4300), "size": Vector2(340, 260), "height": 32.0, "color": Color(0.55, 0.52, 0.47)},
]

const WEAPONS := {
	"pistol": {
		"name": "手枪", "caliber": "pistol", "damage": 28, "cooldown": 0.2, "mag": 6, "reload": 1.3,
		"pellets": 1, "spread": 0.0, "noise": 1.0, "aim_fov": 52.0, "range": 25.0,
		"flash": 0.16,
		# 伤害随距离衰减：5m 满伤 / 10m 80% / 15m 60% / 20m 30%
		"falloff": [[5.0, 1.0], [10.0, 0.8], [15.0, 0.6], [20.0, 0.3]],
		# 弹道偏移随距离：10m 内几乎为零，15m/20m 逐渐明显
		"dist_spread": [[10.0, 0.0], [15.0, 0.02], [20.0, 0.04]],
		# 只有 10m 内才允许爆头
		"headshot_range": 10.0,
	},
	"smg": {
		"name": "冲锋枪", "caliber": "smg", "damage": 13, "cooldown": 0.07, "mag": 30, "reload": 0.85,
		"pellets": 1, "spread": 0.045, "auto": true, "noise": 1.0, "aim_fov": 55.0,
		"range": 40.0, "flash": 0.12,
		# 伤害随距离衰减：20m 满伤 / 25m 80% / 30m 65% / 40m（最大射程）50%
		"falloff": [[20.0, 1.0], [25.0, 0.8], [30.0, 0.65], [40.0, 0.5]],
	},
	"shotgun": {
		"name": "霰弹枪", "caliber": "shotgun", "damage": 16, "cooldown": 0.8, "mag": 6, "reload": 2.6,
		"pellets": 8, "spread": 0.19, "noise": 1.2, "aim_fov": 58.0, "range": 20.0,
		"flash": 0.42,
	},
	"rifle": {
		"name": "步枪", "caliber": "rifle", "damage": 32, "cooldown": 0.12, "mag": 30, "reload": 1.9,
		"pellets": 1, "spread": 0.02, "auto": true, "penetrate": 2, "noise": 1.0,
		"aim_fov": 50.0, "range": 75.0, "flash": 0.2,
	},
	"sniper": {
		"name": "狙击枪", "caliber": "sniper", "damage": 130, "cooldown": 1.4, "mag": 5, "reload": 2.6,
		"pellets": 1, "spread": 0.0, "head_mult": 3.0, "auto": true, "penetrate": 4,
		"noise": 1.2, "aim_fov": 24.0, "range": 140.0, "flash": 0.5,
	},
	"lmg": {
		"name": "重机枪", "caliber": "lmg", "damage": 70, "cooldown": 0.25, "mag": 100, "reload": 4.5,
		"pellets": 1, "spread": 0.05, "auto": true, "penetrate": 3, "noise": 1.4,
		"aim_fov": 58.0, "range": 65.0, "flash": 0.3,
	},
	"grenade": {
		"name": "手榴弹", "damage": 95, "radius": 6.5, "cooldown": 1.2,
		"mag": 1, "reload": 1.2, "explosive": true, "noise": 2.0, "aim_fov": 60.0,
		"range": 35.0, "flash": 0.5,
	},
	"rpg": {
		"name": "火箭炮", "damage": 200, "radius": 8.0, "cooldown": 1.2,
		"mag": 1, "reload": 3.0, "explosive": true, "rocket": true, "noise": 2.5,
		"aim_fov": 60.0, "range": 90.0, "flash": 0.65,
	},
	"melee": {
		"name": "近战", "damage": 20, "cooldown": 0.45,
		"melee": true, "range": 36.0, "arc": 1.0, "aim_fov": 60.0,
	},
}

const CAPS := {"food": 50, "meds": 50, "ammo": 200, "materials": 200, "fuel": 60, "metal": 9999, "parts": 9999}

# 背包分类分区（每个物品只占 1 格，不再有格子尺寸 / 拖拽摆放）
const BACKPACK_GROUPS := [
	{"id": "food", "title": "食物"},
	{"id": "med", "title": "药品"},
	{"id": "ammo", "title": "弹药"},
	{"id": "weapon", "title": "武器"},
	{"id": "special", "title": "特殊物品"},
]

# loot 的 cat → 背包分区
const LOOT_CAT_GROUP := {
	"food": "food",
	"drink": "food",
	"med": "med",
	"melee": "weapon",
	"ranged": "weapon",
	"attach": "special",
	"tool": "special",
	"armor": "special",
	"junk": "special",
	"valuable": "special",
}

const MAX_STAMINA := 100.0
const MAX_SATIETY := 100.0
const SATIETY_DRAIN := 0.35
const STARVE_INTERVAL := 1.0
const STARVE_DAMAGE := 2

const BUILDINGS := {
	"food": {
		"name": "食品店",
		"color": Color(0.24, 0.55, 0.32, 1.0),
		"crime_level": 1,
		"clerks": 1,
		"cops": 0,
		"items": [
			{"kind": "food", "name": "罐头", "price": 15, "cash": 0},
			{"kind": "food", "name": "面包", "price": 10, "cash": 0},
			{"kind": "food", "name": "矿泉水", "price": 8, "cash": 0},
		],
	},
	"gun": {
		"name": "枪店",
		"color": Color(0.5, 0.34, 0.2, 1.0),
		"crime_level": 2,
		"clerks": 1,
		"cops": 0,
		"items": [
			{"kind": "ammo", "name": "手枪弹药", "price": 30, "cash": 0},
			{"kind": "ammo", "name": "步枪弹药", "price": 45, "cash": 0},
			{"kind": "weapon", "name": "霰弹枪", "weapon": "shotgun", "price": 250, "cash": 0},
			{"kind": "weapon", "name": "冲锋枪", "weapon": "smg", "price": 420, "cash": 0},
			{"kind": "weapon", "name": "手榴弹", "weapon": "grenade", "price": 90, "cash": 0},
		],
	},
	"bank": {
		"name": "银行",
		"color": Color(0.25, 0.42, 0.62, 1.0),
		"crime_level": 2,
		"clerks": 1,
		"cops": 1,
		"items": [
			{"kind": "cash", "name": "现金包裹", "price": 0, "cash": 60},
			{"kind": "cash", "name": "保险柜现金", "price": 0, "cash": 120},
			{"kind": "cash", "name": "金条", "price": 0, "cash": 250},
		],
	},
	"hospital": {
		"name": "医院",
		"color": Color(0.72, 0.76, 0.8, 1.0),
		"crime_level": 2,
		"clerks": 1,
		"cops": 0,
		"items": [
			{"kind": "meds", "name": "恢复药水", "price": 60, "cash": 0},
			{"kind": "meds", "name": "绷带", "price": 15, "cash": 0},
		],
	},
	"military": {
		"name": "军营",
		"color": Color(0.32, 0.4, 0.28, 1.0),
		"crime_level": 3,
		"clerks": 0,
		"cops": 0,
		"items": [],
	},
	"police": {
		"name": "警察局",		"color": Color(0.16, 0.22, 0.38, 1.0),
		"crime_level": 3,
		"clerks": 0,
		"cops": 2,
		"items": [
			{"kind": "ammo", "name": "警用弹药", "price": 0, "cash": 0},
			{"kind": "weapon", "name": "警用步枪", "weapon": "rifle", "price": 0, "cash": 0},
			{"kind": "meds", "name": "警用恢复药水", "price": 0, "cash": 0},
		],
	},
	"house": {
		"name": "居民楼",
		"color": Color(0.42, 0.36, 0.3, 1.0),
		"crime_level": 1,
		"clerks": 0,
		"cops": 0,
		"items": [
			{"kind": "food", "name": "冰箱里的食物", "price": 0, "cash": 0},
			{"kind": "cash", "name": "抽屉里的现金", "price": 0, "cash": 40},
			{"kind": "meds", "name": "家庭药箱", "price": 0, "cash": 0},
		],
	},
	"prison": {
		"name": "监狱",
		"color": Color(0.32, 0.34, 0.38, 1.0),
		"crime_level": 3,
		"clerks": 0,
		"cops": 0,
		"items": [],
	},
	"gas": {
		"name": "加油站",
		"color": Color(0.78, 0.3, 0.13, 1.0),
		"crime_level": 1,
		"clerks": 1,
		"cops": 0,
		"items": [
			{"kind": "food", "name": "便利店便当", "price": 12, "cash": 0},
			{"kind": "food", "name": "矿泉水", "price": 8, "cash": 0},
			{"kind": "ammo", "name": "散装子弹", "price": 25, "cash": 0},
		],
	},
	"power": {
		"name": "发电厂",
		"color": Color(0.35, 0.38, 0.42, 1.0),
		"crime_level": 2,
		"clerks": 0,
		"cops": 0,
		"items": [],
	},
}

var money := 200
var hp := 100
var wanted := 0
var vault_key := false
var crime_points := 0
var player_kills := 0
var jail_timer := 0.0
var jail_active := false
var faction := FACTION_HUMAN
var alignment := ALIGN_GOOD
var infected := false
var infection_timer := 0.0
var zombie_redeem := 0
var skill_points := 0
var skills := {}
var mag_state := {}
var reloading := false
var reload_end_msec := 0
var reload_weapon := ""
var suppressors := {}
var scopes := {}
var mutation_levels := {}
var mutations_taken := 0
var meta_weapons := {"pistol": 1, "shotgun": 0, "rifle": 0}
var viewer_position := Vector3.ZERO
var viewer_active := false
var map_building_rects: Array = []
# 已被拆除的 BUILDING_LAYOUT 建筑（像素坐标中心点），小地图跳过绘制
var demolished_buildings: Array = []
# 已被拆除的 TOWERS 塔楼（像素坐标中心点），小地图跳过绘制；与 demolished_buildings 分开，
# 因为塔楼与建筑是两套独立登记（TOWERS 独立绘制、坍塌时移除方式也不同）
var demolished_towers: Array = []
# 已被"搜刮建筑"一次性掏空楼内物资的建筑/塔楼/模型楼（像素坐标中心点），与 demolished_buildings 同一约定
var scavenged_buildings: Array = []
# 建筑搜刮总物资池与冷却（批次 100）：key = 建筑像素坐标中心点。
# 每栋楼一池总物资（与拆除库存同思路），搜刮每次从池里提取，2 分钟一次，池尽即止
const SCAVENGE_POOL_TOTAL := 20
const SCAVENGE_COOLDOWN := 120.0
# 每次搜刮固定产出的制造材料数量（不占物资池，保底收益）
const SCAVENGE_CRAFT_MAT := 20  # 批次 161：搜刮保底制造材料 ×10
var scavenge_pools := {}
var scavenge_cooldowns := {}
# 建筑/塔楼剩余可拆建材库存（key = position: Vector2 像素坐标，value = 剩余量）
var building_material_pool := {}
# 建筑/塔楼结构耐久（key 同上），爆炸物扣血；与材料库存独立，任一归零都触发坍塌
var building_hp := {}
var loot_items: Array = []
# 本局收集的 Boss 专属材料（尸王核心/尸皇之血/尸神之息），供后续局外图纸解锁
var boss_relics := {}
var infinite_ammo := false
var infinite_reserve := false
var _crime_reports: Array = []
var _gunshot_alerts: Array = []
var _last_gunshot_notice := 0
# 异能量：击杀丧尸积累，可应急治疗（H），撤离/败北结算时 1:1 折算 SP
var anomaly := 0
# 发电机状态：燃烧累积秒数 / 断油提醒只发一次
var _gen_burn := 0.0
var _gen_stall_notified := false
# 城市电网：发电厂被修复后为 true（断电后恢复全城供电）
var grid_repaired := false
# 已被摧毁/消散的异能量场 id 名单（联机同步用）
var zones_destroyed: Array = []
# 当前场上丧尸总数（proto3d 每 0.5s 刷新；丧尸 AI 按尸潮规模自动降频）
var zombie_horde_size := 0
# 玩家当前是否站在异能量场内（HUD 警示用，由 anomaly_zone3d 维护）
var in_anomaly_zone := false
var armor_id := ""
var armor_resist_value := 0.0
var melee_item := ""
var melee_item_damage := 0
var meta_supplies := {"food": 0, "meds": 0, "ammo": 0}
var space_energy := 0
var runs_played := 0
var extractions := 0
var attrs := {"vitality": 0, "agility": 0, "perception": 0, "will": 0, "luck": 0}
var early_entry := 0
var early_entry_buys := 0
var endings_seen: Array = []
var intel: Array = []
var revival_stone := false
var revive_count := 0
# 肉鸽新手提示是否已展示过（"首局"引导，见设计文档 2.3）
var rogue_hints_seen := false
var _meta_loaded := false
var test_mode := false
var test_points := 999
# —— 肉鸽模式：局内成长（不跨局保留），从主菜单专用入口开启 ——
signal rogue_levelup_offered(choices: Array)
signal rogue_progress_changed
var rogue_mode := false
var rogue_xp := 0
var rogue_level := 0
var rogue_ranks := {}
# 场景侧回写：准备倒计时（秒）与剩余能量点数量，HUD 直接读
var rogue_prep_left := 0.0
var rogue_cores_left := 0
# 肉鸽激活后经过的秒数：丧尸随时间变强
var rogue_active_elapsed := 0.0
# 顺序关卡（设计文档 4.1/4.2）：当前关卡号（0=未开始）、阶段（prep/active/dev/won）、发育期剩余秒数
var rogue_stage := 0
var rogue_phase := "prep"
var rogue_dev_left := 0.0
# 训练场（单位试验场）：会掉血但锁定 1 滴不死，3 秒未受伤自动回满
var training_ground := false
# 训练场饱食度 5 秒回满计时
var _training_satiety_timer := 0.0
# —— 武器右键特殊技能：冷却统一管理 ——
var _skill_cd_until := {}
const SKILL_CD := {
	"melee": 8.0, "pistol": 15.0, "smg": 30.0, "rifle": 10.0,
	"shotgun": 35.0, "lmg": 30.0, "sniper": 15.0,
}
# 冲锋枪技能：5 秒疾风窗口（前 3 次闪避：距离翻倍、CD 1/3、耗 10 体力；之后窗口内闪避 CD 2/3）
var free_dash_until_msec := 0
# 疾风窗口内剩余强化闪避次数
var wind_dashes_left := 0
# 训练场开关：武器技能无冷却
var no_skill_cd := false
# 霰弹枪技能：剩余爆破弹数（0 = 普通弹药）
var shotgun_breach_left := 0
# 冲锋枪技能：5 秒换弹加速
var reload_haste_until_msec := 0
# 恢复药水持续回复状态（hot_total 总量按 hot_duration 秒均匀回完）
var _hot_left := 0.0
var _hot_rate := 0.0
var _hot_accum := 0.0
# —— 感染累积：暴露值满 100 才感染（缓慢衰减）；防护服完全阻挡但耗耐久 ——
var infection_exposure := 0.0
var hazmat_durability := 100.0
const INFECTION_EXPOSURE_MAX := 100.0
const HAZMAT_MAX_DURABILITY := 100.0
const EXPOSURE_DECAY := 1.5
# —— 中毒（狼蛛毒液）：持续扣血 + 移速 -15% ——
var poison_timer := 0.0
var poison_total := 0.0
var _poison_accum := 0.0
const POISON_DPS := 2.0
const POISON_SLOW := 0.15
# —— 完美闪避缓速：冲刺闪过怪物攻击触发，5 秒全局缓速 90%，退出后进入 40 秒 CD ——
signal slowmo_changed(active: bool)
var slowmo_active := false
var _slowmo_until := 0
var _slowmo_cd_until := 0

const SLOWMO_MSEC := 5000
const SLOWMO_CD_MSEC := 40000
const ROGUE_UPGRADES := [
	{"id": "damage", "name": "火力强化", "desc": "枪械伤害 +15%", "max": 5},
	{"id": "rapid", "name": "快速射击", "desc": "射击间隔 -7%", "max": 5},
	{"id": "speed", "name": "疾行", "desc": "移动速度 +8%", "max": 5},
	{"id": "vital", "name": "体魄", "desc": "生命上限 +20 并回满", "max": 5},
	{"id": "crit", "name": "致命瞄准", "desc": "暴击率 +6%", "max": 5},
	{"id": "reload", "name": "快速装填", "desc": "换弹时间 -12%", "max": 5},
	{"id": "magnet", "name": "磁力拾取", "desc": "磁吸范围 +40%", "max": 5},
	{"id": "armor", "name": "硬化皮肤", "desc": "受到伤害 -8%", "max": 5},
	{"id": "pierce", "name": "穿透弹头", "desc": "子弹多穿透 1 个目标", "max": 3},
]
var mutation_queue: Array = []
var mutation_offer: Array = []
var pending_mutation := ""
var _survival_timer := 0.0
var _heal_accum := 0.0
var _last_damage_msec := 0
var _announced_stage := -1
var _combat_regen_until := 0
var _combat_regen_rate := 0.0
var _serum_until := 0
var _serum_rate := 0.0
var _nap_timer := 0.0
var _second_wind_msec := 0
var resources := {"food": 0, "meds": 0, "ammo": 12, "materials": 0, "fuel": 0}
var weapons := {"pistol": 1, "shotgun": 0, "rifle": 0}
var current_weapon := "pistol"
var stamina := MAX_STAMINA
var satiety := MAX_SATIETY
var return_position := SPAWN_POS
var pending_building := ""

var phase := "prepare"
var round_elapsed := 0.0
var time_left := PREPARE_MIN
var outbreak_elapsed := 0.0
var outbreak_site: Dictionary = {}
var outbreak_sites: Array = []
var day_number := 1
var day_elapsed := 0.0
# 天气系统：黎明重roll（晴 50% / 阴 30% / 雨 20%），月相 0.2~1.0 每晚随机
var weather := "clear"
var moon_phase := 1.0
var debug_time_scale := 1.0
var home_base: Dictionary = {}
# 建造模式开关（base_build3d 进入/退出时设置）：fps_player 据此禁止开火
var base_build_mode := false
# 统一交互菜单开关（hud3d 按 E 打开交互菜单时设置）：遗留 E 轮询节点据此让位
var interact_menu_open := false
# 炮击指挥中：指向正在指挥的迫击炮节点（null = 不在指挥），期间禁止开火、Esc 退出指挥
var mortar_command: Node3D = null
# 联合打击：指挥中左键选点时，所有就绪的迫击炮/火炮齐射同一点
var mortar_volley := false
# 单类型指挥：当前指挥的炮种（mortar/cannon），每次点击只发射该类型中一门就绪的炮
var mortar_command_kind := ""
# 是否为 Q 远程指挥（离开信号区自动中断）；E 站在炮边本地指挥不受信号限制
var mortar_command_remote := false
# 场景全部迫击炮/火炮的缓存：指挥/齐射用，低频（0.5s）重建，避免每帧整树递归
var artillery_cache: Array = []
var _artillery_cache_stamp := -1000
# 远程打击模式（Tab 圆盘选择的迫击炮）：打击点额外要求在信号覆盖内
var mortar_remote := false
# 远程打击圆盘开关（hud3d 打开/关闭时设置）
var strike_dial_open := false
# 观测点选择：进入世界时由观测舱设置的出生点（像素坐标），Vector2.ZERO 表示用默认出生点
var spawn_point_override := Vector2.ZERO
var run_echoes: Array = []
var echo_offer: Array = []
var boss_sp_bonus := 0
var _last_world_stage := -1
var skills_open := false

var news: Array = []
var map_open := false
var backpack_open := false
var pause_menu_open := false
var zombie_transform_chance := 0.99
var bite_infect_chance := 0.99
var spread_infect_chance := 0.9
var transform_delay := 10.0
var signal_strength := 0.0
var in_coverage := false

var home_scene := "res://scenes/city.tscn"
var custom_map_path := ""
var custom_outbreak := false
var custom_map_size := Vector2.ZERO

signal custom_outbreak_site_needed(stage: int)
var return_point_3d := Vector3.ZERO

var _last_seen_msec := 0
var _intro_done := false
var _starve_timer := 0.0
var _signal_sources := {}
# 信号干扰源（能量场 25m 内信号强制 <10%，设计文档 5.5）：id → {pos, radius}
var _signal_interference := {}
var _sighting_msec := 0
var _bite_report_msec := 0
var _transform_report_msec := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--test":
			test_mode = true
	load_meta()
	_sync_weapon_slots()
	_setup_gamepad()
	if test_mode:
		apply_test_loadout()
		print("TEST MODE: 无敌 / 全武器 / 全能力 / 全单位展示")


# ===== 手柄按键适配（InputMap 部分：移动摇杆 + 常用动作手柄键）=====
# 其余功能（武器切换/背包/技能/面板/近战等）在 fps_player 用 InputEventJoypadButton 直接适配
func _setup_gamepad() -> void:
	# 左摇杆 → 移动
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	# 手柄按键 → 已有动作
	_joy_btn("jump", JOY_BUTTON_A)              # A = 跳跃
	_joy_btn("interact", JOY_BUTTON_X)          # X = 交互
	_joy_btn("sprint", JOY_BUTTON_LEFT_STICK)   # 左摇杆按下 = 冲刺


func _joy_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _joy_btn(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# 测试模式：立即触发灾变
func debug_start_outbreak() -> void:
	if phase == "prepare":
		time_left = 0.05


# 测试模式：推进到下一个世界阶段
func debug_next_stage() -> void:
	var stage := world_stage_index()
	if stage + 1 >= WORLD_STAGES.size():
		return
	outbreak_elapsed = float(WORLD_STAGES[stage + 1]["at"]) + 0.1
	_update_world_stage()


# 测试模式：昼夜跳转（白天→夜晚，夜晚→次日黎明）
func debug_toggle_daynight() -> void:
	if is_night():
		day_number += 1
		day_elapsed = 0.0
		day_changed.emit(day_number)
	else:
		day_elapsed = NIGHT_START + 1.0


func apply_test_loadout() -> void:
	# 测试模式弹药规则：弹匣有限（要换弹），备弹无限（换弹不耗储备）
	infinite_ammo = false
	infinite_reserve = true
	skills.clear()
	for skill in SKILLS:
		skills[String(skill["id"])] = 100
	mutation_levels.clear()
	for id in MUTATIONS.keys():
		mutation_levels[String(id)] = MUTATION_MAX_RANK
	for id in ZOMBIE_MUTATIONS.keys():
		mutation_levels[String(id)] = MUTATION_MAX_RANK
	mutations_taken = 32
	meta_weapons = {
		"pistol": 1, "shotgun": 1, "rifle": 1, "smg": 1, "sniper": 1,
		"lmg": 1, "grenade": 1, "rpg": 1,
	}
	weapons = meta_weapons.duplicate()
	weapon_slots.clear()
	_sync_weapon_slots()
	mag_state.clear()
	for id in weapons.keys():
		mag_state[id] = mag_size(String(id))
	current_weapon = "rifle"
	weapons_changed.emit()
	skill_points = test_points
	resources = {"food": 50, "meds": 50, "ammo": CAPS["ammo"], "materials": CAPS["materials"], "fuel": CAPS["fuel"]}
	_migrate_legacy_ammo()
	money = 99999
	armor_id = "vest"
	melee_item = "axe"
	melee_item_damage = int(LOOT_ITEMS["axe"]["damage"])
	for id in weapons.keys():
		suppressors[id] = true
	revival_stone = true
	hp = max_hp()
	skills_changed.emit()
	mutations_changed.emit()
	skill_points_changed.emit(skill_points)
	resources_changed.emit()


func load_meta() -> void:
	if _meta_loaded:
		return
	_meta_loaded = true
	if not FileAccess.file_exists(META_PATH):
		return
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	space_energy = int(data.get("space_energy", 0))
	skill_points = int(data.get("skill_points", skill_points))
	skills = data.get("skills", {})
	mutation_levels = data.get("mutations", {})
	mutations_taken = int(data.get("mutations_taken", 0))
	meta_weapons = data.get("weapons", meta_weapons)
	meta_supplies = data.get("supplies", meta_supplies)
	runs_played = int(data.get("runs", 0))
	extractions = int(data.get("extractions", 0))
	attrs = data.get("attrs", attrs)
	early_entry = int(data.get("early_entry", 0))
	early_entry_buys = int(data.get("early_entry_buys", 0))
	dash_level = int(data.get("dash_level", 0))
	endings_seen = data.get("endings_seen", [])
	intel = data.get("intel", [])
	revival_stone = bool(data.get("revival_stone", false))
	rogue_hints_seen = bool(data.get("rogue_hints_seen", false))
	loot_items = data.get("loot", loot_items)
	armor_id = String(data.get("armor", armor_id))
	armor_resist_value = float(data.get("armor_resist", armor_resist_value))
	melee_item = String(data.get("melee_item", melee_item))
	melee_item_damage = int(data.get("melee_damage", melee_item_damage))
	suppressors = data.get("suppressors", suppressors)
	scopes = data.get("scopes", scopes)
	hazmat_durability = float(data.get("hazmat_durability", HAZMAT_MAX_DURABILITY))


func save_meta() -> void:
	if test_mode:
		return
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"space_energy": space_energy,
		"skill_points": skill_points,
		"skills": skills,
		"mutations": mutation_levels,
		"mutations_taken": mutations_taken,
		"weapons": meta_weapons,
		"supplies": meta_supplies,
		"runs": runs_played,
		"extractions": extractions,
		"attrs": attrs,
		"early_entry": early_entry,
		"early_entry_buys": early_entry_buys,
		"dash_level": dash_level,
		"endings_seen": endings_seen,
		"intel": intel,
		"revival_stone": revival_stone,
		"rogue_hints_seen": rogue_hints_seen,
		"loot": loot_items,
		"armor": armor_id,
		"armor_resist": armor_resist_value,
		"melee_item": melee_item,
		"melee_damage": melee_item_damage,
		"suppressors": suppressors,
		"scopes": scopes,
		"hazmat_durability": hazmat_durability,
	}))
	file.close()


func settle_run(won: bool) -> Dictionary:
	runs_played += 1
	var days := clampi(day_number - 1, 0, FINAL_DAY)
	var day_sp := days * 50
	var storage_sp := home_storage_cashout()
	var summary := {
		"won": won, "loot": 0, "bonus": 0,
		"days": days, "day_sp": day_sp,
		"boss_sp": boss_sp_bonus, "storage_sp": storage_sp,
		"anomaly_sp": anomaly,
		"total": space_energy,
	}
	if won:
		extractions += 1
		var loot := (
			int(resources.get("food", 0)) * 2
			+ int(resources.get("meds", 0)) * 4
			+ total_ammo()
			+ money / 10
		)
		var bonus := 60 + maxi(0, zombie_stage_index() + 1) * 10
		space_energy += loot + bonus + loot_total_value() / 4
		summary["loot"] = loot
		summary["bonus"] = bonus
	space_energy += day_sp + boss_sp_bonus + storage_sp + anomaly
	if anomaly > 0:
		notify("异能量折算 SP +%d" % anomaly)
	summary["total"] = space_energy
	save_meta()
	return summary


func return_to_hub() -> void:
	settle_run(phase == "won")
	# 联机局结束回观测舱：断开 ENet，避免挂着僵尸连接（重进需重新建房/加入）
	Network.leave()
	get_tree().change_scene_to_file(HUB_SCENE)


func enter_city() -> void:
	reset_run()
	get_tree().change_scene_to_file("res://scenes3d/proto3d.tscn")


func spend_energy(amount: int) -> bool:
	if space_energy < amount:
		notify("SP 不足（需要 %d）" % amount)
		return false
	space_energy -= amount
	return true


func buy_shop_item(id: String) -> bool:
	var info: Dictionary = SHOP.get(id, {})
	if info.is_empty():
		return false
	var cost := int(info["cost"])
	match id:
		"skill_point":
			if not spend_energy(cost):
				return false
			skill_points += 1
			skill_points_changed.emit(skill_points)
		"ammo10", "meds1", "food3":
			if not spend_energy(cost):
				return false
			var kind := "ammo"
			var amount := 10
			if id == "meds1":
				kind = "meds"
				amount = 1
			elif id == "food3":
				kind = "food"
				amount = 3
			meta_supplies[kind] = int(meta_supplies.get(kind, 0)) + amount
		"pistol", "shotgun", "rifle", "smg", "sniper", "lmg", "grenade", "rpg":
			if int(meta_weapons.get(id, 0)) > 0:
				notify("已经解锁了")
				return false
			if not spend_energy(cost):
				return false
			meta_weapons[id] = 1
		"suppressor":
			if not spend_energy(cost):
				return false
			add_loot("suppressor")
		"scope_rds", "scope_2x", "scope_4x", "scope_8x":
			if not spend_energy(cost):
				return false
			add_loot(id)
		"clothes":
			if not spend_energy(cost):
				return false
			add_loot(id)
		"revival_stone":
			return buy_revival_stone()
		_:
			return false
	save_meta()
	notify("观测舱购买：%s" % info["name"])
	return true


func buy_revival_stone() -> bool:
	if revival_stone:
		notify("复活石已持有（一次性购买，永久生效）")
		return false
	if not spend_energy(REVIVE_STONE_COST):
		return false
	revival_stone = true
	save_meta()
	notify("购得复活石：可在城市占领据点，死亡后于据点复活")
	return true


# 升级到第 n+1 级（n 为当前等级）所需的 SP
func attr_cost(n: int) -> int:
	return int(ATTR_COST_BASE * pow(ATTR_COST_MULT, n))


func attr_level(id: String) -> int:
	return int(attrs.get(id, 0))


# 属性每级 +2% 的通用加成系数
func attr_mult(id: String) -> float:
	return 1.0 + attr_level(id) * 0.02


func buy_attr(id: String) -> bool:
	if not ATTRS.has(id):
		return false
	var level := attr_level(id)
	var cost := attr_cost(level)
	if not spend_energy(cost):
		return false
	attrs[id] = level + 1
	save_meta()
	var info: Dictionary = ATTRS[id]
	notify("%s 强化至 %d 级（%s）" % [String(info["name"]), level + 1, String(info["desc"])])
	return true


# 开局准备时长：基础 5 分钟 + 系统空间购买的提前入场分钟数，单位秒
func prep_duration() -> float:
	return PREPARE_MIN + early_entry * 60.0


# 下一档提前入场的目标分钟数，已满返回 0
func next_early_entry() -> int:
	if early_entry >= EARLY_ENTRY_MAX:
		return 0
	if early_entry <= 0:
		return EARLY_ENTRY_FIRST
	return mini(early_entry + EARLY_ENTRY_STEP, EARLY_ENTRY_MAX)


func early_entry_cost() -> int:
	if next_early_entry() <= 0:
		return 0
	return int(EARLY_ENTRY_BASE_COST * pow(EARLY_ENTRY_COST_MULT, early_entry_buys))


func buy_early_entry() -> bool:
	var target := next_early_entry()
	if target <= 0:
		notify("提前入场已达上限 %d 分钟" % EARLY_ENTRY_MAX)
		return false
	var cost := early_entry_cost()
	if not spend_energy(cost):
		return false
	early_entry = target
	early_entry_buys += 1
	save_meta()
	notify("提前入场 +%d 分钟（准备期共 %d 分钟）" % [early_entry, int(round(prep_duration() / 60.0))])
	return true


# 空间网格：粗粒度哈希（cell 20m），每 0.25s 从组重建一次，
# 供丧尸/市民/炮塔索敌就近查询，替代逐只全组扫描（2D 实体不进网格）
const SPATIAL_CELL := 20.0
const SPATIAL_INTERVAL := 0.25
const SPATIAL_GROUPS := ["zombies", "npcs", "base_defense"]
var _spatial_cells := {}
var _spatial_timer := 0.0
var _spatial_worker_busy := false


func _process(delta: float) -> void:
	_spatial_timer -= delta
	if _spatial_timer <= 0.0:
		_spatial_timer = SPATIAL_INTERVAL
		_rebuild_spatial_grid()
	# 训练场：3 秒未受伤自动回满
	if training_ground and hp < max_hp():
		if Time.get_ticks_msec() - _last_damage_msec > 3000:
			hp = max_hp()
			hp_changed.emit(hp)
	# 训练场：每 5 秒饱食度自动回满
	if training_ground:
		_training_satiety_timer -= delta
		if _training_satiety_timer <= 0.0:
			_training_satiety_timer = 5.0
			satiety = MAX_SATIETY
	# 中毒：每秒扣血（叠加刷新取最长）
	if poison_timer > 0.0:
		poison_timer -= delta
		_poison_accum += POISON_DPS * delta
		if _poison_accum >= 1.0:
			var tick := int(_poison_accum)
			_poison_accum -= float(tick)
			damage_player(tick)
	# 恢复药水持续回复：按每秒速率均匀回完剩余总量
	if _hot_left > 0.0:
		var hot_gain := _hot_rate * delta
		if hot_gain >= _hot_left:
			hot_gain = _hot_left
		_hot_left -= hot_gain
		_hot_accum += hot_gain
		if _hot_accum >= 1.0:
			var tick := int(_hot_accum)
			_hot_accum -= float(tick)
			heal_player(tick)
	# 完美闪避缓速结束：恢复正常速度，40 秒 CD 从此刻起计
	if slowmo_active and Time.get_ticks_msec() >= _slowmo_until:
		slowmo_active = false
		Engine.time_scale = 1.0
		_slowmo_cd_until = Time.get_ticks_msec() + SLOWMO_CD_MSEC
		slowmo_changed.emit(false)
	_update_reload()
	_tick_generator(delta)
	if not Network.is_server():
		return
	if jail_active:
		jail_timer -= delta
		if jail_timer <= 0.0:
			release_from_jail()
	_update_crime_reports()
	if is_run_over():
		return
	var scaled := delta * debug_time_scale
	round_elapsed += delta
	_survival_timer += scaled
	if _survival_timer >= SURVIVAL_POINT_SECONDS:
		_survival_timer -= SURVIVAL_POINT_SECONDS
		award_skill_point(1)
	_update_mutations_regen(delta)
	_update_survival(delta)

	if phase == "prepare":
		time_left = maxf(0.0, time_left - scaled)
		if time_left <= 0.0:
			start_outbreak()
	elif zombies_active():
		outbreak_elapsed += scaled
		_update_world_stage()
		_advance_day_clock(scaled)


func zombies_active() -> bool:
	return phase == "outbreak" or phase == "survival"


func is_night() -> bool:
	return zombies_active() and day_elapsed >= NIGHT_START


func is_raining() -> bool:
	return weather == "rain"


# 夜晚环境亮度系数：月相 ×（雨天 0.3），月黑风高夜接近全黑
func night_brightness() -> float:
	return moon_phase * (0.3 if is_raining() else 1.0)


# 白天环境亮度系数：晴 1.0 / 阴 0.75 / 雨 0.5
func day_brightness() -> float:
	match weather:
		"cloudy":
			return 0.75
		"rain":
			return 0.5
	return 1.0


func weather_name() -> String:
	match weather:
		"cloudy":
			return "阴"
		"rain":
			return "雨"
	return "晴"


# 黎明换天气：晴 50% / 阴 30% / 雨 20%，并重roll月相（0.2~1.0）
func _roll_weather() -> void:
	var roll := randf()
	if roll < 0.5:
		weather = "clear"
	elif roll < 0.8:
		weather = "cloudy"
	else:
		weather = "rain"
	moon_phase = randf_range(0.2, 1.0)
	weather_changed.emit(weather, moon_phase)


# 当天进度 0.0~1.0（准备期或未爆发时返回 0）
func day_progress() -> float:
	if not zombies_active():
		return 0.0
	return clampf(day_elapsed / DAY_LENGTH, 0.0, 1.0)


# 生存期日钟：跨天时发 day_changed 并在黎明提供回响三选一；第 7 天结束强制回档
func _advance_day_clock(scaled_delta: float) -> void:
	day_elapsed += scaled_delta
	while day_elapsed >= DAY_LENGTH:
		day_elapsed -= DAY_LENGTH
		day_number += 1
		if day_number > FINAL_DAY:
			end_run(false, "收容循环重置窗口到达，强制回归")
			return
		_on_day_dawn()


func _on_day_dawn() -> void:
	_roll_weather()
	day_changed.emit(day_number)
	_feed_workers()
	post_message("第 %d 天黎明。收容循环剩余 %d 天" % [day_number, FINAL_DAY - day_number + 1], Vector2.ZERO, "", true)
	notify("第 %d 天黎明 · 天气：%s" % [day_number, weather_name()])
	if day_number == GRID_FAILURE_DAY and not grid_repaired:
		post_message("紧急播报：发电厂燃料耗尽停运，全城大范围停电！", Vector2.ZERO, "city", true)
		notify("发电站停运：路灯/建筑/信号断电，据点用电设备改用储备电力（可修复发电厂恢复）")
	if phase == "outbreak":
		enter_survival()
	offer_echoes()


# 记录被摧毁/消散的异能量场 id（单机存档无关，联机时钟同步给客户端）
func note_zone_destroyed(id: int) -> void:
	if id < 0 or zones_destroyed.has(id):
		return
	zones_destroyed.append(id)


# 联机世界时钟：主机打包，客户端套用（客户端不本地推进世界时钟，见 _process 的闸门）
func clock_payload() -> Dictionary:
	return {
		"phase": phase,
		"time_left": time_left,
		"day_number": day_number,
		"day_elapsed": day_elapsed,
		"weather": weather,
		"moon_phase": moon_phase,
		"outbreak_elapsed": outbreak_elapsed,
		"grid_repaired": grid_repaired,
		"zones_destroyed": zones_destroyed.duplicate(),
	}


func apply_clock(payload: Dictionary) -> void:
	var new_phase := String(payload.get("phase", phase))
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
	time_left = float(payload.get("time_left", time_left))
	var new_day := int(payload.get("day_number", day_number))
	if new_day != day_number:
		day_number = new_day
		day_changed.emit(day_number)
	day_elapsed = float(payload.get("day_elapsed", day_elapsed))
	outbreak_elapsed = float(payload.get("outbreak_elapsed", outbreak_elapsed))
	grid_repaired = bool(payload.get("grid_repaired", grid_repaired))
	var new_weather := String(payload.get("weather", weather))
	var new_moon := float(payload.get("moon_phase", moon_phase))
	if new_weather != weather or not is_equal_approx(new_moon, moon_phase):
		weather = new_weather
		moon_phase = new_moon
		weather_changed.emit(weather, moon_phase)
	var new_zones: Array = payload.get("zones_destroyed", zones_destroyed)
	if new_zones.size() != zones_destroyed.size():
		zones_destroyed = new_zones.duplicate()
		var city := get_tree().current_scene
		if city != null and city.has_method("apply_zone_destruction"):
			city.apply_zone_destruction(zones_destroyed)


# 据点床铺睡觉跳过夜晚：快进到次日黎明，返回是否成功
func sleep_skip_night() -> bool:
	if not zombies_active() or not is_night():
		return false
	day_elapsed = 0.0
	day_number += 1
	if day_number > FINAL_DAY:
		end_run(false, "收容循环重置窗口到达，强制回归")
		return true
	_on_day_dawn()
	notify("你睡了一觉，醒来已是清晨")
	return true


func enter_survival() -> void:
	if phase == "survival":
		return
	phase = "survival"
	phase_changed.emit(phase)
	post_message(
		"观测简报：异变雨进入持续蔓延阶段，收容循环将于第 %d 日结束" % FINAL_DAY,
		Vector2.ZERO,
		"outbreak",
		true
	)
	notify("灾变进入持续蔓延阶段，活下去吧")


func report_zombie_sighting(pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _sighting_msec < 15000:
		return
	_sighting_msec = now
	post_message("目击报告：出现丧尸，位置已标记", _vec3_to_2(pos), "horde")


func report_bite(pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _bite_report_msec < 12000:
		return
	_bite_report_msec = now
	post_message("紧急消息：有人被丧尸咬伤，正在变异", _vec3_to_2(pos), "horde")


func report_transform(pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _transform_report_msec < 12000:
		return
	_transform_report_msec = now
	post_message("警报：有人变异成丧尸，位置已标记", _vec3_to_2(pos), "outbreak")


func _vec3_to_2(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.z) / 0.05


func is_run_over() -> bool:
	return phase == "won" or phase == "lost"


# 消息即时送达：重大消息（带位置）直接在 M 地图上标点，不再走手机/信号延迟投递
func post_message(text: String, pos := Vector2.ZERO, kind := "", _force_delivered := false) -> void:
	var entry := {
		"text": text,
		"pos": pos,
		"has_pos": pos != Vector2.ZERO,
		"kind": kind,
		"read": true,
		"delivered": true,
		"at": round_elapsed,
	}
	news.append(entry)
	if news.size() > 40:
		news.remove_at(0)
	news_posted.emit(text)


func knows(kind: String) -> bool:
	for entry in news:
		if entry["delivered"] and entry["kind"] == kind:
			return true
	return false


func knows_crisis() -> bool:
	return knows("outbreak") or knows("horde")


func read_markers() -> Array:
	var out: Array = []
	for entry in news:
		if entry["read"] and entry["has_pos"]:
			if entry["kind"] == "horde":
				_update_horde_marker(entry)
			out.append(entry)
	return out


func _update_horde_marker(entry: Dictionary) -> void:
	var center: Vector2 = entry["pos"]
	var sum := Vector2.ZERO
	var count := 0
	for zombie in get_tree().get_nodes_in_group("zombies"):
		var zp: Vector2 = _node_pos2(zombie)
		if zp.distance_to(center) <= 300.0:
			sum += zp
			count += 1
	if count > 0:
		entry["pos"] = sum / float(count)


func _node_pos2(node) -> Vector2:
	var p = node.global_position
	if p is Vector3:
		return Vector2(p.x, p.z) / 0.05
	return p


func latest_news() -> String:
	if news.is_empty():
		return "暂无消息"
	return news[news.size() - 1]["text"]


func toggle_map() -> void:
	map_open = not map_open
	map_toggled.emit(map_open)


func mag_size(id: String) -> int:
	var base := int(WEAPONS.get(id, {}).get("mag", 0))
	if has_extended_mag(id):
		base = int(round(base * 1.5))
	return base


func mag_rounds(id: String) -> int:
	if not mag_state.has(id):
		mag_state[id] = mag_size(id)
	return int(mag_state[id])


func consume_round(id: String) -> bool:
	if infinite_ammo:
		return true
	var rounds := mag_rounds(id)
	if rounds <= 0:
		return false
	mag_state[id] = rounds - 1
	# 弹匣打空自动装填（无需再点左键），无备弹时 start_reload 内部会提示
	if rounds - 1 <= 0 and id == current_weapon:
		start_reload()
	return true


func can_start_reload(id: String) -> bool:
	if id == "" or not WEAPONS.has(id) or WEAPONS[id].get("melee", false):
		return false
	if mag_rounds(id) >= mag_size(id):
		return false
	var caliber := caliber_of(id)
	if caliber.is_empty():
		return false
	return infinite_reserve or ammo_count(caliber, weapon_ammo_type(id)) > 0


func start_reload() -> bool:
	if reloading:
		return false
	var id := current_weapon
	if not can_start_reload(id):
		var caliber := caliber_of(id)
		if not caliber.is_empty() and ammo_count(caliber, weapon_ammo_type(id)) <= 0:
			notify("没有备用%s（%s）了" % [caliber_name(caliber), ammo_type_name(weapon_ammo_type(id))])
		return false
	reloading = true
	reload_weapon = id
	# 冲锋枪技能期间换弹加速 50%
	var haste := 0.5 if Time.get_ticks_msec() < reload_haste_until_msec else 1.0
	reload_end_msec = Time.get_ticks_msec() + int(
		float(WEAPONS[id]["reload"]) * echo_reload_mult() * rogue_reload_mult() * haste
		* weapon_reload_speed_mult(id) * 1000.0
	)
	weapons_changed.emit()
	return true


func _update_reload() -> void:
	if not reloading:
		return
	if Time.get_ticks_msec() < reload_end_msec:
		return
	reloading = false
	var id := reload_weapon
	reload_weapon = ""
	if not WEAPONS.has(id):
		return
	var need := mag_size(id) - mag_rounds(id)
	var caliber := caliber_of(id)
	var atype := weapon_ammo_type(id)
	var available := ammo_count(caliber, atype)
	var infinite := infinite_reserve
	var take := need if infinite else mini(need, available)
	if take > 0:
		if not infinite and ammo_stock.has(caliber):
			ammo_stock[caliber][atype] = available - take
		mag_state[id] = mag_rounds(id) + take
		resources_changed.emit()
	weapons_changed.emit()
	notify("换弹完成（弹匣 %d/%d）" % [mag_rounds(id), mag_size(id)])


func reload_progress() -> float:
	if not reloading:
		return 0.0
	var id := reload_weapon
	if not WEAPONS.has(id):
		return 0.0
	var total := float(WEAPONS[id]["reload"]) * echo_reload_mult() * 1000.0
	var remain := float(reload_end_msec - Time.get_ticks_msec())
	return clampf(1.0 - remain / maxf(total, 1.0), 0.0, 1.0)


func has_suppressor(id: String) -> bool:
	return bool(suppressors.get(id, false))


func install_suppressor(id: String) -> bool:
	if id == "" or not WEAPONS.has(id) or bool(WEAPONS[id].get("melee", false)):
		return false
	suppressors[id] = true
	save_meta()
	weapons_changed.emit()
	return true


func has_scope(id: String) -> bool:
	return scopes.has(id)


func install_scope(weapon_id: String, scope_item_id: String) -> bool:
	if weapon_id == "" or not WEAPONS.has(weapon_id):
		return false
	if bool(WEAPONS[weapon_id].get("melee", false)):
		return false
	var info := loot_info(scope_item_id)
	if info.is_empty() or not info.has("view"):
		return false
	scopes[weapon_id] = float(info["view"])
	save_meta()
	weapons_changed.emit()
	return true


func weapon_view_range(weapon_id: String) -> float:
	if scopes.has(weapon_id):
		return float(scopes[weapon_id])
	if weapon_id == "sniper":
		return 30.0
	return DEFAULT_VIEW_RANGE


func weapon_noise_mult(id: String) -> float:
	var base := float(WEAPONS.get(id, {}).get("noise", 1.0))
	if has_suppressor(id):
		base *= 0.25
	return base


# ===== 枪械改装：弹种 / 武器升级 / 配件 / 异能改装槽 =====

# 弹种（更换弹种 = 换战术）：按目标护甲类型计算伤害系数
const AMMO_TYPES := {
	"normal": {"name": "普通弹", "armor": 1.0, "flesh": 1.0},
	"ap": {"name": "穿甲弹", "armor": 1.5, "flesh": 0.9},
	"inc": {"name": "燃烧弹", "armor": 0.85, "flesh": 0.85, "burn": true},
}
const AMMO_TYPE_ORDER := ["normal", "ap", "inc"]
# 每把武器当前装填的弹种（默认普通弹）
var weapon_ammo := {}

# 口径表：每种武器对应专属子弹，互不通用
const CALIBERS := {
	"pistol": {"name": "手枪弹"},
	"smg": {"name": "冲锋枪弹"},
	"shotgun": {"name": "霰弹"},
	"rifle": {"name": "步枪弹"},
	"sniper": {"name": "狙击弹"},
	"lmg": {"name": "机枪弹"},
}
const AMMO_CAP := 9999
# 备弹库存：ammo_stock[口径][弹种] = 数量
var ammo_stock := {}


func caliber_of(id: String) -> String:
	return String(WEAPONS.get(id, {}).get("caliber", ""))


func caliber_name(caliber: String) -> String:
	return String(CALIBERS.get(caliber, {}).get("name", caliber))


# ammo_type 为空串时返回该口径全部弹种合计
func ammo_count(caliber: String, ammo_type := "") -> int:
	if not ammo_stock.has(caliber):
		return 0
	if ammo_type == "":
		var total := 0
		for t in ammo_stock[caliber].values():
			total += int(t)
		return total
	return int(ammo_stock[caliber].get(ammo_type, 0))


func add_ammo(caliber: String, ammo_type: String, amount: int) -> void:
	if not CALIBERS.has(caliber) or not AMMO_TYPES.has(ammo_type) or amount <= 0:
		return
	if not ammo_stock.has(caliber):
		ammo_stock[caliber] = {}
	var cur := int(ammo_stock[caliber].get(ammo_type, 0))
	ammo_stock[caliber][ammo_type] = mini(cur + amount, AMMO_CAP)
	resources_changed.emit()


func total_ammo() -> int:
	var total := 0
	for caliber in ammo_stock:
		total += ammo_count(caliber)
	return total


# 通用「弹药」来源（商店/拾取/掉落/开局）：按持有武器口径均分为普通弹
func grant_generic_ammo(amount: int) -> void:
	var cals: Array = []
	for id in CALIBERS:
		if int(weapons.get(id, 0)) > 0:
			cals.append(id)
	if cals.is_empty():
		cals.append("pistol")
	var each := maxi(1, amount / cals.size())
	for i in cals.size():
		# 余数补到第一个口径，保证总数不少发
		add_ammo(cals[i], "normal", each + (amount - each * cals.size() if i == 0 else 0))


# 旧通用弹药池（resources["ammo"]）迁移：均分后清零
func _migrate_legacy_ammo() -> void:
	var legacy := int(resources.get("ammo", 0))
	if legacy > 0:
		grant_generic_ammo(legacy)
	resources["ammo"] = 0


func weapon_ammo_type(id: String) -> String:
	return String(weapon_ammo.get(id, "normal"))


func set_weapon_ammo(id: String, ammo_type: String) -> void:
	if not AMMO_TYPES.has(ammo_type):
		return
	weapon_ammo[id] = ammo_type
	weapons_changed.emit()


func ammo_type_name(t: String) -> String:
	return String(AMMO_TYPES.get(t, {}).get("name", t))


# 按目标护甲类型取弹种伤害系数
func ammo_damage_mult(ammo_type: String, armored: bool) -> float:
	var info: Dictionary = AMMO_TYPES.get(ammo_type, AMMO_TYPES["normal"])
	return float(info["armor"] if armored else info["flesh"])


func ammo_causes_burn(ammo_type: String) -> bool:
	return bool(AMMO_TYPES.get(ammo_type, {}).get("burn", false))


# 武器升级：每类武器 0~5 级，每级伤害 +8%、换弹速度 +5%（消耗金属+配件，数值待调）
const WEAPON_LEVEL_MAX := 5
const WEAPON_LEVEL_DMG := 0.08
const WEAPON_LEVEL_RELOAD := 0.05
var weapon_levels := {}


func weapon_level(id: String) -> int:
	return int(weapon_levels.get(id, 0))


# 异能宝石增益（随身携带生效，最多 3 颗）：伤害 +10%/颗、生命上限 +25/颗
func anomaly_gem_count() -> int:
	return mini(3, loot_count("anomaly_gem"))


func weapon_damage_mult(id: String) -> float:
	return 1.0 + WEAPON_LEVEL_DMG * weapon_level(id) + 0.1 * anomaly_gem_count()


func weapon_reload_speed_mult(id: String) -> float:
	return 1.0 / (1.0 + WEAPON_LEVEL_RELOAD * weapon_level(id))


func weapon_upgrade_cost(id: String) -> Dictionary:
	var lv := weapon_level(id)
	return {"craft": 30 * (lv + 1)}


func weapon_upgrade(id: String) -> bool:
	if not WEAPONS.has(id) or bool(WEAPONS[id].get("melee", false)):
		return false
	var lv := weapon_level(id)
	if lv >= WEAPON_LEVEL_MAX:
		notify("%s 已满级" % String(WEAPONS[id]["name"]))
		return false
	var cost: Dictionary = weapon_upgrade_cost(id)
	if loot_count("craft_mat") < int(cost["craft"]):
		notify("材料不足（需 制造材料×%d）" % int(cost["craft"]))
		return false
	remove_loot("craft_mat", int(cost["craft"]))
	weapon_levels[id] = lv + 1
	resources_changed.emit()
	weapons_changed.emit()
	notify("%s 升到 %d 级（伤害 +%d%%，换弹 +%d%%）" % [
		String(WEAPONS[id]["name"]), lv + 1,
		int(round(WEAPON_LEVEL_DMG * (lv + 1) * 100.0)),
		int(round(WEAPON_LEVEL_RELOAD * (lv + 1) * 100.0)),
	])
	return true


# —— 配件·弹夹（扩容弹夹：弹容 +50%）——
var extended_mags := {}


func has_extended_mag(id: String) -> bool:
	return bool(extended_mags.get(id, false))


func install_extended_mag(id: String) -> bool:
	if id == "" or not WEAPONS.has(id) or bool(WEAPONS[id].get("melee", false)):
		return false
	extended_mags[id] = true
	weapons_changed.emit()
	return true


func uninstall_extended_mag(id: String) -> void:
	extended_mags.erase(id)
	weapons_changed.emit()


# —— 异能改装槽（消耗 1 颗异能结晶，武器伤害 +20%，数值待调）——
const ECHO_MOD_DMG := 0.2
var echo_mods := {}


func has_echo_mod(id: String) -> bool:
	return bool(echo_mods.get(id, false))


func echo_mod_damage_mult(id: String) -> float:
	return 1.0 + ECHO_MOD_DMG if has_echo_mod(id) else 1.0


func install_echo_mod(id: String) -> bool:
	if id == "" or not WEAPONS.has(id) or bool(WEAPONS[id].get("melee", false)):
		return false
	if has_echo_mod(id):
		return false
	if loot_count("anomaly_crystal") <= 0:
		notify("需要 1 颗异能结晶（打 Boss 或能量场掉落）")
		return false
	remove_loot("anomaly_crystal", 1)
	echo_mods[id] = true
	weapons_changed.emit()
	notify("%s 完成异能改装（伤害 +%d%%）" % [String(WEAPONS[id]["name"]), int(ECHO_MOD_DMG * 100.0)])
	return true


func uninstall_echo_mod(id: String) -> void:
	if not has_echo_mod(id):
		return
	echo_mods.erase(id)
	add_loot("anomaly_crystal", 1)
	weapons_changed.emit()


# —— 配件装/卸辅助（瞄准镜=红点视野、枪口=消音器、弹夹=扩容；造价占位待调）——
const ATTACH_COSTS := {
	"scope": {"craft": 20, "name": "瞄准镜·红点"},
	"muzzle": {"craft": 15, "name": "枪口·消音器"},
	"mag": {"craft": 25, "name": "弹夹·扩容"},
}
const RED_DOT_VIEW := 18.0


func attachment_installed(id: String, kind: String) -> bool:
	match kind:
		"scope":
			return scopes.has(id)
		"muzzle":
			return has_suppressor(id)
		"mag":
			return has_extended_mag(id)
	return false


func install_attachment(id: String, kind: String) -> bool:
	if id == "" or not WEAPONS.has(id) or bool(WEAPONS[id].get("melee", false)):
		return false
	if attachment_installed(id, kind):
		return false
	var cost: Dictionary = ATTACH_COSTS.get(kind, {})
	if loot_count("craft_mat") < int(cost.get("craft", 0)):
		notify("材料不足（需 制造材料×%d）" % int(cost.get("craft", 0)))
		return false
	remove_loot("craft_mat", int(cost.get("craft", 0)))
	match kind:
		"scope":
			scopes[id] = RED_DOT_VIEW
		"muzzle":
			suppressors[id] = true
		"mag":
			extended_mags[id] = true
	resources_changed.emit()
	weapons_changed.emit()
	return true


func uninstall_attachment(id: String, kind: String) -> void:
	match kind:
		"scope":
			scopes.erase(id)
		"muzzle":
			suppressors.erase(id)
		"mag":
			extended_mags.erase(id)
	weapons_changed.emit()


func toggle_backpack() -> void:
	backpack_open = not backpack_open
	backpack_toggled.emit(backpack_open)


# 场景自定义面板（如试验场召唤面板）：参与 ESC 优先级（先关窗口再开暂停菜单）
signal custom_panel_close_requested
var custom_panel_open := false


func any_panel_open() -> bool:
	return backpack_open or skills_open or map_open or custom_panel_open


# 任何需要点击操作的菜单/面板打开时，禁止鼠标左右键攻击（开火/特殊技/近战）
func attack_blocked_by_ui() -> bool:
	return (
		any_panel_open()
		or interact_menu_open
		or pause_menu_open
		or base_build_mode
		or mortar_command != null
		or strike_dial_open
	)


func toggle_pause_menu() -> void:
	pause_menu_open = not pause_menu_open
	if not Network.is_multiplayer():
		get_tree().paused = pause_menu_open
	pause_toggled.emit(pause_menu_open)


func quit_to_menu() -> void:
	pause_menu_open = false
	get_tree().paused = false
	Network.leave()
	get_tree().change_scene_to_file("res://scenes3d/menu3d.tscn")


func close_all_panels() -> void:
	if backpack_open:
		toggle_backpack()
	if skills_open:
		toggle_skills()
	if map_open:
		toggle_map()
	if custom_panel_open:
		custom_panel_close_requested.emit()


func roll_loot(table: String) -> String:
	var list: Array = LOOT_TABLES.get(table, [])
	if list.is_empty():
		return "can"
	return String(list[randi() % list.size()])


func loot_info(id: String) -> Dictionary:
	return LOOT_ITEMS.get(id, {})


func weapon_model_path(id: String) -> String:
	return String(WEAPON_MODELS.get(id, ""))


func loot_name(id: String) -> String:
	return String(loot_info(id).get("name", id))


func loot_count(id: String) -> int:
	for entry in loot_items:
		if String(entry["id"]) == id:
			return int(entry["qty"])
	return 0


# 一次性"搜刮建筑"标记（批次 42）：key 为建筑像素坐标中心点，整栋楼只能搜刮一次
func is_scavenged(key: Vector2) -> bool:
	return scavenged_buildings.has(key)


func mark_scavenged(key: Vector2) -> void:
	if not scavenged_buildings.has(key):
		scavenged_buildings.append(key)


# —— 建筑搜刮总物资池 + 2 分钟冷却（批次 100）——
func scavenge_pool_remaining(key: Vector2) -> int:
	if not scavenge_pools.has(key):
		scavenge_pools[key] = SCAVENGE_POOL_TOTAL
	return int(scavenge_pools[key])


func scavenge_depleted(key: Vector2) -> bool:
	return scavenge_pool_remaining(key) <= 0


func scavenge_cooldown_left(key: Vector2) -> float:
	var until := float(scavenge_cooldowns.get(key, 0.0))
	return maxf(0.0, until - Time.get_ticks_msec() / 1000.0)


func scavenge_available(key: Vector2) -> bool:
	return not scavenge_depleted(key) and scavenge_cooldown_left(key) <= 0.0


# 每次搜刮：从池里提取 want 件（不足则全给），并启动 2 分钟冷却；返回实际拿到件数
func mine_scavenge_pool(key: Vector2, want: int) -> int:
	var left := scavenge_pool_remaining(key)
	var got := mini(left, maxi(want, 0))
	scavenge_pools[key] = left - got
	scavenge_cooldowns[key] = Time.get_ticks_msec() / 1000.0 + SCAVENGE_COOLDOWN
	return got


# 携带上限（恢复药水 10 瓶 / 异能宝石 3 颗 / 炮弹 20+10）
const LOOT_CAPS := {
	"heal_potion": 10,
	"anomaly_gem": 3,
	"mortar_shell": 20,
	"cannon_shell": 10,
}


# 收集 Boss 专属材料（设计文档 4.4）：按名称计数，供后续局外图纸解锁读取
func collect_boss_relic(relic_name: String) -> void:
	if relic_name.is_empty():
		return
	boss_relics[relic_name] = int(boss_relics.get(relic_name, 0)) + 1


func add_loot(id: String, qty := 1) -> void:
	if not LOOT_ITEMS.has(id):
		return
	if LOOT_CAPS.has(id):
		var current := loot_count(id)
		var cap := int(LOOT_CAPS[id])
		if current >= cap:
			notify("%s 携带已达上限（%d）" % [loot_name(id), cap])
			return
		qty = mini(qty, cap - current)
	for entry in loot_items:
		if String(entry["id"]) == id:
			entry["qty"] = int(entry["qty"]) + qty
			if id == "hazmat":
				hazmat_durability = HAZMAT_MAX_DURABILITY
			notify("获得 %s ×%d" % [loot_name(id), int(entry["qty"])])
			resources_changed.emit()
			return
	loot_items.append({"id": id, "qty": qty})
	if id == "hazmat":
		hazmat_durability = HAZMAT_MAX_DURABILITY
	notify("获得 %s" % loot_name(id))
	resources_changed.emit()


func remove_loot(id: String, qty := 1) -> void:
	for i in loot_items.size():
		var entry: Dictionary = loot_items[i]
		if String(entry["id"]) != id:
			continue
		entry["qty"] = int(entry["qty"]) - qty
		if int(entry["qty"]) <= 0:
			loot_items.remove_at(i)
		resources_changed.emit()
		return


func use_loot(id: String) -> bool:
	var info := loot_info(id)
	if info.is_empty() or loot_count(id) <= 0:
		return false
	var cat := String(info.get("cat", ""))
	var consume := true
	match cat:
		"food", "drink":
			satiety = minf(MAX_SATIETY, satiety + float(info.get("satiety", 0.0)))
			satiety_changed.emit(satiety)
			if info.has("stamina"):
				regen_stamina(float(info["stamina"]))
			notify("食用 %s" % loot_name(id))
		"med":
			if info.has("hot_total"):
				start_hot_regen(int(info["hot_total"]), float(info.get("hot_duration", 10.0)))
			if float(info.get("heal_pct", 0.0)) > 0.0:
				heal_player(int(max_hp() * float(info["heal_pct"]) / 100.0))
			else:
				heal_player(int(info.get("heal", 0)))
			notify("使用 %s" % loot_name(id))
		"armor":
			if not armor_id.is_empty():
				add_loot(armor_id)
			armor_id = id
			armor_resist_value = float(info.get("resist", 0.0))
			notify("装备 %s（减伤 %d%%）" % [loot_name(id), int(armor_resist_value * 100.0)])
		"melee":
			if not melee_item.is_empty():
				add_loot(melee_item)
			melee_item = id
			melee_item_damage = int(info.get("damage", 35))
			notify("装备 %s（近战 %d 伤害）" % [loot_name(id), melee_item_damage])
		"attach":
			if current_weapon == "" or bool(WEAPONS.get(current_weapon, {}).get("melee", false)):
				notify("先拿一把枪再安装配件")
				return false
			if id == "suppressor":
				if has_suppressor(current_weapon):
					notify("这把枪已经装了消音器")
					return false
				install_suppressor(current_weapon)
				notify(
					"给 %s 安装了消音器（枪声大幅降低）" % WEAPONS[current_weapon]["name"]
				)
			else:
				if has_scope(current_weapon):
					notify("这把枪已经装了瞄准镜")
					return false
				if not install_scope(current_weapon, id):
					return false
				notify(
					"给 %s 安装了%s（开镜视距 %d 米）" % [
						WEAPONS[current_weapon]["name"],
						loot_name(id),
						int(weapon_view_range(current_weapon)),
					]
				)
		"ranged":
			add_weapon(String(info.get("weapon", "pistol")))
			notify("获得枪械：%s" % loot_name(id))
		"tool":
			match id:
				"clothes":
					use_clothes()
				"power_bank":
					notify("玩家不再需要电力，充电宝没用了（可以拿去出售）")
				"hazmat":
					consume = false
					notify("防化服已穿戴：可以安全收集/保存异能结晶")
				"anomaly_crystal":
					add_anomaly(5)
					notify("吸收异能结晶：异能量 +5（当前 %d/%d）" % [anomaly, ANOMALY_MAX])
				"flashlight":
					consume = false
					notify("手电筒：按 T 开关照明（夜晚实用）")
				_:
					notify("%s 只能拿去观测舱出售" % loot_name(id))
					return false
		_:
			notify("%s 只能拿去观测舱出售" % loot_name(id))
			return false
	if consume:
		remove_loot(id)
	return true


func loot_total_value() -> int:
	var total := 0
	for entry in loot_items:
		total += int(loot_info(String(entry["id"])).get("value", 0)) * int(entry["qty"])
	return total


func loot_sell_value() -> int:
	var total := 0
	for entry in loot_items:
		var info := loot_info(String(entry["id"]))
		var cat := String(info.get("cat", ""))
		if cat == "junk" or cat == "valuable":
			total += int(info.get("value", 0)) * int(entry["qty"])
	return total


func sell_junk() -> int:
	var gained := loot_sell_value() / 2
	for i in range(loot_items.size() - 1, -1, -1):
		var info := loot_info(String(loot_items[i]["id"]))
		var cat := String(info.get("cat", ""))
		if cat == "junk" or cat == "valuable":
			loot_items.remove_at(i)
	space_energy += gained
	resources_changed.emit()
	save_meta()
	if gained > 0:
		notify("出售杂物与贵重品，获得 %d SP" % gained)
	return gained


func melee_base_damage() -> int:
	if melee_item_damage > 0:
		return melee_item_damage
	if is_zombie():
		return ZOMBIE_CLAW_DAMAGE
	return int(WEAPONS["melee"]["damage"])


func toggle_skills() -> void:
	skills_open = not skills_open
	skills_toggled.emit(skills_open)


func skill_level(id: String) -> int:
	return int(skills.get(id, 0))


func skill_name(id: String) -> String:
	for skill in SKILLS:
		if String(skill["id"]) == id:
			return String(skill["name"])
	return id


func skill_max(id: String) -> int:
	for skill in SKILLS:
		if String(skill["id"]) == id:
			return int(skill["max"])
	return 0


func can_upgrade_skill(id: String) -> bool:
	return skill_points > 0 and skill_level(id) < skill_max(id)


func upgrade_skill(id: String) -> bool:
	if not can_upgrade_skill(id):
		return false
	skill_points -= 1
	skills[id] = skill_level(id) + 1
	skill_points_changed.emit(skill_points)
	skills_changed.emit()
	var level := skill_level(id)
	if level % 10 == 0:
		_check_mutation(id)
	save_meta()
	return true


func _check_mutation(attr: String) -> void:
	if not MUTATION_POOLS.has(attr):
		return
	mutation_queue.append(attr)
	_try_open_mutation()


func _try_open_mutation() -> void:
	if pending_mutation != "" or mutation_queue.is_empty():
		return
	var attr: String = mutation_queue.pop_front()
	var pool: Array = ZOMBIE_POOL if is_zombie() else MUTATION_POOLS.get(attr, [])
	var available: Array = []
	for ability_id in pool:
		if mutation_rank(String(ability_id)) < MUTATION_MAX_RANK:
			available.append(String(ability_id))
	if available.is_empty():
		_try_open_mutation()
		return
	available.shuffle()
	var count := mini(MUTATION_CHOICES, available.size())
	mutation_offer = []
	for i in count:
		mutation_offer.append({"id": available[i]})
	pending_mutation = attr
	mutation_offered.emit()


func choose_mutation(id: String) -> void:
	var found := false
	for entry in mutation_offer:
		if String(entry["id"]) == id:
			found = true
			break
	if not found:
		return
	mutation_levels[id] = mutation_rank(id) + 1
	mutations_taken += 1
	pending_mutation = ""
	mutation_offer = []
	mutations_changed.emit()
	notify(
		"变异能力 %s → %s 级" % [
			mut_info(id).get("name", id), _roman(mutation_rank(id))
		]
	)
	_notify_zombie_stage()
	save_meta()
	_try_open_mutation()


func mutation_rank(id: String) -> int:
	return int(mutation_levels.get(id, 0))


func has_mutation(id: String) -> bool:
	return mutation_rank(id) > 0


func mut_info(id: String) -> Dictionary:
	if MUTATIONS.has(id):
		return MUTATIONS[id]
	return ZOMBIE_MUTATIONS.get(id, {})


func mut_value_at(id: String, index: int, rank: int) -> float:
	if rank <= 0:
		return 0.0
	var info := mut_info(id)
	var from: Array = info.get("from", [])
	var to: Array = info.get("to", [])
	if index >= from.size() or index >= to.size():
		return 0.0
	var t := float(maxi(rank, 1) - 1) / float(MUTATION_MAX_RANK - 1)
	return lerpf(float(from[index]), float(to[index]), clampf(t, 0.0, 1.0))


func mut_value(id: String, index := 0) -> float:
	return mut_value_at(id, index, mutation_rank(id))


func mut_text(id: String, rank: int) -> String:
	var info := mut_info(id)
	var from: Array = info.get("from", [])
	var values: Array = []
	for i in from.size():
		values.append(_format_mut_value(mut_value_at(id, i, rank)))
	return String(info.get("desc", "")) % values


func mut_label(id: String) -> String:
	var rank := mutation_rank(id)
	var ability_name := String(mut_info(id).get("name", id))
	if rank <= 0:
		return "%s（获得）— %s" % [ability_name, mut_text(id, 1)]
	if rank >= MUTATION_MAX_RANK:
		return "%s 已满级" % ability_name
	return "%s %s→%s：%s" % [
		ability_name, _roman(rank), _roman(rank + 1), mut_text(id, rank + 1)
	]


func _format_mut_value(value: float) -> String:
	if absf(value - round(value)) < 0.05:
		return str(int(round(value)))
	return "%.1f" % value


func _roman(n: int) -> String:
	var table := ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ"]
	if n >= 1 and n <= table.size():
		return table[n - 1]
	return str(n)


func zombie_stage_index() -> int:
	var index := -1
	for i in ZOMBIE_STAGES.size():
		if mutations_taken >= int(ZOMBIE_STAGES[i]["at"]):
			index = i
	return index


func zombie_stats() -> Dictionary:
	var stats := {
		"hp": 1.0,
		"damage": 1.0,
		"speed": 1.0,
		"resist": 0.0,
		"attack_speed": 1.0,
		"scale": 1.0,
		"runner_chance": 0.0,
		"runner_speed": 1.0,
		"acid": false,
		"boss": false,
		"spawn_mult": 1.0,
		"cap_mult": 1.0,
	}
	for i in zombie_stage_index() + 1:
		var stage: Dictionary = ZOMBIE_STAGES[i]
		stats["hp"] *= float(stage.get("hp", 1.0))
		stats["damage"] *= float(stage.get("damage", 1.0))
		stats["speed"] *= float(stage.get("speed", 1.0))
		stats["resist"] = maxf(stats["resist"], float(stage.get("resist", 0.0)))
		stats["attack_speed"] *= float(stage.get("attack_speed", 1.0))
		stats["scale"] = maxf(stats["scale"], float(stage.get("scale", 1.0)))
		stats["runner_chance"] = maxf(
			stats["runner_chance"], float(stage.get("runner_chance", 0.0))
		)
		stats["runner_speed"] = maxf(
			stats["runner_speed"], float(stage.get("runner_speed", 1.0))
		)
		if bool(stage.get("acid", false)):
			stats["acid"] = true
		if bool(stage.get("boss", false)):
			stats["boss"] = true
		stats["spawn_mult"] = maxf(
			stats["spawn_mult"], float(stage.get("spawn_mult", 1.0))
		)
		stats["cap_mult"] = maxf(
			stats["cap_mult"], float(stage.get("cap_mult", 1.0))
		)
	return stats


# 世界疫情阶段：按爆发时间查 WORLD_STAGES 表（未爆发时为 0）
func world_stage_index() -> int:
	var index := 0
	for i in WORLD_STAGES.size():
		if outbreak_elapsed >= float(WORLD_STAGES[i]["at"]):
			index = i
	return index


func world_stage_info() -> Dictionary:
	return WORLD_STAGES[world_stage_index()]


# 当前世界阶段的刷怪参数：键位风格与 zombie_stats() 一致，另含 tier 范围与 boss 信息
func world_zombie_stats() -> Dictionary:
	var stage := world_stage_info()
	var boss_tier := int(stage.get("boss_tier", 0))
	return {
		"stage": world_stage_index(),
		"name": String(stage.get("name", "")),
		"tier_min": int(stage.get("tier_min", 1)),
		"tier_max": int(stage.get("tier_max", 1)),
		"hp": float(stage.get("hp", 1.0)),
		"damage": float(stage.get("damage", 1.0)),
		"speed": float(stage.get("speed", 1.0)),
		"resist": float(stage.get("resist", 0.0)),
		"attack_speed": float(stage.get("attack_speed", 1.0)),
		"scale": float(stage.get("scale", 1.0)),
		"runner_chance": float(stage.get("runner_chance", 0.0)),
		"runner_speed": float(stage.get("runner_speed", 1.4)),
		"acid": bool(stage.get("acid", false)),
		"boss": boss_tier > 0,
		"boss_tier": boss_tier,
		"god": bool(stage.get("god", false)),
		"spawn_mult": float(stage.get("spawn_mult", 1.0)),
		"cap_mult": float(stage.get("cap_mult", 1.0)),
	}


# 阶段升级检测：广播疫情升级，并按阶段表追加新爆发点（阶段 5 起只要点位有剩余就继续加）
func _update_world_stage() -> void:
	var stage := world_stage_index()
	if stage <= _last_world_stage:
		return
	_last_world_stage = stage
	if stage <= 0:
		return
	var stage_name := String(WORLD_STAGES[stage]["name"])
	post_message("疫情升级：%s" % stage_name, Vector2.ZERO, "outbreak", true)
	notify("疫情升级：%s" % stage_name)
	if bool(WORLD_STAGES[stage].get("new_site", false)) or stage >= 5:
		if custom_outbreak:
			custom_outbreak_site_needed.emit(stage)
		else:
			add_random_outbreak_site()


func _notify_zombie_stage() -> void:
	var stage := zombie_stage_index()
	if stage < 0 or stage <= _announced_stage:
		return
	_announced_stage = stage
	var stage_name := String(ZOMBIE_STAGES[stage]["name"])
	post_message("尸潮进化：%s 出现！" % stage_name, Vector2.ZERO, "zombie", true)
	notify("尸潮进化：%s" % stage_name)


func heal_player(amount: int) -> void:
	if amount <= 0:
		return
	hp = mini(hp + amount, max_hp())
	hp_changed.emit(hp)


func award_skill_point(amount := 1) -> void:
	skill_points += amount
	skill_points_changed.emit(skill_points)
	notify("获得 SP +%d（按 C 打开能力面板）" % amount)


func max_hp() -> int:
	var base := 0.0
	if is_zombie():
		base = ZOMBIE_BASE_HP + skill_level("vitality") * 2.0
	else:
		base = (
			MAX_HP + skill_level("vitality") * 2.0 + mut_value("energizer")
			+ rogue_rank("vital") * 20.0 + 25.0 * anomaly_gem_count()
		)
	return int(base * attr_mult("vitality") * echo_hp_mult())


func max_stamina() -> float:
	return (
		(MAX_STAMINA + skill_level("endurance") * 2.0 + mut_value("robust"))
		* echo_stamina_mult()
	)


func stamina_regen(standing := false) -> float:
	var base := 16.0 + skill_level("recovery") * 0.5
	if standing:
		base *= 1.0 + mut_value("rest") / 100.0
	return base


func walk_speed_mult() -> float:
	return (
		(1.0 + skill_level("agility") * 0.01 + mut_value("cheetah") / 100.0)
		* attr_mult("agility")
		* echo_move_mult()
		* (1.0 + rogue_rank("speed") * 0.08)
		* (1.0 - POISON_SLOW if poison_timer > 0.0 else 1.0)
	)


func gun_damage_mult() -> float:
	return (1.0 + skill_level("gunnery") * 0.015) * echo_gun_mult() * (1.0 + rogue_rank("damage") * 0.15)


func melee_damage_mult() -> float:
	return 1.0 + skill_level("melee") * 0.02 + mut_value("claws") / 100.0 + 0.1 * anomaly_gem_count()


func melee_cooldown_mult() -> float:
	return 1.0 / (1.0 + mut_value("swift", 0) / 100.0)


func melee_reach_bonus() -> float:
	return mut_value("swift", 1)


func medkit_heal() -> int:
	return MEDKIT_HEAL + skill_level("medic") + int(mut_value("elixir"))


func gun_spread_mult() -> float:
	return 1.0 - mut_value("accuracy") / 100.0


func gun_cooldown_mult() -> float:
	return (1.0 - mut_value("quickdraw") / 100.0) * (1.0 - rogue_rank("rapid") * 0.07)


func recoil_mult() -> float:
	return 1.0 - mut_value("grip") / 100.0


func roll_crit() -> bool:
	var chance := mut_value("crit", 0) / 100.0 + echo_crit_chance() + rogue_rank("crit") * 0.06
	return chance > 0.0 and randf() < chance


func crit_mult() -> float:
	return maxf(1.0, mut_value("crit", 1))


func stamina_drain_mult() -> float:
	return 1.0 - mut_value("iron_lungs") / 100.0


func satiety_drain_mult() -> float:
	return (1.0 - mut_value("metabolism") / 100.0) * echo_hunger_mult()


func sprint_satiety_mult() -> float:
	return 1.0 - mut_value("light_legs") / 100.0


func noise_mult() -> float:
	return (1.0 - mut_value("silent_step") / 100.0) * echo_noise_mult()


func jump_mult() -> float:
	return 1.0 + mut_value("cat_step") / 100.0


func dodge_chance() -> float:
	return mut_value("dodge") / 100.0


func take_second_wind() -> float:
	var amount := mut_value("second_wind")
	if amount <= 0.0 or Time.get_ticks_msec() < _second_wind_msec:
		return 0.0
	_second_wind_msec = Time.get_ticks_msec() + 30000
	return amount


func on_player_kill() -> void:
	if has_mutation("lifesteal"):
		heal_player(int(mut_value("lifesteal")))
	if has_mutation("combat_regen"):
		_combat_regen_until = (
			Time.get_ticks_msec() + int(mut_value("combat_regen", 0) * 1000.0)
		)
		_combat_regen_rate = mut_value("combat_regen", 1)


func on_melee_kill() -> void:
	if has_mutation("bloodthirst"):
		heal_player(int(mut_value("bloodthirst")))
	if echo_melee_lifesteal() > 0.0:
		heal_player(int(max_hp() * echo_melee_lifesteal()))
	on_player_kill()


func backpack_items() -> Array:
	var items: Array = []
	if money > 0:
		items.append({
			"id": "cash",
			"label": "现金 ¥%d" % money,
			"color": Color(0.86, 0.72, 0.3),
			"group": "special",
		})
	var food := int(resources.get("food", 0))
	if food > 0:
		items.append({
			"id": "food",
			"label": "食物 ×%d" % food,
			"color": Color(0.45, 0.78, 0.5),
			"group": "food",
		})
	var meds := int(resources.get("meds", 0))
	if meds > 0:
		items.append({
			"id": "meds",
			"label": "医疗包 ×%d" % meds,
			"color": Color(0.82, 0.45, 0.45),
			"group": "med",
		})
	for _cal in CALIBERS:
		var _n := ammo_count(_cal)
		if _n > 0:
			items.append({
				"id": "ammo_" + _cal,
				"label": "%s ×%d" % [caliber_name(_cal), _n],
				"color": Color(0.82, 0.78, 0.4),
				"group": "ammo",
			})
	# 列出全部持有的枪械（不再写死 pistol/shotgun/rifle 三把）
	for weapon_id in WEAPONS:
		var wid := String(weapon_id)
		# 手雷不占武器栏（G 直接投掷），近战不显示
		if wid == "melee" or wid == "grenade":
			continue
		if int(weapons.get(wid, 0)) > 0:
			var equipped: bool = current_weapon == wid
			items.append({
				"id": wid,
				"label": ("▶ " if equipped else "") + String(WEAPONS[wid]["name"]),
				"color": Color(0.95, 0.85, 0.45) if equipped else Color(0.72, 0.76, 0.82),
				"weapon": true,
				"group": "weapon",
			})
	for entry in loot_items:
		var loot_id := String(entry["id"])
		var info := loot_info(loot_id)
		if info.is_empty():
			continue
		var cat := String(info.get("cat", ""))
		items.append({
			"id": "loot_" + loot_id,
			"label": "%s%s ×%d" % [loot_name(loot_id), energy_tag_text(loot_id), int(entry["qty"])],
			"color": _loot_color(cat),
			"loot_id": loot_id,
			"group": String(LOOT_CAT_GROUP.get(cat, "special")),
		})
	return items


# 按分区取背包条目（分区顺序见 BACKPACK_GROUPS）
func backpack_group_items(group_id: String) -> Array:
	var out: Array = []
	for item in backpack_items():
		if String(item.get("group", "special")) == group_id:
			out.append(item)
	return out


func _loot_color(cat: String) -> Color:
	match cat:
		"food":
			return Color(0.55, 0.8, 0.45)
		"drink":
			return Color(0.45, 0.75, 0.9)
		"med":
			return Color(0.85, 0.5, 0.55)
		"melee":
			return Color(0.75, 0.7, 0.55)
		"ranged":
			return Color(0.7, 0.72, 0.8)
		"armor":
			return Color(0.6, 0.65, 0.72)
		"valuable":
			return Color(0.95, 0.8, 0.3)
		_:
			return Color(0.62, 0.58, 0.5)


func report_signal(source_id: int, strength: float) -> void:
	if strength <= 0.01:
		_signal_sources.erase(source_id)
	else:
		_signal_sources[source_id] = strength
	_recompute_signal()


func clear_signal(source_id: int) -> void:
	_signal_sources.erase(source_id)
	_recompute_signal()


# 信号干扰源（能量场）：进入干扰区后信号强度被压制到 10% 以下（设计文档 5.5）
func report_interference(source_id: int, pos: Vector3, radius: float) -> void:
	_signal_interference[source_id] = {"pos": pos, "radius": radius}
	_recompute_signal()


func clear_interference(source_id: int) -> void:
	_signal_interference.erase(source_id)
	_recompute_signal()


func add_coverage() -> void:
	report_signal(-1, 1.0)


func remove_coverage() -> void:
	clear_signal(-1)


func _recompute_signal() -> void:
	var best := 0.0
	for value in _signal_sources.values():
		best = maxf(best, value)
	# 能量场干扰区：玩家在任一干扰源半径内时，信号强制压到 10% 以下（设计文档 5.5）
	if not _signal_interference.is_empty():
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			for zone in _signal_interference.values():
				var zp: Vector3 = zone["pos"]
				if Vector2(player.global_position.x - zp.x, player.global_position.z - zp.z).length() <= float(zone["radius"]):
					best = minf(best, 0.1)
					break
	var was_covered := in_coverage
	signal_strength = best
	in_coverage = best > 0.2
	if in_coverage != was_covered:
		coverage_changed.emit(in_coverage)


func reset_coverage() -> void:
	_signal_sources.clear()
	_signal_interference.clear()
	signal_strength = 0.0
	if in_coverage:
		in_coverage = false
		coverage_changed.emit(false)


# 场景全部迫击炮/火炮缓存：整树递归收集（0.5s 节流；force 立即重建）
func refresh_artillery_cache(force := false) -> void:
	var now := Time.get_ticks_msec()
	if not force and now - _artillery_cache_stamp < 500:
		return
	_artillery_cache_stamp = now
	var out: Array = []
	_collect_artillery_nodes(get_tree().root, out)
	artillery_cache = out


func _collect_artillery_nodes(node: Node, out: Array) -> void:
	var t := str(node.get("defense_type"))
	if t == "mortar" or t == "cannon":
		out.append(node)
	for child in node.get_children():
		_collect_artillery_nodes(child, out)


# 远程打击可用性：任意世界点是否处于信号覆盖内
# （据点信号圈 15+10×等级 米，或任一信号塔 400m 圈——与 HUD 信号强度显示同一套判定）
# 远程打击可用性：点是否处于「据点连通信号网络」的覆盖内（批次 142 信号塔接力）：
# - 据点信号圈（15+10×等级 m）直接覆盖；
# - 信号塔位于任一已连通信号源范围内（据点圈内、或另一已连通塔的覆盖圈内）即接入网络，
#   其覆盖圈并入网络（接力扩展）；
# - 位于网络之外的信号塔是独立信号区（HUD 有信号），但不与据点互通，不能呼叫远程打击。
func point_in_signal_coverage(point: Vector3) -> bool:
	if not has_home_base():
		return false
	var home_pos: Vector3 = home_base.get("position", Vector3.ZERO)
	var base_r := base_signal_radius()
	var p := Vector2(point.x, point.z)
	var home2 := Vector2(home_pos.x, home_pos.z)
	if p.distance_to(home2) <= base_r:
		return true
	# BFS：从据点出发，把「塔身位于已连通信号范围内」的塔逐级接入网络
	var remaining: Array = []
	for entry in home_base.get("defenses", []):
		if String(entry.get("type", "")) == "signal_tower":
			remaining.append(Vector2(entry["pos"].x, entry["pos"].z))
	var pending: Array = [home2]
	var pending_r: Array = [base_r]
	var connected: Array = []
	while not pending.is_empty():
		var f: Vector2 = pending.pop_back()
		var fr: float = pending_r.pop_back()
		for i in range(remaining.size() - 1, -1, -1):
			var t: Vector2 = remaining[i]
			if t.distance_to(f) <= fr:
				connected.append(t)
				pending.append(t)
				pending_r.append(SIGNAL_TOWER_RANGE)
				remaining.remove_at(i)
	for t in connected:
		if p.distance_to(t) <= SIGNAL_TOWER_RANGE:
			return true
	return false


func announce_intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	post_message("观测简报：异变雨预计于 %d 分钟后降临，请做好准备" % int(round(time_left / 60.0)), Vector2.ZERO, "", true)
	notify("情报：灾变将至。找好据点，囤好物资，准备迎接异变雨")


func start_outbreak() -> void:
	if phase != "prepare":
		return
	phase = "outbreak"
	outbreak_elapsed = 0.0
	outbreak_site = {}
	outbreak_sites.clear()
	day_number = 1
	day_elapsed = 0.0
	_last_world_stage = 0
	if not custom_outbreak:
		add_outbreak_site(OUTBREAK_SITES[randi() % OUTBREAK_SITES.size()], 0.0)
	phase_changed.emit(phase)
	post_message("灾变降临：异变雨开始了，空气中弥漫着孢子雨前的腥味", Vector2.ZERO, "outbreak", true)
	offer_echoes()


func apply_arrest() -> void:
	if test_mode:
		return
	money = 0
	resources["food"] = int(resources["food"] * 0.2)
	resources["meds"] = int(resources["meds"] * 0.2)
	resources["ammo"] = 0
	for _cal in ammo_stock:
		for _t in ammo_stock[_cal]:
			ammo_stock[_cal][_t] = int(ammo_stock[_cal][_t] * 0.2)
	weapons = {"pistol": 0, "shotgun": 0, "rifle": 0}
	current_weapon = ""
	money_changed.emit(money)
	resources_changed.emit()
	weapons_changed.emit()


func outbreak_radius() -> float:
	if outbreak_sites.is_empty():
		# 兼容旧调用：只有单点 outbreak_site 时按它计算
		if outbreak_site.is_empty():
			return 0.0
		return site_radius(outbreak_site)
	var best := 0.0
	for site in outbreak_sites:
		best = maxf(best, site_radius(site))
	return best


# 单个爆发点的扩散半径：普通点位返回 2D 像素单位（同旧 outbreak_radius 语义），
# 米制点位（"metric": true，自定义图用）返回 3D 米
func site_radius(site: Dictionary) -> float:
	var speed := SPREAD_BASE_SPEED * float(site.get("spread", 1.0))
	var active_time := maxf(0.0, outbreak_elapsed - float(site.get("activated_at", 0.0)))
	var radius := minf(60.0 + active_time * speed, 2400.0)
	if bool(site.get("metric", false)):
		return radius * WORLD_SCALE_3D
	return radius


# 单点扩散半径统一换算成 3D 米
func site_radius_m(site: Dictionary) -> float:
	var radius := site_radius(site)
	if bool(site.get("metric", false)):
		return radius
	return radius * WORLD_SCALE_3D


# 爆发点的 3D 世界坐标（米）：像素点位自动按 WORLD_SCALE_3D 换算
func site_pos3(site: Dictionary) -> Vector3:
	var pos = site.get("position", Vector2.ZERO)
	if pos is Vector3:
		return pos
	if bool(site.get("metric", false)):
		return Vector3(pos.x, 0.0, pos.y)
	return Vector3(pos.x * WORLD_SCALE_3D, 0.0, pos.y * WORLD_SCALE_3D)


# 追加一个爆发点；activated_at < 0 表示以当前爆发时刻激活；
# infect 为 true 时立刻首批转化范围内市民（40% 概率，至少 3 个）
func add_outbreak_site(site: Dictionary, activated_at := -1.0, infect := true) -> Dictionary:
	if not site.has("position"):
		return {}
	var entry := site.duplicate()
	entry["spread"] = float(entry.get("spread", 1.0))
	entry["metric"] = bool(entry.get("metric", false))
	entry["activated_at"] = outbreak_elapsed if activated_at < 0.0 else activated_at
	outbreak_sites.append(entry)
	if outbreak_site.is_empty():
		outbreak_site = entry
	if infect:
		var radius := maxf(site_radius_m(entry), OUTBREAK_CONVERT_RADIUS)
		infect_civilians_near(site_pos3(entry), radius, 0.4)
	return entry


# 从 OUTBREAK_SITES 剩余点位中随机追加一个爆发点（城市图用）
func add_random_outbreak_site() -> Dictionary:
	var used := {}
	for site in outbreak_sites:
		used[String(site.get("name", ""))] = true
	var options: Array = []
	for site in OUTBREAK_SITES:
		if not used.has(String(site["name"])):
			options.append(site)
	if options.is_empty():
		return {}
	var entry := add_outbreak_site(options[randi() % options.size()])
	if entry.is_empty():
		return {}
	post_message(
		"疫情扩散：%s 出现新的爆发点！" % String(entry.get("name", "未知区域")),
		entry["position"],
		"outbreak"
	)
	return entry


# 让 radius（米）范围内的市民批量感染：按 chance 概率转化，并保证至少 3 个
func infect_civilians_near(pos3: Vector3, radius: float, chance: float) -> int:
	if not is_inside_tree():
		return 0
	var candidates: Array = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_queued_for_deletion():
			continue
		if _node_pos3(npc).distance_to(pos3) <= radius:
			candidates.append(npc)
	candidates.shuffle()
	var infected := 0
	for npc in candidates:
		if bool(npc.get("_infected")):
			infected += 1
			continue
		npc._infect(chance)
		if bool(npc.get("_infected")):
			infected += 1
	for npc in candidates:
		if infected >= 3:
			break
		if bool(npc.get("_infected")):
			continue
		npc._infect(1.0)
		infected += 1
	return infected


func expected_zombie_count() -> int:
	return mini(ZOMBIE_MAX, int(outbreak_elapsed / ZOMBIE_SPAWN_INTERVAL))


# 丧尸击杀钩子：tier >= 10（尸神·天灾）死亡时记录结算加成并广播
func boss_killed(tier: int) -> void:
	if tier < 10:
		return
	boss_sp_bonus += BOSS_SP_BONUS
	anomaly = mini(ANOMALY_MAX, anomaly + 20)
	post_message("尸神已灭！观测站记录到巨大的回响波动", Vector2.ZERO, "outbreak", true)
	notify("尸神已灭！结算加成 +%d SP · 异能量 +20" % BOSS_SP_BONUS)


func has_home_base() -> bool:
	return not home_base.is_empty()


# 建筑门口位置反查 BUILDING_LAYOUT 的 footprint（3D 米矩形，含室内）；查不到返回空矩形
func building_footprint_at(door_pos: Vector3) -> Rect2:
	for entry in BUILDING_LAYOUT:
		var pos: Vector2 = entry["position"]
		var size2d: Vector2 = entry["size"]
		var half := size2d * WORLD_SCALE_3D / 2.0
		var center := Vector2(pos.x, pos.y) * WORLD_SCALE_3D
		var door := Vector3(center.x, 0.05, center.y + half.y + 1.2)
		if door.distance_to(door_pos) < 2.5:
			return Rect2(center - half, half * 2.0)
	return Rect2()


# 矩形范围（3D 米，xz 平面）内存活的 NPC 数量；死亡未清除的尸体不算
func npcs_in_rect(rect: Rect2) -> int:
	if not is_inside_tree():
		return 0
	var count := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_queued_for_deletion() or bool(npc.get("_dying")):
			continue
		var hp_value = npc.get("hp")
		if hp_value != null and int(hp_value) <= 0:
			continue
		var p: Vector3 = npc.global_position
		if rect.has_point(Vector2(p.x, p.z)):
			count += 1
	return count


# 脚边 3m 内地面建材堆的合计数量（空地建据点用）
# 节点位置统一为 3D 米：Node3D 直接用，Node2D（2D 版实体，像素坐标）按 WORLD_SCALE_3D 换算
func _node_pos3(node: Node) -> Vector3:
	var p = node.get("global_position")
	if p is Vector2:
		return Vector3(p.x * WORLD_SCALE_3D, 0.0, p.y * WORLD_SCALE_3D)
	return p


# 新实体入组后请求下一帧重建网格，避免新刷实体最长 0.25s 对索敌不可见
func request_spatial_rebuild() -> void:
	_spatial_timer = 0.0


# 每 0.25s 重建一次空间网格：一次遍历全部登记实体，按 xz 平面 cell 分桶
func _rebuild_spatial_grid() -> void:
	if not is_inside_tree() or _spatial_worker_busy:
		return
	# 快照：节点引用 + 位置（场景树访问只能在主线程做）
	var snapshot: Array = []
	for group in SPATIAL_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node.is_queued_for_deletion():
				continue
			var p = node.get("global_position")
			if not p is Vector3:
				continue
			snapshot.append([node, p])
	_spatial_worker_busy = true
	if OS.has_feature("threads"):
		WorkerThreadPool.add_task(_build_spatial_cells.bind(snapshot))
	else:
		# Web 无线程环境：主线程内联执行同一计算
		_build_spatial_cells(snapshot)


# worker 线程：纯数据分格——只存放节点引用，不调用任何节点方法
func _build_spatial_cells(snapshot: Array) -> void:
	var cells := {}
	for entry in snapshot:
		var p: Vector3 = entry[1]
		var cell := Vector2i(floori(p.x / SPATIAL_CELL), floori(p.z / SPATIAL_CELL))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(entry[0])
	call_deferred("_apply_spatial_cells", cells)


# 主线程：原子换表（查询方无感知）
func _apply_spatial_cells(cells: Dictionary) -> void:
	_spatial_worker_busy = false
	_spatial_cells = cells


# 半径 radius（米）内属于 group 的实体列表；只查半径覆盖的格子
func entities_in_group_in_radius(pos3: Vector3, group: String, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	var min_cell := Vector2i(
		floori((pos3.x - radius) / SPATIAL_CELL),
		floori((pos3.z - radius) / SPATIAL_CELL)
	)
	var max_cell := Vector2i(
		floori((pos3.x + radius) / SPATIAL_CELL),
		floori((pos3.z + radius) / SPATIAL_CELL)
	)
	for cx in range(min_cell.x, max_cell.x + 1):
		for cz in range(min_cell.y, max_cell.y + 1):
			for node in _spatial_cells.get(Vector2i(cx, cz), []):
				if not is_instance_valid(node) or node.is_queued_for_deletion():
					continue
				if not node.is_in_group(group):
					continue
				var p: Vector3 = node.global_position
				if p.distance_squared_to(pos3) <= r2:
					out.append(node)
	return out


# 半径 radius（米）内属于 group 的最近实体；没有则返回 null
func nearest_entity_in_group(pos3: Vector3, group: String, radius: float) -> Node:
	var best: Node = null
	var best_d2 := radius * radius
	var min_cell := Vector2i(
		floori((pos3.x - radius) / SPATIAL_CELL),
		floori((pos3.z - radius) / SPATIAL_CELL)
	)
	var max_cell := Vector2i(
		floori((pos3.x + radius) / SPATIAL_CELL),
		floori((pos3.z + radius) / SPATIAL_CELL)
	)
	for cx in range(min_cell.x, max_cell.x + 1):
		for cz in range(min_cell.y, max_cell.y + 1):
			for node in _spatial_cells.get(Vector2i(cx, cz), []):
				if not is_instance_valid(node) or node.is_queued_for_deletion():
					continue
				if not node.is_in_group(group):
					continue
				var d2: float = (node.global_position as Vector3).distance_squared_to(pos3)
				if d2 < best_d2:
					best_d2 = d2
					best = node
	return best


# 建材堆位置统一为 3D 米：3D 堆直接用 Vector3，2D 堆（Node2D 像素坐标）按 WORLD_SCALE_3D 换算
func _pile_pos3(pile: Node) -> Vector3:
	var p = pile.get("global_position")
	if p is Vector2:
		return Vector3(p.x * WORLD_SCALE_3D, 0.0, p.y * WORLD_SCALE_3D)
	return p


func nearby_pile_materials(pos: Vector3) -> int:
	if not is_inside_tree():
		return 0
	var total := 0
	for pile in get_tree().get_nodes_in_group("material_piles"):
		if pile.is_queued_for_deletion():
			continue
		if _pile_pos3(pile).distance_to(pos) <= OPEN_GROUND_PILE_REACH:
			total += int(pile.get("amount"))
	return total


# 空地建据点：消耗脚边 3m 内建材堆合计 150 建材，不够时提示还差多少
func claim_open_ground_base(pos: Vector3) -> bool:
	if has_home_base():
		return false
	var available := nearby_pile_materials(pos)
	if available < OPEN_GROUND_BASE_COST:
		notify(
			"空地建据点需要建材 ×%d，还差 %d（拆除建筑掉堆，车运到脚边再按 X）"
			% [OPEN_GROUND_BASE_COST, OPEN_GROUND_BASE_COST - available]
		)
		return false
	var remain := OPEN_GROUND_BASE_COST
	for pile in get_tree().get_nodes_in_group("material_piles"):
		if pile.is_queued_for_deletion():
			continue
		if _pile_pos3(pile).distance_to(pos) > OPEN_GROUND_PILE_REACH:
			continue
		var take := mini(remain, int(pile.get("amount")))
		var left := int(pile.get("amount")) - take
		if left <= 0:
			pile.queue_free()
		elif pile.has_method("setup"):
			pile.setup(left)
		else:
			pile.set("amount", left)
		remain -= take
		if remain <= 0:
			break
	return claim_home_base(OPEN_GROUND_BASE_ID, pos)


# 占领据点：需要复活石（观测舱购买）；建筑内还有存活 NPC 时拒绝；换据点时旧储物自动并入新点
func claim_home_base(building_id: String, pos: Vector3) -> bool:
	if not revival_stone and not rogue_mode:
		notify("需要复活石（观测舱购买）才能设定据点")
		return false
	if building_id != OPEN_GROUND_BASE_ID:
		var footprint := building_footprint_at(pos)
		if footprint.has_area() and npcs_in_rect(footprint) > 0:
			notify("建筑里还有人，先清空再占领")
			return false
	var storage := {"food": 0, "meds": 0, "ammo": 0, "money": 0, "materials": 0, "fuel": 0, "crystals": 0}
	var kept_defenses: Array = []
	var kept_levels: Dictionary = {}
	if has_home_base():
		var old: Dictionary = home_base.get("storage", {})
		for kind in storage.keys():
			storage[kind] = int(storage[kind]) + int(old.get(kind, 0))
		# 同一位置重复占领：保留防御设施登记与升级等级（换位置才清空）
		var old_pos: Vector3 = home_base.get("position", Vector3.ZERO)
		if old_pos.distance_to(pos) < 2.0:
			kept_defenses = home_base.get("defenses", [])
			kept_levels = home_base.get("defense_levels", {})
	home_base = {
		"building_id": building_id,
		"position": pos,
		"storage": storage,
		"level": 1,
		"radius": BASE_BASE_RADIUS,
		"power": 0.0,
		"defenses": kept_defenses,
		"storage_upgrade": 0,
		"defense_levels": kept_levels,
		"workers": [],
		"hp": 400 + 200 * 1,
	}
	home_base_changed.emit()
	notify("已将此处设为据点，原有储物已并入（按 X 进入建造模式）")
	return true


# 死亡后能否在据点复活：需要据点与复活石
func can_respawn_at_base() -> bool:
	return has_home_base() and revival_stone


# 营地本体血量上限：400 + 200×等级（肉鸽守营玩法：丧尸会优先挠营地）
func home_base_hp_max() -> int:
	return 400 + 200 * home_base_level()


func home_base_hp() -> int:
	if not has_home_base():
		return 0
	return int(home_base.get("hp", home_base_hp_max()))


# 营地被打：血量归零则据点摧毁（设施全灭，可重新占领；不算失败）
func damage_home_base(amount: int) -> void:
	if not has_home_base() or amount <= 0:
		return
	var hp := home_base_hp() - amount
	if hp > 0:
		home_base["hp"] = hp
		home_base_changed.emit()
		return
	var pos: Vector3 = home_base.get("position", Vector3.ZERO)
	home_base = {}
	home_base_changed.emit()
	notify("据点被摧毁了！可以重新占领")
	for defense in get_tree().get_nodes_in_group("base_defense"):
		if not defense.is_queued_for_deletion():
			defense.queue_free()
	noise_at(pos, 30.0)


# 肉鸽模式物资数量倍率（可搜刮物品增多）
func loot_amount_mult() -> float:
	return 2.0 if rogue_mode else 1.0


# 复活石生效：传送回据点，生命恢复 50%，携带现金按复活次数递增惩罚
func respawn_at_base(player: Node3D) -> void:
	if not can_respawn_at_base():
		return
	var base_pos: Vector3 = home_base.get("position", Vector3.ZERO)
	var penalty_pct := 10 * (revive_count + 1)
	var loss := int(money * penalty_pct / 100.0)
	if loss > 0:
		money -= loss
		money_changed.emit(money)
	revive_count += 1
	player.global_position = base_pos + Vector3(2.0, 0.3, 2.0)
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	hp = maxi(1, int(max_hp() * 0.5))
	hp_changed.emit(hp)
	notify("复活石生效：你在据点醒来（现金 -%d%%）" % penalty_pct)


func home_base_level() -> int:
	return int(home_base.get("level", 1)) if has_home_base() else 0


func home_base_radius() -> float:
	return float(home_base.get("radius", BASE_BASE_RADIUS)) if has_home_base() else 0.0


# 据点储物折现率：基础 40%，每级 +5%，上限 60%
func home_storage_rate() -> float:
	return minf(0.4 + float(maxi(home_base_level(), 1) - 1) * 0.05, 0.6)


func upgrade_base_cost() -> int:
	return 20 * maxi(home_base_level(), 1)


func upgrade_home_base() -> bool:
	if not has_home_base():
		return false
	var level := home_base_level()
	if level >= BASE_MAX_LEVEL:
		notify("据点已达最高等级（%d 级）" % BASE_MAX_LEVEL)
		return false
	if not spend_materials(upgrade_base_cost()):
		return false
	home_base["level"] = level + 1
	home_base["radius"] = minf(home_base_radius() + 2.0, BASE_MAX_RADIUS)
	home_base_changed.emit()
	notify(
		"据点升级至 %d 级：半径 %.0f 米，储物折现率 %d%%"
		% [level + 1, home_base_radius(), int(home_storage_rate() * 100.0)]
	)
	return true


func expand_base_cost() -> int:
	return BASE_EXPAND_COST


func expand_home_base() -> bool:
	if not has_home_base():
		return false
	if home_base_radius() >= BASE_MAX_RADIUS:
		notify("据点半径已达上限（%.0f 米）" % BASE_MAX_RADIUS)
		return false
	if not spend_materials(expand_base_cost()):
		return false
	home_base["radius"] = minf(home_base_radius() + 2.0, BASE_MAX_RADIUS)
	home_base_changed.emit()
	notify("据点半径扩大至 %.0f 米" % home_base_radius())
	return true


func base_defense_slots() -> int:
	return 2 + maxi(home_base_level(), 1)


func base_defense_cost(type: String) -> int:
	return int(BASE_DEFENSES.get(type, {}).get("cost", 0))


func base_defense_hp(type: String) -> int:
	return int(BASE_DEFENSES.get(type, {}).get("hp", 100))


func base_defense_count() -> int:
	if not has_home_base():
		return 0
	return (home_base.get("defenses", []) as Array).size()


# 放置防御设施：超出据点半径或材料不够时拒绝；设施数量不设上限
func add_base_defense(type: String, pos: Vector3) -> bool:
	if not has_home_base() or not BASE_DEFENSES.has(type):
		return false
	if bool(BASE_DEFENSES[type].get("unique", false)):
		for entry in home_base["defenses"]:
			if String(entry["type"]) == type:
				notify("%s 每据点限建 1 个" % String(BASE_DEFENSES[type]["name"]))
				return false
	# 数量上限（防无脑堆叠塔阵，设计文档 5.2）：cap 字段 > 0 时生效
	var cap := int(BASE_DEFENSES[type].get("cap", 0))
	if cap > 0:
		var count := 0
		for entry in home_base["defenses"]:
			if String(entry["type"]) == type:
				count += 1
		if count >= cap:
			notify("%s 数量已达上限（%d 座）" % [String(BASE_DEFENSES[type]["name"]), cap])
			return false
	var base_pos: Vector3 = home_base["position"]
	var flat := Vector2(pos.x - base_pos.x, pos.z - base_pos.z)
	# 信号塔任意位置可建（自成信号区/接力用），其余设施须在据点半径内
	if type != "signal_tower" and flat.length() > home_base_radius():
		notify("超出据点半径，无法放置")
		return false
	if not defense_affordable(type):
		notify("材料不足（%s）" % defense_cost_text(type))
		return false
	if not spend_materials(base_defense_cost(type)):
		return false
	# 设施附加资源消耗（制造材料，从背包 loot 扣）
	if not test_mode:
		var craft := int(BASE_DEFENSES[type].get("craft", 0))
		if craft > 0:
			remove_loot("craft_mat", craft)
	var defenses: Array = home_base["defenses"]
	defenses.append({"type": type, "pos": pos})
	home_base_changed.emit()
	notify("建造完成：%s（共 %d 座）" % [
		String(BASE_DEFENSES[type]["name"]), defenses.size()
	])
	return true


# 防御设施被摧毁：按位置从据点防御列表移除（节点由设施自身 queue_free），同时清掉升级记录
func remove_base_defense(pos: Vector3) -> void:
	if not has_home_base():
		return
	var defenses: Array = home_base["defenses"]
	for i in range(defenses.size() - 1, -1, -1):
		var entry: Dictionary = defenses[i]
		var p: Vector3 = entry["pos"]
		if Vector2(p.x - pos.x, p.z - pos.z).length() < 0.8:
			defenses.remove_at(i)
			var levels: Dictionary = home_base.get("defense_levels", {})
			levels.erase(defense_key(p))
	home_base_changed.emit()


# 设施位置键：defense_levels 以位置字符串记升级等级（0.1 米精度，避免浮点抖动）
func defense_key(pos: Vector3) -> String:
	return "%d|%d" % [roundi(pos.x * 10.0), roundi(pos.z * 10.0)]


# 某位置设施的当前升级等级（未升级 0）
func defense_upgrade_level(pos: Vector3) -> int:
	if not has_home_base():
		return 0
	var levels: Dictionary = home_base.get("defense_levels", {})
	return int(levels.get(defense_key(pos), 0))


# 某类型设施下一级的升级信息；{} 表示该类型不可升级或已满级
func defense_upgrade_info(type: String, current_level: int) -> Dictionary:
	var levels: Array = DEFENSE_UPGRADES.get(type, [])
	if current_level < 0 or current_level >= levels.size():
		return {}
	return levels[current_level]


# 升级指定位置的防御设施：建材从据点仓库扣，等级记进 defense_levels；测试模式直接成功
func upgrade_base_defense(pos: Vector3) -> bool:
	if not has_home_base():
		return false
	var defenses: Array = home_base["defenses"]
	for entry in defenses:
		var p: Vector3 = entry["pos"]
		if Vector2(p.x - pos.x, p.z - pos.z).length() >= 0.8:
			continue
		var type := String(entry["type"])
		var level := defense_upgrade_level(p)
		var info := defense_upgrade_info(type, level)
		if info.is_empty():
			notify("%s 没有更多升级" % String(BASE_DEFENSES.get(type, {}).get("name", type)))
			return false
		if not spend_materials(int(info["cost"])):
			return false
		var levels: Dictionary = home_base["defense_levels"]
		levels[defense_key(p)] = level + 1
		home_base_changed.emit()
		notify("%s 升级至 %d 级" % [String(BASE_DEFENSES[type]["name"]), level + 1])
		return true
	return false


# 据点信号覆盖半径：15m + 10m×等级
func base_signal_radius() -> float:
	if not has_home_base():
		return 0.0
	return BASE_SIGNAL_BASE_RADIUS + BASE_SIGNAL_LEVEL_RADIUS * home_base_level()


# 当前据点提供的信号强度（0 表示不在覆盖内），供 HUD 提示
func base_signal_strength() -> float:
	return float(_signal_sources.get(BASE_SIGNAL_ID, 0.0))


# 把背包资源/现金转入据点储物，返回实际存入数量
func store_loot(kind: String, amount: int) -> int:
	if not has_home_base() or amount <= 0:
		return 0
	var storage: Dictionary = home_base["storage"]
	var take := 0
	if kind == "money":
		take = mini(amount, money)
		if take <= 0:
			return 0
		money -= take
		money_changed.emit(money)
	elif kind == "ammo":
		# 弹药按口径/弹种明细入仓（storage["ammo"] 记总发数，ammo_detail 记明细供原样取回）
		take = mini(amount, total_ammo())
		if take <= 0:
			return 0
		var detail: Dictionary = storage.get("ammo_detail", {})
		var left := take
		for _cal in ammo_stock:
			for _t in ammo_stock[_cal]:
				var avail := int(ammo_stock[_cal][_t])
				var moved := mini(avail, left)
				if moved > 0:
					ammo_stock[_cal][_t] = avail - moved
					if not detail.has(_cal):
						detail[_cal] = {}
					detail[_cal][_t] = int(detail[_cal].get(_t, 0)) + moved
					left -= moved
		storage["ammo_detail"] = detail
		take = take - left
		if take <= 0:
			return 0
		resources_changed.emit()
	elif resources.has(kind):
		take = mini(amount, int(resources.get(kind, 0)))
		if take <= 0:
			return 0
		resources[kind] = int(resources[kind]) - take
		resources_changed.emit()
	else:
		return 0
	storage[kind] = int(storage.get(kind, 0)) + take
	home_base_changed.emit()
	return take


# 仓库可存取的种类（UI 显示顺序）
const STORAGE_KINDS := ["food", "meds", "ammo", "materials", "fuel", "money", "crystals"]


# 从据点仓库取出到背包，返回实际取出数量（ammo 按入仓明细原样取回，无明细的旧档转为手枪普通弹）
func withdraw_loot(kind: String, amount: int) -> int:
	if not has_home_base() or amount <= 0:
		return 0
	var storage: Dictionary = home_base["storage"]
	var have := int(storage.get(kind, 0))
	var take := mini(amount, have)
	if take <= 0:
		return 0
	match kind:
		"money":
			money += take
			money_changed.emit(money)
		"ammo":
			var detail: Dictionary = storage.get("ammo_detail", {})
			if detail.is_empty():
				add_ammo("pistol", "normal", take)
			else:
				var left := take
				for cal in detail.keys():
					for t in (detail[cal] as Dictionary).keys():
						var moved := mini(int(detail[cal][t]), left)
						if moved > 0:
							add_ammo(String(cal), String(t), moved)
							detail[cal][t] = int(detail[cal][t]) - moved
							left -= moved
				# 清空零项
				for cal in detail.keys():
					var empty := true
					for t in (detail[cal] as Dictionary).values():
						if int(t) > 0:
							empty = false
					if empty:
						detail.erase(cal)
		"crystals":
			add_loot("anomaly_crystal", take)
		_:
			resources[kind] = int(resources.get(kind, 0)) + take
			resources_changed.emit()
	storage[kind] = have - take
	home_base_changed.emit()
	return take


# 一键存放：身上食物/药品/弹药/燃料/建材/现金尽数入仓，结晶需有储存仓；返回摘要文本
func store_all_loot() -> String:
	if not has_home_base():
		return ""
	var parts: Array = []
	for kind in ["food", "meds", "fuel", "materials"]:
		var amount := int(resources.get(kind, 0))
		if amount > 0:
			var got := store_loot(kind, amount)
			if got > 0:
				parts.append("%s ×%d" % [_supply_name(kind), got])
	var ammo_total := total_ammo()
	if ammo_total > 0:
		var got := store_loot("ammo", ammo_total)
		if got > 0:
			ammo_stock.clear()
			parts.append("弹药 ×%d" % got)
	if money > 0:
		var got_money := store_loot("money", money)
		if got_money > 0:
			parts.append("现金 ¥%d" % got_money)
	var crystals := loot_count("anomaly_crystal")
	if crystals > 0 and base_has_containment():
		for i in crystals:
			remove_loot("anomaly_crystal")
		var storage: Dictionary = home_base["storage"]
		storage["crystals"] = int(storage.get("crystals", 0)) + crystals
		home_base_changed.emit()
		parts.append("异能结晶 ×%d（已入储存仓）" % crystals)
	return "已存入据点仓库：" + "、".join(parts) if not parts.is_empty() else ""


# 硬死亡结算：据点储物按折现率（40% 起，据点升级提升，回响可加成）折算 SP，返回折现值并清空储物
func home_storage_cashout() -> int:
	if home_base.is_empty():
		return 0
	var storage: Dictionary = home_base.get("storage", {})
	var value := (
		int(storage.get("food", 0)) * 2
		+ int(storage.get("meds", 0)) * 4
		+ int(storage.get("ammo", 0))
		+ int(storage.get("fuel", 0))
		+ int(storage.get("money", 0)) / 10
	)
	home_base["storage"] = {"food": 0, "meds": 0, "ammo": 0, "money": 0, "materials": 0, "fuel": 0, "crystals": 0}
	return int(value * home_storage_rate() * echo_cashout_mult())


func echo_info(id: String) -> Dictionary:
	for echo in ECHO_POOL:
		if String(echo["id"]) == id:
			return echo
	return {}


func has_echo(id: String) -> bool:
	return run_echoes.has(id)


# 灾变降临与每日黎明触发：从本局未选的回响中随机 3 个供选择
func offer_echoes() -> void:
	var available: Array = []
	for echo in ECHO_POOL:
		if not has_echo(String(echo["id"])):
			available.append(echo)
	if available.is_empty():
		return
	available.shuffle()
	echo_offer = available.slice(0, mini(3, available.size()))
	echo_offered.emit(echo_offer)


func pick_echo(id: String) -> bool:
	for echo in echo_offer:
		if String(echo["id"]) == id:
			run_echoes.append(id)
			echo_offer = []
			notify("回响铭刻：%s——%s" % [String(echo["name"]), String(echo["desc"])])
			return true
	return false


func _echo_mult(key: String) -> float:
	var mult := 1.0
	for id in run_echoes:
		mult *= float(echo_info(String(id)).get(key, 1.0))
	return mult


func _echo_sum(key: String) -> float:
	var total := 0.0
	for id in run_echoes:
		total += float(echo_info(String(id)).get(key, 0.0))
	return total


func echo_gun_mult() -> float:
	return _echo_mult("gun_mult")


func echo_move_mult() -> float:
	return _echo_mult("move_mult")


func echo_hunger_mult() -> float:
	return _echo_mult("hunger_mult")


func echo_hp_mult() -> float:
	return _echo_mult("hp_mult")


func echo_stamina_mult() -> float:
	return _echo_mult("stamina_mult")


func echo_reload_mult() -> float:
	return _echo_mult("reload_mult")


func echo_noise_mult() -> float:
	return _echo_mult("noise_mult")


func echo_loot_mult() -> float:
	return _echo_mult("loot_mult")


func echo_cashout_mult() -> float:
	return 1.0 + _echo_sum("cashout_bonus")


func echo_melee_lifesteal() -> float:
	return _echo_sum("melee_lifesteal")


func echo_crit_chance() -> float:
	return _echo_sum("crit_chance")


func echo_ammo_drop_bonus() -> float:
	return _echo_sum("ammo_drop")


func echo_regen() -> float:
	return _echo_sum("regen")


func end_run(won: bool, reason: String) -> void:
	if is_run_over():
		return
	phase = "won" if won else "lost"
	phase_changed.emit(phase)
	notify(reason)
	run_ended.emit(won, reason)


func reset_run(reload_scene := false) -> void:
	money = 200
	revive_count = 0
	infinite_ammo = false
	infinite_reserve = false
	rogue_xp = 0
	rogue_level = 0
	rogue_ranks.clear()
	rogue_prep_left = 0.0
	rogue_cores_left = 0
	rogue_active_elapsed = 0.0
	rogue_stage = 0
	rogue_phase = "prep"
	rogue_dev_left = 0.0
	training_ground = false
	_hot_left = 0.0
	_hot_rate = 0.0
	_hot_accum = 0.0
	slowmo_active = false
	_slowmo_until = 0
	_slowmo_cd_until = 0
	Engine.time_scale = 1.0
	poison_timer = 0.0
	poison_total = 0.0
	_poison_accum = 0.0
	if test_mode:
		apply_test_loadout()
	# 技能与变异是全局能力，撤离/死亡后都保留
	mutation_queue.clear()
	mutation_offer.clear()
	pending_mutation = ""
	_announced_stage = -1
	_combat_regen_until = 0
	_combat_regen_rate = 0.0
	_serum_until = 0
	_serum_rate = 0.0
	_nap_timer = 0.0
	_second_wind_msec = 0
	_survival_timer = 0.0
	_heal_accum = 0.0
	_last_damage_msec = 0
	skills_changed.emit()
	mutations_changed.emit()
	skill_points_changed.emit(skill_points)
	hp = max_hp()
	wanted = 0
	vault_key = false
	crime_points = 0
	player_kills = 0
	_crime_reports.clear()
	_gunshot_alerts.clear()
	_last_gunshot_notice = 0
	anomaly = 0
	grid_repaired = false
	zones_destroyed.clear()
	in_anomaly_zone = false
	jail_active = false
	jail_timer = 0.0
	faction = FACTION_HUMAN
	alignment = ALIGN_GOOD
	infected = false
	infection_timer = 0.0
	infection_exposure = 0.0
	zombie_redeem = 0
	stamina = max_stamina()
	satiety = MAX_SATIETY
	_starve_timer = 0.0
	resources = {"food": 0, "meds": 0, "ammo": 12, "materials": 0, "fuel": 0}
	for kind in resources.keys():
		resources[kind] += int(meta_supplies.get(kind, 0))
	meta_supplies = {"food": 0, "meds": 0, "ammo": 0}
	weapons = meta_weapons.duplicate()
	weapon_slots.clear()
	_sync_weapon_slots()
	mag_state.clear()
	reloading = false
	reload_weapon = ""
	if (
		int(weapons.get("pistol", 0))
		+ int(weapons.get("shotgun", 0))
		+ int(weapons.get("rifle", 0)) <= 0
	):
		weapons["pistol"] = 1
	current_weapon = "melee"
	for id in ["rifle", "shotgun", "pistol"]:
		if int(weapons.get(id, 0)) > 0:
			current_weapon = id
			break
	save_meta()
	return_position = SPAWN_POS
	pending_building = ""
	phase = "prepare"
	round_elapsed = 0.0
	time_left = prep_duration()
	outbreak_elapsed = 0.0
	outbreak_site = {}
	outbreak_sites.clear()
	day_number = 1
	day_elapsed = 0.0
	weather = "clear"
	moon_phase = 1.0
	weather_changed.emit(weather, moon_phase)
	_last_world_stage = -1
	home_base = {}
	base_build_mode = false
	interact_menu_open = false
	demolished_buildings.clear()
	demolished_towers.clear()
	scavenged_buildings.clear()
	scavenge_pools.clear()
	scavenge_cooldowns.clear()
	building_material_pool.clear()
	building_hp.clear()
	run_echoes.clear()
	echo_offer.clear()
	boss_sp_bonus = 0
	news.clear()
	map_open = false
	backpack_open = false
	zombie_transform_chance = 0.99
	bite_infect_chance = 0.99
	spread_infect_chance = 0.9
	transform_delay = 10.0
	signal_strength = 0.0
	in_coverage = false
	_signal_sources.clear()
	_sighting_msec = 0
	_bite_report_msec = 0
	_transform_report_msec = 0
	_intro_done = false
	_last_seen_msec = 0
	home_base_changed.emit()
	money_changed.emit(money)
	hp_changed.emit(hp)
	resources_changed.emit()
	weapons_changed.emit()
	wanted_changed.emit(wanted)
	stamina_changed.emit(stamina)
	satiety_changed.emit(satiety)
	phase_changed.emit(phase)
	ammo_stock.clear()
	_migrate_legacy_ammo()
	if reload_scene:
		get_tree().change_scene_to_file(home_scene)


func current_weapon_data() -> Dictionary:
	if current_weapon == "" or weapons.get(current_weapon, 0) <= 0:
		return {}
	return WEAPONS[current_weapon]


func add_weapon(id: String) -> void:
	if not WEAPONS.has(id):
		return
	weapons[id] = weapons.get(id, 0) + 1
	mag_state[id] = mag_size(id)
	assign_weapon_slot(id)
	if current_weapon == "" or current_weapon_data().is_empty():
		current_weapon = id
	weapons_changed.emit()


# ===== 武器槽（2 个）：背包双击武器入槽（挤位下压），双击槽内武器退回背包 =====
var weapon_slots: Array = []
const WEAPON_SLOT_MAX := 2


# 捡到武器时自动补空槽（最多 2 个；满了就留在背包，近战 V、手榴弹 G 不占槽）
func assign_weapon_slot(id: String) -> void:
	if id == "" or id == "melee" or id == "grenade" or weapon_slots.has(id):
		return
	if not WEAPONS.has(id):
		return
	if weapon_slots.size() < WEAPON_SLOT_MAX:
		weapon_slots.append(id)


# 武器整批发放时（开局复制 meta / 测试装备）同步槽位；同时清掉已丢失的武器
func _sync_weapon_slots() -> void:
	for i in range(weapon_slots.size() - 1, -1, -1):
		if int(weapons.get(weapon_slots[i], 0)) <= 0:
			weapon_slots.remove_at(i)
	for id in WEAPONS.keys():
		if id == "melee" or id == "grenade":
			continue
		if (
			int(weapons.get(id, 0)) > 0
			and not weapon_slots.has(id)
			and weapon_slots.size() < WEAPON_SLOT_MAX
		):
			weapon_slots.append(id)


# 背包双击武器：进入 1 号槽，原 1 号槽挤到 2 号槽，原 2 号槽退回背包
func equip_weapon(id: String) -> void:
	if not WEAPONS.has(id) or int(weapons.get(id, 0)) <= 0:
		return
	if id == "melee" or id == "grenade":
		return
	weapon_slots.erase(id)
	weapon_slots.push_front(id)
	while weapon_slots.size() > WEAPON_SLOT_MAX:
		weapon_slots.pop_back()
	weapons_changed.emit()


# 双击槽内武器：退回背包（仍在 weapons 里，只是不占槽）
func unequip_weapon(id: String) -> void:
	if not weapon_slots.has(id):
		return
	weapon_slots.erase(id)
	if current_weapon == id:
		if weapon_slots.is_empty():
			select_weapon("melee")
		else:
			select_weapon(String(weapon_slots[0]))
	weapons_changed.emit()


# ===== 手榴弹：G 键直接投掷（不切武器），CD 1 秒，数量 = weapons["grenade"] =====
var grenade_cd_until_msec := 0


func grenade_count() -> int:
	return int(weapons.get("grenade", 0))


func grenade_cd_left() -> float:
	return maxf(0.0, float(grenade_cd_until_msec - Time.get_ticks_msec()) / 1000.0)


# 消耗一颗手雷并进入 1 秒冷却；false = 没雷或冷却中
func consume_grenade() -> bool:
	if Time.get_ticks_msec() < grenade_cd_until_msec:
		return false
	if grenade_count() <= 0:
		return false
	if not infinite_ammo:
		weapons["grenade"] = grenade_count() - 1
	grenade_cd_until_msec = Time.get_ticks_msec() + 1000
	weapons_changed.emit()
	return true


# 取某号位（0~7）当前占用的武器 id，空槽返回 ""
func weapon_at_slot(index: int) -> String:
	if index >= 0 and index < weapon_slots.size():
		return String(weapon_slots[index])
	return ""


# 手柄十字键上下：按槽位顺序循环切换武器
func cycle_weapon_slot(dir: int) -> void:
	if weapon_slots.is_empty():
		return
	var idx := weapon_slots.find(current_weapon)
	if idx < 0:
		idx = 0 if dir > 0 else weapon_slots.size() - 1
	else:
		idx = (idx + dir + weapon_slots.size()) % weapon_slots.size()
	select_weapon(weapon_slots[idx])


func select_weapon(id: String) -> void:
	if id != "melee" and weapons.get(id, 0) <= 0:
		if WEAPONS.has(id):
			notify("没有%s，去枪店或警察局弄一把（1~2 切换武器槽）" % WEAPONS[id]["name"])
		return
	if current_weapon == id:
		return
	current_weapon = id
	reloading = false
	reload_weapon = ""
	weapons_changed.emit()


# 把装备交给随从：玩家失去该装备并刷新热键栏（当前武器被给出时自动切换）
func strip_weapon(id: String) -> void:
	if not WEAPONS.has(id):
		return
	weapons[id] = 0
	if current_weapon == id:
		current_weapon = ""
		for other in ["rifle", "lmg", "sniper", "smg", "shotgun", "pistol"]:
			if int(weapons.get(other, 0)) > 0:
				current_weapon = other
				break
		if current_weapon == "":
			current_weapon = "melee"
		reloading = false
		reload_weapon = ""
	weapons_changed.emit()


func strip_armor() -> void:
	armor_id = ""
	armor_resist_value = 0.0
	weapons_changed.emit()


func strip_melee() -> void:
	melee_item = ""
	melee_item_damage = 0
	weapons_changed.emit()


func cycle_weapon(dir: int) -> void:
	var owned: Array = []
	for id in ["melee", "pistol", "smg", "shotgun", "rifle", "sniper", "lmg", "rpg"]:
		if id == "melee" or int(weapons.get(id, 0)) > 0:
			owned.append(id)
	if owned.is_empty():
		return
	var index := owned.find(current_weapon)
	if index < 0:
		index = 0
	select_weapon(owned[(index + dir + owned.size()) % owned.size()])


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		notify("钱不够（需要 ¥%d）" % amount)
		return false
	money -= amount
	money_changed.emit(money)
	return true


func add_resource(kind: String, amount := 1) -> void:
	if kind == "ammo":
		# 通用弹药来源按口径拆分（普通弹）
		grant_generic_ammo(amount)
		return
	var cap: int = CAPS.get(kind, 999)
	resources[kind] = mini(resources.get(kind, 0) + amount, cap)
	resources_changed.emit()


# 玩家是否站在据点半径内（进入营地范围，身上物资与仓库共享）
func player_in_base_radius() -> bool:
	if not has_home_base():
		return false
	var player := get_tree().get_first_node_in_group("player") if get_tree() != null else null
	if player == null:
		return false
	var base_pos: Vector3 = home_base.get("position", Vector3.ZERO)
	return _flat_distance(player.global_position, base_pos) <= home_base_radius()


# 建材消耗：据点仓库/随身/据点旁建材堆与车斗共享（进入营地范围后无需先存入）；
# 测试模式物资无限，直接成功且不扣料
func spend_materials(amount: int) -> bool:
	if test_mode:
		return true
	if not has_home_base():
		notify("需要先建立据点仓库才能使用建材")
		return false
	if base_materials_available() < amount:
		notify("建材不够（需要建材 ×%d，可把建材堆/车斗开到据点旁直接抵扣）" % amount)
		return false
	# 先扣仓库，再扣随身建材（营地范围内共享），最后从据点旁的建材堆与车斗抵扣
	var storage: Dictionary = home_base["storage"]
	var from_storage := mini(amount, int(storage.get("materials", 0)))
	storage["materials"] = int(storage.get("materials", 0)) - from_storage
	var remaining := amount - from_storage
	if remaining > 0 and player_in_base_radius():
		var from_carry := mini(remaining, int(resources.get("materials", 0)))
		if from_carry > 0:
			resources["materials"] = int(resources.get("materials", 0)) - from_carry
			resources_changed.emit()
			remaining -= from_carry
	if remaining > 0:
		var base_pos: Vector3 = home_base.get("position", Vector3.ZERO)
		var radius := home_base_radius()
		for pile in get_tree().get_nodes_in_group("material_piles"):
			if remaining <= 0:
				break
			if pile.is_queued_for_deletion():
				continue
			if _flat_distance(pile.global_position, base_pos) > radius:
				continue
			var take := mini(remaining, int(pile.amount))
			pile.amount -= take
			remaining -= take
			if int(pile.amount) <= 0:
				pile.queue_free()
			elif pile.has_method("_rebuild"):
				pile._rebuild()
		for vehicle in get_tree().get_nodes_in_group("vehicles"):
			if remaining <= 0:
				break
			if vehicle.is_queued_for_deletion():
				continue
			if _flat_distance(vehicle.global_position, base_pos) > radius:
				continue
			var take := mini(remaining, int(vehicle.get("cargo")))
			vehicle.set("cargo", int(vehicle.get("cargo")) - take)
			remaining -= take
	home_base_changed.emit()
	return true


# 据点可用建材总量：仓库 + 随身建材（营地范围内共享）+ 半径内散落建材堆 + 半径内车斗建材
func base_materials_available() -> int:
	if test_mode:
		return 9999
	if not has_home_base():
		return 0
	var total := int(home_base.get("storage", {}).get("materials", 0))
	if player_in_base_radius():
		total += int(resources.get("materials", 0))
	var base_pos: Vector3 = home_base.get("position", Vector3.ZERO)
	var radius := home_base_radius()
	var tree := get_tree()
	if tree == null:
		return total
	for pile in tree.get_nodes_in_group("material_piles"):
		if pile.is_queued_for_deletion():
			continue
		if _flat_distance(pile.global_position, base_pos) <= radius:
			total += int(pile.amount)
	for vehicle in tree.get_nodes_in_group("vehicles"):
		if vehicle.is_queued_for_deletion():
			continue
		if _flat_distance(vehicle.global_position, base_pos) <= radius:
			total += int(vehicle.get("cargo"))
	return total


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# 建材可随身携带（徒手拾取建材堆计入 resources["materials"]，回据点"存入全部物资"入仓）：供 UI/拾取逻辑判定
func materials_carriable() -> bool:
	return true


# 据点仓库建材存量；测试模式视为无限
func base_materials() -> int:
	if test_mode:
		return 9999
	if not has_home_base():
		return 0
	return int(home_base.get("storage", {}).get("materials", 0))


# 据点仓库容量：100 + 50×据点等级 + 100×扩容次数
func base_storage_cap() -> int:
	return 100 + 50 * home_base_level() + 100 * int(home_base.get("storage_upgrade", 0))


# 建材入仓：受仓库容量限制，返回实际入仓数；测试模式无视容量
func add_materials_to_base(amount: int) -> int:
	if not has_home_base() or amount <= 0:
		return 0
	var storage: Dictionary = home_base["storage"]
	var current := int(storage.get("materials", 0))
	var take := amount if test_mode else mini(amount, maxi(0, base_storage_cap() - current))
	if take <= 0:
		return 0
	storage["materials"] = current + take
	home_base_changed.emit()
	return take


# 仓库扩容花费（建材，从仓库存量扣）
func upgrade_storage_cost() -> int:
	return STORAGE_UPGRADE_COST


# 仓库扩容 +100 容量；测试模式直接成功不扣料
func upgrade_base_storage() -> bool:
	if not has_home_base():
		return false
	if not spend_materials(upgrade_storage_cost()):
		return false
	home_base["storage_upgrade"] = int(home_base.get("storage_upgrade", 0)) + 1
	home_base_changed.emit()
	notify("仓库扩容完成：容量 %d" % base_storage_cap())
	return true


# 工人系统：据点招募的市民（数据存 home_base["workers"]，每项 {name, job, state, data}），
# 每天黎明每人消耗 2 食物（先扣据点仓库，不够扣玩家背包），断粮的工人离队
const WORKER_FOOD_PER_DAY := 2
const WORKER_JOBS := {
	"idle": "待命",
	"guard": "守护营地",
	"build": "建造营地",
	"scavenge": "出门寻找物资",
	"collect": "收集战斗掉落",
	"follow": "跟随主角战斗",
	"goto": "前往某地",
	"operate": "操作设施",
}
# 设施操作员：只有需要人操作的设备才有工作位——
# 炮塔与制造/生产类（武器制造台/食品合成台/医疗组装台/医疗台/工作台/转换器）；
# 围墙/地刺/路障/灯与基建类（发电机/太阳能/风力/电池/信号塔/储存仓）不需要操作员。
# auto=false 的设施必须指派操作员才能运行，auto=true 的自动运行、操作员提供加成
const OPERATOR_DEFS := {
	"turret": {"slots": 2, "auto": true, "desc": "操作员：射速 +25%/人", "skill": "射击"},
	"workbench": {"slots": 1, "auto": true, "desc": "驻守：HP 每秒回复 1", "skill": "工程"},
	"converter": {"slots": 1, "auto": true, "desc": "驻守：HP 每秒回复 1", "skill": "机械"},
	"fabricator": {"slots": 2, "auto": true, "desc": "操作员：制造速度 +25%/人", "skill": "机械"},
	"food_synth": {"slots": 2, "auto": false, "desc": "必须有操作员才能生产（每操作员速度 +25%）", "skill": "农艺"},
	"med_station": {"slots": 2, "auto": false, "desc": "必须有操作员才能生产（每操作员速度 +25%）", "skill": "医疗"},
	"potion_brewer": {"slots": 2, "auto": false, "desc": "必须有操作员才能生产（每操作员速度 +25%）", "skill": "医疗"},
	"mortar": {"slots": 1, "auto": true, "desc": "操作员：装填速度 +25%/人", "skill": "射击"},
	"cannon": {"slots": 1, "auto": true, "desc": "操作员：装填速度 +25%/人", "skill": "射击"},
}
# 市民技能池（分配设施时展示，并对口加成预留）
const WORKER_SKILL_POOL: Array[String] = ["射击", "工程", "机械", "医疗", "农艺", "电讯", "搜集"]
const WORKER_SURNAMES := [
	"王", "李", "张", "刘", "陈", "杨", "赵", "黄", "周", "吴",
	"徐", "孙", "马", "朱", "胡", "郭", "何", "林", "罗", "郑",
]
const WORKER_GIVEN := [
	"伟", "强", "磊", "军", "洋", "勇", "杰", "涛", "明", "超",
	"秀英", "桂兰", "霞", "敏", "静", "丽丽", "艳", "娟", "芳", "燕",
	"建国", "志强", "铁柱", "守业", "有福", "小雨", "子轩", "一鸣", "思远", "念安",
]


# 工人列表（无据点时返回空数组；不要在无据点时持有返回数组做写入）
func workers() -> Array:
	if not has_home_base():
		return []
	if not home_base.has("workers"):
		home_base["workers"] = []
	return home_base["workers"]


# 工人容量：1 + 据点等级
func worker_cap() -> int:
	return 1 + home_base_level() if has_home_base() else 0


func worker_count() -> int:
	return workers().size()


# 随机中文工人名
func recruit_worker_name() -> String:
	return (
		WORKER_SURNAMES[randi() % WORKER_SURNAMES.size()]
		+ WORKER_GIVEN[randi() % WORKER_GIVEN.size()]
	)


func get_worker(wname: String) -> Dictionary:
	for w in workers():
		if String(w["name"]) == wname:
			return w
	return {}


func add_worker(wname: String) -> bool:
	if not has_home_base():
		return false
	if not get_worker(wname).is_empty():
		return false
	if worker_count() >= worker_cap():
		notify("营地工人已满（%d/%d），升级据点可扩容" % [worker_count(), worker_cap()])
		return false
	workers().append({"name": wname, "job": "idle", "state": "home", "data": {}, "level": 0})
	home_base_changed.emit()
	return true


func assign_worker(wname: String, job: String, data := {}) -> bool:
	var w := get_worker(wname)
	if w.is_empty() or not WORKER_JOBS.has(job):
		return false
	# 新指令打断旧指令：改派其它岗位时自动撤出设施操作员位
	if job != "operate" and home_base.has("operators"):
		var ops: Dictionary = home_base["operators"]
		for key in ops.keys():
			(ops[key] as Array).erase(wname)
	w["job"] = job
	w["data"] = data
	if job != "scavenge":
		w["state"] = "home"
	home_base_changed.emit()
	return true


func remove_worker(wname: String) -> bool:
	var list := workers()
	for i in list.size():
		if String(list[i]["name"]) == wname:
			list.remove_at(i)
			home_base_changed.emit()
			return true
	return false


func worker_job_name(job: String) -> String:
	return String(WORKER_JOBS.get(job, job))


# —— 设施操作员（home_base["operators"]: defense_key → [工人名]）——

func operator_slots(type: String) -> int:
	# 不在 OPERATOR_DEFS 里的设施没有工作位（围墙/地刺/路障/灯/基建类）
	return int(OPERATOR_DEFS.get(type, {}).get("slots", 0))


func operator_needs(type: String) -> bool:
	return not bool(OPERATOR_DEFS.get(type, {}).get("auto", true))


func operator_desc(type: String) -> String:
	return String(OPERATOR_DEFS.get(type, {}).get("desc", ""))


func operator_skill(type: String) -> String:
	return String(OPERATOR_DEFS.get(type, {}).get("skill", ""))


func defense_operators(pos: Vector3) -> Array:
	if not has_home_base():
		return []
	var ops: Dictionary = home_base.get("operators", {})
	return ops.get(defense_key(pos), [])


func defense_operator_count(pos: Vector3) -> int:
	return defense_operators(pos).size()


# 指派工人到设施工作位：满员或无工作位的设施拒绝；同一工人只能守一台设施（先从旧位置撤出）
func assign_operator(pos: Vector3, wname: String, type: String) -> bool:
	if not has_home_base() or get_worker(wname).is_empty():
		return false
	if operator_slots(type) <= 0:
		return false
	if not home_base.has("operators"):
		home_base["operators"] = {}
	var key := defense_key(pos)
	var ops: Dictionary = home_base["operators"]
	var list: Array = ops.get(key, []) as Array
	if list.has(wname):
		return true
	if list.size() >= operator_slots(type):
		notify("工作位已满（%d/%d）" % [list.size(), operator_slots(type)])
		return false
	# 从旧设施撤出
	for other_key in ops.keys():
		var other: Array = ops[other_key] as Array
		if other.has(wname):
			other.erase(wname)
	list.append(wname)
	ops[key] = list
	assign_worker(wname, "operate", {"pos": pos})
	home_base_changed.emit()
	notify("%s 开始操作%s" % [wname, String(BASE_DEFENSES.get(type, {}).get("name", "设施"))])
	return true


func unassign_operator(pos: Vector3, wname: String) -> void:
	if not has_home_base():
		return
	var ops: Dictionary = home_base.get("operators", {})
	var key := defense_key(pos)
	var list: Array = ops.get(key, [])
	if list.has(wname):
		list.erase(wname)
		assign_worker(wname, "idle")
		home_base_changed.emit()


# 某类设施中有操作员看守的数量（发电/耗电加成用）
func operated_defense_count(type: String) -> int:
	if not has_home_base():
		return 0
	var count := 0
	for entry in home_base.get("defenses", []):
		if String(entry.get("type", "")) == type and defense_operator_count(entry["pos"]) > 0:
			count += 1
	return count


# 市民技能（用于操作员界面展示）：按名字确定性生成 2 项，存档稳定
func worker_skills(wname: String) -> Array:
	var w := get_worker(wname)
	if w.is_empty():
		return skills_for_name(wname)
	if not w.has("skills"):
		w["skills"] = skills_for_name(wname)
	return w["skills"]


# 按名字确定性生成 2 项技能（不需要工人记录，随从招募前也能展示）
func skills_for_name(wname: String) -> Array:
	var h: int = abs(wname.hash())
	var first: String = WORKER_SKILL_POOL[h % WORKER_SKILL_POOL.size()]
	var second: String = WORKER_SKILL_POOL[(h / 7 + 3) % WORKER_SKILL_POOL.size()]
	while second == first:
		second = WORKER_SKILL_POOL[(WORKER_SKILL_POOL.find(second) + 1) % WORKER_SKILL_POOL.size()]
	return [first, second]


# 市民熟练度（设计文档 5.3）：同岗越久等级越高，死亡作废。
# 上限 5 级，每级效率 +15%（占位值，待调优）。
const WORKER_PROFICIENCY_MAX := 5


func worker_proficiency(wname: String) -> int:
	var w := get_worker(wname)
	if w.is_empty():
		return 0
	return int(w.get("level", 0))


func worker_gain_proficiency(wname: String) -> bool:
	var w := get_worker(wname)
	if w.is_empty():
		return false
	var lv := int(w.get("level", 0))
	if lv >= WORKER_PROFICIENCY_MAX:
		return false
	w["level"] = lv + 1
	home_base_changed.emit()
	notify("%s 熟练度提升到 %d 级！" % [wname, lv + 1])
	return true


# 物资类别中文名（工人带回/搬运通知用）
func _supply_name(kind: String) -> String:
	match kind:
		"food":
			return "食物"
		"meds":
			return "药品"
		"ammo":
			return "弹药"
		"materials":
			return "建材"
		"fuel":
			return "燃料"
		"money":
			return "现金"
	return kind


# 单个工人的黎明口粮：先扣据点仓库食物，不够扣玩家背包；付不起返回 false
func _pay_worker_upkeep() -> bool:
	var storage: Dictionary = home_base["storage"]
	var need := WORKER_FOOD_PER_DAY
	var from_storage := mini(need, int(storage.get("food", 0)))
	if from_storage > 0:
		storage["food"] = int(storage.get("food", 0)) - from_storage
		need -= from_storage
		home_base_changed.emit()
	if need > 0:
		var from_pack := mini(need, int(resources.get("food", 0)))
		if from_pack > 0:
			resources["food"] = int(resources.get("food", 0)) - from_pack
			need -= from_pack
			resources_changed.emit()
	return need <= 0


# 黎明结算工人口粮：付不起 2 食物的工人离队
func _feed_workers() -> void:
	if not has_home_base() or workers().is_empty():
		return
	var starving: Array = []
	for w in workers():
		if not _pay_worker_upkeep():
			starving.append(String(w["name"]))
	for wname in starving:
		remove_worker(wname)
		notify("%s 因断粮离开了营地" % wname)


# 地图标点（2D 像素）换算 3D 世界坐标
func map_marker_3d() -> Vector3:
	return Vector3(map_marker.x * WORLD_SCALE_3D, 0.0, map_marker.y * WORLD_SCALE_3D)


# 出门寻找物资的工人返回：带回 2~4 种随机物资（各 2~6）入据点仓库；实体表现由 worker3d 负责
func worker_scavenge_return(wname: String) -> void:
	var w := get_worker(wname)
	if w.is_empty():
		return
	w["state"] = "home"
	var data: Dictionary = w.get("data", {})
	data.erase("return_msec")
	w["data"] = data
	if not has_home_base():
		return
	var storage: Dictionary = home_base["storage"]
	var pool := ["food", "meds", "ammo", "materials", "fuel"]
	pool.shuffle()
	var parts: Array = []
	for i in mini(randi_range(2, 4), pool.size()):
		var kind: String = pool[i]
		var amount := randi_range(2, 6)
		storage[kind] = int(storage.get(kind, 0)) + amount
		parts.append("%s ×%d" % [_supply_name(kind), amount])
	home_base_changed.emit()
	notify("%s 带回了物资（%s）" % [wname, "、".join(parts)])


# 车辆后备箱容量：未知车型返回默认值 60
func vehicle_cargo_cap(model: String) -> int:
	return int(VEHICLE_CARGO.get(model, VEHICLE_CARGO_DEFAULT))


# 是否算大楼：占地 > 150000 像素² 或 3 层及以上（影响收益/动静/时长）
func demolish_is_big(size_px: Vector2, floors := 1) -> bool:
	return size_px.x * size_px.y > DEMOLISH_BIG_AREA or floors >= 3


# 拆除建材收益：按体积 w×d×(0.6+0.4×层数)/1000 取整，下限 10；
# 大楼收益 ×4（TOWERS 级别建筑 ~1200）；旧调用只传 size_px 依然兼容
func demolish_yield(size_px: Vector2, floors := 1) -> int:
	var gain := size_px.x * size_px.y * (0.6 + 0.4 * floors) / 1000.0
	if demolish_is_big(size_px, floors):
		gain *= 4.0
	return maxi(10, int(roundf(gain)))


# 建筑/塔楼剩余可拆建材库存（key 用中心像素坐标），从未拆过的返回满库存
func building_pool_remaining(pos: Vector2) -> int:
	return int(building_material_pool.get(pos, BUILDING_MATERIAL_POOL))


# 从建筑库存里提取一次建材（最多 BUILDING_MATERIAL_PER_DEMOLISH），写回字典并返回实取值
func mine_building_materials(pos: Vector2) -> int:
	var remaining := building_pool_remaining(pos)
	var got := mini(BUILDING_MATERIAL_PER_DEMOLISH, remaining)
	building_material_pool[pos] = remaining - got
	return got


# 建筑/塔楼结构耐久（key 同上），未记录返回满血
func building_hp_at(pos: Vector2) -> int:
	return int(building_hp.get(pos, BUILDING_HP))


# 爆炸扣血并写回，返回是否已摧毁（≤0）
func damage_building_hp(pos: Vector2, dmg: int) -> bool:
	var hp := maxi(0, building_hp_at(pos) - maxi(0, dmg))
	building_hp[pos] = hp
	return hp <= 0


# 拆除动静半径（米）：普通建筑 30m，大楼 120m（远大于枪声 25~62m）
func demolish_noise_radius(size_px: Vector2, floors := 1) -> float:
	return DEMOLISH_NOISE_BIG if demolish_is_big(size_px, floors) else DEMOLISH_NOISE_SMALL


# 拆除长按秒数：普通建筑 2s、大楼 6s；工具加速（tool_id 为空时自动取玩家最好的工具）
func demolish_hold_seconds(size_px: Vector2, tool_id := "", floors := 1) -> float:
	var seconds := DEMOLISH_HOLD_BIG if demolish_is_big(size_px, floors) else DEMOLISH_HOLD_SMALL
	if tool_id == "":
		tool_id = best_demolish_tool()
	return seconds * float(DEMOLISH_TOOL_MULT.get(tool_id, 1.0))


# 玩家持有的最好拆除工具（镐 > 消防斧 > 铁锤）：查装备的近战武器与背包；没有返回 ""
func best_demolish_tool() -> String:
	for id in ["pickaxe", "axe", "hammer"]:
		if melee_item == id or loot_count(id) > 0:
			return id
	return ""


func consume_ammo(amount := 1) -> bool:
	if test_mode or infinite_ammo:
		return true
	if total_ammo() < amount:
		return false
	for _cal in ammo_stock:
		for _t in ammo_stock[_cal]:
			while amount > 0 and int(ammo_stock[_cal][_t]) > 0:
				ammo_stock[_cal][_t] = int(ammo_stock[_cal][_t]) - 1
				amount -= 1
	resources_changed.emit()
	return true


func _update_survival(delta: float) -> void:
	drain_satiety(SATIETY_DRAIN * satiety_drain_mult() * delta)
	if satiety <= 0.0:
		_starve_timer += delta
		if _starve_timer >= STARVE_INTERVAL:
			_starve_timer -= STARVE_INTERVAL
			damage_player(STARVE_DAMAGE)
	else:
		_starve_timer = 0.0
	_update_auto_use(delta)


# 自动用药阈值（0 = 关闭；否则低于该比例时自动使用），由血条上的游标设置；
# 进食为全自动：饱食低于阈值自动吃，无需手动操作
var auto_heal_ratio := 0.0
const AUTO_EAT_RATIO := 0.4
var _auto_use_timer := 0.0
var _auto_warn_timer := 0.0


func _update_auto_use(delta: float) -> void:
	_auto_use_timer -= delta
	_auto_warn_timer = maxf(0.0, _auto_warn_timer - delta)
	if _auto_use_timer > 0.0:
		return
	_auto_use_timer = 0.5
	if auto_heal_ratio > 0.0 and hp < max_hp() * auto_heal_ratio:
		var has_meds := int(resources.get("meds", 0)) > 0 or (
			player_in_base_radius() and int(home_base.get("storage", {}).get("meds", 0)) > 0
		)
		if has_meds or anomaly >= ANOMALY_HEAL_COST:
			use_medkit()
		elif _auto_warn_timer <= 0.0:
			_auto_warn_timer = 10.0
			notify("生命值过低，背包没有医疗包")
	# 自动进食：饱食低于 40% 自动吃 1 份（背包没有且不在营地仓库范围内时提醒）
	if satiety < MAX_SATIETY * AUTO_EAT_RATIO:
		var has_food := int(resources.get("food", 0)) > 0 or (
			player_in_base_radius() and int(home_base.get("storage", {}).get("food", 0)) > 0
		)
		if has_food:
			eat_food()
		elif _auto_warn_timer <= 0.0:
			_auto_warn_timer = 10.0
			notify("饱食度过低，背包没有食物")


func has_stamina() -> bool:
	return stamina > 1.0


func use_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	stamina_changed.emit(stamina)


func regen_stamina(amount: float) -> void:
	stamina = minf(max_stamina(), stamina + amount)
	stamina_changed.emit(stamina)


func drain_satiety(amount: float) -> void:
	satiety = maxf(0.0, satiety - amount)
	satiety_changed.emit(satiety)


func eat_food() -> bool:
	if resources.get("food", 0) <= 0:
		# 营地范围内直接吃仓库库存（无需取出）
		if player_in_base_radius() and int(home_base.get("storage", {}).get("food", 0)) > 0:
			var storage: Dictionary = home_base["storage"]
			storage["food"] = int(storage.get("food", 0)) - 1
			home_base_changed.emit()
			satiety = minf(MAX_SATIETY, satiety + 40.0)
			satiety_changed.emit(satiety)
			notify("吃了 1 份仓库食物，饱食度 +40")
			return true
		notify("没有食物可以吃（食品店可以购买或抢夺）")
		return false
	resources["food"] -= 1
	resources_changed.emit()
	satiety = minf(MAX_SATIETY, satiety + 40.0)
	satiety_changed.emit(satiety)
	notify("吃了 1 份食物，饱食度 +40")
	return true


func use_medkit() -> bool:
	if hp >= max_hp():
		notify("生命值已满，不需要医疗包")
		return false
	if int(resources.get("meds", 0)) <= 0:
		# 营地范围内直接用仓库医疗包（无需取出）
		if player_in_base_radius() and int(home_base.get("storage", {}).get("meds", 0)) > 0:
			var storage: Dictionary = home_base["storage"]
			storage["meds"] = int(storage.get("meds", 0)) - 1
			home_base_changed.emit()
			hp = mini(hp + medkit_heal(), max_hp())
			hp_changed.emit(hp)
			notify("使用仓库医疗包，生命 +%d" % medkit_heal())
			return true
		return use_anomaly_heal()
	resources["meds"] -= 1
	resources_changed.emit()
	hp = mini(hp + medkit_heal(), max_hp())
	hp_changed.emit(hp)
	if has_mutation("field_aid"):
		regen_stamina(max_stamina() * mut_value("field_aid") / 100.0)
	if has_mutation("serum"):
		_serum_until = Time.get_ticks_msec() + 8000
		_serum_rate = mut_value("serum") / 8.0
	notify("使用医疗包，生命 +%d" % medkit_heal())
	return true


func take_vault_key() -> void:
	if vault_key:
		return
	vault_key = true
	notify("从武装警卫身上拿到了金库钥匙")


func _update_mutations_regen(delta: float) -> void:
	var rate := 0.0
	if has_mutation("self_heal") and Time.get_ticks_msec() - _last_damage_msec > 5000:
		rate += mut_value("self_heal")
	if (
		has_mutation("regeneration")
		and hp < int(max_hp() * mut_value("regeneration", 0) / 100.0)
	):
		rate += mut_value("regeneration", 1)
	if has_mutation("combat_regen") and Time.get_ticks_msec() < _combat_regen_until:
		rate += _combat_regen_rate
	if is_zombie() and has_mutation("z_regen"):
		rate += mut_value("z_regen")
	if has_mutation("serum") and Time.get_ticks_msec() < _serum_until:
		rate += _serum_rate
	rate += echo_regen()
	if rate > 0.0 and hp > 0 and hp < max_hp():
		_heal_accum += rate * delta
		if _heal_accum >= 1.0:
			var gain := int(_heal_accum)
			_heal_accum -= float(gain)
			heal_player(gain)
	if has_mutation("nap"):
		_nap_timer += delta
		if _nap_timer >= 60.0:
			_nap_timer -= 60.0
			heal_player(int(mut_value("nap", 1)))
			regen_stamina(mut_value("nap", 0))


func damage_player(amount: int) -> void:
	if test_mode and not training_ground:
		return
	_last_damage_msec = Time.get_ticks_msec()
	var reduction := mut_value("tough_skin") / 100.0
	if is_zombie():
		reduction += mut_value("z_hide") / 100.0
	reduction += armor_resist_value
	reduction += rogue_rank("armor") * 0.08
	if reduction > 0.0:
		amount = maxi(1, int(round(float(amount) * (1.0 - reduction))))
	if has_mutation("dodge") and randf() < dodge_chance():
		notify("闪避！")
		return
	hp = maxi(0, hp - amount)
	# 训练场：锁定 1 滴血不死
	if training_ground and hp < 1:
		hp = 1
	hp_changed.emit(hp)
	if hp <= 0 and not training_ground:
		player_died.emit()


func heal_full() -> void:
	hp = max_hp()
	hp_changed.emit(hp)


func set_wanted(_level: int) -> void:
	# 通缉系统已彻底删除：通缉值永不变化（恒为 0）
	return


func _sync_wanted_to_network() -> void:
	if (
		Network.is_multiplayer()
		and not Network.is_server()
		and Network.is_connected_peer()
	):
		Network.net_request_wanted.rpc_id(1)


func camera_watching(pos: Vector3) -> bool:
	for camera in get_tree().get_nodes_in_group("surveillance_cameras"):
		if camera.is_watching(pos):
			return true
	return false


# 击杀丧尸积累异能量：+1/只（尸神另算），满 15 解锁应急治疗提示
# 完美闪避触发（丧尸前摇结算时被冲刺闪过 → 由 zombie3d 调用）；CD 从缓速退出后才起计
func trigger_slowmo() -> void:
	var now := Time.get_ticks_msec()
	if now < _slowmo_cd_until or slowmo_active:
		return
	_slowmo_until = now + SLOWMO_MSEC
	slowmo_active = true
	Engine.time_scale = 0.1
	slowmo_changed.emit(true)


# 缓速剩余比例（1 → 0），供秒表 UI 指针
func slowmo_progress() -> float:
	if not slowmo_active:
		return 0.0
	return clampf(float(_slowmo_until - Time.get_ticks_msec()) / float(SLOWMO_MSEC), 0.0, 1.0)


func slowmo_cd_left() -> float:
	return maxf(0.0, float(_slowmo_cd_until - Time.get_ticks_msec()) / 1000.0)


# 武器技能冷却：就绪/剩余/消耗
func skill_ready(id: String) -> bool:
	if no_skill_cd:
		return true
	return Time.get_ticks_msec() >= int(_skill_cd_until.get(id, 0))


func skill_cd_left(id: String) -> float:
	return maxf(0.0, float(int(_skill_cd_until.get(id, 0)) - Time.get_ticks_msec()) / 1000.0)


func use_skill(id: String) -> bool:
	if not skill_ready(id):
		notify("技能冷却中（%.0f 秒）" % skill_cd_left(id))
		return false
	if no_skill_cd:
		return true
	_skill_cd_until[id] = Time.get_ticks_msec() + int(SKILL_CD.get(id, 15.0) * 1000.0)
	return true


# 狼蛛毒素：持续 seconds 秒（重复命中刷新为更长者）
func apply_poison(seconds: float) -> void:
	if seconds > poison_timer:
		poison_total = seconds
	poison_timer = maxf(poison_timer, seconds)


# 中毒剩余比例（1 → 0），供中毒图标倒计时
func poison_progress() -> float:
	if poison_timer <= 0.0 or poison_total <= 0.0:
		return 0.0
	return clampf(poison_timer / poison_total, 0.0, 1.0)


# 设施可负担检查：建材（仓库+周边）+ 附加资源（制造材料）
func defense_affordable(type: String) -> bool:
	if test_mode:
		return true
	if not BASE_DEFENSES.has(type):
		return false
	var info: Dictionary = BASE_DEFENSES[type]
	if base_materials_available() < int(info.get("cost", 0)):
		return false
	if loot_count("craft_mat") < int(info.get("craft", 0)):
		return false
	return true


# 设施造价描述（含附加资源）
func defense_cost_text(type: String) -> String:
	var info: Dictionary = BASE_DEFENSES.get(type, {})
	var parts_text := "建材 ×%d" % int(info.get("cost", 0))
	if int(info.get("craft", 0)) > 0:
		parts_text += " + 制造材料 ×%d" % int(info["craft"])
	return parts_text


# 恢复药水持续回复：duration 秒内均匀回完 total 点生命
func start_hot_regen(total: int, duration: float) -> void:
	_hot_left = float(total)
	_hot_rate = float(total) / maxf(duration, 0.1)
	_hot_accum = 0.0


func note_zombie_slain() -> void:
	add_anomaly(1)
	rogue_add_xp(1)


# —— 肉鸽模式局内升级：击杀得经验，升级时三选一（HUD 顶条 1/2/3，超时自动选第一项）——
func rogue_rank(id: String) -> int:
	return int(rogue_ranks.get(id, 0)) if rogue_mode else 0


func rogue_xp_need() -> int:
	return 6 + rogue_level * 4


func rogue_add_xp(amount: int) -> void:
	if not rogue_mode or is_run_over():
		return
	rogue_xp += amount
	while rogue_xp >= rogue_xp_need():
		rogue_xp -= rogue_xp_need()
		rogue_level += 1
		_offer_rogue_upgrades()
	rogue_progress_changed.emit()


func _offer_rogue_upgrades() -> void:
	var available: Array = []
	for up in ROGUE_UPGRADES:
		if rogue_rank(String(up["id"])) < int(up["max"]):
			available.append(up)
	if available.is_empty():
		return
	available.shuffle()
	rogue_levelup_offered.emit(available.slice(0, mini(3, available.size())))


func rogue_pick(id: String) -> void:
	for up in ROGUE_UPGRADES:
		if String(up["id"]) == id and rogue_rank(id) < int(up["max"]):
			rogue_ranks[id] = rogue_rank(id) + 1
			if id == "vital":
				hp = max_hp()
				hp_changed.emit(hp)
			notify("升级：%s（%d 级）" % [String(up["name"]), rogue_rank(id)])
			break
	rogue_progress_changed.emit()


func rogue_magnet_mult() -> float:
	return 1.0 + rogue_rank("magnet") * 0.4


func rogue_reload_mult() -> float:
	return 1.0 - rogue_rank("reload") * 0.12


# 异能量获取统一入口（结晶拾取/击杀/尸神），带上限与里程碑提示
func add_anomaly(amount: int) -> void:
	if anomaly >= ANOMALY_MAX or amount <= 0:
		return
	anomaly = mini(ANOMALY_MAX, anomaly + amount)
	if anomaly == ANOMALY_HEAL_COST:
		notify("异能量达到 %d：没有医疗包时可按 H 应急治疗" % ANOMALY_HEAL_COST)
	elif anomaly == ANOMALY_MAX:
		notify("异能量已满（撤离/败北结算时 1:1 折算 SP）")


# 异能量应急治疗：没有医疗包时按 H 触发，消耗 15 点回 40% 生命
func use_anomaly_heal() -> bool:
	if anomaly < ANOMALY_HEAL_COST:
		notify("没有医疗包，异能量也不足 %d（击杀丧尸积累）" % ANOMALY_HEAL_COST)
		return false
	anomaly -= ANOMALY_HEAL_COST
	var gain := int(max_hp() * ANOMALY_HEAL_RATIO)
	hp = mini(hp + gain, max_hp())
	hp_changed.emit(hp)
	notify("异能量治疗：生命 +%d（剩余异能量 %d）" % [gain, anomaly])
	return true


# —— 燃料：升为单位，汽油桶 20 升/桶（背包按升携带），仓库按升储存 ——

# 冲刺技能：距离/消耗/附加效果按等级解锁，跨局保留（meta）
const DASH_LEVELS := [
	{"dist": 4.0, "cost": 25, "desc": "冲刺 4m"},
	{"dist": 5.0, "cost": 25, "desc": "冲刺 5m"},
	{"dist": 5.0, "cost": 20, "desc": "消耗 20 · 冲刺期间无敌"},
	{"dist": 5.0, "cost": 20, "desc": "冲刺后 2s 移速 +20%"},
	{"dist": 5.0, "cost": 15, "desc": "消耗 15 · 路径伤害 20 + 击退"},
	{"dist": 7.0, "cost": 15, "desc": "冲刺 7m · 冲刺后 3s 体力速回"},
]
const DASH_MAX_LEVEL := 5
var dash_level := 0


func dash_info() -> Dictionary:
	return DASH_LEVELS[clampi(dash_level, 0, DASH_MAX_LEVEL)]


func dash_upgrade_cost() -> int:
	return dash_level + 1 if dash_level < DASH_MAX_LEVEL else 0


func upgrade_dash() -> bool:
	var cost := dash_upgrade_cost()
	if cost <= 0:
		notify("冲刺已满级")
		return false
	if skill_points < cost:
		notify("技能点不足（需要 %d 点）" % cost)
		return false
	skill_points -= cost
	skill_points_changed.emit(skill_points)
	skills_changed.emit()
	dash_level += 1
	save_meta()
	notify("冲刺升级 Lv.%d：%s" % [dash_level, String(dash_info()["desc"])])
	return true


# 据点是否建有发电机
func base_has_generator() -> bool:
	if not has_home_base():
		return false
	for entry in home_base.get("defenses", []):
		if String(entry.get("type", "")) == "generator":
			return true
	return false


# 据点是否建有异能储存仓（安全存放异能结晶的前提）
func base_has_containment() -> bool:
	if not has_home_base():
		return false
	for entry in home_base.get("defenses", []):
		if String(entry.get("type", "")) == "containment":
			return true
	return false


# 防护：穿着防化服才能安全接触异能结晶
func has_hazmat() -> bool:
	return loot_count("hazmat") > 0


# 异能量泄漏爆发：无防护接触结晶的后果——周围市民感染尸变，玩家也有感染风险
func anomaly_burst(pos: Vector3) -> void:
	post_message("观测到局部异能量异常波动", Vector2(pos.x, pos.z) / WORLD_SCALE_3D, "anomaly", true)
	notify("异能量泄漏！周围的人和物正在异常化……")
	for npc in entities_in_group_in_radius(pos, "npcs", 10.0):
		if npc.is_queued_for_deletion() or bool(npc.get("_dying")):
			continue
		if npc.has_method("_infect"):
			npc.set_meta("anomaly_touched", true)
			npc._infect(1.0)
	if zombies_active() and randf() < 0.3:
		try_infect_player()


# 发电机运转中 = 有据点、有发电机、仓库有燃料
func generator_running() -> bool:
	if not base_has_generator():
		return false
	return int(home_base["storage"].get("fuel", 0)) > 0


# —— 城市电网：准备期与灾变后头两天有电，第 3 天发电站停运 ——

func grid_online() -> bool:
	if grid_repaired:
		return true
	if phase == "prepare":
		return true
	return day_number < GRID_FAILURE_DAY


# 发电厂修复（工业区发电厂门口操作）：建材 ×60 从据点仓库扣，全城供电恢复
func repair_power_plant() -> bool:
	if grid_repaired:
		notify("发电厂已经在运转")
		return false
	if grid_online():
		notify("电网仍在供电，等发电站停运后再来修复")
		return false
	if not spend_materials(POWER_PLANT_REPAIR_COST):
		return false
	grid_repaired = true
	post_message("紧急播报：发电厂恢复运转，城市供电重新上线！", Vector2.ZERO, "city", true)
	notify("发电厂修复完成：全城供电恢复（路灯/建筑/信号满负荷）")
	return true


# —— 据点电力：储备池；油机/太阳能/风力充入，炮塔/照明灯消耗，玩家回充 ——

func base_power() -> float:
	if not has_home_base():
		return 0.0
	return float(home_base.get("power", 0.0))


func base_power_cap() -> float:
	if not has_home_base():
		return 0.0
	var batteries := 0
	for entry in home_base.get("defenses", []):
		if String(entry.get("type", "")) == "battery":
			batteries += 1
	return BASE_POWER_CAP + batteries * BASE_POWER_PER_BATTERY


func _add_base_power(amount: float) -> void:
	if not has_home_base() or amount <= 0.0:
		return
	home_base["power"] = clampf(base_power() + amount, 0.0, base_power_cap())


# 从据点电力池取电（制造设备耗电用），返回实际取到的量
func drain_base_power(amount: float) -> float:
	if not has_home_base() or amount <= 0.0:
		return 0.0
	var got := minf(amount, base_power())
	home_base["power"] = base_power() - got
	return got


# 据点用电设备是否有电：电网在线时免费用市电，断电后吃据点储备
func base_devices_powered() -> bool:
	return grid_online() or base_power() > 0.0


func _count_defense(type: String) -> int:
	if not has_home_base():
		return 0
	var count := 0
	for entry in home_base.get("defenses", []):
		if String(entry.get("type", "")) == type:
			count += 1
	return count


# 电力节拍：发电设备充储备；断电时用电设备吃储备；半径内玩家从储备（或市电）回充
func _tick_generator(delta: float) -> void:
	if not has_home_base():
		_gen_burn = 0.0
		return
	# 充入：太阳能（白天）/ 风力（全天，雨天加倍）；有操作员的机组效率 +30%
	if _count_defense("solar") > 0 and not is_night():
		var solar_units := _count_defense("solar") + 0.3 * operated_defense_count("solar")
		_add_base_power(solar_units * SOLAR_POWER_RATE * day_brightness() * delta)
	if _count_defense("windmill") > 0:
		var wind_rate := WIND_POWER_RATE * (2.0 if is_raining() else 1.0)
		var wind_units := _count_defense("windmill") + 0.3 * operated_defense_count("windmill")
		_add_base_power(wind_units * wind_rate * delta)
	# 发电机：持续烧仓库燃料（1 升 / 60 秒），烧油期间 1 电力/秒（操作员 +30%）
	if base_has_generator():
		var storage: Dictionary = home_base["storage"]
		var fuel_left := int(storage.get("fuel", 0))
		if fuel_left <= 0:
			if not _gen_stall_notified:
				_gen_stall_notified = true
				notify("发电机燃料耗尽，停机了（往据点仓库存入燃料）")
		else:
			if _gen_stall_notified:
				_gen_stall_notified = false
				notify("发电机恢复运转")
			_add_base_power(GEN_POWER_RATE * (1.0 + 0.3 * operated_defense_count("generator")) * delta)
			_gen_burn += delta
			if _gen_burn >= GEN_FUEL_SECONDS:
				var liters := int(_gen_burn / GEN_FUEL_SECONDS)
				_gen_burn -= liters * GEN_FUEL_SECONDS
				storage["fuel"] = fuel_left - mini(liters, fuel_left)
				home_base_changed.emit()
	# 消耗：断电后炮塔/照明灯吃储备（照明灯只在夜间耗电；有驻守的灯不耗电）
	if not grid_online():
		var drain := _count_defense("turret") * TURRET_POWER_DRAIN * delta
		if is_night():
			var unmanned_lamps := _count_defense("lamp") - operated_defense_count("lamp")
			drain += maxi(0, unmanned_lamps) * LAMP_POWER_DRAIN * delta
		if drain > 0.0 and base_power() > 0.0:
			home_base["power"] = maxf(0.0, base_power() - drain)


# —— 能源标记：物品/设施用什么能源一目了然（可叠加多种）——

const ENERGY_TAGS := {
	"hazmat": ["异"],
	"anomaly_crystal": ["异"],
	"turret": ["电"],
	"lamp": ["电"],
	"station": ["电"],
	"battery": ["电"],
	"solar": ["电"],
	"windmill": ["电"],
	"containment": ["异"],
	"generator": ["燃料", "电"],
	"vehicle": ["燃料"],
}
# 预留栏位：以异能结晶为能源的特殊武器（待设计，先占位）
const ANOMALY_WEAPON_SLOTS := ["anomaly_blade", "anomaly_rifle", "anomaly_cannon"]


func energy_tag_text(id: String) -> String:
	var tags: Array = ENERGY_TAGS.get(id, [])
	if tags.is_empty():
		return ""
	return "［%s］" % "+".join(tags)


func use_clothes() -> void:
	wanted = 0
	crime_points = 0
	_crime_reports.clear()
	set_wanted(0)
	disguise_changed.emit()
	notify("换上干净衣服：换了张脸，身上的通缉全部作废")


func reception_strength() -> float:
	return signal_strength


func report_crime(severity := 1, witness: Node = null, is_kill := false) -> void:
	# 通缉系统已彻底删除（全模式不再产生通缉）
	return


func _update_crime_reports() -> void:
	var now := Time.get_ticks_msec()
	for i in range(_crime_reports.size() - 1, -1, -1):
		var report: Dictionary = _crime_reports[i]
		if now < int(report["due"]):
			continue
		_crime_reports.remove_at(i)
		var witness = report.get("witness", null)
		if bool(report.get("has_witness", false)) and not is_instance_valid(witness):
			notify("目击者已经死了，举报没能发出去")
			continue
		if not bool(report.get("identify", true)):
			police_alert(report.get("pos3", Vector3.ZERO), "听到枪声", true)
			continue
		crime_points += int(report["severity"])
		set_wanted(maxi(wanted, clampi(int(report["severity"]), 1, 3)))
		mark_seen()
		if bool(report.get("is_kill", false)):
			register_kill()
		notify("举报上传成功：通缉 %d 星（凶手已被指认）" % wanted)


func report_progress_for(witness) -> float:
	if witness == null or not is_instance_valid(witness):
		return 0.0
	var now := Time.get_ticks_msec()
	for report in _crime_reports:
		var entry_witness = report.get("witness", null)
		if entry_witness == null or not is_instance_valid(entry_witness):
			continue
		if entry_witness != witness:
			continue
		var start := int(report.get("start", report["due"]))
		var delay := maxi(1, int(report["due"]) - start)
		return clampf(float(now - start) / float(delay), 0.0, 1.0)
	return 0.0


func _signal_report_params() -> Dictionary:
	var s := clampf(signal_strength, 0.0, 0.66)
	var t := (0.66 - s) / 0.66
	var delay := lerpf(3.0, 40.0, pow(t, 1.3)) * randf_range(0.85, 1.2)
	var loss := 0.0
	if s < 0.5:
		loss = lerpf(0.0, 0.75, (0.5 - s) / 0.5)
	return {"delay": maxf(1.5, delay), "loss": loss}


func record_gunshot(pos: Vector3, radius := 40.0) -> void:
	_gunshot_alerts.append({"pos": pos, "time": Time.get_ticks_msec(), "radius": radius})
	while _gunshot_alerts.size() > 20:
		_gunshot_alerts.pop_front()
	gunshot_fired.emit(pos)


func police_alert(pos: Vector3, reason := "听到枪声", force := false) -> void:
	# 通缉系统已彻底删除（全模式不再触发警方警报）
	return


func _nearest_hearer(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_dist := radius
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.is_queued_for_deletion():
			continue
		var dist: float = _node_pos3(npc).distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best = npc
	return best


func report_gunshot(pos: Vector3, radius := 40.0) -> void:
	# 枪声是物理声响：无论有没有信号，附近 NPC 都能听到并做出反应
	record_gunshot(pos, radius)  # 丧尸听觉噪音（保留）
	# 通缉系统已彻底删除：不再触发警方报警
	return


func _queue_hearing_report(pos: Vector3, hearer: Node3D) -> void:
	# 通缉系统已彻底删除：不产生犯罪举报
	return


func recent_gunshot(pos: Vector3, radius := 80.0) -> Vector3:
	var alert := recent_gunshot_entry(pos, radius)
	return alert.get("pos", Vector3.ZERO)


func recent_gunshot_entry(pos: Vector3, radius := 80.0) -> Dictionary:
	var now := Time.get_ticks_msec()
	for i in range(_gunshot_alerts.size() - 1, -1, -1):
		var alert: Dictionary = _gunshot_alerts[i]
		if now - int(alert["time"]) > 15000:
			_gunshot_alerts.remove_at(i)
			continue
		var alert_pos: Vector3 = alert["pos"]
		var hear_radius := minf(float(alert.get("radius", radius)), radius)
		if alert_pos.distance_to(pos) <= hear_radius:
			return alert
	return {}


func report_kill(victim_pos: Vector3, witness: Node = null, full_severity := 2) -> void:
	# 通缉系统已彻底删除（全模式不再产生通缉）
	return


func report_crime_direct(severity: int, is_kill := false) -> void:
	# 通缉系统已彻底删除（全模式不再产生通缉）
	return


func register_kill() -> void:
	# 通缉系统已彻底删除：不产生坏人标记
	return


func is_outlaw() -> bool:
	# 通缉系统已彻底删除：永远无坏人标记
	return false


func is_zombie() -> bool:
	# 感染/尸变机制已删除：玩家永远是人类
	return false


func is_good_zombie() -> bool:
	# 好丧尸机制已删除
	return false


func is_bad_zombie() -> bool:
	# 坏丧尸机制已删除
	return false


func is_bad_human() -> bool:
	return not is_zombie() and (wanted > 0 or is_outlaw())


# 感染机制已删除：原"感染"入口改为直接扣生命值（感染伤害，数值待调）
func try_infect_player(chance := INFECTION_BITE_CHANCE) -> void:
	if randf() >= chance:
		return
	damage_player(INFECTION_DAMAGE)


# 感染机制已删除：不再有感染暴露值（保留签名避免调用点报错）
func add_infection_exposure(_amount: float) -> void:
	pass


func _remove_hazmat_item() -> void:
	for i in range(loot_items.size() - 1, -1, -1):
		if String(loot_items[i].get("id", "")) == "hazmat":
			loot_items.remove_at(i)
			break
	resources_changed.emit()


# 感染机制已删除：无感染可治疗（保留签名避免调用点报错）
func cure_infection() -> bool:
	return false


# 尸变机制已删除：玩家不再尸变成丧尸（保留签名避免调用点报错）
func transform_player_to_zombie() -> void:
	pass


# 坏丧尸机制已删除（保留签名避免调用点报错）
func become_bad_zombie() -> void:
	pass


# 丧尸救赎机制已删除（保留签名避免调用点报错）
func on_zombie_kill() -> void:
	pass


func human_threat_level() -> int:
	var level := 1
	level = maxi(level, wanted + 1)
	if player_kills >= 1:
		level = maxi(level, 5)
	if player_kills >= 3:
		level = maxi(level, 6)
	if player_kills >= 5:
		level = maxi(level, 7)
	var stage := zombie_stage_index() + 1
	level = maxi(level, 1 + stage / 2)
	if is_bad_zombie():
		level = maxi(level, 8)
	if player_kills >= 8:
		level = maxi(level, 9)
	if player_kills >= 12:
		level = maxi(level, 10)
	return clampi(level, 1, 10)


func human_tier_info(tier: int) -> Dictionary:
	if tier < 1 or tier > HUMAN_TIERS.size():
		return {}
	return HUMAN_TIERS[tier - 1]


func zombie_tier_info(tier: int) -> Dictionary:
	if tier < 1 or tier > ZOMBIE_TIERS.size():
		return {}
	return ZOMBIE_TIERS[tier - 1]


func pick_zombie_tier() -> int:
	var stage := world_stage_info()
	var low := clampi(int(stage.get("tier_min", 1)), 1, ZOMBIE_TIERS.size())
	var top := clampi(int(stage.get("tier_max", low)), low, ZOMBIE_TIERS.size())
	var tier := randi_range(low, top)
	# 混编比例（每 10 只普通丧尸：2 猎犬、3.5 狼蛛）
	if tier == 1:
		var roll := randf()
		if roll < 0.26:
			return 5
		if roll < 0.26 + 2.0 / 12.0:
			return 2
	return tier


func pick_boss_tier() -> int:
	var boss := int(world_stage_info().get("boss_tier", 0))
	return boss if boss > 0 else 7


func zombie_claw_mult() -> float:
	return 1.0 + mut_value("z_claws") / 100.0


func fine_amount() -> int:
	return wanted * FINE_PER_WANTED + crime_points * FINE_PER_CRIME


func jail_player(seconds := JAIL_SECONDS) -> void:
	if jail_active or is_outlaw() or test_mode:
		return
	jail_active = true
	jail_timer = seconds
	jailed.emit(true)
	notify("你被逮捕了：服刑 %d 秒" % int(seconds))


func release_from_jail() -> void:
	if not jail_active:
		return
	jail_active = false
	jail_timer = 0.0
	jailed.emit(false)
	set_wanted(0)
	crime_points = 0
	notify("刑满释放，通缉记录已清除")


func surrender_after_outbreak() -> void:
	if is_outlaw():
		notify("你已是通缉要犯，投降不被接受！")
		return
	var fine := fine_amount()
	money = maxi(0, money - fine)
	money_changed.emit(money)
	weapons = {"pistol": 0, "shotgun": 0, "rifle": 0}
	current_weapon = "melee"
	weapons_changed.emit()
	set_wanted(0)
	crime_points = 0
	post_message("你向警方投降：缴械并罚款 ¥%d" % fine, Vector2.ZERO, "crime", true)
	notify("投降：武器被缴，罚款 ¥%d" % fine)


func prison_center_3d() -> Vector3:
	for entry in BUILDING_LAYOUT:
		if String(entry["id"]) == "prison":
			var pos: Vector2 = entry["position"]
			return Vector3(pos.x * WORLD_SCALE_3D, 0.0, pos.y * WORLD_SCALE_3D)
	return Vector3.ZERO


func prison_cell_3d() -> Vector3:
	return prison_center_3d() + Vector3(-4.0, 0.3, -2.8)


func prison_barrier_3d() -> Vector3:
	return prison_center_3d() + Vector3(-4.0, 1.6, 0.0)


func mark_seen() -> void:
	_last_seen_msec = Time.get_ticks_msec()


func notify(text: String) -> void:
	notified.emit(text)


func noise_at(pos: Vector3, radius := 25.0) -> void:
	if test_mode:
		return
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if _node_pos3(zombie).distance_to(pos) <= radius:
			zombie.hear_noise(pos)


func enter_building(id: String) -> void:
	pending_building = id
	reset_coverage()
	get_tree().change_scene_to_file("res://scenes/interior.tscn")


func exit_building() -> void:
	pending_building = ""
	reset_coverage()
	get_tree().change_scene_to_file("res://scenes/city.tscn")
