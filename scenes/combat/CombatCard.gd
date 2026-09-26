class_name CombatCard
extends Button
## CardView.tsx の表示専用移植。
## フレームは CSS border-image（枠のみ）相当。イラストはヘッダーと本文の間に全面表示する。

signal drag_began(card_uid: String)

## styles.css の border-width。slice値ではなく枠の厚さ。
## 属性フレームが無いカード（属性なし等）の共通枠。状態異常カードは枠なしの細い縁取りのまま。
const FRAME_DEFAULT := ["res://art/pixel/ui/frame_card_9.png", 12]
const FRAME_BY_ARCHETYPE := {
	"greatold": ["res://art/pixel/ui/frame_card_greatold_9.png", 14],
	"elder": ["res://art/pixel/ui/frame_card_elder_9.png", 12],
	"outer": ["res://art/pixel/ui/frame_card_outer_9.png", 16],
	"all": ["res://art/pixel/ui/frame_card_all_9.png", 16],
	"knight": ["res://art/pixel/ui/frame_card_knight_9.png", 12],
	"magic": ["res://art/pixel/ui/frame_card_magic_9.png", 11],
	"wind": ["res://art/pixel/ui/frame_card_wind_9.png", 13],
	"fire": ["res://art/pixel/ui/frame_card_fire_9.png", 12],
	"earth": ["res://art/pixel/ui/frame_card_earth_9.png", 20],
	"bastet": ["res://art/pixel/ui/frame_card_bastet_9.png", 11],
	"water": ["res://art/pixel/ui/frame_card_water_9.png", 19],
	## 戯神ちゃん（混沌）に専用枠は無い。見た目だけ外宇宙枠を使う。
	"chaos": ["res://art/pixel/ui/frame_card_outer_9.png", 16],
}
## styles.css glow-greatold / glow-elder / glow-outer の drop-shadow 色。
## 発光は加算合成なので、棚色のような暗い色だとほぼ見えない。枠のハイライトに寄せて明るくしてある。
const MYTHOS_GLOW_COLOR := {
	"greatold": Color(0.063, 0.725, 0.506, 1.0),
	"elder": Color(0.980, 0.863, 0.510, 1.0),
	"outer": Color(0.627, 0.314, 0.902, 1.0),
	"all": Color(0.85, 0.55, 1.0, 1.0),
	"knight": Color(0.70, 0.76, 0.84, 1.0),
	"magic": Color(0.32, 0.62, 0.95, 1.0),
	"wind": Color(0.58, 0.86, 0.22, 1.0),
	"fire": Color(0.96, 0.28, 0.05, 1.0),
	"earth": Color(0.93, 0.66, 0.12, 1.0),
	"bastet": Color(0.96, 0.40, 0.55, 1.0),
	"water": Color(0.12, 0.68, 0.74, 1.0),
	"chaos": Color(0.627, 0.314, 0.902, 1.0),
}
## 効果テキスト中で強調する属性の字。色は枠グロー（MYTHOS_GLOW_COLOR）と揃える。
const BODY_KEYWORDS := {"水": "water", "火": "fire", "地": "earth", "風": "wind"}
## 効果テキストの収め方。フォントは下限 BODY_FONT_MIN まで縮め、フッターは
## 基準の高さから「イラストが残る上限」まで広げる。それでも溢れる分は clip で止める。
const BODY_FONT_MIN := 8
const BODY_FONT_MAX := 12
const BODY_FONT_PER_PX := 12.0  ## 本文幅 12px ごとに 1pt（128幅カード≒9pt、拡大表示≒13pt）
const FOOTER_BASE_H := 33.0
const FOOTER_MAX_RATIO := 0.6  ## ヘッダー下の領域のうちフッターが取れる割合の上限
const BODY_PAD_X := 4.0
const BODY_PAD_Y := 2.0
const HEADER_H := 19.0
const TAG_TONES := {
	"attack": Color("6b1f22"),
	"defense": Color("183c66"),
	"effect": Color("452267"),
}
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"
## 既存9-slice枠は 96px 幅。それより広い枠は NinePatch の patch_margin が
## 画面ピクセル直結のため、この幅へ焼いてから載せる。
const FRAME_CANONICAL_W := 96
## 余白判定。これ未満のアルファは枠の外（透明パディング）とみなす。
const FRAME_ALPHA_CUT := 0.10
## 輪郭に接するこれ未満の半透明は、縮小やアンチエイリアスの薄い縁なので落とす。
const FRAME_FRINGE_SOLID := 0.98
## 96px 枠でも、不透明な絵がこの画素以上内側にあるときは余白ごと焼き直す（water）。
const FRAME_INSET_BAKE := 4

static var _ninepatch_tex_cache: Dictionary = {}
static var _ninepatch_margin_cache: Dictionary = {}

var card_uid: String = ""
var _interactive: bool = true
var _frame: NinePatchRect
var _inner: Control
var _header: ColorRect
var _art: TextureRect
var _title: Label
var _type: Label
var _cost: Label
var _body: RichTextLabel
var _footer: ColorRect
var _body_plain: String = ""
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
	_body_plain = str(definition.get("text", ""))
	_body.text = _highlight_keywords(_body_plain)
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
## 96px より広い枠は 96px 幅へ縮小し、外側の透明余白を切り落としてから載せる。
## 余白を残すと枠がカード端から浮いて内側に縮んで見える。
## 縮小（LANCZOS）と、元から半透明フチのある枠は輪郭の中間アルファを落としてから測る。
## 端まで不透明な既存 96px 枠は ArtCache / ResourceLoader のまま（見た目を変えない）。
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
	var widen: bool = src_w > FRAME_CANONICAL_W * 2
	if not widen and _content_inset(img) < FRAME_INSET_BAKE:
		var imported: Texture2D = _imported_texture(path)
		if imported != null:
			_ninepatch_tex_cache[path] = imported
			return imported
	if widen:
		var nh: int = maxi(1, int(round(float(img.get_height()) * float(FRAME_CANONICAL_W) / float(src_w))))
		img.resize(FRAME_CANONICAL_W, nh, Image.INTERPOLATE_LANCZOS)
		img.fix_alpha_edges()
	_strip_contour_fringe(img)
	img = _crop_frame_padding(img)
	_ninepatch_margin_cache[path] = _measure_frame_margin(img)
	var baked: Texture2D = ImageTexture.create_from_image(img)
	_ninepatch_tex_cache[path] = baked
	return baked


## 縮小した枠と、透明余白を焼き直した枠だけ実測値を返す。端まで不透明な 96px 枠は fallback。
static func ninepatch_margin(path: String, fallback: int) -> int:
	if path.is_empty():
		return fallback
	if not _ninepatch_margin_cache.has(path):
		ninepatch_texture(path)
	if _ninepatch_margin_cache.has(path):
		return int(_ninepatch_margin_cache[path])
	return fallback


static func _crop_frame_padding(img: Image) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < FRAME_ALPHA_CUT:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < 0:
		return img
	if min_x == 0 and min_y == 0 and max_x == w - 1 and max_y == h - 1:
		return img
	return img.get_region(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))


## 不透明画素がテクスチャ端から何px内側にあるか。0 なら端まで絵がある。
static func _content_inset(img: Image) -> int:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < FRAME_ALPHA_CUT:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < 0:
		return 0
	var right: int = w - 1 - max_x
	var bottom: int = h - 1 - max_y
	return mini(mini(min_x, min_y), mini(right, bottom))


## 透明に接する中間アルファだけを落とす。内側の塗り（完全不透明）は触らない。
static func _strip_contour_fringe(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var kill: Array[Vector2i] = []
	for y in h:
		for x in w:
			var a: float = img.get_pixel(x, y).a
			if a >= FRAME_FRINGE_SOLID or a < FRAME_ALPHA_CUT:
				continue
			var touch: bool = x == 0 or y == 0 or x == w - 1 or y == h - 1
			if not touch and img.get_pixel(x - 1, y).a < FRAME_ALPHA_CUT:
				touch = true
			if not touch and img.get_pixel(x + 1, y).a < FRAME_ALPHA_CUT:
				touch = true
			if not touch and img.get_pixel(x, y - 1).a < FRAME_ALPHA_CUT:
				touch = true
			if not touch and img.get_pixel(x, y + 1).a < FRAME_ALPHA_CUT:
				touch = true
			if touch:
				kill.append(Vector2i(x, y))
	for i in kill.size():
		var p: Vector2i = kill[i]
		var c: Color = img.get_pixel(p.x, p.y)
		c.a = 0.0
		img.set_pixel(p.x, p.y, c)


## 四辺の中央で、端から内側の透明窓までの画素を測り、一番厚い辺に合わせる。
static func _measure_frame_margin(img: Image) -> int:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cap: int = int(mini(w, h) / 2) - 1
	if cap < 4:
		return maxi(1, cap)
	var sides: Array = [
		_side_thickness(img, true, true),
		_side_thickness(img, true, false),
		_side_thickness(img, false, true),
		_side_thickness(img, false, false),
	]
	var thick: int = 4
	for s in sides:
		if int(s) > thick:
			thick = int(s)
	return clampi(thick, 4, cap)


static func _side_thickness(img: Image, horizontal: bool, from_start: bool) -> int:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var runs: Array = []
	if horizontal:
		var y0: int = int(float(h) * 0.42)
		var y1: int = int(float(h) * 0.58)
		for y in range(y0, y1):
			runs.append(_inward_run(img, y, true, from_start))
	else:
		var x0: int = int(float(w) * 0.42)
		var x1: int = int(float(w) * 0.58)
		for x in range(x0, x1):
			runs.append(_inward_run(img, x, false, from_start))
	if runs.is_empty():
		return 4
	runs.sort()
	return int(runs[int(runs.size() / 2)])


static func _inward_run(img: Image, fixed: int, horizontal: bool, from_start: bool) -> int:
	var length: int = img.get_width() if horizontal else img.get_height()
	var seen: bool = false
	for i in length:
		var pos: int = i if from_start else (length - 1 - i)
		var a: float = img.get_pixel(pos if horizontal else fixed, fixed if horizontal else pos).a
		if not seen:
			if a >= FRAME_ALPHA_CUT:
				seen = true
			continue
		if a < FRAME_ALPHA_CUT:
			return i
	return 4


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
	_header.offset_bottom = HEADER_H
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_header)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 4
	_title.offset_top = 2
	_title.offset_right = -36
	_title.offset_bottom = HEADER_H - 2.0
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_title)

	_type = Label.new()
	_type.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_type.offset_left = -40
	_type.offset_top = 3
	_type.offset_right = -4
	_type.offset_bottom = HEADER_H - 3.0
	_type.add_theme_font_size_override("font_size", 7)
	_type.add_theme_color_override("font_color", Color("e9dcc1"))
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_type)

	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_top = HEADER_H
	_art.offset_bottom = -FOOTER_BASE_H
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_art)

	var cost_plate := ColorRect.new()
	cost_plate.position = Vector2(4, HEADER_H + 4.0)
	cost_plate.size = Vector2(22, 22)
	cost_plate.color = Color("161512")
	cost_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(cost_plate)

	_cost = Label.new()
	_cost.position = Vector2(4, HEADER_H + 5.0)
	_cost.size = Vector2(22, 20)
	_cost.add_theme_font_size_override("font_size", 11)
	_cost.add_theme_color_override("font_color", Color.WHITE)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_cost)

	_footer = ColorRect.new()
	_footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -FOOTER_BASE_H
	_footer.color = Color("16130f")
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_footer)

	## 属性キーワードを色付けするため RichTextLabel。高さとフォントは _fit_body() が決める。
	_body = RichTextLabel.new()
	_body.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_body.offset_left = BODY_PAD_X
	_body.offset_top = -FOOTER_BASE_H + BODY_PAD_Y
	_body.offset_right = -BODY_PAD_X
	_body.offset_bottom = -BODY_PAD_Y
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.fit_content = false
	_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.clip_contents = true
	_body.add_theme_font_size_override("normal_font_size", BODY_FONT_MIN)
	_body.add_theme_font_size_override("bold_font_size", BODY_FONT_MIN)
	_body.add_theme_color_override("default_color", Color("e3d9c2"))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(_body)
	## 保険：本文やフッターがどう計算されても、カードの内枠の外には描かない。
	_inner.clip_contents = true

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
	if frame_data.is_empty() and str(definition.get("type", "")) != "status":
		frame_data = FRAME_DEFAULT
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
	_frame_margin = ninepatch_margin(str(frame_data[0]), int(frame_data[1]))
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
	_fit_body()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_body()


## 「[」を先に逃がしてから、水・火・地・風を枠グローと同じ色の太字にする。
static func _highlight_keywords(text: String) -> String:
	var out: String = text.replace("[", "[lb]")
	for key in BODY_KEYWORDS.keys():
		var tint: Color = MYTHOS_GLOW_COLOR[BODY_KEYWORDS[key]]
		out = out.replace(str(key), "[b][color=#%s]%s[/color][/b]" % [tint.to_html(false), key])
	return out


## 本文をフッター内に収める。カード幅に応じた推奨サイズから始め、まずフッターを
## 上限まで伸ばし、それでも入らなければ BODY_FONT_MIN まで 1pt ずつ縮める。
## 高さは Font で折り返し後の行数を実測する（RichTextLabel の ARBITRARY 折り返しと同じ区切り）。
func _fit_body() -> void:
	if _body == null or _footer == null:
		return
	var card_size: Vector2 = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	var inner_w: float = card_size.x - 2.0 * _frame_margin
	var inner_h: float = card_size.y - 2.0 * _frame_margin
	var text_w: float = inner_w - 2.0 * BODY_PAD_X
	if text_w <= 0.0 or inner_h <= HEADER_H:
		return
	var footer_cap: float = maxf(FOOTER_BASE_H, floorf((inner_h - HEADER_H) * FOOTER_MAX_RATIO))
	var font: Font = _body.get_theme_font("normal_font")
	var start: int = clampi(int(text_w / BODY_FONT_PER_PX), BODY_FONT_MIN, BODY_FONT_MAX)
	var font_size: int = BODY_FONT_MIN
	var need: float = FOOTER_BASE_H
	for fs in range(start, BODY_FONT_MIN - 1, -1):
		font_size = fs
		need = _body_text_height(font, text_w, fs) + 2.0 * BODY_PAD_Y
		if need <= footer_cap:
			break
	var footer_h: float = clampf(ceilf(need), FOOTER_BASE_H, footer_cap)
	_body.add_theme_font_size_override("normal_font_size", font_size)
	_body.add_theme_font_size_override("bold_font_size", font_size)
	_footer.offset_top = -footer_h
	_body.offset_top = -footer_h + BODY_PAD_Y
	if _art != null:
		_art.offset_bottom = -footer_h


func _body_text_height(font: Font, width: float, font_size: int) -> float:
	if font == null or _body_plain.is_empty():
		return 0.0
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND
	return font.get_multiline_string_size(_body_plain, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, flags).y


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
