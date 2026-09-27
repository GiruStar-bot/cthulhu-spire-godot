"""Build a 4x playback preview from the final Godot sprite sheets."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/pixel/enemies_px"
OUTPUT = ART / "source/drowned/drowned_preview.gif"
FIRE_OUTPUT = ART / "source/drowned/drowned_fire_preview.png"
WIDTH, HEIGHT, TOP = 112, 168, 48
DURATIONS = [400, 400, 120, 150, 180, 220, 160, 180, 160, 200]


def main() -> None:
    body = Image.open(ART / "drowned_body_1.png").convert("RGBA")
    effects = Image.open(ART / "drowned_fx_1.png").convert("RGBA")
    frames = []
    for index in range(10):
        canvas = Image.new("RGBA", (WIDTH, HEIGHT + TOP), (10, 21, 27, 255))
        crop = body.crop((index * WIDTH, 0, (index + 1) * WIDTH, HEIGHT))
        canvas.alpha_composite(crop, (0, TOP))
        effect = effects.crop((index * WIDTH, 0, (index + 1) * WIDTH, HEIGHT + TOP))
        canvas.alpha_composite(effect)
        frames.append(canvas.convert("RGB").resize((WIDTH * 4, (HEIGHT + TOP) * 4), Image.Resampling.NEAREST))
    frames[0].save(OUTPUT, save_all=True, append_images=frames[1:], duration=DURATIONS, loop=0)
    frames[6].save(FIRE_OUTPUT)


if __name__ == "__main__":
    main()
