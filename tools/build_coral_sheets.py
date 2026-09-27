"""Build the coral knight's native-resolution pixel animation sheets.

Run from any directory with ``python tools/build_coral_sheets.py``. The large
transparent key poses are source material; Godot imports only the two sheets.
"""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/coral"
SIZE = (112, 168)
TOP = 48
FRAMES = 11


def native(name: str) -> Image.Image:
    image = Image.open(SOURCE / name).convert("RGBA")
    image = image.resize(SIZE, Image.Resampling.NEAREST)
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    image.putalpha(alpha)
    return image


def build_palette(images: list[Image.Image]) -> Image.Image:
    visible = []
    for image in images:
        pixels = (image.get_flattened_data() if hasattr(image, "get_flattened_data")
                  else image.getdata())
        visible.extend((r, g, b) for r, g, b, a in pixels if a)
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    return samples.quantize(colors=48, method=Image.Quantize.MEDIANCUT)


def palette_map(image: Image.Image, palette: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    mapped = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE)
    result = mapped.convert("RGBA")
    result.putalpha(alpha)
    return result


def sparkle(draw: ImageDraw.ImageDraw, x: int, y: int, color: str) -> None:
    draw.point((x - 2, y, x + 2, y), fill=color)
    draw.point((x, y - 2, x, y + 2), fill=color)


def energy(frame: int, image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    cyan = "#78f7f0"
    pale = "#d5fff3"
    dark = "#168d9e"
    if frame in (3, 4, 5):
        for x, y in ((13, 76), (27, 60), (9, 47), (30, 34)):
            sparkle(draw, x, y + TOP, pale if frame == 3 else cyan)
    if frame == 6:
        # The trident's BUTT is at x~21, y~151 in the impact pose.
        contact_y = TOP + 151
        for x, y in ((18, 83), (25, 106), (17, 130)):
            sparkle(draw, x, TOP + y, cyan)
        for radius, color in ((9, pale), (16, cyan), (25, dark)):
            draw.arc((21 - radius, contact_y - radius // 3,
                      21 + radius, contact_y + radius // 3), 5, 175,
                     fill=color, width=1)
        for x1, y1, x2, y2 in ((5, -6, 1, -12), (35, -5, 42, -11),
                                (12, -7, 8, -16), (31, -8, 35, -16)):
            draw.line((x1, contact_y + y1, x2, contact_y + y2), fill=cyan, width=2)
        for x, y in ((3, -14), (10, -20), (39, -17), (47, -8)):
            sparkle(draw, x, contact_y + y, pale)
    elif frame == 7:
        contact_y = TOP + 151
        for radius, color in ((18, cyan), (33, dark)):
            draw.arc((21 - radius, contact_y - radius // 3,
                      21 + radius, contact_y + radius // 3), 8, 172,
                     fill=color, width=1)
        for x, y in ((7, -18), (42, -14), (51, -5)):
            sparkle(draw, x, contact_y + y, cyan)
    elif frame == 8:
        for x, y in ((9, 132), (39, 140), (55, 150)):
            draw.point((x, TOP + y), fill=dark)
    elif frame == 10:
        for x, y in ((12, 32), (25, 40), (18, 78), (31, 104)):
            sparkle(draw, x, TOP + y, cyan)


def main() -> None:
    idle, raised, impact = [native(name) for name in
                            ("idle.png", "raised.png", "impact.png")]
    palette = build_palette([idle, raised, impact])
    idle, raised, impact = [palette_map(image, palette)
                            for image in (idle, raised, impact)]
    idle_breath = Image.new("RGBA", SIZE)
    idle_breath.alpha_composite(idle, (0, -1))
    body = Image.new("RGBA", (SIZE[0] * FRAMES, SIZE[1]))
    fx = Image.new("RGBA", (SIZE[0] * FRAMES, SIZE[1] + TOP))
    poses = [idle, idle_breath, idle, raised, raised, raised,
             impact, impact, impact, raised, idle]
    card_sheet = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    for frame, pose in enumerate(poses):
        body.alpha_composite(pose, (frame * SIZE[0], 0))
        effect = Image.new("RGBA", (SIZE[0], SIZE[1] + TOP))
        energy(frame, effect)
        if 6 <= frame <= 10:
            source_frame = frame - 1  # fanatic frames 5..9
            card = card_sheet.crop((source_frame * 96, 0,
                                    (source_frame + 1) * 96, 204))
            bounds = card.getbbox()
            if bounds:
                card = card.crop(bounds)
                # Card appears at the chest on impact, ascends above the head,
                # then disperses with the same artwork as the existing enemies.
                center_y = {6: 138, 7: 112, 8: 70, 9: 31, 10: 9}[frame]
                effect.alpha_composite(card, (56 - card.width // 2,
                                              center_y - card.height // 2))
        fx.alpha_composite(effect, (frame * SIZE[0], 0))
    body.save(PIXELS / "coral_body_1.png")
    fx.save(PIXELS / "coral_fx_1.png")


if __name__ == "__main__":
    main()
