"""Generate the pixel-art card illustrations (53x59 PNG) and 戯神ちゃん's portraits.

Usage (from the repo root):
    python3 tools/card_art/gen_card_art.py art/pixel/cards art/pixel/ui
Deterministic: pure Python + Pillow, no randomness, no source images.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draw_cards, cards_elder, cards_fire, cards_water, cards_wind, cards_wind2, cards_earth, cards_earth2
import cards_knight2, cards_magic, cards_all, cards_aza, jester_card, card_death, jester_def
from PIL import Image

PACKS = {
    "elder": dict([("cats_paw", (draw_cards.cats_paw, 11)), ("far_guidance", (draw_cards.far_guidance, 11))], **cards_elder.ARTS),
    "fire": cards_fire.ARTS,
    "water": cards_water.ARTS,
    "wind": dict(cards_wind.ARTS, **cards_wind2.ARTS),
    "earth": dict(cards_earth.ARTS, **cards_earth2.ARTS),
    "knight": cards_knight2.ARTS,
    "magic": cards_magic.ARTS,
    "outer": dict(jester_card.ARTS, **cards_aza.ARTS, **card_death.ARTS),
    "all": cards_all.ARTS,
}
ARTS = {k: v for p in PACKS.values() for k, v in p.items()}


def jester_portraits(ui_dir):
    """nyar_gift.png: the full-body sprite x11 at the same place/size the old painting had it
    (1024x1536). host_trickster.png: her bust (hood to chest) x20, centred on 1254x1254."""
    px, (w, h) = jester_def.build()
    spr = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for (x, y), c in px.items():
        spr.putpixel((x, y), c + (255,))
    full = Image.new("RGBA", (1024, 1536), (0, 0, 0, 0))
    full.alpha_composite(spr.resize((w * 11, h * 11), Image.NEAREST), (224, 26))
    full.save(os.path.join(ui_dir, "nyar_gift.png"))
    bust = spr.crop((0, 0, w, 60))
    sq = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
    sq.alpha_composite(bust, ((60 - w) // 2, 0))
    host = Image.new("RGBA", (1254, 1254), (0, 0, 0, 0))
    host.alpha_composite(sq.resize((1200, 1200), Image.NEAREST), (27, 27))
    host.save(os.path.join(ui_dir, "host_trickster.png"))


if __name__ == "__main__":
    cards_dir = sys.argv[1] if len(sys.argv) > 1 else "out_cards"
    ui_dir = sys.argv[2] if len(sys.argv) > 2 else "out_ui"
    os.makedirs(cards_dir, exist_ok=True)
    os.makedirs(ui_dir, exist_ok=True)
    for name, (fn, top) in ARTS.items():
        fn().image(top).save(os.path.join(cards_dir, f"{name}.png"))
    jester_portraits(ui_dir)
    print(len(ARTS), "card images + 2 portraits")
