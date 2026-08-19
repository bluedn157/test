extends Panel

## 실수로 초기화하는 걸 막기 위해 "초기화" 버튼을 누르면 바로 지우지 않고
## 한 번 더 "확인" 절차를 거치게 한다.
var _awaiting_confirm: bool = false

var content_list: VBoxContainer

## 게임 속도 슬라이더 값을 코드에서 바꿀 때(_update_battle_speed_ui 등) value_changed가
## 다시 발생해 GameManager.set_battle_speed를 재호출하는 걸 막기 위한 플래그.
var _updating_speed_slider: bool = false

## 게임 속도 섹션 위젯들. 슬라이더 드래그 중에 패널 전체가 다시 그려지며 슬라이더가
## 통째로 교체되는 걸 피하기 위해, 이 위젯들은 한 번만 만들고 이후엔 값만 갱신한다.
var _speed_checkbox: CheckBox
var _speed_desc_label: Label
var _speed_value_label: Label
var _speed_slider: HSlider
var _speed_max_label: Label


func _ready() -> void:
	_build_ui()
	_update_battle_speed_ui()
	_render()
	GameManager.battle_speed_changed.connect(_on_battle_speed_changed)


func _on_battle_speed_changed() -> void:
	_update_battle_speed_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "설정"
	UITheme.apply_title_style(title)
	root.add_child(title)
	root.add_child(HSeparator.new())

	_build_battle_speed_section(root)
	root.add_child(HSeparator.new())

	content_list = VBoxContainer.new()
	content_list.add_theme_constant_override("separation", 8)
	root.add_child(content_list)


## ---------------- 게임 속도 ----------------
## 이 섹션의 위젯들은 (데이터 관리 섹션과 달리) _ready에서 한 번만 만들고, 이후에는
## _update_battle_speed_ui()로 값만 갱신한다. 슬라이더를 드래그하는 도중 GameManager가
## battle_speed_changed를 emit할 때마다 슬라이더 자체가 새로 생성/교체되면 드래그가
## 끊기기 때문이다.
func _build_battle_speed_section(root: VBoxContainer) -> void:
	var section_label := Label.new()
	section_label.text = "게임 속도"
	UITheme.apply_accent_font_color(section_label)
	section_label.add_theme_font_size_override("font_size", 16)
	root.add_child(section_label)

	var card := UITheme.create_card_panel(UITheme.ROW_BG_COLOR, UITheme.CARD_BORDER_COLOR)
	root.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	_speed_checkbox = CheckBox.new()
	_speed_checkbox.text = "업그레이드 시 자동으로 최대 배속으로 설정"
	_speed_checkbox.toggled.connect(_on_auto_max_toggled)
	box.add_child(_speed_checkbox)

	_speed_desc_label = Label.new()
	_speed_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_speed_desc_label.add_theme_color_override("font_color", UITheme.DIM_TEXT_COLOR)
	box.add_child(_speed_desc_label)

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 10)
	box.add_child(speed_row)

	_speed_value_label = Label.new()
	_speed_value_label.custom_minimum_size = Vector2(140, 0)
	speed_row.add_child(_speed_value_label)

	_speed_slider = HSlider.new()
	_speed_slider.min_value = 1.0
	_speed_slider.step = 0.1
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.value_changed.connect(_on_speed_slider_changed)
	speed_row.add_child(_speed_slider)

	_speed_max_label = Label.new()
	_speed_max_label.add_theme_color_override("font_color", UITheme.DIM_TEXT_COLOR)
	speed_row.add_child(_speed_max_label)


## 게임 속도 위젯들에 GameManager의 현재 상태를 반영한다 (위젯을 새로 만들지 않음).
func _update_battle_speed_ui() -> void:
	var auto_max: bool = GameManager.battle_speed_auto_max
	var max_speed: float = GameManager.get_battle_speed_multiplier()

	_speed_checkbox.set_pressed_no_signal(auto_max)

	if auto_max:
		_speed_desc_label.text = "자동 설정이 켜져 있으면 배속이 항상 최댓값으로 고정되어 직접 조절할 수 없습니다. \"게임 속도\" 공용 업그레이드를 사면 자동으로 최댓값이 올라갑니다."
	else:
		_speed_desc_label.text = "자동 설정을 끄면 1배 ~ 최댓값 사이에서 배속을 직접 조절할 수 있습니다. 이 경우 업그레이드를 사도 현재 배속은 자동으로 오르지 않습니다."

	_speed_value_label.text = "현재 배속: %.1f배" % GameManager.battle_speed_current
	_speed_max_label.text = "최대 %.1f배" % max_speed

	_speed_slider.max_value = max(1.0, max_speed)
	_updating_speed_slider = true
	_speed_slider.value = GameManager.battle_speed_current
	_updating_speed_slider = false
	_speed_slider.editable = not auto_max


func _on_auto_max_toggled(pressed: bool) -> void:
	GameManager.set_battle_speed_auto_max(pressed)


func _on_speed_slider_changed(value: float) -> void:
	if _updating_speed_slider:
		return
	if GameManager.set_battle_speed(value):
		_speed_value_label.text = "현재 배속: %.1f배" % GameManager.battle_speed_current


func _render() -> void:
	for child in content_list.get_children():
		child.queue_free()

	var section_label := Label.new()
	section_label.text = "데이터 관리"
	UITheme.apply_accent_font_color(section_label)
	section_label.add_theme_font_size_override("font_size", 16)
	content_list.add_child(section_label)

	# 위험한 동작(초기화)이라 카드로 한 번 더 감싸서 시각적으로 구분한다.
	var danger_card := UITheme.create_card_panel(UITheme.ROW_BG_COLOR, UITheme.BOSS_TAG_COLOR)
	content_list.add_child(danger_card)

	var danger_box := VBoxContainer.new()
	danger_box.add_theme_constant_override("separation", 10)
	danger_card.add_child(danger_box)

	if not _awaiting_confirm:
		_render_default_state(danger_box)
	else:
		_render_confirm_state(danger_box)


func _render_default_state(box: VBoxContainer) -> void:
	var desc := Label.new()
	desc.text = "골드, 크리스탈, 캐릭터 해금 및 업그레이드 등 모든 진행 상황을 초기화합니다."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_color_override("font_color", UITheme.DIM_TEXT_COLOR)
	box.add_child(desc)

	var reset_button := Button.new()
	reset_button.text = "클리어 데이터 (데이터 초기화)"
	reset_button.pressed.connect(_on_reset_pressed)
	box.add_child(reset_button)


func _render_confirm_state(box: VBoxContainer) -> void:
	var warning := Label.new()
	warning.text = "정말로 초기화하시겠습니까? 이 작업은 되돌릴 수 없습니다."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD
	warning.add_theme_color_override("font_color", UITheme.BOSS_TAG_COLOR)
	box.add_child(warning)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var confirm_button := Button.new()
	confirm_button.text = "초기화 확인"
	confirm_button.pressed.connect(_on_confirm_reset_pressed)
	row.add_child(confirm_button)

	var cancel_button := Button.new()
	cancel_button.text = "취소"
	cancel_button.pressed.connect(_on_cancel_reset_pressed)
	row.add_child(cancel_button)

	box.add_child(row)


func _on_reset_pressed() -> void:
	_awaiting_confirm = true
	_render()


func _on_cancel_reset_pressed() -> void:
	_awaiting_confirm = false
	_render()


func _on_confirm_reset_pressed() -> void:
	GameManager.reset_data()
	# 파티/전투 등 런타임 상태까지 완전히 새로 만들기 위해 씬 자체를 다시 불러온다.
	get_tree().reload_current_scene()
