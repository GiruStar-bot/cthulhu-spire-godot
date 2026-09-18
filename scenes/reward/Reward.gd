extends Control

## RewardView.tsx の移植。store.ts makeRewards() が積んだ候補を表示し、claim で確定する。

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const CARD_SIZE := Vector2(128, 192)

@onready var eyebrow: Label = $Eyebrow
@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var shells_label: Label = $ShellsLabel
@onready var offers_row: HBoxContainer = $OffersRow
@onready var empty_slot: Panel = $EmptySlot


func _ready() -> void:
	var kind: String = str(GameState.floor_kind)
	if kind == "":
		kind = "combat"
	eyebrow.text = "%s · %s" % [Floors.layer_label(GameState.floor), Floors.floor_kind_label(kind, GameState.floor)]
	var offers: Array = GameState.reward if GameState.reward is Array else []
	var items: Array = []
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var offer_kind: String = str(offer.get("kind", ""))
		if offer_kind == "" or offer_kind == "none" or offer_kind == "equipment" or offer_kind == "rune":
			continue
		items.append(offer)
	if items.is_empty():
		title_label.text = "何も見つからなかった"
	else:
		title_label.text = "戦利品を発見"
	if kind == "boss" and GameState.floor >= Floors.DEMO_MAX_FLOOR:
		status_label.text = "最深の戦利。次に進むと、この沈降は終わる。"
	elif kind == "boss" and GameState.floor % 10 == 0:
		status_label.text = "中ボスを越えた。次に進むと中継点で編成できる。"
	else:
		status_label.text = "次の層へ沈む。"
	if GameState.reward_shells > 0:
		shells_label.text = "貝がら +%d" % GameState.reward_shells
		shells_label.visible = true
	else:
		shells_label.visible = false
	_fill_offers(items)
	if GameState.toast != "":
		status_label.text = GameState.toast
		GameState.toast = ""


func _fill_offers(items: Array) -> void:
	for child in offers_row.get_children():
		child.queue_free()
	empty_slot.visible = items.is_empty()
	offers_row.visible = not items.is_empty()
	for offer in items:
		offers_row.add_child(_make_offer(offer))


func _make_offer(offer: Dictionary) -> Control:
	var kind: String = str(offer.get("kind", ""))
	if kind == "card":
		var card: Dictionary = offer.get("card", {})
		var def: Dictionary = Cards.get_card(str(card.get("defId", "")))
		var view: CombatCard = COMBAT_CARD.new()
		view.custom_minimum_size = CARD_SIZE
		view.size = CARD_SIZE
		view.configure(card, def, false, false, false)
		return view
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 96)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(56, 56)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind_label := Label.new()
	kind_label.modulate = Color(0.72, 0.6, 0.38, 1)
	var name_label := Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if kind == "ticket":
		var ticket: String = str(offer.get("ticket", ""))
		art.texture = _load_texture_safe(CollectionData.pack_ticket_art(ticket))
		kind_label.text = "パックチケット"
		name_label.text = str(CollectionData.PACK_TICKET_LABELS.get(ticket, ticket))
	else:
		kind_label.text = "戦利"
		name_label.text = kind
	col.add_child(kind_label)
	col.add_child(name_label)
	row.add_child(art)
	row.add_child(col)
	panel.add_child(row)
	return panel


func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return load("res://art/pixel/ui/card_back.png")
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	return load("res://art/pixel/ui/card_back.png")


func _on_continue_button_pressed() -> void:
	GameState.claim_reward(get_tree())
