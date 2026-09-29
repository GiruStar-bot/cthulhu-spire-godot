#!/usr/bin/env python3
"""Nine card-specific combat effects, painted one native pixel at a time.

Run from anywhere with the bundled Pillow runtime. Every frame is transparent
RGBA at enemy-sprite-scale resolution; Godot displays it with nearest filtering.
"""
from __future__ import annotations

import math

from gen_card_strike_vfx import box, ellipse, ellipse_ring, line, poly, put, sheet
from PIL import Image

INK = (13, 17, 25, 255)
WHITE = (251, 250, 228, 255)
PALE = (208, 232, 225, 255)
WIND_DARK = (31, 60, 67, 255)
WIND = (72, 132, 138, 255)
WIND_LIGHT = (151, 210, 200, 255)
STONE_DARK = (38, 38, 44, 255)
STONE = (103, 98, 91, 255)
STONE_LIGHT = (174, 165, 141, 255)
GOLD = (232, 185, 91, 255)
RED_DARK = (71, 16, 37, 255)
RED = (168, 36, 65, 255)
RED_LIGHT = (239, 82, 99, 255)
PINK = (255, 163, 180, 255)
BLUE_DARK = (19, 39, 85, 255)
BLUE = (38, 93, 178, 255)
CYAN = (84, 189, 230, 255)
ICE = (182, 238, 249, 255)
LAVA_DARK = (98, 28, 23, 255)
LAVA = (220, 64, 27, 255)
ORANGE = (251, 143, 45, 255)
YELLOW = (255, 218, 99, 255)
SHEEP_DARK = (31, 38, 31, 255)
SHEEP = (80, 92, 70, 255)
SHEEP_LIGHT = (144, 148, 99, 255)
PURPLE_DARK = (36, 16, 58, 255)
PURPLE = (107, 52, 154, 255)
PURPLE_LIGHT = (181, 116, 227, 255)
GREEN = (102, 169, 87, 255)


def whirlwind(im: Image.Image, frame: int) -> None:
    height = (34, 55, 82, 95, 100, 96, 75, 42)[frame]
    bottom = 104
    ellipse(im, 40, 103, 31, 4, (25, 37, 40, 170))
    for y in range(bottom - height, bottom):
        t = (bottom - y) / max(1, height)
        radius = 24 - int(t * 15)
        center = 40 + round(math.sin(y * .16 + frame * .65) * 3)
        for x in range(center - radius, center + radius + 1):
            nx = abs(x - center) / max(1, radius)
            if nx > 1:
                continue
            twist = (x * 3 + y * 2 + frame * 11) % 23
            if 7 <= twist <= 11 and nx < .82:
                continue  # transparent channel through the spinning body
            color = WIND_DARK if nx > .82 else WIND if nx > .48 else WIND_LIGHT
            if twist < 4:
                color = PALE
            put(im, x, y, color)
    for ring_y in range(bottom - 8, bottom - height, -17):
        t = (bottom - ring_y) / max(1, height)
        radius = max(8, 27 - int(t * 15))
        x = 40 + round(math.sin(ring_y * .16 + frame * .65) * 3)
        ellipse_ring(im, x, ring_y, radius, max(3, radius // 4), 2, PALE if ring_y % 2 else WIND_LIGHT)
    for i in range(7):
        x = 9 + (i * 13 + frame * 7) % 63
        y = 106 - (i * 19 + frame * 9) % max(1, height)
        box(im, x, y, x + 2, y + 2, GOLD if i % 3 == 0 else PALE)


def wind_arrow(im: Image.Image, frame: int) -> None:
    wobble = (-1, 0, 1, 0, -1, 0)[frame]
    cy = 21 + wobble
    # The gold-cyan arrowhead has dark underside and lit top facets.
    poly(im, [(54, cy - 7), (77, cy), (54, cy + 8), (59, cy + 2), (47, cy + 2)], INK)
    poly(im, [(56, cy - 5), (74, cy), (56, cy), (47, cy)], WIND_LIGHT)
    poly(im, [(56, cy), (73, cy + 1), (56, cy + 6), (47, cy + 2)], WIND_DARK)
    line(im, (10, cy + 2), (56, cy + 2), 6, WIND_DARK)
    line(im, (11, cy), (56, cy), 3, PALE)
    line(im, (13, cy - 1), (51, cy - 1), 1, WHITE)
    poly(im, [(12, cy), (5, cy - 10), (18, cy - 4), (23, cy)], WIND)
    poly(im, [(12, cy + 2), (5, cy + 11), (18, cy + 6), (23, cy + 2)], WIND_DARK)
    for i in range(9):
        x = (i * 9 + frame * 7) % 53
        y = cy + ((i * 5) % 17) - 8
        if i % 2:
            line(im, (x, y), (x - 5, y), 1, WIND_LIGHT)
        else:
            put(im, x, y, PALE)


def muramasa(im: Image.Image, frame: int) -> None:
    # A red helix locks onto the target before one iaido flash cuts through it.
    amount = min(1.0, (frame + 1) / 4)
    if frame <= 5:
        for i in range(int(175 * amount)):
            t = i / 174
            y = 101 - int(t * 88)
            angle = t * math.tau * 2.3 + frame * .65
            depth = math.sin(angle)
            x = 56 + round(math.cos(angle) * (25 - t * 8))
            color = RED_DARK if depth < -.2 else RED if depth < .45 else PINK
            ellipse(im, x, y, 2 if depth < 0 else 3, 2, color)
            if i % 13 == 0:
                put(im, x + 2, y - 3, RED_LIGHT)
    if frame >= 4:
        width = (2, 6, 4, 2)[min(3, frame - 4)]
        line(im, (15, 91), (96, 19), width + 6, RED_DARK)
        line(im, (15, 89), (96, 17), width + 2, RED_LIGHT)
        line(im, (17, 86), (94, 19), max(1, width), WHITE)
        for i in range(15):
            x = 19 + i * 5
            y = 88 - i * 4 + (i % 3 - 1) * (frame - 3) * 3
            box(im, x, y, x + 2, y + 2, PINK if i % 2 else RED_LIGHT)


def cold_flame(im: Image.Image, frame: int) -> None:
    height = (8, 20, 42, 68, 92, 84, 59, 20)[frame]
    ellipse(im, 40, 106, 26, 4, BLUE_DARK)
    ellipse(im, 40, 105, 17, 2, CYAN)
    # Three curved tongues share a molten base but taper and sway separately.
    # The shifting silhouette avoids the straight-sided "blue fence" look.
    for cx, ratio, base_width, bend in ((22, .64, 8, -8), (59, .73, 8, 8), (40, 1.0, 12, 6)):
        peak = 105 - round(height * ratio)
        span = max(1, 105 - peak)
        for y in range(peak, 106):
            t = (105 - y) / span
            center = cx + bend * math.sin(t * math.pi) + 2 * math.sin(t * 8 + frame * .7)
            half = max(1.0, base_width * ((1 - t) ** .72) * (.83 + .17 * math.sin(t * 12 + frame)))
            for x in range(math.floor(center - half), math.ceil(center + half) + 1):
                nx = abs(x - center) / half
                if nx > 1:
                    continue
                if t > .28 and .31 < nx < .47 and (y // 7 + frame) % 3 == 0:
                    continue
                color = BLUE_DARK if nx > .80 else BLUE if nx > .47 else CYAN
                if nx < .18 and (y + x + frame) % 7 < 3:
                    color = ICE
                put(im, x, y, color)
        if frame >= 3:
            put(im, round(cx), peak + 1, ICE)
    for i in range(12):
        x = 11 + (i * 17 + frame * 4) % 58
        y = 99 - (i * 13 + frame * 9) % max(1, height)
        put(im, x, y, ICE if i % 4 == 0 else CYAN)


def earthquake(im: Image.Image, frame: int) -> None:
    # Jagged fissure travels under the target; molten core erupts vertically.
    path = [(4, 59), (21, 56), (31, 62), (45, 50), (57, 55), (70, 45),
            (83, 51), (96, 43), (109, 48)]
    active = min(len(path), 2 + frame * 2)
    for a, b in zip(path[:active], path[1:active]):
        line(im, a, b, 10 if frame >= 2 else 5, STONE_DARK)
        line(im, a, b, 6 if frame >= 2 else 3, LAVA_DARK)
        line(im, a, b, 3 if frame >= 2 else 1, ORANGE)
        if frame >= 3:
            line(im, (a[0], a[1] + 1), (b[0], b[1] + 1), 1, YELLOW)
    if frame >= 3:
        rise = (18, 43, 36, 22, 5)[min(4, frame - 3)]
        for x0 in (29, 56, 83):
            poly(im, [(x0 - 8, 52), (x0 + 8, 52), (x0 + 3, 52 - rise + 7),
                      (x0, 52 - rise), (x0 - 4, 52 - rise + 9)], LAVA_DARK)
            poly(im, [(x0 - 4, 51), (x0 + 2, 51), (x0 + 1, 56 - rise),
                      (x0 - 1, 54 - rise)], LAVA)
            line(im, (x0 - 2, 48), (x0, 59 - rise), 2, YELLOW)
    for i in range(11):
        x = (i * 23 + frame * 5) % 112
        y = 49 - (i * 11 + frame * 5) % (18 if frame < 3 else 41)
        box(im, x, y, x + 2 + i % 2, y + 2, STONE_LIGHT if i % 2 else ORANGE)


def charge(im: Image.Image, frame: int) -> None:
    bob = (3, -2, 1, -3, 2, -3, -1, 2)[frame]
    # Side-on black sheep from the card reference: round wool, horn and face.
    ellipse(im, 47, 63, 36, 5, (18, 22, 20, 160))
    for x, lift in ((28, frame % 2 * 4), (43, (frame + 1) % 2 * 4), (58, frame % 2 * 4)):
        box(im, x - 4, 47 + bob, x + 2, 66 - lift, SHEEP_DARK)
        box(im, x - 2, 49 + bob, x, 62 - lift, SHEEP)
    for x, y, r in ((29, 37, 15), (43, 32, 17), (58, 36, 15), (35, 46, 16), (51, 45, 16)):
        ellipse(im, x, y + bob, r + 2, r + 1, SHEEP_DARK)
        ellipse(im, x - 2, y - 2 + bob, r - 2, r - 3, SHEEP)
    for x, y in ((27, 28), (37, 24), (50, 25), (33, 40), (56, 41)):
        ellipse(im, x, y + bob, 4, 2, SHEEP_LIGHT)
    ellipse(im, 68, 36 + bob, 15, 12, SHEEP_DARK)
    ellipse(im, 70, 34 + bob, 12, 9, SHEEP_LIGHT)
    ellipse_ring(im, 63, 25 + bob, 8, 8, 3, STONE_LIGHT)
    ellipse(im, 70, 33 + bob, 2, 2, WHITE)
    put(im, 71, 33 + bob, INK)
    ellipse(im, 80, 39 + bob, 4, 3, SHEEP_DARK)
    if frame >= 3:
        for i in range(8):
            x = 82 + (i * 7) % 14
            y = 29 + (i * 13) % 26
            box(im, x, y, x + 2, y + 2, STONE_LIGHT if i % 2 else WHITE)


def thecall(im: Image.Image, frame: int) -> None:
    # A giant shadow eye above the battlefield; purple concentric wave passes.
    opening = (3, 7, 13, 20, 20, 20, 16, 8)[frame]
    ellipse(im, 160, 53, 62, 29, PURPLE_DARK)
    ellipse_ring(im, 160, 53, 62, 29, 3, PURPLE)
    ellipse(im, 160, 53, 48, opening, INK)
    ellipse(im, 160, 53, 17, max(2, opening - 2), PURPLE)
    ellipse(im, 160, 53, 8, max(2, opening - 4), PURPLE_LIGHT)
    ellipse(im, 157, 51, 3, 3, WHITE)
    if frame >= 3:
        radius = (22, 55, 105, 149, 180)[min(4, frame - 3)]
        ellipse_ring(im, 160, 100, radius, max(10, radius // 3), 3, PURPLE_LIGHT)
        ellipse_ring(im, 160, 100, max(8, radius - 6), max(6, radius // 3 - 4), 2, PURPLE)
        for i in range(20):
            angle = i * math.tau / 20
            x = round(160 + math.cos(angle) * radius)
            y = round(100 + math.sin(angle) * radius / 3)
            box(im, x, y, x + 2, y + 2, PURPLE_LIGHT if i % 2 else WHITE)


RAINBOW = [(244, 63, 85, 255), (249, 149, 63, 255), (254, 230, 112, 255),
           (129, 219, 111, 255), (90, 201, 232, 255), (120, 124, 230, 255),
           (216, 121, 235, 255)]


def collapse(im: Image.Image, frame: int) -> None:
    cx, cy = 160, 90
    if frame < 2:
        for i in range(36):
            angle = (i * 37 % 360) * math.pi / 180
            dist = 15 + frame * 27 + (i * 11) % 44
            x = round(cx + math.cos(angle) * dist)
            y = round(cy + math.sin(angle) * dist * .65)
            line(im, (x, y), (x + math.cos(angle) * 12, y + math.sin(angle) * 8),
                 2, RAINBOW[i % 7])
    elif frame <= 5:
        for y in range(im.height):
            for x in range(im.width):
                dx, dy = x - cx, y - cy
                dist = math.hypot(dx, dy)
                angle = math.atan2(dy, dx)
                spoke = int((angle + math.pi) * 32 / math.tau)
                edge = 45 + frame * 38 + (spoke % 4) * 9
                if dist > edge and frame != 4:
                    continue
                if dist < 17 + (frame - 2) * 8:
                    color = WHITE
                else:
                    color = RAINBOW[(spoke + int(dist / 23) + frame) % 7]
                    if (x + y + frame * 3) % 11 == 0:
                        color = WHITE
                put(im, x, y, color)
    else:
        for i in range(95):
            x = (i * 97 + frame * 13) % 320
            y = (i * 53 + frame * 7) % 180
            c = RAINBOW[i % 7]
            box(im, x, y, x + 2 + i % 4, y + 1 + i % 3, c)


ELEMENTS = [(LAVA, ORANGE), (BLUE, ICE), (WIND, WIND_LIGHT), (SHEEP, GREEN)]


def ultimate(im: Image.Image, frame: int) -> None:
    starts = [(54, 38), (265, 38), (54, 143), (265, 143)]
    cx, cy = 160, 90
    if frame < 5:
        t = min(1.0, frame / 4)
        for i, (sx, sy) in enumerate(starts):
            x = round(sx * (1 - t) + cx * t)
            y = round(sy * (1 - t) + cy * t)
            dark, light = ELEMENTS[i]
            ellipse(im, x, y, 10, 10, dark)
            ellipse(im, x - 2, y - 2, 5, 5, light)
            for j in range(6):
                xx = x + round(math.cos(j * math.tau / 6) * (13 + frame * 2))
                yy = y + round(math.sin(j * math.tau / 6) * (13 + frame * 2))
                box(im, xx, yy, xx + 2, yy + 2, light)
    else:
        reach = (35, 120, 166, 166, 85)[min(4, frame - 5)]
        thick = (5, 8, 10, 7, 3)[min(4, frame - 5)]
        box(im, cx - reach, cy - thick - 4, cx + reach, cy + thick + 4, PURPLE_DARK)
        box(im, cx - reach, cy - thick, cx + reach, cy + thick, GOLD)
        box(im, cx - reach, cy - 2, cx + reach, cy + 2, WHITE)
        box(im, cx - thick - 4, cy - min(85, reach), cx + thick + 4, cy + min(85, reach), PURPLE_DARK)
        box(im, cx - thick, cy - min(85, reach), cx + thick, cy + min(85, reach), WIND_LIGHT)
        box(im, cx - 2, cy - min(85, reach), cx + 2, cy + min(85, reach), WHITE)
        ellipse(im, cx, cy, 14 + thick, 14 + thick, GOLD)
        ellipse(im, cx, cy, 7 + thick // 2, 7 + thick // 2, WHITE)
        for i in range(24):
            x = (i * 79 + frame * 11) % 320
            y = (i * 47 + frame * 17) % 180
            box(im, x, y, x + 2, y + 2, ELEMENTS[i % 4][1])


def main() -> None:
    sheet("whirlwind_px.png", 80, 112, 8, whirlwind)
    sheet("wind_arrow_px.png", 80, 40, 6, wind_arrow)
    sheet("muramasa_px.png", 112, 112, 8, muramasa)
    sheet("cold_flame_px.png", 80, 112, 8, cold_flame)
    sheet("earthquake_px.png", 112, 72, 8, earthquake)
    sheet("charge_px.png", 96, 72, 8, charge)
    sheet("thecall_px.png", 320, 180, 8, thecall)
    sheet("collapse_px.png", 320, 180, 8, collapse)
    sheet("ultimate_px.png", 320, 180, 10, ultimate)


if __name__ == "__main__":
    main()
