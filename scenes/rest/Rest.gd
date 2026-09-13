extends Control

## 実ソースの RestView.tsx 相当（村ハブ→酒場/鍛冶屋のサブ画面）。
## GameState.rest_mode（""扱い="hub"）で表示を切り替える。sceneは"rest"のまま。
## 酒場/鍛冶屋の中身（宿泊・購入等）はフェーズB以降、ここではプレースホルダーのみ。

@onready var status_label: Label = $StatusLabel
@onready var inn_button: Button = $VillageButtons/InnButton
@onready var smith_button: Button = $VillageButtons/SmithButton
@onready var leave_button: Button = $VillageButtons/LeaveButton
@onready var back_button: Button = $BackButton


func _ready() -> void:
	if GameState.rest_mode == "":
		GameState.rest_mode = "hub"
	_refresh()


func _refresh() -> void:
	var mode: String = GameState.rest_mode
	var is_hub := mode == "hub" or mode == ""
	var caption := "村（休憩ノード）" if is_hub else ("酒場（未実装）" if mode == "inn" else "鍛冶屋（未実装）")
	status_label.text = "%s\n%s" % [Floors.layer_label(GameState.floor), caption]
	inn_button.visible = is_hub
	smith_button.visible = is_hub
	leave_button.visible = is_hub
	back_button.visible = not is_hub


func _on_inn_button_pressed() -> void:
	GameState.visit_village("inn")
	_refresh()


func _on_smith_button_pressed() -> void:
	GameState.visit_village("smith")
	_refresh()


func _on_back_button_pressed() -> void:
	GameState.visit_village("hub")
	_refresh()


func _on_leave_button_pressed() -> void:
	GameState.leave_village(get_tree())
