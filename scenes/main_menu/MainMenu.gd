extends Control

## 実ソースの TitleScreen.tsx 相当。
## 背景: art/pixel/bg/title.jpg 全画面カバー + 半透明の暗幕（bg-ink/45相当）
## ロゴ: .title-float（drift: 0%/100% translateY(0), 50% translateY(-7px), 6.2s ease-in-out infinite）
## ボタン: プレイ=begin()。設定/クレジットはビジュアル配置のみ（パネル自体はフェーズB以降）。

@onready var logo_container: VBoxContainer = $LogoContainer
@onready var play_button: Button = $ButtonRow/PlayButton
@onready var settings_button: Button = $ButtonRow/SettingsButton
@onready var credits_button: Button = $ButtonRow/CreditsButton

var _logo_base_y: float


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	_start_drift()


## styles.css の @keyframes drift 相当（0%/100%=0, 50%=-7px, 6.2s ease-in-out infinite）
func _start_drift() -> void:
	_logo_base_y = logo_container.position.y
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo_container, "position:y", _logo_base_y - 7.0, 3.1)
	tween.tween_property(logo_container, "position:y", _logo_base_y, 3.1)


func _on_play_pressed() -> void:
	GameState.begin(get_tree())


func _on_settings_pressed() -> void:
	pass  ## SettingsPanel相当は未実装（フェーズB以降）


func _on_credits_pressed() -> void:
	pass  ## CreditsPanel相当は未実装（フェーズB以降）
