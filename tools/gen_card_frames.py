"""Pixel-art card frames (NinePatch, 96x144, 12px margin) for Abyss of R'lyeh.

Grid: 48x72 cells, 1 cell = 2px. Border = 6 cells (12px).
Depth d: 0 = outer outline, 5 = inner outline, 1..4 = face band.
Deterministic: no Python hash(), no random module.
Usage: python3 gen_card_frames.py <out_dir>
"""
import math
import os
import sys
from PIL import Image

GRID_W, GRID_H = 48, 72
BORDER = 6
SCALE = 2
FACE = range(1, BORDER - 1)
SIDE_SEED = {"top": 3, "left": 7, "bottom": 11, "right": 5}


def prand(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2654435761) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (n ^ (n >> 16)) / 0xFFFFFFFF


def corner_local(x, y):
    if x < BORDER and y < BORDER:
        return (x, y)
    if x >= GRID_W - BORDER and y < BORDER:
        return (GRID_W - 1 - x, y)
    if x < BORDER and y >= GRID_H - BORDER:
        return (x, GRID_H - 1 - y)
    if x >= GRID_W - BORDER and y >= GRID_H - BORDER:
        return (GRID_W - 1 - x, GRID_H - 1 - y)
    return None


def is_border(x, y):
    return x < BORDER or y < BORDER or x >= GRID_W - BORDER or y >= GRID_H - BORDER


def depth(x, y):
    return min(x, y, GRID_W - 1 - x, GRID_H - 1 - y)


def side_of(x, y):
    m = depth(x, y)
    if m == y:
        return "top"
    if m == x:
        return "left"
    if m == GRID_H - 1 - y:
        return "bottom"
    return "right"


def length_pos(x, y, side):
    return (x if side in ("top", "bottom") else y) - BORDER


def lit(side):
    return side in ("top", "left")


class Frame:
    outline = (20, 14, 10, 255)
    stud_ring = (60, 44, 20, 255)
    stud_hi = (226, 190, 104, 255)
    gem = (110, 176, 164, 255)
    gem_d = (46, 90, 84, 255)
    gem = gem

    def face(self, x, y, d, side, L):
        raise NotImplementedError

    def corner(self, cx, cy):
        # cx, cy: 0 at the outer corner, BORDER-1 at the inner side
        if cx in (0, BORDER - 1) or cy in (0, BORDER - 1):
            return self.outline
        if max(abs(cx - 2.5), abs(cy - 2.5)) < 1.0:
            return self.stud_hi
        return self.stud_ring

    def gem_cells(self, px):
        cols = range(GRID_W // 2 - 2, GRID_W // 2 + 2)
        rows = range(GRID_H // 2 - 2, GRID_H // 2 + 2)
        for d in range(BORDER):
            c = self.outline if d in (0, BORDER - 1) else (self.gem_d if d in (1, BORDER - 2) else self.gem)
            for x in cols:
                px[d][x] = c
                px[GRID_H - 1 - d][x] = c
            for y in rows:
                px[y][d] = c
                px[y][GRID_W - 1 - d] = c

    def build(self):
        px = [[(0, 0, 0, 0)] * GRID_W for _ in range(GRID_H)]
        for y in range(GRID_H):
            for x in range(GRID_W):
                if not is_border(x, y):
                    continue
                c = corner_local(x, y)
                if c is not None:
                    px[y][x] = self.corner(*c)
                    continue
                d = depth(x, y)
                if d in (0, BORDER - 1):
                    px[y][x] = self.outline
                    continue
                side = side_of(x, y)
                px[y][x] = self.face(x, y, d, side, length_pos(x, y, side))
        self.gem_cells(px)
        return px

    def render(self):
        px = self.build()
        img = Image.new("RGBA", (GRID_W, GRID_H))
        img.putdata([c for row in px for c in row])
        return img.resize((GRID_W * SCALE, GRID_H * SCALE), Image.NEAREST)


# ---------- common: wooden planks ----------
class Common(Frame):
    outline = (24, 16, 12, 255)
    light, dark, grain = (144, 106, 62, 255), (60, 40, 24, 255), (40, 26, 16, 255)
    stud_ring, stud_hi = (72, 52, 20, 255), (226, 190, 104, 255)

    def face(self, x, y, d, side, L):
        base = self.light if lit(side) else self.dark
        if (L + SIDE_SEED[side] * 3) % 7 == 0:
            base = self.grain
        total = GRID_W - 2 * BORDER if side in ("top", "bottom") else GRID_H - 2 * BORDER
        for rel in (0.28, 0.7):
            k = int(total * rel)
            if abs(L - k) <= 1:
                base = self.grain if abs(L - k) == 1 else self.outline
        return base


# ---------- fire: charred rock + lava crack ----------
class Fire(Frame):
    outline = (16, 8, 6, 255)
    rock_l, rock_d = (58, 30, 22, 255), (34, 16, 14, 255)
    hot, glow = (255, 214, 80, 255), (224, 104, 24, 255)
    stud_ring, stud_hi = (40, 18, 14, 255), (255, 224, 120, 255)
    gem, gem_d = (255, 150, 40, 255), (120, 50, 16, 255)

    def face(self, x, y, d, side, L):
        c = 2.5 + 0.9 * math.sin(L * 0.35 + SIDE_SEED[side] * 0.5)
        k = abs(d - c)
        if k < 0.35:
            return self.hot
        if k < 0.75:
            return self.glow
        return self.rock_l if lit(side) else self.rock_d


# ---------- water: wet stone + current ----------
class Water(Frame):
    outline = (10, 16, 20, 255)
    stone_l, stone_d = (64, 88, 98, 255), (36, 54, 64, 255)
    speckle, wave = (196, 224, 220, 255), (140, 214, 204, 255)
    stud_ring, stud_hi = (30, 52, 58, 255), (220, 238, 232, 255)
    gem, gem_d = (120, 224, 214, 255), (40, 92, 88, 255)

    def face(self, x, y, d, side, L):
        c = 2.5 + 0.8 * math.sin(L * 0.5 + SIDE_SEED[side] * 0.7)
        if abs(d - c) < 0.35:
            return self.wave
        if prand(x, y, 7) < 0.05:
            return self.speckle
        return self.stone_l if lit(side) else self.stone_d


# ---------- greatold: malachite + writhing tentacle ----------
class GreatOld(Frame):
    outline = (6, 16, 12, 255)
    stone_l, stone_d, band = (34, 86, 62, 255), (18, 52, 38, 255), (52, 118, 86, 255)
    tent, tent_d, sucker = (126, 200, 120, 255), (60, 130, 78, 255), (214, 240, 170, 255)
    stud_ring, stud_hi = (20, 60, 42, 255), (170, 236, 150, 255)
    gem, gem_d = (150, 230, 120, 255), (40, 100, 60, 255)

    def face(self, x, y, d, side, L):
        # malachite banding: concentric-ish stripes
        base = self.stone_l if lit(side) else self.stone_d
        if (L + d * 2 + SIDE_SEED[side]) % 9 in (0, 1):
            base = self.band
        # tentacle: thick body that tapers/wobbles, with suckers on its center line
        c = 2.5 + 1.0 * math.sin(L * 0.22 + SIDE_SEED[side])
        k = abs(d - c)
        if k < 0.5:
            return self.sucker if L % 4 == 0 else self.tent
        if k < 1.1:
            return self.tent_d
        return base


# ---------- elder: pale marble + rose-gold veins ----------
class Elder(Frame):
    outline = (60, 36, 36, 255)
    marble_l, marble_d = (236, 222, 214, 255), (196, 176, 170, 255)
    vein, vein_d = (214, 150, 132, 255), (160, 104, 96, 255)
    stud_ring, stud_hi = (170, 110, 80, 255), (255, 226, 180, 255)
    gem, gem_d = (240, 170, 170, 255), (150, 80, 86, 255)

    def face(self, x, y, d, side, L):
        base = self.marble_l if lit(side) else self.marble_d
        # thin diagonal veins
        if (L + d * 3 + SIDE_SEED[side] * 5) % 13 == 0:
            return self.vein
        if (L - d * 2 + SIDE_SEED[side] * 2) % 17 == 0:
            return self.vein_d
        return base


# ---------- outer: void obsidian + stars ----------
class Outer(Frame):
    outline = (6, 4, 12, 255)
    void_l, void_d, nebula = (46, 30, 70, 255), (24, 16, 40, 255), (82, 46, 110, 255)
    star, star_dim = (240, 232, 255, 255), (150, 130, 200, 255)
    stud_ring, stud_hi = (30, 20, 52, 255), (200, 170, 255, 255)
    gem, gem_d = (180, 120, 255, 255), (70, 40, 120, 255)

    def face(self, x, y, d, side, L):
        base = self.void_l if lit(side) else self.void_d
        n = 2.5 + 1.2 * math.sin(L * 0.18 + SIDE_SEED[side] * 1.3)
        if abs(d - n) < 0.6 and (L // 2) % 3 != 0:
            base = self.nebula
        r = prand(x, y, 31)
        if r < 0.035:
            return self.star
        if r < 0.08:
            return self.star_dim
        return base


# ---------- all: black lacquer + prismatic band ----------
class All(Frame):
    outline = (8, 8, 10, 255)
    black_l, black_d = (38, 36, 44, 255), (20, 20, 26, 255)
    prism = [(255, 96, 96, 255), (255, 186, 80, 255), (240, 240, 110, 255),
             (110, 230, 140, 255), (100, 180, 255, 255), (180, 120, 255, 255)]
    stud_ring, stud_hi = (30, 30, 36, 255), (255, 255, 255, 255)
    gem, gem_d = (255, 255, 255, 255), (120, 120, 140, 255)

    def face(self, x, y, d, side, L):
        if d in (2, 3):
            # rainbow shifts along the length, offset per side so the loop feels continuous
            idx = ((L + SIDE_SEED[side] * 4) // 3 + (1 if d == 3 else 0)) % len(self.prism)
            return self.prism[idx]
        return self.black_l if lit(side) else self.black_d


# ---------- knight: steel plate + rivets ----------
class Knight(Frame):
    outline = (14, 16, 20, 255)
    steel_hi, steel_l, steel_d = (196, 204, 214, 255), (132, 142, 156, 255), (72, 80, 94, 255)
    rivet, rivet_d = (230, 236, 242, 255), (46, 52, 62, 255)
    stud_ring, stud_hi = (60, 66, 78, 255), (240, 244, 250, 255)
    gem, gem_d = (200, 60, 60, 255), (100, 24, 28, 255)

    def face(self, x, y, d, side, L):
        # bevel: outer row highlight, inner row shadow
        if d == 1:
            base = self.steel_hi if lit(side) else self.steel_l
        elif d == BORDER - 2:
            base = self.steel_d
        else:
            base = self.steel_l if lit(side) else self.steel_d
        # rivets every 8 cells, 2x2 on the middle rows
        m = (L + 4) % 8
        if d in (2, 3) and m in (0, 1):
            return self.rivet if (d == 2 and m == 0) else self.rivet_d
        return base


# ---------- magic: dark tome leather + glowing runes ----------
class Magic(Frame):
    outline = (6, 8, 18, 255)
    leather_l, leather_d = (30, 38, 72, 255), (18, 22, 46, 255)
    rune, rune_glow = (150, 210, 255, 255), (70, 110, 200, 255)
    stitch = (90, 100, 140, 255)
    stud_ring, stud_hi = (30, 40, 80, 255), (170, 220, 255, 255)
    gem, gem_d = (120, 190, 255, 255), (40, 70, 140, 255)
    # 4x4 rune glyphs (rows top->bottom), 1 = rune pixel
    GLYPHS = [
        ["1001", "0110", "0110", "1001"],
        ["1110", "0010", "0111", "0100"],
        ["0100", "1111", "0100", "0110"],
        ["1010", "0100", "1010", "0001"],
    ]

    def face(self, x, y, d, side, L):
        base = self.leather_l if lit(side) else self.leather_d
        if d == 1 and L % 3 == 0:
            base = self.stitch
        period = 9
        slot = (L + SIDE_SEED[side]) % period
        g = self.GLYPHS[((L + SIDE_SEED[side]) // period) % len(self.GLYPHS)]
        if slot < 4:
            gy = d - 1  # 0..3 within face
            if 0 <= gy < 4:
                if g[gy][slot] == "1":
                    return self.rune
                # soft halo next to rune pixels
                if (slot > 0 and g[gy][slot - 1] == "1") or (slot < 3 and g[gy][slot + 1] == "1"):
                    return self.rune_glow
        return base


# ---------- wind: pale sage + diagonal gusts ----------
class Wind(Frame):
    outline = (22, 34, 26, 255)
    sage_l, sage_d = (168, 190, 150, 255), (110, 134, 100, 255)
    gust, gust_d = (236, 246, 222, 255), (140, 168, 128, 255)
    leaf = (86, 140, 70, 255)
    stud_ring, stud_hi = (70, 100, 64, 255), (230, 250, 210, 255)
    gem, gem_d = (170, 240, 160, 255), (60, 110, 60, 255)

    def face(self, x, y, d, side, L):
        base = self.sage_l if lit(side) else self.sage_d
        # diagonal streaks sweeping in one direction (like gusts)
        s = (L - d * 2 + SIDE_SEED[side]) % 10
        if s == 0:
            return self.gust
        if s == 1:
            return self.gust_d
        if (L + SIDE_SEED[side] * 2) % 16 == 8 and d in (2, 3):
            return self.leaf
        return base


# ---------- earth: dark soil stone + gold ore ----------
class Earth(Frame):
    outline = (14, 10, 4, 255)
    soil_l, soil_d, pebble = (80, 62, 38, 255), (48, 36, 22, 255), (104, 86, 60, 255)
    gold, gold_d = (246, 206, 90, 255), (170, 124, 36, 255)
    stud_ring, stud_hi = (110, 80, 24, 255), (255, 230, 130, 255)
    gem, gem_d = (246, 206, 90, 255), (120, 84, 20, 255)

    def face(self, x, y, d, side, L):
        base = self.soil_l if lit(side) else self.soil_d
        if prand(x, y, 53) < 0.12:
            base = self.pebble
        # gold nuggets: small clusters every ~11 cells
        seg = (L + SIDE_SEED[side] * 3) % 11
        cd = 2 + int(prand(L // 11, 0, SIDE_SEED[side]) * 2)  # nugget row 2 or 3
        if seg in (0, 1) and d in (cd, cd + 1):
            return self.gold if (seg == 0 and d == cd) else self.gold_d
        return base


# ---------- bastet: rose sandstone + gold chevrons ----------
class Bastet(Frame):
    outline = (60, 28, 24, 255)
    sand_l, sand_d = (232, 170, 150, 255), (192, 128, 112, 255)
    gold, gold_d = (240, 200, 96, 255), (170, 124, 50, 255)
    stud_ring, stud_hi = (150, 96, 44, 255), (255, 234, 150, 255)
    gem, gem_d = (80, 160, 200, 255), (30, 70, 100, 255)  # lapis

    def face(self, x, y, d, side, L):
        base = self.sand_l if lit(side) else self.sand_d
        # stepped-pyramid band: solid gold baseline on row 3, steps on row 2
        p = (L + SIDE_SEED[side]) % 6
        if d == 3:
            return self.gold_d if p in (0, 5) else self.gold
        if d == 2 and p in (2, 3):
            return self.gold
        return base


FRAMES = {
    "common": Common, "fire": Fire, "water": Water,
    "greatold": GreatOld, "elder": Elder, "outer": Outer, "all": All,
    "knight": Knight, "magic": Magic, "wind": Wind, "earth": Earth, "bastet": Bastet,
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for name, cls in FRAMES.items():
        img = cls().render()
        fn = "frame_card_9.png" if name == "common" else f"frame_card_{name}_9.png"
        img.save(os.path.join(out, fn))
        print(fn, img.size)
