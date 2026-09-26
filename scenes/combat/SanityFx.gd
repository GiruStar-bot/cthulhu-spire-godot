class_name SanityFx
extends Control

## 正気度の演出（GDD docs/gdd-sanity-fx.md）。画面全体は動かさず、静止したドット絵を重ねるだけ。
##  - 払った（カードの代償）：雫が 1 粒ゲージへ飛ぶ（約0.3秒）＋ sanity_pay
##  - 削られた（恐怖・敵の吸収）：画面端のインクが 0.5 秒でにじんで引く＋ゲージのヒビ／2px 震え＋ sanity_hit
##  - 低い状態（SanityTiers の 3 段階）：四隅の縁取り、段階3で目の瞬き、わずかな彩度低下＋持続音
##    ＋パネル枠のインク染み（SanityFrameStains。四隅の多くはパネルに隠れるため）
## Combat のルート直下に置き、z_index で「敵より上・敵プレート/手札/HUD より下」に描く。

## 「削られた」ときにゲージのヒビ・震えを出してほしい合図（VitalsHud 側で描く）。
signal hit_shown(crack_tex: Texture2D, shake: bool)

## --- 美術素材（デザインくん / art/sanity-fx）。無ければ描かない（雫と端インクだけ代わりの描画あり）
## 雫：8x8 のコマを横に並べたシート（1コマ目＝飛ぶ雫、残り＝ゲージに染み込むコマ）
const TEX_DROP := "res://art/pixel/fx/sanity_drop.png"
## 端のインク：画面上端用の横長ストリップ（上が濃く下へ抜ける）。上下は反転、左右は回転して使う。
const TEX_EDGE := "res://art/pixel/fx/sanity_hit_edge.png"
const TEX_CORNERS: Array[String] = [
	"res://art/pixel/fx/sanity_corner_1.png",
	"res://art/pixel/fx/sanity_corner_2.png",
	"res://art/pixel/fx/sanity_corner_3.png",
]
## 目：12x8 のコマを横に並べたシート（0=開, 1=半, 2=閉, 3=半）。瞬きは 1→2→3→0。
const TEX_EYE := "res://art/pixel/fx/sanity_eye.png"
const TEX_GAUGE_CRACK := "res://art/pixel/fx/sanity_gauge_crack.png"
## 素材の基準解像度（デザインくんの素材は 1152x648 の等倍で描かれている）
const ART_BASE_H := 648.0
const EDGE_ART_BASE_W := 1152.0
const DROP_FRAME_W := 8
const EYE_FRAME_W := 12
const EYE_BLINK_FRAMES: Array[int] = [1, 2, 3, 0]
const DESAT_SHADER := preload("res://scenes/combat/sanity_desat.gdshader")

## 敵の立ち絵（EnemyRow z=1）より上、敵プレート（12）・浮き文字（15）・手札（20〜）・HUD（30）より下。
const FX_Z := 11
## 雫だけは手札の上からゲージへ飛ぶので HUD より手前。
const DROP_Z := 40
## 四隅の縁取りは画面短辺の 12% まで（UIくん指定）。
const CORNER_MAX_FRAC := 0.12
const DROP_FLIGHT := 0.3
const DROP_FALLBACK_COLOR := Color("1e3a2a")
const DROP_FALLBACK_SIZE := Vector2(6, 8)
const EDGE_IN := 0.1
const EDGE_OUT := 0.4
const EDGE_PEAK_ALPHA := 0.9
const EDGE_FALLBACK_COLOR := Color(0.03, 0.02, 0.04, 0.85)
const EDGE_FALLBACK_FRAC := 0.07
const CORNER_ALPHA: Array[float] = [0.0, 0.8, 0.9, 1.0]
const DESAT_BY_TIER: Array[float] = [0.0, 0.06, 0.12, 0.18]
const TIER_FADE := 0.6
const BLINK_MIN := 4.0
const BLINK_MAX := 7.0
const BLINK_FRAME := 0.05

var _active: bool = true
var _tier: int = 0
var _desat: ColorRect
var _desat_mat: ShaderMaterial
var _corner_root: Control
var _corners: Array[TextureRect] = []
var _eyes: Array[TextureRect] = []
var _edge_root: Control
var _edge_tween: Tween
var _tier_tween: Tween
var _blink_timer: Timer
var _blinking: bool = false
var _frames: SanityFrameStains


func _ready() -> void:
	name = "SanityFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = FX_Z
	_build()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	VideoSettings.get_instance().changed.connect(_on_reduce_motion_changed)
	_layout()


func _exit_tree() -> void:
	## 戦闘の外で持続音を鳴らさない
	AudioManager.stop_sanity_drone(0.2)


func _build() -> void:
	_desat_mat = ShaderMaterial.new()
	_desat_mat.shader = DESAT_SHADER
	_desat_mat.set_shader_parameter("amount", 0.0)
	_desat = ColorRect.new()
	_desat.name = "Desaturate"
	_desat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desat.material = _desat_mat
	_desat.visible = false
	add_child(_desat)

	_corner_root = _full_rect_control("Corners")
	_corner_root.modulate.a = 0.0
	for i in range(4):
		var corner := TextureRect.new()
		corner.name = "Corner%d" % i
		corner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		corner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		corner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## 左上用の素材を反転して 4 隅に使う（0:左上 1:右上 2:左下 3:右下）
		corner.flip_h = i == 1 or i == 3
		corner.flip_v = i == 2 or i == 3
		_corner_root.add_child(corner)
		_corners.append(corner)
		var eye := TextureRect.new()
		eye.name = "Eye%d" % i
		eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		eye.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eye.visible = false
		_corner_root.add_child(eye)
		_eyes.append(eye)

	_edge_root = _full_rect_control("EdgeInk")
	_edge_root.modulate.a = 0.0
	var edge_tex: Texture2D = _tex(TEX_EDGE)
	for side in ["top", "bottom", "left", "right"]:
		if edge_tex != null:
			_edge_root.add_child(_edge_strip(edge_tex, str(side)))
		else:
			_edge_root.add_child(_edge_gradient(str(side)))

	_frames = SanityFrameStains.new()
	add_child(_frames)

	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	_blink_timer.timeout.connect(_on_blink_timer)
	add_child(_blink_timer)


func _full_rect_control(node_name: String) -> Control:
	var c := Control.new()
	c.name = node_name
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## 上端用ストリップを 4 辺に置く（下=上下反転、左右=-90°回転）。
func _edge_strip(tex: Texture2D, side: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Edge_" + side
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.flip_v = side == "bottom" or side == "right"
	rect.set_meta("side", side)
	rect.set_meta("strip", true)
	return rect


## 素材が無いときの端インク：画面端の細い暗いグラデーション（歪みなし）。
func _edge_gradient(side: String) -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, EDGE_FALLBACK_COLOR)
	grad.set_color(1, Color(EDGE_FALLBACK_COLOR, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 64
	gt.height = 64
	match side:
		"top":
			gt.fill_from = Vector2(0.5, 0.0)
			gt.fill_to = Vector2(0.5, 1.0)
		"bottom":
			gt.fill_from = Vector2(0.5, 1.0)
			gt.fill_to = Vector2(0.5, 0.0)
		"left":
			gt.fill_from = Vector2(0.0, 0.5)
			gt.fill_to = Vector2(1.0, 0.5)
		_:
			gt.fill_from = Vector2(1.0, 0.5)
			gt.fill_to = Vector2(0.0, 0.5)
	var rect := TextureRect.new()
	rect.name = "Edge_" + side
	rect.texture = gt
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_meta("side", side)
	return rect


func _layout() -> void:
	## 画面基準（Combat ルートの最小サイズが画面より大きくなっても四隅がはみ出さないように）
	var view: Vector2 = get_viewport_rect().size
	var short_side: float = minf(view.x, view.y)
	var side_px: float = floorf(short_side * CORNER_MAX_FRAC)
	var art_scale: float = maxf(1.0, roundf(short_side / ART_BASE_H))
	var eye_size := Vector2(float(EYE_FRAME_W), 8.0) * 2.0 * art_scale
	var eye_inset: float = floorf(side_px * 0.16)
	for i in range(_corners.size()):
		var right: bool = i == 1 or i == 3
		var bottom: bool = i == 2 or i == 3
		var pos := Vector2(view.x - side_px if right else 0.0, view.y - side_px if bottom else 0.0)
		_corners[i].position = pos
		_corners[i].size = Vector2(side_px, side_px)
		var eye_pos := Vector2(view.x - eye_inset - eye_size.x if right else eye_inset, view.y - eye_inset - eye_size.y if bottom else eye_inset)
		_eyes[i].position = eye_pos
		_eyes[i].size = eye_size
	var thick: float = floorf(short_side * EDGE_FALLBACK_FRAC)
	for child in _edge_root.get_children():
		if not child.has_meta("side"):
			continue
		var rect := child as TextureRect
		if child.has_meta("strip"):
			_layout_strip(rect, view)
			continue
		match str(rect.get_meta("side")):
			"top":
				rect.position = Vector2.ZERO
				rect.size = Vector2(view.x, thick)
			"bottom":
				rect.position = Vector2(0.0, view.y - thick)
				rect.size = Vector2(view.x, thick)
			"left":
				rect.position = Vector2.ZERO
				rect.size = Vector2(thick, view.y)
			_:
				rect.position = Vector2(view.x - thick, 0.0)
				rect.size = Vector2(thick, view.y)


func _layout_strip(rect: TextureRect, view: Vector2) -> void:
	var tex_h: float = float(rect.texture.get_height())
	var thick: float = roundf(tex_h * view.x / EDGE_ART_BASE_W)
	rect.rotation = 0.0
	match str(rect.get_meta("side")):
		"top":
			rect.position = Vector2.ZERO
			rect.size = Vector2(view.x, thick)
		"bottom":
			rect.position = Vector2(0.0, view.y - thick)
			rect.size = Vector2(view.x, thick)
		"left":
			## -90°回転：ローカル上端（濃い側）が画面の左端に来る
			rect.rotation = -PI * 0.5
			rect.position = Vector2(0.0, view.y)
			rect.size = Vector2(view.y, thick)
		_:
			rect.rotation = -PI * 0.5
			rect.position = Vector2(view.x - thick, view.y)
			rect.size = Vector2(view.y, thick)


## 1 回の更新で減った量（理由別）を受け取り、演出と一発音を出す。
## 同じ更新で両方あれば「削られた」側だけ（GDD §4）。
func play_loss(paid: int, hit: int, drop_from: Vector2, gauge_rect: Rect2) -> void:
	if not _active:
		return
	if hit > 0:
		_show_edge_ink()
		hit_shown.emit(_tex(TEX_GAUGE_CRACK), not VideoSettings.is_reduce_motion())
		if not AudioManager.play_sanity_sfx("sanity_hit"):
			AudioManager.play_sfx("hurt_sanity")
	elif paid > 0:
		_spawn_drop(drop_from, gauge_rect)
		AudioManager.play_sanity_sfx("sanity_pay")


## 今の正気度から「低い状態」の段階を反映（見た目と持続音）。段階が下がる時も同じく戻す。
func set_sanity(sanity: int, max_sanity: int) -> void:
	if not _active:
		return
	var tier: int = SanityTiers.tier_for(sanity, max_sanity)
	AudioManager.play_sanity_drone(tier)
	if tier == _tier:
		return
	_tier = tier
	_apply_tier(true)


## 戦闘終了（勝利・敗北演出の開始）時：持続音と四隅を止め、以後は何も出さない。
func stop_all() -> void:
	_active = false
	AudioManager.stop_sanity_drone()
	_blink_timer.stop()
	_tier = 0
	_apply_tier(false)
	_frames.clear()


func current_tier() -> int:
	return _tier


## 段階に合わせて枠にインク染みを付けるパネル（HUD・ログ・ターン終了ボタンなど）。
func set_frame_panels(panels: Array[Control]) -> void:
	_frames.set_panels(panels)
	_frames.set_tier(_tier if _active else 0, false)


## 枠の染みがかぶってはいけない隣の要素の矩形を返す Callable（-> Array[Rect2]）。
func set_frame_neighbor_source(source: Callable) -> void:
	_frames.set_neighbor_source(source)


func _apply_tier(animate: bool) -> void:
	var tier: int = _tier
	var reduce: bool = VideoSettings.is_reduce_motion()
	if _tier_tween != null and _tier_tween.is_valid():
		_tier_tween.kill()
	var corner_tex: Texture2D = null
	if tier > 0:
		corner_tex = _tex(TEX_CORNERS[tier - 1])
	var target_alpha: float = CORNER_ALPHA[tier]
	var desat_amount: float = DESAT_BY_TIER[tier]
	var do_fade: bool = animate and not reduce
	if do_fade and _corner_root.modulate.a > 0.01:
		## いったん薄くしてから差し替え、段階の濃さへ戻す（クロスフェード相当）
		_tier_tween = create_tween()
		_tier_tween.tween_property(_corner_root, "modulate:a", 0.0, TIER_FADE * 0.5)
		_tier_tween.tween_callback(_set_tier_images.bind(corner_tex, tier))
		_tier_tween.tween_property(_corner_root, "modulate:a", target_alpha, TIER_FADE * 0.5)
	elif do_fade:
		_set_tier_images(corner_tex, tier)
		_tier_tween = create_tween()
		_tier_tween.tween_property(_corner_root, "modulate:a", target_alpha, TIER_FADE)
	else:
		_set_tier_images(corner_tex, tier)
		_corner_root.modulate.a = target_alpha
	_frames.set_tier(tier, animate)
	_desat.visible = desat_amount > 0.0
	_desat_mat.set_shader_parameter("amount", desat_amount)
	_restart_blink()


func _set_tier_images(corner_tex: Texture2D, tier: int) -> void:
	for corner in _corners:
		corner.texture = corner_tex
		corner.visible = corner_tex != null
	var eye_tex: Texture2D = _frame(_tex(TEX_EYE), EYE_FRAME_W, 0) if tier >= 3 else null
	for eye in _eyes:
		eye.texture = eye_tex
		eye.visible = eye_tex != null
	_blinking = false


func _show_edge_ink() -> void:
	if _edge_tween != null and _edge_tween.is_valid():
		_edge_tween.kill()
	_edge_root.modulate.a = 0.0
	_edge_tween = create_tween()
	_edge_tween.tween_property(_edge_root, "modulate:a", EDGE_PEAK_ALPHA, EDGE_IN).set_ease(Tween.EASE_OUT)
	_edge_tween.tween_property(_edge_root, "modulate:a", 0.0, EDGE_OUT).set_ease(Tween.EASE_IN)


func _spawn_drop(from: Vector2, gauge_rect: Rect2) -> void:
	var target: Vector2 = gauge_rect.get_center()
	var drop: Control
	var sheet: Texture2D = _tex(TEX_DROP)
	var drop_tex: Texture2D = _frame(sheet, DROP_FRAME_W, 0)
	var art_scale: float = maxf(1.0, roundf(minf(get_viewport_rect().size.x, get_viewport_rect().size.y) / ART_BASE_H))
	if drop_tex != null:
		var tr := TextureRect.new()
		tr.texture = drop_tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = drop_tex.get_size() * 2.0 * art_scale
		drop = tr
	else:
		var cr := ColorRect.new()
		cr.color = DROP_FALLBACK_COLOR
		cr.size = DROP_FALLBACK_SIZE * art_scale
		drop = cr
	drop.name = "SanityDrop"
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.z_as_relative = false
	drop.z_index = DROP_Z
	add_child(drop, true)
	var half: Vector2 = drop.size * 0.5
	var tw: Tween = drop.create_tween()
	if VideoSettings.is_reduce_motion():
		## 飛ばさず、ゲージの上でふっと消える
		drop.global_position = target - half
		tw.tween_property(drop, "modulate:a", 0.0, DROP_FLIGHT)
	else:
		drop.global_position = from - half
		tw.tween_property(drop, "global_position", target - half, DROP_FLIGHT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		## 着地：シートの残りのコマで「染み込む」
		if drop is TextureRect and sheet != null:
			var frames: int = sheet.get_width() / DROP_FRAME_W
			for f in range(1, frames):
				tw.tween_callback(_set_rect_texture.bind(drop, _frame(sheet, DROP_FRAME_W, f)))
				tw.tween_interval(0.04)
		tw.tween_property(drop, "modulate:a", 0.0, 0.08)
	tw.tween_callback(drop.queue_free)


func _restart_blink() -> void:
	_blink_timer.stop()
	if not _active or _tier < 3 or VideoSettings.is_reduce_motion():
		return
	if _tex(TEX_EYE) == null:
		return
	_blink_timer.start(randf_range(BLINK_MIN, BLINK_MAX))


## 4〜7 秒ごとに 1 つだけ瞬きする（タイマーは 1 本なので 2 つ同時にはならない）。
func _on_blink_timer() -> void:
	if not _active or _tier < 3 or VideoSettings.is_reduce_motion() or _blinking:
		return
	var eye: TextureRect = _eyes.pick_random()
	if eye == null or not eye.visible:
		_restart_blink()
		return
	_blinking = true
	var sheet: Texture2D = _tex(TEX_EYE)
	var tw: Tween = create_tween()
	for f in EYE_BLINK_FRAMES:
		tw.tween_callback(_set_rect_texture.bind(eye, _frame(sheet, EYE_FRAME_W, f)))
		tw.tween_interval(BLINK_FRAME)
	tw.tween_callback(_end_blink)


func _end_blink() -> void:
	_blinking = false
	_restart_blink()


func _set_rect_texture(rect: TextureRect, tex: Texture2D) -> void:
	if is_instance_valid(rect) and tex != null:
		rect.texture = tex


## 横並びシートの index 番目のコマ（シートが 1 コマ分より狭ければシートそのもの）。
func _frame(sheet: Texture2D, frame_w: int, index: int) -> Texture2D:
	if sheet == null:
		return null
	if sheet.get_width() < frame_w * 2:
		return sheet
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(float(frame_w * index), 0.0, float(frame_w), float(sheet.get_height()))
	return atlas


func _on_reduce_motion_changed(_enabled: bool) -> void:
	_restart_blink()


func _tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var res: Resource = ResourceLoader.load(path, "Texture2D")
	return res as Texture2D
