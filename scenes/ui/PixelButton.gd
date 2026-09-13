extends Button

## src/components/ui/PixelButton.tsx 相当。
## 実ソースは .ritual-button（枠線#5c5447・背景#171512、ホバーで枠#a99a77・背景#211d17）+
## active:translate-y-[2px] active:shadow-none active:brightness-90 というCSSで構成される。
## 枠線/背景色はres://theme/main_theme.tresのButtonスタイル（Palette参照）で定義済みなので、
## ここでは実ソースにない「押下時にボタン全体が2pxしずむ」動きだけをスクリプトで再現する。

const PRESS_OFFSET := Vector2(0, 2)
const PRESS_MODULATE := Color(0.9, 0.9, 0.9, 1.0)  ## brightness(0.9) 相当

var _base_modulate: Color
var _is_pressed_visual: bool = false


func _ready() -> void:
	_base_modulate = modulate
	button_down.connect(_press)
	button_up.connect(_release)
	mouse_exited.connect(_release)


func _press() -> void:
	if _is_pressed_visual:
		return
	_is_pressed_visual = true
	position += PRESS_OFFSET
	modulate = PRESS_MODULATE


func _release() -> void:
	if not _is_pressed_visual:
		return
	_is_pressed_visual = false
	position -= PRESS_OFFSET
	modulate = _base_modulate
