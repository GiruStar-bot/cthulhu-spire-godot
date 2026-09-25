extends Control

## 5階層ごとの「主催者つきバフイベント」。
## 背景は直前の画面のものをそのまま使い（GameState.blessing_backdrop）、UI だけ重ねる。
## 左下に主催者の上半身 → 頭の右に吹き出し（タイプライター）→ 中央にパネル3枚、その下に文字だけの選択肢。
## 見た目の規則は DialogueEventModal に合わせている。

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const FALLBACK_PORTRAITS := {
	"val": "res://art/pixel/ui/card_back.png",
	"trickster": "res://art/pixel/ui/nyar_gift.png",
}
const BUBBLE_FILL := Color("2A2430")
const ACCENT_BY_HOST := {"val": Color(0.86, 0.84, 0.72), "trickster": Color(0.91, 0.627, 1.0)}
const PORTRAIT_HEIGHT_FRAC := 0.58
const PORTRAIT_MARGIN := 24.0
const PORTRAIT_FADE_IN_SEC := 0.4
const TYPE_MS := 45
const BUBBLE_MAX_W := 340.0
const BUBBLE_PAD := 14.0
const PANEL_SIZE := Vector2(240, 230)
const PANEL_GAP := 20.0
const PANEL_TOP := 64.0
const CHOICE_GAP := 36.0
const CHOICE_ALPHA := 0.85
const CHOICE_HOVER_ALPHA := 1.0
const FADE_IN_SEC := 0.5
const OUTRO_FADE_SEC := 0.45
const REVEAL_CARD_SIZE := Vector2(200, 300)
const REVEAL_SEC := 1.4
const REVEAL_HOLD_SEC := 0.7

@onready var background_art: TextureRect = $BackgroundArt

var _host: String = ""
var _offers: Array = []
var _layer: Control
var _portrait: TextureRect
var _bubble: PanelContainer
var _bubble_label: Label
var _panels: Array = []
var _text_choices: Array = []
var _typing := false
var _advance_requested := false
var _choosing := false
var _done := false


func _ready() -> void:
	_host = GameState.blessing_host
	_offers = GameState.blessing_offers
	if GameState.blessing_backdrop != null:
		background_art.texture = GameState.blessing_backdrop
	if _host == "" or _offers.is_empty():
		## 直接開かれた等で中身が無い：そのまま次へ
		GameState.finish_blessing.call_deferred(get_tree())
		return
	_build()
	call_deferred("_run_intro")


func _unhandled_input(event: InputEvent) -> void:
	if not _typing:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo):
		_advance_requested = true
		get_viewport().set_input_as_handled()


func _host_def() -> Dictionary:
	return Blessings.HOSTS.get(_host, {})


func _build() -> void:
	_layer = Control.new()
	_layer.name = "HostLayer"
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	_portrait = TextureRect.new()
	_portrait.name = "HostPortrait"
	_portrait.texture = _portrait_texture()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.modulate.a = 0.0
	_layer.add_child(_portrait)

	_bubble = PanelContainer.new()
	_bubble.name = "SpeechBubble"
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BUBBLE_FILL
	sb.content_margin_left = BUBBLE_PAD
	sb.content_margin_right = BUBBLE_PAD
	sb.content_margin_top = BUBBLE_PAD
	sb.content_margin_bottom = BUBBLE_PAD + 4.0
	_bubble.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(inner)
	_bubble_label = Label.new()
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.add_theme_font_size_override("font_size", 20)
	_bubble_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.98))
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_bubble_label)
	var underline := ColorRect.new()
	underline.custom_minimum_size = Vector2(0, 1)
	underline.color = _accent()
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(underline)
	_layer.add_child(_bubble)

	for i in _offers.size():
		_panels.append(_make_panel(i, _offers[i]))
	if _host == Blessings.HOST_VAL:
		_text_choices.append(_make_text_choice("%sに会いたくない" % Blessings.VAL_DISPLAY_NAME, _on_decline))
		_text_choices.append(_make_text_choice("撤退する？", _on_retreat))
	_layout()


func _portrait_texture() -> Texture2D:
	var path: String = str(_host_def().get("portrait", ""))
	if path != "" and ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var fallback: String = str(FALLBACK_PORTRAITS.get(_host, ""))
	if fallback == "" or not ResourceLoader.exists(fallback, "Texture2D"):
		fallback = "res://art/pixel/ui/card_back.png"
	return load(fallback) as Texture2D


func _accent() -> Color:
	return ACCENT_BY_HOST.get(_host, Color(0.86, 0.84, 0.72))


## バフパネル（旧 Blessing 画面のボタン表現を枠付きにしたもの）
func _make_panel(index: int, offer: Dictionary) -> Button:
	var button := Button.new()
	button.name = "OfferPanel%d" % index
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.06, 0.08, 0.9)
	normal.set_border_width_all(2)
	normal.border_color = _accent().darkened(0.35)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = _accent()
	hover.bg_color = Color(0.11, 0.09, 0.12, 0.95)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = str(offer.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  ## 句読点・長音を行頭に置かない
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := Label.new()
	text.text = str(offer.get("text", ""))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 15)
	text.add_theme_color_override("font_color", Color(0.72, 0.66, 0.52))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	col.add_child(text)
	button.add_child(col)
	button.modulate.a = 0.0
	button.visible = false
	button.pressed.connect(_on_offer_pressed.bind(index))
	_layer.add_child(button)
	return button


## 文字だけの選択肢（DialogueEventModal の選択肢と同じ見た目。少し小さめ）
func _make_text_choice(label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 20)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.93, 0.89, 0.84))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	button.add_theme_constant_override("outline_size", 6)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.modulate.a = 0.0
	button.visible = false
	button.pressed.connect(handler)
	button.mouse_entered.connect(_on_choice_hover.bind(button, true))
	button.mouse_exited.connect(_on_choice_hover.bind(button, false))
	_layer.add_child(button)
	return button


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	## 立ち絵：左下
	var ph: float = vp.y * PORTRAIT_HEIGHT_FRAC
	var aspect: float = 2.0 / 3.0
	if _portrait.texture != null and _portrait.texture.get_size().y > 0.0:
		aspect = _portrait.texture.get_size().x / _portrait.texture.get_size().y
	var pw: float = ph * aspect
	_place(_portrait, Rect2(PORTRAIT_MARGIN, vp.y - ph, pw, ph))
	## 吹き出し：頭の右
	var bubble_w: float = minf(BUBBLE_MAX_W, vp.x * 0.3)
	_bubble_label.custom_minimum_size = Vector2(bubble_w - BUBBLE_PAD * 2.0, 0)
	_bubble.reset_size()
	var bubble_h: float = maxf(_bubble.get_combined_minimum_size().y, 72.0)
	var head_y: float = vp.y - ph + ph * 0.18
	var bx: float = PORTRAIT_MARGIN + pw * 0.62 + 12.0
	var by: float = clampf(head_y - bubble_h * 0.35, 24.0, vp.y - bubble_h - 24.0)
	var bubble_rect := Rect2(bx, by, bubble_w, bubble_h)
	_place(_bubble, bubble_rect)
	## パネル：立ち絵より右の残り幅の中央
	var area_left: float = PORTRAIT_MARGIN + pw + 24.0
	var n: int = _panels.size()
	var row_w: float = PANEL_SIZE.x * n + PANEL_GAP * maxi(0, n - 1)
	var panel_w: float = PANEL_SIZE.x
	if row_w > vp.x - area_left - 24.0:
		panel_w = (vp.x - area_left - 24.0 - PANEL_GAP * maxi(0, n - 1)) / float(maxi(1, n))
		row_w = panel_w * n + PANEL_GAP * maxi(0, n - 1)
	var center_x: float = area_left + (vp.x - area_left) * 0.5
	var row_x: float = center_x - row_w * 0.5
	for i in n:
		_place(_panels[i], Rect2(row_x + i * (panel_w + PANEL_GAP), PANEL_TOP, panel_w, PANEL_SIZE.y))
	## 文字選択肢：パネルの下。吹き出しと重なる高さなら右へずらす
	if _text_choices.is_empty():
		return
	var sizes: Array = []
	var total_w: float = 0.0
	for b in _text_choices:
		(b as Button).reset_size()
		var sz: Vector2 = (b as Button).get_combined_minimum_size()
		sizes.append(sz)
		total_w += sz.x
	total_w += CHOICE_GAP * (_text_choices.size() - 1)
	var cy: float = PANEL_TOP + PANEL_SIZE.y + 20.0
	var cx: float = center_x - total_w * 0.5
	var choice_h: float = (sizes[0] as Vector2).y
	if cy < bubble_rect.end.y and cy + choice_h > bubble_rect.position.y:
		cx = maxf(cx, bubble_rect.end.x + 24.0)
	cx = minf(cx, vp.x - total_w - 16.0)
	for i in _text_choices.size():
		var sz2: Vector2 = sizes[i]
		_place(_text_choices[i], Rect2(cx, cy, sz2.x, sz2.y))
		cx += sz2.x + CHOICE_GAP


func _place(c: Control, r: Rect2) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = r.position
	c.size = r.size
	c.custom_minimum_size = r.size


func _run_intro() -> void:
	var tw := create_tween()
	tw.tween_property(_portrait, "modulate:a", 1.0, PORTRAIT_FADE_IN_SEC)
	await tw.finished
	_bubble.visible = true
	await _typewriter(str(_host_def().get("line", "")))
	var tw2 := create_tween().set_parallel(true)
	for c in _panels + _text_choices:
		(c as Control).visible = true
		tw2.tween_property(c, "modulate:a", CHOICE_ALPHA if _text_choices.has(c) else 1.0, FADE_IN_SEC)
	await tw2.finished
	_choosing = true


func _typewriter(full_text: String) -> void:
	_typing = true
	_advance_requested = false
	for i in full_text.length():
		if _advance_requested or _done:
			break
		_bubble_label.text = full_text.substr(0, i + 1)
		if AudioManager != null:
			AudioManager.play_sfx("gift_type")
		await get_tree().create_timer(float(TYPE_MS) / 1000.0).timeout
	_bubble_label.text = full_text
	_typing = false


func _on_choice_hover(button: Button, hovering: bool) -> void:
	if _choosing:
		button.modulate.a = CHOICE_HOVER_ALPHA if hovering else CHOICE_ALPHA


func _on_offer_pressed(index: int) -> void:
	if not _choosing or _done:
		return
	_choosing = false
	var result: Dictionary = GameState.apply_blessing_offer(_offers[index])
	var card_id: String = str(result.get("card_id", ""))
	if card_id != "":
		await _reveal_card(card_id)
	await _fade_out()
	GameState.finish_blessing(get_tree())


func _on_decline() -> void:
	if not _choosing or _done:
		return
	_choosing = false
	await _fade_out()
	GameState.decline_blessing_host(get_tree())


func _on_retreat() -> void:
	if not _choosing or _done:
		return
	_choosing = false
	await _fade_out()
	GameState.extract_to_hub(get_tree())


## 魔導書／戯神ちゃん：選択肢が消え、中央にそのカードがうっすら現れて徐々にはっきりする。
func _reveal_card(card_id: String) -> void:
	var tw := create_tween().set_parallel(true)
	for c in _panels + _text_choices + [_bubble]:
		tw.tween_property(c, "modulate:a", 0.0, 0.3)
	await tw.finished
	var vp: Vector2 = get_viewport_rect().size
	var card: CombatCard = COMBAT_CARD.new()
	card.name = "RevealCard"
	card.custom_minimum_size = REVEAL_CARD_SIZE
	card.size = REVEAL_CARD_SIZE
	card.position = Vector2(vp.x * 0.5, vp.y * 0.45) - REVEAL_CARD_SIZE * 0.5
	card.modulate.a = 0.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(card)
	card.configure({"uid": "", "defId": card_id}, Cards.get_card(card_id), true, false, false)
	var tw2 := create_tween()
	tw2.tween_property(card, "modulate:a", 1.0, REVEAL_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw2.finished
	await get_tree().create_timer(REVEAL_HOLD_SEC).timeout


func _fade_out() -> void:
	_done = true
	var tw := create_tween()
	tw.tween_property(_layer, "modulate:a", 0.0, OUTRO_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
