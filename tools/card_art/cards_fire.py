"""Fire-pack card illustrations (53x80 board, 53x59 output window)."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat, flame, fire

FIRE = [(255, 246, 190), (255, 196, 70), (236, 102, 30), (150, 36, 20)]
ICE = [(250, 252, 255), (180, 214, 250), (100, 150, 220), (40, 70, 140)]


# ------------------------------------------------------------- 冷たい炎 cold_flame
def cold_flame():
    BG = [(6, 10, 22), (10, 16, 32), (16, 24, 44)]
    GROUND = [(30, 44, 70), (54, 74, 108), (100, 130, 170), (170, 196, 230)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, y / 60, BG))
    # icy ground with a slope
    for x in range(W):
        top = 60 + int(3 * math.sin(x * 0.2)) - (4 if x < 20 else 0)
        for y in range(top, H):
            t = 1 - (y - top) / 20
            cv.set(x, y, ramp(x, y, t * 0.8 + prand(x // 2, y // 2, 3) * 0.2, GROUND))
    # twisting blue flame column
    fire(cv, 26.5, 61, 48, 8, ICE, seed=0.4, n=4, lean=0.0, body=0.25)
    fire(cv, 28, 40, 26, 4.5, ICE, seed=2.3, n=3, lean=-0.15, body=0.0)
    # ice shards bursting where the flame meets the ground
    for k in range(14):
        ang = math.pi * (0.1 + 0.8 * prand(k, 0, 9))
        ln = 3 + 5 * prand(k, 1, 9)
        for s in range(int(ln)):
            cv.set(26.5 + math.cos(ang) * s * 1.4, 61 - math.sin(ang) * s * 0.7, ICE[0] if s < 2 else ICE[1])
    return cv


# ------------------------------------------------------------------ 火球 fireball
def _fire_ball(cv, cx, cy, r, face):
    BALL = ((240, 110, 70), (206, 60, 40), (150, 34, 28), (96, 18, 20))
    # flame crown behind the ball
    fire(cv, cx, cy + 2, r * 2.6, r * 1.05, FIRE, seed=1.3, n=6, body=0.0)
    cv.ellipse(cx, cy, r + 1, r + 1, flat(FIRE[2]))            # hot rim
    cv.ellipse(cx, cy, r, r, shade(BALL, rim=0.8), "ball")
    face(cv, cx, cy)


def _cute_face(cv, cx, cy):
    E, HI, M = (40, 10, 12), (255, 230, 220), (60, 14, 16)
    for dx in (-5, 4):
        cv.set(cx + dx, cy, E); cv.set(cx + dx + 1, cy, E)
        cv.set(cx + dx, cy + 1, E); cv.set(cx + dx + 1, cy + 1, E)
        cv.set(cx + dx, cy, HI)
    for (x, y) in ((-2, 3), (-1, 4), (0, 3), (1, 4), (2, 3)):   # :3 mouth
        cv.set(cx + x, cy + y, M)
    for dx in (-8, 7):
        cv.set(cx + dx, cy + 3, (236, 120, 100)); cv.set(cx + dx + 1, cy + 3, (236, 120, 100))


def fireball():
    BG = [(20, 8, 12), (32, 12, 18)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - math.hypot((x - 26) / 30, (y - 44) / 34)), BG))
    cv.ellipse(26.5, 66, 11, 1.8, lambda x, y, u, v, r: (90, 24, 20) if r < 0.6 else ((56, 16, 16) if dither(x, y, 0.6) else None))
    _fire_ball(cv, 26.5, 45, 12, _cute_face)
    return cv


# -------------------------------------------------------------- 炎の吸血 flame_drain
def _vamp_face(cv, cx, cy):
    E, G, F = (30, 6, 8), (255, 220, 120), (250, 246, 236)
    for dx, sgn in ((-6, 1), (4, -1)):
        # angry slanted eyes
        cv.set(cx + dx, cy - 1 + (0 if sgn > 0 else 1), E)
        for i in range(3):
            cv.set(cx + dx + i, cy + (i * sgn > 0 and 0 or 0), E)
            cv.set(cx + dx + i, cy + 1, E)
        cv.set(cx + dx + 1, cy + 1, G)
    for x in range(-4, 5):
        cv.set(cx + x, cy + 4, E)
    for x in range(-3, 4):
        cv.set(cx + x, cy + 5, (90, 14, 18))
    for fx in (-3, 2):
        cv.set(cx + fx, cy + 5, F); cv.set(cx + fx, cy + 6, F); cv.set(cx + fx + 1, cy + 5, F)


def _wing(cv, cx, cy, side):
    MEM, BONE = (96, 40, 56), (60, 20, 34)
    tip = (cx + side * 26, cy - 16)
    root = (cx + side * 8, cy - 5)
    pts = [root, tip, (cx + side * 25, cy - 2), (cx + side * 20, cy - 5), (cx + side * 17, cy + 1), (cx + side * 12, cy - 1), (cx + side * 9, cy + 4)]
    cv.poly(pts, flat(MEM), "wing")
    cv.line(root[0], root[1], tip[0], tip[1], BONE)
    cv.line(tip[0], tip[1], cx + side * 21, cy - 4, BONE)


def flame_drain():
    BG = [(16, 6, 12), (28, 10, 20)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - math.hypot((x - 26) / 30, (y - 44) / 34)), BG))
    for side in (-1, 1):
        _wing(cv, 26.5, 42, side)
    cv.outline({"wing"}, (30, 10, 20))
    _fire_ball(cv, 26.5, 46, 12, _vamp_face)
    return cv


# ---------------------------------------------------------------- 炎契約 flame_pact
def flame_pact():
    STONE = [(40, 40, 42), (56, 56, 58), (74, 72, 72), (96, 94, 92)]
    CRACK = [(255, 200, 90), (230, 110, 40), (120, 40, 20)]
    CHAR = ((90, 40, 32), (60, 26, 22), (40, 16, 14), (20, 8, 8))
    cv = Canvas(STONE[1])
    cx, cy = 26.5, 42

    def bg(x, y):
        r = prand(x // 4 + (y // 4) % 2, y // 4, 3)
        c = STONE[1] if r < 0.5 else (STONE[2] if r < 0.85 else STONE[0])
        if (x % 8 == 0 and (y // 4) % 2) or y % 8 == 0:
            c = STONE[0]
        d = math.hypot(x - cx, (y - cy) * 0.9)
        if 17 < d < 19:
            c = STONE[3] if d < 18 else STONE[0]
        return c
    cv.fill(bg)
    # glowing cracks radiating out
    for k in range(10):
        ang = k * math.pi / 5 + 0.2
        for s in range(9, 27):
            x = cx + math.cos(ang) * s + (1 if prand(k, s, 5) < 0.3 else 0)
            y = cy + math.sin(ang) * s * 0.95
            cv.set(x, y, CRACK[1] if s < 18 else CRACK[2])
            if s < 13:
                cv.set(x, y, CRACK[0])
    # flames around the fist
    fire(cv, cx, cy + 6, 30, 10, FIRE, seed=0.7, n=6, body=0.3)
    # charred clenched fist (knuckles up)
    cv.ellipse(cx, cy + 2, 7.5, 8, shade(CHAR, rim=0.75), "fist")
    for i, kx in enumerate((-5, -2, 1, 4)):
        cv.ellipse(cx + kx + 0.5, cy - 5, 1.8, 2.4, shade(CHAR, rim=0.7), "fist")
    cv.outline({"fist"}, CHAR[3])
    # embers glowing between the fingers
    for (x, y) in ((-3, -3), (0, -3), (3, -3), (-1, 3), (2, 6), (-4, 5)):
        cv.set(cx + x, cy + y, CRACK[1])
    return cv


# ---------------------------------------------------------------- 火の意思 flames_will
def flames_will():
    cv = Canvas((10, 8, 8))
    cx, cy = 26.5, 43
    fire(cv, cx, cy + 2, 30, 13, FIRE, seed=2.2, n=7, body=0.0)
    # almond eye
    WHITE, IRIS, IRIS_D, PUPIL = (250, 220, 170), (230, 110, 30), (150, 50, 20), (20, 6, 6)

    def eye(x, y, u, v, r):
        return None
    for y in range(int(cy - 6), int(cy + 7)):
        for x in range(int(cx - 14), int(cx + 15)):
            u = (x + 0.5 - cx) / 14
            h = 6 * (1 - u * u)
            if abs(y + 0.5 - cy) <= h:
                edge = abs(y + 0.5 - cy) > h - 1.2
                cv.set(x, y, (60, 20, 10) if edge else WHITE, "eye")
    cv.ellipse(cx, cy, 5, 5, lambda x, y, u, v, r: (IRIS_D if r > 0.7 else IRIS) if cv.owner(x, y) == "eye" else None)
    cv.ellipse(cx, cy, 2, 2.8, lambda x, y, u, v, r: PUPIL)
    cv.set(cx - 2, cy - 2, (255, 250, 230))
    # lower lashes of flame
    for k in range(-12, 13, 3):
        cv.set(cx + k, cy + 7 - abs(k) // 4, FIRE[2])
    return cv


# ------------------------------------------------------------ フォーマルハウト fomalhaut
def fomalhaut():
    SKY = [(12, 16, 34), (22, 30, 56), (36, 48, 84), (60, 76, 120)]
    RED = [(255, 220, 120), (240, 120, 50), (180, 50, 30), (90, 24, 24)]
    MTN = [(14, 12, 20), (26, 22, 34), (70, 30, 34)]
    cv = Canvas(SKY[0])

    def bg(x, y):
        # layered cloud bands
        band = math.sin(y * 0.55 + 2 * math.sin(x * 0.12)) * 0.5 + 0.5
        t = 0.25 + 0.5 * band * (1 - abs(y - 30) / 40)
        return ramp(x, y, t, SKY)
    cv.fill(bg)
    # the red star burning through the clouds: horizontal glowing streaks
    sx, sy = 26.5, 40
    for y in range(20, 58):
        for x in range(W):
            d = math.hypot((x - sx) / 22, (y - sy) / 7)
            if d < 1.0 and (y % 3 != 0 or d < 0.35):
                cv.set(x, y, ramp(x, y, 1 - d, [RED[3], RED[2], RED[1], RED[0]]))
    cv.ellipse(sx, sy, 3, 2.5, flat(RED[0]))
    for y in range(22, 36):                      # thin rising flare
        if prand(0, y, 3) < 0.8:
            cv.set(sx + (1 if y % 4 == 0 else 0), y, RED[1])
    # jagged mountains in front, rimmed with red light
    for x in range(W):
        top = 58 + int(6 * abs(math.sin(x * 0.18)) + 3 * math.sin(x * 0.53))
        for y in range(top, H):
            cv.set(x, y, MTN[0] if y > top + 2 else MTN[1])
        cv.set(x, top, MTN[2])
    return cv


ARTS = {
    "cold_flame": (cold_flame, 10),
    "fireball": (fireball, 12),
    "flame_drain": (flame_drain, 12),
    "flame_pact": (flame_pact, 12),
    "flames_will": (flames_will, 12),
    "fomalhaut": (fomalhaut, 12),
}
