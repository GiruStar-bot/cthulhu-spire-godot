class_name Blessings
extends RefCounted

## 5階層ごとの「主催者つきバフイベント」。
## 主催者は女神ちゃん（正統派の加護。開発用の呼び名はヴァルちゃん）と戯神（悪魔の取引）の2人。
## ここは抽選と集計だけを持つ純粋ロジック。GameState への反映は GameState.apply_blessing_offer。

## 主催者ID。画面に出す名前は HOSTS の name（固有名は出さない方針）。
const HOST_VAL := "val"
const HOST_TRICKSTER := "trickster"

## ヴァルちゃんの表示名。変えるときはここ1か所だけ直す。
const VAL_DISPLAY_NAME := "女神ちゃん"

const HOSTS := {
	HOST_VAL: {
		"dev_name": "ヴァルちゃん",  ## 開発用の呼び名。画面には出さない
		"name": VAL_DISPLAY_NAME,
		"portrait": "res://art/pixel/ui/host_val.png",
		"line": "加護よ",
	},
	HOST_TRICKSTER: {
		"dev_name": "戯神",
		"name": "戯神",
		"portrait": "res://art/pixel/ui/host_trickster.png",
		"line": "ふふ、どれにする？",
	},
}

## ヴァルちゃんのパネルの種類。4種類を等確率で抽選する（叩き台）。
## 「会いたくない」「撤退する」は、それぞれ同じ回に2枚以上出さない。
const VAL_KINDS := ["val_pack", "val_stat", "val_decline", "val_retreat"]
const VAL_ONCE_PER_EVENT := ["val_decline", "val_retreat"]

## ヴァルちゃん：パック排出率アップの倍率（重ねがけで掛け算）
const PACK_BOOST_MUL := 1.5

## ヴァルちゃん：ステータス上昇。n は倍率 1 + floor(階層/30) を掛ける前の値。scaled=false は倍率なし。
const VAL_STATS := [
	{"stat": "strength", "n": 1, "scaled": true, "label": "筋力+%d"},
	{"stat": "drawBonus", "n": 1, "scaled": false, "label": "ドロー数+%d"},
	{"stat": "energyPerTurn", "n": 1, "scaled": false, "label": "エネルギー最大値+%d"},
	{"stat": "poisonResist", "n": 2, "scaled": true, "label": "毒耐性+%d"},
	{"stat": "baseBlockPerTurn", "n": 3, "scaled": true, "label": "基本防御+%d"},
]

## 戯神の取引（12種）。once_flag を持つものは、そのフラグが立ったランでは二度と出ない。
## パネルに出すのは title の1つだけ。仕様で「」付きの文言があるものはその文言だけ（説明文は出さない＝
## 銀の鍵の行き先などを先に見せない）。「」が無いものは仕様の効果文をそのまま使う。
const TRICKSTER_DEALS := {
	"hp_one_all_pack": {"title": "体力の最大値が1になり、「全」パックを1枚得る。"},
	"heal_hp_lose_san": {"title": "体力が全回復し、正気度を6失う。"},
	"heal_san_lose_hp": {"title": "正気度を6回復し、体力を6失う。"},
	"hp999_san5": {"title": "体力の最大値が999になり、正気度の最大値が5になる。"},
	"energy_for_draw": {"title": "エナジー+2、ドロー数-2。", "once_flag": "took_energy_for_draw"},
	"strength_rush": {"title": "筋力をいっぱいゲット！"},
	"meet_gods": {"title": "神様に会いたい。", "once_flag": "wish_gods"},
	"silver_key": {"title": "銀の鍵を受け取る。"},
	"trickster_again": {"title": "戯神ちゃんにまた会いたい。", "once_flag": "trickster_always"},
	"trickster_never": {"title": "戯神ちゃんに会いたくない。"},
	"trickster_card": {"title": "戯神ちゃんをデッキに加える。"},
	"grimoire": {"title": "「魔導書」を一冊得る。"},
}

const TRICKSTER_CARD_ID := "trickster_chan"
const GOD_WISH_CHANCE := 0.3


## 主催者の抽選。どちらにも会えないときは "" を返す（イベントなしで次へ進む）。
static func pick_host(flags: Dictionary, rand: Callable) -> String:
	var val_ok: bool = not flags.get("no_val", false)
	var trickster_ok: bool = not flags.get("no_trickster", false)
	if trickster_ok and flags.get("trickster_always", false):
		return HOST_TRICKSTER
	if val_ok and trickster_ok:
		return HOST_VAL if float(rand.call()) < 0.5 else HOST_TRICKSTER
	if val_ok:
		return HOST_VAL
	if trickster_ok:
		return HOST_TRICKSTER
	return ""


static func scale_for_floor(current_floor: int) -> int:
	return 1 + int(floor(float(current_floor) / 30.0))


## 戯神「筋力をいっぱいゲット！」の幅。30階まで 3〜6、以降10階ごとに両端+3。
static func strength_rush_range(current_floor: int) -> Vector2i:
	var step: int = maxi(0, int(floor(float(current_floor) / 10.0)) - 2)
	return Vector2i(3 + step * 3, 6 + step * 3)


## パネル3枚ぶんの提示内容を作る。各要素は {kind, title, ...}（画面には title だけを出す）。
static func roll_offers(host: String, flags: Dictionary, current_floor: int, rand: Callable, count: int = 3) -> Array:
	if host == HOST_VAL:
		return _roll_val_offers(current_floor, rand, count)
	if host == HOST_TRICKSTER:
		return _roll_trickster_offers(flags, current_floor, rand, count)
	return []


static func _roll_val_offers(current_floor: int, rand: Callable, count: int) -> Array:
	var packs: Array = []
	for a in CollectionData.PACK_TICKET_ARCHETYPES:
		if str(a) != "all":
			packs.append(str(a))
	var mul: int = scale_for_floor(current_floor)
	var out: Array = []
	var used_once: Dictionary = {}
	for i in count:
		var kinds: Array = []
		for k in VAL_KINDS:
			if VAL_ONCE_PER_EVENT.has(k) and used_once.has(k):
				continue
			if k == "val_pack" and packs.is_empty():
				continue
			kinds.append(k)
		var kind: String = str(kinds[clampi(int(floor(float(rand.call()) * kinds.size())), 0, kinds.size() - 1)])
		if VAL_ONCE_PER_EVENT.has(kind):
			used_once[kind] = true
		if kind == "val_decline":
			out.append({
				"kind": "val_decline",
				"title": "%sに会いたくない" % VAL_DISPLAY_NAME,
			})
		elif kind == "val_retreat":
			out.append({
				"kind": "val_retreat",
				"title": "撤退する",
			})
		elif kind == "val_pack":
			var pack: String = str(Mulberry32.pick_rand(packs, rand))
			var label: String = str(CollectionData.PACK_TICKET_LABELS.get(pack, pack))
			out.append({
				"kind": "val_pack", "pack": pack,
				"title": "%sパックの排出率アップ" % label,
			})
		else:
			var spec: Dictionary = VAL_STATS[int(floor(float(rand.call()) * VAL_STATS.size())) % VAL_STATS.size()]
			var n: int = int(spec.n) * (mul if spec.scaled else 1)
			out.append({
				"kind": "val_stat", "stat": str(spec.stat), "n": n,
				"title": str(spec.label) % n,
			})
	return out


static func _roll_trickster_offers(flags: Dictionary, current_floor: int, rand: Callable, count: int) -> Array:
	var pool: Array = []
	for deal_id in TRICKSTER_DEALS.keys():
		var once: String = str(TRICKSTER_DEALS[deal_id].get("once_flag", ""))
		if once != "" and flags.get(once, false):
			continue
		pool.append(str(deal_id))
	var out: Array = []
	for i in mini(count, pool.size()):
		var idx: int = clampi(int(floor(float(rand.call()) * pool.size())), 0, pool.size() - 1)
		var deal_id: String = str(pool[idx])
		pool.remove_at(idx)
		var def: Dictionary = TRICKSTER_DEALS[deal_id]
		out.append({"kind": "trickster", "deal": deal_id, "title": str(def.title)})
	return out


## 戦闘用の集計。run_blessings の各要素 {stat, n} を足し上げる。
## 旧バフのID（文字列）が残っていても無視する。
static func empty_stats() -> Dictionary:
	return {
		"defense": 0.0, "sanResist": 0.0, "poisonResist": 0.0,
		"poisonImmune": false, "blockRetain": false, "sanFullRestoreOnStart": false,
		"expandedHand": false, "hpPercentHealOnStart": false, "sacrificeEnergyOnStart": false,
		"intangibleOnHit": false, "strength": 0.0, "drawBonus": 0.0, "healPerTurn": 0.0,
		"healBonusPct": 0, "sanHealOnStart": 0.0, "vulnOnStart": 0.0, "energyPerTurn": 0.0,
		"thornDamage": 0.0, "baseBlockPerTurn": 0.0,
	}


static func compute_stats(owned: Array) -> Dictionary:
	var stats: Dictionary = empty_stats()
	for entry in owned:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stat: String = str(entry.get("stat", ""))
		if stat == "" or not stats.has(stat):
			continue
		stats[stat] = float(stats[stat]) + float(entry.get("n", 0))
	return stats


## 中継点などで見せる短い名前。
static func label_of(entry) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get("title", ""))
	return ""
