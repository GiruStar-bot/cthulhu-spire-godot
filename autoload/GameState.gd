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
var best_floor: int = 0
var wins: int = 0
var runs: int = 0
var earned_points: int = 0
var unspent_points: int = 0
## 4元素羅針盤の取得済みマスID（Compass 参照）。1マス＝ステータスポイント1。
var compass_nodes: Array = []
## 超越羅針盤。場面2（The Dream Island）に初めて入ると解放。
## 旧神のマスは白ポイント、戯神のマスは黒ポイントで取る（総獲得数を保存、残りは取得数から逆算）。
var transcend_nodes: Array = []
var transcend_unlocked: bool = false
var white_points: int = 0
var black_points: int = 0
var madness: int = 0
var profile_sanity = null  ## 次ラン開始時に引き継ぐ正気値。null＝未設定（満タンから開始）
var seen_rlyeh: bool = false
var grimoire_read: Array = []
var shells: int = 0
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
## ラン開始時に確定した羅針盤の効果（Compass.bonus）。ラン中に羅針盤を変えても次のランから反映。
var run_compass: Dictionary = Compass.empty_bonus()
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
## 主催者つきバフイベントで得たバフ。各要素 {stat, n, title}（Blessings.compute_stats が集計）。
var run_blessings: Array = []
var encounter_bias: Array = []  ## 旧バフ（潮流）の名残。いまは常に空
## 開いているバフイベント：主催者ID・パネル3枚・背景（直前の画面のもの）
var blessing_host: String = ""
var blessing_offers: Array = []
var blessing_backdrop: Texture2D = null
## ラン単位のフラグ（ラン開始時に空へ戻す）：no_val / no_trickster / trickster_always / wish_gods / took_energy_for_draw
var run_host_flags: Dictionary = {}
## ヴァルちゃん「パック排出率アップ」：パックID -> 倍率（1.5 の累乗）
var pack_boosts: Dictionary = {}
## 戯神「銀の鍵」：次の階が全なる者との戦闘になる
var silver_key_pending: bool = false
var _force_first_drowned: bool = false
## アイホートくんの呪い。-1=なし。値があれば、その階層以降で最初の戦闘のデッキが「百目の子」になる。
var eihort_curse_floor: int = -1


func _ready() -> void:
	rng = Mulberry32.new(randi())
	_load_profile()


## profile.ts の loadProfile() をGameStateのフィールドへ展開する（store.tsの`profile: loadProfile()`相当）
func _load_profile() -> void:
	var p := Profile.load_profile()
	player_name = p.player_name
	best_floor = p.best_floor
	wins = p.wins
	runs = p.runs
	earned_points = p.earned_points
	unspent_points = p.unspent_points
	compass_nodes = p.compass
	transcend_nodes = p.transcend
	transcend_unlocked = p.transcend_unlocked
	white_points = p.white_points
	black_points = p.black_points
	_apply_compass_to_collection()
	madness = p.madness
	profile_sanity = p.sanity
	seen_rlyeh = p.seen_rlyeh
	grimoire_read = p.grimoire_read
	shells = p.shells
	starter_chosen = p.starter_chosen
	## 旧セーブにコレクションキーは無い。collection_saved が真のときだけ復元する。
	if p.get("collection_saved", false) == true:
		CollectionData.apply_save({
			"decks": p.get("decks", {}),
			"active_deck": p.get("active_deck", CollectionData.DEFAULT_DECK_NAME),
			"inventory": p.get("inventory", {}),
			"pack_tickets": p.get("pack_tickets", {}),
		})
	elif CollectionData.profile_seeded:
		CollectionData.seed_new_profile()


## store.ts の persist(profile) 相当。呼び出し箇所は実ソースの各アクションのpersist()呼び出しに対応。
func _persist_profile() -> void:
	var collection: Dictionary = CollectionData.export_save()
	Profile.save_profile({
		"player_name": player_name,
		"best_floor": best_floor,
		"wins": wins,
		"runs": runs,
		"earned_points": earned_points,
		"unspent_points": unspent_points,
		"compass": compass_nodes,
		"transcend": transcend_nodes,
		"transcend_unlocked": transcend_unlocked,
		"white_points": white_points,
		"black_points": black_points,
		"madness": madness,
		"sanity": profile_sanity,
		"seen_rlyeh": seen_rlyeh,
		"grimoire_read": grimoire_read,
		"shells": shells,
		"starter_chosen": starter_chosen,
		"collection_saved": true,
		"decks": collection.get("decks", {}),
		"active_deck": collection.get("active_deck", CollectionData.DEFAULT_DECK_NAME),
		"inventory": collection.get("inventory", {}),
		"pack_tickets": collection.get("pack_tickets", {}),
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
	var owner: String = character if character != "" else starter_path()
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


## 拠点の売却価格。カード定義の sell_price をそのまま使う（無ければ売れない＝0）。
func card_sell_price(card_def: Dictionary) -> int:
	return int(card_def.get("sell_price", 0))


## store.ts の sellItems({cardIds})。合計0円なら何もしない。
func sell_items(card_ids: Array) -> void:
	var total := 0
	var sell_card_ids: Array = []
	for id in card_ids:
		for c in CollectionData.inventory.cards:
			if str(c.get("instance_id", "")) == str(id):
				total += card_sell_price(Cards.get_card(str(c.get("base_card_id", ""))))
				sell_card_ids.append(str(id))
				break
	if total == 0:
		return
	CollectionData.remove_cards(sell_card_ids)
	shells += total
	_persist_profile()
	toast = "貝殻+%d" % total


## 羅針盤（4元素＋超越）の取得済みマスを合算した効果。
func compass_bonus() -> Dictionary:
	var owned: Array = compass_nodes.duplicate()
	owned.append_array(transcend_nodes)
	return Compass.bonus(owned)


## ラン開始時の基礎値（体力・正気度の最大、筋力、エナジー上限）。
func derived_vitals() -> Dictionary:
	return Profile.derived_vitals(compass_bonus(), madness)


func derived_max_hp() -> int:
	return int(derived_vitals().max_hp)


func derived_max_sanity() -> int:
	return int(derived_vitals().max_sanity)


## 戦闘中のエナジー上限。ラン中はラン開始時に確定した羅針盤の値を使う。
func derived_energy() -> int:
	if floor > 0:
		return Profile.BASE_ENERGY + int(run_compass.get("energy", 0))
	return int(derived_vitals().energy)


## profile.ts の madnessPenalty()
func madness_penalty() -> int:
	return Profile.madness_penalty(madness)


## 総ポイント。ボス撃破の累積（earned_points）そのもの。到達階層÷10では再計算しない。
func total_points() -> int:
	return earned_points


func _sync_unspent_points() -> void:
	unspent_points = max(0, earned_points - compass_nodes.size())


## デッキ上限の羅針盤ボーナスを CollectionData へ渡す（デッキ編成の上限判定に使う）。
func _apply_compass_to_collection() -> void:
	CollectionData.deck_limit_bonus = int(compass_bonus().deck_limit)


func _after_compass_change() -> void:
	_sync_unspent_points()
	_apply_compass_to_collection()
	_persist_profile()


## 4元素羅針盤のマスを1つ取る。ポイント不足・隣接していない・取得済みなら false。
func take_compass_node(id: String) -> bool:
	if not Compass.ELEMENTS.has(Compass.branch_of(id)):
		return false
	if unspent_points <= 0 or not Compass.can_take(compass_nodes, id):
		return false
	compass_nodes.append(id)
	_after_compass_change()
	return true


## 4元素羅針盤を全マス返却（無料）。
func reset_compass() -> void:
	compass_nodes = []
	_after_compass_change()


## 超越羅針盤の残りポイント。side は "elder"（白）か "trickster"（黒）。
func transcend_points_left(side: String) -> int:
	var total: int = white_points if side == "elder" else black_points
	return max(0, total - Compass.count_in(transcend_nodes, [side]))


func take_transcend_node(id: String) -> bool:
	var side: String = Compass.branch_of(id)
	if not transcend_unlocked or not Compass.TRANSCEND_SIDES.has(side):
		return false
	if transcend_points_left(side) <= 0 or not Compass.can_take(transcend_nodes, id):
		return false
	transcend_nodes.append(id)
	_after_compass_change()
	return true


func reset_transcend() -> void:
	transcend_nodes = []
	_after_compass_change()


## 白ポイント（旧神バフを選んだとき）。獲得元のイベントは未実装。
func add_white_points(amount: int) -> void:
	if amount > 0:
		white_points += amount
		_persist_profile()


## 黒ポイント（戯神バフを選んだとき）。獲得元のイベントは未実装。
func add_black_points(amount: int) -> void:
	if amount > 0:
		black_points += amount
		_persist_profile()


## 場面2（The Dream Island）に初めて入ったとき超越羅針盤を解放する。
func unlock_transcend() -> void:
	if transcend_unlocked:
		return
	transcend_unlocked = true
	_persist_profile()


## 旧ステータス配分からスターターを決めていた名残。配分が無くなったので常に investigator。
func starter_path() -> String:
	return "investigator"


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
	if realm == "dream":
		unlock_transcend()
	seed = randi()
	rng = Mulberry32.new(seed)
	run_floors = []
	floor = 0
	toast = ""
	## CollectionData は Autoload 済み。同期ウォーム（所持枚数が多くてもフレーム数枚程度）。
	ArtCache.warm_for_collection()
	goto_scene(tree, "hub")


## store.ts の toTitle()。Dream Island 中は waking タイトルへ戻さない。
func to_title(tree: SceneTree) -> void:
	if realm == "dream":
		goto_scene(tree, "dream_title")
	else:
		goto_scene(tree, "title")


## store.ts の startRun()。
## 名前入力UIは未実装のため名前チェックは省略する。
## 初期デッキは廃止したので、スターター選択済みでも最低枚数を満たすまで潜航できない。
func start_run(tree: SceneTree) -> void:
	var deck_err: String = CollectionData.loadout_error()
	if deck_err != "":
		toast = deck_err
		return
	runs += 1
	_persist_profile()

	character = starter_path()
	run_compass = compass_bonus()
	var vitals: Dictionary = Profile.derived_vitals(run_compass, madness)

	max_hp = vitals.max_hp
	hp = max_hp

	max_sanity = vitals.max_sanity
	if max_sanity <= 0:
		_shatter(tree)
		return
	## HUB に戻ったら体力・正気度は全回復（旧仕様の正気持ち越しは廃止）
	sanity = max_sanity

	run_strength = int(vitals.strength)
	extra_energy_next = 0
	act = 1
	deck = loadout_deck()
	run_floors = []
	run_blessings = []
	encounter_bias = []
	_clear_blessing_run_state()
	floor_kind = ""
	_force_first_drowned = false
	eihort_curse_floor = -1

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
		_sync_unspent_points()
		wins += 1
		profile_sanity = null  ## HUB に戻ったら正気は全回復
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
	blessing_offers = []

	var kind: String = Floors.type_for(floor, rng)
	var enemy_ids: Array = []
	if _force_first_drowned and floor == 1:
		_force_first_drowned = false
		kind = "combat"
		enemy_ids = ["drowned"]
	## 戯神「銀の鍵」：階層に関係なく全なる者との戦闘
	if silver_key_pending:
		silver_key_pending = false
		kind = "boss"
		enemy_ids = ["yog_sothoth"]
	floor_kind = kind

	if kind == "combat" or kind == "elite" or kind == "boss":
		if enemy_ids.is_empty():
			enemy_ids = CombatLogic.encounter_ids(kind, floor, Callable(self, "_rand"), encounter_bias)
		## 戯神「神様に会いたい。」：通常戦闘の30%がボス（全なる者を含む）になる
		if kind == "combat" and run_host_flags.get("wish_gods", false) and rng.next_float() < Blessings.GOD_WISH_CHANCE:
			enemy_ids = [str(Mulberry32.pick(Enemies.BOSS_IDS, rng))]
		combat = {"floor": floor, "kind": kind, "enemy_ids": enemy_ids}
		goto_scene(tree, "combat")
	elif kind == "rest":
		rest_mode = "hub"
		## 鍛冶屋廃止。酒場の beerSold だけこの辞書に載せる。
		village = {}
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
	var host: String = Blessings.pick_host(run_host_flags, Callable(self, "_rand"))
	if host == "":
		_advance_after_blessing(tree)  ## 両方に「会いたくない」を選んだ：イベントなしで次へ
		return
	blessing_host = host
	blessing_offers = Blessings.roll_offers(host, run_host_flags, floor, Callable(self, "_rand"))
	blessing_backdrop = _current_backdrop(tree)
	goto_scene(tree, "blessing")


## 直前の画面の背景をそのまま使う（UI だけ消して重ねる）。見つからなければその階層の背景。
func _current_backdrop(tree: SceneTree) -> Texture2D:
	var cur: Node = tree.current_scene
	if cur != null:
		for path in ["BackgroundArt", "HubLayer/HubBg"]:
			var node: Node = cur.get_node_or_null(path)
			if node is TextureRect and (node as TextureRect).texture != null:
				return (node as TextureRect).texture
	var fallback: String = Biomes.biome_art(Biomes.biome_for_floor(floor))
	if ResourceLoader.exists(fallback, "Texture2D"):
		return load(fallback) as Texture2D
	return null


func _clear_blessing_run_state() -> void:
	blessing_host = ""
	blessing_offers = []
	blessing_backdrop = null
	run_host_flags = {}
	pack_boosts = {}
	silver_key_pending = false


## パネルを選んだときの効果を反映する。戻り値は画面側の演出用（魔導書で得たカードIDなど）。
func apply_blessing_offer(offer: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var kind: String = str(offer.get("kind", ""))
	var title: String = str(offer.get("title", ""))
	if kind == "val_pack":
		var pack: String = str(offer.get("pack", ""))
		pack_boosts[pack] = float(pack_boosts.get(pack, 1.0)) * Blessings.PACK_BOOST_MUL
		run_blessings.append({"title": title})
	elif kind == "val_stat":
		run_blessings.append({"stat": str(offer.get("stat", "")), "n": int(offer.get("n", 0)), "title": title})
	elif kind == "val_decline":
		run_host_flags["no_val"] = true
		blessing_offers = []
		return {}
	elif kind == "val_retreat":
		blessing_offers = []
		return {"retreat": true}  ## 画面側がフェードアウトしてから extract_to_hub を呼ぶ
	elif kind == "trickster":
		result = _apply_trickster_deal(str(offer.get("deal", "")), title)
	## 「銀の鍵を受け取る。」など文になっているタイトルはそのまま、短い名前は「〜を得た。」
	if title == "":
		toast = ""
	elif title.ends_with("。"):
		toast = title
	else:
		toast = "%sを得た。" % title
	blessing_offers = []
	return result


func _apply_trickster_deal(deal: String, title: String) -> Dictionary:
	match deal:
		"hp_one_all_pack":
			max_hp = 1
			hp = 1
			CollectionData.add_pack_ticket("all")
			_persist_profile()
		"heal_hp_lose_san":
			hp = max_hp
			sanity = maxi(1, sanity - 6)  ## 戦闘外で正気0（崩壊）にはしない
		"heal_san_lose_hp":
			sanity = mini(max_sanity, sanity + 6)
			hp = maxi(1, hp - 6)
		"hp999_san5":
			max_hp = 999
			max_sanity = 5
			sanity = mini(sanity, max_sanity)
		"energy_for_draw":
			run_host_flags["took_energy_for_draw"] = true
			run_blessings.append({"stat": "energyPerTurn", "n": 2, "title": title})
			run_blessings.append({"stat": "drawBonus", "n": -2, "title": ""})
		"strength_rush":
			var r: Vector2i = Blessings.strength_rush_range(floor)
			var gain: int = r.x + int(rng.next_float() * float(r.y - r.x + 1))
			run_strength += mini(gain, r.y)
			return {"strength": mini(gain, r.y)}
		"meet_gods":
			run_host_flags["wish_gods"] = true
		"silver_key":
			silver_key_pending = true
		"trickster_again":
			run_host_flags["trickster_always"] = true
		"trickster_never":
			run_host_flags["no_trickster"] = true
			run_host_flags.erase("trickster_always")
		"trickster_card":
			_add_run_gift_card(Blessings.TRICKSTER_CARD_ID)
			return {"card_id": Blessings.TRICKSTER_CARD_ID}
		"grimoire":
			var card_id: String = _roll_grimoire_card()
			if card_id != "":
				_add_run_gift_card(card_id)
			return {"card_id": card_id}
	return {}


## デッキ上限を無視して、このランのデッキにだけ加える（コレクションには入れない）。
## prune_run_deck で消されないよう runGift を付ける。
func _add_run_gift_card(card_id: String) -> void:
	var card: Dictionary = Cards.make_card(card_id)
	card["runGift"] = true
	deck.append(card)


func _roll_grimoire_card() -> String:
	var pool: Array = []
	for card_id in Cards.CARDS.keys():
		var d: Dictionary = Cards.CARDS[card_id]
		if not d.get("grimoire", false):
			continue
		if d.get("unobtainable", false) or d.get("enemyOnly", false) or str(d.get("type", "")) == "status":
			continue
		pool.append(str(card_id))
	if pool.is_empty():
		return ""
	return str(Mulberry32.pick(pool, rng))


## バフイベントを閉じて次へ進む（パネル選択・「会いたくない」の後）。
func finish_blessing(tree: SceneTree) -> void:
	blessing_host = ""
	blessing_offers = []
	blessing_backdrop = null
	_advance_after_blessing(tree)


func _advance_after_blessing(tree: SceneTree) -> void:
	if floor_kind == "boss" and floor % 10 == 0 and floor < Floors.DEMO_MAX_FLOOR:
		best_floor = max(best_floor, floor)
		_sync_unspent_points()
		profile_sanity = null  ## HUB に戻ったら正気は全回復
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
		profile_sanity = null  ## HUB に戻ったら正気は全回復
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


## store.ts の resolveEvent(choiceId)。
## 旧テキストイベント（tome / well / cult / mirror）の数値分岐はイベントごと削除した。
func resolve_event(tree: SceneTree, choice_id: String) -> void:
	var ev: Dictionary = event if event is Dictionary else {}
	var event_id: String = str(ev.get("id", ""))
	## アイホートくん「戦う」だけは次の階層へ進まず、この階層のまま戦闘へ入る。
	## 勝てば通常の戦闘と同じく報酬 → finish_advance で次の階層へ。
	if event_id == "eihort" and choice_id == "fight":
		event = null
		combat = {"floor": floor, "kind": "combat", "enemy_ids": ["eihort"]}
		goto_scene(tree, "combat")
		return
	if event_id == "eihort":
		apply_eihort_curse()  ## 返事の台詞は会話モーダル側で見せ済み
	_persist_profile()
	event = null
	finish_advance(tree)


const EIHORT_CURSE_RANGE := 15  ## 呪いの階層は現在階層+1〜+15（最深100階で打ち止め）


## アイホートくんの呪いを付ける（イベント「子を宿す」／戦闘で「子を宿す」が命中）。
## すでに呪われていれば重ねない（先の呪いの階層のまま）。
func apply_eihort_curse() -> void:
	if eihort_curse_floor >= 0:
		return
	var lo: int = floor + 1
	var hi: int = mini(floor + EIHORT_CURSE_RANGE, Floors.DEMO_MAX_FLOOR)
	if lo > hi:
		return
	eihort_curse_floor = mini(hi, lo + int(rng.next_float() * float(hi - lo + 1)))


## 戦闘開始時に呼ぶ。呪いの階層以降の戦闘なら true を返し、呪いを解く（一度きり）。
## 呪いの階層が村落やイベントでも、その先の最初の戦闘で発動する。
func consume_eihort_curse(combat_floor: int) -> bool:
	if eihort_curse_floor < 0 or combat_floor < eihort_curse_floor:
		return false
	eihort_curse_floor = -1
	return true


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
	_sync_unspent_points()
	profile_sanity = null  ## HUB に戻ったら正気は全回復
	_persist_profile()
	reset_run()
	toast = "%sから帰還した" % Floors.layer_label(left_floor)
	goto_scene(tree, "hub")


## store.ts の giveUp()（EndView「拠点へ戻る」／victory画面のボタン）。
## 実ソースでは victory 画面のボタン表記が「タイトルへ戻る」なのに実際は scene を
## "hub" にする食い違いがあるが、これは実装ミスと判断し、Godot版ではボタン表記を
## 「帰還」に修正した（End.gd参照）。give_up()自体の動作（hubへ戻る）は変更していない。
func give_up(tree: SceneTree) -> void:
	profile_sanity = null  ## HUB に戻ったら正気は全回復
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


const BOSS_POINT_TEXT := "ステータスポイント +1"


## ボス撃破か。10階ボス・100階の全なる者・銀の鍵の全なる者は floor_kind が boss。
## 戯神「神様に会いたい」は通常戦闘のまま敵IDだけ Enemies.BOSS_IDS になる。両方をここで見る。
func _encounter_is_boss(combat_state: Dictionary) -> bool:
	if floor_kind == "boss":
		return true
	for e in combat_state.get("enemies", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var enemy_id: String = str(e.get("defId", ""))
		if Enemies.BOSS_IDS.has(enemy_id):
			return true
	return false


## 撃破の瞬間に+1して保存する。報酬画面へ進む処理は呼ばない。
## 1戦闘につき1回（唱者が分裂しても、同じボスを別ランで倒したときだけまた+1）。
func note_boss_status_point(combat_state: Dictionary) -> bool:
	if combat_state.get("bossPointGranted", false):
		return false
	if not _encounter_is_boss(combat_state):
		return false
	combat_state["bossPointGranted"] = true
	earned_points += 1
	_sync_unspent_points()
	_persist_profile()
	var log_lines: Array = combat_state.get("log", [])
	log_lines.append(BOSS_POINT_TEXT)
	combat_state["log"] = log_lines
	var floaters: Array = combat_state.get("floaters", [])
	floaters.append({
		"id": Mulberry32.uid("f"),
		"text": BOSS_POINT_TEXT,
		"kind": "info",
		"who": "player",
	})
	combat_state["floaters"] = floaters
	return true


## 戦闘勝利。store.ts presentCombat win 分岐：貝殻加算のあと makeRewards() で報酬画面へ。
## ボスのステータスポイントは撃破時点（Combat が報酬へ進む前）に加算済み。
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


## 最深階層だけ更新する。獲得ポイントはボス撃破時の累積のまま（ここで÷10し直さない）。
func _mark_defeat() -> void:
	best_floor = max(best_floor, floor)
	_sync_unspent_points()
	profile_sanity = null  ## HUB に戻ったら正気は全回復
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
	var prev_max: int = Profile.derived_vitals(compass_bonus(), madness).max_sanity
	var new_madness: int = madness + Profile.MADNESS_STEP
	var new_read: Array = grimoire_read.duplicate()
	new_read.append(next.card_id)
	var max_sanity_next: int = Profile.derived_vitals(compass_bonus(), new_madness).max_sanity
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


## cardEvaluator.ts loadoutDeck() 相当。
## 未編成のときの旧フォールバック（打撃・守り・研究／鞭・印章・囁き）は定義ごと削除した。
## 空のまま戦闘へ入れる。新しい初期デッキは別タスク。
func loadout_deck() -> Array:
	var out: Array = []
	var counts: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	if counts.is_empty():
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
	var kept_gifts: Array = []
	for card in deck:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		if card.get("combatSpawn", false):
			continue
		if card.get("runGift", false):
			kept_gifts.append(card)  ## 戯神の取引で得たカードは上限・編成に関係なく残す
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
	kept.append_array(kept_gifts)
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
		"blessings": _combat_blessings(),
		"strengthMul": int(run_compass.get("strength_mul", 1)),
		"sanFullEachTurn": run_compass.get("turn_san_full", false) == true,
	}


## 戦闘へ渡すバフ。羅針盤のドロー・毎ターン防御は既存のバフ集計（Blessings.compute_stats）に乗せる。
func _combat_blessings() -> Array:
	var out: Array = run_blessings.duplicate()
	var draw: int = int(run_compass.get("draw", 0))
	if draw != 0:
		out.append({"stat": "drawBonus", "n": draw})
	var turn_block: int = int(run_compass.get("turn_block", 0))
	if turn_block > 0:
		out.append({"stat": "baseBlockPerTurn", "n": turn_block})
	return out


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
## 削除したパック（毒・狂信・供物・影）のチケットは出さない。偏りや敵属性がそれなら有効なパックへ逃がす。
func _reward_ticket_archetype() -> String:
	var base: String = _reward_ticket_archetype_base()
	return _apply_pack_boost(base)


## ヴァルちゃんの「排出率アップ」。重み 1 のパックを 1.5^k に上げたのと同じ確率になるよう、
## 増えた重みの分だけ、ブーストしたパックへ引き直す（ブーストが無ければ base のまま）。
func _apply_pack_boost(base: String) -> String:
	if pack_boosts.is_empty():
		return base
	var pool_size: int = 0
	for a in CollectionData.PACK_TICKET_ARCHETYPES:
		if str(a) != "all":
			pool_size += 1
	var extra: Dictionary = {}
	var extra_total: float = 0.0
	for pack in pack_boosts.keys():
		var w: float = float(pack_boosts[pack]) - 1.0
		if w > 0.0:
			extra[pack] = w
			extra_total += w
	if extra_total <= 0.0:
		return base
	if rng.next_float() >= extra_total / (extra_total + float(pool_size)):
		return base
	return str(Mulberry32.weighted_pick(extra, Callable(self, "_rand")))


func _reward_ticket_archetype_base() -> String:
	var pool: Array = []
	for a in CollectionData.PACK_TICKET_ARCHETYPES:
		if str(a) != "all":
			pool.append(str(a))
	if not encounter_bias.is_empty():
		var biased: String = str(Mulberry32.pick(encounter_bias, rng))
		if pool.has(biased):
			return biased
	var arch: String = _encounter_archetype()
	if pool.has(arch):
		return arch
	if pool.is_empty():
		return "knight"
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
	var owner: String = character if character != "" else starter_path()
	var card: Dictionary = Cards.weighted_card(owner, Callable(self, "_rand"))
	return {"kind": "card", "card": card}


## extractToHub() / giveUp() / accept_shatter() 共通のラン状態リセット
func reset_run() -> void:
	floor = 0
	run_floors = []
	floor_kind = ""
	run_blessings = []
	encounter_bias = []
	_clear_blessing_run_state()
	_force_first_drowned = false
	eihort_curse_floor = -1
	combat = null
	reward = null
	reward_shells = 0
	event = null
	rest_mode = ""
	village = null
	deck = []
	run_strength = 0
	run_compass = Compass.empty_bonus()
	extra_energy_next = 0
	hp = 0
	max_hp = 0
	sanity = 0
	max_sanity = 0


