class_name CardSequenceVfx
extends Sprite2D

## ９種類のカード固有シートを１回だけ再生する。画素は Python 側で描く。
## 横断する２種類は敵ごとに、残りは接触コマでダメージ表示を解放する。
signal struck
signal struck_at(uid: String)

const WHIRLWIND: Texture2D = preload("res://art/pixel/fx/whirlwind_px.png")
const WIND_ARROW: Texture2D = preload("res://art/pixel/fx/wind_arrow_px.png")
const MURAMASA: Texture2D = preload("res://art/pixel/fx/muramasa_px.png")
const COLD_FLAME: Texture2D = preload("res://art/pixel/fx/cold_flame_px.png")
const EARTHQUAKE: Texture2D = preload("res://art/pixel/fx/earthquake_px.png")
const CHARGE: Texture2D = preload("res://art/pixel/fx/charge_px.png")
const THECALL: Texture2D = preload("res://art/pixel/fx/thecall_px.png")
const COLLAPSE: Texture2D = preload("res://art/pixel/fx/collapse_px.png")
const ULTIMATE: Texture2D = preload("res://art/pixel/fx/ultimate_px.png")

static var _cache: Dictionary = {}

var _kind: String = ""
var _cells: Array[Texture2D] = []
var _holds: Array[float] = []
var _hit_frame: int = 0
var _elapsed: float = 0.0
var _hit_sent: bool = false
var _points: Array[Vector2] = []
var _uids: Array[String] = []
var _crossed: Dictionary = {}
var _base_position: Vector2 = Vector2.ZERO
var _start_x: float = 0.0
var _end_x: float = 0.0
var _arrow_origin: Vector2 = Vector2.ZERO


func setup(kind_name: String, points: Array[Vector2], uids: Array[String], view_size: Vector2) -> void:
	_kind = kind_name
	_points = points.duplicate()
	_uids = uids.duplicate()
	var source: Texture2D
	var cell_size: Vector2i
	match _kind:
		"whirlwind_px":
			source = WHIRLWIND
			cell_size = Vector2i(80, 112)
			_holds = [0.10, 0.09, 0.09, 0.12, 0.12, 0.10, 0.10, 0.12]
			offset = Vector2(0, -56)
		"wind_arrow_px":
			source = WIND_ARROW
			cell_size = Vector2i(96, 80)
			_holds = [0.08, 0.08, 0.08, 0.08, 0.10, 0.10, 0.10, 0.10, 0.10, 0.12]
			_hit_frame = 4
		"muramasa_px":
			source = MURAMASA
			cell_size = Vector2i(112, 112)
			_holds = [0.10, 0.09, 0.09, 0.11, 0.07, 0.11, 0.11, 0.10]
			_hit_frame = 4
		"cold_flame_px":
			source = COLD_FLAME
			cell_size = Vector2i(80, 112)
			_holds = [0.10, 0.09, 0.09, 0.09, 0.12, 0.11, 0.11, 0.10]
			_hit_frame = 4
			offset = Vector2(0, -56)
		"earthquake_px":
			source = EARTHQUAKE
			cell_size = Vector2i(112, 72)
			_holds = [0.09, 0.09, 0.09, 0.11, 0.12, 0.11, 0.10, 0.10]
			_hit_frame = 4
			offset = Vector2(0, -36)
		"charge_px":
			source = CHARGE
			cell_size = Vector2i(96, 72)
			_holds = [0.10, 0.10, 0.09, 0.12, 0.10, 0.10, 0.09, 0.09]
			_hit_frame = 3
		"thecall_px":
			source = THECALL
			cell_size = Vector2i(320, 180)
			_holds = [0.12, 0.11, 0.11, 0.11, 0.13, 0.14, 0.13, 0.12]
			_hit_frame = 5
		"collapse_px":
			source = COLLAPSE
			cell_size = Vector2i(320, 180)
			_holds = [0.11, 0.10, 0.09, 0.12, 0.12, 0.11, 0.10, 0.10]
			_hit_frame = 3
		"ultimate_px":
			source = ULTIMATE
			cell_size = Vector2i(320, 180)
			_holds = [0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0.13, 0.11, 0.10, 0.10]
			_hit_frame = 6
		_:
			push_error("Unknown card sequence VFX: " + kind_name)
			return
	_cells = _slice(kind_name, source, cell_size)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = _cells[0]
	if _is_screen():
		scale = Vector2(view_size.x / 320.0, view_size.y / 180.0)
		_base_position = view_size * 0.5
	else:
		scale = Vector2.ONE * (2.4 if _kind == "wind_arrow_px" else 3.0)
		_base_position = _points[0] if not _points.is_empty() else view_size * 0.5
	if _kind == "wind_arrow_px":
		_arrow_origin = Vector2(view_size.x * 0.15, view_size.y * 0.78)
	if _is_traversal():
		var min_x: float = _base_position.x
		var max_x: float = _base_position.x
		for point in _points:
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
		_start_x = min_x - (150.0 if _kind == "whirlwind_px" else 230.0)
		_end_x = max_x + (150.0 if _kind == "whirlwind_px" else 230.0)
	visible = false
	set_process(false)


func play() -> void:
	_elapsed = 0.0
	_hit_sent = false
	_crossed.clear()
	visible = true
	_show_frame(0)
	set_process(true)


func show_still() -> void:
	_elapsed = _elapsed_at_frame(_hit_frame)
	_hit_sent = true
	visible = true
	_show_frame(_hit_frame)
	set_process(false)
	if _is_traversal() or _kind == "wind_arrow_px":
		for uid in _uids:
			struck_at.emit(uid)
	else:
		struck.emit()
	var tw: Tween = create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_elapsed += delta
	var index: int = _frame_index()
	_show_frame(index)
	if _kind == "wind_arrow_px":
		if index >= _hit_frame and not _hit_sent:
			_hit_sent = true
			if not _uids.is_empty():
				struck_at.emit(_uids[0])
	elif _is_traversal():
		for i in _uids.size():
			var uid: String = _uids[i]
			if not _crossed.has(uid) and position.x >= _points[i].x:
				_crossed[uid] = true
				struck_at.emit(uid)
	elif index >= _hit_frame and not _hit_sent:
		_hit_sent = true
		struck.emit()
	if _elapsed >= _duration():
		if _kind == "wind_arrow_px":
			if not _hit_sent and not _uids.is_empty():
				struck_at.emit(_uids[0])
		elif _is_traversal():
			for uid in _uids:
				if not _crossed.has(uid):
					struck_at.emit(uid)
		elif not _hit_sent:
			struck.emit()
		set_process(false)
		queue_free()


func _show_frame(i: int) -> void:
	texture = _cells[i]
	position = _base_position
	if _kind == "wind_arrow_px":
		if i < _hit_frame:
			var travel: float = clampf(_elapsed / _elapsed_at_frame(_hit_frame), 0.0, 1.0)
			position = _arrow_origin.lerp(_base_position, travel)
			rotation = (_base_position - _arrow_origin).angle()
		else:
			rotation = 0.0
	elif _is_traversal():
		var reach: float = clampf(_elapsed / (_duration() * 0.85), 0.0, 1.0)
		position.x = lerpf(_start_x, _end_x, reach)
	elif _kind == "charge_px":
		var approach: Array[float] = [-240.0, -165.0, -80.0, 0.0, -30.0, -62.0, -68.0, -74.0]
		position.x = _base_position.x + approach[i]
		if i >= 4:
			position.y -= float(i - 3) * 5.0


func _frame_index() -> int:
	var acc: float = 0.0
	for i in _cells.size():
		acc += _holds[i]
		if _elapsed < acc:
			return i
	return _cells.size() - 1


func _elapsed_at_frame(index: int) -> float:
	var value: float = 0.0
	for i in index:
		value += _holds[i]
	return value


func _duration() -> float:
	var value: float = 0.0
	for hold in _holds:
		value += hold
	return value


func _is_screen() -> bool:
	return _kind == "thecall_px" or _kind == "collapse_px" or _kind == "ultimate_px"


func _is_traversal() -> bool:
	return _kind == "whirlwind_px"


static func _slice(kind_name: String, source: Texture2D, cell_size: Vector2i) -> Array[Texture2D]:
	if _cache.has(kind_name):
		return _cache[kind_name]
	var cells: Array[Texture2D] = []
	var image: Image = source.get_image()
	for i in range(int(source.get_width() / cell_size.x)):
		var cell: Image = image.get_region(Rect2i(i * cell_size.x, 0, cell_size.x, cell_size.y))
		cells.append(ImageTexture.create_from_image(cell))
	_cache[kind_name] = cells
	return cells
