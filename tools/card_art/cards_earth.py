"""Earth-pack card illustrations (53x80 board, 53x59 output window)."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat, fire

OLIVE = ((170, 160, 100), (130, 120, 70), (92, 84, 48), (50, 44, 26))
HORN = ((230, 220, 190), (170, 156, 120))


def _spawnling(cv, cx, cy, r, mood="happy", facing=1):
    """The little olive horned spawn: round body, stubby limbs, big eyes."""
    cv.ellipse(cx, cy, r, r * 0.92, shade(OLIVE, rim=0.8), "mob")
    for side in (-1, 1):                                   # horns
        hx = cx + side * r * 0.55
        cv.set(hx, cy - r * 0.95, HORN[0], "mob"); cv.set(hx + side, cy - r * 1.05, HORN[0], "mob")
        cv.set(hx, cy - r * 0.8, HORN[1], "mob"); cv.set(hx + side * 2, cy - r * 1.1, HORN[1], "mob")
    for (dx, dy) in ((-0.6, 0.75), (0.5, 0.8)):             # feet
        cv.ellipse(cx + dx * r, cy + dy * r, r * 0.28, r * 0.22, flat(OLIVE[2]), "mob")
    cv.outline({"mob"}, OLIVE[3])
    E, HI = (24, 20, 14), (255, 255, 255)
    ex = cx + facing * r * 0.15
    for dx in (-0.35, 0.35):
        x = ex + dx * r
        y = cy - r * 0.1
        if mood == "angry":
            cv.set(x, y, E); cv.set(x + 1, y, E); cv.set(x, y + 1, E); cv.set(x + 1, y + 1, E)
            cv.set(x - (1 if dx < 0 else -2), y - 1, E); cv.set(x + (0 if dx < 0 else -1), y - 1, E)
        else:
            cv.ellipse(x + 0.5, y + 0.5, 1.6, 2.0, flat(E))
            cv.set(x, y - 1, HI)
    my = cy + r * 0.3
    if mood == "angry":
        cv.set(ex - 1, my, E); cv.set(ex, my + 1, E); cv.set(ex + 1, my, E)
    else:
        cv.ellipse(ex, my + 0.5, 1.8, 1.2, lambda x, y, u, v, rr: (140, 40, 40) if v > 0 else E)
    cv.set(ex - r * 0.6, cy + r * 0.2, (210, 140, 120)); cv.set(ex + r * 0.6, cy + r * 0.2, (210, 140, 120))


# ----------------------------------------------------------------------- 突進 charge
def charge():
    SKY = [(120, 120, 170), (160, 156, 196), (200, 196, 220)]
    DUST = [(240, 236, 230), (206, 200, 196), (160, 154, 156)]
    ROCK = ((200, 200, 210), (150, 150, 164), (104, 104, 120), (60, 60, 74))
    cv = Canvas(SKY[0])
    cv.fill(lambda x, y: ramp(x, y, y / 70, SKY))
    # dust cloud billowing behind (upper right)
    for (cx, cy, r) in ((40, 14, 9), (48, 22, 8), (34, 22, 7), (46, 32, 7), (38, 32, 6)):
        cv.ellipse(cx, cy, r, r, lambda x, y, u, v, rr: DUST[0] if u + v < -0.2 else (DUST[1] if rr < 0.8 else DUST[2]))
    # speed lines
    for k in range(7):
        y = 30 + k * 3
        for s in range(8 + k % 3 * 3):
            cv.set(34 + s + k, y - s // 3, DUST[1] if s % 2 else None)
    # shattered boulder lower left
    cv.poly([(4, 56), (14, 46), (24, 50), (26, 62), (18, 70), (6, 68)], lambda x, y: ROCK[1] if x + y < 64 else ROCK[2], "rock")
    for (a, b, c, d) in ((10, 50, 16, 64), (16, 52, 24, 58), (8, 60, 20, 66)):
        cv.line(a, b, c, d, ROCK[3])
    cv.outline({"rock"}, ROCK[3])
    for k in range(12):                                   # flying chips
        x = 6 + prand(k, 0, 3) * 28
        y = 28 + prand(k, 1, 3) * 30
        cv.set(x, y, ROCK[1]); cv.set(x + 1, y, ROCK[2]); cv.set(x, y + 1, ROCK[3])
    # ground
    cv.fill(lambda x, y: (ROCK[2] if prand(x, y, 5) < 0.5 else ROCK[1]) if y > 66 + int(2 * math.sin(x * 0.3)) else None)
    _spawnling(cv, 30, 44, 9, mood="angry", facing=-1)
    return cv


# -------------------------------------------------------------------------- 闇 darkness
def darkness():
    RING = [(8, 6, 12), (14, 12, 20), (22, 18, 30), (34, 28, 44)]
    cv = Canvas(RING[0])

    def bg(x, y):
        d = math.hypot(x + 0.5 - 26.5, y + 0.5 - 40)
        ring = (math.sin(d * 1.15) + 1) / 2
        fade = min(1, d / 30)
        return ramp(x, y, ring * 0.9 * fade + 0.05, RING)
    cv.fill(bg)
    cv.ellipse(26.5, 40, 2, 2, flat((0, 0, 0)))
    return cv


# ----------------------------------------------------------------- 大地震 earthquake
def earthquake():
    ROCK = [(40, 34, 30), (66, 56, 48), (96, 84, 72), (130, 116, 100)]
    LAVA = [(255, 200, 80), (230, 120, 40), (140, 50, 24), (50, 20, 14)]
    DUST = [(120, 110, 100), (150, 140, 128)]
    cv = Canvas(ROCK[1])

    # the main fissure: a jagged line zigzagging down the card, widening toward the viewer
    def crack_x(y):
        return 26 + 6 * math.sin(y * 0.09) + 3 * math.sin(y * 0.31)

    seeds = [(gx * 9 + 4 + prand(gx, gy, 3) * 6 - 3, gy * 9 + 4 + prand(gx, gy, 4) * 6 - 3, prand(gx, gy, 5))
             for gx in range(7) for gy in range(10)]

    def bg(x, y):
        ds = sorted((math.hypot(x + 0.5 - sx, y + 0.5 - sy), t) for sx, sy, t in seeds)
        (d1, t1), (d2, _) = ds[0], ds[1]
        if d2 - d1 < 0.9:
            return ROCK[0]
        c = ROCK[3] if t1 > 0.7 else (ROCK[2] if t1 > 0.3 else ROCK[1])
        if d2 - d1 < 1.9 and dither(x, y, 0.5):           # bevel along plate edges
            c = ROCK[1]
        return c
    cv.fill(bg)
    for y in range(H):
        half = 1 + y * 0.09
        cx = crack_x(y)
        for x in range(int(cx - half - 2), int(cx + half + 3)):
            d = abs(x + 0.5 - cx) / half
            if d < 0.45:
                c = LAVA[3] if y < 40 else (LAVA[1] if d < 0.2 else LAVA[2])
            elif d < 1.0:
                c = ROCK[0] if x < cx else LAVA[3]
            elif d < 1.35:
                c = ROCK[0]
            else:
                continue
            cv.set(x, y, c)
    # glow rising from the deep part of the crack
    for y in range(40, H):
        cx = crack_x(y)
        cv.set(cx, y, LAVA[0] if y % 3 else LAVA[1])
    # side cracks
    for (x0, y0, x1, y1) in ((24, 20, 10, 16), (30, 34, 46, 28), (22, 50, 6, 58), (32, 58, 48, 66)):
        cv.line(x0, y0, x1, y1, ROCK[0])
    # dust plumes
    for (cx, cy, r) in ((13, 24, 4), (16, 20, 3), (41, 44, 4), (44, 40, 3)):
        cv.ellipse(cx, cy, r, r, lambda x, y, u, v, rr: DUST[1] if u + v < 0 else DUST[0])
    return cv


# ------------------------------------------------------------ 母なる神性 mother_goddess
def mother_goddess():
    BG = [(14, 10, 20), (26, 20, 36), (40, 32, 54)]
    BODY = ((60, 44, 72), (40, 28, 50), (26, 18, 34), (12, 8, 16))
    SLIME = [(220, 230, 110), (170, 180, 60), (110, 120, 40), (60, 66, 24)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - math.hypot((x - 26) / 32, (y - 40) / 40)), BG))
    # huge hooded dark mass
    cv.ellipse(26.5, 26, 14, 16, shade(BODY, rim=0.85), "mass")
    cv.poly([(13, 28), (40, 28), (47, 50), (6, 50)], lambda x, y: BODY[1] if x < 30 else BODY[2], "mass")
    cv.ellipse(26.5, 30, 7, 9, flat(BODY[3]))                 # empty hood opening
    cv.outline({"mass"}, BODY[3])
    # slime dripping from the lower edge
    for x in range(7, 47):
        drip = prand(x // 3, 0, 11)
        n = int(3 + (16 * drip if drip > 0.45 else 3 * drip))
        for y in range(44, 44 + n):
            t = (y - 44) / max(1, n)
            edge = (x // 3) * 3 == x or (x // 3) * 3 + 2 == x
            cv.set(x, y, SLIME[0] if t < 0.3 and not edge else (SLIME[2] if edge else SLIME[1]))
        cv.set(x, 44 + n, SLIME[3] if n > 5 else SLIME[2])
    # the small figure standing in the ooze, rim-lit
    FIG = [
        "..OO..",
        ".OOOO.",
        "..OO..",
        ".OOOO.",
        "OOOOOO",
        ".OOOO.",
        ".O..O.",
    ]
    cv.sprite(FIG, 24, 54, {"O": (10, 8, 14)}, "fig")
    cv.outline_outside({"fig"}, (230, 230, 250))
    return cv


# ---------------------------------------------------------------- 滋養 nourishment
def nourishment():
    WOOD = [(40, 24, 16), (60, 38, 24), (80, 52, 32)]
    PLATE = ((70, 72, 80), (46, 48, 56), (30, 32, 38), (14, 14, 18))
    MEAT = ((250, 180, 100), (214, 120, 50), (160, 76, 30), (90, 40, 18))
    BONE = ((244, 236, 214), (200, 188, 160), (120, 110, 90))
    cv = Canvas(WOOD[1])
    cv.fill(lambda x, y: WOOD[0] if (y + x // 12) % 7 == 0 else (WOOD[2] if prand(x // 5, y, 3) < 0.2 else WOOD[1]))
    cv.ellipse(26.5, 44, 22, 15, lambda x, y, u, v, r: PLATE[3] if r > 0.94 else (PLATE[0] if r > 0.78 and u + v < 0 else (PLATE[1] if r > 0.78 else PLATE[2])))
    # drumstick lying diagonally: meaty end lower left, bone to upper right
    cv.line(30, 40, 43, 29, BONE[1], "bone", width=3)
    cv.ellipse(44, 28, 2.4, 2.4, flat(BONE[0]), "bone"); cv.ellipse(42, 26, 2.2, 2.2, flat(BONE[0]), "bone")
    cv.outline({"bone"}, BONE[2])
    for i in range(14):                                     # teardrop of meat along the bone axis
        t = i / 13
        cx, cy = 14 + 16 * t, 50 - 10 * t
        r = 8.5 * (1 - t) ** 0.6 + 1.5
        cv.ellipse(cx, cy, r, r * 0.85, flat(MEAT[1]), "meat")
    for y in range(H):                                       # shade the union: light top-left, dark bottom-right
        for x in range(W):
            if cv.owner(x, y) != "meat":
                continue
            if cv.owner(x + 1, y + 1) != "meat" or cv.owner(x, y + 2) != "meat":
                cv.set(x, y, MEAT[2])
            elif cv.owner(x - 2, y - 2) != "meat":
                cv.set(x, y, MEAT[0])
    cv.outline({"meat"}, MEAT[3])
    for (x, y) in ((17, 42), (20, 40), (24, 44), (18, 47), (26, 49)):      # crispy glints
        cv.set(x, y, MEAT[0])
    # herb sprig and berries
    for k in range(8):
        cv.set(33 + k, 50 + k // 2, (70, 110, 60)); cv.set(33 + k, 49 + k // 2, (100, 140, 80) if k % 2 else None)
    for (x, y) in ((36, 55), (39, 56), (37, 58)):
        cv.ellipse(x, y, 1.3, 1.3, flat((140, 30, 40)))
    # steam
    for k in range(3):
        for s in range(10):
            cv.set(18 + k * 5 + int(2 * math.sin(s * 0.7 + k)), 34 - s, (170, 160, 150) if s % 2 else None)
    return cv


# ------------------------------------------------------------------ 落とし子 spawn
def spawn():
    SKY = [(150, 200, 236), (190, 222, 244), (226, 240, 250)]
    GRASS = [(90, 150, 70), (120, 180, 90), (160, 206, 120)]
    CLOUD = (250, 252, 255)
    cv = Canvas(SKY[0])
    hill = 44
    cv.fill(lambda x, y: ramp(x, y, 1 - y / hill, SKY) if y < hill + int(3 * math.sin(x * 0.12)) else
            ramp(x, y, 0.2 + 0.6 * prand(x // 2, y, 6), GRASS))
    for (cx, cy, r) in ((12, 18, 4), (16, 17, 5), (20, 19, 3.5), (40, 24, 3), (43, 23, 4)):
        cv.ellipse(cx, cy, r, r * 0.7, flat(CLOUD))
    for k in range(30):                                   # grass blades and flowers
        x = int(prand(k, 0, 8) * W)
        y = hill + 4 + int(prand(k, 1, 8) * 30)
        cv.set(x, y, GRASS[2]); cv.set(x, y - 1, GRASS[2] if k % 3 else (250, 240, 250))
    _spawnling(cv, 28, 48, 9, mood="happy", facing=1)
    for s in range(5):                                    # little dust puff behind
        cv.set(14 - s, 56 - (s % 2), (230, 226, 210))
    return cv


ARTS = {
    "charge": (charge, 12),
    "darkness": (darkness, 11),
    "earthquake": (earthquake, 10),
    "mother_goddess": (mother_goddess, 8),
    "nourishment": (nourishment, 14),
    "spawn": (spawn, 12),
}
