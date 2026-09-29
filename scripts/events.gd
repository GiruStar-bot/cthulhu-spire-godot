class_name Events
extends RefCounted

## 予兆イベント。会話モーダル（presentation: "dialogue"）だけを載せる。
## 旧テキストイベント（tome / well / cult / mirror）は廃止。

const EVENTS := [
	## 会話モーダル（scenes/event/DialogueEventModal.gd）で進むイベント。
	## 表示するのは台詞と選択肢の文字だけ。id（開発用の呼び名）は画面に出さない。
	## choices は先頭が立ち絵の左、2つ目が右。reply がある選択肢は返事を見せてから進む。
	{
		"id": "eihort",
		"presentation": "dialogue",
		"background": "res://art/pixel/events/eihort_labyrinth.png",
		"portrait": "res://art/pixel/enemies/eihort.png",
		"line": "お、人間じゃん。君、僕の子を産んでみない？",
		"choices": [
			{"id": "fight", "label": "戦う"},
			{"id": "bear", "label": "子を宿す", "reply": "やった！ありがとう！"},
		],
	},
]


static func get_event(event_id: String) -> Dictionary:
	for ev in EVENTS:
		if str(ev.get("id", "")) == event_id:
			return ev
	return {}


## 0 はこの世界周期で抽選停止。1〜3 はクトゥグァの次の場面。
static func pick_event(rand: Callable, cthugha_stage: int = 0) -> Dictionary:
	var pool: Array = EVENTS.duplicate()
	if cthugha_stage >= 1 and cthugha_stage <= 3:
		pool.append({
			"id": "cthugha",
			"presentation": "cthugha",
			"stage": cthugha_stage,
		})
	if pool.is_empty():
		return {}
	return Mulberry32.pick_rand(pool, rand)
