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

## useCollectionStore.ts の STARTER_CARDS（起動時に一度だけ所持カードへ投入する）
const STARTER_CARDS := [
	{"id": "strike", "count": 4},
	{"id": "ward", "count": 4},
	{"id": "study", "count": 2},
	{"id": "whisper", "count": 2},
	{"id": "insight", "count": 2},
	{"id": "lash", "count": 2},
	{"id": "dressing", "count": 2},
	{"id": "sweep", "count": 2},
]

## リリース前のデバッグ用。全カードを所持して編成検証できるようにする。
const DEBUG_OWN_ALL_CARDS := true

## packTickets.ts PACK_TICKET_ARCHETYPES / PACK_TICKET_LABELS
const PACK_TICKET_ARCHETYPES := [
	"fanatic", "knight", "poison", "outer", "elder", "deep", "offering", "shadow", "greatold", "all",
]

const PACK_TICKET_LABELS := {
	"fanatic": "狂信",
	"knight": "騎士",
	"poison": "毒",
	"outer": "外宇宙",
	"elder": "旧神",
	"deep": "深き者",
	"offering": "供物",
	"shadow": "影",
	"greatold": "大いなるもの",
	"all": "全",
}

## useCollectionStore.ts STARTER_DECKS（最初の一度きりの4流派）
const STARTER_ARCHETYPES := ["fanatic", "knight", "poison", "deep"]

const STARTER_DECKS := {
	"fanatic": [
		{"id": "strike", "count": 4},
		{"id": "ward", "count": 2},
		{"id": "study", "count": 2},
		{"id": "whisper", "count": 2},
		{"id": "precise", "count": 2},
		{"id": "offering", "count": 4},
		{"id": "rite", "count": 2},
		{"id": "tome", "count": 1},
		{"id": "thecall", "count": 1},
	],
	"knight": [
		{"id": "ward", "count": 4},
		{"id": "sigil", "count": 4},
		{"id": "chant", "count": 4},
		{"id": "ironwill", "count": 4},
		{"id": "bash", "count": 2},
		{"id": "laststand", "count": 2},
	],
	"poison": [
		{"id": "strike", "count": 4},
		{"id": "ward", "count": 2},
		{"id": "study", "count": 2},
		{"id": "whisper", "count": 2},
		{"id": "precise", "count": 2},
		{"id": "lash", "count": 2},
		{"id": "corrosive_strike", "count": 4},
		{"id": "pus_mist", "count": 2},
	],
	"deep": [
		{"id": "strike", "count": 4},
		{"id": "ward", "count": 2},
		{"id": "study", "count": 2},
		{"id": "whisper", "count": 2},
		{"id": "sweep", "count": 4},
		{"id": "adapted_scales", "count": 4},
		{"id": "deep_breath", "count": 1},
		{"id": "deep_ones_blessing", "count": 1},
	],
}


## useCollectionStore.ts の seedInventory()。CollectionDataには永続化がまだ無いため
## （フェーズB以降で対応）、起動の度に毎回これで初期化する。
func _ready() -> void:
	var cards: Array = []
	for entry in STARTER_CARDS:
		for i in int(entry.count):
			cards.append({
				"instance_id": "ci_%s_%s" % [str(Time.get_ticks_usec()), str(randi())],
				"base_card_id": entry.id,
				"origin": "starter",
			})
	inventory.cards = cards
	if DEBUG_OWN_ALL_CARDS:
		_grant_all_cards_for_debug()
		pack_tickets["all"] = maxi(int(pack_tickets.get("all", 0)), 3)

	var runes: Array = []
	for effect in Runes.RUNE_CATALOG.keys():
		for i in range(2):
			var value: int = Runes.RUNE_CATALOG[effect]
			var rune := {"id": "rn_%s_%s" % [str(Time.get_ticks_usec()), str(randi())], "effect": effect, "value": value}
			runes.append(rune)
			rune_registry[rune.id] = rune
	inventory.runes = runes


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


# ============================================================
# デッキ管理（useCollectionStore.ts の createDeck/deleteDeck/renameDeck/
# setActiveDeck/addToDeck/removeFromDeck 相当）
# ============================================================

## useCollectionStore.ts の deckSize()
static func deck_size(deck: Dictionary) -> int:
	var total := 0
	for v in deck.values():
		total += int(v)
	return total


## useCollectionStore.ts の copiesOfBase()
static func copies_of_base(deck: Dictionary, base_card_id: String) -> int:
	return int(deck.get(base_card_id, 0))


## DeckBuilderScreen.tsx の nextDeckName()。「デッキN」の空いている番号を探す
## （DeckListScreen.tsx の「＋新規デッキ」が使う）。
static func next_deck_name(existing_decks: Dictionary) -> String:
	var n := existing_decks.size() + 1
	while existing_decks.has("デッキ%d" % n):
		n += 1
	return "デッキ%d" % n


## useCollectionStore.ts の createDeck()
func create_deck(deck_name: String) -> bool:
	var trimmed := deck_name.strip_edges()
	if trimmed.is_empty() or decks.has(trimmed):
		return false
	decks[trimmed] = {}
	active_deck = trimmed
	return true


## useCollectionStore.ts の deleteDeck()。デッキが1つしか無い場合は削除しない。
func delete_deck(deck_name: String) -> void:
	if decks.size() <= 1 or not decks.has(deck_name):
		return
	decks.erase(deck_name)
	if active_deck == deck_name:
		active_deck = decks.keys()[0]


## useCollectionStore.ts の renameDeck()
func rename_deck(old_name: String, new_name: String) -> bool:
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty() or decks.has(trimmed) or not decks.has(old_name):
		return false
	decks[trimmed] = decks[old_name]
	decks.erase(old_name)
	if active_deck == old_name:
		active_deck = trimmed
	return true


## useCollectionStore.ts の setActiveDeck()
func set_active_deck(deck_name: String) -> void:
	if decks.has(deck_name):
		active_deck = deck_name


## useCollectionStore.ts の addToDeck()。DECK_LIMIT/COPY_LIMIT/所持枚数のいずれかを
## 超える場合は失敗してfalseを返す。
func add_to_deck(card_id: String) -> bool:
	var deck: Dictionary = decks.get(active_deck, {})
	var total := deck_size(deck)
	var current := int(deck.get(card_id, 0))
	var owned := 0
	for c in inventory.cards:
		if c.get("base_card_id", "") == card_id:
			owned += 1
	if total >= DECK_LIMIT or current >= COPY_LIMIT or current >= owned:
		return false
	deck[card_id] = current + 1
	decks[active_deck] = deck
	return true


## useCollectionStore.ts の removeFromDeck()
func remove_from_deck(card_id: String) -> void:
	var deck: Dictionary = decks.get(active_deck, {})
	var current := int(deck.get(card_id, 0))
	if current <= 0:
		return
	if current - 1 <= 0:
		deck.erase(card_id)
	else:
		deck[card_id] = current - 1
	decks[active_deck] = deck


## cardEvaluator.ts の loadoutError()。問題なければ空文字を返す。
func loadout_error() -> String:
	var deck: Dictionary = decks.get(active_deck, {})
	var n := deck_size(deck)
	if n <= 0:
		return "デッキが空です。デッキ編成でカードを組んでください。"
	if n < MIN_RUN_DECK:
		return "デッキが%d枚未満です（現在 %d）。" % [MIN_RUN_DECK, n]
	return ""


## 所持カードをbase_card_idごとに集計する（デッキ編成タブの一覧表示用ヘルパー。
## useCollectionStore.tsには無いが、inventory.cardsの集計はUI側で毎回書くと
## 冗長なためここに置く）。
func owned_card_counts() -> Dictionary:
	var counts: Dictionary = {}
	for c in inventory.cards:
		var id: String = c.get("base_card_id", "")
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


## useCollectionStore.ts の addLootEquipment()。uidが既に存在する場合は何もしない。
func add_loot_equipment(equipment_inst: Dictionary) -> void:
	var equip_uid: String = equipment_inst.get("uid", "")
	for inst in inventory.equipment:
		if inst.get("uid", "") == equip_uid:
			return
	inventory.equipment.append(equipment_inst)


## useCollectionStore.ts の addLootRune()。インベントリとレジストリの両方に追加する
## （装着中のルーンもrune_registry経由で参照できるようにするため）。
func add_loot_rune(rune: Dictionary) -> void:
	inventory.runes.append(rune)
	rune_registry[rune.get("id", "")] = rune


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
	return true


func add_loot_card(card_id: String) -> bool:
	if not Cards.CARDS.has(card_id): return false
	inventory.cards.append({"instance_id": "ci_%s" % Time.get_ticks_usec(), "base_card_id": card_id, "origin": "loot"})
	return true

## useCollectionStore.ts の removeCards()。削除後、各デッキの所持数を新しい所持数へ
## クランプし直す（SellScreen.tsx側は売却可能数＝所持数-デッキ使用数しか売らせないため
## 通常は発生しないが、実ソース同様の安全策として移植する）。
func remove_cards(ids: Array) -> void:
	if ids.is_empty():
		return
	inventory.cards = inventory.cards.filter(func(c): return not ids.has(str(c.get("instance_id", ""))))
	var owned: Dictionary = {}
	for c in inventory.cards:
		var base_id: String = str(c.get("base_card_id", ""))
		owned[base_id] = int(owned.get(base_id, 0)) + 1
	for deck_name in decks.keys():
		var counts: Dictionary = decks[deck_name]
		var clamped_counts: Dictionary = {}
		for card_id in counts.keys():
			var clamped: int = min(int(counts[card_id]), int(owned.get(card_id, 0)))
			if clamped > 0:
				clamped_counts[card_id] = clamped
		decks[deck_name] = clamped_counts


func remove_equipment(ids: Array) -> void:
	inventory.equipment = inventory.equipment.filter(func(e): return not ids.has(str(e.get("uid", ""))))


## useCollectionStore.ts の removeRunes()
func remove_runes(ids: Array) -> void:
	inventory.runes = inventory.runes.filter(func(r): return not ids.has(str(r.get("id", ""))))

func consume_pack_ticket(ticket: String) -> bool:
	var n := int(pack_tickets.get(ticket, 0))
	if n <= 0: return false
	pack_tickets[ticket] = n - 1
	return true


func add_pack_ticket(ticket: String) -> void:
	pack_tickets[ticket] = int(pack_tickets.get(ticket, 0)) + 1


static func pack_ticket_art(ticket: String) -> String:
	return "res://art/pixel/tickets/ticket_%s.png" % ticket


## useCollectionStore.ts の chooseStarterDeck()。
## DEBUG_OWN_ALL_CARDS の間は所持カードを消さず、選択した4流派の構成だけデッキへ載せる。
func choose_starter_deck(archetype: String) -> void:
	if not STARTER_DECKS.has(archetype):
		return
	var list: Array = STARTER_DECKS[archetype]
	var counts: Dictionary = {}
	var starter_cards: Array = []
	for entry in list:
		var card_id: String = str(entry.get("id", ""))
		var n: int = int(entry.get("count", 0))
		if not Cards.CARDS.has(card_id) or n <= 0:
			continue
		counts[card_id] = n
		for i in n:
			starter_cards.append({
				"instance_id": "ci_%s_%s" % [str(Time.get_ticks_usec()), str(randi())],
				"base_card_id": card_id,
				"origin": "starter",
			})
	if not DEBUG_OWN_ALL_CARDS:
		inventory.cards = starter_cards
	decks[DEFAULT_DECK_NAME] = counts
	active_deck = DEFAULT_DECK_NAME


func _grant_all_cards_for_debug() -> void:
	var owned := {}
	for c in inventory.cards:
		owned[str(c.get("base_card_id", ""))] = true
	for card_id in Cards.CARDS.keys():
		var d: Dictionary = Cards.CARDS[card_id]
		if d.get("type") == "status" or d.get("rarity") == "status":
			continue
		if owned.get(card_id, false):
			continue
		for i in COPY_LIMIT:
			inventory.cards.append({
				"instance_id": "ci_dbg_%s_%d" % [str(card_id), i],
				"base_card_id": card_id,
				"origin": "debug",
			})
