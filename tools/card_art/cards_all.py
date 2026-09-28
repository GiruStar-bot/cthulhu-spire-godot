"""All-pack card illustrations (53x80 board, 53x59 output window)."""
import math
from pxlib import W, H, Canvas, prand, dither, ramp, shade, flat

SPACE = [(8, 6, 22), (18, 14, 44), (34, 24, 70)]
PRISM = [(255, 90, 110), (255, 170, 70), (250, 240, 110), (110, 230, 150), (90, 180, 255), (170, 110, 255)]


def space_bg(cv, seed=1):
    cv.fill(lambda x, y: ramp(x, y, 0.3 * prand(x // 6, y // 6, seed) + 0.2 * math.sin(x * 0.1 + y * 0.07), SPACE))
    for k in range(40):
        x, y = int(prand(k, 0, seed + 9) * W), int(prand(k, 1, seed + 9) * H)
        cv.set(x, y, (255, 255, 255) if k % 3 == 0 else (170, 160, 220))


# ---------------------------------------------------------------------- 崩壊 collapse
def collapse():
    cv = Canvas(SPACE[0])
    space_bg(cv, 2)
    cx, cy = 26.5, 40
    # rainbow shards bursting out of a white core
    for k in range(48):
        a = k / 48 * math.pi * 2 + prand(k, 0, 3) * 0.1
        ln = 12 + 18 * prand(k, 1, 3)
        col = PRISM[k % len(PRISM)]
        for s in range(int(ln)):
            w = max(0, int(2.5 * (1 - s / ln)))
            x, y = cx + math.cos(a) * s, cy + math.sin(a) * s * 1.05
            for j in range(-w, w + 1):
                cv.set(x - math.sin(a) * j * 0.6, y + math.cos(a) * j * 0.6, col if s > 4 else (255, 250, 240))
    cv.ellipse(cx, cy, 5, 5, lambda x, y, u, v, r: (255, 255, 255) if r < 0.5 else (255, 240, 200))
    for k in range(20):                                          # flying specks
        a = prand(k, 2, 3) * math.pi * 2
        d = 18 + 10 * prand(k, 3, 3)
        cv.set(cx + math.cos(a) * d, cy + math.sin(a) * d, PRISM[k % 6])
    return cv


# --------------------------------------------------------------------- 全能 omnipotence
def omnipotence():
    SKIN = [(60, 50, 70), (90, 76, 100), (130, 114, 140)]
    cv = Canvas(SPACE[0])
    space_bg(cv, 3)
    cx, cy = 26.5, 40
    # eyelids / lashes: dark almond around the eye
    for y in range(int(cy - 14), int(cy + 15)):
        for x in range(W):
            u = (x + 0.5 - cx) / 26
            if abs(u) >= 1:
                continue
            h = 12 * (1 - u * u)
            d = abs(y + 0.5 - cy)
            if d < h + 3 and d >= h:
                cv.set(x, y, SKIN[0] if d < h + 1.5 else SKIN[1])
            elif d < h:
                cv.set(x, y, (236, 230, 236) if d < h - 1.5 else (190, 180, 200), "white")
    for k in range(-24, 25, 3):                                  # lashes
        u = k / 26
        h = 12 * (1 - u * u) + 3
        cv.line(cx + k, cy - h, cx + k * 1.1, cy - h - 3, (20, 14, 26))
    # iris: swirling cosmic colours, dark pupil
    def iris(x, y, u, v, r):
        if cv.owner(x, y) != "white":
            return None
        a = math.atan2(v, u)
        k = int((a / (math.pi * 2) + 0.5) * 12 + r * 6) % 6
        c = PRISM[k]
        if r > 0.82:
            return (60, 30, 90)
        return c if dither(x, y, 0.6) else (120, 80, 180)
    cv.ellipse(cx, cy, 11, 11, iris)
    cv.ellipse(cx, cy, 4.5, 4.5, lambda x, y, u, v, r: (6, 4, 14) if r < 0.8 else (60, 30, 90))
    cv.set(cx - 3, cy - 3, (255, 255, 255)); cv.set(cx - 2, cy - 3, (255, 255, 255)); cv.set(cx - 3, cy - 2, (255, 255, 255))
    cv.set(cx + 2, cy + 2, (230, 230, 255))
    return cv


# -------------------------------------------------------------------- 銀の鍵 silver_key
def silver_key():
    V = [(20, 10, 34), (40, 20, 64), (70, 36, 110), (110, 60, 160)]
    SIL = ((250, 250, 255), (200, 204, 220), (140, 144, 170), (60, 60, 84))
    cv = Canvas(V[0])

    def bg(x, y):
        s = math.sin((x - 26.5) * 0.12 + math.sin(y * 0.08) * 2 + y * 0.05)
        return ramp(x, y, (s + 1) / 2 * 0.8, V)
    cv.fill(bg)
    # iridescent streaks sweeping diagonally
    for k, off in enumerate((-18, 20, 38)):
        for y in range(H):
            x0 = off + y * 0.55 + 4 * math.sin(y * 0.1 + k)
            for j in range(4):
                if dither(int(x0 + j), y, 0.7):
                    cv.set(x0 + j, y, PRISM[(y // 3 + j + k) % 6])
    # the key: ornate bow at top, shaft, bit at the bottom
    cx = 26.5
    cv.ellipse(cx, 22, 7, 7, lambda x, y, u, v, r: SIL[1] if r > 0.45 else None, "key")
    cv.ellipse(cx, 22, 2.2, 2.2, flat(SIL[1]), "key")
    for (dx, dy) in ((-7, 0), (7, 0), (0, -7)):
        cv.ellipse(cx + dx, 22 + dy, 2.2, 2.2, lambda x, y, u, v, r: SIL[1] if r > 0.3 else None, "key")
    for y in range(29, 62):
        cv.set(cx - 1, y, SIL[1], "key"); cv.set(cx, y, SIL[0], "key"); cv.set(cx + 1, y, SIL[2], "key")
    for y in range(31, 35):
        for x in range(int(cx) - 2, int(cx) + 3):
            cv.set(x, y, SIL[1], "key")
    cv.poly([(cx + 1, 52), (cx + 8, 52), (cx + 8, 61), (cx + 1, 61)], lambda x, y: SIL[2] if (x + y) % 4 == 0 else SIL[1], "key")
    for (x, y) in ((cx + 4, 54), (cx + 4, 55), (cx + 6, 58), (cx + 3, 58)):
        cv.set(x, y, SIL[3])
    cv.outline_outside({"key"}, SIL[3])
    return cv


# ------------------------------------------------------------------ 超越者 transcendent
def transcendent():
    GLOW = [(255, 255, 240), (255, 236, 190), (240, 200, 140), (170, 130, 110), (80, 60, 80)]
    cv = Canvas(SPACE[0])
    space_bg(cv, 5)
    cx = 26.5
    # radiant humanoid, arms spread and slightly lowered
    L = lambda a, b, c, d, w: cv.line(a, b, c, d, GLOW[1], "body", width=w)
    cv.ellipse(cx, 16, 3.5, 4, flat(GLOW[1]), "body")                      # head
    cv.poly([(cx - 6, 22), (cx + 6, 22), (cx + 4, 42), (cx - 4, 42)], flat(GLOW[1]), "body")   # torso
    L(cx - 5, 23, cx - 17, 34, 2); L(cx - 17, 34, cx - 23, 38, 2)          # arms
    L(cx + 5, 23, cx + 17, 34, 2); L(cx + 17, 34, cx + 23, 38, 2)
    L(cx - 3, 42, cx - 4, 68, 3); L(cx + 2, 42, cx + 3, 68, 3)            # legs
    # inner core brighter
    for y in range(14, 60):
        cv.set(cx, y, GLOW[0])
    cv.ellipse(cx, 15, 2, 2, flat((220, 200, 230)))                        # the brain glowing inside
    cv.glow({"body"}, [GLOW[2], GLOW[3], GLOW[4], None], 5)
    return cv


ARTS = {
    "collapse": (collapse, 11),
    "omnipotence": (omnipotence, 11),
    "silver_key": (silver_key, 10),
    "transcendent": (transcendent, 8),
}
