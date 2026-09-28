"""Knight-pack v2 — redrawn under the pixel-art principles (claude/pixel-art-principles.md):
moderate depth and contrast, material read through low-contrast mottling / wear rather than
checker dither, one focal point per card, drawn from the theme (old art = reference only).
53x59 window (board rows 0..58).
"""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat, fire, vnoise, band, texture

FIRE = [(255, 244, 196), (255, 196, 84), (230, 110, 40), (140, 44, 24)]
STEEL = ((226, 230, 236), (176, 182, 192), (128, 134, 148), (86, 90, 104), (48, 50, 62))
RUSTY = ((196, 182, 164), (150, 136, 120), (112, 96, 84), (82, 66, 56), (52, 40, 34))
RUST = ((150, 84, 48), (112, 60, 36))
WOODT = ((150, 104, 64), (120, 80, 48), (92, 60, 36), (64, 40, 24), (40, 24, 14))
LEATHERT = ((120, 78, 50), (92, 58, 38), (66, 40, 26), (40, 24, 16))


# ------------------------------------------------------------------ shared pieces
def stone_wall(cv, tones, light=None, seed=1, bw=10, bh=6, top=0, bottom=59):
    """Irregular stone blocks: each block its own tone, soft mottling, thin mortar, a lit top
    edge per block. `light(x, y)` 0..1 brightens toward a light source."""
    for y in range(top, bottom):
        row = y // bh
        off = (row * 7) % bw
        for x in range(W):
            bx = (x + off) // bw
            ly = y % bh
            lx = (x + off) % bw
            mortar = ly == 0 or lx == 0
            base = prand(bx, row, seed) * 0.35 + texture(x, y, seed + 3) * 0.3
            if light:
                base += light(x, y) * 0.45
            if mortar:
                c = tones[0]
            else:
                t = min(0.999, base)
                c = band(t, tones[1:])
                if ly == 1 and prand(x, y, seed + 9) < 0.7:
                    c = tones[min(len(tones) - 1, tones.index(c) + 1)]   # lit top edge of the block
            cv.set(x, y, c)


def wood(x, y, tones, seed, along=(1.0, 0.0)):
    """Wood grain along a direction: long streaks, a knot now and then."""
    ax, ay = along
    u = x * ax + y * ay                  # along the grain
    v = -x * ay + y * ax                 # across the grain
    g = vnoise(u * 0.25, v * 1.6, 1.0, seed) * 0.7 + vnoise(u, v, 3.0, seed + 5) * 0.3
    return band(g, tones[1:4])


def blade(cv, x0, y0, x1, y1, width, tones=STEEL, owner="blade", tip=0.18, fuller=True):
    """Straight blade from (x0,y0) (hilt) to (x1,y1) (tip): lit edge, mid face, a fuller, dark edge."""
    Lh = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / Lh, (y1 - y0) / Lh
    nx, ny = -uy, ux
    for i in range(int(Lh * 2) + 1):
        t = i / (Lh * 2)
        w = width * (1 if t < 1 - tip else max(0.0, (1 - t) / tip))
        cx, cy = x0 + ux * Lh * t, y0 + uy * Lh * t
        for k10 in range(-int(w * 10), int(w * 10) + 1, 5):
            k = k10 / 10
            if k < -w + 0.6:
                c = tones[0]                      # lit edge
            elif fuller and abs(k) < 0.4 and t < 0.7:
                c = tones[3]                      # fuller groove
            elif k < 0:
                c = tones[1]
            elif k < w - 0.6:
                c = tones[2]
            else:
                c = tones[3]
            cv.set(cx + nx * k, cy + ny * k, c, owner)


def vignette_bg(cv, tones, cx=26.5, cy=30, rx=34, ry=36, seed=5):
    def f(x, y):
        d = math.hypot((x - cx) / rx, (y - cy) / ry)
        t = max(0.0, 1 - d) * 0.8 + (texture(x, y, seed) - 0.5) * 0.18
        return band(max(0, min(0.999, t)), tones)
    cv.fill(f)


# ------------------------------------------------------------------- 武器庫 armory
def armory():
    WALL = ((24, 20, 22), (46, 40, 42), (58, 50, 50), (72, 62, 58), (92, 76, 64), (120, 96, 72))
    cv = Canvas(WALL[0])
    torch = (7, 14)
    stone_wall(cv, WALL, light=lambda x, y: max(0, 1 - math.hypot(x - torch[0], (y - torch[1]) * 1.2) / 30), seed=3)
    # floor
    for y in range(52, 59):
        for x in range(W):
            cv.set(x, y, band(texture(x, y, 21) * 0.6 + 0.1, WALL[1:4]))
    for x in range(W):
        cv.set(x, 52, WALL[4] if x < 28 else WALL[3])
    # torch in a bracket, with a small flame
    for y in range(15, 22):
        cv.set(torch[0], y, WOODT[3])
    cv.set(torch[0] - 1, 21, (70, 70, 76)); cv.set(torch[0] + 1, 21, (70, 70, 76))
    fire(cv, torch[0] + 0.5, 15, 7, 2.2, FIRE, seed=0.4, n=3, body=0.3)
    # wooden rack: two pegs rails
    for x in range(14, 50):
        cv.set(x, 20, WOODT[1]); cv.set(x, 21, WOODT[3])
        cv.set(x, 44, WOODT[1]); cv.set(x, 45, WOODT[3])
    # weapons hung on the rack: sword, spear, axe, and a kite shield leaning below
    blade(cv, 20, 18, 20, 48, 1.4, STEEL, "wpn")
    cv.line(17, 17, 23, 17, (120, 96, 60), width=1)           # crossguard
    for y in range(11, 17):
        cv.set(20, y, LEATHERT[1] if y % 2 else LEATHERT[2])
    cv.set(20, 10, (150, 120, 70))                              # pommel
    for y in range(8, 52):                                      # spear shaft
        cv.set(28, y, wood(28, y, WOODT, 11, (0, 1)))
    cv.poly([(28.5, 3), (31, 9), (28.5, 11), (26, 9)], lambda x, y: STEEL[1] if x < 28.5 else STEEL[3], "wpn")
    for y in range(14, 50):                                     # axe handle
        cv.set(37, y, wood(37, y, WOODT, 13, (0, 1)))
    cv.poly([(38, 15), (44, 12), (45, 20), (38, 21)], lambda x, y: STEEL[1] if y < 16 else STEEL[2], "wpn")
    cv.line(44, 12, 45, 20, STEEL[0])
    # kite shield resting on the floor
    cv.poly([(40, 36), (50, 36), (50, 44), (45, 53), (40, 44)], lambda x, y: (84, 40, 44) if x < 45 else (64, 30, 34), "wpn")
    cv.line(45, 37, 45, 51, (170, 150, 100))
    cv.line(41, 40, 49, 40, (170, 150, 100))
    cv.outline_outside({"wpn"}, WALL[0])
    return cv


def crossbow():
    FLOOR = ((20, 18, 20), (32, 30, 32), (42, 40, 42), (54, 50, 52))
    cv = Canvas(FLOOR[0])
    # dark flagstones seen from above
    for y in range(59):
        for x in range(W):
            seam = (x + (y // 11) * 5) % 13 == 0 or y % 11 == 0
            c = FLOOR[0] if seam else band(texture(x, y, 7) * 0.7 + prand((x + (y // 11) * 5) // 13, y // 11, 3) * 0.3, FLOOR[1:])
            cv.set(x, y, c)
    # stock: diagonal wooden body with grain
    ang = (0.6, 0.8)
    x0, y0, x1, y1 = 14, 8, 38, 54
    for t in range(0, 101):
        f = t / 100
        cx, cy = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
        w = 2.4 if f < 0.75 else 3.4
        for k in range(-int(w), int(w) + 1):
            x, y = cx + k * 0.8, cy - k * 0.6
            c = wood(x, y, WOODT, 17, ang)
            if k == -int(w):
                c = WOODT[0]
            if k == int(w):
                c = WOODT[3]
            cv.set(x, y, c, "xb")
    # steel prod (the bow) across the front, gently curved
    for i in range(41):
        t = i / 40 - 0.5
        x = 19 + t * 30
        y = 16 + t * 16 + 6 * (t * t * 4) * 0.5
        for k in range(3):
            cv.set(x, y + k, (STEEL[0], STEEL[2], STEEL[3])[k], "xb")
    cv.line(4, 11, 20, 24, (200, 194, 176)); cv.line(34, 26, 20, 24, (200, 194, 176))   # string drawn back
    # bolt resting in the groove, steel head
    cv.line(20, 22, 13, 12, (150, 110, 70))
    cv.poly([(12, 9), (14.5, 12), (11, 12.5)], flat(STEEL[0]), "xb")
    # trigger and stirrup
    cv.set(31, 44, STEEL[3]); cv.set(31, 45, STEEL[3])
    cv.ellipse(13.5, 8, 2, 1.6, lambda x, y, u, v, r: STEEL[2] if r > 0.4 else None, "xb")
    cv.outline_outside({"xb"}, (10, 8, 8))
    # a few nicks and a worn patch on the stock
    for (x, y) in ((24, 26), (29, 35), (33, 44)):
        cv.set(x, y, WOODT[0])
    return cv


# ------------------------------------------------------------------ なまくら dull_blade
def dull_blade():
    GROUND = ((22, 22, 20), (34, 34, 30), (46, 44, 38), (58, 56, 48))
    cv = Canvas(GROUND[0])
    vignette_bg(cv, GROUND, seed=9)
    # the old sword lying diagonally
    blade(cv, 14, 46, 42, 10, 2.4, RUSTY, "blade", fuller=True)
    # rust patches and nicks along the edge
    for k in range(9):
        t = 0.12 + 0.75 * prand(k, 0, 6)
        x, y = 14 + 28 * t, 46 - 36 * t
        cv.set(x + 1, y + 1, RUST[0] if k % 2 else RUST[1])
        if k % 3 == 0:
            cv.set(x + 2, y + 1, RUST[1])
    for k in range(5):                                       # chipped edge: bites out of the lit side
        t = 0.2 + 0.6 * prand(k, 2, 8)
        x, y = 14 + 28 * t, 46 - 36 * t
        cv.set(x - 2, y - 1, GROUND[1])
    cv.outline_outside({"blade"}, GROUND[0])
    # crossguard, worn leather grip with a loose end, pommel
    cv.line(8, 41, 19, 52, (104, 88, 70), width=2)
    for k in range(8):
        x, y = 12 - k * 0.8, 49 + k * 0.7
        cv.set(x, y, LEATHERT[1] if k % 2 else LEATHERT[2]); cv.set(x + 1, y, LEATHERT[2])
    cv.ellipse(5.5, 55.5, 1.8, 1.8, flat(RUSTY[2]))
    for s in range(4):
        cv.set(9 + s, 55 + s // 2, LEATHERT[0])
    return cv


def dull_blade_upgraded():
    """なまくら+ : the same old sword, reground — clean steel, a bright fresh edge, new grip."""
    GROUND = ((22, 22, 20), (34, 34, 30), (46, 44, 38), (58, 56, 48))
    cv = Canvas(GROUND[0])
    vignette_bg(cv, GROUND, seed=9)
    blade(cv, 14, 46, 42, 10, 2.4, STEEL, "blade", fuller=True)
    for k in range(4):                                       # a few old pits left in the flat
        t = 0.25 + 0.5 * prand(k, 0, 6)
        cv.set(14 + 28 * t + 1, 46 - 36 * t + 1, STEEL[3])
    cv.outline_outside({"blade"}, GROUND[0])
    for (x, y) in ((33, 20), (34, 19), (35, 18), (36, 17)):   # glint running along the new edge
        cv.set(x - 1, y - 1, (255, 255, 255))
    cv.line(8, 41, 19, 52, (150, 130, 90), width=2)
    for k in range(8):
        x, y = 12 - k * 0.8, 49 + k * 0.7
        cv.set(x, y, LEATHERT[0] if k % 2 else LEATHERT[1]); cv.set(x + 1, y, LEATHERT[2])
    cv.ellipse(5.5, 55.5, 1.8, 1.8, flat(STEEL[2]))
    return cv


# ------------------------------------------------------------------ 鉄の鎧 iron_armor
def iron_armor():
    WALL = ((20, 18, 18), (38, 34, 32), (48, 42, 38), (60, 52, 44), (78, 66, 52), (104, 84, 60))
    ARM = ((212, 206, 196), (160, 156, 150), (118, 114, 112), (82, 78, 80), (46, 44, 48))
    cv = Canvas(WALL[0])
    stone_wall(cv, WALL, light=lambda x, y: max(0, 1 - math.hypot(x - 26, (y - 24) * 1.1) / 28), seed=5, bw=11, bh=7)
    # stand
    for y in range(44, 58):
        cv.set(26, y, wood(26, y, WOODT, 3, (0, 1))); cv.set(27, y, WOODT[3])
    cv.line(17, 57, 36, 57, WOODT[2], width=2)
    # breastplate: rounded, a centre ridge, lit from the upper left, with dents and scratches
    def plate(x, y, u, v, r):
        lit = -(u * 0.55 + v * 0.8)
        t = 0.5 + lit * 0.45 + (texture(x, y, 11) - 0.5) * 0.06
        return band(max(0, min(0.999, t)), ARM[::-1])
    cv.ellipse(26.5, 30, 11, 14, plate, "arm")
    cv.poly([(16, 38), (37, 38), (35, 46), (18, 46)], lambda x, y: ARM[2] if x < 27 else ARM[3], "arm")   # waist lames
    for y in (40, 43):
        for x in range(17, 37):
            cv.set(x, y, ARM[4])
    for side in (-1, 1):                                     # pauldrons
        cv.ellipse(26.5 + side * 12, 20, 5.5, 4.5, plate, "arm")
        cv.ellipse(26.5 + side * 13, 24, 4.5, 2.8, plate, "arm")
    cv.outline_outside({"arm"}, ARM[4])
    for y in range(18, 38):                                  # centre ridge
        cv.set(26, y, ARM[0] if y < 30 else ARM[1]); cv.set(27, y, ARM[3])
    for (x, y) in ((19, 22), (34, 22), (18, 34), (35, 34), (22, 45), (31, 45)):
        cv.set(x, y, ARM[0]); cv.set(x + 1, y + 1, ARM[4])   # rivets
    for (x0, y0, x1, y1) in ((20, 28, 23, 26), (30, 33, 33, 35)):
        cv.line(x0, y0, x1, y1, ARM[3])                      # scratches
    cv.ellipse(31, 26, 1.5, 1.2, flat(ARM[3])); cv.set(30, 25, ARM[1])   # a dent
    return cv


# -------------------------------------------------------------- 最期の抵抗 laststand
def laststand():
    BG = ((16, 8, 8), (28, 12, 12), (44, 18, 16), (60, 24, 20))
    SKIN = ((214, 160, 128), (178, 120, 94), (136, 84, 66), (90, 50, 42))
    BLOOD = ((170, 34, 34), (120, 20, 24))
    cv = Canvas(BG[0])
    vignette_bg(cv, BG, cy=24, seed=4)
    # sword held point-down: grip through the fist, wide crossguard, blade below
    blade(cv, 27, 44, 27, 62, 3.2, STEEL, "blade", tip=0.05)
    cv.poly([(9, 42), (45, 42), (45, 45), (9, 45)], lambda x, y: STEEL[1] if y < 44 else STEEL[3], "blade")
    cv.set(27, 43, BLOOD[0]); cv.set(26, 43, BLOOD[1])       # red stone in the guard
    for y in range(8, 42):
        cv.set(26, y, LEATHERT[1] if (y // 2) % 2 else LEATHERT[2]); cv.set(27, y, LEATHERT[2]); cv.set(28, y, LEATHERT[3])
    cv.ellipse(27, 6, 3, 2.5, lambda x, y, u, v, r: STEEL[1] if u + v < 0 else STEEL[3], "blade")
    cv.outline_outside({"blade"}, BG[0])
    # the clenched fist, knuckles white, blood on the fingers
    def fist(x, y, u, v, r):
        lit = -(u * 0.5 + v * 0.8)
        return band(max(0, min(0.999, 0.5 + lit * 0.45 + (texture(x, y, 13) - 0.5) * 0.2)), SKIN[::-1])
    cv.ellipse(27.5, 25, 8.5, 7.5, fist, "fist")
    for k, dy in enumerate((-4, -1, 2, 5)):
        cv.ellipse(20, 25 + dy, 3, 1.6, fist, "fist")
        cv.set(19, 25 + dy, SKIN[0])                         # knuckle highlight
        for x in range(18, 23):
            cv.set(x, 26.5 + dy, SKIN[3])                    # line between fingers
    cv.poly([(0, 30), (18, 22), (22, 34), (2, 46)], lambda x, y: band(texture(x, y, 17) * 0.8, LEATHERT[1:][::-1]), "fist")   # sleeve
    cv.outline_outside({"fist"}, SKIN[3])
    for (x, y) in ((21, 21), (22, 22), (24, 27), (20, 28), (30, 29), (31, 30)):
        cv.set(x, y, BLOOD[0] if (x + y) % 2 else BLOOD[1])
    return cv


# ----------------------------------------------------------------- ムラマサ muramasa
def muramasa():
    BG = ((10, 4, 18), (22, 8, 38), (38, 14, 62), (58, 24, 92))
    AURA = [(236, 200, 255), (190, 120, 250), (130, 60, 200), (80, 30, 130)]
    BLADE = ((236, 232, 246), (190, 184, 210), (140, 132, 170), (96, 88, 126), (56, 50, 80))
    cv = Canvas(BG[0])
    def f(x, y):
        dx, dy = x + 0.5 - 26.5, (y + 0.5 - 30) * 0.8
        d = math.hypot(dx, dy)
        a = math.atan2(dy, dx)
        s = (math.sin(d * 0.45 - a * 2) + 1) / 2
        return band(min(0.999, 0.05 + 0.55 * s ** 2 * min(1, d / 14) + (texture(x, y, 2) - 0.5) * 0.1), BG)
    cv.fill(f)
    # cursed aura licking up the blade (kept narrow)
    fire(cv, 28, 50, 44, 3.4, AURA, seed=1.1, n=4, body=0.0)
    # katana: slight curve, hamon line along the edge
    for i in range(0, 91):
        t = i / 90
        x = 27 + 2.0 * math.sin(t * math.pi * 0.5)
        y = 50 - t * 44
        w = 1.5 if t < 0.9 else 1.5 * (1 - t) / 0.1
        for k10 in range(-int(w * 10), int(w * 10) + 1, 5):
            k = k10 / 10
            c = BLADE[0] if k < -w + 0.6 else (BLADE[2] if k < 0.3 else BLADE[3])
            if abs(k - 0.4) < 0.3 and (i // 3) % 2 == 0:
                c = BLADE[1]                                 # wavy hamon
            cv.set(x + k, y, c, "kat")
    cv.outline_outside({"kat"}, BLADE[4])
    cv.line(23, 51, 31, 51, (200, 170, 70), width=2)          # tsuba
    for y in range(53, 59):                                  # wrapped handle
        for x in (27, 28):
            cv.set(x, y, (26, 16, 30) if (x + y) % 2 else (150, 130, 166))
    return cv


# ---------------------------------------------------------------------- 盾 shield
def shield():
    WALL = ((16, 16, 22), (30, 30, 38), (40, 40, 50), (50, 50, 62), (64, 64, 76))
    cv = Canvas(WALL[0])
    stone_wall(cv, WALL, light=lambda x, y: max(0, 1 - math.hypot(x - 20, y - 14) / 40) * 0.6, seed=7, bw=12, bh=7)
    for y in range(44, 59):                                  # stone ledge
        for x in range(W):
            cv.set(x, y, band(texture(x, y, 15) * 0.7 + (0.25 if y == 44 else 0), WALL[1:]))
    for x in range(W):
        cv.set(x, 45, WALL[0])
    # round buckler, dished: bevelled rim, a boss, dents and scrapes
    def face(x, y, u, v, r):
        d = math.sqrt(r)
        lit = -(u * 0.55 + v * 0.8)
        if d > 0.86:
            t = 0.55 + lit * 0.45
        else:
            t = 0.45 - lit * 0.25 + (texture(x, y, 19) - 0.5) * 0.2   # dished: lit the other way
        return band(max(0, min(0.999, t)), STEEL[::-1])
    cv.ellipse(26.5, 32, 15, 14, face, "sh")
    cv.outline_outside({"sh"}, STEEL[4])
    cv.ellipse(26.5, 32, 3.8, 3.6, lambda x, y, u, v, r: STEEL[0] if u + v < -0.5 else (STEEL[1] if r < 0.6 else STEEL[3]))
    for a in range(0, 360, 45):
        cv.set(26.5 + math.cos(math.radians(a)) * 12, 32 + math.sin(math.radians(a)) * 11.3, STEEL[4])
    for (x0, y0, x1, y1) in ((17, 27, 21, 25), (31, 38, 35, 36), (22, 40, 24, 41)):
        cv.line(x0, y0, x1, y1, STEEL[3])
    cv.ellipse(33, 27, 1.6, 1.3, flat(STEEL[3])); cv.set(32, 26, STEEL[1])
    # leather straps hanging below
    for side in (-1, 1):
        for i in range(9):
            x = 26.5 + side * (7 + i * 0.7)
            y = 45 + math.sin(i * 0.5) * 1.6
            cv.set(x, y, LEATHERT[1]); cv.set(x, y + 1, LEATHERT[3])
    return cv


ARTS = {
    "armory": (armory, 0),
    "crossbow": (crossbow, 0),
    "dull_blade_base": (dull_blade, 0),
    "dull_blade_upgraded": (dull_blade_upgraded, 0),
    "iron_armor": (iron_armor, 0),
    "laststand": (laststand, 0),
    "muramasa": (muramasa, 0),
    "buckler": (shield, 0),
}
