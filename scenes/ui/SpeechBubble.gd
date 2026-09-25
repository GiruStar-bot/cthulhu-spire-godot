class_name SpeechBubble
extends Control

## 吹き出し部品：角丸の枠＋半透明の暗い地＋話者の方向を指すしっぽ（三角）。
## 幅はセリフの長さに合わせて MIN_W〜MAX_W で伸縮し、MAX_W を超える分は折り返す。
## anchor（基準位置）を中心に、上下に AMPLITUDE px ふわふわ浮く。
## いまはバフイベント（Blessing）だけが使う。DialogueEventModal／OuterGiftModal は各自の吹き出しのまま。

const PAD_X := 18.0
const PAD_Y := 12.0
const MIN_W := 96.0
const MAX_W := 340.0
const MIN_H := 48.0
const CORNER := 10
const BORDER := 2
const FILL := Color(0.10, 0.08, 0.12, 0.82)
const TAIL_W := 14.0  ## しっぽの根元の高さ
const TAIL_LEN := 16.0  ## しっぽの長さ（枠から話者側へ突き出す）
const FONT_SIZE := 20
const AMPLITUDE := 3.0
const PERIOD_SEC := 2.5

var accent: Color = Color(0.86, 0.84, 0.72)
## しっぽを出す側："left"（話者が左）／"right"
var tail_side: String = "left"
## しっぽの根元の高さ（吹き出しの高さに対する割合）
var tail_y_frac: float = 0.55

var _label: Label
var _anchor: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _floating: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "BubbleText"
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.98))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


## 全文に合わせて大きさを決める（タイプライター中に枠が伸び縮みしないよう、先に全文で測る）。
func fit_to_text(full_text: String) -> void:
	var font: Font = _label.get_theme_font("font")
	var text_w: float = font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var inner_w: float = clampf(ceilf(text_w) + 2.0, MIN_W - PAD_X * 2.0, MAX_W - PAD_X * 2.0)
	var wraps: bool = text_w + 2.0 > MAX_W - PAD_X * 2.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wraps else TextServer.AUTOWRAP_OFF
	_label.text = full_text
	_label.custom_minimum_size = Vector2(inner_w, 0)
	_label.size = Vector2(inner_w, 0)
	var inner_h: float = _label.get_combined_minimum_size().y
	var w: float = inner_w + PAD_X * 2.0
	var h: float = maxf(inner_h + PAD_Y * 2.0, MIN_H)
	size = Vector2(w, h)
	custom_minimum_size = size
	_label.position = Vector2(PAD_X, (h - inner_h) * 0.5)
	_label.size = Vector2(inner_w, inner_h)
	queue_redraw()


func set_text(text: String) -> void:
	_label.text = text


## 基準位置（浮遊の中心）。
func set_anchor_position(pos: Vector2) -> void:
	_anchor = pos
	position = pos + Vector2(0, _float_offset())


func set_floating(enabled: bool) -> void:
	_floating = enabled


func _float_offset() -> float:
	if not _floating:
		return 0.0
	return sin(_time * TAU / PERIOD_SEC) * AMPLITUDE


func _process(delta: float) -> void:
	_time += delta
	position = _anchor + Vector2(0, _float_offset())


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FILL
	sb.border_color = accent
	sb.set_border_width_all(BORDER)
	sb.set_corner_radius_all(CORNER)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	## しっぽ：枠の外へ三角を出し、根元は枠の縁を塗りつぶして継ぎ目を消す
	var y0: float = clampf(size.y * tail_y_frac, CORNER + TAIL_W * 0.5, size.y - CORNER - TAIL_W * 0.5)
	var base_x: float = 0.0 if tail_side == "left" else size.x
	var dir: float = -1.0 if tail_side == "left" else 1.0
	var tip := Vector2(base_x + dir * TAIL_LEN, y0 + TAIL_W * 0.6)
	var a := Vector2(base_x + dir * -1.0, y0 - TAIL_W * 0.5)
	var b := Vector2(base_x + dir * -1.0, y0 + TAIL_W * 0.5)
	draw_colored_polygon(PackedVector2Array([a, tip, b]), FILL)
	draw_line(Vector2(base_x, y0 - TAIL_W * 0.5), tip, accent, BORDER, true)
	draw_line(tip, Vector2(base_x, y0 + TAIL_W * 0.5), accent, BORDER, true)
	## 根元の枠線を地の色で上書き（しっぽと本体をつなげる）
	var inner_x: float = base_x - dir * (BORDER * 0.5)
	draw_line(Vector2(inner_x, y0 - TAIL_W * 0.5 + 1.0), Vector2(inner_x, y0 + TAIL_W * 0.5 - 1.0), FILL, BORDER + 1.0)
