extends Control
## PackOpenSequence.tsx を専用シーン化した開封演出。
## 裏向きで並べ、タップでめくる。遊戯王/DMP 寄りの手順。点滅は使わない。

signal closed

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const PIXEL_BUTTON := preload("res://scenes/ui/PixelButton.tscn")
const CARD_BACK := "res://art/pixel/ui/card_back_pack.png"
const CARD_BACK_FALLBACK := "res://art/pixel/ui/card_back.png"
const PACK_BASE := Vector2(220, 330)
const PACK_SCALE := 1.5
const CARD_ASPECT := 1.5
const CARD_REVEAL_SCALE := 2.0 / 3.0
const CARD_GAP := 12.0
const MYTHOS_ARCHETYPES := ["greatold", "elder", "outer", "all"]
const FLIP_HALF_S := 0.22
const DEAL_S := 0.20
const MYTHOS_POP_S := 0.50
## 属性の光（デザインくん #78 の色表のピーク値）。旧神＝石茶・旧支配者＝深緑・外宇宙＝紫・全＝金（外周に虹）。
## pack_glow_*.png がある場合は素材側の色を使い、これはフォールバックの放射グラデにだけ掛ける。
const MYTHOS_LIGHT := {
	"elder": Color("#C9A57A"),
	"greatold": Color("#4F9A7A"),
	"outer": Color("#A98BD1"),
	"all": Color("#F2E3A0"),
}
const GLOW_ART_FMT := "res://art/pixel/fx/pack_glow_%s.png"
const SPARKLE_ART_FMT := "res://art/pixel/fx/pack_sparkle_%s.png"
const NEW_BADGE_ART := "res://art/pixel/ui/badge_new.png"
const SPARKLE_FRAMES := 4
const SPARKLE_COUNT := {"elder": 2, "greatold": 3, "outer": 4, "all": 7}
const TELL_ALPHA_MIN := 0.3
const TELL_ALPHA_MAX := 0.7
const HIT_GLOW_SCALE := 1.15
const HIT_GLOW_FADE := {"elder": 0.4, "greatold": 0.5, "outer": 0.6, "all": 1.2}  ## 光の余韻を当たり音の尺に合わせる
## 当たりの強さ順（旧神 < 旧支配者 < 外宇宙 < 全）。音も光もこの順で派手にする。
const MYTHOS_RANK := {"elder": 1, "greatold": 2, "outer": 3, "all": 4}

## ---- 開封の尺と音（音楽くん・UIくん・働き者くんの仕様） ----
const SHAKE_STEP_S := 0.24  ## 揺れ 1 回の長さ。5 回で約 1.2 秒
const SHAKE_ANGLES := [-3.0, 3.0, -2.5, 2.5, 0.0]
const SHAKE_PITCHES := [1.0, 1.06, 1.12, 1.19, 1.26]  ## 半音ずつ上げる
const DEAL_STAGGER_S := 0.08
const DEAL_PITCH_STEP := 0.03  ## 配り 1 枚ごとに pitch_scale を +0.03
const HIT_HOLD_S := 0.4  ## 当たりを捲ったら拡大して止める時間（入力も止める）
const HIT_HOLD_SCALE := 1.16
const NEW_DELAY_S := 0.15  ## 当たり音と pack_new をぶつけない遅れ
const FLASH_ALPHA := 0.6  ## 破裂時の白フラッシュ。全面真っ白にはしない
const IDLE_FADE_OUT_S := 0.1
const BGM_DUCK_DB := -12.0
const BGM_RESTORE_S := 0.5
const TELL_PULSE_S := 0.6
## NEW バッジ（UIくん指定）：左上、24×10px、DotGothic16 8px、地 #D8B84A・文字 #1A1020
const NEW_BADGE_SIZE := Vector2(24, 10)
const NEW_BADGE_BG := Color("#D8B84A")
const NEW_BADGE_FG := Color("#1A1020")
const NEW_BADGE_FONT_SIZE := 8
const NEW_BADGE_HOP_PX := 2.0

var _card_ids: Array = []
var _new_flags: Array = []  ## 開封前に未所持だったカードか（同じパックで 2 枚目以降は false）
var _holding: bool = false  ## 当たり拡大中は次のめくりを受け付けない
var _flash: ColorRect
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
var _pack_size: Vector2 = PACK_BASE * PACK_SCALE
var _card_size: Vector2 = Vector2(176, 264)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


## owned_before：開封でコレクションに足す「前」の所持枚数（CollectionData.owned_card_counts() の写し）。
## null なら NEW 判定をしない。
func setup(pack_art: String, card_ids: Array, owned_before: Variant = null) -> void:
	_pack_art = pack_art
	_card_ids.clear()
	for item in card_ids:
		_card_ids.append(str(item))
	_flipped.clear()
	_new_flags.clear()
	var seen: Dictionary = {}
	for id in _card_ids:
		_flipped.append(false)
		var is_new: bool = owned_before is Dictionary and int((owned_before as Dictionary).get(id, 0)) <= 0 and not seen.has(id)
		_new_flags.append(is_new)
		seen[id] = true
	_phase = "idle"
	AudioManager.duck_bgm(BGM_DUCK_DB)
	AudioManager.play_sfx_loop("pack_idle")
	_show_idle()


func _exit_tree() -> void:
	## 閉じる以外の経路で消えても、ループと BGM の下げを残さない。
	AudioManager.stop_sfx_loop(IDLE_FADE_OUT_S)
	AudioManager.restore_bgm(BGM_RESTORE_S)


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
	_pack.custom_minimum_size = _pack_size
	_pack.size = _pack_size
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
	_skip.text = "全部めくる"
	_skip.custom_minimum_size = Vector2(120, 32)
	_skip.add_theme_font_size_override("font_size", 12)
	_skip.modulate = Color(1, 1, 1, 0.82)  ## 控えめなサブボタン扱い
	_skip.visible = false  ## 配り終わってから出す
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
	_flash = ColorRect.new()
	_flash.name = "BurstFlash"
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	resized.connect(_layout_chrome)
	call_deferred("_layout_chrome")


func _layout_chrome() -> void:
	var view: Vector2 = size
	if view.x < 8.0 or view.y < 8.0:
		view = get_viewport_rect().size
	_compute_stage_sizes(view)
	_skip.size = Vector2(120, 32)
	_skip.position = Vector2(view.x - 120.0 - 20.0, view.y - 32.0 - 20.0)  ## 右下
	_close.size = Vector2(160, 44)
	_close.position = Vector2(view.x * 0.5 - 80.0, view.y * 0.86)
	_pack.custom_minimum_size = _pack_size
	_pack.size = _pack_size
	_pack.pivot_offset = _pack_size * 0.5
	if _phase == "idle" or _phase == "shaking" or _phase == "bursting":
		_pack.position = view * 0.5 - _pack_size * 0.5
		_hint.size = Vector2(view.x, 24.0)
		_hint.position = Vector2(0.0, view.y * 0.5 + _pack_size.y * 0.5 + 12.0)
	else:
		_hint.size = Vector2(view.x, 24.0)
		_hint.position = Vector2(0.0, view.y * 0.86 - 36.0)
	_layout_row()


func _compute_stage_sizes(view: Vector2) -> void:
	var pack_h: float = minf(PACK_BASE.y * PACK_SCALE, view.y * 0.72)
	var pack_s: float = pack_h / PACK_BASE.y
	_pack_size = PACK_BASE * pack_s
	var n: int = maxi(_card_ids.size(), 4)
	var gap: float = CARD_GAP
	var side: float = 36.0
	var max_w: float = (view.x - side * 2.0 - gap * float(n - 1)) / float(n)
	var max_h: float = view.y * 0.62
	var card_h: float = minf(max_h, _pack_size.y)
	var card_w: float = card_h / CARD_ASPECT
	if card_w > max_w:
		card_w = max_w
		card_h = card_w * CARD_ASPECT
	_card_size = Vector2(card_w, card_h) * CARD_REVEAL_SCALE


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
	_skip.visible = false
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
	AudioManager.stop_sfx_loop(IDLE_FADE_OUT_S)
	_seq_tween = create_tween()
	for i in SHAKE_ANGLES.size():
		_seq_tween.tween_callback(AudioManager.play_sfx.bind("pack_shake", float(SHAKE_PITCHES[i])))
		_seq_tween.tween_property(_pack, "rotation_degrees", float(SHAKE_ANGLES[i]), SHAKE_STEP_S).set_trans(Tween.TRANS_SINE)
	_seq_tween.tween_callback(_burst_pack)


func _burst_pack() -> void:
	if _phase != "shaking":
		return
	_phase = "bursting"
	if _seq_tween != null and is_instance_valid(_seq_tween):
		_seq_tween.kill()
	## pack_burst の頭（破裂音）と白フラッシュを同じフレームに合わせる。
	AudioManager.play_sfx("pack_burst")
	_flash_once()
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
		var pack_center: Vector2 = size * 0.5 - _card_size * 0.5
		for i in n:
			var root: Control = _slots[i]["root"]
			var dest: Vector2 = root.position
			root.position = pack_center
			root.scale = Vector2(0.42, 0.42)
			root.modulate.a = 0.0
			var tw := root.create_tween()
			tw.tween_interval(DEAL_STAGGER_S * float(i))
			tw.tween_callback(AudioManager.play_sfx.bind("pack_deal", 1.0 + DEAL_PITCH_STEP * float(i)))
			tw.tween_property(root, "position", dest, DEAL_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(root, "scale", Vector2.ONE, DEAL_S)
			tw.parallel().tween_property(root, "modulate:a", 1.0, DEAL_S)
	_hint.visible = true
	_hint.text = "カードをタップしてめくる"
	## instant（全部めくる経由）のときは予兆も出さない。呼び出し側がそのまま全部捲る。
	if not instant:
		var deal_end_s: float = DEAL_STAGGER_S * float(maxi(0, n - 1)) + DEAL_S
		get_tree().create_timer(deal_end_s).timeout.connect(_on_deal_finished)
	_layout_chrome()


## 配り終わり：「全部めくる」を出し、伏せた当たりを脈打たせて予兆音を 1 回鳴らす。
func _on_deal_finished() -> void:
	if _phase != "revealing":
		return
	_skip.visible = true
	var any_tell: bool = false
	for i in _slots.size():
		if _flipped[i]:
			continue
		var arch: String = _arch_of(str(_slots[i]["def_id"]))
		if MYTHOS_ARCHETYPES.has(arch):
			_start_tell_pulse(_slots[i], arch)
			any_tell = true
	if any_tell:
		AudioManager.play_sfx("pack_tell")
	_layout_chrome()


## 伏せた当たりの予兆。背後の光輪の不透明度を 0.3〜0.7 で脈打たせる（強い属性ほど上限寄り）。
func _start_tell_pulse(slot: Dictionary, arch: String) -> void:
	var glow: TextureRect = slot["glow"]
	var tint: Color = Color.WHITE if bool(slot.get("glow_art", false)) else MYTHOS_LIGHT[arch]
	var rank: int = int(MYTHOS_RANK.get(arch, 1))
	var hi: float = lerpf(TELL_ALPHA_MIN + 0.15, TELL_ALPHA_MAX, float(rank - 1) / 3.0)
	glow.scale = Vector2.ONE
	glow.modulate = Color(tint.r, tint.g, tint.b, TELL_ALPHA_MIN)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", hi, TELL_PULSE_S).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate:a", TELL_ALPHA_MIN, TELL_PULSE_S).set_trans(Tween.TRANS_SINE)
	slot["tell_tween"] = tw


func _make_slot(index: int, def_id: String) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = _card_size
	root.size = _card_size
	root.pivot_offset = _card_size * 0.5
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_slot_input.bind(index))
	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.position = Vector2(-28, -28)
	glow.size = _card_size + Vector2(56, 56)
	glow.pivot_offset = glow.size * 0.5
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_arch: String = _arch_of(def_id)
	var glow_art: Texture2D = null
	if MYTHOS_ARCHETYPES.has(slot_arch):
		glow_art = _load_texture_safe(GLOW_ART_FMT % slot_arch)
	if glow_art != null:
		glow.texture = glow_art
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
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
	back.size = _card_size
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
	front.custom_minimum_size = _card_size
	front.size = _card_size
	front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.configure(fake, def, true, false, false)
	front.visible = false
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(front)
	var badge: Control = null
	if index < _new_flags.size() and bool(_new_flags[index]):
		badge = _make_new_badge()
		root.add_child(badge)
	return {
		"root": root,
		"glow": glow,
		"back": back,
		"front": front,
		"def_id": def_id,
		"badge": badge,
		"tell_tween": null,
		"glow_art": glow_art != null,
	}


## NEW バッジ。カード左上（右上のコストと重ならない位置）。捲るまで隠す。
## badge_new.png（デザインくん #78）があればそれを整数倍で、無ければ地色＋ドット文字で描く。
func _make_new_badge() -> Control:
	var art: Texture2D = _load_texture_safe(NEW_BADGE_ART)
	var badge: Control
	if art != null:
		var tr := TextureRect.new()
		tr.texture = art
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		badge = tr
	else:
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = NEW_BADGE_BG
		panel.add_theme_stylebox_override("panel", sb)
		var label := Label.new()
		label.text = "NEW"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", NEW_BADGE_FONT_SIZE)
		label.add_theme_color_override("font_color", NEW_BADGE_FG)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		badge = panel
	badge.name = "NewBadge"
	badge.custom_minimum_size = NEW_BADGE_SIZE
	badge.size = NEW_BADGE_SIZE
	badge.position = Vector2(4, 4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	badge.z_index = 2
	return badge


func _layout_row() -> void:
	var n: int = _slots.size()
	if n <= 0:
		return
	var view: Vector2 = size
	if view.x < 8.0:
		view = get_viewport_rect().size
	var gap: float = CARD_GAP
	var total_w: float = float(n) * _card_size.x + float(maxi(0, n - 1)) * gap
	var origin := Vector2((view.x - total_w) * 0.5, view.y * 0.46 - _card_size.y * 0.5)
	for i in n:
		var slot: Dictionary = _slots[i]
		var root: Control = slot["root"]
		root.custom_minimum_size = _card_size
		root.size = _card_size
		root.pivot_offset = _card_size * 0.5
		var glow: TextureRect = slot["glow"]
		glow.position = Vector2(-28, -28)
		glow.size = _card_size + Vector2(56, 56)
		glow.pivot_offset = glow.size * 0.5
		var back: TextureRect = slot["back"]
		back.size = _card_size
		var front: Control = slot["front"]
		front.custom_minimum_size = _card_size
		front.size = _card_size
		if root.get_meta("flipping", false):
			continue
		if _phase == "revealing" and root.modulate.a < 0.99:
			continue
		root.position = origin + Vector2(float(i) * (_card_size.x + gap), 0.0)


func _on_slot_input(event: InputEvent, index: int) -> void:
	if _phase != "revealing" or _holding:
		return
	if index < 0 or index >= _flipped.size():
		return
	if _flipped[index]:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_flip_card(index)


func _flip_card(index: int) -> void:
	if _phase != "revealing" or _holding:
		return
	if index < 0 or index >= _slots.size():
		return
	if _flipped[index]:
		return
	_flipped[index] = true
	var slot: Dictionary = _slots[index]
	var root: Control = slot["root"]
	root.set_meta("flipping", true)
	_stop_tell_pulse(slot)
	AudioManager.play_sfx("pack_flip")
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
	var badge: Control = slot.get("badge")
	if badge != null:
		badge.visible = true


func _after_flip(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot: Dictionary = _slots[index]
	var root: Control = slot["root"]
	root.set_meta("flipping", false)
	root.scale = Vector2.ONE
	var arch: String = _arch_of(str(slot["def_id"]))
	var is_new: bool = index < _new_flags.size() and bool(_new_flags[index])
	if slot.get("badge") != null:
		_hop_badge(slot["badge"])
	if MYTHOS_ARCHETYPES.has(arch):
		## 当たり：属性音＋光、0.4 秒拡大して止める。その間は次のめくりを受け付けない。
		_holding = true
		AudioManager.play_sfx("pack_hit_%s" % arch)
		if is_new:
			get_tree().create_timer(NEW_DELAY_S).timeout.connect(AudioManager.play_sfx.bind("pack_new"))
		_play_mythos_fx(slot, arch)
		get_tree().create_timer(MYTHOS_POP_S * 0.35 + HIT_HOLD_S).timeout.connect(_end_hold)
		return
	if is_new:
		AudioManager.play_sfx("pack_new")
	_check_done()


func _end_hold() -> void:
	_holding = false
	if not is_inside_tree():
		return
	_check_done()


func _hop_badge(badge: Control) -> void:
	var base_y: float = badge.position.y
	var tw := badge.create_tween()
	tw.tween_property(badge, "position:y", base_y - NEW_BADGE_HOP_PX, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "position:y", base_y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _stop_tell_pulse(slot: Dictionary) -> void:
	var tw = slot.get("tell_tween")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	slot["tell_tween"] = null
	(slot["glow"] as CanvasItem).modulate.a = 0.0


func _arch_of(def_id: String) -> String:
	var def: Dictionary = Cards.get_card(def_id)
	return str(def.get("archetype", ""))


## 破裂時に 1 フレームだけ白く飛ばす（不透明度 60%）。
func _flash_once() -> void:
	_flash.color = Color(1, 1, 1, FLASH_ALPHA)
	var tw := _flash.create_tween()
	tw.tween_interval(1.0 / 60.0)
	tw.tween_callback(func() -> void: _flash.color = Color(1, 1, 1, 0))


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


## 属性（旧支配者・旧神・外宇宙・全）のカード：光輪を不透明度 1.0 で出し、0.4 秒の拡大に合わせて
## 1.0 から 1.15 へ広げてからフェード。光の粒を散らす（全だけ多め・余韻長め）。
func _play_mythos_fx(slot: Dictionary, arch: String) -> void:
	var glow: TextureRect = slot["glow"]
	var root: Control = slot["root"]
	var tint: Color = Color.WHITE if bool(slot.get("glow_art", false)) else MYTHOS_LIGHT[arch]
	glow.modulate = Color(tint.r, tint.g, tint.b, 1.0)
	glow.scale = Vector2.ONE
	var glow_tw := glow.create_tween()
	glow_tw.tween_property(glow, "scale", Vector2(HIT_GLOW_SCALE, HIT_GLOW_SCALE), MYTHOS_POP_S * 0.35 + HIT_HOLD_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	glow_tw.tween_property(glow, "modulate:a", 0.0, float(HIT_GLOW_FADE.get(arch, 0.5))).set_trans(Tween.TRANS_SINE)
	var pop := root.create_tween()
	pop.tween_property(root, "scale", Vector2(HIT_HOLD_SCALE, HIT_HOLD_SCALE), MYTHOS_POP_S * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_interval(HIT_HOLD_S)
	pop.tween_property(root, "scale", Vector2.ONE, MYTHOS_POP_S * 0.65).set_trans(Tween.TRANS_SINE)
	_spawn_sparkles(root, arch)


func _spawn_sparkles(root: Control, arch: String) -> void:
	var tex: Texture2D = _load_texture_safe(SPARKLE_ART_FMT % arch)
	if tex == null:
		return
	var count: int = int(SPARKLE_COUNT.get(arch, 2))
	var center: Vector2 = _card_size * 0.5
	var life: float = float(HIT_GLOW_FADE.get(arch, 0.5)) + 0.2
	for i in count:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.hframes = SPARKLE_FRAMES
		sp.frame = 0
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2(2, 2)  ## 整数倍のみ
		sp.z_index = 3
		var ang: float = TAU * (float(i) + randf() * 0.6) / float(count)
		var start: Vector2 = center + Vector2(cos(ang), sin(ang)) * (_card_size.x * 0.35)
		var dest: Vector2 = center + Vector2(cos(ang), sin(ang)) * (_card_size.x * 0.75)
		sp.position = start
		root.add_child(sp)
		var tw := sp.create_tween()
		tw.tween_property(sp, "position", dest, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "frame", SPARKLE_FRAMES - 1, life)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, life).set_delay(life * 0.5)
		tw.tween_callback(sp.queue_free)


func _check_done() -> void:
	if _flipped.is_empty() or _phase == "done":
		return
	for flag in _flipped:
		if not flag:
			return
	_phase = "done"
	AudioManager.play_sfx("pack_done")
	_hint.text = ""
	_close.visible = true
	_skip.visible = false
	_layout_chrome()


## 「全部めくる」：一斉に捲り、鳴らすのは一番強い当たり音 1 回と pack_done だけ。
## 未所持が 1 枚でもあれば、当たり音の 0.15 秒後に pack_new を 1 回。NEW バッジは残す。
func _skip_all() -> void:
	if _phase == "done":
		return
	_holding = false
	AudioManager.stop_sfx_loop(IDLE_FADE_OUT_S)
	var best_arch: String = ""
	var any_new: bool = false
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
		if not _flipped[i]:
			var arch: String = _arch_of(str(slot["def_id"]))
			if int(MYTHOS_RANK.get(arch, 0)) > int(MYTHOS_RANK.get(best_arch, 0)):
				best_arch = arch
			if i < _new_flags.size() and bool(_new_flags[i]):
				any_new = true
		_stop_tell_pulse(slot)
		(slot["back"] as CanvasItem).visible = false
		(slot["front"] as CanvasItem).visible = true
		(slot["glow"] as CanvasItem).modulate.a = 0.0
		var badge: Control = slot.get("badge")
		if badge != null:
			badge.visible = true
		_flipped[i] = true
	_layout_row()
	if best_arch != "":
		AudioManager.play_sfx("pack_hit_%s" % best_arch)
	if any_new:
		get_tree().create_timer(NEW_DELAY_S).timeout.connect(AudioManager.play_sfx.bind("pack_new"))
	if best_arch != "":
		## 当たり音の頭が鳴り切ってから締める。
		get_tree().create_timer(HIT_HOLD_S).timeout.connect(AudioManager.play_sfx.bind("pack_done"))
	else:
		AudioManager.play_sfx("pack_done")
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
