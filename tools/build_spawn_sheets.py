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
RIM = (84, 67, 57, 255)
TOOTH = (235, 220, 170, 255)
THROAT = (21, 12, 15, 255)


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


def belly_pose(base: Image.Image, breathe: int, crouch: int) -> Image.Image:
    """Whole-row integer movement keeps arms joined and feet planted."""
    result = Image.new("RGBA", (W, H))
    for y in range(H):
        # A slow swelling centered on the abdomen, fading toward shoulders
        # and feet. The cast compresses the same area by two native pixels.
        weight = max(0.0, 1.0 - abs(y - 110) / 50.0)
        reach = round((breathe - crouch) * weight)
        for x in range(W):
            if not reach or not 66 <= y <= 151:
                result.putpixel((x, y), base.getpixel((x, y)))
                continue
            sample_x = round(56 + (x - 56) * (1.0 - reach / 55.0))
            if 0 <= sample_x < W:
                result.putpixel((x, y), base.getpixel((sample_x, y)))
    return result


def maw(image: Image.Image, radius_x: int, radius_y: int, glint: bool) -> None:
    """Redraw the front-facing mouth at each key pose, including its teeth."""
    draw = ImageDraw.Draw(image)
    cx, cy = 56, 48
    # A dark gray face plate covers the source mouth; the rim and teeth are
    # then repainted at the intended opening, not stretched from old pixels.
    draw.ellipse((cx - 20, cy - 21, cx + 20, cy + 21), fill=(83, 81, 78, 255))
    draw.ellipse((cx - radius_x - 3, cy - radius_y - 3,
                  cx + radius_x + 3, cy + radius_y + 3), fill=RIM)
    draw.ellipse((cx - radius_x, cy - radius_y,
                  cx + radius_x, cy + radius_y), fill=THROAT)
    # Radial tooth pairs remain individually readable at native resolution.
    for dx in (-9, -5, -1, 3, 7):
        yy = round(radius_y * (1.0 - (dx / max(1, radius_x)) ** 2) ** 0.5)
        for side in (-1, 1):
            y = cy + side * max(2, yy - 1)
            draw.rectangle((cx + dx, y - (2 if side > 0 else 0),
                            cx + dx + 1, y + (2 if side < 0 else 0)), fill=TOOTH)
    for side in (-1, 1):
        for dy in (-7, -2, 3, 8):
            xx = round(radius_x * (1.0 - (dy / max(1, radius_y)) ** 2) ** 0.5)
            x = cx + side * max(2, xx - 1)
            draw.rectangle((x - (2 if side > 0 else 0), cy + dy,
                            x + (2 if side < 0 else 0), cy + dy + 1), fill=TOOTH)
    if glint:
        draw.point((cx - 3, cy - 2), fill=(109, 224, 207, 255))
        draw.point((cx + 4, cy + 3), fill=(109, 224, 207, 255))


def effect(frame: int, shared: Image.Image) -> Image.Image:
    fx = Image.new("RGBA", (W, H + TOP))
    draw = ImageDraw.Draw(fx)
    cy = TOP + 78
    if 5 <= frame <= 8:
        # The individual wind-up is a brief pressure ripple from the maw to
        # the chest. The card itself is always the existing shared art.
        extent = {5: 4, 6: 8, 7: 13, 8: 19}[frame]
        for side in (-1, 1):
            x = 56 + side * extent
            draw.arc((x - 6, cy - 9, x + 6, cy + 9),
                     100 if side < 0 else 280, 260 if side < 0 else 80,
                     fill=(94, 181, 166, 255), width=1)
    if FIRE <= frame <= FIRE + 4:
        source_index = frame - FIRE + 5  # Exact fanatic card frames 5..9.
        card = shared.crop((source_index * 96, 0,
                            (source_index + 1) * 96, 204))
        bounds = card.getbbox()
        if bounds:
            card = card.crop(bounds)
            center_y = {8: 126, 9: 112, 10: 101, 11: 96, 12: 96}[frame]
            fx.alpha_composite(card, (56 - card.width // 2,
                                      center_y - card.height // 2))
    return fx


def main() -> None:
    base = native_base()
    shared = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    # Two uneven breaths, then a held compression before the mouth snaps open.
    breaths = [0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    crouches = [0, 0, 0, 0, 0, 1, 2, 2, 0, 0, 0, 0, 0]
    openings = [(12, 13), (12, 12), (11, 11), (12, 12),
                (12, 13), (11, 10), (10, 8), (14, 15),
                (17, 19), (17, 19), (15, 16), (13, 14), (12, 13)]
    body_sheet = Image.new("RGBA", (W * FRAMES, H))
    fx_sheet = Image.new("RGBA", (W * FRAMES, H + TOP))
    previews = []
    for frame in range(FRAMES):
        body = belly_pose(base, breaths[frame], crouches[frame])
        maw(body, *openings[frame], glint=frame == FIRE)
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
                duration=[240, 210, 260, 220, 180, 170, 230,
                          140, 220, 180, 170, 190, 650],
                loop=0, optimize=False)


if __name__ == "__main__":
    main()
