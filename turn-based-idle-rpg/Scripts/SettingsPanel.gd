extends Panel

## 실수로 초기화하는 걸 막기 위해 "초기화" 버튼을 누르면 바로 지우지 않고
## 한 번 더 "확인" 절차를 거치게 한다.
var _awaiting_confirm: bool = false

var content_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	_render()


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

	content_list = VBoxContainer.new()
	content_list.add_theme_constant_override("separation", 8)
	root.add_child(content_list)


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
