extends Sprite2D

## 横1列のシートを、コマごとの秒数で一度だけ再生して struck を出す。
## 光の柱・三叉の矛・ねこの手で共用。退くコマもシート側に描いてある。
## AtlasTexture.region の書き換えは Forward+ で画面に乗らないことがあるので、
## コマは最初に切り出して texture 自体を差し替える。

signal struck

var _frame_size: Vector2i = Vector2i(32, 32)
var _frames: int = 1
var _strike_at: int = 0
var _holds: Array = []
var _cells: Array[Texture2D] = []
var _t: float = 0.0
var _hit_sent: bool = false
var _playing: bool = false


func setup(sheet: Texture2D, frame_size: Vector2i, scale_px: float, strike_at: int, holds: Array, anchor_bottom: bool) -> void:
	_frame_size = frame_size
	_frames = maxi(1, int(sheet.get_width() / frame_size.x))
	_strike_at = clampi(strike_at, 0, _frames - 1)
	_holds = holds
	_slice(sheet)
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(scale_px, scale_px)
	## 下端をノード原点に置く。足元の輪はシートの下端に描く。
	if anchor_bottom:
		offset = Vector2(0.0, -float(frame_size.y) * 0.5)
	else:
		offset = Vector2.ZERO
	_set_frame(0)
	visible = false
	set_process(true)


func play() -> void:
	_t = 0.0
	_hit_sent = false
	_playing = true
	visible = true
	_set_frame(0)


func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	var idx: int = _index()
	_set_frame(idx)
	if idx >= _strike_at and not _hit_sent:
		_hit_sent = true
		struck.emit()
	if _finished():
		_playing = false
		visible = false
		queue_free()


func _slice(sheet: Texture2D) -> void:
	_cells.clear()
	hframes = 1
	vframes = 1
	var image: Image = sheet.get_image()
	if image == null or image.is_empty():
		texture = sheet
		hframes = _frames
		return
	for i in _frames:
		var cell: Image = image.get_region(Rect2i(i * _frame_size.x, 0, _frame_size.x, _frame_size.y))
		_cells.append(ImageTexture.create_from_image(cell))
	texture = _cells[0]


func _hold_at(i: int) -> float:
	if i >= 0 and i < _holds.size():
		return float(_holds[i])
	return 0.08


func _index() -> int:
	var acc: float = 0.0
	var last: int = _frames - 1
	for i in last:
		if _t < acc + _hold_at(i):
			return i
		acc += _hold_at(i)
	return last


func _finished() -> bool:
	var acc: float = 0.0
	for i in _frames:
		acc += _hold_at(i)
	return _t >= acc


func _set_frame(i: int) -> void:
	var col: int = clampi(i, 0, _frames - 1)
	if _cells.is_empty():
		frame = col
		return
	var next: Texture2D = _cells[col]
	if texture == next:
		return
	texture = next
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
