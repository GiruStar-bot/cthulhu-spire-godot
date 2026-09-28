class_name CthughaEventModal
extends CanvasLayer

## 戦闘で使うドット敵を神殿の足場に立たせ、話者の横で共通の吹き出しを一行ずつ再生する。
## 自由入力の本文は保存・送信しない。
signal choice_selected(choice_id: String)

const SHRINE_BG := "res://art/pixel/bg/shrine.jpg"
const TYPE_MS := 45
const LINE_HOLD_SEC := 0.65
const BUBBLE_FADE_SEC := 0.18
const ACTOR_SCALE_SINGLE := 2.15
const ACTOR_SCALE_GROUP := 1.95
const ACTOR_FEET_RATIO := 0.76
const BUBBLE_MARGIN := 18.0

const PEOPLE_WORDS: Array[String] = ["上司", "同僚", "彼女", "彼氏", "友達", "家族", "親", "あいつ", "人間関係", "ぼっち", "孤独", "嫌われ", "いじめ", "職場"]
const LIFE_WORDS: Array[String] = ["お金", "金が", "金欠", "貧乏", "生活", "仕事", "働き", "給料", "家賃", "欲しい", "足りない", "無い", "ない"]
const ANGER_WORDS: Array[String] = ["殺したい", "ころしたい", "死んでほしい", "許せない", "憎い", "消えてほしい", "恨む"]

var _stage: int = 1
var _root: Control
var _actors: Dictionary = {}
var _heads: Dictionary = {}
var _idle_frames: Dictionary = {}
var _bubble: SpeechBubble
var _choices: HBoxContainer
var _input: LineEdit
var _typing: bool = false
var _advance_requested: bool = false
var _busy: bool = false
var _finished: bool = false
var _idle_time: float = 0.0
var _idle_frame: int = -1


func setup(stage: int) -> void:
	_stage = clampi(stage, 1, 3)


func _ready() -> void:
	layer = 80
	_build()
	call_deferred("_start")


func _process(delta: float) -> void:
	_idle_time += delta
	var frame: int = int(_idle_time / 0.5) % 2
	if frame == _idle_frame:
		return
	_idle_frame = frame
	for actor_id in _actors.keys():
		var actor: TextureRect = _actors[actor_id] as TextureRect
		var frames: Array = _idle_frames[actor_id]
		actor.texture = frames[frame] as Texture2D


func _unhandled_input(event: InputEvent) -> void:
	if not _typing or _finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_requested = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_advance_requested = true
	else:
		return
	get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load(SHRINE_BG) as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(background)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.025, 0.012, 0.025, 0.50)
	_root.add_child(veil)

	var actor_ids: Array = ["priest"] if _stage == 1 else (["fanatic"] if _stage == 2 else ["fanatic", "priest", "acolyte"])
	for actor_id in actor_ids:
		_add_actor(actor_id)
	_layout_actors()

	_bubble = SpeechBubble.new()
	_bubble.name = "SpeechBubble"
	_bubble.accent = Color(0.90, 0.40, 0.24)
	_bubble.visible = false
	_root.add_child(_bubble)

	_choices = HBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_choices.offset_left = 70.0
	_choices.offset_right = -70.0
	_choices.offset_top = -94.0
	_choices.offset_bottom = -25.0
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 22)
	_root.add_child(_choices)


func _add_actor(actor_id: String) -> void:
	var def: Dictionary = Enemies.get_enemy(actor_id)
	var sheet_path: String = Enemies.px_sheet_path(str(def.get("sprite", "")), "body", 1)
	var sheet: Texture2D = ResourceLoader.load(sheet_path, "Texture2D") as Texture2D
	if sheet == null:
		push_error("クトゥグァイベントのドット絵を読み込めません: %s" % sheet_path)
		return
	var dims: Dictionary = Enemies.px_dims(def)
	var actor := TextureRect.new()
	actor.name = actor_id.capitalize() + "Pixel"
	var frames: Array = [
		_body_frame(sheet, 0, int(dims.bw), int(dims.bh)),
		_body_frame(sheet, 1, int(dims.bw), int(dims.bh)),
	]
	actor.texture = frames[0] as Texture2D
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor.stretch_mode = TextureRect.STRETCH_SCALE
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(actor)
	_actors[actor_id] = actor
	_idle_frames[actor_id] = frames


func _body_frame(sheet: Texture2D, frame: int, width: int, height: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.filter_clip = true
	atlas.region = Rect2(frame * width, 0, width, height)
	return atlas


func _layout_actors() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var is_group: bool = _stage == 3
	var ids: Array = ["priest"] if _stage == 1 else (["fanatic"] if _stage == 2 else ["fanatic", "priest", "acolyte"])
	var center_fractions: Array = [0.25, 0.50, 0.75] if is_group else [0.50]
	for index in ids.size():
		var actor_id: String = ids[index]
		if not _actors.has(actor_id):
			continue
		var actor: TextureRect = _actors[actor_id] as TextureRect
		var dims: Dictionary = Enemies.px_dims(Enemies.get_enemy(actor_id))
		var scale_factor: float = minf(ACTOR_SCALE_GROUP if is_group else ACTOR_SCALE_SINGLE, view.y / 720.0 * (ACTOR_SCALE_GROUP if is_group else ACTOR_SCALE_SINGLE))
		var drawn := Vector2(float(dims.bw), float(dims.bh)) * scale_factor
		var center_x: float = view.x * center_fractions[index]
		var feet_y: float = view.y * ACTOR_FEET_RATIO
		actor.position = Vector2(center_x - drawn.x * 0.5, feet_y - drawn.y)
		actor.size = drawn
		_heads[actor_id] = Vector2(center_x, actor.position.y + drawn.y * 0.18)


func _start() -> void:
	if _finished or not is_inside_tree():
		return
	match _stage:
		1: _play_lines([_line("priest", "あなたは世の中に不満がお有りですか？")], _first_choices)
		2: _play_lines([_line("fanatic", "お、お前さん、大司祭様がいってた新入りか")], _second_choices)
		3: _play_lines([
			_line("priest", "お、来ましたね。"),
			_line("acolyte", "あなたが例の"),
			_line("fanatic", "そう、こいつ。いろいろ苦労してるらしい"),
			_line("priest", "あなたに問いたい"),
			_line("priest", "苦しみはこの世から消え去って欲しいと思われますか"),
		], _third_choices_one)


func _line(speaker: String, text: String) -> Dictionary:
	return {"speaker": speaker, "text": text}


func _play_lines(lines: Array[Dictionary], done: Callable) -> void:
	if _finished:
		return
	_busy = true
	_clear_choices()
	for entry in lines:
		await _say(str(entry.get("speaker", "priest")), str(entry.get("text", "")))
		if _finished:
			return
	_busy = false
	done.call()


func _say(speaker: String, full_text: String) -> void:
	for actor_id in _actors.keys():
		(_actors[actor_id] as TextureRect).modulate.a = 1.0 if actor_id == speaker else 0.62
	_bubble.scale = Vector2.ONE
	_bubble.fit_to_text(full_text)
	_bubble.set_text("")
	var view: Vector2 = get_viewport().get_visible_rect().size
	var bounds := Rect2(Vector2(BUBBLE_MARGIN, BUBBLE_MARGIN), Vector2(view.x - BUBBLE_MARGIN * 2.0, view.y * 0.58))
	var head: Vector2 = _heads.get(speaker, view * 0.5)
	_bubble.place_beside(head, 18.0, bounds)
	## ③の左の狂信者は右側に置くと中央の大司祭を隠すため、吹き出しを外側へ出す。
	if _stage == 3 and speaker == "fanatic":
		_bubble.scale = Vector2(0.80, 0.80)
		_bubble.tail_side = "right"
		var left_x: float = 8.0
		var top_y: float = clampf(head.y - _bubble.size.y * _bubble.scale.y * 0.5, BUBBLE_MARGIN, view.y * 0.58 - _bubble.size.y * _bubble.scale.y)
		_bubble.tail_y_frac = 0.5
		_bubble.set_anchor_position(Vector2(left_x, top_y))
		_bubble.queue_redraw()
	_bubble.modulate.a = 1.0
	_bubble.visible = true
	_typing = true
	_advance_requested = false
	for index in full_text.length():
		if _advance_requested or _finished:
			break
		_bubble.set_text(full_text.substr(0, index + 1))
		var audio_manager: Node = get_node_or_null("/root/AudioManager")
		if audio_manager != null:
			audio_manager.call("play_sfx", "gift_type")
		await get_tree().create_timer(float(TYPE_MS) / 1000.0).timeout
	_typing = false
	_bubble.set_text(full_text)
	if _finished:
		return
	await get_tree().create_timer(LINE_HOLD_SEC).timeout
	var fade: Tween = create_tween()
	fade.tween_property(_bubble, "modulate:a", 0.0, BUBBLE_FADE_SEC)
	await fade.finished
	_bubble.visible = false


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _set_choices(options: Array[Dictionary]) -> void:
	_clear_choices()
	for option in options:
		var button := Button.new()
		button.text = str(option.get("label", ""))
		button.custom_minimum_size = Vector2(175, 56)
		button.add_theme_font_size_override("font_size", 22)
		var action: Callable = option.get("action", Callable())
		button.pressed.connect(action)
		_choices.add_child(button)


func _finish(choice_id: String) -> void:
	if _finished:
		return
	_finished = true
	choice_selected.emit(choice_id)


func _first_choices() -> void:
	_set_choices([
		{"label": "はい", "action": func() -> void: _play_lines([_line("priest", "ではこれを授けましょう")], func() -> void: _finish("accept_fireballs"))},
		{"label": "いいえ", "action": func() -> void: _finish("decline")},
	])


func _second_choices() -> void:
	_set_choices([
		{"label": "はい", "action": func() -> void: _play_lines([_line("fanatic", "やっぱお前か"), _line("fanatic", "で、どんな不満を抱いてんだ？")], _show_input)},
		{"label": "いいえ", "action": func() -> void: _play_lines([_line("fanatic", "そうか、お前じゃないのか")], func() -> void: _finish("deny"))},
	])


func _show_input() -> void:
	_input = LineEdit.new()
	_input.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_input.offset_left = 145.0
	_input.offset_right = -145.0
	_input.offset_top = -164.0
	_input.offset_bottom = -108.0
	_input.placeholder_text = "今抱いている不満をここに吐く"
	_input.max_length = 500
	_root.add_child(_input)
	_set_choices([
		{"label": "話す", "action": _submit_input},
		{"label": "話したくない", "action": func() -> void: _finish("skip")},
	])
	_input.grab_focus()
	_input.text_submitted.connect(func(_unused: String) -> void: _submit_input())


func _submit_input() -> void:
	if _input == null or _busy:
		return
	var category: String = classify_complaint(_input.text)
	_input.queue_free()
	_input = null
	match category:
		"people": _play_lines([
			_line("fanatic", "そうか、苦労してんだな。"),
			_line("fanatic", "全部お前が背負いこむのだけはやめた方がいい。"),
			_line("fanatic", "また、不満吐きたくなったら、話聞くぜ、じゃあな"),
		], func() -> void: _finish("speak"))
		"life": _play_lines([
			_line("fanatic", "なるほど"),
			_line("fanatic", "今って、欲しいものがどんどん遠くなってってるよな"),
			_line("fanatic", "それに誰も助けてくれない"),
			_line("fanatic", "まあしゃーないことだけどな"),
			_line("fanatic", "またなんか不満があったら、話聞くぜ、じゃあな"),
		], func() -> void: _finish("speak"))
		"anger": _play_lines([
			_line("fanatic", "まあ、落ち着けって"),
			_line("fanatic", "俺も人を恨んだことはあるが"),
			_line("fanatic", "どうせ、どうでもよくなると思うぜ"),
			_line("fanatic", "また、なんかあれば話きくぜ、じゃあな"),
		], func() -> void: _finish("speak"))
		_: _play_lines([_line("fanatic", "何いってんだ？")], func() -> void: _finish("fight"))


## 人物を含む「許せない」は人間関係、単独なら攻撃的な回答。
static func classify_complaint(raw: String) -> String:
	var value: String = raw.strip_edges().to_lower()
	if value.is_empty():
		return ""
	for word in PEOPLE_WORDS:
		if value.contains(word):
			return "people"
	for word in ANGER_WORDS:
		if value.contains(word):
			return "anger"
	for word in LIFE_WORDS:
		if value.contains(word):
			return "life"
	return ""


func _third_choices_one() -> void:
	_set_choices([
		{"label": "思う", "action": func() -> void: _play_lines([
			_line("priest", "なるほど、ではもう一つお聞きしたい"),
			_line("priest", "苦しみは人にとって必要だと思われますか？"),
		], _third_choices_two)},
		{"label": "思わない", "action": _third_decline},
	])


func _third_decline() -> void:
	_play_lines([
		_line("priest", "そうですか、楽観的ですね"),
		_line("fanatic", "じゃあ、お前さんはここに来ないほうがいいな"),
		_line("acolyte", "ええ、お強い人です"),
	], func() -> void: _finish("decline"))


func _third_choices_two() -> void:
	_set_choices([
		{"label": "思う", "action": _third_decline},
		{"label": "必要ではない", "action": func() -> void: _play_lines([
			_line("priest", "なんて素晴らしい！ あなたは私が求めていた方です！"),
			_line("fanatic", "苦しいのってまじどうしようも無えよな"),
			_line("priest", "では、あなたはこの質問を受ける権利がある"),
			_line("priest", "人を苦しみから救ってくれるのは『死』のみであるとお思いですか？"),
		], _third_choices_three)},
	])


func _third_choices_three() -> void:
	_set_choices([
		{"label": "思う", "action": func() -> void: _play_lines([_line("priest", "そうですか！ あなたはやはり、私の見込んだ方です")], _show_ending)},
		{"label": "他にも手段がある", "action": func() -> void: _play_lines([
			_line("priest", "そうですか…"),
			_line("priest", "では、あなたはあなたの世界で、苦しみと戦い続けるといいでしょう"),
		], func() -> void: _finish("decline"))},
	])


func _show_ending() -> void:
	for actor in _actors.values():
		(actor as TextureRect).visible = false
	_bubble.visible = false
	_clear_choices()
	var sky := ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.color = Color(0.005, 0.008, 0.04)
	_root.add_child(sky)
	var sky_title := Label.new()
	sky_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sky_title.offset_top = 50.0
	sky_title.offset_bottom = 100.0
	sky_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sky_title.add_theme_font_size_override("font_size", 28)
	sky_title.text = "みなみのうお座　フォーマルハウト"
	_root.add_child(sky_title)
	var caption := Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption.offset_bottom = -22.0
	caption.add_theme_font_size_override("font_size", 30)
	caption.text = "あなたは壊滅の神となるのです\n体力 1　正気度 1"
	_root.add_child(caption)
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var fish := Line2D.new()
	fish.width = 2.0
	fish.default_color = Color(0.45, 0.65, 0.9, 0.72)
	fish.points = PackedVector2Array([
		center + Vector2(-310, -155), center + Vector2(-225, -195),
		center + Vector2(-140, -145), center + Vector2(-75, -185),
		center + Vector2(25, -125), center + Vector2(120, -160),
	])
	_root.add_child(fish)
	for point in fish.points:
		var star := Panel.new()
		var star_style := StyleBoxFlat.new()
		star_style.bg_color = Color(0.75, 0.85, 1.0)
		star_style.set_corner_radius_all(5)
		star.add_theme_stylebox_override("panel", star_style)
		star.position = point - Vector2(4, 4)
		star.size = Vector2(8, 8)
		_root.add_child(star)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for i in 9:
		var orb := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.31, 0.05)
		style.set_corner_radius_all(32)
		orb.add_theme_stylebox_override("panel", style)
		orb.size = Vector2(36, 36)
		var angle: float = TAU * float(i) / 9.0
		orb.position = center + Vector2(cos(angle), sin(angle)) * 215.0
		_root.add_child(orb)
		tween.tween_property(orb, "position", center, 2.3)
	await tween.finished
	caption.text = "体力 0　正気度 0"
	await get_tree().create_timer(0.8).timeout
	_finish("ascend")
