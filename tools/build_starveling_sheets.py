"""Build the Starveling's native pixel sheets from three full-body key poses."""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/starveling"
WIDTH, HEIGHT, TOP, COUNT = 112, 168, 48, 11


def native(name: str, down: int = 0) -> Image.Image:
    image = Image.open(SOURCE / name).convert("RGBA")
    image = image.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    image.putalpha(alpha)
    if down:
        placed = Image.new("RGBA", (WIDTH, HEIGHT))
        placed.alpha_composite(image, (0, down))
        return placed
    return image


def common_palette(images: list[Image.Image]) -> Image.Image:
    colors = []
    for image in images:
        pixels = (image.get_flattened_data() if hasattr(image, "get_flattened_data")
                  else image.getdata())
        colors.extend((r, g, b) for r, g, b, a in pixels if a)
    samples = Image.new("RGB", (len(colors), 1))
    samples.putdata(colors)
    return samples.quantize(colors=48, method=Image.Quantize.MEDIANCUT)


def apply_palette(image: Image.Image, palette: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    result = image.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def bubble(draw: ImageDraw.ImageDraw, x: int, y: int, radius: int) -> None:
    draw.ellipse((x - radius, y - radius, x + radius, y + radius),
                 fill="#10445e", outline="#71eced", width=1)
    draw.point((x - radius + 1, y - radius), fill="#d4fff1")
    draw.point((x + 1, y + radius - 1), fill="#279db6")


def water_effect(frame: int, effect: Image.Image) -> None:
    draw = ImageDraw.Draw(effect)
    if frame in (3, 4):
        # A few droplets are pulled toward the hungry mouth.
        for x, y, radius in ((37, 77, 2), (79, 75, 2), (48, 68, 1),
                              (69, 64, 1)):
            bubble(draw, x, y + TOP, radius)
    elif frame == 5:
        # Spat water gathers into a loose, bubbly card silhouette at the chest.
        for x, y, radius in ((56, 59, 3), (61, 66, 3), (54, 71, 2),
                              (50, 77, 3), (62, 77, 3), (49, 86, 3),
                              (63, 87, 3), (55, 93, 2)):
            bubble(draw, x, y + TOP, radius)
        draw.line((55, TOP + 56, 59, TOP + 64), fill="#93f3ee", width=2)
        draw.line((56, TOP + 72, 56, TOP + 91), fill="#48c9d8", width=1)
    elif frame == 6:
        # At cast_fire the bubbles close around the card at the sternum.
        for x, y, radius in ((46, 75, 3), (66, 77, 3), (47, 91, 2),
                              (65, 94, 3), (56, 68, 2)):
            bubble(draw, x, y + TOP, radius)
        for x, y in ((43, 83), (69, 86), (55, 99)):
            draw.point((x, y + TOP), fill="#d4fff1")
    elif frame == 7:
        for x, y, radius in ((47, 81, 1), (64, 84, 1), (58, 92, 1)):
            bubble(draw, x, y + TOP, radius)


def main() -> None:
    idle = native("idle.png")
    inhale = native("inhale.png", down=5)
    release = native("release.png", down=7)
    palette = common_palette([idle, inhale, release])
    idle, inhale, release = [apply_palette(p, palette)
                             for p in (idle, inhale, release)]
    breath = Image.new("RGBA", (WIDTH, HEIGHT))
    breath.alpha_composite(idle, (0, -1))
    poses = [idle, breath, idle, inhale, inhale, release,
             release, release, release, inhale, idle]
    body = Image.new("RGBA", (WIDTH * COUNT, HEIGHT))
    fx = Image.new("RGBA", (WIDTH * COUNT, HEIGHT + TOP))
    cards = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    for frame, pose in enumerate(poses):
        body.alpha_composite(pose, (frame * WIDTH, 0))
        effect = Image.new("RGBA", (WIDTH, HEIGHT + TOP))
        water_effect(frame, effect)
        if 6 <= frame <= 10:
            source = frame - 1  # existing fanatic card: chest -> above -> scatter
            card = cards.crop((source * 96, 0, (source + 1) * 96, 204))
            bounds = card.getbbox()
            if bounds:
                card = card.crop(bounds)
                center_y = {6: 130, 7: 112, 8: 69, 9: 30, 10: 9}[frame]
                effect.alpha_composite(card, (56 - card.width // 2,
                                              center_y - card.height // 2))
        fx.alpha_composite(effect, (frame * WIDTH, 0))
    body.save(PIXELS / "starveling_body_1.png")
    fx.save(PIXELS / "starveling_fx_1.png")
    preview_frames = []
    contact = Image.new("RGBA", (WIDTH * COUNT, HEIGHT + TOP), (7, 20, 24, 255))
    for frame in range(COUNT):
        preview = Image.new("RGBA", (WIDTH, HEIGHT + TOP), (7, 20, 24, 255))
        preview.alpha_composite(
            body.crop((frame * WIDTH, 0, (frame + 1) * WIDTH, HEIGHT)),
            (0, TOP))
        preview.alpha_composite(
            fx.crop((frame * WIDTH, 0, (frame + 1) * WIDTH, HEIGHT + TOP)))
        contact.alpha_composite(preview, (frame * WIDTH, 0))
        preview_frames.append(preview)
    contact.save(SOURCE / "starveling_contact_preview.png")
    preview_frames[6].resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "starveling_fire_preview.png")
    gif_frames = [frame.resize((336, 648), Image.Resampling.NEAREST).convert("RGB")
                  for frame in preview_frames]
    gif_frames[0].save(
        SOURCE / "starveling_preview.gif", save_all=True,
        append_images=gif_frames[1:],
        duration=[520, 420, 120, 180, 240, 130, 220, 160, 170, 190, 350],
        loop=0, optimize=False)


if __name__ == "__main__":
    main()
