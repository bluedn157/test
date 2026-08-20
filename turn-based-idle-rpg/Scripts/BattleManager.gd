class_name BattleManager
extends Node

## 화면(Main.gd)이 구독할 신호들
signal battle_message(text: String)
signal stats_updated
signal battle_won(gold_reward: int, crystal_reward: int)
signal battle_lost

## 행동 하나(공격/스킬/힐/도발/버프)가 실행될 때마다 emit된다.
## Main은 이 신호를 받아 애니메이션을 재생하게 될 것이다(추후 단계).
## data 필드: actor, target, action_type("attack"/"skill_damage"/"heal"/"taunt"/"buff"),
##            value(데미지 또는 회복량, 도발/버프는 0), is_actor_party, is_target_party
signal action_performed(data: Dictionary)

const ROUND_PAUSE := 0.1  # 라운드가 끝난 뒤 다음 라운드 시작까지 대기 시간(초)
const BATTLE_START_DELAY := 0.5  # 전투 시작(등장 메시지) 후 첫 행동까지 대기 시간(초)

## 행동 하나가 끝난 뒤 다음 행동으로 넘어가기 전 대기하는 시간(초).
## TODO(연출 단계): 이 자리를 "Main의 애니메이션 재생 완료 대기"로 교체할 예정.
## 지금은 순서가 하나씩 처리되는지 확인하기 위한 임시 지연이다.
const ACTION_ANIMATION_PLACEHOLDER_DELAY := 0.3

## ---- 힐러 자동 치유 발동 조건 (나중에 밸런스 조정하기 쉽도록 상수로 분리) ----
## 아군의 "입은 피해(빠진 HP)"가 치유량의 이 비율 이상이면 치유를 사용한다.
const HEAL_TRIGGER_DAMAGE_RATIO := 0.75
## 또는 아군의 "입은 피해(빠진 HP)"가 자신 maxHP의 이 비율 이상이면 치유를 사용한다.
const HEAL_TRIGGER_HP_RATIO := 0.5

var party: Array[Character] = []
var enemies: Array[Enemy] = []
var battle_active: bool = false

## 전투 루프를 식별하는 세대 번호. stop_battle() 직후 곧바로 start_battle()이 다시
## 불려도(예: 던전 전환) 이전 루프의 await가 재개됐을 때 자신이 이미 낡은 루프임을
## 알아채고 스스로 멈추도록 하기 위함. (await 기반 루프라 Timer.stop()처럼 즉시
## 멈출 수 없어서 필요함)
var _battle_run_id: int = 0


## 새 전투를 시작한다. party/enemies는 이미 setup() 끝난 상태여야 함.
## party는 1~4명(딜러/힐러/탱커/버퍼 중 해금된 인원), enemies는 1~3마리까지 지원.
func start_battle(p: Array[Character], enemy_list: Array[Enemy]) -> void:
	party = p
	enemies = enemy_list
	battle_active = true
	_battle_run_id += 1
	var run_id := _battle_run_id

	for m in party:
		for skill_id in m.skill_cooldowns.keys():
			m.skill_cooldowns[skill_id] = 0
		m.active_effects.clear()

	# 쿨다운/상태 효과를 지운 결과를 화면(버프/도발 아이콘 등)에 바로 반영한다.
	# 이걸 emit 안 하면 다음 행동이 벌어져서 stats_updated가 다시 불릴 때까지
	# 이전 전투에서 걸렸던 효과 아이콘이 화면에 그대로 남아있게 된다.
	stats_updated.emit()

	if enemies.size() == 1:
		battle_message.emit("%s 등장!" % enemies[0].character_name)
	else:
		battle_message.emit("%s %d마리 등장!" % [enemies[0].character_name, enemies.size()])

	_run_battle_loop(run_id)


func stop_battle() -> void:
	battle_active = false


## 전투가 끝날 때까지 "한 라운드 처리 -> 라운드 사이 대기"를 반복하는 비동기 루프.
## await로 진행되므로 start_battle()에서는 그냥 호출만 하고 기다리지 않는다.
func _run_battle_loop(run_id: int) -> void:
	# 등장 메시지가 뜨자마자 바로 행동이 시작되지 않도록 첫 라운드 전에 텀을 준다.
	await get_tree().create_timer(BATTLE_START_DELAY).timeout
	if not battle_active or run_id != _battle_run_id:
		return

	while battle_active and run_id == _battle_run_id:
		await _process_round(run_id)
		if not battle_active or run_id != _battle_run_id:
			return
		await get_tree().create_timer(ROUND_PAUSE).timeout


## 한 라운드 = 파티원 + 살아있는 몬스터들이 SPD 높은 순서대로 한 번씩 행동.
## 이제 행동을 한 명씩 순차적으로(await로 텀을 두고) 처리한다.
## 파티원은 항상 살아있는 몬스터 중 맨 앞(첫 번째)을 공격.
## 몬스터는 살아있는 파티원 중 무작위 한 명을 공격.
## (역할별 스킬/AI는 아직 없음. 딜러 외 역할도 지금은 기본 공격만 수행)
func _process_round(run_id: int) -> void:
	var combatants := _prepare_round_combatants()

	for combatant in combatants:
		if not battle_active or run_id != _battle_run_id:
			return

		if combatant.hp <= 0:
			continue

		if combatant in party:
			if await _process_party_action(combatant):
				return
		else:
			if await _process_enemy_action(combatant):
				return


## 한 라운드에서 실제로 행동할 살아있는 캐릭터들을 준비한다.
## 파티원의 스킬 쿨다운과 모든 전투원의 상태 효과를 먼저 틱한 뒤 SPD 순으로 정렬한다.
func _prepare_round_combatants() -> Array[Character]:
	var combatants: Array[Character] = []

	for m in party:
		if m.hp > 0:
			_tick_skill_cooldowns(m)
			m.tick_effects()
			combatants.append(m)

	# 상태 효과 시스템은 범용이라 이후 몬스터에게도 상태이상을 걸 수 있으므로 몬스터도 함께 틱한다.
	for e in enemies:
		if e.hp > 0:
			e.tick_effects()
			combatants.append(e)

	combatants.sort_custom(func(a, b): return a.spd > b.spd)
	return combatants


## 파티원의 행동을 결정하고 실행한다.
## 반환값 true = 전투가 끝났으므로 현재 라운드를 즉시 종료해야 함.
func _process_party_action(character: Character) -> bool:
	var ready_skill := _get_ready_skill(character)

	if ready_skill and ready_skill.skill_type == "heal":
		var heal_target := _find_heal_target(character, ready_skill)
		if heal_target:
			await _execute_heal(character, ready_skill, heal_target)
		else:
			await _process_party_basic_or_skill_attack(character, ready_skill)
	elif ready_skill and ready_skill.skill_type == "taunt":
		await _execute_taunt(character, ready_skill)
	elif ready_skill and ready_skill.skill_type == "buff":
		var buff_target := _find_buff_target(character, ready_skill)
		if buff_target:
			await _execute_buff(character, ready_skill, buff_target)
		else:
			await _process_party_basic_or_skill_attack(character, null)
	else:
		await _process_party_basic_or_skill_attack(character, ready_skill)

	if _all_enemies_dead():
		_end_battle_won()
		return true

	return false


## 파티원의 일반 공격 또는 공격 스킬을 실행한다.
func _process_party_basic_or_skill_attack(character: Character, ready_skill: SkillData) -> void:
	var target := _get_first_alive_enemy()
	if target == null:
		return

	if ready_skill:
		await _execute_skill(character, ready_skill, target)
	else:
		await _execute_attack(character, target)


## 몬스터의 행동을 실행한다.
## 반환값 true = 전투가 끝났으므로 현재 라운드를 즉시 종료해야 함.
func _process_enemy_action(enemy: Enemy) -> bool:
	var target := _get_random_alive_party_member()
	if target == null:
		_end_battle_lost()
		return true

	await _execute_attack(enemy, target)

	if _all_party_dead():
		_end_battle_lost()
		return true

	return false


## 행동 하나를 emit하고, 다음 행동으로 넘어가기 전 텀을 준다.
## 지금은 고정 delay지만, 연출 단계에서는 Main의 "애니메이션 끝났음" 신호를 기다리는 걸로 교체될 자리.
func _await_action_beat(actor: Character, target: Character, action_type: String, value: int) -> void:
	action_performed.emit({
		"actor": actor,
		"target": target,
		"action_type": action_type,
		"value": value,
		"is_actor_party": actor in party,
		"is_target_party": target in party,
	})
	await get_tree().create_timer(ACTION_ANIMATION_PLACEHOLDER_DELAY).timeout


func _execute_attack(attacker: Character, target: Character) -> void:
	var damage: int = max(1, _get_effective_atk(attacker) - target.def)
	target.hp = max(0, target.hp - damage)

	battle_message.emit("%s의 공격! %s에게 %d 데미지" % [attacker.character_name, target.character_name, damage])
	stats_updated.emit()
	await _await_action_beat(attacker, target, "attack", damage)


## 매 라운드 시작 시 파티원 전원의 스킬 쿨다운을 1씩 줄인다.
func _tick_skill_cooldowns(character: Character) -> void:
	for skill_id in character.skill_cooldowns.keys():
		if character.skill_cooldowns[skill_id] > 0:
			character.skill_cooldowns[skill_id] -= 1


## 사용 가능(체크박스 켜짐 + 쿨다운 끝 + MP 충분)한 스킬 중 첫 번째를 반환. 없으면 null.
## 힐 스킬은 추가로 "치유가 실제로 필요한 아군이 있는지"(_find_heal_target)까지 확인한다.
func _get_ready_skill(character: Character) -> SkillData:
	for skill in character.skills:
		if not character.skill_enabled.get(skill.skill_id, true):
			continue
		if character.skill_cooldowns.get(skill.skill_id, 0) > 0:
			continue
		if character.mp < skill.mp_cost:
			continue
		if skill.skill_type == "heal" and _find_heal_target(character, skill) == null:
			continue
		if skill.skill_type == "buff" and _find_buff_target(character, skill) == null:
			continue
		return skill
	return null

func _execute_skill(attacker: Character, skill: SkillData, target: Character) -> void:
	attacker.mp -= skill.mp_cost
	attacker.skill_cooldowns[skill.skill_id] = skill.cooldown + 1

	var power := GameManager.get_skill_power(attacker.character_role, skill.skill_id)
	var damage: int = max(1, int(_get_effective_atk(attacker) * power) - target.def)
	target.hp = max(0, target.hp - damage)

	battle_message.emit("%s의 %s! %s에게 %d 데미지" % [attacker.character_name, skill.skill_name, target.character_name, damage])
	stats_updated.emit()
	await _await_action_beat(attacker, target, "skill_damage", damage)

	
## 힐 스킬을 사용할 대상을 찾는다. 아래 두 조건 중 하나라도 만족하는 아군이 있으면 그중
## 가장 많이 다친(빠진 HP가 큰) 아군을 반환한다. 아무도 조건을 만족하지 않으면 null.
## - 입은 피해(빠진 HP) >= 이 스킬의 치유량 * HEAL_TRIGGER_DAMAGE_RATIO
## - 입은 피해(빠진 HP) >= 자신 maxHP * HEAL_TRIGGER_HP_RATIO
func _find_heal_target(caster: Character, skill: SkillData) -> Character:
	var power := GameManager.get_skill_power(caster.character_role, skill.skill_id)
	var base_heal_amount: int = int(_get_effective_atk(caster) * power)
	## 최대HP 비례 회복 비율(0이면 해당 업그레이드 미보유). 대상마다 max_hp가 달라
	## 실제 힐량도 달라지므로, 아래 루프 안에서 대상별로 다시 계산한다.
	var hp_percent := GameManager.get_skill_hp_percent(caster.character_role, skill.skill_id)

	var best_target: Character = null
	var best_missing_hp := -1
	for member in party:
		if member.hp <= 0:
			continue
		var missing_hp: int = member.max_hp - member.hp
		if missing_hp <= 0:
			continue
		var heal_amount: int = base_heal_amount + int(member.max_hp * hp_percent)

		var meets_damage_ratio := missing_hp >= heal_amount * HEAL_TRIGGER_DAMAGE_RATIO
		var meets_hp_ratio := missing_hp >= member.max_hp * HEAL_TRIGGER_HP_RATIO
		if meets_damage_ratio or meets_hp_ratio:
			if missing_hp > best_missing_hp:
				best_missing_hp = missing_hp
				best_target = member

	return best_target


## 힐 스킬 실행: 대상 아군의 HP를 회복시킨다(maxHP 초과 불가).
func _execute_heal(caster: Character, skill: SkillData, target: Character) -> void:
	caster.mp -= skill.mp_cost
	caster.skill_cooldowns[skill.skill_id] = skill.cooldown + 1

	var power := GameManager.get_skill_power(caster.character_role, skill.skill_id)
	var hp_percent := GameManager.get_skill_hp_percent(caster.character_role, skill.skill_id)
	var heal_amount: int = int(_get_effective_atk(caster) * power) + int(target.max_hp * hp_percent)
	target.hp = min(target.max_hp, target.hp + heal_amount)

	battle_message.emit("%s의 %s! %s의 HP를 %d 회복" % [caster.character_name, skill.skill_name, target.character_name, heal_amount])
	stats_updated.emit()
	await _await_action_beat(caster, target, "heal", heal_amount)

## 도발 스킬 실행: 자신에게 TAUNT 상태 효과를 건다(가중치 = 스킬 파워, 지속시간 = 공통 상수).
## 실제 타겟팅 반영은 _get_random_alive_party_member()의 가중치 계산에서 이뤄진다.
func _execute_taunt(caster: Character, skill: SkillData) -> void:
	caster.mp -= skill.mp_cost
	caster.skill_cooldowns[skill.skill_id] = skill.cooldown + 1

	var weight := GameManager.get_skill_power(caster.character_role, skill.skill_id)
	caster.apply_effect(GameManager.TAUNT_EFFECT_ID, GameManager.TAUNT_DURATION_TURNS, {"weight": weight})

	battle_message.emit("%s의 %s! %d턴 동안 적의 시선을 끈다" % [caster.character_name, skill.skill_name, GameManager.TAUNT_DURATION_TURNS])
	stats_updated.emit()
	await _await_action_beat(caster, caster, "taunt", 0)

## 버프를 걸 대상을 찾는다. 우선순위: 1) 딜러(아직 버프 안 걸려있어야 함) 2) 그 외에는
## 버프가 안 걸린 아군 중 공격력이 가장 높은 순. 걸 수 있는 대상이 없으면(전원 버프 중) null.
func _find_buff_target(caster: Character, skill: SkillData) -> Character:
	var candidates: Array[Character] = []
	for member in party:
		if member.hp <= 0:
			continue
		if member.has_effect(GameManager.BUFF_EFFECT_ID):
			continue
		candidates.append(member)
	if candidates.is_empty():
		return null

	for member in candidates:
		if member.character_role == "dealer":
			return member

	var best_target: Character = candidates[0]
	for member in candidates:
		if member.atk > best_target.atk:
			best_target = member
	return best_target


## 버프 스킬 실행: 대상 아군에게 공격력 증가 효과를 건다.
func _execute_buff(caster: Character, skill: SkillData, target: Character) -> void:
	caster.mp -= skill.mp_cost
	caster.skill_cooldowns[skill.skill_id] = skill.cooldown + 1

	var buff_percent := GameManager.get_skill_power(caster.character_role, skill.skill_id)
	target.apply_effect(GameManager.BUFF_EFFECT_ID, GameManager.BUFF_DURATION_TURNS, {"atk_multiplier": 1.0 + buff_percent})

	battle_message.emit("%s의 %s! %s의 공격력이 %d턴 동안 %d%% 증가" % [caster.character_name, skill.skill_name, target.character_name, GameManager.BUFF_DURATION_TURNS, int(buff_percent * 100)])
	stats_updated.emit()
	await _await_action_beat(caster, target, "buff", 0)


## 버프 효과가 걸려있으면 반영된 실제 공격력을, 없으면 기본 공격력을 반환한다.
func _get_effective_atk(character: Character) -> int:
	if character.has_effect(GameManager.BUFF_EFFECT_ID):
		var multiplier: float = character.get_effect_data(GameManager.BUFF_EFFECT_ID).get("atk_multiplier", 1.0)
		return int(character.atk * multiplier)
	return character.atk


func _get_first_alive_enemy() -> Enemy:
	for e in enemies:
		if e.hp > 0:
			return e
	return null


## 적이 공격할 아군을 가중치 기반으로 뽑는다.
## 도발 중인 아군은 TAUNT 상태 효과의 weight를, 나머지는 GameManager.TAUNT_BASE_WEIGHT(기본 1.0)를 가중치로 써서
## "가중치 / 전체 가중치 합" 확률로 뽑는다. 아무도 도발 중이 아니면 전원 가중치가 같아서 기존과 동일하게 완전 균등해진다.
func _get_random_alive_party_member() -> Character:
	var alive: Array[Character] = []
	var weights: Array[float] = []
	for m in party:
		if m.hp > 0:
			alive.append(m)
			var weight := GameManager.TAUNT_BASE_WEIGHT
			if m.has_effect(GameManager.TAUNT_EFFECT_ID):
				weight = float(m.get_effect_data(GameManager.TAUNT_EFFECT_ID).get("weight", GameManager.TAUNT_BASE_WEIGHT))
			weights.append(weight)
	if alive.is_empty():
		return null

	var total_weight := 0.0
	for w in weights:
		total_weight += w

	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in alive.size():
		cumulative += weights[i]
		if roll < cumulative:
			return alive[i]
	return alive[alive.size() - 1]  # 부동소수점 오차 대비 안전장치
func _all_enemies_dead() -> bool:
	for e in enemies:
		if e.hp > 0:
			return false
	return true


func _all_party_dead() -> bool:
	for m in party:
		if m.hp > 0:
			return false
	return true


func _end_battle_won() -> void:
	stop_battle()

	var total_gold := 0
	var total_crystal := 0
	for e in enemies:
		total_gold += e.gold_reward
		total_crystal += e.crystal_reward

	battle_message.emit("전투 승리!")
	battle_won.emit(total_gold, total_crystal)


func _end_battle_lost() -> void:
	stop_battle()
	battle_message.emit("패배했습니다...")
	battle_lost.emit()
