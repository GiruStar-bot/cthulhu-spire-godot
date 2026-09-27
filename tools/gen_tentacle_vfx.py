#!/usr/bin/env python3
"""Procedural pixel sheet for the tentacle card's ground strike.

No reference illustration. Playback matches SanityTendril (a horizontal strip,
grow then reverse) but the picture does not: one thick octopus arm. Colors
follow the water-card frame — dark indigo body, bright cyan suckers.
"""
from __future__ import annotations

import math

from PIL import Image

W = 72
H = 88
FRAMES = 8
OUT = "art/pixel/fx/tentacle_ground.png"

# Water-frame family. Body stays in the dark indigo of frame_card_water_9.
# Suckers are much lighter so the row still reads.
INK = (6, 14, 18, 255)
DORSAL = (14, 34, 42, 255)
MUSCLE = (24, 72, 88, 255)
HIGH = (78, 168, 186, 255)
BELLY = (36, 104, 124, 255)
RING = (210, 244, 250, 255)
HOLE = (8, 22, 30, 255)
SPARK = (176, 228, 238, 255)
GROUND = (12, 36, 46, 255)

# Base at the ground, tip at the end. y grows downward.
# Outer poses sit a few px in from the edge so the thicker limb does not clip.
POSES: list[list[tuple[int, int]]] = [
	[(36, 84), (36, 74)],
	[(36, 84), (37, 66), (35, 54)],
	[(36, 84), (38, 62), (34, 46), (30, 34)],
	[(36, 84), (37, 60), (32, 44), (28, 28), (36, 16)],
	[(36, 84), (35, 58), (28, 42), (30, 26), (42, 16), (52, 20)],
	[(36, 84), (34, 56), (26, 40), (30, 24), (44, 14), (56, 20), (60, 30)],
	[(36, 84), (34, 60), (26, 44), (16, 34), (10, 42), (8, 54)],
	[(36, 84), (34, 62), (28, 46), (18, 34), (12, 40), (10, 52), (16, 62)],
]


def line_points(a: tuple[int, int], b: tuple[int, int]) -> list[tuple[int, int]]:
	x0, y0 = a
	x1, y1 = b
	pts: list[tuple[int, int]] = []
	dx = abs(x1 - x0)
	dy = abs(y1 - y0)
	sx = 1 if x0 < x1 else -1
	sy = 1 if y0 < y1 else -1
	err = dx - dy
	while True:
		pts.append((x0, y0))
		if x0 == x1 and y0 == y1:
			break
		e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return pts


def spine_points(pose: list[tuple[int, int]]) -> list[tuple[int, int]]:
	pts: list[tuple[int, int]] = []
	for i in range(len(pose) - 1):
		seg = line_points(pose[i], pose[i + 1])
		if pts:
			seg = seg[1:]
		pts.extend(seg)
	return pts


def plot(img: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
	if 0 <= x < W and 0 <= y < H:
		img.putpixel((x, y), color)


def disc(img: Image.Image, x: int, y: int, r: int, color: tuple[int, int, int, int]) -> None:
	if r < 0:
		return
	r2 = r * r
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r2:
				plot(img, x + dx, y + dy, color)


def radius_at(i: int, count: int) -> int:
	if count <= 1:
		return 8
	t = i / float(count - 1)
	base = 8.8 - 3.8 * t
	bulge = 1.05 * math.sin(i * 0.72)
	return max(4, int(round(base + bulge)))


def belly_normal(pts: list[tuple[int, int]], i: int) -> tuple[int, int]:
	prev = pts[max(0, i - 1)]
	nxt = pts[min(len(pts) - 1, i + 1)]
	dx = nxt[0] - prev[0]
	dy = nxt[1] - prev[1]
	nx, ny = -dy, dx
	if nx < 0 or (nx == 0 and ny < 0):
		nx, ny = -nx, -ny
	mag = max(abs(nx), abs(ny), 1)
	return int(round(nx / mag)), int(round(ny / mag))


def draw_ground(img: Image.Image, reach: int) -> None:
	y = H - 2
	half = 5 + reach
	for x in range(36 - half, 37 + half):
		plot(img, x, y, INK)
		plot(img, x, y - 1, GROUND)
		if abs(x - 36) % 5 == 0:
			plot(img, x, y - 2, MUSCLE)
	plot(img, 36, y - 3, HIGH)


def draw_body(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	n = len(pts)
	for i, (x, y) in enumerate(pts):
		disc(img, x, y, radius_at(i, n) + 1, INK)
	for i, (x, y) in enumerate(pts):
		disc(img, x, y, radius_at(i, n), DORSAL)
	for i, (x, y) in enumerate(pts):
		sx, sy = belly_normal(pts, i)
		r = max(2, radius_at(i, n) - 2)
		disc(img, x + sx, y + sy, r, BELLY)
		disc(img, x - sx, y - sy, max(1, r - 1), MUSCLE)
		if i % 2 == 0:
			plot(img, x - sx * 2, y - sy * 2, HIGH)


def draw_suckers(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	n = len(pts)
	if n < 10:
		return
	step = 7
	for i in range(5, n - 3, step):
		sx, sy = belly_normal(pts, i)
		r = radius_at(i, n)
		cx = pts[i][0] + sx * max(2, r - 1)
		cy = pts[i][1] + sy * max(2, r - 1)
		disc(img, cx, cy, 4, INK)
		disc(img, cx, cy, 3, RING)
		disc(img, cx, cy, 1, HOLE)


def draw_hook(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	if len(pts) < 2:
		return
	x0, y0 = pts[-2]
	x1, y1 = pts[-1]
	dx, dy = x1 - x0, y1 - y0
	mag = max(abs(dx), abs(dy), 1)
	sx = int(round(dx / mag))
	sy = int(round(dy / mag))
	for step, rad in ((1, 4), (2, 3), (4, 3)):
		disc(img, x1 + sx * step, y1 + sy * step, rad + 1, INK)
		disc(img, x1 + sx * step, y1 + sy * step, rad, DORSAL)
		disc(img, x1 + sx * step, y1 + sy * step, max(1, rad - 1), MUSCLE)
	plot(img, x1 + sx * 2, y1 + sy * 2, HIGH)


def draw_splash(img: Image.Image, pts: list[tuple[int, int]]) -> None:
	x, y = pts[-1]
	for sx, sy, color in (
		(x - 5, y - 6, SPARK),
		(x - 8, y - 1, HIGH),
		(x + 4, y - 7, SPARK),
		(x - 2, y - 9, RING),
		(x + 6, y - 2, MUSCLE),
		(x - 7, y + 3, SPARK),
		(x + 2, y + 5, RING),
	):
		plot(img, sx, sy, color)
	hx, hy = pts[max(0, len(pts) - 4)]
	disc(img, hx, hy, 5, INK)
	disc(img, hx, hy, 4, MUSCLE)
	plot(img, hx - 1, hy - 1, SPARK)


def draw_frame(index: int) -> Image.Image:
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	pts = spine_points(POSES[index])
	draw_ground(img, index)
	draw_body(img, pts)
	if index >= 1:
		draw_suckers(img, pts)
	draw_hook(img, pts)
	if index >= 2:
		draw_suckers(img, pts)
	if index == FRAMES - 1:
		draw_splash(img, pts)
	return img


def main() -> None:
	sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
	for i in range(FRAMES):
		frame = draw_frame(i)
		sheet.paste(frame, (i * W, 0), frame)
	sheet.save(OUT)
	scale = 4
	preview = Image.new("RGBA", (W * FRAMES * scale, H * scale), (22, 16, 24, 255))
	big = sheet.resize((W * FRAMES * scale, H * scale), Image.NEAREST)
	preview.paste(big, (0, 0), big)
	preview.save("/workspace/artifacts/tentacle_sheet_preview.png")
	print(f"wrote {OUT} {sheet.size}")


if __name__ == "__main__":
	main()
