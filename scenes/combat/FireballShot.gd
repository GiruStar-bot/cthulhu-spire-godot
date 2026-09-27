extends Sprite2D

## 火球カードの飛翔弾。炎のコマをループしながら飛び、着弾で struck を出して火花を散らす。
## 火花はシート末尾の別コマを、着弾点に一瞬だけ重ねる。

signal struck

const LOOP_FPS := 12.0
const LOOP_FRAMES := 4
const SPARK_STEP := 0.06

var _frame_size: Vector2i = Vector2i(40, 40)
var _loop: int = LOOP_FRAMES
var _atlas: AtlasTexture
var _sheet: Texture2D
var _mode: int = 0
var _t: float = 0.0
var _hit_sent: bool = false
var _spark: Sprite2D
var _spark_atlas: AtlasTexture
var _spark_t: float = -1.0


func setup(sheet: Texture2D, frame_size: Vector2i, scale_px: float) -> void:
	_frame_size = frame_size
	_sheet = sheet
	var cols: int = maxi(1, int(sheet.get_width() / frame_size.x))
	_loop = mini(LOOP_FRAMES, cols)
	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	_atlas.filter_clip = true
	texture = _atlas
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(scale_px, scale_px)
	_set_frame(0)
	visible = false


func launch(from_pos: Vector2, to_pos: Vector2, duration: float) -> void:
	position = from_pos
	visible = true
	_mode = 1
	_t = 0.0
	_hit_sent = false
	_set_frame(0)
	var tw: Tween = create_tween()
	tw.tween_property(self, "position", to_pos, maxf(0.05, duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_arrive)


func _process(delta: float) -> void:
	if _mode == 0:
		return
	if _mode == 1:
		_t += delta
		if _loop > 0:
			_set_frame(int(_t * LOOP_FPS) % _loop)
		return
	_tick_spark(delta)


func _on_arrive() -> void:
	if _hit_sent:
		return
	_hit_sent = true
	_mode = 2
	## 球は消して、同じ位置に火花だけ残す。親を隠すと子も消えるのでテクスチャだけ外す。
	texture = null
	struck.emit()
	_start_spark()


func _start_spark() -> void:
	if _sheet == null:
		queue_free()
		return
	var cols: int = maxi(1, int(_sheet.get_width() / _frame_size.x))
	if cols <= _loop:
		queue_free()
		return
	_spark = Sprite2D.new()
	_spark_atlas = AtlasTexture.new()
	_spark_atlas.atlas = _sheet
	_spark_atlas.filter_clip = true
	_spark.texture = _spark_atlas
	_spark.centered = true
	_spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spark.z_index = 1
	add_child(_spark)
	_spark_t = 0.0
	_show_spark_frame(0)


func _tick_spark(delta: float) -> void:
	if _spark == null or not is_instance_valid(_spark) or _spark_t < 0.0:
		return
	_spark_t += delta
	var cols: int = maxi(1, int(_sheet.get_width() / _frame_size.x))
	var extra: int = cols - _loop
	var si: int = int(_spark_t / SPARK_STEP)
	if extra <= 0 or si >= extra:
		_mode = 0
		queue_free()
		return
	_show_spark_frame(si)


func _show_spark_frame(index: int) -> void:
	if _spark_atlas == null:
		return
	var x: float = float((_loop + index) * _frame_size.x)
	_spark_atlas.region = Rect2(x, 0.0, float(_frame_size.x), float(_frame_size.y))


func _set_frame(index: int) -> void:
	if _atlas == null:
		return
	var i: int = clampi(index, 0, _loop - 1)
	_atlas.region = Rect2(float(i * _frame_size.x), 0.0, float(_frame_size.x), float(_frame_size.y))
