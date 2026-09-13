extends Control

## HubScreen.tsx 相当のタブハブ。売却・ショップ・カードパックはフェーズBの簡易操作UI。

const TICKET_ARCHETYPES := ["fanatic", "knight", "poison", "outer", "elder", "deep", "offering", "shadow", "greatold"]
const TICKET_LABELS := {
	"fanatic": "狂信", "knight": "騎士", "poison": "毒", "outer": "外宇宙", "elder": "旧神",
	"deep": "深き者", "offering": "供物", "shadow": "影", "greatold": "大いなるもの",
}
const SELL_PRICE := {"starter": 2, "common": 5, "uncommon": 10, "rare": 20}

@onready var player_name_label: Label = $Root/Header/PlayerNameLabel
@onready var info_label: Label = $Root/Header/InfoLabel
@onready var top_right_button: Button = $Root/Header/TopRightButton
@onready var descend_panel: VBoxContainer = $Root/Body/Content/DescendPanel
@onready var descend_status_label: Label = $Root/Body/Content/DescendPanel/DescendStatusLabel
@onready var primary_action_button: Button = $Root/Body/Content/DescendPanel/PrimaryActionButton
@onready var extract_button: Button = $Root/Body/Content/DescendPanel/ExtractButton
@onready var placeholder_panel: Label = $Root/Body/Content/PlaceholderPanel
@onready var commerce_panel: VBoxContainer = $Root/Body/Content/CommercePanel
@onready var commerce_title: Label = $Root/Body/Content/CommercePanel/CommerceTitle
@onready var commerce_status: Label = $Root/Body/Content/CommercePanel/CommerceStatus
@onready var commerce_list: VBoxContainer = $Root/Body/Content/CommercePanel/CommerceList
@onready var commerce_refresh_button: Button = $Root/Body/Content/CommercePanel/CommerceRefreshButton

@onready var nav_buttons: Dictionary = {
	"descend": $Root/Body/Nav/DescendButton,
	"deck": $Root/Body/Nav/DeckButton,
	"equipment": $Root/Body/Nav/EquipmentButton,
	"sell": $Root/Body/Nav/SellButton,
	"shop": $Root/Body/Nav/ShopButton,
	"packs": $Root/Body/Nav/PacksButton,
}

var active_tab := "descend"
var shop_rank := "普通"
var shop_cards: Array = []
var shop_equipment: Array = []
var last_pack_result: Array = []


func _ready() -> void:
	for tab_name in nav_buttons.keys():
		nav_buttons[tab_name].pressed.connect(_select_tab.bind(tab_name))
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	extract_button.pressed.connect(_on_extract_button_pressed)
	top_right_button.pressed.connect(_on_top_right_button_pressed)
	commerce_refresh_button.pressed.connect(_refresh_active_commerce)
	_select_tab("descend")
	_update_header()


func _select_tab(tab_name: String) -> void:
	active_tab = tab_name
	for key in nav_buttons.keys():
		nav_buttons[key].disabled = key == tab_name
	descend_panel.visible = tab_name == "descend"
	commerce_panel.visible = tab_name in ["sell", "shop", "packs"]
	placeholder_panel.visible = not descend_panel.visible and not commerce_panel.visible
	if tab_name == "descend":
		_update_descend_panel()
	elif commerce_panel.visible:
		_refresh_active_commerce()
	else:
		placeholder_panel.text = "未実装（フェーズB以降）"


func _update_header() -> void:
	player_name_label.text = GameState.player_name if GameState.player_name != "" else "無名"
	var layer := Floors.layer_label(GameState.floor) if GameState.floor > 0 else (Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "—")
	info_label.text = "最深 %s · デッキ %d/%d · 貝殻 %d" % [layer, _deck_count(), CollectionData.DECK_LIMIT, GameState.shells]
	top_right_button.text = "帰還" if GameState.floor > 0 else "タイトル"


func _update_descend_panel() -> void:
	if GameState.floor > 0:
		descend_status_label.text = "中継点\n%sを越えた\nHP %d/%d · SAN %d/%d · 貝殻 %d" % [Floors.layer_label(GameState.floor), GameState.hp, GameState.max_hp, GameState.sanity, GameState.max_sanity, GameState.shells]
		primary_action_button.text = "次の層へ沈む"
		extract_button.visible = true
	else:
		descend_status_label.text = "探索準備\n最深到達: %s · 貝殻 %d" % [Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "未潜航", GameState.shells]
		primary_action_button.text = "潜航開始"
		extract_button.visible = false


func _refresh_active_commerce() -> void:
	_update_header()
	for child in commerce_list.get_children():
		child.free()
	match active_tab:
		"sell": _show_sell()
		"shop": _show_shop()
		"packs": _show_packs()


func _show_sell() -> void:
	commerce_title.text = "売却"
	commerce_status.text = "売れるカード・未装備の装備を選んで貝殻に換える。　所持: %d" % GameState.shells
	commerce_refresh_button.text = "一覧を更新"
	var used := _used_cards()
	var grouped := {}
	for card in CollectionData.inventory.cards:
		var card_id := str(card.get("base_card_id", card.get("baseCardId", "")))
		grouped[card_id] = int(grouped.get(card_id, 0)) + 1
	for card_id in grouped.keys():
		var sellable := int(grouped[card_id]) - int(used.get(card_id, 0))
		if sellable <= 0 or not Cards.CARDS.has(card_id):
			continue
		var def: Dictionary = Cards.get_card(card_id)
		var price := int(SELL_PRICE.get(str(def.get("rarity", "")), 0))
		if price <= 0:
			continue
		_add_action_button("カードを売却: %s  (%d貝殻 / 残り%d)" % [def.get("name", card_id), price, sellable], _sell_card.bind(card_id, price))
	var equipped_uids := {}
	for inst in GameState.equipped.values():
		if inst != null:
			equipped_uids[str(inst.get("uid", ""))] = true
	for inst in CollectionData.inventory.equipment:
		var uid := str(inst.get("uid", ""))
		if uid == "" or equipped_uids.has(uid):
			continue
		_add_action_button("装備を売却: %s  (%d貝殻)" % [Equipment.equipment_label(inst), int(inst.get("tier", 1)) * 5], _sell_equipment.bind(uid))
	if commerce_list.get_child_count() == 0:
		_add_info("売却できる品がない。デッキに使用中のカードと装備中の品は保護される。")


func _show_shop() -> void:
	if shop_cards.is_empty() and shop_equipment.is_empty():
		_generate_shop_stock()
	commerce_title.text = "鍛冶屋"
	commerce_status.text = "%sの在庫。所持: %d貝殻" % [shop_rank, GameState.shells]
	commerce_refresh_button.text = "在庫を更新"
	for good in shop_cards:
		if good.get("sold", false):
			continue
		var def: Dictionary = Cards.get_card(str(good.def_id))
		_add_action_button("購入: %s  (%d貝殻)" % [def.get("name", good.def_id), int(good.price)], _buy_shop_card.bind(str(good.uid)))
	for good in shop_equipment:
		if good.get("sold", false):
			continue
		_add_action_button("購入: %s  (%d貝殻)" % [Equipment.equipment_label(good.inst), int(good.price)], _buy_shop_equipment.bind(str(good.uid)))
	if commerce_list.get_child_count() == 0:
		_add_info("在庫はすべて購入済み。更新して新しい在庫を見る。")


func _show_packs() -> void:
	commerce_title.text = "カードパック"
	commerce_status.text = "属性チケット1枚で、対応属性2枚を含む4枚を獲得する。"
	commerce_refresh_button.text = "結果を閉じる"
	if not last_pack_result.is_empty():
		_add_info("今回の獲得: " + ", ".join(last_pack_result))
	for archetype in TICKET_ARCHETYPES:
		var count := int(CollectionData.pack_tickets.get(archetype, 0))
		_add_action_button("%sパックを開封  (チケット: %d)" % [TICKET_LABELS[archetype], count], _open_pack.bind(archetype), count <= 0)


func _generate_shop_stock() -> void:
	shop_cards.clear()
	shop_equipment.clear()
	var roll := _rand()
	shop_rank = "禁忌" if roll < 0.002 else ("神" if roll < 0.032 else ("天才" if roll < 0.182 else ("中級" if roll < 0.382 else "普通")))
	var candidates: Array = []
	for def in Cards.CARDS.values():
		if def.get("shop", false) and def.get("type", "") != "status" and not def.get("enemyOnly", false):
			candidates.append(def)
	for i in range(mini(6, candidates.size())):
		var def: Dictionary = candidates[_rand_index(candidates.size())]
		shop_cards.append({"uid": "shop_card_%s_%s" % [Time.get_ticks_usec(), i], "def_id": def.id, "price": _shop_price(def), "sold": false})
	var tier := {"普通": 1, "中級": 2, "天才": 3, "神": 4, "禁忌": 5}.get(shop_rank, 1)
	var equipment_ids: Array = Equipment.EQUIPMENT.keys()
	for i in range(2):
		var inst := Equipment.roll_equipment_at_tier(str(equipment_ids[_rand_index(equipment_ids.size())]), tier, GameState.rng, "smith")
		shop_equipment.append({"uid": "shop_equipment_%s_%s" % [Time.get_ticks_usec(), i], "inst": inst, "price": 0 if shop_rank == "禁忌" else tier * 15, "sold": false})


func _shop_price(def: Dictionary) -> int:
	if def.get("id", "") == "beer":
		return 5
	var rarity := str(def.get("rarity", "common"))
	return max(3, int(def.get("cost", 1)) * 5 + (15 if rarity == "rare" else (5 if rarity == "uncommon" else 0)))


func _sell_card(card_id: String, price: int) -> void:
	var used := int(_used_cards().get(card_id, 0))
	var owned: Array = CollectionData.inventory.cards.filter(func(card): return str(card.get("base_card_id", card.get("baseCardId", ""))) == card_id)
	if owned.size() <= used:
		return
	CollectionData.remove_cards([str(owned[used].get("instance_id", owned[used].get("instanceId", "")))])
	GameState.add_shells(price)
	_refresh_active_commerce()


func _sell_equipment(uid: String) -> void:
	for inst in CollectionData.inventory.equipment:
		if str(inst.get("uid", "")) == uid:
			CollectionData.remove_equipment([uid])
			GameState.add_shells(int(inst.get("tier", 1)) * 5)
			_refresh_active_commerce()
			return


func _buy_shop_card(uid: String) -> void:
	for good in shop_cards:
		if str(good.uid) != uid or good.sold:
			continue
		if GameState.spend_shells(int(good.price)):
			CollectionData.add_loot_card(str(good.def_id))
			good.sold = true
		_refresh_active_commerce()
		return


func _buy_shop_equipment(uid: String) -> void:
	for good in shop_equipment:
		if str(good.uid) != uid or good.sold:
			continue
		if GameState.spend_shells(int(good.price)):
			CollectionData.add_loot_equipment(good.inst)
			good.sold = true
		_refresh_active_commerce()
		return


func _open_pack(archetype: String) -> void:
	if not CollectionData.consume_pack_ticket(archetype):
		return
	last_pack_result.clear()
	for i in range(2):
		_add_pack_card(_pick_pack_card(archetype, true))
	for i in range(2):
		_add_pack_card(_pick_pack_card("", false))
	_refresh_active_commerce()


func _pick_pack_card(archetype: String, include_shop: bool) -> String:
	var owner := GameState.character if GameState.character != "" else "investigator"
	var pool: Array = []
	for def in Cards.CARDS.values():
		if def.get("rarity", "") in ["starter", "status"] or def.get("enemyOnly", false) or def.get("grimoire", false):
			continue
		if not include_shop and def.get("shop", false):
			continue
		if def.get("owner", "") not in ["shared", owner]:
			continue
		if archetype != "" and def.get("archetype", "") != archetype:
			continue
		pool.append(def)
	if pool.is_empty() and archetype != "":
		return _pick_pack_card("", include_shop)
	var rarity_roll := _rand()
	var rarity := "common" if rarity_roll < 0.62 else ("uncommon" if rarity_roll < 0.9 else "rare")
	var rarity_pool: Array = pool.filter(func(def): return def.get("rarity", "") == rarity)
	var candidates: Array = rarity_pool if not rarity_pool.is_empty() else pool
	var def: Dictionary = candidates[_rand_index(candidates.size())]
	return str(def.id)


func _add_pack_card(card_id: String) -> void:
	if CollectionData.add_loot_card(card_id):
		last_pack_result.append(str(Cards.get_card(card_id).get("name", card_id)))


func _used_cards() -> Dictionary:
	var used := {}
	for counts in CollectionData.decks.values():
		for card_id in counts.keys():
			used[card_id] = int(used.get(card_id, 0)) + int(counts[card_id])
	return used


func _add_action_button(text_value: String, action: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = text_value
	button.disabled = disabled
	button.pressed.connect(action)
	commerce_list.add_child(button)


func _add_info(text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	commerce_list.add_child(label)


func _rand() -> float:
	return GameState.rng.next_float() if GameState.rng != null else randf()


func _rand_index(size: int) -> int:
	return clampi(int(_rand() * size), 0, size - 1)


func _deck_count() -> int:
	var total := 0
	for v in CollectionData.decks.get(CollectionData.active_deck, {}).values():
		total += int(v)
	return total


func _on_primary_action_pressed() -> void:
	if GameState.floor <= 0:
		GameState.start_run(get_tree())
	else:
		GameState.resume_descent(get_tree())


func _on_extract_button_pressed() -> void:
	GameState.extract_to_hub(get_tree())


func _on_top_right_button_pressed() -> void:
	if GameState.floor > 0:
		GameState.extract_to_hub(get_tree())
	else:
		GameState.to_title(get_tree())
