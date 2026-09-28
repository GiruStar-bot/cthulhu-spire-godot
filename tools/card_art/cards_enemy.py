"""Pixel-art illustrations for the cards enemies play (2026-09). Each function returns
a Canvas; only rows 0..58 are shown (ARTS top = 0). Deterministic."""
import math
from pxlib import Canvas, W, OUT_H, ramp, dither, prand, vnoise, shade
from cards_revise import vgrad, rot, dot, seg, disc, bubble

H = OUT_H


# ---------------------------------------------------------------- helpers
def tube(cv, samples, tones, owner=None, light=(-0.6, -0.8), rim=0.82):
    """Shaded tube along samples [(x, y, r), ...]; tones = [deep, sh, mid, hi].
    Each pixel takes the normal of the sample it is most inside, so joints stay smooth."""
    x0 = int(min(s[0] - s[2] for s in samples)) - 1
    x1 = int(max(s[0] + s[2] for s in samples)) + 2
    y0 = int(min(s[1] - s[2] for s in samples)) - 1
    y1 = int(max(s[1] + s[2] for s in samples)) + 2
    for y in range(max(0, y0), min(80, y1)):
        for x in range(max(0, x0), min(W, x1)):
            best = None
            for sx, sy, r in samples:
                dx, dy = x + 0.5 - sx, y + 0.5 - sy
                k = (dx * dx + dy * dy) / (r * r)
                if k <= 1.0 and (best is None or k < best[0]):
                    best = (k, dx / r, dy / r)
            if best is None:
                continue
            k, u, v = best
            s = -(u * light[0] + v * light[1])
            t = (s + 1) / 2
            if k > rim * rim and s < 0.1:
                t *= 0.35
            cv.set(x, y, ramp(x, y, t, tones), owner)


def path(fn, n, r_fn):
    """samples of a curve fn(t)->(x,y), t in 0..1, radius r_fn(t)."""
    out = []
    for i in range(n + 1):
        t = i / n
        x, y = fn(t)
        out.append((x, y, r_fn(t)))
    return out


def bez(p0, p1, p2, p3):
    def fn(t):
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        return (a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1])
    return fn


def soft_glow(cv, cx, cy, rx, ry, colors, seed=0):
    """Dithered radial glow blended onto what is there (colors from centre outwards)."""
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            if d < 1.0:
                cv.set(x, y, ramp(x, y, d, colors + [None]) if d < 0.95 else None)


def glow_ring(cv, cx, cy, r0, r1, colors):
    for y in range(H):
        for x in range(W):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r0 <= d <= r1:
                t = (d - r0) / max(0.01, r1 - r0)
                c = ramp(x, y, t, colors)
                if c is not None:
                    cv.set(x, y, c)


def stars(cv, seed, n, cols, y1=H):
    for i in range(n):
        x = int(prand(i, 1, seed) * W)
        y = int(prand(i, 2, seed) * y1)
        cv.set(x, y, cols[i % len(cols)])


def sea_band(cv, y0, cols, foam, seed=0, amp=1.2, k=0.45):
    """Choppy sea from y0 to the bottom, foam on crests."""
    for x in range(W):
        top = y0 + amp * math.sin(x * k + seed) + 0.6 * math.sin(x * 1.3 + seed * 2)
        for y in range(int(top), H):
            t = (y - top) / max(1, H - top)
            c = ramp(x, y, t, cols)
            if y == int(top):
                c = foam
            elif math.sin(x * 0.9 + y * 1.7 + seed) > 0.93:
                c = cols[0]
            cv.set(x, y, c, "sea")


# ================================================================ 深淵の掌
def abyss_grasp():
    cv = Canvas((6, 12, 18))
    vgrad(cv, None, None, colors=[(6, 10, 16), (10, 22, 30), (14, 34, 42)])
    stars(cv, 7, 10, [(40, 70, 76), (30, 54, 60)], 40)
    soft_glow(cv, 26, 26, 24, 26, [(30, 70, 70), (20, 50, 54), (14, 36, 42)])
    FLESH = [(14, 30, 32), (34, 70, 66), (70, 120, 108), (130, 180, 156)]
    CLAW = (226, 232, 206)
    # 手首
    tube(cv, path(bez((27, 62), (27, 54), (26, 46), (26, 38)), 20, lambda t: 6.5 - 1.2 * t), FLESH, "hand")
    # 掌
    tube(cv, [(26, 33, 8.5), (24, 30, 7.5), (29, 31, 7.5)], FLESH, "hand")
    # 指：鉤爪で内に曲がる
    fingers = [
        ((18, 30), (12, 24), (9, 16), (12, 11)),     # 小指（外へ）
        ((21, 26), (18, 17), (17, 9), (20, 5)),
        ((26, 24), (26, 15), (27, 7), (30, 5)),
        ((31, 26), (34, 17), (37, 10), (36, 5)),
        ((33, 34), (40, 31), (45, 25), (44, 19)),    # 親指
    ]
    for i, (a, b, c, d) in enumerate(fingers):
        r0 = 3.0 if i == 4 else 2.6
        tube(cv, path(bez(a, b, c, d), 22, lambda t, r0=r0: r0 - 1.4 * t), FLESH, "hand")
    cv.outline_outside({"hand"}, (4, 10, 12))
    for i, (a, b, c, d) in enumerate(fingers):
        # 爪：先端からさらに内側へ
        fn = bez(a, b, c, d)
        x1, y1 = fn(1.0)
        x0, y0 = fn(0.9)
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1
        dx, dy = dx / L, dy / L
        cx = 26 - x1
        seg(cv, x1, y1, x1 + dx * 2.5 + (1 if cx > 0 else -1) * 1.2, y1 + dy * 2.5 + 1.2, CLAW)
    # 吸盤のような鱗
    for i in range(14):
        x = 22 + prand(i, 3, 11) * 9
        y = 34 + prand(i, 4, 11) * 20
        if cv.owner(int(x), int(y)) == "hand":
            dot(cv, x, y, (100, 150, 130))
    # 海
    sea_band(cv, 49, [(40, 90, 96), (20, 54, 64), (10, 30, 40)], (200, 230, 222), 1.0)
    for i in range(18):  # 手首まわりの飛沫
        a = math.pi * (1.05 + 0.9 * prand(i, 1, 3))
        r = 7 + 4 * prand(i, 2, 3)
        dot(cv, 27 + math.cos(a) * r, 49 + math.sin(a) * r * 0.5, (220, 240, 232) if i % 3 else (150, 200, 196))
    return cv


# ================================================================ 塩の外皮
def brine_hide():
    cv = Canvas((8, 16, 22))
    vgrad(cv, None, None, colors=[(8, 14, 22), (12, 26, 34), (18, 40, 46)])
    for i in range(12):
        bubble(cv, 3 + prand(i, 1, 5) * 47, 4 + prand(i, 2, 5) * 50, 0.8 + prand(i, 3, 5) * 0.9, (70, 120, 130), (170, 210, 214))
    TONES = [(30, 28, 30), (86, 80, 74), (140, 132, 116), (196, 190, 172), (236, 234, 222)]
    CX, CY, RX, RY = 26.5, 31.0, 19.5, 22.5

    seeds = [(CX, CY)]
    for k, (n, rr) in enumerate(((6, 0.45), (11, 0.82))):
        for i in range(n):
            a = i / n * 2 * math.pi + k * 0.3
            seeds.append((CX + math.cos(a) * rr * RX, CY + math.sin(a) * rr * RY))

    def shell(x, y, u, v, r):
        px, py = x + 0.5, y + 0.5
        ds = sorted((math.hypot(px - sx, py - sy), sx, sy) for sx, sy in seeds)
        (d1, sx, sy), (d2, _, _) = ds[0], ds[1]
        if d2 - d1 < 1.1:
            return TONES[0]
        # 板ごとの面：中心からの向きで縁を立体に
        bx, by = (px - sx), (py - sy)
        L = math.hypot(bx, by) + 0.01
        bevel = -(bx * -0.6 + by * -0.8) / L * min(1.0, 1.6 / max(0.3, d2 - d1))
        s = -(u * -0.55 + v * -0.8)
        t = 0.52 + 0.3 * s - 0.3 * r + 0.28 * bevel
        return ramp(x, y, t, TONES)
    cv.ellipse(CX, CY, RX, RY, shell, "shell")
    cv.outline({"shell"}, (26, 24, 26))
    # 塩の結晶
    for i in range(26):
        a = prand(i, 1, 9) * 2 * math.pi
        rr = math.sqrt(prand(i, 2, 9)) * 0.85
        x = CX + math.cos(a) * rr * RX
        y = CY + math.sin(a) * rr * RY
        c = (244, 246, 240) if i % 2 else (206, 222, 226)
        dot(cv, x, y, c)
        if i % 3 == 0:
            dot(cv, x + 1, y, (170, 190, 196))
            dot(cv, x, y - 1, (250, 252, 250))
    # フジツボ
    for i in range(8):
        a = prand(i, 5, 4) * 2 * math.pi
        rr = 0.35 + 0.5 * prand(i, 6, 4)
        x = CX + math.cos(a) * rr * RX
        y = CY + math.sin(a) * rr * RY
        disc(cv, x, y, 1.9, (120, 110, 96))
        disc(cv, x - 0.3, y - 0.3, 1.2, (190, 180, 160))
        dot(cv, x, y, (30, 26, 28))
    # 中央の鋲（骨）
    disc(cv, CX, CY, 3.2, (60, 54, 50))
    disc(cv, CX - 0.4, CY - 0.4, 2.4, (200, 192, 170))
    dot(cv, CX - 1.4, CY - 1.4, (250, 248, 236))
    # 海藻
    for k, bx in enumerate((4, 49)):
        for y in range(40, H):
            x = bx + 1.5 * math.sin(y * 0.35 + k * 2)
            dot(cv, x, y, (40, 90, 60))
            dot(cv, x + 1, y, (24, 60, 44))
    return cv


# ================================================================ 子を宿す
def child_bearing():
    cv = Canvas((16, 6, 16))
    vgrad(cv, None, None, colors=[(14, 4, 14), (30, 10, 26), (44, 14, 32)])
    soft_glow(cv, 26, 30, 26, 28, [(120, 50, 80), (80, 30, 60), (50, 18, 40)])
    SAC = [(70, 20, 44), (130, 50, 80), (190, 96, 118), (236, 170, 170), (255, 220, 200)]
    CX, CY, RX, RY = 26.5, 29.0, 16.0, 20.0

    def sac(x, y, u, v, r):
        s = -(u * -0.5 + v * -0.85)
        t = 0.25 + 0.2 * s + 0.6 * (1 - r)
        return ramp(x, y, t, SAC)
    cv.ellipse(CX, CY, RX, RY, sac, "sac")
    # 胎児（中で丸まる影）
    EMB = [(40, 4, 22), (70, 12, 36)]
    for ex, ey, s in ((22, 22, 1.0), (31, 30, 1.1), (23, 37, 0.9)):
        cv.ellipse(ex, ey, 4.2 * s, 3.6 * s, lambda x, y, u, v, r: EMB[0] if r > 0.5 else EMB[1])
        for j in range(8):  # 丸まった尾
            a = j / 8 * math.pi * 1.3
            dot(cv, ex - 3 * s * math.cos(a), ey + 3.5 * s * math.sin(a) * 0.8 + 0.5, EMB[0])
        cv.ellipse(ex + 3 * s, ey - 2.6 * s, 2.2 * s, 2.2 * s, lambda x, y, u, v, r: EMB[0] if r > 0.6 else EMB[1])
        dot(cv, ex + 3.4 * s, ey - 2.8 * s, (250, 210, 120))
    # 血管
    for i in range(5):
        a = -2.4 + i * 0.35
        x, y = CX + math.cos(a) * RX * 0.9, CY + math.sin(a) * RY * 0.9
        for j in range(14):
            nx = x + 0.9 * math.cos(a + math.pi + 0.5 * math.sin(j * 0.8 + i))
            ny = y + 0.9 * math.sin(a + math.pi + 0.5 * math.sin(j * 0.8 + i))
            dot(cv, nx, ny, (110, 20, 40))
            x, y = nx, ny
    cv.outline({"sac"}, (40, 8, 24))
    # 艶
    for i in range(9):
        a = math.pi * (1.1 + i * 0.05)
        dot(cv, CX + math.cos(a) * RX * 0.82, CY + math.sin(a) * RY * 0.82, (255, 236, 236))
    # 足元の小さな卵
    for i, (x, y, r) in enumerate(((10, 50, 4.0), (43, 49, 4.4), (18, 53, 3.0), (35, 54, 3.4), (7, 42, 2.4), (47, 41, 2.6))):
        cv.ellipse(x, y, r, r * 1.1, shade([(236, 170, 170), (170, 80, 104), (110, 36, 66), (60, 14, 36)]), "egg")
        dot(cv, x - r * 0.4, y - r * 0.4, (255, 230, 230))
    # 粘液の床
    for x in range(W):
        top = 55 + math.sin(x * 0.5) * 0.8
        for y in range(int(top), H):
            if cv.owner(x, y) != "egg":
                cv.set(x, y, ramp(x, y, (y - top) / 5, [(90, 30, 56), (50, 14, 34)]))
    return cv


# ================================================================ 唱和の呪文
def chorusunity():
    cv = Canvas((12, 10, 18))
    vgrad(cv, None, None, colors=[(10, 8, 18), (20, 14, 30), (26, 18, 34)])
    soft_glow(cv, 26.5, 26, 28, 36, [(200, 150, 90), (150, 106, 70), (100, 70, 60), (56, 40, 48)])
    # 床
    for y in range(52, H):
        for x in range(W):
            cv.set(x, y, ramp(x, y, (y - 52) / 7, [(50, 40, 50), (24, 18, 28)]))
    ROBE = [(8, 6, 12), (22, 16, 30), (40, 30, 50)]
    RIM = [(250, 214, 140), (170, 120, 70)]
    for side in (-1, 1):
        d = -side                       # 中央（光）へ向く向き
        bx = 26.5 + side * 13.5
        cv.poly([(bx - d * 5, 29), (bx + d * 4, 29), (bx + d * 8, 59), (bx - d * 11, 59)],
                lambda x, y: ramp(x, y, 0.3 + 0.4 * (y - 29) / 30 * 0.3, ROBE), "robe")
        hx = bx + d * 0.5
        cv.ellipse(hx, 23, 5.2, 6.4, lambda *a: ROBE[1], "robe")
        cv.poly([(hx - d * 2, 17.5), (hx - d * 8, 25), (hx - d * 3, 28)], lambda x, y: ROBE[1], "robe")
        # 顔の開き（上を仰いで歌う）
        cv.ellipse(hx + d * 2.6, 22.5, 2.3, 3.4, lambda *a: (4, 2, 6), "robe")
        dot(cv, hx + d * 3.2, 24.5, (240, 200, 130))
        # 合わせた手を掲げる袖
        tube(cv, path(bez((bx + d * 1, 36), (bx + d * 4, 34), (bx + d * 6, 31), (bx + d * 8.5, 28)), 16,
                      lambda t: 2.2 - 0.6 * t), [ROBE[0], ROBE[1], ROBE[2], ROBE[2]], "robe")
        disc(cv, bx + d * 9.2, 27.2, 1.2, (210, 180, 150), "hand")
    # 光の側だけ縁を金に
    rim = []
    for y in range(H):
        for x in range(W):
            if cv.owner(x, y) != "robe":
                continue
            d = 1 if x < 26.5 else -1
            if cv.owner(x + d, y) not in ("robe", "hand"):
                rim.append((x, y, 0))
            elif cv.owner(x + 2 * d, y) not in ("robe", "hand") and y < 45:
                rim.append((x, y, 1))
    for x, y, k in rim:
        if k == 0 or dither(x, y, 0.5):
            cv.set(x, y, RIM[k])
    cv.outline_outside({"robe"}, (6, 4, 8))
    # 二人の間を昇る光の二重螺旋
    for k in (0, 1):
        for i in range(260):
            t = i / 260
            y = 52 - t * 48
            x = 26.5 + (2.0 + 5.0 * t) * math.sin(t * 13 + k * math.pi)
            front = math.cos(t * 13 + k * math.pi) > 0
            c = (255, 236, 180) if front else (190, 140, 90)
            dot(cv, x, y, c, "chant")
    cv.glow({"chant"}, [(150, 110, 70), None], 1)
    # 頂の印
    for i in range(8):
        a = i / 8 * 2 * math.pi
        L = 4.5 if i % 2 == 0 else 2.5
        seg(cv, 26.5, 5.5, 26.5 + math.cos(a) * L, 5.5 + math.sin(a) * L, (240, 210, 150))
    disc(cv, 26.5, 5.5, 1.3, (255, 250, 220))
    return cv


# ================================================================ 貪る顎
def devourmaw():
    cv = Canvas((8, 2, 4))
    vgrad(cv, None, None, colors=[(10, 2, 4), (20, 6, 8), (12, 3, 5)])
    CX, CY = 26.5, 30.0
    FLESH = [(40, 8, 12), (80, 18, 24), (130, 40, 44), (180, 80, 76)]
    TOOTH = [(90, 80, 64), (170, 160, 132), (230, 224, 196)]
    rings = [(24.0, 19.0, 20), (17.0, 12.5, 16), (11.5, 7.5, 12)]
    for y in range(H):
        for x in range(W):
            dx, dy = x + 0.5 - CX, (y + 0.5 - CY) * 1.08
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            if r > 26:
                continue
            # 唇・肉
            c = ramp(x, y, 1 - (r / 26) ** 0.7 * 0.9 - 0.15 * math.sin(a * 9 + r * 0.4) * 0.3, FLESH)
            if r > 23.5:
                c = FLESH[1] if prand(x, y, 3) > 0.5 else FLESH[0]
            if r < 7.5:  # 喉の闇
                t = r / 7.5
                c = ramp(x, y, t, [(0, 0, 0), (20, 2, 4), (60, 10, 14)])
            for ro, ri, n in rings:
                if ri <= r <= ro:
                    f = ((a + (0.3 if n == 16 else 0)) / (2 * math.pi) * n) % 1.0
                    depth = (ro - r) / (ro - ri)       # 0=根元 1=先端
                    half = 0.46 * (1 - depth)
                    if abs(f - 0.5) < half:
                        side = (f - 0.5) / max(0.01, half)
                        c = TOOTH[2] if side < -0.3 else (TOOTH[1] if side < 0.5 else TOOTH[0])
                        if depth > 0.85:
                            c = TOOTH[2]
            cv.set(x, y, c, "maw")
    # 涎
    for i, (x, y0, L) in enumerate(((17, 36, 8), (34, 37, 11), (25, 40, 6))):
        for j in range(L):
            dot(cv, x + 0.2 * math.sin(j), y0 + j, (200, 170, 150) if j % 3 else (240, 220, 200))
        disc(cv, x, y0 + L, 0.9, (220, 200, 180))
    return cv


# ================================================================ 抱擁
def embrace():
    cv = Canvas((6, 8, 18))
    vgrad(cv, None, None, colors=[(6, 6, 16), (12, 12, 30), (10, 10, 24)])
    soft_glow(cv, 26.5, 30, 16, 16, [(220, 190, 255), (150, 110, 210), (80, 56, 140), (36, 26, 70)])
    disc(cv, 26.5, 30, 3.2, (250, 240, 255))
    TENT = [(26, 22, 44), (70, 60, 100), (140, 124, 170), (214, 204, 230)]
    arms = [
        (bez((3, 64), (-4, 30), (6, 4), (28, 8)), 6.0),
        (bez((50, 64), (58, 34), (50, 12), (32, 14)), 6.0),
        (bez((8, 64), (16, 46), (34, 54), (42, 40)), 4.4),
    ]
    for fn, r0 in arms:
        tube(cv, path(fn, 60, lambda t, r0=r0: r0 * (1 - 0.72 * t) + 0.6), TENT, "arm")
    cv.outline_outside({"arm"}, (4, 4, 10))
    # 吸盤（内側）
    for fn, r0 in arms:
        for i in range(3, 18):
            t = i / 20
            x, y = fn(t)
            x2, y2 = fn(t + 0.01)
            nx, ny = -(y2 - y), (x2 - x)
            L = math.hypot(nx, ny) or 1
            nx, ny = nx / L, ny / L
            if (26.5 - x) * nx + (30 - y) * ny < 0:
                nx, ny = -nx, -ny
            rr = r0 * (1 - 0.72 * t) * 0.6
            dot(cv, x + nx * rr, y + ny * rr, (236, 190, 210))
    # 光の粒
    for i in range(14):
        a = prand(i, 1, 2) * 2 * math.pi
        r = 6 + 6 * prand(i, 2, 2)
        dot(cv, 26.5 + math.cos(a) * r, 30 + math.sin(a) * r, (200, 170, 255))
    return cv


# ================================================================ 邪視の呪縛
def evil_eye_bind():
    cv = Canvas((14, 4, 10))
    vgrad(cv, None, None, colors=[(12, 2, 10), (28, 6, 20), (18, 4, 14)])
    EX, EY = 26.5, 18.0
    soft_glow(cv, EX, EY, 26, 14, [(160, 40, 50), (100, 20, 40), (50, 10, 26)])
    # 光条
    for i in range(12):
        a = i / 12 * 2 * math.pi + 0.13
        for r in range(12, 26):
            if r % 2 == 0:
                dot(cv, EX + math.cos(a) * r * 1.3, EY + math.sin(a) * r * 0.8, (120, 30, 40))
    # 剣（下向き、呪縛される）
    BL = [(90, 96, 110), (170, 176, 190), (230, 234, 240)]
    for y in range(31, 57):
        w = 2.5 if y < 52 else 2.5 * (57 - y) / 5
        for x in range(int(26.5 - w), int(26.5 + w + 0.99)):
            cv.set(x, y, BL[2] if x < 26 else (BL[1] if x < 28 else BL[0]), "sword")
    cv.poly([(19, 28), (34, 28), (34, 31), (19, 31)], lambda x, y: (190, 150, 70) if y < 30 else (120, 90, 40), "sword")
    cv.poly([(25, 20), (28, 20), (28, 28), (25, 28)], lambda x, y: (80, 50, 40) if (y % 2) else (110, 70, 50), "sword")
    cv.outline_outside({"sword"}, (8, 2, 6))
    # 鎖（X 字に巻き付く）
    CH = [(70, 70, 80), (150, 150, 160), (200, 200, 210)]
    for sgn in (-1, 1):
        for i in range(12):
            t = i / 11
            x = 26.5 + sgn * (20 - 40 * t)
            y = 34 + 16 * t + 2 * math.sin(t * 3)
            if i % 2 == 0:
                cv.ellipse(x, y, 2.0, 1.3, lambda px, py, u, v, r: CH[1] if r > 0.35 else None, "chain")
            else:
                seg(cv, x - 1.2, y, x + 1.2, y, CH[2], "chain")
    cv.outline_outside({"chain"}, (10, 4, 8))
    # 眼
    def eye(x, y, u, v, r):
        if r > 0.8:
            return (60, 10, 20)
        return (220, 200, 150) if v < 0 else (180, 150, 110)
    pts = []
    for i in range(40):
        a = i / 40 * 2 * math.pi
        pts.append((EX + 13 * math.cos(a), EY + 6.5 * math.sin(a) * (1 - 0.35 * abs(math.cos(a)))))
    cv.poly(pts, lambda x, y: (206, 186, 140) if y < EY else (160, 130, 96), "eye")
    cv.outline({"eye"}, (70, 8, 20))
    cv.ellipse(EX, EY, 5.5, 5.2, lambda x, y, u, v, r: (230, 60, 40) if r < 0.45 else ((180, 30, 30) if r < 0.8 else (90, 10, 20)))
    for y in range(int(EY - 5), int(EY + 5)):
        cv.set(26, y, (10, 0, 4))
        if abs(y - EY) < 3:
            cv.set(27, y, (10, 0, 4))
    dot(cv, EX - 2.5, EY - 2.5, (255, 230, 200))
    # 眼の血管
    for i, (x, y) in enumerate(((16, 17), (37, 17), (17, 20), (36, 20))):
        dot(cv, x, y, (170, 40, 40))
        dot(cv, x + (1 if x < EX else -1), y, (170, 40, 40))
    return cv


# ================================================================ 群れの急襲
BAT = [
    "#.................#",
    "##......#.#......##",
    "###.....###.....###",
    "####...#e#e#...####",
    "#####.#######.#####",
    "###################",
    ".##.#.#######.#.##.",
    "..#...#.###.#...#..",
    "........#.#........",
]


def _bat(cv, cx, cy, sc, body, eye, owner):
    """Front-facing bat-winged silhouette (19x9 sprite) scaled by an integer."""
    for j, row in enumerate(BAT):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            c = eye if ch == "e" else body
            for a in range(sc):
                for b in range(sc):
                    cv.set(cx + (i - 9) * sc + a, cy + (j - 4) * sc + b, c, owner)


def flockrush():
    cv = Canvas((14, 8, 24))
    vgrad(cv, None, None, colors=[(12, 6, 22), (34, 16, 46), (60, 28, 60)])
    stars(cv, 3, 16, [(120, 100, 150), (80, 70, 110)], 40)
    disc(cv, 42, 10, 5.5, (210, 200, 180))
    disc(cv, 40.5, 9, 4.5, (236, 228, 206))
    disc(cv, 44, 12, 1.2, (190, 180, 160))
    # 急降下の軌跡
    for i in range(9):
        y0 = 4 + i * 6
        x0 = prand(i, 1, 8) * 20
        seg(cv, x0, y0, x0 + 12, y0 + 9, (70, 40, 90))
    far = [(9, 9), (22, 5), (31, 17), (6, 26), (47, 28), (16, 44)]
    for x, y in far:
        _bat(cv, x, y, 1, (40, 22, 52), (230, 70, 60), "far")
    # 近い群れ：急降下の残像つき
    for x, y, sc in ((20, 30, 2), (37, 45, 2)):
        for k in range(1, 4):
            for i in range(3):
                seg(cv, x - 6 - k * 3 + i * 6, y - 8 - k * 3, x - 4 - k * 2 + i * 6, y - 6 - k * 2, (90, 50, 110))
        _bat(cv, x, y, sc, (14, 6, 20), (255, 100, 70), "near")
    cv.outline_outside({"near"}, (150, 90, 160))
    return cv


# ================================================================ 凍てつく息
def frost_breath():
    cv = Canvas((6, 12, 24))
    vgrad(cv, None, None, colors=[(6, 10, 22), (12, 24, 44), (20, 40, 60)])
    # 息：左上の顎から右下へ広がる円錐
    SX, SY = 9.0, 13.0
    DX, DY = math.cos(math.radians(40)), math.sin(math.radians(40))
    MIST = [(40, 80, 110), (90, 150, 180), (170, 220, 236), (240, 252, 255)]
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5 - SX, y + 0.5 - SY
            along = px * DX + py * DY
            perp = -px * DY + py * DX
            if along <= 0:
                continue
            width = 2.5 + along * 0.42
            k = abs(perp + 2.5 * math.sin(along * 0.25)) / width
            if k > 1:
                continue
            n = vnoise(x, y, 4.5, 5) * 0.5 + vnoise(x, y, 2.0, 9) * 0.5
            t = (1 - k) * 0.8 + n * 0.45 - along / 110
            if t > 0.25:
                cv.set(x, y, ramp(x, y, (t - 0.25) / 0.8, MIST), "mist")
    # 顎（左上隅のシルエット）
    J1, J2 = (26, 34, 52), (14, 18, 30)
    cv.poly([(0, 0), (8, 0), (15, 5), (17, 8), (13, 9), (0, 10)], lambda x, y: J1 if y < 5 else J2, "jaw")
    cv.poly([(0, 18), (9, 16), (14, 17), (12, 21), (4, 24), (0, 25)], lambda x, y: J2, "jaw")
    for x in (3, 6, 9, 12):
        seg(cv, x, 10, x + 0.4, 12.5 - (x == 12), (224, 230, 236))
    for x in (4, 7, 10):
        seg(cv, x, 17, x + 0.4, 15, (224, 230, 236))
    dot(cv, 8, 3, (120, 220, 255))
    dot(cv, 9, 3, (220, 250, 255))
    dot(cv, 10, 4, (80, 170, 220))
    cv.outline_outside({"jaw"}, (60, 90, 120))
    # 氷の結晶
    def flake(cx, cy, r, c):
        for k in range(6):
            a = k * math.pi / 3
            seg(cv, cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r, c)
    for i, (x, y, r) in enumerate(((30, 18, 2.5), (44, 30, 3), (22, 36, 2), (40, 46, 2.5), (14, 26, 1.5), (48, 14, 1.5))):
        flake(x, y, r, (230, 248, 255))
    # 霜柱
    ICE = [(90, 150, 190), (170, 220, 240), (240, 252, 255)]
    for i in range(11):
        bx = 1 + i * 5 + prand(i, 1, 6) * 2
        h = 4 + prand(i, 2, 6) * 9
        cv.poly([(bx - 2.2, 59), (bx, 59 - h), (bx + 2.2, 59)],
                lambda x, y, bx=bx: ICE[2] if x < bx - 0.5 else (ICE[1] if x < bx + 0.8 else ICE[0]), "ice")
    cv.outline_outside({"ice"}, (30, 60, 90))
    return cv


# ================================================================ 疾風の爪
def gale_claw():
    cv = Canvas((10, 18, 22))
    vgrad(cv, None, None, colors=[(8, 14, 18), (16, 30, 36), (22, 40, 44)])
    # 風の筋
    for i in range(14):
        y0 = prand(i, 1, 2) * 58
        x0 = prand(i, 2, 2) * 30 - 10
        L = 10 + prand(i, 3, 2) * 16
        for j in range(int(L * 3)):
            t = j / (L * 3)
            dot(cv, x0 + t * L, y0 + t * L * 0.35 + 1.2 * math.sin(t * 4 + i), (40, 70, 72) if t < 0.7 else (70, 110, 110))
    CORE, EDGE, GL = (250, 255, 252), (170, 236, 226), (60, 130, 130)

    def slash(x0, y0, x1, y1, bow, wmax, owner):
        n = 120
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t + bow * math.sin(math.pi * t) * (y1 - y0) / 50
            y = y0 + (y1 - y0) * t - bow * math.sin(math.pi * t) * (x1 - x0) / 50
            w = wmax * math.sin(math.pi * t) ** 0.7
            disc(cv, x, y, w + 0.6, EDGE, owner)
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t + bow * math.sin(math.pi * t) * (y1 - y0) / 50
            y = y0 + (y1 - y0) * t - bow * math.sin(math.pi * t) * (x1 - x0) / 50
            w = wmax * math.sin(math.pi * t) ** 0.7
            if w > 0.5:
                disc(cv, x, y, w - 0.3, CORE, owner)
    # 2 回の斬撃（3 本爪 ×2）
    for k in range(3):   # 一撃目の残像
        slash(44 + k * 6, 10 + k * 2, 20 + k * 6, 56 + k * 2, 5, 1.1, "s2")
    cv.glow({"s2"}, [(30, 70, 72), None], 1)
    for y in range(H):
        for x in range(W):
            if cv.owner(x, y) == "s2":
                cv.set(x, y, (70, 130, 130) if cv.get(x, y) == CORE else (40, 90, 92))
    for k in range(3):   # 二撃目
        slash(34 + k * 6, 3 + k * 2, 6 + k * 6, 50 + k * 2, 6, 1.7, "s1")
    cv.glow({"s1"}, [GL, (30, 70, 72), None], 2)
    return cv


# ================================================================ 大海嘯
def great_surge():
    cv = Canvas((10, 14, 22))
    vgrad(cv, None, None, colors=[(10, 12, 20), (20, 26, 38), (34, 42, 52)])
    disc(cv, 8, 8, 3.5, (220, 226, 210))
    disc(cv, 7, 7, 2.5, (240, 244, 230))
    # 廃墟の門（呑まれかけ）
    STONE = (26, 32, 40)
    cv.poly([(2, 52), (2, 38), (4, 36), (6, 38), (6, 52)], lambda x, y: STONE, "ruin")
    cv.poly([(12, 52), (12, 40), (14, 38), (16, 40), (16, 52)], lambda x, y: STONE, "ruin")
    cv.poly([(1, 38), (17, 38), (17, 35), (1, 35)], lambda x, y: STONE, "ruin")
    pts = [(53, 56), (53, 26), (47, 14), (39, 7), (29, 4), (20, 6), (13, 11), (9, 18), (10, 24),
           (14, 26), (18, 23), (19, 19), (23, 22), (26, 32), (28, 44), (27, 56)]
    WAVE = [(8, 30, 40), (16, 56, 66), (40, 100, 108), (90, 160, 160), (170, 220, 214)]

    def wv(x, y):
        # 波の面：左（前面）ほど明るく透け、右下ほど深い
        t = 0.75 - (x - 18) / 60 - (y - 10) / 90
        t += 0.12 * math.sin((x * 0.5 + y * 0.9))
        return ramp(x, y, t, WAVE)
    cv.poly(pts, wv, "wave")
    # 筋
    for k in range(5):
        for i in range(60):
            t = i / 59
            a = math.pi * (1.1 + 0.8 * t)
            r = 12 + k * 4
            x = 34 + math.cos(a) * r * 0.9 + t * 6
            y = 30 + math.sin(a) * r
            if cv.owner(int(x), int(y)) == "wave":
                dot(cv, x, y, (120, 190, 186) if k % 2 else (26, 70, 80))
    # 泡の縁
    FOAM = [(250, 252, 250), (210, 232, 230), (150, 200, 200)]
    for y in range(H):
        for x in range(W):
            if cv.owner(x, y) != "wave":
                continue
            edge = any(cv.owner(x + dx, y + dy) != "wave" for dx, dy in ((0, -1), (-1, 0), (0, -2), (-1, -1)))
            if edge and y < 30:
                cv.set(x, y, FOAM[0] if dither(x, y, 0.7) else FOAM[1])
    for i in range(40):
        a = math.pi * (0.9 + 0.9 * prand(i, 1, 5))
        r = 16 + 6 * prand(i, 2, 5)
        dot(cv, 31 + math.cos(a) * r, 26 + math.sin(a) * r * 1.05, FOAM[i % 3])
    for i in range(14):  # 唇から落ちる飛沫
        dot(cv, 12 + prand(i, 3, 5) * 8, 26 + prand(i, 4, 5) * 10, FOAM[1])
    sea_band(cv, 51, [(40, 100, 108), (16, 56, 66), (8, 30, 40)], (220, 240, 236), 2.0, 1.0, 0.6)
    return cv


# ================================================================ 非ユークリッドの罠
def noneuclid():
    cv = Canvas((8, 6, 16))
    CX, CY = 26.5, 30.0
    COLS = [(20, 14, 40), (60, 36, 110), (40, 120, 150), (150, 90, 200)]
    # 回転しながら縮む入れ子の四角 → 深い穴
    for y in range(H):
        for x in range(W):
            dx, dy = x + 0.5 - CX, y + 0.5 - CY
            r = max(abs(dx), abs(dy))
            level = 0
            best = None
            for k in range(14):
                s = 30 * (0.8 ** k)
                a = k * 0.19
                ca, sa = math.cos(a), math.sin(a)
                u, v = dx * ca + dy * sa, -dx * sa + dy * ca
                if max(abs(u), abs(v)) <= s:
                    level = k
                    best = (u, v, s)
            u, v, s = best if best else (dx, dy, 30)
            edge = s - max(abs(u), abs(v))
            depth = level / 13
            if edge < 0.9 * (1 - depth * 0.5) and level < 13:
                c = COLS[3] if (level % 2 == 0) else COLS[2]
                if depth > 0.6:
                    c = COLS[1]
            else:
                # 面：上/左の面は明るく、下/右は暗い（遠近のねじれ）
                face = (u + v) / max(1.0, s)
                t = 0.25 + 0.2 * face - depth * 0.3
                c = ramp(x, y, max(0, t), [COLS[0], COLS[1]])
                if level >= 12:
                    c = (0, 0, 0)
            cv.set(x, y, c)
    # 奥の眼
    cv.ellipse(CX, CY, 2.6, 1.6, lambda x, y, u, v, r: (220, 230, 120) if r < 0.5 else (140, 60, 180))
    dot(cv, CX - 0.5, CY - 0.5, (10, 0, 10))
    return cv


# ================================================================ 千貌の代償
def _mask(cv, cx, cy, s, skin, dark, mood, owner):
    cv.ellipse(cx, cy, 3.6 * s, 4.8 * s, lambda x, y, u, v, r: skin[0] if (u < -0.2 and v < 0.1) else (skin[1] if r < 0.75 else skin[2]), owner)
    ey = cy - 1.0 * s
    for sx in (-1, 1):
        cv.ellipse(cx + sx * 1.5 * s, ey, 0.9 * s + 0.2, 0.6 * s + 0.35, lambda *a: dark)
    my = cy + 2.2 * s
    if mood == 0:     # 笑う
        for i in range(-2, 3):
            dot(cv, cx + i * 0.7 * s, my - (0.5 * s if abs(i) == 2 else 0), dark)
    elif mood == 1:   # 叫ぶ
        cv.ellipse(cx, my + 0.3 * s, 0.9 * s + 0.2, 1.1 * s + 0.2, lambda *a: dark)
    else:             # 嘆く
        for i in range(-2, 3):
            dot(cv, cx + i * 0.7 * s, my + (0.5 * s if abs(i) == 2 else 0), dark)


def pricewisdom():
    cv = Canvas((10, 8, 10))
    vgrad(cv, None, None, colors=[(8, 6, 8), (20, 14, 16), (14, 10, 12)])
    soft_glow(cv, 26.5, 26, 26, 24, [(120, 90, 40), (70, 50, 30), (30, 22, 20)])
    # 後光のように並ぶ無数の顔
    for ring, (R, n, s, col) in enumerate(((21, 14, 0.55, [(110, 100, 90), (80, 72, 66), (50, 44, 42)]),
                                            (14, 10, 0.75, [(170, 156, 136), (130, 118, 104), (80, 72, 66)]))):
        for i in range(n):
            a = i / n * 2 * math.pi + ring * 0.3
            x, y = 26.5 + math.cos(a) * R * 1.05, 25 + math.sin(a) * R
            if y > 40:
                continue
            _mask(cv, x, y, s, col, (20, 14, 14), (i + ring) % 3, "mask")
    # 頭巾の人影
    cv.poly([(10, 59), (14, 40), (20, 32), (33, 32), (39, 40), (43, 59)], lambda x, y: ramp(x, y, (x - 10) / 40, [(40, 32, 30), (22, 18, 18), (12, 10, 10)]), "hood")
    cv.ellipse(26.5, 27, 9, 11, lambda x, y, u, v, r: (40, 32, 30) if u < -0.2 else (24, 20, 20), "hood")
    cv.ellipse(26.5, 29, 6.2, 8.2, lambda *a: (4, 2, 4), "hood")
    cv.outline_outside({"hood"}, (200, 160, 80))
    # 中央の顔：金の糸で縫い付けた仮面
    _mask(cv, 26.5, 29.5, 1.25, [(236, 226, 206), (200, 188, 168), (140, 128, 112)], (16, 10, 10), 2, "face")
    for i in range(22):
        t = i / 21
        dot(cv, 26.5 + (8 + 10 * t) * math.cos(1.1 + t * 2), 29.5 + (8 + 10 * t) * math.sin(1.1 + t * 2), (230, 180, 80))
        dot(cv, 26.5 - (8 + 10 * t) * math.cos(1.1 + t * 2), 29.5 + (8 + 10 * t) * math.sin(1.1 + t * 2), (230, 180, 80))
    # ひび
    seg(cv, 26.5, 23.5, 25.5, 27, (80, 60, 50))
    seg(cv, 25.5, 27, 27, 29, (80, 60, 50))
    return cv


# ================================================================ 原形質の奔流
def protosurge():
    cv = Canvas((6, 12, 8))
    vgrad(cv, None, None, colors=[(6, 10, 8), (12, 22, 14), (18, 30, 18)])
    OOZE = [(10, 30, 14), (30, 80, 30), (80, 150, 50), (170, 220, 100)]
    blobs = []
    for i in range(46):
        t = i / 45
        a = t * 3.6 * math.pi
        R = 20 * (1 - t) + 3
        x = 26.5 + math.cos(a) * R * 1.0
        y = 32 + math.sin(a) * R * 0.95 - 4 * t
        r = 7.5 * (1 - t) + 2.4 + 1.5 * prand(i, 1, 4)
        blobs.append((x, y, r))
    tube(cv, blobs, OOZE, "ooze")
    cv.outline_outside({"ooze"}, (4, 10, 6))
    # 目
    for i in range(12):
        x, y, r = blobs[int(prand(i, 1, 7) * 40)]
        x += (prand(i, 2, 7) - 0.5) * r
        y += (prand(i, 3, 7) - 0.5) * r
        rr = 1.0 + prand(i, 4, 7) * 1.4
        cv.ellipse(x, y, rr + 0.5, rr, lambda *a: (230, 236, 200))
        dot(cv, x + 0.2, y, (10, 16, 8))
        if rr > 1.8:
            dot(cv, x + 0.7, y, (10, 16, 8))
    # 泡と飛沫
    for i in range(20):
        bubble(cv, prand(i, 1, 3) * 53, prand(i, 2, 3) * 58, 0.8 + prand(i, 3, 3), (90, 170, 60), (200, 240, 140))
    # 滴り
    for i, x in enumerate((8, 17, 38, 46)):
        top = 44 + prand(i, 1, 1) * 6
        for y in range(int(top), H):
            if cv.owner(x, y) != "ooze":
                cv.set(x, y, OOZE[1] if y % 3 else OOZE[2])
    return cv


# ================================================================ 大司祭の啓示
def revelation():
    cv = Canvas((10, 4, 18))
    vgrad(cv, None, None, colors=[(10, 4, 18), (26, 10, 40), (40, 16, 52)])
    soft_glow(cv, 26.5, 12, 22, 16, [(220, 150, 255), (140, 70, 200), (70, 30, 110), (36, 14, 60)])
    # 光条
    for i in range(16):
        a = math.pi + i / 15 * math.pi
        for r in range(8, 30):
            if (r + i) % 3:
                dot(cv, 26.5 + math.cos(a) * r, 12 + math.sin(a) * r * 0.9, (150, 90, 210))
    # 啓示の眼（頭上）
    cv.ellipse(26.5, 12, 7, 3.5, lambda x, y, u, v, r: (250, 230, 255) if r < 0.75 else (200, 140, 240), "eye")
    disc(cv, 26.5, 12, 2.2, (120, 30, 160))
    disc(cv, 26.5, 12, 1.0, (20, 0, 30))
    # 大司祭（正面）
    ROBE = [(12, 6, 18), (34, 16, 50), (66, 34, 90), (120, 80, 150)]
    cv.poly([(8, 59), (16, 32), (37, 32), (45, 59)], lambda x, y: ramp(x, y, 0.55 - abs(x - 26.5) / 30 - (y - 32) / 80, ROBE), "robe")
    cv.ellipse(26.5, 30, 7.5, 8.5, lambda x, y, u, v, r: ROBE[2] if (u < 0 and r > 0.4) else ROBE[1], "robe")
    cv.poly([(22.5, 20), (26.5, 16), (30.5, 20)], lambda x, y: ROBE[2], "robe")
    cv.ellipse(26.5, 31.5, 4.6, 5.6, lambda *a: (4, 0, 8), "robe")
    for ex in (24.8, 28.2):
        dot(cv, ex, 31, (240, 150, 255))
    # 掲げた腕
    for side in (-1, 1):
        seg(cv, 26.5 + side * 7, 38, 26.5 + side * 16, 24, ROBE[2], "robe")
        seg(cv, 26.5 + side * 7.8, 38.5, 26.5 + side * 16.8, 24.5, ROBE[1], "robe")
        seg(cv, 26.5 + side * 8.5, 39, 26.5 + side * 17.5, 25, ROBE[1], "robe")
        disc(cv, 26.5 + side * 16.8, 22.5, 1.5, (190, 160, 170), "robe")
    cv.outline_outside({"robe"}, (6, 2, 10))
    # 胸の印
    for i in range(3):
        dot(cv, 26.5, 42 + i * 2, (220, 160, 80))
    dot(cv, 25.5, 44, (220, 160, 80))
    dot(cv, 27.5, 44, (220, 160, 80))
    # 降り注ぐ恐怖の欠片
    for i in range(10):
        x = 3 + prand(i, 1, 6) * 47
        y = 18 + prand(i, 2, 6) * 36
        if cv.owner(int(x), int(y)) is None:
            seg(cv, x, y, x + 1, y + 2.5, (180, 110, 230))
    return cv


# ================================================================ 沈黙の呪縛
def silent_bind():
    cv = Canvas((8, 8, 14))
    vgrad(cv, None, None, colors=[(8, 8, 14), (18, 18, 30), (12, 12, 22)])
    soft_glow(cv, 26.5, 28, 24, 26, [(80, 90, 130), (46, 50, 80), (24, 26, 44)])
    # 鎖（X）
    CH = [(70, 74, 90), (140, 146, 160), (200, 206, 220)]
    for sgn in (-1, 1):
        for i in range(15):
            t = i / 14
            x = 26.5 + sgn * (26 - 52 * t)
            y = 4 + 52 * t
            if i % 2 == 0:
                cv.ellipse(x, y, 2.1, 1.5, lambda px, py, u, v, r: CH[1] if r > 0.3 else None, "chain")
            else:
                seg(cv, x - 1.3, y - 1.3 * -sgn, x + 1.3, y + 1.3 * -sgn, CH[2], "chain")
    cv.outline_outside({"chain"}, (6, 6, 10))
    # 仮面
    MK = [(80, 84, 96), (150, 156, 168), (210, 214, 220), (244, 246, 248)]
    cv.ellipse(26.5, 29, 12.5, 16, lambda x, y, u, v, r: ramp(x, y, 0.8 - 0.3 * u - 0.2 * v - 0.25 * r, MK), "mask")
    cv.outline({"mask"}, (40, 42, 54))
    for sx in (-1, 1):
        cv.poly([(26.5 + sx * 2, 23), (26.5 + sx * 8, 22), (26.5 + sx * 9, 25), (26.5 + sx * 3, 26)], lambda x, y: (10, 10, 18))
        dot(cv, 26.5 + sx * 5.5, 24, (140, 170, 255))
    # 縫い付けられた口
    for x in range(19, 35):
        cv.set(x, 36, (60, 40, 50))
    for i in range(6):
        x = 20 + i * 2.8
        seg(cv, x, 34, x + 1, 38, (30, 20, 26))
    # 鼻筋・ひび
    seg(cv, 26.5, 26, 26.5, 31, (170, 176, 186))
    seg(cv, 30, 14, 32, 19, (110, 114, 126))
    seg(cv, 32, 19, 31, 22, (110, 114, 126))
    # 南京錠
    cv.poly([(23, 44), (30, 44), (30, 51), (23, 51)], lambda x, y: (200, 160, 70) if x < 27 else (150, 110, 40), "lock")
    for i in range(12):
        a = math.pi + i / 11 * math.pi
        dot(cv, 26.5 + math.cos(a) * 2.5, 44 + math.sin(a) * 3, (180, 180, 190))
    dot(cv, 26, 47, (40, 20, 10))
    dot(cv, 26, 48, (40, 20, 10))
    cv.outline_outside({"lock"}, (20, 14, 10))
    return cv


# ================================================================ 空へ攫う
def sky_snatch():
    cv = Canvas((16, 22, 30))
    vgrad(cv, None, None, colors=[(12, 16, 24), (30, 40, 52), (50, 62, 70)])
    WIND = [(80, 100, 110), (150, 176, 180), (220, 236, 232)]
    # 竜巻：上が広く下が細い
    for k in range(9):
        for i in range(400):
            t = i / 399
            y = 58 - t * 56
            R = 2 + 20 * t ** 1.3
            a = t * 16 + k * 0.7
            x = 26.5 + math.sin(a) * R + 4 * math.sin(t * 3)
            front = math.cos(a) > 0
            if front or i % 3 == 0:
                dot(cv, x, y, WIND[2] if (front and k % 3 == 0) else (WIND[1] if front else WIND[0]), "wind")
    # 攫われる人影
    FIG = (14, 12, 18)
    cx, cy = 30, 30
    disc(cv, cx, cy - 4, 1.6, FIG, "fig")
    seg(cv, cx, cy - 2.5, cx - 1, cy + 3, FIG, "fig")
    seg(cv, cx + 0.8, cy - 2.5, cx - 0.2, cy + 3, FIG, "fig")
    seg(cv, cx - 1, cy + 3, cx - 4, cy + 6, FIG, "fig")
    seg(cv, cx - 0.5, cy + 3, cx + 1, cy + 7, FIG, "fig")
    seg(cv, cx, cy - 1.5, cx + 4, cy - 4, FIG, "fig")
    seg(cv, cx, cy - 1.5, cx - 4, cy - 3, FIG, "fig")
    cv.outline_outside({"fig"}, (200, 220, 220))
    # 奪われて舞うカード
    for i, (x, y, a) in enumerate(((12, 16, 0.4), (42, 42, -0.5))):
        T = rot(x, y, a)
        cv.poly([T(-2.5, -3.5), T(2.5, -3.5), T(2.5, 3.5), T(-2.5, 3.5)], lambda px, py: (200, 180, 130), "card")
        cv.poly([T(-1.5, -2.5), T(1.5, -2.5), T(1.5, 0.5), T(-1.5, 0.5)], lambda px, py: (90, 60, 110), "card")
    cv.outline_outside({"card"}, (20, 16, 20))
    return cv


# ================================================================ 鐘鳴らし
def tollbell():
    cv = Canvas((6, 14, 14))
    vgrad(cv, None, None, colors=[(6, 12, 14), (10, 26, 26), (8, 18, 20)])
    # 音の波紋
    for k in range(4):
        r = 18 + k * 6
        for i in range(160):
            a = i / 160 * 2 * math.pi
            if (i // 8) % 2 == 0:
                dot(cv, 26.5 + math.cos(a) * r, 32 + math.sin(a) * r * 0.75, [(80, 200, 160), (60, 160, 130), (40, 110, 96), (26, 70, 64)][k])
    # 梁と吊り
    cv.poly([(0, 2), (53, 2), (53, 6), (0, 6)], lambda x, y: (60, 40, 30) if y < 4 else (36, 24, 18), "beam")
    for y in range(6, 12):
        cv.set(26, y, (90, 80, 70))
        cv.set(27, y, (60, 50, 40))
    T = rot(26.5, 12, math.radians(-12))
    BR = [(26, 16, 8), (70, 44, 18), (128, 84, 34), (184, 132, 56), (240, 200, 116)]
    # 鐘の輪郭（局所座標 u 横, v 下）
    prof = [(0, 2.5), (3, 5.5), (8, 7.0), (16, 8.5), (24, 11.5), (27, 15.0), (29, 15.5)]

    def width(v):
        for (v0, w0), (v1, w1) in zip(prof, prof[1:]):
            if v0 <= v <= v1:
                return w0 + (w1 - w0) * (v - v0) / (v1 - v0)
        return None
    for y in range(8, 50):
        for x in range(W):
            px, py = x + 0.5 - 26.5, y + 0.5 - 12
            a = math.radians(12)
            u = px * math.cos(a) - py * math.sin(a)
            v = px * math.sin(a) + py * math.cos(a)
            w = width(v)
            if w is None or abs(u) > w:
                continue
            s = u / w
            t = 0.5 - 0.55 * s - 0.25 * abs(s) ** 3 + 0.06 * math.sin(v * 0.9) + (0.12 if -0.55 < s < -0.3 else 0)
            if 24 < v < 25.5 or 6 < v < 7:
                t -= 0.3
            cv.set(x, y, ramp(x, y, t, BR), "bell")
    cv.outline_outside({"bell"}, (4, 8, 8))
    # 舌（振り子）
    x, y = T(1.5, 30)
    disc(cv, x, y, 2.2, (60, 40, 20))
    disc(cv, x - 0.5, y - 0.5, 1.2, (150, 110, 50))
    # 緑錆
    for i in range(16):
        x, y = T((prand(i, 1, 8) - 0.5) * 20, 8 + prand(i, 2, 8) * 16)
        if cv.owner(int(x), int(y)) == "bell":
            dot(cv, x, y, (70, 150, 120))
    return cv


# ================================================================ 呼び声
def thecall():
    cv = Canvas((6, 8, 14))
    vgrad(cv, None, None, colors=[(8, 6, 18), (24, 14, 40), (36, 30, 54)])
    # 同心の呼び声
    for k in range(6):
        r = 6 + k * 5
        for i in range(200):
            a = i / 200 * 2 * math.pi
            dot(cv, 26.5 + math.cos(a) * r * 1.15, 20 + math.sin(a) * r, [(170, 110, 230), (140, 80, 200), (110, 60, 170), (80, 44, 130), (60, 34, 100), (46, 26, 80)][k])
    # 巨影（頭と触腕、翼）
    SH = (10, 8, 20)
    for side in (-1, 1):
        cv.poly([(26.5, 26), (26.5 + side * 24, 8), (26.5 + side * 22, 18), (26.5 + side * 26, 22), (26.5 + side * 18, 30)], lambda x, y: (18, 12, 32), "god")
    cv.ellipse(26.5, 20, 9, 11, lambda *a: SH, "god")
    for k in range(-3, 4):
        x0 = 26.5 + k * 2.2
        for i in range(24):
            t = i / 23
            dot(cv, x0 + k * t * 1.5 + 1.2 * math.sin(t * 6 + k), 26 + t * 18, SH, "god")
            dot(cv, x0 + k * t * 1.5 + 1.2 * math.sin(t * 6 + k) + 1, 26 + t * 18, SH, "god")
    cv.outline_outside({"god"}, (120, 70, 180))
    for ex in (22.5, 30.5):
        cv.ellipse(ex, 18, 1.8, 1.0, lambda *a: (255, 240, 120))
        dot(cv, ex, 18, (255, 255, 230))
    # 沈んだ都ルルイエ
    CITY = (16, 14, 24)
    for i, (x, w, h) in enumerate(((2, 5, 10), (8, 4, 16), (13, 6, 8), (38, 5, 12), (44, 4, 18), (49, 4, 9))):
        cv.poly([(x, 50), (x, 50 - h), (x + w * 0.6, 50 - h - 2), (x + w, 50 - h + 1), (x + w, 50)], lambda px, py: CITY, "city")
    sea_band(cv, 48, [(30, 30, 60), (16, 16, 36), (8, 8, 20)], (120, 100, 180), 3.0, 0.8)
    # 海面に映る眼
    for ex in (22.5, 30.5):
        dot(cv, ex, 52, (220, 200, 100))
        dot(cv, ex, 54, (160, 140, 80))
    return cv


# ================================================================ 海
def sea():
    cv = Canvas((10, 20, 30))
    vgrad(cv, None, None, colors=[(20, 34, 48), (40, 64, 80), (70, 96, 104)], y0=0, y1=22)
    disc(cv, 38, 11, 4, (236, 236, 214))
    for y in range(22, H):
        for x in range(W):
            t = (y - 22) / 37
            c = ramp(x, y, t, [(46, 96, 110), (24, 64, 84), (12, 36, 54)])
            # 月の道
            if abs(x - 38) < 3 - t * 2 and math.sin(y * 2.3 + x) > 0.2:
                c = (200, 210, 190)
            cv.set(x, y, c)
    # うねる波の層（手前ほど大きい）
    FOAM = (230, 242, 236)
    for k, (y0, amp, per) in enumerate(((26, 0.8, 6.0), (31, 1.2, 8.0), (38, 2.0, 11.0), (47, 3.0, 15.0))):
        for x in range(W):
            ph = (x + k * 5) / per * 2 * math.pi
            top = y0 - amp * max(0, math.sin(ph)) ** 2 * 2
            for y in range(int(top), int(top) + 2 + k):
                c = [(40, 96, 110), (30, 80, 100), (20, 64, 86), (14, 48, 70)][k]
                if y == int(top):
                    c = FOAM if math.sin(ph) > 0.3 else (140, 190, 196)
                cv.set(x, y, c)
    # 防壁のような大波（手前）
    for x in range(W):
        top = 52 - 3 * math.sin(x * 0.3)
        for y in range(int(top), H):
            cv.set(x, y, ramp(x, y, (y - top) / 6, [(80, 150, 160), (30, 80, 100), (14, 40, 60)]))
        cv.set(x, int(top), FOAM)
    return cv


ARTS = {
    "abyss_grasp": (abyss_grasp, 0),
    "brine_hide": (brine_hide, 0),
    "child_bearing": (child_bearing, 0),
    "chorusunity": (chorusunity, 0),
    "devourmaw": (devourmaw, 0),
    "embrace": (embrace, 0),
    "evil_eye_bind": (evil_eye_bind, 0),
    "flockrush": (flockrush, 0),
    "frost_breath": (frost_breath, 0),
    "gale_claw": (gale_claw, 0),
    "great_surge": (great_surge, 0),
    "noneuclid": (noneuclid, 0),
    "pricewisdom": (pricewisdom, 0),
    "protosurge": (protosurge, 0),
    "revelation": (revelation, 0),
    "silent_bind": (silent_bind, 0),
    "sky_snatch": (sky_snatch, 0),
    "tollbell": (tollbell, 0),
    "thecall": (thecall, 0),
    "sea": (sea, 0),
}
