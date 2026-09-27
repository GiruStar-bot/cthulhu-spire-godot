"""Build Spawn's grounded breathing and maw-cast pixel sheets.

The source concept is reduced once to a small, fixed palette. Every output
frame is composed afresh from that native-pixel base; no frame accumulates
parts or shadows from a previous frame.
"""

from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/spawn"
W, H, TOP, FRAMES, FIRE = 112, 168, 48, 13, 8
INK = (19, 16, 17, 255)


def native_base() -> Image.Image:
    source = Image.open(SOURCE / "spawn_concept.png").convert("RGB")
    image = source.resize((W, H), Image.Resampling.NEAREST)
    # The generated concept has an opaque near-black background. Trace its
    # contiguous lit body and replace only the background with real alpha.
    lit = {(x, y) for y in range(H) for x in range(W)
           if max(image.getpixel((x, y))) >= 64}
    visited: set[tuple[int, int]] = set()
    largest: set[tuple[int, int]] = set()
    for seed in lit:
        if seed in visited:
            continue
        component = {seed}
        queue = deque([seed])
        visited.add(seed)
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x - 1, y), (x + 1, y),
                             (x, y - 1), (x, y + 1)):
                if neighbor in lit and neighbor not in visited:
                    visited.add(neighbor)
                    component.add(neighbor)
                    queue.append(neighbor)
        if len(component) > len(largest):
            largest = component
    # A one-pixel ink border replaces the concept's diffuse halo.
    mask = Image.new("L", (W, H))
    for x, y in largest:
        mask.putpixel((x, y), 255)
    mask = mask.filter(ImageFilter.MaxFilter(3))
    palette = image.quantize(colors=28, method=Image.Quantize.MEDIANCUT,
                             dither=Image.Dither.NONE).convert("RGBA")
    palette.putalpha(mask)
    for y in range(H):
        for x in range(W):
            if mask.getpixel((x, y)) and (x, y) not in largest:
                palette.putpixel((x, y), INK)
    palette.save(SOURCE / "spawn_native_base.png")
    return palette


def body_pose(base: Image.Image, breathe: int, crouch: int) -> Image.Image:
    """Deform the entire silhouette as one grounded key pose.

    The head and shoulders rise with the inhalation, while the shoulders
    broaden and the belly swells. During the wind-up, all three compress
    together. The knees transition into unmoving feet at ground contact.
    """
    result = Image.new("RGBA", (W, H))
    for y in range(H):
        upper_weight = min(1.0, max(0.0, (150 - y) / 40.0))
        shoulder_weight = max(0.0, 1.0 - abs(y - 78) / 41.0)
        belly_weight = max(0.0, 1.0 - abs(y - 111) / 43.0)
        vertical = round((0.8 * breathe - 1.2 * crouch) * upper_weight)
        widen = round((0.75 * breathe - 0.45 * crouch) * shoulder_weight
                      + (1.25 * breathe - 1.0 * crouch) * belly_weight)
        source_y = min(H - 1, max(0, y + vertical))
        for x in range(W):
            sample_x = round(56 + (x - 56) * (1.0 - widen / 55.0))
            if 0 <= sample_x < W:
                result.putpixel((x, y), base.getpixel((sample_x, source_y)))
    return result


def open_maw(image: Image.Image, pose: Image.Image,
             extra: int, head_shift: int) -> None:
    """Open the existing shaded mouth without replacing its rim or teeth."""
    if not extra:
        return
    # The oval includes the original cheek and tooth shading. Masking its
    # outer edge avoids the rectangular cut-out visible in a scaled patch.
    left, top, right, bottom = 37, 27 + head_shift, 76, 70 + head_shift
    patch = pose.crop((left, top, right, bottom))
    width, height = patch.size
    enlarged = patch.resize((width + extra * 2, height + extra * 2),
                            Image.Resampling.NEAREST)
    mask = Image.new("L", enlarged.size)
    ImageDraw.Draw(mask).ellipse((1, 1, enlarged.width - 2,
                                 enlarged.height - 2), fill=255)
    enlarged.putalpha(mask)
    image.alpha_composite(enlarged,
                          (left - extra, top - extra))


def effect(frame: int, shared: Image.Image) -> Image.Image:
    fx = Image.new("RGBA", (W, H + TOP))
    draw = ImageDraw.Draw(fx)
    cy = TOP + 49
    if 6 <= frame <= 8:
        # Short, uneven spit trails connect the mouth to the shared card.
        # They inherit the monster's olive color, so the gold/teal card
        # remains the same visual signal as every other pixel enemy.
        length = {6: 2, 7: 4, 8: 7}[frame]
        for x, offset in ((51, 0), (57, 2), (62, -1)):
            draw.line((x, cy + 8, x + offset, cy + 8 + length),
                      fill=(143, 139, 77, 255), width=1)
    if FIRE <= frame <= FIRE + 4:
        source_index = frame - FIRE + 5  # Exact fanatic card frames 5..9.
        card = shared.crop((source_index * 96, 0,
                            (source_index + 1) * 96, 204))
        bounds = card.getbbox()
        if bounds:
            card = card.crop(bounds)
            center_y = {8: 96, 9: 82, 10: 64, 11: 45, 12: 30}[frame]
            fx.alpha_composite(card, (56 - card.width // 2,
                                      center_y - card.height // 2))
    return fx


def main() -> None:
    base = native_base()
    shared = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    # Two uneven breaths, then a held compression before the mouth snaps open.
    breaths = [0, 1, 2, 1, 0, 0, 0, 0, 2, 1, 1, 0, 0]
    crouches = [0, 0, 0, 0, 0, 1, 2, 2, 0, 0, 0, 0, 0]
    openings = [0, 0, 0, 0, 0, 0, 1, 3, 5, 5, 3, 1, 0]
    body_sheet = Image.new("RGBA", (W * FRAMES, H))
    fx_sheet = Image.new("RGBA", (W * FRAMES, H + TOP))
    previews = []
    for frame in range(FRAMES):
        body = body_pose(base, breaths[frame], crouches[frame])
        head_shift = -round(0.8 * breaths[frame] - 1.2 * crouches[frame])
        open_maw(body, body.copy(), openings[frame], head_shift)
        body_sheet.alpha_composite(body, (frame * W, 0))
        vfx = effect(frame, shared)
        fx_sheet.alpha_composite(vfx, (frame * W, 0))
        preview = Image.new("RGBA", (W, H + TOP), (7, 20, 24, 255))
        preview.alpha_composite(body, (0, TOP))
        preview.alpha_composite(vfx)
        previews.append(preview)
    body_sheet.save(PIXELS / "spawn_body_1.png")
    fx_sheet.save(PIXELS / "spawn_fx_1.png")
    contact = Image.new("RGBA", (W * FRAMES, H + TOP))
    for index, preview in enumerate(previews):
        contact.alpha_composite(preview, (index * W, 0))
    contact.save(SOURCE / "spawn_contact_preview.png")
    previews[FIRE].resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "spawn_fire_preview.png")
    gif = [p.resize((336, 648), Image.Resampling.NEAREST).convert("RGB")
           for p in previews]
    gif[0].save(SOURCE / "spawn_preview.gif", save_all=True,
                append_images=gif[1:],
                duration=[320, 320, 320, 320, 180, 170, 230,
                          140, 220, 180, 170, 190, 650],
                loop=0, optimize=False)


if __name__ == "__main__":
    main()
