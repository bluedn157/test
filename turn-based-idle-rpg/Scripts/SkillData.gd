class_name SkillData
extends Resource

## 스킬 고유 id. GameManager의 CHARACTER_SKILL_INFO 키와 일치해야 함.
@export var skill_id: String = ""
@export var skill_name: String = ""
@export var description: String = ""

## 스킬 종류. "attack"(적에게 데미지, 기본값) / "heal"(아군 HP 회복).
@export var skill_type: String = "attack"

## 소모 MP.
@export var mp_cost: int = 0

## 재사용 대기 턴 수. 0이면 매 턴 사용 가능.
@export var cooldown: int = 0

## 데미지/힐 배율. 예: 1.5면 기본 공격력의 1.5배.
@export var power: float = 1.0
