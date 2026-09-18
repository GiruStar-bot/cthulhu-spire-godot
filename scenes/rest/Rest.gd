extends Control

## RestView.tsx 相当。VillageHub で建物をクリックして酒場/鍛冶屋へ入る。
## 宿泊・購入・強化の数値ロジックは既存関数をそのまま使う。

const PIXEL_BUTTON := preload("res://scenes/ui/PixelButton.tscn")
const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"
const BUILDING_HOVER_LIFT := 12.0
const BUILDING_HOVER_DUR := 0.16
const FORGE_CARD_SIZE := Vector2(132, 198)
const SHOP_CARD_SIZE := Vector2(128, 192)

@onready var hub_layer: Control = $HubLayer
@onready var hub_vitals: VitalsHud = $HubLayer/HubHud/HubVitals
@onready var hub_shells: Label = $HubLayer/HubHud/HubShells
@onready var tavern_hotspot: Button = $HubLayer/TavernHotspot
@onready var smith_hotspot: Button = $HubLayer/SmithHotspot
@onready var leave_button: Button = $HubLayer/LeaveButton

@onready var inn_layer: Control = $InnLayer
@onready var inn_vitals: VitalsHud = $InnLayer/InnHud/InnVitals
@onready var inn_shells: Label = $InnLayer/InnHud/InnShells
@onready var stay_list: VBoxContainer = $InnLayer/StayList
@onready var beer_button: Button = $InnLayer/BeerPanel/BeerCol/BeerButton
@onready var landlady: TextureRect = $InnLayer/Landlady
@onready var landlady_line: Label = $InnLayer/LandladyLine

@onready var smith_layer: Control = $SmithLayer
@onready var smith_vitals: VitalsHud = $SmithLayer/SmithHud/SmithVitals
@onready var smith_shells: Label = $SmithLayer/SmithHud/SmithShells
@onready var smith_rank: Label = $SmithLayer/SmithHud/SmithRank
@onready var smith_goods: HFlowContainer = $SmithLayer/SmithBody/SmithGoodsScroll/SmithGoods
@onready var smith_equip: HFlowContainer = $SmithLayer/SmithBody/SmithEquipScroll/SmithEquip
@onready var smith_forge_button: Button = $SmithLayer/SmithMenu/SmithForgeButton

@onready var sub_layer: Control = $SubLayer
@onready var sub_title: Label = $SubLayer/SubPanel/SubTitle
@onready var sub_info: Label = $SubLayer/SubPanel/SubInfo
@onready var sub_actions: HFlowContainer = $SubLayer/SubPanel/SubScroll/SubActions

var _tavern_rest_y: float = 0.0
var _smith_rest_y: float = 0.0


func _ready() -> void:
	if GameState.rest_mode == "":
		GameState.rest_mode = "hub"
	tavern_hotspot.mouse_entered.connect(_on_building_hover.bind(tavern_hotspot, true))
	tavern_hotspot.mouse_exited.connect(_on_building_hover.bind(tavern_hotspot, false))
	smith_hotspot.mouse_entered.connect(_on_building_hover.bind(smith_hotspot, true))
	smith_hotspot.mouse_exited.connect(_on_building_hover.bind(smith_hotspot, false))
	resized.connect(_layout_hub_buildings)
	_layout_hub_buildings()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_hub_buildings()


func _layout_hub_buildings() -> void:
	if tavern_hotspot == null or smith_hotspot == null:
		return
	var view: Vector2 = size
	if view.x < 8.0 or view.y < 8.0:
		return
	var tavern_w: float = clampf(view.x * 0.52, 220.0, 544.0)
	var tavern_h: float = tavern_w * (1040.0 / 1904.0) + 28.0
	tavern_hotspot.size = Vector2(tavern_w, tavern_h)
	tavern_hotspot.position = Vector2(view.x * 0.04, view.y * 0.74 - tavern_h)
	_tavern_rest_y = tavern_hotspot.position.y
	var smith_w: float = clampf(view.x * 0.44, 180.0, 448.0)
	var smith_h: float = smith_w * (884.0 / 1739.0) + 28.0
	smith_hotspot.size = Vector2(smith_w, smith_h)
	smith_hotspot.position = Vector2(view.x - view.x * 0.04 - smith_w, view.y * 0.72 - smith_h)
	_smith_rest_y = smith_hotspot.position.y
	_layout_inn_npc(view)
	_layout_smith_npc(view)


func _layout_inn_npc(view: Vector2) -> void:
	var h: float = minf(view.y * 0.55, 396.0)
	var w: float = h * (831.0 / 1311.0)
	landlady.position = Vector2(view.x * 0.04, view.y - h)
	landlady.size = Vector2(w, h)
	landlady_line.position = Vector2(landlady.position.x + 12.0, landlady.position.y - 36.0)
	landlady_line.size = Vector2(maxf(160.0, w - 24.0), 32.0)


func _layout_smith_npc(view: Vector2) -> void:
	var npc: TextureRect = $SmithLayer/SmithNpc
	var line: Label = $SmithLayer/SmithLine
	var h: float = minf(view.y * 0.50, 380.0)
	var w: float = h * (925.0 / 1012.0)
	npc.position = Vector2(view.x - w - view.x * 0.02, view.y - h)
	npc.size = Vector2(w, h)
	line.position = Vector2(npc.position.x + 20.0, npc.position.y - 36.0)
	line.size = Vector2(maxf(80.0, w - 40.0), 32.0)


func _on_building_hover(hotspot: Button, hovering: bool) -> void:
	if GameState.rest_mode != "hub" and GameState.rest_mode != "":
		return
	var rest_y: float = _tavern_rest_y if hotspot == tavern_hotspot else _smith_rest_y
	var tw := hotspot.create_tween()
	tw.tween_property(hotspot, "position:y", rest_y - BUILDING_HOVER_LIFT if hovering else rest_y, BUILDING_HOVER_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _vitals_payload() -> Dictionary:
	var current_floor: int = int(GameState.floor)
	return {
		"player_name": GameState.player_name,
		"floor_text": "%s · %s" % [Floors.floor_band(current_floor), Floors.layer_label(current_floor)],
		"hp": GameState.hp,
		"max_hp": GameState.max_hp,
		"sanity": GameState.sanity,
		"max_sanity": GameState.max_sanity,
		"shells": GameState.shells,
		"show_header": true,
		"show_energy": false,
		"show_status": false,
		"show_shells": true,
	}


func _shells_text() -> String:
	return "貝殻 %d" % GameState.shells


func _refresh() -> void:
	var mode: String = GameState.rest_mode
	var is_hub: bool = mode == "hub" or mode == ""
	hub_layer.visible = is_hub
	inn_layer.visible = mode == "inn"
	smith_layer.visible = mode == "smith"
	sub_layer.visible = mode == "upgrade" or mode == "deck" or mode == "sell"
	var payload: Dictionary = _vitals_payload()
	hub_vitals.visible = true
	hub_vitals.set_show_frame(true)
	hub_vitals.bind(payload)
	hub_shells.text = _shells_text()
	inn_vitals.visible = true
	inn_vitals.set_show_frame(false)
	inn_vitals.bind(payload)
	inn_shells.text = _shells_text()
	smith_vitals.visible = false
	smith_shells.text = _shells_text()
	if is_hub:
		_layout_hub_buildings()
	elif mode == "inn":
		_refresh_inn_room()
	elif mode == "smith":
		_refresh_smith_room()
	else:
		_refresh_sub_room(mode)


func _refresh_inn_room() -> void:
	_free_children(stay_list)
	var rows: Array = [
		[10, "体力20%回復", "res://art/pixel/village/room-10.jpg"],
		[20, "体力50%回復", "res://art/pixel/village/room-20.jpg"],
		[30, "体力全快", "res://art/pixel/village/room-30.jpg"],
	]
	for row in rows:
		var cost: int = int(row[0])
		stay_list.add_child(_make_stay_row(cost, str(row[1]), str(row[2])))
	var beer_sold: bool = _beer_sold()
	beer_button.disabled = beer_sold or GameState.shells < 5
	beer_button.text = "売り切れ" if beer_sold else "ビール瓶 · 貝殻5"


func _make_stay_row(cost: int, heal_text: String, art_path: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 96)
	button.disabled = GameState.shells < cost
	button.pressed.connect(_stay.bind(cost))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(148, 84)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _load_texture_safe(art_path)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var caption := Label.new()
	caption.text = "%d貝殻\n%s" % [cost, heal_text]
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	button.add_child(row)
	return button


func _beer_sold() -> bool:
	if not (GameState.village is Dictionary):
		return false
	return GameState.village.get("beerSold", false) and true


func _on_beer_pressed() -> void:
	if _beer_sold():
		return
	if GameState.shells < 5:
		return
	if not GameState.spend_shells(5):
		return
	CollectionData.add_loot_card("beer")
	if GameState.village is Dictionary:
		GameState.village["beerSold"] = true
	_refresh()


## GameState.village.smith（smith.ts の makeSmith() の戻り値相当：
## rank/kind/taboo/goods/equipment_goods）を取得する共通ヘルパー
func _current_smith() -> Dictionary:
	if not (GameState.village is Dictionary):
		return {}
	var smith: Dictionary = GameState.village.get("smith", {})
	return smith


## store.ts の forgeAtSmith() が参照する `!!s.village?.smith.taboo` 相当
func _is_taboo_smith() -> bool:
	return _current_smith().get("taboo", false) and true


func _refresh_smith_room() -> void:
	var smith: Dictionary = _current_smith()
	var taboo: bool = _is_taboo_smith()
	var rank: String = str(smith.get("rank", "normal"))
	smith_rank.text = "受け取れ" if taboo else Smith.rank_label(rank)
	smith_forge_button.text = "焼く（強化）　無料" if taboo else "焼く（強化）　貝殻5"
	_free_children(smith_goods)
	var goods: Array = smith.get("goods", [])
	var shown_cards: int = 0
	for good in goods:
		if good.get("sold", false):
			continue
		var def_id: String = str(good.get("def_id", ""))
		var card_def: Dictionary = Cards.get_card(def_id)
		var price: int = int(good.get("price", 0))
		var price_text: String = "無料" if price <= 0 or taboo else "%d貝殻" % price
		var disabled: bool = GameState.shells < price and price > 0 and not taboo
		smith_goods.add_child(_make_shop_card(card_def, def_id, price_text, disabled, _buy_card_good.bind(good)))
		shown_cards += 1
	if shown_cards == 0:
		var empty := Label.new()
		empty.text = "売約済み"
		smith_goods.add_child(empty)
	_free_children(smith_equip)
	$SmithLayer/SmithBody/EquipLabel.visible = false
	$SmithLayer/SmithBody/SmithEquipScroll.visible = false


func _make_shop_card(def: Dictionary, def_id: String, price_text: String, disabled: bool, action: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(SHOP_CARD_SIZE.x, SHOP_CARD_SIZE.y + 28.0)
	wrap.add_theme_constant_override("separation", 4)
	var view: CombatCard = COMBAT_CARD.new()
	view.custom_minimum_size = SHOP_CARD_SIZE
	view.size = SHOP_CARD_SIZE
	var fake: Dictionary = {"uid": "shop-%s" % def_id, "defId": def_id}
	view.configure(fake, def, not disabled, false, true)
	if disabled:
		view.disabled = true
	else:
		view.pressed.connect(action)
	wrap.add_child(view)
	var price_label := Label.new()
	price_label.text = price_text
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.add_theme_color_override("font_color", Color("d4a84b"))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(price_label)
	return wrap


func _make_shop_equip(def: Dictionary, label: String, price_text: String, disabled: bool, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 150)
	button.disabled = disabled
	button.pressed.connect(action)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 80)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = _load_texture_safe(str(def.get("art", "")))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)
	var name_label := Label.new()
	name_label.text = label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var price_label := Label.new()
	price_label.text = price_text
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color("d4a84b"))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price_label)
	button.add_child(col)
	return button


func _refresh_sub_room(mode: String) -> void:
	GameState.prune_run_deck()
	_free_children(sub_actions)
	if mode == "upgrade":
		var taboo: bool = _is_taboo_smith()
		sub_title.text = "焼く（強化・禁忌）" if taboo else "焼く（強化）"
		sub_info.text = "貝殻0で一度だけ強化する（倍率2倍）。カードを選ぶ。" if taboo else "貝殻5で一度だけ強化する（倍率1.5倍）。カードを選ぶ。"
		_fill_run_deck_cards(true)
	elif mode == "deck":
		sub_title.text = "潜航デッキ"
		sub_info.text = "この沈降で使うデッキ。戦闘中に増えたカードは残らない。"
		_fill_run_deck_cards(false)
	elif mode == "sell":
		sub_title.text = "売却"
		sub_info.text = "探索中は売却できない。拠点の売却で手放す。"


func _fill_run_deck_cards(forging: bool) -> void:
	var taboo: bool = _is_taboo_smith()
	var cost: int = 0 if taboo else 5
	for card in GameState.deck:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var uid: String = str(card.get("uid", ""))
		var def_id: String = str(card.get("defId", ""))
		var def: Dictionary = Cards.get_card(def_id)
		if def.is_empty():
			continue
		var already: bool = card.get("upgraded", false) or float(card.get("forge", 0.0)) > 0.0
		var playable: bool = forging and not already and (cost <= 0 or GameState.shells >= cost)
		var view: CombatCard = COMBAT_CARD.new()
		view.custom_minimum_size = FORGE_CARD_SIZE
		view.size = FORGE_CARD_SIZE
		view.configure(card, def, playable, false, forging and not already)
		if forging and not already and playable:
			view.pressed.connect(_forge.bind(uid))
		elif forging and already:
			view.modulate = Color(0.72, 0.72, 0.72, 1.0)
			view.disabled = true
			var stamp := Label.new()
			stamp.text = "強化済"
			stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stamp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			stamp.offset_top = -28.0
			stamp.add_theme_font_size_override("font_size", 12)
			stamp.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42, 1))
			stamp.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
			stamp.add_theme_constant_override("outline_size", 4)
			stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.add_child(stamp)
		elif forging and not playable:
			view.modulate = Color(0.62, 0.62, 0.62, 1.0)
			view.disabled = true
		sub_actions.add_child(view)
	if sub_actions.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "デッキにカードがない。"
		empty.add_theme_color_override("font_color", Color(0.78, 0.72, 0.60, 1))
		sub_actions.add_child(empty)


func _stay(cost: int) -> void:
	if not GameState.spend_shells(cost):
		return
	var hp_ratio := 1.0 if cost == 30 else (0.5 if cost == 20 else 0.2)
	GameState.hp = min(GameState.max_hp, GameState.hp + int(GameState.max_hp * hp_ratio))
	GameState.sanity = min(GameState.max_sanity, GameState.sanity + cost)
	_refresh()


## store.ts の buyGood()。goodはGameState.village.smith.goods内のDictionary参照そのもの
## （GDScriptのDictionaryは参照型のため、good.sold = true が元の配列要素へ反映される）。
func _buy_card_good(good: Dictionary) -> void:
	if good.get("sold", false):
		return
	var price := int(good.get("price", 0))
	if price > 0 and not GameState.spend_shells(price):
		return
	CollectionData.add_loot_card(str(good.get("def_id", "")))
	good.sold = true
	_refresh()


## store.ts の buyEquipmentGood()。在庫生成時（Smith.make_equipment_goods）に確保したuidは
## 表示専用で、購入が確定した時点で同じdef_id/tierを使って改めて roll_equipment_at_tier() を
## 呼び直す（power/bonus_statsが在庫プレビュー時とは変わる、実ソースの仕様上の挙動）。
func _buy_equipment_good(good: Dictionary) -> void:
	if good.get("sold", false):
		return
	var price := int(good.get("price", 0))
	if price > 0 and not GameState.spend_shells(price):
		return
	var inst := Equipment.roll_equipment_at_tier(str(good.get("def_id", "")), int(good.get("tier", 1)), GameState.rng, "smith")
	CollectionData.add_loot_equipment(inst)
	good.sold = true
	_refresh()


## store.ts の forgeAtSmith()。taboo鍛冶屋なら無料・倍率2倍、通常は貝殻5・倍率1.5倍
## （smith.ts の forgeCard(card, taboo) 相当）。1枚につき一度だけ強化可能（card.forge>0で判定）。
func _forge(uid: String) -> void:
	var taboo := _is_taboo_smith()
	var cost := 0 if taboo else 5
	var mul := 2.0 if taboo else 1.5
	for card in GameState.deck:
		if str(card.uid) == uid:
			if float(card.get("forge", 0.0)) > 0.0:
				return
			if cost > 0 and not GameState.spend_shells(cost):
				return
			card.upgraded = true
			card.forge = float(card.get("forge", 1.0)) * mul
			break
	_refresh()


func _add_action(text_value: String, action: Callable, disabled: bool = false) -> void:
	var button: Button = PIXEL_BUTTON.instantiate() as Button
	button.text = text_value
	button.disabled = disabled
	button.pressed.connect(action)
	sub_actions.add_child(button)


func _free_children(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var kids: Array = node.get_children()
	for child in kids:
		node.remove_child(child)
		child.queue_free()


func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return load(FALLBACK_TEX) as Texture2D
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return load(FALLBACK_TEX) as Texture2D


func _on_inn_button_pressed() -> void:
	GameState.visit_village("inn")
	_refresh()


func _on_smith_button_pressed() -> void:
	GameState.visit_village("smith")
	_refresh()


func _on_back_button_pressed() -> void:
	GameState.visit_village("hub")
	_refresh()


func _on_leave_button_pressed() -> void:
	GameState.leave_village(get_tree())


func _on_smith_deck_pressed() -> void:
	GameState.visit_village("deck")
	_refresh()


func _on_smith_forge_pressed() -> void:
	GameState.visit_village("upgrade")
	_refresh()


func _on_smith_sell_pressed() -> void:
	GameState.visit_village("sell")
	_refresh()


func _on_sub_back_pressed() -> void:
	GameState.visit_village("smith")
	_refresh()
