extends CanvasLayer
class_name DialogueEventModal

## 立ち絵＋吹き出しで進む会話イベント（OuterGiftModal の演出パターンを流用した汎用版）。
## 立ち絵が中央にフェードイン → 頭横の吹き出し（共通部品 SpeechBubble）にタイプライターで台詞 → 表示し終えて
## LINE_HOLD_SEC 後に吹き出しが自動で消える → 立ち絵の両脇に文字だけの選択肢がうっすら出る。
## reply を持つ選択肢は、選択肢を消して返事を同じ吹き出しで出し、全体をフェードアウトしてから通知する。
## reply の無い選択肢は演出を挟まずすぐ通知する。遷移（GameState 呼び出し）は呼び出し側の責務。
##
## setup() に渡す config:
##   portrait: String  立ち絵（無ければ描かない）
##   background: String  背景（任意。無ければ暗幕のみ）
##   line: String  最初の台詞
##   choices: Array  [{id, label, reply?}]  先頭が立ち絵の左、2つ目が右

signal choice_selected(choice_id: String)

const ACCENT := Color(0.78, 0.32, 0.30)
const PORTRAIT_HEIGHT_FRAC := 0.60
const PORTRAIT_FADE_IN_SEC := 0.4
const TYPE_MS := 45
const LINE_HOLD_SEC := 0.4  ## 全文表示後、この秒数で必ず吹き出しを消す（クリック待ちしない）
const BUBBLE_FADE_SEC := 0.22
const CHOICE_FADE_IN_SEC := 0.6
const CHOICE_FADE_OUT_SEC := 0.25
const CHOICE_ALPHA := 0.85  ## 影のようにうっすら（ただし読める濃さ）
const CHOICE_HOVER_ALPHA := 1.0
const OUTRO_FADE_SEC := 0.45
## 吹き出しを置く頭の位置（立ち絵の矩形に対する割合）と、頭の中心からしっぽの先までの距離（立ち絵の幅に対する割合）
const HEAD_Y_FRAC := 0.18
const HEAD_GAP_FRAC := 0.14
const BUBBLE_SCREEN_MARGIN := 16.0
const CHOICE_GAP := 28.0
const DIM_WITH_BACKGROUND := 0.55
const DIM_WITHOUT_BACKGROUND := 0.9

var _config: Dictionary = {}
var _root: Control
var _portrait: TextureRect
var _bubble: SpeechBubble
var _choice_buttons: Array = []
var _typing := false
var _advance_requested := false
var _choosing := false
var _finished := false


func setup(config: Dictionary) -> void:
	_config = config


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	call_deferred("_run_intro")


func _unhandled_input(event: InputEvent) -> void:
	## タイプライター中のクリックで全文表示へスキップ（OuterGiftModal と同じ）。
	if _finished or not _typing:
		return
	if _is_advance_event(event):
		_advance_requested = true
		get_viewport().set_input_as_handled()


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background_tex: Texture2D = _load_texture(str(_config.get("background", "")))
	if background_tex != null:
		var background := TextureRect.new()
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.texture = background_tex
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(background)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.015, 0.04, DIM_WITH_BACKGROUND if background_tex != null else DIM_WITHOUT_BACKGROUND)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.texture = _load_texture(str(_config.get("portrait", "")))
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.modulate = Color(1, 1, 1, 0.0)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait)
	_layout_portrait()

	_bubble = SpeechBubble.new()
	_bubble.name = "SpeechBubble"
	_bubble.visible = false
	_bubble.accent = ACCENT
	_root.add_child(_bubble)

	var choices: Array = _config.get("choices", [])
	for choice in choices:
		_choice_buttons.append(_make_choice_button(choice))


## 文字だけの選択肢。枠・背景なし。うっすら表示し、ホバーで少し濃くなる。
func _make_choice_button(choice: Dictionary) -> Button:
	var button := Button.new()
	button.text = str(choice.get("label", ""))
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 26)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.93, 0.89, 0.84))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	button.add_theme_constant_override("outline_size", 6)
	button.modulate = Color(1, 1, 1, 0.0)
	button.visible = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_choice_pressed.bind(choice))
	button.mouse_entered.connect(_on_choice_hover.bind(button, true))
	button.mouse_exited.connect(_on_choice_hover.bind(button, false))
	_root.add_child(button)
	return button


func _layout_portrait() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var target_h: float = vp.y * PORTRAIT_HEIGHT_FRAC
	var aspect := 0.55
	if _portrait.texture != null:
		var sz: Vector2 = _portrait.texture.get_size()
		if sz.y > 0.0:
			aspect = sz.x / sz.y
	var target_w: float = target_h * aspect
	_portrait.anchor_left = 0.5
	_portrait.anchor_right = 0.5
	_portrait.anchor_top = 0.5
	_portrait.anchor_bottom = 0.5
	_portrait.offset_left = -target_w * 0.5
	_portrait.offset_right = target_w * 0.5
	_portrait.offset_top = -target_h * 0.5
	_portrait.offset_bottom = target_h * 0.5


## 吹き出しを立ち絵の頭の横に置き、しっぽを頭へ向ける（右隣を優先、溢れたら左）。
## 頭の高さで横に置くので、胸の高さに出る選択肢とは重ならない。
func _layout_bubble_beside_head() -> void:
	var portrait_rect: Rect2 = _portrait.get_rect()
	var vp_size: Vector2 = _root.size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = get_viewport().get_visible_rect().size
	var head := Vector2(portrait_rect.get_center().x, portrait_rect.position.y + portrait_rect.size.y * HEAD_Y_FRAC)
	var bounds := Rect2(Vector2.ONE * BUBBLE_SCREEN_MARGIN, vp_size - Vector2.ONE * BUBBLE_SCREEN_MARGIN * 2.0)
	_bubble.place_beside(head, portrait_rect.size.x * HEAD_GAP_FRAC, bounds)


## 選択肢は立ち絵の左右、胸のあたりの高さに置く。先頭が左、2つ目が右。
func _layout_choices() -> void:
	var portrait_rect: Rect2 = _portrait.get_rect()
	var mid_y: float = portrait_rect.position.y + portrait_rect.size.y * 0.55
	for i in _choice_buttons.size():
		var button: Button = _choice_buttons[i]
		button.reset_size()
		var sz: Vector2 = button.get_combined_minimum_size()
		var x: float = portrait_rect.position.x - CHOICE_GAP - sz.x if i % 2 == 0 else portrait_rect.end.x + CHOICE_GAP
		button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = x
		button.offset_top = mid_y - sz.y * 0.5
		button.offset_right = x + sz.x
		button.offset_bottom = mid_y + sz.y * 0.5


func _run_intro() -> void:
	_layout_portrait()
	var tw_in := create_tween()
	tw_in.tween_property(_portrait, "modulate:a", 1.0, PORTRAIT_FADE_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if _finished:
		return
	await _say(str(_config.get("line", "")))
	if _finished:
		return
	await _show_choices()


## 台詞をタイプライター表示し、全文表示から LINE_HOLD_SEC 後に吹き出しを消す。
func _say(text: String) -> void:
	_open_bubble(text)
	await _typewriter_line(text)
	if _finished:
		return
	await get_tree().create_timer(LINE_HOLD_SEC).timeout
	if _finished:
		return
	var tw := create_tween()
	tw.tween_property(_bubble, "modulate:a", 0.0, BUBBLE_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_bubble.visible = false


## 全文で吹き出しの大きさを決めてから頭の横に置き、空の状態で表示する。
func _open_bubble(full_text: String) -> void:
	_bubble.fit_to_text(full_text)
	_bubble.set_text("")
	_layout_bubble_beside_head()
	_bubble.modulate.a = 1.0
	_bubble.visible = true


func _typewriter_line(full_text: String) -> void:
	_typing = true
	_advance_requested = false
	_bubble.set_text("")
	var i := 0
	var n: int = full_text.length()
	while i < n and not _finished:
		if _advance_requested:
			break
		i += 1
		_bubble.set_text(full_text.substr(0, i))
		if AudioManager != null:
			AudioManager.play_sfx("gift_type")
		await get_tree().create_timer(float(TYPE_MS) / 1000.0).timeout
	_bubble.set_text(full_text)
	_advance_requested = false
	_typing = false


func _show_choices() -> void:
	_layout_choices()
	var tw := create_tween()
	tw.set_parallel(true)
	for button in _choice_buttons:
		(button as Button).visible = true
		tw.tween_property(button, "modulate:a", CHOICE_ALPHA, CHOICE_FADE_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_choosing = true


func _on_choice_hover(button: Button, hovering: bool) -> void:
	if not _choosing:
		return
	button.modulate.a = CHOICE_HOVER_ALPHA if hovering else CHOICE_ALPHA


func _on_choice_pressed(choice: Dictionary) -> void:
	if not _choosing or _finished:
		return
	_choosing = false
	var choice_id: String = str(choice.get("id", ""))
	var reply: String = str(choice.get("reply", ""))
	if reply.is_empty():
		_finish(choice_id)
		return
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	for button in _choice_buttons:
		tw_out.tween_property(button, "modulate:a", 0.0, CHOICE_FADE_OUT_SEC)
	await tw_out.finished
	for button in _choice_buttons:
		(button as Button).visible = false
	await _say_then_keep(reply)
	if _finished:
		return
	var tw_all := create_tween()
	tw_all.tween_property(_root, "modulate:a", 0.0, OUTRO_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_all.finished
	_finish(choice_id)


## 返事用：全文表示から LINE_HOLD_SEC 待つ（吹き出しは全体フェードで一緒に消す）。
func _say_then_keep(text: String) -> void:
	_open_bubble(text)
	await _typewriter_line(text)
	if _finished:
		return
	await get_tree().create_timer(LINE_HOLD_SEC).timeout


func _finish(choice_id: String) -> void:
	if _finished:
		return
	_finished = true
	choice_selected.emit(choice_id)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D
