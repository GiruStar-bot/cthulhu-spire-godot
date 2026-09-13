extends Control

## 実ソースの EventView.tsx 相当。フェーズAでは実イベント本文/選択肢無しのダミー。
## 選択肢は2つとも resolve_event() へ渡し、finishAdvance()相当の分岐に合流させる。

@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	status_label.text = "%s\n予兆（ダミー）" % Floors.layer_label(GameState.floor)


func _on_choice_a_button_pressed() -> void:
	GameState.resolve_event(get_tree(), "a")


func _on_choice_b_button_pressed() -> void:
	GameState.resolve_event(get_tree(), "b")
