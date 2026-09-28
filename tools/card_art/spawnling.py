"""落とし仔 — canonical sprite for the little olive spawn (used by 突進 and 落とし仔).

A round, soft olive body, two small cream horns, stubby feet, big dark eyes with a glint.
Moods: "happy" (open smile, blush) and "charge" (brows down, gritted mouth, leaning forward).
Drawn as a dict {(x, y): colour} around its own centre, then pasted.
"""
import math

OLIVE = ((196, 186, 118), (160, 150, 88), (124, 114, 64), (90, 80, 44), (56, 48, 26))
HORN = ((244, 236, 206), (196, 182, 146), (130, 116, 90))
EYE = (26, 22, 16)
BLUSH = (222, 146, 120)
OUT = (40, 32, 18)


def build(mood="happy", r=9.0, squash=1.0, flip=False):
    """squash > 1 stretches it horizontally (speed)."""
    px = {}
    rx, ry = round(r * squash * 2) / 2, round(r / squash ** 0.5 * 2) / 2
    lean = 2 if mood == "charge" else 0

    def put(x, y, c):
        px[(int(round(x)), int(round(y)))] = c

    # feet first (behind the body)
    k = r / 9.0                                          # features scale with size
    for (fx, fy) in ((-0.55, 0.78), (0.5, 0.82)) if mood != "charge" else ((-0.9, 0.6), (0.2, 0.9)):
        for y in range(-3, 4):
            for x in range(-4, 5):
                if (x / (3.2 * k)) ** 2 + (y / (2.2 * k)) ** 2 <= 1:
                    put(fx * rx + x, fy * ry + y, OLIVE[3] if y > 0 else OLIVE[2])
    # body: soft ball lit from the upper left, darker rim at the bottom right
    for y in range(-int(ry) - 1, int(ry) + 2):
        for x in range(-int(rx) - 1, int(rx) + 2):
            u, v = (x + 0.5) / rx, (y + 0.5) / ry
            rr = u * u + v * v
            if rr > 1:
                continue
            lit = -(u * 0.55 + v * 0.8)
            if rr > 0.82 and lit < 0:
                c = OLIVE[3]
            elif lit < -0.35:
                c = OLIVE[2]
            elif lit > 0.45 and rr < 0.45:
                c = OLIVE[0]
            else:
                c = OLIVE[1]
            put(x + lean, y, c)
    # horns: small cream cones pointing up (forward when charging)
    for side in (-1, 1):
        hx = side * rx * 0.5 + lean + (2 if mood == "charge" else 0)
        hy = -ry * 0.88
        pts = [(0, 0), (side * 0.6, -1), (side * 1.2, -2), (side * 1.4, -3)] if mood != "charge" else [(0, 0), (1, -1), (2, -1.5), (3, -2)]
        if r < 6:
            pts = pts[:2]
        for i, (dx, dy) in enumerate(pts):
            put(hx + dx, hy + dy, HORN[0] if i < 3 else HORN[1])
            put(hx + dx + (1 if side < 0 else -1) * 0.8, hy + dy + 0.6, HORN[1])
    # outline outside the shape
    shape = set(px)
    for (x, y) in list(shape):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in shape:
                px[n] = OUT
    # face
    ex = lean + (rx * 0.18 if mood == "charge" else 0)
    for side in (-1, 1):
        cx, cy = ex + side * rx * 0.34, -ry * 0.08
        if mood == "fall" or r < 6:
            put(cx, cy, EYE); put(cx, cy + 1, EYE) if r >= 5 else None
            if r >= 6:
                put(cx, cy - 1, (255, 255, 255))
            continue
        if mood == "charge":
            for dx in (0, 1):
                put(cx + dx, cy, EYE); put(cx + dx, cy + 1, EYE)
            put(cx - side * 0.5, cy - 1.5, EYE); put(cx + side * 0.5 + 0.5, cy - 1, EYE)     # brows down
            put(cx, cy, (240, 240, 230))
        else:
            for dy in range(-1, 2):
                for dx in (0, 1):
                    put(cx + dx, cy + dy, EYE)
            put(cx, cy - 1, (255, 255, 255))
        put(cx + side * 1.8 + 0.5, cy + 2.5, BLUSH)
    my = ry * 0.34
    if mood == "fall" or r < 6:
        put(ex, my, (120, 40, 40))                       # small round "o" of surprise
        if r >= 6:
            put(ex + 1, my, (120, 40, 40)); put(ex, my + 1, (120, 40, 40)); put(ex + 1, my + 1, (120, 40, 40))
    elif mood == "charge":
        for dx in range(-1, 3):
            put(ex + dx, my, EYE)
        put(ex, my - 1, (240, 240, 230)); put(ex + 1, my - 1, (240, 240, 230))   # gritted teeth
    else:
        put(ex - 1, my, EYE); put(ex + 2, my, EYE)
        put(ex, my + 1, (150, 50, 50)); put(ex + 1, my + 1, (150, 50, 50))
        put(ex, my, (150, 50, 50)); put(ex + 1, my, (150, 50, 50))
    if flip:                                             # tumbling: upside down
        px = {(x, -y): c for (x, y), c in px.items()}
    return px


def paste(cv, cx, cy, owner="mob", **kw):
    for (x, y), c in build(**kw).items():
        cv.set(cx + x, cy + y, c, owner)
