#!/usr/bin/env python3
"""Draw three combat card effects at native pixel resolution, one pixel at a time.

The enemy body frames are 75-91 pixels wide. These sheets use the same size
language as the 40x40 fireball and 72x88 tentacle, then Godot enlarges them
with nearest filtering. No generated illustration or image resampling is used.
"""
from __future__ import annotations

import math
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "art/pixel/fx"
RGBA = tuple[int, int, int, int]
INK: RGBA = (25, 21, 28, 255)
SHADOW: RGBA = (59, 41, 46, 255)
GOLD_DARK: RGBA = (111, 72, 45, 255)
GOLD: RGBA = (194, 135, 66, 255)
GOLD_LIGHT: RGBA = (241, 198, 106, 255)
IVORY: RGBA = (239, 229, 178, 255)
WHITE: RGBA = (255, 250, 218, 255)
TEAL_DARK: RGBA = (24, 63, 69, 255)
TEAL: RGBA = (62, 139, 148, 255)
TEAL_LIGHT: RGBA = (152, 220, 212, 255)
FUR_DARK: RGBA = (72, 43, 49, 255)
FUR: RGBA = (142, 87, 74, 255)
FUR_LIGHT: RGBA = (199, 139, 101, 255)
CREAM: RGBA = (231, 198, 157, 255)
PINK_DARK: RGBA = (123, 65, 81, 255)
PINK: RGBA = (207, 122, 138, 255)
PINK_LIGHT: RGBA = (245, 183, 177, 255)


def put(im: Image.Image, x: int, y: int, c: RGBA) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def box(im: Image.Image, x0: int, y0: int, x1: int, y1: int, c: RGBA) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(im, x, y, c)


def ellipse(im: Image.Image, cx: float, cy: float, rx: float, ry: float, c: RGBA) -> None:
    for y in range(max(0, math.floor(cy - ry)), min(im.height, math.ceil(cy + ry) + 1)):
        for x in range(max(0, math.floor(cx - rx)), min(im.width, math.ceil(cx + rx) + 1)):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                put(im, x, y, c)


def line(im: Image.Image, a: tuple[float, float], b: tuple[float, float], width: float, c: RGBA) -> None:
    steps = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) * 2) + 1
    for i in range(steps + 1):
        t = i / steps
        ellipse(im, a[0] * (1 - t) + b[0] * t, a[1] * (1 - t) + b[1] * t, width / 2, width / 2, c)


def poly(im: Image.Image, points: list[tuple[int, int]], c: RGBA) -> None:
    y0 = max(0, min(p[1] for p in points))
    y1 = min(im.height, max(p[1] for p in points) + 1)
    for y in range(y0, y1):
        hits: list[float] = []
        for a, b in zip(points, points[1:] + points[:1]):
            if (a[1] <= y < b[1]) or (b[1] <= y < a[1]):
                hits.append(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
        hits.sort()
        for j in range(0, len(hits) - 1, 2):
            box(im, math.ceil(hits[j]), y, math.ceil(hits[j + 1]), y + 1, c)


def sheet(name: str, width: int, height: int, count: int, draw) -> None:
    result = Image.new("RGBA", (width * count, height))
    for i in range(count):
        frame = Image.new("RGBA", (width, height))
        draw(frame, i)
        result.paste(frame, (i * width, 0))
    result.save(OUT / name)
    print(f"{name}: {width}x{height}, {count} frames")


def pillar(im: Image.Image, frame: int) -> None:
    # Full 216-pixel height becomes 648 screen pixels. The base sits at the
    # enemy's feet; at both 720p and 648p the light starts above the viewport.
    w, h = im.size
    cx = w // 2
    if frame == 0:
        ellipse(im, cx, h - 6, 28, 3, GOLD_DARK)
        ellipse(im, cx, h - 6, 18, 2, GOLD_LIGHT)
        return
    end = (48, 117, 176, h, h, h, h, h)[frame]
    fade_step = max(0, frame - 4)
    for y in range(end):
        # A stone-like uneven rim, brighter on the left and darker on the right.
        rough = ((y * 17 + y // 7) % 11) - 5
        half = 42 + rough // 3 + (3 if frame in (3, 4) else 0)
        for x in range(cx - half, cx + half + 1):
            ax = abs(x - cx)
            if ax > 38 + rough // 4:
                color = GOLD_DARK if (x + y) % 4 else GOLD
            elif ax > 30 + rough // 4:
                color = GOLD if x > cx else GOLD_LIGHT
            elif ax > 22:
                color = GOLD_LIGHT if x > cx else IVORY
            elif ax > 13:
                color = IVORY
            else:
                color = WHITE
            if fade_step and (x * 7 + y * 11) % 7 < fade_step * 2:
                continue
            put(im, x, y, color)
    if frame >= 3:
        # Floor-facing, foreshortened rings and debris add depth at impact.
        for rad, color in ((45, GOLD_DARK), (35, GOLD), (23, GOLD_LIGHT), (13, WHITE)):
            ellipse(im, cx, h - 5, rad, max(2, rad // 9), color)
        if frame >= 4:
            for i in range(16):
                side = -1 if i % 2 else 1
                x = cx + side * (22 + (i * 13) % 31)
                y = h - 12 - (i * 7) % 13 - (frame - 4) * (i % 3 + 1) * 3
                box(im, x, y, x + (1 if i % 3 else 2), y + 2, GOLD_LIGHT if i % 3 else WHITE)
    for i in range(12):
        y = (i * 41 + frame * 17) % max(1, end)
        x = cx + (-1 if i % 2 else 1) * (47 + i % 8)
        if frame < 6 or i % 2:
            box(im, x, y, x + 2, y + 4, GOLD_LIGHT)


def trident(im: Image.Image, frame: int) -> None:
    # The three *separate* tapered tines and broad neck match the card icon.
    # Shaft shading is asymmetric: dark far side, ivory near face.
    dy = (12, 8, 4, 0, -1, 2, 5, 7)[frame]
    def sh(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
        return [(x, y + dy) for x, y in points]
    poly(im, sh([(32, 107), (44, 107), (42, 47), (37, 38), (34, 47)]), INK)
    poly(im, sh([(35, 105), (40, 105), (39, 48), (36, 44)]), GOLD_DARK)
    line(im, (36, 103 + dy), (35, 47 + dy), 2, GOLD_LIGHT)
    line(im, (40, 100 + dy), (39, 49 + dy), 1, SHADOW)
    for y in (84, 93):
        box(im, 33, y + dy, 43, y + 2 + dy, GOLD)
        box(im, 34, y + dy, 36, y + 2 + dy, IVORY)
    # Fork collar and curved side arms; crossbar is visibly in front of haft.
    poly(im, sh([(30, 50), (45, 50), (49, 42), (50, 39), (43, 44), (32, 44), (25, 39), (26, 43)]), INK)
    poly(im, sh([(31, 48), (44, 48), (46, 44), (39, 45), (34, 45), (28, 43)]), GOLD)
    line(im, (29, 44 + dy), (45, 45 + dy), 2, IVORY)
    # Three tines are pointed and long enough to read as a weapon at 3x.
    for side in (-1, 0, 1):
        mid = 38 + side * 16
        tip_y = 4 if side == 0 else 12
        base_y = 44 if side == 0 else 43
        tip_x = mid + side * 3
        poly(im, sh([(mid - 5, base_y), (mid + 5, base_y), (mid + 3, tip_y + 11), (tip_x, tip_y), (mid - 3, tip_y + 11)]), INK)
        poly(im, sh([(mid - 3, base_y - 2), (mid + 1, base_y - 2), (mid, tip_y + 6), (tip_x, tip_y + 2)]), GOLD_DARK)
        line(im, (mid - 2, base_y - 5 + dy), (tip_x - 1, tip_y + 6 + dy), 2, IVORY)
        line(im, (mid + 3, base_y - 8 + dy), (mid + 2, tip_y + 13 + dy), 1, GOLD)
    box(im, 35, 42 + dy, 41, 48 + dy, GOLD_DARK)
    box(im, 36, 42 + dy, 39, 47 + dy, GOLD_LIGHT)
    if frame >= 4:
        for i in range(10):
            ang = i * math.tau / 10
            r = 12 + (frame - 4) * 6 + i % 3
            x = round(38 + math.cos(ang) * r)
            y = round(28 + math.sin(ang) * r * .65)
            box(im, x, y, x + 2, y + 2, TEAL_LIGHT if i % 2 else WHITE)


def paw(im: Image.Image, frame: int) -> None:
    dy = (12, 7, 3, 0, -2, -7, -12)[frame]
    # Brown fur limb behind the cream paw, as seen on cats_paw card art.
    poly(im, [(21, 0), (44, 0), (49, 20 + dy), (42, 36 + dy), (20, 35 + dy), (15, 21 + dy)], FUR_DARK)
    poly(im, [(23, 0), (40, 0), (44, 22 + dy), (38, 33 + dy), (23, 30 + dy), (19, 17 + dy)], FUR)
    line(im, (23, 3), (25, 25 + dy), 3, FUR_LIGHT)
    for x, y in ((22, 12), (35, 16), (29, 24), (40, 9)):
        box(im, x, y + dy // 2, x + 2, y + 3 + dy // 2, FUR_DARK)
    ellipse(im, 32, 39 + dy, 24, 20, INK)
    ellipse(im, 32, 37 + dy, 22, 18, FUR_DARK)
    ellipse(im, 32, 39 + dy, 20, 17, CREAM)
    ellipse(im, 27, 34 + dy, 12, 8, IVORY)
    ellipse(im, 43, 44 + dy, 5, 9, FUR_LIGHT)
    # Four separate toe beans and a central heart-like pad.
    for x, y, rx, ry in ((17, 33, 4, 5), (27, 27, 5, 5), (39, 28, 5, 5), (49, 35, 4, 5)):
        ellipse(im, x, y + dy, rx + 1, ry + 1, PINK_DARK)
        ellipse(im, x - 1, y - 1 + dy, rx - 1, ry - 1, PINK)
        put(im, x - 1, y - 2 + dy, PINK_LIGHT)
    ellipse(im, 32, 47 + dy, 11, 8, PINK_DARK)
    ellipse(im, 31, 45 + dy, 9, 6, PINK)
    ellipse(im, 27, 43 + dy, 3, 2, PINK_LIGHT)
    if frame >= 3:
        for i in range(3):
            x = 15 + i * 17
            line(im, (x, 54 + dy), (x - 5 - (frame - 3) * 2, 59 + dy), 2, IVORY)
            put(im, x - 6 - (frame - 3) * 2, 60 + dy, WHITE)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet("nodens_pillar_px.png", 112, 216, 8, pillar)
    sheet("trident_px.png", 76, 112, 8, trident)
    sheet("cats_paw_px.png", 64, 72, 7, paw)


if __name__ == "__main__":
    main()
