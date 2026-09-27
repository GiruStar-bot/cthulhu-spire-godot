extends Sprite2D

## 触手カードの地面攻撃。シート形式と状態機械は SanityTendril と同じ考え方
## （横1列、12fpsで伸びる、退くときは逆再生の2倍速）。長い待機は無い。
## 伸びきったコマで struck を出し、少しだけ見せてから地面へ戻る。
## 見た目は正気度の細い青緑触手ではなく、別素材の太いタコの足。

signal struck

const FPS := 12.0
const RETRACT_SPEED := 2.0
const HIT_HOLD := 0.08

var _frame_size: Vector2i = Vector2i(72, 88)
var _grow: int = 1
var _atlas: AtlasTexture
var _mode: int = 0
var _t: float = 0.0
var _hit_sent: bool = false


func setup(sheet: Texture2D, frame_size: Vector2i, scale_px: float) -> void:
	_frame_size = frame_size
	_grow = maxi(1, int(sheet.get_width() / frame_size.x))
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


func _process(delta: float) -> void:
	if _mode == 0:
		return
	_t += delta
	if _mode == 1:
		var idx: int = mini(int(_t * FPS), _grow - 1)
		_set_frame(idx)
		if idx >= _grow - 1 and not _hit_sent:
			_hit_sent = true
			struck.emit()
			_mode = 2
			_t = 0.0
	elif _mode == 2:
		_set_frame(_grow - 1)
		if _t >= HIT_HOLD:
			_mode = 3
			_t = 0.0
	else:
		var back: int = int(_t * FPS * RETRACT_SPEED)
		if back >= _grow:
			_mode = 0
			visible = false
			queue_free()
		else:
			_set_frame(_grow - 1 - back)


func _set_frame(index: int) -> void:
	if _atlas == null:
		return
	var i: int = clampi(index, 0, _grow - 1)
	_atlas.region = Rect2(float(i * _frame_size.x), 0.0, float(_frame_size.x), float(_frame_size.y))
