"""Earth-pack redraws (v2): 突進 / 母なる神性 / 落とし仔, under the pixel-art principles."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat, vnoise, band, texture
import spawnling


# ----------------------------------------------------------------------- 突進 charge
def charge():
    """The spawn bursts through a boulder at full tilt: rock shattering outward,
    speed lines and a dust trail streaming behind it."""
    SKY = ((150, 120, 150), (180, 146, 162), (208, 174, 170), (232, 204, 184))
    ROCK = ((176, 176, 186), (132, 132, 146), (96, 96, 110), (66, 66, 80), (36, 36, 48))
    DUST = ((236, 230, 220), (206, 198, 188), (164, 156, 150))
    cv = Canvas(SKY[0])
    cv.fill(lambda x, y: band(min(0.999, y / 70 + (texture(x, y, 4) - 0.5) * 0.12), SKY))
    ground = 48
    for y in range(ground, 59):
        for x in range(W):
            cv.set(x, y, band(texture(x, y, 6) * 0.6 + 0.2, ROCK[2:][::-1]))
    for x in range(W):
        cv.set(x, ground, ROCK[2])
    # dust trail billowing behind (left), low along the ground
    for (cx, cy, r) in ((4, 44, 6), (11, 46, 5), (2, 36, 4), (9, 39, 4.5), (16, 44, 3.5)):
        cv.ellipse(cx, cy, r, r * 0.85, lambda x, y, u, v, rr: DUST[0] if u + v < -0.4 else (DUST[1] if rr < 0.75 else DUST[2]), "dust")
    # speed lines streaming back from the spawn
    for k, y in enumerate((25, 28, 31, 34, 37, 40, 43)):
        L = 14 + (k % 3) * 6
        x0 = 17 - (k % 2) * 3
        for s in range(L):
            if s % 6 < 4:
                cv.set(x0 - s, y, SKY[3] if s < L * 0.6 else SKY[2])
    # the boulder, split open on the right, pieces flying up and away
    body = [(35, 48), (37, 38), (43, 31), (52, 31), (53, 40), (53, 48)]
    cv.poly(body, lambda x, y: band(0.55 - (x - 34) / 40 - (y - 30) / 60 + (texture(x, y, 8) - 0.5) * 0.2, ROCK[1:4][::-1]), "rock")
    for (a0, b0, a1, b1) in ((39, 40, 47, 43), (41, 36, 45, 42), (40, 45, 50, 47), (43, 36, 52, 35), (39, 42, 44, 38)):
        cv.line(a0, b0, a1, b1, ROCK[4])                      # cracks running from the impact
    cv.outline_outside({"rock"}, ROCK[4])
    shards = [(40, 28, 3.5, 0.5), (46, 24, 3, 1.2), (37, 22, 2.5, 2.3), (51, 27, 2.5, 0.8), (43, 16, 2.2, 1.9), (50, 18, 2, 0.3),
              (36, 30, 2.2, 2.8), (48, 11, 1.6, 1.4), (41, 9, 1.4, 0.2), (52, 12, 1.3, 2.0)]
    for i, (sx, sy, r, rot) in enumerate(shards):
        pts = [(sx + math.cos(rot + k * 2.1) * r * (1 + 0.3 * (k % 2)), sy + math.sin(rot + k * 2.1) * r) for k in range(3)]
        cv.poly(pts, lambda x, y: ROCK[1] if y < sy else ROCK[2], ("sh", i))
        cv.outline_outside({("sh", i)}, ROCK[4])
    for k in range(14):                                       # grit
        cv.set(28 + prand(k, 0, 3) * 24, 8 + prand(k, 1, 3) * 30, ROCK[2])
    # impact flash where head meets rock
    for k in range(10):                                   # impact burst lines radiating from the hit
        a = -1.2 + k * 0.25
        for s in range(2, 6):
            if s % 2 == 0:
                cv.set(36 + math.cos(a) * s, 37 + math.sin(a) * s, (255, 250, 230))
    # the spawn itself, stretched with speed, leaning into the hit
    spawnling.paste(cv, 24, 38, mood="charge", r=9, squash=1.2)
    return cv


# -------------------------------------------------------------- 母なる神性 mother_goddess
def mother_goddess():
    """A vast hooded shape, and thick, glossy slime oozing down from it and pooling."""
    BG = ((10, 8, 16), (18, 14, 28), (28, 22, 42))
    MASS = ((64, 50, 80), (46, 34, 60), (32, 24, 44), (20, 14, 30), (10, 6, 16))
    SLIME = ((236, 244, 150), (196, 208, 86), (146, 160, 52), (98, 108, 32), (60, 66, 20))
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: band(max(0, min(0.999, (1 - math.hypot((x - 26) / 32, (y - 26) / 34)) * 0.9)), BG))
    # the hooded mass: a tall rounded cowl, darker toward the right, an empty dark opening
    def mass(x, y, u, v, r):
        lit = -(u * 0.5 + v * 0.6)
        return band(max(0, min(0.999, 0.45 + lit * 0.35 + (texture(x, y, 12) - 0.5) * 0.15)), MASS[3::-1])
    cv.ellipse(26.5, 20, 16, 18, mass, "mass")
    cv.poly([(10, 22), (43, 22), (49, 44), (4, 44)], lambda x, y: band(0.4 - (x - 26) / 70 + (texture(x, y, 14) - 0.5) * 0.15, MASS[3::-1]), "mass")
    cv.outline_outside({"mass"}, MASS[4])
    cv.ellipse(26.5, 24, 7, 9, lambda x, y, u, v, r: MASS[4] if r < 0.8 else MASS[3])

    # ---- slime as a soft field (metaballs): a sheet along the lower edge of the mass, drips
    # that thin as they stretch and swell into heavy drops, a pool below. Shaded from the field's
    # gradient so it reads as thick, wet, glossy goo rather than tubes.
    shapes = []                                          # (kind, params)
    edge = lambda x: 40 + 1.8 * math.sin(x * 0.33 + 0.6)
    drips = [(7, 3, 2.6), (12, 13, 1.9), (18, 4, 3.0), (24, 8, 2.2), (28, 17, 1.6), (33, 3, 2.8), (38, 11, 2.3), (44, 5, 2.4), (48, 2, 2.2)]

    def field(x, y):
        f = 0.0
        # sheet: thick band hugging the hem of the mass
        d = y - edge(x)
        if 4 <= x <= 49:
            f = max(f, 1 - abs(d + 2.8) / 4.2)
        for i, (dx, length, w) in enumerate(drips):
            top = edge(dx)
            if top <= y <= top + length:
                t = (y - top) / length
                wob = 0.9 * math.sin(t * 3.0 + i) * t              # drips wander a little
                ww = w * (1 - 0.55 * t) + 0.35
                bead = 0.6 * max(0, 1 - abs(t - 0.55) * 6) if length > 9 else 0   # a bead forming mid-drip
                f = max(f, 1 - abs(x - dx - wob) / (ww + bead))
            by = top + length
            br = w * (1.35 if length > 6 else 1.1)
            wob_end = 0.9 * math.sin(3.0 + i)
            f = max(f, 1 - math.hypot(x - dx - wob_end, (y - by) * 1.15) / br)
        # pool on the ground
        if y >= 54:
            f = max(f, 1 - abs(y - 57.5) / 2.8 - max(0, abs(x - 26.5) - 20) / 3)
        return f

    L = (-0.5, -0.6, 0.62)
    for y in range(30, 59):
        for x in range(W):
            f = field(x + 0.5, y + 0.5)
            if f <= 0:
                continue
            gx = field(x + 1.5, y + 0.5) - field(x - 0.5, y + 0.5)
            gy = field(x + 0.5, y + 1.5) - field(x + 0.5, y - 0.5)
            nx, ny = -gx * 1.4, -gy * 1.4
            nz = max(0.15, 1 - min(1, nx * nx + ny * ny)) ** 0.5
            nl = (nx * L[0] + ny * L[1] + nz * L[2])
            if nl > 0.93:
                c = (255, 255, 228)                      # specular glint
            elif nl > 0.72:
                c = SLIME[0]
            elif nl > 0.45:
                c = SLIME[1]
            elif nl > 0.15:
                c = SLIME[2]
            else:
                c = SLIME[3]
            cv.set(x, y, c, "slime")
    cv.outline_outside({"slime"}, SLIME[4])
    return cv


# ------------------------------------------------------------------- 落とし仔 spawn
def black_sheep():
    """黒羊: the little spawn itself, bounding happily across a meadow (the token card's art)."""
    SKY = ((150, 196, 232), (176, 214, 242), (204, 230, 248), (230, 242, 252))
    GRASS = ((70, 124, 62), (94, 152, 76), (122, 180, 96), (156, 204, 122))
    cv = Canvas(SKY[0])
    hill = lambda x: 36 + 3 * math.sin(x * 0.11 + 0.5)
    def f(x, y):
        if y < hill(x):
            return band(min(0.999, 1 - y / 40), SKY)
        t = texture(x, y, 9) * 0.55 + (1 - (y - hill(x)) / 30) * 0.35
        return band(max(0, min(0.999, t)), GRASS)
    cv.fill(f)
    for (cx, cy, r) in ((11, 12, 3.2), (15, 11, 4.2), (19, 12.5, 3), (40, 18, 2.6), (43, 17, 3.4)):
        cv.ellipse(cx, cy, r, r * 0.7, lambda x, y, u, v, rr: (255, 255, 255) if v < 0.3 else (226, 236, 246))
    for k in range(24):                                      # grass tufts and a few flowers
        x = int(prand(k, 0, 8) * W)
        y = int(hill(x) + 3 + prand(k, 1, 8) * 18)
        cv.set(x, y, GRASS[3]); cv.set(x + 1, y - 1, GRASS[3])
        if k % 5 == 0:
            cv.set(x, y - 1, (250, 236, 246))
    # soft shadow under it, a small dust puff behind
    cv.ellipse(28, 50, 8, 1.5, lambda x, y, u, v, r: GRASS[0])
    for (x, y) in ((15, 47), (13, 46), (12, 48), (16, 49)):
        cv.set(x, y, (236, 232, 214))
    spawnling.paste(cv, 28, 38, mood="happy", r=9.5)
    return cv


# ------------------------------------------------------------------- 落とし仔 spawn
def spawn():
    """Six 黒羊 dropping out of the sky onto the land: far ones small and high, near ones
    large and low, one tumbling head over heels."""
    SKY = ((70, 54, 96), (100, 76, 120), (140, 106, 138), (188, 146, 150), (226, 188, 164))
    LAND = ((40, 44, 30), (58, 64, 40), (78, 86, 52), (104, 112, 66))
    DUST = ((226, 214, 190), (190, 176, 150))
    cv = Canvas(SKY[0])
    horizon = 44
    hill = lambda x: horizon + 2 * math.sin(x * 0.15 + 1) + 1.2 * math.sin(x * 0.4)

    def f(x, y):
        if y < hill(x):
            t = y / horizon
            return band(min(0.999, t * 0.95 + (texture(x, y, 3) - 0.5) * 0.08), SKY)
        d = (y - hill(x)) / 15
        return band(max(0, min(0.999, 0.25 + d * 0.4 + (texture(x, y, 5) - 0.5) * 0.3)), LAND)
    cv.fill(f)
    for x in range(W):                                   # rim light on the hills
        cv.set(x, int(hill(x)), LAND[3])
    # falling: (x, y, r, flip) far -> near; each with a short streak trailing above it
    sheep = [(9, 7, 3.5, False), (42, 5, 3.5, False), (20, 14, 4.5, True), (36, 18, 5.5, False), (12, 29, 6.5, False), (33, 34, 7.5, False)]
    for (x, y, r, fl) in sheep:
        for k in range(int(r * 1.6)):                    # motion streaks
            for dx in (-r * 0.5, 0, r * 0.5):
                if (k + int(dx)) % 2 == 0:
                    cv.set(x + dx, y - r - 2 - k, SKY[3] if k < r else SKY[2])
    for (x, y, r, fl) in sheep:
        spawnling.paste(cv, x, y, owner=("s", x), mood="fall", r=r, flip=fl)
    return cv


ARTS = {
    "charge": (charge, 0),
    "mother_goddess": (mother_goddess, 0),
    "spawn": (spawn, 0),
    "black_sheep": (black_sheep, 0),
}
