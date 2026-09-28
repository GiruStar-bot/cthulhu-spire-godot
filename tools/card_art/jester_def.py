"""戯神ちゃん — canonical pixel sprite (52 x 133), baked.

Defined from her standing portrait (art/pixel/ui/nyar_gift.png) at x0.09 with her own
colours, then hand-finished: outline, the blindfold-like shadow band over the eyes (her
signature — no eyes are drawn), blush and a sly smile. See claude/jester-pixel-design.md.
The pixels are stored in jester_sprite.json so this needs no source image and no sklearn.
"""
import json, os

SKIN = ((244, 208, 176), (222, 176, 146), (176, 128, 110), (120, 80, 76))
_D = json.load(open(os.path.join(os.path.dirname(__file__), "jester_sprite.json")))


def build():
    return {(p[0], p[1]): (p[2], p[3], p[4]) for p in _D["px"]}, tuple(_D["size"])
