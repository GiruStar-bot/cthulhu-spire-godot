class_name Runes
extends RefCounted

## src/game/runes.ts 相当。
## 注意：引き継ぎ資料(PROJECT_HANDOFF_v2.md 3-4-8)は「現存6種」と記載しているが、
## 実ソース(runes.ts)には9種類（VULN+/ENERGY+/THORNを含む）が定義されている。
## ドキュメントより実コードを正とする方針に従い、9種全てを移植する。
##
## 参照: reference/cthulhu-spire-main/src/game/runes.ts

const RUNE_ART_FILES := {
	"BLK+": "blk.png",
	"DRAW": "draw.png",
	"SAN+": "san.png",
	"STR+": "str.png",
	"POISON": "poison.png",
	"HEAL": "heal.png",
	"VULN+": "vuln.png",
	"ENERGY+": "energy.png",
	"THORN": "thorn.png",
}

## effect -> base value（RUNE_CATALOGのvalue相当。IDは個体ごとにロール時採番）
const RUNE_CATALOG := {
	"BLK+": 2,
	"DRAW": 1,
	"SAN+": 3,
	"STR+": 1,
	"POISON": 2,
	"HEAL": 4,
	"VULN+": 1,
	"ENERGY+": 1,
	"THORN": 2,
}


## runes.ts の runeArt()
static func rune_art(effect: String) -> String:
	if not RUNE_ART_FILES.has(effect):
		return ""
	return "res://art/pixel/runes/%s" % RUNE_ART_FILES[effect]


## runes.ts の rollRune()
static func roll_rune(effect: String, floor: int, rng: Mulberry32) -> Dictionary:
	var base: int = RUNE_CATALOG.get(effect, 1)
	var tier := Equipment.tier_from_floor(floor)
	var scaled: float = base + int(tier / 2.0)
	var roll: float = 1.0 + (rng.next_float() * 2.0 - 1.0) * 0.25
	var value: int = max(1, int(round(scaled * roll)))
	if effect == "ENERGY+":
		value = min(2, value)
	return {"id": "rn_%s_%s" % [str(Time.get_ticks_usec()), str(randi())], "effect": effect, "value": value}
