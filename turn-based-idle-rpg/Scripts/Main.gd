extends Control

## 메뉴 제목 라벨("Menu")
@onready var menu_title_label: Label = $HBoxContainer/MenuPanel/VBoxContainer/Label

## 메뉴 버튼들
@onready var upgrade_button: Button = $HBoxContainer/MenuPanel/VBoxContainer/UpgradeButton
@onready var monster_button: Button = $HBoxContainer/MenuPanel/VBoxContainer/MonsterButton
@onready var dungeon_button: Button = $HBoxContainer/MenuPanel/VBoxContainer/DungeonButton
@onready var settings_button: Button = $HBoxContainer/MenuPanel/VBoxContainer/SettingsButton

## 버튼과 짝지어질 내용 패널들 (같은 순서로 배열에 담을 것)
@onready var upgrade_panel: Control = $HBoxContainer/MenuPanel/VBoxContainer/ContentArea/UpgradePanel
@onready var monster_panel: Control = $HBoxContainer/MenuPanel/VBoxContainer/ContentArea/MonsterPanel
@onready var dungeon_panel: Control = $HBoxContainer/MenuPanel/VBoxContainer/ContentArea/DungeonPanel
@onready var settings_panel: Control = $HBoxContainer/MenuPanel/VBoxContainer/ContentArea/SettingsPanel

## 파티원 영역 및 슬롯 4개
@onready var player_area: BoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/PlayerArea
@onready var player_unit_1: VBoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/PlayerArea/PlayerUnit1
@onready var player_unit_2: VBoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/PlayerArea/PlayerUnit2
@onready var player_unit_3: VBoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/PlayerArea/PlayerUnit3
@onready var player_unit_4: VBoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/PlayerArea/PlayerUnit4

## 던전 정보 / 골드 / 크리스탈 / 전투 메시지
@onready var dungeon_info_label: Label = $"HBoxContainer/BattlePanel/VBoxContainer/Label (Dungeon Info)"
@onready var gold_label: Label = $HBoxContainer/BattlePanel/VBoxContainer/GoldLabel
@onready var crystal_label: Label = $HBoxContainer/BattlePanel/VBoxContainer/CrystalLabel
@onready var battle_message_label: Label = $HBoxContainer/BattlePanel/VBoxContainer/BattleMessage

## 몬스터 영역 및 슬롯 3개
@onready var enemy_area: BoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/EnemyArea
@onready var enemy_unit_1: VBoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/EnemyArea/EnemyUnit1
@onready var enemy_unit_2: VBoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/EnemyArea/EnemyUnit2
@onready var enemy_unit_3: VBoxContainer = $HBoxContainer/BattlePanel/VBoxContainer/EnemyArea/EnemyUnit3

## 역할(role) 문자열 -> 해당 역할의 Character 서브클래스
var ROLE_CLASS := {
	"dealer": Character_Dealer,
	"healer": Character_Healer,
	"tanker": Character_Tanker,
	"buffer": Character_Buffer,
}

## 아직 정식 캐릭터/몬스터 그림이 없어서 구분용 임시 아이콘(역할/종류별 색이 다른 원)을 사용한다.
## 나중에 진짜 아트가 들어오면 이 경로들만 교체하면 된다.
const ROLE_PORTRAIT_PATHS := {
	"dealer": "res://Assets/Portraits/dealer.png",
	"healer": "res://Assets/Portraits/healer.png",
	"tanker": "res://Assets/Portraits/tanker.png",
	"buffer": "res://Assets/Portraits/buffer.png",
}
## 몬스터는 enemy_name(EnemyData.enemy_name)으로 구분한다.
const ENEMY_PORTRAIT_PATHS := {
	"Slime": "res://Assets/Portraits/slime.png",
	"Bee": "res://Assets/Portraits/bee.png",
	"Goblin King": "res://Assets/Portraits/goblin_king_boss.png",
	"Baller": "res://Assets/Portraits/baller_boss.png",
}

## 상태 효과(버프/도발/추후 디버프 등) 아이콘. GameManager의 XXX_EFFECT_ID와 매칭되는 것만
## 전용 아이콘을 쓰고, 매핑에 없는(=아직 없는 디버프 등 미래에 추가될) effect_id는
## STATUS_EFFECT_GENERIC_ICON_PATH로 대체 표시한다.
const STATUS_EFFECT_ICON_PATHS := {
	"atk_buff": "res://Assets/StatusIcons/buff.png",
	"taunt": "res://Assets/StatusIcons/taunt.png",
}
const STATUS_EFFECT_GENERIC_ICON_PATH := "res://Assets/StatusIcons/generic.png"
## 상태 효과 아이콘에 마우스를 올렸을 때 보여줄 이름(매핑에 없으면 effect_id를 그대로 보여줌).
const STATUS_EFFECT_DISPLAY_NAMES := {
	"atk_buff": "공격력 버프",
	"taunt": "도발",
}

const BOSS_FLOOR := 31       # 30F까지 잡몹, 31F에서 보스
const RESPAWN_DELAY := 0.3   # 다음 몬스터/층 등장까지 대기 시간(초)

var battle_manager: BattleManager

var menu_buttons: Array[Button]
var menu_panels: Array[Control]

var enemy_units: Array   # [{container, name_label, hp_bar, hp_label}, ...]
var player_units: Array  # [{container, name_label, hp_bar, hp_label, mp_bar, mp_label}, ...]

var party: Array[Character] = []
var enemies: Array[Enemy] = []

## 타격/힐 이펙트를 화면 맨 위에 그리기 위한 전용 레이어. 유닛 컨테이너는
## BoxContainer 자식이라 그 안에 직접 이펙트를 넣으면 레이아웃이 흐트러지므로,
## 좌표만 계산해서 이 레이어 위에 별도로 띄운다.
var effect_layer: Control


func _ready() -> void:
	theme = UITheme.build_app_theme()  # 게임 전체 공용 다크 테마. 자식 전체에 자동 적용됨.
	_setup_container_alignment()

	menu_buttons = [upgrade_button, monster_button, dungeon_button, settings_button]
	menu_panels = [upgrade_panel, monster_panel, dungeon_panel, settings_panel]

	for i in menu_buttons.size():
		menu_buttons[i].toggle_mode = true  # 선택된 탭이 눌린 상태(강조 테두리)로 보이게
		menu_buttons[i].pressed.connect(_on_menu_button_pressed.bind(i))

	_show_panel(0)  # 기본으로 업그레이드 탭 보여줌

	_setup_enemy_unit_refs()
	_setup_player_unit_refs()
	_setup_effect_layer()
	_style_top_labels()
	_rebuild_party()
	_setup_battle_manager()

	GameManager.character_stat_upgraded.connect(_on_character_stat_upgraded)
	GameManager.character_skill_learned.connect(_on_character_skill_learned)
	GameManager.character_unlocked.connect(_on_character_unlocked)
	GameManager.dungeon_changed.connect(_on_dungeon_changed)
	GameManager.gold_changed.connect(_refresh_currency_labels)

	_refresh_currency_labels()
	_start_current_floor()


## 화면 전체를 덮는 빈 레이어를 만들어 맨 마지막 자식으로 추가한다(=항상 맨 위에 그려짐).
## 마우스 입력은 무시해서 아래 UI 클릭을 막지 않게 한다.
func _setup_effect_layer() -> void:
	effect_layer = Control.new()
	effect_layer.name = "EffectLayer"
	effect_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect_layer)


## 몬스터 및 파티원 컨테이너 영역을 중앙 정렬하도록 설정하는 함수
func _setup_container_alignment() -> void:
	if enemy_area is BoxContainer:
		enemy_area.alignment = BoxContainer.ALIGNMENT_CENTER
	if player_area is BoxContainer:
		player_area.alignment = BoxContainer.ALIGNMENT_CENTER


func _on_menu_button_pressed(index: int) -> void:
	_show_panel(index)


func _show_panel(index: int) -> void:
	for i in menu_panels.size():
		menu_panels[i].visible = (i == index)
	for i in menu_buttons.size():
		menu_buttons[i].button_pressed = (i == index)


## 던전 정보/골드/크리스탈/전투 메시지 라벨에 공용 테마 색을 입힌다.
func _style_top_labels() -> void:
	UITheme.apply_title_style(menu_title_label, 16)
	UITheme.apply_accent_font_color(dungeon_info_label)
	gold_label.add_theme_color_override("font_color", UITheme.NEXT_STAT_COLOR)
	crystal_label.add_theme_color_override("font_color", UITheme.MP_BAR_COLOR)
	battle_message_label.add_theme_color_override("font_color", UITheme.TEXT_COLOR)


func _setup_enemy_unit_refs() -> void:
	enemy_units = [
		{
			"container": enemy_unit_1,
			"portrait_frame": enemy_unit_1.get_node("Portrait"),
			"portrait": enemy_unit_1.get_node("Portrait/PortraitTexture"),
			"status_row": enemy_unit_1.get_node("StatusRow"),
			"name_label": enemy_unit_1.get_node("EnemyInfo/EnemyName"),
			"hp_bar": enemy_unit_1.get_node("EnemyInfo/HPRow/HPBar"),
			"hp_label": enemy_unit_1.get_node("EnemyInfo/HPRow/EnemyHP"),
		},
		{
			"container": enemy_unit_2,
			"portrait_frame": enemy_unit_2.get_node("Portrait"),
			"portrait": enemy_unit_2.get_node("Portrait/PortraitTexture"),
			"status_row": enemy_unit_2.get_node("StatusRow"),
			"name_label": enemy_unit_2.get_node("EnemyInfo/EnemyName"),
			"hp_bar": enemy_unit_2.get_node("EnemyInfo/HPRow/HPBar"),
			"hp_label": enemy_unit_2.get_node("EnemyInfo/HPRow/EnemyHP"),
		},
		{
			"container": enemy_unit_3,
			"portrait_frame": enemy_unit_3.get_node("Portrait"),
			"portrait": enemy_unit_3.get_node("Portrait/PortraitTexture"),
			"status_row": enemy_unit_3.get_node("StatusRow"),
			"name_label": enemy_unit_3.get_node("EnemyInfo/EnemyName"),
			"hp_bar": enemy_unit_3.get_node("EnemyInfo/HPRow/HPBar"),
			"hp_label": enemy_unit_3.get_node("EnemyInfo/HPRow/EnemyHP"),
		},
	]
	for unit in enemy_units:
		UITheme.apply_accent_font_color(unit["name_label"])
		UITheme.style_bar(unit["hp_bar"], UITheme.HP_BAR_COLOR)
		UITheme.style_portrait_frame(unit["portrait_frame"])


func _setup_player_unit_refs() -> void:
	player_units = []
	for unit in [player_unit_1, player_unit_2, player_unit_3, player_unit_4]:
		var entry := {
			"container": unit,
			"portrait_frame": unit.get_node("Portrait"),
			"portrait": unit.get_node("Portrait/PortraitTexture"),
			"status_row": unit.get_node("StatusRow"),
			"name_label": unit.get_node("PlayerInfo/PlayerName"),
			"hp_bar": unit.get_node("PlayerInfo/HPRow/HPBar"),
			"hp_label": unit.get_node("PlayerInfo/HPRow/PlayerHP"),
			"mp_bar": unit.get_node("PlayerInfo/MPRow/MPBar"),
			"mp_label": unit.get_node("PlayerInfo/MPRow/PlayerMP"),
		}
		UITheme.apply_accent_font_color(entry["name_label"])
		UITheme.style_bar(entry["hp_bar"], UITheme.HP_BAR_COLOR)
		UITheme.style_bar(entry["mp_bar"], UITheme.MP_BAR_COLOR)
		UITheme.style_portrait_frame(entry["portrait_frame"])
		player_units.append(entry)


## GameManager.unlocked_characters를 기준으로 파티를 다시 구성한다.
func _rebuild_party() -> void:
	var new_party: Array[Character] = []
	for role in GameManager.ROLES:
		if not GameManager.unlocked_characters[role]:
			continue
		var existing := _find_party_member(role)
		if existing:
			new_party.append(existing)
		else:
			var character: Character = ROLE_CLASS[role].new()
			var data: CharacterData = GameManager.get_character_base_data(role)
			character.setup(data)
			GameManager.apply_character_upgrades(role, character)
			GameManager.apply_character_skills(role, character)
			new_party.append(character)
	party = new_party
	if battle_manager:
		battle_manager.party = party
	_update_party_bars()


func _find_party_member(role: String) -> Character:
	for m in party:
		if m.character_role == role:
			return m
	return null


## 업그레이드 패널에서 스탯을 구매하면 즉시 전투 중인 해당 파티원에게 반영.
func _on_character_stat_upgraded(role: String, key: String, amount: int) -> void:
	var member := _find_party_member(role)
	if member == null:
		return
	match key:
		"hp":
			member.max_hp += amount
			member.hp += amount
		"mp":
			member.max_mp += amount
			member.mp += amount
		"atk":
			member.atk += amount
		"def":
			member.def += amount
		"spd":
			member.spd += amount
	_update_party_bars()


## 업그레이드 패널에서 스킬을 습득하면 즉시 전투 중인 해당 파티원에게 반영.
func _on_character_skill_learned(role: String, skill_id: String) -> void:
	var member := _find_party_member(role)
	if member == null:
		return
	for skill_info in GameManager.CHARACTER_SKILL_INFO[role]:
		if skill_info["skill_id"] == skill_id:
			member.learn_skill(load(skill_info["resource_path"]))
			return


## 업그레이드 패널에서 새 캐릭터를 해금하면 파티에 합류시킨다.
func _on_character_unlocked(_role: String) -> void:
	_rebuild_party()


func _setup_battle_manager() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)

	battle_manager.stats_updated.connect(_on_stats_updated)
	battle_manager.battle_message.connect(_on_battle_message)
	battle_manager.battle_won.connect(_on_battle_won)
	battle_manager.battle_lost.connect(_on_battle_lost)
	battle_manager.action_performed.connect(_on_action_performed)


## 행동한 유닛(actor)이 있는 슬롯의 "초상화 프레임"을 찾는다. 아군이면 party 배열, 적이면
## enemies 배열에서의 인덱스로 player_units/enemy_units와 짝을 맞춘다.
## 애니메이션(hop/타격 이펙트/데미지 팝업)은 카드 전체가 아니라 초상화 한 장만 기준으로
## 움직이거나 중앙 정렬돼야 하므로, 전체 컨테이너가 아니라 portrait_frame을 반환한다.
func _get_unit_portrait(character: Character, is_party: bool) -> Control:
	if is_party:
		var idx := party.find(character)
		if idx >= 0 and idx < player_units.size():
			return player_units[idx]["portrait_frame"]
	else:
		var idx := enemies.find(character)
		if idx >= 0 and idx < enemy_units.size():
			return enemy_units[idx]["portrait_frame"]
	return null


## 행동 하나(action_performed)가 들어올 때마다 행동한 유닛은 hop 연출, 대상 유닛은
## 액션 종류에 맞는 타격 이펙트를 재생한다. 데미지 계열(공격/스킬 데미지) 행동은 대상이
## 좌우로 흔들리는 shake 연출도 함께 재생해서 "맞았다"는 느낌을 준다.
## 아군이 아군을 공격하는 경우는 실질적으로 없지만(파티끼리는 attack/skill_damage를
## 서로 쓰지 않음), 굳이 actor/target의 아군 여부를 따로 비교하지 않고 action_type만
## 보고 판단하는 게 더 간단하고 실수할 여지도 적다.
func _on_action_performed(data: Dictionary) -> void:
	var actor: Character = data["actor"]
	var target: Character = data["target"]
	var is_actor_party: bool = data["is_actor_party"]
	var is_target_party: bool = data["is_target_party"]
	var action_type: String = data["action_type"]

	var actor_portrait := _get_unit_portrait(actor, is_actor_party)
	if actor_portrait:
		_play_hop_animation(actor_portrait)

	var target_portrait := _get_unit_portrait(target, is_target_party)
	if target_portrait:
		_play_hit_effect(target_portrait, action_type)
		_play_value_popup(target_portrait, action_type, int(data["value"]))
		if _is_damage_action(action_type):
			_play_shake_animation(target_portrait)


## 데미지를 입히는 액션인지 여부. shake 연출을 넣을지 말지 이 하나로 판단한다.
func _is_damage_action(action_type: String) -> bool:
	return action_type == "attack" or action_type == "skill_damage"


## 유닛이 위로 살짝 튀었다가 원래 위치로 내려오는 연출. 카드 전체가 아니라 초상화
## 프레임만 움직여서, HP/MP 바나 버프 칸은 그대로 있고 사진만 통통 튀게 한다.
## portrait_frame은 BoxContainer(PlayerArea/EnemyArea) 하위 VBoxContainer의 자식이라
## position은 평소엔 부모가 자동으로 맞춰주지만, 이 짧은 Tween이 도는 동안엔 부모가
## 다시 정렬할 일이 없으므로 position을 직접 움직여도 문제없다.
const HOP_HEIGHT := 20.0

func _play_hop_animation(portrait_frame: Control) -> void:
	var origin_y := portrait_frame.position.y
	var half_duration: float = BattleManager.ACTION_ANIMATION_PLACEHOLDER_DELAY / 2.0

	var tween := create_tween()
	tween.tween_property(portrait_frame, "position:y", origin_y - HOP_HEIGHT, half_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait_frame, "position:y", origin_y, half_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 피격 대상 초상화가 좌우로 흔들리는 연출. hop과 마찬가지로 portrait_frame의 position만
## 움직이므로 HP/MP 바나 이름표는 그대로 있고 사진만 흔들린다. 진폭을 점점 줄여가며
## 왕복시켜서 "퍽 맞았다" 느낌을 낸다. 전체 길이는 히트 이펙트와 맞춰서 액션 한 번의
## 애니메이션 딜레이 안에 끝나도록 한다.
const SHAKE_DISTANCE := 10.0

func _play_shake_animation(portrait_frame: Control) -> void:
	var origin_x := portrait_frame.position.x
	var duration: float = BattleManager.ACTION_ANIMATION_PLACEHOLDER_DELAY
	var step: float = duration / 6.0

	var tween := create_tween()
	tween.tween_property(portrait_frame, "position:x", origin_x - SHAKE_DISTANCE, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait_frame, "position:x", origin_x + SHAKE_DISTANCE, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(portrait_frame, "position:x", origin_x - SHAKE_DISTANCE * 0.5, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(portrait_frame, "position:x", origin_x, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 대상 초상화(portrait_frame)의 화면 중앙 좌표를 effect_layer 기준 로컬 좌표로 변환한다.
## (effect_layer는 회전/스케일 없는 풀렉트 레이어라 global_position 차만 빼면 됨)
func _control_center_in_effect_layer(control: Control) -> Vector2:
	var global_center := control.global_position + control.size / 2.0
	return global_center - effect_layer.global_position


## action_type에 따라 대상 위에 다른 타격 이펙트를 띄운다.
func _play_hit_effect(target_portrait: Control, action_type: String) -> void:
	match action_type:
		"attack", "skill_damage":
			_spawn_slash_effect(target_portrait)
		"heal":
			_spawn_circle_effect(target_portrait, Color(0.35, 1.0, 0.45))
		"taunt":
			_spawn_circle_effect(target_portrait, Color(1.0, 0.65, 0.15))
		"buff":
			_spawn_circle_effect(target_portrait, Color(0.55, 0.6, 1.0))


## 공격/스킬 데미지용 베기 이펙트: 대상 위에 짧은 사선 막대가 나타났다 사라진다.
func _spawn_slash_effect(target_portrait: Control) -> void:
	var slash := ColorRect.new()
	slash.color = Color(1.0, 0.25, 0.25)
	slash.size = Vector2(12, 92)
	slash.pivot_offset = slash.size / 2.0
	slash.rotation_degrees = -40.0
	slash.modulate.a = 0.0
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_layer.add_child(slash)
	slash.position = _control_center_in_effect_layer(target_portrait) - slash.size / 2.0

	var duration: float = BattleManager.ACTION_ANIMATION_PLACEHOLDER_DELAY
	var tween := create_tween()
	tween.tween_property(slash, "modulate:a", 1.0, duration * 0.3)
	tween.tween_interval(duration * 0.2)
	tween.tween_property(slash, "modulate:a", 0.0, duration * 0.5)
	tween.finished.connect(slash.queue_free)


## 힐/도발/버프용 원형 이펙트: 대상 위에 색이 다른 반짝이는 원이 커지며 나타났다 사라진다.
func _spawn_circle_effect(target_portrait: Control, color: Color) -> void:
	var circle := Panel.new()
	var circle_size := Vector2(68, 68)
	circle.size = circle_size
	circle.pivot_offset = circle_size / 2.0
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(circle_size.x / 2.0)
	style.corner_radius_top_right = int(circle_size.x / 2.0)
	style.corner_radius_bottom_left = int(circle_size.x / 2.0)
	style.corner_radius_bottom_right = int(circle_size.x / 2.0)
	circle.add_theme_stylebox_override("panel", style)

	circle.modulate.a = 0.0
	circle.scale = Vector2(0.4, 0.4)
	effect_layer.add_child(circle)
	circle.position = _control_center_in_effect_layer(target_portrait) - circle_size / 2.0

	var duration: float = BattleManager.ACTION_ANIMATION_PLACEHOLDER_DELAY
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "modulate:a", 0.85, duration * 0.3)
	tween.tween_property(circle, "scale", Vector2(1.0, 1.0), duration * 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(circle, "modulate:a", 0.0, duration * 0.4)
	tween.finished.connect(circle.queue_free)


## 데미지/힐량 숫자를 대상 위에 띄운다. 공격/스킬 데미지는 "-값"을 붉은 계열로,
## 힐은 "+값"을 초록 계열로 표시. 값이 없는 도발/버프는 표시하지 않는다.
const DAMAGE_POPUP_COLOR := Color(1.0, 0.35, 0.35)
const HEAL_POPUP_COLOR := Color(0.4, 1.0, 0.5)
const POPUP_RISE_DISTANCE := 40.0

func _play_value_popup(target_portrait: Control, action_type: String, value: int) -> void:
	if value <= 0:
		return

	var text: String
	var color: Color
	match action_type:
		"attack", "skill_damage":
			text = "-%d" % value
			color = DAMAGE_POPUP_COLOR
		"heal":
			text = "+%d" % value
			color = HEAL_POPUP_COLOR
		_:
			return

	var popup := Label.new()
	popup.text = text
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_font_size_override("font_size", 26)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	popup.add_theme_constant_override("outline_size", 5)
	effect_layer.add_child(popup)
	popup.reset_size()

	# 라벨은 add_child 직후에야 실제 크기가 잡히므로, 그 크기를 기준으로 중앙 정렬한다.
	var center := _control_center_in_effect_layer(target_portrait)
	popup.position = center - popup.size / 2.0 - Vector2(0, 10)
	popup.modulate.a = 0.0

	var duration: float = BattleManager.ACTION_ANIMATION_PLACEHOLDER_DELAY * 1.6
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "modulate:a", 1.0, duration * 0.15)
	tween.tween_property(popup, "position:y", popup.position.y - POPUP_RISE_DISTANCE, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(popup, "modulate:a", 0.0, duration * 0.35)
	tween.finished.connect(popup.queue_free)


func _get_enemy_count(floor: int) -> int:
	var progress: float = clamp(float(floor) / 30.0, 0.0, 1.0)

	var weight_1: float = max(0.0, 1.4 - progress * 1.8)
	var weight_2: float = 1.0
	var weight_3: float = max(0.0, progress * 1.5 - 0.7)

	if floor <= 10:
		weight_3 = 0.0
	if floor >= 21:
		weight_1 = 0.0

	var total: float = weight_1 + weight_2 + weight_3
	var roll: float = randf() * total

	if roll < weight_1:
		return 1
	elif roll < weight_1 + weight_2:
		return 2
	else:
		return 3


func _is_boss_floor(floor: int) -> bool:
	return floor == BOSS_FLOOR


func _get_stat_multiplier(dungeon: int) -> float:
	return GameManager.get_dungeon_enemy_stat_multiplier(dungeon)


func _get_reward_multiplier(dungeon: int) -> float:
	return GameManager.get_dungeon_enemy_reward_multiplier(dungeon)


## 몬스터 로스터(어느 던전에 어떤 몬스터가 나오는지)는 몬스터 도감(MonsterPanel)도 참조해야 해서
## GameManager.DUNGEON_ENEMY_DATA로 옮겨졌다. 자세한 내용은 GameManager.gd 참고.


func _pick_mob_path(mob_paths: Array, floor: int) -> String:
	if mob_paths.size() == 1:
		return mob_paths[0]

	var progress: float = clamp(float(floor) / 30.0, 0.0, 1.0)

	var weight_slime: float = max(0.1, 1.2 - progress * 0.5)
	var weight_bee: float = 1 + progress * 1.0

	var total: float = weight_slime + weight_bee
	var roll: float = randf() * total

	if roll < weight_slime:
		return mob_paths[0]
	else:
		return mob_paths[1]


func _create_enemy(data_path: String, dungeon: int) -> Enemy:
	var data: EnemyData = load(data_path)
	var e := Enemy.new()
	e.setup_enemy(data)

	var stat_mult: float = _get_stat_multiplier(dungeon)
	var reward_mult: float = _get_reward_multiplier(dungeon)

	e.max_hp = int(e.max_hp * stat_mult)
	e.hp = e.max_hp
	e.atk = int(e.atk * stat_mult)
	e.def = int(e.def * stat_mult)
	e.spd = int(e.spd * stat_mult)

	e.gold_reward = int(e.gold_reward * reward_mult)
	e.crystal_reward = int(e.crystal_reward)

	# 실제로 전투에 등장했으니 몬스터 도감에 등록(이미 등록된 몬스터면 GameManager 쪽에서 무시함).
	GameManager.discover_enemy(data_path)

	return e


func _setup_enemies_for_current_floor() -> void:
	var floor: int = GameManager.current_floor
	var dungeon: int = GameManager.current_dungeon
	var dungeon_data: Dictionary = GameManager.DUNGEON_ENEMY_DATA[dungeon]
	enemies.clear()

	if _is_boss_floor(floor):
		enemies.append(_create_enemy(dungeon_data["boss"], dungeon))
	else:
		var count := _get_enemy_count(floor)
		var mob_paths: Array = dungeon_data["mobs"]
		for i in count:
			var picked_path: String = _pick_mob_path(mob_paths, floor)
			enemies.append(_create_enemy(picked_path, dungeon))

	_update_enemy_unit_visibility()
	_update_enemy_bars()
	_update_dungeon_label()


## 몬스터 수에 따라 첫 번째 슬롯부터 보여주고 나머지는 숨겨서 중앙에 배치되도록 설정
func _update_enemy_unit_visibility() -> void:
	for i in enemy_units.size():
		var unit: Dictionary = enemy_units[i]
		if i < enemies.size():
			unit["container"].visible = true
			unit["portrait"].texture = _get_enemy_portrait(enemies[i].character_name)
			UITheme.style_portrait_frame(unit["portrait_frame"], enemies[i].is_boss)
			unit["name_label"].text = enemies[i].character_name
		else:
			unit["container"].visible = false


## 역할/몬스터 이름에 맞는 임시 아이콘 텍스처를 가져온다(없으면 null, TextureRect는 빈 채로 둠).
var _portrait_cache: Dictionary = {}

func _load_portrait(path: String) -> Texture2D:
	if not _portrait_cache.has(path):
		_portrait_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _portrait_cache[path]


func _get_role_portrait(role: String) -> Texture2D:
	if not ROLE_PORTRAIT_PATHS.has(role):
		return null
	return _load_portrait(ROLE_PORTRAIT_PATHS[role])


func _get_enemy_portrait(enemy_name: String) -> Texture2D:
	if not ENEMY_PORTRAIT_PATHS.has(enemy_name):
		return null
	return _load_portrait(ENEMY_PORTRAIT_PATHS[enemy_name])


func _update_dungeon_label() -> void:
	var floor: int = GameManager.current_floor
	var floor_text := "BOSS" if _is_boss_floor(floor) else "%dF" % floor
	dungeon_info_label.text = "DUNGEON %d - %s" % [GameManager.current_dungeon, floor_text]


func _start_current_floor() -> void:
	_setup_enemies_for_current_floor()
	battle_manager.start_battle(party, enemies)


func _on_stats_updated() -> void:
	_update_party_bars()
	_update_enemy_bars()


func _on_battle_message(text: String) -> void:
	battle_message_label.text = text


func _on_battle_won(gold_reward: int, crystal_reward: int) -> void:
	var streak_bonus: int = GameManager.get_streak_gold_bonus(GameManager.current_floor)
	GameManager.add_gold(gold_reward + streak_bonus)
	GameManager.add_crystal(crystal_reward)
	_refresh_currency_labels()

	var boss_just_cleared: bool = GameManager.current_floor >= BOSS_FLOOR

	if boss_just_cleared:
		for m in party:
			m.hp = m.max_hp
			m.mp = m.max_mp
		_update_party_bars()
	else:
		_apply_post_battle_heal()

	if boss_just_cleared:
		GameManager.unlock_next_dungeon(GameManager.current_dungeon)
		GameManager.current_floor = 1
	else:
		GameManager.current_floor += 1
	GameManager.save_progress()

	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_start_current_floor()


func _on_dungeon_changed() -> void:
	battle_manager.stop_battle()
	_start_current_floor()


func _on_battle_lost() -> void:
	GameManager.current_floor = 1
	GameManager.save_progress()
	for m in party:
		m.hp = m.max_hp
		m.mp = m.max_mp
	_update_party_bars()

	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_start_current_floor()


func _apply_post_battle_heal() -> void:
	var hp_percent: float = GameManager.get_post_battle_heal_hp_percent()
	var mp_percent: float = GameManager.get_post_battle_heal_mp_percent()
	
	for m in party:
		if m.hp <= 0:
			continue
		if hp_percent > 0:
			m.hp = min(m.max_hp, m.hp + int(m.max_hp * hp_percent))
		if mp_percent > 0:
			m.mp = min(m.max_mp, m.mp + int(m.max_mp * mp_percent))
	_update_party_bars()


func _refresh_currency_labels() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	crystal_label.text = "Crystal: %d" % GameManager.crystal


## 파티원 인원수에 따라 앞쪽 슬롯부터 차례대로 켜주어 중앙으로 정렬시킴
func _update_party_bars() -> void:
	for i in player_units.size():
		var unit: Dictionary = player_units[i]
		if i < party.size():
			var m: Character = party[i]
			unit["container"].visible = true
			unit["portrait"].texture = _get_role_portrait(m.character_role)
			unit["name_label"].text = m.character_name.to_upper()
			unit["hp_bar"].max_value = m.max_hp
			unit["hp_bar"].value = m.hp
			unit["hp_label"].text = "%d / %d" % [m.hp, m.max_hp]
			unit["mp_bar"].max_value = m.max_mp
			unit["mp_bar"].value = m.mp
			unit["mp_label"].text = "%d / %d" % [m.mp, m.max_mp]
			_refresh_status_row(unit["status_row"], m)
		else:
			unit["container"].visible = false


func _update_enemy_bars() -> void:
	for i in enemies.size():
		var e: Enemy = enemies[i]
		var unit: Dictionary = enemy_units[i]
		unit["hp_bar"].max_value = e.max_hp
		unit["hp_bar"].value = e.hp
		unit["hp_label"].text = "%d / %d" % [e.hp, e.max_hp]
		_refresh_status_row(unit["status_row"], e)


## status_row(HBoxContainer)를 character의 현재 active_effects에 맞춰 다시 그린다.
## 매번 기존 배지를 지우고 새로 만드는 방식이라 라운드가 지나 지속시간이 바뀌면 그대로 반영된다.
func _refresh_status_row(status_row: HBoxContainer, character: Character) -> void:
	for child in status_row.get_children():
		child.queue_free()

	for effect_id in character.active_effects.keys():
		var remaining_turns: int = character.active_effects[effect_id]["remaining_turns"]
		status_row.add_child(_make_status_badge(effect_id, remaining_turns))


## 아이콘(고정 크기 TextureRect) + 오른쪽 아래에 남은 턴 수를 작게 표시하는 배지 하나를 만든다.
## 아이콘/숫자 모두 고정 크기라 RichTextLabel 자동 줄바꿈 같은 레이아웃 문제와 무관하다.
const STATUS_BADGE_SIZE := 20

func _make_status_badge(effect_id: String, remaining_turns: int) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(STATUS_BADGE_SIZE, STATUS_BADGE_SIZE)
	badge.tooltip_text = "%s (%d턴 남음)" % [
		STATUS_EFFECT_DISPLAY_NAMES.get(effect_id, effect_id), remaining_turns
	]

	var icon_path: String = STATUS_EFFECT_ICON_PATHS.get(effect_id, STATUS_EFFECT_GENERIC_ICON_PATH)
	var icon_rect := TextureRect.new()
	icon_rect.texture = _load_portrait(icon_path)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon_rect)

	var count_label := Label.new()
	count_label.text = str(remaining_turns)
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 3)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(count_label)

	return badge
