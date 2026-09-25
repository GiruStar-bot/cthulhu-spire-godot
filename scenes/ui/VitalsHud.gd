class_name VitalsHud
extends Panel

## 戦闘・村で共用する HP/SAN 枠。エナジー箱と状態異常アイコンもここで描く。

const FRAME_PANEL := "res://art/ui/frame_panel.png"
## 原作 CSS: border-image-slice 62 / border-width 10px。
## 画像の透明余白を含めた柱は約62px。表示は石の見え方を優先して16pxへ縮小する。
const FRAME_SLICE := 62
const FRAME_DISPLAY := 16
## Scaled texture has ~4px transparent outer pad; expand frame so visible stone sits on the fill edge.
const FRAME_OUTSET := 4
## Godot 4 StyleBoxFlat.content_margin does NOT inset child Controls — use this for offsets/MarginContainer.
const FRAME_CONTENT_INSET := 22  # FRAME_DISPLAY + 6
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"
const ICON_STR := "res://art/pixel/status/strength.png"
const ICON_POISON := "res://art/pixel/status/poison.png"
const ICON_WEAK := "res://art/pixel/status/weak.png"
const ICON_SEAL_ATTACK := "res://art/pixel/status/seal_attack.png"
const ICON_SEAL_SKILL := "res://art/pixel/status/seal_skill.png"
const ICON_BLOCK := "res://art/pixel/status/block.png"
const ICON_SHELL := "res://art/shell.jpg"
const ENERGY_CAP := 5
const ENERGY_BOX := 12.0
const ACCENT := Color("3aa39a")
const BLOOD := Color("c45c4a")
const FROST := Color("9fd3ec")
const MUTED := Color("9a917f")
const PARCHMENT := Color("ede4d0")
const INK_TRACK := Color("161512")
const BORDER := Color("5c5447")

var _header: HBoxContainer
var _name_label: Label
var _floor_label: Label
var _hp_fill: ColorRect
var _hp_value: Label
var _san_fill: ColorRect
var _san_value: Label
var _status_row: HFlowContainer
var _frame: NinePatchRect
var _built: bool = false
@export var show_frame: bool = true
static var _scaled_frame_tex: Texture2D


func _ready() -> void:
	if not _built:
		_build()


func bind(data: Dictionary) -> void:
	if not _built:
		_build()
	var show_header: bool = data.get("show_header", true) and true
	_header.visible = show_header
	if show_header:
		var pname: String = str(data.get("player_name", ""))
		if pname == "":
			pname = "無名"
		_name_label.text = pname
		_floor_label.text = str(data.get("floor_text", ""))
		_floor_label.visible = _floor_label.text != ""
	_set_bar(_hp_fill, _hp_value, int(data.get("hp", 0)), int(data.get("max_hp", 0)))
	_set_bar(_san_fill, _san_value, int(data.get("sanity", 0)), int(data.get("max_sanity", 0)))
	_rebuild_status(data)
	_apply_frame_visible()


func set_show_frame(enabled: bool) -> void:
	show_frame = enabled
	_apply_frame_visible()


func _build() -> void:
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.x < 8.0:
		custom_minimum_size = Vector2(232, 96)
	_decorate()
	# StyleBoxFlat.content_margin does not pad children; inset the content root explicitly.
	var pad: int = FRAME_CONTENT_INSET if show_frame else 8
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, pad)
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_header = HBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = _make_label(PARCHMENT, 13)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_floor_label = _make_label(MUTED, 11)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header.add_child(_name_label)
	_header.add_child(_floor_label)
	col.add_child(_header)

	col.add_child(_make_bar_block("HP", Color("8b1e1e"), true))
	col.add_child(_make_bar_block("SAN", ACCENT, false))

	_status_row = HFlowContainer.new()
	_status_row.add_theme_constant_override("h_separation", 8)
	_status_row.add_theme_constant_override("v_separation", 4)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_status_row)


func _make_bar_block(caption: String, fill_color: Color, is_hp: bool) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := _make_label(MUTED, 10)
	cap.text = caption
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _make_label(PARCHMENT, 10)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(72, 0)
	row.add_child(cap)
	row.add_child(value)
	block.add_child(row)
	var fill: ColorRect = _make_bar(fill_color)
	block.add_child(fill.get_parent())
	if is_hp:
		_hp_fill = fill
		_hp_value = value
	else:
		_san_fill = fill
		_san_value = value
	return block


func _make_bar(fill_color: Color) -> ColorRect:
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(0, 8)
	track.color = INK_TRACK
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.color = fill_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	return fill


func _rebuild_status(data: Dictionary) -> void:
	var kids: Array = _status_row.get_children()
	for child in kids:
		_status_row.remove_child(child)
		child.queue_free()
	var show_energy: bool = data.get("show_energy", false) and true
	if show_energy:
		var energy: int = int(data.get("energy", 0))
		var max_energy: int = int(data.get("max_energy", 0))
		var nrg := _make_label(PARCHMENT, 11)
		nrg.text = "NRG %d/%d" % [energy, max_energy]
		_status_row.add_child(nrg)
		_status_row.add_child(_make_energy(energy, max_energy))
		var block_n: int = int(data.get("block", 0))
		_status_row.add_child(make_icon_stat(ICON_BLOCK, str(block_n), PARCHMENT))
	var show_shells: bool = data.get("show_shells", true) and true
	if show_shells:
		_status_row.add_child(make_icon_stat(ICON_SHELL, str(int(data.get("shells", 0))), PARCHMENT))
	var show_status: bool = data.get("show_status", false) and true
	if show_status:
		var strength: int = int(data.get("strength", 0))
		var weak: int = int(data.get("weak", 0))
		var poison: int = int(data.get("poison", 0))
		if strength > 0:
			_status_row.add_child(make_icon_stat(ICON_STR, str(strength), ACCENT))
		if weak > 0:
			_status_row.add_child(make_icon_stat(ICON_WEAK, str(weak), BLOOD))
		if poison > 0:
			_status_row.add_child(make_icon_stat(ICON_POISON, str(poison), ACCENT))
		## 寒気（ターン終了時にその値だけHPを失う。非致死）。専用アイコンが無いので文字で出す
		var cold: int = int(data.get("cold", 0))
		if cold > 0:
			var cold_lab := _make_label(FROST, 11)
			cold_lab.text = "寒気%d" % cold
			cold_lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			_status_row.add_child(cold_lab)
		var sealed_raw = data.get("sealed", "")
		var sealed: String = ""
		if sealed_raw != null:
			sealed = str(sealed_raw)
		if sealed != "" and sealed != "<null>":
			var seal_path: String = ICON_SEAL_ATTACK if sealed == "attack" else ICON_SEAL_SKILL
			var seal_txt: String = "攻撃" if sealed == "attack" else "技能"
			_status_row.add_child(make_icon_stat(seal_path, seal_txt, BLOOD))
		var powers: Array = data.get("powers", [])
		for power_id in powers:
			var lab := _make_label(MUTED, 10)
			lab.text = str(CombatLogic.POWER_TEXT.get(str(power_id), power_id))
			lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			_status_row.add_child(lab)
	_status_row.visible = _status_row.get_child_count() > 0


func _make_energy(current: int, maximum: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boxes: int = clampi(maximum, 0, ENERGY_CAP)
	var i: int = 0
	while i < boxes:
		row.add_child(_energy_box(i < current))
		i += 1
	if maximum > ENERGY_CAP:
		var extra := _make_label(ACCENT if current > ENERGY_CAP else MUTED, 11)
		extra.text = "+%d" % (maximum - ENERGY_CAP)
		row.add_child(extra)
	return row


func _energy_box(filled: bool) -> Panel:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(ENERGY_BOX, ENERGY_BOX)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	if filled:
		style.bg_color = ACCENT
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = BORDER
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	box.add_theme_stylebox_override("panel", style)
	return box


static func make_icon_stat(path: String, amount: String, tone: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_static(path)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lab := Label.new()
	lab.text = amount
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", tone)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(lab)
	return row


static func _load_static(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return load(FALLBACK_TEX) as Texture2D
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	return load(FALLBACK_TEX) as Texture2D


func _decorate() -> void:
	_frame = attach_panel_frame(self)
	_apply_frame_visible()


func _apply_frame_visible() -> void:
	if _frame:
		_frame.visible = show_frame
	var style := StyleBoxFlat.new()
	if show_frame:
		style.bg_color = Color(0.07, 0.065, 0.055, 0.92)
		# Kept in sync with FRAME_CONTENT_INSET; real inset is the content VBox pad.
		style.content_margin_left = FRAME_CONTENT_INSET
		style.content_margin_right = FRAME_CONTENT_INSET
		style.content_margin_top = FRAME_CONTENT_INSET
		style.content_margin_bottom = FRAME_CONTENT_INSET
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 2
		style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)


static func panel_frame_texture() -> Texture2D:
	if _scaled_frame_tex != null:
		return _scaled_frame_tex
	var src: Texture2D = load(FRAME_PANEL) as Texture2D
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	var factor: float = float(FRAME_DISPLAY) / float(FRAME_SLICE)
	var nw: int = maxi(1, int(round(float(img.get_width()) * factor)))
	var nh: int = maxi(1, int(round(float(img.get_height()) * factor)))
	img.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	_scaled_frame_tex = ImageTexture.create_from_image(img)
	return _scaled_frame_tex


static func attach_panel_frame(host: Control) -> NinePatchRect:
	var frame := NinePatchRect.new()
	frame.name = "PanelFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Push stone outside the fill rect so transparent patch pad does not let bg bleed past the frame.
	frame.offset_left = -float(FRAME_OUTSET)
	frame.offset_top = -float(FRAME_OUTSET)
	frame.offset_right = float(FRAME_OUTSET)
	frame.offset_bottom = float(FRAME_OUTSET)
	frame.texture = panel_frame_texture()
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.draw_center = false
	frame.patch_margin_left = FRAME_DISPLAY
	frame.patch_margin_top = FRAME_DISPLAY
	frame.patch_margin_right = FRAME_DISPLAY
	frame.patch_margin_bottom = FRAME_DISPLAY
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(frame)
	host.move_child(frame, 0)
	return frame


## Apply FULL_RECT child insets so text/scroll sit inside the stone (StyleBox content_margin alone is not enough).
static func apply_framed_content_inset(control: Control, inset: int = -1) -> void:
	var pad: int = FRAME_CONTENT_INSET if inset < 0 else inset
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = float(pad)
	control.offset_top = float(pad)
	control.offset_right = -float(pad)
	control.offset_bottom = -float(pad)


func _set_bar(fill: ColorRect, value_label: Label, current: int, maximum: int) -> void:
	value_label.text = "%d/%d" % [current, maximum]
	var ratio: float = 0.0
	if maximum > 0:
		ratio = clampf(float(current) / float(maximum), 0.0, 1.0)
	fill.anchor_right = ratio


func _make_label(tone: Color, font_px: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", tone)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
