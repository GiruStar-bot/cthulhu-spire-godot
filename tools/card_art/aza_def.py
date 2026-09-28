"""アザくん — canonical pixel sprite (29 x 44), baked.

Defined from the clearest card art of him (the child curled up in the geode) at card dot
density with the art's own moody colours; hair lifted, outlined, and hand-finished with
magenta horns, faintly glowing closed eyes and long pink nails. See claude/aza-pixel-design.md.
Stored in aza_sprite.json: no source image, no sklearn.
"""
import json, os

_D = json.load(open(os.path.join(os.path.dirname(__file__), "aza_sprite.json")))
GW, GH = _D["size"]


def build(eyes="closed"):
    return {(p[0], p[1]): (p[2], p[3], p[4]) for p in _D["px"]}


def paste(cv, left, top, owner="aza", **kw):
    for (x, y), c in build(**kw).items():
        cv.set(left + x, top + y, c, owner)
