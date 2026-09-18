class_name Equipment
extends RefCounted

## src/game/equipment.ts 相当。装備定義・ロール処理・装備込みステータス計算。
##
## 参照: reference/cthulhu-spire-main/src/game/equipment.ts

const EQUIPMENT_SLOTS := ["head", "chest", "arms", "legs", "feet"]
const MIN_CHIP_DAMAGE := 1

const ALL_BONUS_KEYS := ["strength", "defense", "poisonResist", "sanResist"]

const BONUS_STAT_BASE := {
	"strength": 1,
	"defense": 2,
	"poisonResist": 2,
	"sanResist": 2,
}

const TIER_BONUS_CONFIG := {
	1: {"range_pct": 0.15, "bonus_chance": 0.0, "second_bonus_chance": 0.0},
	2: {"range_pct": 0.2, "bonus_chance": 0.25, "second_bonus_chance": 0.0},
	3: {"range_pct": 0.25, "bonus_chance": 0.5, "second_bonus_chance": 0.0},
	4: {"range_pct": 0.3, "bonus_chance": 0.75, "second_bonus_chance": 0.25},
	5: {"range_pct": 0.35, "bonus_chance": 1.0, "second_bonus_chance": 0.5},
}

## id -> {name, slot, archetype, sockets, base_strength?, base_defense?,
##        base_poison_resist?, base_san_resist?, base_draw?, base_heal?, base_thorn?}
const EQUIPMENT := {
	"ragged_hood": {"name": "襤褸の頭巾", "slot": "head", "archetype": "generic", "sockets": 1, "base_defense": 3},
	"worn_coat": {"name": "着古した外套", "slot": "chest", "archetype": "generic", "sockets": 2, "base_defense": 5},
	"bandaged_arms": {"name": "包帯の腕", "slot": "arms", "archetype": "generic", "sockets": 1, "base_strength": 1},
	"patched_legs": {"name": "継ぎ接ぎの脚衣", "slot": "legs", "archetype": "generic", "sockets": 1, "base_san_resist": 3},
	"worn_boots": {"name": "履き古した靴", "slot": "feet", "archetype": "generic", "sockets": 1, "base_poison_resist": 3},
	"blood_veil": {"name": "血に濡れた眼帯", "slot": "head", "archetype": "fanatic", "sockets": 1, "base_strength": 2},
	"sacrifice_plate": {"name": "生贄の胸当て", "slot": "chest", "archetype": "fanatic", "sockets": 2, "base_strength": 2},
	"fanatic_bangle": {"name": "狂信の腕輪", "slot": "arms", "archetype": "fanatic", "sockets": 1, "base_strength": 2},
	"cursed_greaves": {"name": "呪われた脚甲", "slot": "legs", "archetype": "fanatic", "sockets": 1, "base_strength": 1},
	"bloodstained_boots": {"name": "血染めの靴", "slot": "feet", "archetype": "fanatic", "sockets": 1, "base_strength": 1},
	"pilgrim_helm": {"name": "巡礼の兜", "slot": "head", "archetype": "knight", "sockets": 1, "base_defense": 3},
	"pilgrim_mail": {"name": "巡礼の鎧", "slot": "chest", "archetype": "knight", "sockets": 2, "base_defense": 5},
	"pilgrim_gauntlets": {"name": "巡礼の篭手", "slot": "arms", "archetype": "knight", "sockets": 1, "base_defense": 3},
	"pilgrim_greaves": {"name": "巡礼の脚甲", "slot": "legs", "archetype": "knight", "sockets": 1, "base_defense": 3},
	"pilgrim_boots": {"name": "巡礼の靴", "slot": "feet", "archetype": "knight", "sockets": 1, "base_defense": 2},
	"venom_hood": {"name": "猛毒の頭巾", "slot": "head", "archetype": "poison", "sockets": 1, "base_poison_resist": 3},
	"venom_coat": {"name": "猛毒の外套", "slot": "chest", "archetype": "poison", "sockets": 2, "base_poison_resist": 4},
	"venom_bangle": {"name": "猛毒の腕輪", "slot": "arms", "archetype": "poison", "sockets": 1, "base_poison_resist": 3},
	"venom_leggings": {"name": "猛毒の脚衣", "slot": "legs", "archetype": "poison", "sockets": 1, "base_poison_resist": 3},
	"venom_boots": {"name": "猛毒の靴", "slot": "feet", "archetype": "poison", "sockets": 1, "base_poison_resist": 2},
	"void_helm": {"name": "虚空の兜", "slot": "head", "archetype": "outer", "sockets": 1, "base_san_resist": 3},
	"void_coat": {"name": "虚空の外套", "slot": "chest", "archetype": "outer", "sockets": 2, "base_san_resist": 4},
	"void_gauntlets": {"name": "虚空の篭手", "slot": "arms", "archetype": "outer", "sockets": 1, "base_san_resist": 3},
	"void_leggings": {"name": "虚空の脚衣", "slot": "legs", "archetype": "outer", "sockets": 1, "base_san_resist": 3},
	"void_boots": {"name": "虚空の靴", "slot": "feet", "archetype": "outer", "sockets": 1, "base_san_resist": 2},
	"ancient_helm": {"name": "太古の兜", "slot": "head", "archetype": "elder", "sockets": 1, "base_draw": 2},
	"ancient_robe": {"name": "太古の法衣", "slot": "chest", "archetype": "elder", "sockets": 2, "base_draw": 2},
	"ancient_vambrace": {"name": "太古の腕甲", "slot": "arms", "archetype": "elder", "sockets": 1, "base_draw": 2},
	"ancient_leggings": {"name": "太古の脚衣", "slot": "legs", "archetype": "elder", "sockets": 1, "base_draw": 1},
	"ancient_boots": {"name": "太古の靴", "slot": "feet", "archetype": "elder", "sockets": 1, "base_draw": 1},
	"abyssal_hood": {"name": "深海の頭巾", "slot": "head", "archetype": "deep", "sockets": 1, "base_heal": 2},
	"abyssal_coat": {"name": "深海の外套", "slot": "chest", "archetype": "deep", "sockets": 2, "base_heal": 3},
	"abyssal_bracers": {"name": "深海の腕当て", "slot": "arms", "archetype": "deep", "sockets": 1, "base_heal": 2},
	"abyssal_leggings": {"name": "深海の脚衣", "slot": "legs", "archetype": "deep", "sockets": 1, "base_heal": 2},
	"abyssal_boots": {"name": "深海の靴", "slot": "feet", "archetype": "deep", "sockets": 1, "base_heal": 1},
	"offering_headdress": {"name": "供物の頭飾り", "slot": "head", "archetype": "offering", "sockets": 1, "base_thorn": 2},
	"offering_vestment": {"name": "供物の法衣", "slot": "chest", "archetype": "offering", "sockets": 2, "base_thorn": 3},
	"offering_bangle": {"name": "供物の腕輪", "slot": "arms", "archetype": "offering", "sockets": 1, "base_thorn": 2},
	"offering_leggings": {"name": "供物の脚衣", "slot": "legs", "archetype": "offering", "sockets": 1, "base_thorn": 2},
	"offering_sandals": {"name": "供物の靴", "slot": "feet", "archetype": "offering", "sockets": 1, "base_thorn": 1},
	"umbral_hood": {"name": "闇の頭巾", "slot": "head", "archetype": "shadow", "sockets": 1, "base_defense": 2},
	"umbral_wrap": {"name": "闇の衣", "slot": "chest", "archetype": "shadow", "sockets": 2, "base_defense": 3},
	"umbral_gloves": {"name": "闇の手袋", "slot": "arms", "archetype": "shadow", "sockets": 1, "base_defense": 2},
	"umbral_leggings": {"name": "闇の脚衣", "slot": "legs", "archetype": "shadow", "sockets": 1, "base_defense": 2},
	"umbral_boots": {"name": "闇の靴", "slot": "feet", "archetype": "shadow", "sockets": 1, "base_defense": 1},
}


## equipment.ts の tierFromFloor()
static func tier_from_floor(floor: int) -> int:
	return max(1, int(floor / 10.0) + 1)


static func get_equipment(id: String) -> Dictionary:
	if not EQUIPMENT.has(id):
		push_error("unknown equipment: %s" % id)
		return {}
	return EQUIPMENT[id]


static func _stat_keys_of(def: Dictionary) -> Array:
	var keys: Array = []
	if def.get("base_strength", 0):
		keys.append("strength")
	if def.get("base_defense", 0):
		keys.append("defense")
	if def.get("base_poison_resist", 0):
		keys.append("poisonResist")
	if def.get("base_san_resist", 0):
		keys.append("sanResist")
	return keys


static func _roll_bonus_stats(def: Dictionary, tier: int, power: float, rng: Mulberry32) -> Dictionary:
	var cfg: Dictionary = TIER_BONUS_CONFIG.get(clampi(tier, 1, 5), TIER_BONUS_CONFIG[1])
	var own_keys := _stat_keys_of(def)
	var pool: Array = ALL_BONUS_KEYS.filter(func(k): return not own_keys.has(k))
	var bonus: Dictionary = {}
	if pool.is_empty():
		return bonus

	if rng.next_float() < cfg.bonus_chance:
		var idx := int(rng.next_float() * pool.size())
		var key: String = pool[idx]
		bonus[key] = max(1, round(BONUS_STAT_BASE[key] * power))

		var remaining: Array = pool.filter(func(k): return k != key)
		if not remaining.is_empty() and rng.next_float() < cfg.second_bonus_chance:
			var key2: String = remaining[int(rng.next_float() * remaining.size())]
			bonus[key2] = max(1, round(BONUS_STAT_BASE[key2] * power))
	return bonus


## equipment.ts の rollEquipmentPower()
static func roll_equipment_power(tier: int, rng: Mulberry32) -> float:
	var cfg: Dictionary = TIER_BONUS_CONFIG.get(clampi(tier, 1, 5), TIER_BONUS_CONFIG[1])
	var base: float = 1.0 + tier * 0.15
	var roll: float = 1.0 + (rng.next_float() * 2.0 - 1.0) * cfg.range_pct
	return max(0.5, base * roll)


## equipment.ts の rollEquipmentAtTier()
## 戻り値のEquipmentInstance相当: {uid, def_id, tier, power, socketed_runes, bonus_stats, obtained_floor, source}
static func roll_equipment_at_tier(def_id: String, tier: int, rng: Mulberry32, source: String) -> Dictionary:
	var def := get_equipment(def_id)
	var power := roll_equipment_power(tier, rng)
	var sockets: int = def.get("sockets", 0)
	var socketed_runes: Array = []
	for i in range(sockets):
		socketed_runes.append(null)
	return {
		"uid": "eq_%s_%s" % [str(Time.get_ticks_usec()), str(randi())],
		"def_id": def_id,
		"tier": tier,
		"power": power,
		"socketed_runes": socketed_runes,
		"bonus_stats": _roll_bonus_stats(def, tier, power, rng),
		"obtained_floor": 0,
		"source": source,
	}


## equipment.ts の rollEquipment()
static func roll_equipment(def_id: String, floor: int, rng: Mulberry32, source: String) -> Dictionary:
	var inst := roll_equipment_at_tier(def_id, tier_from_floor(floor), rng, source)
	inst.obtained_floor = floor
	return inst


## equipment.ts の pickEquipmentTemplate()
static func pick_equipment_template(rng: Mulberry32) -> String:
	var ids := EQUIPMENT.keys()
	if ids.is_empty():
		return "ragged_hood"
	return ids[int(rng.next_float() * ids.size())]


## store.ts pickEquipmentDefId()
static func pick_equipment_def_id(archetype, rng: Mulberry32) -> String:
	if archetype != null and str(archetype) != "" and str(archetype) != "generic":
		var matching: Array = []
		for def_id in EQUIPMENT.keys():
			var def: Dictionary = EQUIPMENT[def_id]
			if str(def.get("archetype", "")) == str(archetype):
				matching.append(str(def_id))
		if matching.size() > 0 and rng.next_float() < 0.7:
			return str(Mulberry32.pick(matching, rng))
	return pick_equipment_template(rng)


## equipment.ts の equipmentLabel()
static func equipment_label(inst: Dictionary) -> String:
	var def: Dictionary = EQUIPMENT.get(inst.get("def_id", ""), {})
	var bonus_count: int = (inst.get("bonus_stats", {}) as Dictionary).size()
	var name: String = def.get("name", inst.get("def_id", ""))
	return "%s +%d" % [name, bonus_count] if bonus_count > 0 else name


## equipment.ts の hasFullSet()：5部位すべてが同一archetypeか
static func has_full_set(equipped: Dictionary, archetype: String) -> bool:
	for slot in EQUIPMENT_SLOTS:
		var inst = equipped.get(slot)
		if inst == null:
			return false
		var def: Dictionary = EQUIPMENT.get(inst.get("def_id", ""), {})
		if def.get("archetype", "") != archetype:
			return false
	return true


## equipment.ts の computeEquipmentStats()。peek_rune_fn: Callable(String)->Dictionary（見つからなければ{}）
static func compute_equipment_stats(equipped: Dictionary, peek_rune_fn: Callable) -> Dictionary:
	## 戻り値のキーはcamelCase（TSのEquipmentStatsインターフェース＋combat.gdの参照契約に合わせる。
	## equipment.gd内部のEQUIPMENT/EquipmentInstanceのフィールド名はsnake_caseのまま独立）。
	var stats := {
		"defense": 0.0, "sanResist": 0.0, "poisonResist": 0.0,
		"poisonImmune": false, "blockRetain": false, "sanFullRestoreOnStart": false,
		"expandedHand": false, "hpPercentHealOnStart": false, "sacrificeEnergyOnStart": false,
		"intangibleOnHit": false, "strength": 0.0, "drawBonus": 0.0, "healPerTurn": 0.0,
		"healBonusPct": 0, "sanHealOnStart": 0.0, "vulnOnStart": 0.0, "energyPerTurn": 0.0,
		"thornDamage": 0.0,
	}

	for slot in equipped.keys():
		var inst = equipped[slot]
		if inst == null:
			continue
		var def: Dictionary = EQUIPMENT.get(inst.get("def_id", ""), {})
		if def.is_empty():
			continue
		var power: float = inst.get("power", 1.0)
		if power == 0:
			power = 1.0

		stats.defense += def.get("base_defense", 0) * power
		stats.sanResist += def.get("base_san_resist", 0) * power
		stats.poisonResist += def.get("base_poison_resist", 0) * power
		stats.strength += def.get("base_strength", 0) * power
		stats.drawBonus += def.get("base_draw", 0) * power
		stats.healPerTurn += def.get("base_heal", 0) * power
		stats.thornDamage += def.get("base_thorn", 0) * power

		var bonus: Dictionary = inst.get("bonus_stats", {})
		if bonus.has("strength"):
			stats.strength += bonus.strength
		if bonus.has("defense"):
			stats.defense += bonus.defense
		if bonus.has("poisonResist"):
			stats.poisonResist += bonus.poisonResist
		if bonus.has("sanResist"):
			stats.sanResist += bonus.sanResist

		for rune_id in (inst.get("socketed_runes", []) as Array):
			if rune_id == null:
				continue
			## peek_rune_fn（CollectionData.peek_rune()）はルーンが見つからない場合
			## Dictionaryではなくnullを返すため、Dictionary型で受けずVariantで受ける
			## （nullをDictionary型変数へ代入すると実行時エラーになるため）。
			var rune = peek_rune_fn.call(rune_id)
			if rune == null or rune.is_empty():
				continue
			match rune.get("effect", ""):
				"BLK+":
					stats.defense += rune.value
					stats.strength += 1
				"SAN+":
					stats.sanResist += rune.value
					stats.sanHealOnStart += 2
				"POISON":
					stats.poisonResist += rune.value
					stats.healPerTurn += 1
				"STR+":
					stats.strength += rune.value
					stats.defense += 1
				"DRAW":
					stats.drawBonus += rune.value
					stats.vulnOnStart += 1
				"HEAL":
					stats.healPerTurn += rune.value
					stats.poisonResist += 1
				"VULN+":
					stats.vulnOnStart += rune.value
					stats.strength += 1
				"ENERGY+":
					stats.energyPerTurn += rune.value
					stats.drawBonus += 1
				"THORN":
					stats.thornDamage += rune.value
					stats.defense += 1

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


## equipment.ts の applyFlatDefense()
static func apply_flat_defense(damage: int, defense: float) -> int:
	if damage <= 0:
		return damage
	var reduced: float = damage - defense
	return max(MIN_CHIP_DAMAGE, int(round(reduced)))


## equipment.ts の applyFlatResist()
static func apply_flat_resist(amount: int, resist: float) -> int:
	if amount <= 0:
		return amount
	return max(0, int(round(amount - resist)))
