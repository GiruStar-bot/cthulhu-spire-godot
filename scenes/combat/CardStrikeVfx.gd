extends Node2D

## Three card attacks drawn on a 3x pixel grid. The signal is emitted at visual contact.
signal struck

const PIXEL_SCALE := 3.0
const GOLD := Color(1.0, 0.78, 0.29)
const WHITE := Color(1.0, 0.97, 0.79)
const BLUE := Color(0.23, 0.73, 0.94)
const DARK_BLUE := Color(0.06, 0.20, 0.36)

var _kind: String = ""
var _elapsed: float = 0.0
var _hit_sent: bool = false
var _radius: float = 20.0


func setup(kind_name: String, body_width: float) -> void:
	_kind = kind_name
	_radius = clampf(body_width / PIXEL_SCALE * 0.24, 15.0, 31.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * PIXEL_SCALE
	set_process(false)


func play() -> void:
	_elapsed = 0.0
	_hit_sent = false
	set_process(true)
	queue_redraw()


func show_still() -> void:
	_elapsed = _contact_time() + 0.06
	_hit_sent = true
	set_process(false)
	queue_redraw()
	var tw: Tween = create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_elapsed += delta
	var hit_time: float = _contact_time()
	if _elapsed >= hit_time and not _hit_sent:
		_hit_sent = true
		struck.emit()
	queue_redraw()
	if _elapsed >= _duration():
		set_process(false)
		queue_free()


func _contact_time() -> float:
	match _kind:
		"pillar": return 0.34
		"trident": return 0.36
		"paw": return 0.25
	return 0.0


func _duration() -> float:
	match _kind:
		"pillar": return 0.83
		"trident": return 0.82
		"paw": return 0.60
	return 0.0


func _draw() -> void:
	match _kind:
		"pillar": _draw_pillar()
		"trident": _draw_trident()
		"paw": _draw_paw()


func _draw_pillar() -> void:
	var half_w: float = _radius
	var charge: float = clampf(_elapsed / 0.30, 0.0, 1.0)
	var fade: float = clampf((0.83 - _elapsed) / 0.28, 0.0, 1.0)
	var ring_w: float = half_w * (0.55 + charge * 0.45)
	# Ground marker arrives before the beam, so every target remains readable.
	_draw_ring(Vector2.ZERO, ring_w, 4.0, GOLD * Color(1, 1, 1, 0.32 + charge * 0.37))
	_draw_ring(Vector2(0, -1), ring_w * 0.62, 2.0, WHITE * Color(1, 1, 1, 0.55 * fade))
	for i in 5:
		var fleck_x: float = float(i - 2) * half_w * 0.44
		var fleck_y: float = -12.0 - float((i * 29) % 57) - charge * 15.0
		var flicker: float = 0.35 + 0.65 * absf(sin(_elapsed * 16.0 + float(i) * 2.1))
		_px(Rect2(fleck_x, fleck_y, 2, 4), Color(1.0, 0.78, 0.28, charge * flicker * fade))
	if _elapsed < 0.28:
		var thread_y: float = -142.0 + charge * 92.0
		_px(Rect2(-1, thread_y, 2, 24 + charge * 32), Color(1.0, 0.95, 0.67, charge * 0.8))
		return
	var fall: float = clampf((_elapsed - 0.28) / 0.06, 0.0, 1.0)
	var narrow: float = 1.0 if _elapsed < 0.57 else clampf((0.78 - _elapsed) / 0.21, 0.0, 1.0)
	var beam_half: float = maxf(1.0, roundf(half_w * fall * narrow))
	var beam_top: float = -154.0 * fall
	_px(Rect2(-beam_half * 0.82, beam_top, 4, -beam_top), Color(0.96, 0.57, 0.13, 0.24 * fade))
	_px(Rect2(beam_half * 0.82 - 4, beam_top, 4, -beam_top), Color(0.96, 0.57, 0.13, 0.24 * fade))
	_px(Rect2(-beam_half * 0.53, beam_top, 3, -beam_top), Color(1.0, 0.85, 0.38, 0.32 * fade))
	_px(Rect2(beam_half * 0.53 - 3, beam_top, 3, -beam_top), Color(1.0, 0.85, 0.38, 0.32 * fade))
	# The shaft is assembled from uneven pixel bands, rather than a stretched sheet.
	for segment in 13:
		var y: float = -float(segment + 1) * 12.0
		if y < beam_top:
			continue
		var band_w: float = 8.0 + float((segment * 7) % 4) * 2.0
		_px(Rect2(-band_w, y, band_w * 2.0, 12.0), Color(0.96, 0.59 + float(segment % 3) * 0.05, 0.15, 0.80 * fade))
		_px(Rect2(-band_w * 0.55, y, band_w * 1.1, 12.0), Color(1.0, 0.83, 0.38, 0.91 * fade))
		if segment % 3 != 1:
			_px(Rect2(-3, y + 2, 6, 8), Color(1.0, 0.98, 0.72, 0.95 * fade))
		var shard_x: float = band_w + 4.0 + float((segment * 5) % 7)
		_px(Rect2(-shard_x - 2, y + 3, 2, 5), Color(1.0, 0.84, 0.37, 0.45 * fade))
		_px(Rect2(shard_x, y + 7, 2, 3), Color(1.0, 0.84, 0.37, 0.45 * fade))
	if _elapsed >= 0.34:
		var shock: float = clampf((_elapsed - 0.34) / 0.22, 0.0, 1.0)
		_draw_ring(Vector2(0, 1), half_w * (0.8 + shock * 1.0), 5.0 - shock * 3.0, Color(1.0, 0.86, 0.43, (1.0 - shock) * 0.85))
		for i in 7:
			var angle: float = float(i) * TAU / 7.0
			var dist: float = 7.0 + shock * (23.0 + float(i % 3) * 6.0)
			_px(Rect2(roundf(cos(angle) * dist), roundf(-8.0 - absf(sin(angle)) * dist), 2, 5), Color(1.0, 0.87, 0.47, (1.0 - shock) * 0.8))


func _draw_trident() -> void:
	var flight: float = clampf((_elapsed - 0.10) / 0.26, 0.0, 1.0)
	var eased: float = flight * flight * (3.0 - 2.0 * flight)
	var tip: Vector2 = Vector2(roundf(-94.0 * (1.0 - eased)), roundf(62.0 * (1.0 - eased)))
	var direction: Vector2 = Vector2(0.83, -0.55)
	var normal: Vector2 = Vector2(0.55, 0.83)
	var head: Vector2 = tip - direction * 20.0
	var tail: Vector2 = tip - direction * 82.0
	var opacity: float = clampf((0.82 - _elapsed) / 0.24, 0.0, 1.0)
	if _elapsed < 0.10:
		var charge: float = _elapsed / 0.10
		for i in 3:
			var fleck: Vector2 = Vector2(-98 + i * 8, 57 - i * 5)
			_px(Rect2(fleck, Vector2(2, 2)), Color(0.32, 0.80, 0.93, charge))
		return
	# Layered shaft, fork and three distinct points travel as one object.
	_stroke(tail + Vector2(3, 3), head + Vector2(3, 3), 6.0, Color(0.02, 0.10, 0.17, 0.78 * opacity))
	_stroke(tail, head, 6.0, DARK_BLUE * Color(1, 1, 1, opacity))
	_stroke(tail + normal, head + normal, 3.0, GOLD * Color(1, 1, 1, opacity))
	_stroke(head - normal * 14.0, head + normal * 14.0, 4.0, GOLD * Color(1, 1, 1, opacity))
	for fork in [-1, 0, 1]:
		var root: Vector2 = head + normal * float(fork) * 13.0
		var point: Vector2 = tip + normal * float(fork) * 13.0
		_stroke(root, point, 4.0, DARK_BLUE * Color(1, 1, 1, opacity))
		_stroke(root + normal, point + normal, 2.0, GOLD * Color(1, 1, 1, opacity))
		_px(Rect2(point - Vector2(2, 2), Vector2(4, 4)), WHITE * Color(1, 1, 1, opacity))
	if _elapsed < 0.36:
		for i in 3:
			var wake: Vector2 = tail - direction * float(10 + i * 13)
			_stroke(wake - normal * 5.0, wake + normal * 5.0, 2.0, Color(0.35, 0.82, 0.97, flight * (0.6 - float(i) * 0.1)))
	else:
		var burst: float = clampf((_elapsed - 0.36) / 0.34, 0.0, 1.0)
		var flash: float = maxf(0.0, 1.0 - burst * 2.2)
		_px(Rect2(-14, -3, 28, 6), WHITE * Color(1, 1, 1, flash))
		_px(Rect2(-3, -18, 6, 36), WHITE * Color(1, 1, 1, flash))
		for i in 9:
			var angle: float = (float(i) + 0.35) * TAU / 9.0
			var unit: Vector2 = Vector2(cos(angle), sin(angle))
			var inner: Vector2 = unit * (7.0 + burst * 12.0)
			var outer: Vector2 = unit * (19.0 + burst * (18.0 + float(i % 3) * 5.0))
			_stroke(inner, outer, 3.0 if i % 2 == 0 else 2.0, Color(0.35, 0.84, 0.97, (1.0 - burst) * 0.9))
		_draw_ring(Vector2(0, 7), 8.0 + burst * 32.0, 3.0, Color(0.25, 0.68, 0.83, (1.0 - burst) * 0.72))


func _draw_paw() -> void:
	var stamp: float = clampf((_elapsed - 0.11) / 0.14, 0.0, 1.0)
	var eased: float = stamp * stamp * (3.0 - 2.0 * stamp)
	var pull: float = clampf((_elapsed - 0.37) / 0.18, 0.0, 1.0)
	var paw_y: float = roundf(-42.0 * (1.0 - eased) - 23.0 * pull)
	var alpha: float = clampf((0.60 - _elapsed) / 0.18, 0.0, 1.0)
	if _elapsed < 0.11:
		for i in 3:
			_px(Rect2(float(i - 1) * 8.0, -44 - float(i % 2) * 4.0, 3, 3), Color(1.0, 0.72, 0.84, _elapsed / 0.11 * 0.7))
	# Uneven stepped rows give the pad a rounded pixel silhouette.
	var shadow: Color = Color(0.19, 0.07, 0.19, alpha)
	var fur: Color = Color(0.91, 0.48, 0.64, alpha)
	var light: Color = Color(1.0, 0.75, 0.82, alpha)
	_px(Rect2(-12, paw_y + 1, 24, 4), shadow)
	_px(Rect2(-16, paw_y + 5, 32, 8), shadow)
	_px(Rect2(-14, paw_y + 13, 28, 5), shadow)
	_px(Rect2(-10, paw_y + 18, 20, 3), shadow)
	_px(Rect2(-11, paw_y + 2, 22, 4), fur)
	_px(Rect2(-14, paw_y + 6, 28, 7), fur)
	_px(Rect2(-12, paw_y + 13, 24, 4), light)
	_px(Rect2(-8, paw_y + 17, 16, 2), fur)
	_px(Rect2(-6, paw_y + 7, 12, 7), Color(1.0, 0.87, 0.86, alpha))
	for i in 4:
		var toe_x: float = -16.0 + float(i) * 9.0
		var toe_y: float = paw_y - 7.0 - (3.0 if i == 1 or i == 2 else 0.0)
		_px(Rect2(toe_x - 1, toe_y + 2, 9, 11), shadow)
		_px(Rect2(toe_x, toe_y, 7, 11), fur)
		_px(Rect2(toe_x + 1, toe_y + 1, 5, 5), light)
	if _elapsed >= 0.25:
		var slash: float = clampf((_elapsed - 0.25) / 0.27, 0.0, 1.0)
		for i in 3:
			var x: float = -9.0 + float(i) * 8.0
			_stroke(Vector2(x - 5.0 * slash, 7.0), Vector2(x + 2.0 * slash, 15.0 + 11.0 * slash), 2.0, Color(1.0, 0.88, 0.81, (1.0 - slash) * 0.95))
		_draw_ring(Vector2(0, 11), 8.0 + slash * 17.0, 2.0, Color(1.0, 0.62, 0.75, (1.0 - slash) * 0.7))
		for i in 4:
			var dust_x: float = float(i - 2) * 9.0 * (1.0 + slash)
			_px(Rect2(dust_x, 17.0 + float(i % 2) * 3.0, 2, 2), Color(1.0, 0.72, 0.78, (1.0 - slash) * 0.75))


func _draw_ring(center: Vector2, width: float, height: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	var half_w: float = roundf(width)
	var half_h: float = roundf(height)
	_px(Rect2(center.x - half_w, center.y - half_h, half_w * 2.0, 2), color)
	_px(Rect2(center.x - half_w * 0.75, center.y + half_h, half_w * 1.5, 2), color)
	_px(Rect2(center.x - half_w, center.y - half_h + 2, 2, half_h * 2.0), color)
	_px(Rect2(center.x + half_w - 2, center.y - half_h + 2, 2, half_h * 2.0), color)


func _px(rect: Rect2, color: Color) -> void:
	if color.a > 0.0:
		draw_rect(Rect2(rect.position.round(), rect.size.round()), color)


func _stroke(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	if color.a > 0.0:
		draw_line(a.round(), b.round(), color, width, false)
