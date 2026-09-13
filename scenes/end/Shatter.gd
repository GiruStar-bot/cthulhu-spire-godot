extends Control

## 実ソースの ShatterView.tsx 相当（正気0での「全ロスト」画面）。

func _on_title_button_pressed() -> void:
	GameState.accept_shatter(get_tree())
