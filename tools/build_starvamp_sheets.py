"""Build Starvamp's slow bat wingbeat and shared-card cast sheets."""

from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/starvamp"
W, H, TOP, FRAMES, FIRE = 128, 168, 48, 15, 10
INK = (25, 14, 34, 255)


def cutout(image: Image.Image) -> Image.Image:
    """Remove the generated black backdrop from all separated body parts."""
    rgb = image.convert("RGB")
    mask = Image.new("L", (W, H))
    for y in range(H):
        for x in range(W):
            if max(rgb.getpixel((x, y))) >= 73:
                mask.putpixel((x, y), 255)
    # Keep wings, feet and tube mouth even where dark joints separate them.
    # Close small gaps between membranes and their dark ribs.
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    outside = {(x, y) for x in range(W) for y in (0, H - 1)}
    outside.update((x, y) for y in range(H) for x in (0, W - 1))
    seen = set(outside)
    queue = deque(outside)
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y),
                       (x, y - 1), (x, y + 1)):
            if (0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen
                    and mask.getpixel((nx, ny)) == 0):
                seen.add((nx, ny))
                queue.append((nx, ny))
    for y in range(H):
        for x in range(W):
            if (x, y) not in seen:
                mask.putpixel((x, y), 255)
    bordered = mask.filter(ImageFilter.MaxFilter(3))
    result = rgb.convert("RGBA")
    result.putalpha(bordered)
    for y in range(H):
        for x in range(W):
            if bordered.getpixel((x, y)) and not mask.getpixel((x, y)):
                result.putpixel((x, y), INK)
    return result


def native(name: str, height_scale: float = 1.0,
           top_shift: int = 0) -> Image.Image:
    original = Image.open(SOURCE / name).convert("RGB")
    scaled_h = round(H * height_scale)
    scaled = original.resize((112, scaled_h), Image.Resampling.NEAREST)
    aligned = Image.new("RGB", (W, H), (0, 0, 0))
    aligned.paste(scaled, (8, top_shift))
    return cutout(aligned)


def palette_for(images: list[Image.Image]) -> Image.Image:
    visible = []
    for image in images:
        visible.extend((r, g, b) for r, g, b, a
                       in image.get_flattened_data() if a)
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    return samples.quantize(colors=36, method=Image.Quantize.MEDIANCUT)


def palette_map(image: Image.Image, palette: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    result = image.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def effect(frame: int, cards: Image.Image) -> Image.Image:
    fx = Image.new("RGBA", (W, H + TOP))
    if FIRE <= frame <= FIRE + 4:
        source_index = frame - FIRE + 5  # Fanatic's established card frames.
        card = cards.crop((source_index * 96, 0,
                           (source_index + 1) * 96, 204))
        bounds = card.getbbox()
        if bounds:
            card = card.crop(bounds)
            center_y = {10: 153, 11: 130, 12: 105, 13: 80, 14: 55}[frame]
            fx.alpha_composite(card, (W // 2 - card.width // 2,
                                      center_y - card.height // 2))
    return fx


def main() -> None:
    # The high-wing body dips; the downstroke lifts the whole body.
    # Complete poses preserve membrane shading and shoulder attachment.
    sources = [native("wings_mid.png"),
               native("wings_high.png", 1.00, -7),
               native("wings_low.png"),
               native("cast_fold.png")]
    palette = palette_for(sources)
    mid, high, low, fold = [
        palette_map(source, palette) for source in sources]
    for name, pose in zip(("wings_mid", "wings_high", "wings_low",
                           "cast_fold"), (mid, high, low, fold)):
        pose.save(SOURCE / f"{name}_native.png")
    # A broad, paired beat, followed by a cloak-like fold and sharp release.
    poses = [mid, high, mid, low, mid, mid,
             mid, fold, fold, fold, high, high, mid, low, mid]
    hover = [0, 0, 0, -1, 0, 0, 0, 0, 0, 0, -1, -1, 0, -1, 0]
    body_sheet = Image.new("RGBA", (W * FRAMES, H))
    fx_sheet = Image.new("RGBA", (W * FRAMES, H + TOP))
    cards = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    previews = []
    for frame, pose in enumerate(poses):
        body = Image.new("RGBA", (W, H))
        body.alpha_composite(pose, (0, hover[frame]))
        body_sheet.alpha_composite(body, (frame * W, 0))
        vfx = effect(frame, cards)
        fx_sheet.alpha_composite(vfx, (frame * W, 0))
        preview = Image.new("RGBA", (W, H + TOP), (7, 20, 24, 255))
        preview.alpha_composite(body, (0, TOP))
        preview.alpha_composite(vfx)
        previews.append(preview)
    body_sheet.save(PIXELS / "starvamp_body_1.png")
    fx_sheet.save(PIXELS / "starvamp_fx_1.png")
    contact = Image.new("RGBA", (W * FRAMES, H + TOP))
    for frame, preview in enumerate(previews):
        contact.alpha_composite(preview, (frame * W, 0))
    contact.save(SOURCE / "starvamp_contact_preview.png")
    previews[FIRE].resize((512, 864), Image.Resampling.NEAREST).save(
        SOURCE / "starvamp_fire_preview.png")
    gif = [preview.resize((384, 648), Image.Resampling.NEAREST).convert("RGB")
           for preview in previews]
    gif[0].save(SOURCE / "starvamp_preview.gif", save_all=True,
                append_images=gif[1:],
                duration=[240, 230, 210, 230, 240, 260,
                          160, 190, 230, 220, 250, 200, 190, 210, 650],
                loop=0, optimize=False)


if __name__ == "__main__":
    main()
