extends Control

## EventView.tsx の移植。予兆UIは Blessing（加護）と同じカード択レイアウト。

@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var choices_row: HBoxContainer = $ChoicesRow

const DIALOGUE_MODAL := preload("res://scenes/event/DialogueEventModal.gd")

var _choice_ids: Array = ["a", "b"]


func _ready() -> void:
	var ev: Dictionary = GameState.event if GameState.event is Dictionary else {}
	if ev.is_empty():
		ev = Events.pick_event(Callable(GameState, "_rand"))
		GameState.event = ev
	if GameState.toast != "":
		GameState.toast = ""
	## presentation: "dialogue" のイベントは、通常の予兆レイアウトを使わず会話モーダルで進める。
	if str(ev.get("presentation", "")) == "dialogue":
		_open_dialogue_modal(ev)
		return
	title_label.text = str(ev.get("title", "予兆"))
	status_label.text = str(ev.get("body", ""))
	var choices: Array = ev.get("choices", [])
	_rebuild_choices(choices)


func _open_dialogue_modal(ev: Dictionary) -> void:
	## 背景と暗幕は残し、見出し・本文・選択肢パネルだけ隠す（タイトルは出さない）。
	for node_name in ["Eyebrow", "TitleLabel", "StatusLabel", "ChoicesRow"]:
		var node: CanvasItem = get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = false
	var modal: DialogueEventModal = DIALOGUE_MODAL.new()
	modal.name = "DialogueEventModal"
	modal.setup({
		"portrait": str(ev.get("portrait", "")),
		"background": str(ev.get("background", "")),
		"line": str(ev.get("line", "")),
		"choices": ev.get("choices", []),
	})
	modal.choice_selected.connect(_on_pick, CONNECT_ONE_SHOT)
	add_child(modal)


func _rebuild_choices(choices: Array) -> void:
	var kids: Array = choices_row.get_children()
	for child in kids:
		choices_row.remove_child(child)
		child.queue_free()
	_choice_ids = []
	var index: int = 0
	while index < choices.size():
		var choice: Dictionary = choices[index]
		var choice_id: String = str(choice.get("id", "a" if index == 0 else "b"))
		_choice_ids.append(choice_id)
		choices_row.add_child(_make_choice_card(choice, choice_id))
		index += 1


func _make_choice_card(choice: Dictionary, choice_id: String) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 220)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_pick.bind(choice_id))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = str(choice.get("label", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := Label.new()
	text_label.text = str(choice.get("result", ""))
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text_label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.52, 1))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	col.add_child(text_label)
	button.add_child(col)
	return button


func _on_pick(choice_id: String) -> void:
	GameState.resolve_event(get_tree(), choice_id)
