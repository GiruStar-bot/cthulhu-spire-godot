class_name HubArtworkList
extends VBoxContainer

## Hub.gd が実行時に組み立てる一覧へ、表示専用のアートワークを付与する。
## デッキ/所持品/商取引の状態や、ボタンの action は一切変更しない。

@export_enum("cards", "equipment", "commerce", "grimoire") var presentation: String = "cards"

const FRAME_BY_RARITY := {
	"common": ["res://art/pixel/ui/frame_card_common_9.png", 8],
	"uncommon": ["res://art/pixel/ui/frame_card_uncommon_9.png", 16],
	"rare": ["res://art/pixel/ui/frame_card_9.png", 13],
}
const FRAME_BY_ARCHETYPE := {
	"greatold": ["res://art/pixel/ui/frame_card_greatold_9.png", 15],
	"elder": ["res://art/pixel/ui/frame_card_elder_9.png", 14],
	"outer": ["res://art/pixel/ui/frame_card_outer_9.png", 19],
}
const TICKET_ARCHETYPES := ["fanatic", "knight", "poison", "outer", "elder", "deep", "offering", "shadow", "greatold"]


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered_tree)
	call_deferred("_decorate_existing")


func _on_child_entered_tree(child: Node) -> void:
	_decorate_child.call_deferred(child)


func _decorate_existing() -> void:
	for child in get_children():
		_decorate_child(child)


func _decorate_child(child: Node) -> void:
	if not is_instance_valid(child) or child.has_meta("hub_artwork_decorated"):
		return
	match presentation:
		"cards":
			_decorate_card_row(child)
		"equipment":
			_decorate_equipment_row(child)
		"commerce":
			_decorate_commerce_button(child)
		"grimoire":
			_decorate_grimoire_entry(child)


func _decorate_card_row(child: Node) -> void:
	var row := child as HBoxContainer
	if row == null:
		return
	var label := _first_label(row)
	if label == null:
		return
	var card := _find_card_by_name(_base_name(label.text))
	if card.is_empty():
		return
	row.add_child(_make_thumbnail(str(card.get("art", "")), str(card.get("archetype", "")), str(card.get("rarity", "")), Vector2(62, 82)))
	row.move_child(row.get_child(row.get_child_count() - 1), 0)
	row.set_meta("hub_artwork_decorated", true)


func _decorate_equipment_row(child: Node) -> void:
	var row: HBoxContainer = child as HBoxContainer
	if row == null and child is VBoxContainer and child.get_child_count() > 0:
		row = child.get_child(0) as HBoxContainer
	if row == null:
		return
	var label := _first_label(row)
	if label == null:
		return
	var equipment := _find_equipment_by_name(_base_name(label.text).trim_prefix("頭: ").trim_prefix("胸: ").trim_prefix("腕: ").trim_prefix("脚: ").trim_prefix("足: "))
	if equipment.is_empty():
		return
	row.add_child(_make_thumbnail(str(equipment.get("art", "")), str(equipment.get("archetype", "")), "common", Vector2(62, 62)))
	row.move_child(row.get_child(row.get_child_count() - 1), 0)
	child.set_meta("hub_artwork_decorated", true)


func _decorate_commerce_button(child: Node) -> void:
	var button := child as Button
	if button == null:
		return
	var original_text := button.text
	var visual := _commerce_visual(original_text)
	if visual.is_empty():
		return
	var art_path := str(visual.get("art", ""))
	if art_path == "":
		return
	button.text = ""
	button.custom_minimum_size = Vector2(0, 68)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.add_child(_make_thumbnail(art_path, str(visual.get("archetype", "")), str(visual.get("rarity", "common")), Vector2(46, 56)))
	var label := Label.new()
	label.text = original_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	button.add_child(row)
	button.set_meta("hub_artwork_decorated", true)


func _decorate_grimoire_entry(child: Node) -> void:
	var label := child as Label
	if label == null:
		return
	var card := _find_grimoire_card(label.text)
	if card.is_empty():
		return
	var index := label.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	remove_child(label)
	row.add_child(_make_thumbnail(str(card.get("art", "")), str(card.get("archetype", "")), str(card.get("rarity", "rare")), Vector2(42, 54)))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	add_child(row)
	move_child(row, index)
	row.set_meta("hub_artwork_decorated", true)


func _commerce_visual(text: String) -> Dictionary:
	if text.begins_with("カードを売却: "):
		var card := _find_card_by_name(_base_name(text.trim_prefix("カードを売却: ")))
		return card
	if text.begins_with("購入: "):
		var card := _find_card_by_name(_base_name(text.trim_prefix("購入: ")))
		return card
	if text.begins_with("装備を売却: "):
		return _find_equipment_by_name(_base_name(text.trim_prefix("装備を売却: ")))
	for archetype in TICKET_ARCHETYPES:
		if text.begins_with(archetype + "パック"):
			return {"art": "res://art/pixel/tickets/ticket_%s.png" % archetype, "archetype": archetype, "rarity": "rare"}
	return {}


func _find_card_by_name(name: String) -> Dictionary:
	for card in Cards.CARDS.values():
		if str(card.get("name", "")) == name:
			return card
	return {}


func _find_equipment_by_name(name: String) -> Dictionary:
	for equipment in Equipment.EQUIPMENT.values():
		if str(equipment.get("name", "")) == name:
			return equipment
	return {}


func _find_grimoire_card(text: String) -> Dictionary:
	for chapter in Grimoire.chapters():
		if text.contains(str(chapter.get("title", ""))):
			var id = chapter.get("card_id", null)
			if id != null:
				return Cards.get_card(str(id))
	return {}


func _base_name(text: String) -> String:
	return text.split("（", false, 1)[0].strip_edges()


func _first_label(parent: Node) -> Label:
	for child in parent.get_children():
		var label := child as Label
		if label != null:
			return label
	return null


func _make_thumbnail(art_path: String, archetype: String, rarity: String, minimum_size: Vector2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = minimum_size
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("100f0c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(background)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 5
	art.offset_top = 5
	art.offset_right = -5
	art.offset_bottom = -5
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if art_path != "" and ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	holder.add_child(art)

	var frame_data: Array = FRAME_BY_ARCHETYPE.get(archetype, FRAME_BY_RARITY.get(rarity, FRAME_BY_RARITY["common"]))
	var frame := NinePatchRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_path := str(frame_data[0])
	if ResourceLoader.exists(frame_path):
		frame.texture = load(frame_path)
		var margin := int(frame_data[1])
		frame.patch_margin_left = margin
		frame.patch_margin_top = margin
		frame.patch_margin_right = margin
		frame.patch_margin_bottom = margin
	holder.add_child(frame)
	return holder
