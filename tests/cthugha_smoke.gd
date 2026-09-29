extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var choose_last: Callable = func() -> float: return 0.99
	assert(str(Events.pick_event(choose_last, 1).get("id", "")) == "cthugha")
	assert(int(Events.pick_event(choose_last, 3).get("stage", 0)) == 3)
	assert(str(Events.pick_event(choose_last, 0).get("id", "")) == "eihort")
	assert(CthughaEventModal.classify_complaint("上司が許せない") == "people")
	assert(CthughaEventModal.classify_complaint("殺したい") == "anger")
	assert(CthughaEventModal.classify_complaint("家賃が払えない") == "life")
	assert(CthughaEventModal.classify_complaint("意味不明な文章") == "")
	for stage in [1, 2, 3]:
		var modal := CthughaEventModal.new()
		modal.setup(stage)
		modal.set("_finished", true)
		root.add_child(modal)
		assert(modal.get_child_count() > 0)
		modal.queue_free()
	await process_frame
	var sequence := CthughaEventModal.new()
	sequence.setup(1)
	root.add_child(sequence)
	var panel: Panel = sequence.get("_dialogue_panel") as Panel
	assert(panel != null and is_equal_approx(panel.anchor_top, 2.0 / 3.0))
	await create_timer(3.0).timeout
	assert((sequence.get("_speaker_label") as Label).text == "大司祭")
	assert((sequence.get("_dialogue_label") as Label).text == "あなたは世の中に不満がお有りですか？")
	var choices: HBoxContainer = sequence.get("_choices") as HBoxContainer
	assert(choices.get_child_count() == 2)
	var picked: Array[String] = []
	sequence.choice_selected.connect(func(choice_id: String) -> void: picked.append(choice_id))
	(choices.get_child(0) as Button).pressed.emit()
	await create_timer(2.0).timeout
	assert(picked == ["accept_fireballs"])
	sequence.queue_free()
	print("CTHUGHA_SMOKE_OK")
	quit()
