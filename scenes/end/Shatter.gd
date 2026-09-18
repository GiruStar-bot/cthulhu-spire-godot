extends Control

## 実ソースの ShatterView.tsx 相当（正気0での「全ロスト」画面）。
## タイトル確定後、瞼を閉じてから DreamGate へ渡す。reset は accept_shatter 側。

const LID_CLOSE_S := 0.72

@onready var lid_top: Panel = $LidTop
@onready var lid_bottom: Panel = $LidBottom
@onready var title_button: Button = $TitleButton

var _closing: bool = false


func _on_title_button_pressed() -> void:
	if _closing:
		return
	_closing = true
	title_button.disabled = true
	lid_top.mouse_filter = Control.MOUSE_FILTER_STOP
	lid_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	var cover: float = size.y * 0.56
	if cover < 8.0:
		cover = get_viewport_rect().size.y * 0.56
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(lid_top, "offset_bottom", cover, LID_CLOSE_S)
	tw.tween_property(lid_bottom, "offset_top", -cover, LID_CLOSE_S)
	tw.chain().tween_interval(0.18)
	tw.chain().tween_callback(_handoff)


func _handoff() -> void:
	GameState.accept_shatter(get_tree())
