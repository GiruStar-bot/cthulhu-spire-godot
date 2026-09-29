"""Make a still, game-scale Salt Chorister pixel study for art review."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/pixel/enemies_px/source/choir"
CANVAS = (112, 168)
BACKDROP = (7, 20, 24, 255)


def main() -> None:
    source = Image.open(SOURCE / "choir_pixel_source.png").convert("RGBA")
    solid = source.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    bounds = solid.getbbox()
    if bounds is None:
        raise ValueError("Salt Chorister source has no visible figure")
    figure = source.crop(bounds)

    # Scale the complete figure once onto the same native canvas as other
    # standing enemies. Quantize only visible pixels, without dithering.
    scale = min(84 / figure.width, 154 / figure.height)
    size = (round(figure.width * scale), round(figure.height * scale))
    ink = Image.new("RGB", figure.size, (17, 18, 25))
    ink.paste(figure.convert("RGB"), mask=figure.getchannel("A"))
    reduced_color = ink.resize(size, Image.Resampling.LANCZOS)
    reduced_alpha = figure.getchannel("A").resize(size, Image.Resampling.LANCZOS)
    reduced_alpha = reduced_alpha.point(lambda value: 255 if value >= 128 else 0)

    visible = [color for color, alpha in zip(
        reduced_color.get_flattened_data(), reduced_alpha.get_flattened_data()
    ) if alpha]
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    palette = samples.quantize(colors=40, method=Image.Quantize.MEDIANCUT)
    reduced = reduced_color.quantize(
        palette=palette, dither=Image.Dither.NONE
    ).convert("RGBA")
    reduced.putalpha(reduced_alpha)

    native = Image.new("RGBA", CANVAS)
    native.alpha_composite(reduced, ((CANVAS[0] - size[0]) // 2, 168 - size[1] - 5))
    native.save(SOURCE / "choir_pixel_study.png")

    preview = Image.new("RGBA", (112, 216), BACKDROP)
    preview.alpha_composite(native, (0, 48))
    preview.resize((448, 864), Image.Resampling.NEAREST).save(
        SOURCE / "choir_pixel_study_preview.png"
    )


if __name__ == "__main__":
    main()
