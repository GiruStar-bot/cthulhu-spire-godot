extends Control

## EventView.tsx の移植。events.ts の4予兆と store.ts resolveEvent の数値をそのまま使う。

@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var choice_a_button: Button = $ChoiceAButton
@onready var choice_b_button: Button = $ChoiceBButton

var _choice_ids: Array = ["a", "b"]


func _ready() -> void:
	var ev: Dictionary = GameState.event if GameState.event is Dictionary else {}
	if ev.is_empty():
		ev = Events.pick_event(Callable(GameState, "_rand"))
		GameState.event = ev
	title_label.text = str(ev.get("title", "予兆"))
	status_label.text = str(ev.get("body", ""))
	var choices: Array = ev.get("choices", [])
	_apply_choice(choice_a_button, choices, 0)
	_apply_choice(choice_b_button, choices, 1)
	if GameState.toast != "":
		GameState.toast = ""


func _apply_choice(button: Button, choices: Array, index: int) -> void:
	if index >= choices.size():
		button.visible = false
		return
	var choice: Dictionary = choices[index]
	_choice_ids[index] = str(choice.get("id", "a" if index == 0 else "b"))
	button.text = "%s\n%s" % [str(choice.get("label", "")), str(choice.get("result", ""))]
	button.visible = true


func _on_choice_a_button_pressed() -> void:
	GameState.resolve_event(get_tree(), str(_choice_ids[0]))


func _on_choice_b_button_pressed() -> void:
	GameState.resolve_event(get_tree(), str(_choice_ids[1]))
