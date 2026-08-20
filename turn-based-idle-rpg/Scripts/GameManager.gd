extends Node

signal gold_changed
signal character_stat_upgraded(role: String, key: String, amount: int)
signal character_skill_learned(role: String, skill_id: String)
signal character_unlocked(role: String)
signal dungeon_changed
signal dungeon_unlocked(dungeon: int)
signal data_reset
## 몬스터 도감에 새 몬스터가 등록될 때(=처음 만났을 때) emit. MonsterPanel이 구독해서
## 다시 그리게 한다.
signal enemy_discovered(enemy_path: String)
## 게임 속도(현재 적용값 / 자동 최대 설정)가 바뀔 때 emit. SettingsPanel이 구독해서 다시 그린다.
signal battle_speed_changed

const SAVE_PATH := "user://save_data.cfg"
const AUTO_SAVE_INTERVAL := 1.0

## 던전 강화 배수의 "기준값". 업그레이드로 이 값 자체가 조정됨.
const STAT_MULTIPLIER_STEP_BASE := 2.0
const REWARD_MULTIPLIER_STEP_BASE := 3.0

## ---- 탱커 도발(taunt) 관련 상수 ----
## BattleManager(적 타겟팅)와 UpgradePanel(UI 확률 미리보기) 둘 다 이 값을 참조해서
## 로직과 화면 표시가 항상 일치하게 한다.
## 도발 지속 턴 수.
const TAUNT_DURATION_TURNS := 3
## Character.active_effects에 쓰이는 도발 효과 식별자.
const TAUNT_EFFECT_ID := "taunt"
## 도발하지 않은 파티원의 기본 가중치. 이 값 대비 도발 가중치가 클수록 잘 끌림.
const TAUNT_BASE_WEIGHT := 1.0

## ---- 버퍼 공격력 강화(buff) 관련 상수 ----
## Character.active_effects에 쓰이는 공격력 버프 효과 식별자.
const BUFF_EFFECT_ID := "atk_buff"
## 버프 지속 턴 수.
const BUFF_DURATION_TURNS := 3

## ---- 몬스터 로스터 (원래 Main.gd에 있었지만, 몬스터 도감(MonsterPanel)도 같은 데이터가
## 필요해서 Main과 MonsterPanel이 공용으로 참조하는 GameManager로 옮겼다) ----
const SLIME_PATH := "res://Resources/Enemies/slime.tres"
const BEE_PATH := "res://Resources/Enemies/bee.tres"
const GOBLIN_KING_BOSS_PATH := "res://Resources/Enemies/goblin_king_boss.tres"
const BALLER_BOSS_PATH := "res://Resources/Enemies/baller_boss.tres"

## 던전별로 등장하는 잡몹/보스 목록. 새 던전을 추가할 땐 여기에 한 줄만 추가하면 됨.
const DUNGEON_ENEMY_DATA := {
	1: {"mobs": [SLIME_PATH], "boss": GOBLIN_KING_BOSS_PATH},
	2: {"mobs": [SLIME_PATH, BEE_PATH], "boss": GOBLIN_KING_BOSS_PATH},
}

var gold: int = 0
var crystal: int = 0

## 실제로 Engine.time_scale에 적용되는 현재 게임 속도 배율 (1.0 ~ get_battle_speed_multiplier()).
var battle_speed_current: float = 1.0
## true면 "게임 속도" 공용 업그레이드를 살 때마다 battle_speed_current가 자동으로 최댓값(레벨 기준)으로
## 맞춰지고, 설정 화면에서 직접 조절할 수 없다. false면 업그레이드를 사도 현재 속도는 그대로 유지되고,
## 설정 화면 슬라이더로 1배~최댓값 사이에서 직접 조절할 수 있다.
var battle_speed_auto_max: bool = true

var _auto_save_timer: Timer

var current_dungeon: int = 1
var current_floor: int = 1

## 해금된 던전 중 가장 높은 번호. 던전 N의 보스를 깨면 N+1이 열림.
var max_unlocked_dungeon: int = 1

## 역할 목록 (탭/파티 슬롯 순서 기준). 새 역할을 추가할 땐 여기 + 아래 정보들만 채우면 됨.
const ROLES := ["dealer", "healer", "tanker", "buffer"]
const ROLE_LABELS := {
	"dealer": "딜러",
	"healer": "힐러",
	"tanker": "탱커",
	"buffer": "버퍼",
}

const ROLE_DATA_PATH := {
	"dealer": "res://Resources/Characters/dealer.tres",
	"healer": "res://Resources/Characters/healer.tres",
	"tanker": "res://Resources/Characters/tanker.tres",
	"buffer": "res://Resources/Characters/buffer.tres",
}

## 캐릭터 해금 여부. 딜러는 처음부터 해금된 상태로 시작.
var unlocked_characters: Dictionary = {
	"dealer": true,
	"healer": false,
	"tanker": false,
	"buffer": false,
}

## 몬스터 도감: 실제로 전투에서 만난(등장한) 몬스터의 EnemyData 리소스 경로 -> true.
## 아직 안 만난 몬스터는 이 딕셔너리에 없으므로 MonsterPanel에서 "미발견"으로 표시된다.
var discovered_enemies: Dictionary = {}

## 캐릭터 해금 비용 (골드). 딜러는 이미 해금돼 있으므로 값 없음. (수치는 임시값)
const UNLOCK_COST := {
	"healer": 150,
	"tanker": 250,
	"buffer": 350,
}

## 공용 업그레이드 레벨 (전투 후 회복 등, 전체 파티에 적용될 요소)
var common_upgrades: Dictionary = {
	"post_battle_heal_hp": 0,
	"post_battle_heal_mp": 0,
	"dungeon_stat_reduction": 0,
	"dungeon_reward_boost": 0,
	"battle_speed": 0,
}

## 공용 업그레이드 정보: 레벨당 증가량 / 기본 가격 / 가격 증가율 / 표시 이름
## (수치는 임시값이라 나중에 밸런스에 맞춰 조정하면 됨)
const COMMON_UPGRADE_INFO := {
	"post_battle_heal_hp": {"per_level": 5, "unit": "%", "base_cost": 20, "cost_growth": 1.2, "label": "전투 후 HP 회복"},
	"post_battle_heal_mp": {"per_level": 5, "unit": "%", "base_cost": 20, "cost_growth": 1.2, "label": "전투 후 MP 회복"},
	"dungeon_stat_reduction": {"per_level": 1, "unit": "%", "base_cost": 30, "cost_growth": 1.25, "label": "던전 몬스터 강화율 감소"},
	"dungeon_reward_boost": {"per_level": 1, "unit": "%", "base_cost": 30, "cost_growth": 1.25, "label": "던전 보상 배율 증가"},
	"battle_speed": {"per_level": 10, "unit": "%", "base_cost": 40, "cost_growth": 1.3, "label": "게임 속도", "max_level": 10},
}

## 역할별 스탯 업그레이드 레벨: {role: {key: level}}
var character_upgrades: Dictionary = {
	"dealer": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
	"healer": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
	"tanker": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
	"buffer": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
}

## 역할별 습득한 스킬 id 목록. (딜러 외 역할은 아직 스킬이 없어서 빈 배열)
## 역할별 습득한 스킬 상태. skill_id -> {"learned": bool, "level": int}
var character_skills: Dictionary = {
	"dealer": {},
	"healer": {},
	"tanker": {},
	"buffer": {},
}

## 역할별 배울 수 있는 스킬 정보. resource_path에서 SkillData를 로드하고, cost는 습득 비용(골드).
## power_per_level/upgrade_base_cost/upgrade_cost_growth는 습득 이후 데미지 배율 업그레이드에 쓰임.
## 새 스킬을 추가할 땐 여기에 한 줄만 추가하면 됨.
const CHARACTER_SKILL_INFO := {
	"dealer": [
		{
			"skill_id": "power_strike",
			"resource_path": "res://Resources/Skills/dealer_power_strike.tres",
			"cost": 100,
			"power_per_level": 0.1,
			"upgrade_base_cost": 60,
			"upgrade_cost_growth": 1.2,
		},
	],
		
	"healer": [
		{
			"skill_id": "heal",
			"resource_path": "res://Resources/Skills/healer_heal.tres",
			"cost": 100,
			"power_per_level": 0.1,
			"upgrade_base_cost": 60,
			"upgrade_cost_growth": 1.2,
			"power_name": "힐량", # 기본 강화 트랙 이름 추가
			"extra_upgrades": [
				{
					"track_id": "hp_percent",
					"per_level": 0.05,
					"base_cost": 80,
					"cost_growth": 1.25,
					"label": "강화",
					"name": "최대 HP 비례 회복",
				},
			],
		},
	],

	"tanker": [
		{
			"skill_id": "taunt",
			"resource_path": "res://Resources/Skills/tanker_taunt.tres",
			"cost": 100,
			"power_per_level": 0.3,
			"upgrade_base_cost": 60,
			"upgrade_cost_growth": 1.2,
		},
	],
	"buffer": [
		{
			"skill_id": "atk_buff",
			"resource_path": "res://Resources/Skills/buffer_atk_buff.tres",
			"cost": 100,
			"power_per_level": 0.03,
			"upgrade_base_cost": 60,
			"upgrade_cost_growth": 1.2,
		},
	],
}

## 역할별 스탯 업그레이드 정보 (수치는 임시값이라 나중에 밸런스에 맞춰 조정하면 됨).
## 딜러 외 역할은 아직 스킬/행동 로직이 없어서 수치만 다르게 잡아둔 상태.
const CHARACTER_UPGRADE_INFO := {
	"dealer": {
		"hp": {"per_level": 10, "unit": "", "base_cost": 15, "cost_growth": 1.15, "label": "HP"},
		"mp": {"per_level": 5, "unit": "", "base_cost": 15, "cost_growth": 1.15, "label": "MP"},
		"atk": {"per_level": 2, "unit": "", "base_cost": 25, "cost_growth": 1.18, "label": "ATK"},
		"def": {"per_level": 2, "unit": "", "base_cost": 20, "cost_growth": 1.18, "label": "DEF"},
		"spd": {"per_level": 1, "unit": "", "base_cost": 30, "cost_growth": 1.2, "label": "SPD"},
	},
	"healer": {
		"hp": {"per_level": 8, "unit": "", "base_cost": 15, "cost_growth": 1.15, "label": "HP"},
		"mp": {"per_level": 8, "unit": "", "base_cost": 20, "cost_growth": 1.16, "label": "MP"},
		"atk": {"per_level": 1, "unit": "", "base_cost": 20, "cost_growth": 1.18, "label": "ATK"},
		"def": {"per_level": 2, "unit": "", "base_cost": 20, "cost_growth": 1.18, "label": "DEF"},
		"spd": {"per_level": 1, "unit": "", "base_cost": 30, "cost_growth": 1.2, "label": "SPD"},
	},
	"tanker": {
		"hp": {"per_level": 15, "unit": "", "base_cost": 15, "cost_growth": 1.15, "label": "HP"},
		"mp": {"per_level": 3, "unit": "", "base_cost": 15, "cost_growth": 1.15, "label": "MP"},
		"atk": {"per_level": 1, "unit": "", "base_cost": 20, "cost_growth": 1.18, "label": "ATK"},
		"def": {"per_level": 3, "unit": "", "base_cost": 25, "cost_growth": 1.18, "label": "DEF"},
		"spd": {"per_level": 1, "unit": "", "base_cost": 30, "cost_growth": 1.2, "label": "SPD"},
	},
	"buffer": {
		"hp": {"per_level": 10, "unit": "", "base_cost": 15, "cost_growth": 1.15, "label": "HP"},
		"mp": {"per_level": 6, "unit": "", "base_cost": 18, "cost_growth": 1.16, "label": "MP"},
		"atk": {"per_level": 1, "unit": "", "base_cost": 20, "cost_growth": 1.18, "label": "ATK"},
		"def": {"per_level": 2, "unit": "", "base_cost": 20, "cost_growth": 1.18, "label": "DEF"},
		"spd": {"per_level": 1, "unit": "", "base_cost": 30, "cost_growth": 1.2, "label": "SPD"},
	},
}


func _ready() -> void:
	## When save file error
	#DirAccess.remove_absolute(SAVE_PATH)
	load_game()

	# 재화가 빠르게 변하는 Idle 게임이므로 재화 변경 함수에서 매번 저장하지 않는다.
	# 실제 시간 기준 1초마다 전체 세이브를 수행해 강제 종료 시 손실을 최소화한다.
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.one_shot = false
	_auto_save_timer.ignore_time_scale = true
	_auto_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_auto_save_timer.timeout.connect(save_game)
	add_child(_auto_save_timer)
	_auto_save_timer.start()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit()


func add_crystal(amount: int) -> void:
	crystal += amount


## 레벨에 따른 업그레이드 가격 (지수적으로 증가).
func _get_upgrade_cost(base_cost: int, growth: float, level: int) -> int:
	return int(round(base_cost * pow(growth, level)))


func get_common_upgrade_cost(key: String) -> int:
	var info: Dictionary = COMMON_UPGRADE_INFO[key]
	return _get_upgrade_cost(info["base_cost"], info["cost_growth"], common_upgrades[key])


## 해당 업그레이드가 최대 레벨(있는 경우)에 도달했는지 여부.
func is_common_upgrade_maxed(key: String) -> bool:
	var info: Dictionary = COMMON_UPGRADE_INFO[key]
	if not info.has("max_level"):
		return false
	return common_upgrades[key] >= int(info["max_level"])


## 공용 업그레이드 구매. 골드가 부족하거나 최대 레벨이면 false.
func purchase_common_upgrade(key: String) -> bool:
	if is_common_upgrade_maxed(key):
		return false
	var cost := get_common_upgrade_cost(key)
	if gold < cost:
		return false
	gold -= cost
	common_upgrades[key] += 1
	if key == "battle_speed":
		if battle_speed_auto_max:
			# 자동 최대 배속 설정이 켜져 있으면, 업그레이드로 최댓값이 오른 즉시 현재 속도도 그만큼 올린다.
			battle_speed_current = get_battle_speed_multiplier()
		_apply_battle_speed()
		battle_speed_changed.emit()
	gold_changed.emit()
	save_game()
	return true


func get_post_battle_heal_hp_percent() -> float:
	return common_upgrades["post_battle_heal_hp"] * COMMON_UPGRADE_INFO["post_battle_heal_hp"]["per_level"] / 100.0


func get_post_battle_heal_mp_percent() -> float:
	return common_upgrades["post_battle_heal_mp"] * COMMON_UPGRADE_INFO["post_battle_heal_mp"]["per_level"] / 100.0

## 업그레이드 반영된 던전 스탯 배수 기준값. 레벨당 5%씩 줄어듦(최소 0).
func get_dungeon_stat_multiplier_step() -> float:
	return get_dungeon_stat_multiplier_step_at(common_upgrades["dungeon_stat_reduction"])


## 업그레이드 반영된 던전 스탯 배수 기준값 (레벨 지정 버전). UI에서 "다음 레벨" 미리보기용.
func get_dungeon_stat_multiplier_step_at(level: int) -> float:
	var reduction_percent: float = level * COMMON_UPGRADE_INFO["dungeon_stat_reduction"]["per_level"]
	var factor: float = max(0.0, 1.0 - reduction_percent / 100.0)
	return STAT_MULTIPLIER_STEP_BASE * factor


## 업그레이드 반영된 던전 보상 배수 기준값. 레벨당 5%씩 늘어남.
func get_dungeon_reward_multiplier_step() -> float:
	return get_dungeon_reward_multiplier_step_at(common_upgrades["dungeon_reward_boost"])


## 업그레이드 반영된 던전 보상 배수 기준값 (레벨 지정 버전). UI에서 "다음 레벨" 미리보기용.
func get_dungeon_reward_multiplier_step_at(level: int) -> float:
	var boost_percent: float = level * COMMON_UPGRADE_INFO["dungeon_reward_boost"]["per_level"]
	var factor: float = 1.0 + boost_percent / 100.0
	return REWARD_MULTIPLIER_STEP_BASE * factor


## 업그레이드 반영된 게임(전투) 진행 배속. 레벨당 10%씩 빨라짐 (기본 1.0배).
func get_battle_speed_multiplier() -> float:
	return get_battle_speed_multiplier_at(common_upgrades["battle_speed"])


## 업그레이드 반영된 게임 배속 (레벨 지정 버전). UI에서 "다음 레벨" 미리보기용.
func get_battle_speed_multiplier_at(level: int) -> float:
	var boost_percent: float = level * COMMON_UPGRADE_INFO["battle_speed"]["per_level"]
	return 1.0 + boost_percent / 100.0


## 현재 battle_speed_current 값을 엔진 배속(Engine.time_scale)에 반영한다.
## 전투 딜레이(get_tree().create_timer)와 연출 Tween 모두 이 값을 따라 함께 빨라진다.
func _apply_battle_speed() -> void:
	Engine.time_scale = battle_speed_current


## 게임 속도를 직접 설정한다 (설정 화면의 슬라이더 등에서 호출). "자동 최대 배속" 체크가
## 켜져 있는 동안에는 직접 조절이 불가능하므로 무시하고 false를 반환한다.
func set_battle_speed(value: float) -> bool:
	if battle_speed_auto_max:
		return false
	battle_speed_current = clamp(value, 1.0, get_battle_speed_multiplier())
	_apply_battle_speed()
	battle_speed_changed.emit()
	save_game()
	return true


## "자동 최대 배속" 체크박스 토글. 켜면 즉시 현재 속도를 최댓값으로 맞추고 이후 직접 조절을 막는다.
## 끄면 현재 속도는 그대로 유지한 채 1배~최댓값 사이에서 직접 조절할 수 있게 된다.
func set_battle_speed_auto_max(enabled: bool) -> void:
	battle_speed_auto_max = enabled
	if enabled:
		battle_speed_current = get_battle_speed_multiplier()
		_apply_battle_speed()
	battle_speed_changed.emit()
	save_game()


## ---------------- 캐릭터 해금 ----------------

func is_character_unlocked(role: String) -> bool:
	return unlocked_characters.get(role, false)
	
## 현재 해금된 캐릭터 수. UpgradePanel에서 도발 적중률을 "현재 파티 기준"으로 미리 보여줄 때 사용.
func get_unlocked_character_count() -> int:
	var count := 0
	for role in ROLES:
		if is_character_unlocked(role):
			count += 1
	return count

## 도발 가중치(weight)와 파티 인원수(member_count, 도발한 본인 포함)를 받아
## "도발한 캐릭터가 적의 공격 대상으로 뽑힐 확률"(0~1)을 계산한다.
## 공식: weight / (weight + 나머지 인원수 * TAUNT_BASE_WEIGHT)
## 인원수와 무관하게 항상 같은 공식 하나로 계산되므로, 2명/3명/4명 파티 모두 자동으로 대응된다.
func get_taunt_hit_chance(weight: float, member_count: int) -> float:
	var others: int = max(0, member_count - 1)
	var total_weight: float = weight + others * TAUNT_BASE_WEIGHT
	if total_weight <= 0.0:
		return 0.0
	return weight / total_weight


func get_unlock_cost(role: String) -> int:
	return UNLOCK_COST.get(role, 0)


## 캐릭터 해금 구매. 이미 해금됐거나 골드가 부족하면 false.
func unlock_character(role: String) -> bool:
	if is_character_unlocked(role):
		return false
	var cost := get_unlock_cost(role)
	if gold < cost:
		return false
	gold -= cost
	unlocked_characters[role] = true
	gold_changed.emit()
	character_unlocked.emit(role)
	save_game()
	return true


## ---------------- 역할별 스탯 업그레이드 ----------------

func get_character_upgrade_cost(role: String, key: String) -> int:
	var info: Dictionary = CHARACTER_UPGRADE_INFO[role][key]
	return _get_upgrade_cost(info["base_cost"], info["cost_growth"], character_upgrades[role][key])


## 역할별 스탯 업그레이드 구매. 성공 시 character_stat_upgraded 신호로 즉시 반영할 증가량을 알려준다.
func purchase_character_upgrade(role: String, key: String) -> bool:
	var cost := get_character_upgrade_cost(role, key)
	if gold < cost:
		return false
	gold -= cost
	character_upgrades[role][key] += 1
	gold_changed.emit()
	character_stat_upgraded.emit(role, key, int(CHARACTER_UPGRADE_INFO[role][key]["per_level"]))
	save_game()
	return true


func get_character_base_data(role: String) -> CharacterData:
	return load(ROLE_DATA_PATH[role])


## 기초 스탯 하나를 이름으로 조회 (업그레이드 미포함, 순수 base 값).
func get_character_base_stat(role: String, key: String) -> int:
	var data := get_character_base_data(role)
	match key:
		"hp":
			return data.max_hp
		"mp":
			return data.max_mp
		"atk":
			return data.atk
		"def":
			return data.def
		"spd":
			return data.spd
	return 0

## base 스탯 + 지금까지 산 업그레이드가 전부 반영된 현재 스탯. 스킬 데미지 미리보기 등에 사용.
func get_character_current_stat(role: String, key: String) -> int:
	var base_value := get_character_base_stat(role, key)
	var level: int = character_upgrades[role][key]
	var per_level: int = int(CHARACTER_UPGRADE_INFO[role][key]["per_level"])
	return base_value + level * per_level

## 캐릭터의 base 스탯에 지금까지 산 해당 역할 업그레이드 전부를 더한다.
## 캐릭터를 새로 setup()한 직후, 세션당 한 번만 호출하면 됨(이후 구매분은 신호로 반영).
func apply_character_upgrades(role: String, character: Character) -> void:
	var info: Dictionary = CHARACTER_UPGRADE_INFO[role]
	var levels: Dictionary = character_upgrades[role]
	character.max_hp += levels["hp"] * info["hp"]["per_level"]
	character.hp = character.max_hp
	character.max_mp += levels["mp"] * info["mp"]["per_level"]
	character.mp = character.max_mp
	character.atk += levels["atk"] * info["atk"]["per_level"]
	character.def += levels["def"] * info["def"]["per_level"]
	character.spd += levels["spd"] * info["spd"]["per_level"]


## ---------------- 역할별 스킬 ----------------

func is_skill_learned(role: String, skill_id: String) -> bool:
	return character_skills[role].has(skill_id)


## track: "power"(기본, 기존 힐량/데미지/도발/버프 등 원래 있던 강화)나
## 스킬별로 추가된 트랙 id(예: 힐의 "hp_percent"). 해당 트랙을 산 적 없으면 0.
func get_skill_level(role: String, skill_id: String, track: String = "power") -> int:
	if not is_skill_learned(role, skill_id):
		return 0
	var levels = character_skills[role][skill_id]["level"]
	## 구버전 세이브 호환: level이 예전처럼 int 하나로 저장돼 있으면 그걸 power 트랙으로 취급.
	if levels is int:
		return levels if track == "power" else 0
	return levels.get(track, 0)


## 트랙 하나의 강화 정보(per_level/base_cost/cost_growth/label)를 반환.
## "power" 트랙은 skill_info에 원래 있던 필드들을 그대로 쓰고,
## 그 외 트랙은 skill_info["extra_upgrades"] 배열에서 track_id로 찾는다.
func _get_skill_track_info(skill_info: Dictionary, track: String) -> Dictionary:
	if track == "power":
		return {
			"per_level": skill_info["power_per_level"],
			"base_cost": skill_info["upgrade_base_cost"],
			"cost_growth": skill_info["upgrade_cost_growth"],
			"label": "강화",
			"name": skill_info.get("power_name", "기본 강화"), # 설정한 이름 사용
		}
	for extra in skill_info.get("extra_upgrades", []):
		if extra["track_id"] == track:
			return extra
	return {}


func get_skill_info(role: String, skill_id: String) -> Dictionary:
	for skill_info in CHARACTER_SKILL_INFO[role]:
		if skill_info["skill_id"] == skill_id:
			return skill_info
	return {}


func get_character_skill_cost(role: String, skill_id: String) -> int:
	return get_skill_info(role, skill_id).get("cost", 0)


## 스킬 습득. 성공 시 character_skill_learned 신호로 즉시 반영을 알려준다.
func learn_character_skill(role: String, skill_id: String) -> bool:
	if is_skill_learned(role, skill_id):
		return false
	var cost := get_character_skill_cost(role, skill_id)
	if gold < cost:
		return false
	gold -= cost
	character_skills[role][skill_id] = {"learned": true, "level": {"power": 0}}
	gold_changed.emit()
	character_skill_learned.emit(role, skill_id)
	save_game()
	return true


## 레벨에 따른 스킬 업그레이드 가격. track을 안 주면 기존 "power" 트랙(힐량/데미지 등) 기준.
func get_skill_upgrade_cost(role: String, skill_id: String, track: String = "power") -> int:
	var info := get_skill_info(role, skill_id)
	var track_info := _get_skill_track_info(info, track)
	var level := get_skill_level(role, skill_id, track)
	return _get_upgrade_cost(track_info["base_cost"], track_info["cost_growth"], level)


## 스킬 업그레이드 구매. track을 안 주면 기존 "power" 트랙. 습득 안 했거나 골드 부족하면 false.
func purchase_skill_upgrade(role: String, skill_id: String, track: String = "power") -> bool:
	if not is_skill_learned(role, skill_id):
		return false
	var cost := get_skill_upgrade_cost(role, skill_id, track)
	if gold < cost:
		return false
	gold -= cost

	var levels = character_skills[role][skill_id]["level"]
	if levels is int:  # 구버전 세이브 호환
		levels = {"power": levels}
	levels[track] = levels.get(track, 0) + 1
	character_skills[role][skill_id]["level"] = levels

	gold_changed.emit()
	character_skill_learned.emit(role, skill_id)
	save_game()
	return true


## 레벨업 반영된 실제 데미지 배율. 스킬을 안 배웠으면 base power를 그대로 반환.
func get_skill_power(role: String, skill_id: String) -> float:
	var info := get_skill_info(role, skill_id)
	if info.is_empty():
		return 1.0
	var skill: SkillData = load(info["resource_path"])
	var level := get_skill_level(role, skill_id)
	return skill.power + level * float(info["power_per_level"])


## "hp_percent" 트랙 레벨 반영된 실제 비율(0.05 = 5%). 해당 트랙이 없는 스킬(힐 외)은 0.0.
func get_skill_hp_percent(role: String, skill_id: String) -> float:
	var info := get_skill_info(role, skill_id)
	var track_info := _get_skill_track_info(info, "hp_percent")
	if track_info.is_empty():
		return 0.0
	var level := get_skill_level(role, skill_id, "hp_percent")
	return level * float(track_info["per_level"])


## 지금까지 배운 스킬들을 캐릭터에 실제로 등록한다.
## 캐릭터를 새로 setup()한 직후, 세션당 한 번만 호출하면 됨(이후 습득/업그레이드분은 신호로 반영).
func apply_character_skills(role: String, character: Character) -> void:
	for skill_info in CHARACTER_SKILL_INFO[role]:
		if character_skills[role].has(skill_info["skill_id"]):
			var skill: SkillData = load(skill_info["resource_path"])
			character.learn_skill(skill)

## ---------------- 던전 진행도 ----------------
## current_dungeon/current_floor는 Main.gd에서 전투 결과에 따라 직접 바꾸므로,
## 그쪽에서 바뀔 때마다 이 함수를 호출해서 저장한다.
func save_progress() -> void:
	save_game()


func is_dungeon_unlocked(dungeon: int) -> bool:
	return dungeon <= max_unlocked_dungeon


## 던전 N의 보스를 처치했을 때 호출. N+1 던전을 해금한다 (이미 해금돼 있으면 아무 일 없음).
func unlock_next_dungeon(cleared_dungeon: int) -> void:
	if cleared_dungeon + 1 > max_unlocked_dungeon:
		max_unlocked_dungeon = cleared_dungeon + 1
		save_game()
		dungeon_unlocked.emit(max_unlocked_dungeon)


## 던전 선택 화면에서 다른 던전으로 이동. 해금 안 됐거나 이미 그 던전이면 false.
## 어떤 던전으로 옮기든 항상 1F부터 시작한다 (진행도는 던전별로 따로 저장하지 않음).
func select_dungeon(dungeon: int) -> bool:
	if not is_dungeon_unlocked(dungeon):
		return false
	if dungeon == current_dungeon:
		return false
	current_dungeon = dungeon
	current_floor = 1
	save_game()
	dungeon_changed.emit()
	return true


## ---------------- 몬스터 스탯/보상 배수 (Main.gd 몬스터 생성 + MonsterPanel 도감 미리보기 공용) ----------------

## dungeon 번째 던전에 등장하는 몬스터의 스탯 배수. 1던전은 배수 없음(1.0).
func get_dungeon_enemy_stat_multiplier(dungeon: int) -> float:
	return max(1.0, float(dungeon - 1) * get_dungeon_stat_multiplier_step())


## dungeon 번째 던전에 등장하는 몬스터의 보상(골드/크리스탈) 배수. 1던전은 배수 없음(1.0).
func get_dungeon_enemy_reward_multiplier(dungeon: int) -> float:
	return max(1.0, float(dungeon - 1) * get_dungeon_reward_multiplier_step())


## ---------------- 몬스터 도감 ----------------

func is_enemy_discovered(enemy_path: String) -> bool:
	return discovered_enemies.has(enemy_path)


## 몬스터를 도감에 등록한다. Main.gd가 몬스터를 실제로 스폰(=전투 등장)시킬 때마다 호출.
## 이미 등록된 몬스터면 아무 일도 하지 않는다.
func discover_enemy(enemy_path: String) -> void:
	if discovered_enemies.has(enemy_path):
		return
	discovered_enemies[enemy_path] = true
	enemy_discovered.emit(enemy_path)
	save_game()


## 도감에 표시할 전체 몬스터 목록 (던전 순서대로, 중복 제거). 각 항목은 EnemyData 리소스 경로.
## 발견 여부와 무관하게 "앞으로 몇 종류가 더 있는지"를 보여주기 위해 전체 로스터를 반환한다.
func get_all_enemy_paths() -> Array[String]:
	var seen: Dictionary = {}
	var paths: Array[String] = []
	var dungeon_keys := DUNGEON_ENEMY_DATA.keys()
	dungeon_keys.sort()
	for dungeon in dungeon_keys:
		var dungeon_data: Dictionary = DUNGEON_ENEMY_DATA[dungeon]
		for mob_path in dungeon_data["mobs"]:
			if not seen.has(mob_path):
				seen[mob_path] = true
				paths.append(mob_path)
		var boss_path: String = dungeon_data["boss"]
		if not seen.has(boss_path):
			seen[boss_path] = true
			paths.append(boss_path)
	return paths


## ---------------- 저장 / 불러오기 / 초기화 ----------------
## 중요한 영구 상태 변경 직후에는 호출할 수 있고, 일반적인 재화 변화는 1초 주기 자동 저장으로 처리한다.

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "gold", gold)
	config.set_value("player", "crystal", crystal)
	config.set_value("player", "current_dungeon", current_dungeon)
	config.set_value("player", "current_floor", current_floor)
	config.set_value("player", "max_unlocked_dungeon", max_unlocked_dungeon)
	config.set_value("player", "battle_speed_current", battle_speed_current)
	config.set_value("player", "battle_speed_auto_max", battle_speed_auto_max)
	config.set_value("data", "unlocked_characters", unlocked_characters)
	config.set_value("data", "common_upgrades", common_upgrades)
	config.set_value("data", "character_upgrades", character_upgrades)
	config.set_value("data", "character_skills", character_skills)
	config.set_value("data", "discovered_enemies", discovered_enemies)
	config.save(SAVE_PATH)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	gold = config.get_value("player", "gold", gold)
	crystal = config.get_value("player", "crystal", crystal)
	current_dungeon = config.get_value("player", "current_dungeon", current_dungeon)
	current_floor = config.get_value("player", "current_floor", current_floor)
	max_unlocked_dungeon = config.get_value("player", "max_unlocked_dungeon", max_unlocked_dungeon)
	battle_speed_current = config.get_value("player", "battle_speed_current", battle_speed_current)
	battle_speed_auto_max = config.get_value("player", "battle_speed_auto_max", battle_speed_auto_max)
	unlocked_characters = config.get_value("data", "unlocked_characters", unlocked_characters)
	var loaded_common_upgrades: Dictionary = config.get_value("data", "common_upgrades", {})
	for key in loaded_common_upgrades.keys():
		common_upgrades[key] = loaded_common_upgrades[key]
	if battle_speed_auto_max:
		battle_speed_current = get_battle_speed_multiplier()
	else:
		battle_speed_current = clamp(battle_speed_current, 1.0, get_battle_speed_multiplier())
	var loaded_character_upgrades: Dictionary = config.get_value("data", "character_upgrades", {})
	for role in loaded_character_upgrades.keys():
		for key in loaded_character_upgrades[role].keys():
			character_upgrades[role][key] = loaded_character_upgrades[role][key]
	var loaded_character_skills: Dictionary = config.get_value("data", "character_skills", {})
	for role in loaded_character_skills.keys():
		character_skills[role] = loaded_character_skills[role]
	discovered_enemies = config.get_value("data", "discovered_enemies", discovered_enemies)
	_apply_battle_speed()


## 세이브 파일을 지우고 모든 진행 상황을 초기값으로 되돌린다. (설정 > 데이터 초기화)
## 호출한 쪽에서 get_tree().reload_current_scene()으로 화면 자체를 다시 그려줘야
## 파티/전투 등 런타임 상태까지 깨끗하게 리셋된다.
func reset_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	gold = 0
	crystal = 0
	current_dungeon = 1
	current_floor = 1
	max_unlocked_dungeon = 1
	battle_speed_current = 1.0
	battle_speed_auto_max = true
	unlocked_characters = {
		"dealer": true,
		"healer": false,
		"tanker": false,
		"buffer": false,
	}
	common_upgrades = {
		"post_battle_heal_hp": 0,
		"post_battle_heal_mp": 0,
		"dungeon_stat_reduction": 0,
		"dungeon_reward_boost": 0,
		"battle_speed": 0,
	}
	_apply_battle_speed()
	character_upgrades = {
		"dealer": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
		"healer": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
		"tanker": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
		"buffer": {"hp": 0, "mp": 0, "atk": 0, "def": 0, "spd": 0},
	}
	character_skills = {
		"dealer": {},
		"healer": {},
		"tanker": {},
		"buffer": {},
	}
	discovered_enemies = {}

	data_reset.emit()
	gold_changed.emit()
	battle_speed_changed.emit()
