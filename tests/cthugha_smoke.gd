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
		root.add_child(modal)
		assert(modal.get_child_count() > 0)
		modal.queue_free()
	await process_frame
	print("CTHUGHA_SMOKE_OK")
	quit()
