"""Water-pack card illustrations (53x80 board, 53x59 output window)."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat

SEA_BG = [(6, 16, 22), (10, 28, 36), (16, 44, 54), (30, 70, 80)]


def scale_cell(x, y, size, ox=0, oy=0, rot=0.0):
    """Overlapping round scales (each row covers the lower half of the row above).
    Returns (u, v, id): u,v are the offset from the scale's centre in radii (-1..1)."""
    xr = x + 0.5 + (y - oy) * rot - ox
    yr = y + 0.5 - oy
    step = size * 0.55
    best = None
    base_row = int(math.floor(yr / step))
    for row in (base_row + 1, base_row, base_row - 1):     # front-most row first
        shift = size * 0.5 if row % 2 else 0
        col = int(math.floor((xr - shift) / size + 0.5))
        cx, cy = col * size + shift, row * step
        u, v = (xr - cx) / (size * 0.55), (yr - cy) / (size * 0.55)
        if u * u + v * v <= 1.0 and v >= -0.25:
            return u, v, (row, col)
        if best is None:
            best = (u, v, (row, col))
    return best


def scale_color(x, y, u, v, tones, sid, sparkle=None, seed=0):
    """tones = (hi, mid, dark, edge). Shaded as a small dome lit from top-left."""
    hi, mid, dark, edge = tones
    r = u * u + v * v
    if r > 0.8:
        return edge
    if r > 0.55 or v > 0.55:
        return dark
    if u < -0.1 and v < 0.15:
        return hi
    if sparkle and prand(sid[0], sid[1], seed) < 0.15 and abs(u) < 0.25 and abs(v - 0.1) < 0.2:
        return sparkle
    return mid


# ---------------------------------------------------------------- 適応の鱗 adapted_scales
def adapted_scales():
    SKIN = [(216, 186, 170), (186, 152, 138), (140, 108, 98), (90, 66, 60)]
    SC = ((150, 250, 220), (60, 190, 160), (30, 110, 100), (12, 50, 50))
    cv = Canvas(SEA_BG[0])
    cv.fill(lambda x, y: ramp(x, y, 0.3 * (1 - abs(x - 26) / 30), SEA_BG))
    # forearm running from bottom-left up to top-right
    for y in range(H):
        c = 22 + (80 - y) * 0.1
        x0, x1 = c - 17, c + 17
        for x in range(int(x0), int(x1) + 1):
            t = (x - x0) / (x1 - x0)            # 0 left edge .. 1 right edge
            edge_scale = 0.36 + 0.05 * math.sin(y * 0.12)
            if t < edge_scale:                   # human skin on the left
                col = SKIN[0] if t > 0.12 else (SKIN[1] if t > 0.05 else SKIN[2])
                if prand(x, y, 3) < 0.05:
                    col = SKIN[1]
            else:
                u, v, sid = scale_cell(x, y, 6, rot=0.0)
                col = scale_color(x, y, u, v, SC, sid, sparkle=(220, 255, 240), seed=5)
                if t < edge_scale + 0.06:        # scales fading in: sparse
                    col = SKIN[1] if dither(x, y, 0.5) else col
            cv.set(x, y, col, "arm")
    cv.outline({"arm"}, SKIN[3])
    # water droplets on the skin
    for (x, y) in ((14, 30), (12, 44), (15, 58), (10, 64), (17, 22)):
        cv.set(x, y, (240, 250, 255)); cv.set(x, y + 1, (160, 190, 200))
    return cv


# --------------------------------------------------------------------- 異本 apocrypha
def apocrypha():
    ROCK = [(28, 40, 42), (42, 58, 60), (60, 78, 78), (84, 104, 100)]
    COVER = ((110, 210, 196), (50, 140, 132), (28, 88, 86), (12, 40, 42))
    SPINE, SPINE_D, PAGE, PAGE_D, GOLD = (110, 70, 44), (70, 42, 28), (220, 206, 170), (160, 140, 110), (210, 170, 80)
    cv = Canvas(ROCK[1])
    cv.fill(lambda x, y: ramp(x, y, 0.3 + 0.4 * prand(x // 3, y // 3, 2), ROCK))
    # barnacles: little rings
    for (bx, by, r) in ((10, 66, 3), (22, 70, 2.5), (40, 64, 2.2), (46, 72, 3), (6, 52, 2), (34, 72, 2)):
        cv.ellipse(bx, by, r, r * 0.8, lambda x, y, u, v, rr: ROCK[3] if rr > 0.55 else (ROCK[0] if rr < 0.25 else ROCK[2]))
    # the book, seen from above at an angle
    cover = [(12, 24), (38, 20), (46, 52), (20, 57)]
    pages = [(20, 57), (46, 52), (46, 55), (20, 60)]
    spine = [(9, 26), (12, 24), (20, 57), (17, 60)]
    cv.poly(pages, lambda x, y: PAGE if (y + x // 3) % 2 else PAGE_D, "book")
    cv.poly(spine, lambda x, y: SPINE if (y // 5) % 2 else SPINE_D, "book")
    cv.poly(cover, lambda x, y: ramp(x, y, 0.3 + 0.5 * (1 - (y - 20) / 40), [COVER[2], COVER[1], COVER[0]]), "book")
    # embossed sea-creature sigil on the cover: glowing swirl
    for k in range(40):
        t = k / 39
        a = t * math.pi * 3
        r = 2 + 7 * t
        cv.set(29 + math.cos(a) * r * 0.8, 38 + math.sin(a) * r * 0.7, COVER[0] if k % 3 else (200, 255, 240))
    cv.outline({"book"}, COVER[3])
    for y in range(24, 58, 8):                   # spine bands
        cv.set(11 + (y - 24) * 8 // 33, y, GOLD); cv.set(12 + (y - 24) * 8 // 33, y, GOLD)
    return cv


# --------------------------------------------------------------- えら呼吸 gill_breathing
SWIMMER = [
    "....OO.......",
    "...OssO......",
    "...OssOO.....",
    "....OsssO....",
    ".....OsssO...",
    ".....OssssO..",
    "......OsssO..",
    "......OsssO..",
    "......OssssO.",
    ".......OsssO.",
    ".......OsOssO",
    "......OsO.OsO",
    ".....OsO..OsO",
    "....OsO...OsO",
    "...OsO.....OO",
    "...OO........",
]


def gill_breathing():
    WATER = [(4, 18, 26), (8, 34, 44), (18, 62, 72), (50, 110, 116), (140, 200, 190)]
    cv = Canvas(WATER[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - y / 70), WATER[:4]))
    # god rays from the surface (upper left) slanting down-right
    for k, (x0, w) in enumerate(((6, 3), (16, 2), (24, 4), (34, 2), (42, 3))):
        for y in range(0, 70):
            xs = x0 + y * 0.35
            for x in range(int(xs), int(xs + w)):
                if dither(x, y, 0.22 - y / 300) and (y // 2) % 2 == 0:
                    cv.set(x, y, WATER[3] if y > 20 else WATER[4])
    # surface ripples at the top
    for x in range(W):
        if (x + (x // 5)) % 3:
            cv.set(x, 0, WATER[4]); cv.set(x, 1, WATER[3] if x % 2 else WATER[4])
    # diver, head first, descending to the lower right (drawn with thick limbs)
    BODY, BODY_D, RIM = (60, 104, 110), (30, 58, 64), (140, 190, 186)
    L = lambda x0, y0, x1, y1, w, c=BODY: cv.line(x0, y0, x1, y1, c, "swim", width=w)
    L(10, 17, 17, 27, 2)                     # arms reaching forward
    L(13, 16, 19, 26, 2)
    L(17, 26, 29, 45, 4); L(18, 26, 30, 45, 4)   # torso
    L(29, 44, 35, 62, 3); L(31, 44, 41, 58, 3)   # legs
    L(35, 62, 36, 66, 2, BODY_D); L(41, 58, 44, 61, 2, BODY_D)   # feet
    cv.ellipse(18, 23.5, 2.6, 2.6, flat(BODY), "swim")          # head
    cv.outline_outside({"swim"}, (6, 18, 24))
    for (x, y) in ((19, 21), (20, 22), (22, 29), (24, 32), (26, 35), (28, 38), (30, 41), (33, 48), (36, 52)):
        cv.set(x, y, RIM)
    for k in range(6):                       # hair streaming back
        cv.set(20 + k, 20 + k // 2, (40, 70, 76))
    # bubbles rising from the mouth
    for (x, y) in ((16, 20), (17, 15), (15, 10), (16, 6)):
        cv.set(x, y, WATER[4])
    return cv


# ------------------------------------------------------------ 母の抱擁 mothers_embrace
HEAD = [
    "..OOOO..",
    ".OmmmmO.",
    "OmhmmhmO",
    "OmemmemO",
    "OmmmmmmO",
    ".OmmmmO.",
]


def mothers_embrace():
    BG = [(8, 18, 34), (14, 32, 52), (24, 52, 72)]
    SKIN = ((150, 190, 130), (100, 150, 100), (60, 104, 74), (30, 56, 44))
    FIN = (220, 170, 90)
    ORB = [(255, 250, 220), (250, 220, 140), (200, 170, 90), (120, 110, 70)]
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - y / 80) * 0.9, BG))
    cx, cy = 26.5, 42
    # round body below, with coiled necks rising
    cv.ellipse(cx, cy + 9, 12, 9, shade(SKIN), "body")
    heads = [(cx - 12, cy - 4), (cx - 5, cy - 14), (cx + 5, cy - 14), (cx + 12, cy - 4), (cx + 9, cy + 6)]
    for (hx, hy) in heads:
        cv.line(cx + (hx - cx) * 0.3, cy + 6, hx, hy + 3, SKIN[1], "body", width=4)
    for (hx, hy) in heads:
        cv.sprite(HEAD, int(hx) - 4, int(hy) - 3, {"O": SKIN[3], "m": SKIN[1], "h": SKIN[0], "e": (20, 30, 24)}, "body")
        cv.set(hx - 1, hy - 4, FIN); cv.set(hx + 1, hy - 4, FIN); cv.set(hx, hy - 5, FIN)
    # glowing orb held in the middle
    cv.ellipse(cx, cy + 1, 7, 7, lambda x, y, u, v, r: (ORB[3] if dither(x, y, 0.5) else None) if r > 0.5 else None)
    cv.ellipse(cx, cy + 1, 3.5, 3.5, lambda x, y, u, v, r: ORB[0] if r < 0.35 else (ORB[1] if r < 0.7 else ORB[2]))
    # fin ridge along the body
    for x in range(int(cx - 10), int(cx + 11), 3):
        cv.set(x, cy + 18, FIN)
    return cv


# ------------------------------------------------------------------------ 鱗 scales
def scales():
    TEAL = ((90, 170, 160), (40, 110, 110), (22, 66, 70), (8, 28, 32))
    PEARL = ((250, 248, 236), (206, 204, 190), (140, 140, 130), (60, 60, 60))
    cv = Canvas(TEAL[3])
    for y in range(H):
        for x in range(W):
            u, v, sid = scale_cell(x, y, 8, rot=-0.35)
            # a diagonal band of pale, silvery scales through the middle
            band = abs((x - 0.6 * y) - (-10)) < 14 + 3 * math.sin(y * 0.2)
            tones = PEARL if band else TEAL
            cv.set(x, y, scale_color(x, y, u, v, tones, sid, sparkle=(255, 255, 255) if band else (160, 230, 220), seed=3))
    return cv


# ---------------------------------------------------------------------- 海契約 sea_pact
def sea_pact():
    SKY = [(10, 14, 26), (20, 28, 44)]
    WAVE = [(20, 34, 56), (40, 64, 90), (90, 120, 140), (220, 234, 240)]
    ROCK = [(20, 22, 26), (30, 32, 38), (42, 44, 50)]
    RUNE, RUNE_D = (140, 240, 220), (40, 110, 104)
    STEEL = ((200, 210, 216), (130, 140, 150), (70, 76, 86))
    cv = Canvas(SKY[0])
    shore = 34
    def bg(x, y):
        if y < 14:
            return ramp(x, y, y / 14, SKY)
        if y < shore:
            for k, base in enumerate((17, 23, 29)):
                crest = base + 1.6 * math.sin(x * 0.35 + k * 2.1) + math.sin(x * 0.9 + k)
                if 0 <= y - crest < 1.0:
                    return WAVE[3]
                if 1.0 <= y - crest < 2.2 and dither(x, y, 0.5):
                    return WAVE[2]
            if y > shore - 3 and prand(x, y, 5) < 0.5:
                return WAVE[3]
            return ramp(x, y, 0.2 + 0.3 * ((y - 14) / 20), WAVE[:3])
        return ramp(x, y, 0.4 + 0.5 * prand(x // 3, y // 2, 7), ROCK)
    cv.fill(bg)
    # rune circle on the ground (ellipse because of perspective)
    cx, cy = 26.5, 52
    for rx, ry in ((20, 9), (15, 6.8)):
        cv.ellipse(cx, cy, rx, ry, lambda x, y, u, v, r: RUNE if r > 0.88 else None)
    cv.ellipse(cx, cy, 17.5, 7.9, lambda x, y, u, v, r: (RUNE_D if (x * 3 + y) % 5 == 0 else None) if 0.72 < r < 0.95 else None)
    for k in range(8):                                # spokes
        a = k * math.pi / 4
        cv.line(cx + math.cos(a) * 4, cy + math.sin(a) * 1.8, cx + math.cos(a) * 14, cy + math.sin(a) * 6.3, RUNE_D)
    # trident stuck into the centre
    for y in range(18, 53):
        cv.set(26, y, STEEL[1]); cv.set(27, y, STEEL[2])
    for x in range(20, 34):
        cv.set(x, 22, STEEL[1])
    for px in (20, 26, 33):
        for y in range(12, 22):
            cv.set(px, y, STEEL[0] if px != 33 else STEEL[1])
        cv.set(px, 11, STEEL[0]); cv.set(px - 1, 13, STEEL[1]); cv.set(px + 1, 13, STEEL[1])
    cv.set(26, 53, RUNE)
    return cv


# ----------------------------------------------------------------------- 触手 tentacle
def tentacle():
    WATER = [(6, 14, 16), (12, 28, 30), (22, 46, 46), (40, 70, 66)]
    SKIN = ((140, 190, 150), (90, 150, 116), (54, 104, 84), (24, 54, 46))
    SUCK, SUCK_D = (200, 230, 190), (70, 110, 90)
    FOAM = [(230, 240, 230), (160, 190, 180)]
    cv = Canvas(WATER[0])
    surface = 60
    cv.fill(lambda x, y: ramp(x, y, 0.25 if y < surface else 0.5 + 0.4 * ((y + x // 4) % 3 == 0), WATER))
    # S-shaped tentacle: centre line points, thickness tapering to the tip
    pts = []
    for i in range(80):
        t = i / 79
        x = 26 + 11 * math.sin(t * math.pi * 1.5 + 0.2) * (0.5 + 0.5 * t)
        y = surface + 3 - t * 50
        pts.append((x, y, 8.5 * (1 - t) ** 0.9 + 1.0))
    for (x, y, r) in pts:
        cv.ellipse(x, y, r, r, shade(SKIN, rim=0.8), "tent")
    cv.outline({"tent"}, SKIN[3])
    # suckers along the inner side
    for i in range(6, 70, 7):
        x, y, r = pts[i]
        side = 1 if math.cos(i / 79 * math.pi * 1.6 + 0.3) > 0 else -1
        sx, sy = x + side * r * 0.5, y
        cv.ellipse(sx, sy, max(1.2, r * 0.3), max(1.2, r * 0.3), lambda xx, yy, u, v, rr: SUCK_D if rr < 0.4 else SUCK)
    # splash where it breaks the surface
    for k in range(18):
        ang = math.pi * (0.05 + 0.9 * prand(k, 0, 4))
        ln = 3 + 6 * prand(k, 1, 4)
        for s in range(int(ln)):
            cv.set(29 + math.cos(ang) * (9 + s * 1.2), surface - math.sin(ang) * s, FOAM[0] if s % 2 else FOAM[1])
    for x in range(14, 44):
        if prand(x, 0, 6) < 0.6:
            cv.set(x, surface, FOAM[1])
    return cv


ARTS = {
    "adapted_scales": (adapted_scales, 10),
    "apocrypha": (apocrypha, 12),
    "gill_breathing": (gill_breathing, 4),
    "mothers_embrace": (mothers_embrace, 13),
    "scales": (scales, 10),
    "sea_pact": (sea_pact, 6),
    "tentacle": (tentacle, 8),
}
