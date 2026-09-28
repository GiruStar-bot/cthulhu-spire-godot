"""Wind-pack card illustrations (53x80 board, 53x59 output window)."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat

YEL = ((255, 230, 110), (236, 190, 50), (180, 130, 30), (100, 70, 20))


def _ribbon(cv, pts, width=2, tones=YEL, owner="ribbon"):
    """A fluttering ribbon: resampled smoothly, light face / dark face swap as it twists,
    with a dark edge only on the underside."""
    dense = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0)))
        for k in range(n):
            t = k / n
            # ease between points so corners round off
            dense.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * (3 * t * t - 2 * t * t * t)))
    dense.append(pts[-1])
    for i, (x, y) in enumerate(dense):
        face = tones[0] if (i // 5) % 2 == 0 else tones[1]
        for k in range(width):
            cv.set(x, y + k, face, owner)
        cv.set(x, y + width, tones[3])


# ---------------------------------------------------------------------- 砂漠 desert
def desert():
    SKY = [(250, 240, 200), (240, 226, 176), (226, 206, 150)]
    SAND = [(120, 70, 36), (160, 100, 52), (196, 136, 76), (224, 170, 106)]
    cv = Canvas(SKY[0])
    horizon = 38

    def bg(x, y):
        if y < horizon:
            return ramp(x, y, y / horizon, SKY)
        # dunes: layered ridges, lit side / shadow side
        h = y - horizon
        ridge = math.sin(x * 0.16 + h * 0.35) + 0.6 * math.sin(x * 0.07 - h * 0.12)
        t = 0.55 + 0.35 * ridge - h / 120
        return ramp(x, y, t, SAND)
    cv.fill(bg)
    # flag on a pole, cloth flying to the right
    for y in range(20, 46):
        cv.set(18, y, (60, 40, 24)); cv.set(19, y, (90, 62, 36))
    for i in range(20):                       # pennant tapering to the right, rippling
        x = 20 + i
        top = 20 + int(1.5 * math.sin(i * 0.6))
        h = max(1, 9 - i * 9 // 20)
        for dy in range(h):
            c = YEL[0] if dy < h / 2 else YEL[1]
            if (i + dy) % 7 == 0:
                c = YEL[2]
            cv.set(x, top + dy, c)
        cv.set(x, top + h, YEL[3])
    # blowing sand streaks
    for k in range(9):
        y = 30 + int(prand(k, 0, 3) * 26)
        x0 = int(prand(k, 1, 3) * 40)
        for s in range(4 + k % 3):
            if (s + k) % 3:
                cv.set(x0 + s, y, SAND[3])
    return cv


# ------------------------------------------------------------ 黄衣の王 king_in_yellow
def king_in_yellow():
    BG = [(24, 14, 8), (40, 24, 14), (62, 40, 22)]
    PAGE, PAGE_D, PAGE_S = (230, 214, 176), (190, 170, 130), (120, 100, 76)
    MASK = ((252, 214, 100), (230, 170, 50), (170, 110, 30), (90, 54, 18))
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, 0.2 + 0.5 * max(0, 1 - math.hypot((x - 30) / 30, (y - 30) / 30)), BG))
    # open book at the bottom
    cv.poly([(2, 54), (26, 50), (26, 72), (4, 76)], lambda x, y: PAGE_D if (y - x // 6) % 4 == 0 and 6 < x < 23 else PAGE, "book")
    cv.poly([(26, 50), (51, 53), (49, 76), (26, 72)], lambda x, y: PAGE_S if (y + x // 6) % 4 == 0 and 29 < x < 47 else PAGE_D, "book")
    cv.line(26, 50, 26, 72, PAGE_S)
    cv.outline({"book"}, (60, 44, 30))
    # the pale mask lying tilted on the book
    cv.ellipse(25, 38, 13, 15, shade(MASK, rim=0.82), "mask")
    cv.outline({"mask"}, MASK[3])
    E = (20, 10, 6)
    for (ex, ey) in ((19, 34), (29, 34)):              # eye holes
        cv.ellipse(ex, ey, 2.8, 1.8, flat(E))
    cv.line(24, 35, 22, 42, MASK[2]); cv.line(22, 42, 25, 43, MASK[2])     # nose
    cv.ellipse(24, 47, 3, 1.6, flat(E))                                      # mouth, slightly open
    cv.line(16, 28, 20, 31, MASK[3])                   # crack
    # wisps of pale wind
    for k in range(3):
        for s in range(14):
            cv.set(34 + s, 18 + k * 5 + int(2 * math.sin(s * 0.5 + k)), (210, 200, 180) if s % 3 else None)
    return cv


# ---------------------------------------------------------------- つじ風 whirlwind
def whirlwind():
    SKY = [(40, 56, 76), (60, 78, 98), (90, 106, 124)]
    GROUND = [(120, 126, 130), (150, 156, 158), (180, 184, 184)]
    WIND = [(250, 250, 246), (206, 204, 196), (150, 148, 142), (100, 98, 96)]
    cv = Canvas(SKY[0])
    ground = 60
    cv.fill(lambda x, y: ramp(x, y, y / ground, SKY) if y < ground else
            (GROUND[0] if (x - (y - ground) * (x - 26) // 12) % 9 == 0 or (y - ground) % 6 == 0 else GROUND[1 + (x + y) % 2]))
    # buildings silhouettes on the horizon
    for (x0, x1, top) in ((0, 11, 48), (40, 53, 46)):
        cv.poly([(x0, top), (x1, top), (x1, ground), (x0, ground)], lambda x, y: (70, 76, 84) if (x + y) % 5 else (90, 96, 104))
    for y in range(40, ground):
        cv.set(44, y, (40, 44, 50))                    # street lamp
    cv.set(45, 40, (40, 44, 50)); cv.set(46, 40, (40, 44, 50))
    # funnel: stacked wobbling bands, wide at the top
    for y in range(4, ground):
        t = (y - 4) / (ground - 4)
        half = 18 * (1 - t) ** 1.3 + 1.5
        c = 26.5 + 4 * math.sin(t * 5)
        for x in range(int(c - half), int(c + half) + 1):
            u = (x + 0.5 - c) / half
            band = math.sin(y * 0.9 + u * 3)
            tone = 0.5 + 0.3 * band - 0.3 * u
            cv.set(x, y, ramp(x, y, max(0, min(1, tone)), WIND[::-1]))
    # yellow ribbon spiralling around the funnel
    pts = []
    for i in range(60):
        t = i / 59
        y = 8 + t * 46
        half = 18 * (1 - (y - 4) / (ground - 4)) ** 1.3 + 3
        x = 26.5 + 4 * math.sin((y - 4) / (ground - 4) * 5) + half * math.sin(t * math.pi * 5)
        if math.cos(t * math.pi * 5) > -0.2:           # only the front half is visible
            pts.append((x, y))
        else:
            if len(pts) > 1:
                _ribbon(cv, pts)
            pts = []
    if len(pts) > 1:
        _ribbon(cv, pts)
    # debris / splash at the base
    for k in range(16):
        ang = math.pi * (0.05 + 0.9 * prand(k, 0, 5))
        ln = 2 + 5 * prand(k, 1, 5)
        for s in range(int(ln)):
            cv.set(26.5 + math.cos(ang) * (3 + s * 1.3), ground - math.sin(ang) * s * 0.8, WIND[0] if s % 2 else WIND[1])
    return cv


# ------------------------------------------------------------ 風神の弓 wind_gods_bow
def wind_gods_bow():
    SKY = [(120, 124, 120), (140, 142, 134), (160, 160, 150)]
    BONE = ((250, 246, 234), (214, 206, 186), (150, 140, 120), (80, 72, 60))
    GRIP, GRIP_D = (70, 50, 36), (40, 28, 20)
    cv = Canvas(SKY[0])
    cv.fill(lambda x, y: ramp(x, y, (x + y * 0.5) / 90, SKY))
    for k in range(8):                                  # wind streaks
        y = 8 + k * 8 + int(prand(k, 0, 2) * 4)
        for s in range(int(10 + 10 * prand(k, 1, 2))):
            if s % 4 != 3:
                cv.set(int(prand(k, 2, 2) * 20) + s, y - s // 5, SKY[2] if k % 2 else (210, 206, 192))
    # bow: an arc from top right to bottom left, string straight
    top, bot = (40, 6), (10, 72)
    arc = []
    for i in range(60):
        t = i / 59
        x = top[0] + (bot[0] - top[0]) * t + 14 * math.sin(t * math.pi)
        y = top[1] + (bot[1] - top[1]) * t + 4 * math.sin(t * math.pi)
        arc.append((x, y))
    for (x0, y0), (x1, y1) in zip(arc, arc[1:]):
        cv.line(x0, y0, x1, y1, BONE[1], "bow", width=3)
    cv.outline_outside({"bow"}, BONE[3])
    for (x, y) in arc[::3]:
        cv.set(x, y, BONE[0])
    # curled tips
    for (x, y, s) in ((40, 6, -1), (10, 72, 1)):
        cv.set(x - s, y - s, BONE[1]); cv.set(x - 2 * s, y - s, BONE[1]); cv.set(x - 2 * s, y, BONE[2])
    cv.line(top[0], top[1], bot[0], bot[1], (90, 84, 70))                # string
    # grip wrapped in leather
    gx, gy = arc[30]
    for k in range(-3, 4):
        cv.set(gx + k * 0.4, gy + k, GRIP if k % 2 else GRIP_D)
        cv.set(gx + k * 0.4 + 1, gy + k, GRIP_D)
    # arrow nocked across the bow
    cv.line(20, 32, 50, 44, (90, 70, 50))
    cv.poly([(50, 42), (53, 45), (49, 46)], flat((200, 200, 200)))
    for (x, y) in ((18, 30), (19, 32), (17, 32)):
        cv.set(x, y, (180, 220, 230))
    # yellow ribbons tied to the limbs, blowing left
    _ribbon(cv, [(47, 20), (40, 17), (34, 21), (27, 17), (20, 20), (14, 16)])
    _ribbon(cv, [(29, 62), (22, 60), (16, 64), (9, 60), (4, 63)])
    return cv


# ---------------------------------------------------------- 黄色のコイン yellow_coin
def yellow_coin():
    CLOTH = [(18, 24, 38), (30, 38, 56), (46, 56, 76), (66, 78, 98)]
    GOLD = ((250, 226, 150), (212, 170, 80), (160, 112, 44), (90, 58, 22))
    cv = Canvas(CLOTH[0])
    cv.fill(lambda x, y: ramp(x, y, 0.3 + 0.35 * math.sin(x * 0.18 + y * 0.12) + 0.15 * math.sin(y * 0.4), CLOTH))
    cx, cy, r = 26.5, 40, 18
    cv.ellipse(cx + 1.5, cy + 2, r, r, flat((10, 12, 20)))                 # shadow
    cv.ellipse(cx, cy, r, r, lambda x, y, u, v, rr: GOLD[3] if rr > 0.9 else (GOLD[0] if rr > 0.78 and u + v < -0.3 else (GOLD[2] if rr > 0.78 else (GOLD[1] if (x * 7 + y * 3) % 11 else GOLD[2]))), "coin")
    # embossed shield with crown
    cv.poly([(19, 32), (34, 32), (34, 42), (26.5, 52), (19, 42)], lambda x, y: GOLD[1], "shield")
    cv.outline({"shield"}, GOLD[3])
    for (x, y) in ((21, 34), (22, 35), (32, 34), (31, 35), (26, 38), (27, 38), (26, 44), (27, 44), (24, 41), (29, 41)):
        cv.set(x, y, GOLD[0])
    for (x, y) in ((23, 38), (30, 38), (26, 47)):
        cv.set(x, y, GOLD[3])
    for x in range(21, 33):                                             # crown
        cv.set(x, 30, GOLD[2])
    for x in (21, 24, 26, 27, 29, 32):
        cv.set(x, 29, GOLD[0]); cv.set(x, 28, GOLD[1] if x in (26, 27) else GOLD[0])
    cv.set(26, 27, GOLD[0]); cv.set(27, 26, GOLD[0])
    return cv


# ------------------------------------------------------ 黄色の幻覚 yellow_hallucination
def yellow_hallucination():
    GLOW = [(40, 30, 6), (90, 70, 14), (150, 120, 30), (210, 180, 60), (250, 230, 120)]
    SIL, SIL_H = (20, 14, 6), (60, 46, 16)
    cv = Canvas(GLOW[0])

    def bg(x, y):
        d = math.hypot(x - 26.5, (y - 26) * 0.9)
        rings = 0.5 + 0.5 * math.sin(d * 0.9 - math.atan2(y - 26, x - 26.5) * 2)
        t = max(0, 1 - d / 38) * 0.7 + rings * 0.3
        return ramp(x, y, t, GLOW)
    cv.fill(bg)
    # crowned silhouette, head and shoulders
    cv.poly([(4, 80), (8, 56), (16, 50), (22, 48), (31, 48), (37, 50), (45, 56), (49, 80)], flat(SIL), "sil")
    cv.ellipse(26.5, 38, 7, 9, flat(SIL), "sil")
    crown = [(19, 32), (20, 22), (22, 28), (24, 19), (26.5, 26), (29, 19), (31, 28), (33, 22), (34, 32)]
    cv.poly(crown, flat(SIL), "sil")
    cv.outline_outside({"sil"}, SIL_H)
    # ragged hem / tatters dissolving into the glow
    for x in range(4, 50):
        if prand(x, 0, 8) < 0.5:
            cv.set(x, 55 + int(3 * prand(x, 1, 8)), SIL_H)
    return cv


ARTS = {
    "desert": (desert, 10),
    "king_in_yellow": (king_in_yellow, 14),
    "whirlwind": (whirlwind, 6),
    "wind_gods_bow": (wind_gods_bow, 10),
    "yellow_coin": (yellow_coin, 11),
    "yellow_hallucination": (yellow_hallucination, 12),
}
