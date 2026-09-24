class_name EnemyAi
extends RefCounted

## src/game/enemyAi.ts の、combat.ts が import する関数のみ忠実移植。

const AI_CATEGORY_WEIGHTS := {
	"attack": 0.45,
	"defense": 0.35,
	"effect": 0.2,
}

## 敵ランクごとに使えるカードの上限（カードの enemy_tier と比較）。
## 雑魚は enemy_tier 1 のみ、エリートは 2 まで。ボスはデッキ指定なので制限なし。
const TIER_MAX_ENEMY_TIER := {
	"mob": 1,
	"elite": 2,
}


## enemyAi.ts rollEnemyCard()
static func roll_enemy_card(def_id: String, rand: Callable) -> Dictionary:
	var def := Enemies.get_enemy(def_id)
	var max_tier = null if def.has("deck") else TIER_MAX_ENEMY_TIER[str(def.get("tier", "mob"))]
	var use_archetype: bool = (not def.has("deck")) and str(def.get("archetype", "")) != ""

	var build_pool := func(tag: String) -> Array:
		if use_archetype:
			return Cards.ai_card_pool(tag, max_tier, def.get("archetype"))
		return Cards.ai_card_pool(tag, max_tier)

	var pools: Dictionary
	if def.has("deck"):
		pools = {
			"attack": Cards.ai_card_pool_from(def.deck, "attack"),
			"defense": Cards.ai_card_pool_from(def.deck, "defense"),
			"effect": Cards.ai_card_pool_from(def.deck, "effect"),
		}
	else:
		pools = {
			"attack": build_pool.call("attack"),
			"defense": build_pool.call("defense"),
			"effect": build_pool.call("effect"),
		}

	var active_weights := {}
	for tag in AI_CATEGORY_WEIGHTS.keys():
		if (pools[tag] as Array).size() > 0:
			active_weights[tag] = AI_CATEGORY_WEIGHTS[tag]

	if active_weights.is_empty():
		var fallback_tier = max_tier if max_tier != null else TIER_MAX_ENEMY_TIER["mob"]
		return Mulberry32.pick_rand(Cards.ai_card_pool("attack", fallback_tier), rand)
	var category: String = str(Mulberry32.weighted_pick(active_weights, rand))
	return Mulberry32.pick_rand(pools[category], rand)


## enemyAi.ts cardToIntent()
static func card_to_intent(card: Dictionary) -> Dictionary:
	var intent := {"kind": "unknown"}
	for eff in card.get("effects", []):
		var t: String = str(eff.get("t", ""))
		if t == "damage" or t == "damageAll" or t == "damageX":
			intent.kind = "attack"
			intent.damage = int(intent.get("damage", 0)) + int(eff.get("n", 0))
			if eff.has("hits"):
				intent.hits = int(eff.get("hits", 1))
		if t == "block" or t == "blockPerEnemy":
			if intent.kind != "attack":
				intent.kind = "defend"
			intent.block = int(intent.get("block", 0)) + int(eff.get("n", 0))
		if t == "strength":
			intent.strength = int(intent.get("strength", 0)) + int(eff.get("n", 0))
			if intent.kind == "unknown":
				intent.kind = "buff"
		if t == "weak":
			intent.weak = int(intent.get("weak", 0)) + int(eff.get("n", 0))
			if intent.kind == "unknown":
				intent.kind = "debuff"
		if t == "vulnerable":
			intent.vulnerable = int(intent.get("vulnerable", 0)) + int(eff.get("n", 0))
			if intent.kind == "unknown":
				intent.kind = "debuff"
		if t == "poison":
			intent.poison = int(intent.get("poison", 0)) + int(eff.get("n", 0))
			if intent.kind == "unknown":
				intent.kind = "debuff"
		if t == "addDread":
			intent.dread = int(intent.get("dread", 0)) + int(eff.get("n", 0))
			if intent.kind == "unknown":
				intent.kind = "debuff"
		if t == "sanity" and float(eff.get("n", 0)) < 0:
			intent.sanityDrain = int(intent.get("sanityDrain", 0)) + int(abs(float(eff.get("n", 0))))
			if intent.kind == "unknown":
				intent.kind = "debuff"
		if t == "heal":
			intent.heal = int(intent.get("heal", 0)) + int(eff.get("n", 0))
			if intent.kind == "unknown":
				intent.kind = "buff"
		if t == "seal":
			intent.seal = eff.get("value")
			intent.kind = "debuff"
		if t == "eihortCurseOnHit":
			intent.eihortCurse = true
		## 以下は敵専用（ithaqua）の効果タグ
		if t == "inflictCold":
			intent.cold = int(intent.get("cold", 0)) + int(eff.get("n", 0))
			if intent.kind == "unknown":
				intent.kind = "debuff"
		if t == "addStatusToDraw":
			var adds: Array = intent.get("addToDraw", [])
			adds.append({"id": str(eff.get("id", "")), "n": int(eff.get("n", 1))})
			intent.addToDraw = adds
			if intent.kind == "unknown":
				intent.kind = "debuff"
		if t == "snatchHand":
			intent.snatch = int(intent.get("snatch", 0)) + int(eff.get("n", 1))
			if intent.kind == "unknown":
				intent.kind = "debuff"
	if intent.kind == "unknown":
		intent.kind = "buff"
	return intent
