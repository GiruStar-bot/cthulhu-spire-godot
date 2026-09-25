extends Control

## HUB の「羅針盤」「超越羅針盤」タブ。mode で切り替える。
## element  ：中心から火・水・風・地の4枝（斜め十字）。通貨はステータスポイント。
## transcend：上半分が旧神（白ポイント）、下半分が戯神（黒ポイント）。
## マスは Button（ホバー/タップで効果名）、枝の線は Board の draw で描く。
## 取得・リセットの判定と保存は GameState（Compass の純粋ロジック）に任せる。

signal compass_changed

@export_enum("element", "transcend") var mode: String = "element"

const NODE_SIZES := {"s": 24.0, "m": 32.0, "l": 44.0}
const CENTER_SIZE := 48.0
const BOARD_MARGIN := 52.0

const BRANCH_COLORS := {
	"fire": Color("d0583e"),
	"water": Color("3f8fd0"),
	"wind": Color("7cc28a"),
	"earth": Color("c09a52"),
	"elder": Color("efe6c4"),
	"trickster": Color("9a5fd0"),
}
## 4元素は斜め十字。y は下向きが正。
const ELEMENT_DIRS := {
	"fire": Vector2(-1, -1),
	"water": Vector2(1, -1),
	"earth": Vector2(-1, 1),
	"wind": Vector2(1, 1),
}
const LOCKED_BORDER := Color(0.32, 0.30, 0.27, 0.9)
const LOCKED_FILL := Color(0.07, 0.065, 0.06, 0.85)
const LINE_DIM := Color(0.30, 0.28, 0.24, 0.55)

@onready var title_label: Label = $Layout/HeaderRow/TitleLabel
@onready var points_label: Label = $Layout/HeaderRow/PointsLabel
@onready var debug_white_button: Button = $Layout/HeaderRow/DebugWhiteButton
@onready var debug_black_button: Button = $Layout/HeaderRow/DebugBlackButton
@onready var reset_button: Button = $Layout/HeaderRow/ResetButton
@onready var board: Control = $Layout/BoardFrame/Board
@onready var info_label: Label = $Layout/InfoLabel

var _buttons: Dictionary = {}  ## node_id -> Button
var _branch_labels: Dictionary = {}  ## branch -> Label
var _center: Label = null
var _hovered: String = ""


func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	board.draw.connect(_on_board_draw)
	board.resized.connect(_layout_board)
	var debug: bool = OS.is_debug_build() and mode == "transcend"
	debug_white_button.visible = debug
	debug_black_button.visible = debug
	debug_white_button.pressed.connect(_on_debug_points.bind("elder"))
	debug_black_button.pressed.connect(_on_debug_points.bind("trickster"))
	_build_board()
	refresh()


func _branches() -> Array:
	return Compass.TRANSCEND_SIDES if mode == "transcend" else Compass.ELEMENTS


func _owned() -> Array:
	return GameState.transcend_nodes if mode == "transcend" else GameState.compass_nodes


func _points_left(branch: String) -> int:
	if mode == "transcend":
		return GameState.transcend_points_left(branch)
	return GameState.unspent_points


func _build_board() -> void:
	_center = Label.new()
	_center.text = "超越" if mode == "transcend" else "羅"
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.size = Vector2(CENTER_SIZE, CENTER_SIZE)
	_center.add_theme_font_size_override("font_size", 13 if mode == "transcend" else 20)
	_center.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66))
	var center_style := StyleBoxFlat.new()
	center_style.bg_color = Color(0.10, 0.08, 0.05, 0.95)
	center_style.border_color = Color(0.78, 0.64, 0.38)
	center_style.set_border_width_all(3)
	center_style.set_corner_radius_all(int(CENTER_SIZE / 2.0))
	_center.add_theme_stylebox_override("normal", center_style)
	board.add_child(_center)
	for branch in _branches():
		var tag := Label.new()
		tag.text = str(Compass.BRANCH_LABELS[branch])
		tag.add_theme_font_size_override("font_size", 18)
		tag.add_theme_color_override("font_color", BRANCH_COLORS[branch])
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("outline_size", 4)
		board.add_child(tag)
		_branch_labels[branch] = tag
		for id in Compass.node_ids(str(branch)):
			var button := Button.new()
			var size: float = NODE_SIZES[Compass.size_of(str(id))]
			button.custom_minimum_size = Vector2(size, size)
			button.size = Vector2(size, size)
			button.focus_mode = Control.FOCUS_NONE
			button.tooltip_text = Compass.effect_text(str(id))
			button.add_theme_font_size_override("font_size", 12 if size < 40.0 else 15)
			button.mouse_entered.connect(_on_node_hover.bind(str(id)))
			button.pressed.connect(_on_node_pressed.bind(str(id)))
			board.add_child(button)
			_buttons[id] = button
			_style_node(str(id), _owned())
	_layout_board()


## 中心からの位置。4元素は斜め十字、超越は上下の縦一列。
func _node_position(branch: String, index: int) -> Vector2:
	var half: Vector2 = board.size / 2.0
	var steps: int = Compass.sizes_of(branch).size()
	if mode == "transcend":
		var reach_v: float = maxf(0.0, half.y - BOARD_MARGIN)
		var sign_y: float = -1.0 if branch == "elder" else 1.0
		return half + Vector2(0, sign_y * reach_v * float(index) / float(steps))
	var dir: Vector2 = ELEMENT_DIRS[branch]
	var reach: Vector2 = Vector2(maxf(0.0, half.x - BOARD_MARGIN), maxf(0.0, half.y - BOARD_MARGIN))
	## 縦横で同じ歩幅にする（斜め45度のまま、狭い方の辺に合わせる）
	var r: float = minf(reach.x, reach.y)
	return half + dir * r * float(index) / float(steps)


func _layout_board() -> void:
	if _center == null:
		return
	_center.position = board.size / 2.0 - _center.size / 2.0
	for branch in _branches():
		var steps: int = Compass.sizes_of(str(branch)).size()
		for i in steps:
			var id: String = Compass.node_id(str(branch), i + 1)
			var button: Button = _buttons[id]
			## Hub のテーマの余白で広がった分を戻して正円にする
			button.size = button.custom_minimum_size
			button.position = _node_position(str(branch), i + 1) - button.size / 2.0
		var tag: Label = _branch_labels[branch]
		var tip: Vector2 = _node_position(str(branch), steps)
		tag.reset_size()
		var end_radius: float = float(NODE_SIZES["l"]) / 2.0
		var offset: Vector2
		if mode == "transcend":
			offset = Vector2(end_radius + 10.0 + tag.size.x / 2.0, 0.0)
		else:
			## 終点の外側（左右）に置く。上下はマスと同じ高さ
			var side: float = signf((tip - board.size / 2.0).x)
			offset = Vector2(side * (end_radius + 10.0 + tag.size.x / 2.0), 0.0)
		tag.position = tip + offset - tag.size / 2.0
	board.queue_redraw()


func _on_board_draw() -> void:
	var owned: Array = _owned()
	var center: Vector2 = board.size / 2.0
	for branch in _branches():
		var prev: Vector2 = center
		var color: Color = BRANCH_COLORS[branch]
		for i in Compass.sizes_of(str(branch)).size():
			var id: String = Compass.node_id(str(branch), i + 1)
			var pos: Vector2 = _node_position(str(branch), i + 1)
			var lit: bool = owned.has(id)
			board.draw_line(prev, pos, color if lit else LINE_DIM, 5.0 if lit else 3.0, true)
			prev = pos


func refresh() -> void:
	if not is_node_ready():
		return
	var owned: Array = _owned()
	if mode == "transcend":
		title_label.text = "超越羅針盤"
		points_label.text = "白ポイント %d / %d　　黒ポイント %d / %d" % [
			GameState.transcend_points_left("elder"), GameState.white_points,
			GameState.transcend_points_left("trickster"), GameState.black_points,
		]
	else:
		title_label.text = "羅針盤"
		points_label.text = "ステータスポイント %d / %d" % [GameState.unspent_points, GameState.total_points()]
	reset_button.disabled = owned.is_empty()
	for id in _buttons.keys():
		_style_node(str(id), owned)
	_show_info(_hovered)
	board.queue_redraw()


## 3状態：取得済み＝塗り、取得可能＝枝色の縁、未解放＝灰色。
func _node_state(id: String, owned: Array) -> String:
	if owned.has(id):
		return "owned"
	if Compass.can_take(owned, id):
		return "open"
	return "locked"


func _style_node(id: String, owned: Array) -> void:
	var button: Button = _buttons[id]
	var branch: String = Compass.branch_of(id)
	var color: Color = BRANCH_COLORS[branch]
	var state: String = _node_state(id, owned)
	var size: String = Compass.size_of(id)
	button.text = "" if size == "s" else ("中" if size == "m" else str(Compass.BRANCH_LABELS[branch]).substr(0, 1))
	var normal := StyleBoxFlat.new()
	normal.set_content_margin_all(0.0)
	normal.set_corner_radius_all(int(button.custom_minimum_size.x / 2.0))
	normal.anti_aliasing = true
	match state:
		"owned":
			normal.bg_color = color
			normal.border_color = color.lightened(0.45)
			normal.set_border_width_all(3)
			normal.shadow_color = Color(color, 0.55)
			normal.shadow_size = 6
			button.add_theme_color_override("font_color", Color(0.08, 0.06, 0.05))
			button.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.05))
		"open":
			normal.bg_color = Color(0.09, 0.08, 0.07, 0.95)
			normal.border_color = color
			normal.set_border_width_all(3)
			button.add_theme_color_override("font_color", color)
			button.add_theme_color_override("font_hover_color", color.lightened(0.3))
		_:
			normal.bg_color = LOCKED_FILL
			normal.border_color = LOCKED_BORDER
			normal.set_border_width_all(2)
			button.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
			button.add_theme_color_override("font_hover_color", Color(0.6, 0.56, 0.5))
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = normal.border_color.lightened(0.35)
	hover.set_border_width_all(4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", normal)


func _on_node_hover(id: String) -> void:
	_hovered = id
	_show_info(id)


func _show_info(id: String) -> void:
	if id == "":
		info_label.text = "マスにカーソルを合わせる（タップする）と効果を表示。中心に近いマスから順に1ポイントずつ取れる。"
		if GameState.floor > 0:
			info_label.text += "\n変更は次の潜航から反映される。"
		return
	var owned: Array = _owned()
	var state: String = _node_state(id, owned)
	var note: String = ""
	match state:
		"owned":
			note = "取得済み"
		"open":
			note = "取得できる（1ポイント）" if _points_left(Compass.branch_of(id)) > 0 else "ポイントが足りない"
		_:
			note = "未解放（手前のマスを先に取る）"
	info_label.text = "%s\n%s" % [Compass.effect_text(id), note]
	if GameState.floor > 0:
		info_label.text += "　／　変更は次の潜航から反映される"


func _on_node_pressed(id: String) -> void:
	_hovered = id
	var taken: bool = false
	if mode == "transcend":
		taken = GameState.take_transcend_node(id)
	else:
		taken = GameState.take_compass_node(id)
	if taken:
		compass_changed.emit()
	refresh()


func _on_reset_pressed() -> void:
	if mode == "transcend":
		GameState.reset_transcend()
	else:
		GameState.reset_compass()
	compass_changed.emit()
	refresh()


## 開発ビルドだけ：白・黒ポイントを1ずつ付与する（獲得イベントは未実装のため）。
func _on_debug_points(side: String) -> void:
	if not OS.is_debug_build():
		return
	if side == "elder":
		GameState.add_white_points(1)
	else:
		GameState.add_black_points(1)
	refresh()
