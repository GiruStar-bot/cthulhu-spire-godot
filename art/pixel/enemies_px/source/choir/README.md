# Salt Chorister pixel animation

The approved still study is `choir_pixel_study.png`; the larger generated
source and four complete animation key poses are kept beside it. Source art is
excluded from Godot import by `.gdignore`.

Run `python tools/build_choir_sheets.py` to regenerate the 112×168 body sheet,
112×216 effect sheet, contact strip, fire-frame preview, and GIF. All four
complete poses share one 44-color palette and hard transparency.

| Frames | Motion |
| --- | --- |
| 0–5 | Neutral posture, then a held inhale: shoulders, chest, sleeves, and robe move together. |
| 6–9 | Another inhale draws both sleeve openings toward the sternum. |
| 10 | She opens both sleeves and sings; the established gold-and-teal card appears at her chest. |
| 11–14 | The card rises to face height and disperses while she returns to idle. |

Card and glow pixels are copied from `fanatic_fx_1.png` frames 5–9. The real
CombatCard uses the shared reveal path in `Combat.gd`, with frame 10 as
`cast_fire`; no character-specific card design is drawn.
