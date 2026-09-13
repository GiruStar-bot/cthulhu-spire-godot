extends Control

## 実ソースの HubScreen.tsx 相当。単一画面＋サイドナビ（タブ）で
## 探索開始/デッキ編成/装備/売却/ショップ/カードパックを行き来する。
## floor>0（中継点）でもfloor==0（拠点）でも同じこの画面が使われ、
## descendタブの中身だけが CheckpointPanel / PrepareView 相当で切り替わる。
## フェーズAで実装するのは「探索開始」タブのみ。他は未実装プレースホルダー。

@onready var player_name_label: Label = $Root/Header/PlayerNameLabel
@onready var info_label: Label = $Root/Header/InfoLabel
@onready var top_right_button: Button = $Root/Header/TopRightButton

@onready var descend_panel: VBoxContainer = $Root/Body/Content/DescendPanel
@onready var descend_status_label: Label = $Root/Body/Content/DescendPanel/DescendStatusLabel
@onready var primary_action_button: Button = $Root/Body/Content/DescendPanel/PrimaryActionButton
@onready var extract_button: Button = $Root/Body/Content/DescendPanel/ExtractButton

@onready var placeholder_panel: Label = $Root/Body/Content/PlaceholderPanel

@onready var nav_buttons: Dictionary = {
	"descend": $Root/Body/Nav/DescendButton,
	"deck": $Root/Body/Nav/DeckButton,
	"equipment": $Root/Body/Nav/EquipmentButton,
	"sell": $Root/Body/Nav/SellButton,
	"shop": $Root/Body/Nav/ShopButton,
	"packs": $Root/Body/Nav/PacksButton,
}


func _ready() -> void:
	for tab_name in nav_buttons.keys():
		nav_buttons[tab_name].pressed.connect(_select_tab.bind(tab_name))
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	extract_button.pressed.connect(_on_extract_button_pressed)
	top_right_button.pressed.connect(_on_top_right_button_pressed)
	_select_tab("descend")
	_update_header()
	if GameState.toast != "":
		GameState.toast = ""


func _select_tab(tab_name: String) -> void:
	for key in nav_buttons.keys():
		nav_buttons[key].disabled = key == tab_name
	descend_panel.visible = tab_name == "descend"
	placeholder_panel.visible = tab_name != "descend"
	if tab_name == "descend":
		_update_descend_panel()
	else:
		placeholder_panel.text = "未実装（フェーズB以降）"


func _update_header() -> void:
	player_name_label.text = GameState.player_name if GameState.player_name != "" else "無名"
	if GameState.floor > 0:
		info_label.text = "%s · デッキ %d/%d" % [
			Floors.layer_label(GameState.floor),
			_deck_count(),
			CollectionData.DECK_LIMIT,
		]
		top_right_button.text = "帰還"
	else:
		info_label.text = "最深 %s · デッキ %d/%d" % [
			Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "—",
			_deck_count(),
			CollectionData.DECK_LIMIT,
		]
		top_right_button.text = "タイトル"


func _update_descend_panel() -> void:
	if GameState.floor > 0:
		## HubScreen.tsx の CheckpointPanel 相当
		descend_status_label.text = "中継点\n%sを越えた\nHP %d/%d · SAN %d/%d · 貝殻 %d" % [
			Floors.layer_label(GameState.floor),
			GameState.hp,
			GameState.max_hp,
			GameState.sanity,
			GameState.max_sanity,
			GameState.shells,
		]
		primary_action_button.text = "次の層へ沈む"
		extract_button.visible = true
	else:
		## PrepareView.tsx 相当（ステ振り・デッキ選択は未実装、フェーズB以降）
		descend_status_label.text = "探索準備\n最深到達: %s · 貝殻 %d" % [
			Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "未潜航",
			GameState.shells,
		]
		primary_action_button.text = "潜航開始"
		extract_button.visible = false


func _deck_count() -> int:
	var counts: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	var total := 0
	for v in counts.values():
		total += v
	return total


func _on_primary_action_pressed() -> void:
	if GameState.floor <= 0:
		GameState.start_run(get_tree())
	else:
		GameState.resume_descent(get_tree())


func _on_extract_button_pressed() -> void:
	## extract_to_hub()はシーンを"hub"（＝このシーン自身）に戻す＝再読込されるため、
	## 再読込後の_ready()がヘッダー/タブ表示を作り直す。
	GameState.extract_to_hub(get_tree())


func _on_top_right_button_pressed() -> void:
	if GameState.floor > 0:
		GameState.extract_to_hub(get_tree())
	else:
		GameState.to_title(get_tree())
