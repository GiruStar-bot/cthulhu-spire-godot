"""Outer-god cards built on the canonical アザくん sprite (aza_def.py): he always stays curled
up inside his crystal shell. Azathoth is unimaginably huge, so what surrounds him (stars) is tiny.
"""
import math
from pxlib import W, H, Canvas, prand, dither, ramp
import aza_def

V = [(8, 3, 16), (22, 8, 38), (46, 16, 76), (90, 36, 140), (160, 90, 220)]
SHELL = ((236, 120, 230), (130, 60, 190), (84, 32, 136), (48, 16, 84), (24, 8, 44))
CX, CY = 26.5, 30          # centre of the shell in the 53x59 window


def void(cv, seed=0.0, dark=1.0):
    def f(x, y):
        dx, dy = x + 0.5 - CX, (y + 0.5 - CY) * 0.85
        d = math.hypot(dx, dy)
        a = math.atan2(dy, dx)
        s = (math.sin(d * 0.36 - a * 2 + seed) + 1) / 2
        return ramp(x, y, (0.04 + 0.5 * s ** 2 * min(1, d / 18)) * dark, V)
    cv.fill(f)


def shell(cv, cracked=False):
    """Cracked crystal geode: an irregular ring of shards (2-4 dots thick) around a dark,
    starry hollow; shards lit on their outer face, a thin pink glow along the inner rim."""
    def rim(a):
        # lozenge-ish radius with jagged shard tips
        c, s_ = math.cos(a), math.sin(a)
        base = 1.0 / ((abs(c) / 16.5) ** 1.6 + (abs(s_) / 25.5) ** 1.6) ** (1 / 1.6)
        return base
    n = 64
    for y in range(59):
        for x in range(W):
            dx, dy = x + 0.5 - CX, y + 0.5 - CY
            a = math.atan2(dy, dx)
            d = math.hypot(dx, dy)
            r_in = rim(a)
            shard = int((a + math.pi) / (2 * math.pi) * n)
            thick = 2.2 + 2.2 * prand(shard // 2, 0, 13)
            if r_in - 0.6 <= d <= r_in + thick:
                t = (d - r_in) / thick
                lit = -(dx * 0.5 + dy * 0.85) / max(d, 1)
                c = SHELL[1] if lit > 0.3 else (SHELL[2] if lit > -0.3 else SHELL[3])
                if t < 0.22:
                    c = SHELL[0]                         # inner glowing rim
                elif t > 0.85:
                    c = SHELL[4]
                if shard % 5 == 0 and 0.3 < t < 0.7:
                    c = SHELL[0] if lit > 0 else SHELL[1]  # a facet catching the light
                cv.set(x, y, c, "shell")
            elif d < r_in - 0.6:
                cv.set(x, y, SHELL[4] if prand(x, y, 5) > 0.05 else (230, 180, 255), "hollow")
    for (x, y) in ((CX - 11, CY - 8), (CX + 11, CY + 8), (CX - 10, CY + 13), (CX + 10, CY - 14)):
        cv.set(x, y, (255, 230, 255))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.set(x + dx, y + dy, (180, 110, 240))
    aza_def.paste(cv, int(CX) - 14, int(CY) - 21)
    if cracked:
        for (a0, b0, c0, d0) in ((CX - 17, CY - 10, CX - 12, CY - 5), (CX + 16, CY + 14, CX + 11, CY + 10), (CX + 1, CY - 27, CX + 3, CY - 22)):
            cv.line(a0, b0, c0, d0, (255, 230, 255))


def sparkle(cv, x, y, big=False, col=(255, 240, 255), col2=(200, 150, 255)):
    cv.set(x, y, col)
    arms = 2 if big else 1
    for k in range(1, arms + 1):
        c = col if k == 1 and big else col2
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            cv.set(x + dx, y + dy, c)


# ---------------------------------------------------------------- いびき snore
def snore():
    """White shock waves spreading out from him."""
    cv = Canvas(V[0])
    void(cv, 3.1)
    WAVE = [(255, 255, 255), (220, 210, 240), (150, 130, 200)]
    for (r, strength) in ((23, 1.0), (30, 0.85), (38, 0.6), (47, 0.35)):
        for y in range(59):
            for x in range(W):
                d = math.hypot(x + 0.5 - CX, (y + 0.5 - CY) * 1.0)
                k = abs(d - r)
                if k < 1.1:
                    c = WAVE[0] if strength > 0.55 else WAVE[1]
                    if dither(x, y, strength + 0.2):
                        cv.set(x, y, c)
                elif k < 1.8 and dither(x, y, strength * 0.5):
                    cv.set(x, y, WAVE[2])
    shell(cv)
    # the nearest ring, just outside the shell, fully white
    for i in range(160):
        a = i / 160 * math.pi * 2
        for rr in (21.5, 22.5):
            x, y = CX + math.cos(a) * rr, CY + math.sin(a) * rr * 1.3
            if cv.owner(int(x), int(y)) not in ("shell", "hollow", "aza"):
                cv.set(x, y, WAVE[0])
    return cv


# ------------------------------------------------------------- 寝返り turn_over
def turn_over():
    """Still curled in his shell, he rolls over — and the stars nearby burst."""
    cv = Canvas(V[0])
    void(cv, 4.0, dark=0.8)
    BURST = [(255, 255, 230), (255, 214, 120), (250, 120, 90), (160, 60, 140)]
    for k in range(9):                                   # tiny stars exploding around him
        a = k / 9 * math.pi * 2 + 0.4
        d = 21 + 4 * prand(k, 0, 3)
        bx, by = CX + math.cos(a) * d, CY + math.sin(a) * d * 1.25
        size = 2 + int(prand(k, 1, 3) * 3.5)
        for j in range(8):
            aa = j / 8 * math.pi * 2 + k
            for s in range(1, size + 1):
                cv.set(bx + math.cos(aa) * s, by + math.sin(aa) * s, BURST[min(3, s)] if s < size else BURST[3])
        if size >= 4:                                     # blast ring around the bigger ones
            for j in range(24):
                aa = j / 24 * math.pi * 2
                if j % 2 == 0:
                    cv.set(bx + math.cos(aa) * (size + 2), by + math.sin(aa) * (size + 2), (255, 200, 170))
        cv.set(bx, by, BURST[0])
        cv.set(bx + 1, by, BURST[1]); cv.set(bx - 1, by, BURST[1]); cv.set(bx, by + 1, BURST[1]); cv.set(bx, by - 1, BURST[1])
    # still-whole tiny stars being pulled toward the blasts
    for k in range(12):
        x, y = int(prand(k, 5, 7) * W), int(prand(k, 6, 7) * 58)
        if math.hypot(x - CX, y - CY) > 23:
            cv.set(x, y, (255, 240, 200))
    # motion arcs: the shell rolling
    for side in (-1, 1):
        for i in range(30):
            a = math.pi * (0.2 + i / 45) * side
            cv.set(CX + math.sin(a) * 23.5 * side, CY - math.cos(a) * 31, (220, 200, 255) if i % 3 else None)
    shell(cv, cracked=True)
    return cv


# ------------------------------------------------------------------ 夢見 dreaming
def dreaming():
    """Glitter drifting and dancing around the shell."""
    cv = Canvas(V[0])
    void(cv, 1.4)
    GLIT = [(255, 250, 255), (255, 200, 250), (200, 170, 255), (150, 220, 255)]
    for k in range(34):
        a = prand(k, 0, 11) * math.pi * 2
        d = 19 + prand(k, 1, 11) * 9
        x, y = CX + math.cos(a) * d, CY + math.sin(a) * d * 1.3
        c = GLIT[k % 4]
        if k % 5 == 0:
            sparkle(cv, int(x), int(y), big=True, col=GLIT[0], col2=c)
        elif k % 2 == 0:
            sparkle(cv, int(x), int(y), col=c, col2=GLIT[2])
        else:
            cv.set(x, y, c)
    # a ribbon of glitter swirling round the shell
    for i in range(90):
        t = i / 90
        a = t * math.pi * 2.2 + 0.5
        x = CX + math.cos(a) * (21 + 2 * math.sin(t * 9))
        y = CY + math.sin(a) * 28 + (t - 0.5) * 8
        if i % 2 == 0:
            cv.set(x, y, GLIT[1] if i % 6 else GLIT[0])
    shell(cv)
    return cv


# -------------------------------------------------------- 混沌の微睡み chaos_slumber
def chaos_slumber():
    """Little chaos-spawn blobs drifting around his sleep."""
    cv = Canvas(V[0])
    void(cv, 0.5)
    for k, (x, y) in enumerate(((5, 8), (47, 7), (4, 30), (48, 34), (8, 52), (45, 53), (26, 2))):
        cv.ellipse(x, y, 3.5, 3, lambda xx, yy, u, v, r: V[4] if r > 0.55 else V[3], ("g", k))
        cv.set(x + 1, y + 3, V[3]); cv.set(x - 2, y + 3, V[3])
        cv.set(x - 1, y, (20, 6, 30)); cv.set(x + 1, y, (20, 6, 30))
    shell(cv)
    return cv


ARTS = {
    "snore": (snore, 0),
    "turn_over": (turn_over, 0),
    "dreaming": (dreaming, 0),
    "chaos_slumber": (chaos_slumber, 0),
}
