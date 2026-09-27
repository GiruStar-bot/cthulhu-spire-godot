"""Finalize the generated drowned sheet with a shared, hard-edged pixel palette."""

from pathlib import Path
from PIL import Image, ImageDraw


SHEET = Path(__file__).resolve().parents[1] / "art/pixel/enemies_px/drowned_body_1.png"
PALETTE_SIZE = 48


def main() -> None:
    image = Image.open(SHEET).convert("RGBA")
    pixels = list(image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata())
    visible = [(r, g, b) for r, g, b, a in pixels if a >= 128]
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    palette = samples.quantize(colors=PALETTE_SIZE, method=Image.Quantize.MEDIANCUT)
    indexed = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE)
    rgb = indexed.convert("RGB")
    colors = list(rgb.get_flattened_data() if hasattr(rgb, "get_flattened_data") else rgb.getdata())
    finalized = Image.new("RGBA", image.size)
    finalized.putdata(
        [(r, g, b, 255) if source[3] >= 128 else (0, 0, 0, 0)
         for (r, g, b), source in zip(colors, pixels)]
    )
    # Gameplay commits the enemy card at frame 6. Light both pupils on that frame.
    draw = ImageDraw.Draw(finalized)
    for eye_x in (45, 64):
        x = 6 * 112 + eye_x
        draw.rectangle((x, 27, x + 3, 28), fill=(160, 243, 232, 255))
    finalized.save(SHEET)


if __name__ == "__main__":
    main()
