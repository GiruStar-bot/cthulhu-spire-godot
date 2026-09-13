extends Control

## 実ソースの CombatView.tsx + combat.ts 相当。フェーズAではカードプレイ無しの
## ダミー勝敗ボタンのみ（フェーズBでカード1枚のプレイ→ダメージを実装予定）。
## 勝利はGameState.win_combat()経由でreward画面へ、敗北はGameState.lose_combat()
## 経由でdefeat/shatterへ、それぞれ実ソースのpresentCombat()の分岐を再現する。

@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	var kind: String = GameState.combat.get("kind", "combat") if GameState.combat else "combat"
	status_label.text = "%s（%s・ダミー）" % [Floors.layer_label(GameState.floor), Floors.floor_kind_label(kind, GameState.floor)]


func _on_win_button_pressed() -> void:
	GameState.win_combat(get_tree())


func _on_lose_button_pressed() -> void:
	GameState.lose_combat(get_tree())
