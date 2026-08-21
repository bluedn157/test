extends Panel

const TAB_NAMES := ["공용", "딜러", "힐러", "탱커", "버퍼"]

const CELL_PADDING := 8

# 스킬 표 열의 정확한 고정 폭
const COL_1_WIDTH := 50   # 1열: 사용 (체크박스)
const COL_3_WIDTH := 120  # 3열: 강화 / 습득 버튼

var tab_buttons: Array[Button] = []
var content_list: VBoxContainer
var current_tab: int = 0


func _ready() -> void:
	_build_ui()
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.crystal_changed.connect(_on_crystal_changed)
	_show_tab(0)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	margin.add_child(root)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	root.add_child(tab_bar)

	for i in TAB_NAMES.size():
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_show_tab.bind(i))
		tab_bar.add_child(btn)
		tab_buttons.append(btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	content_list = VBoxContainer.new()
	content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_list.add_theme_constant_override("separation", 12)
	scroll.add_child(content_list)


func _show_tab(index: int) -> void:
	current_tab = index
	for i in tab_buttons.size():
		tab_buttons[i].button_pressed = (i == index)
	_render_tab()


func _on_gold_changed() -> void:
	_render_tab()

func _on_crystal_changed() -> void:
	_render_tab()


func _render_tab() -> void:
	for child in content_list.get_children():
		child.queue_free()

	if current_tab == 0:
		_render_common_tab()
		return

	var role: String = GameManager.ROLES[current_tab - 1]
	if GameManager.is_character_unlocked(role):
		_render_character_tab(role)
	else:
		_render_locked_tab(role)


func _get_common_upgrade_currency(upgrade_id: String) -> String:
	if upgrade_id in ["dungeon_stat_reduction", "dungeon_reward_boost", "battle_speed"]:
		return "C"
	return "G"


## ---------------- 공용 탭 ----------------

func _render_common_tab() -> void:
	_add_section_label("공용 업그레이드")
	
	var grid := _create_compact_table_grid(3)
	content_list.add_child(grid)
	
	_add_table_header(grid, ["업그레이드 항목", "수치 변화 (현재 → 다음)", "강화"])

	for key in GameManager.COMMON_UPGRADE_INFO.keys():
		var info: Dictionary = GameManager.COMMON_UPGRADE_INFO[key]
		var level: int = GameManager.common_upgrades[key]
		var per_level: int = int(info["per_level"])
		var maxed: bool = GameManager.is_common_upgrade_maxed(key)
		var cost: int = GameManager.get_common_upgrade_cost(key)
		var current_text: String
		var next_text: String
		if key == "dungeon_stat_reduction":
			current_text = "%.2f" % GameManager.get_dungeon_stat_multiplier_step()
			next_text = "%.2f" % GameManager.get_dungeon_stat_multiplier_step_at(level + 1)
		elif key == "dungeon_reward_boost":
			current_text = "%.2f" % GameManager.get_dungeon_reward_multiplier_step()
			next_text = "%.2f" % GameManager.get_dungeon_reward_multiplier_step_at(level + 1)
		elif key == "battle_speed":
			current_text = "%.1f배" % GameManager.get_battle_speed_multiplier()
			next_text = "%.1f배" % GameManager.get_battle_speed_multiplier_at(level + 1)
		elif key == "streak_gold_bonus":
			current_text = "%dG/층" % (level * per_level)
			next_text = "%dG/층" % ((level + 1) * per_level)
		else:
			current_text = "%d%%" % (level * per_level)
			next_text = "%d%%" % ((level + 1) * per_level)

		if maxed:
			next_text = current_text

		_add_upgrade_row_to_grid(grid, info["label"], level, cost, current_text, next_text, _on_common_upgrade_pressed.bind(key), maxed, _get_common_upgrade_currency(key))


func _on_common_upgrade_pressed(key: String) -> void:
	if GameManager.purchase_common_upgrade(key):
		_render_tab()


## ---------------- 해금되지 않은 캐릭터 탭 ----------------

func _render_locked_tab(role: String) -> void:
	var role_name: String = GameManager.ROLE_LABELS[role]
	var cost: int = GameManager.get_unlock_cost(role)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.create_cell_style(UITheme.ROW_BG_COLOR, UITheme.BORDER_COLOR, 1))
	
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var label := Label.new()
	label.text = "%s 캐릭터를 아직 해금하지 않았습니다." % role_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var unlock_button := Button.new()
	unlock_button.text = "%s 해금 (%d C)" % [role_name, cost]
	unlock_button.disabled = GameManager.crystal < cost
	unlock_button.add_theme_color_override("font_color", UITheme.CRYSTAL_COLOR)
	unlock_button.pressed.connect(_on_unlock_pressed.bind(role))
	box.add_child(unlock_button)

	content_list.add_child(panel)


func _on_unlock_pressed(role: String) -> void:
	if GameManager.unlock_character(role):
		_render_tab()


## ---------------- 캐릭터별 탭 ----------------

func _render_character_tab(role: String) -> void:
	var role_name: String = GameManager.ROLE_LABELS[role]
	var stat_info: Dictionary = GameManager.CHARACTER_UPGRADE_INFO[role]
	var stat_levels: Dictionary = GameManager.character_upgrades[role]

	_add_section_label("%s 스탯 업그레이드" % role_name)
	
	var stat_grid := _create_compact_table_grid(3)
	content_list.add_child(stat_grid)
	_add_table_header(stat_grid, ["스탯 항목", "수치 변화", "강화"])

	for key in stat_info.keys():
		var info: Dictionary = stat_info[key]
		var level: int = stat_levels[key]
		var per_level: int = int(info["per_level"])
		var base_value: int = GameManager.get_character_base_stat(role, key)
		var cost: int = GameManager.get_character_upgrade_cost(role, key)
		var current_text := "%d" % (base_value + level * per_level)
		var next_text := "%d" % (base_value + (level + 1) * per_level)
		
		_add_upgrade_row_to_grid(stat_grid, info["label"], level, cost, current_text, next_text, _on_character_upgrade_pressed.bind(role, key))

	_add_section_label("스킬")
	var skill_list: Array = GameManager.CHARACTER_SKILL_INFO[role]
	if skill_list.is_empty():
		var skill_note := Label.new()
		skill_note.text = "아직 배울 수 있는 스킬이 없습니다."
		skill_note.autowrap_mode = TextServer.AUTOWRAP_WORD
		skill_note.modulate = Color(1, 1, 1, 0.6)
		skill_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_list.add_child(skill_note)
	else:
		var header_panel := _build_skill_header(["사용", "스킬 정보 및 효과", "강화 / 습득"])
		content_list.add_child(header_panel)

		var skill_card_list := VBoxContainer.new()
		skill_card_list.add_theme_constant_override("separation", 6)
		content_list.add_child(skill_card_list)

		for skill_info in skill_list:
			skill_card_list.add_child(_build_skill_card(role, skill_info))


func _on_character_upgrade_pressed(role: String, key: String) -> void:
	if GameManager.purchase_character_upgrade(role, key):
		_render_tab()


## 스킬 표 상단 헤더
func _build_skill_header(headers: Array[String]) -> PanelContainer:
	var header_panel := PanelContainer.new()
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = UITheme.HEADER_BG_COLOR
	outer_style.border_color = UITheme.BORDER_COLOR
	outer_style.set_border_width_all(1)
	outer_style.content_margin_left = UITheme.CARD_BORDER_WIDTH
	outer_style.content_margin_right = UITheme.CARD_BORDER_WIDTH
	outer_style.content_margin_top = 4
	outer_style.content_margin_bottom = 4
	header_panel.add_theme_stylebox_override("panel", outer_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	header_panel.add_child(hbox)

	var widths := [COL_1_WIDTH, 0, COL_3_WIDTH]
	for i in headers.size():
		var cell := PanelContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		
		if widths[i] > 0:
			cell.custom_minimum_size = Vector2(widths[i], 0)
		else:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0,0,0,0)
		if i > 0:
			style.border_width_left = 1
			style.border_color = UITheme.BORDER_COLOR
		cell.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = headers[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", UITheme.ACCENT_COLOR)
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(label)
		
		hbox.add_child(cell)

	return header_panel


## 스킬 카드 생성
func _build_skill_card(role: String, skill_info: Dictionary) -> Control:
	var skill_id: String = skill_info["skill_id"]
	var skill: SkillData = load(skill_info["resource_path"])
	var learned: bool = GameManager.is_skill_learned(role, skill_id)
	var level: int = GameManager.get_skill_level(role, skill_id)
	var current_power: float = GameManager.get_skill_power(role, skill_id) if learned else skill.power

	var name_text := "%s (Lv.%d)" % [skill.skill_name, level] if learned else skill.skill_name
	var description_text: String = skill.description
	var extra_line := ""
	if learned:
		var next_power := current_power + float(skill_info["power_per_level"])
		if skill.skill_type == "taunt":
			var member_count: int = max(1, GameManager.get_unlocked_character_count())
			var current_chance := GameManager.get_taunt_hit_chance(current_power, member_count)
			var next_chance := GameManager.get_taunt_hit_chance(next_power, member_count)
			var color_hex := UITheme.NEXT_STAT_COLOR.to_html(false)
			extra_line = "\n현재 파티 기준 적중률: %d%% → [color=#%s]%d%%[/color]" % [
				int(round(current_chance * 100)), color_hex, int(round(next_chance * 100))
			]
		else:
			description_text = _highlight_power_in_description(skill.description, current_power, next_power)

	var power_info_text := "[b]%s[/b]\n%s\n[color=#89b4fa]MP %d / %d턴 쿨다운[/color]%s" % [
		name_text, description_text, skill.mp_cost, skill.cooldown, extra_line
	]

	var power_track_info := GameManager._get_skill_track_info(skill_info, "power")
	var power_button: Button
	if learned:
		var upgrade_cost := GameManager.get_skill_upgrade_cost(role, skill_id)
		power_button = Button.new()
		# 버튼 표시는 'label' ("강화") 사용
		power_button.text = "%s\n (%d G)" % [power_track_info.get("label", "강화"), upgrade_cost]
		power_button.disabled = GameManager.gold < upgrade_cost
		power_button.add_theme_color_override("font_color", UITheme.GOLD_COLOR)
		power_button.pressed.connect(_on_skill_upgrade_pressed.bind(role, skill_id, "power"))
	else:
		power_button = Button.new()
		power_button.text = "배우기\n(%d G)" % skill_info["cost"]
		power_button.disabled = GameManager.gold < int(skill_info["cost"])
		power_button.add_theme_color_override("font_color", UITheme.GOLD_COLOR)
		power_button.pressed.connect(_on_learn_skill_pressed.bind(role, skill_id))

	var track_rows: Array[Dictionary] = [{"info_text": power_info_text, "button": power_button}]

	if learned:
		for extra in skill_info.get("extra_upgrades", []):
			var track_id: String = extra["track_id"]
			var track_info := GameManager._get_skill_track_info(skill_info, track_id)
			var track_level: int = GameManager.get_skill_level(role, skill_id, track_id)
			var current_val: float = track_level * float(track_info.get("per_level", 0.0))
			var next_val: float = (track_level + 1) * float(track_info.get("per_level", 0.0))
			var color_hex2 := UITheme.NEXT_STAT_COLOR.to_html(false)
			
			# 텍스트 설명에는 'name' ("최대 HP 비례 회복") 사용
			var track_name: String = track_info.get("name", track_info.get("label", ""))
			var track_text := "%s: %d%% → [color=#%s]%d%%[/color]" % [
				track_name, int(round(current_val * 100)), color_hex2, int(round(next_val * 100))
			]

			var track_cost := GameManager.get_skill_upgrade_cost(role, skill_id, track_id)
			var track_button := Button.new()
			# 버튼 표시는 'label' ("강화") 사용
			track_button.text = "%s (%d G)" % [track_info.get("label", "강화"), track_cost]
			track_button.disabled = GameManager.gold < track_cost
			track_button.add_theme_color_override("font_color", UITheme.GOLD_COLOR)
			track_button.pressed.connect(_on_skill_upgrade_pressed.bind(role, skill_id, track_id))

			track_rows.append({"info_text": track_text, "button": track_button})

	# 카드 생성 및 배치 부분
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.ROW_BG_COLOR
	card_style.border_color = UITheme.CARD_BORDER_COLOR
	card_style.set_border_width_all(UITheme.CARD_BORDER_WIDTH)
	card_style.content_margin_left = 0
	card_style.content_margin_right = 0
	card_style.content_margin_top = 0
	card_style.content_margin_bottom = 0
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var card_hbox := HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 0)
	card.add_child(card_hbox)

	var check_area := CenterContainer.new()
	check_area.custom_minimum_size = Vector2(COL_1_WIDTH, 0)
	check_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	check_area.mouse_filter = Control.MOUSE_FILTER_PASS
	if learned:
		var check := CheckBox.new()
		check.button_pressed = _get_skill_enabled(role, skill_id)
		check.toggled.connect(_on_skill_toggled.bind(role, skill_id))
		check_area.add_child(check)
	card_hbox.add_child(check_area)

	var tracks_vbox := VBoxContainer.new()
	tracks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks_vbox.add_theme_constant_override("separation", 0)
	card_hbox.add_child(tracks_vbox)

	for i in track_rows.size():
		var row_data: Dictionary = track_rows[i]

		var row_panel := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0, 0, 0, 0)
		if i > 0:
			row_style.border_width_top = 1
		row_style.border_width_left = 1
		row_style.border_color = UITheme.BORDER_COLOR
		row_style.content_margin_left = CELL_PADDING
		row_style.content_margin_right = 0
		row_style.content_margin_top = CELL_PADDING
		row_style.content_margin_bottom = CELL_PADDING
		row_panel.add_theme_stylebox_override("panel", row_style)
		row_panel.mouse_filter = Control.MOUSE_FILTER_PASS

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 0)
		row_panel.add_child(row_hbox)

		var info_label := RichTextLabel.new()
		info_label.bbcode_enabled = true
		info_label.fit_content = true
		info_label.scroll_active = false
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_label.text = row_data["info_text"]
		row_hbox.add_child(info_label)

		var btn_panel := PanelContainer.new()
		btn_panel.custom_minimum_size = Vector2(COL_3_WIDTH, 0)
		btn_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0,0,0,0)
		btn_style.border_width_left = 1
		btn_style.border_color = UITheme.BORDER_COLOR
		btn_style.content_margin_left = 4
		btn_style.content_margin_right = 4
		btn_panel.add_theme_stylebox_override("panel", btn_style)

		var btn_area := CenterContainer.new()
		btn_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var button: Button = row_data["button"]
		button.custom_minimum_size = Vector2(COL_3_WIDTH - 12, 0)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		
		btn_area.add_child(button)
		btn_panel.add_child(btn_area)
		
		row_hbox.add_child(btn_panel)

		tracks_vbox.add_child(row_panel)

	return card


## 스탯 업그레이드 한 줄 추가
func _add_upgrade_row_to_grid(grid: GridContainer, label_text: String, level: int, cost: int, current_text: String, next_text: String, callable: Callable, maxed: bool = false, currency: String = "G") -> void:
	var name_cell := UITheme.create_cell_panel(UITheme.ROW_BG_COLOR, CELL_PADDING)
	var name_label := Label.new()
	name_label.text = "%s (Lv.%d)" % [label_text, level]
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_cell.add_child(name_label)
	grid.add_child(name_cell)

	var stat_cell := UITheme.create_cell_panel(UITheme.ROW_BG_COLOR, CELL_PADDING)
	var change_box := HBoxContainer.new()
	change_box.alignment = BoxContainer.ALIGNMENT_CENTER
	change_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_cell.add_child(change_box)

	var current_label := Label.new()
	current_label.text = current_text
	current_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change_box.add_child(current_label)

	var arrow_label := Label.new()
	arrow_label.text = " → "
	arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change_box.add_child(arrow_label)

	var next_label := Label.new()
	next_label.text = next_text
	next_label.add_theme_color_override("font_color", UITheme.NEXT_STAT_COLOR)
	next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change_box.add_child(next_label)
	grid.add_child(stat_cell)

	var btn_cell := UITheme.create_cell_panel(UITheme.ROW_BG_COLOR, CELL_PADDING)
	var buy_button := Button.new()
	if maxed:
		buy_button.text = "MAX"
		buy_button.disabled = true
	else:
		buy_button.text = "%d %s" % [cost, currency]
		buy_button.disabled = (GameManager.crystal < cost) if currency == "C" else (GameManager.gold < cost)
		buy_button.add_theme_color_override("font_color", UITheme.CRYSTAL_COLOR if currency == "C" else UITheme.GOLD_COLOR)
	buy_button.pressed.connect(callable)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_cell.add_child(buy_button)
	grid.add_child(btn_cell)


## 스킬 설명 문구 내 수치 강조 및 변화 표시
func _highlight_power_in_description(description: String, current_power: float, next_power: float = -1.0) -> String:
	var regex := RegEx.new()
	regex.compile("[0-9]+(\\.[0-9]+)?배")
	var match_result := regex.search(description)
	var is_percent := false
	
	if match_result == null:
		regex.compile("[0-9]+(\\.[0-9]+)?%")
		match_result = regex.search(description)
		is_percent = true

	if match_result == null:
		return description

	var color_hex := UITheme.NEXT_STAT_COLOR.to_html(false)
	var replacement: String
	if next_power >= 0.0:
		replacement = "%s → [color=#%s]%s[/color]" % [
			_format_power(current_power, is_percent), color_hex, _format_power(next_power, is_percent)
		]
	else:
		replacement = "[color=#%s]%s[/color]" % [color_hex, _format_power(current_power, is_percent)]

	return regex.sub(description, replacement, false)


func _format_power(power: float, is_percent: bool = false) -> String:
	var suffix := "%" if is_percent else "배"
	var display_val := power
	if is_percent and power <= 5.0:
		display_val = power * 100.0

	if is_equal_approx(display_val, roundf(display_val)):
		return "%d%s" % [int(round(display_val)), suffix]
	return "%.1f%s" % [display_val, suffix]

	
func _get_party_member(role: String) -> Character:
	var main := get_tree().root.get_node("Main")
	if main.has_method("_find_party_member"):
		return main._find_party_member(role)
	return null


func _get_skill_enabled(role: String, skill_id: String) -> bool:
	var member := _get_party_member(role)
	if member:
		return member.skill_enabled.get(skill_id, true)
	return true


func _on_skill_upgrade_pressed(role: String, skill_id: String, track: String = "power") -> void:
	if GameManager.purchase_skill_upgrade(role, skill_id, track):
		_render_tab()

func _on_learn_skill_pressed(role: String, skill_id: String) -> void:
	if GameManager.learn_character_skill(role, skill_id):
		_render_tab()


func _on_skill_toggled(pressed: bool, role: String, skill_id: String) -> void:
	var member := _get_party_member(role)
	if member:
		member.skill_enabled[skill_id] = pressed


## ---------------- 표(Table) 생성 헬퍼 함수 ----------------

func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UITheme.ACCENT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_list.add_child(label)


func _create_compact_table_grid(cols: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = cols
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	return grid


func _add_table_header(grid: GridContainer, headers: Array[String]) -> void:
	for title in headers:
		var cell := UITheme.create_cell_panel(UITheme.HEADER_BG_COLOR, CELL_PADDING)
		var label := Label.new()
		label.text = title
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_accent_font_color(label)
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(label)
		grid.add_child(cell)
