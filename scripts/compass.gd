class_name Compass
extends RefCounted

## 羅針盤（ステータスポイントの使い道）。4元素羅針盤と超越羅針盤の純粋ロジック。
## 取得状態の保存・ポイント残量の管理は GameState（compass_nodes / transcend_nodes）。
## 数値はすべて叩き台。
##
## マスIDは "<枝>_<番号>"（番号は中心側から1始まり）。各枝は一本道で、
## 中心に隣接する1番から順に、取得済みのマスの次だけ取れる。

const ELEMENTS := ["fire", "water", "wind", "earth"]
const TRANSCEND_SIDES := ["elder", "trickster"]

## 枝ごとのマスの規模。s=小 m=中 l=大（終点）
const ELEMENT_SIZES := ["s", "s", "m", "s", "s", "m", "l"]
const TRANSCEND_SIZES := ["s", "s", "m", "s", "l"]

const BRANCH_LABELS := {
	"fire": "火", "water": "水", "wind": "風", "earth": "地",
	"elder": "旧神", "trickster": "戯神",
}
const SIZE_LABELS := {"s": "小", "m": "中", "l": "大"}

## 効果のキー：max_hp / max_sanity / strength / energy / draw / deck_limit /
## strength_mul（筋力による与ダメージ加算の倍率）/ turn_block（毎ターン開始時の防御）/
## turn_san_full（毎ターン開始時に正気度を全回復）
## 超越羅針盤の途中のマスは、旧神＝地、戯神＝火の小・中と同じ効果（叩き台）。
const EFFECTS := {
	"fire": {"s": {"strength": 1}, "m": {"energy": 1, "draw": 1}, "l": {"strength_mul": 2}},
	"water": {"s": {"max_sanity": 8}, "m": {"draw": 1, "deck_limit": 1}, "l": {"draw": 2}},
	"wind": {"s": {"max_hp": 4, "max_sanity": 4}, "m": {"deck_limit": 1, "draw": 1}, "l": {"deck_limit": 6}},
	"earth": {"s": {"max_hp": 8}, "m": {"deck_limit": 1, "energy": 1}, "l": {"max_hp": 100}},
	"elder": {"s": {"max_hp": 8}, "m": {"deck_limit": 1, "energy": 1}, "l": {"turn_block": 50}},
	"trickster": {"s": {"strength": 1}, "m": {"energy": 1, "draw": 1}, "l": {"turn_san_full": 1}},
}

## 終点の名前（効果文の前に出す）
const END_NAMES := {
	"fire": "筋力2倍", "water": "ドロー数+2", "wind": "デッキ上限+6", "earth": "体力最大+100",
	"elder": "天空", "trickster": "深淵",
}

const EFFECT_TEXTS := {
	"max_hp": "体力最大+%d",
	"max_sanity": "正気度最大+%d",
	"strength": "筋力+%d",
	"energy": "エナジー上限+%d",
	"draw": "ドロー+%d",
	"deck_limit": "デッキ上限+%d",
}


static func is_transcend_branch(branch: String) -> bool:
	return TRANSCEND_SIDES.has(branch)


static func sizes_of(branch: String) -> Array:
	return TRANSCEND_SIZES if is_transcend_branch(branch) else ELEMENT_SIZES


static func node_id(branch: String, index: int) -> String:
	return "%s_%d" % [branch, index]


static func node_ids(branch: String) -> Array:
	var out: Array = []
	for i in sizes_of(branch).size():
		out.append(node_id(branch, i + 1))
	return out


static func branch_of(id: String) -> String:
	var at: int = id.rfind("_")
	return id.substr(0, at) if at > 0 else ""


static func index_of(id: String) -> int:
	var at: int = id.rfind("_")
	if at <= 0:
		return 0
	var tail: String = id.substr(at + 1)
	return int(tail) if tail.is_valid_int() else 0


static func is_valid(id: String) -> bool:
	var branch: String = branch_of(id)
	if not EFFECTS.has(branch):
		return false
	var idx: int = index_of(id)
	return idx >= 1 and idx <= sizes_of(branch).size()


static func size_of(id: String) -> String:
	if not is_valid(id):
		return ""
	return str(sizes_of(branch_of(id))[index_of(id) - 1])


static func effect_of(id: String) -> Dictionary:
	if not is_valid(id):
		return {}
	var table: Dictionary = EFFECTS[branch_of(id)]
	return table.get(size_of(id), {})


## ホバー表示用。例「火・小：筋力+1」「旧神・終点「天空」：毎ターン開始時に防御50を得る」
static func effect_text(id: String) -> String:
	if not is_valid(id):
		return ""
	var branch: String = branch_of(id)
	var size: String = size_of(id)
	var eff: Dictionary = effect_of(id)
	var parts: Array = []
	for key in ["max_hp", "max_sanity", "strength", "energy", "draw", "deck_limit"]:
		if eff.has(key):
			parts.append(str(EFFECT_TEXTS[key]) % int(eff[key]))
	if eff.has("strength_mul"):
		parts.append("筋力による与ダメージ加算が2倍")
	if eff.has("turn_block"):
		parts.append("毎ターン開始時に防御%dを得る" % int(eff.turn_block))
	if eff.has("turn_san_full"):
		parts.append("毎ターン開始時に正気度を全回復する")
	var head: String = "%s・%s" % [BRANCH_LABELS[branch], SIZE_LABELS[size]]
	if size == "l":
		head = "%s・終点「%s」" % [BRANCH_LABELS[branch], END_NAMES[branch]]
	return "%s：%s" % [head, "、".join(PackedStringArray(parts))]


## 取れるマスか。未取得で、1番か直前のマスを取得済み。
static func can_take(owned: Array, id: String) -> bool:
	if not is_valid(id) or owned.has(id):
		return false
	var idx: int = index_of(id)
	return idx == 1 or owned.has(node_id(branch_of(id), idx - 1))


## 保存データの正規化。不正なIDと、途中が抜けたマス（一本道を満たさないもの）を捨てる。
static func sanitize(raw, branches: Array) -> Array:
	var owned: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return owned
	for branch in branches:
		for id in node_ids(str(branch)):
			if not (raw as Array).has(id):
				break
			owned.append(id)
	return owned


static func count_in(owned: Array, branches: Array) -> int:
	var n: int = 0
	for id in owned:
		if branches.has(branch_of(str(id))):
			n += 1
	return n


static func empty_bonus() -> Dictionary:
	return {
		"max_hp": 0, "max_sanity": 0, "strength": 0, "energy": 0, "draw": 0,
		"deck_limit": 0, "strength_mul": 1, "turn_block": 0, "turn_san_full": false,
	}


## 取得済みマスの効果を合算する。strength_mul は掛け算ではなく「持っていれば2」。
static func bonus(owned: Array) -> Dictionary:
	var out: Dictionary = empty_bonus()
	for raw_id in owned:
		var eff: Dictionary = effect_of(str(raw_id))
		for key in eff.keys():
			if key == "strength_mul":
				out.strength_mul = maxi(int(out.strength_mul), int(eff[key]))
			elif key == "turn_san_full":
				out.turn_san_full = true
			else:
				out[key] = int(out[key]) + int(eff[key])
	return out
