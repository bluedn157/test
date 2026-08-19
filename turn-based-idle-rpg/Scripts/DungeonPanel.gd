extends Panel

## 화면에 미리 보여줄 던전 목록 개수. 아직 안 만든 던전도 "잠김"으로 미리 보여줘서
## 앞으로 늘어날 거라는 걸 알 수 있게 함. 실제 던전 컨텐츠(몬스터 구성 등)가 늘어나면
## 이 값도 같이 늘리면 됨.
const MAX_DISPLAYED_DUNGEON := 5

var content_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	GameManager.dungeon_changed.connect(_render)
	GameManager.dungeon_unlocked.connect(_render.unbind(1))
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
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "던전 선택"
	UITheme.apply_title_style(title)
	root.add_child(title)

	content_list = VBoxContainer.new()
	content_list.add_theme_constant_override("separation", 8)
	root.add_child(content_list)


func _render() -> void:
	for child in content_list.get_children():
		child.queue_free()

	for dungeon in range(1, MAX_DISPLAYED_DUNGEON + 1):
		_add_dungeon_row(dungeon)


func _add_dungeon_row(dungeon: int) -> void:
	var unlocked := GameManager.is_dungeon_unlocked(dungeon)
	var is_current := (dungeon == GameManager.current_dungeon)

	# 진행 중인 던전은 강조 테두리, 잠긴 던전은 더 어두운 배경으로 구분.
	var bg := UITheme.LOCKED_ROW_BG_COLOR if not unlocked else UITheme.ROW_BG_COLOR
	var border := UITheme.ACCENT_COLOR if is_current else UITheme.CARD_BORDER_COLOR
	var card := UITheme.create_card_panel(bg, border)
	content_list.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var label := Label.new()
	var status := ""
	if is_current:
		status = " (진행 중)"
	elif not unlocked:
		status = " (잠김 - 이전 던전 보스를 클리어하면 해금)"
	label.text = "던전 %d%s" % [dungeon, status]
	label.custom_minimum_size = Vector2(260, 0)
	if is_current:
		UITheme.apply_accent_font_color(label)
	elif not unlocked:
		label.add_theme_color_override("font_color", UITheme.DIM_TEXT_COLOR)
	row.add_child(label)

	var enter_button := Button.new()
	enter_button.text = "입장"
	enter_button.disabled = not unlocked or is_current
	enter_button.pressed.connect(_on_enter_pressed.bind(dungeon))
	row.add_child(enter_button)


func _on_enter_pressed(dungeon: int) -> void:
	GameManager.select_dungeon(dungeon)
