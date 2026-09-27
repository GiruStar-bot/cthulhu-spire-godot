"""Build the Byakhee's pixel wingbeat and chest-rift card-cast sheets."""

from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/byakhee"
WIDTH, HEIGHT, TOP = 112, 168, 48
IDLE_FRAMES, FRAMES, FIRE_FRAME = 6, 15, 11
INK = "#201428"
VOID = "#0c0b17"
PLUM = "#5b3c70"
VIOLET = "#a17bc6"
PALE = "#e7cafd"
EYE = "#ade5da"
EYE_FIRE = "#d8fff2"


def native(name: str) -> Image.Image:
    image = Image.open(SOURCE / name).convert("RGBA")
    image = image.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    # Generated sources occasionally contain detached one-pixel opaque noise.
    alpha = image.getchannel("A")
    visited = set()
    largest = set()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if not alpha.getpixel((x, y)) or (x, y) in visited:
                continue
            component = {(x, y)}
            stack = [(x, y)]
            visited.add((x, y))
            while stack:
                px, py = stack.pop()
                for nx, ny in ((px - 1, py), (px + 1, py),
                               (px, py - 1), (px, py + 1)):
                    if (0 <= nx < WIDTH and 0 <= ny < HEIGHT
                            and (nx, ny) not in visited
                            and alpha.getpixel((nx, ny))):
                        visited.add((nx, ny))
                        component.add((nx, ny))
                        stack.append((nx, ny))
            if len(component) > len(largest):
                largest = component
    cleaned = Image.new("L", (WIDTH, HEIGHT))
    for x, y in largest:
        cleaned.putpixel((x, y), 255)
    image.putalpha(cleaned)
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


def line(draw: ImageDraw.ImageDraw, coords: list[tuple[int, int]], color: str) -> None:
    draw.line([(x, y + TOP) for x, y in coords], fill=color, width=1)


def rift(draw: ImageDraw.ImageDraw, rx: int, ry: int, rim: str) -> None:
    cx, cy = 56, 67 + TOP
    points = [(cx, cy - ry), (cx + rx, cy),
              (cx, cy + ry), (cx - rx, cy)]
    draw.polygon(points, fill=INK)
    draw.polygon([(cx, cy - ry + 2), (cx + rx - 2, cy),
                  (cx, cy + ry - 2), (cx - rx + 2, cy)], fill=VOID)
    draw.line(points + [points[0]], fill=rim, width=2)


def effect_frame(frame: int) -> Image.Image:
    """The actual enemy card appears through this tear at FIRE_FRAME."""
    fx = Image.new("RGBA", (WIDTH, HEIGHT + TOP))
    draw = ImageDraw.Draw(fx)
    if frame == 7:
        point(draw, 56, 67, PLUM)
        point(draw, 58, 69, VIOLET)
    elif frame == 8:
        line(draw, [(47, 61), (52, 64), (55, 67)], PLUM)
        line(draw, [(65, 61), (60, 64), (57, 67)], PLUM)
        rift(draw, 3, 5, VIOLET)
    elif frame == 9:
        line(draw, [(45, 58), (49, 62), (52, 65)], VIOLET)
        line(draw, [(67, 58), (63, 62), (60, 65)], VIOLET)
        rift(draw, 6, 8, VIOLET)
        for x, y in ((43, 55), (69, 56), (47, 77), (65, 76)):
            point(draw, x, y, PLUM)
    elif frame == 10:
        rift(draw, 10, 13, PALE)
        line(draw, [(46, 67), (40, 62), (38, 56)], VIOLET)
        line(draw, [(66, 67), (72, 62), (74, 56)], VIOLET)
        for x, y in ((54, 53), (60, 77), (42, 73), (70, 72)):
            point(draw, x, y, PALE)
    elif frame == FIRE_FRAME:
        # The split and eye flash share the real-card spawn frame.
        for side in (-1, 1):
            x = 56 + side * 14
            draw.line([(56 + side * 3, 53 + TOP), (x, 56 + TOP),
                       (x + side * 8, 65 + TOP), (x, 78 + TOP),
                       (x + side * 11, 84 + TOP)], fill=PALE, width=2)
            line(draw, [(56 + side * 4, 57), (x + side * 3, 66),
                        (x + side * 9, 76)], VIOLET)
            line(draw, [(x + side * 10, 52), (x + side * 17, 46)], PALE)
        for x, y in ((24, 56), (88, 57), (21, 78), (91, 80),
                     (54, 45), (60, 47), (32, 91), (80, 91)):
            point(draw, x, y, PALE)
    elif frame == 12:
        for x, y in ((31, 51), (81, 53), (24, 73), (88, 72),
                     (50, 37), (63, 39)):
            point(draw, x, y, PALE if x % 2 else VIOLET)
        line(draw, [(28, 73), (23, 65), (26, 58)], VIOLET)
        line(draw, [(84, 73), (89, 65), (86, 58)], VIOLET)
    elif frame == 13:
        for x, y in ((43, 49), (69, 48), (52, 32), (61, 34)):
            point(draw, x, y, PLUM)
    return fx


def main() -> None:
    idle = native("idle.png")
    asym = native("idle_asym.png")
    up = native("wings_up.png")
    half = native("cast_half.png")
    full = native("cast_full.png")
    palette = shared_palette([idle, asym, up, half, full])
    idle, asym, up, half, full = [
        palette_map(image, palette) for image in (idle, asym, up, half, full)
    ]
    # Each pose is a complete redraw: the large moving wing shadows stay attached.
    poses = [idle, asym, up, up, asym, idle,
             idle, up, half, full, full, full, full, half, idle]
    body = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT))
    fx_sheet = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT + TOP))
    contact = Image.new("RGBA", (WIDTH * FRAMES, HEIGHT + TOP), (7, 20, 24, 255))
    previews = []
    for frame, pose in enumerate(poses):
        sprite = pose.copy()
        eyes = ImageDraw.Draw(sprite)
        for x in (47, 64):
            eyes.point((x, 36), fill=EYE_FIRE if frame == FIRE_FRAME else EYE)
        body.alpha_composite(sprite, (frame * WIDTH, 0))
        fx = effect_frame(frame)
        fx_sheet.alpha_composite(fx, (frame * WIDTH, 0))
        preview = Image.new("RGBA", (WIDTH, HEIGHT + TOP), (7, 20, 24, 255))
        preview.alpha_composite(sprite, (0, TOP))
        preview.alpha_composite(fx)
        contact.alpha_composite(preview, (frame * WIDTH, 0))
        previews.append(preview)
    body.save(PIXELS / "byakhee_body_1.png")
    fx_sheet.save(PIXELS / "byakhee_fx_1.png")
    contact.save(SOURCE / "byakhee_contact_preview.png")
    previews[FIRE_FRAME].resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "byakhee_fire_preview.png")
    previews[FIRE_FRAME - 1].resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "byakhee_rift_preview.png")
    durations = [190, 170, 220, 180, 190, 210,
                 120, 160, 170, 190, 220, 240, 180, 170, 200]
    gif = [frame.resize((336, 648), Image.Resampling.NEAREST).convert("RGB")
           for frame in previews]
    gif[0].save(SOURCE / "byakhee_preview.gif", save_all=True,
                append_images=gif[1:], duration=durations, loop=0,
                optimize=False)


if __name__ == "__main__":
    main()
