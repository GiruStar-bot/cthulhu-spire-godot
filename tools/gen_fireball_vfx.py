#!/usr/bin/env python3
"""Procedural sheet for the fireball card.

4 looping flame frames, then 3 spark frames played once on impact.
Colors follow frame_card_fire_9: deep red, orange, bright yellow.
"""
from __future__ import annotations

import math

from PIL import Image

W = 40
H = 40
LOOP = 4
SPARKS = 3
FRAMES = LOOP + SPARKS
OUT = "art/pixel/fx/fireball.png"

INK = (42, 8, 10, 255)
DEEP = (76, 17, 21, 255)
RED = (163, 29, 30, 255)
ORANGE = (231, 66, 10, 255)
AMBER = (241, 97, 11, 255)
GOLD = (254, 176, 42, 255)
YELLOW = (254, 228, 71, 255)
HOT = (255, 246, 214, 255)

CX = 20
CY = 22


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


def tongue(img: Image.Image, ox: int, length: int, sway: int, color: tuple[int, int, int, int]) -> None:
	for i in range(length):
		x = CX + ox + (sway if i % 2 == 0 else 0)
		y = CY - 7 - i
		rad = 1 if i < length - 2 else 0
		disc(img, x, y, rad, color)
		if i < 2:
			plot(img, x, y, YELLOW)


def draw_ball(img: Image.Image, variant: int) -> None:
	shifts = ((-1, -1), (0, 0), (1, 1), (0, -1))
	sx, sy = shifts[variant % 4]
	disc(img, CX, CY, 9, INK)
	disc(img, CX, CY, 8, DEEP)
	disc(img, CX, CY, 6, RED)
	disc(img, CX + sx, CY + sy, 4, ORANGE)
	disc(img, CX + sx, CY + sy - 1, 2, YELLOW)
	plot(img, CX + sx, CY + sy - 1, HOT)
	tongues = (
		((-2, 5, 1, AMBER), (1, 6, -1, YELLOW), (3, 3, 0, ORANGE)),
		((0, 7, 0, YELLOW), (-3, 4, 1, ORANGE), (2, 4, -1, GOLD)),
		((2, 6, -1, YELLOW), (-1, 4, 0, AMBER), (-3, 3, 1, RED)),
		((1, 5, 1, GOLD), (-2, 6, 0, YELLOW), (3, 4, -1, ORANGE)),
	)
	for ox, length, sway, color in tongues[variant % 4]:
		tongue(img, ox, length, sway, color)
	# Loose embers so the silhouette flickers instead of sitting as a coin.
	embers = (
		((CX - 10, CY - 2), (CX + 9, CY + 1), (CX - 4, CY + 8), (CX + 3, CY - 12)),
		((CX - 9, CY + 2), (CX + 10, CY - 1), (CX + 5, CY + 8), (CX - 2, CY - 13)),
		((CX - 8, CY - 4), (CX + 8, CY + 3), (CX - 6, CY + 7), (CX + 1, CY - 14)),
		((CX + 10, CY - 3), (CX - 11, CY + 1), (CX + 2, CY + 9), (CX - 1, CY - 12)),
	)
	for i, (x, y) in enumerate(embers[variant % 4]):
		plot(img, x, y, YELLOW if i % 2 == 0 else GOLD)
		if i % 2 == 0:
			plot(img, x, y - 1, HOT)


def draw_sparks(img: Image.Image, burst: int) -> None:
	count = 12
	dist = (6, 11, 16)[burst]
	rad = (1, 1, 0)[burst]
	if burst == 0:
		disc(img, CX, CY, 3, YELLOW)
		disc(img, CX, CY, 1, HOT)
	for i in range(count):
		ang = (math.pi * 2.0 * i / count) + burst * 0.18
		# Bias upward so the burst reads as fire, not a ring of gravel.
		dx = int(round(math.cos(ang) * (dist + (i % 3))))
		dy = int(round(math.sin(ang) * (dist + (i % 2)) - (2 if burst < 2 else 1)))
		col = (YELLOW, GOLD, ORANGE, AMBER, HOT, RED)[i % 6]
		disc(img, CX + dx, CY + dy, rad, col)
		if burst < 2 and i % 2 == 0:
			plot(img, CX + dx, CY + dy - 1, HOT)


def main() -> None:
	sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
	for i in range(LOOP):
		frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
		draw_ball(frame, i)
		sheet.paste(frame, (i * W, 0), frame)
	for i in range(SPARKS):
		frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
		draw_sparks(frame, i)
		sheet.paste(frame, ((LOOP + i) * W, 0), frame)
	sheet.save(OUT)
	scale = 6
	preview = Image.new("RGBA", (W * FRAMES * scale, H * scale), (22, 14, 16, 255))
	big = sheet.resize((W * FRAMES * scale, H * scale), Image.NEAREST)
	preview.paste(big, (0, 0), big)
	preview.save("/workspace/artifacts/fireball_sheet_preview.png")
	print(f"wrote {OUT} {sheet.size}")


if __name__ == "__main__":
	main()
