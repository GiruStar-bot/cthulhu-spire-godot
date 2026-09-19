extends CanvasLayer
class_name OuterGiftModal

## DreamTitle プレイ直後の「外宇宙の贈り物」シェル（見た目のみ）。
## カードIDの実付与は後続。プレースホルダ定数は GameState 側。

const ACCENT := Color(0.91, 0.627, 1.0)  ## #E8A0FF 祭礼キャンディ虹
const PACK_ART_PRIMARY := "res://art/pixel/packs/pack_outer_nobackground.png"
const PACK_ART_FALLBACK := "res://art/pixel/packs/pack_outer.jpg"
const FRAME_ART := "res://art/pixel/ui/frame_card_outer_9.png"
const NYAR_ART_PRIMARY := "res://art/pixel/ui/nyar_gift.png"
const NYAR_ART_FALLBACK := "res://art/pixel/nyar.png"
const PIXEL_BUTTON_SCENE := "res://scenes/ui/PixelButton.tscn"

signal proceeded

var _dim: ColorRect
var _root: Control


func _ready() -> void:
	layer = 80
	_build()
	AudioManager.play_sfx("gift_open")


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.05, 0.02, 0.08, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	var nyar := TextureRect.new()
	nyar.name = "NyarPortrait"
	nyar.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	nyar.anchor_left = 0.0
	nyar.anchor_right = 0.0
	nyar.anchor_top = 0.5
	nyar.anchor_bottom = 0.5
	nyar.offset_left = 24.0
	nyar.offset_top = -220.0
	nyar.offset_right = 280.0
	nyar.offset_bottom = 220.0
	nyar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nyar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	nyar.modulate = Color(1, 1, 1, 0.42)
	nyar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _soft_set_texture(nyar, NYAR_ART_PRIMARY):
		_soft_set_texture(nyar, NYAR_ART_FALLBACK)
	_root.add_child(nyar)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -140.0
	center.offset_right = 140.0
	center.offset_top = -260.0
	center.offset_bottom = 260.0
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(center)

	var card_slot := Control.new()
	card_slot.custom_minimum_size = Vector2(180, 270)
	card_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(card_slot)

	var pack := TextureRect.new()
	pack.name = "PackPreview"
	pack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not _soft_set_texture(pack, PACK_ART_PRIMARY):
		_soft_set_texture(pack, PACK_ART_FALLBACK)
	card_slot.add_child(pack)

	var frame := TextureRect.new()
	frame.name = "OuterFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.modulate = ACCENT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_soft_set_texture(frame, FRAME_ART)
	card_slot.add_child(frame)

	# 枠が無いとき用の薄いアクセント縁
	var accent_border := Panel.new()
	accent_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accent_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	accent_border.add_theme_stylebox_override("panel", sb)
	if frame.texture == null:
		card_slot.add_child(accent_border)

	var copy := Label.new()
	copy.text = "外宇宙デッキを受け取った"
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_theme_font_size_override("font_size", 22)
	copy.add_theme_color_override("font_color", ACCENT)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(copy)

	var proceed: BaseButton = _make_proceed_button()
	proceed.text = "進む"
	proceed.custom_minimum_size = Vector2(160, 44)
	proceed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	proceed.pressed.connect(_on_proceed)
	center.add_child(proceed)


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


func _on_proceed() -> void:
	AudioManager.play_sfx("gift_confirm")
	proceeded.emit()
	queue_free()
