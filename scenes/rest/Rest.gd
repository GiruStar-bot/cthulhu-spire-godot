extends Control

## 実ソースの RestView.tsx 相当（村ハブ→酒場/鍛冶屋のサブ画面）。
## GameState.rest_mode（""扱い="hub"）で表示を切り替える。sceneは"rest"のまま。
## 酒場/鍛冶屋の中身（宿泊・購入等）はフェーズB以降、ここではプレースホルダーのみ。

@onready var status_label: Label = $StatusLabel
@onready var inn_button: Button = $VillageButtons/InnButton
@onready var smith_button: Button = $VillageButtons/SmithButton
@onready var leave_button: Button = $VillageButtons/LeaveButton
@onready var back_button: Button = $BackButton
@onready var room_panel: VBoxContainer = $RoomPanel
@onready var room_title: Label = $RoomPanel/RoomTitle
@onready var room_info: Label = $RoomPanel/RoomInfo
@onready var room_actions: VBoxContainer = $RoomPanel/RoomActions

var shop_stock: Array = []


func _ready() -> void:
	if GameState.rest_mode == "":
		GameState.rest_mode = "hub"
	_refresh()


func _refresh() -> void:
	var mode: String = GameState.rest_mode
	var is_hub := mode == "hub" or mode == ""
	var caption := "村（休憩ノード）" if is_hub else ("酒場（未実装）" if mode == "inn" else "鍛冶屋（未実装）")
	status_label.text = "%s\n%s" % [Floors.layer_label(GameState.floor), caption]
	inn_button.visible = is_hub
	smith_button.visible = is_hub
	leave_button.visible = is_hub
	back_button.visible = not is_hub
	room_panel.visible = not is_hub
	if not is_hub:
		_refresh_room(mode)


func _refresh_room(mode: String) -> void:
	for child in room_actions.get_children(): child.free()
	room_info.text = "所持: %d貝殻" % GameState.shells
	if mode == "inn":
		room_title.text = "酒場"
		_add_action("宿泊 10貝殻（体力20%・正気+10）", _stay.bind(10))
		_add_action("宿泊 20貝殻（体力50%・正気+20）", _stay.bind(20))
		_add_action("宿泊 30貝殻（体力全快・正気+30）", _stay.bind(30))
	elif mode == "smith":
		room_title.text = "鍛冶屋"
		if shop_stock.is_empty():
			for card in Cards.CARDS.values():
				if card.get("shop", false) and shop_stock.size() < 4: shop_stock.append({"id": card.id, "price": max(3, int(card.get("cost", 1)) * 5), "sold": false})
		for good in shop_stock:
			if not good.sold: _add_action("購入: %s（%d貝殻）" % [Cards.get_card(good.id).get("name", good.id), good.price], _buy.bind(good))
		_add_action("焼く（強化）", func(): GameState.visit_village("upgrade"); _refresh())
		_add_action("デッキ編集へ", func(): GameState.visit_village("deck"); _refresh())
		_add_action("売却へ", func(): GameState.visit_village("sell"); _refresh())
	elif mode == "upgrade":
		room_title.text = "焼く（強化）"
		room_info.text = "貝殻5で一度だけ強化する。"
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


func _stay(cost: int) -> void:
	if not GameState.spend_shells(cost): return
	var hp_ratio := 1.0 if cost == 30 else (0.5 if cost == 20 else 0.2)
	GameState.hp = min(GameState.max_hp, GameState.hp + int(GameState.max_hp * hp_ratio))
	GameState.sanity = min(GameState.max_sanity, GameState.sanity + cost)
	_refresh()

func _buy(good: Dictionary) -> void:
	if GameState.spend_shells(int(good.price)):
		CollectionData.add_loot_card(str(good.id)); good.sold = true
	_refresh()

func _forge(uid: String) -> void:
	if not GameState.spend_shells(5): return
	for card in GameState.deck:
		if str(card.uid) == uid:
			card.upgraded = true; card.forge = float(card.get("forge", 1.0)) * 1.5; break
	_refresh()

func _add_action(text_value: String, action: Callable) -> void:
	var button := Button.new(); button.text = text_value; button.pressed.connect(action); room_actions.add_child(button)


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
