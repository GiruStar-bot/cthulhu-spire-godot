"""戯神の奉仕 v4 — built from the canonical 戯神ちゃん sprite (jester_def.py).

The card crops her bust 1:1 from the definition sprite (so her proportions match the
standing portrait) and replaces the playing card in her hands with アザくん as a tiny
horned orb.
"""
import math
from pxlib import W, H, Canvas, prand, dither, ramp
import jester_def

V = [(10, 4, 20), (26, 8, 44), (52, 18, 84), (96, 40, 150), (170, 96, 226)]


def jester_gods_service():
    cv = Canvas(V[0])
    cx, cy = 26.5, 38

    def f(x, y):
        dx, dy = x + 0.5 - cx, (y + 0.5 - cy) * 0.8
        d = math.hypot(dx, dy)
        a = math.atan2(dy, dx)
        s = (math.sin(d * 0.4 - a * 2 + 2.3) + 1) / 2
        return ramp(x, y, 0.05 + 0.45 * s ** 2 * min(1, d / 16), V)
    cv.fill(f)
    for k in range(18):
        x, y = int(prand(k, 0, 71) * W), int(prand(k, 1, 71) * 58)
        cv.set(x, y, (230, 190, 255) if k % 3 == 0 else V[3])

    # her, from the definition sprite (top 60 rows = hood to waist), centred
    px, size = jester_def.build()
    left = (W - size[0]) // 2
    for (x, y), c in px.items():
        if y < 60:
            cv.set(left + x, y, c, "her")

    # アザくん as a small orb where the card was, glowing between her hands
    ox, oy = left + 25.5, 37.5
    cv.ellipse(ox, oy, 7, 6.5, lambda x, y, u, v, r: (V[3] if dither(x, y, 0.55 * (1 - r)) and cv.owner(x, y) == "her" else None))

    def orb(x, y, u, v, r):
        if r > 0.78:
            return (232, 112, 222)
        if u < -0.15 and v < -0.2 and r < 0.45:
            return (206, 156, 255)
        return (74, 26, 116) if r > 0.3 else (116, 44, 166)
    cv.ellipse(ox, oy, 3.6, 3.6, orb)
    for (dx, dy) in ((-2, -4), (-3, -5), (2, -4), (3, -5)):       # two tiny horns
        cv.set(ox + dx - 0.5, oy + dy, (246, 128, 214))
    cv.set(ox - 1.5, oy - 1, (255, 240, 255))                     # sparkle
    # her fingertips curling over the lower sides of the orb
    SK = jester_def.SKIN
    for (dx, dy, c) in ((-4, 1, SK[1]), (-4, 2, SK[0]), (-3, 3, SK[1]), (3, 1, SK[1]), (3, 2, SK[1]), (2, 3, SK[2])):
        cv.set(ox + dx, oy + dy, c)
    return cv


ARTS = {"jester_gods_service": (jester_gods_service, 0)}
