"""Elder-pack card illustrations (53x80 pixel art)."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat


# ------------------------------------------------------------------ 猫叉 cat_fork
HEART = [
    ".OO.OO.",
    "OhhOmmO",
    "OhmmmmO",
    ".OmmmO.",
    "..OmO..",
    "...O...",
]


def cat_fork():
    BG = [(4, 4, 7), (10, 10, 14), (22, 22, 28), (44, 44, 52), (80, 80, 90)]
    cv = Canvas(BG[0])
    # mist cloud, upper left: soft dithered blob
    def bg(x, y):
        d = math.hypot((x - 22) / 22, (y - 15) / 11)
        d2 = math.hypot((x - 34) / 14, (y - 22) / 8)
        t = max(0.0, 1.0 - min(d, d2 * 1.1))
        n = prand(x // 2, y // 2, 4) * 0.25
        return ramp(x, y, t * 0.9 + n * t, BG)
    cv.fill(bg)
    # winding stem from bottom to the cloud
    STEM, STEM_D = (150, 150, 160), (86, 86, 98)
    pts = []
    for y in range(76, 20, -1):
        x = 26 + 7 * math.sin((76 - y) * 0.11) + 2 * math.sin((76 - y) * 0.31)
        pts.append((x, y))
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        cv.line(x0, y0, x1, y1, STEM, "stem")
        cv.set(round(x0) + 1, y0, STEM_D)
    # heart leaves alternating left / right of the stem
    pal = {"O": (40, 40, 48), "h": (246, 246, 250), "m": (190, 190, 200)}
    for k, i in enumerate(range(4, len(pts) - 2, 7)):
        x, y = pts[i]
        side = -1 if k % 2 == 0 else 1
        left = int(round(x)) + (2 if side > 0 else -8)
        cv.sprite(HEART, left, int(y) - 3, pal)
        # tiny petiole
        cv.set(int(round(x)) + side, int(y), STEM)
    # sparkles
    SP, SP_D = (255, 255, 255), (150, 150, 170)
    for (x, y, big) in ((12, 30, 1), (40, 36, 1), (17, 52, 0), (37, 60, 1), (30, 26, 0), (9, 64, 0),
                        (44, 48, 0), (21, 70, 0), (33, 44, 0), (15, 40, 0), (41, 22, 0)):
        cv.set(x, y, SP)
        if big:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cv.set(x + dx, y + dy, SP_D)
    return cv


# ------------------------------------------------------------ 夢の癒し dream_mending
HOOD = [
    "....OOOOO....",
    "...OhhhhhO...",
    "..OhhHHHhhO..",
    "..OhH...HhO..",
    "..OhH...HhO..",
    ".OhhH...HhhO.",
    ".OhhhH.HhhhO.",
    "OhhhhhhhhhhhO",
]


def dream_mending():
    SKY = [(10, 14, 34), (16, 22, 48), (24, 32, 64)]
    SEA = [(20, 34, 60), (34, 56, 90), (70, 100, 140)]
    STONE = ((96, 104, 110), (66, 72, 80), (44, 48, 56), (28, 30, 38))
    MOSS = (70, 92, 50)
    ROBE, ROBE_D, ROBE_H = (22, 22, 30), (12, 12, 18), (38, 38, 50)
    HALO, HALO_D = (236, 200, 130), (140, 110, 70)
    SKIN, SKIN_D, SKIN_S = (222, 168, 132), (170, 112, 88), (110, 70, 56)
    CLOTH = (190, 50, 50)
    HAIR = (150, 110, 60)
    FLAME, FLAME_D, WAX = (255, 240, 170), (240, 170, 70), (230, 220, 200)
    WATER = [(8, 12, 24), (16, 22, 40), (30, 40, 64)]
    horizon = 36
    cv = Canvas(SKY[0])

    def bg(x, y):
        if y < horizon:
            c = ramp(x, y, y / horizon, SKY)
            if prand(x * 7 + 3, y * 13 + 1, 5) < 0.02 and y < 30:
                c = (230, 230, 240)
            return c
        if y < 46:
            t = (y - horizon) / 10
            c = ramp(x, y, 1 - t, SEA)
            if y == horizon + 1 and prand(x, 0, 8) < 0.6:
                c = SEA[2]
            return c
        return ramp(x, y, (y - 46) / 34 * 0.6, WATER)
    cv.fill(bg)

    # standing stones
    def stone(x0, x1, top, bottom, lean):
        pts = [(x0 + lean, top), (x1 + lean, top + 2), (x1, bottom), (x0, bottom)]
        cv.poly(pts, lambda x, y: STONE[1] if x < (x0 + x1) / 2 + lean * (bottom - y) / (bottom - top) else STONE[2], "stone")
    stone(2, 10, 20, 52, 1)
    stone(43, 51, 22, 52, -1)
    cv.outline({"stone"}, STONE[3])
    for x in range(3, 11):
        if prand(x, 1, 3) < 0.7:
            cv.set(x + 1, 21, MOSS); cv.set(x + 1, 22, MOSS if prand(x, 2, 3) < 0.5 else STONE[1])
    for x in range(43, 51):
        if prand(x, 1, 7) < 0.7:
            cv.set(x - 1, 23, MOSS); cv.set(x - 1, 24, MOSS if prand(x, 2, 7) < 0.5 else STONE[2])

    # halo behind the hooded figure
    cv.ellipse(26.5, 14, 9.5, 9.5, lambda x, y, u, v, r: (HALO if r > 0.8 else (HALO_D if r > 0.62 and dither(x, y, 0.5) else None)))
    # hooded figure: tall dark robe widening to the ground
    cv.poly([(21, 12), (32, 12), (35, 30), (37, 46), (16, 46), (18, 30)],
            lambda x, y: ROBE_H if x < 21 + (y - 12) * -0.1 + 2 else (ROBE_D if x > 31 else ROBE), "robe")
    cv.sprite(HOOD, 20, 8, {"O": (6, 6, 10), "h": ROBE, "H": ROBE_H, ".": (2, 2, 4)})
    cv.outline({"robe"}, (6, 6, 10))
    for (x, y0) in ((23, 22), (26, 20), (30, 22)):
        for y in range(y0, 47):
            if cv.owner(x, y) == "robe":
                cv.set(x, y, ROBE_D)
    for y in range(20, 47):
        for x in range(W):
            if cv.owner(x, y) == "robe" and cv.owner(x - 1, y) == "robe" and cv.owner(x - 2, y) != "robe":
                cv.set(x, y, ROBE_H)
                break

    # altar slab
    cv.poly([(5, 51), (48, 51), (50, 59), (3, 59)], lambda x, y: STONE[0] if y == 51 else (STONE[1] if y < 55 else STONE[2]), "altar")
    cv.outline({"altar"}, STONE[3])
    # sleeper lying on the altar, head to the left
    cv.ellipse(10.5, 47, 3.0, 2.8, shade((SKIN, SKIN, SKIN_D, SKIN_S)), "body")      # head
    for x in range(8, 13):
        cv.set(x, 44, HAIR)
    for y in range(45, 49):
        cv.set(7, y, HAIR)
    cv.poly([(13, 44.5), (22, 44), (31, 44.5), (38, 46), (46, 47.5), (46, 50), (13, 50.5)],
            lambda x, y: SKIN if y < 47 else (SKIN_D if y < 49 else SKIN_S), "body")   # torso + legs
    for x in range(26, 32):
        for y in (46, 47, 48):
            cv.set(x, y, CLOTH if y < 48 else (140, 30, 34))
    for x in range(14, 24):                                                          # arm along the side
        cv.set(x, 49, SKIN_D)
    cv.set(19, 45, SKIN_D); cv.set(20, 46, SKIN_D)                                     # ribs shading
    cv.outline({"body"}, SKIN_S)
    # candle standing on the sleeper's chest, with flame
    for y in range(38, 45):
        cv.set(22, y, WAX)
    cv.set(23, 44, (160, 150, 140))
    cv.set(22, 36, FLAME); cv.set(22, 37, FLAME); cv.set(22, 35, FLAME_D)
    cv.set(21, 37, FLAME_D); cv.set(23, 37, FLAME_D)
    # candle light reflected on the water: broken vertical streak
    # candle light on the foreground water: a few short horizontal glints
    for (x, y, n) in ((21, 63, 3), (22, 67, 2), (20, 71, 4), (23, 75, 2)):
        for k in range(n):
            cv.set(x + k, y, FLAME_D if k else FLAME)
    return cv


# ----------------------------------------------------------------- 古の印 eldersign
def eldersign():
    STONE = [(14, 18, 28), (20, 26, 38), (28, 34, 48)]
    RING = [(255, 236, 190), (220, 180, 110), (130, 100, 60), (60, 50, 40)]
    RUNE, RUNE_G = (250, 246, 236), (170, 190, 220)
    cv = Canvas(STONE[0])

    def bg(x, y):
        # stone blocks
        row = y // 9
        off = 6 if row % 2 else 0
        if y % 9 == 0 or (x + off) % 13 == 0:
            return STONE[0]
        return STONE[2] if prand(x, y, 2) < 0.08 else STONE[1]
    cv.fill(bg)
    cx, cy, rx, ry = 26.5, 39, 21.5, 27
    # outer glow + ring
    cv.ellipse(cx, cy, rx + 3, ry + 3, lambda x, y, u, v, r: RING[3] if dither(x, y, 0.5) else None)
    cv.ellipse(cx, cy, rx + 1.5, ry + 1.5, lambda x, y, u, v, r: RING[2] if r > 0.9 else None)
    cv.ellipse(cx, cy, rx, ry, lambda x, y, u, v, r: (RING[0] if r > 0.93 else (RING[1] if r > 0.85 else (
        RING[2] if r > 0.78 and dither(x, y, 0.5) else (8, 10, 16)))))
    # sigil: big X, frame strokes and runic letters (all in pale strokes, 1px)
    L = lambda a, b, c, d: cv.line(a, b, c, d, RUNE, "rune")
    L(14, 22, 38, 58); L(38, 22, 14, 58)            # the X
    L(14, 22, 14, 44); L(38, 36, 38, 58)            # side bars
    L(14, 22, 22, 22); L(30, 58, 38, 58)            # top-left / bottom-right hooks
    L(26, 15, 26, 22)                                # 'R' stem at the top
    L(26, 15, 30, 15); L(30, 15, 30, 18); L(30, 18, 26, 18); L(26, 18, 30, 22)
    L(31, 26, 35, 26); L(35, 26, 35, 30); L(35, 30, 32, 30)   # small 'G'-like rune right
    L(17, 28, 17, 33); L(17, 28, 20, 31); L(20, 31, 20, 28)   # 'N'-like rune left
    L(21, 50, 24, 46); L(24, 46, 27, 50); L(22, 49, 26, 49)   # 'A'-like rune bottom
    L(26, 58, 26, 64)                                # tail through the ring
    # faint cold glow around the strokes
    for y in range(H):
        for x in range(W):
            if cv.owner(x, y) == "rune":
                continue
            if any(cv.owner(x + dx, y + dy) == "rune" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) and dither(x, y, 0.5):
                cv.set(x, y, (60, 70, 96))
    # lightning crackles
    for (x, y) in ((11, 36), (12, 37), (41, 44), (40, 45), (33, 19), (19, 55)):
        cv.set(x, y, RUNE_G)
    return cv


# ------------------------------------------------------------ 女神の加護 goddess_blessing
CAT = [
    "..O..O.........",
    ".OmO.mO.OOOOO..",
    ".OmmmmOOmmmmmOO",
    "OmhhmmmmmmmhmmO",
    "OmehmmmmmmhmmmO",
    "OmmmmmmmmmmmmmO",
    ".OmdddddddmmmO.",
    "..OOmmmmmmmOO..",
    "....OOOOOOO....",
]


def goddess_blessing():
    BG = (3, 4, 3)
    ARC = [(236, 240, 170), (190, 200, 110), (110, 120, 60), (50, 56, 30)]
    WEAVE = ((120, 118, 70), (92, 90, 52), (64, 62, 36), (36, 34, 20))
    cv = Canvas(BG)
    # two glowing arcs like cupped hands of light
    for side in (-1, 1):
        for i in range(0, 60):
            t = i / 59
            ang = math.pi * (0.62 + 0.62 * t)
            x = 26.5 + side * (15 * -math.cos(ang) + 0) + side * 1
            y = 42 - 17 * math.sin(ang) + 10 * t
            cx = 26.5 + side * (4 + 13 * math.sin(math.pi * t))
            cy = 24 + 32 * t
            for k, col in ((0, ARC[0]), (1, ARC[1])):
                cv.set(round(cx) + side * k * 0 + (k if side > 0 else -k) * 0, round(cy) + k * 0, None)
            cv.set(round(cx), round(cy), ARC[0], "arc")
            cv.set(round(cx) + side, round(cy), ARC[1], "arc")
            if 0.2 < t < 0.8:
                cv.set(round(cx) - side, round(cy), ARC[1], "arc")
    cv.glow({"arc"}, [ARC[2], ARC[3], None], 3)
    # woven cushion / basket pedestal
    cv.poly([(18, 45), (35, 45), (34, 58), (19, 58)], lambda x, y: (
        WEAVE[0] if (x + y) % 4 == 0 else (WEAVE[1] if (x - y) % 4 == 0 else WEAVE[2])), "base")
    cv.ellipse(26.5, 45, 9.5, 2.2, lambda x, y, u, v, r: WEAVE[0] if v < 0 else WEAVE[1], "base")
    for x in range(19, 35):
        cv.set(x, 51, WEAVE[3])
    cv.outline({"base"}, WEAVE[3])
    # sleeping cat curled on top
    cv.sprite(CAT, 19, 36, {"O": (30, 30, 30), "m": (120, 120, 116), "h": (170, 170, 164), "d": (70, 70, 68), "e": (36, 36, 36)})
    return cv


# ------------------------------------------------------------ 女神への供物 goddess_offering
def goddess_offering():
    BG = [(6, 3, 3), (14, 6, 6), (24, 10, 10)]
    SKIN = ((150, 64, 56), (116, 44, 40), (80, 28, 28), (44, 14, 16))
    BOWL = ((96, 56, 38), (70, 40, 28), (46, 26, 20), (24, 14, 12))
    BLOOD = [(70, 8, 12), (110, 18, 22), (150, 36, 36)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - math.hypot((x - 26) / 34, (y - 48) / 40)), BG))
    # faint cat silhouette in the dark, upper right
    for (x, y) in [(38, 16), (39, 15), (43, 15), (44, 16), (38, 17), (44, 17)]:
        cv.set(x, y, (34, 12, 12))
    cv.ellipse(41, 19, 3.5, 3, flat((28, 10, 10)))
    cv.ellipse(41, 26, 4.5, 5, flat((24, 9, 9)))
    # bowl
    cv.ellipse(26.5, 56, 19, 12, shade(BOWL, rim=0.8), "bowl")
    cv.poly([(7, 56), (46, 56), (46, 57), (7, 57)], flat(BOWL[1]), "bowl")
    cv.ellipse(26.5, 52, 19, 5.5, lambda x, y, u, v, r: BOWL[0] if r > 0.8 else None, "bowl")
    cv.ellipse(26.5, 52.3, 16.5, 4.2, lambda x, y, u, v, r: ramp(x, y, max(0, -v) * 0.5 + (0.4 if r < 0.25 else 0), BLOOD), "blood")
    cv.outline({"bowl"}, BOWL[3])
    # forearm and hand reaching down from the upper left, fingers into the bowl
    arm = [(3, 0), (15, 0), (24, 22), (18, 26)]
    cv.poly(arm, lambda x, y: SKIN[1] if x < 9 + y * 0.45 else SKIN[2], "hand")
    cv.poly([(16, 20), (30, 22), (34, 30), (32, 36), (20, 34), (15, 27)],
            lambda x, y: SKIN[0] if y < 26 and x < 26 else (SKIN[1] if y < 31 else SKIN[2]), "hand")
    # fingers pointing down
    # fingers: tapered, touching, slightly curled toward the bowl
    for (x0, x1, top, bot, bend) in ((18, 21, 32, 42, 0.5), (21, 24, 33, 46, 1.0), (24, 27, 33, 47, 1.2), (27, 30, 33, 45, 1.3), (30, 33, 31, 41, 1.0)):
        cv.poly([(x0, top), (x1, top), (x1 - 0.5 + bend, bot - 2), (x0 + 1 + bend, bot)],
                lambda x, y, xs=x0: SKIN[0] if x == xs + 1 and y < 38 else SKIN[1], "hand")
    cv.poly([(16, 26), (19, 28), (15, 37), (13, 36)], flat(SKIN[1]), "hand")          # thumb
    cv.outline({"hand"}, SKIN[3])
    # veins / knuckles highlights
    for (x, y) in ((20, 24), (23, 23), (26, 24), (22, 28), (25, 29), (28, 30)):
        cv.set(x, y, SKIN[0])
    for (x0, x1, top, bot, bend) in ((18, 21, 32, 42, 0.5), (21, 24, 33, 46, 1.0), (24, 27, 33, 47, 1.2), (27, 30, 33, 45, 1.3)):
        for y in range(top + 2, bot - 1):
            cv.set(x1, y, SKIN[3])       # gap line between neighbouring fingers
    # ripples where fingertips touch the blood
    for x in (25, 26, 28, 29):
        cv.set(x, 50, BLOOD[2])
    return cv


# ---------------------------------------------------------------- 光の柱 light_pillar
def light_pillar():
    BG = (4, 3, 2)
    BEAM = [(255, 255, 240), (255, 232, 170), (236, 170, 80), (150, 90, 36), (70, 40, 20)]
    WATER = [(6, 5, 6), (14, 12, 12), (26, 22, 20)]
    cv = Canvas(BG)
    surface = 58
    cv.fill(lambda x, y: None if y < surface else ramp(x, y, (y - surface) / 22 * 0.7, WATER))
    # vertical beam, slightly wider toward the bottom, with soft dithered edges
    for y in range(0, surface + 1):
        half = 3.5 + y * 0.03
        for x in range(W):
            d = abs(x + 0.5 - 26.5) / half
            if d < 0.35:
                c = BEAM[0]
            elif d < 0.7:
                c = BEAM[1]
            elif d < 1.0:
                c = BEAM[2] if dither(x, y, 0.75) else BEAM[1]
            elif d < 1.6:
                c = BEAM[3] if dither(x, y, 1.6 - d) else None
            elif d < 2.4:
                c = BEAM[4] if dither(x, y, (2.4 - d) * 0.5) else None
            else:
                c = None
            cv.set(x, y, c)
    # sparks spraying out at the base
    for k in range(22):
        ang = math.pi * (0.08 + 0.84 * prand(k, 0, 31))
        length = 4 + 9 * prand(k, 1, 31)
        for s in range(int(length)):
            x = 26.5 + math.cos(ang) * s * (1.6 if k % 2 else 1.0)
            y = surface - 1 - math.sin(ang) * s * 0.9
            if prand(k, s, 33) < 0.8:
                cv.set(x, y, BEAM[1] if s < length * 0.5 else BEAM[2])
    # dark thing at the base where the beam strikes
    cv.ellipse(26.5, surface - 1, 4.5, 2.2, lambda x, y, u, v, r: (40, 26, 18) if r > 0.4 else (20, 14, 10))
    # reflection on water: broken horizontal dashes under the beam
    for y in range(surface + 1, H):
        spread = 3 + (y - surface) * 0.25
        for x in range(W):
            dx = abs(x + 0.5 - 26.5)
            if dx < spread and prand(x // 2, y, 41) < 0.55 * (1 - dx / spread) + 0.1 * (y % 2):
                cv.set(x, y, BEAM[1] if dx < 2 else (BEAM[2] if dx < spread * 0.6 else BEAM[3]))
    return cv


# ------------------------------------------------------------------ 三叉の矛 trident
def trident():
    ROCK = [(16, 26, 30), (26, 40, 44), (40, 56, 58), (58, 76, 76)]
    CAVE = [(4, 8, 12), (8, 14, 18), (14, 22, 26)]
    PLANT, PLANT_D = (60, 110, 60), (34, 70, 40)
    BONE = ((246, 238, 220), (208, 196, 170), (150, 136, 112), (70, 60, 48))
    GOLD = ((250, 220, 120), (200, 160, 60), (120, 90, 30))
    WRAP, WRAP_D = (110, 80, 50), (70, 48, 30)
    cv = Canvas(ROCK[1])

    def bg(x, y):
        d = math.hypot((x - 26.5) / 20, (y - 30) / 30)
        if d < 1.0:
            return ramp(x, y, 1 - d, [CAVE[2], CAVE[1], CAVE[0], CAVE[0]])
        # rough rock with blocky texture
        r = prand(x // 3, y // 3, 7)
        c = ROCK[2] if r < 0.35 else (ROCK[1] if r < 0.8 else ROCK[3])
        if d < 1.12:
            c = ROCK[0]
        return c
    cv.fill(bg)
    # ruined pillar stubs at the sides
    for (x0, x1, top) in ((2, 7, 38), (46, 51, 43)):
        cv.poly([(x0, top), (x1, top - 1), (x1, H), (x0, H)],
                lambda x, y, a=x0: ROCK[3] if x < a + 2 else ROCK[2], "pillar")
    cv.outline({"pillar"}, ROCK[0])
    # ground
    cv.fill(lambda x, y: (ROCK[2] if prand(x, y, 9) < 0.5 else ROCK[1]) if y >= 61 else None)
    # plants
    for (bx, h) in ((9, 9), (12, 6), (41, 8), (44, 11), (38, 5), (15, 4)):
        for s in range(h):
            x = bx + int(2 * math.sin(s * 0.6 + bx))
            cv.set(x, 62 - s, PLANT if s % 2 else PLANT_D)
            if s % 3 == 1:
                cv.set(x + 1, 62 - s, PLANT)
    # shaft
    for y in range(40, H):
        cv.set(26, y, WRAP if (y // 2) % 2 else WRAP_D, "shaft")
        cv.set(27, y, WRAP_D, "shaft")
    # gold collar
    for y in range(36, 42):
        for x in range(24, 30):
            cv.set(x, y, GOLD[0] if x == 24 else (GOLD[2] if x == 29 or y == 41 else GOLD[1]), "tri")
    # bone head: central prong + two curved side prongs
    for y in range(12, 36):
        cv.set(26, y, BONE[0], "tri"); cv.set(27, y, BONE[1], "tri")
    cv.poly([(26.5, 7), (29.5, 12), (26.5, 11), (23.5, 12)], flat(BONE[0]), "tri")     # centre tip
    for side in (-1, 1):
        prev = None
        for i in range(0, 25):
            t = i / 24
            x = 26.5 + side * (3 + 7 * math.sin(t * math.pi * 0.5) + 2 * t)
            y = 35 - 18 * t
            p = (round(x), round(y))
            cv.set(p[0], p[1], BONE[1] if side > 0 else BONE[0], "tri")
            cv.set(p[0] + side * -1, p[1], BONE[2] if side > 0 else BONE[1], "tri")
        tipx = 26.5 + side * 12
        cv.poly([(tipx, 11), (tipx + 2.5, 17), (tipx - 2.5, 17)], flat(BONE[0]), "tri")
        # cross bar joining the prongs
    for x in range(17, 37):
        cv.set(x, 34, BONE[1], "tri"); cv.set(x, 35, BONE[2], "tri")
    # barbs on the centre prong
    for (x, y) in ((24, 16), (25, 17), (29, 16), (28, 17)):
        cv.set(x, y, BONE[1], "tri")
    cv.outline_outside({"tri", "shaft"}, BONE[3])
    return cv


# name -> (draw function, first visible row). Output is rows top..top+58 (53x59).
ARTS = {
    "cat_fork": (cat_fork, 10),
    "dream_mending": (dream_mending, 4),
    "eldersign": (eldersign, 10),
    "goddess_blessing": (goddess_blessing, 11),
    "goddess_offering": (goddess_offering, 10),
    "light_pillar": (light_pillar, 12),
    "trident": (trident, 5),
}
