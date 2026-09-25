extends Control

## 実ソースの TitleScreen.tsx 相当。
## 背景: art/pixel/bg/title.jpg 全画面カバー + 半透明の暗幕（bg-ink/45相当）
## ロゴ: .title-float（drift: 0%/100% translateY(0), 50% translateY(-7px), 6.2s ease-in-out infinite）
## ボタン: プレイ=begin()。設定/クレジットはビジュアル配置のみ（パネル自体はフェーズB以降）。

@onready var logo_container: VBoxContainer = $Stage/LogoSlot/LogoContainer
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
@onready var reduce_motion_check: CheckButton = get_node_or_null("SettingsPanel/Margin/Content/MotionRow/ReduceMotionCheck") as CheckButton
@onready var credits_panel: PanelContainer = $CreditsPanel
@onready var close_credits_button: Button = $CreditsPanel/Margin/Content/CloseButton

var _logo_base_y: float

const _OUTER_GIFT_MODAL := preload("res://scenes/main_menu/OuterGiftModal.gd")


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
	## 「画面の揺れ・歪みを減らす」（ON で演出を控えめに。既定 OFF = 従来の見た目）
	if reduce_motion_check:
		reduce_motion_check.set_pressed_no_signal(VideoSettings.is_reduce_motion())
		reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	_refresh_volume_labels()
	_apply_logo_tracking()
	_start_drift()


func _apply_logo_tracking() -> void:
	var name_label: Label = logo_container.get_node_or_null("NameLabel") as Label
	if name_label:
		var is_dream: bool = name_label.text.find("Dream") >= 0
		name_label.add_theme_constant_override("letter_spacing", 2 if is_dream else 6)
	var of_label: Label = logo_container.get_node_or_null("OfLabel") as Label
	if of_label:
		of_label.add_theme_constant_override("letter_spacing", 6)


## styles.css の @keyframes drift 相当（0%/100%=0, 50%=-7px, 6.2s ease-in-out infinite）
func _start_drift() -> void:
	_logo_base_y = logo_container.position.y
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo_container, "position:y", _logo_base_y - 7.0, 3.1)
	tween.tween_property(logo_container, "position:y", _logo_base_y, 3.1)


func _is_dream_title() -> bool:
	var path := str(scene_file_path)
	if path.ends_with("DreamTitle.tscn"):
		return true
	return name == "DreamTitle"


func _on_play_pressed() -> void:
	if _is_dream_title():
		_show_outer_gift_modal()
		return
	GameState.begin(get_tree())


## Dream Island：外宇宙贈り物モーダル → 進むで begin（通常タイトルは直 begin）。
func _show_outer_gift_modal() -> void:
	if get_node_or_null("OuterGiftModal") != null:
		return
	var modal = _OUTER_GIFT_MODAL.new()
	modal.name = "OuterGiftModal"
	modal.proceeded.connect(_on_outer_gift_proceeded, CONNECT_ONE_SHOT)
	add_child(modal)


func _on_outer_gift_proceeded() -> void:
	GameState.realm = "dream"
	## 外宇宙贈り物＝スターター確定。Dream Hub で FIRST DESCENT を出さない。
	GameState.mark_starter_chosen()
	## デッキ付与は後続。プレースホルダが空ならスキップ（クラッシュしない）。
	var ids: Array = GameState.OUTER_STARTER_IDS_PLACEHOLDER.duplicate()
	if not ids.is_empty():
		GameState.pending_outer_starter = ids
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


func _on_reduce_motion_toggled(enabled: bool) -> void:
	VideoSettings.set_reduce_motion(enabled)


func _refresh_volume_labels() -> void:
	music_value_label.text = "%d" % roundi(music_slider.value * 100.0)
	sfx_value_label.text = "%d" % roundi(sfx_slider.value * 100.0)
