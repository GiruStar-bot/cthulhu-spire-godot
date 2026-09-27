"""Build the Mi-Go's native pixel wingbeat and spore-to-card cast sheets."""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/migo"
WIDTH, HEIGHT, TOP = 112, 168, 48
IDLE_FRAMES, FRAMES, FIRE_FRAME = 4, 12, 8
INK = "#21172d"
DEEP = "#286a54"
SPORE = "#54cba5"
PALE = "#b9ffe1"
LILAC = "#e5b7ee"


def native(name: str) -> Image.Image:
    """Downsample once, then remove generated edge translucency and shading."""
    image = Image.open(SOURCE / name).convert("RGBA")
    image = image.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return image


def shared_palette(images: list[Image.Image]) -> Image.Image:
    visible = []
    for image in images:
        visible.extend((r, g, b) for r, g, b, a in image.get_flattened_data() if a)
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    return samples.quantize(colors=32, method=Image.Quantize.MEDIANCUT)


def palette_map(image: Image.Image, palette: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    result = image.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def point(draw: ImageDraw.ImageDraw, x: int, y: int, color: str) -> None:
    draw.point((x, y + TOP), fill=color)


def strand(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: str) -> None:
    draw.line([(x, y + TOP) for x, y in points], fill=color, width=1)


def glint(draw: ImageDraw.ImageDraw, x: int, y: int, color: str) -> None:
    point(draw, x, y, color)
    point(draw, x - 1, y, color)
    point(draw, x + 1, y, color)
    point(draw, x, y - 1, color)
    point(draw, x, y + 1, color)


def effect_frame(frame: int) -> Image.Image:
    """The real enemy card is drawn by Combat.gd at FIRE_FRAME."""
    fx = Image.new("RGBA", (WIDTH, HEIGHT + TOP))
    d = ImageDraw.Draw(fx)
    if frame == 4:
        point(d, 56, 70, DEEP)
    elif frame == 5:
        glint(d, 56, 68, SPORE)
        for x, y in ((49, 73), (63, 73)):
            point(d, x, y, DEEP)
    elif frame == 6:
        strand(d, [(43, 69), (48, 64), (51, 68)], SPORE)
        strand(d, [(69, 69), (64, 64), (61, 68)], LILAC)
        d.rectangle((51, 60 + TOP, 61, 74 + TOP), outline=DEEP)
        for x, y in ((53, 63), (58, 69), (56, 72)):
            point(d, x, y, PALE)
    elif frame == 7:
        strand(d, [(42, 68), (48, 61), (51, 65)], SPORE)
        strand(d, [(70, 68), (64, 61), (61, 65)], SPORE)
        d.rectangle((50, 57 + TOP, 62, 76 + TOP), outline=PALE, width=1)
        d.rectangle((52, 59 + TOP, 60, 74 + TOP), fill=DEEP)
        for x, y in ((54, 61), (58, 64), (53, 70), (57, 73)):
            point(d, x, y, SPORE)
        for x, y in ((46, 56), (66, 57), (44, 78), (68, 77)):
            point(d, x, y, LILAC)
    elif frame == FIRE_FRAME:
        # The pincer-held spores split as the actual card appears at the chest.
        for x1, y1, x2, y2 in ((50, 59, 43, 52), (62, 59, 69, 52),
                               (49, 73, 42, 79), (63, 73, 70, 79)):
            strand(d, [(x1, y1), (x2, y2)], PALE)
        for x, y in ((40, 57), (73, 56), (38, 73), (75, 74), (55, 47)):
            glint(d, x, y, SPORE)
    elif frame == 9:
        for x, y in ((42, 48), (70, 47), (36, 64), (77, 66), (51, 34), (62, 35)):
            glint(d, x, y, SPORE if x % 2 else LILAC)
    elif frame == 10:
        for x, y in ((45, 43), (68, 44), (53, 27), (60, 29)):
            point(d, x, y, DEEP if x % 2 else SPORE)
    return fx


def main() -> None:
    idle = native("idle.png")
    wings_up = native("idle_wings_up.png")
    half = native("cast_half.png")
    grip = native("cast_grip.png")
    palette = shared_palette([idle, wings_up, half, grip])
    idle, wings_up, half, grip = [
        palette_map(image, palette) for image in (idle, wings_up, half, grip)
    ]
    # A held beat lets the wings read separately from the much slower float tween.
    poses = [idle, wings_up, wings_up, idle,
             idle, wings_up, half, grip, grip, half, wings_up, idle]
    body = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT))
    fx_sheet = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT + TOP))
    contact = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT + TOP), (7, 20, 24, 255))
    previews = []
    for frame, pose in enumerate(poses):
        body.alpha_composite(pose, (frame * WIDTH, 0))
        fx = effect_frame(frame)
        fx_sheet.alpha_composite(fx, (frame * WIDTH, 0))
        preview = Image.new("RGBA", (WIDTH, HEIGHT + TOP), (7, 20, 24, 255))
        preview.alpha_composite(pose, (0, TOP))
        preview.alpha_composite(fx)
        contact.alpha_composite(preview, (frame * WIDTH, 0))
        previews.append(preview)
    body.save(PIXELS / "migo_body_1.png")
    fx_sheet.save(PIXELS / "migo_fx_1.png")
    contact.save(SOURCE / "migo_contact_preview.png")
    previews[FIRE_FRAME].resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "migo_fire_preview.png")
    durations = [220, 230, 220, 240, 120, 150, 170, 220, 200, 160, 160, 210]
    gif = [frame.resize((336, 648), Image.Resampling.NEAREST).convert("RGB")
           for frame in previews]
    gif[0].save(SOURCE / "migo_preview.gif", save_all=True,
                append_images=gif[1:], duration=durations, loop=0,
                optimize=False)


if __name__ == "__main__":
    main()
