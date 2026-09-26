class_name FrameStainExtents
extends RefCounted

## パネル枠のインク染み（SanityFrameStains）を辺ごとにどこまで外へ出してよいかの計算だけ。

## 辺ごとの外への広がり [左, 上, 右, 下]：その辺の外側 outset 幅の帯にかかる隣の要素までの距離で打ち切る（最大 outset）。
## 隣が角の外側だけにかかるときは、隙間の広い方の辺を切って残るインクを多くする。
## 画面の端に面した辺は隣が無いので outset のまま（画面外で切れるのは構わない）。
static func side_extents(inner: Rect2, others: Array[Rect2], outset: float) -> Array[float]:
	var ext: Array[float] = [outset, outset, outset, outset]
	var mains: Array[Rect2] = [
		Rect2(inner.position.x - outset, inner.position.y, outset, inner.size.y),
		Rect2(inner.position.x, inner.position.y - outset, inner.size.x, outset),
		Rect2(inner.end.x, inner.position.y, outset, inner.size.y),
		Rect2(inner.position.x, inner.end.y, inner.size.x, outset),
	]
	var valid: Array[Rect2] = []
	for r in others:
		if r.size.x > 0.0 and r.size.y > 0.0:
			valid.append(r)
	for r in valid:
		var gaps: Array[float] = _gaps(inner, r, outset)
		for side in range(4):
			if mains[side].intersects(r):
				ext[side] = minf(ext[side], gaps[side])
	## 角：[横の辺, 縦の辺]（左上・右上・右下・左下）
	var corners: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 1), Vector2i(2, 3), Vector2i(0, 3)]
	for r in valid:
		var gaps: Array[float] = _gaps(inner, r, outset)
		for c in corners:
			var cx: float = inner.position.x - outset if c.x == 0 else inner.end.x
			var cy: float = inner.position.y - outset if c.y == 1 else inner.end.y
			if not Rect2(cx, cy, outset, outset).intersects(r):
				continue
			if ext[c.x] <= gaps[c.x] or ext[c.y] <= gaps[c.y]:
				continue
			if gaps[c.x] >= gaps[c.y]:
				ext[c.x] = gaps[c.x]
			else:
				ext[c.y] = gaps[c.y]
	return ext


static func _gaps(inner: Rect2, r: Rect2, outset: float) -> Array[float]:
	return [
		clampf(inner.position.x - r.end.x, 0.0, outset),
		clampf(inner.position.y - r.end.y, 0.0, outset),
		clampf(r.position.x - inner.end.x, 0.0, outset),
		clampf(r.position.y - inner.end.y, 0.0, outset),
	]
