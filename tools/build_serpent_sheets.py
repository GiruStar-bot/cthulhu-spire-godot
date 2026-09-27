"""Build the Mu serpent-man's native pixel body and pendant-water card FX."""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/serpent"
WIDTH, HEIGHT, TOP, FRAMES = 112, 168, 48, 11
GOLD, PALE, AQUA, DEEP = "#f6dc76", "#d6fff0", "#78eadf", "#187d8a"


def native(name: str, down: int = 0) -> Image.Image:
    image = Image.open(SOURCE / name).convert("RGBA")
    image = image.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    if down:
        aligned = Image.new("RGBA", (WIDTH, HEIGHT))
        aligned.alpha_composite(image, (0, down))
        return aligned
    return image


def palette_for(images: list[Image.Image]) -> Image.Image:
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
    result = image.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def water_ring(draw: ImageDraw.ImageDraw, radius: int, color: str) -> None:
    cx, cy = 56, TOP + 60
    bounds = (cx - radius, cy - radius, cx + radius, cy + radius)
    for start, end in ((18, 155), (200, 342)):
        draw.arc(bounds, start, end, fill=DEEP, width=3)
        draw.arc(bounds, start, end, fill=color, width=1)


def sparkle(draw: ImageDraw.ImageDraw, x: int, y: int, color: str) -> None:
    y += TOP
    draw.point((x - 2, y, x + 2, y), fill=color)
    draw.point((x, y - 2, x, y + 2), fill=color)


def draw_effect(frame: int, cards: Image.Image) -> Image.Image:
    fx = Image.new("RGBA", (WIDTH, HEIGHT + TOP))
    draw = ImageDraw.Draw(fx)
    if frame in (3, 4, 5):
        # Water rises from both palms and wraps the gold pendant.
        draw.line((37, TOP + 57, 44, TOP + 62, 49, TOP + 57),
                  fill=AQUA, width=1)
        draw.line((75, TOP + 57, 68, TOP + 62, 63, TOP + 57),
                  fill=AQUA, width=1)
        water_ring(draw, {3: 6, 4: 11, 5: 16}[frame],
                   {3: GOLD, 4: AQUA, 5: PALE}[frame])
        sparkle(draw, 56, 52, GOLD)
    if frame == 5:
        for x, y in ((36, 49), (75, 50), (43, 75), (69, 77)):
            sparkle(draw, x, y, AQUA)
    if frame == 6:
        # The pendant-water surface parts exactly as the real card is revealed.
        for radius, color in ((12, GOLD), (20, AQUA)):
            water_ring(draw, radius, color)
        for x1, y1, x2, y2 in ((35, 44, 29, 39), (77, 44, 83, 39),
                               (38, 75, 31, 81), (74, 75, 81, 81)):
            draw.line((x1, TOP + y1, x2, TOP + y2), fill=AQUA, width=2)
        for x, y in ((30, 53), (82, 54), (46, 84), (68, 84)):
            sparkle(draw, x, y, PALE)
    elif frame == 7:
        water_ring(draw, 23, DEEP)
        for x, y in ((29, 52), (83, 50), (38, 78), (74, 78)):
            sparkle(draw, x, y, AQUA)
    elif frame == 8:
        for x, y in ((23, 54), (89, 56), (32, 76), (80, 75)):
            draw.point((x, y + TOP), fill=DEEP)
    if 6 <= frame <= 10:
        source = frame - 1  # Existing fanatic card frames 5..9.
        card = cards.crop((source * 96, 0, (source + 1) * 96, 204))
        bounds = card.getbbox()
        if bounds:
            card = card.crop(bounds)
            center_y = {6: 108, 7: 94, 8: 64, 9: 29, 10: 9}[frame]
            fx.alpha_composite(card, (56 - card.width // 2,
                                      center_y - card.height // 2))
    return fx


def main() -> None:
    idle = native("idle.png")
    idle_b = native("idle_b.png", down=3)
    prepare = native("prepare.png")
    release = native("release.png", down=3)
    palette = palette_for([idle, idle_b, prepare, release])
    idle, idle_b, prepare, release = [palette_map(image, palette)
                                      for image in (idle, idle_b, prepare, release)]
    poses = [idle, idle_b, idle, prepare, prepare, release,
             release, release, release, prepare, idle]
    body = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT))
    fx = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT + TOP))
    contact = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT + TOP),
                        (7, 20, 24, 255))
    cards = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    previews = []
    for frame, pose in enumerate(poses):
        sprite = pose.copy()
        if frame == 6:
            # The two amber eye glints peak with the real card reveal.
            eyes = ImageDraw.Draw(sprite)
            eyes.point((51, 20, 64, 20), fill="#fff2a0")
            eyes.point((52, 21, 65, 21), fill="#f4bc35")
        body.alpha_composite(sprite, (frame * WIDTH, 0))
        effect = draw_effect(frame, cards)
        fx.alpha_composite(effect, (frame * WIDTH, 0))
        preview = Image.new("RGBA", (WIDTH, HEIGHT + TOP), (7, 20, 24, 255))
        preview.alpha_composite(sprite, (0, TOP))
        preview.alpha_composite(effect)
        contact.alpha_composite(preview, (frame * WIDTH, 0))
        previews.append(preview)
    body.save(PIXELS / "serpent_body_1.png")
    fx.save(PIXELS / "serpent_fx_1.png")
    contact.save(SOURCE / "serpent_contact_preview.png")
    previews[6].resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "serpent_fire_preview.png")
    gif = [frame.resize((336, 648), Image.Resampling.NEAREST).convert("RGB")
           for frame in previews]
    gif[0].save(SOURCE / "serpent_preview.gif", save_all=True,
                append_images=gif[1:],
                duration=[500, 500, 120, 180, 220, 180, 220, 180, 180, 190, 300],
                loop=0, optimize=False)


if __name__ == "__main__":
    main()
