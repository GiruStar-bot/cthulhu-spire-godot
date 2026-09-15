class_name CombatCard
extends Button
## CardView.tsx の表示専用移植。ロジックは Combat.gd 側に残す。
## プレイ入力は CombatView.tsx と同様に pointerdown 起点のドラッグで行う。

signal drag_began(card_uid: String)

## CSSのborder-image-sliceを、96px幅へポイント縮小した値へ変換したNinePatch margin。
## common: 66→8 / uncommon: 130→16 / rare: 50→13
const FRAME_BY_RARITY := {
	"common": ["res://art/pixel/ui/frame_card_common_9.png", 8],
	"uncommon": ["res://art/pixel/ui/frame_card_uncommon_9.png", 16],
	"rare": ["res://art/pixel/ui/frame_card_9.png", 13],
}
const FRAME_BY_ARCHETYPE := {
	## greatold: 120→15 / elder: 115→14 / outer: 150→19
	"greatold": ["res://art/pixel/ui/frame_card_greatold_9.png", 15],
	"elder": ["res://art/pixel/ui/frame_card_elder_9.png", 14],
	"outer": ["res://art/pixel/ui/frame_card_outer_9.png", 19],
}
const TAG_TONES := {
	"attack": Color("6b1f22"),
	"defense": Color("183c66"),
	"effect": Color("452267"),
}
const TAG_LABELS := {"attack": "攻撃", "defense": "防御", "effect": "異能"}
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"

var card_uid: String = ""
var _interactive: bool = true
var _frame: NinePatchRect
var _header: ColorRect
var _art: TextureRect
var _title: Label
var _type: Label
var _cost: Label
var _body: Label
var _glow: ColorRect
var _fallback_outline: Panel
var _idle_scale := Vector2.ONE
var _built := false


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pivot_offset = custom_minimum_size * 0.5
	if not _built:
		_build()
	mouse_entered.connect(_on_hovered)
	mouse_exited.connect(_on_unhovered)


func configure(card: Dictionary, definition: Dictionary, playable: bool, selected: bool, interactive: bool = true) -> void:
	if not _built:
		_build()
	_interactive = interactive
	card_uid = str(card.get("uid", ""))
	var art_path: String = str(definition.get("art", ""))
	_art.texture = _load_texture_safe(art_path)
	var ai_tag: String = str(definition.get("aiTag", ""))
	_header.color = TAG_TONES.get(ai_tag, Color("312d26"))
	_type.text = str(TAG_LABELS.get(ai_tag, "秘術"))
	_title.text = "%s%s" % [definition.get("name", "Unknown"), "+" if card.get("upgraded", false) else ""]
	_cost.text = "X" if definition.get("xCost", false) else ("—" if definition.get("unplayable", false) else str(Cards.card_cost(card)))
	_body.text = str(definition.get("text", ""))
	_glow.visible = selected
	if interactive:
		disabled = not playable
		modulate.a = 1.0 if playable else 0.56
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if playable else Control.CURSOR_ARROW
	else:
		disabled = false
		modulate.a = 1.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	_apply_frame(definition)
	if selected:
		z_index = 30
		_idle_scale = Vector2(1.055, 1.055)
		scale = _idle_scale
	else:
		z_index = 0
		_idle_scale = Vector2.ONE


func _gui_input(event: InputEvent) -> void:
	if not _interactive or disabled:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and card_uid != "":
			drag_began.emit(card_uid)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and card_uid != "":
			drag_began.emit(card_uid)
			accept_event()


func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return load(FALLBACK_TEX) as Texture2D
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return load(FALLBACK_TEX) as Texture2D


func _build() -> void:
	if _built:
		return
	_built = true
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("12110e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_fallback_outline = Panel.new()
	_fallback_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallback_outline)

	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_left = 10
	_art.offset_top = 37
	_art.offset_right = -10
	_art.offset_bottom = -47
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	var art_shade := ColorRect.new()
	art_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_shade.offset_left = 10
	art_shade.offset_top = 37
	art_shade.offset_right = -10
	art_shade.offset_bottom = -47
	art_shade.color = Color(0.02, 0.02, 0.02, 0.14)
	art_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_shade)

	_header = ColorRect.new()
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.offset_left = 8
	_header.offset_top = 8
	_header.offset_right = -8
	_header.offset_bottom = 34
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 13
	_title.offset_top = 11
	_title.offset_right = -35
	_title.offset_bottom = 29
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_type = Label.new()
	_type.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_type.offset_left = -44
	_type.offset_top = 11
	_type.offset_right = -12
	_type.offset_bottom = 29
	_type.add_theme_font_size_override("font_size", 8)
	_type.add_theme_color_override("font_color", Color("e9dcc1"))
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_type)

	var cost_plate := ColorRect.new()
	cost_plate.position = Vector2(14, 43)
	cost_plate.size = Vector2(26, 26)
	cost_plate.color = Color("161512")
	cost_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cost_plate)

	_cost = Label.new()
	_cost.position = Vector2(14, 45)
	_cost.size = Vector2(26, 22)
	_cost.add_theme_font_size_override("font_size", 14)
	_cost.add_theme_color_override("font_color", Color.WHITE)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost)

	var footer := ColorRect.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 8
	footer.offset_top = -43
	footer.offset_right = -8
	footer.offset_bottom = -8
	footer.color = Color("16130f")
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)

	_body = Label.new()
	_body.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_body.offset_left = 12
	_body.offset_top = -40
	_body.offset_right = -12
	_body.offset_bottom = -10
	_body.add_theme_font_size_override("font_size", 8)
	_body.add_theme_color_override("font_color", Color("e3d9c2"))
	_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_glow = ColorRect.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.color = Color(0.94, 0.79, 0.38, 0.18)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	_frame = NinePatchRect.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.draw_center = false
	_frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)


func _apply_frame(definition: Dictionary) -> void:
	var archetype: String = str(definition.get("archetype", ""))
	var frame_data: Array = FRAME_BY_ARCHETYPE.get(archetype, [])
	if frame_data.is_empty():
		frame_data = FRAME_BY_RARITY.get(str(definition.get("rarity", "")), [])
	if frame_data.is_empty():
		_frame.visible = false
		_fallback_outline.visible = true
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0, 0, 0, 0)
		fallback.border_width_left = 2
		fallback.border_width_top = 2
		fallback.border_width_right = 2
		fallback.border_width_bottom = 2
		var tag: String = str(definition.get("aiTag", ""))
		fallback.border_color = TAG_TONES.get(tag, Color("d7c69b"))
		_fallback_outline.add_theme_stylebox_override("panel", fallback)
		return
	_frame.visible = true
	_fallback_outline.visible = false
	_frame.texture = _load_texture_safe(str(frame_data[0]))
	var margin: int = int(frame_data[1])
	_frame.patch_margin_left = margin
	_frame.patch_margin_top = margin
	_frame.patch_margin_right = margin
	_frame.patch_margin_bottom = margin


func _on_hovered() -> void:
	if not _interactive or disabled:
		return
	z_index = 40
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _idle_scale * 1.08, 0.12)


func _on_unhovered() -> void:
	if _glow.visible:
		return
	z_index = 0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _idle_scale, 0.14)
