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
