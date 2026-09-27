"""Build the Colour's hovering palette-cycle and cocoon-to-card cast sheets."""

import colorsys
import math
from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/colour"
WIDTH, HEIGHT, TOP = 112, 168, 48
IDLE_FRAMES, TOTAL_FRAMES = 6, 16
TAU = 2.0 * math.pi
RAINBOW = ("#baef78", "#5de0c2", "#71b9f4", "#a787ef",
           "#e178d9", "#e7a878")


def native(name: str, shrink: bool = False) -> Image.Image:
    image = Image.open(SOURCE / name).convert("RGBA")
    if shrink:
        # The generated weaving pose reaches farther upward than the idle pose.
        # Fit it within the same floating silhouette without cropping its roots.
        image = image.resize((940, 1412), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (1024, 1536))
        canvas.alpha_composite(image, (42, 105))
        image = canvas
    image = image.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return image


def flowing_color(image: Image.Image, phase: int) -> Image.Image:
    """Shift broad color bands through opaque material; keep dark outlines fixed."""
    src = list(image.get_flattened_data() if hasattr(image, "get_flattened_data")
               else image.getdata())
    dst = []
    for index, (r, g, b, a) in enumerate(src):
        if a == 0:
            dst.append((0, 0, 0, 0))
            continue
        shade = 0.24 * r + 0.62 * g + 0.14 * b
        if shade < 62:
            dst.append((r, g, b, 255))
            continue
        x, y = index % WIDTH, index // WIDTH
        band = math.sin(y * 0.115 - x * 0.067 + phase * TAU / IDLE_FRAMES)
        hue = 0.29 + (band + 1.0) * 0.195  # lime -> aqua -> violet
        tr, tg, tb = colorsys.hsv_to_rgb(hue, 0.65, 1.0)
        target = (tr * 255, tg * 255, tb * 255)
        weight = 0.34 + 0.10 * math.sin(x * 0.08 + phase * TAU / IDLE_FRAMES)
        scale = shade / 180.0
        dst.append(tuple(max(0, min(255, round(original * (1.0 - weight)
                         + target_channel * scale * weight)))
                         for original, target_channel in zip((r, g, b), target))
                   + (255,))
    out = Image.new("RGBA", image.size)
    out.putdata(dst)
    return out


def common_palette(images: list[Image.Image]) -> Image.Image:
    visible = []
    for image in images:
        pixels = (image.get_flattened_data() if hasattr(image, "get_flattened_data")
                  else image.getdata())
        visible.extend((r, g, b) for r, g, b, a in pixels if a)
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    return samples.quantize(colors=64, method=Image.Quantize.MEDIANCUT)


def palette_map(image: Image.Image, palette: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    result = image.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def point(draw: ImageDraw.ImageDraw, x: int, y: int, color: str) -> None:
    draw.point((x, y + TOP), fill=color)


def thread(draw: ImageDraw.ImageDraw, coords: list[tuple[int, int]], color: str) -> None:
    draw.line([(x, y + TOP) for x, y in coords], fill=color, width=1)


def cocoon(draw: ImageDraw.ImageDraw, frame: int) -> None:
    center_x, center_y = 56, 60
    rx, ry = (9, 13) if frame == 8 else (11, 17)
    for y in range(center_y - ry, center_y + ry + 1):
        for x in range(center_x - rx, center_x + rx + 1):
            radius = ((x - center_x) / rx) ** 2 + ((y - center_y) / ry) ** 2
            if radius > 1.0:
                continue
            if frame == 8 and radius < 0.55:
                continue  # loose first loop, not a finished shell
            stripe = ((x + 2 * y) // 6 + frame) % len(RAINBOW)
            if radius > 0.87:
                color = "#262236"
            elif (x + 2 * y + frame * 3) % 9 <= 1:
                color = "#39244b"  # thin negative gaps between wound strands
            elif (2 * x - y) % 11 == 0:
                color = "#e8ffcf"  # crossing thread catches the light
            else:
                color = RAINBOW[stripe]
            point(draw, x, y, color)
    if frame >= 9:
        for offset in (-10, -4, 2, 8):
            thread(draw, [(center_x - rx + 2, center_y + offset - 4),
                          (center_x + rx - 2, center_y + offset + 4)],
                   RAINBOW[(offset + frame) % len(RAINBOW)])
    if frame == 10:
        thread(draw, [(53, 47), (57, 52), (54, 58), (59, 64), (55, 72)],
               "#f3ffd1")


def effect_frame(frame: int, cards: Image.Image) -> Image.Image:
    effect = Image.new("RGBA", (WIDTH, HEIGHT + TOP))
    draw = ImageDraw.Draw(effect)
    if frame in (7, 8, 9, 10):
        sweep = frame - 7
        thread(draw, [(34, 51), (41, 49 + sweep), (47, 54), (51, 58)],
               RAINBOW[sweep])
        thread(draw, [(78, 51), (71, 49 + sweep), (65, 54), (61, 58)],
               RAINBOW[(sweep + 3) % 6])
        thread(draw, [(47, 77), (51, 69), (54, 67)], RAINBOW[(sweep + 1) % 6])
        thread(draw, [(66, 77), (62, 70), (59, 67)], RAINBOW[(sweep + 4) % 6])
        if frame >= 8:
            cocoon(draw, frame)
    if frame == 11:
        # The cocoon breaks at cast_fire; its center becomes the card.
        for index, (dx, dy) in enumerate(((-24, -18), (-20, 4), (-16, 20),
                                          (0, -27), (0, 28), (16, -19),
                                          (23, 7), (18, 20))):
            color = RAINBOW[index % len(RAINBOW)]
            thread(draw, [(56 + dx // 3, 60 + dy // 3),
                          (56 + dx, 60 + dy)], color)
            point(draw, 56 + dx, 60 + dy, "#e5ffd7")
    elif frame == 12:
        for x, y, color in ((35, 45, RAINBOW[1]), (77, 72, RAINBOW[4]),
                             (40, 81, RAINBOW[3]), (72, 38, RAINBOW[0])):
            point(draw, x, y, color)
    if 11 <= frame <= 15:
        source = frame - 6  # fanatic card frames 5..9
        card = cards.crop((source * 96, 0, (source + 1) * 96, 204))
        bounds = card.getbbox()
        if bounds:
            card = card.crop(bounds)
            cy = {11: 111, 12: 93, 13: 60, 14: 29, 15: 9}[frame]
            effect.alpha_composite(card, (56 - card.width // 2,
                                          cy - card.height // 2))
    return effect


def main() -> None:
    idle = native("idle.png")
    weave = native("weave.png", shrink=True)
    burst = native("burst.png")
    poses = [flowing_color(idle, i) for i in range(IDLE_FRAMES)]
    poses.extend((flowing_color(idle, 0),
                  flowing_color(weave, 1), flowing_color(weave, 2),
                  flowing_color(weave, 3), flowing_color(weave, 4),
                  flowing_color(burst, 5), flowing_color(burst, 0),
                  flowing_color(burst, 1), flowing_color(weave, 2),
                  flowing_color(idle, 3)))
    assert len(poses) == TOTAL_FRAMES
    palette = common_palette(poses)
    body = Image.new("RGBA", (WIDTH * TOTAL_FRAMES, HEIGHT))
    fx = Image.new("RGBA", (WIDTH * TOTAL_FRAMES, HEIGHT + TOP))
    cards = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    contact = Image.new("RGBA", (WIDTH * TOTAL_FRAMES, HEIGHT + TOP),
                        (7, 20, 24, 255))
    previews = []
    for frame, pose in enumerate(poses):
        sprite = palette_map(pose, palette)
        body.alpha_composite(sprite, (frame * WIDTH, 0))
        effect = effect_frame(frame, cards)
        fx.alpha_composite(effect, (frame * WIDTH, 0))
        preview = Image.new("RGBA", (WIDTH, HEIGHT + TOP), (7, 20, 24, 255))
        preview.alpha_composite(sprite, (0, TOP))
        preview.alpha_composite(effect)
        contact.alpha_composite(preview, (frame * WIDTH, 0))
        previews.append(preview)
    body.save(PIXELS / "colour_body_1.png")
    fx.save(PIXELS / "colour_fx_1.png")
    contact.save(SOURCE / "colour_contact_preview.png")
    for frame, name in ((9, "colour_cocoon_preview.png"),
                        (11, "colour_fire_preview.png")):
        previews[frame].resize((448, 864), Image.Resampling.NEAREST).save(
            SOURCE / name)
    gif = [frame.resize((336, 648), Image.Resampling.NEAREST).convert("RGB")
           for frame in previews]
    gif[0].save(SOURCE / "colour_preview.gif", save_all=True,
                append_images=gif[1:],
                duration=[200] * 6 + [120, 160, 180, 200, 180,
                                      200, 170, 170, 180, 280],
                loop=0, optimize=False)


if __name__ == "__main__":
    main()
