"""Build the Salt Chorister's singing poses and shared-card cast sheets."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PIXELS = ROOT / "art/pixel/enemies_px"
SOURCE = PIXELS / "source/choir"
W, H, TOP, FRAMES, FIRE = 112, 168, 48, 15, 10
INK = (17, 18, 25)
POSE_CROPS = (
    (0, 0, 512, 768),
    (512, 0, 1024, 768),
    (0, 768, 512, 1536),
    (512, 768, 1024, 1536),
)


def native_pose(sheet: Image.Image, crop: tuple[int, int, int, int]) -> Image.Image:
    panel = sheet.crop(crop)
    alpha = panel.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"Empty Chorister pose: {crop}")
    figure = panel.crop(bounds)
    scale = min(102 / figure.width, 154 / figure.height)
    size = (round(figure.width * scale), round(figure.height * scale))
    matte = Image.new("RGB", figure.size, INK)
    matte.paste(figure.convert("RGB"), mask=figure.getchannel("A"))
    color = matte.resize(size, Image.Resampling.LANCZOS)
    shape = figure.getchannel("A").resize(size, Image.Resampling.LANCZOS)
    shape = shape.point(lambda value: 255 if value >= 128 else 0)
    reduced = color.convert("RGBA")
    reduced.putalpha(shape)
    pose = Image.new("RGBA", (W, H))
    pose.alpha_composite(reduced, ((W - size[0]) // 2, H - size[1] - 5))
    return pose


def shared_palette(poses: list[Image.Image]) -> Image.Image:
    visible = [pixel[:3] for pose in poses
               for pixel in pose.get_flattened_data() if pixel[3]]
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    return samples.quantize(colors=44, method=Image.Quantize.MEDIANCUT)


def apply_palette(pose: Image.Image, palette: Image.Image) -> Image.Image:
    output = pose.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    output.putalpha(pose.getchannel("A"))
    return output


def card_fx(frame: int, cards: Image.Image) -> Image.Image:
    effect = Image.new("RGBA", (W, H + TOP))
    if FIRE <= frame <= FIRE + 4:
        # Exact established card-and-glow pixels from the Fanatic sheet.
        source = frame - FIRE + 5
        card = cards.crop((source * 96, 0, (source + 1) * 96, 204))
        bounds = card.getbbox()
        if bounds:
            card = card.crop(bounds)
            center_y = (120, 108, 96, 86, 78)[frame - FIRE]
            effect.alpha_composite(
                card, ((W - card.width) // 2, center_y - card.height // 2)
            )
    return effect


def main() -> None:
    source = Image.open(SOURCE / "choir_pose_sheet.png").convert("RGBA")
    poses = [native_pose(source, crop) for crop in POSE_CROPS]
    palette = shared_palette(poses)
    neutral, inhale, prepare, release = [
        apply_palette(pose, palette) for pose in poses
    ]
    for name, pose in zip(
        ("neutral", "inhale", "prepare", "release"),
        (neutral, inhale, prepare, release),
    ):
        pose.save(SOURCE / f"choir_{name}_native.png")

    # Whole-body key poses: breath moves the shoulders and hem together.
    # The cast pulls both sleeves inward before opening them at frame 10.
    sequence = [neutral, inhale, inhale, neutral, neutral, neutral,
                neutral, inhale, prepare, prepare, release, release,
                release, inhale, neutral]
    body_sheet = Image.new("RGBA", (W * FRAMES, H))
    fx_sheet = Image.new("RGBA", (W * FRAMES, H + TOP))
    cards = Image.open(PIXELS / "fanatic_fx_1.png").convert("RGBA")
    previews = []
    for frame, pose in enumerate(sequence):
        body_sheet.alpha_composite(pose, (frame * W, 0))
        fx = card_fx(frame, cards)
        fx_sheet.alpha_composite(fx, (frame * W, 0))
        preview = Image.new("RGBA", (W, H + TOP), (7, 20, 24, 255))
        preview.alpha_composite(pose, (0, TOP))
        preview.alpha_composite(fx)
        previews.append(preview)

    body_sheet.save(PIXELS / "choir_body_1.png")
    fx_sheet.save(PIXELS / "choir_fx_1.png")
    contact = Image.new("RGBA", (W * FRAMES, H + TOP))
    for frame, preview in enumerate(previews):
        contact.alpha_composite(preview, (frame * W, 0))
    contact.save(SOURCE / "choir_contact_preview.png")
    previews[FIRE].resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "choir_fire_preview.png"
    )
    gif = [preview.resize((336, 648), Image.Resampling.NEAREST).convert("RGB")
           for preview in previews]
    gif[0].save(
        SOURCE / "choir_preview.gif", save_all=True, append_images=gif[1:],
        duration=[240, 250, 240, 240, 250, 320,
                  160, 210, 250, 240, 240, 200, 190, 190, 650],
        loop=0, optimize=False,
    )


if __name__ == "__main__":
    main()
