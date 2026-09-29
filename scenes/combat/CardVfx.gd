class_name CardVfx
extends RefCounted

## カードの vfx キーを「どの型で描くか」と「当たるまで数字と被弾SEを待つか」に解決する。
## cards.gd に書くのはカード固有のキー（tentacle_ground / fireball）。型の名前はここだけ。
## 表に無いキーは何も出さない（スキルに vfx が付いても、敵の中心へ衝撃は出ない）。
##
## 段階:
##  1. この表と、Combat の着弾待ちを1つの入口にする（今ここ）
##  2. sky_fall / thrust / stamp は光の柱・三叉の矛・ねこの手で接続済み
##  3. sweep / ring_wave と、残りの優先度A
##  4. 自分側（self_*）。手札とHUDに出す
##  5. 敵カードは同じ型を反転
##  6. 優先度B・C
## 光の柱は届いた敵から数字を外す。sweep も同じ入口を使う。

const PROFILES := {
	"impact": {
		"family": "impact",
		"delay": false,
	},
	"slash": {
		"family": "slash",
		"delay": false,
	},
	"arrow": {
		"family": "arrow",
		"delay": false,
	},
	"tentacle_ground": {
		"family": "ground_rise",
		"delay": true,
		"timeout": 1.2,
		"hit_sfx": "vfx_impact",
	},
	"fireball": {
		"family": "projectile",
		"delay": true,
		"timeout": 0.7,
		"hit_sfx": "vfx_impact",
	},
	"light_pillar": {
		"family": "sky_fall",
		"delay": true,
		"timeout": 1.1,
		"hit_sfx": "vfx_impact",
	},
	"trident": {
		"family": "thrust",
		"delay": true,
		"timeout": 1.0,
		"hit_sfx": "vfx_impact",
	},
	"cats_paw": {
		"family": "stamp",
		"delay": true,
		"timeout": 0.8,
		"hit_sfx": "cat_hiss",
	},
	"whirlwind_px": {"family": "whirlwind_px", "delay": true, "timeout": 1.2, "hit_sfx": "vfx_impact"},
	"wind_arrow_px": {"family": "wind_arrow_px", "delay": true, "timeout": 1.0, "hit_sfx": "vfx_arrow"},
	"muramasa_px": {"family": "muramasa_px", "delay": true, "timeout": 1.0, "hit_sfx": "vfx_slash"},
	"cold_flame_px": {"family": "cold_flame_px", "delay": true, "timeout": 1.0, "hit_sfx": "vfx_impact"},
	"earthquake_px": {"family": "earthquake_px", "delay": true, "timeout": 1.2, "hit_sfx": "vfx_impact"},
	"charge_px": {"family": "charge_px", "delay": true, "timeout": 1.0, "hit_sfx": "vfx_impact"},
	"thecall_px": {"family": "thecall_px", "delay": true, "timeout": 1.2, "hit_sfx": "vfx_impact"},
	"collapse_px": {"family": "collapse_px", "delay": true, "timeout": 1.0, "hit_sfx": "vfx_impact"},
	"ultimate_px": {"family": "ultimate_px", "delay": true, "timeout": 1.2, "hit_sfx": "vfx_impact"},
}

## cards.gd の汎用キーを変えず、戦闘演出だけカード固有のシートへ差し替える。
const CARD_KEYS := {
	"whirlwind": "whirlwind_px",
	"whirlwind_free": "whirlwind_px",
	"wind_gods_bow": "wind_arrow_px",
	"muramasa": "muramasa_px",
	"cold_flame": "cold_flame_px",
	"earthquake": "earthquake_px",
	"charge": "charge_px",
	"thecall": "thecall_px",
	"collapse": "collapse_px",
	"ultimate_arcane": "ultimate_px",
}

const SEQUENCE_FAMILIES := {
	"whirlwind_px": true,
	"wind_arrow_px": true,
	"muramasa_px": true,
	"cold_flame_px": true,
	"earthquake_px": true,
	"charge_px": true,
	"thecall_px": true,
	"collapse_px": true,
	"ultimate_px": true,
}

## 自分に向かう型。敵座標は要らない。描画は段階4。
const SELF_FAMILIES := {
	"self_guard": true,
	"self_heal": true,
	"self_power": true,
	"turn_aura": true,
	"seek": true,
	"draw_burst": true,
	"summon": true,
	"energy": true,
	"sacrifice": true,
}


static func profile(vfx_key: String) -> Dictionary:
	var raw: Variant = PROFILES.get(vfx_key, null)
	if raw is Dictionary:
		return raw
	return {}


static func key_for_card(def_id: String, declared_key: String) -> String:
	return str(CARD_KEYS.get(def_id, declared_key))


static func is_sequence_family(family_name: String) -> bool:
	return SEQUENCE_FAMILIES.has(family_name)


static func family(vfx_key: String) -> String:
	var row: Dictionary = profile(vfx_key)
	if row.is_empty():
		return ""
	return str(row.get("family", ""))


static func delays_hit(vfx_key: String) -> bool:
	var row: Dictionary = profile(vfx_key)
	return row.get("delay", false) == true


static func timeout_sec(vfx_key: String) -> float:
	var row: Dictionary = profile(vfx_key)
	return float(row.get("timeout", 1.2))


static func hit_sfx(vfx_key: String) -> String:
	var row: Dictionary = profile(vfx_key)
	return str(row.get("hit_sfx", ""))


static func is_self_family(family_name: String) -> bool:
	return SELF_FAMILIES.has(family_name)
