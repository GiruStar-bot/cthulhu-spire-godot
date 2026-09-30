extends Sprite2D

## Python の１画素ずつ描いた低解像度シートを、敵と同じ nearest の３倍で再生する。
## 接触コマに達したときだけ struck を送る。
signal struck

const PIXEL_SCALE := 3.0
const PILLAR_SHEET: Texture2D = preload("res://art/pixel/fx/nodens_pillar_px.png")
const TRIDENT_SHEET: Texture2D = preload("res://art/pixel/fx/trident_px.png")
const PAW_SHEET: Texture2D = preload("res://art/pixel/fx/cats_paw_px.png")
const TRIDENT_APPROACH := [155.0, 115.0, 75.0, 35.0, 0.0, 0.0, 0.0, 0.0]
const TRIDENT_DEPTH := [1.6, 1.45, 1.28, 1.13, 1.0, 1.0, 1.0, 1.0]
const PAW_DESCENT := [-82.0, -54.0, -23.0, 0.0, -7.0, -18.0, -28.0]
const PAW_STAMP_SCALE := [0.78, 0.87, 0.98, 1.14, 1.0, 0.9, 0.82]

static var _cache: Dictionary = {}

var _kind: String = ""
var _cells: Array[Texture2D] = []
var _holds: Array[float] = []
var _hit_frame: int = 0
var _elapsed: float = 0.0
var _hit_sent: bool = false
var _base_position: Vector2


func setup(kind_name: String, _body_width: float) -> void:
	_kind = kind_name
	var sheet: Texture2D
	var cell_size: Vector2i
	match _kind:
		"pillar":
			sheet = PILLAR_SHEET
			cell_size = Vector2i(112, 216)
			_holds = [0.12, 0.07, 0.06, 0.07, 0.12, 0.11, 0.12, 0.13]
			_hit_frame = 4
			offset = Vector2(0.0, -108.0)
		"trident":
			sheet = TRIDENT_SHEET
			cell_size = Vector2i(112, 112)
			_holds = [0.07, 0.07, 0.07, 0.08, 0.10, 0.09, 0.09, 0.10]
			_hit_frame = 4
			offset = Vector2(0.0, 6.0)
		"paw":
			sheet = PAW_SHEET
			cell_size = Vector2i(96, 96)
			_holds = [0.09, 0.08, 0.08, 0.10, 0.09, 0.09, 0.08]
			_hit_frame = 3
			offset = Vector2.ZERO
		_:
			push_error("Unknown card strike: " + kind_name)
			return
	_cells = _sliced_cells(kind_name, sheet, cell_size)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * PIXEL_SCALE
	texture = _cells[0]
	visible = false
	set_process(false)


func play() -> void:
	_elapsed = 0.0
	_hit_sent = false
	_base_position = position
	visible = true
	set_process(true)
	_show_frame(0)


func show_still() -> void:
	_base_position = position
	_hit_sent = true
	visible = true
	_show_frame(_hit_frame)
	set_process(false)
	var tw: Tween = create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_elapsed += delta
	var acc: float = 0.0
	for i in _cells.size():
		acc += _holds[i]
		if _elapsed < acc:
			_show_frame(i)
			if i >= _hit_frame and not _hit_sent:
				_hit_sent = true
				struck.emit()
			return
	if not _hit_sent:
		_hit_sent = true
		struck.emit()
	set_process(false)
	queue_free()


func _show_frame(i: int) -> void:
	texture = _cells[i]
	if _kind == "trident":
		# From the player's near field, straight into the target. Perspective
		# shrinks the weapon as it recedes; the tip meets the shockwave center.
		position = _base_position + Vector2(0.0, TRIDENT_APPROACH[i])
		scale = Vector2.ONE * PIXEL_SCALE * TRIDENT_DEPTH[i]
		rotation = 0.0
	elif _kind == "paw":
		position = _base_position + Vector2(0.0, PAW_DESCENT[i])
		scale = Vector2.ONE * PIXEL_SCALE * PAW_STAMP_SCALE[i]
	else:
		position = _base_position


static func _sliced_cells(kind_name: String, sheet: Texture2D, size: Vector2i) -> Array[Texture2D]:
	if _cache.has(kind_name):
		return _cache[kind_name]
	var cells: Array[Texture2D] = []
	var image: Image = sheet.get_image()
	for i in range(int(sheet.get_width() / size.x)):
		var cell: Image = image.get_region(Rect2i(i * size.x, 0, size.x, size.y))
		cells.append(ImageTexture.create_from_image(cell))
	_cache[kind_name] = cells
	return cells
