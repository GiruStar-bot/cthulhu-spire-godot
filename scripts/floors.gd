class_name Floors
extends RefCounted

## src/game/floors.ts 相当。フロア種別の決定的生成ロジックのみを移植する。
## イベント本文・敵編成の実データ（EVENTS/encounterIds）はフェーズB以降。

const DEMO_MAX_FLOOR := 100


## floors.ts の typeFor()
static func type_for(floor: int, rng: Mulberry32) -> String:
	if floor % 10 == 0:
		return "boss"
	if floor % 10 == 5:
		return "rest"
	if floor == 1:
		return "combat" if rng.next_float() < 0.82 else "event"
	var r := rng.next_float()
	if r < 0.2:
		return "event"
	if r < 0.26:
		return "elite"
	return "combat"


## floors.ts の generateRunTable()
## 戻り値: [{floor:int, type:String, event_id:String, enemy_ids:Array}, ...]
## event_id/enemy_ids は実データ未接続のため常に空（フェーズB以降で埋める）。
static func generate_run_table(rng: Mulberry32, max_floor: int = DEMO_MAX_FLOOR) -> Array:
	var out: Array = []
	for floor in range(1, max_floor + 1):
		var t := type_for(floor, rng)
		var spec := {"floor": floor, "type": t}
		if t == "event":
			spec["event_id"] = ""
		elif t != "rest":
			spec["enemy_ids"] = []
		out.append(spec)
	return out


## floors.ts の layerLabel()
static func layer_label(floor: int) -> String:
	return "第%d層" % floor


## floors.ts の floorKindLabel()
static func floor_kind_label(kind: String, floor: int) -> String:
	if kind == "boss":
		if floor >= 100:
			return "全なる者"
		if floor % 50 == 0:
			return "大ボス"
		return "中ボス"
	if kind == "elite":
		return "精鋭"
	if kind == "combat":
		return "守護"
	if kind == "rest":
		return "村落"
	return "予兆"
