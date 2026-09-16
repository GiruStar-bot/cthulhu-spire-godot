extends Control
## PackOpenSequence.tsx を専用シーン化した開封演出。
## 裏向きで並べ、タップでめくる。遊戯王/DMP 寄りの手順。点滅は使わない。

signal closed

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const PIXEL_BUTTON := preload("res://scenes/ui/PixelButton.tscn")
const CARD_BACK := "res://art/pixel/ui/card_back_pack.png"
const CARD_BACK_FALLBACK := "res://art/pixel/ui/card_back.png"
const PACK_SIZE := Vector2(220, 330)
const CARD_SIZE := Vector2(176, 264)
const MYTHOS_ARCHETYPES := ["greatold", "elder", "outer"]
const FLIP_HALF_S := 0.22
const DEAL_S := 0.20
const RARE_POP_S := 0.50
const RARE_LIGHT := Color(1.0, 0.92, 0.62, 1.0)
const MYTHOS_LIGHT := {
	"greatold": Color(0.063, 0.725, 0.506, 1.0),
	"elder": Color(0.980, 0.863, 0.510, 1.0),
	"outer": Color(0.627, 0.314, 0.902, 1.0),
}

var _card_ids: Array = []
var _pack_art: String = ""
var _phase: String = "idle"
var _flipped: Array = []
var _slots: Array = []
var _dim: ColorRect
var _pack: TextureRect
var _hint: Label
var _skip: Button
var _close: Button
var _row: Control
var _idle_tween: Tween
var _seq_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func setup(pack_art: String, card_ids: Array) -> void:
	_pack_art = pack_art
	_card_ids.clear()
	for item in card_ids:
		_card_ids.append(str(item))
	_flipped.clear()
	for _i in _card_ids.size():
		_flipped.append(false)
	_phase = "idle"
	_show_idle()


func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://art/pixel/bg/loadout.jpg", "Texture2D"):
		bg.texture = load("res://art/pixel/bg/loadout.jpg")
	bg.modulate = Color(0.38, 0.34, 0.30, 1)
	add_child(bg)
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.03, 0.78)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	_pack = TextureRect.new()
	_pack.name = "PackImage"
	_pack.custom_minimum_size = PACK_SIZE
	_pack.size = PACK_SIZE
	_pack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pack.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pack.mouse_filter = Control.MOUSE_FILTER_STOP
	_pack.gui_input.connect(_on_pack_input)
	add_child(_pack)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.60, 0.92))
	_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.85))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_skip = PIXEL_BUTTON.instantiate() as Button
	_skip.text = "スキップ"
	_skip.custom_minimum_size = Vector2(108, 36)
	_skip.pressed.connect(_skip_all)
	add_child(_skip)
	_close = PIXEL_BUTTON.instantiate() as Button
	_close.text = "閉じる"
	_close.custom_minimum_size = Vector2(160, 44)
	_close.visible = false
	_close.pressed.connect(_on_close)
	add_child(_close)
	_row = Control.new()
	_row.name = "CardRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	resized.connect(_layout_chrome)
	call_deferred("_layout_chrome")


func _layout_chrome() -> void:
	var view: Vector2 = size
	if view.x < 8.0 or view.y < 8.0:
		view = get_viewport_rect().size
	_skip.position = Vector2(view.x - 128.0, 16.0)
	_skip.size = Vector2(108, 36)
	_close.size = Vector2(160, 44)
	_close.position = Vector2(view.x * 0.5 - 80.0, view.y * 0.86)
	_pack.pivot_offset = PACK_SIZE * 0.5
	if _phase == "idle" or _phase == "shaking" or _phase == "bursting":
		_pack.position = view * 0.5 - PACK_SIZE * 0.5
		_hint.size = Vector2(view.x, 24.0)
		_hint.position = Vector2(0.0, view.y * 0.5 + PACK_SIZE.y * 0.5 + 12.0)
	else:
		_hint.size = Vector2(view.x, 24.0)
		_hint.position = Vector2(0.0, view.y * 0.86 - 36.0)
	_layout_row()


func _show_idle() -> void:
	_pack.visible = true
	_pack.modulate = Color.WHITE
	_pack.scale = Vector2.ONE
	_pack.rotation_degrees = 0.0
	_pack.texture = _load_texture_safe(_pack_art)
	if _pack.texture == null:
		_pack.texture = _load_texture_safe(CARD_BACK_FALLBACK)
	_hint.visible = true
	_hint.text = "タップして開封"
	_close.visible = false
	_skip.visible = true
	_kill_idle()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_pack, "modulate", Color(1.10, 1.06, 0.98, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(_pack, "modulate", Color.WHITE, 1.2).set_trans(Tween.TRANS_SINE)
	_layout_chrome()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _phase == "idle":
			_begin_open()


func _on_pack_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _phase == "idle":
			_begin_open()


func _begin_open() -> void:
	if _phase != "idle":
		return
	_phase = "shaking"
	_hint.text = ""
	_kill_idle()
	_pack.modulate = Color.WHITE
	if _seq_tween != null and is_instance_valid(_seq_tween):
		_seq_tween.kill()
	_seq_tween = create_tween()
	_seq_tween.tween_property(_pack, "rotation_degrees", -3.0, 0.09)
	_seq_tween.tween_property(_pack, "rotation_degrees", 3.0, 0.09)
	_seq_tween.tween_property(_pack, "rotation_degrees", -2.0, 0.09)
	_seq_tween.tween_property(_pack, "rotation_degrees", 2.0, 0.09)
	_seq_tween.tween_property(_pack, "rotation_degrees", 0.0, 0.09)
	_seq_tween.tween_callback(_burst_pack)


func _burst_pack() -> void:
	if _phase != "shaking":
		return
	_phase = "bursting"
	if _seq_tween != null and is_instance_valid(_seq_tween):
		_seq_tween.kill()
	_seq_tween = create_tween()
	_seq_tween.tween_property(_pack, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_seq_tween.parallel().tween_property(_pack, "modulate", Color(1.18, 1.12, 1.02, 1.0), 0.18)
	_seq_tween.tween_property(_pack, "scale", Vector2(1.22, 1.22), 0.27).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_seq_tween.parallel().tween_property(_pack, "modulate", Color(1, 1, 1, 0), 0.27)
	_seq_tween.tween_callback(_deal_cards)


func _deal_cards(instant: bool = false) -> void:
	if _phase == "done":
		return
	_phase = "revealing"
	_pack.visible = false
	_clear_row()
	var n: int = _card_ids.size()
	for i in n:
		var slot: Dictionary = _make_slot(i, str(_card_ids[i]))
		_slots.append(slot)
		_row.add_child(slot["root"])
	_layout_row()
	if instant:
		for i in n:
			var root: Control = _slots[i]["root"]
			root.scale = Vector2.ONE
			root.modulate.a = 1.0
	else:
		var pack_center: Vector2 = size * 0.5 - CARD_SIZE * 0.5
		for i in n:
			var root: Control = _slots[i]["root"]
			var dest: Vector2 = root.position
			root.position = pack_center
			root.scale = Vector2(0.42, 0.42)
			root.modulate.a = 0.0
			var tw := root.create_tween()
			tw.tween_interval(0.08 * float(i))
			tw.tween_property(root, "position", dest, DEAL_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(root, "scale", Vector2.ONE, DEAL_S)
			tw.parallel().tween_property(root, "modulate:a", 1.0, DEAL_S)
	_hint.visible = true
	_hint.text = "カードをタップしてめくる"
	_layout_chrome()


func _make_slot(index: int, def_id: String) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = CARD_SIZE
	root.size = CARD_SIZE
	root.pivot_offset = CARD_SIZE * 0.5
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_slot_input.bind(index))
	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.position = Vector2(-28, -28)
	glow.size = CARD_SIZE + Vector2(56, 56)
	glow.pivot_offset = glow.size * 0.5
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture = _make_radial_glow_texture()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add_mat
	glow.modulate = Color(1, 1, 1, 0)
	glow.show_behind_parent = true
	root.add_child(glow)
	var back := TextureRect.new()
	back.name = "Back"
	back.position = Vector2.ZERO
	back.size = CARD_SIZE
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_tex: Texture2D = _load_texture_safe(CARD_BACK)
	if back_tex == null:
		back_tex = _load_texture_safe(CARD_BACK_FALLBACK)
	back.texture = back_tex
	root.add_child(back)
	var def: Dictionary = Cards.get_card(def_id)
	var fake: Dictionary = {"uid": "", "defId": def_id}
	var front: CombatCard = COMBAT_CARD.new()
	front.custom_minimum_size = CARD_SIZE
	front.size = CARD_SIZE
	front.configure(fake, def, true, false, false)
	front.visible = false
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(front)
	return {
		"root": root,
		"glow": glow,
		"back": back,
		"front": front,
		"def_id": def_id,
	}


func _layout_row() -> void:
	var n: int = _slots.size()
	if n <= 0:
		return
	var view: Vector2 = size
	if view.x < 8.0:
		view = get_viewport_rect().size
	var gap: float = 18.0
	var total_w: float = float(n) * CARD_SIZE.x + float(maxi(0, n - 1)) * gap
	var origin := Vector2((view.x - total_w) * 0.5, view.y * 0.42 - CARD_SIZE.y * 0.5)
	for i in n:
		var root: Control = _slots[i]["root"]
		if root.get_meta("flipping", false):
			continue
		root.position = origin + Vector2(float(i) * (CARD_SIZE.x + gap), 0.0)
		root.size = CARD_SIZE


func _on_slot_input(event: InputEvent, index: int) -> void:
	if _phase != "revealing":
		return
	if index < 0 or index >= _flipped.size():
		return
	if _flipped[index]:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_flip_card(index)


func _flip_card(index: int) -> void:
	if _phase != "revealing":
		return
	if index < 0 or index >= _slots.size():
		return
	if _flipped[index]:
		return
	_flipped[index] = true
	var slot: Dictionary = _slots[index]
	var root: Control = slot["root"]
	root.set_meta("flipping", true)
	AudioManager.play_sfx("select")
	var tw := root.create_tween()
	tw.tween_property(root, "scale:x", 0.04, FLIP_HALF_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_swap_face.bind(index))
	tw.tween_property(root, "scale:x", 1.0, FLIP_HALF_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_after_flip.bind(index))


func _swap_face(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot: Dictionary = _slots[index]
	(slot["back"] as CanvasItem).visible = false
	(slot["front"] as CanvasItem).visible = true


func _after_flip(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot: Dictionary = _slots[index]
	var root: Control = slot["root"]
	root.set_meta("flipping", false)
	root.scale = Vector2.ONE
	var def: Dictionary = Cards.get_card(str(slot["def_id"]))
	var rarity: String = str(def.get("rarity", "common"))
	var arch: String = str(def.get("archetype", ""))
	var is_rare: bool = rarity == "rare"
	var is_mythos: bool = MYTHOS_ARCHETYPES.has(arch)
	if is_rare or is_mythos:
		_play_rarity_fx(slot, is_rare, arch)
	_check_done()


func _make_radial_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.95),
		Color(1, 1, 1, 0.42),
		Color(1, 1, 1, 0.12),
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


func _play_rarity_fx(slot: Dictionary, is_rare: bool, arch: String) -> void:
	var glow: TextureRect = slot["glow"]
	var root: Control = slot["root"]
	var light: Color = RARE_LIGHT
	if MYTHOS_LIGHT.has(arch):
		light = MYTHOS_LIGHT[arch]
	glow.modulate = Color(light.r, light.g, light.b, 0.0)
	glow.scale = Vector2(0.82, 0.82)
	var peak: float = 0.95 if is_rare else 0.72
	var glow_tw := glow.create_tween()
	glow_tw.tween_property(glow, "modulate:a", peak, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	glow_tw.parallel().tween_property(glow, "scale", Vector2(1.28, 1.28), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	glow_tw.tween_property(glow, "modulate:a", 0.18 if is_rare else 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	glow_tw.parallel().tween_property(glow, "scale", Vector2(1.08, 1.08), 0.55)
	if is_rare:
		glow_tw.tween_property(glow, "modulate:a", 0.0, 0.90).set_trans(Tween.TRANS_SINE)
	var pop := root.create_tween()
	pop.tween_property(root, "scale", Vector2(1.16, 1.16), RARE_POP_S * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(root, "scale", Vector2.ONE, RARE_POP_S * 0.65).set_trans(Tween.TRANS_SINE)


func _check_done() -> void:
	if _flipped.is_empty():
		return
	for flag in _flipped:
		if not flag:
			return
	_phase = "done"
	_hint.text = ""
	_close.visible = true
	_skip.visible = false
	_layout_chrome()


func _skip_all() -> void:
	if _phase == "done":
		return
	_kill_idle()
	if _seq_tween != null and is_instance_valid(_seq_tween):
		_seq_tween.kill()
	_seq_tween = null
	if _slots.is_empty():
		_phase = "bursting"
		_deal_cards(true)
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var root: Control = slot["root"]
		root.set_meta("flipping", false)
		root.scale = Vector2.ONE
		root.modulate.a = 1.0
		(slot["back"] as CanvasItem).visible = false
		(slot["front"] as CanvasItem).visible = true
		(slot["glow"] as CanvasItem).modulate.a = 0.0
		_flipped[i] = true
	_layout_row()
	_phase = "done"
	_pack.visible = false
	_hint.text = ""
	_close.visible = true
	_skip.visible = false
	_layout_chrome()


func _on_close() -> void:
	closed.emit()
	queue_free()


func _clear_row() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_slots.clear()


func _kill_idle() -> void:
	if _idle_tween != null and is_instance_valid(_idle_tween):
		_idle_tween.kill()
	_idle_tween = null


func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return null
