extends Control

## 実ソースの RewardView.tsx 相当。フェーズAでは戦利品の実データ無しのダミー表示。

@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	status_label.text = "%s\n戦利品（ダミー）" % Floors.layer_label(GameState.floor)


func _on_continue_button_pressed() -> void:
	GameState.claim_reward(get_tree())
