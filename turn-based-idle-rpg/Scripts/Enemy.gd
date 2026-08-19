class_name Enemy
extends Character

var gold_reward: int = 10
var crystal_reward: int = 0
var is_boss: bool = false


## EnemyData 리소스(.tres) 하나를 받아서 이 몬스터의 스탯을 채운다.
## 몬스터 종류를 늘릴 땐 이 함수를 건드릴 필요 없이 .tres 파일만 새로 만들면 됨.
func setup_enemy(data: EnemyData) -> void:
	character_name = data.enemy_name
	character_role = "enemy"

	max_hp = data.max_hp
	hp = data.max_hp

	atk = data.atk
	def = data.def
	spd = data.spd

	gold_reward = data.gold_reward
	crystal_reward = data.crystal_reward
	is_boss = data.is_boss
