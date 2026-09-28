"""Hand-built pixel art for two card illustrations, drawn in code on a 53x80 grid.

53x80 is chosen so that, in the hand (art area 106px wide), 1 dot = 2 screen px,
the same dot size as the pixel card frames. Deterministic (no random module).
Usage: python3 draw_cards.py <out_dir>
"""
import math
import os
import sys
from PIL import Image

W, H = 53, 80


def prand(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2654435761) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (n ^ (n >> 16)) / 0xFFFFFFFF


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither(x, y, t):
    """True if an ordered-dither threshold t (0..1) says 'use the second colour'."""
    return (BAYER4[y % 4][x % 4] + 0.5) / 16 < t


class Canvas:
    def __init__(self, bg=(0, 0, 0)):
        self.px = [[bg] * W for _ in range(H)]
        self.mask = [[None] * W for _ in range(H)]  # which shape owns the cell

    def set(self, x, y, c, owner=None):
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = c
            if owner is not None:
                self.mask[y][x] = owner

    def get(self, x, y):
        return self.px[y][x]

    def image(self, top=0, rows=59, scale=1):
        img = Image.new("RGB", (W, H))
        img.putdata([c for row in self.px for c in row])
        img = img.crop((0, top, W, top + rows))
        if scale != 1:
            img = img.resize((W * scale, rows * scale), Image.NEAREST)
        return img


def ellipse_cells(cx, cy, rx, ry):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            r = u * u + v * v
            if r <= 1.0:
                yield x, y, u, v, r


def shade_ellipse(cv, cx, cy, rx, ry, tones, owner, light=(-0.55, -0.83), rim=0.78):
    """tones = (hi, mid, shadow, deep). Hard-edged light from top-left."""
    hi, mid, sh, deep = tones
    for x, y, u, v, r in ellipse_cells(cx, cy, rx, ry):
        s = -(u * light[0] + v * light[1])  # >0 faces the light
        if r > rim and s < -0.1:
            c = deep
        elif s < -0.35:
            c = sh
        elif s > 0.45 and r < 0.55:
            c = hi
        else:
            c = mid
        cv.set(x, y, c, owner)


def outline(cv, bgset, color, owners=None):
    """Cells of a shape that touch the background (4-neighbour) become outline."""
    todo = []
    for y in range(H):
        for x in range(W):
            o = cv.mask[y][x]
            if o is None or (owners and o not in owners):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H) or cv.mask[ny][nx] is None:
                    todo.append((x, y))
                    break
    for x, y in todo:
        cv.set(x, y, color)


# ------------------------------------------------------------------ cats_paw
def cats_paw():
    BG0, BG1, BG2 = (18, 11, 10), (28, 18, 15), (40, 27, 21)
    OUT = (52, 34, 26)
    FUR = ((244, 234, 216), (218, 202, 178), (170, 148, 122), (118, 96, 78))
    PAD = ((252, 184, 176), (228, 122, 122), (182, 82, 88), (128, 54, 62))
    CLAW, CLAW_D = (240, 228, 206), (176, 140, 112)
    ARM_L, ARM, ARM_D, STRIPE = (116, 98, 78), (84, 70, 56), (56, 45, 36), (34, 26, 22)

    cv = Canvas(BG0)
    # background: faint warm vignette around the paw, ordered dither between steps
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - 26.5) / 30, (y - 44) / 38)
            t = max(0.0, 1.0 - d)
            if t > 0.5:
                c = BG2 if (t > 0.58 or dither(x, y, (t - 0.5) / 0.08)) else BG1
            elif t > 0.2:
                c = BG1 if (t > 0.28 or dither(x, y, (t - 0.2) / 0.08)) else BG0
            else:
                c = BG0
            cv.set(x, y, c)

    # forearm (tabby), slanting down-left, drawn first so the paw sits on top
    for y in range(55, H):
        f = (y - 55) / (H - 55)
        x0 = 14.5 - 5.5 * f
        x1 = 36.5 - 3.0 * f
        for x in range(int(x0), int(x1) + 1):
            u = (x - x0) / max(1, x1 - x0)
            c = ARM_L if u < 0.22 else (ARM_D if u > 0.8 else ARM)
            wave = math.sin(x * 0.35 + y * 0.9) + (prand(y, 0, 17) - 0.5)
            if (y + int(1.6 * wave)) % 5 == 0 and 0.08 < u < 0.95 and prand(x, y, 19) < 0.85:
                c = STRIPE
            elif (y + int(1.6 * wave)) % 5 == 1 and 0.08 < u < 0.95 and prand(x, y, 23) < 0.35:
                c = ARM_D
            cv.set(x, y, c, "arm")
    outline(cv, None, STRIPE, owners={"arm"})
    # dark wrist band where fur meets the arm
    for x in range(14, 38):
        for y in (56, 57):
            if cv.mask[y][x] == "arm":
                cv.set(x, y, ARM_D, "arm")

    # palm + wrist fur
    shade_ellipse(cv, 27.0, 47.5, 13.5, 10.5, FUR, "fur")
    shade_ellipse(cv, 25.5, 53.5, 11.5, 6.5, FUR, "fur")
    # toes (fur beans)
    toes = [(15.5, 39.0, 4.7, 5.6), (22.6, 32.5, 5.0, 6.1), (32.2, 32.5, 5.0, 6.1), (39.2, 39.0, 4.7, 5.6)]
    for i, (cx, cy, rx, ry) in enumerate(toes):
        shade_ellipse(cv, cx, cy, rx, ry, FUR, f"toe{i}")

    # fur tufts: jagged edge on the sides and the bottom of the wrist fur
    for x in range(15, 37):
        if prand(x, 0, 9) < 0.45:
            cv.set(x, 60, FUR[2], "fur")

    outline(cv, None, OUT, owners={"fur", "toe0", "toe1", "toe2", "toe3"})
    # separations between toes and palm: shadow where a toe's lower edge meets the palm
    for i, (cx, cy, rx, ry) in enumerate(toes):
        for x, y, u, v, r in ellipse_cells(cx, cy, rx, ry):
            if r > 0.72 and v > 0.3:
                below = cv.mask[y + 1][x] if y + 1 < H else None
                if below == "fur":
                    cv.set(x, y, FUR[3])
    # gaps between neighbouring toes
    for (a, b) in ((0, 1), (1, 2), (2, 3)):
        ax, bx = toes[a][0], toes[b][0]
        mx = int(round((ax + bx) / 2))
        for y in range(int(min(toes[a][1], toes[b][1])), int(max(toes[a][1], toes[b][1]) + 4)):
            if cv.mask[y][mx] and cv.mask[y][mx].startswith("toe"):
                cv.set(mx, y, OUT)

    # toe pads and main pad: flat mid tone per union, then one highlight and a
    # contour on the shadow side (keeps overlapping lobes from leaving seams)
    pads = [(cx + 0.2, cy + 0.9, rx * 0.62, ry * 0.6) for (cx, cy, rx, ry) in toes]
    main = [(27.0, 47.8, 6.2, 4.6), (22.0, 50.2, 3.8, 3.2), (32.0, 50.2, 3.8, 3.2), (27.0, 44.0, 3.2, 2.8)]
    for i, e in enumerate(pads):
        for x, y, u, v, r in ellipse_cells(*e):
            cv.set(x, y, PAD[1], f"pad{i}")
    for e in main:
        for x, y, u, v, r in ellipse_cells(*e):
            cv.set(x, y, PAD[1], "mainpad")
    padset = {"pad0", "pad1", "pad2", "pad3", "mainpad"}
    for y in range(H):
        for x in range(W):
            o = cv.mask[y][x]
            if o not in padset:
                continue
            if cv.mask[y + 1][x] != o or cv.mask[y][x + 1] != o:
                cv.set(x, y, PAD[3])
            elif cv.mask[y + 2][x] != o or cv.mask[y][x + 2] != o:
                cv.set(x, y, PAD[2])
    # highlights (top-left of each bean)
    for (cx, cy, rx, ry) in pads:
        hx, hy = int(cx - rx * 0.35), int(cy - ry * 0.45)
        cv.set(hx, hy, PAD[0]); cv.set(hx + 1, hy, PAD[0]); cv.set(hx, hy + 1, PAD[0])
    for (hx, hy) in ((24, 45), (25, 45), (24, 46), (26, 42), (20, 49)):
        cv.set(hx, hy, PAD[0])

    # claws poking out of the toe tips
    for (x, y0, n) in ((22, 25, 2), (32, 25, 2), (13, 32, 2), (41, 32, 2)):
        for k in range(n):
            cv.set(x, y0 + k, CLAW if k == 0 else CLAW_D)
        cv.set(x, y0 - 1, OUT)
    return cv


# -------------------------------------------------------------- far_guidance
FIGURE = [
    "....O....",
    "...OhO...",
    "..OhHhO..",
    "..OHhhO..",
    "..OhhhO..",
    ".OChhhCO.",
    "OCCchcCCO",
    "OCcccccCO",
    "rCcccccCr",
    "rCcccccCr",
    "rCcccccCr",
    "OCcccccCO",
    "OrCcccCrO",
    "ORrcccrRO",
    ".ORROORR.",
]


def far_guidance():
    SKY = [(3, 3, 8), (6, 6, 13), (10, 10, 20)]
    GROUND = [(14, 14, 28), (20, 20, 40), (28, 28, 54)]
    GLOW = [(236, 190, 104), (176, 128, 64), (104, 76, 42), (58, 44, 34)]
    FIG = {"O": (4, 4, 8), "C": (44, 46, 72), "c": (28, 30, 50), "h": (22, 24, 40), "H": (38, 40, 62), "R": (222, 176, 98), "r": (130, 98, 60)}

    horizon = 49
    cv = Canvas(SKY[0])
    for y in range(H):
        for x in range(W):
            if y < horizon:
                t = y / horizon
                if t > 0.7:
                    c = SKY[2] if dither(x, y, (t - 0.7) / 0.3) else SKY[1]
                elif t > 0.35:
                    c = SKY[1] if dither(x, y, (t - 0.35) / 0.35) else SKY[0]
                else:
                    c = SKY[0]
            else:
                # ground: speckled, denser/lighter toward the viewer
                f = (y - horizon) / (H - horizon)
                r = prand(x, y, 11)
                c = GROUND[0]
                if r < 0.18 + 0.35 * f:
                    c = GROUND[1]
                if r < 0.02 + 0.05 * f:
                    c = GROUND[2]
                if y == horizon and r < 0.5:
                    c = SKY[2]
            cv.set(x, y, c)

    # pool of light on the ground around the figure's feet
    fx, fy = 26, 62
    for y in range(horizon + 2, H):
        for x in range(W):
            d = math.hypot((x + 0.5 - (fx + 0.5)) / 11.0, (y + 0.5 - fy) / 3.0)
            if d < 0.3:
                c = GLOW[0]
            elif d < 0.55:
                c = GLOW[1] if dither(x, y, (d - 0.3) / 0.25) else GLOW[0]
            elif d < 0.8:
                c = GLOW[2] if dither(x, y, (d - 0.55) / 0.25) else GLOW[1]
            elif d < 1.1:
                c = None if dither(x, y, (d - 0.8) / 0.3) else GLOW[2]
            elif d < 1.45:
                c = None if dither(x, y, 0.55 + (d - 1.1)) else GLOW[3]
            else:
                c = None
            if c:
                cv.set(x, y, c)
    # the figure's own shadow on the lit ground
    for x in range(fx - 2, fx + 3):
        cv.set(x, fy, (40, 30, 26))
    # figure, feet on fy-1
    top = fy - len(FIGURE)
    left = fx - len(FIGURE[0]) // 2
    for j, row in enumerate(FIGURE):
        for i, ch in enumerate(row):
            if ch != ".":
                cv.set(left + i, top + j, FIG[ch])
    return cv


ARTS = {"cats_paw": cats_paw, "far_guidance": far_guidance}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for name, fn in ARTS.items():
        img = fn().image(11)
        img.save(os.path.join(out, f"{name}.png"))
        print(name, img.size)
