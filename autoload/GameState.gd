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
var event = null
var rest_mode: String = ""  ## visitVillage() の room 相当："", "hub", "inn", "smith"
var village = null
var toast: String = ""


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
func begin(tree: SceneTree) -> void:
	_load_profile()
	seed = randi()
	rng = Mulberry32.new(seed)
	run_floors = Floors.generate_run_table(rng, Floors.DEMO_MAX_FLOOR)
	floor = 0
	toast = ""
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
	runs += 1
	_persist_profile()

	character = starter_path(stats)
	var vitals := Profile.derived_vitals(stats, madness)
	var fanatic: bool = Equipment.has_full_set(equipped, "fanatic")

	max_hp = vitals.max_hp
	hp = max_hp

	max_sanity = vitals.max_sanity
	if max_sanity <= 0:
		if not fanatic:
			_shatter(tree)
			return
		max_sanity = 1
	sanity = max_sanity if profile_sanity == null else min(int(profile_sanity), max_sanity)
	if sanity <= 0:
		if not fanatic:
			_shatter(tree)
			return
		sanity = max(1, sanity)

	run_strength = int(vitals.strength)
	extra_energy_next = 0
	act = 1
	deck = loadout_deck()
	if run_floors.is_empty():
		seed = randi()
		rng = Mulberry32.new(seed)
		run_floors = Floors.generate_run_table(rng, Floors.DEMO_MAX_FLOOR)

	if not seen_rlyeh:
		## store.ts startRun()：初回のみ1階の遭遇を"drowned"に強制上書きする
		seen_rlyeh = true
		_persist_profile()
		if run_floors.size() > 0:
			run_floors[0] = {"floor": 1, "type": "combat", "enemy_ids": ["drowned"]}

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
	var table_len: int = run_floors.size() if run_floors.size() > 0 else Floors.DEMO_MAX_FLOOR
	if next_floor > table_len:
		## store.ts enterFloor()のvictory分岐：bestFloor/earnedPoints/unspentPoints/wins/sanityを更新して永続化
		best_floor = max(best_floor, floor)
		var budget := Profile.total_points(best_floor)
		earned_points = budget
		unspent_points = max(0, budget - Profile.stat_sum(stats))
		wins += 1
		profile_sanity = sanity
		_persist_profile()
		combat = null
		reward = null
		event = null
		rest_mode = ""
		goto_scene(tree, "victory")
		return

	var spec: Dictionary = run_floors[next_floor - 1]
	floor = next_floor
	combat = null
	reward = null
	event = null
	rest_mode = ""

	var kind: String = spec.get("type", "combat")
	if kind == "combat" or kind == "elite" or kind == "boss":
		## store.ts enterFloor(): spec.enemyIds が空なら encounterIds() で決定する。
		## CombatState 本体は Combat.gd が CombatLogic.start_combat() で構築する。
		var enemy_ids: Array = spec.get("enemy_ids", [])
		if enemy_ids.is_empty():
			enemy_ids = CombatLogic.encounter_ids(kind, floor, Callable(self, "_rand"))
		combat = {"floor": floor, "kind": kind, "enemy_ids": enemy_ids}
		goto_scene(tree, "combat")
	elif kind == "rest":
		rest_mode = "hub"
		## smith.ts の makeSmith(rand)。品揃え/ランク階層（SLOTS/SHOP_POOL/equipmentGoods）は
		## 未移植（フェーズB以降）だが、taboo判定だけは rollShopRank() と同じ確率（0.2%）で
		## 先行して用意する（forge_at_smith相当のtaboo無料・倍率2倍分岐が必要なため）。
		village = {"smith": {"taboo": _rand() < 0.002}}
		goto_scene(tree, "rest")
	else:
		## 実際は EVENTS から該当イベントを引く（フェーズB以降）
		event = {"id": spec.get("event_id", "")}
		goto_scene(tree, "event")


## store.ts の finishAdvance(carry) 相当。
## 10層毎のボス撃破（周回未終了時）は拠点(hub)に自動帰還＝中継点。
## 最終層到達で victory。それ以外は次の階層へ enter_floor する。
## 注意：DEMO_MAX_FLOOR分岐は実ソースでもearnedPoints/unspentPointsを更新しない
## （中継点分岐・enterFloorのvictory分岐とはフィールド更新内容が異なる）。実装ミスの可能性が
## あるが、値のズレが実害を生まない箇所のため、忠実性を優先しそのまま移植する。
func finish_advance(tree: SceneTree) -> void:
	var spec: Dictionary = run_floors[floor - 1] if floor - 1 < run_floors.size() else {}
	if spec.get("type", "") == "boss" and floor % 10 == 0 and floor < Floors.DEMO_MAX_FLOOR:
		best_floor = max(best_floor, floor)
		var budget := Profile.total_points(best_floor)
		earned_points = budget
		unspent_points = max(0, budget - Profile.stat_sum(stats))
		profile_sanity = sanity
		_persist_profile()
		toast = "%sを越えた" % Floors.layer_label(floor)
		combat = null
		reward = null
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
		event = null
		goto_scene(tree, "victory")
		return
	enter_floor(tree, floor + 1)


## store.ts の claimReward()（reward画面の「次へ進む」）。
## 実際の戦利品確定処理（addLootCard等）はフェーズB以降。
func claim_reward(tree: SceneTree) -> void:
	finish_advance(tree)


## store.ts の resolveFlee()（宝殻の徘徊者からの逃走成立後）
func resolve_flee(tree: SceneTree) -> void:
	finish_advance(tree)


## store.ts の resolveEvent(choiceId)。実際の効果分岐はフェーズB以降。
func resolve_event(tree: SceneTree, _choice_id: String) -> void:
	event = null
	finish_advance(tree)


## store.ts の leaveVillage()（RestView VillageHubの「次の層へ」）
func leave_village(tree: SceneTree) -> void:
	rest_mode = ""
	village = null
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
func accept_shatter(tree: SceneTree) -> void:
	_load_profile()
	reset_run()
	player_name = ""
	goto_scene(tree, "title")


## 戦闘勝利（フェーズAではカード無しのダミー）。実際は presentCombat() が
## 920ms後に reward 画面へ遷移させる。
func win_combat(tree: SceneTree) -> void:
	reward = {}  ## 実際は makeRewards() で戦利品候補を生成（フェーズB以降）
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
	if (sanity <= 0 or max_sanity <= 0) and not Equipment.has_full_set(equipped, "fanatic"):
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
	if (max_sanity_next <= 0 or new_sanity <= 0) and not Equipment.has_full_set(equipped, "fanatic"):
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
		"equipped": equipped,
	}


func apply_player_hook(hook: Dictionary) -> void:
	hp = int(hook.hp)
	max_hp = int(hook.maxHp)
	sanity = int(hook.sanity)
	max_sanity = int(hook.get("maxSanity", max_sanity))


## extractToHub() / giveUp() / accept_shatter() 共通のラン状態リセット
func reset_run() -> void:
	floor = 0
	run_floors = []
	combat = null
	reward = null
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
