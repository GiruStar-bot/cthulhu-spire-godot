extends Control

## 実ソースの RestView.tsx 相当（村ハブ→酒場/鍛冶屋のサブ画面）。
## GameState.rest_mode（""扱い="hub"）で表示を切り替える。sceneは"rest"のまま。
## 酒場（宿泊）は簡易UI。鍛冶屋は smith.ts の makeSmith() が生成した
## GameState.village.smith（rank/kind/taboo/goods/equipment_goods）を消費する。

@onready var status_label: Label = $StatusLabel
@onready var inn_button: Button = $VillageButtons/InnButton
@onready var smith_button: Button = $VillageButtons/SmithButton
@onready var leave_button: Button = $VillageButtons/LeaveButton
@onready var back_button: Button = $BackButton
@onready var room_panel: VBoxContainer = $RoomPanel
@onready var room_title: Label = $RoomPanel/RoomTitle
@onready var room_info: Label = $RoomPanel/RoomInfo
@onready var room_actions: VBoxContainer = $RoomPanel/RoomActions


func _ready() -> void:
	if GameState.rest_mode == "":
		GameState.rest_mode = "hub"
	_refresh()


func _refresh() -> void:
	var mode: String = GameState.rest_mode
	var is_hub := mode == "hub" or mode == ""
	var caption := "村（休憩ノード）" if is_hub else ("酒場" if mode == "inn" else "鍛冶屋")
	status_label.text = "%s\n%s" % [Floors.layer_label(GameState.floor), caption]
	inn_button.visible = is_hub
	smith_button.visible = is_hub
	leave_button.visible = is_hub
	back_button.visible = not is_hub
	room_panel.visible = not is_hub
	if not is_hub:
		_refresh_room(mode)


## GameState.village.smith（smith.ts の makeSmith() の戻り値相当：
## rank/kind/taboo/goods/equipment_goods）を取得する共通ヘルパー
func _current_smith() -> Dictionary:
	if not (GameState.village is Dictionary):
		return {}
	return GameState.village.get("smith", {})


## store.ts の forgeAtSmith() が参照する `!!s.village?.smith.taboo` 相当
func _is_taboo_smith() -> bool:
	return bool(_current_smith().get("taboo", false))


func _refresh_room(mode: String) -> void:
	for child in room_actions.get_children(): child.free()
	room_info.text = "所持: %d貝殻" % GameState.shells
	if mode == "inn":
		room_title.text = "酒場"
		_add_action("宿泊 10貝殻（体力20%・正気+10）", _stay.bind(10))
		_add_action("宿泊 20貝殻（体力50%・正気+20）", _stay.bind(20))
		_add_action("宿泊 30貝殻（体力全快・正気+30）", _stay.bind(30))
	elif mode == "smith":
		_refresh_smith_room()
	elif mode == "upgrade":
		var taboo := _is_taboo_smith()
		room_title.text = "焼く（強化・禁忌）" if taboo else "焼く（強化）"
		room_info.text = "貝殻0で一度だけ強化する（倍率2倍）。" if taboo else "貝殻5で一度だけ強化する（倍率1.5倍）。"
		for card in GameState.deck:
			if not card.get("upgraded", false): _add_action("強化: " + Cards.get_card(card.defId).get("name", card.defId), _forge.bind(str(card.uid)))
	elif mode == "deck":
		room_title.text = "デッキ編集"
		room_info.text = "拠点のデッキ編成タブを利用する。"
		_add_action("拠点へ戻る", func(): GameState.goto_scene(get_tree(), "hub"))
	elif mode == "sell":
		room_title.text = "売却"
		room_info.text = "拠点の売却タブを利用する。"
		_add_action("拠点へ戻る", func(): GameState.goto_scene(get_tree(), "hub"))


## RestView.tsx の SmithRoom 相当。GameState.village.smith.goods（カード在庫）と
## equipment_goods（装備在庫）をそれぞれ購入ボタンとして並べる。
func _refresh_smith_room() -> void:
	var smith := _current_smith()
	var taboo: bool = bool(smith.get("taboo", false))
	var rank: String = str(smith.get("rank", "normal"))

	room_title.text = "鍛冶屋"
	room_info.text = "受け取れ　所持: %d貝殻" % GameState.shells if taboo else "%s　所持: %d貝殻" % [Smith.rank_label(rank), GameState.shells]

	var goods: Array = smith.get("goods", [])
	for good in goods:
		if bool(good.get("sold", false)):
			continue
		var def_id := str(good.get("def_id", ""))
		var card_def := Cards.get_card(def_id)
		var price := int(good.get("price", 0))
		var price_text := "無料" if price <= 0 else "%d貝殻" % price
		_add_action("購入: %s（%s）" % [str(card_def.get("name", def_id)), price_text], _buy_card_good.bind(good), GameState.shells < price)

	var equipment_goods: Array = smith.get("equipment_goods", [])
	for good in equipment_goods:
		if bool(good.get("sold", false)):
			continue
		var def_id := str(good.get("def_id", ""))
		var equip_def := Equipment.get_equipment(def_id)
		var tier := int(good.get("tier", 1))
		var price := int(good.get("price", 0))
		var price_text := "無料" if price <= 0 else "%d貝殻" % price
		_add_action("装備購入: %s Tier%d（%s）" % [str(equip_def.get("name", def_id)), tier, price_text], _buy_equipment_good.bind(good), GameState.shells < price)

	_add_action(("焼く（強化）　貝殻0・倍率2倍" if taboo else "焼く（強化）　貝殻5・倍率1.5倍"), func(): GameState.visit_village("upgrade"); _refresh())
	_add_action("デッキ編集へ", func(): GameState.visit_village("deck"); _refresh())
	_add_action("売却へ", func(): GameState.visit_village("sell"); _refresh())


func _stay(cost: int) -> void:
	if not GameState.spend_shells(cost): return
	var hp_ratio := 1.0 if cost == 30 else (0.5 if cost == 20 else 0.2)
	GameState.hp = min(GameState.max_hp, GameState.hp + int(GameState.max_hp * hp_ratio))
	GameState.sanity = min(GameState.max_sanity, GameState.sanity + cost)
	_refresh()


## store.ts の buyGood()。goodはGameState.village.smith.goods内のDictionary参照そのもの
## （GDScriptのDictionaryは参照型のため、good.sold = true が元の配列要素へ反映される）。
func _buy_card_good(good: Dictionary) -> void:
	if bool(good.get("sold", false)):
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
	if bool(good.get("sold", false)):
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
	var button := Button.new()
	button.text = text_value
	button.disabled = disabled
	button.pressed.connect(action)
	room_actions.add_child(button)


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
