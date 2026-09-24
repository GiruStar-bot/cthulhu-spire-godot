class_name Blessings
extends RefCounted

## 装備／ルーンの効果を、5階層ごとの3択バフへ変換する。
## 数値は Runes.RUNE_CATALOG と Equipment.compute_equipment_stats の
## ルーン副作用・セットボーナスをそのまま使う。発明しない。

const CATALOG := {
	"rune_blk": {
		"name": "防護の刻印",
		"text": "防御+2。筋力+1。",
		"rune": "BLK+",
	},
	"rune_draw": {
		"name": "予兆の刻印",
		"text": "基本ドロー+1。戦闘開始時、敵に弱体1。",
		"rune": "DRAW",
	},
	"rune_san": {
		"name": "正気の刻印",
		"text": "正気耐性+3。戦闘開始時、正気+2。",
		"rune": "SAN+",
	},
	"rune_str": {
		"name": "剛力の刻印",
		"text": "筋力+1。防御+1。",
		"rune": "STR+",
	},
	"rune_poison": {
		"name": "抗毒の刻印",
		"text": "毒耐性+2。ターン開始時、体力+1。",
		"rune": "POISON",
	},
	"rune_heal": {
		"name": "再生の刻印",
		"text": "ターン開始時、体力+4。毒耐性+1。",
		"rune": "HEAL",
	},
	"rune_vuln": {
		"name": "弱点の刻印",
		"text": "戦闘開始時、敵に弱体1。筋力+1。",
		"rune": "VULN+",
	},
	"rune_energy": {
		"name": "気力の刻印",
		"text": "毎ターンエネルギー+1。基本ドロー+1。",
		"rune": "ENERGY+",
	},
	"rune_thorn": {
		"name": "棘の刻印",
		"text": "棘+2。防御+1。",
		"rune": "THORN",
	},
	"set_knight": {
		"name": "巡礼の構え",
		"text": "ブロックがターンをまたいで残る。",
		"unique": true,
		"flag": "blockRetain",
	},
	"set_poison": {
		"name": "猛毒の血",
		"text": "毒を受けない。回復量+50%。",
		"unique": true,
		"flag": "poisonImmune",
	},
	"set_outer": {
		"name": "虚空の呼吸",
		"text": "戦闘開始時、正気を全回復する。",
		"unique": true,
		"flag": "sanFullRestoreOnStart",
	},
	"set_elder": {
		"name": "太古の手",
		"text": "手札の上限が広がる。",
		"unique": true,
		"flag": "expandedHand",
	},
	"set_deep": {
		"name": "深海の息",
		"text": "戦闘開始時、最大体力の10%を回復する。",
		"unique": true,
		"flag": "hpPercentHealOnStart",
	},
	"set_offering": {
		"name": "供物の契約",
		"text": "戦闘開始時、最大体力の10%を失い、エネルギー+1。",
		"unique": true,
		"flag": "sacrificeEnergyOnStart",
	},
	"set_shadow": {
		"name": "影の歩み",
		"text": "被弾時、一度だけ不可視になる。",
		"unique": true,
		"flag": "intangibleOnHit",
	},
	"bias_fanatic": {
		"name": "狂信の潮流",
		"text": "狂信の敵と遭遇しやすくなる。その属性のチケットが落ちやすい。",
		"bias": "fanatic",
	},
	"bias_knight": {
		"name": "騎士の潮流",
		"text": "騎士の敵と遭遇しやすくなる。その属性のチケットが落ちやすい。",
		"bias": "knight",
	},
	"bias_poison": {
		"name": "毒の潮流",
		"text": "毒の敵と遭遇しやすくなる。その属性のチケットが落ちやすい。",
		"bias": "poison",
	},
	"bias_outer": {
		"name": "外宇宙の潮流",
		"text": "外宇宙の敵と遭遇しやすくなる。その属性のチケットが落ちやすい。",
		"bias": "outer",
	},
	"bias_elder": {
		"name": "旧神の潮流",
		"text": "旧神のチケットが落ちやすい。",
		"bias": "elder",
	},
	"bias_deep": {
		"name": "深き者の潮流",
		"text": "深き者の敵と遭遇しやすくなる。その属性のチケットが落ちやすい。",
		"bias": "water",
	},
	"bias_offering": {
		"name": "供物の潮流",
		"text": "供物のチケットが落ちやすい。",
		"bias": "offering",
	},
	"bias_shadow": {
		"name": "影の潮流",
		"text": "影のチケットが落ちやすい。",
		"bias": "shadow",
	},
	"bias_greatold": {
		"name": "旧支配者の潮流",
		"text": "旧支配者のチケットが落ちやすい。",
		"bias": "greatold",
	},
}


static func empty_stats() -> Dictionary:
	return {
		"defense": 0.0, "sanResist": 0.0, "poisonResist": 0.0,
		"poisonImmune": false, "blockRetain": false, "sanFullRestoreOnStart": false,
		"expandedHand": false, "hpPercentHealOnStart": false, "sacrificeEnergyOnStart": false,
		"intangibleOnHit": false, "strength": 0.0, "drawBonus": 0.0, "healPerTurn": 0.0,
		"healBonusPct": 0, "sanHealOnStart": 0.0, "vulnOnStart": 0.0, "energyPerTurn": 0.0,
		"thornDamage": 0.0,
	}


static func get_def(blessing_id: String) -> Dictionary:
	return CATALOG.get(blessing_id, {})


static func _apply_rune(stats: Dictionary, effect: String) -> void:
	var value: int = int(Runes.RUNE_CATALOG.get(effect, 1))
	match effect:
		"BLK+":
			stats.defense += value
			stats.strength += 1
		"SAN+":
			stats.sanResist += value
			stats.sanHealOnStart += 2
		"POISON":
			stats.poisonResist += value
			stats.healPerTurn += 1
		"STR+":
			stats.strength += value
			stats.defense += 1
		"DRAW":
			stats.drawBonus += value
			stats.vulnOnStart += 1
		"HEAL":
			stats.healPerTurn += value
			stats.poisonResist += 1
		"VULN+":
			stats.vulnOnStart += value
			stats.strength += 1
		"ENERGY+":
			stats.energyPerTurn += value
			stats.drawBonus += 1
		"THORN":
			stats.thornDamage += value
			stats.defense += 1


static func compute_stats(owned: Array) -> Dictionary:
	var stats: Dictionary = empty_stats()
	for raw_id in owned:
		var blessing_id: String = str(raw_id)
		var def: Dictionary = CATALOG.get(blessing_id, {})
		if def.is_empty():
			continue
		var rune_effect: String = str(def.get("rune", ""))
		if rune_effect != "":
			_apply_rune(stats, rune_effect)
		var flag: String = str(def.get("flag", ""))
		if flag != "":
			stats[flag] = true
			if flag == "poisonImmune":
				stats.healBonusPct = 50
	stats.defense = round(stats.defense)
	stats.sanResist = round(stats.sanResist)
	stats.poisonResist = round(stats.poisonResist)
	stats.strength = round(stats.strength)
	stats.drawBonus = round(stats.drawBonus)
	stats.healPerTurn = round(stats.healPerTurn)
	stats.sanHealOnStart = round(stats.sanHealOnStart)
	stats.vulnOnStart = round(stats.vulnOnStart)
	stats.energyPerTurn = round(stats.energyPerTurn)
	stats.thornDamage = round(stats.thornDamage)
	return stats


static func available_ids(owned: Array) -> Array:
	var taken: Dictionary = {}
	for raw_id in owned:
		taken[str(raw_id)] = true
	var out: Array = []
	for blessing_id in CATALOG.keys():
		var def: Dictionary = CATALOG[blessing_id]
		if def.get("unique", false) and taken.has(blessing_id):
			continue
		out.append(blessing_id)
	return out


static func roll_choices(owned: Array, rng: Mulberry32, count: int = 3) -> Array:
	var pool: Array = available_ids(owned)
	var out: Array = []
	var n: int = mini(count, pool.size())
	for i in n:
		var idx: int = int(rng.next_float() * pool.size())
		idx = clampi(idx, 0, pool.size() - 1)
		out.append(str(pool[idx]))
		pool.remove_at(idx)
	return out
