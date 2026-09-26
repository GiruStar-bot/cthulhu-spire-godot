class_name SanityTendril
extends TextureRect

## 触手 1 本（SanityTendrils が作る）。横 1 列のシート：伸びるコマ → 最後に待機 2 コマ。
## 伸びる：12fps で 1 回、待機：2 コマを 0.5 秒ずつ交互（1px の揺れは素材に描かれている）、
## 退く：伸びるコマを逆順に 2 倍速で流して消える。reduce_motion ON は伸びきったコマで止め、退くときは即消す。
## 固める（敗北時）：伸びきったコマで止めたまま残す。揺れ・瞬き・退くはもう無い（GDD §8）。
## 持ち越し（低い段階のまま次の戦闘へ）：伸びるアニメなしで伸びきったコマから出し、そのまま待機へ。
## 重ねの層（add_layer）：別の所（別の z）に描く同じ大きさのシート。コマ番号・表示・位置はこの 1 本が決め、
## 層は写すだけ（タイマーは 1 つ）。段階3の HUD の背面に使う。


## 写すだけの層。frame_index はいつも持ち主と同じ。
class Layer extends TextureRect:
	var frame_index: int = 0
	var _atlas: AtlasTexture
	var _frame_size: Vector2i

	func setup(sheet: Texture2D, frame_size: Vector2i, scale_px: float) -> void:
		_frame_size = frame_size
		_atlas = AtlasTexture.new()
		_atlas.atlas = sheet
		texture = _atlas
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(frame_size) * scale_px
		visible = false

	func set_frame(index: int) -> void:
		frame_index = index
		_atlas.region = Rect2(float(index * _frame_size.x), 0.0, float(_frame_size.x), float(_frame_size.y))

enum Mode { HIDDEN, GROW, IDLE, STATIC, RETRACT, FROZEN }

const FPS := 12.0
const RETRACT_SPEED := 2.0
const IDLE_FRAMES := 2
const IDLE_STEP := 0.5
## 目の瞬き（sanity_eye.png：12x8 のコマ 4 つ＝開・半・閉・半。瞬きは 1→2→3→0）
const EYE_FRAME := Vector2i(12, 8)
const EYE_BLINK_FRAMES: Array[int] = [1, 2, 3, 0]
const BLINK_FRAME := 0.05
const BLINK_MIN := 4.0
const BLINK_MAX := 7.0

var mode: Mode = Mode.HIDDEN
var frame_index: int = 0
var art_scale: float = 3.0
var _sheet: Texture2D
var _frame_size: Vector2i
var _grow: int = 0
var _t: float = 0.0
var _atlas: AtlasTexture
var _eye: TextureRect
var _eye_frames: Array[Texture2D] = []
var _eye_pos: Array[Vector2i] = []
var _blink_left: float = 0.0
var _blink_step: int = -1
var blink_count: int = 0
var _layers: Array[Layer] = []


## frames：シートのコマ数（成長＋待機 2）。-1 はシートの幅から数える。幅が足りなければ幅に合わせる。
func setup(sheet: Texture2D, frame_size: Vector2i, scale_px: float, frames: int = -1) -> void:
	_sheet = sheet
	_frame_size = frame_size
	art_scale = scale_px
	var in_sheet: int = sheet.get_width() / frame_size.x
	if frames > 0 and frames != in_sheet:
		push_warning("SanityTendril: %s は %d コマ（指定 %d）" % [sheet.resource_path, in_sheet, frames])
	var n: int = mini(frames, in_sheet) if frames > 0 else in_sheet
	_grow = maxi(1, n - IDLE_FRAMES)
	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	texture = _atlas
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(frame_size) * art_scale
	visible = false
	_set_frame(0)


func grow_count() -> int:
	return _grow


func grow_duration() -> float:
	return float(_grow) / FPS


func retract_duration() -> float:
	return grow_duration() / RETRACT_SPEED


## 瞬き用の目。idle_eye_pos は待機コマごとの目の左上（素材の px）。
func enable_eye(eye_frames: Array[Texture2D], idle_eye_pos: Array[Vector2i]) -> void:
	_eye_frames = eye_frames
	_eye_pos = idle_eye_pos
	_eye = TextureRect.new()
	_eye.name = "EyeBlink"
	_eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_eye.stretch_mode = TextureRect.STRETCH_SCALE
	_eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eye.size = Vector2(EYE_FRAME) * art_scale
	_eye.visible = false
	add_child(_eye)


## 同じ大きさ・同じコマ割りのシートを写す層を作って返す（置き場所は呼ぶ側が決める）。
func add_layer(sheet: Texture2D) -> Layer:
	var l := Layer.new()
	l.setup(sheet, _frame_size, art_scale)
	_layers.append(l)
	l.set_frame(frame_index)
	_sync_layer_visibility()
	return l


func layer(i: int) -> Layer:
	if i < 0 or i >= _layers.size() or not is_instance_valid(_layers[i]):
		return null
	return _layers[i]


## 層の位置を持ち主に合わせる（SanityTendrils が位置を決めるたびに呼ぶ）
func sync_layers() -> void:
	for l in _layers:
		if is_instance_valid(l) and l.is_inside_tree():
			l.global_position = global_position


func _sync_layer_visibility() -> void:
	var shown: bool = is_visible_in_tree() if is_inside_tree() else visible
	for l in _layers:
		if is_instance_valid(l):
			l.visible = shown


## 層も一緒に消す（持ち主を消すとき。勝ち・逃げ・パネルの付け直し）
func free_layers() -> void:
	for l in _layers:
		if is_instance_valid(l):
			l.visible = false
			l.queue_free()
	_layers.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_layer_visibility()
		sync_layers()
	elif what == NOTIFICATION_PREDELETE:
		for l in _layers:
			if is_instance_valid(l):
				l.queue_free()


func has_eye() -> bool:
	return _eye != null


func eye_node() -> TextureRect:
	return _eye


func play_grow(reduce: bool) -> void:
	if mode == Mode.FROZEN:
		return
	visible = true
	_t = 0.0
	if reduce:
		mode = Mode.STATIC
		_set_frame(_grow - 1)
	else:
		mode = Mode.GROW
		_set_frame(0)
	_reset_blink()


## 前の戦闘から持ち越した段階：伸びるアニメなしで伸びきったコマをすぐ出し、1 コマ分おいて待機へ
## （reduce_motion ON は伸びきったコマで静止）。
func show_grown(reduce: bool) -> void:
	visible = true
	_set_frame(_grow - 1)
	_reset_blink()
	if reduce:
		mode = Mode.STATIC
		_t = 0.0
	else:
		mode = Mode.IDLE
		## 負の間は伸びきったコマのまま（瞬きもしない）、0 から通常の待機
		_t = -1.0 / FPS


## 敗北時：伸びきったコマで固める（目は素材の開いた目のまま）。以後は揺れも瞬きも退きもしない。
## show_hidden=true（正気度0の敗北）は隠れている触手も即座に出して固める。
func freeze(show_hidden: bool = false) -> void:
	if not show_hidden and (mode == Mode.HIDDEN or not visible):
		return
	visible = true
	mode = Mode.FROZEN
	_t = 0.0
	_set_frame(_grow - 1)
	_reset_blink()


func is_frozen() -> bool:
	return mode == Mode.FROZEN


func play_retract(reduce: bool) -> void:
	if mode == Mode.HIDDEN or mode == Mode.FROZEN:
		return
	if reduce:
		hide_now()
		return
	## 途中まで伸びていたら、その位置から戻す
	var start: int = mini(frame_index, _grow - 1)
	mode = Mode.RETRACT
	_t = float(_grow - 1 - start) / (FPS * RETRACT_SPEED)
	_set_frame(start)
	_reset_blink()


func hide_now() -> void:
	mode = Mode.HIDDEN
	visible = false
	_reset_blink()


## reduce_motion が途中で切り替わったとき（待機中なら静止 ↔ 揺れ）。
func set_reduce_motion(reduce: bool) -> void:
	if reduce and (mode == Mode.GROW or mode == Mode.IDLE):
		mode = Mode.STATIC
		_set_frame(_grow - 1)
		_reset_blink()
	elif reduce and mode == Mode.RETRACT:
		hide_now()
	elif not reduce and mode == Mode.STATIC:
		mode = Mode.IDLE
		_t = 0.0
		_reset_blink()


func _process(delta: float) -> void:
	_t += delta
	match mode:
		Mode.GROW:
			if _t >= grow_duration():
				mode = Mode.IDLE
				_t = 0.0
				_set_frame(_grow)
			else:
				_set_frame(mini(int(_t * FPS), _grow - 1))
		Mode.IDLE:
			if _t < 0.0:
				return
			_set_frame(_grow + (int(_t / IDLE_STEP) % IDLE_FRAMES))
			_tick_blink(delta)
		Mode.RETRACT:
			var back: int = int(_t * FPS * RETRACT_SPEED)
			if back >= _grow:
				hide_now()
			else:
				_set_frame(_grow - 1 - back)


func _set_frame(index: int) -> void:
	frame_index = index
	for l in _layers:
		if is_instance_valid(l):
			l.set_frame(index)
	if _atlas != null:
		_atlas.region = Rect2(float(index * _frame_size.x), 0.0, float(_frame_size.x), float(_frame_size.y))
	if _eye != null and _eye_pos.size() >= IDLE_FRAMES and index >= _grow:
		_eye.position = Vector2(_eye_pos[index - _grow]) * art_scale


func _reset_blink() -> void:
	_blink_step = -1
	_blink_left = randf_range(BLINK_MIN, BLINK_MAX)
	if _eye != null:
		_eye.visible = false


## 4〜7 秒ごとに 1 回だけ瞬く（待機中のみ。目はこの 1 本だけ）。
func _tick_blink(delta: float) -> void:
	if _eye == null or _eye_frames.size() < 4:
		return
	_blink_left -= delta
	if _blink_left > 0.0:
		return
	_blink_step += 1
	if _blink_step >= EYE_BLINK_FRAMES.size():
		_reset_blink()
		return
	if _blink_step == 0:
		blink_count += 1
	var f: int = EYE_BLINK_FRAMES[_blink_step]
	## 0（開）は素材に描かれた目そのものを見せる
	_eye.visible = f != 0
	_eye.texture = _eye_frames[f]
	_blink_left = BLINK_FRAME
