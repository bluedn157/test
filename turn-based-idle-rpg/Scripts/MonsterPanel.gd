extends Panel

## 몬스터 도감. GameManager.discovered_enemies에 등록된(=실제로 전투에서 만난) 몬스터만
## 이름/스탯/보상을 보여주고, 아직 못 만난 몬스터는 로스터상의 자리만 "???"로 잡아둔다.
## (이름조차 로드하지 않아서, 안 만난 몬스터의 정체가 코드상으로도 새어나가지 않는다)

const CELL_PADDING := 10

const PORTRAIT_SIZE := 64

## 몬스터 이름(EnemyData.enemy_name) -> 초상화 경로.
## Main.gd의 ENEMY_PORTRAIT_PATHS와 같은 매핑이다(몬스터 그림 경로가 EnemyData 리소스
## 자체에는 필드로 없어서 여기서도 별도로 들고 있어야 함).
const ENEMY_PORTRAIT_PATHS := {
	"Slime": "res://Assets/Portraits/slime.png",
	"Bee": "res://Assets/Portraits/bee.png",
	"Goblin King": "res://Assets/Portraits/goblin_king_boss.png",
	"Baller": "res://Assets/Portraits/baller_boss.png",
}

## 미발견 몬스터 자리에 표시할 잠금 아이콘. 실제 몬스터 그림 대신 항상 같은 아이콘만
## 보여줘서 도감을 열기 전엔 어떤 몬스터인지 전혀 알 수 없게 한다.
const LOCKED_ICON_PATH := "res://Assets/StatusIcons/generic.png"

var content_list: VBoxContainer
var title_label: Label

var _portrait_cache: Dictionary = {}
var _locked_icon: Texture2D


func _ready() -> void:
	_build_ui()
	GameManager.enemy_discovered.connect(_render.unbind(1))
	# 예상 스탯/보상이 "현재 던전 기준"이라 던전을 옮기면 미리보기 수치도 다시 계산해야 한다.
	GameManager.dungeon_changed.connect(_render)
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

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", UITheme.ACCENT_COLOR)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	content_list = VBoxContainer.new()
	content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_list.add_theme_constant_override("separation", 8)
	scroll.add_child(content_list)


func _render() -> void:
	var all_paths := GameManager.get_all_enemy_paths()

	var discovered_count := 0
	for path in all_paths:
		if GameManager.is_enemy_discovered(path):
			discovered_count += 1
	title_label.text = "몬스터 도감 (%d / %d 발견)" % [discovered_count, all_paths.size()]

	for child in content_list.get_children():
		child.queue_free()

	if all_paths.is_empty():
		var empty_label := Label.new()
		empty_label.text = "등록된 몬스터가 없습니다."
		empty_label.modulate = Color(1, 1, 1, 0.6)
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_list.add_child(empty_label)
		return

	for path in all_paths:
		content_list.add_child(_build_monster_card(path))


func _build_monster_card(enemy_path: String) -> Control:
	var discovered := GameManager.is_enemy_discovered(enemy_path)

	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.ROW_BG_COLOR if discovered else UITheme.LOCKED_ROW_BG_COLOR
	card_style.border_color = UITheme.CARD_BORDER_COLOR
	card_style.set_border_width_all(UITheme.CARD_BORDER_WIDTH)
	card_style.content_margin_left = CELL_PADDING
	card_style.content_margin_right = CELL_PADDING
	card_style.content_margin_top = CELL_PADDING
	card_style.content_margin_bottom = CELL_PADDING
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(portrait_frame)

	var portrait_box := CenterContainer.new()
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_box)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE - UITheme.PORTRAIT_INNER_MARGIN * 2, PORTRAIT_SIZE - UITheme.PORTRAIT_INNER_MARGIN * 2)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	if not discovered:
		portrait.texture = _get_locked_icon()
		portrait.modulate = Color(0.5, 0.5, 0.55)
		UITheme.style_portrait_frame(portrait_frame)

		var name_label := Label.new()
		name_label.text = "??? (미발견)"
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_child(name_label)

		var hint_label := Label.new()
		hint_label.text = "아직 전투에서 만나지 않은 몬스터입니다."
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		hint_label.modulate = Color(1, 1, 1, 0.55)
		hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_child(hint_label)

		return card

	# ---- 여기부터는 이미 만난 몬스터라 리소스를 읽어서 실제 정보를 보여준다 ----
	var data: EnemyData = load(enemy_path)
	portrait.texture = _get_portrait(data.enemy_name)
	UITheme.style_portrait_frame(portrait_frame, data.is_boss)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = data.enemy_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UITheme.ACCENT_COLOR)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_label)

	if data.is_boss:
		var boss_tag := Label.new()
		boss_tag.text = "BOSS"
		boss_tag.add_theme_font_size_override("font_size", 11)
		boss_tag.add_theme_color_override("font_color", UITheme.BOSS_TAG_COLOR)
		boss_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(boss_tag)

	var dungeon: int = GameManager.current_dungeon
	var stat_mult := GameManager.get_dungeon_enemy_stat_multiplier(dungeon)
	var reward_mult := GameManager.get_dungeon_enemy_reward_multiplier(dungeon)
	var color_hex := UITheme.NEXT_STAT_COLOR.to_html(false)
	var gold_hex := UITheme.GOLD_COLOR.to_html(false)
	var crystal_hex := UITheme.CRYSTAL_COLOR.to_html(false)

	var stat_label := RichTextLabel.new()
	stat_label.bbcode_enabled = true
	stat_label.fit_content = true
	stat_label.scroll_active = false
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_label.text = (
		"HP %d / ATK %d / DEF %d / SPD %d  [color=#%s](%d던전 기준)[/color]\n" +
		"보상 [color=#%s]Gold %d[/color] / [color=#%s]Crystal %d[/color]"
	) % [
		int(data.max_hp * stat_mult), int(data.atk * stat_mult), int(data.def * stat_mult), data.spd,
		color_hex, dungeon,
		gold_hex, int(data.gold_reward * reward_mult), crystal_hex, int(data.crystal_reward),
	]
	info_vbox.add_child(stat_label)

	return card


func _get_portrait(enemy_name: String) -> Texture2D:
	if not ENEMY_PORTRAIT_PATHS.has(enemy_name):
		return null
	var path: String = ENEMY_PORTRAIT_PATHS[enemy_name]
	if not _portrait_cache.has(path):
		_portrait_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _portrait_cache[path]


func _get_locked_icon() -> Texture2D:
	if _locked_icon == null and ResourceLoader.exists(LOCKED_ICON_PATH):
		_locked_icon = load(LOCKED_ICON_PATH)
	return _locked_icon
