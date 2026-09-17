extends Control

## 5階層ごとの3択バフ。装備／ルーンの代わり。


func _ready() -> void:
	var choices: Array = GameState.blessing_choices
	$Eyebrow.text = "%s　深層の加護" % Floors.layer_label(GameState.floor)
	$TitleLabel.text = "三つの潮流から、一つを選ぶ"
	$StatusLabel.text = "この沈降のあいだ、選んだ加護は累積する。"
	var row: HBoxContainer = $ChoicesRow
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	if choices.is_empty():
		choices = Blessings.roll_choices(GameState.run_blessings, GameState.rng)
		GameState.blessing_choices = choices
	for blessing_id in choices:
		row.add_child(_make_choice(str(blessing_id)))
	if GameState.toast != "":
		$StatusLabel.text = GameState.toast
		GameState.toast = ""


func _make_choice(blessing_id: String) -> Control:
	var def: Dictionary = Blessings.get_def(blessing_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 220)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_pick.bind(blessing_id))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = str(def.get("name", blessing_id))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := Label.new()
	text_label.text = str(def.get("text", ""))
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text_label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.52, 1))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	col.add_child(text_label)
	button.add_child(col)
	return button


func _on_pick(blessing_id: String) -> void:
	GameState.choose_blessing(get_tree(), blessing_id)
