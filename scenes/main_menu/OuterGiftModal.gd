extends CanvasLayer
class_name OuterGiftModal

## DreamTitle プレイ直後の「外宇宙の贈り物」演出。
## ニャル中央 + 頭横吹き出し（共通部品 SpeechBubble、タイプライター）→ デッキ授与 → 貰う。
## 下部ティッカー帯は使わない。タイトル Stage を隠し、フル dim。

const ACCENT := Color(0.91, 0.627, 1.0)  ## #E8A0FF
const PACK_ART_PRIMARY := "res://art/pixel/cards/outer_gift.jpg"
const PACK_ART_FALLBACK_A := "res://art/pixel/packs/pack_outer_nobackground.png"
const PACK_ART_FALLBACK_B := "res://art/pixel/packs/pack_outer.jpg"
const FRAME_ART := "res://art/pixel/ui/frame_card_outer_9.png"
const NYAR_ART_PRIMARY := "res://art/pixel/ui/nyar_gift.png"
const NYAR_ART_FALLBACK := "res://art/pixel/nyar.png"
const PIXEL_BUTTON_SCENE := "res://scenes/ui/PixelButton.tscn"

const NYAR_HEIGHT_FRAC := 0.60  ## 55–65% の中間
const NYAR_FADE_IN_SEC := 0.4
const NYAR_DRIFT_OUT_SEC := 0.6
const CARD_FADE_IN_SEC := 0.6
const TYPE_MS := 45  ## Undertale-ish char delay (~45ms)
const TYPE_MS_JITTER := 0  ## reserved; keep fixed ~45ms per steering
const LINE_AUTO_SEC := 1.6
const NYAR_DRIFT_PX := 36.0
## 吹き出しを置く頭の位置（ニャルの矩形に対する割合）と、頭の中心からしっぽの先までの距離（ニャルの幅に対する割合）
const HEAD_Y_FRAC := 0.18
const HEAD_GAP_FRAC := 0.14
const BUBBLE_SCREEN_MARGIN := 16.0
const FRAME_PATCH_MARGIN := 19

signal proceeded

var _dim: ColorRect
var _root: Control
var _nyar: TextureRect
var _bubble: SpeechBubble
var _card_slot: Control
var _proceed_btn: BaseButton
var _hidden_chrome: Array = []
var _phase: String = "init"
var _finished := false
var _awaiting_advance := false
var _advance_requested := false
var _typing := false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_title_chrome()
	_build()
	_soft_sfx("gift_open")
	call_deferred("_run_sequence")


func _exit_tree() -> void:
	_restore_title_chrome()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if _typing:
		## タイプライター中のクリックで全文表示へスキップ
		if _is_advance_event(event):
			_advance_requested = true
			get_viewport().set_input_as_handled()
		return
	if not _awaiting_advance:
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


func _hide_title_chrome() -> void:
	_hidden_chrome.clear()
	var parent_n := get_parent()
	if parent_n == null:
		return
	for name in ["Stage", "Veil"]:
		var node := parent_n.get_node_or_null(name) as CanvasItem
		if node != null and node.visible:
			node.visible = false
			_hidden_chrome.append(node)


func _restore_title_chrome() -> void:
	for node in _hidden_chrome:
		if is_instance_valid(node):
			(node as CanvasItem).visible = true
	_hidden_chrome.clear()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	## フル dim（タイトルボタンが透けない）
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.015, 0.06, 0.96)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_nyar = TextureRect.new()
	_nyar.name = "NyarPortrait"
	_nyar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nyar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_nyar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_nyar.modulate = Color(1, 1, 1, 0.0)
	_nyar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _soft_set_texture(_nyar, NYAR_ART_PRIMARY):
		_soft_set_texture(_nyar, NYAR_ART_FALLBACK)
	_root.add_child(_nyar)
	_layout_nyar()

	_bubble = SpeechBubble.new()
	_bubble.name = "SpeechBubble"
	_bubble.visible = false
	_bubble.accent = ACCENT
	_root.add_child(_bubble)

	_card_slot = Control.new()
	_card_slot.name = "CardSlot"
	_card_slot.set_anchors_preset(Control.PRESET_CENTER)
	_card_slot.anchor_left = 0.5
	_card_slot.anchor_right = 0.5
	_card_slot.anchor_top = 0.5
	_card_slot.anchor_bottom = 0.5
	_card_slot.offset_left = -100.0
	_card_slot.offset_right = 100.0
	_card_slot.offset_top = -170.0
	_card_slot.offset_bottom = 140.0
	_card_slot.modulate = Color(1, 1, 1, 0.0)
	_card_slot.visible = false
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card_slot)

	var pack := TextureRect.new()
	pack.name = "PackPreview"
	pack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pack.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _soft_set_texture(pack, PACK_ART_PRIMARY):
		if not _soft_set_texture(pack, PACK_ART_FALLBACK_A):
			_soft_set_texture(pack, PACK_ART_FALLBACK_B)
	_card_slot.add_child(pack)

	var frame := NinePatchRect.new()
	frame.name = "OuterFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	if ResourceLoader.exists(FRAME_ART):
		var frame_tex: Texture2D = load(FRAME_ART) as Texture2D
		if frame_tex != null:
			frame.texture = frame_tex
			frame.patch_margin_left = FRAME_PATCH_MARGIN
			frame.patch_margin_top = FRAME_PATCH_MARGIN
			frame.patch_margin_right = FRAME_PATCH_MARGIN
			frame.patch_margin_bottom = FRAME_PATCH_MARGIN
	_card_slot.add_child(frame)

	if frame.texture == null:
		var accent_border := Panel.new()
		accent_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		accent_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(0)
		accent_border.add_theme_stylebox_override("panel", sb)
		_card_slot.add_child(accent_border)

	_proceed_btn = _make_proceed_button()
	_proceed_btn.text = "貰う"
	_proceed_btn.custom_minimum_size = Vector2(168, 48)
	_proceed_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_proceed_btn.anchor_left = 0.5
	_proceed_btn.anchor_right = 0.5
	_proceed_btn.anchor_top = 1.0
	_proceed_btn.anchor_bottom = 1.0
	_proceed_btn.offset_left = -84.0
	_proceed_btn.offset_right = 84.0
	_proceed_btn.offset_top = -72.0
	_proceed_btn.offset_bottom = -24.0
	_proceed_btn.visible = false
	_proceed_btn.disabled = true
	_proceed_btn.pressed.connect(_on_proceed)
	_root.add_child(_proceed_btn)


func _layout_nyar() -> void:
	var vp := get_viewport().get_visible_rect().size
	var target_h: float = clampf(vp.y * NYAR_HEIGHT_FRAC, vp.y * 0.55, vp.y * 0.65)
	var aspect := 0.55
	if _nyar.texture != null:
		var sz := _nyar.texture.get_size()
		if sz.y > 0.0:
			aspect = sz.x / sz.y
	var target_w: float = target_h * aspect
	_nyar.anchor_left = 0.5
	_nyar.anchor_right = 0.5
	_nyar.anchor_top = 0.5
	_nyar.anchor_bottom = 0.5
	_nyar.offset_left = -target_w * 0.5
	_nyar.offset_right = target_w * 0.5
	_nyar.offset_top = -target_h * 0.5
	_nyar.offset_bottom = target_h * 0.5


## 吹き出しをニャルの頭の横に置き、しっぽを頭へ向ける（右隣を優先、溢れたら左）。
func _layout_bubble_beside_head() -> void:
	var nyar_rect: Rect2 = _nyar.get_rect()
	var vp_size: Vector2 = _root.size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = get_viewport().get_visible_rect().size
	var head := Vector2(nyar_rect.get_center().x, nyar_rect.position.y + nyar_rect.size.y * HEAD_Y_FRAC)
	var bounds := Rect2(Vector2.ONE * BUBBLE_SCREEN_MARGIN, vp_size - Vector2.ONE * BUBBLE_SCREEN_MARGIN * 2.0)
	_bubble.place_beside(head, nyar_rect.size.x * HEAD_GAP_FRAC, bounds)


func _run_sequence() -> void:
	if _finished:
		return

	_layout_nyar()

	## 1) ニャル中央 α0→1
	_phase = "appear"
	var tw_in := create_tween()
	tw_in.tween_property(_nyar, "modulate:a", 1.0, NYAR_FADE_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if _finished:
		return

	## 2) 吹き出し行1（タイプライター／行頭 gift_talk なし）
	_phase = "line1"
	await _typewriter_line("やあ、%s！君に会えて嬉しいよ" % _player_display_name())
	if _finished:
		return
	await _wait_advance_or_timeout(LINE_AUTO_SEC)
	if _finished:
		return

	## 3) 吹き出し行2
	_phase = "line2"
	await _typewriter_line("何も無い君にはこれを授けよう！")
	if _finished:
		return
	await _wait_advance_or_timeout(LINE_AUTO_SEC)
	if _finished:
		return

	## 4) ニャル↑ドリフト消失 ＋ 外宇宙カード同時フェードイン
	_phase = "reveal"
	await _fade_bubble_out()
	if _finished:
		return

	_soft_sfx("gift_reveal")
	_card_slot.visible = true
	_card_slot.modulate.a = 0.0
	var nyar_base_top := _nyar.offset_top
	var nyar_base_bot := _nyar.offset_bottom
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_nyar, "modulate:a", 0.0, NYAR_DRIFT_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_nyar, "offset_top", nyar_base_top - NYAR_DRIFT_PX, NYAR_DRIFT_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_nyar, "offset_bottom", nyar_base_bot - NYAR_DRIFT_PX, NYAR_DRIFT_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_card_slot, "modulate:a", 1.0, CARD_FADE_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if _finished:
		return
	_nyar.visible = false
	_bubble.visible = false

	_proceed_btn.visible = true
	_proceed_btn.disabled = false
	_phase = "ready"


func _typewriter_line(full_text: String) -> void:
	_typing = true
	_advance_requested = false
	## 全文で大きさを決めてから頭の横に置く（行ごとに伸縮する）
	_bubble.fit_to_text(full_text)
	_bubble.set_text("")
	_layout_bubble_beside_head()
	_bubble.visible = true
	var i := 0
	var n := full_text.length()
	while i < n and not _finished:
		if _advance_requested:
			_bubble.set_text(full_text)
			_advance_requested = false
			break
		i += 1
		_bubble.set_text(full_text.substr(0, i))
		## 毎文字 gift_type（pitch ±5% は AudioManager 側）
		if AudioManager != null:
			AudioManager.play_sfx("gift_type")
		await get_tree().create_timer(float(TYPE_MS) / 1000.0).timeout
	_bubble.set_text(full_text)
	_typing = false


func _fade_bubble_out() -> void:
	if not _bubble.visible:
		return
	var tw := create_tween()
	tw.tween_property(_bubble, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_bubble.visible = false
	_bubble.modulate.a = 1.0


func _wait_advance_or_timeout(sec: float) -> void:
	_awaiting_advance = true
	_advance_requested = false
	var elapsed := 0.0
	while elapsed < sec and not _advance_requested and not _finished:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_awaiting_advance = false
	_advance_requested = false


func _player_display_name() -> String:
	## name from profile / 無名 / 旅人
	var n := str(GameState.player_name).strip_edges()
	if not n.is_empty():
		return n
	## Hub ヘッダは「無名」、贈り物台詞の空名は「旅人」
	return "旅人"


func _make_proceed_button() -> BaseButton:
	if ResourceLoader.exists(PIXEL_BUTTON_SCENE):
		var packed: PackedScene = load(PIXEL_BUTTON_SCENE) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			if inst is BaseButton:
				return inst as BaseButton
	var fallback := Button.new()
	fallback.add_theme_color_override("font_color", ACCENT)
	return fallback


func _soft_set_texture(node: TextureRect, path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return false
	node.texture = tex
	return true


func _soft_sfx(cue: String) -> void:
	if AudioManager == null:
		return
	AudioManager.play_sfx(cue)


func _on_proceed() -> void:
	if _finished:
		return
	_finished = true
	_soft_sfx("gift_confirm")
	proceeded.emit()
	queue_free()
