class_name Smith
extends RefCounted

## 【廃止・未使用】鍛冶屋は今回の更新で無効化した。このファイルの関数はどこからも呼ばない。
## 品揃え生成と売却価格の式は、将来別の形で再設計するまで残すデッドコード。
## 拠点の売却価格は GameState.card_sell_price / equipment_sell_price / rune_sell_price。
## 酒場（Rest の inn）は対象外。
##
## 元は src/game/smith.ts。SHOP_CARDS は cards.gd にマージ済みのため、ここは品揃え生成だけ。
## 参照: reference/cthulhu-spire-main/src/game/smith.ts

const SHOP_POOL := {
	"sword": {
		"normal": ["iron_sword", "iron_axe", "knife"],
		"mid": ["ritual_dagger", "ghoul_claw"],
		"genius": ["deep_spear", "star_sword"],
		"god": ["spawn_blade", "cthugha_blade"],
		"taboo": ["nyar_fake", "azathoth_end"],
	},
	"bow": {
		"normal": ["short_bow", "hunter_bow", "crossbow"],
		"mid": ["bone_bow", "fanatic_dart"],
		"genius": ["migo_gun", "elder_staff"],
		"god": ["wind_gods_bow", "blackwood_bow"],
		"taboo": ["hunter_shot", "yog_gun"],
	},
	"heavy": {
		"normal": ["iron_shield", "tower_shield", "chain_mail"],
		"mid": ["deep_scale", "shoggoth_plate"],
		"genius": ["yith_shell", "dagon_shield"],
		"god": ["cthulhu_mail", "tsathoggua_shield"],
		"taboo": ["yog_gate", "plateau_mail"],
	},
	"light": {
		"normal": ["buckler", "leather", "thief_cloak"],
		"mid": ["ghoul_rags", "gaki_hide"],
		"genius": ["yith_coat", "penguin_fur"],
		"god": ["yellow_rags", "nameless_veil"],
		"taboo": ["azathoth_nap", "colour_robe"],
	},
}

const SHOP_PRICE := {
	"iron_sword": 8, "iron_axe": 10, "knife": 3, "ritual_dagger": 15, "ghoul_claw": 12,
	"deep_spear": 25, "star_sword": 32, "spawn_blade": 80, "cthugha_blade": 75,
	"nyar_fake": 130, "azathoth_end": 999,
	"short_bow": 3, "hunter_bow": 8, "crossbow": 11, "bone_bow": 16, "fanatic_dart": 14,
	"migo_gun": 35, "elder_staff": 28, "wind_gods_bow": 75, "blackwood_bow": 65,
	"hunter_shot": 150, "yog_gun": 140,
	"iron_shield": 8, "tower_shield": 12, "chain_mail": 7, "deep_scale": 18, "shoggoth_plate": 15,
	"yith_shell": 35, "dagon_shield": 40, "cthulhu_mail": 80, "tsathoggua_shield": 70,
	"yog_gate": 150, "plateau_mail": 145,
	"buckler": 4, "leather": 7, "thief_cloak": 10, "ghoul_rags": 12, "gaki_hide": 14,
	"yith_coat": 30, "penguin_fur": 28, "yellow_rags": 75, "nameless_veil": 80,
	"azathoth_nap": 120, "colour_robe": 140,
	"beer": 5,
}

const SLOTS := {
	"normal": [["normal"], ["normal"], ["normal"], ["normal"], ["normal"], ["normal", "normal", "normal", "normal", "mid"]],
	"mid": [["normal"], ["normal"], ["mid"], ["mid"], ["mid"], ["mid", "mid", "mid", "mid", "genius"]],
	"genius": [["normal", "mid"], ["normal", "mid"], ["genius"], ["genius"], ["genius"], ["genius", "genius", "genius", "genius", "god"]],
	"god": [["mid"], ["mid"], ["genius"], ["genius"], ["god"], ["god", "god", "god", "god", "taboo"]],
	"taboo": [["genius"], ["genius"], ["god"], ["god"], ["taboo"], ["taboo"]],
}

const RANK_LABELS := {"normal": "普通", "mid": "中級", "genius": "天才", "god": "神", "taboo": "禁忌"}


## smith.ts の rollShopRank()
static func roll_shop_rank(rng: Mulberry32) -> String:
	var r := rng.next_float()
	if r < 0.002:
		return "taboo"
	if r < 0.032:
		return "god"
	if r < 0.182:
		return "genius"
	if r < 0.382:
		return "mid"
	return "normal"


## smith.ts の makeSmith()
static func make_smith(rng: Mulberry32) -> Dictionary:
	var weapon := rng.next_float() < 0.5
	var kind: String
	if weapon:
		kind = "sword" if rng.next_float() < 0.5 else "bow"
	else:
		kind = "heavy" if rng.next_float() < 0.5 else "light"
	var rank := roll_shop_rank(rng)
	var taboo := rank == "taboo"

	var rank_slots: Array = SLOTS[rank]
	var goods: Array = []
	for opts in rank_slots:
		var slot_options: Array = opts
		var slot_rank: String = str(Mulberry32.pick(slot_options, rng))
		var pool: Array = SHOP_POOL[kind][slot_rank]
		var def_id: String = str(Mulberry32.pick(pool, rng))
		goods.append({
			"uid": Mulberry32.uid("g"),
			"def_id": def_id,
			"price": 0 if taboo else int(SHOP_PRICE.get(def_id, 8)),
			"sold": false,
		})

	return {
		"rank": rank,
		"kind": kind,
		"taboo": taboo,
		"goods": goods,
	}


## smith.ts の rankLabel()
static func rank_label(rank: String) -> String:
	return str(RANK_LABELS.get(rank, rank))


## smith.ts の shopLabel()
static func shop_label() -> String:
	return "鍛冶屋"


const CARD_SELL_PRICE := {"common": 5, "uncommon": 10, "rare": 20}


## smith.ts の cardSellPrice()
static func card_sell_price(card_def: Dictionary) -> int:
	return int(CARD_SELL_PRICE.get(str(card_def.get("rarity", "")), 0))


