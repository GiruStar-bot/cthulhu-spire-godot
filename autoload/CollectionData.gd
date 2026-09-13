extends Node

## カード・ルーン・装備・デッキの実体（実ソース src/store/useCollectionStore.ts 相当）。
## GameState（ラン中の状態＋プロフィール、game/store.ts 相当）とは別の永続化層。混同しないこと。
##
## 参照: reference/cthulhu-spire-main/src/store/useCollectionStore.ts
##
## equipment/runesの具体的なDictionary形状は scripts/equipment.gd (Equipment.roll_equipment_at_tier
## の戻り値) / scripts/runes.gd (Runes.roll_rune の戻り値) を正とする。ここで再定義しない。

const DECK_LIMIT := 20  ## 1デッキの最大枚数
const COPY_LIMIT := 4  ## 同カードの最大所持枚数（デッキ内）
const MIN_RUN_DECK := 10  ## 潜航開始に必要な最低枚数（cardEvaluator.ts）
const DEFAULT_DECK_NAME := "デッキ1"
const SAVE_PATH := "user://cthulhu_spire_collection_v1.json"

## cards: {instance_id, base_card_id, origin("starter"|"loot")} の配列
## runes: {id, effect, value} の配列（Runes.roll_rune()の戻り値の形。フェーズB以降で投入）
## equipment: {uid, def_id, tier, power, socketed_runes, bonus_stats, obtained_floor, source}
##            の配列（Equipment.roll_equipment_at_tier()/roll_equipment()の戻り値の形）
var inventory: Dictionary = {
	"cards": [],
	"runes": [],
	"equipment": [],
}

var decks: Dictionary = {DEFAULT_DECK_NAME: {}}  ## デッキ名 -> {カードid: 枚数}
var active_deck: String = DEFAULT_DECK_NAME
var rune_registry: Dictionary = {}  ## ルーンid -> ルーンDictionary（装備に装着中でも参照可能に）
var pack_tickets: Dictionary = {}  ## アーキタイプ -> 所持枚数


func _ready() -> void:
	_load_collection()


func add_loot_card(base_card_id: String) -> bool:
	if not Cards.CARDS.has(base_card_id):
		return false
	inventory.cards.append({
		"instance_id": "ci_%s_%s" % [Time.get_ticks_usec(), randi()],
		"base_card_id": base_card_id,
		"origin": "loot",
	})
	_persist_collection()
	return true


func add_pack_ticket(ticket: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	pack_tickets[ticket] = max(0, int(pack_tickets.get(ticket, 0))) + amount
	_persist_collection()


func consume_pack_ticket(ticket: String) -> bool:
	var count := int(pack_tickets.get(ticket, 0))
	if count <= 0:
		return false
	pack_tickets[ticket] = count - 1
	_persist_collection()
	return true


func remove_cards(instance_ids: Array) -> void:
	if instance_ids.is_empty():
		return
	var remove_set := {}
	for id in instance_ids:
		remove_set[str(id)] = true
	inventory.cards = inventory.cards.filter(func(card): return not remove_set.has(str(card.get("instance_id", card.get("instanceId", "")))))
	_clamp_decks_to_inventory()
	_persist_collection()


func remove_equipment(uids: Array) -> void:
	if uids.is_empty():
		return
	var remove_set := {}
	for uid in uids:
		remove_set[str(uid)] = true
	inventory.equipment = inventory.equipment.filter(func(inst): return not remove_set.has(str(inst.get("uid", ""))))
	_persist_collection()


func _clamp_decks_to_inventory() -> void:
	var owned := {}
	for card in inventory.cards:
		var card_id := str(card.get("base_card_id", card.get("baseCardId", "")))
		owned[card_id] = int(owned.get(card_id, 0)) + 1
	for deck_name in decks.keys():
		var counts: Dictionary = decks[deck_name]
		var next := {}
		for card_id in counts.keys():
			var count := min(int(counts[card_id]), int(owned.get(card_id, 0)))
			if count > 0:
				next[card_id] = count
		decks[deck_name] = next


func _persist_collection() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"inventory": inventory,
		"decks": decks,
		"active_deck": active_deck,
		"rune_registry": rune_registry,
		"pack_tickets": pack_tickets,
	}))
	file.close()


func _load_collection() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var loaded_inventory = parsed.get("inventory", {})
	if typeof(loaded_inventory) == TYPE_DICTIONARY:
		for key in ["cards", "runes", "equipment"]:
			if typeof(loaded_inventory.get(key, [])) == TYPE_ARRAY:
				inventory[key] = loaded_inventory[key]
	var loaded_decks = parsed.get("decks", {})
	if typeof(loaded_decks) == TYPE_DICTIONARY and not loaded_decks.is_empty():
		decks = loaded_decks
	active_deck = str(parsed.get("active_deck", DEFAULT_DECK_NAME))
	if not decks.has(active_deck):
		active_deck = str(decks.keys()[0]) if not decks.is_empty() else DEFAULT_DECK_NAME
	var loaded_registry = parsed.get("rune_registry", {})
	rune_registry = loaded_registry if typeof(loaded_registry) == TYPE_DICTIONARY else {}
	var loaded_tickets = parsed.get("pack_tickets", {})
	pack_tickets = loaded_tickets if typeof(loaded_tickets) == TYPE_DICTIONARY else {}
	_clamp_decks_to_inventory()


## GameState.equipped[slot] に入れる装備インスタンスをこのインベントリから取得するヘルパー。
## equipItem()等が実装されるフェーズB以降で使用する（現状は他の2エージェントとの
## データ整合性のためのプレースホルダー）。
static func peek_equipment(inventory_equipment: Array, equipment_uid: String) -> Dictionary:
	for inst in inventory_equipment:
		if inst.get("uid", "") == equipment_uid:
			return inst
	return {}


## useCollectionStore.ts の peekRune() 相当。combat.gd から装備込みステータス計算時に参照される。
func peek_rune(id: String):
	return rune_registry.get(id, null)


## useCollectionStore.ts の addLootEquipment()。uidが既に存在する場合は何もしない。
func add_loot_equipment(equipment_inst: Dictionary) -> void:
	var equip_uid: String = equipment_inst.get("uid", "")
	for inst in inventory.equipment:
		if inst.get("uid", "") == equip_uid:
			return
	inventory.equipment.append(equipment_inst)
	_persist_collection()


## useCollectionStore.ts の addLootRune()。インベントリとレジストリの両方に追加する
## （装着中のルーンもrune_registry経由で参照できるようにするため）。
func add_loot_rune(rune: Dictionary) -> void:
	inventory.runes.append(rune)
	rune_registry[rune.get("id", "")] = rune
	_persist_collection()


## useCollectionStore.ts の socketRuneToEquipment()。
## 成功したらtrueを返し、ルーンはinventory.runesから外れてsocket内に移る
## （rune_registryには残るため、peek_rune()による戦闘中の参照は引き続き可能）。
func socket_rune_to_equipment(equipment_uid: String, rune_id: String, socket_index: int) -> bool:
	var gear_idx := -1
	for i in range(inventory.equipment.size()):
		if inventory.equipment[i].get("uid", "") == equipment_uid:
			gear_idx = i
			break
	if gear_idx == -1:
		return false
	var rune_idx := -1
	for i in range(inventory.runes.size()):
		if inventory.runes[i].get("id", "") == rune_id:
			rune_idx = i
			break
	if rune_idx == -1:
		return false

	var gear: Dictionary = inventory.equipment[gear_idx]
	var sockets: Array = gear.get("socketed_runes", [])
	if socket_index < 0 or socket_index >= sockets.size():
		return false
	if sockets[socket_index] != null:
		return false

	var rune: Dictionary = inventory.runes[rune_idx]
	sockets[socket_index] = rune_id
	gear.socketed_runes = sockets
	inventory.runes.remove_at(rune_idx)
	rune_registry[rune_id] = rune
	_persist_collection()
	return true


## useCollectionStore.ts の unsocketRuneFromEquipment()。
## rune_registryに元のルーン情報が残っていればそれを、無ければBLK+/2のダミーを復元する
## （実ソースの `?? { id, effect: "BLK+", value: 2 }` フォールバック相当）。
func unsocket_rune_from_equipment(equipment_uid: String, socket_index: int) -> bool:
	var gear_idx := -1
	for i in range(inventory.equipment.size()):
		if inventory.equipment[i].get("uid", "") == equipment_uid:
			gear_idx = i
			break
	if gear_idx == -1:
		return false

	var gear: Dictionary = inventory.equipment[gear_idx]
	var sockets: Array = gear.get("socketed_runes", [])
	if socket_index < 0 or socket_index >= sockets.size():
		return false
	var rune_id = sockets[socket_index]
	if rune_id == null:
		return false

	sockets[socket_index] = null
	gear.socketed_runes = sockets
	var restored: Dictionary = rune_registry.get(rune_id, {"id": rune_id, "effect": "BLK+", "value": 2})
	inventory.runes.append(restored)
	rune_registry[rune_id] = restored
	_persist_collection()
	return true
