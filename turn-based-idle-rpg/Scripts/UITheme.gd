class_name UITheme
extends RefCounted

## 게임 전체가 공유하는 다크 톤 + 노랑 강조색 테마.
## 업그레이드 탭에서 쓰던 톤을 기준으로 삼아, 다른 패널/전투 화면도 여기 값을 가져다 쓴다.
## 색 하나를 바꿔야 할 때 이 파일만 고치면 되도록 하는 게 목적.
##
## 사용법: 인스턴스화하지 않고 UITheme.BORDER_COLOR / UITheme.create_cell_style(...) 처럼
## 클래스 이름으로 바로 접근한다 (const/static func이라 인스턴스가 필요 없음).
##
## build_app_theme()로 만든 Theme를 루트(Main)의 theme 프로퍼티에 한 번만 꽂아두면
## Panel/Button/Label/ProgressBar 등 자식 전체에 자동으로 적용된다(각 노드마다 일일이
## 스타일을 안 줘도 됨). 개별 노드가 다른 색이 필요할 때만(예: HP바=빨강, MP바=파랑)
## add_theme_*_override로 그 노드에서만 덮어쓰면 된다.

# ---- 배경/테두리 팔레트 ----
const PANEL_BG_COLOR := Color("#11111b")  # 패널(전투화면/메뉴/각 탭) 바깥 배경 - 가장 어두움
const BORDER_COLOR := Color("#3f445b")
const HEADER_BG_COLOR := Color("#1e1e2e")
const ROW_BG_COLOR := Color("#181825")
const LOCKED_ROW_BG_COLOR := Color("#111118")  # 잠긴/미발견 항목용 더 어두운 배경

# ---- 카드(스킬 카드, 몬스터 카드 등) 테두리 ----
const CARD_BORDER_COLOR := Color("#6c7086")
const CARD_BORDER_WIDTH := 2

# ---- 강조 텍스트 색 ----
const ACCENT_COLOR := Color("#f9e2af")           # 제목/헤더/이름 등 기본 강조(노랑)
const BOSS_TAG_COLOR := Color("#f38ba8")         # 보스 태그, 위험/경고 문구 등(빨강 계열)
const NEXT_STAT_COLOR := Color(0.45, 1.0, 0.55)  # "다음 레벨" 미리보기 수치 강조(초록)
const TEXT_COLOR := Color("#cdd6f4")             # 본문 기본 텍스트(라이트 그레이)
const DIM_TEXT_COLOR := Color(1, 1, 1, 0.6)      # 설명/보조 텍스트

# ---- 전투 화면 HP/MP 바 ----
const HP_BAR_COLOR := Color("#f38ba8")
const MP_BAR_COLOR := Color("#89b4fa")
const BAR_TRACK_COLOR := LOCKED_ROW_BG_COLOR

# ---- 재화(골드/크리스탈) 공용 색상 ----
# 업그레이드 패널의 "G"/"C" 비용 표시, 상단 골드/크리스탈 라벨, 재화 아이콘까지
# 전부 이 두 값만 참조해서 한 곳만 고치면 게임 전체에 일관되게 반영되게 한다.
const GOLD_COLOR := ACCENT_COLOR    # 골드 = 노랑
const CRYSTAL_COLOR := MP_BAR_COLOR # 크리스탈 = 파랑 (MP 바와 같은 계열)
# 던전 이름은 골드(노랑)와 겹치지 않는 별도의 강조색을 쓴다.
const DUNGEON_NAME_COLOR := Color("#cba6f7")

# ---- 초상화 프레임(전투 유닛, 몬스터 도감 공용) ----
const PORTRAIT_BG_COLOR := HEADER_BG_COLOR
const PORTRAIT_BORDER_COLOR := CARD_BORDER_COLOR
const PORTRAIT_BORDER_WIDTH := 2
const PORTRAIT_CORNER_RADIUS := 6
const PORTRAIT_INNER_MARGIN := 3
const BOSS_PORTRAIT_BORDER_COLOR := BOSS_TAG_COLOR  # 보스는 테두리만 경고색으로 구분
const BOSS_PORTRAIT_BORDER_WIDTH := 3


## 표 칸 하나에 쓰는 StyleBoxFlat을 만든다. padding은 칸마다 원하는 여백이 달라서
## 인자로 받는다(호출부의 기존 CELL_PADDING 값을 그대로 넘기면 됨).
static func create_cell_style(bg: Color, border: Color = BORDER_COLOR, border_width: int = 1, padding: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


## 표 칸 하나를 감싸는 PanelContainer를 만든다.
static func create_cell_panel(bg: Color, padding: int = 8) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_theme_stylebox_override("panel", create_cell_style(bg, BORDER_COLOR, 1, padding))
	return cell


## 골드/크리스탈처럼 텍스트 앞에 붙는 작은 원형 재화 아이콘. 실제 아이콘 이미지가 없는
## 동안 쓰는 자리표시자라 텍스처 대신 완전히 둥근 모서리의 StyleBoxFlat 패널로 만든다.
## 나중에 진짜 아이콘이 생기면 이 함수 안만 텍스처로 바꾸면 전체에 반영된다.
##
## 행 높이 정중앙에 그냥 SHRINK_CENTER로 맞추면, 텍스트는 폰트 하강폭(descender) 때문에
## 시각적 무게중심이 실제 박스 중앙보다 아래에 있어서 원이 글자보다 위로 붙어 보인다.
## 그래서 원을 감싸는 MarginContainer에 위쪽 여백만 줘서 살짝 아래로 밀어 눈에 맞춰준다
## (위/아래 마진 차이의 절반만큼 실제로 이동한다).
#!
const CURRENCY_ICON_VERTICAL_NUDGE := 1

static func create_currency_icon(color: Color, diameter: float = 14.0) -> Control:
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(diameter, diameter)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(diameter / 2.0))
	dot.add_theme_stylebox_override("panel", style)

	var wrapper := MarginContainer.new()
	wrapper.add_theme_constant_override("margin_top", int(CURRENCY_ICON_VERTICAL_NUDGE * 2.0))
	wrapper.add_theme_constant_override("margin_bottom", 0)
	wrapper.add_theme_constant_override("margin_left", 0)
	wrapper.add_theme_constant_override("margin_right", 0)
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(dot)
	return wrapper


## 카드(스킬 카드, 몬스터 카드 등)용 StyleBoxFlat 기본형. content_margin은 호출부에서
## 필요에 따라 덮어써도 된다.
static func create_card_style(bg: Color, border: Color = CARD_BORDER_COLOR, border_width: int = CARD_BORDER_WIDTH) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	return style


## DungeonPanel의 던전 행, SettingsPanel의 섹션 등 "카드 하나"를 감싸는 PanelContainer.
## create_cell_panel과 달리 카드 톤 테두리(CARD_BORDER_COLOR)를 쓰고 패딩이 더 넉넉하다.
static func create_card_panel(bg: Color, border: Color = CARD_BORDER_COLOR, padding: int = 12) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := create_card_style(bg, border)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	card.add_theme_stylebox_override("panel", style)
	return card


## 제목/이름 라벨에 기본 강조색(노랑)을 적용하는 짧은 헬퍼.
static func apply_accent_font_color(label: Label) -> void:
	label.add_theme_color_override("font_color", ACCENT_COLOR)


## 패널/탭 맨 위 큰 제목에 쓰는 스타일(강조색 + 큰 폰트). SettingsPanel/DungeonPanel처럼
## 자체 제목 라벨을 만드는 곳에서 공통으로 쓴다.
static func apply_title_style(label: Label, font_size: int = 18) -> void:
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	label.add_theme_font_size_override("font_size", font_size)


## HP/MP 바처럼 배경(track)+채움(fill) 색이 다른 ProgressBar에 스타일을 입힌다.
static func style_bar(bar: ProgressBar, fill_color: Color) -> void:
	bar.add_theme_stylebox_override("background", create_cell_style(BAR_TRACK_COLOR, BORDER_COLOR, 1, 0))
	bar.add_theme_stylebox_override("fill", create_cell_style(fill_color, fill_color, 0, 0))


## 유닛 초상화를 감싸는 PanelContainer("프레임")에 둥근 테두리 + 어두운 배경을 입혀서,
## 밋밋한 이미지 한 장이 아니라 카드처럼 보이게 다듬는다. 초상화 사이에 살짝 여백
## (PORTRAIT_INNER_MARGIN)을 둬서 이미지가 테두리에 바로 붙지 않게 한다.
## is_boss가 true면 테두리를 경고색(빨강 계열)으로 굵게 둘러서, 이름표를 보기 전에도
## 초상화만으로 보스를 구분할 수 있게 한다. (전투 화면 EnemyUnit / 몬스터 도감 공용)
static func style_portrait_frame(frame: PanelContainer, is_boss: bool = false) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PORTRAIT_BG_COLOR
	style.border_color = BOSS_PORTRAIT_BORDER_COLOR if is_boss else PORTRAIT_BORDER_COLOR
	style.set_border_width_all(BOSS_PORTRAIT_BORDER_WIDTH if is_boss else PORTRAIT_BORDER_WIDTH)
	style.set_corner_radius_all(PORTRAIT_CORNER_RADIUS)
	style.content_margin_left = PORTRAIT_INNER_MARGIN
	style.content_margin_right = PORTRAIT_INNER_MARGIN
	style.content_margin_top = PORTRAIT_INNER_MARGIN
	style.content_margin_bottom = PORTRAIT_INNER_MARGIN
	frame.add_theme_stylebox_override("panel", style)


## 게임 전체 기본 테마. Main.gd가 루트 Control의 theme으로 한 번 꽂아두면 Panel/Button/
## Label/ProgressBar 등 스타일을 따로 지정하지 않은 모든 자식 노드에 자동 적용된다.
static func build_app_theme() -> Theme:
	var theme := Theme.new()

	# Panel: 전투화면/메뉴/각 탭(UpgradePanel 등)의 바깥 배경.
	theme.set_stylebox("panel", "Panel", create_cell_style(PANEL_BG_COLOR, BORDER_COLOR, 1, 0))

	# Button: 기본/호버/눌림/비활성 네 상태 + 상태별 글자색.
	theme.set_stylebox("normal", "Button", create_cell_style(ROW_BG_COLOR, BORDER_COLOR, 1, 8))
	theme.set_stylebox("hover", "Button", create_cell_style(HEADER_BG_COLOR, CARD_BORDER_COLOR, 1, 8))
	theme.set_stylebox("pressed", "Button", create_cell_style(HEADER_BG_COLOR, ACCENT_COLOR, 2, 8))
	theme.set_stylebox("disabled", "Button", create_cell_style(LOCKED_ROW_BG_COLOR, BORDER_COLOR, 1, 8))
	theme.set_color("font_color", "Button", TEXT_COLOR)
	theme.set_color("font_hover_color", "Button", ACCENT_COLOR)
	theme.set_color("font_pressed_color", "Button", ACCENT_COLOR)
	theme.set_color("font_disabled_color", "Button", DIM_TEXT_COLOR)

	# Label: 기본 본문 글자색.
	theme.set_color("font_color", "Label", TEXT_COLOR)

	# ProgressBar: 기본 track/fill(개별 HP/MP 바는 style_bar()로 색만 덮어씀).
	theme.set_stylebox("background", "ProgressBar", create_cell_style(BAR_TRACK_COLOR, BORDER_COLOR, 1, 0))
	theme.set_stylebox("fill", "ProgressBar", create_cell_style(NEXT_STAT_COLOR, NEXT_STAT_COLOR, 0, 0))

	return theme
