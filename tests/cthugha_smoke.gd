extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var choose_last: Callable = func() -> float: return 0.99
	assert(str(Events.pick_event(choose_last, 1).get("id", "")) == "cthugha")
	assert(int(Events.pick_event(choose_last, 3).get("stage", 0)) == 3)
	assert(str(Events.pick_event(choose_last, 0).get("id", "")) == "eihort")
	assert(CthughaEventModal.is_correct_passphrase("フォーマルハウト"))
	assert(CthughaEventModal.is_correct_passphrase(" Fomalhaut "))
	assert(not CthughaEventModal.is_correct_passphrase("クトゥグァ"))
	var state: Node = load("res://autoload/GameState.gd").new()
	state.set("cthugha_stage", 1)
	state.set("cthugha_suspended_run", true)
	assert(int(state.call("cthugha_pick_stage")) == 0)
	assert(str(Events.pick_event(choose_last, int(state.call("cthugha_pick_stage"))).get("id", "")) == "eihort")
	state.set("cthugha_suspended_run", false)
	assert(int(state.call("cthugha_pick_stage")) == 1)
	state.free()
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
	await create_timer(4.0).timeout
	assert(picked == ["accept_fireballs"])
	sequence.queue_free()
	var password_modal := CthughaEventModal.new()
	password_modal.setup(2)
	root.add_child(password_modal)
	await create_timer(3.0).timeout
	var password_choices: HBoxContainer = password_modal.get("_choices") as HBoxContainer
	assert(password_choices.get_child_count() == 2)
	(password_choices.get_child(0) as Button).pressed.emit()
	await create_timer(3.5).timeout
	var password_input: LineEdit = password_modal.get("_input") as LineEdit
	assert(password_input != null)
	var password_result: Array[String] = []
	password_modal.choice_selected.connect(func(choice_id: String) -> void: password_result.append(choice_id))
	password_input.text = "Fomalhaut"
	password_modal.call("_submit_input")
	await create_timer(2.5).timeout
	assert(password_result == ["passphrase"])
	password_modal.queue_free()
	var wrong_modal := CthughaEventModal.new()
	wrong_modal.setup(2)
	root.add_child(wrong_modal)
	await create_timer(3.0).timeout
	((wrong_modal.get("_choices") as HBoxContainer).get_child(0) as Button).pressed.emit()
	await create_timer(3.5).timeout
	var wrong_result: Array[String] = []
	wrong_modal.choice_selected.connect(func(choice_id: String) -> void: wrong_result.append(choice_id))
	(wrong_modal.get("_input") as LineEdit).text = "違う言葉"
	wrong_modal.call("_submit_input")
	await create_timer(2.0).timeout
	assert(wrong_result == ["fight"])
	wrong_modal.queue_free()
	print("CTHUGHA_SMOKE_OK")
	quit()
