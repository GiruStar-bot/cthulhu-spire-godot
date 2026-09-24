extends Control

## Godot向けHub画面。単一画面＋サイドナビで、探索準備・ロードアウト・
## 売買・パック開封を一貫して操作する。ゲームロジックと永続データは
## Autoload／scripts側に置き、このスクリプトは表示と入力の接続を担当する。

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const PACK_OPEN_SCENE := preload("res://scenes/hub/PackOpen.tscn")
const INSPECTOR_CARD_SIZE := Vector2(220, 330)
const INSPECTOR_IN_DUR := 0.22
const INSPECTOR_OUT_DUR := 0.20
const INSPECTOR_BTN_DUR := 0.14
const INSPECTOR_GHOST_DUR := 0.16
const PACK_TILE_W := 176.0
## デッキ編成のカードプール。POOL_CARD_SIZE が可読性の下限。列数を決めたあと、
## 端数はまずカードを最大 POOL_CARD_MAX_W まで大きくして吸収し、残りを列間隔へ配る。
const POOL_CARD_SIZE := Vector2(128, 192)
const POOL_CARD_MAX_W := 160.0
const POOL_CARD_GAP := 8
const POOL_CARD_GAP_MAX := 40
const POOL_BAR_GAP := 6  ## 右端カードとスクロールバーの間。グロー（外側22px）は下のZ順でバーの下に回す
const PACK_ART_SIZE := Vector2(160, 240)

@onready var background_art: TextureRect = $BackgroundArt
@onready var player_name_label: Label = $Root/Header/PlayerNameLabel
@onready var info_label: Label = $Root/Header/InfoLabel
@onready var top_right_button: Button = $Root/Header/TopRightButton

@onready var descend_panel: HBoxContainer = $Root/Body/Content/DescendPanel
@onready var descend_status_label: Label = $Root/Body/Content/DescendPanel/DescendLeftColumn/DescendStatusLabel
@onready var primary_action_button: Button = $Root/Body/Content/DescendPanel/DescendLeftColumn/PrimaryActionButton
@onready var extract_button: Button = $Root/Body/Content/DescendPanel/DescendLeftColumn/ExtractButton
@onready var stat_panel: VBoxContainer = $Root/Body/Content/DescendPanel/DescendLeftColumn/StatPanel
@onready var stat_header_label: Label = $Root/Body/Content/DescendPanel/DescendLeftColumn/StatPanel/StatHeaderLabel
@onready var stat_rows_container: VBoxContainer = $Root/Body/Content/DescendPanel/DescendLeftColumn/StatPanel/StatRowsContainer
@onready var prepare_deck_select_panel: PanelContainer = $Root/Body/Content/DescendPanel/PrepareDeckSelectPanel
@onready var prepare_deck_list: VBoxContainer = $Root/Body/Content/DescendPanel/PrepareDeckSelectPanel/Margin/Content/DeckList
@onready var prepare_selected_deck_label: Label = $Root/Body/Content/DescendPanel/PrepareDeckSelectPanel/Margin/Content/SelectedDeckLabel

@onready var placeholder_panel: Label = $Root/Body/Content/PlaceholderPanel
@onready var commerce_panel: VBoxContainer = $Root/Body/Content/CommercePanel
@onready var commerce_title: Label = $Root/Body/Content/CommercePanel/CommerceTitle
@onready var commerce_list: VBoxContainer = $Root/Body/Content/CommercePanel/CommerceList

@onready var sell_panel: VBoxContainer = $Root/Body/Content/SellPanel
@onready var sell_card_tab_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellCardTabButton
@onready var sell_surplus_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellSurplusButton
@onready var sell_select_all_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellSelectAllButton
@onready var sell_clear_all_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellClearAllButton
@onready var sell_list_container: HFlowContainer = $Root/Body/Content/SellPanel/SellListScroll/SellListContainer
@onready var sell_total_label: Label = $Root/Body/Content/SellPanel/SellFooterRow/SellTotalLabel
@onready var sell_confirm_button: Button = $Root/Body/Content/SellPanel/SellFooterRow/SellConfirmButton

@onready var deck_panel: VBoxContainer = $Root/Body/Content/DeckPanel
@onready var starter_pick_panel: VBoxContainer = $Root/Body/Content/DeckPanel/StarterPickPanel

@onready var deck_list_sub_panel: VBoxContainer = $Root/Body/Content/DeckPanel/DeckListSubPanel
@onready var deck_list_create_button: Button = $Root/Body/Content/DeckPanel/DeckListSubPanel/DeckListHeaderRow/DeckListCreateButton
@onready var deck_list_back_button: Button = $Root/Body/Content/DeckPanel/DeckListSubPanel/DeckListHeaderRow/DeckListBackButton
@onready var deck_list_container: VBoxContainer = $Root/Body/Content/DeckPanel/DeckListSubPanel/DeckListScroll/DeckListContainer

@onready var deck_edit_sub_panel: VBoxContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel
@onready var deck_edit_title_label: Label = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckEditHeaderRow/DeckEditTitleLabel
@onready var rename_deck_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckEditHeaderRow/RenameDeckButton
@onready var delete_deck_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckEditHeaderRow/DeleteDeckButton
@onready var deck_rename_row: HBoxContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckRenameRow
@onready var deck_rename_edit: LineEdit = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckRenameRow/DeckRenameEdit
@onready var confirm_rename_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckRenameRow/ConfirmRenameButton
@onready var cancel_rename_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckRenameRow/CancelRenameButton
@onready var deck_count_label: Label = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/DeckContentsPanel/DeckContents/DeckCountLabel
@onready var deck_error_label: Label = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckErrorLabel
@onready var deck_search_edit: LineEdit = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckSearchRow/DeckSearchEdit
@onready var deck_sort_option_button: OptionButton = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckSearchRow/DeckSortOptionButton
@onready var deck_filter_reset_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckSearchRow/DeckFilterResetButton
@onready var deck_filter_archetype_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckSearchRow/ArchetypeButton
@onready var deck_filter_rarity_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckSearchRow/RarityButton
@onready var deck_filter_ai_tag_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckSearchRow/AiTagButton
@onready var deck_filter_archetype_popover: PanelContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterArchetypePopover
@onready var deck_filter_rarity_popover: PanelContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterRarityPopover
@onready var deck_filter_ai_tag_popover: PanelContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterAiTagPopover
@onready var deck_filter_archetype_row: HFlowContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterArchetypePopover/DeckFilterArchetypeRow
@onready var deck_filter_rarity_row: HFlowContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterRarityPopover/DeckFilterRarityRow
@onready var deck_filter_ai_tag_row: HFlowContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterAiTagPopover/DeckFilterAiTagRow
@onready var deck_result_count_label: Label = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckResultCountLabel
@onready var card_scroll: ScrollContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/CardScrollFrame/CardScroll
@onready var card_list_container: GridContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/CardScrollFrame/CardScroll/CardListContainer
@onready var deck_contents_container: VBoxContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/DeckContentsPanel/DeckContents/DeckContentsScroll/DeckContentsContainer
@onready var deck_back_to_list_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/DeckContentsPanel/DeckContents/DeckBackToListButton

@onready var nav_buttons: Dictionary = {
	"descend": $Root/Body/Nav/DescendButton,
	"deck": $Root/Body/Nav/DeckButton,
	"sell": $Root/Body/Nav/SellButton,
	"shop": $Root/Body/Nav/ShopButton,
	"packs": $Root/Body/Nav/PacksButton,
}
@onready var body_nav: VBoxContainer = $Root/Body/Nav
@onready var nav_frame: Panel = $NavFrame

var _commerce_tab := ""
var _last_pack_result: Array = []  ## store.ts の lastPackResult 相当（ShopPanel.tsx の通常パック結果表示）
var _pack_open: Control = null

# SellScreen.tsx 相当の状態
var _sell_card_selections: Dictionary = {}  ## base_card_id -> 選択数
var _sell_card_row_nodes: Dictionary = {}  ## base_card_id -> {qty_label, minus_btn, plus_btn, sellable}

# ============================================================
# デッキ編成/装備タブの検索・フィルター・ソート
# （DeckBuilderScreen.tsx / EquipmentScreen.tsx 相当）
# ここに無いフレーム（風・火・豊穣・魔導）は専用パックを持たない。
# カード自体の archetype と枠画像は別定数のまま残す。
# ============================================================

## 絞り込み・ジャンル順ソートの対象。scripts/cards.gd に実在する archetype に合わせる
## （greatold は現データに無いので外す。archetype 無し＝generic は対象外）。
const DECK_FILTERABLE_ARCHETYPES := ["knight", "outer", "elder", "water", "all", "fire", "wind", "earth", "magic", "fanatic", "shadow"]
const DECK_FILTERABLE_RARITIES := ["common", "uncommon", "rare", "legendary", "status"]
const DECK_FILTERABLE_AI_TAGS := ["attack", "defense", "effect"]
const DECK_RARITY_ORDER := ["common", "uncommon", "rare", "legendary", "status"]
const DECK_SORT_MODES := ["cost", "rarity", "owned", "archetype"]
const DECK_SORT_LABELS := {"cost": "コスト順", "rarity": "レア度順", "owned": "所持数順", "archetype": "ジャンル順"}
const RARITY_LABELS := {"common": "コモン", "uncommon": "アンコモン", "rare": "レア", "legendary": "レジェンダリー", "status": "状態"}
const AI_TAG_LABELS := {"attack": "攻撃", "defense": "防御", "effect": "効果"}

const NORMAL_PACK_ART := "res://art/pixel/ui/card_back.png"


## Hub デッキ棚（正四角タイル）。顔は deck_tile_*。pack fallback なし。
const DECK_SHELF_COLORS := {
	"fanatic": Color("6B1F22"),
	"knight": Color("5C6570"),
	"poison": Color("2F5C3A"),
	"water": Color("1F4A5C"),
	"outer": Color("3A2A55"),
	"elder": Color("4A4538"),
	"offering": Color("5C4A2E"),
	"shadow": Color("2A2438"),
	"greatold": Color("3A2850"),
	"all": Color("3A3548"),
	"none": Color("2A2430"),
}
const DECK_SHELF_DEFAULT_COLOR := Color("2A2430")
const DECK_SHELF_TILE_FMT := "res://art/pixel/ui/deck_tile_%s.png"
const DECK_SHELF_TILE := Vector2(128, 128)
const DECK_SHELF_ARCHETYPE_MIN := 4  ## 同一属性がこの枚数以上で属性タイル、未満は none

var _deck_mode: String = "list"  ## DeckHubScreen.tsx の mode: "list" | "edit"
var _deck_edit_open: bool = false
var _deck_edit_working: Dictionary = {}
var _deck_edit_snapshot: Dictionary = {}
var _pending_deck_leave: String = ""
var _active_deck_before_edit: String = ""  ## 空デッキを自動削除したとき、編集前の選択へ戻すため
var _deck_leave_bypass: bool = false
var _deck_save_layer: CanvasLayer = null
var _deck_renaming: bool = false
var _deck_filter_archetypes: Dictionary = {}
var _deck_filter_rarities: Dictionary = {}
var _deck_filter_ai_tags: Dictionary = {}
var _deck_search: String = ""
var _deck_sort_mode: String = "cost"
var _inspector_card_id: String = ""
var _inspector_layer: Control = null
var _inspector_dim: ColorRect = null
var _inspector_card: CombatCard = null
var _inspector_actions: HBoxContainer = null
var _inspector_minus: Button = null
var _inspector_plus: Button = null
var _inspector_count: Label = null
var _inspector_busy_close: bool = false
var _inspector_card_tween: Tween = null
var _deck_contents_dirty: bool = false



func _ready() -> void:
	for tab_name in nav_buttons.keys():
		nav_buttons[tab_name].pressed.connect(_select_tab.bind(tab_name))
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	extract_button.pressed.connect(_on_extract_button_pressed)
	top_right_button.pressed.connect(_on_top_right_button_pressed)
	deck_list_create_button.pressed.connect(_on_deck_list_create_pressed)
	deck_list_back_button.pressed.connect(_select_tab.bind("descend"))
	card_scroll.resized.connect(_fit_card_grid)
	## ScrollContainer 内部のバーは中身より先に描かれる。カードのグローやホバー拡大（z 40）より上へ出す。
	card_scroll.get_v_scroll_bar().z_index = 50
	rename_deck_button.pressed.connect(_on_rename_deck_pressed)
	delete_deck_button.pressed.connect(_on_delete_deck_pressed)
	confirm_rename_button.pressed.connect(_on_rename_confirm_pressed)
	cancel_rename_button.pressed.connect(_on_rename_cancel_pressed)
	deck_back_to_list_button.pressed.connect(_on_deck_back_to_list_pressed)
	sell_surplus_button.pressed.connect(_on_sell_surplus_pressed)
	sell_select_all_button.pressed.connect(_on_sell_select_all_pressed)
	sell_clear_all_button.pressed.connect(_on_sell_clear_all_pressed)
	sell_confirm_button.pressed.connect(_on_sell_confirm_pressed)
	_setup_deck_filters()
	prepare_deck_select_panel.visible = false
	_ensure_deck_save_dialog()
	body_nav.size_flags_vertical = 0
	_apply_dream_hub_look()
	_select_tab("descend")
	_update_header()
	call_deferred("_fit_nav_chrome")
	if GameState.toast != "":
		GameState.toast = ""



## Dream Island: same Hub skeleton; swap BG + light island labels when realm is dream.
## Theme（金石板ルック）差し替えは後続。まずは機能ロック／ラベル優先。
func _apply_dream_hub_look() -> void:
	if str(GameState.realm) != "dream":
		return
	if background_art != null:
		var path := "res://art/pixel/bg/dream_hub.jpg"
		if not ResourceLoader.exists(path):
			path = "res://art/pixel/bg/dream_title.png"
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				background_art.texture = tex
	## ナビ：島向けラベル。探索タブ自体は開けるが主ボタンは封印（dim）。
	## 祝福/休憩ナビは未実装のため追加しない。
	if nav_buttons.has("descend") and nav_buttons["descend"]:
		nav_buttons["descend"].text = "探索（封印）"
		nav_buttons["descend"].modulate = Color(1, 1, 1, 0.55)
	if nav_buttons.has("deck") and nav_buttons["deck"]:
		nav_buttons["deck"].text = "デッキ"
	if nav_buttons.has("shop") and nav_buttons["shop"]:
		nav_buttons["shop"].text = "ショップ"

func _fit_nav_chrome() -> void:
	if nav_frame == null or body_nav == null:
		return
	var min_size: Vector2 = body_nav.get_combined_minimum_size()
	nav_frame.offset_top = 36.0
	nav_frame.offset_right = 120.0
	nav_frame.offset_bottom = 36.0 + min_size.y
	nav_frame.visible = body_nav.visible


## デッキ編成タブの検索欄・ソートドロップダウン・フィルタートグル行を一度だけ構築する。
func _setup_deck_filters() -> void:
	deck_search_edit.text_changed.connect(_on_deck_search_changed)
	deck_filter_reset_button.pressed.connect(_on_deck_filter_reset_pressed)
	deck_filter_archetype_button.pressed.connect(_toggle_deck_popover.bind(deck_filter_archetype_popover))
	deck_filter_rarity_button.pressed.connect(_toggle_deck_popover.bind(deck_filter_rarity_popover))
	deck_filter_ai_tag_button.pressed.connect(_toggle_deck_popover.bind(deck_filter_ai_tag_popover))

	deck_sort_option_button.clear()
	for mode in DECK_SORT_MODES:
		deck_sort_option_button.add_item(str(DECK_SORT_LABELS.get(mode, mode)))
	deck_sort_option_button.select(DECK_SORT_MODES.find(_deck_sort_mode))
	deck_sort_option_button.item_selected.connect(_on_deck_sort_selected)

	_build_toggle_row(deck_filter_archetype_row, DECK_FILTERABLE_ARCHETYPES,
		func(a): return str(Cards.ARCHETYPE_LABELS.get(a, a)),
		_deck_filter_archetypes, _on_deck_filter_archetype_toggled)
	_build_toggle_row(deck_filter_rarity_row, DECK_FILTERABLE_RARITIES,
		func(r): return str(RARITY_LABELS.get(r, r)),
		_deck_filter_rarities, _on_deck_filter_rarity_toggled)
	_build_toggle_row(deck_filter_ai_tag_row, DECK_FILTERABLE_AI_TAGS,
		func(t): return str(AI_TAG_LABELS.get(t, t)),
		_deck_filter_ai_tags, _on_deck_filter_ai_tag_toggled)
	_float_deck_filter_popovers()




## 複数選択トグル行を一度だけ構築する共通ヘルパー。
## option_label: (value) -> String、on_toggle: (pressed: bool, value) -> void
func _build_toggle_row(container: Control, options: Array, option_label: Callable, state: Dictionary, on_toggle: Callable) -> void:
	for child in container.get_children():
		child.queue_free()
	for opt in options:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = str(option_label.call(opt))
		btn.button_pressed = state.has(opt)
		btn.toggled.connect(on_toggle.bind(opt))
		container.add_child(btn)


func _float_deck_filter_popovers() -> void:
	var overlay: Control = deck_panel.get_parent() as Control
	if overlay == null:
		return
	for panel in [deck_filter_archetype_popover, deck_filter_rarity_popover, deck_filter_ai_tag_popover]:
		if panel.get_parent() == overlay:
			continue
		panel.reparent(overlay, false)
		panel.visible = false
		panel.z_index = 40


func _toggle_deck_popover(target: Control) -> void:
	var opening: bool = not target.visible
	for panel in [deck_filter_archetype_popover, deck_filter_rarity_popover, deck_filter_ai_tag_popover]:
		panel.visible = false
	if not opening:
		return
	var anchor: Control = deck_filter_archetype_button
	if target == deck_filter_rarity_popover:
		anchor = deck_filter_rarity_button
	elif target == deck_filter_ai_tag_popover:
		anchor = deck_filter_ai_tag_button
	var min_size: Vector2 = target.get_combined_minimum_size()
	target.size = Vector2(maxf(280.0, min_size.x), maxf(48.0, min_size.y))
	var pos: Vector2 = anchor.global_position + Vector2(0.0, anchor.size.y + 4.0)
	var view: Vector2 = get_viewport_rect().size
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - target.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - target.size.y - 8.0))
	target.global_position = pos
	target.visible = true


## _build_toggle_row()で構築済みの行のボタン押下状態を、リセット等で外部からstateを
## 変更した後に再同期する（シグナルは発火させない）。
func _sync_toggle_row(container: Control, options: Array, state: Dictionary) -> void:
	var i := 0
	for child in container.get_children():
		if child is Button and i < options.size():
			child.set_pressed_no_signal(state.has(options[i]))
		i += 1


## Content配下の全パネルをまとめて非表示にする。tab === "packs" || tab === "deck" の時
## Content内の他パネルが一切見えない（HubScreen.tsx 42-62行目の早期returnレンダー）実ソースの
## 挙動を、個別のvisible設定漏れが起きないよう一箇所にまとめて再現する。
func _hide_all_content_panels() -> void:
	_close_card_inspector()
	descend_panel.visible = false
	deck_panel.visible = false
	sell_panel.visible = false
	commerce_panel.visible = false
	placeholder_panel.visible = false


func _select_tab(tab_name: String) -> void:
	if not _deck_leave_bypass and _deck_mode == "edit" and _deck_edit_blocks_leave():
		_pending_deck_leave = "list" if tab_name == "deck" else "tab:" + tab_name
		_show_deck_save_dialog()
		return
	if _deck_mode == "edit" and not _deck_leave_bypass:
		_close_deck_edit()
		_deck_mode = "list"
	for key in nav_buttons.keys():
		nav_buttons[key].set_pressed_no_signal(key == tab_name)
	_hide_all_content_panels()
	## パック・デッキ（一覧/編集の両モード）は全幅。戻るボタンは各画面側に置く。
	var hide_nav: bool = tab_name == "packs" or tab_name == "deck"
	if body_nav != null:
		body_nav.visible = not hide_nav
	if nav_frame != null:
		nav_frame.visible = not hide_nav
		if nav_frame.visible:
			call_deferred("_fit_nav_chrome")
	match tab_name:
		"descend":
			descend_panel.visible = true
		"deck":
			deck_panel.visible = true
		"sell":
			sell_panel.visible = true
		"shop", "packs":
			commerce_panel.visible = true
	if tab_name == "descend":
		_update_descend_panel()
	elif tab_name == "deck":
		## HubScreen.tsx では"deck"タブは専用の早期returnレンダー（DeckHubScreen）に
		## 切り替わり、他のタブへ移動すると通常アンマウントされる。そのためmode(useState)は
		## タブへ再入するたびに初期値"list"へ戻る。ここではそれをタブ選択時のリセットで再現する。
		_deck_mode = "list"
		_deck_renaming = false
		_refresh_deck_tab()
	elif tab_name == "sell":
		## HubScreen.tsx の {tab === "sell" ? <SellScreen .../> : null} も、deckタブ同様
		## タブ切替でSellScreenがアンマウント/再マウントされ、選択状態(useState)は
		## タブへ再入するたびに初期化される。ここでも同じくタブ選択時にリセットする。
		_sell_card_selections.clear()
		_refresh_sell_tab()
	elif commerce_panel.visible:
		_commerce_tab = tab_name
		_refresh_commerce()


func _update_header() -> void:
	player_name_label.text = GameState.player_name if GameState.player_name != "" else "無名"
	if GameState.floor > 0:
		info_label.text = "%s　｜　デッキ %d/%d　｜　貝殻 %d" % [
			Floors.layer_label(GameState.floor),
			_deck_count(),
			CollectionData.DECK_LIMIT,
			GameState.shells,
		]
		top_right_button.text = "帰還"
	else:
		info_label.text = "最深 %s　｜　デッキ %d/%d　｜　貝殻 %d" % [
			Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "—",
			_deck_count(),
			CollectionData.DECK_LIMIT,
			GameState.shells,
		]
		top_right_button.text = "タイトル"


func _update_descend_panel() -> void:
	if GameState.floor > 0:
		## HubScreen.tsx の CheckpointPanel 相当
		var blessing_line: String = "加護 なし"
		if GameState.run_blessings.size() > 0:
			var names: Array = []
			for blessing_id in GameState.run_blessings:
				var def: Dictionary = Blessings.get_def(str(blessing_id))
				names.append(str(def.get("name", blessing_id)))
			blessing_line = "加護 %s" % " · ".join(PackedStringArray(names))
		descend_status_label.text = "中継点\n%sを越えた\nHP %d/%d · SAN %d/%d · 貝殻 %d\n%s" % [
			Floors.layer_label(GameState.floor),
			GameState.hp,
			GameState.max_hp,
			GameState.sanity,
			GameState.max_sanity,
			GameState.shells,
			blessing_line,
		]
		primary_action_button.text = "次の層へ沈む"
		primary_action_button.disabled = false
		extract_button.visible = true
		stat_panel.visible = false
		prepare_deck_select_panel.visible = false
	else:
		## PrepareView.tsx 相当。canStart は実ソースでは
		## `playerName.trim().length > 0 && !loadoutError()` だが、名前入力UIは未実装のため
		## デッキ枚数チェック（loadoutError()）のみを反映する。
		descend_status_label.text = "探索準備\n最深到達: %s · 貝殻 %d\n使用デッキ: %s（%d/%d）" % [
			Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "未潜航",
			GameState.shells,
			CollectionData.active_deck,
			_deck_count(),
			CollectionData.DECK_LIMIT,
		]
		if str(GameState.realm) == "dream":
			## Dream 探索は後続。誤って waking ランを開始しない。
			primary_action_button.text = "探索（封印）"
			primary_action_button.disabled = true
		else:
			primary_action_button.text = "潜航開始"
			primary_action_button.disabled = CollectionData.loadout_error() != ""
		extract_button.visible = false
		stat_panel.visible = true
		_refresh_stat_panel()
		## 探索準備中は使用デッキを選べる。夢の島では潜航自体を封じているので出さない。
		var show_deck_select: bool = str(GameState.realm) != "dream"
		prepare_deck_select_panel.visible = show_deck_select
		if show_deck_select:
			_rebuild_prepare_deck_list()


func _rebuild_prepare_deck_list() -> void:
	for child in prepare_deck_list.get_children():
		child.queue_free()
	for name in CollectionData.decks.keys():
		var deck_name := str(name)
		var count := CollectionData.deck_size(CollectionData.decks.get(deck_name, {}))
		var button := Button.new()
		button.text = "%s    %d/%d" % [deck_name, count, CollectionData.DECK_LIMIT]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = deck_name == CollectionData.active_deck
		button.pressed.connect(_on_prepare_deck_selected.bind(deck_name))
		prepare_deck_list.add_child(button)
	var active_count := _deck_count()
	prepare_selected_deck_label.text = "選択中: %s（%d/%d〜%d）" % [CollectionData.active_deck, active_count, CollectionData.MIN_RUN_DECK, CollectionData.DECK_LIMIT]


func _on_prepare_deck_selected(deck_name: String) -> void:
	CollectionData.set_active_deck(deck_name)
	GameState._persist_profile()
	_rebuild_prepare_deck_list()
	_update_header()
	_update_descend_panel()


# ============================================================
# ステ振りUI（PrepareView.tsx の STAT_UI / StatRow 相当）
# ============================================================

const STAT_UI := [
	{"key": "hp", "name": "体力", "tag": "HP"},
	{"key": "san", "name": "正気", "tag": "SAN"},
	{"key": "intelligent", "name": "知力", "tag": "INT"},
	{"key": "strength", "name": "筋力", "tag": "STR"},
	{"key": "energy", "name": "気力", "tag": "NRG"},
]


func _refresh_stat_panel() -> void:
	var spent := Profile.stat_sum(GameState.stats)
	var budget := GameState.total_points()
	var remain: int = max(0, budget - spent)
	stat_header_label.text = "使用可能ポイント: %d / 総ポイント: %d" % [remain, budget]

	for child in stat_rows_container.get_children():
		child.queue_free()
	for row in STAT_UI:
		var key: String = row.key
		var sp: int = int(GameState.stats.get(key, 0))
		var base: int = Profile.stat_base(key, GameState.madness)
		var final: int = Profile.stat_final(key, sp, GameState.madness)

		var hrow := HBoxContainer.new()
		hrow.custom_minimum_size = Vector2(0, 44)
		hrow.add_theme_constant_override("separation", 8)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s（%s） SP%d　%d → %d" % [row.name, row.tag, sp, base, final]
		hrow.add_child(label)

		var minus_btn := Button.new()
		minus_btn.text = "−"
		minus_btn.custom_minimum_size = Vector2(42, 36)
		minus_btn.disabled = sp <= Profile.STAT_MIN
		minus_btn.pressed.connect(_on_stat_minus_pressed.bind(key))
		hrow.add_child(minus_btn)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(42, 36)
		plus_btn.disabled = remain <= 0
		plus_btn.pressed.connect(_on_stat_plus_pressed.bind(key))
		hrow.add_child(plus_btn)

		stat_rows_container.add_child(hrow)


func _on_stat_minus_pressed(key: String) -> void:
	GameState.set_stat(key, int(GameState.stats.get(key, 0)) - 1)
	_refresh_stat_panel()


func _on_stat_plus_pressed(key: String) -> void:
	GameState.set_stat(key, int(GameState.stats.get(key, 0)) + 1)
	_refresh_stat_panel()


func _deck_count() -> int:
	return CollectionData.deck_size(_view_deck_counts())


func _on_primary_action_pressed() -> void:
	if _deck_edit_blocks_leave():
		_pending_deck_leave = "primary"
		_show_deck_save_dialog()
		return
	if GameState.floor <= 0:
		if str(GameState.realm) == "dream":
			GameState.toast = "夢の島の探索はまだ開けない。"
			return
		GameState.start_run(get_tree())
	else:
		GameState.resume_descent(get_tree())


func _on_extract_button_pressed() -> void:
	## extract_to_hub()はシーンを"hub"（＝このシーン自身）に戻す＝再読込されるため、
	## 再読込後の_ready()がヘッダー/タブ表示を作り直す。
	if _deck_edit_blocks_leave():
		_pending_deck_leave = "extract"
		_show_deck_save_dialog()
		return
	_close_deck_edit()
	GameState.extract_to_hub(get_tree())


func _on_top_right_button_pressed() -> void:
	if _deck_edit_blocks_leave():
		_pending_deck_leave = "extract" if GameState.floor > 0 else "title"
		_show_deck_save_dialog()
		return
	_close_deck_edit()
	if GameState.floor > 0:
		GameState.extract_to_hub(get_tree())
	else:
		GameState.to_title(get_tree())


func _view_deck_counts() -> Dictionary:
	if _deck_edit_open:
		return _deck_edit_working
	var counts: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	return counts


func _begin_deck_edit() -> void:
	var live: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	_deck_edit_snapshot = live.duplicate(true)
	_deck_edit_working = live.duplicate(true)
	_deck_edit_open = true


func _deck_counts_differ() -> bool:
	var keys: Dictionary = {}
	for k in _deck_edit_working.keys():
		keys[str(k)] = true
	for k in _deck_edit_snapshot.keys():
		keys[str(k)] = true
	for k in keys.keys():
		if int(_deck_edit_working.get(k, 0)) != int(_deck_edit_snapshot.get(k, 0)):
			return true
	return false


func _deck_edit_blocks_leave() -> bool:
	if _deck_leave_bypass:
		return false
	if _deck_mode != "edit" or not _deck_edit_open:
		return false
	return _deck_counts_differ()


func _mutate_view_deck_add(card_id: String) -> bool:
	if _deck_edit_open:
		var total: int = CollectionData.deck_size(_deck_edit_working)
		var current: int = int(_deck_edit_working.get(card_id, 0))
		var owned: int = int(CollectionData.owned_card_counts().get(card_id, 0))
		if total >= CollectionData.DECK_LIMIT or current >= CollectionData.COPY_LIMIT or current >= owned:
			return false
		_deck_edit_working[card_id] = current + 1
		return true
	return CollectionData.add_to_deck(card_id)


func _mutate_view_deck_remove(card_id: String) -> void:
	if not _deck_edit_open:
		CollectionData.remove_from_deck(card_id)
		return
	var current: int = int(_deck_edit_working.get(card_id, 0))
	if current <= 1:
		_deck_edit_working.erase(card_id)
	else:
		_deck_edit_working[card_id] = current - 1


## 編集セッションを閉じる。確定後の本体デッキが空なら自動で削除する
## （新規作成して何も入れずに離れた場合／全部抜いた場合）。最後の1デッキは delete_deck() が残す。
## 探索開始（primary）経由では呼ばない：消すと別デッキが黙って有効になり、そのまま潜航してしまう。
func _close_deck_edit() -> void:
	var was_open: bool = _deck_edit_open
	_deck_edit_open = false
	if not was_open:
		return
	var deck_name: String = CollectionData.active_deck
	if CollectionData.deck_size(CollectionData.decks.get(deck_name, {})) > 0:
		return
	CollectionData.delete_deck(deck_name)
	if not CollectionData.decks.has(deck_name):
		CollectionData.set_active_deck(_active_deck_before_edit)
		GameState._persist_profile()


func _commit_working_deck() -> void:
	var deck_name: String = CollectionData.active_deck
	CollectionData.decks[deck_name] = _deck_edit_working.duplicate(true)
	_deck_edit_snapshot = _deck_edit_working.duplicate(true)


func _ensure_deck_save_dialog() -> void:
	if _deck_save_layer != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "DeckSaveConfirm"
	layer.layer = 90
	layer.visible = false
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_top = -80.0
	panel.offset_right = 220.0
	panel.offset_bottom = 80.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.06, 0.96)
	style.border_color = Color(0.72, 0.55, 0.28, 1)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var label := Label.new()
	label.text = "変更内容を保存しますか？"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78, 1))
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var save_btn := Button.new()
	save_btn.text = "保存する"
	save_btn.custom_minimum_size = Vector2(140, 40)
	save_btn.pressed.connect(_on_deck_save_chosen.bind(true))
	row.add_child(save_btn)
	var drop_btn := Button.new()
	drop_btn.text = "保存しない"
	drop_btn.custom_minimum_size = Vector2(140, 40)
	drop_btn.pressed.connect(_on_deck_save_chosen.bind(false))
	row.add_child(drop_btn)
	_deck_save_layer = layer


func _show_deck_save_dialog() -> void:
	_ensure_deck_save_dialog()
	_deck_save_layer.visible = true


func _on_deck_save_chosen(save_changes: bool) -> void:
	if save_changes:
		_commit_working_deck()
		GameState._persist_profile()
	elif CollectionData.decks.has(CollectionData.active_deck):
		## 作業コピーしか触っていないが、仕様どおり本体は編集開始時へ戻す。
		CollectionData.decks[CollectionData.active_deck] = _deck_edit_snapshot.duplicate(true)
	if _deck_save_layer != null:
		_deck_save_layer.visible = false
	var action: String = _pending_deck_leave
	_pending_deck_leave = ""
	if action == "primary":
		_deck_edit_open = false
	else:
		_close_deck_edit()
	_deck_leave_bypass = true
	if action == "list":
		_close_card_inspector()
		_deck_mode = "list"
		_refresh_deck_tab()
		_update_header()
	elif action.begins_with("tab:"):
		_deck_mode = "list"
		_select_tab(action.substr(4))
	elif action == "title":
		GameState.to_title(get_tree())
	elif action == "extract":
		GameState.extract_to_hub(get_tree())
	elif action == "primary":
		_on_primary_action_pressed()
	_deck_leave_bypass = false


func _refresh_commerce() -> void:
	for child in commerce_list.get_children():
		commerce_list.remove_child(child)
		child.queue_free()
	if _commerce_tab == "shop":
		## ShopPanel.tsx 相当：通常パック（buyCardPack()）購入のみ。
		## 以前ここにあったSHOP_CARDS（鉄剣等）販売は鍛冶屋（Rest.gd）側の実装であり、
		## Hubのショップタブの内容として誤っていたため撤去した。
		if not _last_pack_result.is_empty():
			commerce_title.text = "通常パック"
			for def_id in _last_pack_result:
				var d := Cards.get_card(str(def_id))
				_commerce_card_result(d, str(def_id))
			_commerce_button("閉じる", _on_clear_pack_result)
		else:
			commerce_title.text = "ショップ　所持: %d貝殻" % GameState.shells
			var info := Label.new()
			info.text = "通常パック\nカードを4枚引く。所持数が少ないカードほど出やすい。"
			commerce_list.add_child(info)
			_commerce_button("購入 · 貝殻%d" % GameState.CARD_PACK_PRICE, _on_buy_card_pack, GameState.shells < GameState.CARD_PACK_PRICE,
				NORMAL_PACK_ART, "", "uncommon")
	elif _commerce_tab == "packs":
		## PackShopScreen.tsx：ナビを隠して全幅。パック絵は object-contain。
		commerce_title.text = "カードパック"
		var back_row := HBoxContainer.new()
		back_row.add_theme_constant_override("separation", 10)
		var back_btn := Button.new()
		back_btn.text = "← 戻る"
		back_btn.custom_minimum_size = Vector2(96, 32)
		back_btn.pressed.connect(_select_tab.bind("descend"))
		back_row.add_child(back_btn)
		var desc := Label.new()
		desc.text = "属性チケットを消費して開封する。専用パックは各10枚から始まる。"
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58, 1))
		desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		back_row.add_child(desc)
		commerce_list.add_child(back_row)
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var pack_grid := GridContainer.new()
		pack_grid.name = "PackGrid"
		pack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pack_grid.add_theme_constant_override("h_separation", 12)
		pack_grid.add_theme_constant_override("v_separation", 12)
		var cols: int = 5
		var avail: float = commerce_panel.size.x
		if avail > 64.0:
			cols = clampi(int(avail / (PACK_TILE_W + 12.0)), 2, 7)
		pack_grid.columns = cols
		for a in CollectionData.PACK_TICKET_ARCHETYPES:
			var n: int = int(CollectionData.pack_tickets.get(a, 0))
			pack_grid.add_child(_make_pack_tile(str(a), n))
		scroll.add_child(pack_grid)
		scroll.resized.connect(_fit_pack_grid.bind(scroll))
		commerce_list.add_child(scroll)


## ShopPanel.tsx の buyCardPack ボタン相当
func _on_buy_card_pack() -> void:
	if _pack_open != null and is_instance_valid(_pack_open):
		return
	var result: Array = GameState.buy_card_pack()
	if result.is_empty():
		return
	_last_pack_result = []
	_launch_pack_open(NORMAL_PACK_ART, result)


## ShopPanel.tsx の clearPackResult() 相当
func _on_clear_pack_result() -> void:
	_last_pack_result = []
	_refresh_commerce()

## store.ts の openArchetypePack()。前半2枚は属性プール（旧支配者は風・火、外宇宙は豊穣を混ぜる。
## レアリティ62/28/10%＋未所持優遇）、後半2枚は weightedCard()（同じ重み付けの自由枠。魔導はここだけ）で選ぶ。
## owner は実ソース同様 `character ?? starterPath(stats)`（ラン中でなければ暫定キャラで判定）。
func _open_pack(archetype: String) -> void:
	if _pack_open != null and is_instance_valid(_pack_open):
		return
	if not CollectionData.consume_pack_ticket(archetype):
		return
	var owner: String = GameState.character if GameState.character != "" else GameState.starter_path(GameState.stats)
	var rand := Callable(GameState, "_rand")
	var revealed: Array = []
	if archetype == "all":
		var all_card: Dictionary = Cards.pick_all_pack_card(rand)
		var all_id: String = str(all_card.get("defId", ""))
		CollectionData.add_loot_card(all_id)
		revealed.append(all_id)
	else:
		var forced_archetypes: Array = [archetype]
		if archetype == "greatold":
			forced_archetypes = ["greatold", "wind", "fire"]
		elif archetype == "outer":
			forced_archetypes = ["outer", "earth"]
		for i in range(2):
			var forced: Dictionary = Cards.weighted_archetype_cards(owner, forced_archetypes, rand)
			var def_id: String = str(forced.get("defId", ""))
			CollectionData.add_loot_card(def_id)
			revealed.append(def_id)
		for i in range(2):
			var free_card: Dictionary = Cards.weighted_card(owner, rand)
			var def_id: String = str(free_card.get("defId", ""))
			CollectionData.add_loot_card(def_id)
			revealed.append(def_id)
	var art_path: String = _pack_open_art_path(archetype)
	GameState._persist_profile()
	_launch_pack_open(art_path, revealed)


func _launch_pack_open(pack_art: String, card_ids: Array) -> void:
	if card_ids.is_empty():
		_refresh_commerce()
		return
	if _pack_open != null and is_instance_valid(_pack_open):
		return
	var node: Control = PACK_OPEN_SCENE.instantiate() as Control
	add_child(node)
	node.move_to_front()
	_pack_open = node
	node.connect("closed", _on_pack_open_closed)
	node.call("setup", pack_art, card_ids)


func _pack_open_art_path(archetype: String) -> String:
	var png_path: String = "res://art/pixel/packs/pack_%s_nobackground.png" % archetype
	if ResourceLoader.exists(png_path):
		return png_path
	var jpg_path: String = "res://art/pixel/packs/pack_%s.jpg" % archetype
	if ResourceLoader.exists(jpg_path):
		return jpg_path
	return "res://art/pixel/packs/pack_outer_nobackground.png"


func _on_pack_open_closed() -> void:
	_pack_open = null
	_refresh_commerce()
	_update_header()
func _commerce_button(label: String, action: Callable, disabled: bool = false, art_path: String = "", archetype: String = "", rarity: String = "common") -> void:
	var button := Button.new()
	button.disabled = disabled
	button.pressed.connect(action)
	if art_path == "":
		button.text = label
		commerce_list.add_child(button)
		return

	button.custom_minimum_size = Vector2(0, 68)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.add_child(_make_art_thumbnail(art_path, archetype, rarity, Vector2(46, 56)))
	var text_label := Label.new()
	text_label.text = label
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_label)
	button.add_child(row)
	commerce_list.add_child(button)


func _commerce_card_result(definition: Dictionary, fallback_id: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 10)
	row.add_child(_make_art_thumbnail(Cards.card_art({}, definition), str(definition.get("archetype", "")), str(definition.get("rarity", "common")), Vector2(46, 56)))
	var label := Label.new()
	label.text = "・%s" % str(definition.get("name", fallback_id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	row.add_child(label)
	commerce_list.add_child(row)


func _fit_pack_grid(scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	var grid: GridContainer = scroll.get_node_or_null("PackGrid") as GridContainer
	if grid == null:
		return
	var cols: int = clampi(int(scroll.size.x / (PACK_TILE_W + 12.0)), 2, 7)
	if grid.columns != cols:
		grid.columns = cols


## PackShopScreen.tsx と同様に、チケットではなく pack_${archetype}.jpg のパック本体をグリッド表示する。
## 絵は object-contain（COVERED禁止）。原作の minmax(11rem) 相当で全絵を見せる。
func _make_pack_tile(archetype: String, ticket_count: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(PACK_TILE_W, 0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15130f")
	style.border_color = Color("655b4b")
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 3
	style.shadow_offset = Vector2(3, 3)
	tile.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pack_art := TextureRect.new()
	pack_art.custom_minimum_size = PACK_ART_SIZE
	pack_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pack_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pack_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := "res://art/pixel/packs/pack_%s.jpg" % archetype
	var art_tex: Texture2D = _load_texture_safe(art_path)
	if art_tex == null:
		art_tex = _load_texture_safe("res://art/pixel/packs/pack_outer.jpg")
	if art_tex != null:
		pack_art.texture = art_tex
	col.add_child(pack_art)
	var label_name: String = str(Cards.ARCHETYPE_LABELS.get(archetype, archetype))
	var name_label := Label.new()
	name_label.text = "%sパック" % label_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var sub := Label.new()
	if archetype == "all":
		sub.text = "開封で1枚（銀の鍵／崩壊／全能／超越者）"
	elif archetype == "greatold":
		sub.text = "4枚中2枚が旧支配者・風・火"
	elif archetype == "outer":
		sub.text = "4枚中2枚が外宇宙・豊穣"
	else:
		sub.text = "4枚中2枚が%s確定" % label_name
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58, 1))
	sub.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)
	var ticket_row := HBoxContainer.new()
	ticket_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ticket_row.add_theme_constant_override("separation", 8)
	ticket_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ticket_icon := TextureRect.new()
	ticket_icon.custom_minimum_size = Vector2(40, 22)
	ticket_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ticket_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ticket_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ticket_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ticket_tex: Texture2D = _load_texture_safe(CollectionData.pack_ticket_art(archetype))
	if ticket_tex != null:
		ticket_icon.texture = ticket_tex
	ticket_row.add_child(ticket_icon)
	var owned := Label.new()
	owned.text = "所持 %d" % ticket_count
	owned.add_theme_font_size_override("font_size", 12)
	owned.add_theme_color_override("font_color", Color.WHITE)
	owned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket_row.add_child(owned)
	col.add_child(ticket_row)
	var open_btn := Button.new()
	open_btn.text = "開封 · チケット1枚"
	open_btn.custom_minimum_size = Vector2(0, 32)
	open_btn.disabled = ticket_count < 1
	open_btn.pressed.connect(_open_pack.bind(archetype))
	col.add_child(open_btn)
	tile.add_child(col)
	return tile


## カード/装備/チケット用の実画像サムネイル。
## TextureRectで art を表示し、CombatCard.gd と同一の NinePatchRect 枠を重ねる。
func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty():
		return null
	## ArtCache Autoload 経由（未登録時のみフォールバック直ロード）
	if ArtCache != null:
		return ArtCache.get_texture(path)
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return null


func _make_art_thumbnail(art_path: String, archetype: String, rarity: String, minimum_size: Vector2, with_frame: bool = true) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = minimum_size
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("100f0c")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(backdrop)

	var thumbnail := TextureRect.new()
	thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if with_frame:
		thumbnail.offset_left = 5
		thumbnail.offset_top = 5
		thumbnail.offset_right = -5
		thumbnail.offset_bottom = -5
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_texture := _load_texture_safe(art_path)
	# カタログに画像パスがあるが素材が未配置の場合も、セルを空白にしない。
	if art_texture == null and art_path.begins_with("res://art/pixel/cards/"):
		art_texture = _load_texture_safe(NORMAL_PACK_ART)
	if art_texture != null:
		thumbnail.texture = art_texture
	holder.add_child(thumbnail)

	if art_texture == null:
		var missing_label := Label.new()
		missing_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		missing_label.text = "NO ART"
		missing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		missing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		missing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(missing_label)

	if not with_frame:
		return holder

	var frame_data: Array = CombatCard.FRAME_BY_ARCHETYPE.get(archetype, CombatCard.FRAME_BY_RARITY.get(rarity, CombatCard.FRAME_BY_RARITY["common"]))
	var frame := NinePatchRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.draw_center = false
	frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_path := str(frame_data[0])
	var frame_texture := CombatCard.ninepatch_texture(frame_path)
	if frame_texture != null:
		frame.texture = frame_texture
		var margin: int = CombatCard.ninepatch_margin(frame_path, int(frame_data[1]))
		frame.patch_margin_left = margin
		frame.patch_margin_top = margin
		frame.patch_margin_right = margin
		frame.patch_margin_bottom = margin
	holder.add_child(frame)
	return holder


func _make_art_strip(art_path: String, strip_size: Vector2) -> Control:
	return _make_art_thumbnail(art_path, "", "common", strip_size, false)


# ============================================================
# 売却タブ（SellScreen.tsx 相当）
# ============================================================

## SellScreen.tsx の usedAcrossDecks()
func _used_across_decks() -> Dictionary:
	var used: Dictionary = {}
	for counts in CollectionData.decks.values():
		for card_id in counts.keys():
			used[card_id] = int(used.get(card_id, 0)) + int(counts[card_id])
	return used


## SellScreen.tsx の cardRows（groupInventory()+所持数-デッキ使用数=売却可能数、0枚は除外）
func _sellable_card_rows() -> Array:
	var used := _used_across_decks()
	var owned := CollectionData.owned_card_counts()
	var out: Array = []
	for card_id in owned.keys():
		var owned_n: int = int(owned[card_id])
		var used_n: int = int(used.get(str(card_id), 0))
		var sellable: int = max(0, owned_n - used_n)
		if sellable > 0:
			out.append({"base_card_id": str(card_id), "owned": owned_n, "sellable": sellable})
	return out


## SellScreen.tsx の qtyFor()
func _sell_qty_for(base_card_id: String, sellable: int) -> int:
	return min(int(_sell_card_selections.get(base_card_id, 0)), sellable)


## SellScreen.tsx の setCardQty()
## ±／サムネトグルはグリッド全体を queue_free+再構築せず、該当行の数量ラベルだけ更新する。
func _set_sell_card_qty(base_card_id: String, qty: int, max_qty: int) -> void:
	var clamped: int = max(0, min(max_qty, qty))
	if clamped <= 0:
		_sell_card_selections.erase(base_card_id)
	else:
		_sell_card_selections[base_card_id] = clamped
	if _sell_card_row_nodes.has(base_card_id):
		_sync_sell_card_row(base_card_id, max_qty)
		_update_sell_footer()
	else:
		_refresh_sell_tab()


func _on_sell_card_thumb_pressed(base_card_id: String, sellable: int) -> void:
	var qty: int = _sell_qty_for(base_card_id, sellable)
	_set_sell_card_qty(base_card_id, 0 if qty > 0 else sellable, sellable)


func _on_sell_card_minus_pressed(base_card_id: String, sellable: int) -> void:
	var qty: int = _sell_qty_for(base_card_id, sellable)
	_set_sell_card_qty(base_card_id, qty - 1, sellable)


func _on_sell_card_plus_pressed(base_card_id: String, sellable: int) -> void:
	var qty: int = _sell_qty_for(base_card_id, sellable)
	_set_sell_card_qty(base_card_id, qty + 1, sellable)


func _sync_sell_card_row(base_card_id: String, sellable: int) -> void:
	if not _sell_card_row_nodes.has(base_card_id):
		return
	var row: Dictionary = _sell_card_row_nodes[base_card_id]
	var qty: int = _sell_qty_for(base_card_id, sellable)
	var qty_label: Label = row["qty_label"]
	var minus_btn: Button = row["minus_btn"]
	var plus_btn: Button = row["plus_btn"]
	qty_label.text = "%d/%d" % [qty, sellable]
	minus_btn.disabled = qty <= 0
	plus_btn.disabled = qty >= sellable
	var cc: CombatCard = row.get("combat_card") as CombatCard
	if cc != null and is_instance_valid(cc):
		var def: Dictionary = row.get("card_def", {})
		cc.configure({"defId": base_card_id}, def, true, qty > 0, true)


func _update_sell_footer() -> void:
	sell_total_label.text = "選択中 %d点 · 獲得予定 貝殻%d" % [_sell_total_selected(), _sell_total_value()]
	sell_confirm_button.disabled = _sell_total_selected() == 0


func _sell_card_total_count() -> int:
	var total := 0
	for r in _sellable_card_rows():
		total += _sell_qty_for(str(r.base_card_id), int(r.sellable))
	return total


func _sell_card_total_value() -> int:
	var total := 0
	for r in _sellable_card_rows():
		var qty := _sell_qty_for(str(r.base_card_id), int(r.sellable))
		if qty > 0:
			total += qty * GameState.card_sell_price(Cards.get_card(str(r.base_card_id)))
	return total


## SellScreen.tsx の totalValue
func _sell_total_value() -> int:
	return _sell_card_total_value()


## SellScreen.tsx の totalSelected
func _sell_total_selected() -> int:
	return _sell_card_total_count()


func _refresh_sell_tab() -> void:
	_sell_card_row_nodes.clear()
	sell_card_tab_button.disabled = true
	sell_surplus_button.visible = true

	for child in sell_list_container.get_children():
		child.queue_free()

	## SellScreen.tsx の grid-cols-[repeat(auto-fill,minmax(8rem,1fr))] 相当。
	## 幅は 128 のまま折り返し列数を維持し、サムネはデッキ編成と同じ 88×124。
	var rows := _sellable_card_rows()
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "売れるカードがない。"
		sell_list_container.add_child(empty_label)
	for r in rows:
		var base_card_id: String = str(r.base_card_id)
		var owned_n: int = int(r.owned)
		var sellable: int = int(r.sellable)
		var qty := _sell_qty_for(base_card_id, sellable)
		var def := Cards.get_card(base_card_id)
		var unit_price: int = GameState.card_sell_price(def)

		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(148, 260)
		cell.add_theme_constant_override("separation", 4)

		var card_holder := Control.new()
		card_holder.custom_minimum_size = Vector2(128, 192)
		card_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var combat_card: CombatCard = COMBAT_CARD.new() as CombatCard
		combat_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		combat_card.tooltip_text = "%s（所持%d）" % [str(def.get("name", base_card_id)), owned_n]
		combat_card.pressed.connect(_on_sell_card_thumb_pressed.bind(base_card_id, sellable))
		card_holder.add_child(combat_card)
		combat_card.configure({"defId": base_card_id}, def, true, qty > 0, true)

		var owned_badge := Label.new()
		owned_badge.text = "x%d" % owned_n
		owned_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
		owned_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		combat_card.add_child(owned_badge)

		cell.add_child(card_holder)

		var qty_row := HBoxContainer.new()
		qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
		qty_row.add_theme_constant_override("separation", 4)
		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.disabled = qty <= 0
		minus_btn.pressed.connect(_on_sell_card_minus_pressed.bind(base_card_id, sellable))
		qty_row.add_child(minus_btn)
		var qty_label := Label.new()
		qty_label.text = "%d/%d" % [qty, sellable]
		qty_label.custom_minimum_size = Vector2(40, 0)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		qty_row.add_child(qty_label)
		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.disabled = qty >= sellable
		plus_btn.pressed.connect(_on_sell_card_plus_pressed.bind(base_card_id, sellable))
		qty_row.add_child(plus_btn)
		cell.add_child(qty_row)
		_sell_card_row_nodes[base_card_id] = {
			"qty_label": qty_label,
			"minus_btn": minus_btn,
			"plus_btn": plus_btn,
			"sellable": sellable,
			"combat_card": combat_card,
			"card_def": def,
		}

		var price_label := Label.new()
		price_label.text = "貝殻%d/枚" % unit_price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		cell.add_child(price_label)

		sell_list_container.add_child(cell)

	_update_sell_footer()


## SellScreen.tsx の selectAll()
func _on_sell_select_all_pressed() -> void:
	_sell_card_selections.clear()
	for r in _sellable_card_rows():
		_sell_card_selections[str(r.base_card_id)] = int(r.sellable)
	_refresh_sell_tab()


## SellScreen.tsx の clearAll()
func _on_sell_clear_all_pressed() -> void:
	_sell_card_selections.clear()
	_refresh_sell_tab()


## SellScreen.tsx の selectSurplus()：デッキ編成の上限(COPY_LIMIT)を超える余剰分だけを選択する
func _on_sell_surplus_pressed() -> void:
	_sell_card_selections.clear()
	for r in _sellable_card_rows():
		var sellable: int = int(r.sellable)
		if sellable > CollectionData.COPY_LIMIT:
			_sell_card_selections[str(r.base_card_id)] = sellable - CollectionData.COPY_LIMIT
	_refresh_sell_tab()


## SellScreen.tsx の handleSell()
func _on_sell_confirm_pressed() -> void:
	if _sell_total_selected() == 0:
		return
	var card_ids: Array = []
	for r in _sellable_card_rows():
		var base_card_id: String = str(r.base_card_id)
		var qty := _sell_qty_for(base_card_id, int(r.sellable))
		if qty <= 0:
			continue
		var picked := 0
		for c in CollectionData.inventory.cards:
			if picked >= qty:
				break
			if str(c.get("base_card_id", "")) == base_card_id:
				card_ids.append(str(c.get("instance_id", "")))
				picked += 1
	GameState.sell_items(card_ids)
	_sell_card_selections.clear()
	_refresh_sell_tab()
	_update_header()


# ============================================================
# デッキ編成タブ（DeckHubScreen.tsx / DeckBuilderScreen.tsx 相当）
# ============================================================

## DeckHubScreen.tsx の mode: "list" | "edit" 相当のトップレベル切り替え。
## 初期デッキ選択は廃止。パックを開いて自分で組む。
func _refresh_deck_tab() -> void:
	_hide_starter_pick()
	deck_list_sub_panel.visible = _deck_mode == "list"
	deck_edit_sub_panel.visible = _deck_mode == "edit"
	if _deck_mode == "list":
		_deck_edit_open = false
		_rebuild_deck_list()
	else:
		if not _deck_edit_open:
			_begin_deck_edit()
		_refresh_deck_edit_header()
		_refresh_deck_summary()
		_rebuild_card_list()


func _hide_starter_pick() -> void:
	if starter_pick_panel:
		starter_pick_panel.visible = false
	_clear_starter_pick()


func _clear_starter_pick() -> void:
	var leftover: Node = deck_panel.get_node_or_null("StarterPickRoot")
	while leftover != null:
		leftover.name = "StarterPickDead"
		deck_panel.remove_child(leftover)
		leftover.queue_free()
		leftover = deck_panel.get_node_or_null("StarterPickRoot")
	if starter_pick_panel == null:
		return
	var kids: Array = starter_pick_panel.get_children()
	for child in kids:
		starter_pick_panel.remove_child(child)
		child.queue_free()


## DeckListScreen.tsx の topArchetypeOfCounts() — 4枚未満は none（混成／未染色）
func _top_archetype_of_counts(counts: Dictionary) -> Dictionary:
	var tally: Dictionary = {}
	for card_id in counts.keys():
		var def := Cards.get_card(str(card_id))
		var archetype: String = str(def.get("archetype", ""))
		if archetype == "" or archetype == "generic":
			continue
		tally[archetype] = int(tally.get(archetype, 0)) + int(counts[card_id])
	var best_archetype := ""
	var best_count := 0
	for archetype in tally.keys():
		var count: int = int(tally[archetype])
		if best_archetype == "" or count > best_count:
			best_archetype = archetype
			best_count = count
	if best_archetype == "" or best_count < DECK_SHELF_ARCHETYPE_MIN:
		return {"archetype": "none", "count": best_count}
	return {"archetype": best_archetype, "count": best_count}


## DeckListScreen.tsx の「禁書目録」一覧 — 正四角デッキ束タイル棚
func _rebuild_deck_list() -> void:
	for child in deck_list_container.get_children():
		child.queue_free()
	var names := CollectionData.decks.keys()
	if names.is_empty():
		var empty_label := Label.new()
		empty_label.text = "デッキがありません。"
		deck_list_container.add_child(empty_label)
		return
	var shelf := HFlowContainer.new()
	shelf.name = "DeckShelfFlow"
	shelf.add_theme_constant_override("h_separation", 10)
	shelf.add_theme_constant_override("v_separation", 10)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_list_container.add_child(shelf)
	for name in names:
		var counts: Dictionary = CollectionData.decks.get(name, {})
		var top := _top_archetype_of_counts(counts)
		var arch := str(top.get("archetype", "none"))
		if arch == "":
			arch = "none"
		shelf.add_child(_make_deck_shelf_tile(str(name), arch, CollectionData.deck_size(counts)))


func _make_deck_shelf_tile(deck_name: String, archetype: String, total: int) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = DECK_SHELF_TILE
	tile.clip_contents = true
	tile.tooltip_text = "%s（%d/%d枚）" % [deck_name, total, CollectionData.DECK_LIMIT]
	tile.pressed.connect(_on_deck_list_open.bind(deck_name))
	var empty := StyleBoxEmpty.new()
	tile.add_theme_stylebox_override("normal", empty)
	tile.add_theme_stylebox_override("hover", empty)
	tile.add_theme_stylebox_override("pressed", empty)
	tile.add_theme_stylebox_override("disabled", empty)
	tile.add_theme_stylebox_override("focus", empty)

	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = DECK_SHELF_COLORS.get(archetype, DECK_SHELF_DEFAULT_COLOR)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(0)  ## no gold border
	bg.add_theme_stylebox_override("panel", sb)
	tile.add_child(bg)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_TOP_WIDE)
	icon.anchor_bottom = 0.72
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile_id := archetype if archetype != "" else "none"
	var icon_path := DECK_SHELF_TILE_FMT % tile_id
	var tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	elif tile_id != "none" and ResourceLoader.exists(DECK_SHELF_TILE_FMT % "none"):
		## missing attr tile → none only (never pack art)
		tex = load(DECK_SHELF_TILE_FMT % "none") as Texture2D
	if tex != null:
		icon.texture = tex
	tile.add_child(icon)

	var name_bar := ColorRect.new()
	name_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_bar.offset_top = -36
	name_bar.color = Color(0, 0, 0, 0.55)
	name_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_bar)

	var name_label := Label.new()
	name_label.text = deck_name
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_left = 6
	name_label.offset_top = -32
	name_label.offset_right = -6
	name_label.offset_bottom = -4
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_label)
	return tile


## DeckBuilderScreen.tsx のデッキ名表示/名前変更/削除ボタン行の状態更新
func _refresh_deck_edit_header() -> void:
	var names := CollectionData.decks.keys()
	deck_edit_title_label.text = CollectionData.active_deck
	deck_edit_title_label.visible = not _deck_renaming
	rename_deck_button.visible = not _deck_renaming
	delete_deck_button.visible = not _deck_renaming
	delete_deck_button.disabled = names.size() <= 1
	deck_rename_row.visible = _deck_renaming


func _refresh_deck_summary() -> void:
	var deck: Dictionary = _view_deck_counts()
	var n := CollectionData.deck_size(deck)
	deck_count_label.text = "%s: %d/%d枚（最低%d枚必要）" % [
		CollectionData.active_deck, n, CollectionData.DECK_LIMIT, CollectionData.MIN_RUN_DECK,
	]
	deck_error_label.text = CollectionData.loadout_error_for(deck)
	deck_error_label.visible = deck_error_label.text != ""


## DeckBuilderScreen.tsx の groupInventory()+検索+フィルター相当。
## 所持カード（base_card_id単位）を名前検索・ジャンル/レア度/種別フィルターで絞り込む。
func _filtered_deck_card_ids(owned: Dictionary) -> Array:
	var query := _deck_search.strip_edges().to_lower()
	var out: Array = []
	for card_id in owned.keys():
		var def := Cards.get_card(str(card_id))
		if def.is_empty():
			continue
		if query != "" and not str(def.get("name", "")).to_lower().contains(query):
			continue
		var archetype: String = str(def.get("archetype", "generic"))
		if _deck_filter_archetypes.size() > 0 and not _deck_filter_archetypes.has(archetype):
			continue
		var rarity: String = str(def.get("rarity", ""))
		if _deck_filter_rarities.size() > 0 and not _deck_filter_rarities.has(rarity):
			continue
		var ai_tag: String = str(def.get("aiTag", ""))
		if _deck_filter_ai_tags.size() > 0 and (ai_tag == "" or not _deck_filter_ai_tags.has(ai_tag)):
			continue
		out.append(card_id)
	return out


## DeckBuilderScreen.tsx の sortGroups(groups, mode, ownedOf) 相当
func _sort_deck_card_ids(ids: Array, owned: Dictionary) -> void:
	ids.sort_custom(func(a, b):
		var ad := Cards.get_card(str(a))
		var bd := Cards.get_card(str(b))
		match _deck_sort_mode:
			"cost":
				var ac: int = int(ad.get("cost", 0))
				var bc: int = int(bd.get("cost", 0))
				return ac < bc if ac != bc else str(ad.get("name", "")) < str(bd.get("name", ""))
			"rarity":
				var ar: int = DECK_RARITY_ORDER.find(str(ad.get("rarity", "")))
				var br: int = DECK_RARITY_ORDER.find(str(bd.get("rarity", "")))
				return ar < br if ar != br else int(ad.get("cost", 0)) < int(bd.get("cost", 0))
			"owned":
				var ao: int = int(owned.get(a, 0))
				var bo: int = int(owned.get(b, 0))
				return ao > bo if ao != bo else int(ad.get("cost", 0)) < int(bd.get("cost", 0))
			"archetype":
				var aa: int = DECK_FILTERABLE_ARCHETYPES.find(str(ad.get("archetype", "generic")))
				var ba: int = DECK_FILTERABLE_ARCHETYPES.find(str(bd.get("archetype", "generic")))
				return aa < ba if aa != ba else int(ad.get("cost", 0)) < int(bd.get("cost", 0))
		return false
	)


func _rebuild_card_list() -> void:
	_free_children(card_list_container)
	var deck: Dictionary = _view_deck_counts()
	var owned: Dictionary = CollectionData.owned_card_counts()
	var ids := _filtered_deck_card_ids(owned)
	_sort_deck_card_ids(ids, owned)
	deck_result_count_label.text = "%d/%d件" % [ids.size(), owned.size()]
	_rebuild_deck_contents(deck)
	if ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "条件に一致するカードがありません。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		card_list_container.columns = 1
		card_list_container.add_child(empty_label)
		return

	for card_id in ids:
		var def := Cards.get_card(str(card_id))
		var name: String = def.get("name", str(card_id)) if not def.is_empty() else str(card_id)
		var in_deck: int = CollectionData.copies_of_base(deck, str(card_id))
		var owned_count: int = int(owned[card_id])
		card_list_container.add_child(_make_pool_thumb(str(card_id), def, name, owned_count, in_deck))
	_fit_card_grid()


## _fit_pack_grid と同じく幅から列数を決める。端数は列間隔へ配って右端の空きを消す。
## 縦スクロールバー分は常に差し引く（検索で件数が変わりバーが出入りしても列数が振動しないように）。
## 幅はパネルの内側余白も引いた実際の中身幅で計算する。はみ出すとグリッドがバーの下へ潜る。
func _fit_card_grid() -> void:
	if card_scroll == null or card_list_container == null:
		return
	if card_list_container.get_child_count() == 0 or not (card_list_container.get_child(0) is CombatCard):
		return
	var bar_w: float = card_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var pad_w: float = card_scroll.get_theme_stylebox("panel").get_minimum_size().x
	var avail: float = card_scroll.size.x - pad_w - bar_w - POOL_BAR_GAP
	if avail <= 0.0:
		return
	var cols: int = maxi(1, int((avail + POOL_CARD_GAP) / (POOL_CARD_SIZE.x + POOL_CARD_GAP)))
	var cell_w: float = floorf(clampf((avail - (cols - 1) * POOL_CARD_GAP) / cols, POOL_CARD_SIZE.x, POOL_CARD_MAX_W))
	var cell := Vector2(cell_w, roundf(cell_w * POOL_CARD_SIZE.y / POOL_CARD_SIZE.x))
	var gap: int = POOL_CARD_GAP
	if cols > 1:
		gap = clampi(int((avail - cols * cell_w) / (cols - 1)), POOL_CARD_GAP, POOL_CARD_GAP_MAX)
	if card_list_container.columns != cols:
		card_list_container.columns = cols
	card_list_container.add_theme_constant_override("h_separation", gap)
	for child in card_list_container.get_children():
		var card := child as Control
		if card != null and card.custom_minimum_size != cell:
			card.custom_minimum_size = cell
			card.pivot_offset = cell * 0.5  ## ホバー拡大の中心（CombatCard._sync_pivot と同じ）


func _rebuild_deck_contents(deck: Dictionary) -> void:
	deck_contents_container.custom_minimum_size.x = 0
	deck_contents_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_free_children(deck_contents_container)
	var card_ids: Array = deck.keys()
	card_ids.sort_custom(func(a, b):
		var a_name := str(Cards.get_card(str(a)).get("name", a))
		var b_name := str(Cards.get_card(str(b)).get("name", b))
		return a_name < b_name
	)
	if card_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "カードをクリックして編成"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck_contents_container.add_child(empty_label)
		return
	for card_id in card_ids:
		var count: int = int(deck.get(card_id, 0))
		if count <= 0:
			continue
		var def: Dictionary = Cards.get_card(str(card_id))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 40)
		row.clip_contents = true
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_theme_constant_override("separation", 8)
		row.gui_input.connect(_on_deck_row_gui.bind(str(card_id), row))

		var thumb: Control = _make_art_strip(Cards.card_art({}, def), Vector2(72, 32))
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(thumb)

		## Controlは子の最小幅を合算しない。Labelの全文幅で右パネルが押し広がるのを防ぐ。
		var text_host := Control.new()
		text_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_host.custom_minimum_size = Vector2(8, 32)
		text_host.clip_contents = true
		text_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Label.new()
		name_label.text = str(def.get("name", card_id))
		name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		name_label.offset_top = 2
		name_label.offset_bottom = 20
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_host.add_child(name_label)
		var arch: String = str(def.get("archetype", ""))
		if arch != "" and arch != "generic":
			var arch_label := Label.new()
			arch_label.text = str(Cards.ARCHETYPE_LABELS.get(arch, arch))
			arch_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			arch_label.offset_top = -16
			arch_label.offset_bottom = -1
			arch_label.add_theme_font_size_override("font_size", 10)
			arch_label.add_theme_color_override("font_color", Color("d4a84b"))
			arch_label.clip_text = true
			arch_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			arch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text_host.add_child(arch_label)
		row.add_child(text_host)

		var count_label := Label.new()
		count_label.text = "×%d" % count
		count_label.custom_minimum_size = Vector2(36, 0)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(count_label)

		var minus_btn := Button.new()
		minus_btn.text = "✕"
		minus_btn.custom_minimum_size = Vector2(32, 32)
		minus_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		minus_btn.tooltip_text = "1枚減らす"
		minus_btn.pressed.connect(_on_deck_remove_pressed.bind(str(card_id)))
		row.add_child(minus_btn)
		deck_contents_container.add_child(row)


func _free_children(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var kids: Array = node.get_children()
	for child in kids:
		node.remove_child(child)
		child.queue_free()


func _on_deck_add_pressed(card_id: String) -> void:
	if card_id == "":
		return
	var deck: Dictionary = _view_deck_counts()
	var owned: Dictionary = CollectionData.owned_card_counts()
	var in_deck: int = CollectionData.copies_of_base(deck, card_id)
	var owned_count: int = int(owned.get(card_id, 0))
	var deck_total: int = CollectionData.deck_size(deck)
	if deck_total >= CollectionData.DECK_LIMIT or in_deck >= CollectionData.COPY_LIMIT or in_deck >= owned_count:
		_sync_inspector_actions()
		return
	if not _mutate_view_deck_add(card_id):
		_sync_inspector_actions()
		return
	_update_header()
	_refresh_deck_summary()
	_sync_pool_thumb(card_id)
	_sync_inspector_actions()
	_spawn_add_ghost()
	_queue_deck_contents_rebuild()


func _on_deck_remove_pressed(card_id: String) -> void:
	if card_id == "":
		return
	_mutate_view_deck_remove(card_id)
	_update_header()
	_refresh_deck_summary()
	_sync_pool_thumb(card_id)
	_sync_inspector_actions()
	_queue_deck_contents_rebuild()


func _queue_deck_contents_rebuild() -> void:
	if _deck_contents_dirty:
		return
	_deck_contents_dirty = true
	call_deferred("_rebuild_active_deck_contents")


func _rebuild_active_deck_contents() -> void:
	_deck_contents_dirty = false
	if deck_contents_container == null or not is_instance_valid(deck_contents_container):
		return
	_rebuild_deck_contents(_view_deck_counts())


func _on_deck_row_gui(event: InputEvent, card_id: String, row: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var from_rect := Rect2()
		if row != null and is_instance_valid(row):
			from_rect = row.get_global_rect()
		_open_card_inspector(card_id, from_rect)


func _make_pool_thumb(card_id: String, def: Dictionary, card_name: String, owned_count: int, in_deck: int) -> CombatCard:
	var combat_card: CombatCard = COMBAT_CARD.new() as CombatCard
	combat_card.custom_minimum_size = POOL_CARD_SIZE
	combat_card.set_meta("card_id", card_id)
	combat_card.tooltip_text = "%s\n所持 %d / デッキ内 %d" % [card_name, owned_count, in_deck]
	combat_card.pressed.connect(_on_pool_thumb_pressed.bind(card_id, combat_card))
	combat_card.configure({"defId": card_id}, def, true, false, true)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "%d/%d" % [in_deck, owned_count]
	count_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	count_label.offset_left = -46
	count_label.offset_top = 4
	count_label.offset_right = -4
	count_label.offset_bottom = 20
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 9)
	count_label.add_theme_color_override("font_color", Color("d8d0c0"))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	count_label.add_theme_constant_override("outline_size", 3)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_card.add_child(count_label)

	if in_deck <= 0:
		combat_card.modulate = Color(1, 1, 1, 0.92)
	return combat_card


func _on_pool_thumb_pressed(card_id: String, thumb: Control) -> void:
	var from_rect := Rect2()
	if thumb != null and is_instance_valid(thumb):
		from_rect = thumb.get_global_rect()
	_open_card_inspector(card_id, from_rect)


func _sync_pool_thumb(card_id: String) -> void:
	var deck: Dictionary = _view_deck_counts()
	var owned: Dictionary = CollectionData.owned_card_counts()
	var in_deck: int = CollectionData.copies_of_base(deck, card_id)
	var owned_count: int = int(owned.get(card_id, 0))
	for child in card_list_container.get_children():
		if str(child.get_meta("card_id", "")) != card_id:
			continue
		var count_label: Label = child.get_node_or_null("CountLabel") as Label
		if count_label != null:
			count_label.text = "%d/%d" % [in_deck, owned_count]
		if child is CanvasItem:
			(child as CanvasItem).modulate = Color(1, 1, 1, 0.92) if in_deck <= 0 else Color.WHITE


func _open_card_inspector(card_id: String, from_rect: Rect2 = Rect2()) -> void:
	if card_id == "":
		return
	_inspector_busy_close = false
	_inspector_card_id = card_id
	_ensure_inspector_layer()
	_fly_inspector_card(from_rect)
	_sync_inspector_actions()
	_float_inspector_actions()


func _kill_inspector_card_tween() -> void:
	if _inspector_card_tween != null and is_instance_valid(_inspector_card_tween):
		_inspector_card_tween.kill()
	_inspector_card_tween = null


func _mute_card_hover(card: CombatCard) -> void:
	if card.mouse_entered.is_connected(card._on_hovered):
		card.mouse_entered.disconnect(card._on_hovered)
	if card.mouse_exited.is_connected(card._on_unhovered):
		card.mouse_exited.disconnect(card._on_unhovered)


func _make_inspect_card() -> CombatCard:
	var def: Dictionary = Cards.get_card(_inspector_card_id)
	var fake: Dictionary = {"uid": "", "defId": _inspector_card_id}
	var card: CombatCard = COMBAT_CARD.new()
	card.custom_minimum_size = INSPECTOR_CARD_SIZE
	card.size = INSPECTOR_CARD_SIZE
	card.configure(fake, def, true, false, false)
	return card


func _card_pool_center() -> Vector2:
	var scroll: Node = card_list_container.get_parent()
	if scroll is Control:
		return (scroll as Control).get_global_rect().get_center()
	return card_list_container.get_global_rect().get_center()


func _deck_contents_center() -> Vector2:
	var scroll: Node = deck_contents_container.get_parent()
	if scroll is Control:
		return (scroll as Control).get_global_rect().get_center()
	return deck_contents_container.get_global_rect().get_center()


func _close_card_inspector() -> void:
	_kill_inspector_card_tween()
	_inspector_busy_close = false
	_inspector_card_id = ""
	_inspector_card = null
	_inspector_actions = null
	_inspector_minus = null
	_inspector_plus = null
	_inspector_count = null
	_inspector_dim = null
	if _inspector_layer != null and is_instance_valid(_inspector_layer):
		remove_child(_inspector_layer)
		_inspector_layer.queue_free()
	_inspector_layer = null


func _dismiss_inspector() -> void:
	if _inspector_busy_close:
		return
	if _inspector_layer == null or not is_instance_valid(_inspector_layer):
		_close_card_inspector()
		return
	_inspector_busy_close = true
	_kill_inspector_card_tween()
	if _inspector_actions != null and is_instance_valid(_inspector_actions):
		_inspector_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hide_btns := _inspector_actions.create_tween()
		hide_btns.tween_property(_inspector_actions, "modulate:a", 0.0, 0.1)
		hide_btns.parallel().tween_property(_inspector_actions, "position:y", _inspector_actions.position.y + 14.0, 0.1)
	if _inspector_dim != null and is_instance_valid(_inspector_dim):
		_inspector_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dim_tw := _inspector_dim.create_tween()
		dim_tw.tween_property(_inspector_dim, "color:a", 0.0, INSPECTOR_OUT_DUR)
	if _inspector_card != null and is_instance_valid(_inspector_card):
		var card: CombatCard = _inspector_card
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pivot_offset = card.size * 0.5
		var dest: Vector2 = _card_pool_center() - card.pivot_offset
		var tw := card.create_tween().set_parallel(true)
		_inspector_card_tween = tw
		tw.tween_property(card, "global_position", dest, INSPECTOR_OUT_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "scale", Vector2(0.28, 0.28), INSPECTOR_OUT_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(card, "modulate", Color(0.06, 0.05, 0.04, 0.0), INSPECTOR_OUT_DUR)
		tw.chain().tween_callback(_close_card_inspector)
	else:
		_close_card_inspector()


func _ensure_inspector_layer() -> void:
	if _inspector_layer != null and is_instance_valid(_inspector_layer):
		_inspector_layer.move_to_front()
		return
	var layer := Control.new()
	layer.name = "CardInspectorLayer"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 80
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	layer.move_to_front()
	_inspector_layer = layer
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_inspector_dim_gui)
	layer.add_child(dim)
	_inspector_dim = dim
	var dim_tw := dim.create_tween()
	dim_tw.tween_property(dim, "color:a", 0.62, INSPECTOR_IN_DUR)
	_build_inspector_actions()


func _build_inspector_actions() -> void:
	if _inspector_actions != null and is_instance_valid(_inspector_actions):
		return
	var actions := HBoxContainer.new()
	actions.name = "InspectActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	actions.mouse_filter = Control.MOUSE_FILTER_STOP
	actions.z_index = 2
	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.focus_mode = Control.FOCUS_NONE
	minus_btn.custom_minimum_size = Vector2(56, 40)
	minus_btn.add_theme_font_size_override("font_size", 22)
	minus_btn.pressed.connect(_on_inspector_minus)
	actions.add_child(minus_btn)
	var count_label := Label.new()
	count_label.text = "×0"
	count_label.custom_minimum_size = Vector2(72, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", Color("f3ead2"))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	count_label.add_theme_constant_override("outline_size", 4)
	actions.add_child(count_label)
	var plus_btn := Button.new()
	plus_btn.text = "＋"
	plus_btn.focus_mode = Control.FOCUS_NONE
	plus_btn.custom_minimum_size = Vector2(56, 40)
	plus_btn.add_theme_font_size_override("font_size", 22)
	plus_btn.pressed.connect(_on_inspector_plus)
	actions.add_child(plus_btn)
	_inspector_layer.add_child(actions)
	_inspector_actions = actions
	_inspector_minus = minus_btn
	_inspector_plus = plus_btn
	_inspector_count = count_label
	actions.modulate.a = 0.0


func _inspector_card_dest() -> Vector2:
	var view: Vector2 = get_viewport_rect().size
	return Vector2(view.x * 0.5, view.y * 0.42) - INSPECTOR_CARD_SIZE * 0.5


func _fly_inspector_card(from_rect: Rect2) -> void:
	if _inspector_layer == null:
		return
	_kill_inspector_card_tween()
	if _inspector_card != null and is_instance_valid(_inspector_card):
		_inspector_card.queue_free()
		_inspector_card = null
	var card: CombatCard = _make_inspect_card()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.z_index = 3
	_inspector_layer.add_child(card)
	_mute_card_hover(card)
	_inspector_card = card
	card.pivot_offset = INSPECTOR_CARD_SIZE * 0.5
	var dest: Vector2 = _inspector_card_dest()
	var start_center: Vector2 = from_rect.get_center() if from_rect.size.x > 8.0 else _card_pool_center()
	var start_scale: float = 0.4
	if from_rect.size.x > 8.0:
		start_scale = clampf(from_rect.size.x / INSPECTOR_CARD_SIZE.x, 0.28, 0.7)
	card.global_position = start_center - card.pivot_offset
	card.scale = Vector2(start_scale, start_scale)
	card.modulate = Color.WHITE
	var tw := card.create_tween().set_parallel(true)
	_inspector_card_tween = tw
	tw.tween_property(card, "global_position", dest, INSPECTOR_IN_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, INSPECTOR_IN_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _float_inspector_actions() -> void:
	if _inspector_actions == null or not is_instance_valid(_inspector_actions):
		return
	var dest_card: Vector2 = _inspector_card_dest()
	var min_s: Vector2 = _inspector_actions.get_combined_minimum_size()
	var w: float = maxf(220.0, min_s.x)
	var h: float = maxf(40.0, min_s.y)
	_inspector_actions.size = Vector2(w, h)
	var rest := Vector2(dest_card.x + INSPECTOR_CARD_SIZE.x * 0.5 - w * 0.5, dest_card.y + INSPECTOR_CARD_SIZE.y + 16.0)
	_inspector_actions.position = rest + Vector2(0, 18)
	_inspector_actions.modulate.a = 0.0
	var tw := _inspector_actions.create_tween()
	tw.tween_interval(INSPECTOR_IN_DUR * 0.55)
	tw.tween_property(_inspector_actions, "position", rest, INSPECTOR_BTN_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_inspector_actions, "modulate:a", 1.0, INSPECTOR_BTN_DUR)


func _sync_inspector_actions() -> void:
	if _inspector_card_id == "":
		return
	if _inspector_count == null or not is_instance_valid(_inspector_count):
		return
	var deck: Dictionary = _view_deck_counts()
	var owned: Dictionary = CollectionData.owned_card_counts()
	var in_deck: int = CollectionData.copies_of_base(deck, _inspector_card_id)
	var owned_count: int = int(owned.get(_inspector_card_id, 0))
	var deck_total: int = CollectionData.deck_size(deck)
	_inspector_count.text = "×%d" % in_deck
	if _inspector_minus != null and is_instance_valid(_inspector_minus):
		_inspector_minus.disabled = in_deck <= 0
	if _inspector_plus != null and is_instance_valid(_inspector_plus):
		_inspector_plus.disabled = deck_total >= CollectionData.DECK_LIMIT or in_deck >= CollectionData.COPY_LIMIT or in_deck >= owned_count


func _on_inspector_plus() -> void:
	if _inspector_busy_close or _inspector_card_id == "":
		return
	_on_deck_add_pressed(_inspector_card_id)


func _on_inspector_minus() -> void:
	if _inspector_busy_close or _inspector_card_id == "":
		return
	_on_deck_remove_pressed(_inspector_card_id)


func _spawn_add_ghost() -> void:
	if _inspector_layer == null or _inspector_card == null:
		return
	if not is_instance_valid(_inspector_layer) or not is_instance_valid(_inspector_card):
		return
	var ghost: CombatCard = _make_inspect_card()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 4
	_inspector_layer.add_child(ghost)
	_mute_card_hover(ghost)
	ghost.pivot_offset = INSPECTOR_CARD_SIZE * 0.5
	ghost.global_position = _inspector_card.global_position
	ghost.scale = _inspector_card.scale
	var dest: Vector2 = _deck_contents_center() - ghost.pivot_offset
	var tw := ghost.create_tween().set_parallel(true)
	tw.tween_property(ghost, "global_position", dest, INSPECTOR_GHOST_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "scale", Vector2(0.18, 0.18), INSPECTOR_GHOST_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "modulate", Color(0.05, 0.04, 0.03, 0.0), INSPECTOR_GHOST_DUR)
	tw.chain().tween_callback(ghost.queue_free)


func _on_inspector_dim_gui(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_dismiss_inspector()


## DeckListScreen.tsx の「＋新規デッキ」（nextDeckName()で自動命名→即編集モードへ）
func _on_deck_list_create_pressed() -> void:
	var name := CollectionData.next_deck_name(CollectionData.decks)
	_active_deck_before_edit = CollectionData.active_deck
	if CollectionData.create_deck(name):
		GameState._persist_profile()
		_deck_mode = "edit"
		_deck_renaming = false
		_refresh_deck_tab()
		_update_header()


## DeckListScreen.tsx の onEditDeck()（デッキタイルクリック→編集モードへ）
func _on_deck_list_open(name: String) -> void:
	_active_deck_before_edit = CollectionData.active_deck
	CollectionData.set_active_deck(name)
	GameState._persist_profile()
	_deck_mode = "edit"
	_deck_renaming = false
	_refresh_deck_tab()
	_update_header()


## DeckBuilderScreen.tsx の「記録して戻る」（onBack、一覧モードへ）
func _on_deck_back_to_list_pressed() -> void:
	if _deck_edit_blocks_leave():
		_pending_deck_leave = "list"
		_show_deck_save_dialog()
		return
	_close_card_inspector()
	_close_deck_edit()
	_deck_mode = "list"
	_refresh_deck_tab()
	_update_header()


func _on_rename_deck_pressed() -> void:
	_deck_renaming = true
	deck_rename_edit.text = CollectionData.active_deck
	_refresh_deck_edit_header()


func _on_rename_confirm_pressed() -> void:
	if CollectionData.rename_deck(CollectionData.active_deck, deck_rename_edit.text):
		_deck_renaming = false
		GameState._persist_profile()
	_refresh_deck_edit_header()
	_update_header()


func _on_rename_cancel_pressed() -> void:
	_deck_renaming = false
	_refresh_deck_edit_header()


func _on_delete_deck_pressed() -> void:
	_close_card_inspector()
	_deck_edit_open = false
	CollectionData.delete_deck(CollectionData.active_deck)
	_deck_mode = "list"
	GameState._persist_profile()
	_refresh_deck_tab()
	_update_header()


func _on_deck_search_changed(text: String) -> void:
	_deck_search = text
	_rebuild_card_list()


func _on_deck_sort_selected(index: int) -> void:
	_deck_sort_mode = DECK_SORT_MODES[index]
	_rebuild_card_list()


func _on_deck_filter_archetype_toggled(pressed: bool, value: String) -> void:
	if pressed:
		_deck_filter_archetypes[value] = true
	else:
		_deck_filter_archetypes.erase(value)
	_rebuild_card_list()
	deck_filter_archetype_popover.visible = false


func _on_deck_filter_rarity_toggled(pressed: bool, value: String) -> void:
	if pressed:
		_deck_filter_rarities[value] = true
	else:
		_deck_filter_rarities.erase(value)
	_rebuild_card_list()
	deck_filter_rarity_popover.visible = false


func _on_deck_filter_ai_tag_toggled(pressed: bool, value: String) -> void:
	if pressed:
		_deck_filter_ai_tags[value] = true
	else:
		_deck_filter_ai_tags.erase(value)
	_rebuild_card_list()
	deck_filter_ai_tag_popover.visible = false


## DeckBuilderScreen.tsx の「条件をリセット」相当
func _on_deck_filter_reset_pressed() -> void:
	_deck_filter_archetypes.clear()
	_deck_filter_rarities.clear()
	_deck_filter_ai_tags.clear()
	_deck_search = ""
	deck_search_edit.text = ""
	_sync_toggle_row(deck_filter_archetype_row, DECK_FILTERABLE_ARCHETYPES, _deck_filter_archetypes)
	_sync_toggle_row(deck_filter_rarity_row, DECK_FILTERABLE_RARITIES, _deck_filter_rarities)
	_sync_toggle_row(deck_filter_ai_tag_row, DECK_FILTERABLE_AI_TAGS, _deck_filter_ai_tags)
	_rebuild_card_list()
	deck_filter_archetype_popover.visible = false
	deck_filter_rarity_popover.visible = false
	deck_filter_ai_tag_popover.visible = false
