extends Control

## 5階層ごとの「主催者つきバフイベント」。
## 背景は直前の画面のものをそのまま使い（GameState.blessing_backdrop）、UI だけ重ねる。
## 左下に主催者の上半身 → 頭の右に吹き出し（タイプライター）→ 中央にパネル3枚。
## 「会いたくない」「撤退する」もパネルの1枚として出る（Blessings.roll_offers）。

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const FALLBACK_PORTRAITS := {
	"val": "res://art/pixel/ui/card_back.png",
	"trickster": "res://art/pixel/ui/nyar_gift.png",
}
const ACCENT_BY_HOST := {"val": Color(0.86, 0.84, 0.72), "trickster": Color(0.91, 0.627, 1.0)}
## 立ち絵の高さ（画面比）。上半身の正方形の絵は横に広いので低めにして、パネルの高さと重ねない
const PORTRAIT_HEIGHT_FRAC := 0.58
const PORTRAIT_HEIGHT_FRAC_WIDE := 0.5
## 吹き出しの位置（立ち絵の幅・高さに対する割合）。上半身の絵は頭が大きいので右・下寄り
const BUBBLE_X_FRAC := 0.62
const BUBBLE_X_FRAC_WIDE := 0.8
const HEAD_Y_FRAC := 0.18
const HEAD_Y_FRAC_WIDE := 0.26
const WIDE_ASPECT := 0.8
const PORTRAIT_MARGIN := 24.0
const PORTRAIT_FADE_IN_SEC := 0.4
const TYPE_MS := 45
## パネルはタイトルだけ（効果文は出さない＝選んだ後に起きることを先に見せない）
const PANEL_SIZE := Vector2(280, 72)  ## 高さは最小値。いちばん長いタイトルに合わせて伸ばす
const PANEL_FONT := 18
const PANEL_PAD := 14.0
const PANEL_GAP := 20.0
const PANEL_TOP := 64.0
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
var _bubble: SpeechBubble
var _panels: Array = []
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

	_bubble = SpeechBubble.new()
	_bubble.name = "SpeechBubble"
	_bubble.visible = false
	_bubble.accent = _accent()
	_bubble.tail_side = "left"  ## 話者（立ち絵の頭）は吹き出しの左
	_layer.add_child(_bubble)
	## 木に入れてから測る（プロジェクトのフォントで幅を決めるため）
	_bubble.fit_to_text(str(_host_def().get("line", "")))
	_bubble.set_text("")

	for i in _offers.size():
		_panels.append(_make_panel(i, _offers[i]))
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
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PANEL_PAD)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.name = "Title"
	title.text = _title_lines(str(offer.get("title", "")))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  ## 句読点・長音を行頭に置かない
	title.add_theme_font_size_override("font_size", PANEL_FONT)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	button.add_child(col)
	button.modulate.a = 0.0
	button.visible = false
	button.pressed.connect(_on_offer_pressed.bind(index))
	_layer.add_child(button)
	return button


## 1行に収まらない長い文は「、」で改行する（「会いたくな／い」のような切れ方を避ける）。
func _title_lines(text: String) -> String:
	var font: Font = get_theme_default_font()
	var inner_w: float = PANEL_SIZE.x - PANEL_PAD * 2.0
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PANEL_FONT).x <= inner_w:
		return text
	var cut: int = text.find("、")
	if cut < 0:
		return text
	return text.substr(0, cut + 1) + "\n" + text.substr(cut + 1)


## いちばん長いタイトルが収まる高さ（全パネル共通）。フォントで直接測る（配置前の Label は幅が決まっていないため）。
func _panel_height(panel_w: float) -> float:
	var font: Font = get_theme_default_font()
	var h: float = PANEL_SIZE.y
	for p in _panels:
		var title: Label = (p as Control).find_child("Title", true, false) as Label
		if title == null:
			continue
		var text_h: float = font.get_multiline_string_size(title.text, HORIZONTAL_ALIGNMENT_CENTER, panel_w - PANEL_PAD * 2.0, PANEL_FONT).y
		h = maxf(h, text_h + PANEL_PAD * 2.0 + 16.0)
	return h


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	## 立ち絵：左下
	var aspect: float = 2.0 / 3.0
	if _portrait.texture != null and _portrait.texture.get_size().y > 0.0:
		aspect = _portrait.texture.get_size().x / _portrait.texture.get_size().y
	var wide: bool = aspect >= WIDE_ASPECT
	var ph: float = vp.y * (PORTRAIT_HEIGHT_FRAC_WIDE if wide else PORTRAIT_HEIGHT_FRAC)
	var pw: float = ph * aspect
	_place(_portrait, Rect2(PORTRAIT_MARGIN, vp.y - ph, pw, ph))
	## 吹き出し：頭の右。大きさはセリフに合わせて SpeechBubble が決める。しっぽの先が頭の横に来るよう置く
	var bubble_size: Vector2 = _bubble.size
	var head_y: float = vp.y - ph + ph * (HEAD_Y_FRAC_WIDE if wide else HEAD_Y_FRAC)
	var bx: float = PORTRAIT_MARGIN + pw * (BUBBLE_X_FRAC_WIDE if wide else BUBBLE_X_FRAC) + 8.0 + SpeechBubble.TAIL_LEN
	var by: float = clampf(head_y - bubble_size.y * _bubble.tail_y_frac, 24.0, vp.y - bubble_size.y - 24.0)
	_bubble.set_anchor_position(Vector2(bx, by))
	## パネル：立ち絵と同じ高さにかかるなら立ち絵より右の残り幅、かからなければ画面幅の中央
	## 下に文字の選択肢が無いので、立ち絵より上の空きの中で縦中央に置く（上端は PANEL_TOP 以上）
	var area_left: float = PORTRAIT_MARGIN + pw + 24.0
	var panel_top: float = PANEL_TOP
	var panel_h: float = _panel_height(PANEL_SIZE.x)
	if PANEL_TOP + panel_h + 12.0 <= vp.y - ph:
		area_left = 24.0
		panel_top = maxf(PANEL_TOP, (vp.y - ph - panel_h) * 0.5)
	var n: int = _panels.size()
	var row_w: float = PANEL_SIZE.x * n + PANEL_GAP * maxi(0, n - 1)
	var panel_w: float = PANEL_SIZE.x
	if row_w > vp.x - area_left - 24.0:
		panel_w = (vp.x - area_left - 24.0 - PANEL_GAP * maxi(0, n - 1)) / float(maxi(1, n))
		row_w = panel_w * n + PANEL_GAP * maxi(0, n - 1)
	var center_x: float = area_left + (vp.x - area_left) * 0.5
	var row_x: float = center_x - row_w * 0.5
	for i in n:
		_place(_panels[i], Rect2(row_x + i * (panel_w + PANEL_GAP), panel_top, panel_w, panel_h))


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
	for c in _panels:
		(c as Control).visible = true
		tw2.tween_property(c, "modulate:a", 1.0, FADE_IN_SEC)
	await tw2.finished
	_choosing = true


func _typewriter(full_text: String) -> void:
	_typing = true
	_advance_requested = false
	for i in full_text.length():
		if _advance_requested or _done:
			break
		_bubble.set_text(full_text.substr(0, i + 1))
		if AudioManager != null:
			AudioManager.play_sfx("gift_type")
		await get_tree().create_timer(float(TYPE_MS) / 1000.0).timeout
	_bubble.set_text(full_text)
	_typing = false


func _on_offer_pressed(index: int) -> void:
	if not _choosing or _done:
		return
	_choosing = false
	var result: Dictionary = GameState.apply_blessing_offer(_offers[index])
	var card_id: String = str(result.get("card_id", ""))
	if card_id != "":
		await _reveal_card(card_id)
	await _fade_out()
	if result.get("retreat", false):
		GameState.extract_to_hub(get_tree())  ## 戦利品を持ったまま拠点へ（全回復）
		return
	GameState.finish_blessing(get_tree())


## 魔導書／戯神ちゃん：選択肢が消え、中央にそのカードがうっすら現れて徐々にはっきりする。
func _reveal_card(card_id: String) -> void:
	var tw := create_tween().set_parallel(true)
	for c in _panels + [_bubble]:
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
