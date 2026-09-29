extends Node2D

## Card attacks share only playback and the visual-contact signal.
## Each subject is drawn from a shaded pixel sprite at the enemy's native pixel scale.
signal struck

const PIXEL_SCALE := 3.0
const PILLAR_ART: Texture2D = preload("res://art/pixel/fx/nodens_pillar_v2.png")
const TRIDENT_ART: Texture2D = preload("res://art/pixel/fx/trident_weapon_v2.png")
const PAW_ART: Texture2D = preload("res://art/pixel/fx/cats_paw_v2.png")

static var _pixel_cache: Dictionary = {}

var _kind: String = ""
var _texture: Texture2D
var _body_width: float = 120.0
var _elapsed: float = 0.0
var _top_y: float = 0.0
var _hit_sent: bool = false


func setup(kind_name: String, body_width: float) -> void:
	_kind = kind_name
	_body_width = body_width
	_texture = _pixel_texture(kind_name)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * PIXEL_SCALE
	set_process(false)


func play() -> void:
	_elapsed = 0.0
	_top_y = -position.y / PIXEL_SCALE
	_hit_sent = false
	set_process(true)
	queue_redraw()


func show_still() -> void:
	_top_y = -position.y / PIXEL_SCALE
	_elapsed = _contact_time() + 0.05
	_hit_sent = true
	set_process(false)
	queue_redraw()
	var tw: Tween = create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _contact_time() and not _hit_sent:
		_hit_sent = true
		struck.emit()
	queue_redraw()
	if _elapsed >= _duration():
		set_process(false)
		queue_free()


func _contact_time() -> float:
	match _kind:
		"pillar": return 0.42
		"trident": return 0.43
		"paw": return 0.31
	return 0.0


func _duration() -> float:
	match _kind:
		"pillar": return 1.0
		"trident": return 0.91
		"paw": return 0.72
	return 0.0


func _draw() -> void:
	if _texture == null:
		return
	match _kind:
		"pillar": _draw_pillar()
		"trident": _draw_trident()
		"paw": _draw_paw()


func _draw_pillar() -> void:
	var width_px: float = clampf(_body_width / PIXEL_SCALE * 1.8, 145.0, 180.0)
	var charge: float = clampf(_elapsed / 0.20, 0.0, 1.0)
	var ring_radius: float = width_px * (0.22 + charge * 0.13)
	if _elapsed < 0.42:
		_ring(Vector2.ZERO, ring_radius, 0.19, Color(1.0, 0.82, 0.38, charge * 0.78), 3.0)
	for i in 7:
		var angle: float = float(i) * TAU / 7.0
		var fleck_radius: float = ring_radius * (0.65 + 0.24 * sin(_elapsed * 10.0 + float(i)))
		var point: Vector2 = Vector2(cos(angle) * fleck_radius, sin(angle) * fleck_radius * 0.19 - 4.0)
		_pixel(Rect2(point, Vector2(2, 4)), Color(1.0, 0.92, 0.57, charge * 0.82))
	if _elapsed < 0.20:
		return
	# Reveal the image from y=0 downward. The base flare arrives exactly at struck.
	var descent: float = clampf((_elapsed - 0.20) / 0.22, 0.0, 1.0)
	var height_px: float = -_top_y
	var src_height: float = float(_texture.get_height()) * descent
	var fade: float = clampf((1.0 - _elapsed) / 0.35, 0.0, 1.0)
	var shaft: Rect2 = Rect2(-width_px * 0.5, _top_y, width_px, height_px * descent)
	var source: Rect2 = Rect2(0, 0, _texture.get_width(), src_height)
	if shaft.size.y > 0.0:
		# A broad distant aura and a sharper near layer give the shaft thickness.
		var aura: Rect2 = Rect2(shaft.position.x - 12, shaft.position.y, shaft.size.x + 24, shaft.size.y)
		draw_texture_rect_region(_texture, aura, source, Color(1.0, 0.76, 0.40, 0.24 * fade))
		draw_texture_rect_region(_texture, shaft, source, Color(1.0, 1.0, 1.0, 0.91 * fade))
	if _elapsed >= 0.42:
		var ripple: float = clampf((_elapsed - 0.42) / 0.34, 0.0, 1.0)
		_ring(Vector2(0, 2), ring_radius * (1.0 + ripple * 1.15), 0.20, Color(1.0, 0.88, 0.46, (1.0 - ripple) * 0.58), 2.0)
		for i in 9:
			var drift: float = float(i - 4) * (8.0 + ripple * 5.0)
			_pixel(Rect2(drift, -7.0 - float(i % 3) * 5.0 - ripple * 30.0, 2, 5), Color(1.0, 0.88, 0.5, (1.0 - ripple) * 0.8))


func _draw_trident() -> void:
	var flight: float = clampf((_elapsed - 0.08) / 0.35, 0.0, 1.0)
	var ease: float = flight * flight * (3.0 - 2.0 * flight)
	var recoil: float = clampf((_elapsed - 0.51) / 0.23, 0.0, 1.0)
	var tip: Vector2 = Vector2(-72.0 * (1.0 - ease) - recoil * 11.0, 53.0 * (1.0 - ease) + recoil * 7.0)
	var size_px: float = clampf(_body_width / PIXEL_SCALE * 1.35, 104.0, 132.0) * lerpf(0.72, 1.0, ease)
	var rect: Rect2 = Rect2(tip - Vector2(size_px * 0.91, size_px * 0.08), Vector2.ONE * size_px)
	var fade: float = clampf((0.91 - _elapsed) / 0.24, 0.0, 1.0)
	if _elapsed < 0.08:
		var shimmer: float = _elapsed / 0.08
		_pixel(Rect2(-75, 46, 3, 3), Color(0.52, 0.87, 0.96, shimmer))
		return
	# The artwork contains a tapered cylindrical haft and three shaded metal prongs.
	var trail: Rect2 = Rect2(rect.position + Vector2(-8, 6), rect.size)
	draw_texture_rect(_texture, trail, false, Color(0.24, 0.75, 0.95, 0.22 * fade * (1.0 - recoil)))
	draw_texture_rect(_texture, rect, false, Color(1.0, 1.0, 1.0, fade))
	if _elapsed < 0.43:
		for i in 3:
			var start: Vector2 = tip + Vector2(-20.0 - float(i) * 12.0, 19.0 + float(i) * 8.0)
			_stroke(start, start + Vector2(16, -6), Color(0.43, 0.86, 0.99, flight * (0.55 - float(i) * 0.1)), 2.0)
	else:
		var burst: float = clampf((_elapsed - 0.43) / 0.35, 0.0, 1.0)
		var flash: float = maxf(0.0, 1.0 - burst * 4.5)
		_ring(Vector2(0, 5), 7.0 + burst * 25.0, 0.65, Color(0.35, 0.88, 0.97, (1.0 - burst) * 0.56), 2.0)
		for i in 7:
			var side: float = float(i - 3)
			var x: float = side * (5.0 + burst * 7.0)
			var y: float = 10.0 - (12.0 + float((i * 3) % 5) * 3.0) * sin(burst * PI)
			_pixel(Rect2(x, y, 2.0 + float(i % 2), 4.0), Color(0.45, 0.87, 0.96, (1.0 - burst) * 0.82))
		_pixel(Rect2(-6, -2, 12, 4), Color(1.0, 0.99, 0.83, flash))


func _draw_paw() -> void:
	var descent: float = clampf((_elapsed - 0.09) / 0.22, 0.0, 1.0)
	var ease: float = descent * descent * (3.0 - 2.0 * descent)
	var recoil: float = clampf((_elapsed - 0.43) / 0.22, 0.0, 1.0)
	var width_px: float = clampf(_body_width / PIXEL_SCALE * 1.1, 70.0, 90.0) * lerpf(0.70, 1.0, ease)
	var height_px: float = width_px * (0.80 if _elapsed >= 0.31 and _elapsed < 0.40 else 1.0)
	var paw_y: float = -67.0 * (1.0 - ease) - recoil * 30.0
	var rect: Rect2 = Rect2(-width_px * 0.5, paw_y - height_px * 0.55, width_px, height_px)
	var fade: float = clampf((0.72 - _elapsed) / 0.22, 0.0, 1.0)
	if _elapsed < 0.09:
		return
	draw_texture_rect(_texture, Rect2(rect.position + Vector2(3, 5), rect.size), false, Color(0.12, 0.05, 0.13, 0.30 * fade))
	draw_texture_rect(_texture, rect, false, Color(1.0, 1.0, 1.0, fade))
	if _elapsed >= 0.31:
		var scratch: float = clampf((_elapsed - 0.31) / 0.28, 0.0, 1.0)
		for i in 3:
			var x: float = -11.0 + float(i) * 10.0
			_stroke(Vector2(x - 7.0, 7), Vector2(x + 5.0 + scratch * 9.0, 19.0 + scratch * 15.0), Color(1.0, 0.91, 0.85, (1.0 - scratch) * 0.95), 3.0)
		_ring(Vector2(0, 10), 9.0 + scratch * 25.0, 0.47, Color(1.0, 0.67, 0.76, (1.0 - scratch) * 0.72), 2.0)


func _ring(center: Vector2, radius: float, y_scale: float, color: Color, line_width: float) -> void:
	if color.a <= 0.0:
		return
	var last: Vector2 = center + Vector2(radius, 0)
	for i in range(1, 17):
		var angle: float = float(i) * TAU / 16.0
		var point: Vector2 = center + Vector2(cos(angle) * radius, sin(angle) * radius * y_scale)
		_stroke(last, point, color, line_width)
		last = point


func _pixel(rect: Rect2, color: Color) -> void:
	if color.a > 0.0:
		draw_rect(Rect2(rect.position.round(), rect.size.round()), color)


func _stroke(start: Vector2, end: Vector2, color: Color, width_px: float) -> void:
	if color.a > 0.0:
		draw_line(start.round(), end.round(), color, width_px, false)


static func _pixel_texture(kind_name: String) -> Texture2D:
	if _pixel_cache.has(kind_name):
		return _pixel_cache[kind_name] as Texture2D
	var source: Texture2D
	var target_size: Vector2i
	match kind_name:
		"pillar":
			source = PILLAR_ART
			target_size = Vector2i(192, 288)
		"trident":
			source = TRIDENT_ART
			target_size = Vector2i(128, 128)
		"paw":
			source = PAW_ART
			target_size = Vector2i(96, 96)
		_:
			return null
	var image: Image = source.get_image()
	image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	var pixel_art: Texture2D = ImageTexture.create_from_image(image)
	_pixel_cache[kind_name] = pixel_art
	return pixel_art
