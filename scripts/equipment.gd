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

## id -> {name, slot, archetype, art, sockets, base_strength?, base_defense?,
##        base_poison_resist?, base_san_resist?, base_draw?, base_heal?, base_thorn?}
const EQUIPMENT := {
	"ragged_hood": {"name": "襤褸の頭巾", "slot": "head", "archetype": "generic", "art": "res://art/pixel/equipment/ragged_hood.jpg", "sockets": 1, "base_defense": 3},
	"worn_coat": {"name": "着古した外套", "slot": "chest", "archetype": "generic", "art": "res://art/pixel/equipment/worn_coat.jpg", "sockets": 2, "base_defense": 5},
	"bandaged_arms": {"name": "包帯の腕", "slot": "arms", "archetype": "generic", "art": "res://art/pixel/equipment/bandaged_arms.jpg", "sockets": 1, "base_strength": 1},
	"patched_legs": {"name": "継ぎ接ぎの脚衣", "slot": "legs", "archetype": "generic", "art": "res://art/pixel/equipment/patched_legs.jpg", "sockets": 1, "base_san_resist": 3},
	"worn_boots": {"name": "履き古した靴", "slot": "feet", "archetype": "generic", "art": "res://art/pixel/equipment/worn_boots.jpg", "sockets": 1, "base_poison_resist": 3},
	"blood_veil": {"name": "血に濡れた眼帯", "slot": "head", "archetype": "fanatic", "art": "res://art/pixel/equipment/blood_veil.jpg", "sockets": 1, "base_strength": 2},
	"sacrifice_plate": {"name": "生贄の胸当て", "slot": "chest", "archetype": "fanatic", "art": "res://art/pixel/equipment/sacrifice_plate.jpg", "sockets": 2, "base_strength": 2},
	"fanatic_bangle": {"name": "狂信の腕輪", "slot": "arms", "archetype": "fanatic", "art": "res://art/pixel/equipment/fanatic_bangle.jpg", "sockets": 1, "base_strength": 2},
	"cursed_greaves": {"name": "呪われた脚甲", "slot": "legs", "archetype": "fanatic", "art": "res://art/pixel/equipment/cursed_greaves.jpg", "sockets": 1, "base_strength": 1},
	"bloodstained_boots": {"name": "血染めの靴", "slot": "feet", "archetype": "fanatic", "art": "res://art/pixel/equipment/bloodstained_boots.jpg", "sockets": 1, "base_strength": 1},
	"pilgrim_helm": {"name": "巡礼の兜", "slot": "head", "archetype": "knight", "art": "res://art/pixel/equipment/pilgrim_helm.jpg", "sockets": 1, "base_defense": 3},
	"pilgrim_mail": {"name": "巡礼の鎧", "slot": "chest", "archetype": "knight", "art": "res://art/pixel/equipment/pilgrim_mail.jpg", "sockets": 2, "base_defense": 5},
	"pilgrim_gauntlets": {"name": "巡礼の篭手", "slot": "arms", "archetype": "knight", "art": "res://art/pixel/equipment/pilgrim_gauntlets.jpg", "sockets": 1, "base_defense": 3},
	"pilgrim_greaves": {"name": "巡礼の脚甲", "slot": "legs", "archetype": "knight", "art": "res://art/pixel/equipment/pilgrim_greaves.jpg", "sockets": 1, "base_defense": 3},
	"pilgrim_boots": {"name": "巡礼の靴", "slot": "feet", "archetype": "knight", "art": "res://art/pixel/equipment/pilgrim_boots.jpg", "sockets": 1, "base_defense": 2},
	"venom_hood": {"name": "猛毒の頭巾", "slot": "head", "archetype": "poison", "art": "res://art/pixel/equipment/venom_hood.jpg", "sockets": 1, "base_poison_resist": 3},
	"venom_coat": {"name": "猛毒の外套", "slot": "chest", "archetype": "poison", "art": "res://art/pixel/equipment/venom_coat.jpg", "sockets": 2, "base_poison_resist": 4},
	"venom_bangle": {"name": "猛毒の腕輪", "slot": "arms", "archetype": "poison", "art": "res://art/pixel/equipment/venom_bangle.jpg", "sockets": 1, "base_poison_resist": 3},
	"venom_leggings": {"name": "猛毒の脚衣", "slot": "legs", "archetype": "poison", "art": "res://art/pixel/equipment/venom_leggings.jpg", "sockets": 1, "base_poison_resist": 3},
	"venom_boots": {"name": "猛毒の靴", "slot": "feet", "archetype": "poison", "art": "res://art/pixel/equipment/venom_boots.jpg", "sockets": 1, "base_poison_resist": 2},
	"void_helm": {"name": "虚空の兜", "slot": "head", "archetype": "outer", "art": "res://art/pixel/equipment/void_helm.jpg", "sockets": 1, "base_san_resist": 3},
	"void_coat": {"name": "虚空の外套", "slot": "chest", "archetype": "outer", "art": "res://art/pixel/equipment/void_coat.jpg", "sockets": 2, "base_san_resist": 4},
	"void_gauntlets": {"name": "虚空の篭手", "slot": "arms", "archetype": "outer", "art": "res://art/pixel/equipment/void_gauntlets.jpg", "sockets": 1, "base_san_resist": 3},
	"void_leggings": {"name": "虚空の脚衣", "slot": "legs", "archetype": "outer", "art": "res://art/pixel/equipment/void_leggings.jpg", "sockets": 1, "base_san_resist": 3},
	"void_boots": {"name": "虚空の靴", "slot": "feet", "archetype": "outer", "art": "res://art/pixel/equipment/void_boots.jpg", "sockets": 1, "base_san_resist": 2},
	"ancient_helm": {"name": "太古の兜", "slot": "head", "archetype": "elder", "art": "res://art/pixel/equipment/ancient_helm.jpg", "sockets": 1, "base_draw": 2},
	"ancient_robe": {"name": "太古の法衣", "slot": "chest", "archetype": "elder", "art": "res://art/pixel/equipment/ancient_robe.jpg", "sockets": 2, "base_draw": 2},
	"ancient_vambrace": {"name": "太古の腕甲", "slot": "arms", "archetype": "elder", "art": "res://art/pixel/equipment/ancient_vambrace.jpg", "sockets": 1, "base_draw": 2},
	"ancient_leggings": {"name": "太古の脚衣", "slot": "legs", "archetype": "elder", "art": "res://art/pixel/equipment/ancient_leggings.jpg", "sockets": 1, "base_draw": 1},
	"ancient_boots": {"name": "太古の靴", "slot": "feet", "archetype": "elder", "art": "res://art/pixel/equipment/ancient_boots.jpg", "sockets": 1, "base_draw": 1},
	"abyssal_hood": {"name": "深海の頭巾", "slot": "head", "archetype": "deep", "art": "res://art/pixel/equipment/abyssal_hood.jpg", "sockets": 1, "base_heal": 2},
	"abyssal_coat": {"name": "深海の外套", "slot": "chest", "archetype": "deep", "art": "res://art/pixel/equipment/abyssal_coat.jpg", "sockets": 2, "base_heal": 3},
	"abyssal_bracers": {"name": "深海の腕当て", "slot": "arms", "archetype": "deep", "art": "res://art/pixel/equipment/abyssal_bracers.jpg", "sockets": 1, "base_heal": 2},
	"abyssal_leggings": {"name": "深海の脚衣", "slot": "legs", "archetype": "deep", "art": "res://art/pixel/equipment/abyssal_leggings.jpg", "sockets": 1, "base_heal": 2},
	"abyssal_boots": {"name": "深海の靴", "slot": "feet", "archetype": "deep", "art": "res://art/pixel/equipment/abyssal_boots.jpg", "sockets": 1, "base_heal": 1},
	"offering_headdress": {"name": "供物の頭飾り", "slot": "head", "archetype": "offering", "art": "res://art/pixel/equipment/offering_headdress.jpg", "sockets": 1, "base_thorn": 2},
	"offering_vestment": {"name": "供物の法衣", "slot": "chest", "archetype": "offering", "art": "res://art/pixel/equipment/offering_vestment.jpg", "sockets": 2, "base_thorn": 3},
	"offering_bangle": {"name": "供物の腕輪", "slot": "arms", "archetype": "offering", "art": "res://art/pixel/equipment/offering_bangle.jpg", "sockets": 1, "base_thorn": 2},
	"offering_leggings": {"name": "供物の脚衣", "slot": "legs", "archetype": "offering", "art": "res://art/pixel/equipment/offering_leggings.jpg", "sockets": 1, "base_thorn": 2},
	"offering_sandals": {"name": "供物の靴", "slot": "feet", "archetype": "offering", "art": "res://art/pixel/equipment/offering_sandals.jpg", "sockets": 1, "base_thorn": 1},
	"umbral_hood": {"name": "闇の頭巾", "slot": "head", "archetype": "shadow", "art": "res://art/pixel/equipment/umbral_hood.jpg", "sockets": 1, "base_defense": 2},
	"umbral_wrap": {"name": "闇の衣", "slot": "chest", "archetype": "shadow", "art": "res://art/pixel/equipment/umbral_wrap.jpg", "sockets": 2, "base_defense": 3},
	"umbral_gloves": {"name": "闇の手袋", "slot": "arms", "archetype": "shadow", "art": "res://art/pixel/equipment/umbral_gloves.jpg", "sockets": 1, "base_defense": 2},
	"umbral_leggings": {"name": "闇の脚衣", "slot": "legs", "archetype": "shadow", "art": "res://art/pixel/equipment/umbral_leggings.jpg", "sockets": 1, "base_defense": 2},
	"umbral_boots": {"name": "闇の靴", "slot": "feet", "archetype": "shadow", "art": "res://art/pixel/equipment/umbral_boots.jpg", "sockets": 1, "base_defense": 1},
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
	var stats := {
		"defense": 0.0, "san_resist": 0.0, "poison_resist": 0.0,
		"poison_immune": false, "block_retain": false, "san_full_restore_on_start": false,
		"expanded_hand": false, "hp_percent_heal_on_start": false, "sacrifice_energy_on_start": false,
		"intangible_on_hit": false, "strength": 0.0, "draw_bonus": 0.0, "heal_per_turn": 0.0,
		"heal_bonus_pct": 0, "san_heal_on_start": 0.0, "vuln_on_start": 0.0, "energy_per_turn": 0.0,
		"thorn_damage": 0.0,
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
		stats.san_resist += def.get("base_san_resist", 0) * power
		stats.poison_resist += def.get("base_poison_resist", 0) * power
		stats.strength += def.get("base_strength", 0) * power
		stats.draw_bonus += def.get("base_draw", 0) * power
		stats.heal_per_turn += def.get("base_heal", 0) * power
		stats.thorn_damage += def.get("base_thorn", 0) * power

		var bonus: Dictionary = inst.get("bonus_stats", {})
		if bonus.has("strength"):
			stats.strength += bonus.strength
		if bonus.has("defense"):
			stats.defense += bonus.defense
		if bonus.has("poisonResist"):
			stats.poison_resist += bonus.poisonResist
		if bonus.has("sanResist"):
			stats.san_resist += bonus.sanResist

		for rune_id in (inst.get("socketed_runes", []) as Array):
			if rune_id == null:
				continue
			var rune: Dictionary = peek_rune_fn.call(rune_id)
			if rune.is_empty():
				continue
			match rune.get("effect", ""):
				"BLK+":
					stats.defense += rune.value
					stats.strength += 1
				"SAN+":
					stats.san_resist += rune.value
					stats.san_heal_on_start += 2
				"POISON":
					stats.poison_resist += rune.value
					stats.heal_per_turn += 1
				"STR+":
					stats.strength += rune.value
					stats.defense += 1
				"DRAW":
					stats.draw_bonus += rune.value
					stats.vuln_on_start += 1
				"HEAL":
					stats.heal_per_turn += rune.value
					stats.poison_resist += 1
				"VULN+":
					stats.vuln_on_start += rune.value
					stats.strength += 1
				"ENERGY+":
					stats.energy_per_turn += rune.value
					stats.draw_bonus += 1
				"THORN":
					stats.thorn_damage += rune.value
					stats.defense += 1

	stats.defense = round(stats.defense)
	stats.san_resist = round(stats.san_resist)
	stats.poison_resist = round(stats.poison_resist)
	stats.strength = round(stats.strength)
	stats.draw_bonus = round(stats.draw_bonus)
	stats.heal_per_turn = round(stats.heal_per_turn)
	stats.san_heal_on_start = round(stats.san_heal_on_start)
	stats.vuln_on_start = round(stats.vuln_on_start)
	stats.energy_per_turn = round(stats.energy_per_turn)
	stats.thorn_damage = round(stats.thorn_damage)

	if has_full_set(equipped, "poison"):
		stats.poison_immune = true
		stats.heal_bonus_pct = 50
	if has_full_set(equipped, "knight"):
		stats.block_retain = true
	if has_full_set(equipped, "outer"):
		stats.san_full_restore_on_start = true
	if has_full_set(equipped, "elder"):
		stats.expanded_hand = true
	if has_full_set(equipped, "deep"):
		stats.hp_percent_heal_on_start = true
	if has_full_set(equipped, "offering"):
		stats.sacrifice_energy_on_start = true
	if has_full_set(equipped, "shadow"):
		stats.intangible_on_hit = true

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
