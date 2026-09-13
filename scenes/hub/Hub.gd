extends Control

## 実ソースの HubScreen.tsx 相当。単一画面＋サイドナビ（タブ）で
## 探索開始/デッキ編成/装備/売却/ショップ/カードパックを行き来する。
## floor>0（中継点）でもfloor==0（拠点）でも同じこの画面が使われ、
## descendタブの中身だけが CheckpointPanel / PrepareView 相当で切り替わる。
##
## 実装済みタブ: 探索開始 / デッキ編成（DeckHubScreen.tsx + DeckBuilderScreen.tsx 相当）/
## 装備（EquipmentScreen.tsx 相当）。売却/ショップ/カードパックは未実装プレースホルダーのまま。

@onready var player_name_label: Label = $Root/Header/PlayerNameLabel
@onready var info_label: Label = $Root/Header/InfoLabel
@onready var top_right_button: Button = $Root/Header/TopRightButton

@onready var descend_panel: VBoxContainer = $Root/Body/Content/DescendPanel
@onready var descend_status_label: Label = $Root/Body/Content/DescendPanel/DescendStatusLabel
@onready var primary_action_button: Button = $Root/Body/Content/DescendPanel/PrimaryActionButton
@onready var extract_button: Button = $Root/Body/Content/DescendPanel/ExtractButton

@onready var placeholder_panel: Label = $Root/Body/Content/PlaceholderPanel

@onready var deck_panel: VBoxContainer = $Root/Body/Content/DeckPanel
@onready var new_deck_name_edit: LineEdit = $Root/Body/Content/DeckPanel/DeckHeaderRow/NewDeckNameEdit
@onready var create_deck_button: Button = $Root/Body/Content/DeckPanel/DeckHeaderRow/CreateDeckButton
@onready var delete_deck_button: Button = $Root/Body/Content/DeckPanel/DeckHeaderRow/DeleteDeckButton
@onready var deck_option_button: OptionButton = $Root/Body/Content/DeckPanel/DeckOptionButton
@onready var deck_count_label: Label = $Root/Body/Content/DeckPanel/DeckCountLabel
@onready var deck_error_label: Label = $Root/Body/Content/DeckPanel/DeckErrorLabel
@onready var card_list_container: VBoxContainer = $Root/Body/Content/DeckPanel/CardScroll/CardListContainer

@onready var equipment_panel: VBoxContainer = $Root/Body/Content/EquipmentPanel
@onready var equipped_list_container: VBoxContainer = $Root/Body/Content/EquipmentPanel/EquippedListContainer
@onready var stats_label: Label = $Root/Body/Content/EquipmentPanel/StatsLabel
@onready var inventory_list_container: VBoxContainer = $Root/Body/Content/EquipmentPanel/InventoryScroll/InventoryListContainer
@onready var rune_list_container: VBoxContainer = $Root/Body/Content/EquipmentPanel/RuneScroll/RuneListContainer

@onready var nav_buttons: Dictionary = {
	"descend": $Root/Body/Nav/DescendButton,
	"deck": $Root/Body/Nav/DeckButton,
	"equipment": $Root/Body/Nav/EquipmentButton,
	"sell": $Root/Body/Nav/SellButton,
	"shop": $Root/Body/Nav/ShopButton,
	"packs": $Root/Body/Nav/PacksButton,
}

var _selected_rune_id: String = ""


func _ready() -> void:
	for tab_name in nav_buttons.keys():
		nav_buttons[tab_name].pressed.connect(_select_tab.bind(tab_name))
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	extract_button.pressed.connect(_on_extract_button_pressed)
	top_right_button.pressed.connect(_on_top_right_button_pressed)
	create_deck_button.pressed.connect(_on_create_deck_pressed)
	delete_deck_button.pressed.connect(_on_delete_deck_pressed)
	deck_option_button.item_selected.connect(_on_deck_selected)
	_select_tab("descend")
	_update_header()
	if GameState.toast != "":
		GameState.toast = ""


func _select_tab(tab_name: String) -> void:
	for key in nav_buttons.keys():
		nav_buttons[key].disabled = key == tab_name
	descend_panel.visible = tab_name == "descend"
	deck_panel.visible = tab_name == "deck"
	equipment_panel.visible = tab_name == "equipment"
	placeholder_panel.visible = tab_name in ["sell", "shop", "packs"]
	if tab_name == "descend":
		_update_descend_panel()
	elif tab_name == "deck":
		_refresh_deck_tab()
	elif tab_name == "equipment":
		_selected_rune_id = ""
		_refresh_equipment_tab()
	else:
		placeholder_panel.text = "未実装（フェーズB以降）"


func _update_header() -> void:
	player_name_label.text = GameState.player_name if GameState.player_name != "" else "無名"
	if GameState.floor > 0:
		info_label.text = "%s · デッキ %d/%d" % [
			Floors.layer_label(GameState.floor),
			_deck_count(),
			CollectionData.DECK_LIMIT,
		]
		top_right_button.text = "帰還"
	else:
		info_label.text = "最深 %s · デッキ %d/%d" % [
			Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "—",
			_deck_count(),
			CollectionData.DECK_LIMIT,
		]
		top_right_button.text = "タイトル"


func _update_descend_panel() -> void:
	if GameState.floor > 0:
		## HubScreen.tsx の CheckpointPanel 相当
		descend_status_label.text = "中継点\n%sを越えた\nHP %d/%d · SAN %d/%d · 貝殻 %d" % [
			Floors.layer_label(GameState.floor),
			GameState.hp,
			GameState.max_hp,
			GameState.sanity,
			GameState.max_sanity,
			GameState.shells,
		]
		primary_action_button.text = "次の層へ沈む"
		extract_button.visible = true
	else:
		## PrepareView.tsx 相当（ステ振りは未実装、フェーズB以降）
		descend_status_label.text = "探索準備\n最深到達: %s · 貝殻 %d" % [
			Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "未潜航",
			GameState.shells,
		]
		primary_action_button.text = "潜航開始"
		extract_button.visible = false


func _deck_count() -> int:
	var counts: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	return CollectionData.deck_size(counts)


func _on_primary_action_pressed() -> void:
	if GameState.floor <= 0:
		GameState.start_run(get_tree())
	else:
		GameState.resume_descent(get_tree())


func _on_extract_button_pressed() -> void:
	## extract_to_hub()はシーンを"hub"（＝このシーン自身）に戻す＝再読込されるため、
	## 再読込後の_ready()がヘッダー/タブ表示を作り直す。
	GameState.extract_to_hub(get_tree())


func _on_top_right_button_pressed() -> void:
	if GameState.floor > 0:
		GameState.extract_to_hub(get_tree())
	else:
		GameState.to_title(get_tree())


# ============================================================
# デッキ編成タブ（DeckHubScreen.tsx / DeckBuilderScreen.tsx 相当）
# ============================================================

func _refresh_deck_tab() -> void:
	_rebuild_deck_option_button()
	_refresh_deck_summary()
	_rebuild_card_list()


func _rebuild_deck_option_button() -> void:
	deck_option_button.clear()
	var names := CollectionData.decks.keys()
	for i in range(names.size()):
		deck_option_button.add_item(str(names[i]), i)
		if names[i] == CollectionData.active_deck:
			deck_option_button.select(i)
	delete_deck_button.disabled = names.size() <= 1


func _refresh_deck_summary() -> void:
	var deck: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	var n := CollectionData.deck_size(deck)
	deck_count_label.text = "%s: %d/%d枚（最低%d枚必要）" % [
		CollectionData.active_deck, n, CollectionData.DECK_LIMIT, CollectionData.MIN_RUN_DECK,
	]
	deck_error_label.text = CollectionData.loadout_error()


func _rebuild_card_list() -> void:
	for child in card_list_container.get_children():
		child.queue_free()
	var deck: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	var owned: Dictionary = CollectionData.owned_card_counts()
	var ids := owned.keys()
	ids.sort()
	for card_id in ids:
		var def := Cards.get_card(str(card_id))
		var name: String = def.get("name", str(card_id)) if not def.is_empty() else str(card_id)
		var in_deck: int = CollectionData.copies_of_base(deck, str(card_id))
		var owned_count: int = int(owned[card_id])

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = "%s（所持%d / デッキ内%d）" % [name, owned_count, in_deck]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.disabled = in_deck <= 0
		minus_btn.pressed.connect(_on_deck_remove_pressed.bind(str(card_id)))
		row.add_child(minus_btn)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		var deck_total := CollectionData.deck_size(deck)
		plus_btn.disabled = deck_total >= CollectionData.DECK_LIMIT or in_deck >= CollectionData.COPY_LIMIT or in_deck >= owned_count
		plus_btn.pressed.connect(_on_deck_add_pressed.bind(str(card_id)))
		row.add_child(plus_btn)

		card_list_container.add_child(row)


func _on_deck_add_pressed(card_id: String) -> void:
	CollectionData.add_to_deck(card_id)
	_refresh_deck_tab()
	_update_header()


func _on_deck_remove_pressed(card_id: String) -> void:
	CollectionData.remove_from_deck(card_id)
	_refresh_deck_tab()
	_update_header()


func _on_create_deck_pressed() -> void:
	if CollectionData.create_deck(new_deck_name_edit.text):
		new_deck_name_edit.text = ""
		_refresh_deck_tab()
		_update_header()


func _on_delete_deck_pressed() -> void:
	CollectionData.delete_deck(CollectionData.active_deck)
	_refresh_deck_tab()
	_update_header()


func _on_deck_selected(index: int) -> void:
	var name := deck_option_button.get_item_text(index)
	CollectionData.set_active_deck(name)
	_refresh_deck_tab()
	_update_header()


# ============================================================
# 装備タブ（EquipmentScreen.tsx 相当）
# ============================================================

func _refresh_equipment_tab() -> void:
	_rebuild_equipped_list()
	_refresh_stats_label()
	_rebuild_inventory_list()
	_rebuild_rune_list()


func _rebuild_equipped_list() -> void:
	for child in equipped_list_container.get_children():
		child.queue_free()
	var SLOT_LABEL := {"head": "頭", "chest": "胸", "arms": "腕", "legs": "脚", "feet": "足"}
	for slot in Equipment.EQUIPMENT_SLOTS:
		var inst = GameState.equipped.get(slot)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if inst != null:
			label.text = "%s: %s（Tier%d）" % [SLOT_LABEL.get(slot, slot), Equipment.equipment_label(inst), int(inst.get("tier", 1))]
		else:
			label.text = "%s: （なし）" % SLOT_LABEL.get(slot, slot)
		row.add_child(label)
		var unequip_btn := Button.new()
		unequip_btn.text = "外す"
		unequip_btn.disabled = inst == null
		unequip_btn.pressed.connect(_on_unequip_pressed.bind(slot))
		row.add_child(unequip_btn)
		equipped_list_container.add_child(row)


func _refresh_stats_label() -> void:
	var stats := Equipment.compute_equipment_stats(GameState.equipped, Callable(CollectionData, "peek_rune"))
	var extras: Array = []
	if stats.get("poisonImmune"):
		extras.append("毒無効")
	if stats.get("blockRetain"):
		extras.append("ブロック持ち越し")
	if stats.get("sanFullRestoreOnStart"):
		extras.append("戦闘開始時正気全快")
	if stats.get("expandedHand"):
		extras.append("手札拡張")
	if stats.get("hpPercentHealOnStart"):
		extras.append("戦闘開始時HP割合回復")
	if stats.get("sacrificeEnergyOnStart"):
		extras.append("戦闘開始時気力供物")
	if stats.get("intangibleOnHit"):
		extras.append("被弾時実体化解除")
	stats_label.text = "防御 %d　筋力 %d　毒耐性 %d　正気耐性 %d　引き +%d　回復/T %d%s" % [
		int(stats.defense), int(stats.strength), int(stats.poisonResist), int(stats.sanResist),
		int(stats.drawBonus), int(stats.healPerTurn),
		("\n" + "・".join(extras)) if extras.size() > 0 else "",
	]


func _rebuild_inventory_list() -> void:
	for child in inventory_list_container.get_children():
		child.queue_free()
	for inst in CollectionData.inventory.equipment:
		var def := Equipment.get_equipment(inst.get("def_id", ""))
		if def.is_empty():
			continue

		var col := VBoxContainer.new()

		var header := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s（%s, Tier%d, 威力%.2f）" % [
			Equipment.equipment_label(inst), def.get("slot", ""), int(inst.get("tier", 1)), float(inst.get("power", 1.0)),
		]
		header.add_child(label)
		var equip_btn := Button.new()
		equip_btn.text = "装備"
		equip_btn.pressed.connect(_on_equip_pressed.bind(str(inst.get("uid", ""))))
		header.add_child(equip_btn)
		col.add_child(header)

		var sockets: Array = inst.get("socketed_runes", [])
		for i in range(sockets.size()):
			var socket_row := HBoxContainer.new()
			socket_row.add_theme_constant_override("separation", 6)
			var rune_id = sockets[i]
			var socket_label := Label.new()
			socket_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if rune_id != null:
				var rune: Dictionary = CollectionData.rune_registry.get(rune_id, {})
				socket_label.text = "  ソケット%d: %s(%s)" % [i, rune.get("effect", "?"), str(rune.get("value", "?"))]
				var unsocket_btn := Button.new()
				unsocket_btn.text = "外す"
				unsocket_btn.pressed.connect(_on_unsocket_pressed.bind(str(inst.get("uid", "")), i))
				socket_row.add_child(socket_label)
				socket_row.add_child(unsocket_btn)
			else:
				socket_label.text = "  ソケット%d: 空" % i
				var socket_btn := Button.new()
				socket_btn.text = "ここに装着"
				socket_btn.disabled = _selected_rune_id == ""
				socket_btn.pressed.connect(_on_socket_pressed.bind(str(inst.get("uid", "")), i))
				socket_row.add_child(socket_label)
				socket_row.add_child(socket_btn)
			col.add_child(socket_row)

		inventory_list_container.add_child(col)
		inventory_list_container.add_child(HSeparator.new())


func _rebuild_rune_list() -> void:
	for child in rune_list_container.get_children():
		child.queue_free()
	for rune in CollectionData.inventory.runes:
		var row := HBoxContainer.new()
		var rune_id: String = str(rune.get("id", ""))
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mark := "▶ " if rune_id == _selected_rune_id else ""
		label.text = "%s%s（値%s）" % [mark, rune.get("effect", "?"), str(rune.get("value", "?"))]
		row.add_child(label)
		var select_btn := Button.new()
		select_btn.text = "選択解除" if rune_id == _selected_rune_id else "選択"
		select_btn.pressed.connect(_on_select_rune_pressed.bind(rune_id))
		row.add_child(select_btn)
		rune_list_container.add_child(row)


func _on_equip_pressed(equipment_uid: String) -> void:
	GameState.equip_item(equipment_uid)
	_refresh_equipment_tab()


func _on_unequip_pressed(slot: String) -> void:
	GameState.unequip_slot(slot)
	_refresh_equipment_tab()


func _on_select_rune_pressed(rune_id: String) -> void:
	_selected_rune_id = "" if _selected_rune_id == rune_id else rune_id
	_refresh_equipment_tab()


func _on_socket_pressed(equipment_uid: String, socket_index: int) -> void:
	if _selected_rune_id == "":
		return
	if CollectionData.socket_rune_to_equipment(equipment_uid, _selected_rune_id, socket_index):
		_selected_rune_id = ""
		GameState.sync_equipped_from_inventory(equipment_uid)
	_refresh_equipment_tab()


func _on_unsocket_pressed(equipment_uid: String, socket_index: int) -> void:
	if CollectionData.unsocket_rune_from_equipment(equipment_uid, socket_index):
		GameState.sync_equipped_from_inventory(equipment_uid)
	_refresh_equipment_tab()
