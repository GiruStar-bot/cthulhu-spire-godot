extends Node

## カード・ルーン・装備・デッキの実体（実ソース src/store/useCollectionStore.ts 相当）。
## GameState（ラン中の状態＋プロフィール、game/store.ts 相当）とは別の永続化層。混同しないこと。
##
## 参照: reference/cthulhu-spire-main/src/store/useCollectionStore.ts

const DECK_LIMIT := 20  ## 1デッキの最大枚数
const COPY_LIMIT := 4  ## 同カードの最大所持枚数（デッキ内）
const MIN_RUN_DECK := 10  ## 潜航開始に必要な最低枚数（cardEvaluator.ts）
const DEFAULT_DECK_NAME := "デッキ1"

## cards: {instance_id, base_card_id, origin("starter"|"loot")} の配列
## runes: {id, effect, value} の配列
## equipment: EquipmentInstance相当のDictionaryの配列
var inventory: Dictionary = {
	"cards": [],
	"runes": [],
	"equipment": [],
}

var decks: Dictionary = {DEFAULT_DECK_NAME: {}}  ## デッキ名 -> {カードid: 枚数}
var active_deck: String = DEFAULT_DECK_NAME
var rune_registry: Dictionary = {}  ## ルーンid -> ルーンDictionary（装備に装着中でも参照可能に）
var pack_tickets: Dictionary = {}  ## アーキタイプ -> 所持枚数
