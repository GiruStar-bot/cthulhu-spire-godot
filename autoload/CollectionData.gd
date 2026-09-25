extends Node

## カード・デッキの実体（実ソース src/store/useCollectionStore.ts 相当）。
## GameState（ラン中の状態＋プロフィール、game/store.ts 相当）とは別の永続化層。混同しないこと。
##
## 参照: reference/cthulhu-spire-main/src/store/useCollectionStore.ts

const DECK_LIMIT := 20  ## 1デッキの最大枚数
const COPY_LIMIT := 3  ## 同一カードを1デッキに入れられる上限
const MIN_RUN_DECK := 10  ## 潜航開始に必要な最低枚数（cardEvaluator.ts）
const DEFAULT_DECK_NAME := "デッキ1"

## cards: {instance_id, base_card_id, origin("starter"|"loot")} の配列
var inventory: Dictionary = {
	"cards": [],
}

var decks: Dictionary = {DEFAULT_DECK_NAME: {}}  ## デッキ名 -> {カードid: 枚数}
var active_deck: String = DEFAULT_DECK_NAME
var pack_tickets: Dictionary = {}  ## アーキタイプ -> 所持枚数

## 初期デッキは廃止。新規プロフィールだけ初期チケットを配る。
## セーブに collection_saved があれば起動時は復元し、ここでは作り直さない。
const INITIAL_PACK_TICKETS := 10

## packTickets.ts PACK_TICKET_ARCHETYPES / PACK_TICKET_LABELS
## 毒・狂信・供物・影のパックは凍結のあと削除した。
## 風・火は旧支配者パック、地（豊穣）は外宇宙パックの強制枠から出る。魔導に専用パックは無い。
const PACK_TICKET_ARCHETYPES := [
	"knight", "outer", "elder", "water", "greatold", "all",
]

const PACK_TICKET_LABELS := {
	"knight": "騎士",
	"outer": "外宇宙",
	"elder": "旧神",
	"water": "水",
	"greatold": "大いなるもの",
	"all": "全",
}

## リリース前のデバッグ用。全カードを所持して編成検証できるようにする。
const DEBUG_OWN_ALL_CARDS := true

## セーブから復元済みなら _ready は初期化しない。GameState._load_profile が先に立てる。
var restored_from_profile: bool = false
var profile_seeded: bool = false


## 新規プロフィール、またはコレクションを持たない旧セーブの初期状態。
func seed_new_profile() -> void:
	restored_from_profile = false
	inventory = {"cards": []}
	decks = {DEFAULT_DECK_NAME: {}}
	active_deck = DEFAULT_DECK_NAME
	pack_tickets = {}
	_seed_initial_pack_tickets()
	if DEBUG_OWN_ALL_CARDS:
		_grant_all_cards_for_debug()
		pack_tickets["all"] = maxi(int(pack_tickets.get("all", 0)), 3)
	profile_seeded = true


func _ready() -> void:
	if restored_from_profile:
		profile_seeded = true
		return
	seed_new_profile()
	GameState._persist_profile()


func export_save() -> Dictionary:
	return {
		"decks": decks.duplicate(true),
		"active_deck": active_deck,
		"inventory": inventory.duplicate(true),
		"pack_tickets": pack_tickets.duplicate(true),
	}


## 旧セーブはキーが無い。欠損は空として扱い、呼び出し側が新規初期化を選ぶ。
func apply_save(data: Dictionary) -> void:
	var saved_decks: Dictionary = {}
	var raw_decks = data.get("decks", {})
	if typeof(raw_decks) == TYPE_DICTIONARY:
		saved_decks = raw_decks
	decks = {}
	for deck_name in saved_decks.keys():
		var clean: Dictionary = {}
		var raw_counts = saved_decks[deck_name]
		if typeof(raw_counts) == TYPE_DICTIONARY:
			for card_id in raw_counts.keys():
				clean[str(card_id)] = int(raw_counts[card_id])
		decks[str(deck_name)] = clean
	if decks.is_empty():
		decks[DEFAULT_DECK_NAME] = {}
	var saved_active: String = str(data.get("active_deck", DEFAULT_DECK_NAME))
	if decks.has(saved_active):
		active_deck = saved_active
	else:
		active_deck = str(decks.keys()[0])

	var inv: Dictionary = {}
	var raw_inv = data.get("inventory", {})
	if typeof(raw_inv) == TYPE_DICTIONARY:
		inv = raw_inv
	var cards = inv.get("cards", [])
	inventory = {
		"cards": cards if typeof(cards) == TYPE_ARRAY else [],
	}

	pack_tickets = {}
	var raw_tickets = data.get("pack_tickets", {})
	if typeof(raw_tickets) == TYPE_DICTIONARY:
		for key in raw_tickets.keys():
			pack_tickets[str(key)] = int(raw_tickets[key])
	if pack_tickets.has("deep"):
		pack_tickets["water"] = int(pack_tickets.get("water", 0)) + int(pack_tickets["deep"])
		pack_tickets.erase("deep")

	_drop_unknown_cards()
	restored_from_profile = true
	profile_seeded = true


## 削除済みカード（バックラー等）がセーブに残っていても、所持とデッキから外して落とす。
func _drop_unknown_cards() -> void:
	for deck_name in decks.keys():
		var counts: Dictionary = decks[deck_name]
		if typeof(counts) != TYPE_DICTIONARY:
			decks[deck_name] = {}
			continue
		var clean: Dictionary = {}
		for card_id in counts.keys():
			var id: String = str(card_id)
			if Cards.CARDS.has(id):
				clean[id] = int(counts[card_id])
		decks[deck_name] = clean
	var kept: Array = []
	for c in inventory.get("cards", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var base_id: String = str(c.get("base_card_id", ""))
		if Cards.CARDS.has(base_id):
			kept.append(c)
	inventory["cards"] = kept


## 有効な属性パックを初期枚数だけ配る。全パックは対象外。
func _seed_initial_pack_tickets() -> void:
	for archetype in PACK_TICKET_ARCHETYPES:
		var key: String = str(archetype)
		if key == "all":
			continue
		pack_tickets[key] = INITIAL_PACK_TICKETS


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
	return loadout_error_for(deck)


static func loadout_error_for(deck: Dictionary) -> String:
	var n := deck_size(deck)
	if n <= 0:
		return "デッキが空です。パックを開いてデッキを組んでください。"
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


func consume_pack_ticket(ticket: String) -> bool:
	var n := int(pack_tickets.get(ticket, 0))
	if n <= 0: return false
	pack_tickets[ticket] = n - 1
	return true


func add_pack_ticket(ticket: String) -> void:
	pack_tickets[ticket] = int(pack_tickets.get(ticket, 0)) + 1


static func pack_ticket_art(ticket: String) -> String:
	return "res://art/pixel/tickets/ticket_%s.png" % ticket


func _grant_all_cards_for_debug() -> void:
	var owned := {}
	for c in inventory.cards:
		owned[str(c.get("base_card_id", ""))] = true
	for card_id in Cards.CARDS.keys():
		var d: Dictionary = Cards.CARDS[card_id]
		## HUBに出さないカード：状態異常（type）と入手不可（unobtainable）。rarity には頼らない。
		if d.get("type") == "status" or d.get("unobtainable", false):
			continue
		if owned.get(card_id, false):
			continue
		for i in COPY_LIMIT:
			inventory.cards.append({
				"instance_id": "ci_dbg_%s_%d" % [str(card_id), i],
				"base_card_id": card_id,
				"origin": "debug",
			})
