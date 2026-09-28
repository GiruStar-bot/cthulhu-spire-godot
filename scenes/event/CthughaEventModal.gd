class_name CthughaEventModal
extends CanvasLayer

## クトゥグァの三段階イベント。入力本文は保存・送信しない。
signal choice_selected(choice_id: String)

const SHRINE_BG := "res://art/pixel/bg/shrine.jpg"
const PRIEST_ART := "res://art/pixel/priest.png"
const FANATIC_ART := "res://art/pixel/fanatic.png"
const ACOLYTE_ART := "res://art/pixel/acolyte.png"

const PEOPLE_WORDS: Array[String] = ["上司", "同僚", "彼女", "彼氏", "友達", "家族", "親", "あいつ", "人間関係", "ぼっち", "孤独", "嫌われ", "いじめ", "職場"]
const LIFE_WORDS: Array[String] = ["お金", "金が", "金欠", "貧乏", "生活", "仕事", "働き", "給料", "家賃", "欲しい", "足りない", "無い", "ない"]
const ANGER_WORDS: Array[String] = ["殺したい", "ころしたい", "死んでほしい", "許せない", "憎い", "消えてほしい", "恨む"]

var _stage: int = 1
var _root: Control
var _content: VBoxContainer
var _line: Label
var _choices: HBoxContainer
var _input: LineEdit
var _locked: bool = false


func setup(stage: int) -> void:
	_stage = clampi(stage, 1, 3)


func _ready() -> void:
	layer = 80
	_build()
	match _stage:
		1: _show_first()
		2: _show_second()
		3: _show_third_question_one()


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
	_root.add_child(background)

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.025, 0.012, 0.025, 0.78)
	_root.add_child(veil)

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_content.offset_left = -430.0
	_content.offset_right = 430.0
	_content.offset_top = -295.0
	_content.offset_bottom = 295.0
	_content.add_theme_constant_override("separation", 20)
	_root.add_child(_content)

	var portraits := HBoxContainer.new()
	portraits.custom_minimum_size.y = 220.0
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.add_theme_constant_override("separation", 24)
	_content.add_child(portraits)
	if _stage == 3:
		_add_portrait(portraits, FANATIC_ART)
	_add_portrait(portraits, PRIEST_ART if _stage != 2 else FANATIC_ART)
	if _stage == 3:
		_add_portrait(portraits, ACOLYTE_ART)

	_line = Label.new()
	_line.custom_minimum_size.y = 145.0
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_line.add_theme_font_size_override("font_size", 24)
	_line.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	_content.add_child(_line)

	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 24)
	_content.add_child(_choices)


func _add_portrait(row: HBoxContainer, path: String) -> void:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(180, 220)
	portrait.texture = load(path) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(portrait)


func _set_choices(options: Array[Dictionary]) -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for option in options:
		var button := Button.new()
		button.text = str(option.get("label", ""))
		button.custom_minimum_size = Vector2(170, 54)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(option.get("action", Callable()))
		_choices.add_child(button)


func _finish(choice_id: String) -> void:
	if _locked:
		return
	_locked = true
	choice_selected.emit(choice_id)


func _show_reply(reply: String, choice_id: String) -> void:
	_line.text = reply
	_set_choices([{"label": "進む", "action": func() -> void: _finish(choice_id)}])


func _show_first() -> void:
	_line.text = "大司祭「あなたは世の中に不満がお有りですか？」"
	_set_choices([
		{"label": "はい", "action": func() -> void: _show_reply("大司祭「ではこれを授けましょう」\n火球を3枚受け取った。", "accept_fireballs")},
		{"label": "いいえ", "action": func() -> void: _finish("decline")},
	])


func _show_second() -> void:
	_line.text = "狂信者「お、お前さん。大司祭様がいってた新入りか？」"
	_set_choices([
		{"label": "はい", "action": _show_input},
		{"label": "いいえ", "action": func() -> void: _show_reply("狂信者「そうか、お前じゃないのか」", "deny")},
	])


func _show_input() -> void:
	_line.text = "狂信者「やっぱお前か。で、どんな不満を抱いてんだ？」"
	_input = LineEdit.new()
	_input.placeholder_text = "今抱いている不満をここに吐く"
	_input.max_length = 500
	_input.custom_minimum_size.y = 50.0
	_content.add_child(_input)
	_content.move_child(_input, _choices.get_index())
	_set_choices([
		{"label": "話す", "action": _submit_input},
		{"label": "話したくない", "action": func() -> void: _finish("skip")},
	])
	_input.grab_focus()
	_input.text_submitted.connect(func(_unused: String) -> void: _submit_input())


func _submit_input() -> void:
	if _input == null:
		return
	var category: String = classify_complaint(_input.text)
	_input.queue_free()
	_input = null
	match category:
		"people": _show_reply("狂信者「そうか、苦労してんだな。全部お前が背負い込むのだけはやめた方がいい。また話を聞くぜ」", "speak")
		"life": _show_reply("狂信者「なるほど。欲しいものが遠くなっていくよな。また不満があったら話を聞くぜ」", "speak")
		"anger": _show_reply("狂信者「まあ、落ち着けって。俺も人を恨んだことはある。また話を聞くぜ」", "speak")
		_: _show_reply("狂信者「何いってんだ？」", "fight")


## 人物を含む「許せない」は人間関係として扱う。単独なら攻撃的な回答。
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


func _show_third_question_one() -> void:
	_line.text = "大司祭「お、来ましたね」\n侍祭「あなたが例の」\n狂信者「そう、こいつ。いろいろ苦労してるらしい」"
	_set_choices([{"label": "話を聞く", "action": _show_third_question_one_after_intro}])


func _show_third_question_one_after_intro() -> void:
	_line.text = "大司祭「お、来ましたね。あなたに問いたい。\n苦しみはこの世から消え去って欲しいと思われますか？」"
	_set_choices([
		{"label": "思う", "action": _show_third_question_two},
		{"label": "思わない", "action": func() -> void: _show_reply("大司祭「そうですか、楽観的ですね」\n狂信者「じゃあ、お前さんはここに来ないほうがいいな」", "decline")},
	])


func _show_third_question_two() -> void:
	_line.text = "大司祭「苦しみは人にとって必要だと思われますか？」"
	_set_choices([
		{"label": "思う", "action": func() -> void: _show_reply("大司祭「そうですか、楽観的ですね」", "decline")},
		{"label": "必要ではない", "action": _show_third_question_three},
	])


func _show_third_question_three() -> void:
	_line.text = "大司祭「なんて素晴らしい！ あなたは私が求めていた方です！\n人を苦しみから救ってくれるのは『死』のみであるとお思いですか？」"
	_set_choices([
		{"label": "思う", "action": _show_ending},
		{"label": "他にも手段がある", "action": func() -> void: _show_reply("大司祭「そうですか……あなたの世界で苦しみと戦い続けるといいでしょう」", "decline")},
	])


func _show_ending() -> void:
	_content.visible = false
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
