extends Control

## 実ソースの TitleScreen.tsx 相当。
## 背景: art/pixel/bg/title.jpg 全画面カバー + 半透明の暗幕（bg-ink/45相当）
## ロゴ: .title-float（drift: 0%/100% translateY(0), 50% translateY(-7px), 6.2s ease-in-out infinite）
## ボタン: プレイ=begin()。設定/クレジットはビジュアル配置のみ（パネル自体はフェーズB以降）。

@onready var logo_container: VBoxContainer = $Stage/LogoContainer
@onready var play_button: Button = $Stage/ButtonRow/PlayButton
@onready var settings_button: Button = $Stage/ButtonRow/SettingsButton
@onready var credits_button: Button = $Stage/ButtonRow/CreditsButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var music_slider: HSlider = $SettingsPanel/Margin/Content/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $SettingsPanel/Margin/Content/SfxRow/SfxSlider
@onready var music_value_label: Label = $SettingsPanel/Margin/Content/MusicRow/Header/MusicValue
@onready var sfx_value_label: Label = $SettingsPanel/Margin/Content/SfxRow/Header/SfxValue
@onready var fullscreen_check: CheckButton = $SettingsPanel/Margin/Content/FullscreenCheck
@onready var close_settings_button: Button = $SettingsPanel/Margin/Content/CloseButton
@onready var credits_panel: PanelContainer = $CreditsPanel
@onready var close_credits_button: Button = $CreditsPanel/Margin/Content/CloseButton

var _logo_base_y: float


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	close_settings_button.pressed.connect(_on_close_settings_pressed)
	close_credits_button.pressed.connect(_on_close_credits_pressed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	music_slider.set_value_no_signal(AudioManager.get_music_volume())
	sfx_slider.set_value_no_signal(AudioManager.get_sfx_volume())
	fullscreen_check.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_volume_labels()
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
	settings_panel.visible = true


func _on_credits_pressed() -> void:
	credits_panel.visible = true


func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume(value)
	_refresh_volume_labels()


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_refresh_volume_labels()


func _on_close_settings_pressed() -> void:
	settings_panel.visible = false


func _on_close_credits_pressed() -> void:
	credits_panel.visible = false


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _refresh_volume_labels() -> void:
	music_value_label.text = "%d" % roundi(music_slider.value * 100.0)
	sfx_value_label.text = "%d" % roundi(sfx_slider.value * 100.0)
