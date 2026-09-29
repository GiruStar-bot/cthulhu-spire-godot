extends Sprite2D

## 触手カードの地面攻撃。横1列のシートを、コマごとの秒数で再生する。
## 伸びる → 引いて溜める → 鞭のように短く叩く、で struck を出す。
## 退くときは逆再生の2倍速。飛沫はシート末尾の別コマで、生え始めだけ被せる。

signal struck

const RETRACT_FPS := 24.0
const HIT_HOLD := 0.07
const ACTION_FRAMES := 10
const STRIKE_FRAME := 8
const SPLASH_STEP := 0.10
## 0-1 生え際、2-3 伸び、4-5 タメ、6-7 鞭、8 叩き（struck）、9 余韻。
const FRAME_HOLD: Array[float] = [0.09, 0.09, 0.10, 0.10, 0.12, 0.18, 0.07, 0.05, 0.05, 0.06]

var _frame_size: Vector2i = Vector2i(72, 88)
var _grow: int = ACTION_FRAMES
var _strike_at: int = STRIKE_FRAME
var _atlas: AtlasTexture
var _sheet: Texture2D
var _mode: int = 0
var _t: float = 0.0
var _hit_sent: bool = false
var _splash: Sprite2D
var _splash_atlas: AtlasTexture
var _splash_t: float = -1.0


func setup(sheet: Texture2D, frame_size: Vector2i, scale_px: float) -> void:
	_frame_size = frame_size
	_sheet = sheet
	var cols: int = maxi(1, int(sheet.get_width() / frame_size.x))
	_grow = mini(ACTION_FRAMES, cols)
	_strike_at = mini(STRIKE_FRAME, _grow - 1)
	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	_atlas.filter_clip = true
	texture = _atlas
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(scale_px, scale_px)
	## 下端がノード原点。offset はスケール前の素材 px。
	offset = Vector2(0.0, -float(frame_size.y) * 0.5)
	_set_frame(0)
	visible = false


func play() -> void:
	_t = 0.0
	_hit_sent = false
	_mode = 1
	visible = true
	_set_frame(0)
	_start_splash()


func _process(delta: float) -> void:
	if _mode == 0:
		return
	_t += delta
	_tick_splash(delta)
	if _mode == 1:
		var idx: int = _grow_index()
		_set_frame(idx)
		if idx >= _strike_at and not _hit_sent:
			_hit_sent = true
			struck.emit()
		if idx >= _grow - 1:
			_mode = 2
			_t = 0.0
	elif _mode == 2:
		_set_frame(_grow - 1)
		if _t >= HIT_HOLD:
			_mode = 3
			_t = 0.0
	else:
		var back: int = int(_t * RETRACT_FPS)
		if back >= _grow:
			_mode = 0
			visible = false
			queue_free()
		else:
			_set_frame(_grow - 1 - back)


func _grow_index() -> int:
	var acc: float = 0.0
	var last: int = _grow - 1
	for i in last:
		var hold: float = 0.08
		if i < FRAME_HOLD.size():
			hold = FRAME_HOLD[i]
		if _t < acc + hold:
			return i
		acc += hold
	return last


func _start_splash() -> void:
	if _sheet == null:
		return
	var cols: int = maxi(1, int(_sheet.get_width() / _frame_size.x))
	if cols <= _grow:
		return
	_splash = Sprite2D.new()
	_splash_atlas = AtlasTexture.new()
	_splash_atlas.atlas = _sheet
	_splash_atlas.filter_clip = true
	_splash.texture = _splash_atlas
	_splash.centered = true
	_splash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_splash.offset = offset
	_splash.z_index = 1
	add_child(_splash)
	_splash_t = 0.0
	_show_splash_frame(0)


func _tick_splash(delta: float) -> void:
	if _splash == null or not is_instance_valid(_splash) or _splash_t < 0.0:
		return
	_splash_t += delta
	var cols: int = maxi(1, int(_sheet.get_width() / _frame_size.x))
	var extra: int = cols - _grow
	var si: int = int(_splash_t / SPLASH_STEP)
	if extra <= 0 or si >= extra:
		_splash.visible = false
		_splash.queue_free()
		_splash = null
		_splash_t = -1.0
		return
	_show_splash_frame(si)


func _show_splash_frame(index: int) -> void:
	if _splash_atlas == null:
		return
	var x: float = float((_grow + index) * _frame_size.x)
	_splash_atlas.region = Rect2(x, 0.0, float(_frame_size.x), float(_frame_size.y))
	_splash.texture = _splash_atlas


func _set_frame(index: int) -> void:
	if _atlas == null:
		return
	var i: int = clampi(index, 0, _grow - 1)
	_atlas.region = Rect2(float(i * _frame_size.x), 0.0, float(_frame_size.x), float(_frame_size.y))
	## Forward+ は region だけ変えても描き直さないことがある。
	texture = _atlas
