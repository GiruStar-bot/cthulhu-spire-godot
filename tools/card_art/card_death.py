"""死 (death) v3 — an old black-violet tome, no ornament.

Design notes (kept deliberately moderate: at this resolution any one feature pushed hard
reads as a caricature):
- depth: a modest page block (4 dots on the side, 2 on top), boards overhanging by 1 dot;
- age: low-contrast mottling of the leather (two close tones, no checker dither), a few thin
  creases with a 1-dot highlight beside them, two soft stains, scuffed corners and a worn spine;
- pages: greyed, slightly uneven lines, one darker (water-marked) band;
- the skull: pressed into the cover, rim partly worn away.
"""
import math
from pxlib import W, H, Canvas, prand, dither, ramp

BG = [(6, 3, 10), (13, 6, 20), (24, 10, 36)]
LEATHER = ((70, 46, 90), (52, 32, 70), (40, 24, 56), (30, 17, 43), (16, 8, 25))   # hi .. deepest
WORN = (84, 64, 96)            # scuffed leather
STAIN = (48, 36, 52)           # dull, slightly greyer blotch
PAGE = ((128, 114, 124), (104, 92, 106), (82, 70, 88), (64, 52, 70))
SKULL = ((150, 124, 172), (116, 92, 142), (78, 56, 102), (18, 8, 26))


def noise(x, y, s, seed):
    """Smooth-ish value noise: bilinear over a coarse grid of prand values."""
    gx, gy = x / s, y / s
    x0, y0 = int(gx), int(gy)
    fx, fy = gx - x0, gy - y0
    a = prand(x0, y0, seed); b = prand(x0 + 1, y0, seed)
    c = prand(x0, y0 + 1, seed); d = prand(x0 + 1, y0 + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def death():
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - math.hypot((x - 26) / 30, (y - 30) / 32)) * 0.85, BG))
    cv.ellipse(28, 56, 18, 2, lambda x, y, u, v, r: (4, 2, 6) if r < 0.6 else ((8, 4, 12) if dither(x, y, 0.5) else None))

    L, R, T, B = 11, 39, 7, 54          # front board
    DX, DY = 4, -2                       # modest thickness, receding up-right

    # ---- page block (top + fore-edge), greyed and a little uneven
    cv.poly([(L + 1, T), (R, T), (R + DX, T + DY), (L + 1 + DX, T + DY)],
            lambda x, y: PAGE[1] if (x + int(prand(x, 0, 3) * 2)) % 3 else PAGE[2], "book")
    def fore(x, y):
        c = PAGE[1] if y % 2 else PAGE[2]
        if prand(0, y, 4) < 0.12:                        # an uneven, darker page
            c = PAGE[3]
        if 30 <= y <= 34:                                # water-marked band
            c = PAGE[2] if y % 2 else PAGE[3]
        if x == R + DX:
            c = PAGE[3]
        return c
    cv.poly([(R, T), (R + DX, T + DY), (R + DX, B + DY), (R, B)], fore, "book")
    for x in range(R, R + DX + 2):                       # back board lip along the bottom
        cv.set(x, B + 1 - (x - R) * 0.5, LEATHER[4])
    cv.line(R + DX + 1, T + DY, R + DX + 1, B + DY, LEATHER[4])

    # ---- front board: aged leather
    def cover(x, y):
        n = noise(x, y, 5, 17) * 0.7 + noise(x, y, 2.5, 23) * 0.3
        light = 1 - ((x - L) / (R - L) * 0.55 + (y - T) / (B - T) * 0.45)   # soft light from top-left
        t = n * 0.45 + light * 0.55
        c = LEATHER[1] if t > 0.62 else (LEATHER[2] if t > 0.4 else LEATHER[3])
        if x == L:
            c = LEATHER[4]                               # spine shadow
        elif x == L + 1:
            c = WORN if prand(0, y, 9) < 0.35 else LEATHER[0]   # worn spine edge
        return c
    cv.poly([(L, T), (R + 1, T), (R + 1, B + 1), (L, B + 1)], cover, "book")

    # stains: two soft blotches with a slightly darker rim
    for (sx, sy, rx, ry) in ((31, 16, 5, 3.5), (17, 44, 4, 3)):
        cv.ellipse(sx, sy, rx, ry, lambda x, y, u, v, r: (LEATHER[4] if r > 0.8 and prand(x, y, 31) < 0.6 else
                                                          (STAIN if r < 0.8 and noise(x, y, 2, 41) > 0.35 else None)))
    # creases: thin dark lines with a 1-dot highlight on their lit side
    for (x0, y0, x1, y1) in ((13, 24, 20, 27), (29, 44, 37, 47), (34, 8, 37, 14), (14, 12, 16, 17)):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n + math.sin(i * 0.9) * 0.6)
            cv.set(x, y, LEATHER[4])
            cv.set(x, y - 1, LEATHER[1])
    # scuffed corners: lighter wear, the very corner dot rubbed off
    for (cx, cy, sx, sy) in ((R, T, -1, 1), (R, B, -1, -1), (L + 1, B, 1, -1)):
        for (dx, dy) in ((0, 0), (1, 0), (0, 1), (2, 0), (0, 2), (1, 1)):
            cv.set(cx + dx * sx, cy + dy * sy, WORN)
        cv.set(cx, cy, BG[1])
    # board edge catching the light (broken, not a clean line)
    for x in range(L + 2, R):
        if prand(x, 1, 7) < 0.7:
            cv.set(x, T, LEATHER[0])
    cv.outline_outside({"book"}, LEATHER[4])

    # ---- the skull, pressed in; rim worn in places
    cx, cy = (L + R) / 2 + 0.5, (T + B) / 2 - 1
    skull = set()
    for y in range(int(cy - 7), int(cy + 8)):
        for x in range(int(cx - 7), int(cx + 8)):
            u, v = (x + 0.5 - cx) / 5.8, (y + 0.5 - (cy - 1.5)) / 5.2
            if u * u + v * v <= 1:
                skull.add((x, y))
    for y in range(int(cy + 3), int(cy + 7)):
        for x in range(int(cx - 3), int(cx + 4)):
            skull.add((x, y))
    for (x, y) in skull:
        up = (x - 1, y) not in skull or (x, y - 1) not in skull
        dn = (x + 1, y) not in skull or (x, y + 1) not in skull
        c = SKULL[3] if up else (SKULL[0] if dn else SKULL[1])
        if (up or dn) and prand(x, y, 51) < 0.25:
            c = SKULL[2]                                  # worn rim
        if not (up or dn) and noise(x, y, 2, 53) < 0.3:
            c = SKULL[2]                                  # grime settled in the recess
        cv.set(x, y, c)
    for ex in (cx - 3, cx + 2):
        for (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (2, 0), (0, -1), (1, -1)):
            cv.set(ex + dx, cy - 1 + dy, SKULL[3])
    cv.set(cx - 0.5, cy + 2, SKULL[3]); cv.set(cx + 0.5, cy + 2, SKULL[3])
    for x in range(int(cx - 2), int(cx + 3)):
        cv.set(x, cy + 5, SKULL[3] if x % 2 else SKULL[2])
    return cv


ARTS = {"death": (death, 0)}
