extends Control

## 正気0のあと。瞼が開くと螺旋階段。UPはルルイエ、DOWNは夢の島の器。

const LID_HOLD_S := 0.55
const LID_OPEN_S := 0.85

@onready var lid_top: Panel = $LidTop
@onready var lid_bottom: Panel = $LidBottom
@onready var choices: HBoxContainer = $Choices
@onready var up_button: Button = $Choices/UpButton
@onready var down_button: Button = $Choices/DownButton
@onready var hint_label: Label = $HintLabel

var _picked: bool = false


func _ready() -> void:
	up_button.pressed.connect(_on_up_pressed)
	down_button.pressed.connect(_on_down_pressed)
	choices.visible = false
	hint_label.visible = false
	call_deferred("_boot_sequence")


func _boot_sequence() -> void:
	_set_lids_closed()
	var tw: Tween = create_tween()
	tw.tween_interval(LID_HOLD_S)
	tw.tween_callback(_open_lids)


func _viewport_size() -> Vector2:
	var view: Vector2 = size
	if view.x < 8.0 or view.y < 8.0:
		view = get_viewport_rect().size
	return view


func _lid_cover() -> float:
	return _viewport_size().y * 0.56


func _set_lids_closed() -> void:
	var cover: float = _lid_cover()
	lid_top.offset_bottom = cover
	lid_bottom.offset_top = -cover
	lid_top.mouse_filter = Control.MOUSE_FILTER_STOP
	lid_bottom.mouse_filter = Control.MOUSE_FILTER_STOP


func _open_lids() -> void:
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(lid_top, "offset_bottom", 0.0, LID_OPEN_S)
	tw.tween_property(lid_bottom, "offset_top", 0.0, LID_OPEN_S)
	tw.chain().tween_callback(_show_choices)


func _show_choices() -> void:
	lid_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lid_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choices.visible = true
	hint_label.visible = true
	choices.modulate.a = 0.0
	hint_label.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(choices, "modulate:a", 1.0, 0.35)
	tw.tween_property(hint_label, "modulate:a", 1.0, 0.45)


func _on_up_pressed() -> void:
	if _picked:
		return
	_picked = true
	GameState.goto_scene(get_tree(), "title")


func _on_down_pressed() -> void:
	if _picked:
		return
	_picked = true
	GameState.goto_scene(get_tree(), "dream_title")
