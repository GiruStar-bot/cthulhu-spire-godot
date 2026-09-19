extends CanvasLayer
class_name OuterGiftModal

## DreamTitle プレイ直後の「外宇宙の贈り物」演出（台詞ティッカー → デッキ授与 → 貰う）。
## タイトル Stage を隠し、フル dim で背後メニューを見せない。

const ACCENT := Color(0.91, 0.627, 1.0)  ## #E8A0FF
const PACK_ART_PRIMARY := "res://art/pixel/packs/pack_outer_nobackground.png"
const PACK_ART_FALLBACK := "res://art/pixel/packs/pack_outer.jpg"
const FRAME_ART := "res://art/pixel/ui/frame_card_outer_9.png"
const NYAR_ART_PRIMARY := "res://art/pixel/ui/nyar_gift.png"
const NYAR_ART_FALLBACK := "res://art/pixel/nyar.png"
const PIXEL_BUTTON_SCENE := "res://scenes/ui/PixelButton.tscn"

const NYAR_FADE_IN_SEC := 0.4
const NYAR_DRIFT_OUT_SEC := 0.6
const CARD_FADE_IN_SEC := 0.6
const TELOP_AUTO_SEC := 2.4
const NYAR_DRIFT_PX := 36.0

signal proceeded

var _dim: ColorRect
var _root: Control
var _nyar: TextureRect
var _card_slot: Control
var _ticker_band: Control
var _telop: Label
var _underline: ColorRect
var _proceed_btn: BaseButton
var _hidden_chrome: Array = []
var _phase: String = "init"  ## init|line1|line2|reveal|done
var _finished := false
var _awaiting_advance := false
var _advance_requested := false


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
	if not _awaiting_advance:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_requested = true
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_advance_requested = true
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_advance_requested = true
		get_viewport().set_input_as_handled()


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
	_nyar.set_anchors_preset(Control.PRESET_CENTER)
	_nyar.anchor_left = 0.5
	_nyar.anchor_right = 0.5
	_nyar.anchor_top = 0.5
	_nyar.anchor_bottom = 0.5
	_nyar.offset_left = -170.0
	_nyar.offset_right = 170.0
	_nyar.offset_top = -280.0
	_nyar.offset_bottom = 120.0
	_nyar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nyar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_nyar.modulate = Color(1, 1, 1, 0.0)
	_nyar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _soft_set_texture(_nyar, NYAR_ART_PRIMARY):
		_soft_set_texture(_nyar, NYAR_ART_FALLBACK)
	_root.add_child(_nyar)

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
	if not _soft_set_texture(pack, PACK_ART_PRIMARY):
		_soft_set_texture(pack, PACK_ART_FALLBACK)
	_card_slot.add_child(pack)

	var frame := TextureRect.new()
	frame.name = "OuterFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = ACCENT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_soft_set_texture(frame, FRAME_ART)
	_card_slot.add_child(frame)

	if frame.texture == null:
		var accent_border := Panel.new()
		accent_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		accent_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		accent_border.add_theme_stylebox_override("panel", sb)
		_card_slot.add_child(accent_border)

	## 下部ティッカー帯（吹き出しなし）＋キャンディ虹の細い下線
	_ticker_band = Control.new()
	_ticker_band.name = "TickerBand"
	_ticker_band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_ticker_band.offset_top = -120.0
	_ticker_band.offset_bottom = -28.0
	_ticker_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ticker_band)

	var band_bg := ColorRect.new()
	band_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band_bg.color = Color(0.05, 0.02, 0.1, 0.55)
	band_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker_band.add_child(band_bg)

	_telop = Label.new()
	_telop.name = "Telop"
	_telop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_telop.offset_left = 48.0
	_telop.offset_right = -48.0
	_telop.offset_top = 8.0
	_telop.offset_bottom = -18.0
	_telop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_telop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_telop.add_theme_font_size_override("font_size", 24)
	_telop.add_theme_color_override("font_color", ACCENT)
	_telop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_telop.text = ""
	_telop.modulate = Color(1, 1, 1, 0.0)
	_ticker_band.add_child(_telop)

	_underline = ColorRect.new()
	_underline.name = "CandyUnderline"
	_underline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_underline.offset_top = -3.0
	_underline.offset_left = 120.0
	_underline.offset_right = -120.0
	_underline.color = ACCENT
	_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker_band.add_child(_underline)

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


func _run_sequence() -> void:
	if _finished:
		return

	## 1) ニャル中央 α0→1
	_phase = "appear"
	var tw_in := create_tween()
	tw_in.tween_property(_nyar, "modulate:a", 1.0, NYAR_FADE_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if _finished:
		return

	## 2) ティッカー行1
	_phase = "line1"
	_soft_sfx("gift_talk")
	await _show_telop("やあ、%s！君に会えて嬉しいよ" % _player_display_name())
	if _finished:
		return
	await _wait_advance_or_timeout(TELOP_AUTO_SEC)
	if _finished:
		return

	## 3) ティッカー行2
	_phase = "line2"
	_soft_sfx("gift_talk")
	await _show_telop("何も無い君にはこれを授けよう！")
	if _finished:
		return
	await _wait_advance_or_timeout(TELOP_AUTO_SEC)
	if _finished:
		return

	## 4) ニャル↑ドリフト消失 ＋ デッキカード同時フェードイン
	_phase = "reveal"
	await _fade_telop_out()
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

	_ticker_band.visible = false
	_proceed_btn.visible = true
	_proceed_btn.disabled = false
	_phase = "ready"


func _show_telop(text: String) -> void:
	_telop.text = text
	_telop.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_telop, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _fade_telop_out() -> void:
	var tw := create_tween()
	tw.tween_property(_telop, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


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
	var n := str(GameState.player_name).strip_edges()
	if n.is_empty():
		return "旅人"
	return n


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
