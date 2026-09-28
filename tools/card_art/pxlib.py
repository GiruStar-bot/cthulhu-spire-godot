"""Small pixel-art drawing kit for 53x80 card illustrations. Deterministic."""
import math
from PIL import Image

W, H = 53, 80
OUT_H = 59  # 53x59 matches the in-hand art area (106x117 at 2px per dot)
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def prand(x, y, seed):
    s = seed if isinstance(seed, int) else int(round(seed * 1000))
    n = (int(x) * 374761393 + int(y) * 668265263 + s * 2654435761) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (n ^ (n >> 16)) / 0xFFFFFFFF


def dither(x, y, t):
    return (BAYER4[y % 4][x % 4] + 0.5) / 16 < t


def ramp(x, y, t, colors):
    """Pick from a list of colours by t in 0..1 with ordered dither between steps."""
    t = min(max(t, 0.0), 0.9999)
    f = t * (len(colors) - 1)
    i = int(f)
    frac = f - i
    if i + 1 >= len(colors):
        return colors[-1]
    return colors[i + 1] if dither(x, y, frac) else colors[i]


class Canvas:
    def __init__(self, bg=(0, 0, 0)):
        self.px = [[bg] * W for _ in range(H)]
        self.own = [[None] * W for _ in range(H)]

    def inb(self, x, y):
        return 0 <= x < W and 0 <= y < H

    def set(self, x, y, c, owner=None):
        x, y = int(x), int(y)
        if self.inb(x, y) and c is not None:
            self.px[y][x] = c
            if owner is not None:
                self.own[y][x] = owner

    def get(self, x, y):
        return self.px[y][x] if self.inb(x, y) else None

    def owner(self, x, y):
        return self.own[y][x] if self.inb(x, y) else None

    def fill(self, fn):
        """fn(x, y) -> colour or None, applied to every cell."""
        for y in range(H):
            for x in range(W):
                c = fn(x, y)
                if c is not None:
                    self.px[y][x] = c

    def image(self, top=0, rows=None, scale=1):
        """Card art is 53x59: the part of the 53x80 drawing board that the card shows."""
        rows = rows or OUT_H
        img = Image.new("RGB", (W, H))
        img.putdata([c for row in self.px for c in row])
        img = img.crop((0, top, W, top + rows))
        return img if scale == 1 else img.resize((W * scale, rows * scale), Image.NEAREST)

    # ---- shapes -------------------------------------------------------
    def ellipse(self, cx, cy, rx, ry, color_fn, owner=None):
        """color_fn(x, y, u, v, r) with u,v in -1..1 and r = u^2+v^2."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                r = u * u + v * v
                if r <= 1.0:
                    self.set(x, y, color_fn(x, y, u, v, r), owner)

    def poly(self, pts, color_fn, owner=None):
        """Scanline fill of a polygon; color_fn(x, y)."""
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(math.ceil(max(ys))) + 1):
            yc = y + 0.5
            xs = []
            n = len(pts)
            for i in range(n):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[0::2], xs[1::2]):
                for x in range(int(math.floor(a + 0.5)), int(math.floor(b + 0.5))):
                    self.set(x, y, color_fn(x, y), owner)

    def line(self, x0, y0, x1, y1, color, owner=None, width=1):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            for k in range(width):
                if dx >= -dy:
                    self.set(x0, y0 + k, color, owner)
                else:
                    self.set(x0 + k, y0, color, owner)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def sprite(self, rows, left, top, palette, owner=None):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in palette:
                    self.set(left + i, top + j, palette[ch], owner)

    def outline(self, owners, color, diag=False):
        """Cells owned by `owners` that touch a cell with another owner become `color`."""
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diag:
            nb += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        todo = []
        for y in range(H):
            for x in range(W):
                if self.own[y][x] not in owners:
                    continue
                for dx, dy in nb:
                    if self.owner(x + dx, y + dy) not in owners:
                        todo.append((x, y))
                        break
        for x, y in todo:
            self.px[y][x] = color

    def outline_outside(self, owners, color):
        """Paint cells just outside the shape (4-neighbour) - a halo/outline that does not eat the shape."""
        todo = []
        for y in range(H):
            for x in range(W):
                if self.own[y][x] in owners:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.owner(x + dx, y + dy) in owners:
                        todo.append((x, y))
                        break
        for x, y in todo:
            self.px[y][x] = color

    def glow(self, owners, colors, radius, seed=0):
        """Dithered glow around shapes: colors[0] nearest. Only paints non-owned cells."""
        pts = [(x, y) for y in range(H) for x in range(W) if self.own[y][x] in owners]
        if not pts:
            return
        for y in range(H):
            for x in range(W):
                if self.own[y][x] in owners:
                    continue
                d = min(abs(px - x) + abs(py - y) for px, py in pts) if len(pts) < 400 else \
                    min(math.hypot(px - x, py - y) for px, py in pts[::2])
                if d <= radius:
                    t = d / (radius + 1)
                    idx = min(len(colors) - 1, int(t * len(colors)))
                    frac = t * len(colors) - idx
                    c = colors[idx]
                    if idx + 1 < len(colors) and dither(x, y, frac):
                        c = colors[idx + 1]
                    if c is not None:
                        self.px[y][x] = c


def shade(tones, light=(-0.55, -0.83), rim=0.78):
    """Ellipse colour fn with hard-edged light from top-left. tones=(hi, mid, sh, deep)."""
    hi, mid, sh, deep = tones

    def fn(x, y, u, v, r):
        s = -(u * light[0] + v * light[1])
        if r > rim and s < -0.1:
            return deep
        if s < -0.35:
            return sh
        if s > 0.45 and r < 0.55:
            return hi
        return mid
    return fn


def flat(c):
    return lambda *a: c


def flame(cv, cx, base_y, height, width, colors, seed=0, sway=2.0, owner="flame", tongues=3):
    """Hard-edged pixel flame. colors: [core, inner, mid, outer] (bright -> dark).
    Base at base_y, tip about height rows above. Tongues are separate flicks near the top."""
    core, inner, mid, outer = colors
    for y in range(int(base_y - height * 1.15), int(base_y) + 1):
        v = (base_y - y) / height            # 0 at base .. 1 at tip
        if v < 0:
            continue
        center = cx + sway * math.sin(v * 3.2 + seed)
        w = width * max(0.0, 1.0 - v) ** 0.75
        # ragged edge: coarse noise per row
        w *= 0.85 + 0.3 * prand(int(v * 12), 0, seed + 1)
        for x in range(int(center - width - 2), int(center + width + 3)):
            d = abs(x + 0.5 - center) / max(w, 0.01)
            if d > 1.0:
                continue
            if d < 0.3 and v < 0.55:
                c = core
            elif d < 0.55 and v < 0.75:
                c = inner
            elif d < 0.82:
                c = mid
            else:
                c = outer
            cv.set(x, y, c, owner)
    # tongues: thin flicks above/around the body
    for k in range(tongues):
        tx = cx + (k - (tongues - 1) / 2) * width * 0.55 + sway * math.sin(seed + k)
        top = base_y - height * (0.75 + 0.35 * prand(k, 3, seed))
        length = height * (0.25 + 0.15 * prand(k, 4, seed))
        for s in range(int(length)):
            y = top + s
            x = tx + 1.2 * math.sin(s * 0.6 + k + seed)
            cv.set(x, y, mid if s < length * 0.4 else inner, owner)
            if s > length * 0.5:
                cv.set(x + 1, y, mid, owner)


def fire(cv, cx, base_y, height, width, colors, seed=0, n=5, owner="flame", lean=0.0, body=0.35):
    """Bushy fire made of n tongues (field-based). colors: [core, inner, mid, outer].
    width = half-width of the whole fire at its base; height = tallest tongue."""
    core, inner, mid, outer = colors
    tongues = []
    for i in range(n):
        f = (i / (n - 1) - 0.5) if n > 1 else 0.0          # -0.5 .. 0.5 across the base
        centre_bias = 1.0 - abs(f) * 1.3
        h = height * (0.45 + 0.55 * centre_bias) * (0.85 + 0.3 * prand(i, 1, seed))
        tongues.append((cx + f * width * 1.4, h, width * (0.42 + 0.2 * centre_bias), i))
    top = int(base_y - height * 1.1)
    for y in range(top, int(base_y + width * body) + 1):
        for x in range(int(cx - width * 1.6), int(cx + width * 1.6) + 1):
            F = 0.0
            for (tx, h, tw, i) in tongues:
                v = (base_y - (y + 0.5)) / h
                if v < 0 or v > 1:
                    continue
                c = tx + lean * v * h + 1.6 * math.sin(v * 4.0 + i * 1.7 + seed) * v
                w = tw * (1 - v) ** 0.85 * (1 + 0.6 * v * (1 - v))
                if w <= 0:
                    continue
                d = abs(x + 0.5 - c) / w
                if d < 1:
                    F = max(F, (1 - d) * (1 - v * 0.55))
            # round body at the base
            if body:
                u = (x + 0.5 - cx) / width
                vv = (y + 0.5 - base_y) / (width * body * 2)
                rr = u * u + vv * vv
                if rr < 1:
                    F = max(F, (1 - rr) * 0.9)
            if F <= 0.02:
                continue
            if F > 0.62:
                col = core
            elif F > 0.42:
                col = inner
            elif F > 0.2:
                col = mid
            else:
                col = outer
            cv.set(x, y, col, owner)


def vnoise(x, y, s, seed):
    """Smooth value noise (bilinear over a coarse grid). 0..1."""
    gx, gy = x / s, y / s
    x0, y0 = math.floor(gx), math.floor(gy)
    fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = prand(x0, y0, seed); b = prand(x0 + 1, y0, seed)
    c = prand(x0, y0 + 1, seed); d = prand(x0 + 1, y0 + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def band(t, tones, cuts=None):
    """Pick a flat tone for t in 0..1 (no dithering). tones: dark -> light."""
    n = len(tones)
    cuts = cuts or [(i + 1) / n for i in range(n - 1)]
    for i, c in enumerate(cuts):
        if t < c:
            return tones[i]
    return tones[-1]


def texture(x, y, seed, s1=5.0, s2=2.2):
    """Low-contrast material mottling (0..1)."""
    return vnoise(x, y, s1, seed) * 0.65 + vnoise(x, y, s2, seed + 7) * 0.35
