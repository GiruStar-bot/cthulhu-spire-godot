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
const CARD_SIZE := Vector2(128, 192)
const PREVIEW_CARD_SIZE := Vector2(112, 160)
const PREVIEW_CARD_SIZE_DUAL := Vector2(76, 114)
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"
const ENEMY_PLATE_W := 176.0
const ENEMY_PLATE_W_DUAL := 148.0
const ENEMY_PLATE_GAP := 8.0
const ENEMY_CUTOUT_W := 688.0
const ENEMY_CUTOUT_H := 608.0
const ENEMY_CUTOUT_W_DUAL := 640.0
const ENEMY_BOSS_W := 816.0
const ENEMY_BOSS_H := 688.0
const ENEMY_GROUND_SINGLE := 0.20
const ENEMY_GROUND_DUAL := 0.14
const ENEMY_BOSS_HP := 150

@onready var hud_panel: VitalsHud = $HudPanel
@onready var hud_label: Label = $HudPanel/HudLabel
@onready var log_scroll: ScrollContainer = $LogPanel/LogScroll
@onready var log_label: Label = $LogPanel/LogScroll/LogLabel
@onready var log_panel: Panel = $LogPanel
@onready var message_label: Label = $MessageLabel
@onready var enemy_row: Control = $EnemyRow
@onready var hand_row: Control = $HandRow
@onready var hand_tray: Panel = $HandTray
@onready var end_turn_button: Button = $EndTurnButton
@onready var background_art: TextureRect = $BackgroundArt
@onready var floater_layer: Control = $FloaterLayer

var state: Dictionary = {}
var player: Dictionary = {}
var targeting_uid: String = ""
var resolving: bool = false
var _shown_floaters := {}
var _enemy_art_by_uid := {}
var _enemy_hit_by_uid := {}
var _drag_uid: String = ""
var _drag_ghost: CombatCard = null
var _drag_source: CombatCard = null
var _draw_btn: Button
var _discard_btn: Button
var _chrome_ready: bool = false
var _death_fx_done: Dictionary = {}
var _hit_tweens: Dictionary = {}
var _float_tweens: Dictionary = {}
var _prev_hp: int = -1
var _prev_sanity: int = -1
var _fx_canvas: CanvasLayer
var _vertigo_rect: ColorRect
var _vertigo_mat: ShaderMaterial
var _vertigo_tween: Tween
var _shield: Polygon2D
var _shield_tween: Tween
var _vfx_layer: Node2D
var _draw_in_tweens: Dictionary = {}
