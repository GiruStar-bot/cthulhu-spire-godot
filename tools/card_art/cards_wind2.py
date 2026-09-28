"""Wind-pack redraws (v2): 砂漠 / 黄衣の王 / 風神の弓 / 黄色のコイン.
Drawn from the card's theme rather than traced from the old art.
"""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat

YEL = ((255, 232, 120), (238, 192, 56), (184, 134, 34), (104, 72, 22))


def emboss(cv, owner, hi, mid, lo):
    """Raised relief: light on the top-left edge, shadow on the bottom-right edge."""
    cells = [(x, y) for y in range(H) for x in range(W) if cv.owner(x, y) == owner]
    for x, y in cells:
        tl = cv.owner(x - 1, y) != owner or cv.owner(x, y - 1) != owner
        br = cv.owner(x + 1, y) != owner or cv.owner(x, y + 1) != owner
        cv.px[y][x] = lo if br and not tl else (hi if tl and not br else mid)


# ------------------------------------------------------------------------- 砂漠 desert
def desert():
    """Dunes rendered from a height field (gentle windward slopes, steep lee faces),
    shaded by the sun from the upper left, with wind ripples on the sunlit sand."""
    SKY = [(252, 242, 212), (248, 226, 184), (238, 208, 156)]
    SAND = [(96, 52, 30), (140, 80, 44), (186, 120, 66), (224, 164, 98), (246, 200, 136), (255, 226, 172)]
    cv = Canvas(SKY[0])
    cv.fill(lambda x, y: ramp(x, y, y / 44, SKY))
    cv.ellipse(40, 14, 4.5, 4.5, lambda x, y, u, v, r: (255, 252, 236) if r < 0.55 else ((255, 244, 214) if dither(x, y, 0.5) else None))

    def ridge(x, crest, amp, lw, ll):
        d = x - crest
        if d < 0:
            return amp * max(0.0, 1 + d / lw) ** 1.6
        return amp * max(0.0, 1 - d / ll) ** 1.1

    def height(x, z):
        h = ridge(x, 18 + 9 * math.sin(z * 0.06) + z * 0.2, 7, 22, 6)
        h = max(h, ridge(x, 42 + 6 * math.sin(z * 0.08 + 1.3) - z * 0.1, 5, 16, 5))
        h = max(h, ridge(x, 30 + 12 * math.sin(z * 0.04 + 2), 3, 14, 4))
        return h + 0.6 * math.sin(x * 0.4 + z * 0.3)

    horizon, depth = 30, 70
    ybuf = [H] * W
    for zi in range(depth, -1, -1):                   # near to far, keep the highest drawn row per column
        z = zi
        base = horizon + z * 0.72
        for x in range(W):
            h = height(x, z)
            sy = int(base - h * 0.9)
            if sy >= ybuf[x]:
                continue
            # slope shading
            dhx = height(x + 1, z) - height(x - 1, z)
            dhz = height(x, z + 1) - height(x, z - 1)
            lum = 0.5 + 0.14 * dhx + 0.04 * dhz
            if lum > 0.45:
                # ripples on the sunlit side, curving with the dune
                if math.sin(x * 0.55 + z * 1.3 + h * 0.5) > 0.82:
                    lum -= 0.18
            lum -= (1 - z / depth) * 0.0
            t = max(0.0, min(0.999, lum))
            c = SAND[int(t * len(SAND))]
            if z > depth - 25:                          # distance haze
                c = tuple(int(cc * 0.7 + s * 0.3) for cc, s in zip(c, SKY[2]))
            for y in range(max(0, sy), ybuf[x]):
                cv.set(x, y, c)
            ybuf[x] = sy
    # small yellow pennant planted on the big dune's crest
    px, py = 20, None
    for y in range(H):
        if cv.get(px, y) != cv.get(px, 0) and y > horizon - 10:
            py = y
            break
    py = py or 40
    for y in range(py - 10, py + 1):
        cv.set(px, y, (70, 46, 28))
    for i in range(8):
        for d in range(max(1, 4 - i // 2)):
            cv.set(px + 1 + i, py - 10 + int(math.sin(i * 0.8)) + d, YEL[0] if d == 0 else YEL[1])
    # sand blowing off the crest
    for k in range(8):
        x0, y0 = px + 2 + int(prand(k, 0, 5) * 12), py + 1 + int(prand(k, 1, 5) * 8)
        for s_ in range(3):
            if (s_ + k) % 2 == 0:
                cv.set(x0 + s_, y0 - s_ // 2, SAND[5])
    return cv


# ------------------------------------------------------------------- 黄衣の王 king_in_yellow
def king_in_yellow():
    BG = [(16, 10, 8), (30, 20, 14), (52, 36, 18)]
    LEATHER = ((120, 44, 40), (92, 30, 30), (64, 20, 22), (34, 10, 12))
    GOLD = ((236, 200, 110), (180, 140, 60))
    PAGES = ((236, 222, 188), (196, 178, 142), (150, 130, 100))
    MASK = ((255, 236, 150), (240, 196, 72), (196, 144, 40), (130, 84, 22), (70, 42, 14))
    cv = Canvas(BG[0])
    cv.fill(lambda x, y: ramp(x, y, max(0, 1 - math.hypot((x - 27) / 30, (y - 34) / 26)) * 0.9, BG))

    # thick closed book, seen from above-front: cover (top face), front edge of pages, spine at left
    cover = [(5, 48), (44, 44), (50, 58), (10, 63)]
    pages = [(10, 63), (50, 58), (50, 64), (10, 69)]
    spine = [(3, 50), (5, 48), (10, 63), (10, 69), (8, 70), (3, 56)]
    cv.poly(pages, lambda x, y: PAGES[0] if (y - int((x - 10) * -0.12)) % 2 else PAGES[1], "book")
    cv.poly(spine, lambda x, y: LEATHER[2] if (y // 3) % 2 else LEATHER[3], "book")
    cv.poly(cover, lambda x, y: LEATHER[0] if x + (y - 44) * 1.2 < 30 else LEATHER[1], "book")
    cv.outline({"book"}, LEATHER[3])
    for x in range(11, 50):                                         # front board edge under the cover
        y = int(63 - (x - 10) * 0.125)
        cv.set(x, y, LEATHER[2])
    for (x, y) in ((8, 49), (9, 50), (43, 45), (42, 46), (46, 56), (47, 55), (13, 61), (12, 60)):   # gilt corner pieces
        cv.set(x, y, GOLD[0])
    for x in range(12, 46, 2):                                      # gilt border line on the cover
        cv.set(x, int(49 - (x - 5) * 0.1), GOLD[1])
    # the pale yellow mask lying on the book, tilted, with its own shadow on the cover
    cv.ellipse(30, 47, 11, 6, lambda x, y, u, v, r: LEATHER[3] if dither(x, y, 0.8) else None)
    cv.ellipse(27, 38, 10.5, 13, shade((MASK[0], MASK[1], MASK[2], MASK[3]), rim=0.82), "mask")
    cv.outline({"mask"}, MASK[4])
    E = (20, 10, 6)
    for (ex, ey) in ((22.5, 34), (31.5, 34)):                      # hollow eye holes
        cv.ellipse(ex, ey, 3, 1.8, lambda x, y, u, v, r: E if r < 0.7 else MASK[3])
    cv.line(27, 33, 26, 41, MASK[2]); cv.line(26, 41, 28, 42, MASK[3])   # nose ridge
    cv.set(28, 36, MASK[0]); cv.set(28, 37, MASK[0])
    for x in range(23, 32):                                          # thin expressionless mouth
        cv.set(x, 45, MASK[4] if 24 < x < 30 else MASK[3])
    cv.line(20, 27, 23, 31, MASK[4]); cv.line(23, 31, 22, 33, MASK[4])  # hairline crack
    for (x, y) in ((20, 30), (19, 36), (21, 42)):                    # glints
        cv.set(x, y, MASK[0])
    return cv


# ------------------------------------------------------------------- 風神の弓 wind_gods_bow
def wind_gods_bow():
    SKY = [(70, 86, 100), (96, 114, 124), (130, 146, 150)]
    BONE = ((252, 248, 236), (218, 210, 190), (160, 150, 128), (70, 62, 50))
    GOLD = ((250, 214, 110), (190, 144, 50), (110, 76, 26))
    WINDC = ((240, 252, 255), (176, 222, 236), (110, 170, 196))
    SHAFT = ((200, 150, 90), (150, 104, 60), (96, 62, 36))
    cv = Canvas(SKY[0])
    cv.fill(lambda x, y: ramp(x, y, 0.3 + 0.35 * math.sin(x * 0.08 + y * 0.05) + 0.2 * (y / 80), SKY))
    for k in range(6):                                                # background wind streaks
        y = 12 + k * 11
        for s in range(18):
            if s % 5 < 3:
                cv.set(2 + k * 3 + s, y + int(2 * math.sin(s * 0.3)), SKY[2])

    # --- bow: thick bone limbs curving from top to bottom, grip in the middle
    arc = []
    for i in range(80):
        t = i / 79
        x = 14 + 12 * math.sin(t * math.pi) - 2 * math.sin(t * math.pi * 2)
        y = 8 + 64 * t
        arc.append((x, y))
    for (x, y) in arc:
        for k in range(-1, 3):
            cv.set(x + k, y, BONE[0] if k == -1 else (BONE[1] if k < 2 else BONE[2]), "bow")
    cv.outline_outside({"bow"}, BONE[3])
    for (x, y) in (arc[0], arc[-1]):                                 # gold tips
        for k in range(-1, 3):
            cv.set(x + k, y, GOLD[0] if k < 1 else GOLD[1])
        cv.set(x - 2, y + (1 if y < 40 else -1), GOLD[1])
    gx, gy = arc[40]
    for y in range(int(gy) - 4, int(gy) + 5):                         # leather-bound grip
        for k in range(-1, 3):
            cv.set(gx + k, y, SHAFT[2] if (y + k) % 2 else SHAFT[1])
    # string
    cv.line(arc[0][0] + 1, arc[0][1], 32, 40, (230, 226, 210))
    cv.line(32, 40, arc[-1][0] + 1, arc[-1][1], (230, 226, 210))

    # --- ribbons wound around both limbs: diagonal wraps + a streaming tail
    def wraps(i0, i1, tail):
        # a ribbon spiralling round the limb: visible where it passes in front
        for i in range(i0, i1):
            x, y = arc[i]
            ph = (i - i0) / 5.0 * math.pi
            if math.sin(ph) > -0.1:
                shade_c = YEL[0] if math.cos(ph) > 0 else YEL[1]
                for k in range(-2, 4):
                    cv.set(x + k, y + (k - 1) * 0.35, shade_c)
                cv.set(x + 4, y + 1, YEL[3]); cv.set(x - 3, y - 1, YEL[3])
        x, y = arc[i1]
        for j, (dx, dy) in enumerate(tail):                           # loose ends streaming in the wind
            for w in range(3):
                cv.set(x + dx, y + dy + w, YEL[0] if w == 0 else (YEL[1] if (j // 3) % 2 == 0 else YEL[2]))
            cv.set(x + dx, y + dy + 3, YEL[3])
    tail_up = [(-1 - j, -1 - int(3.5 * math.sin(j * 0.4)) - j // 4) for j in range(17)]
    tail_dn = [(-1 - j, 1 + int(3.5 * math.sin(j * 0.4)) + j // 5) for j in range(15)]
    wraps(8, 30, tail_up)
    wraps(52, 72, tail_dn)

    # --- the arrow: thick shaft, steel head, fletching, nocked on the string
    ax0, ay0, ax1, ay1 = 32, 40, 50, 30          # nock -> tip, drawn across the bow
    for t in range(0, 101):
        f = t / 100
        x = ax0 - 14 + (ax1 - ax0 + 14) * f
        y = ay0 + 7 + (ay1 - ay0 - 7) * f
        cv.set(x, y, SHAFT[0], "arrow"); cv.set(x, y + 1, SHAFT[1], "arrow"); cv.set(x, y + 2, SHAFT[2], "arrow")
    hx, hy = ax1, ay1
    cv.poly([(hx - 1, hy - 3), (hx + 4, hy + 1), (hx - 1, hy + 5)], lambda x, y: BONE[0] if y < hy + 1 else BONE[2], "arrow")
    fx, fy = ax0 - 14, ay0 + 7
    for k in range(5):                                               # fletching
        cv.set(fx + k, fy - 2 + k // 3, (200, 60, 60)); cv.set(fx + k, fy + 4 - k // 3, (200, 60, 60))
        cv.set(fx + k, fy - 1 + k // 3, (150, 30, 40)); cv.set(fx + k, fy + 3 - k // 3, (150, 30, 40))
    cv.outline_outside({"arrow"}, (40, 30, 26))
    # wind coiling around the arrow: a spiral ribbon of air along the shaft
    for i in range(60):
        f = i / 59
        x = ax0 - 12 + (ax1 - ax0 + 10) * f
        y = ay0 + 7 + (ay1 - ay0 - 7) * f + 1
        ph = f * math.pi * 6
        off = 5.5 * math.sin(ph)
        front = math.cos(ph) > 0
        c = WINDC[0] if front else WINDC[2]
        if front or i % 2:
            cv.set(x, y + off, c); cv.set(x, y + off + 1, WINDC[1] if front else WINDC[2])
            if front:
                cv.set(x + 1, y + off, WINDC[1])
    for k in range(4):                                               # streaks trailing behind the arrow
        for s_ in range(6):
            cv.set(ax0 - 16 - s_ - k, ay0 + 5 + k * 2 + s_ // 3, WINDC[1] if s_ % 2 == 0 else None)
    for (x, y) in ((53, 28), (52, 33), (54, 31)):                   # air bursting past the tip
        cv.set(x, y, WINDC[0])
    return cv


# ------------------------------------------------------------------- 黄色のコイン yellow_coin
def yellow_coin():
    CLOTH = [(16, 20, 34), (26, 32, 50), (40, 48, 70), (58, 68, 92)]
    G = ((255, 238, 170), (236, 196, 96), (196, 150, 60), (140, 98, 36), (80, 52, 20))
    cv = Canvas(CLOTH[0])
    cv.fill(lambda x, y: ramp(x, y, 0.3 + 0.3 * math.sin(x * 0.2 + y * 0.13) + 0.2 * math.sin(y * 0.45 - x * 0.05), CLOTH))
    cx, cy, R = 26.5, 40, 20
    cv.ellipse(cx + 2, cy + 2.5, R, R, flat((8, 10, 18)))            # drop shadow

    def coin(x, y, u, v, r):
        d = math.sqrt(r)
        lit = -(u * 0.6 + v * 0.8)                                    # facing the light (top-left)
        if d > 0.94:
            return G[4]
        if d > 0.8:                                                   # raised, bevelled rim
            return G[0] if lit > 0.35 else (G[1] if lit > -0.2 else G[3])
        if d > 0.76:                                                  # groove inside the rim
            return G[3] if lit > 0 else G[1]
        # sunken field: slightly darker, faint concentric turning marks
        c = G[2] if lit > -0.3 else G[3]
        if int(d * 40) % 7 == 0 and 0.3 < d < 0.72 and lit < 0:
            c = G[3]
        return c
    cv.ellipse(cx, cy, R, R, coin, "coin")
    # ring of beads just inside the groove
    for k in range(36):
        a = k / 36 * math.pi * 2
        x, y = cx + math.cos(a) * R * 0.7, cy + math.sin(a) * R * 0.7
        cv.set(x, y, G[1] if math.cos(a) + math.sin(a) < 0 else G[3])
    # embossed royal crest: a five-point crown with gems over a laurel wreath
    CROWN = [
        "x....x....x....x....x",
        "x....x....x....x....x",
        "xx..xxx..xxx..xxx..xx",
        "xxx.xxx.xxxxx.xxx.xxx",
        "xxxxxxxxxxxxxxxxxxxxx",
        "xxxxxxxxxxxxxxxxxxxxx",
        "xxxxxxxxxxxxxxxxxxxxx",
        "xxxxxxxxxxxxxxxxxxxxx",
        ".....................",
        "xxxxxxxxxxxxxxxxxxxxx",
        "xxxxxxxxxxxxxxxxxxxxx",
    ]
    left, top = int(cx) - 10, int(cy) - 9
    for j, row in enumerate(CROWN):
        for i, ch in enumerate(row):
            if ch == "x":
                cv.set(left + i, top + j, G[1], "sign")
    # laurel branches curving up both sides below the crown
    for side in (-1, 1):
        for k in range(9):
            a = math.radians(100 + k * 11)
            lx = cx + side * math.cos(a) * -13.5
            ly = cy + 5 + math.sin(a) * 9.5 - k * 0.6
            cv.set(lx, ly, G[1], "sign")
            if k % 2 == 0:
                cv.set(lx + side, ly - 1, G[1], "sign"); cv.set(lx + side * 2, ly - 1, G[1], "sign")
            else:
                cv.set(lx - side, ly - 1, G[1], "sign")
    emboss(cv, "sign", G[0], G[1], G[4])
    # engraved details on top of the relief: band line, gems, arches
    for gx in (left + 5, left + 10, left + 15):
        cv.set(gx, top + 5, (210, 60, 50)); cv.set(gx, top + 6, (130, 30, 30))
    for gx in (left, left + 5, left + 10, left + 15, left + 20):
        cv.set(gx, top, G[0])
    for x in range(left + 1, left + 20, 2):
        cv.set(x, top + 10, G[3])
    # tiny legend dots arcing over the top, like engraved lettering
    for k in range(9):
        a = math.pi * (1.2 + 0.07 * k)
        cv.set(cx + math.cos(a) * 12.5, cy + math.sin(a) * 12.5, G[4] if k % 2 else G[3])
    # a glint on the rim
    for (x, y) in ((cx - 12, cy - 13), (cx - 11, cy - 14), (cx - 13, cy - 12), (cx - 12, cy - 15), (cx - 15, cy - 12)):
        cv.set(x, y, (255, 255, 240))
    return cv


ARTS = {
    "desert": (desert, 7),
    "king_in_yellow": (king_in_yellow, 18),
    "wind_gods_bow": (wind_gods_bow, 8),
    "yellow_coin": (yellow_coin, 11),
}
