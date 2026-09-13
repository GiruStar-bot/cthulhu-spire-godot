class_name Equipment
extends RefCounted

## combat.ts が import する equipment.ts の計算関数のみ忠実移植。
## EQUIPMENT カタログ本体は equipment.ts の移植待ち。未登録ならその部位は加算しない。

const MIN_CHIP_DAMAGE := 1
const EQUIPMENT_SLOTS := ["head", "chest", "arms", "legs", "feet"]
const EQUIPMENT := {}


static func _round(n: float) -> int:
	return int(round(n))


## equipment.ts applyFlatDefense()
static func apply_flat_defense(damage: int, defense: float) -> int:
	if damage <= 0:
		return damage
	var reduced: float = float(damage) - defense
	return maxi(MIN_CHIP_DAMAGE, _round(reduced))


## equipment.ts applyFlatResist()
static func apply_flat_resist(amount: int, resist: float) -> int:
	if amount <= 0:
		return amount
	return maxi(0, _round(float(amount) - resist))


## equipment.ts hasFullSet()
static func has_full_set(equipped: Dictionary, archetype: String) -> bool:
	for slot in EQUIPMENT_SLOTS:
		var inst = equipped.get(slot)
		if inst == null:
			return false
		var def = EQUIPMENT.get(str(inst.get("defId", "")), null)
		if def == null or def.get("archetype") != archetype:
			return false
	return true


## equipment.ts computeEquipmentStats()
static func compute_equipment_stats(equipped: Dictionary, peek_rune: Callable) -> Dictionary:
	var stats := {
		"defense": 0.0,
		"sanResist": 0.0,
		"poisonResist": 0.0,
		"poisonImmune": false,
		"blockRetain": false,
		"sanFullRestoreOnStart": false,
		"expandedHand": false,
		"hpPercentHealOnStart": false,
		"sacrificeEnergyOnStart": false,
		"intangibleOnHit": false,
		"strength": 0.0,
		"drawBonus": 0.0,
		"healPerTurn": 0.0,
		"healBonusPct": 0.0,
		"sanHealOnStart": 0.0,
		"vulnOnStart": 0.0,
		"energyPerTurn": 0.0,
		"thornDamage": 0.0,
	}
	for inst in equipped.values():
		if inst == null:
			continue
		var def = EQUIPMENT.get(str(inst.get("defId", "")), null)
		if def == null:
			continue
		var power: float = float(inst.get("power", 1))
		stats.defense += float(def.get("baseDefense", 0)) * power
		stats.sanResist += float(def.get("baseSanResist", 0)) * power
		stats.poisonResist += float(def.get("basePoisonResist", 0)) * power
		stats.strength += float(def.get("baseStrength", 0)) * power
		stats.drawBonus += float(def.get("baseDraw", 0)) * power
		stats.healPerTurn += float(def.get("baseHeal", 0)) * power
		stats.thornDamage += float(def.get("baseThorn", 0)) * power
		var bonus: Dictionary = inst.get("bonusStats", {})
		if bonus.get("strength"):
			stats.strength += float(bonus.strength)
		if bonus.get("defense"):
			stats.defense += float(bonus.defense)
		if bonus.get("poisonResist"):
			stats.poisonResist += float(bonus.poisonResist)
		if bonus.get("sanResist"):
			stats.sanResist += float(bonus.sanResist)
		for rune_id in inst.get("socketedRunes", []):
			if not rune_id:
				continue
			var rune = peek_rune.call(str(rune_id))
			if rune == null:
				continue
			match str(rune.get("effect", "")):
				"BLK+":
					stats.defense += float(rune.value)
					stats.strength += 1
				"SAN+":
					stats.sanResist += float(rune.value)
					stats.sanHealOnStart += 2
				"POISON":
					stats.poisonResist += float(rune.value)
					stats.healPerTurn += 1
				"STR+":
					stats.strength += float(rune.value)
					stats.defense += 1
				"DRAW":
					stats.drawBonus += float(rune.value)
					stats.vulnOnStart += 1
				"HEAL":
					stats.healPerTurn += float(rune.value)
					stats.poisonResist += 1
				"VULN+":
					stats.vulnOnStart += float(rune.value)
					stats.strength += 1
				"ENERGY+":
					stats.energyPerTurn += float(rune.value)
					stats.drawBonus += 1
				"THORN":
					stats.thornDamage += float(rune.value)
					stats.defense += 1
	stats.defense = _round(stats.defense)
	stats.sanResist = _round(stats.sanResist)
	stats.poisonResist = _round(stats.poisonResist)
	stats.strength = _round(stats.strength)
	stats.drawBonus = _round(stats.drawBonus)
	stats.healPerTurn = _round(stats.healPerTurn)
	stats.sanHealOnStart = _round(stats.sanHealOnStart)
	stats.vulnOnStart = _round(stats.vulnOnStart)
	stats.energyPerTurn = _round(stats.energyPerTurn)
	stats.thornDamage = _round(stats.thornDamage)
	if has_full_set(equipped, "poison"):
		stats.poisonImmune = true
		stats.healBonusPct = 50
	if has_full_set(equipped, "knight"):
		stats.blockRetain = true
	if has_full_set(equipped, "outer"):
		stats.sanFullRestoreOnStart = true
	if has_full_set(equipped, "elder"):
		stats.expandedHand = true
	if has_full_set(equipped, "deep"):
		stats.hpPercentHealOnStart = true
	if has_full_set(equipped, "offering"):
		stats.sacrificeEnergyOnStart = true
	if has_full_set(equipped, "shadow"):
		stats.intangibleOnHit = true
	return stats
