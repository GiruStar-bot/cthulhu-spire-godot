class_name CombatLogic
extends RefCounted

## src/game/combat.ts の忠実な移植。数値・条件分岐は変更していない。
## 乱数は rng.ts と同じく Callable（() -> float, [0,1)）で渡す。
## PlayerHook / CombatState / CombatEnemy は Dictionary。


static func _floater(text: String, kind: String, who: String) -> Dictionary:
	return {"id": Mulberry32.uid("f"), "text": text, "kind": kind, "who": who}


static func _apply_heal_bonus(n: int, heal_bonus_pct: float) -> int:
	return int(round(float(n) * (1.0 + heal_bonus_pct / 100.0)))


static func _scale_hp(base: int, floor: int) -> int:
	return int(round(float(base) * (1.0 + float(maxi(0, floor - 1)) * 0.045)))


static func _block_position(floor: int) -> int:
	return ((floor - 1) % 10) + 1


static func _block_strength_bonus(floor: int) -> int:
	var pos := _block_position(floor)
	if pos <= 3:
		return 1
	if pos <= 6:
		return 2
	if pos <= 9:
		return 3
	return 5


## combat.ts makeEnemy()
static func make_enemy(def_id: String, floor: int, rand: Callable) -> Dictionary:
	var d := Enemies.get_enemy(def_id)
	var max_hp := _scale_hp(int(d.get("maxHp", 1)), floor)
	var is_boss := d.has("deck")
	var e := {
		"uid": Mulberry32.uid("e"),
		"defId": def_id,
		"hp": max_hp,
		"maxHp": max_hp,
		"block": 0,
		"strength": int(ceil(float(_block_strength_bonus(floor)) / 2.0)) if is_boss else _block_strength_bonus(floor),
		"weak": 0,
		"vulnerable": 0,
		"poison": 0,
		"patternIndex": 0,
		"intent": {"kind": "unknown"},
		"actionCardIds": [],
		"sealed": null,
	}
	_roll_next_action(e, rand)
	return e


static func _roll_next_action(e: Dictionary, rand: Callable) -> void:
	var d := Enemies.get_enemy(str(e.defId))
	var n: int = int(d.get("cardsPerTurn", 1))
	var card_ids: Array = []
	for i in n:
		card_ids.append(EnemyAi.roll_enemy_card(str(e.defId), rand).id)
	e.actionCardIds = card_ids
	e.intent = EnemyAi.card_to_intent(Cards.get_card(str(card_ids[0])))
	if d.get("trait") == "liar":
		var shown: Array = []
		for i in n:
			shown.append(EnemyAi.roll_enemy_card(str(e.defId), rand).id)
		e.shownCardIds = shown
		e.shownIntent = EnemyAi.card_to_intent(Cards.get_card(str(shown[0])))
	else:
		e.erase("shownCardIds")
		e.erase("shownIntent")


## combat.ts living()
static func living(c: Dictionary) -> Array:
	var out: Array = []
	for e in c.enemies:
		if int(e.hp) > 0:
			out.append(e)
	return out


static func _dmg_dealt(base: int, strength: int, weak: int) -> int:
	var n := base + strength
	if weak > 0:
		n = int(floor(float(n) * 0.75))
	return maxi(0, n)


static func _dmg_taken(raw: int, vulnerable: int) -> int:
	return int(floor(float(raw) * 1.5)) if vulnerable > 0 else raw


static func _apply_to_enemy(e: Dictionary, raw: int, c: Dictionary, rand: Callable = Callable()) -> int:
	var n := _dmg_taken(raw, int(e.vulnerable))
	if Enemies.get_enemy(str(e.defId)).get("trait") == "nurse" and int(e.block) > 0:
		n = int(floor(float(n) * 0.5))
	var blocked: int = mini(int(e.block), n)
	e.block = int(e.block) - blocked
	var hp: int = n - blocked
	e.hp = maxi(0, int(e.hp) - hp)
	c.floaters.append(_floater("-%d" % n, "dmg", str(e.uid)))
	_maybe_split(e, c, rand)
	return n


static func _maybe_split(e: Dictionary, c: Dictionary, rand: Callable = Callable()) -> void:
	if Enemies.get_enemy(str(e.defId)).get("trait") != "split":
		return
	if e.get("splitDone") or int(e.hp) <= 0 or int(e.hp) > float(e.maxHp) / 2.0:
		return
	e.splitDone = true
	var roll: Callable = rand if rand.is_valid() else func(): return 0.5
	var clone := make_enemy(str(e.defId), int(c.floor), roll)
	clone.hp = e.hp
	clone.maxHp = e.maxHp
	clone.splitDone = true
	clone.strength = e.strength
	c.enemies.append(clone)
	c.log.append("%sが分かれた。" % Enemies.get_enemy(str(e.defId)).name)
	c.floaters.append(_floater("分裂", "info", str(e.uid)))


static func _incoming(raw: int, c: Dictionary) -> int:
	return mini(1, maxi(0, raw)) if int(c.intangible) > 0 else raw


static func _base_draw_count(c: Dictionary) -> int:
	return 5 + int(round(float(c.equipmentStats.get("drawBonus", 0))))


## combat.ts drawCards()
static func draw_cards(c: Dictionary, n: int, rand: Callable, player = null) -> void:
	var hand_limit: int = 12 if c.equipmentStats.get("expandedHand") else 10
	var drawn := 0
	while drawn < n:
		if c.hand.size() >= hand_limit:
			break
		if c.draw.size() == 0:
			if c.discard.size() == 0:
				break
			c.draw = Mulberry32.shuffle(c.discard, rand)
			c.discard = []
		var card = c.draw.pop_back()
		if card == null:
			break
		var d := Cards.get_card(str(card.defId))
		if d.get("onDraw") and player != null:
			_run_effects(d.onDraw, c, player, null, rand, card)
			c.floaters.append(_floater(str(d.name), "info", "player"))
			c.log.append("%sを引いた。" % d.name)
		c.hand.append(card)
		drawn += 1


static func _add_to_discard(c: Dictionary, card: Dictionary) -> void:
	c.discard.append(card)


static func _spawn_combat_card(def_id: String) -> Dictionary:
	var spawned: Dictionary = Cards.make_card(def_id)
	spawned["combatSpawn"] = true
	return spawned


static func _insert_into_draw(c: Dictionary, card: Dictionary, rand: Callable) -> void:
	var idx := int(floor(rand.call() * float(c.draw.size() + 1)))
	c.draw.insert(idx, card)


static func _double_effect_numbers(effects: Array) -> Array:
	var out: Array = []
	for item in effects:
		if typeof(item) != TYPE_DICTIONARY:
			out.append(item)
			continue
		var copy: Dictionary = item.duplicate(true)
		if copy.has("n"):
			copy.n = int(copy.n) * 2
		if copy.has("block"):
			copy.block = int(copy.block) * 2
		if copy.has("strength"):
			copy.strength = int(copy.strength) * 2
		if copy.has("then"):
			copy.then = _double_effect_numbers(copy.then)
		out.append(copy)
	return out


static func _seek_tagged(c: Dictionary, tag: String, need: int, rand: Callable) -> int:
	var moved: int = 0
	moved += _pull_tagged_from(c, "draw", tag, need - moved, rand)
	if moved < need:
		moved += _pull_tagged_from(c, "discard", tag, need - moved, rand)
	return moved


static func _pull_tagged_from(c: Dictionary, pile_key: String, tag: String, need: int, rand: Callable) -> int:
	if need <= 0:
		return 0
	var pile: Array = c[pile_key]
	var hits: Array = []
	var rest: Array = []
	for card_inst in pile:
		if Cards.has_tag(Cards.get_card(str(card_inst.defId)), tag):
			hits.append(card_inst)
		else:
			rest.append(card_inst)
	hits = Mulberry32.shuffle(hits, rand)
	var take: int = mini(need, hits.size())
	for i in take:
		c.hand.append(hits[i])
	var leftover: Array = hits.slice(take)
	leftover.append_array(rest)
	c[pile_key] = leftover
	return take


## combat.ts computeDeckSynergy()
static func compute_deck_synergy(deck: Array):
	var counts := {}
	for card in deck:
		var def := Cards.get_card(str(card.defId))
		var arch = def.get("archetype")
		if not arch or arch == "generic":
			continue
		counts[arch] = int(counts.get(arch, 0)) + 1
	var best_arch = null
	var best_count := 0
	for arch in counts.keys():
		if best_arch == null or int(counts[arch]) > best_count:
			best_arch = arch
			best_count = int(counts[arch])
	if best_arch == null or best_count < 8:
		return null
	var tier: int = 3 if best_count >= 16 else (2 if best_count >= 12 else 1)
	return {"archetype": best_arch, "tier": tier}


## combat.ts startCombat()
static func start_combat(deck: Array, enemy_ids: Array, player: Dictionary, floor: int, rand: Callable) -> Dictionary:
	var draw: Array = []
	for card in deck:
		var copy: Dictionary = card.duplicate(true)
		copy.uid = Mulberry32.uid("c")
		draw.append(copy)
	draw = Mulberry32.shuffle(draw, rand)
	var enemies: Array = []
	for id in enemy_ids:
		enemies.append(make_enemy(str(id), floor, rand))
	var eq: Dictionary = Blessings.compute_stats(player.get("blessings", []))
	var base_energy: int = int(player.get("baseEnergy", 3))
	var c := {
		"floor": floor,
		"enemies": enemies,
		"draw": draw,
		"discard": [],
		"exhaust": [],
		"hand": [],
		"energy": base_energy + int(player.get("extraEnergyNext", 0)) + int(eq.get("energyPerTurn", 0)),
		"maxEnergy": base_energy,
		"block": 0,
		"strength": int(round(float(eq.get("strength", 0)))),
		"dexterity": 0,
		"weak": 0,
		"vulnerable": 0,
		"poison": 0,
		"powers": [],
		"cardsPlayed": 0,
		"sealed": null,
		"intangible": 0,
		"nextAttackMul": 1,
		"blockLost": 0,
		"pendingPhase": 0,
		"attackSelfHurt": 0,
		"keepBlock": 0,
		"skipDraw": 0,
		"energyNext": 0,
		"cold": 0,
		"retainHand": 0,
		"thornsVulnerable": 0,
		"xSpent": 0,
		"forceEnd": false,
		"bastBlessing": 0,
		"bastBlock": 0,
		"bastStr": 0,
		"turn": 1,
		"phase": "player",
		"result": "ongoing",
		"log": ["空気が、厚くなる。"],
		"floaters": [],
		"equipmentStats": eq,
		"synergy": compute_deck_synergy(deck),
	}
	c.strength = int(c.strength) + int(player.get("extraStrength", 0))
	if c.synergy:
		var archetype: String = str(c.synergy.archetype)
		var tier: int = int(c.synergy.tier)
		if archetype == "fanatic":
			c.strength = int(c.strength) + tier
		if archetype == "greatold":
			c.strength = int(c.strength) + tier
		if archetype == "poison":
			for e in c.enemies:
				e.poison = int(e.poison) + tier
		if archetype == "elder":
			var weak_n: int = 2 if tier == 3 else 1
			for e in c.enemies:
				e.weak = int(e.weak) + weak_n
		if archetype == "deep":
			var heal_n: int = 2 if tier == 1 else (4 if tier == 2 else 6)
			player.hp = mini(int(player.maxHp), int(player.hp) + heal_n)
		if archetype == "offering" and tier >= 2:
			c.energy = int(c.energy) + 1
		if archetype == "shadow" and tier == 3:
			c.intangible = int(c.intangible) + 1
	if int(eq.get("vulnOnStart", 0)) > 0:
		for e in c.enemies:
			e.vulnerable = int(e.vulnerable) + int(eq.vulnOnStart)
	if int(eq.get("sanHealOnStart", 0)) > 0:
		player.sanity = mini(int(player.maxSanity), int(player.sanity) + int(eq.sanHealOnStart))
	if eq.get("sanFullRestoreOnStart"):
		player.sanity = player.maxSanity
	if eq.get("hpPercentHealOnStart"):
		var heal_n2: int = int(floor(float(player.maxHp) * 0.1))
		player.hp = mini(int(player.maxHp), int(player.hp) + heal_n2)
	if eq.get("sacrificeEnergyOnStart"):
		var cost: int = maxi(1, int(floor(float(player.maxHp) * 0.1)))
		player.hp = maxi(1, int(player.hp) - cost)
		c.energy = int(c.energy) + 1
	var outer_bonus: int = int(c.synergy.tier) if c.synergy and str(c.synergy.archetype) == "outer" else 0
	draw_cards(c, _base_draw_count(c) + outer_bonus, rand, player)
	if int(player.sanity) <= 0:
		_add_to_discard(c, _spawn_combat_card("dread"))
		c.log.append("恐怖がデッキに沈む。")
	return c


static func _living_target(c: Dictionary, target_id):
	var live := living(c)
	if target_id:
		for x in live:
			if str(x.uid) == str(target_id):
				return x
	if live.size() > 0:
		return live[0]
	return null


static func _run_effects(effects: Array, c: Dictionary, player: Dictionary, target_id, rand: Callable, card = null) -> void:
	var work: Array = effects
	if card != null:
		var cdef: Dictionary = Cards.get_card(str(card.defId))
		if Cards.has_tag(cdef, "cat") and "goddessContract" in c.powers:
			work = _double_effect_numbers(effects)
	for e in work:
		var t: String = str(e.get("t", ""))
		match t:
			"damage":
				var tgt = _living_target(c, target_id)
				if tgt == null:
					continue
				var n: int = _dmg_dealt(Cards.scale_n(int(e.n), card), int(c.strength), int(c.weak))
				if card != null and str(card.get("defId")) == "laststand" and float(player.hp) <= float(player.maxHp) * 0.5:
					n += 12 if card.get("upgraded") else 9
				if float(c.nextAttackMul) != 1.0:
					n = int(floor(float(n) * float(c.nextAttackMul)))
					c.nextAttackMul = 1
				var dealt := _apply_to_enemy(tgt, n, c, rand)
				var cname: String = Cards.get_card(str(card.defId)).name if card != null else "攻撃"
				c.log.append("%sで%sに%dダメージ。" % [cname, Enemies.get_enemy(str(tgt.defId)).name, dealt])
				if int(c.attackSelfHurt) > 0:
					player.hp = maxi(1, int(player.hp) - int(c.attackSelfHurt))
					c.floaters.append(_floater("-%d" % int(c.attackSelfHurt), "dmg", "player"))
			"damageAll":
				var n2: int = _dmg_dealt(Cards.scale_n(int(e.n), card), int(c.strength), int(c.weak))
				if float(c.nextAttackMul) != 1.0:
					n2 = int(floor(float(n2) * float(c.nextAttackMul)))
					c.nextAttackMul = 1
				for tgt2 in living(c):
					_apply_to_enemy(tgt2, n2, c, rand)
				c.log.append("%sが敵全体を襲った。" % (Cards.get_card(str(card.defId)).name if card != null else "攻撃"))
				if int(c.attackSelfHurt) > 0:
					player.hp = maxi(1, int(player.hp) - int(c.attackSelfHurt))
					c.floaters.append(_floater("-%d" % int(c.attackSelfHurt), "dmg", "player"))
			"block":
				var bn: int = Cards.scale_n(int(e.n), card) + int(c.dexterity)
				if card != null:
					var card_def := Cards.get_card(str(card.defId))
					if card_def.get("aiTag") == "defense" and c.synergy and str(c.synergy.archetype) == "knight":
						bn += int(c.synergy.tier)
				c.block = int(c.block) + bn
				c.floaters.append(_floater("+%d" % bn, "block", "player"))
				c.log.append("%sでブロック%dを得た。" % [Cards.get_card(str(card.defId)).name if card != null else "防御", bn])
			"draw":
				draw_cards(c, int(e.n), rand)
			"energy":
				c.energy = int(c.energy) + int(e.n)
			"strength":
				c.strength = int(c.strength) + int(e.n)
			"dexterity":
				c.dexterity = int(c.dexterity) + int(e.n)
			"heal":
				var healed := _apply_heal_bonus(int(e.n), float(c.equipmentStats.get("healBonusPct", 0)))
				player.hp = mini(int(player.maxHp), int(player.hp) + healed)
				c.floaters.append(_floater("+%d" % healed, "heal", "player"))
				c.log.append("体力を%d回復した。" % healed)
			"sanity":
				change_sanity(player, c, int(e.n))
			"sanityDamage":
				var reduced := Equipment.apply_flat_resist(int(e.n), float(c.equipmentStats.get("sanResist", 0)))
				change_sanity(player, c, -reduced)
				c.log.append("恐怖に苛まれ、正気を%d失った。" % reduced)
			"hpCost":
				player.hp = maxi(1, int(player.hp) - int(e.n))
				c.floaters.append(_floater("-%d" % int(e.n), "dmg", "player"))
				c.log.append("体力を%d失った。" % int(e.n))
			"hpCostHalf":
				var lost: int = maxi(1, int(floor(float(player.hp) / 2.0)))
				player.hp = maxi(1, int(player.hp) - lost)
				c.floaters.append(_floater("-%d" % lost, "dmg", "player"))
				c.log.append("体力を%d失った。" % lost)
			"curePoison":
				c.poison = 0
				c.log.append("毒が浄化された。")
			"weak":
				var live_w := living(c)
				if target_id:
					var tw = _living_target(c, target_id)
					if tw:
						tw.weak = int(tw.weak) + int(e.n)
				else:
					for tgtw in live_w:
						tgtw.weak = int(tgtw.weak) + int(e.n)
				if target_id:
					c.log.append("敵に弱体%dを付与した。" % int(e.n))
				else:
					c.log.append("敵全体に弱体%dを付与した。" % int(e.n))
			"vulnerable":
				var live_v := living(c)
				if target_id:
					var tv = _living_target(c, target_id)
					if tv:
						tv.vulnerable = int(tv.vulnerable) + int(e.n)
				else:
					for tgtv in live_v:
						tgtv.vulnerable = int(tgtv.vulnerable) + int(e.n)
				if target_id:
					c.log.append("敵に脆弱%dを付与した。" % int(e.n))
				else:
					c.log.append("敵全体に脆弱%dを付与した。" % int(e.n))
			"gainPower":
				if not (e.id in c.powers):
					c.powers.append(e.id)
			"addDread":
				for i in int(e.n):
					_insert_into_draw(c, _spawn_combat_card("dread"), rand)
				c.log.append("恐怖を%d枚差し込んだ。" % int(e.n))
			"ifIntentAttack":
				var ti = _living_target(c, target_id)
				if ti and str(ti.intent.get("kind")) == "attack":
					_run_effects(e.get("then", []), c, player, target_id, rand, card)
			"ifSanityBelow":
				if int(player.sanity) < int(e.threshold):
					_run_effects(e.get("then", []), c, player, target_id, rand, card)
			"poison":
				var live_p := living(c)
				if target_id:
					var tp = _living_target(c, target_id)
					if tp:
						tp.poison = int(tp.poison) + int(e.n)
				else:
					for tgtp in live_p:
						tgtp.poison = int(tgtp.poison) + int(e.n)
			"intangible":
				c.intangible = int(c.intangible) + int(e.n)
				c.floaters.append(_floater("無形", "info", "player"))
			"loseMaxHp":
				player.maxHp = maxi(1, int(player.maxHp) - int(e.n))
				player.hp = mini(int(player.hp), int(player.maxHp))
				c.floaters.append(_floater("最大-%d" % int(e.n), "dmg", "player"))
			"addCurse":
				_add_to_discard(c, _spawn_combat_card(str(e.id)))
			"nextAttackMul":
				c.nextAttackMul = float(c.nextAttackMul) * float(e.n)
			"phaseDelay":
				c.pendingPhase = 1
			"attackSelfHurt":
				c.attackSelfHurt = int(c.attackSelfHurt) + int(e.n)
			"blockPerEnemy":
				var bpn: int = living(c).size() * int(e.n)
				if bpn > 0:
					c.block = int(c.block) + bpn
					c.floaters.append(_floater("+%d" % bpn, "block", "player"))
			"damageX":
				var tx = _living_target(c, target_id)
				if tx:
					_apply_to_enemy(tx, _dmg_dealt(int(e.n) * maxi(0, int(c.xSpent)), int(c.strength), int(c.weak)), c, rand)
			"exhaustHand":
				for h in c.hand:
					c.exhaust.append(h)
				c.hand = []
			"banish":
				for i in int(e.n):
					if c.hand.size() == 0:
						break
					var j := int(floor(rand.call() * float(c.hand.size())))
					var gone = c.hand.pop_at(j)
					if gone:
						c.exhaust.append(gone)
			"healOnKill":
				var tk = null
				for x in living(c):
					if str(x.uid) == str(target_id):
						tk = x
						break
				if tk == null:
					var hk := _apply_heal_bonus(int(e.n), float(c.equipmentStats.get("healBonusPct", 0)))
					player.hp = mini(int(player.maxHp), int(player.hp) + hk)
					c.floaters.append(_floater("+%d" % hk, "heal", "player"))
			"retainBlock":
				c.keepBlock = 1
			"discardRandom":
				for i in int(e.n):
					if c.hand.size() == 0:
						break
					var jd := int(floor(rand.call() * float(c.hand.size())))
					var gone_d = c.hand.pop_at(jd)
					if gone_d:
						_add_to_discard(c, gone_d)
			"skipDraw":
				c.skipDraw = int(c.skipDraw) + int(e.n)
			"energyNext":
				c.energyNext = int(c.energyNext) + int(e.n)
			"cancelIntent":
				var tc = _living_target(c, target_id)
				if tc:
					tc.intent = {"kind": "defend", "block": 0}
					tc.shownIntent = tc.intent
			"endTurnMaybe":
				if rand.call() < float(e.p):
					c.forceEnd = true
			"cold":
				c.cold = int(c.cold) + int(e.n)
			"bind":
				var tb = _living_target(c, target_id)
				if tb:
					tb.bound = 1
			"selfVulnerable":
				c.vulnerable = int(c.vulnerable) + int(e.n)
			"retainCards":
				c.retainHand = maxi(int(c.retainHand), int(e.n))
			"thornsVulnerable":
				c.thornsVulnerable = int(c.thornsVulnerable) + int(e.n)
			"loseMaxHpHalf":
				var lost_m: int = int(floor(float(player.maxHp) / 2.0))
				player.maxHp = maxi(1, int(player.maxHp) - lost_m)
				player.hp = mini(int(player.hp), int(player.maxHp))
				c.floaters.append(_floater("最大-%d" % lost_m, "dmg", "player"))
			"seal":
				c.sealed = e.value
				c.log.append("%sが封じられた。" % ("攻撃" if e.value == "attack" else "技能"))
			"sealEnemy":
				var ts = _living_target(c, target_id)
				if ts:
					ts.sealed = e.value
					c.log.append("%sの%sを封じた。" % [Enemies.get_enemy(str(ts.defId)).name, "攻撃" if e.value == "attack" else "技能"])
			"clearStatus":
				c.poison = 0
				c.weak = 0
				c.vulnerable = 0
				c.cold = 0
				c.log.append("状態異常が回復した。")
			"addToDraw":
				var add_n: int = int(e.get("n", 1))
				var add_id: String = str(e.get("id", ""))
				for _i in add_n:
					_insert_into_draw(c, _spawn_combat_card(add_id), rand)
				c.log.append("%sを%d枚デッキに加えた。" % [Cards.get_card(add_id).get("name", add_id), add_n])
			"addToHand":
				var hand_n: int = int(e.get("n", 1))
				var hand_id: String = str(e.get("id", ""))
				for _j in hand_n:
					c.hand.append(_spawn_combat_card(hand_id))
				c.log.append("%sを%d枚手札に加えた。" % [Cards.get_card(hand_id).get("name", hand_id), hand_n])
			"seekTagged":
				var tag: String = str(e.get("tag", "cat"))
				var need: int = int(e.n)
				var moved: int = _seek_tagged(c, tag, need, rand)
				c.log.append("デッキから「%s」を%d枚加えた。" % [tag, moved])
			"bastBlessing":
				c.bastBlessing = 1
				c.bastBlock = Cards.scale_n(int(e.get("block", 5)), card)
				c.bastStr = Cards.scale_n(int(e.get("strength", 1)), card)
				c.log.append("このターン、猫を使うたびブロック%d、筋力%dを得る。" % [int(c.bastBlock), int(c.bastStr)])


## combat.ts changeSanity()
static func change_sanity(player: Dictionary, c: Dictionary, delta: int) -> void:
	var before: int = int(player.sanity)
	player.sanity = maxi(0, mini(int(player.maxSanity), int(player.sanity) + delta))
	if delta != 0:
		c.floaters.append(_floater("%s%d" % ["+" if delta > 0 else "", delta], "sanity", "player"))
		c.log.append("正気が%s%dした。" % ["+" if delta > 0 else "", delta])
	if delta < 0:
		if "bloodOath" in c.powers:
			c.strength = int(c.strength) + 2
		if before > 0 and int(player.sanity) == 0:
			_add_to_discard(c, _spawn_combat_card("dread"))
			_add_to_discard(c, _spawn_combat_card("dread"))
			c.log.append("正気が砕ける。恐怖がデッキを満たす。")


static func _finish_play(c: Dictionary, card: Dictionary, def_exhaust: bool) -> void:
	if typeof(card.get("charges")) == TYPE_INT:
		card.charges = int(card.charges) - 1
		if int(card.charges) > 0:
			_add_to_discard(c, card)
			return
		c.exhaust.append(card)
		return
	if def_exhaust or Cards.get_card(str(card.defId)).get("type") == "power":
		c.exhaust.append(card)
	else:
		_add_to_discard(c, card)


## cardEvaluator.ts evaluateCardEffect()（combat.ts が呼ぶ薄いラッパ）
static func _evaluate_card_effect(card: Dictionary) -> Dictionary:
	return {"cost": Cards.card_cost(card), "effects": Cards.card_effects(card)}


## combat.ts canPlay()
static func can_play(c: Dictionary, card: Dictionary) -> bool:
	var d := Cards.get_card(str(card.defId))
	if c.phase != "player" or c.result != "ongoing":
		return false
	if d.get("unplayable"):
		return false
	if c.sealed and d.get("type") == c.sealed:
		return false
	if d.get("xCost"):
		return true
	return int(_evaluate_card_effect(card).cost) <= int(c.energy)


## combat.ts playCard()
static func play_card(c: Dictionary, player: Dictionary, card_uid: String, target_id, rand: Callable) -> Dictionary:
	var empty: Array = []
	if c.phase != "player" or c.result != "ongoing":
		return {"error": "自分のターンではない。", "sfx": empty}
	var idx := -1
	for i in c.hand.size():
		if str(c.hand[i].uid) == card_uid:
			idx = i
			break
	if idx < 0:
		return {"error": "手札にない。", "sfx": empty}
	var card: Dictionary = c.hand[idx]
	var d := Cards.get_card(str(card.defId))
	if d.get("unplayable"):
		return {"error": "プレイできない。", "sfx": empty}
	if c.sealed and d.get("type") == c.sealed:
		return {"error": "%sは封じられている。" % ("攻撃" if c.sealed == "attack" else "技能"), "sfx": empty}
	var evaled := _evaluate_card_effect(card)
	var cost: int = int(c.energy) if d.get("xCost") else int(evaled.cost)
	if (not d.get("xCost")) and cost > int(c.energy):
		return {"error": "エネルギーが足りない。", "sfx": empty}
	if d.get("target") == "enemy" and living(c).size() > 1 and not target_id:
		return {"error": "対象を選んでください。", "sfx": empty}
	c.hand.remove_at(idx)
	c.xSpent = cost if d.get("xCost") else 0
	c.energy = int(c.energy) - cost
	c.cardsPlayed = int(c.cardsPlayed) + 1
	_run_effects(evaled.effects, c, player, target_id, rand, card)
	if d.get("type") == "attack" and "resolve" in c.powers:
		c.block = int(c.block) + 3
	if int(c.get("bastBlessing", 0)) > 0 and Cards.has_tag(d, "cat"):
		var bb: int = int(c.get("bastBlock", 5))
		var bs: int = int(c.get("bastStr", 1))
		c.block = int(c.block) + bb
		c.strength = int(c.strength) + bs
		c.floaters.append(_floater("+%d" % bb, "block", "player"))
		c.log.append("女神の加護: ブロック%d、筋力%d。" % [bb, bs])
	_finish_play(c, card, true if d.get("exhaust") else false)
	_check_over(c, player)
	var sfx: Array = ["attack"] if d.get("type") == "attack" else ["skill"]
	return {"error": null, "sfx": sfx}


static func _check_over(c: Dictionary, player: Dictionary) -> void:
	if int(player.hp) <= 0:
		c.result = "lose"
		c.phase = "over"
		c.log.append("肉体が、折れた。")
		return
	if int(player.sanity) <= 0:
		c.result = "lose"
		c.phase = "over"
		c.log.append("正気が、0になった。器がひび割れる。")
		return
	if living(c).size() == 0:
		c.result = "win"
		c.phase = "over"
		c.log.append("回廊は、しばらく静かだ。")


static func _apply_enemy_intent(intent: Dictionary, e: Dictionary, c: Dictionary, player: Dictionary, rand: Callable, sfx: Array) -> void:
	if intent.get("kind") == "attack":
		e.hadAttackThisTurn = true
		var hits: int = int(intent.get("hits", 1))
		var base: int = int(intent.get("damage", 0))
		var total_dealt := 0
		for i in hits:
			var n: int = _dmg_dealt(base, int(e.strength), int(e.weak))
			n = _dmg_taken(n, int(c.vulnerable))
			if int(player.sanity) <= 0:
				n += 2
			n = _incoming(n, c)
			var blocked: int = mini(int(c.block), n)
			c.block = int(c.block) - blocked
			if blocked > 0:
				c.blockLost = int(c.blockLost) + blocked
			var hp: int = n - blocked
			var reduced_hp: int = Equipment.apply_flat_defense(hp, float(c.equipmentStats.get("defense", 0)))
			player.hp = maxi(0, int(player.hp) - reduced_hp)
			total_dealt += reduced_hp
			c.floaters.append(_floater("-%d" % n, "dmg", "player"))
			if hp > 0:
				sfx.append("hurt")
			if blocked > 0:
				sfx.append("block")
			if reduced_hp > 0 and float(c.equipmentStats.get("thornDamage", 0)) > 0:
				e.hp = maxi(0, int(e.hp) - int(c.equipmentStats.thornDamage))
				c.floaters.append(_floater("-%d" % int(c.equipmentStats.thornDamage), "dmg", str(e.uid)))
			if c.equipmentStats.get("intangibleOnHit") and reduced_hp > 0 and int(c.intangible) == 0:
				c.intangible = int(c.intangible) + 1
		c.log.append("%sが%dダメージ。" % [Enemies.get_enemy(str(e.defId)).name, total_dealt])
	if intent.get("kind") == "defend" or intent.get("block"):
		e.block = int(e.block) + int(intent.get("block", 0))
		if intent.get("block"):
			c.log.append("%sがブロック%dを得た。" % [Enemies.get_enemy(str(e.defId)).name, int(intent.block)])
	if intent.get("strength"):
		e.strength = int(e.strength) + int(intent.strength)
	if intent.get("heal"):
		e.hp = mini(int(e.maxHp), int(e.hp) + int(intent.heal))
		c.floaters.append(_floater("+%d" % int(intent.heal), "heal", str(e.uid)))
	if intent.get("weak"):
		c.weak = int(c.weak) + int(intent.weak)
		c.log.append("%sに弱体%dを仕掛けられた。" % [Enemies.get_enemy(str(e.defId)).name, int(intent.weak)])
	if intent.get("vulnerable"):
		c.vulnerable = int(c.vulnerable) + int(intent.vulnerable)
		c.log.append("%sに脆弱%dを仕掛けられた。" % [Enemies.get_enemy(str(e.defId)).name, int(intent.vulnerable)])
	if intent.get("poison"):
		c.poison = int(c.poison) + int(intent.poison)
		c.log.append("%sに毒%dを付与された。" % [Enemies.get_enemy(str(e.defId)).name, int(intent.poison)])
	if intent.get("sanityDrain"):
		var reduced := Equipment.apply_flat_resist(int(intent.sanityDrain), float(c.equipmentStats.get("sanResist", 0)))
		player.sanity = maxi(0, int(player.sanity) - reduced)
		c.floaters.append(_floater("-%d" % reduced, "sanity", "player"))
		c.log.append("%sに正気を%d奪われた。" % [Enemies.get_enemy(str(e.defId)).name, reduced])
	if intent.get("dread"):
		for i in int(intent.dread):
			_insert_into_draw(c, _spawn_combat_card("dread"), rand)
		c.log.append("%sが恐怖を注ぎ込む。" % Enemies.get_enemy(str(e.defId)).name)
	if intent.get("seal"):
		c.sealed = intent.seal
		c.log.append("%sが%sを封じた。" % [Enemies.get_enemy(str(e.defId)).name, "攻撃" if intent.seal == "attack" else "技能"])


static func _enemy_act(e: Dictionary, c: Dictionary, player: Dictionary, rand: Callable, sfx: Array) -> void:
	if int(e.hp) <= 0:
		return
	e.block = 0
	e.hadAttackThisTurn = false
	if e.actionCardIds.size() == 0:
		if (not e.get("sealed")) or str(e.intent.get("kind")) != "attack":
			_apply_enemy_intent(e.intent, e, c, player, rand, sfx)
		else:
			c.log.append("%sの行動は封じられている。" % Enemies.get_enemy(str(e.defId)).name)
		e.sealed = null
		return
	for id in e.actionCardIds:
		var d := Cards.get_card(str(id))
		if e.get("sealed") and d.get("type") == e.sealed:
			c.log.append("%sの%sは封じられて不発に終わった。" % [Enemies.get_enemy(str(e.defId)).name, d.name])
			continue
		_apply_enemy_intent(EnemyAi.card_to_intent(d), e, c, player, rand, sfx)
	e.sealed = null


## combat.ts endTurn()
static func end_turn(c: Dictionary, player: Dictionary, rand: Callable) -> Array:
	var sfx: Array = []
	if c.phase != "player" or c.result != "ongoing":
		return sfx
	c.phase = "enemy"
	c.bastBlessing = 0
	var kept: Array = []
	var hand: Array = c.hand.duplicate()
	c.hand = []
	if int(c.retainHand) > 0:
		for i in int(c.retainHand):
			if hand.size() == 0:
				break
			kept.append(hand.pop_back())
		c.retainHand = 0
	for card in hand:
		var d := Cards.get_card(str(card.defId))
		if d.get("ethereal"):
			c.exhaust.append(card)
		else:
			_add_to_discard(c, card)
	c.hand = kept
	if int(c.weak) > 0:
		c.weak = int(c.weak) - 1
	if int(c.vulnerable) > 0:
		c.vulnerable = int(c.vulnerable) - 1
	c.sealed = null
	var has_bell := false
	for e in living(c):
		if Enemies.get_enemy(str(e.defId)).get("trait") == "bell":
			has_bell = true
			break
	if has_bell and int(c.block) > 0:
		c.log.append("鐘がブロックを砕いた。")
		c.floaters.append(_floater("破", "info", "player"))
		c.block = 0
	if int(c.cold) > 0:
		player.hp = maxi(1, int(player.hp) - int(c.cold))
		c.floaters.append(_floater("-%d" % int(c.cold), "dmg", "player"))
	if (not c.equipmentStats.get("poisonImmune")) and int(c.poison) > 0:
		var reduced := Equipment.apply_flat_resist(int(c.poison), float(c.equipmentStats.get("poisonResist", 0)))
		player.hp = maxi(1, int(player.hp) - reduced)
		c.floaters.append(_floater("毒%d" % reduced, "dmg", "player"))
	var heal_n := _apply_heal_bonus(int(c.equipmentStats.get("healPerTurn", 0)), float(c.equipmentStats.get("healBonusPct", 0)))
	if heal_n > 0:
		player.hp = mini(int(player.maxHp), int(player.hp) + heal_n)
		c.floaters.append(_floater("+%d" % heal_n, "heal", "player"))
	for e in living(c):
		if int(e.poison) > 0:
			e.hp = maxi(0, int(e.hp) - int(e.poison))
			c.floaters.append(_floater("毒%d" % int(e.poison), "dmg", str(e.uid)))
		if e.get("bound"):
			e.bound = 0
			c.log.append("%sは動けない。" % Enemies.get_enemy(str(e.defId)).name)
		else:
			_enemy_act(e, c, player, rand, sfx)
			if int(c.thornsVulnerable) > 0 and e.get("hadAttackThisTurn"):
				e.vulnerable = int(e.vulnerable) + int(c.thornsVulnerable)
		if int(e.weak) > 0:
			e.weak = int(e.weak) - 1
		if int(e.vulnerable) > 0:
			e.vulnerable = int(e.vulnerable) - 1
		_roll_next_action(e, rand)
	_maybe_choir(c, rand)
	_check_over(c, player)
	if c.result != "ongoing":
		return sfx
	if int(c.intangible) > 0:
		c.intangible = int(c.intangible) - 1
	var reflect: int = int(c.blockLost) if c.pendingPhase else 0
	c.pendingPhase = 0
	c.blockLost = 0
	c.attackSelfHurt = 0
	c.thornsVulnerable = 0
	c.phase = "player"
	c.turn = int(c.turn) + 1
	_handle_flee(c)
	if c.result != "ongoing":
		return sfx
	if c.equipmentStats.get("blockRetain"):
		pass
	elif int(c.keepBlock) > 0:
		c.keepBlock = int(c.keepBlock) - 1
	else:
		c.block = 0
	c.energy = maxi(0, int(c.maxEnergy) + int(c.energyNext) + int(c.equipmentStats.get("energyPerTurn", 0)))
	c.energyNext = 0
	var draw_n: int = maxi(0, _base_draw_count(c) - int(c.skipDraw))
	c.skipDraw = 0
	if "echo" in c.powers:
		var live := living(c)
		if live.size() > 0:
			var tgt = Mulberry32.pick_rand(live, rand)
			if tgt:
				var n := _dmg_dealt(4, int(c.strength), int(c.weak))
				_apply_to_enemy(tgt, n, c, rand)
	if reflect > 0:
		var live2 := living(c)
		if live2.size() > 0:
			var tgt2 = Mulberry32.pick_rand(live2, rand)
			if tgt2:
				_apply_to_enemy(tgt2, reflect, c, rand)
				c.log.append("遅延した力が還る。")
	draw_cards(c, draw_n, rand, player)
	_check_over(c, player)
	return sfx


static func _handle_flee(c: Dictionary) -> void:
	if int(c.turn) <= 2:
		return
	var fleeing: Array = []
	for e in living(c):
		if Enemies.get_enemy(str(e.defId)).get("trait") == "flee":
			fleeing.append(e)
	if fleeing.size() == 0:
		return
	for e in fleeing:
		e.hp = 0
		c.log.append("%sが逃げ去った。" % Enemies.get_enemy(str(e.defId)).name)
		c.floaters.append(_floater("逃走", "info", str(e.uid)))
	if living(c).size() == 0:
		c.result = "fled"
		c.phase = "over"


## combat.ts clearFloaters()
static func clear_floaters(c: Dictionary) -> void:
	c.floaters = []


static func _maybe_choir(c: Dictionary, rand: Callable) -> void:
	var live: Array = []
	for e in living(c):
		if Enemies.get_enemy(str(e.defId)).get("trait") == "choir":
			live.append(e)
	if live.size() != 1:
		return
	c.enemies.append(make_enemy("choir", int(c.floor), rand))
	c.log.append("塩の唱者が応える。")
	c.floaters.append(_floater("合唱", "info", "player"))


## combat.ts encounterIds()
static func encounter_ids(kind: String, floor: int, rand: Callable, bias: Array = []) -> Array:
	if kind == "boss":
		if floor >= 100:
			return ["yog_sothoth"]
		if floor >= 90:
			return ["iha"]
		if floor >= 80:
			return ["nyar"]
		if floor >= 70:
			return ["bell"]
		if floor >= 60:
			return ["warden"]
		if floor >= 50:
			return ["herald"]
		if floor >= 40:
			return ["flock", "flock"]
		if floor >= 30:
			return ["nurse"]
		if floor >= 20:
			return ["choir", "choir"]
		return ["priest"]
	if kind == "combat" and rand.call() < 0.03:
		return ["treasure_wanderer"]
	var VOID := ["migo", "shan", "starvamp", "colour"]
	var void_chance := 0.38 if floor >= 50 else (0.28 if floor >= 16 else (0.18 if floor >= 8 else 0.0))
	if void_chance and rand.call() < void_chance:
		if kind == "elite":
			return ["starvamp"] if rand.call() < 0.5 else [Mulberry32.pick_rand(VOID, rand), Mulberry32.pick_rand(["migo", "shan"], rand)]
		if rand.call() < (0.45 if floor >= 40 else 0.22):
			return [Mulberry32.pick_rand(VOID, rand), Mulberry32.pick_rand(VOID, rand)]
		return [Mulberry32.pick_rand(VOID, rand)]
	if kind == "elite":
		if floor >= 70:
			return ["spawn", "serpent"] if rand.call() < 0.5 else ["starveling", "byakhee"]
		if floor >= 40:
			return ["spawn"] if rand.call() < 0.5 else ["serpent"]
		if floor >= 20:
			return ["starveling"]
		return [Mulberry32.pick_rand(["coral", "byakhee", "fanatic"], rand)]
	var pool: Array
	if floor >= 80:
		pool = ["spawn", "serpent", "starveling"]
	elif floor >= 60:
		pool = ["spawn", "serpent", "byakhee"]
	elif floor >= 40:
		pool = ["serpent", "spawn", "coral"]
	elif floor >= 20:
		pool = ["acolyte", "drowned", "coral", "byakhee"]
	else:
		pool = ["acolyte", "drowned", "coral"]
	var double := 0.5 if floor >= 40 else (0.35 if floor >= 12 else 0.12)
	if not bias.is_empty():
		for arch in bias:
			var extra: Array = Enemies.combat_ids_for_archetype(str(arch))
			for enemy_id in extra:
				pool.append(enemy_id)
	if rand.call() < double:
		return [Mulberry32.pick_rand(pool, rand), Mulberry32.pick_rand(pool, rand)]
	return [Mulberry32.pick_rand(pool, rand)]


const POWER_TEXT := {
	"resolve": "攻撃を出すとブロックを得る",
	"echo": "ターン開始時、ランダムな敵にダメージ",
	"bloodOath": "正気を失うと筋力を得る",
	"goddessContract": "「猫」の効果の数字が2倍になる",
}
