class_name CombatCard
extends Button
## CardView.tsx の表示専用移植。
## フレームは CSS border-image（枠のみ）相当。イラストはヘッダーと本文の間に全面表示する。

signal drag_began(card_uid: String)

## styles.css の border-width。slice値ではなく枠の厚さ。
const FRAME_BY_RARITY := {
	"common": ["res://art/pixel/ui/frame_card_common_9.png", 10],
	"uncommon": ["res://art/pixel/ui/frame_card_uncommon_9.png", 12],
	"rare": ["res://art/pixel/ui/frame_card_9.png", 12],
	"legendary": ["res://art/pixel/ui/frame_card_9.png", 12],
}
const FRAME_BY_ARCHETYPE := {
	"greatold": ["res://art/pixel/ui/frame_card_greatold_9.png", 14],
	"elder": ["res://art/pixel/ui/frame_card_elder_9.png", 12],
	"outer": ["res://art/pixel/ui/frame_card_outer_9.png", 16],
	"all": ["res://art/pixel/ui/frame_card_all_9.png", 16],
	"knight": ["res://art/pixel/ui/frame_card_knight_9.png", 14],
	"magic": ["res://art/pixel/ui/frame_card_magic_9.png", 13],
	"wind": ["res://art/pixel/ui/frame_card_wind_9.png", 15],
	"fire": ["res://art/pixel/ui/frame_card_fire_9.png", 14],
	"earth": ["res://art/pixel/ui/frame_card_earth_9.png", 16],
	"bastet": ["res://art/pixel/ui/frame_card_bastet_9.png", 13],
}
## styles.css glow-greatold / glow-elder / glow-outer の drop-shadow 色。
const MYTHOS_GLOW_COLOR := {
	"greatold": Color(0.063, 0.725, 0.506, 1.0),
	"elder": Color(0.980, 0.863, 0.510, 1.0),
	"outer": Color(0.627, 0.314, 0.902, 1.0),
	"all": Color(0.85, 0.55, 1.0, 1.0),
}
const TAG_TONES := {
	"attack": Color("6b1f22"),
	"defense": Color("183c66"),
	"effect": Color("452267"),
}
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"
## 既存9-slice枠は 96px 幅。1152px の新規枠は NinePatch の patch_margin が
## 画面ピクセル直結のため、この幅へ焼いてから載せる。
const FRAME_CANONICAL_W := 96

static var _ninepatch_tex_cache: Dictionary = {}

var card_uid: String = ""
var _interactive: bool = true
var _frame: NinePatchRect
var _inner: Control
var _header: ColorRect
var _art: TextureRect
var _title: Label
var _type: Label
var _cost: Label
var _body: Label
var _glow: ColorRect
var _mythos_halo: TextureRect
var _mythos_frame_glow: NinePatchRect
var _mythos_tween: Tween
var _fallback_outline: Panel
var _idle_scale := Vector2.ONE
var _built := false
var _frame_margin: int = 10


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clear_theme_styles()
	if not _built:
		_build()
	_sync_pivot()
	mouse_entered.connect(_on_hovered)
	mouse_exited.connect(_on_unhovered)


func configure(card: Dictionary, definition: Dictionary, playable: bool, selected: bool, interactive: bool = true) -> void:
	if not _built:
		_build()
	_interactive = interactive
	card_uid = str(card.get("uid", ""))
	var art_path: String = Cards.card_art(card, definition)
	_art.texture = _load_texture_safe(art_path)
	var ai_tag: String = str(definition.get("aiTag", ""))
	_header.color = TAG_TONES.get(ai_tag, Color("312d26"))
	var arch: String = str(definition.get("archetype", ""))
	var type_label: String = str(Cards.ARCHETYPE_LABELS.get(arch, ""))
	if Cards.has_tag(definition, "cat"):
		type_label = "猫" if type_label == "" else "%s·猫" % type_label
	_type.text = type_label
	_type.visible = _type.text != ""
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
	_sync_pivot()
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
			if drag_began.get_connections().size() > 0:
				drag_began.emit(card_uid)
				accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and card_uid != "":
			if drag_began.get_connections().size() > 0:
				drag_began.emit(card_uid)
				accept_event()


func _load_texture_safe(path: String) -> Texture2D:
	var resolved: String = Cards.resolve_art(path)
	if resolved.is_empty():
		return load(FALLBACK_TEX) as Texture2D
	## ArtCache Autoload があればキャッシュ経由（begin ウォーム済みを再利用）
	if ArtCache != null:
		var cached: Texture2D = ArtCache.get_texture(resolved)
		if cached != null:
			return cached
	if not ResourceLoader.exists(resolved, "Texture2D"):
		return load(FALLBACK_TEX) as Texture2D
	var resource: Resource = ResourceLoader.load(resolved, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return load(FALLBACK_TEX) as Texture2D


## NinePatchRect の patch_margin はテクスチャ画素 = 画面画素。
## 1152×1728 の枠は 96×144 に焼いて既存枠と同じマージンが使えるようにする。
## 既存の 96px 枠は ArtCache / ResourceLoader のまま（見た目を変えない）。
static func ninepatch_texture(path: String) -> Texture2D:
	if path.is_empty():
		return load(FALLBACK_TEX) as Texture2D
	if _ninepatch_tex_cache.has(path):
		return _ninepatch_tex_cache[path] as Texture2D
	var img := Image.new()
	var loaded_ok: bool = false
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not abs_path.is_empty() and FileAccess.file_exists(abs_path):
		loaded_ok = img.load(abs_path) == OK
	if loaded_ok and img.get_width() <= FRAME_CANONICAL_W * 2:
		var imported: Texture2D = _imported_texture(path)
		if imported != null:
			_ninepatch_tex_cache[path] = imported
			return imported
	if not loaded_ok:
		var imported2: Texture2D = _imported_texture(path)
		if imported2 != null:
			_ninepatch_tex_cache[path] = imported2
			return imported2
		var fb: Texture2D = load(FALLBACK_TEX) as Texture2D
		_ninepatch_tex_cache[path] = fb
		return fb
	if img.is_compressed():
		img.decompress()
	var src_w: int = img.get_width()
	if src_w > FRAME_CANONICAL_W * 2:
		var nh: int = maxi(1, int(round(float(img.get_height()) * float(FRAME_CANONICAL_W) / float(src_w))))
		img.resize(FRAME_CANONICAL_W, nh, Image.INTERPOLATE_LANCZOS)
		img.fix_alpha_edges()
	var baked: Texture2D = ImageTexture.create_from_image(img)
	_ninepatch_tex_cache[path] = baked
	return baked


static func _imported_texture(path: String) -> Texture2D:
	if ArtCache != null:
		var cached: Texture2D = ArtCache.get_texture(path)
		if cached != null:
			return cached
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if resource is Texture2D:
		return resource as Texture2D
	return null


func _clear_theme_styles() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("focus", empty)


func _build() -> void:
	if _built:
		return
	_built = true
	_clear_theme_styles()

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("12110e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_fallback_outline = Panel.new()
	_fallback_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallback_outline)

	_inner = Control.new()
	_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inner)

	_header = ColorRect.new()
	_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header.offset_bottom = 22
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_header)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 4
	_title.offset_top = 2
	_title.offset_right = -36
	_title.offset_bottom = 20
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_title)

	_type = Label.new()
	_type.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_type.offset_left = -40
	_type.offset_top = 3
	_type.offset_right = -4
	_type.offset_bottom = 19
	_type.add_theme_font_size_override("font_size", 8)
	_type.add_theme_color_override("font_color", Color("e9dcc1"))
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_type)

	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_top = 22
	_art.offset_bottom = -38
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_art)

	var cost_plate := ColorRect.new()
	cost_plate.position = Vector2(4, 26)
	cost_plate.size = Vector2(22, 22)
	cost_plate.color = Color("161512")
	cost_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(cost_plate)

	_cost = Label.new()
	_cost.position = Vector2(4, 27)
	_cost.size = Vector2(22, 20)
	_cost.add_theme_font_size_override("font_size", 12)
	_cost.add_theme_color_override("font_color", Color.WHITE)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_cost)

	var footer := ColorRect.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -38
	footer.color = Color("16130f")
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(footer)

	_body = Label.new()
	_body.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_body.offset_left = 4
	_body.offset_top = -36
	_body.offset_right = -4
	_body.offset_bottom = -2
	_body.add_theme_font_size_override("font_size", 8)
	_body.add_theme_color_override("font_color", Color("e3d9c2"))
	_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_body)

	_glow = ColorRect.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.color = Color(0.94, 0.79, 0.38, 0.18)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.visible = false
	add_child(_glow)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mythos_halo = TextureRect.new()
	_mythos_halo.name = "MythosHalo"
	_mythos_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mythos_halo.offset_left = -22
	_mythos_halo.offset_top = -22
	_mythos_halo.offset_right = 22
	_mythos_halo.offset_bottom = 22
	_mythos_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mythos_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_mythos_halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mythos_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mythos_halo.material = add_mat
	_mythos_halo.texture = _make_radial_glow_texture()
	_mythos_halo.show_behind_parent = true
	_mythos_halo.visible = false
	add_child(_mythos_halo)

	_mythos_frame_glow = NinePatchRect.new()
	_mythos_frame_glow.name = "MythosFrameGlow"
	_mythos_frame_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mythos_frame_glow.offset_left = -5
	_mythos_frame_glow.offset_top = -5
	_mythos_frame_glow.offset_right = 5
	_mythos_frame_glow.offset_bottom = 5
	_mythos_frame_glow.draw_center = false
	_mythos_frame_glow.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_mythos_frame_glow.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_mythos_frame_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mythos_frame_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mythos_frame_glow.material = add_mat
	_mythos_frame_glow.show_behind_parent = true
	_mythos_frame_glow.visible = false
	add_child(_mythos_frame_glow)

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
		_frame_margin = 2
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0, 0, 0, 0)
		fallback.set_border_width_all(2)
		var tag: String = str(definition.get("aiTag", ""))
		fallback.border_color = TAG_TONES.get(tag, Color("d7c69b"))
		_fallback_outline.add_theme_stylebox_override("panel", fallback)
		_apply_inner_margin()
		_apply_mythos_glow("")
		return
	_frame.visible = true
	_fallback_outline.visible = false
	_frame.texture = ninepatch_texture(str(frame_data[0]))
	_frame_margin = int(frame_data[1])
	_frame.patch_margin_left = _frame_margin
	_frame.patch_margin_top = _frame_margin
	_frame.patch_margin_right = _frame_margin
	_frame.patch_margin_bottom = _frame_margin
	_apply_inner_margin()
	_apply_mythos_glow(archetype)


func _make_radial_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0.16),
		Color(1, 1, 1, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	return tex


func _apply_mythos_glow(archetype: String) -> void:
	if _mythos_tween != null and is_instance_valid(_mythos_tween):
		_mythos_tween.kill()
	_mythos_tween = null
	var is_mythos: bool = MYTHOS_GLOW_COLOR.has(archetype)
	if _mythos_halo != null:
		_mythos_halo.visible = is_mythos
	if _mythos_frame_glow != null:
		_mythos_frame_glow.visible = is_mythos
	if not is_mythos:
		return
	var col: Color = MYTHOS_GLOW_COLOR[archetype]
	_mythos_halo.modulate = col
	_mythos_frame_glow.modulate = col
	_mythos_frame_glow.texture = _frame.texture
	_mythos_frame_glow.patch_margin_left = _frame_margin
	_mythos_frame_glow.patch_margin_top = _frame_margin
	_mythos_frame_glow.patch_margin_right = _frame_margin
	_mythos_frame_glow.patch_margin_bottom = _frame_margin
	_set_mythos_intensity(0.5)
	_mythos_tween = create_tween().set_loops()
	_mythos_tween.tween_method(_set_mythos_intensity, 0.5, 0.9, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mythos_tween.tween_method(_set_mythos_intensity, 0.9, 0.5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_mythos_intensity(v: float) -> void:
	if _mythos_halo != null:
		_mythos_halo.modulate.a = v * 0.38
	if _mythos_frame_glow != null:
		_mythos_frame_glow.modulate.a = v


func _exit_tree() -> void:
	if _mythos_tween != null and is_instance_valid(_mythos_tween):
		_mythos_tween.kill()
	_mythos_tween = null


func _apply_inner_margin() -> void:
	if _inner == null:
		return
	var m: int = _frame_margin
	_inner.offset_left = m
	_inner.offset_top = m
	_inner.offset_right = -m
	_inner.offset_bottom = -m


func _sync_pivot() -> void:
	pivot_offset = custom_minimum_size * 0.5


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
