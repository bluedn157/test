class_name Character_Buffer
extends Character

## 씬(Character_Scene_Buffer.tscn)의 Inspector에서 buffer.tres 리소스를 연결해두면
## _ready() 시점에 자동으로 스탯이 채워진다.
@export var data: CharacterData


func _ready() -> void:
	if data:
		setup(data)
