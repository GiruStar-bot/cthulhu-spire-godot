"""Magic-pack (and 残響 echo) card illustrations (53x80 board, 53x59 output window)."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat, fire

PAGE = ((236, 222, 190), (206, 188, 150), (150, 130, 100), (80, 64, 48))
TEAL = [(200, 255, 240), (110, 230, 210), (50, 160, 150), (24, 80, 80)]
FIRE = [(255, 246, 190), (255, 196, 70), (236, 102, 30), (150, 36, 20)]


# --- element icons -------------------------------------------------------------
def icon_flame(cv, cx, cy, s=1.0):
    fire(cv, cx, cy + 4 * s, 11 * s, 4 * s, FIRE, seed=0.9, n=4, body=0.5, owner=("flame", cx, cy))


def icon_drop(cv, cx, cy, s=1.0, tones=((220, 240, 255), (120, 180, 240), (60, 110, 200), (24, 50, 110))):
    own = ("icon_drop", cx, cy)
    for y in range(int(cy - 7 * s), int(cy + 5 * s) + 1):
        t = (y - (cy - 7 * s)) / (12 * s)
        w = 4.5 * s * math.sin(min(1, t * 1.15) * math.pi * 0.62) if t < 0.62 else 4.5 * s * math.sqrt(max(0, 1 - ((t - 0.62) / 0.38) ** 2))
        for x in range(int(cx - w), int(cx + w) + 1):
            u = (x + 0.5 - cx) / max(w, 0.5)
            c = tones[0] if (u < -0.2 and 0.45 < t < 0.75) else (tones[1] if u < 0.35 else tones[2])
            cv.set(x, y, c, own)
    cv.outline({own}, tones[3])


def icon_wind(cv, cx, cy, s=1.0, tones=((190, 250, 170), (110, 210, 100), (24, 60, 30))):
    """Two gust curls: a long tail running left, curling into a spiral at the right."""
    own = ("icon_wind", cx, cy)
    for k, (ox, oy, r) in enumerate(((2, -3, 3.6), (-1, 3.5, 2.8))):
        sx, sy = cx + ox * s, cy + oy * s
        for i in range(70):
            a = i / 69 * math.pi * 3.2                  # 1.6 turns
            rr = r * s * (1 - a / (math.pi * 4))
            cv.set(sx + math.sin(a) * rr, sy - math.cos(a) * rr + r * s, tones[0] if i < 40 else tones[1], own)
        for t in range(int(11 * s)):                    # tail
            cv.set(sx - t, sy, tones[0], own)
    cv.outline_outside({own}, tones[2])


def icon_crystal(cv, cx, cy, s=1.0, tones=((250, 240, 160), (210, 180, 70), (140, 110, 40), (70, 50, 20))):
    own = ("icon_crystal", cx, cy)
    pts = [(cx, cy - 10 * s), (cx + 4 * s, cy - 4 * s), (cx + 4 * s, cy + 4 * s), (cx, cy + 9 * s), (cx - 4 * s, cy + 4 * s), (cx - 4 * s, cy - 4 * s)]
    cv.poly(pts, lambda x, y: tones[0] if x < cx - 1 else (tones[1] if x < cx + 1.5 else tones[2]), own)
    cv.outline({own}, tones[3])


def open_book(cv, cx, top, w=22, h=14, cover=(40, 50, 90)):
    """Open book seen from the front/above: two pages curving up to a central gutter."""
    for side in (-1, 1):
        for x in range(0, w):
            lift = int(3 * math.sin((1 - x / w) * math.pi / 2))
            px = cx + side * (x + 1)
            for y in range(top - lift, top + h - lift // 2):
                c = PAGE[0] if x > 2 else PAGE[2]
                if (y - top) % 3 == 1 and 3 < x < w - 2 and prand(px, y, 3) < 0.7:
                    c = PAGE[2]
                cv.set(px, y, c, "book")
            cv.set(px, top + h - lift // 2, PAGE[1], "book")
    for x in range(-w - 1, w + 2):                 # cover edge
        cv.set(cx + x, top + h + 1, cover); cv.set(cx + x, top + h + 2, tuple(v // 2 for v in cover))
    cv.outline({"book"}, PAGE[3])


# ----------------------------------------------------------------- 回復 restoration
def restoration():
    BG = [(14, 10, 20), (26, 20, 32)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, 0.4 * prand(x // 4, y // 4, 3), BG))
    # warm light in the middle
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - 28, y - 42)
            if d < 3:
                cv.set(x, y, (255, 250, 220))
            elif d < 7:
                cv.set(x, y, (250, 210, 130) if dither(x, y, 1 - (d - 3) / 5) else (170, 120, 60))
            elif d < 14 and dither(x, y, (14 - d) / 14 * 0.6):
                cv.set(x, y, (120, 84, 44))
    icon_wind(cv, 29, 25, 1.2)
    icon_drop(cv, 17, 48, 1.1)
    icon_crystal(cv, 38, 48, 1.1)
    return cv


# ----------------------------------------------------------------- 呪文書 spellbook
def spellbook():
    BG = [(10, 12, 22), (18, 22, 36)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, y / 90, BG))
    open_book(cv, 26, 48, 22, 14)
    # teal sigil hovering over the pages and smoke rising
    for k in range(40):
        a = k / 40 * math.pi * 2
        cv.set(26.5 + math.cos(a) * 8, 42 + math.sin(a) * 5, TEAL[1])
    for (a, b, c, d) in ((20, 42, 33, 42), (26, 37, 26, 47), (22, 38, 31, 46), (31, 38, 22, 46)):
        cv.line(a, b, c, d, TEAL[0])
    for k in range(3):
        for s in range(26):
            cv.set(22 + k * 5 + 3 * math.sin(s * 0.3 + k * 2), 36 - s, TEAL[2] if s % 3 else TEAL[1])
    for (x, y) in ((20, 14), (33, 18), (27, 10)):
        cv.set(x, y, TEAL[0])
    return cv


# ------------------------------------------------------------ 究極魔術 ultimate_arcane
def ultimate_arcane():
    BG = [(8, 20, 50), (20, 60, 120), (60, 140, 210)]
    cv = Canvas(BG[0])
    cx, cy = 26.5, 42

    def bg(x, y):
        dx, dy = x + 0.5 - cx, y + 0.5 - cy
        a = math.atan2(dy, dx)
        d = math.hypot(dx, dy)
        ray = max(0, math.cos(a * 8)) ** 6 + max(0, math.cos(a * 2)) ** 30
        t = ray * max(0, 1 - d / 45) + max(0, 1 - d / 22) * 0.4
        return ramp(x, y, min(1, t), BG)
    cv.fill(bg)
    cv.ellipse(cx, cy, 6, 6, lambda x, y, u, v, r: (255, 255, 255) if r < 0.4 else (200, 240, 255))
    for k in range(-26, 27):                       # cross flare
        cv.set(cx + k, cy, (220, 250, 255) if abs(k) < 16 else (120, 200, 240))
    for k in range(-30, 31):
        cv.set(cx, cy + k, (220, 250, 255) if abs(k) < 18 else (120, 200, 240))
    icon_flame(cv, 14, 26, 1.0)
    icon_drop(cv, 40, 26, 1.0)
    icon_wind(cv, 14, 58, 1.0)
    icon_crystal(cv, 40, 58, 1.0)
    return cv


# --------------------------------------------------------------------- 知 wisdom
def wisdom():
    BG = [(16, 14, 30), (26, 22, 44)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, 0.4 * prand(x // 5, y // 5, 2), BG))
    open_book(cv, 26, 56, 18, 10, cover=(90, 50, 30))
    # glyph stream rising out of the book
    GLY = ["11", "10", "01", "111", "101"]
    for k in range(12):
        x = 22 + int(8 * math.sin(k * 0.9)) + (k % 3)
        y = 50 - k * 4
        g = GLY[k % len(GLY)]
        for i, ch in enumerate(g):
            if ch == "1":
                cv.set(x + i, y, TEAL[0] if k % 2 else TEAL[1]); cv.set(x + i, y + 1, TEAL[2])
    for s in range(40):
        cv.set(26 + 5 * math.sin(s * 0.25), 54 - s, TEAL[3] if s % 2 else None)
    # loose pages flying
    for (x, y, w, h) in ((7, 18, 10, 12), (36, 28, 11, 9)):
        cv.poly([(x, y), (x + w, y + 2), (x + w - 1, y + h), (x - 1, y + h - 2)], lambda xx, yy: PAGE[0] if (yy - y) % 3 else PAGE[2], "pg")
    cv.outline({"pg"}, PAGE[3])
    return cv


# ------------------------------------------------------------------------ 残響 echo
def echo():
    BG = [(18, 16, 28), (30, 28, 44), (60, 56, 84), (130, 120, 170)]
    BELL = ((110, 110, 120), (70, 70, 80), (44, 44, 52), (20, 20, 26))
    cv = Canvas(BG[0])
    cx, cy = 26.5, 40

    def bg(x, y):
        d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.1)
        ring = (math.cos(d * 0.7) + 1) / 2
        return ramp(x, y, (ring ** 4) * max(0, 1 - d / 34) + 0.1, BG)
    cv.fill(bg)
    # bell body
    pts = [(21, 26), (32, 26), (35, 40), (40, 48), (13, 48), (18, 40)]
    cv.poly(pts, lambda x, y: BELL[0] if x < 22 else (BELL[1] if x < 30 else BELL[2]), "bell")
    cv.ellipse(26.5, 26, 5.5, 3, shade(BELL), "bell")
    cv.outline({"bell"}, BELL[3])
    cv.line(24, 30, 27, 44, BELL[3])                    # crack
    cv.ellipse(26.5, 50, 2, 2, flat(BELL[2]))            # clapper
    # yoke on top
    cv.poly([(15, 20), (38, 20), (38, 23), (15, 23)], flat((50, 40, 34)))
    cv.line(26, 21, 26, 25, BELL[2])
    return cv


ARTS = {
    "restoration": (restoration, 12),
    "spellbook": (spellbook, 10),
    "ultimate_arcane": (ultimate_arcane, 12),
    "wisdom": (wisdom, 10),
    "echo": (echo, 11),
}
