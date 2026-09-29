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


def ellipse_ring(im: Image.Image, cx: int, cy: int, rx: int, ry: int, width: int, c: RGBA) -> None:
    for y in range(max(0, cy - ry), min(im.height, cy + ry + 1)):
        for x in range(max(0, cx - rx), min(im.width, cx + rx + 1)):
            outer = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            inner = ((x - cx) / max(1, rx - width)) ** 2 + ((y - cy) / max(1, ry - width)) ** 2
            if outer <= 1 and inner >= 1:
                put(im, x, y, c)


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
    # Three tips converge toward a vanishing point. The wide near end of the
    # haft is closest to the player: this is a throw straight into the scene.
    if frame <= 5:
        # Four faces of the tapering cylindrical haft. The lit left edge and
        # dark right plane make the near end read as volume, not a flat wedge.
        poly(im, [(51, 73), (62, 73), (72, 110), (40, 110)], INK)
        poly(im, [(52, 75), (61, 75), (69, 108), (43, 108)], GOLD_DARK)
        poly(im, [(52, 75), (55, 75), (48, 108), (43, 108)], IVORY)
        poly(im, [(55, 75), (59, 75), (63, 108), (48, 108)], GOLD)
        poly(im, [(59, 75), (62, 75), (69, 108), (63, 108)], SHADOW)
        line(im, (53, 77), (46, 104), 2, WHITE)
        for y, radius in ((89, 10), (99, 13)):
            ellipse_ring(im, 56, y, radius, 4, 2, INK)
            line(im, (56 - radius + 2, y + 1), (56 + radius - 3, y + 1), 2, GOLD)
            line(im, (56 - radius + 4, y), (56 - radius + 8, y), 1, WHITE)
        ellipse(im, 56, 106, 16, 5, INK)
        ellipse(im, 56, 105, 14, 3, GOLD_DARK)
        ellipse(im, 53, 104, 8, 2, GOLD_LIGHT)
        # Each prong has an offset dark extrusion, a broad front plane and a
        # copper side facet. Their tips point into the enemy along one axis.
        for side in (-1, 0, 1):
            base_x = 56 + side * 25
            tip_x = 56 + side * 13
            tip_y = 40 if side == 0 else 46
            blade = [(base_x - 7, 72), (base_x + 7, 72),
                     (tip_x + 4, tip_y + 9), (tip_x, tip_y),
                     (tip_x - 4, tip_y + 9)]
            poly(im, [(x + 4, y + 4) for x, y in blade], SHADOW)
            poly(im, blade, INK)
            poly(im, [(base_x - 5, 70), (base_x + 1, 70),
                      (tip_x + 1, tip_y + 8), (tip_x, tip_y + 2),
                      (tip_x - 2, tip_y + 8)], IVORY)
            poly(im, [(base_x + 1, 70), (base_x + 5, 70),
                      (tip_x + 3, tip_y + 9), (tip_x + 1, tip_y + 8)], GOLD_DARK)
            line(im, (base_x - 4, 68), (tip_x - 1, tip_y + 7), 2, WHITE)
            line(im, (base_x + 6, 71), (tip_x + 3, tip_y + 9), 2, GOLD)
            put(im, tip_x, tip_y, WHITE)
        # Extruded crossbar: light top, deep front face, dark lower bevel.
        poly(im, [(27, 65), (85, 65), (82, 78), (30, 78)], INK)
        poly(im, [(30, 66), (82, 66), (77, 71), (35, 71)], GOLD_LIGHT)
        poly(im, [(35, 71), (77, 71), (80, 75), (32, 75)], GOLD_DARK)
        line(im, (33, 67), (79, 67), 2, IVORY)
        line(im, (34, 76), (78, 76), 1, SHADOW)
        ellipse(im, 56, 73, 12, 5, INK)
        ellipse(im, 55, 71, 10, 3, GOLD)
        ellipse(im, 53, 70, 5, 2, IVORY)
    if frame >= 4:
        radius = (12, 24, 35, 47)[frame - 4]
        ellipse_ring(im, 56, 51, radius, max(6, radius * 3 // 4), 3, TEAL)
        ellipse_ring(im, 56, 51, radius - 3, max(4, radius * 3 // 4 - 3), 1, WHITE)
        if frame == 4:
            ellipse(im, 56, 51, 6, 5, WHITE)
        for i in range(12):
            angle = (i + .5) * math.tau / 12
            r = radius + 3 + i % 5
            x = round(56 + math.cos(angle) * r)
            y = round(51 + math.sin(angle) * r * .75)
            box(im, x, y, x + 2, y + 2, TEAL_LIGHT if i % 2 else IVORY)


def paw(im: Image.Image, frame: int) -> None:
    dy = (10, 6, 3, 0, -1, -4, -7)[frame]
    stamp = Image.new("RGBA", (64, 72))
    # A self-contained paw print: no forearm or straight wrist cut-off.
    ellipse(stamp, 32, 39 + dy, 24, 20, INK)
    ellipse(stamp, 32, 37 + dy, 22, 18, FUR_DARK)
    ellipse(stamp, 32, 39 + dy, 20, 17, CREAM)
    ellipse(stamp, 27, 34 + dy, 12, 8, IVORY)
    ellipse(stamp, 43, 44 + dy, 5, 9, FUR_LIGHT)
    # Four separate toe beans and a central heart-like pad.
    for x, y, rx, ry in ((17, 33, 4, 5), (27, 27, 5, 5), (39, 28, 5, 5), (49, 35, 4, 5)):
        ellipse(stamp, x, y + dy, rx + 1, ry + 1, PINK_DARK)
        ellipse(stamp, x - 1, y - 1 + dy, rx - 1, ry - 1, PINK)
        put(stamp, x - 1, y - 2 + dy, PINK_LIGHT)
    ellipse(stamp, 32, 47 + dy, 11, 8, PINK_DARK)
    ellipse(stamp, 31, 45 + dy, 9, 6, PINK)
    ellipse(stamp, 27, 43 + dy, 3, 2, PINK_LIGHT)
    im.paste(stamp, (16, 12))
    if frame >= 3:
        radius = (29, 35, 41, 46)[frame - 3]
        ellipse_ring(im, 48, 51 + dy, radius, max(6, radius * 3 // 4), 3, PINK_LIGHT)
        ellipse_ring(im, 48, 51 + dy, radius - 3, max(4, radius * 3 // 4 - 3), 1, WHITE)
        for i in range(12):
            angle = (i + .3) * math.tau / 12
            x = round(48 + math.cos(angle) * (radius + 3))
            y = round(51 + dy + math.sin(angle) * (radius * .75 + 3))
            box(im, x, y, x + 2, y + 2, WHITE if i % 3 == 0 else PINK)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet("nodens_pillar_px.png", 112, 216, 8, pillar)
    sheet("trident_px.png", 112, 112, 8, trident)
    sheet("cats_paw_px.png", 96, 96, 7, paw)


if __name__ == "__main__":
    main()
