class_name Character
extends Node

@export var character_name: String = ""
@export var character_role: String = ""

@export var max_hp: int = 100
@export var hp: int = 100

@export var max_mp: int = 100
@export var mp: int = 100

@export var atk: int = 10
@export var def: int = 10
@export var spd: int = 10

## 습득한 스킬 목록.
var skills: Array[SkillData] = []
## skill_id -> 남은 쿨다운(턴). 전투 시작 시 BattleManager가 0으로 초기화함.
var skill_cooldowns: Dictionary = {}
## skill_id -> 자동전투에서 사용할지 여부. 기본값 true(습득하면 바로 사용).
var skill_enabled: Dictionary = {}

## ---- 범용 상태 효과(도발, 이후 추가될 상태이상/버프 등도 전부 이 딕셔너리 하나로 처리) ----
## effect_id -> {"remaining_turns": int, "data": Dictionary}
## data는 효과별로 필요한 부가 정보를 자유 형식으로 담는다(예: 도발이면 {"weight": 3.0}).
var active_effects: Dictionary = {}


## 상태 효과를 새로 걸거나(이미 있으면) 지속시간/데이터를 갱신한다.
func apply_effect(effect_id: String, duration_turns: int, data: Dictionary = {}) -> void:
	active_effects[effect_id] = {"remaining_turns": duration_turns, "data": data}


## 해당 상태 효과가 걸려 있는지 확인.
func has_effect(effect_id: String) -> bool:
	return active_effects.has(effect_id)


## 상태 효과의 부가 데이터를 가져온다. 걸려있지 않으면 빈 딕셔너리.
func get_effect_data(effect_id: String) -> Dictionary:
	if not active_effects.has(effect_id):
		return {}
	return active_effects[effect_id]["data"]


## 상태 효과를 즉시 제거한다.
func remove_effect(effect_id: String) -> void:
	active_effects.erase(effect_id)


## 매 라운드 시작 시 BattleManager가 호출: 모든 상태 효과의 남은 턴을 1씩 줄이고,
## 0이 되면 자동으로 제거한다.
func tick_effects() -> void:
	var expired: Array[String] = []
	for effect_id in active_effects.keys():
		active_effects[effect_id]["remaining_turns"] -= 1
		if active_effects[effect_id]["remaining_turns"] <= 0:
			expired.append(effect_id)
	for effect_id in expired:
		active_effects.erase(effect_id)

## 스킬을 배운 상태로 등록한다. 이미 등록된 스킬이면 아무 일도 하지 않는다.
func learn_skill(skill: SkillData) -> void:
	if skill_enabled.has(skill.skill_id):
		return
	skills.append(skill)
	skill_cooldowns[skill.skill_id] = 0
	skill_enabled[skill.skill_id] = true


## CharacterData 리소스(.tres)를 받아서 기초 스탯을 채운다.
## 새 역할(예: 5번째 캐릭터)을 추가할 땐 이 함수를 안 건드려도 됨.
func setup(data: CharacterData) -> void:
	character_name = data.character_name
	character_role = data.character_role

	max_hp = data.max_hp
	hp = data.max_hp

	max_mp = data.max_mp
	mp = data.max_mp

	atk = data.atk
	def = data.def
	spd = data.spd
