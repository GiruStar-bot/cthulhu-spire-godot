#!/usr/bin/env python3
"""Procedural pixel sheet for the tentacle card's ground strike.

10 action frames, then 2 splash-only frames that TentacleStrike overlays at
the start. Playback holds the wind-up and snaps the whip.

The arm is one thick octopus limb in the water-frame indigo, with a sharp
taper, two sucker columns, and a pair of dark rings.
"""
from __future__ import annotations

import math

from PIL import Image

W = 72
H = 88
ACTION = 10
SPLASH = 2
FRAMES = ACTION + SPLASH
OUT = "art/pixel/fx/tentacle_ground.png"

INK = (6, 14, 18, 255)
DORSAL = (12, 32, 40, 255)
MUSCLE = (20, 58, 72, 255)
HIGH = (72, 156, 174, 255)
BELLY = (28, 86, 104, 255)
RING = (214, 244, 250, 255)
HOLE = (6, 18, 26, 255)
SPARK = (168, 224, 236, 255)
WHITE = (236, 248, 252, 255)
BAND = (4, 12, 16, 255)
GROUND = (12, 36, 46, 255)

# 0-2 rise, 3-4 cock back, 5 is the hitch, 6-7 the whip, 8 the crack, 9 the wrap.
POSES: list[list[tuple[int, int]]] = [
	[(36, 84), (34, 74), (33, 66)],
	[(36, 84), (32, 68), (40, 54), (34, 42)],
	[(36, 84), (30, 66), (42, 50), (32, 34), (36, 22)],
	[(36, 84), (32, 64), (26, 46), (34, 28), (46, 16), (52, 20)],
	[(36, 84), (34, 66), (30, 48), (40, 32), (52, 20), (58, 26)],
	[(36, 84), (40, 70), (36, 54), (48, 40), (58, 32), (60, 42)],
	[(36, 84), (28, 66), (18, 48), (16, 30), (30, 16), (44, 12)],
	[(36, 84), (26, 62), (14, 44), (10, 28), (18, 16), (30, 22)],
	[(36, 84), (28, 64), (16, 46), (8, 32), (6, 44), (12, 56)],
	[(36, 84), (30, 66), (18, 48), (10, 36), (8, 48), (16, 62), (26, 70)],
]


def catmull(p0, p1, p2, p3, t: float) -> tuple[float, float]:
	t2 = t * t
	t3 = t2 * t

	def axis(a: float, b: float, c: float, d: float) -> float:
		return 0.5 * (
			(2.0 * b)
			+ (-a + c) * t
			+ (2.0 * a - 5.0 * b + 4.0 * c - d) * t2
			+ (-a + 3.0 * b - 3.0 * c + d) * t3
		)

	return axis(p0[0], p1[0], p2[0], p3[0]), axis(p0[1], p1[1], p2[1], p3[1])


def spine_points(pose: list[tuple[int, int]]) -> list[tuple[int, int]]:
	if len(pose) < 2:
		return list(pose)
	ext = [pose[0], *pose, pose[-1]]
	raw: list[tuple[int, int]] = []
	for i in range(1, len(ext) - 2):
		p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
		dist = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
		steps = max(2, int(round(dist * 2.0)))
		for s in range(steps):
			x, y = catmull(p0, p1, p2, p3, s / float(steps))
			raw.append((int(round(x)), int(round(y))))
	raw.append(pose[-1])
	out: list[tuple[int, int]] = []
	for p in raw:
		if not out or out[-1] != p:
			out.append(p)
	return out


def plot(img: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
	if 0 <= x < W and 0 <= y < H:
		img.putpixel((x, y), color)


def disc(img: Image.Image, x: int, y: int, r: int, color: tuple[int, int, int, int]) -> None:
	if r < 0:
		return
	if r == 0:
		plot(img, x, y, color)
		return
	r2 = r * r
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r2:
				plot(img, x + dx, y + dy, color)


def radius_at(i: int, count: int) -> int:
	if count <= 1:
		return 10
	t = i / float(count - 1)
	wobble = 0.65 * math.sin(t * 17.0) * (1.0 - t)
	return max(1, int(round(11.2 * ((1.0 - t) ** 1.2) + wobble)))


def smooth_frame(pts: list[tuple[int, int]]) -> list[tuple[float, float, float, float]]:
	"""Per spine point: tangent x/y and a ventral normal that does not flip."""
	n = len(pts)
	out: list[tuple[float, float, float, float]] = []
	prev: tuple[float, float] | None = None
	for i in range(n):
		i0 = max(0, i - 2)
		i1 = min(n - 1, i + 2)
		dx = float(pts[i1][0] - pts[i0][0])
		dy = float(pts[i1][1] - pts[i0][1])
		mag = math.hypot(dx, dy) or 1.0
		tx, ty = dx / mag, dy / mag
		vx, vy = -ty, tx
		if prev is not None and vx * prev[0] + vy * prev[1] < 0.0:
			vx, vy = -vx, -vy
		prev = (vx, vy)
		out.append((tx, ty, vx, vy))
	return out


def draw_ground(img: Image.Image, reach: int) -> None:
	y = H - 2
	half = 8 + min(reach, 4)
	for x in range(36 - half, 37 + half):
		plot(img, x, y, INK)
		plot(img, x, y - 1, GROUND)
		if abs(x - 36) % 4 == 0:
			plot(img, x, y - 2, MUSCLE)
	plot(img, 36, y - 3, HIGH)


def draw_body(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	n = len(pts)
	frame = smooth_frame(pts)
	for i, (x, y) in enumerate(pts):
		disc(img, x, y, radius_at(i, n) + 1, INK)
	for i, (x, y) in enumerate(pts):
		disc(img, x, y, radius_at(i, n), DORSAL)
	for i, (x, y) in enumerate(pts):
		r = radius_at(i, n)
		_tx, _ty, vx, vy = frame[i]
		if r >= 5:
			disc(img, int(round(x + vx * 2)), int(round(y + vy * 2)), max(1, r - 4), BELLY)
			disc(img, int(round(x - vx)), int(round(y - vy)), max(1, r - 3), MUSCLE)
		if i % 2 == 0 and r >= 3:
			plot(img, int(round(x - vx * max(1, r - 1))), int(round(y - vy * max(1, r - 1))), HIGH)


def draw_rings(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	n = len(pts)
	frame = smooth_frame(pts)
	for frac in (0.32, 0.50):
		i = int(round(frac * (n - 1)))
		r = radius_at(i, n)
		if r < 5:
			continue
		x, y = pts[i]
		_tx, _ty, vx, vy = frame[i]
		# One-pixel crease inside the silhouette, not a cut through it.
		for k in range(-(r - 2), r - 1):
			px = int(round(x + vx * k))
			py = int(round(y + vy * k))
			plot(img, px, py, BAND)


def draw_suckers(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	n = len(pts)
	if n < 16:
		return
	frame = smooth_frame(pts)
	step = 6
	i = 6
	while i < n - 4:
		r = radius_at(i, n)
		if r >= 5:
			_tx, _ty, vx, vy = frame[i]
			x, y = pts[i]
			for depth in (0.20, 0.62):
				cx = int(round(x + vx * r * depth))
				cy = int(round(y + vy * r * depth))
				disc(img, cx, cy, 2, INK)
				disc(img, cx, cy, 1, RING)
				plot(img, cx, cy, HOLE)
		i += step


def draw_tip(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	if len(pts) < 3:
		return
	x0, y0 = pts[-3]
	x1, y1 = pts[-1]
	dx, dy = x1 - x0, y1 - y0
	mag = max(abs(dx), abs(dy), 1)
	sx = int(round(dx / mag))
	sy = int(round(dy / mag))
	disc(img, x1 + sx, y1 + sy, 2, INK)
	disc(img, x1 + sx, y1 + sy, 1, DORSAL)
	plot(img, x1 + sx * 2, y1 + sy * 2, MUSCLE)
	plot(img, x1 + sx * 3, y1 + sy * 3, HIGH)


def draw_trail(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	if len(pts) < 8:
		return
	x1, y1 = float(pts[-1][0]), float(pts[-1][1])
	x0, y0 = float(pts[-8][0]), float(pts[-8][1])
	dx, dy = x0 - x1, y0 - y1
	mag = max(math.hypot(dx, dy), 1.0)
	bx, by = dx / mag, dy / mag
	px, py = -by, bx
	for s, col, side in (
		(5, WHITE, 2),
		(9, SPARK, -2),
		(13, WHITE, 1),
		(17, HIGH, -1),
		(8, SPARK, 3),
		(12, WHITE, -3),
	):
		plot(img, int(round(x1 + bx * s + px * side)), int(round(y1 + by * s + py * side)), col)


def draw_hit_sparks(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	x, y = pts[-1]
	for dx, dy, col in (
		(-4, -5, WHITE),
		(-7, -1, SPARK),
		(3, -6, HIGH),
		(5, -2, WHITE),
		(-2, -8, SPARK),
		(1, 4, RING),
	):
		plot(img, x + dx, y + dy, col)


def draw_spray(img: Image.Image, burst: int) -> None:
	ox, oy = 36, 83
	if burst == 0:
		drops = (
			(-14, -2), (-11, -8), (-7, -14), (-3, -18), (1, -16), (6, -14),
			(11, -9), (15, -3), (-5, -6), (4, -5), (8, -4), (-9, -3),
			(0, -9), (13, -7), (-16, -5), (3, -12),
		)
	else:
		drops = (
			(-18, -6), (-12, -14), (-6, -20), (0, -22), (7, -18), (13, -12),
			(18, -5), (-8, -8), (5, -9), (10, -4), (-3, -12), (16, -9),
		)
	for i, (dx, dy) in enumerate(drops):
		col = WHITE if i % 2 == 0 else SPARK
		disc(img, ox + dx, oy + dy, 1, col)
		if i % 3 == 0:
			plot(img, ox + dx, oy + dy - 2, HIGH)


def draw_frame(index: int) -> Image.Image:
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	if index >= ACTION:
		draw_spray(img, index - ACTION)
		return img
	pts = spine_points(POSES[index])
	draw_ground(img, index)
	draw_body(img, pts)
	if len(pts) > 18:
		draw_rings(img, pts)
		draw_suckers(img, pts)
	draw_tip(img, pts)
	if index in (6, 7, 8):
		draw_trail(img, pts)
	if index >= 8:
		draw_hit_sparks(img, pts)
	return img


def main() -> None:
	sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
	for i in range(FRAMES):
		frame = draw_frame(i)
		sheet.paste(frame, (i * W, 0), frame)
	sheet.save(OUT)
	scale = 4
	preview = Image.new("RGBA", (W * FRAMES * scale, H * scale), (18, 14, 20, 255))
	big = sheet.resize((W * FRAMES * scale, H * scale), Image.NEAREST)
	preview.paste(big, (0, 0), big)
	preview.save("/workspace/artifacts/tentacle_sheet_preview.png")
	print(f"wrote {OUT} {sheet.size}")


if __name__ == "__main__":
	main()
