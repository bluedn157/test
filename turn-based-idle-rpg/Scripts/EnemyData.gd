class_name EnemyData
extends Resource

@export var enemy_name: String = ""

@export_group("Stats")
@export var max_hp: int = 100
@export var atk: int = 10
@export var def: int = 10
@export var spd: int = 10

@export_group("Reward")
@export var gold_reward: int = 10
@export var crystal_reward: int = 0
@export var is_boss: bool = false
