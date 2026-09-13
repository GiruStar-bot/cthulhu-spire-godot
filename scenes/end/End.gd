extends Control

## 実ソースの EndView.tsx 相当（kind="victory"|"defeat"を1コンポーネントで共有）。
## GameState.scene の値で表示を切り替える。ボタンはどちらもgiveUp()相当（拠点hubへ戻る）。
##
## 実ソースの victory 画面はボタン表記が「タイトルへ戻る」なのに実際は拠点(hub)へ戻る
## giveUp()を呼ぶ食い違いがあるが、本移植ではこれは実装ミスと判断し、
## 表記を実動作に合わせて「帰還」に修正した（動作＝giveUp()自体は変更していない）。

@onready var title_label: Label = $TitleLabel
@onready var status_label: Label = $StatusLabel
@onready var action_button: Button = $ActionButton


func _ready() -> void:
	if GameState.scene == "victory":
		title_label.text = "見てしまった。"
		status_label.text = "最深 %s" % (Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "未潜航")
		action_button.text = "帰還"
	else:
		title_label.text = "死亡"
		status_label.text = "%sで止まった" % Floors.layer_label(GameState.floor)
		action_button.text = "拠点へ戻る"


func _on_action_button_pressed() -> void:
	GameState.give_up(get_tree())
