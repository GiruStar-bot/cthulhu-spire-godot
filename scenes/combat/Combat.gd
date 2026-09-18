extends Control

## CombatView.tsx の操作フローを再現する戦闘コントローラ。
## 手札はドラッグ&ドロップでプレイ（原作 resolveDrop / isAboveHand / pickFoe 相当）。
## HUD/ログは原作の石枠パネル。敵は全身＋右に使用カードとステータスパネル。
## ゲームロジック（_play_card / _end_turn 等）は変更しない。

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const PIXEL_BUTTON := preload("res://scenes/ui/PixelButton.tscn")
const DISSOLVE_SHADER := preload("res://scenes/combat/enemy_dissolve.gdshader")
const DISSOLVE_NOISE := preload("res://art/pixel/ui/dissolve_noise.png")
const VERTIGO_SHADER := preload("res://scenes/combat/screen_vertigo.gdshader")
const SHOCK_CARDS := ["migo_gun"]
const SHOCK_CORE := Color(0.70, 0.95, 0.28, 0.95)
const SHOCK_GLOW := Color(0.48, 0.12, 0.62, 0.38)
const SHOCK_SPARK := Color(0.78, 0.42, 0.95, 1.0)
const FX_IMPACT := preload("res://art/pixel/fx/fx_impact.png")
const FX_SLASH := preload("res://art/pixel/fx/fx_slash.png")
const FX_ARROW := preload("res://art/pixel/fx/fx_arrow.png")
const RESULT_WIN_DELAY := 0.92
const RESULT_FLEE_DELAY := 0.92
const RESULT_LOSE_DELAY := 0.56
const HAND_ABOVE_MARGIN := 20.0
const DRAW_IN_DURATION := 0.35
const DRAW_IN_STAGGER := 0.04
const DRAW_IN_STAGGER_CAP := 8
const DRAW_IN_SCALE := 0.42
const DRAW_IN_ROT_OFFSET := -16.0
