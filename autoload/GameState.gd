extends Node

## ラン中の状態＋永続プロフィール＋画面遷移（実ソース src/game/store.ts の GameStore、
## src/game/profile.ts の PlayerProfile、src/components/game/GameApp.tsx のシーン切替
## switch文 相当）。CollectionData（カード・ルーン・装備・デッキの実体、useCollectionStore
## 相当）とは別の永続化層。混同しないこと。
##
## プロフィール（永続フィールド群）の計算式・保存/読込は scripts/profile.gd (class_name Profile)
## に委譲し、ここで再実装しない。二重管理は値のズレの温床になる（引き継ぎ資料の地雷リスト参照）。
##
## 参照: reference/cthulhu-spire-main/src/game/store.ts
##       reference/cthulhu-spire-main/src/game/profile.ts
##       reference/cthulhu-spire-main/src/game/floors.ts
##       reference/cthulhu-spire-main/src/game/equipment.ts
##       reference/cthulhu-spire-main/src/game/grimoire.ts
##       reference/cthulhu-spire-main/src/game/smith.ts
##       reference/cthulhu-spire-main/src/components/game/GameApp.tsx
##
## 実ソースの Scene 型のうち "prologue" / "map" / "prepare" / "between" は
## GameApp.tsx のswitch文には存在するが、どの遷移関数からも実際にはセットされない
## 到達不能パス（デッドコード）と確認済みのため、本移植では再現しない。

## GameApp.tsx のシーン→コンポーネント対応を、シーン→シーンファイルパスとして再現
const SCENE_PATHS := {
	"title": "res://scenes/main_menu/MainMenu.tscn",
	"hub": "res://scenes/hub/Hub.tscn",
	"combat": "res://scenes/combat/Combat.tscn",
	"reward": "res://scenes/reward/Reward.tscn",
	"event": "res://scenes/event/Event.tscn",
	"rest": "res://scenes/rest/Rest.tscn",
	"victory": "res://scenes/end/End.tscn",
	"defeat": "res://scenes/end/End.tscn",
	"shatter": "res://scenes/end/Shatter.tscn",
	"blessing": "res://scenes/blessing/Blessing.tscn",
	"dream_gate": "res://scenes/dream_gate/DreamGate.tscn",
	"dream_title": "res://scenes/main_menu/DreamTitle.tscn",
}

# --- PlayerProfile 相当（拠点に永続、次ランへ引き継ぐ）。実体は Profile.gd 参照 ---
var player_name: String = ""
var stats: Dictionary = Profile.empty_stats()
var best_floor: int = 0
var wins: int = 0
var runs: int = 0
var earned_points: int = 0
var unspent_points: int = 0
var madness: int = 0
var profile_sanity = null  ## 次ラン開始時に引き継ぐ正気値。null＝未設定（満タンから開始）
var seen_rlyeh: bool = false
var grimoire_read: Array = []
var equipped: Dictionary = {}  ## slot(String) -> EquipmentInstance(Dictionary, equipment.gd参照)
var shells: int = 0
var equipment_presets: Dictionary = {}
var starter_chosen: bool = false

## "waking" | "dream"。DreamTitle 外宇宙贈り物フローで "dream" をセットする。
var realm: String = "waking"
## 外宇宙スターター付与予約（シェル段階では中身はプレースホルダ／空）。
var pending_outer_starter: Array = []

## 後続で Cards.get_card 検証してから付与する想定。空＝付与スキップ（クラッシュ防止）。
const OUTER_STARTER_IDS_PLACEHOLDER: Array = []

# --- GameStore 相当（ラン中のみ有効） ---
var scene: String = "title"
var seed: int = 0
var rng: Mulberry32 = null
var character: String = ""  ## "investigator" | "cultist" | ""（未選択）
var hp: int = 0
var max_hp: int = 0
var sanity: int = 0
var max_sanity: int = 0
var deck: Array = []
var run_strength: int = 0
var extra_energy_next: int = 0
var act: int = 1
var run_floors: Array = []
var floor: int = 0  ## 0 = 拠点（村落）に滞在中でラン未開始。1以上でラン中の現在階層
var combat = null
var reward = null
var reward_shells: int = 0
var event = null
var rest_mode: String = ""  ## visitVillage() の room 相当："", "hub", "inn", "smith"
var village = null
var toast: String = ""
var floor_kind: String = ""
var run_blessings: Array = []
var encounter_bias: Array = []
var blessing_choices: Array = []
var _force_first_drowned: bool = false


func _ready() -> void:
	rng = Mulberry32.new(randi())
	_load_profile()


## profile.ts の loadProfile() をGameStateのフィールドへ展開する（store.tsの`profile: loadProfile()`相当）
func _load_profile() -> void:
	var p := Profile.load_profile()
	player_name = p.player_name
	stats = p.stats
	best_floor = p.best_floor
	wins = p.wins
	runs = p.runs
	earned_points = p.earned_points
	unspent_points = p.unspent_points
	madness = p.madness
	profile_sanity = p.sanity
	seen_rlyeh = p.seen_rlyeh
	grimoire_read = p.grimoire_read
	equipped = p.equipped
	shells = p.shells
	equipment_presets = p.equipment_presets
	starter_chosen = p.starter_chosen


## store.ts の persist(profile) 相当。呼び出し箇所は実ソースの各アクションのpersist()呼び出しに対応。
func _persist_profile() -> void:
	Profile.save_profile({
		"player_name": player_name,
		"stats": stats,
		"best_floor": best_floor,
		"wins": wins,
		"runs": runs,
		"earned_points": earned_points,
		"unspent_points": unspent_points,
		"madness": madness,
		"sanity": profile_sanity,
		"seen_rlyeh": seen_rlyeh,
		"grimoire_read": grimoire_read,
		"equipped": equipped,
		"shells": shells,
		"equipment_presets": equipment_presets,
		"starter_chosen": starter_chosen,
	})


func add_shells(amount: int) -> void:
	if amount > 0:
		shells += amount
		_persist_profile()


func spend_shells(amount: int) -> bool:
	if amount <= 0 or shells < amount:
		return false
	shells -= amount
	_persist_profile()
	return true


## store.ts の CARD_PACK_PRICE
const CARD_PACK_PRICE := 150

## store.ts DROP_RATES / ITEM_COUNT_WEIGHTS
const DROP_RATES := {
	"combat": {"chance": 0.5, "weights": {"card": 0.6, "ticket": 0.4}},
	"elite": {"chance": 0.9, "weights": {"card": 0.4, "ticket": 0.6}},
	"boss": {"chance": 1.0, "weights": {"card": 0.2, "ticket": 0.8}},
}

const ITEM_COUNT_WEIGHTS := {
	"combat": {1: 0.8, 2: 0.2},
	"elite": {1: 0.6, 2: 0.3, 3: 0.1},
	"boss": {1: 0.3, 2: 0.4, 3: 0.3},
}

const ALL_TICKET_BOSS_CHANCE := 0.05


## store.ts の buyCardPack()。貝殻CARD_PACK_PRICEで通常パックを購入し、
## Cards.weighted_card()（所持数が少ないカードほど出やすい重み付け）で4枚引く。
## 戻り値は引いたカードのdefId配列（実ソースの lastPackResult 相当）。
## 購入失敗（貝殻不足）時は toast をセットして空配列を返す。
func buy_card_pack() -> Array:
	if shells < CARD_PACK_PRICE:
		toast = "貝殻が足りない。"
		return []
	var owner: String = character if character != "" else starter_path(stats)
	var rand := Callable(self, "_rand")
	var result: Array = []
	for i in range(4):
		var card := Cards.weighted_card(owner, rand)
		var def_id := str(card.get("defId", ""))
		CollectionData.add_loot_card(def_id)
		result.append(def_id)
	shells -= CARD_PACK_PRICE
	_persist_profile()
	toast = "通常パックを開封した。"
	return result


## store.ts の sellItems({cardIds, equipmentUids, runeIds})。装着中の装備・ソケット中の
## ルーンは（呼び出し元が既に除外している前提だが）念のためここでも除外する。
## 合計0円なら何もしない。
func sell_items(card_ids: Array, equipment_uids: Array, rune_ids: Array) -> void:
	var equipped_uids: Dictionary = {}
	for item in equipped.values():
		if item != null:
			equipped_uids[str(item.get("uid", ""))] = true
	var socketed_rune_ids: Dictionary = {}
	for inst in CollectionData.inventory.equipment:
		for rid in inst.get("socketed_runes", []):
			if rid != null:
				socketed_rune_ids[str(rid)] = true

	var total := 0
	var sell_card_ids: Array = []
	for id in card_ids:
		for c in CollectionData.inventory.cards:
			if str(c.get("instance_id", "")) == str(id):
				total += Smith.card_sell_price(Cards.get_card(str(c.get("base_card_id", ""))))
				sell_card_ids.append(str(id))
				break

	var sell_equipment_uids: Array = []
	for uid in equipment_uids:
		if equipped_uids.has(str(uid)):
			continue
		for inst in CollectionData.inventory.equipment:
			if str(inst.get("uid", "")) == str(uid):
				total += Smith.equipment_sell_price(inst)
				sell_equipment_uids.append(str(uid))
				break

	var sell_rune_ids: Array = []
	for rid in rune_ids:
		if socketed_rune_ids.has(str(rid)):
			continue
		for rune in CollectionData.inventory.runes:
			if str(rune.get("id", "")) == str(rid):
				total += Smith.rune_sell_price(rune)
				sell_rune_ids.append(str(rid))
				break

	if total == 0:
		return
	CollectionData.remove_cards(sell_card_ids)
	CollectionData.remove_equipment(sell_equipment_uids)
	CollectionData.remove_runes(sell_rune_ids)
	shells += total
	_persist_profile()
	toast = "貝殻+%d" % total


## profile.ts の derivedVitals().maxHp
func derived_max_hp() -> int:
	return Profile.derived_vitals(stats, madness).max_hp


## profile.ts の derivedVitals().maxSanity
func derived_max_sanity() -> int:
	return Profile.derived_vitals(stats, madness).max_sanity


## profile.ts の derivedVitals().energy
func derived_energy() -> int:
	return Profile.derived_vitals(stats, madness).energy


## profile.ts の madnessPenalty()
func madness_penalty() -> int:
	return Profile.madness_penalty(madness)


## profile.ts の totalPoints()
func total_points() -> int:
	return Profile.total_points(best_floor)


## store.ts の setStat(key, value)。予算(totalPoints)を超える配分は無視する。
func set_stat(key: String, value: int) -> void:
	var next: int = max(Profile.STAT_MIN, value)
	var others: int = Profile.stat_sum(stats) - int(stats.get(key, 0))
	var budget := total_points()
	if others + next > budget:
		return
	stats[key] = next
	stats = Profile.clamp_stats(stats)
	earned_points = budget
	unspent_points = max(0, budget - Profile.stat_sum(stats))
	_persist_profile()


## store.ts の starterPath(stats)
func starter_path(p_stats: Dictionary) -> String:
	return "investigator" if int(p_stats.get("hp", 0)) >= int(p_stats.get("san", 0)) else "cultist"


# ============================================================
# シーン遷移（GameApp.tsx のレンダー切替 + store.ts の各アクション相当）
# ============================================================

func goto_scene(tree: SceneTree, next_scene: String) -> void:
	scene = next_scene
	tree.change_scene_to_file(SCENE_PATHS[next_scene])
	AudioManager.play_bgm_for_scene(next_scene)


## store.ts の begin()：プレイ開始（タイトル→拠点）。プロフィールを再読込しランテーブルを生成する。
## 所持カード／枠テクスチャを ArtCache でウォームしてから Hub へ遷移する（売却・デッキの冷ロード回避）。
func begin(tree: SceneTree) -> void:
	_load_profile()
	seed = randi()
	rng = Mulberry32.new(seed)
	run_floors = []
	floor = 0
	toast = ""
	## CollectionData は Autoload 済み。同期ウォーム（所持枚数が多くてもフレーム数枚程度）。
	ArtCache.warm_for_collection()
	goto_scene(tree, "hub")


## store.ts の toTitle()
func to_title(tree: SceneTree) -> void:
	goto_scene(tree, "title")


## store.ts の startRun()。
## 実際はプレイヤー名・デッキ枚数のバリデーションを行うが、
## 名前入力/デッキ編成の必須チェックUIが未実装のため、それらのバリデーションのみ省略する
## （デッキが空でも実行は継続する。フェーズB以降で追加）。
## runs加算・madness蓄積による正気0シャター判定・初回ルルイエ強制遭遇は実ソース通り実装する。
func start_run(tree: SceneTree) -> void:
	if CollectionData.deck_size(CollectionData.decks.get(CollectionData.active_deck, {})) < CollectionData.MIN_RUN_DECK and not starter_chosen:
		toast = "最初のデッキを選んでください。"
		return
	runs += 1
	_persist_profile()

	character = starter_path(stats)
	var vitals := Profile.derived_vitals(stats, madness)

	max_hp = vitals.max_hp
	hp = max_hp

	max_sanity = vitals.max_sanity
	if max_sanity <= 0:
		_shatter(tree)
		return
	sanity = max_sanity if profile_sanity == null else min(int(profile_sanity), max_sanity)
	if sanity <= 0:
		_shatter(tree)
		return

	run_strength = int(vitals.strength)
	extra_energy_next = 0
	act = 1
	deck = loadout_deck()
	run_floors = []
	run_blessings = []
	encounter_bias = []
	blessing_choices = []
	floor_kind = ""
	_force_first_drowned = false

	if not seen_rlyeh:
		seen_rlyeh = true
		_persist_profile()
		_force_first_drowned = true

	enter_floor(tree, 1)


## start_run()/turn_grimoire_page() 共通のshatter処理
## （正気0でwipeProfile()するstore.ts側の各箇所の重複ロジックをまとめたヘルパー。
## 実ソースにこの関数自体は存在しないが、lose_combat()と合わせて3箇所で同じ処理を
## 繰り返さないための移植時の整理。挙動はwipeProfile()呼び出し箇所と完全に同一）。
func _shatter(tree: SceneTree) -> void:
	Profile.wipe_profile()
	_load_profile()
	player_name = ""
	reset_run()
	goto_scene(tree, "shatter")


## store.ts の enterFloor(floor, carry) 相当。
## ランテーブルの終端を超えたら victory、それ以外は spec.type に応じて
## combat/elite/boss→戦闘、rest→休憩、それ以外→予兆(event) に振り分ける。
func enter_floor(tree: SceneTree, next_floor: int) -> void:
	if next_floor > Floors.DEMO_MAX_FLOOR:
		best_floor = max(best_floor, floor)
		var budget := Profile.total_points(best_floor)
		earned_points = budget
		unspent_points = max(0, budget - Profile.stat_sum(stats))
		wins += 1
		profile_sanity = sanity
		_persist_profile()
		combat = null
		reward = null
		reward_shells = 0
		event = null
		rest_mode = ""
		goto_scene(tree, "victory")
		return

	floor = next_floor
	combat = null
	reward = null
	reward_shells = 0
	event = null
	rest_mode = ""
	blessing_choices = []

	var kind: String = Floors.type_for(floor, rng)
	var enemy_ids: Array = []
	if _force_first_drowned and floor == 1:
		_force_first_drowned = false
		kind = "combat"
		enemy_ids = ["drowned"]
	floor_kind = kind

	if kind == "combat" or kind == "elite" or kind == "boss":
		if enemy_ids.is_empty():
			enemy_ids = CombatLogic.encounter_ids(kind, floor, Callable(self, "_rand"), encounter_bias)
		combat = {"floor": floor, "kind": kind, "enemy_ids": enemy_ids}
		goto_scene(tree, "combat")
	elif kind == "rest":
		rest_mode = "hub"
		village = {"smith": Smith.make_smith(rng)}
		goto_scene(tree, "rest")
	else:
		var ev: Dictionary = Events.pick_event(Callable(self, "_rand"))
		event = ev
		goto_scene(tree, "event")


func finish_advance(tree: SceneTree) -> void:
	if _should_offer_blessing():
		_open_blessing(tree)
		return
	_advance_after_blessing(tree)


func _should_offer_blessing() -> bool:
	return floor > 0 and floor % 5 == 0 and floor < Floors.DEMO_MAX_FLOOR


func _open_blessing(tree: SceneTree) -> void:
	blessing_choices = Blessings.roll_choices(run_blessings, rng)
	goto_scene(tree, "blessing")


func choose_blessing(tree: SceneTree, blessing_id: String) -> void:
	var def: Dictionary = Blessings.get_def(blessing_id)
	if def.is_empty():
		_advance_after_blessing(tree)
		return
	run_blessings.append(blessing_id)
	var bias: String = str(def.get("bias", ""))
	if bias != "":
		encounter_bias.append(bias)
	toast = "%sを得た。" % str(def.get("name", blessing_id))
	blessing_choices = []
	_advance_after_blessing(tree)


func _advance_after_blessing(tree: SceneTree) -> void:
	if floor_kind == "boss" and floor % 10 == 0 and floor < Floors.DEMO_MAX_FLOOR:
		best_floor = max(best_floor, floor)
		var budget := Profile.total_points(best_floor)
		earned_points = budget
		unspent_points = max(0, budget - Profile.stat_sum(stats))
		profile_sanity = sanity
		_persist_profile()
		toast = "%sを越えた" % Floors.layer_label(floor)
		combat = null
		reward = null
		reward_shells = 0
		event = null
		goto_scene(tree, "hub")
		return
	if floor >= Floors.DEMO_MAX_FLOOR:
		best_floor = max(best_floor, floor)
		wins += 1
		profile_sanity = sanity
		_persist_profile()
		combat = null
		reward = null
		reward_shells = 0
		event = null
		goto_scene(tree, "victory")
		return
	enter_floor(tree, floor + 1)


## store.ts の claimReward()（reward画面の「次へ進む」）。
func claim_reward(tree: SceneTree) -> void:
	var rewards: Array = reward if reward is Array else []
	var labels: Array = []
	for offer in rewards:
		if not (offer is Dictionary):
			continue
		var kind: String = str(offer.get("kind", ""))
		if kind == "card":
			var card: Dictionary = offer.get("card", {})
			var def_id: String = str(card.get("defId", ""))
			if CollectionData.add_loot_card(def_id):
				labels.append(str(Cards.get_card(def_id).get("name", def_id)))
		elif kind == "ticket":
			var ticket: String = str(offer.get("ticket", ""))
			CollectionData.add_pack_ticket(ticket)
			labels.append("%sのパックチケット" % str(CollectionData.PACK_TICKET_LABELS.get(ticket, ticket)))
	toast = "何も見つからなかった。" if labels.is_empty() else "%sを戦利品として持ち帰った。" % "・".join(labels)
	_persist_profile()
	reward = null
	reward_shells = 0
	finish_advance(tree)


## store.ts の resolveFlee()（宝殻の徘徊者からの逃走成立後）
func resolve_flee(tree: SceneTree) -> void:
	toast = "宝殻の徘徊者は、逃げ去った。"
	finish_advance(tree)


## store.ts の resolveEvent(choiceId)。数値は events.ts / store.ts の分岐を忠実移植。
func resolve_event(tree: SceneTree, choice_id: String) -> void:
	var ev: Dictionary = event if event is Dictionary else {}
	var event_id: String = str(ev.get("id", ""))
	if event_id == "tome":
		if choice_id == "read":
			sanity = max(0, sanity - 8)
			for card in deck:
				if not card.get("upgraded", false):
					card.upgraded = true
					break
			CollectionData.add_loot_card("tome")
			toast = "頁が、瞳の裏に残る。正気-8。禁断の書を戦利品として持ち帰った。"
		else:
			toast = "本は、本の文法に任せる。"
	elif event_id == "well":
		if choice_id == "drink":
			hp = mini(max_hp, hp + 18)
			sanity = max(0, sanity - 7)
			toast = "水ではなかった。体力+18、正気-7。"
		else:
			hp = mini(max_hp, hp + 8)
			sanity = mini(max_sanity, sanity + 4)
			toast = "手が、きれいになる。体力+8、正気+4。"
	elif event_id == "cult":
		if choice_id == "kneel":
			sanity = max(0, sanity - 10)
			var ticket: String = _reward_ticket_archetype()
			CollectionData.add_pack_ticket(ticket)
			toast = "%sのパックチケットを渡された。正気-10。" % str(CollectionData.PACK_TICKET_LABELS.get(ticket, ticket))
		else:
			hp = max(1, hp - 8)
			sanity = mini(max_sanity, sanity + 6)
			toast = "名を口にしなかった。体力-8、正気+6。"
	elif event_id == "mirror":
		if choice_id == "follow":
			extra_energy_next = 2
			toast = "もう一人の自分が、最初のターンを払う。"
		else:
			hp = max(1, hp - 10)
			run_strength += 2
			toast = "肺にガラス。体力-10。沈降中、筋力+2。"
	_persist_profile()
	event = null
	finish_advance(tree)


## store.ts の leaveVillage()（RestView VillageHubの「次の層へ」）
func leave_village(tree: SceneTree) -> void:
	rest_mode = ""
	village = null
	if _should_offer_blessing():
		_open_blessing(tree)
		return
	enter_floor(tree, floor + 1)


## store.ts の visitVillage(room)（RestView内のサブ画面遷移。sceneは"rest"のまま）
func visit_village(room: String) -> void:
	rest_mode = room


## store.ts の resumeDescent()（Hub中継点の「次の層へ沈む」）
func resume_descent(tree: SceneTree) -> void:
	if floor <= 0:
		return
	enter_floor(tree, floor + 1)


## store.ts の extractToHub()（Hub中継点の「拠点へ帰還」／ヘッダーの「帰還」）
func extract_to_hub(tree: SceneTree) -> void:
	var left_floor := floor
	best_floor = max(best_floor, floor)
	var budget := Profile.total_points(best_floor)
	earned_points = budget
	unspent_points = max(0, budget - Profile.stat_sum(stats))
	profile_sanity = sanity
	_persist_profile()
	reset_run()
	toast = "%sから帰還した" % Floors.layer_label(left_floor)
	goto_scene(tree, "hub")


## store.ts の giveUp()（EndView「拠点へ戻る」／victory画面のボタン）。
## 実ソースでは victory 画面のボタン表記が「タイトルへ戻る」なのに実際は scene を
## "hub" にする食い違いがあるが、これは実装ミスと判断し、Godot版ではボタン表記を
## 「帰還」に修正した（End.gd参照）。give_up()自体の動作（hubへ戻る）は変更していない。
func give_up(tree: SceneTree) -> void:
	profile_sanity = sanity
	_persist_profile()
	reset_run()
	goto_scene(tree, "hub")


## store.ts の acceptShatter()（ShatterView「タイトル」）。
## wipeProfile()自体は lose_combat() 側（実ソースのpresentCombat lose分岐相当）で
## 既に実行済みのため、ここでは実ソース同様 loadProfile() の再読込のみ行う。
## reset_run() は従来どおり。タイトルへは行かず、瞼の先の螺旋階段へ渡す。
func accept_shatter(tree: SceneTree) -> void:
	_load_profile()
	reset_run()
	player_name = ""
	goto_scene(tree, "dream_gate")


## 戦闘勝利。store.ts presentCombat win 分岐：貝殻加算のあと makeRewards() で報酬画面へ。
func win_combat(tree: SceneTree) -> void:
	var treasure: bool = _had_treasure_wanderer()
	var gained: int = _roll_shells()
	if treasure:
		gained *= 3
	if gained > 0:
		shells += gained
		_persist_profile()
		toast = "きれいな貝殻 +%d" % gained
	reward_shells = gained
	reward = _make_rewards()
	goto_scene(tree, "reward")


## store.ts の markDefeat() 相当：最深階層・獲得ポイント・正気を更新して永続化する。
func _mark_defeat() -> void:
	best_floor = max(best_floor, floor)
	var budget := Profile.total_points(best_floor)
	earned_points = budget
	unspent_points = max(0, budget - Profile.stat_sum(stats))
	profile_sanity = sanity
	_persist_profile()


## 戦闘敗北（フェーズAではカード無しのダミー）。
## markDefeat()相当でプロフィールを更新後、正気0（かつ狂信者フルセット未装備）なら
## shatter（wipeProfile）、それ以外は defeat へ。
func lose_combat(tree: SceneTree) -> void:
	_mark_defeat()
	if sanity <= 0 or max_sanity <= 0:
		_shatter(tree)
	else:
		goto_scene(tree, "defeat")


## grimoire.ts の nextUnread() + store.ts の turnGrimoirePage() 相当。
## 図鑑（The All）を1頁読み進める：未読の章が無ければ何もしない。
## 狂気+MADNESS_STEP・対応カードIDをgrimoire_readへ追加・正気を新最大値でクランプする。
## 正気0（かつ狂信者フルセット未装備）になる場合はプロフィール全消去（shatter）。
func turn_grimoire_page(tree: SceneTree) -> void:
	var next = Grimoire.next_unread(grimoire_read)
	if next == null or next.get("card_id") == null:
		return
	var prev_max: int = Profile.derived_vitals(stats, madness).max_sanity
	var new_madness: int = madness + Profile.MADNESS_STEP
	var new_read: Array = grimoire_read.duplicate()
	new_read.append(next.card_id)
	var max_sanity_next: int = Profile.derived_vitals(stats, new_madness).max_sanity
	var cur: int = prev_max if profile_sanity == null else int(profile_sanity)
	var new_sanity: int = max(0, min(cur, max_sanity_next))
	if max_sanity_next <= 0 or new_sanity <= 0:
		_shatter(tree)
		return
	madness = new_madness
	grimoire_read = new_read
	profile_sanity = max(1, new_sanity)
	_persist_profile()


func _rand() -> float:
	return rng.next_float()


## cardEvaluator.ts loadoutDeck() 相当。未編成なら調査員スターターを使う。
func loadout_deck() -> Array:
	var out: Array = []
	var counts: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	if counts.is_empty():
		var starter: Array = ["strike", "strike", "strike", "strike", "strike", "ward", "ward", "ward", "ward", "study"]
		if character == "cultist":
			starter = ["lash", "lash", "lash", "lash", "lash", "sigil", "sigil", "sigil", "sigil", "whisper"]
		for id in starter:
			out.append(Cards.make_card(str(id)))
		return out
	for card_id in counts.keys():
		if not Cards.CARDS.has(card_id):
			continue
		for i in int(counts[card_id]):
			out.append(Cards.make_card(str(card_id)))
	return out


## 戦闘中に手札へ生えたカード（猫など）はランデッキへ残さない。
## 強化（upgraded/forge）は探索開始デッキの実体に載っているので、そちらを優先して残す。
func prune_run_deck() -> void:
	var caps: Dictionary = {}
	for card in loadout_deck():
		var def_id: String = str(card.get("defId", ""))
		caps[def_id] = int(caps.get(def_id, 0)) + 1
	var grouped: Dictionary = {}
	for card in deck:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if card.get("combatSpawn", false):
			continue
		var def_id: String = str(card.get("defId", ""))
		var def: Dictionary = Cards.get_card(def_id)
		if str(def.get("type", "")) == "status":
			continue
		if not grouped.has(def_id):
			grouped[def_id] = []
		var copies: Array = grouped[def_id]
		copies.append(card)
		grouped[def_id] = copies
	var kept: Array = []
	for def_id in grouped.keys():
		var copies: Array = grouped[def_id]
		copies.sort_custom(_prefer_upgraded_copy)
		var cap: int = int(caps.get(def_id, 0))
		var n: int = mini(copies.size(), cap)
		for i in n:
			kept.append(copies[i])
	deck = kept


func _prefer_upgraded_copy(a: Dictionary, b: Dictionary) -> bool:
	var a_score: int = (2 if a.get("upgraded", false) else 0) + (1 if float(a.get("forge", 0.0)) > 0.0 else 0)
	var b_score: int = (2 if b.get("upgraded", false) else 0) + (1 if float(b.get("forge", 0.0)) > 0.0 else 0)
	return a_score > b_score


## store.ts hookFrom() 相当。CombatLogic が HP/SAN を直接書き換える。
func player_hook() -> Dictionary:
	return {
		"hp": hp,
		"maxHp": max_hp,
		"sanity": sanity,
		"maxSanity": max_sanity,
		"extraStrength": run_strength,
		"extraEnergyNext": extra_energy_next,
		"baseEnergy": derived_energy(),
		"blessings": run_blessings,
	}


func apply_player_hook(hook: Dictionary) -> void:
	hp = int(hook.hp)
	max_hp = int(hook.maxHp)
	sanity = int(hook.sanity)
	max_sanity = int(hook.get("maxSanity", max_sanity))


## store.ts markStarterChosen()
func mark_starter_chosen() -> void:
	starter_chosen = true
	_persist_profile()


## store.ts rollShells()
func _roll_shells() -> int:
	if floor_kind == "boss":
		if floor % 50 == 0:
			return 40 + int(rng.next_float() * 21)
		return 9 + int(rng.next_float() * 7)
	var n: int = 1
	if combat is Dictionary:
		n = (combat.get("enemies", []) as Array).size()
		if n <= 0:
			n = 1
	var total := 0
	for i in n:
		total += int(rng.next_float() * 3)
	return total


func _had_treasure_wanderer() -> bool:
	if not (combat is Dictionary):
		return false
	for e in combat.get("enemies", []):
		if str(e.get("defId", "")) == "treasure_wanderer":
			return true
	return false


## store.ts encounterArchetype()
func _encounter_archetype() -> String:
	var counts: Dictionary = {}
	if not (combat is Dictionary):
		return ""
	for e in combat.get("enemies", []):
		var def: Dictionary = Enemies.get_enemy(str(e.get("defId", "")))
		var arch: String = str(def.get("archetype", ""))
		if arch == "":
			continue
		counts[arch] = int(counts.get(arch, 0)) + 1
	if counts.is_empty():
		return ""
	var best := 0
	for n in counts.values():
		if int(n) > best:
			best = int(n)
	var top: Array = []
	for arch in counts.keys():
		if int(counts[arch]) == best:
			top.append(str(arch))
	return str(Mulberry32.pick(top, rng))


## store.ts rewardTicketArchetype()
func _reward_ticket_archetype() -> String:
	if not encounter_bias.is_empty():
		return str(Mulberry32.pick(encounter_bias, rng))
	var arch: String = _encounter_archetype()
	if arch != "" and arch != "generic" and arch != "all":
		return arch
	var pool: Array = []
	for a in CollectionData.PACK_TICKET_ARCHETYPES:
		if str(a) != "all":
			pool.append(str(a))
	if pool.is_empty():
		return "fanatic"
	return str(Mulberry32.pick(pool, rng))


## store.ts makeRewards() — 装備／ルーンは出さない。カードかパックチケットのみ。
func _make_rewards() -> Array:
	if _had_treasure_wanderer():
		return [
			{"kind": "ticket", "ticket": _reward_ticket_archetype()},
			{"kind": "ticket", "ticket": _reward_ticket_archetype()},
			{"kind": "ticket", "ticket": _reward_ticket_archetype()},
		]
	var kind: String = "boss" if floor_kind == "boss" else ("elite" if floor_kind == "elite" else "combat")
	var table: Dictionary = DROP_RATES[kind]
	var rewards: Array = []
	if rng.next_float() >= float(table.get("chance", 0.5)):
		rewards = [{"kind": "none"}]
	else:
		var count: int = int(Mulberry32.weighted_pick(ITEM_COUNT_WEIGHTS[kind], Callable(self, "_rand")))
		var weights: Dictionary = table.get("weights", {"ticket": 1.0})
		for i in count:
			var category: String = str(Mulberry32.weighted_pick(weights, Callable(self, "_rand")))
			if category == "card":
				rewards.append(_reward_card_offer())
			else:
				rewards.append({"kind": "ticket", "ticket": _reward_ticket_archetype()})
	if kind == "boss" and rng.next_float() < ALL_TICKET_BOSS_CHANCE:
		if rewards.size() == 1 and str(rewards[0].get("kind", "")) == "none":
			rewards = [{"kind": "ticket", "ticket": "all"}]
		else:
			rewards.append({"kind": "ticket", "ticket": "all"})
	return rewards


func _reward_card_offer() -> Dictionary:
	var owner: String = character if character != "" else starter_path(stats)
	var card: Dictionary = Cards.weighted_card(owner, Callable(self, "_rand"))
	return {"kind": "card", "card": card}


## extractToHub() / giveUp() / accept_shatter() 共通のラン状態リセット
func reset_run() -> void:
	floor = 0
	run_floors = []
	floor_kind = ""
	run_blessings = []
	encounter_bias = []
	blessing_choices = []
	_force_first_drowned = false
	combat = null
	reward = null
	reward_shells = 0
	event = null
	rest_mode = ""
	village = null
	deck = []
	run_strength = 0
	extra_energy_next = 0
	hp = 0
	max_hp = 0
	sanity = 0
	max_sanity = 0


# ============================================================
# 装備管理（store.ts の equipItem/unequipSlot/equipmentPreset系 相当）。
# CollectionData.inventory.equipment が実体、equipped はそこから見た「装着中」の参照。
# ============================================================

## store.ts の equipItem()
func equip_item(equipment_uid: String) -> void:
	var inst := CollectionData.peek_equipment(CollectionData.inventory.equipment, equipment_uid)
	if inst.is_empty():
		return
	var def := Equipment.get_equipment(inst.get("def_id", ""))
	if def.is_empty():
		return
	equipped[def.get("slot", "")] = inst
	_persist_profile()


## store.ts の unequipSlot()
func unequip_slot(slot: String) -> void:
	if not equipped.has(slot):
		return
	equipped.erase(slot)
	_persist_profile()


## store.ts の saveEquipmentPreset()：現在の装着状況をプリセット名で保存する
func save_equipment_preset(preset_name: String) -> void:
	var trimmed := preset_name.strip_edges()
	if trimmed.is_empty():
		return
	var preset: Dictionary = {}
	for slot in Equipment.EQUIPMENT_SLOTS:
		var inst = equipped.get(slot)
		if inst != null:
			preset[slot] = inst.get("uid", "")
	equipment_presets[trimmed] = preset
	_persist_profile()


## store.ts の applyEquipmentPreset()。インベントリに存在しない装備は無視し、toastで通知する。
func apply_equipment_preset(preset_name: String) -> void:
	if not equipment_presets.has(preset_name):
		return
	var preset: Dictionary = equipment_presets[preset_name]
	var missing := false
	for slot in Equipment.EQUIPMENT_SLOTS:
		if not preset.has(slot):
			continue
		var inst := CollectionData.peek_equipment(CollectionData.inventory.equipment, preset[slot])
		if not inst.is_empty():
			equipped[slot] = inst
		else:
			missing = true
	_persist_profile()
	if missing:
		toast = "一部の装備が見つかりませんでした。"


## store.ts の deleteEquipmentPreset()
func delete_equipment_preset(preset_name: String) -> void:
	if not equipment_presets.has(preset_name):
		return
	equipment_presets.erase(preset_name)
	_persist_profile()


## store.ts の renameEquipmentPreset()。成功したらtrue。
func rename_equipment_preset(old_name: String, new_name: String) -> bool:
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty() or equipment_presets.has(trimmed) or not equipment_presets.has(old_name):
		return false
	equipment_presets[trimmed] = equipment_presets[old_name]
	equipment_presets.erase(old_name)
	_persist_profile()
	return true


## store.ts の syncEquippedFromInventory()（モジュールトップレベル関数）相当。
## ルーンの着脱等でinventory側の装備インスタンスが更新された後、
## GameState.equipped側の参照（コピー）を最新化するために呼ぶ。
func sync_equipped_from_inventory(equipment_uid: String) -> void:
	var target_slot := ""
	for slot in equipped.keys():
		var inst = equipped[slot]
		if inst != null and inst.get("uid", "") == equipment_uid:
			target_slot = slot
			break
	if target_slot.is_empty():
		return
	var latest := CollectionData.peek_equipment(CollectionData.inventory.equipment, equipment_uid)
	if latest.is_empty():
		return
	equipped[target_slot] = latest
	_persist_profile()
