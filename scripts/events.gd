class_name Events
extends RefCounted

## src/game/events.ts の忠実移植。

const EVENTS := [
	{
		"id": "tome",
		"title": "在ってはならない本",
		"body": "生きた石の書見台に、開かれたまま置かれている。瞬きするたび、文字が組み替わる。目を逸らすこともできる。",
		"choices": [
			{"id": "read", "label": "読む", "result": "知識が流れ込む。正気-8。ランダムなカードを強化。『禁断の書』を得る。"},
			{"id": "leave", "label": "閉じたままにする", "result": "歩き続ける。何も学ばない。"},
		],
	},
	{
		"id": "well",
		"title": "静かな井戸",
		"body": "真っ黒な水。完全に静止し、頭上にない空を映している。匂いは、水ではない。",
		"choices": [
			{"id": "drink", "label": "飲む", "result": "18回復。正気-7。"},
			{"id": "wash", "label": "手を洗う", "result": "8回復。正気+4。"},
		],
	},
	{
		"id": "cult",
		"title": "集会",
		"body": "頭巾の人々が道を開ける。まだ与えられていない名前を、待っていたように。",
		"choices": [
			{"id": "kneel", "label": "跪く", "result": "遺物を得る。正気-10。"},
			{"id": "refuse", "label": "名を拒む", "result": "失望される。体力-8。正気+6。"},
		],
	},
	{
		"id": "mirror",
		"title": "誤った回廊",
		"body": "黒いガラスを通り過ぎる。反射は、すでに廊下の先で待っている。",
		"choices": [
			{"id": "follow", "label": "追う", "result": "次の戦闘、最初のターンにエネルギー+2。"},
			{"id": "smash", "label": "割る", "result": "体力-10。この沈降中、筋力+2。"},
		],
	},
	## 会話モーダル（scenes/event/DialogueEventModal.gd）で進むイベント。
	## 表示するのは台詞と選択肢の文字だけ。id（開発用の呼び名）は画面に出さない。
	## choices は先頭が立ち絵の左、2つ目が右。reply がある選択肢は返事を見せてから進む。
	{
		"id": "eihort",
		"presentation": "dialogue",
		"background": "res://art/pixel/events/eihort_labyrinth.png",
		"portrait": "res://art/pixel/enemies/eihort.png",
		"line": "お、人間じゃん。君の子を産んでみない？",
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


static func pick_event(rand: Callable) -> Dictionary:
	if EVENTS.is_empty():
		return {}
	return Mulberry32.pick_rand(EVENTS, rand)
