extends Control

## EventView.tsx の移植。予兆UIは Blessing（加護）と同じカード択レイアウト。

@onready var background_art: TextureRect = $BackgroundArt
@onready var veil: ColorRect = $Veil
@onready var eyebrow_label: Label = $Eyebrow
@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var choices_row: HBoxContainer = $ChoicesRow

const PORTRAIT_SIZE := Vector2(220, 220)
const PORTRAIT_TOP := -318.0  ## 画面中央からの上端（基準648pxの画面で上から6px）
const PORTRAIT_TEXT_SHIFT := 130.0  ## 立ち絵があるときだけ、見出し〜選択肢をこの分下げて立ち絵の場所を空ける

var _choice_ids: Array = ["a", "b"]


func _ready() -> void:
	var ev: Dictionary = GameState.event if GameState.event is Dictionary else {}
	if ev.is_empty():
		ev = Events.pick_event(Callable(GameState, "_rand"))
		GameState.event = ev
	_apply_event_art(ev)
	title_label.text = str(ev.get("title", "予兆"))
	status_label.text = str(ev.get("body", ""))
	var choices: Array = ev.get("choices", [])
	_rebuild_choices(choices)
	if GameState.toast != "":
		GameState.toast = ""


## 任意フィールド background / portrait を持つイベントだけの追加描画。
## どちらも無い既存イベントでは何もしない（見た目は従来のまま）。画像が未生成なら描かない。
func _apply_event_art(ev: Dictionary) -> void:
	var background_tex: Texture2D = _load_event_texture(str(ev.get("background", "")))
	if background_tex != null:
		background_art.texture = background_tex
	var portrait_tex: Texture2D = _load_event_texture(str(ev.get("portrait", "")))
	if portrait_tex == null:
		return
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = portrait_tex
	portrait.set_anchors_preset(Control.PRESET_CENTER)
	portrait.offset_left = -PORTRAIT_SIZE.x * 0.5
	portrait.offset_right = PORTRAIT_SIZE.x * 0.5
	portrait.offset_top = PORTRAIT_TOP
	portrait.offset_bottom = PORTRAIT_TOP + PORTRAIT_SIZE.y
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	## 暗幕（Veil）の上・文字と選択肢の下に置く。
	move_child(portrait, veil.get_index() + 1)
	for node in [eyebrow_label, title_label, status_label, choices_row]:
		var control: Control = node as Control
		control.offset_top += PORTRAIT_TEXT_SHIFT
		control.offset_bottom += PORTRAIT_TEXT_SHIFT


func _load_event_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	return resource as Texture2D


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
