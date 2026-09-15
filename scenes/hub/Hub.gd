extends Control

## Godot向けHub画面。単一画面＋サイドナビで、探索準備・ロードアウト・
## 売買・パック開封を一貫して操作する。ゲームロジックと永続データは
## Autoload／scripts側に置き、このスクリプトは表示と入力の接続を担当する。

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
@onready var prepare_equipment_summary_panel: PanelContainer = $Root/Body/Content/DescendPanel/PrepareEquipmentSummaryPanel
@onready var prepare_equipment_stats_label: Label = $Root/Body/Content/DescendPanel/PrepareEquipmentSummaryPanel/Margin/Content/StatsLabel
@onready var prepare_deck_select_panel: PanelContainer = $Root/Body/Content/DescendPanel/PrepareDeckSelectPanel
@onready var prepare_deck_list: VBoxContainer = $Root/Body/Content/DescendPanel/PrepareDeckSelectPanel/Margin/Content/DeckList
@onready var prepare_selected_deck_label: Label = $Root/Body/Content/DescendPanel/PrepareDeckSelectPanel/Margin/Content/SelectedDeckLabel

@onready var placeholder_panel: Label = $Root/Body/Content/PlaceholderPanel
@onready var commerce_panel: VBoxContainer = $Root/Body/Content/CommercePanel
@onready var commerce_title: Label = $Root/Body/Content/CommercePanel/CommerceTitle
@onready var commerce_list: VBoxContainer = $Root/Body/Content/CommercePanel/CommerceList

@onready var sell_panel: VBoxContainer = $Root/Body/Content/SellPanel
@onready var sell_card_tab_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellCardTabButton
@onready var sell_equipment_tab_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellEquipmentTabButton
@onready var sell_rune_tab_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellRuneTabButton
@onready var sell_surplus_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellSurplusButton
@onready var sell_select_all_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellSelectAllButton
@onready var sell_clear_all_button: Button = $Root/Body/Content/SellPanel/SellTabRow/SellClearAllButton
@onready var sell_list_container: HFlowContainer = $Root/Body/Content/SellPanel/SellListScroll/SellListContainer
@onready var sell_total_label: Label = $Root/Body/Content/SellPanel/SellFooterRow/SellTotalLabel
@onready var sell_confirm_button: Button = $Root/Body/Content/SellPanel/SellFooterRow/SellConfirmButton

@onready var deck_panel: VBoxContainer = $Root/Body/Content/DeckPanel

@onready var deck_list_sub_panel: VBoxContainer = $Root/Body/Content/DeckPanel/DeckListSubPanel
@onready var deck_list_create_button: Button = $Root/Body/Content/DeckPanel/DeckListSubPanel/DeckListHeaderRow/DeckListCreateButton
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
@onready var deck_filter_archetype_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterTriggerRow/ArchetypeButton
@onready var deck_filter_rarity_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterTriggerRow/RarityButton
@onready var deck_filter_ai_tag_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterTriggerRow/AiTagButton
@onready var deck_filter_archetype_popover: PanelContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterArchetypePopover
@onready var deck_filter_rarity_popover: PanelContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterRarityPopover
@onready var deck_filter_ai_tag_popover: PanelContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterAiTagPopover
@onready var deck_filter_archetype_row: HFlowContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterArchetypePopover/DeckFilterArchetypeRow
@onready var deck_filter_rarity_row: HFlowContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterRarityPopover/DeckFilterRarityRow
@onready var deck_filter_ai_tag_row: HFlowContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckFilterAiTagPopover/DeckFilterAiTagRow
@onready var deck_result_count_label: Label = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/DeckResultCountLabel
@onready var card_list_container: HFlowContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/CardPoolPanel/CardPool/CardScroll/CardListContainer
@onready var deck_contents_container: VBoxContainer = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/DeckContentsPanel/DeckContents/DeckContentsScroll/DeckContentsContainer
@onready var deck_back_to_list_button: Button = $Root/Body/Content/DeckPanel/DeckEditSubPanel/DeckWorkspace/DeckContentsPanel/DeckContents/DeckBackToListButton

@onready var equipment_panel: VBoxContainer = $Root/Body/Content/EquipmentPanel
@onready var equipped_list_container: VBoxContainer = $Root/Body/Content/EquipmentPanel/EquippedListContainer
@onready var stats_label: Label = $Root/Body/Content/EquipmentPanel/StatsLabel
@onready var equipment_sort_button: Button = $Root/Body/Content/EquipmentPanel/EquipmentFilterRow/EquipmentSortButton
@onready var equipment_filter_reset_button: Button = $Root/Body/Content/EquipmentPanel/EquipmentFilterRow/EquipmentFilterResetButton
@onready var equipment_filter_archetype_button: Button = $Root/Body/Content/EquipmentPanel/EquipmentFilterTriggerRow/ArchetypeButton
@onready var equipment_filter_slot_button: Button = $Root/Body/Content/EquipmentPanel/EquipmentFilterTriggerRow/SlotButton
@onready var equipment_filter_archetype_popover: PanelContainer = $Root/Body/Content/EquipmentPanel/EquipmentFilterArchetypePopover
@onready var equipment_filter_slot_popover: PanelContainer = $Root/Body/Content/EquipmentPanel/EquipmentFilterSlotPopover
@onready var equipment_filter_archetype_row: HFlowContainer = $Root/Body/Content/EquipmentPanel/EquipmentFilterArchetypePopover/EquipmentFilterArchetypeRow
@onready var equipment_filter_slot_row: HFlowContainer = $Root/Body/Content/EquipmentPanel/EquipmentFilterSlotPopover/EquipmentFilterSlotRow
@onready var inventory_label: Label = $Root/Body/Content/EquipmentPanel/InventoryLabel
@onready var inventory_list_container: VBoxContainer = $Root/Body/Content/EquipmentPanel/InventoryScroll/InventoryListContainer
@onready var rune_label: Label = $Root/Body/Content/EquipmentPanel/RuneLabel
@onready var rune_search_edit: LineEdit = $Root/Body/Content/EquipmentPanel/RuneSearchEdit
@onready var rune_category_row: HFlowContainer = $Root/Body/Content/EquipmentPanel/RuneCategoryRow
@onready var rune_list_container: VBoxContainer = $Root/Body/Content/EquipmentPanel/RuneScroll/RuneListContainer

@onready var nav_buttons: Dictionary = {
	"descend": $Root/Body/Nav/DescendButton,
	"deck": $Root/Body/Nav/DeckButton,
	"equipment": $Root/Body/Nav/EquipmentButton,
	"sell": $Root/Body/Nav/SellButton,
	"shop": $Root/Body/Nav/ShopButton,
	"packs": $Root/Body/Nav/PacksButton,
}

var _selected_rune_id: String = ""
var _commerce_tab := ""
var _last_pack_result: Array = []  ## store.ts の lastPackResult 相当（ShopPanel.tsx の通常パック結果表示）

# SellScreen.tsx 相当の状態
var _sell_tab: String = "card"  ## "card" | "equipment" | "rune"
var _sell_card_selections: Dictionary = {}  ## base_card_id -> 選択数
var _sell_equipment_uids: Dictionary = {}  ## uid -> true
var _sell_rune_ids: Dictionary = {}  ## id -> true

# ============================================================
# デッキ編成/装備タブの検索・フィルター・ソート
# （DeckBuilderScreen.tsx / EquipmentScreen.tsx 相当）
# ============================================================

const DECK_FILTERABLE_ARCHETYPES := ["fanatic", "knight", "poison", "outer", "elder", "deep", "offering", "shadow", "greatold"]
const DECK_FILTERABLE_RARITIES := ["starter", "common", "uncommon", "rare"]
const DECK_FILTERABLE_AI_TAGS := ["attack", "defense", "effect"]
const DECK_RARITY_ORDER := ["starter", "common", "uncommon", "rare", "status"]
const DECK_SORT_MODES := ["cost", "rarity", "owned", "archetype"]
const DECK_SORT_LABELS := {"cost": "コスト順", "rarity": "レア度順", "owned": "所持数順", "archetype": "ジャンル順"}
const RARITY_LABELS := {"starter": "スターター", "common": "コモン", "uncommon": "アンコモン", "rare": "レア", "status": "状態"}
const AI_TAG_LABELS := {"attack": "攻撃", "defense": "防御", "effect": "効果"}

const EQUIPMENT_SLOT_LABELS := {"head": "頭", "chest": "胸", "arms": "腕", "legs": "脚", "feet": "足"}
const NORMAL_PACK_ART := "res://art/pixel/ui/card_back.png"

## CombatCard.gd と同じカード枠の9-slice指定。Hubの一覧でも同じカード体系を使う。
const CARD_FRAME_BY_RARITY := {
	"common": ["res://art/pixel/ui/frame_card_common_9.png", 8],
	"uncommon": ["res://art/pixel/ui/frame_card_uncommon_9.png", 16],
	"rare": ["res://art/pixel/ui/frame_card_9.png", 13],
}
const CARD_FRAME_BY_ARCHETYPE := {
	"greatold": ["res://art/pixel/ui/frame_card_greatold_9.png", 15],
	"elder": ["res://art/pixel/ui/frame_card_elder_9.png", 14],
	"outer": ["res://art/pixel/ui/frame_card_outer_9.png", 19],
}

const RUNE_CATEGORY_OF_EFFECT := {
	"STR+": "attack", "VULN+": "attack", "THORN": "attack",
	"BLK+": "defense", "POISON": "defense",
	"HEAL": "heal", "SAN+": "heal",
	"DRAW": "special", "ENERGY+": "special",
}
const RUNE_CATEGORIES := ["attack", "defense", "heal", "special"]
const RUNE_CATEGORY_LABELS := {"attack": "攻", "defense": "防", "heal": "回復", "special": "特殊"}

var _deck_mode: String = "list"  ## DeckHubScreen.tsx の mode: "list" | "edit"
var _deck_renaming: bool = false
var _deck_filter_archetypes: Dictionary = {}
var _deck_filter_rarities: Dictionary = {}
var _deck_filter_ai_tags: Dictionary = {}
var _deck_search: String = ""
var _deck_sort_mode: String = "cost"

var _equip_filter_archetypes: Dictionary = {}
var _equip_filter_slots: Dictionary = {}
var _equip_sort_asc: bool = false

var _rune_search: String = ""
var _rune_category: String = ""  # "" = 全て


func _ready() -> void:
	for tab_name in nav_buttons.keys():
		nav_buttons[tab_name].pressed.connect(_select_tab.bind(tab_name))
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	extract_button.pressed.connect(_on_extract_button_pressed)
	top_right_button.pressed.connect(_on_top_right_button_pressed)
	deck_list_create_button.pressed.connect(_on_deck_list_create_pressed)
	rename_deck_button.pressed.connect(_on_rename_deck_pressed)
	delete_deck_button.pressed.connect(_on_delete_deck_pressed)
	confirm_rename_button.pressed.connect(_on_rename_confirm_pressed)
	cancel_rename_button.pressed.connect(_on_rename_cancel_pressed)
	deck_back_to_list_button.pressed.connect(_on_deck_back_to_list_pressed)
	sell_card_tab_button.pressed.connect(_on_sell_tab_selected.bind("card"))
	sell_equipment_tab_button.pressed.connect(_on_sell_tab_selected.bind("equipment"))
	sell_rune_tab_button.pressed.connect(_on_sell_tab_selected.bind("rune"))
	sell_surplus_button.pressed.connect(_on_sell_surplus_pressed)
	sell_select_all_button.pressed.connect(_on_sell_select_all_pressed)
	sell_clear_all_button.pressed.connect(_on_sell_clear_all_pressed)
	sell_confirm_button.pressed.connect(_on_sell_confirm_pressed)
	_setup_deck_filters()
	_setup_equipment_filters()
	_select_tab("descend")
	_update_header()
	if GameState.toast != "":
		GameState.toast = ""


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


## 装備タブのジャンル/部位フィルター・tierソート・ルーン検索/カテゴリ行を一度だけ構築する。
func _setup_equipment_filters() -> void:
	equipment_sort_button.pressed.connect(_on_equipment_sort_toggle_pressed)
	equipment_filter_reset_button.pressed.connect(_on_equipment_filter_reset_pressed)
	rune_search_edit.text_changed.connect(_on_rune_search_changed)
	equipment_filter_archetype_button.pressed.connect(_toggle_equipment_popover.bind(equipment_filter_archetype_popover))
	equipment_filter_slot_button.pressed.connect(_toggle_equipment_popover.bind(equipment_filter_slot_popover))

	_build_toggle_row(equipment_filter_archetype_row, _equipment_filterable_archetypes(),
		func(a): return "汎用" if a == "generic" else str(Cards.ARCHETYPE_LABELS.get(a, a)),
		_equip_filter_archetypes, _on_equip_filter_archetype_toggled)
	_build_toggle_row(equipment_filter_slot_row, Equipment.EQUIPMENT_SLOTS,
		func(s): return str(EQUIPMENT_SLOT_LABELS.get(s, s)),
		_equip_filter_slots, _on_equip_filter_slot_toggled)

	var group := ButtonGroup.new()
	var rune_cat_options: Array = [""] + RUNE_CATEGORIES
	for opt in rune_cat_options:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.text = "全て" if opt == "" else str(RUNE_CATEGORY_LABELS.get(opt, opt))
		btn.button_pressed = _rune_category == opt
		btn.toggled.connect(_on_rune_category_toggled.bind(opt))
		rune_category_row.add_child(btn)


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


func _toggle_deck_popover(target: Control) -> void:
	for panel in [deck_filter_archetype_popover, deck_filter_rarity_popover, deck_filter_ai_tag_popover]:
		panel.visible = panel == target and not target.visible


func _toggle_equipment_popover(target: Control) -> void:
	for panel in [equipment_filter_archetype_popover, equipment_filter_slot_popover]:
		panel.visible = panel == target and not target.visible


## _build_toggle_row()で構築済みの行のボタン押下状態を、リセット等で外部からstateを
## 変更した後に再同期する（シグナルは発火させない）。
func _sync_toggle_row(container: Control, options: Array, state: Dictionary) -> void:
	var i := 0
	for child in container.get_children():
		if child is Button and i < options.size():
			child.set_pressed_no_signal(state.has(options[i]))
		i += 1


## EquipmentScreen.tsx の FILTERABLE_ARCHETYPES 相当：EQUIPMENTカタログに実在する
## アーキタイプ（"generic"含む）を出現順に重複無しで集めたもの。
func _equipment_filterable_archetypes() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for def in Equipment.EQUIPMENT.values():
		var a: String = str(def.get("archetype", "generic"))
		if not seen.has(a):
			seen[a] = true
			out.append(a)
	return out


## Content配下の全パネルをまとめて非表示にする。tab === "packs" || tab === "deck" の時
## Content内の他パネルが一切見えない（HubScreen.tsx 42-62行目の早期returnレンダー）実ソースの
## 挙動を、個別のvisible設定漏れが起きないよう一箇所にまとめて再現する。
func _hide_all_content_panels() -> void:
	descend_panel.visible = false
	deck_panel.visible = false
	equipment_panel.visible = false
	sell_panel.visible = false
	commerce_panel.visible = false
	placeholder_panel.visible = false


func _select_tab(tab_name: String) -> void:
	for key in nav_buttons.keys():
		nav_buttons[key].set_pressed_no_signal(key == tab_name)
	_hide_all_content_panels()
	match tab_name:
		"descend":
			descend_panel.visible = true
		"deck":
			deck_panel.visible = true
		"equipment":
			equipment_panel.visible = true
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
	elif tab_name == "equipment":
		_selected_rune_id = ""
		_refresh_equipment_tab()
	elif tab_name == "sell":
		## HubScreen.tsx の {tab === "sell" ? <SellScreen .../> : null} も、deckタブ同様
		## タブ切替でSellScreenがアンマウント/再マウントされ、選択状態(useState)は
		## タブへ再入するたびに初期化される。ここでも同じくタブ選択時にリセットする。
		_sell_tab = "card"
		_sell_card_selections.clear()
		_sell_equipment_uids.clear()
		_sell_rune_ids.clear()
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
		descend_status_label.text = "中継点\n%sを越えた\nHP %d/%d · SAN %d/%d · 貝殻 %d" % [
			Floors.layer_label(GameState.floor),
			GameState.hp,
			GameState.max_hp,
			GameState.sanity,
			GameState.max_sanity,
			GameState.shells,
		]
		primary_action_button.text = "次の層へ沈む"
		primary_action_button.disabled = false
		extract_button.visible = true
		stat_panel.visible = false
		prepare_equipment_summary_panel.visible = false
		prepare_deck_select_panel.visible = false
	else:
		## PrepareView.tsx 相当。canStart は実ソースでは
		## `playerName.trim().length > 0 && !loadoutError()` だが、名前入力UIは未実装のため
		## デッキ枚数チェック（loadoutError()）のみを反映する。
		descend_status_label.text = "探索準備\n最深到達: %s · 貝殻 %d" % [
			Floors.layer_label(GameState.best_floor) if GameState.best_floor > 0 else "未潜航",
			GameState.shells,
		]
		primary_action_button.text = "潜航開始"
		primary_action_button.disabled = CollectionData.loadout_error() != ""
		extract_button.visible = false
		stat_panel.visible = true
		_refresh_stat_panel()
		prepare_equipment_summary_panel.visible = true
		prepare_deck_select_panel.visible = true
		_refresh_prepare_equipment_summary()
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
	_rebuild_prepare_deck_list()
	_update_header()
	primary_action_button.disabled = CollectionData.loadout_error() != ""


func _refresh_prepare_equipment_summary() -> void:
	var equipment_stats := Equipment.compute_equipment_stats(GameState.equipped, Callable(CollectionData, "peek_rune"))
	var vitals := Profile.derived_vitals(GameState.stats, GameState.madness)
	prepare_equipment_stats_label.text = "体力 %d\n筋力 %d\n防御 %d\n毒耐性 %d\n正気耐性 %d" % [
		int(vitals.get("max_hp", 0)),
		int(equipment_stats.get("strength", 0)),
		roundi(float(equipment_stats.get("defense", 0.0))),
		roundi(float(equipment_stats.get("poisonResist", 0.0))),
		roundi(float(equipment_stats.get("sanResist", 0.0))),
	]


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
	var counts: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	return CollectionData.deck_size(counts)


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


func _refresh_commerce() -> void:
	for child in commerce_list.get_children(): child.free()
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
		commerce_title.text = "カードパック（チケットを1枚消費）"
		var pack_grid := GridContainer.new()
		pack_grid.columns = 3
		pack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pack_grid.add_theme_constant_override("h_separation", 10)
		pack_grid.add_theme_constant_override("v_separation", 10)
		for a in ["fanatic","knight","poison","outer","elder","deep","offering","shadow","greatold"]:
			var n := int(CollectionData.pack_tickets.get(a,0))
			pack_grid.add_child(_make_pack_button(a, n))
		commerce_list.add_child(pack_grid)


## ShopPanel.tsx の buyCardPack ボタン相当
func _on_buy_card_pack() -> void:
	var result := GameState.buy_card_pack()
	if not result.is_empty():
		_last_pack_result = result
	_refresh_commerce()


## ShopPanel.tsx の clearPackResult() 相当
func _on_clear_pack_result() -> void:
	_last_pack_result = []
	_refresh_commerce()

## store.ts の openArchetypePack()。前半2枚は weightedArchetypeCard()（当該アーキタイプ保証＋
## レアリティ62/28/10%＋未所持優遇）、後半2枚は weightedCard()（同じ重み付けの自由枠）で選ぶ。
## owner は実ソース同様 `character ?? starterPath(stats)`（ラン中でなければ暫定キャラで判定）。
func _open_pack(archetype: String) -> void:
	if not CollectionData.consume_pack_ticket(archetype): return
	var owner: String = GameState.character if GameState.character != "" else GameState.starter_path(GameState.stats)
	var rand := Callable(GameState, "_rand")
	for i in range(2):
		var forced := Cards.weighted_archetype_card(owner, archetype, rand)
		CollectionData.add_loot_card(str(forced.get("defId", "")))
	for i in range(2):
		var free := Cards.weighted_card(owner, rand)
		CollectionData.add_loot_card(str(free.get("defId", "")))
	_refresh_commerce()

func _equipped(gear: Dictionary) -> bool:
	for item in GameState.equipped.values():
		if item != null and item.get("uid","") == gear.get("uid",""): return true
	return false

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
	row.add_child(_make_art_thumbnail(str(definition.get("art", "")), str(definition.get("archetype", "")), str(definition.get("rarity", "common")), Vector2(46, 56)))
	var label := Label.new()
	label.text = "・%s" % str(definition.get("name", fallback_id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	row.add_child(label)
	commerce_list.add_child(row)


## PackShopScreen.tsx と同様に、チケットではなく pack_${archetype}.png のパック本体をグリッド表示する。
func _make_pack_button(archetype: String, ticket_count: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(174, 216)
	button.disabled = ticket_count <= 0
	button.pressed.connect(_open_pack.bind(archetype))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	var pack_art := TextureRect.new()
	pack_art.custom_minimum_size = Vector2(0, 142)
	pack_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pack_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pack_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pack_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pack_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := "res://art/pixel/packs/pack_%s.png" % archetype
	if ResourceLoader.exists(art_path):
		pack_art.texture = load(art_path)
	content.add_child(pack_art)
	var label := Label.new()
	label.text = "%sパック\n所持 %d" % [str(Cards.ARCHETYPE_LABELS.get(archetype, archetype)), ticket_count]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	button.add_child(content)
	return button


## カード/装備/チケット用の実画像サムネイル。
## TextureRectで art を表示し、CombatCard.gd と同一の NinePatchRect 枠を重ねる。
func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return null


func _make_art_thumbnail(art_path: String, archetype: String, rarity: String, minimum_size: Vector2) -> Control:
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

	var frame_data: Array = CARD_FRAME_BY_ARCHETYPE.get(archetype, CARD_FRAME_BY_RARITY.get(rarity, CARD_FRAME_BY_RARITY["common"]))
	var frame := NinePatchRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_path := str(frame_data[0])
	var frame_texture := _load_texture_safe(frame_path)
	if frame_texture != null:
		frame.texture = frame_texture
		var margin := int(frame_data[1])
		frame.patch_margin_left = margin
		frame.patch_margin_top = margin
		frame.patch_margin_right = margin
		frame.patch_margin_bottom = margin
	holder.add_child(frame)
	return holder


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


## SellScreen.tsx の sellableEquipment（装着中は除外）
func _sellable_equipment() -> Array:
	var out: Array = []
	for inst in CollectionData.inventory.equipment:
		if not _equipped(inst):
			out.append(inst)
	return out


func _socketed_rune_ids() -> Dictionary:
	var out: Dictionary = {}
	for inst in CollectionData.inventory.equipment:
		for rid in inst.get("socketed_runes", []):
			if rid != null:
				out[str(rid)] = true
	return out


## SellScreen.tsx の sellableRunes（いずれかの装備にソケット中のものは除外）
func _sellable_runes() -> Array:
	var socketed := _socketed_rune_ids()
	var out: Array = []
	for rune in CollectionData.inventory.runes:
		if not socketed.has(str(rune.get("id", ""))):
			out.append(rune)
	return out


## SellScreen.tsx の qtyFor()
func _sell_qty_for(base_card_id: String, sellable: int) -> int:
	return min(int(_sell_card_selections.get(base_card_id, 0)), sellable)


## SellScreen.tsx の setCardQty()
func _set_sell_card_qty(base_card_id: String, qty: int, max_qty: int) -> void:
	var clamped: int = max(0, min(max_qty, qty))
	if clamped <= 0:
		_sell_card_selections.erase(base_card_id)
	else:
		_sell_card_selections[base_card_id] = clamped
	_refresh_sell_tab()


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
			total += qty * Smith.card_sell_price(Cards.get_card(str(r.base_card_id)))
	return total


func _sell_equipment_total_value() -> int:
	var total := 0
	for inst in _sellable_equipment():
		if _sell_equipment_uids.has(str(inst.get("uid", ""))):
			total += Smith.equipment_sell_price(inst)
	return total


func _sell_rune_total_value() -> int:
	var total := 0
	for rune in _sellable_runes():
		if _sell_rune_ids.has(str(rune.get("id", ""))):
			total += Smith.rune_sell_price(rune)
	return total


## SellScreen.tsx の totalValue
func _sell_total_value() -> int:
	return _sell_card_total_value() + _sell_equipment_total_value() + _sell_rune_total_value()


## SellScreen.tsx の totalSelected
func _sell_total_selected() -> int:
	return _sell_card_total_count() + _sell_equipment_uids.size() + _sell_rune_ids.size()


func _refresh_sell_tab() -> void:
	for key in ["card", "equipment", "rune"]:
		var btn: Button = sell_card_tab_button if key == "card" else (sell_equipment_tab_button if key == "equipment" else sell_rune_tab_button)
		btn.disabled = key == _sell_tab
	sell_surplus_button.visible = _sell_tab == "card"

	for child in sell_list_container.get_children():
		child.queue_free()

	if _sell_tab == "card":
		## SellScreen.tsx の grid-cols-[repeat(auto-fill,minmax(8rem,1fr))] 相当。
		## 1枚あたり最小 Vector2(128,180) のセルを HFlowContainer で折り返し表示する。
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
			var unit_price := Smith.card_sell_price(def)

			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(128, 180)
			cell.add_theme_constant_override("separation", 4)
			cell.clip_contents = true

			## SellScreen.tsx の CardView onClick（クリックで最大/解除トグル）相当
			var thumb_btn := Button.new()
			thumb_btn.custom_minimum_size = Vector2(0, 82)
			thumb_btn.clip_contents = true
			thumb_btn.tooltip_text = "%s（所持%d）" % [str(def.get("name", base_card_id)), owned_n]
			thumb_btn.pressed.connect(_set_sell_card_qty.bind(base_card_id, 0 if qty > 0 else sellable, sellable))
			var art_path := str(def.get("art", ""))
			var sell_art := _make_art_thumbnail(art_path, str(def.get("archetype", "")), str(def.get("rarity", "common")), Vector2(0, 82))
			sell_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			thumb_btn.add_child(sell_art)
			var owned_badge := Label.new()
			owned_badge.text = "x%d" % owned_n
			owned_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
			owned_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumb_btn.add_child(owned_badge)
			cell.add_child(thumb_btn)

			var name_label := Label.new()
			name_label.text = str(def.get("name", base_card_id))
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			name_label.max_lines_visible = 2
			cell.add_child(name_label)

			var qty_row := HBoxContainer.new()
			qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
			qty_row.add_theme_constant_override("separation", 4)
			var minus_btn := Button.new()
			minus_btn.text = "-"
			minus_btn.disabled = qty <= 0
			minus_btn.pressed.connect(_set_sell_card_qty.bind(base_card_id, qty - 1, sellable))
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
			plus_btn.pressed.connect(_set_sell_card_qty.bind(base_card_id, qty + 1, sellable))
			qty_row.add_child(plus_btn)
			cell.add_child(qty_row)

			var price_label := Label.new()
			price_label.text = "貝殻%d/枚" % unit_price
			price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			cell.add_child(price_label)

			sell_list_container.add_child(cell)

	elif _sell_tab == "equipment":
		var equipment_list := _sellable_equipment()
		if equipment_list.is_empty():
			var empty_label := Label.new()
			empty_label.text = "売れる装備がない。"
			sell_list_container.add_child(empty_label)
		for inst in equipment_list:
			var uid := str(inst.get("uid", ""))
			var def := Equipment.get_equipment(str(inst.get("def_id", "")))
			var selected := _sell_equipment_uids.has(uid)

			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(112, 140)
			cell.add_theme_constant_override("separation", 4)
			cell.add_child(_make_art_thumbnail(str(def.get("art", "")), str(def.get("archetype", "")), "common", Vector2(0, 64)))

			var btn := Button.new()
			btn.toggle_mode = true
			btn.button_pressed = selected
			btn.text = "%s\n貝殻%d" % [Equipment.equipment_label(inst), Smith.equipment_sell_price(inst)]
			btn.toggled.connect(_on_sell_equipment_toggled.bind(uid))
			cell.add_child(btn)

			sell_list_container.add_child(cell)

	else:
		var rune_list := _sellable_runes()
		if rune_list.is_empty():
			var empty_label := Label.new()
			empty_label.text = "売れるルーンがない。"
			sell_list_container.add_child(empty_label)
		for rune in rune_list:
			var rid := str(rune.get("id", ""))
			var selected := _sell_rune_ids.has(rid)

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(112, 64)
			btn.toggle_mode = true
			btn.button_pressed = selected
			btn.text = "%s（値%s）\n貝殻%d" % [str(rune.get("effect", "?")), str(rune.get("value", "?")), Smith.rune_sell_price(rune)]
			btn.toggled.connect(_on_sell_rune_toggled.bind(rid))

			sell_list_container.add_child(btn)

	sell_total_label.text = "選択中 %d点 · 獲得予定 貝殻%d" % [_sell_total_selected(), _sell_total_value()]
	sell_confirm_button.disabled = _sell_total_selected() == 0


func _on_sell_tab_selected(tab_name: String) -> void:
	_sell_tab = tab_name
	_refresh_sell_tab()


func _on_sell_equipment_toggled(pressed: bool, uid: String) -> void:
	if pressed:
		_sell_equipment_uids[uid] = true
	else:
		_sell_equipment_uids.erase(uid)
	_refresh_sell_tab()


func _on_sell_rune_toggled(pressed: bool, rid: String) -> void:
	if pressed:
		_sell_rune_ids[rid] = true
	else:
		_sell_rune_ids.erase(rid)
	_refresh_sell_tab()


## SellScreen.tsx の selectAll()
func _on_sell_select_all_pressed() -> void:
	if _sell_tab == "card":
		_sell_card_selections.clear()
		for r in _sellable_card_rows():
			_sell_card_selections[str(r.base_card_id)] = int(r.sellable)
	elif _sell_tab == "equipment":
		_sell_equipment_uids.clear()
		for inst in _sellable_equipment():
			_sell_equipment_uids[str(inst.get("uid", ""))] = true
	else:
		_sell_rune_ids.clear()
		for rune in _sellable_runes():
			_sell_rune_ids[str(rune.get("id", ""))] = true
	_refresh_sell_tab()


## SellScreen.tsx の clearAll()
func _on_sell_clear_all_pressed() -> void:
	if _sell_tab == "card":
		_sell_card_selections.clear()
	elif _sell_tab == "equipment":
		_sell_equipment_uids.clear()
	else:
		_sell_rune_ids.clear()
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
	GameState.sell_items(card_ids, _sell_equipment_uids.keys(), _sell_rune_ids.keys())
	_sell_card_selections.clear()
	_sell_equipment_uids.clear()
	_sell_rune_ids.clear()
	_refresh_sell_tab()
	_update_header()


# ============================================================
# デッキ編成タブ（DeckHubScreen.tsx / DeckBuilderScreen.tsx 相当）
# ============================================================

## DeckHubScreen.tsx の mode: "list" | "edit" 相当のトップレベル切り替え
func _refresh_deck_tab() -> void:
	deck_list_sub_panel.visible = _deck_mode == "list"
	deck_edit_sub_panel.visible = _deck_mode == "edit"
	if _deck_mode == "list":
		_rebuild_deck_list()
	else:
		_refresh_deck_edit_header()
		_refresh_deck_summary()
		_rebuild_card_list()


## DeckListScreen.tsx の topArchetypeOfCounts()
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
	if best_archetype == "":
		return {}
	return {"archetype": best_archetype, "count": best_count}


## DeckListScreen.tsx の「禁書目録」一覧（本のようなタイル一覧、簡易UI版）
func _rebuild_deck_list() -> void:
	for child in deck_list_container.get_children():
		child.queue_free()
	var names := CollectionData.decks.keys()
	if names.is_empty():
		var empty_label := Label.new()
		empty_label.text = "デッキがありません。"
		deck_list_container.add_child(empty_label)
		return
	for name in names:
		var counts: Dictionary = CollectionData.decks.get(name, {})
		var total := CollectionData.deck_size(counts)
		var top := _top_archetype_of_counts(counts)
		var top_text := "印はまだ定まらない"
		if not top.is_empty():
			top_text = "%sの印 · %d枚" % [str(Cards.ARCHETYPE_LABELS.get(top.archetype, top.archetype)), int(top.count)]
		var btn := Button.new()
		btn.text = "%s\n%d/%d枚　｜　%s" % [str(name), total, CollectionData.DECK_LIMIT, top_text]
		btn.custom_minimum_size = Vector2(0, 76)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_deck_list_open.bind(str(name)))
		deck_list_container.add_child(btn)


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
	var deck: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	var n := CollectionData.deck_size(deck)
	deck_count_label.text = "%s: %d/%d枚（最低%d枚必要）" % [
		CollectionData.active_deck, n, CollectionData.DECK_LIMIT, CollectionData.MIN_RUN_DECK,
	]
	deck_error_label.text = CollectionData.loadout_error()


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
	for child in card_list_container.get_children():
		child.queue_free()
	for child in deck_contents_container.get_children():
		child.queue_free()
	var deck: Dictionary = CollectionData.decks.get(CollectionData.active_deck, {})
	var owned: Dictionary = CollectionData.owned_card_counts()
	var ids := _filtered_deck_card_ids(owned)
	_sort_deck_card_ids(ids, owned)
	deck_result_count_label.text = "%d/%d件" % [ids.size(), owned.size()]
	_rebuild_deck_contents(deck)
	if ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "条件に一致するカードがありません。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		card_list_container.add_child(empty_label)
		return

	for card_id in ids:
		var def := Cards.get_card(str(card_id))
		var name: String = def.get("name", str(card_id)) if not def.is_empty() else str(card_id)
		var in_deck: int = CollectionData.copies_of_base(deck, str(card_id))
		var owned_count: int = int(owned[card_id])
		var deck_total := CollectionData.deck_size(deck)

		var card_button := Button.new()
		card_button.custom_minimum_size = Vector2(96, 148)
		card_button.clip_contents = true
		card_button.tooltip_text = "%s\n所持 %d / デッキ内 %d" % [name, owned_count, in_deck]
		card_button.disabled = deck_total >= CollectionData.DECK_LIMIT or in_deck >= CollectionData.COPY_LIMIT or in_deck >= owned_count
		card_button.pressed.connect(_on_deck_add_pressed.bind(str(card_id)))

		var card_content := VBoxContainer.new()
		card_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
		card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.clip_contents = true
		card_content.add_theme_constant_override("separation", 3)

		var art := _make_art_thumbnail(
			str(def.get("art", "")),
			str(def.get("archetype", "")),
			str(def.get("rarity", "common")),
			Vector2(80, 110)
		)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var owned_badge := Label.new()
		owned_badge.text = "所持%d" % owned_count
		owned_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
		owned_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(owned_badge)
		if in_deck > 0:
			var deck_badge := Label.new()
			deck_badge.text = "編成%d" % in_deck
			deck_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
			deck_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.add_child(deck_badge)
		card_content.add_child(art)

		var name_label := Label.new()
		name_label.text = name
		name_label.custom_minimum_size = Vector2(0, 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		name_label.max_lines_visible = 2
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(name_label)

		card_button.add_child(card_content)
		card_list_container.add_child(card_button)


func _rebuild_deck_contents(deck: Dictionary) -> void:
	var card_ids: Array = deck.keys()
	card_ids.sort_custom(func(a, b):
		var a_name := str(Cards.get_card(str(a)).get("name", a))
		var b_name := str(Cards.get_card(str(b)).get("name", b))
		return a_name < b_name
	)
	if card_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "カードを左のプールから追加してください。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		deck_contents_container.add_child(empty_label)
		return
	for card_id in card_ids:
		var count := int(deck.get(card_id, 0))
		if count <= 0:
			continue
		var def := Cards.get_card(str(card_id))
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 38)
		row.clip_contents = true
		row.add_theme_constant_override("separation", 4)

		var label := Label.new()
		label.text = "%s  ×%d" % [str(def.get("name", card_id)), count]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.clip_text = true
		row.add_child(label)

		var minus_btn := Button.new()
		minus_btn.text = "−"
		minus_btn.custom_minimum_size = Vector2(36, 32)
		minus_btn.tooltip_text = "デッキから1枚外す"
		minus_btn.pressed.connect(_on_deck_remove_pressed.bind(str(card_id)))
		row.add_child(minus_btn)
		deck_contents_container.add_child(row)


func _on_deck_add_pressed(card_id: String) -> void:
	CollectionData.add_to_deck(card_id)
	_refresh_deck_tab()
	_update_header()


func _on_deck_remove_pressed(card_id: String) -> void:
	CollectionData.remove_from_deck(card_id)
	_refresh_deck_tab()
	_update_header()


## DeckListScreen.tsx の「＋新規デッキ」（nextDeckName()で自動命名→即編集モードへ）
func _on_deck_list_create_pressed() -> void:
	var name := CollectionData.next_deck_name(CollectionData.decks)
	if CollectionData.create_deck(name):
		_deck_mode = "edit"
		_deck_renaming = false
		_refresh_deck_tab()
		_update_header()


## DeckListScreen.tsx の onEditDeck()（デッキタイルクリック→編集モードへ）
func _on_deck_list_open(name: String) -> void:
	CollectionData.set_active_deck(name)
	_deck_mode = "edit"
	_deck_renaming = false
	_refresh_deck_tab()
	_update_header()


## DeckBuilderScreen.tsx の「記録して戻る」（onBack、一覧モードへ）
func _on_deck_back_to_list_pressed() -> void:
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
	_refresh_deck_edit_header()
	_update_header()


func _on_rename_cancel_pressed() -> void:
	_deck_renaming = false
	_refresh_deck_edit_header()


func _on_delete_deck_pressed() -> void:
	CollectionData.delete_deck(CollectionData.active_deck)
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


# ============================================================
# 装備タブ（EquipmentScreen.tsx 相当）
# ============================================================

func _refresh_equipment_tab() -> void:
	_rebuild_equipped_list()
	_refresh_stats_label()
	_rebuild_inventory_list()
	_rebuild_rune_list()


func _rebuild_equipped_list() -> void:
	for child in equipped_list_container.get_children():
		child.queue_free()
	var SLOT_LABEL := {"head": "頭", "chest": "胸", "arms": "腕", "legs": "脚", "feet": "足"}
	for slot in Equipment.EQUIPMENT_SLOTS:
		var inst = GameState.equipped.get(slot)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 58)
		row.add_theme_constant_override("separation", 10)
		if inst != null:
			var equipped_def := Equipment.get_equipment(str(inst.get("def_id", "")))
			row.add_child(_make_art_thumbnail(str(equipped_def.get("art", "")), str(equipped_def.get("archetype", "")), "common", Vector2(50, 50)))
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		if inst != null:
			label.text = "%s: %s（Tier%d）" % [SLOT_LABEL.get(slot, slot), Equipment.equipment_label(inst), int(inst.get("tier", 1))]
		else:
			label.text = "%s: （なし）" % SLOT_LABEL.get(slot, slot)
		row.add_child(label)
		var unequip_btn := Button.new()
		unequip_btn.text = "外す"
		unequip_btn.disabled = inst == null
		unequip_btn.pressed.connect(_on_unequip_pressed.bind(slot))
		row.add_child(unequip_btn)
		equipped_list_container.add_child(row)


func _refresh_stats_label() -> void:
	var stats := Equipment.compute_equipment_stats(GameState.equipped, Callable(CollectionData, "peek_rune"))
	var extras: Array = []
	if stats.get("poisonImmune"):
		extras.append("毒無効")
	if stats.get("blockRetain"):
		extras.append("ブロック持ち越し")
	if stats.get("sanFullRestoreOnStart"):
		extras.append("戦闘開始時正気全快")
	if stats.get("expandedHand"):
		extras.append("手札拡張")
	if stats.get("hpPercentHealOnStart"):
		extras.append("戦闘開始時HP割合回復")
	if stats.get("sacrificeEnergyOnStart"):
		extras.append("戦闘開始時気力供物")
	if stats.get("intangibleOnHit"):
		extras.append("被弾時実体化解除")
	stats_label.text = "防御 %d　筋力 %d　毒耐性 %d　正気耐性 %d　引き +%d　回復/T %d%s" % [
		int(stats.defense), int(stats.strength), int(stats.poisonResist), int(stats.sanResist),
		int(stats.drawBonus), int(stats.healPerTurn),
		("\n" + "・".join(extras)) if extras.size() > 0 else "",
	]


## EquipmentScreen.tsx のジャンル/部位フィルター＋tierソート相当
func _filtered_sorted_equipment() -> Array:
	var out: Array = []
	for inst in CollectionData.inventory.equipment:
		var def := Equipment.get_equipment(str(inst.get("def_id", "")))
		if def.is_empty():
			continue
		var archetype: String = str(def.get("archetype", "generic"))
		if _equip_filter_archetypes.size() > 0 and not _equip_filter_archetypes.has(archetype):
			continue
		var slot: String = str(def.get("slot", ""))
		if _equip_filter_slots.size() > 0 and not _equip_filter_slots.has(slot):
			continue
		out.append(inst)
	out.sort_custom(func(a, b):
		var at: int = int(a.get("tier", 1))
		var bt: int = int(b.get("tier", 1))
		return at < bt if _equip_sort_asc else at > bt
	)
	return out


func _rebuild_inventory_list() -> void:
	for child in inventory_list_container.get_children():
		child.queue_free()
	var filtered := _filtered_sorted_equipment()
	inventory_label.text = "所持装備 %d/%d" % [filtered.size(), CollectionData.inventory.equipment.size()]
	for inst in filtered:
		var def := Equipment.get_equipment(str(inst.get("def_id", "")))
		if def.is_empty():
			continue

		var col := VBoxContainer.new()

		var header := HBoxContainer.new()
		header.custom_minimum_size = Vector2(0, 76)
		header.add_theme_constant_override("separation", 10)
		header.add_child(_make_art_thumbnail(str(def.get("art", "")), str(def.get("archetype", "")), "common", Vector2(62, 62)))
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		label.text = "%s（%s, Tier%d, 威力%.2f）" % [
			Equipment.equipment_label(inst), def.get("slot", ""), int(inst.get("tier", 1)), float(inst.get("power", 1.0)),
		]
		header.add_child(label)
		var equip_btn := Button.new()
		equip_btn.text = "装備"
		equip_btn.pressed.connect(_on_equip_pressed.bind(str(inst.get("uid", ""))))
		header.add_child(equip_btn)
		col.add_child(header)

		var sockets: Array = inst.get("socketed_runes", [])
		for i in range(sockets.size()):
			var socket_row := HBoxContainer.new()
			socket_row.add_theme_constant_override("separation", 6)
			var rune_id = sockets[i]
			var socket_label := Label.new()
			socket_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			socket_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			if rune_id != null:
				var rune: Dictionary = CollectionData.rune_registry.get(rune_id, {})
				socket_label.text = "  ソケット%d: %s(%s)" % [i, rune.get("effect", "?"), str(rune.get("value", "?"))]
				var unsocket_btn := Button.new()
				unsocket_btn.text = "外す"
				unsocket_btn.pressed.connect(_on_unsocket_pressed.bind(str(inst.get("uid", "")), i))
				socket_row.add_child(socket_label)
				socket_row.add_child(unsocket_btn)
			else:
				socket_label.text = "  ソケット%d: 空" % i
				var socket_btn := Button.new()
				socket_btn.text = "ここに装着"
				socket_btn.disabled = _selected_rune_id == ""
				socket_btn.pressed.connect(_on_socket_pressed.bind(str(inst.get("uid", "")), i))
				socket_row.add_child(socket_label)
				socket_row.add_child(socket_btn)
			col.add_child(socket_row)

		inventory_list_container.add_child(col)
		inventory_list_container.add_child(HSeparator.new())


## EquipmentScreen.tsx のルーン検索＋カテゴリフィルター相当
func _filtered_runes() -> Array:
	var query := _rune_search.strip_edges().to_lower()
	var out: Array = []
	for rune in CollectionData.inventory.runes:
		var effect: String = str(rune.get("effect", ""))
		if _rune_category != "" and str(RUNE_CATEGORY_OF_EFFECT.get(effect, "")) != _rune_category:
			continue
		if query != "" and not effect.to_lower().contains(query):
			continue
		out.append(rune)
	return out


func _rebuild_rune_list() -> void:
	for child in rune_list_container.get_children():
		child.queue_free()
	var filtered := _filtered_runes()
	rune_label.text = "所持ルーン（選択してから装備側の「ここに装着」を押す） %d/%d" % [filtered.size(), CollectionData.inventory.runes.size()]
	for rune in filtered:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 48)
		row.add_theme_constant_override("separation", 10)
		var rune_id: String = str(rune.get("id", ""))
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		var mark := "▶ " if rune_id == _selected_rune_id else ""
		label.text = "%s%s（値%s）" % [mark, rune.get("effect", "?"), str(rune.get("value", "?"))]
		row.add_child(label)
		var select_btn := Button.new()
		select_btn.text = "選択解除" if rune_id == _selected_rune_id else "選択"
		select_btn.pressed.connect(_on_select_rune_pressed.bind(rune_id))
		row.add_child(select_btn)
		rune_list_container.add_child(row)


func _on_equip_pressed(equipment_uid: String) -> void:
	GameState.equip_item(equipment_uid)
	_refresh_equipment_tab()


func _on_unequip_pressed(slot: String) -> void:
	GameState.unequip_slot(slot)
	_refresh_equipment_tab()


func _on_select_rune_pressed(rune_id: String) -> void:
	_selected_rune_id = "" if _selected_rune_id == rune_id else rune_id
	_refresh_equipment_tab()


func _on_socket_pressed(equipment_uid: String, socket_index: int) -> void:
	if _selected_rune_id == "":
		return
	if CollectionData.socket_rune_to_equipment(equipment_uid, _selected_rune_id, socket_index):
		_selected_rune_id = ""
		GameState.sync_equipped_from_inventory(equipment_uid)
	_refresh_equipment_tab()


func _on_unsocket_pressed(equipment_uid: String, socket_index: int) -> void:
	if CollectionData.unsocket_rune_from_equipment(equipment_uid, socket_index):
		GameState.sync_equipped_from_inventory(equipment_uid)
	_refresh_equipment_tab()


func _on_equip_filter_archetype_toggled(pressed: bool, value: String) -> void:
	if pressed:
		_equip_filter_archetypes[value] = true
	else:
		_equip_filter_archetypes.erase(value)
	_rebuild_inventory_list()
	equipment_filter_archetype_popover.visible = false


func _on_equip_filter_slot_toggled(pressed: bool, value: String) -> void:
	if pressed:
		_equip_filter_slots[value] = true
	else:
		_equip_filter_slots.erase(value)
	_rebuild_inventory_list()
	equipment_filter_slot_popover.visible = false


## EquipmentScreen.tsx の「tier{sortAsc ? "低い順" : "高い順"}」トグルボタン相当
func _on_equipment_sort_toggle_pressed() -> void:
	_equip_sort_asc = not _equip_sort_asc
	equipment_sort_button.text = "tier低い順" if _equip_sort_asc else "tier高い順"
	_rebuild_inventory_list()


## EquipmentScreen.tsx の「フィルターをリセット」相当
func _on_equipment_filter_reset_pressed() -> void:
	_equip_filter_archetypes.clear()
	_equip_filter_slots.clear()
	_sync_toggle_row(equipment_filter_archetype_row, _equipment_filterable_archetypes(), _equip_filter_archetypes)
	_sync_toggle_row(equipment_filter_slot_row, Equipment.EQUIPMENT_SLOTS, _equip_filter_slots)
	_rebuild_inventory_list()
	equipment_filter_archetype_popover.visible = false
	equipment_filter_slot_popover.visible = false


func _on_rune_search_changed(text: String) -> void:
	_rune_search = text
	_rebuild_rune_list()


func _on_rune_category_toggled(pressed: bool, value: String) -> void:
	if pressed:
		_rune_category = value
		_rebuild_rune_list()
