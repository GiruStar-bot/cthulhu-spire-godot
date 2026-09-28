"""Redrawn card illustrations (2026-09 feedback). Each function returns a Canvas;
only rows 0..58 are shown (ARTS top = 0). Deterministic."""
import math
from pxlib import Canvas, W, OUT_H, ramp, dither, prand, vnoise, shade

H = OUT_H


# ---------------------------------------------------------------- helpers
def vgrad(cv, top, bottom, y0=0, y1=H, colors=None):
    """Dithered vertical gradient between a list of colours."""
    cols = colors or [top, bottom]
    for y in range(y0, y1):
        t = (y - y0) / max(1, (y1 - y0 - 1))
        for x in range(W):
            cv.set(x, y, ramp(x, y, t, cols))


def rot(cx, cy, ang):
    ca, sa = math.cos(ang), math.sin(ang)

    def T(u, v):
        return cx + u * ca - v * sa, cy + u * sa + v * ca
    return T


def dot(cv, x, y, c, owner=None):
    cv.set(int(round(x)), int(round(y)), c, owner)


def seg(cv, x0, y0, x1, y1, c, owner=None, step=0.25):
    n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
    for i in range(n + 1):
        t = i / n
        dot(cv, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c, owner)


def disc(cv, cx, cy, r, c, owner=None):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                cv.set(x, y, c, owner)


def bubble(cv, cx, cy, r, rim, hi, fill=None):
    """Small water bubble: rim ring, optional tinted fill, one highlight dot."""
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                if d > r - 1.0:
                    cv.set(x, y, rim)
                elif fill is not None:
                    cv.set(x, y, fill)
    dot(cv, cx - r * 0.45, cy - r * 0.45, hi)


# ================================================================ 1. 風神の弓
def wind_gods_bow():
    BG = [(16, 22, 30), (22, 30, 38), (26, 36, 42)]
    BOW, BOW_SH = (226, 218, 196), (140, 132, 114)
    STRING, GOLD = (150, 166, 160), (222, 178, 80)
    WF, WF2, WB = (196, 236, 222), (120, 186, 170), (52, 84, 82)
    CORE, G1, G2, G3 = (250, 255, 250), (176, 238, 222), (84, 150, 140), (40, 70, 70)
    cv = Canvas(BG[0])
    vgrad(cv, None, None, colors=BG)
    # 矢は右上へ。局所座標 u=矢の進む向き, v=弓の長さ方向
    T = rot(24.0, 31.0, -math.radians(38))
    S0, HALF, GRIPV, D = -3.0, 27.0, 3.5, 11.5
    p = math.log(0.5) / math.log((HALF + GRIPV) / (2 * HALF))

    def bow_u(v):
        s = (v + HALF) / (2 * HALF)
        return S0 + D * math.sin(math.pi * (max(0.0, min(1.0, s)) ** p))

    A, K = 3.0, 2 * math.pi / 17.0

    def strands(front):
        v = -HALF + 1
        while v <= HALF - 1:
            bu = bow_u(v)
            fade = min(1.0, (v + HALF) / 4, (HALF - v) / 4)
            for ph in (0.0, math.pi):
                a = K * v + ph
                if (math.cos(a) > 0) != front:
                    continue
                c = (WF if math.cos(a) > 0.55 else WF2) if front else WB
                dot(cv, *T(bu + A * fade * math.sin(a), v), c)
            v += 0.2

    strands(False)
    v = -HALF
    while v <= HALF:
        bu = bow_u(v)
        tip = min(v + HALF, HALF - v)
        if tip < 2.5:
            bu += (2.5 - tip) * 0.6
        dot(cv, *T(bu, v), BOW)
        if tip > 1.5:
            dot(cv, *T(bu - 1, v), BOW_SH)
        v += 0.2
    for v in (GRIPV - 2, GRIPV - 1, GRIPV, GRIPV + 1):
        bu = bow_u(v)
        dot(cv, *T(bu, v), GOLD)
        dot(cv, *T(bu - 1, v), GOLD)
    strands(True)
    # 弦を V 字に引き絞る
    NU = S0 - 12
    seg(cv, *T(S0, -HALF), *T(NU, GRIPV), STRING)
    seg(cv, *T(S0, HALF), *T(NU, GRIPV), STRING)
    # 風の矢
    HB, TIPU = 22.0, 31.0
    u = NU
    while u <= HB:
        k = int((u - NU) // 3) % 2
        dot(cv, *T(u, GRIPV), CORE if k == 0 else G1)
        u += 0.25
    for ph in (0.0, math.pi):
        u = NU + 1
        while u < HB - 1:
            a = (u - NU) * 0.7 + ph
            off = 1.7 * math.sin(a)
            if abs(off) > 0.6:
                dot(cv, *T(u, GRIPV + off), G1 if math.cos(a) > 0 else G2)
            u += 0.25
    u = HB
    while u <= TIPU:
        t = (u - HB) / (TIPU - HB)
        half = 4.6 * (1 - t) ** 0.85
        w = -half
        while w <= half:
            dot(cv, *T(u, GRIPV + w), G1 if abs(w) > half - 1.0 else G3)
            w += 0.34
        dot(cv, *T(u, GRIPV), CORE)
        u += 0.25
    for sgn in (-1, 1):
        dot(cv, *T(HB - 1, GRIPV + sgn * 4), G1)
        dot(cv, *T(HB - 2, GRIPV + sgn * 5), G2)
    dot(cv, *T(TIPU + 1, GRIPV), G1)
    # 矢羽：弦の後ろへ流れ出る風
    for sgn in (-1, 1):
        for length, lift in ((6, 2.2), (5, 4.0)):
            t = 0.0
            while t < length:
                uu = NU + 4 - t
                vv = GRIPV + sgn * (lift * min(1.0, t / 3.0) + 0.25 * t)
                dot(cv, *T(uu, vv), G1 if t < 2 else (G2 if t < length - 2 else G3))
                t += 0.3
    return cv


# ================================================================ 6. クロスボウ
def crossbow():
    BG = [(20, 18, 22), (30, 27, 30), (38, 34, 36)]
    WOOD = [(58, 34, 20), (96, 58, 32), (140, 90, 50), (178, 124, 72)]
    STEEL = [(40, 44, 52), (86, 94, 106), (150, 160, 172), (214, 222, 230)]
    STRING = (196, 186, 160)
    OUT = (14, 10, 10)
    cv = Canvas(BG[0])
    vgrad(cv, None, None, colors=BG)
    # 石壁の目地をうっすら
    for y in range(H):
        for x in range(W):
            row = y // 9
            if y % 9 == 0 or (x + (row % 2) * 7) % 14 == 0:
                if cv.get(x, y) != BG[0]:
                    cv.set(x, y, BG[0])
    ang = -math.radians(40)           # 右上を向く
    T = rot(26, 31, ang)

    def box(u0, u1, v0, v1, tones, owner):
        """Filled, lit-from-top-left bar in local coords."""
        u = u0
        while u <= u1:
            v = v0
            while v <= v1:
                t = (v - v0) / max(0.01, v1 - v0)
                c = tones[3] if t < 0.2 else (tones[2] if t < 0.55 else (tones[1] if t < 0.85 else tones[0]))
                dot(cv, *T(u, v), c, owner)
                v += 0.3
            u += 0.3

    # 銃床（ストック）と台座
    box(-22, 8, -1.6, 1.6, WOOD, "stock")
    box(-24, -17, -2.6, 2.4, WOOD, "stock")      # 肩当て
    box(-9, -4, 1.6, 5.0, WOOD, "stock")          # 握り
    cv.outline_outside({"stock"}, OUT)
    # 弓（リム）：前方で左右に張る鋼
    LU = 6.0
    for sgn in (-1, 1):
        v = 0.0
        while v <= 17:
            u = LU - 0.018 * v * v * 1.6
            for w in (-0.6, 0.0, 0.6):
                dot(cv, *T(u + w, sgn * v), STEEL[2] if w < 0 else STEEL[1], "limb")
            v += 0.2
        dot(cv, *T(LU - 0.018 * 289 * 1.6, sgn * 17.2), STEEL[3], "limb")
    # 弦：引いた状態でナット（-6）まで
    NUT = -6.0
    tipu = LU - 0.018 * 289 * 1.6
    seg(cv, *T(tipu, -17), *T(NUT, -1.0), STRING)
    seg(cv, *T(tipu, 17), *T(NUT, 1.0), STRING)
    # 矢（ボルト）2本：銃身の上に平行に装填
    for off in (-1.7, 1.7):
        u = NUT - 1
        while u <= 16:
            dot(cv, *T(u, off), STEEL[2], "bolt")
            u += 0.25
        # 鏃
        for k in range(5):
            half = (4 - k) * 0.45
            w = -half
            while w <= half:
                dot(cv, *T(20 - k, off + w), STEEL[3] if k < 2 else STEEL[2], "bolt")
                w += 0.3
        # 矢羽（赤）
        for k in range(3):
            dot(cv, *T(NUT - 1 + k, off + (0.9 if off > 0 else -0.9)), (170, 40, 40))
    # 鋼の金具
    box(4, 8, -2.2, 2.2, STEEL, "metal")
    box(-8, -6, -2.0, 2.0, STEEL, "metal")
    cv.outline_outside({"metal", "limb"}, OUT)
    return cv


# ================================================================ 7. ムラマサ
def muramasa():
    BG = [(10, 6, 14), (18, 10, 24), (26, 12, 30)]
    BLADE = [(96, 104, 120), (168, 176, 190), (224, 230, 238), (250, 252, 255)]
    HAMON = (236, 240, 248)
    TSUKA, ITO, SAME = (34, 20, 26), (70, 26, 40), (204, 196, 180)
    TSUBA = [(40, 34, 30), (92, 80, 60), (156, 132, 84)]
    AURA = [(150, 30, 70), (96, 20, 60), (58, 14, 44)]
    AURA_HI = (230, 70, 110)
    OUT = (6, 4, 8)
    cv = Canvas(BG[0])
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - 26, y - 28) / 34
            cv.set(x, y, ramp(x, y, d, BG[::-1]))
    # 刀は垂直（切っ先が上）。わずかな反り
    CX = 25.0
    TIP, HABAKI, TSUBA_Y, END = 2, 41, 43, 57

    def blade_x(y):
        t = (HABAKI - y) / (HABAKI - TIP)
        return CX + 2.2 * t * t

    # 螺旋の妖気：二筋の煙が刀身を巻き上がる。奥を通る部分は先に描き、刀身で隠す
    def aura(front):
        for ph in (0.0, math.pi):
            y = END + 1.0
            while y >= TIP - 3:
                t = (END + 1 - y) / (END + 1 - TIP)
                r = 3.5 + 6.0 * math.sin(math.pi * min(1.0, t * 1.02)) ** 0.8
                a = y * 0.19 + ph
                if (math.cos(a) > 0) == front:
                    x = blade_x(max(TIP, min(HABAKI, y))) + r * math.sin(a)
                    if front:
                        dot(cv, x, y, AURA_HI if math.cos(a) > 0.75 else AURA[0], "aura")
                        dot(cv, x + (1 if math.sin(a) > 0 else -1), y + 1, AURA[1], "aura")
                    else:
                        dot(cv, x, y, AURA[2], "aura")
                y -= 0.2
    aura(False)
    # 刀身：幅4px。峰（左）暗→地鉄→刃文→刃（右）明。切っ先は斜めに細る
    for y in range(TIP, HABAKI + 1):
        bx = blade_x(y)
        w = 4 if y > TIP + 4 else max(1, (y - TIP + 1) * 4 // 5)
        x0 = int(round(bx)) - 2
        for i in range(w):
            x = x0 + (4 - w) + i
            if i == 0:
                tone = BLADE[0]
            elif i == w - 1:
                tone = BLADE[3]
            else:
                tone = BLADE[1] if i < w - 2 else BLADE[2]
            cv.set(x, y, tone, "blade")
        if y > TIP + 5 and math.sin(y * 1.1) > -0.2:
            cv.set(x0 + 2, y, HAMON, "blade")
    # はばき・鍔
    for x in range(int(CX) - 2, int(CX) + 3):
        cv.set(x, HABAKI + 1, (190, 150, 70), "fit")
    for y in range(TSUBA_Y, TSUBA_Y + 2):
        for x in range(int(CX) - 5, int(CX) + 6):
            cv.set(x, y, TSUBA[2] if y == TSUBA_Y else TSUBA[1], "fit")
    cv.set(int(CX) - 5, TSUBA_Y + 1, TSUBA[0], "fit")
    cv.set(int(CX) + 5, TSUBA_Y + 1, TSUBA[0], "fit")
    # 柄：菱形の柄巻き
    for y in range(TSUBA_Y + 2, END + 1):
        for i in range(3):
            x = int(CX) - 1 + i
            k = (y + i) % 4
            c = SAME if k == 0 else (ITO if k in (1, 3) else TSUKA)
            if y == END:
                c = TSUBA[1]
            cv.set(x, y, c, "hilt")
    cv.outline_outside({"blade", "fit", "hilt"}, OUT)
    aura(True)
    return cv


# ================================================================ 8. 冷たい炎
def cold_flame():
    BG = [(8, 12, 26), (12, 20, 38), (18, 30, 52)]
    ICE = [(60, 100, 170), (110, 170, 230), (178, 224, 250), (240, 252, 255)]
    SNOW = [(120, 140, 170), (170, 190, 214), (214, 226, 240)]
    cv = Canvas(BG[0])
    vgrad(cv, None, None, colors=BG)
    # 雪の地面
    for x in range(W):
        top = 48 + int(round(1.5 * math.sin(x * 0.35) + 1.0 * math.sin(x * 0.9)))
        for y in range(top, H):
            cv.set(x, y, ramp(x, y, (y - top) / 12, SNOW[::-1]))
    # うねる炎：中心線を S 字にくねらせ、幅は根元が太く先で細い。
    # 複数の舌を重ね、内側ほど明るい（青白い芯）
    base, top_y = 49.0, 6.0

    def tongue(cx, height, width, phase, amp, lean):
        for y in range(int(base - height), int(base) + 1):
            v = (base - y) / height
            c = cx + amp * math.sin(v * 5.2 + phase) * (0.3 + v) + lean * v * v * 10
            w = width * (1 - v) ** 0.7 * (0.75 + 0.5 * math.sin(v * 3.0 + phase) ** 2)
            for x in range(int(c - w) - 1, int(c + w) + 2):
                d = abs(x + 0.5 - c) / max(w, 0.3)
                if d > 1:
                    continue
                f = (1 - d) * (1 - v * 0.6)
                col = ICE[3] if f > 0.62 else (ICE[2] if f > 0.4 else (ICE[1] if f > 0.18 else ICE[0]))
                old = cv.get(x, y)
                if old in ICE and ICE.index(old) >= ICE.index(col):
                    continue
                cv.set(x, y, col, "flame")

    tongue(26, 43, 9.0, 0.0, 3.2, 0.0)
    tongue(20, 30, 5.0, 1.7, 2.4, -0.12)
    tongue(33, 33, 5.2, 3.1, 2.6, 0.14)
    tongue(27, 22, 4.0, 4.4, 1.6, 0.05)
    # 火の粉ならぬ氷の粒が舞い上がる
    for i in range(10):
        x = 10 + prand(i, 1, 9) * 33
        y = 4 + prand(i, 2, 9) * 30
        if cv.owner(int(x), int(y)) != "flame":
            dot(cv, x, y, ICE[2] if i % 3 else ICE[3])
    cv.glow({"flame"}, [(34, 60, 104), None], 1, seed=3)
    return cv


# ================================================================ 2. 魔術書
def spellbook():
    BG = [(8, 8, 20), (14, 14, 32), (20, 20, 44)]
    STONE = [(34, 34, 44), (58, 58, 72), (90, 90, 106), (124, 124, 140)]
    PAGE = [(150, 132, 104), (196, 180, 146), (232, 220, 188), (250, 244, 222)]
    COVER = [(40, 16, 20), (84, 30, 34), (122, 48, 44)]
    INK = (120, 96, 80)
    RUNE = [(40, 110, 120), (80, 196, 196), (170, 246, 236), (240, 255, 250)]
    OUT = (6, 6, 12)
    cv = Canvas(BG[0])
    vgrad(cv, None, None, colors=BG)
    # 台座：柱と天板（上面に奥行き）
    for y in range(44, H):
        for x in range(19, 34):
            t = (x - 19) / 14
            cv.set(x, y, STONE[2] if t < 0.25 else (STONE[1] if t < 0.75 else STONE[0]), "ped")
    for y in range(52, H):
        for x in range(15, 38):
            t = (x - 15) / 22
            cv.set(x, y, STONE[3] if y == 52 else (STONE[2] if t < 0.3 else (STONE[1] if t < 0.8 else STONE[0])), "ped")
    for y in range(40, 45):
        for x in range(11, 42):
            top = y < 42
            cv.set(x, y, STONE[3] if top else (STONE[2] if x < 20 else STONE[1]), "ped")
    cv.outline_outside({"ped"}, OUT)
    # 本：逆八の字（V字）に開いたページ。背は中央下、ページは左右上へ反り上がる
    SPX, SPY = 26, 40
    for side in (-1, 1):
        # 表紙（ページの下に少しはみ出す）
        cv.poly([(SPX, SPY), (SPX + side * 15, SPY - 8), (SPX + side * 16, SPY - 6), (SPX + side * 1, SPY + 1)],
                lambda x, y: COVER[1], "book")
        # 紙束
        pts = [(SPX, SPY - 1), (SPX + side * 14, SPY - 9), (SPX + side * 14, SPY - 17), (SPX, SPY - 9)]
        cv.poly(pts, lambda x, y, s=side: PAGE[2] if (x - SPX) * s > 9 else (PAGE[1] if (x - SPX) * s > 3 else PAGE[0]), "book")
        # 行（文字）の線
        for k in range(4):
            y0 = SPY - 13 + k * 2
            for i in range(3, 12):
                if (i + k) % 5 != 0:
                    xx = SPX + side * i
                    yy = y0 - (i * 8) // 14 + 4
                    if cv.owner(xx, yy) == "book":
                        cv.set(xx, yy, INK)
    cv.outline_outside({"book"}, OUT)
    # 魔法陣：本の上に水平な楕円として現れる
    CX, CY = 26, 21
    for y in range(CY - 8, CY + 9):
        for x in range(2, 51):
            u, v = (x + 0.5 - CX) / 21.0, (y + 0.5 - CY) / 7.0
            r = math.sqrt(u * u + v * v)
            if 0.92 < r <= 1.0 or 0.62 < r <= 0.7:
                cv.set(x, y, RUNE[2] if v < 0 else RUNE[1], "rune")
            elif r <= 0.62 and abs(u) < 0.05:
                cv.set(x, y, RUNE[1], "rune")
            elif 0.7 < r <= 0.92 and (int((math.atan2(v, u) + math.pi) * 6) % 3 == 0) and (x + y) % 2 == 0:
                cv.set(x, y, RUNE[0], "rune")
    for k in range(6):
        a = k * math.pi / 3
        dot(cv, CX + 17.5 * math.cos(a), CY + 5.8 * math.sin(a), RUNE[3], "rune")
    # 本から魔法陣へ立ちのぼる光と、上へ昇っていくオーラ
    for x in range(14, 39):
        for y in range(6, SPY - 10):
            d = abs(x + 0.5 - 26) / 12.0
            t = (SPY - 10 - y) / (SPY - 16)
            if d < 1 and prand(x, y // 2, 5) < (1 - d) * 0.35 * (1 - t * 0.5) and cv.owner(x, y) is None:
                cv.set(x, y, RUNE[0] if prand(x, y, 6) < 0.7 else RUNE[1])
    for i in range(7):
        x = 12 + i * 5 + int(prand(i, 1, 4) * 3)
        ln = 5 + int(prand(i, 2, 4) * 6)
        y0 = 13 - int(prand(i, 3, 4) * 6)
        for k in range(ln):
            dot(cv, x + 0.8 * math.sin(k * 0.8 + i), y0 - k, RUNE[2] if k < 2 else RUNE[1] if k < ln - 2 else RUNE[0])
    return cv


# ================================================================ 3. 滋養
def nourishment():
    WALL = [(26, 18, 14), (36, 26, 20)]
    WOOD = [(70, 40, 22), (102, 62, 34), (138, 88, 48), (170, 116, 66)]
    WOOD_EDGE = [(46, 26, 14), (70, 40, 22)]
    PLATE = [(96, 100, 110), (170, 174, 182), (214, 216, 222), (246, 246, 250)]
    MEAT = [(70, 26, 16), (122, 46, 24), (170, 76, 36), (206, 114, 58), (238, 168, 106)]
    BONE = [(150, 140, 120), (206, 198, 176), (240, 236, 222)]
    STEAM = [(120, 100, 90), (170, 150, 140)]
    OUT = (16, 8, 6)
    cv = Canvas(WALL[0])
    vgrad(cv, None, None, 0, 22, colors=WALL)
    # 机：上面は奥へ細る板目（遠いほど暗い）、手前に厚み
    for y in range(20, 53):
        t = (y - 20) / 32
        for x in range(W):
            plank = int((x - 26) / (5 + 7 * t) + 20) % 2
            g = vnoise(x * (1.2 - 0.6 * t), y * 3, 3, 11 + plank)
            tone = 0.15 + 0.7 * t + (g - 0.5) * 0.35
            c = ramp(x, y, max(0, min(1, tone)), WOOD)
            if abs(((x - 26) / (5 + 7 * t) + 20) % 1) < 0.06:
                c = WOOD[0]
            cv.set(x, y, c)
    for y in range(53, H):
        for x in range(W):
            cv.set(x, y, WOOD_EDGE[1] if y < 55 else WOOD_EDGE[0])
    for x in range(W):
        cv.set(x, 52, WOOD[3])
    # 皿の影 → 皿（楕円、縁の厚みと内側のくぼみ）
    cv.ellipse(27, 41, 21, 8, lambda *a: WOOD[0])
    cv.ellipse(26, 38, 21, 8, shade((PLATE[3], PLATE[2], PLATE[1], PLATE[0])), "plate")
    cv.ellipse(26, 38.5, 16, 5.6, lambda x, y, u, v, r: PLATE[1] if v < -0.2 else PLATE[2], "plate")
    cv.outline_outside({"plate"}, OUT)
    # 肉の影
    cv.ellipse(25, 40, 12, 3.5, lambda *a: PLATE[0])
    # 骨（奥から手前右上へ突き出す）
    for i in range(11):
        x, y = 30 + i * 1.0, 31 - i * 0.9
        disc(cv, x, y, 1.8, BONE[1], "bone")
        dot(cv, x - 0.5, y - 1.0, BONE[2], "bone")
        dot(cv, x + 0.6, y + 1.2, BONE[0], "bone")
    for cx, cy in ((42.5, 21.0), (40.2, 19.2)):
        disc(cv, cx, cy, 2.4, BONE[1], "bone")
        dot(cv, cx - 1, cy - 1, BONE[2], "bone")
    dot(cv, 43.5, 22.5, BONE[0], "bone")
    # 肉：丸みのある塊。上から光、下と右が影、表面に焼き色の筋
    def meat_fn(x, y, u, v, r):
        s = -(u * -0.5 + v * -0.85)
        if r > 0.8 and s < 0:
            c = MEAT[0]
        elif s < -0.35:
            c = MEAT[1]
        elif s < 0.15:
            c = MEAT[2]
        elif s < 0.55:
            c = MEAT[3]
        else:
            c = MEAT[4] if r < 0.35 else MEAT[3]
        if (x * 2 + y * 3) % 7 == 0 and s < 0.5 and r < 0.85:
            c = MEAT[1] if c != MEAT[0] else c
        return c
    cv.ellipse(24, 32, 11.5, 8.5, meat_fn, "meat")
    cv.outline_outside({"meat", "bone"}, OUT)
    # 湯気
    for k, x0 in enumerate((18, 24, 30)):
        for i in range(9):
            dot(cv, x0 + 1.5 * math.sin(i * 0.7 + k), 20 - i, STEAM[1] if i < 5 else STEAM[0])
    return cv


# ================================================================ 4. 海契約
def sea_pact():
    SKY = [(6, 10, 24), (12, 20, 40), (22, 36, 60)]
    SEA = [(10, 30, 50), (18, 50, 74), (32, 80, 104), (70, 130, 150)]
    FOAM = (170, 220, 224)
    STONE = [(30, 34, 40), (54, 60, 70), (84, 92, 104), (120, 128, 140)]
    RUNE = [(30, 110, 120), (70, 200, 200), (180, 250, 240)]
    PRONG = [(40, 60, 64), (92, 130, 130), (160, 200, 196), (224, 246, 240)]
    GOLD = [(120, 84, 30), (200, 150, 60)]
    BUB_RIM, BUB_HI, BUB_FILL = (150, 220, 226), (250, 255, 255), (40, 90, 110)
    OUT = (4, 8, 14)
    cv = Canvas(SKY[0])
    vgrad(cv, None, None, 0, 14, colors=SKY)
    # 奥に広がる海：水平線から手前へ明るく、波頭の筋
    for y in range(14, 34):
        t = (y - 14) / 20
        for x in range(W):
            c = ramp(x, y, t * 0.9, SEA)
            w = math.sin(x * (0.5 - 0.3 * t) + y * 1.7) + math.sin(x * 0.23 - y * 0.9)
            if w > 1.55 - t * 0.3:
                c = FOAM if t > 0.4 and w > 1.75 else SEA[3]
            cv.set(x, y, c)
    for x in range(W):
        cv.set(x, 14, SEA[3])
    # 祭壇：手前へ張り出す石の天板（台形）と側面
    top = [(6, 34), (46, 34), (53, 47), (0, 47)]
    cv.poly(top, lambda x, y: ramp(x, y, (y - 34) / 13 * 0.8 + 0.1, STONE[1:]), "altar")
    for y in range(47, H):
        for x in range(W):
            cv.set(x, y, STONE[1] if y == 47 else STONE[0], "altar")
    for x in range(W):
        cv.set(x, 34, STONE[3], "altar")
    # 魔法陣（天板上の楕円）
    CX, CY = 26, 41
    for y in range(34, 48):
        for x in range(3, 50):
            u, v = (x + 0.5 - CX) / 20.0, (y + 0.5 - CY) / 5.8
            r = math.sqrt(u * u + v * v)
            if 0.9 < r <= 1.0 or 0.55 < r <= 0.64:
                cv.set(x, y, RUNE[1])
            elif 0.64 < r <= 0.9 and int((math.atan2(v, u) + math.pi) * 5) % 2 == 0 and (x + y) % 2 == 0:
                cv.set(x, y, RUNE[0])
    for k in range(8):
        a = k * math.pi / 4
        dot(cv, CX + 15.5 * math.cos(a), CY + 4.5 * math.sin(a), RUNE[2])
    # 三叉の矛：太い柄（3px）と、根元が太い三つの穂先
    SX = 25
    for y in range(10, 43):
        cv.set(SX - 1, y, PRONG[1], "spear")
        cv.set(SX, y, PRONG[2], "spear")
        cv.set(SX + 1, y, PRONG[0], "spear")
    for y in (24, 25, 32, 33):
        for x in range(SX - 1, SX + 2):
            cv.set(x, y, GOLD[1] if y % 2 == 0 else GOLD[0], "spear")
    # 横木
    for x in range(SX - 9, SX + 10):
        cv.set(x, 11, PRONG[2], "spear")
        cv.set(x, 12, PRONG[1], "spear")
    for px_, h in ((SX - 9, 9), (SX + 9, 9), (SX, 12)):
        for k in range(h):
            y = 10 - k
            w = 1 if k < h - 3 else 0
            for dx in range(-1, 2):
                if abs(dx) <= w or dx == 0:
                    cv.set(px_ + dx, y, PRONG[2] if dx < 0 else (PRONG[3] if dx == 0 else PRONG[1]), "spear")
        cv.set(px_, 10 - h, PRONG[3], "spear")
        # 返し
        cv.set(px_ + (1 if px_ >= SX else -1) * 2, 10 - h + 3, PRONG[2], "spear")
    cv.outline_outside({"spear"}, OUT)
    # 刺さった根元のひび
    for dx, dy in ((-3, 1), (-5, 2), (3, 1), (5, 1), (6, 2)):
        dot(cv, SX + dx, 42 + dy, STONE[0])
    # 矛のまわりを舞う水泡
    for (bx, by, r) in ((14, 22, 2.6), (37, 19, 2.2), (11, 31, 1.6), (40, 29, 2.8), (19, 14, 1.4),
                        (33, 7, 1.6), (15, 5, 1.2), (43, 12, 1.3), (32, 26, 1.2), (18, 27, 1.0)):
        bubble(cv, bx, by, r, BUB_RIM, BUB_HI, BUB_FILL if r > 2 else None)
    return cv


# ================================================================ 5. えら呼吸
def gill_breathing():
    SEA = [(4, 18, 34), (8, 34, 58), (16, 60, 88), (30, 96, 120)]
    RAY = (40, 110, 130)
    SKIN = [(30, 70, 84), (54, 112, 124), (92, 158, 162), (150, 208, 204)]
    FIN = [(20, 90, 110), (60, 170, 180)]
    HAIR = [(10, 30, 40), (24, 56, 70)]
    GILL = (180, 60, 70)
    BUB = (170, 230, 236)
    OUT = (2, 12, 22)
    cv = Canvas(SEA[0])
    vgrad(cv, None, None, colors=SEA[::-1])
    # 水面から差し込む光の筋
    for k, x0 in enumerate((8, 20, 34, 46)):
        for y in range(0, 44):
            x = x0 + y * 0.35
            if prand(k, y // 3, 2) < 0.8 and dither(int(x), y, 0.5 - y / 90):
                cv.set(int(x), y, RAY)
    # 泳ぐ姿：右上へ向かって伸びやかに。頭は右上、脚は左下へ流れる
    Z = 1.45
    T0 = rot(27, 30, -math.radians(32))

    def T(u, v):
        return T0(u * Z, v * Z)

    def limb(u0, v0, u1, v1, r0, r1, owner="body"):
        n = 24
        for i in range(n + 1):
            t = i / n
            u, v = u0 + (u1 - u0) * t, v0 + (v1 - v0) * t
            r = (r0 + (r1 - r0) * t) * Z
            x, y = T(u, v)
            cv.ellipse(x, y, r, r, lambda xx, yy, a, b, rr: SKIN[2] if b < -0.2 else (SKIN[1] if b < 0.5 else SKIN[0]), owner)

    # 奥の腕：体に沿って後ろへかいた直後
    limb(7, 2.2, 1, 4.6, 1.1, 0.9)
    # 胴（胸→腰）
    limb(-1, 0, 9, 0, 2.6, 2.9)
    # 脚：開いてキックの途中
    limb(-1, -1.0, -11, -4.2, 1.8, 1.0)
    limb(-1, 1.0, -9, 4.4, 1.8, 1.0)
    # 手前の腕：頭の先へ伸ばして水をつかむ
    limb(8, -2.0, 18, -5.5, 1.1, 0.8)
    # 頭
    hx, hy = T(12.5, 0.6)
    cv.ellipse(hx, hy, 2.3 * Z, 2.1 * Z, shade((SKIN[3], SKIN[2], SKIN[1], SKIN[0])), "body")
    cv.outline_outside({"body"}, OUT)
    # 髪は後ろへなびく
    for i in range(10):
        for w in (-1.5, -0.5, 0.5):
            x, y = T(12 - i * 0.9, 0.6 + w * 0.8 + 0.7 * math.sin(i * 0.8))
            dot(cv, x, y, HAIR[1] if w > -1 else HAIR[0])
    # 脚の先の水かき（ひれ）、背びれ
    for sgn, (fu, fv) in ((-1, (-11, -4.2)), (1, (-9, 4.4))):
        for k in range(5):
            for w in range(-k, k + 1):
                x, y = T(fu - 1.2 - k * 0.9, fv + w * 0.55)
                dot(cv, x, y, FIN[1] if w < 0 else FIN[0])
    for k in range(6):
        x, y = T(1 + k * 1.1, -2.8 - (3 - abs(k - 2.5)) * 0.5)
        dot(cv, x, y, FIN[1])
    # 首のえら
    for k in range(3):
        x, y = T(10.4 + k * 0.3, -0.4 + k * 0.7)
        dot(cv, x, y, GILL)
    # 目
    ex, ey = T(13.6, 0.0)
    dot(cv, ex, ey, (230, 250, 240))
    # 泡（口元から後ろへ）
    for i, (du, dv, r) in enumerate(((17, -3.5, 1.0), (19, -6, 1.4), (22, -9, 1.2), (5, -8, 1.6), (-6, -9, 1.2), (-10, 7, 1.0))):
        x, y = T(du, dv)
        bubble(cv, x, y, r, BUB, (255, 255, 255))
    return cv


# ================================================================ 9. 女神の加護
def goddess_blessing():
    BG = [(10, 10, 24), (16, 18, 40), (24, 26, 56)]
    STONE = [(70, 56, 40), (120, 98, 66), (170, 142, 96), (210, 184, 130)]
    LAPIS = [(20, 40, 100), (40, 76, 160)]
    CAT = [(52, 50, 60), (96, 92, 104), (140, 136, 148), (190, 186, 196)]
    EYE = (220, 200, 90)
    ARM = [(70, 42, 30), (112, 70, 46), (156, 104, 70), (190, 138, 96)]
    GOLD = [(140, 100, 30), (214, 170, 70), (250, 224, 140)]
    OUT = (6, 6, 12)
    cv = Canvas(BG[0])
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - 26, y - 34) / 32
            cv.set(x, y, ramp(x, y, d, BG[::-1]))
    # 台座：天板（上面）と前面、ラピスの帯
    cv.poly([(10, 42), (43, 42), (46, 46), (7, 46)], lambda x, y: STONE[3] if y < 44 else STONE[2], "ped")
    for y in range(46, H):
        for x in range(9, 45):
            t = (x - 9) / 35
            c = STONE[2] if t < 0.2 else (STONE[1] if t < 0.8 else STONE[0])
            if 49 <= y <= 50:
                c = LAPIS[1] if (x // 3) % 2 else GOLD[1]
            cv.set(x, y, c, "ped")
    cv.outline_outside({"ped"}, OUT)
    # 横になった猫（香箱座り気味、頭は左、尾は手前に巻く）
    cv.ellipse(28, 38, 11, 4.8, shade((CAT[3], CAT[2], CAT[1], CAT[0])), "cat")
    cv.ellipse(17, 34.5, 4.8, 4.3, shade((CAT[3], CAT[2], CAT[1], CAT[0])), "cat")
    for ex, ey in ((14, 29.5), (20, 29.5)):     # 耳
        cv.poly([(ex - 1.5, ey + 2), (ex, ey - 1.5), (ex + 1.5, ey + 2)], lambda x, y: CAT[1], "cat")
    for i in range(12):                      # 尾
        dot(cv, 37 - i * 1.2, 42 - 0.8 * math.sin(i * 0.5), CAT[1], "cat")
    cv.outline_outside({"cat"}, OUT)
    dot(cv, 15.5, 34, EYE)
    dot(cv, 18.5, 34, EYE)
    # 猫を包む淡い光
    # バステトの腕：画面の上の左右から降りてきて、猫の両脇で手のひらを内へ向け、包み込む
    def arm(side):
        p0 = (26 + side * 30, -4)          # 画面外（上の角）
        p1 = (26 + side * 25, 26)          # 外へふくらむ
        p2 = (26 + side * 15, 39)          # 猫の脇
        pts = []
        n = 60
        for i in range(n + 1):
            t = i / n
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
            pts.append((x, y, 3.2 - 1.2 * t))
        for (x, y, r) in pts:
            cv.ellipse(x, y, r, r, lambda xx, yy, u, v, rr, s=side: ARM[3] if u * s < -0.4 else (ARM[2] if u * s < 0.3 else ARM[1]), "arm")
        for (x, y, r) in pts[22:25] + pts[44:46]:          # 金の腕輪
            cv.ellipse(x, y, r + 0.4, r + 0.4, lambda xx, yy, u, v, rr: GOLD[2] if v < -0.2 else GOLD[1], "arm")
        # 手のひら：猫の脇で内側へ向け、指先は猫の背を覆うように上へ
        hx, hy, _ = pts[-1]
        cv.ellipse(hx - side * 1.0, hy - 0.5, 2.4, 2.8, lambda xx, yy, u, v, rr, s=side: ARM[2] if u * s > 0 else ARM[1], "arm")
        for k in range(4):
            fy = hy - 3 + k * 1.4
            for i in range(5 - (k % 3)):
                dot(cv, hx - side * (2.5 + i * 0.9), fy - i * 0.35, ARM[3] if i < 2 else ARM[2], "arm")
        # 親指は下から猫を支える
        for i in range(4):
            dot(cv, hx - side * (1 + i), hy + 2.5, ARM[2], "arm")
    arm(-1)
    arm(1)
    cv.outline_outside({"arm"}, OUT)
    return cv


# ================================================================ 10. 触手
def tentacle():
    SKY = [(6, 8, 30), (12, 16, 54), (20, 28, 80)]          # 藍
    SEA = [(10, 30, 70), (20, 60, 110), (40, 100, 150)]     # 青・水
    FOAM = [(120, 180, 210), (200, 236, 246)]
    TENT = [(20, 30, 70), (36, 56, 118), (60, 96, 170), (104, 150, 214)]
    SUCK = [(90, 150, 110), (150, 210, 150), (206, 246, 196)]  # 薄緑のアクセント
    OUT = (4, 4, 18)
    cv = Canvas(SKY[0])
    vgrad(cv, None, None, 0, 40, colors=SKY)
    for y in range(40, H):
        t = (y - 40) / 19
        for x in range(W):
            c = ramp(x, y, t, SEA[::-1][::-1])
            if math.sin(x * 0.6 + y * 1.3) + math.sin(x * 0.21 - y) > 1.6:
                c = SEA[2]
            cv.set(x, y, c)
    for x in range(W):
        cv.set(x, 40, FOAM[0])
    # 触手：海面から太く生え、S字にうねって先が巻く
    def spine(t):
        # t=0 海面, t=1 先端
        x = 30 - 12 * math.sin(t * 2.6) + 6 * t
        y = 46 - 44 * t
        return x, y

    def radius(t):
        return 6.2 * (1 - t) ** 0.9 + 0.6

    n = 220
    pts = [spine(i / n) for i in range(n + 1)]
    for i in range(n + 1):
        t = i / n
        x, y = pts[i]
        r = radius(t)
        # 進行方向の法線
        x2, y2 = pts[min(n, i + 1)]
        tx, ty = x2 - x, y2 - y
        ln = math.hypot(tx, ty) or 1
        nx, ny = -ty / ln, tx / ln
        w = -r
        while w <= r:
            s = w / r                       # -1..1（左が影、右が光）
            c = TENT[3] if s > 0.55 else (TENT[2] if s > -0.1 else (TENT[1] if s > -0.7 else TENT[0]))
            dot(cv, x + nx * w, y + ny * w, c, "tent")
            w += 0.4
    # 吸盤：内側（左側）に沿って並ぶ
    for k in range(1, 12):
        t = k / 13
        x, y = spine(t)
        r = radius(t)
        x2, y2 = spine(t + 0.01)
        tx, ty = x2 - x, y2 - y
        ln = math.hypot(tx, ty) or 1
        nx, ny = -ty / ln, tx / ln
        sx, sy = x - nx * r * 0.7, y - ny * r * 0.7
        rr = max(0.7, r * 0.32)
        disc(cv, sx, sy, rr, SUCK[0], "tent")
        dot(cv, sx, sy, SUCK[1], "tent")
        if rr > 1.2:
            dot(cv, sx - 0.5, sy - 0.5, SUCK[2], "tent")
    # 先端の巻き
    tx, ty = spine(1.0)
    for i in range(18):
        a = i * 0.45
        dot(cv, tx + 2.6 * math.cos(a) * (1 - i / 22) + 2.4, ty + 2.6 * math.sin(a) * (1 - i / 22) + 1, TENT[2], "tent")
    cv.outline_outside({"tent"}, OUT)
    # 飛沫
    for (x, y) in ((16, 38), (19, 35), (40, 37), (43, 34), (13, 41), (45, 40), (22, 33), (38, 32)):
        dot(cv, x, y, FOAM[1])
    for x in range(14, 42):
        if prand(x, 1, 7) < 0.6:
            dot(cv, x, 40 + (1 if x % 3 == 0 else 0), FOAM[1])
    return cv


# ================================================================ 11. 詠唱
def chant():
    BG = [(10, 8, 20), (18, 14, 34), (28, 22, 48)]
    FIG = [(12, 10, 22), (30, 26, 48), (54, 48, 80)]
    RIM = (120, 110, 170)
    SKIN = [(120, 96, 110), (170, 140, 150)]
    MAG = [(60, 80, 180), (110, 150, 240), (190, 220, 255), (250, 252, 255)]
    OUT = (4, 2, 10)
    cv = Canvas(BG[0])
    vgrad(cv, None, None, colors=BG)
    # 人の横顔（右向き）：フード付きの薄い衣。肩・首・頭がわかる輪郭
    head_cx, head_cy = 17, 20
    cv.ellipse(head_cx, head_cy, 6.5, 7.5, lambda *a: FIG[1], "fig")           # 頭（フード）
    cv.poly([(12, 25), (21, 25), (22, 31), (13, 32)], lambda x, y: FIG[1], "fig")  # 首
    cv.poly([(2, 34), (10, 30), (24, 30), (30, 36), (33, 59), (0, 59), (0, 40)],
            lambda x, y: FIG[1] if x > 12 else FIG[0], "fig")                       # 肩と胴（細身）
    # 顔の前面（横顔）：額→鼻→開いた口→顎
    face = [(20, 14), (22.5, 17), (24.5, 20.5), (22.5, 21.5), (23.5, 23), (21, 23.4), (22.5, 25.5), (19, 27.5), (17, 26)]
    cv.poly(face, lambda x, y: SKIN[1] if x > 21 else SKIN[0], "face")
    dot(cv, 22, 23.2, OUT)        # 開いた口
    dot(cv, 21.5, 18.2, OUT)      # 目
    # フードの縁取り（後ろからの光）
    cv.outline({"fig"}, RIM)
    # 前へ伸ばした手（胸の前で印を結ぶ）
    cv.poly([(22, 36), (28, 33), (30, 34), (24, 38)], lambda x, y: FIG[2], "fig")
    dot(cv, 30, 33, SKIN[1])
    dot(cv, 31, 34, SKIN[0])
    # 口から魔法陣が連なって飛び出す：遠くほど大きく薄い円（横から見た楕円）
    for k, (cx, rx, ry) in enumerate(((27, 1.3, 3.0), (32, 2.0, 5.0), (38, 2.6, 7.5), (45, 3.0, 10.0))):
        col_o = MAG[2] if k < 2 else MAG[1]
        for i in range(90):
            a = i / 90 * 2 * math.pi
            x = cx + rx * math.cos(a)
            y = 23 + ry * math.sin(a)
            dot(cv, x, y, col_o if math.cos(a) > -0.2 else MAG[0], "mag")
        # 内側の小円と刻み
        for i in range(40):
            a = i / 40 * 2 * math.pi
            dot(cv, cx + rx * 0.55 * math.cos(a), 23 + ry * 0.55 * math.sin(a), MAG[0], "mag")
        for j in range(6):
            a = j * math.pi / 3 + k
            dot(cv, cx + rx * 0.8 * math.cos(a), 23 + ry * 0.8 * math.sin(a), MAG[3], "mag")
    # 口から伸びる光の筋
    for x in range(23, 50):
        if (x % 3) != 0:
            dot(cv, x, 23, MAG[3] if x < 30 else MAG[2])
    return cv


# ================================================================ 12. 適応の鱗
def adapted_scales():
    BG = [(6, 20, 26), (10, 32, 40), (16, 46, 54)]
    SCALE = [(12, 60, 60), (24, 100, 96), (48, 150, 136), (110, 206, 184), (190, 246, 226)]
    CLAW = [(60, 70, 70), (170, 190, 184)]
    OUT = (2, 10, 14)
    cv = Canvas(BG[0])
    vgrad(cv, None, None, colors=BG)
    # 前腕は左下から右上へ。手の甲をこちらに向け、指を少しひらく
    T = rot(24, 34, -math.radians(52))
    # 局所座標：u=腕の長さ方向（手首は u=0、指先は +）、v=幅方向（上が -）
    # 形状：前腕（太さ 5.5→4.5）、手首で少し細く、手の甲（幅 5.5）
    def arm_w(u):
        if u < -3:
            return 4.9 - 0.012 * (u + 34)          # 前腕：肘側がわずかに太い
        if u < 0:
            return 4.2                              # 手首で少しくびれる
        return 4.2 + 1.3 * min(1.0, u / 7.0)        # 手の甲：指の付け根へ向けて広がる

    def scale_tone(u, v, half, size):
        """円柱の陰影（上が明）に、ずらし積みの鱗の縁を重ねる。"""
        shade_t = 0.5 - 0.5 * (v / half)
        su = (u / size) % 1.0
        row = int(math.floor(u / size))
        sv = (v / size + (0.5 if row % 2 else 0.0)) % 1.0
        edge = su < 0.22 or abs(sv - 0.5) > 0.4
        if edge:
            return SCALE[0] if shade_t < 0.45 else SCALE[1]
        return SCALE[min(4, 1 + int(shade_t * 3.2))] if su > 0.55 else SCALE[min(3, 1 + int(shade_t * 2.6))]

    for u in [i * 0.3 for i in range(int(-34 / 0.3), int(8 / 0.3) + 1)]:
        half = arm_w(u)
        v = -half
        while v <= half:
            size = 3.0 if u < -3 else 2.0            # 手の甲の鱗は細かく
            c = scale_tone(u, v, half, size)
            dot(cv, *T(u, v), c, "arm")
            v += 0.3
    # 指の付け根の関節（ナックル）：4つの盛り上がりを明るく
    for k in range(4):
        dot(cv, *T(7.6, (k - 1.5) * 2.5 - 0.6), SCALE[4], "arm")
        dot(cv, *T(7.9, (k - 1.5) * 2.5 - 0.2), SCALE[3], "arm")
    # 指：手の甲から4本、わずかに扇状。関節2つ、先に爪
    for k in range(4):
        spread = (k - 1.5) * 0.12
        base_v = (k - 1.5) * 2.5
        length = 8.5 if k in (1, 2) else (7.0 if k == 0 else 6.2)
        t = 0.0
        while t <= length:
            u = 8 + t * math.cos(spread)
            v = base_v + t * math.sin(spread) * 4
            half = 1.25 - 0.35 * (t / length)
            w = -half
            while w <= half:
                s = w / half
                c = SCALE[3] if s < -0.35 else (SCALE[2] if s < 0.45 else SCALE[1])
                if abs(t - length * 0.38) < 0.3 or abs(t - length * 0.7) < 0.3:
                    c = SCALE[0]
                dot(cv, *T(u, v + w), c, "arm")
                w += 0.3
            t += 0.3
        ux = 8 + (length + 0.5) * math.cos(spread)
        vx = base_v + (length + 0.5) * math.sin(spread) * 4
        dot(cv, *T(ux, vx), CLAW[1], "claw")
        dot(cv, *T(ux + 0.6, vx), CLAW[0], "claw")
    # 親指：手の甲の下側（小指と反対側）から前へ
    t = 0.0
    while t <= 6.0:
        u, v = 1.5 + t * 0.85, 4.8 + t * 0.35
        for w in (-0.9, -0.3, 0.3, 0.9):
            dot(cv, *T(u, v + w), SCALE[2] if w < 0 else SCALE[1], "arm")
        t += 0.3
    dot(cv, *T(1.5 + 6.6 * 0.85, 4.8 + 6.6 * 0.35), CLAW[1], "claw")
    cv.outline_outside({"arm", "claw"}, OUT)
    return cv


ARTS = {
    "goddess_blessing": (goddess_blessing, 0),
    "tentacle": (tentacle, 0),
    "chant": (chant, 0),
    "adapted_scales": (adapted_scales, 0),
    "spellbook": (spellbook, 0),
    "nourishment": (nourishment, 0),
    "sea_pact": (sea_pact, 0),
    "gill_breathing": (gill_breathing, 0),
    "wind_gods_bow": (wind_gods_bow, 0),
    "crossbow": (crossbow, 0),
    "muramasa": (muramasa, 0),
    "cold_flame": (cold_flame, 0),
}
