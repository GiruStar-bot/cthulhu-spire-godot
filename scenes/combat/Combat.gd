extends Control

## CombatView.tsx の操作フローを簡易UIで再現する戦闘コントローラ。
## 見た目（扇状手札・ドラッグドロップ）は後続。ここでは
## 手札クリック → playCard →（必要なら対象選択）→ ターン終了 → endTurn のループと
## presentCombat() 相当の勝敗遷移だけを実装する。

const PIXEL_BUTTON := preload("res://scenes/ui/PixelButton.tscn")
const RESULT_WIN_DELAY := 0.92
const RESULT_FLEE_DELAY := 0.92
const RESULT_LOSE_DELAY := 0.56

@onready var hud_label: Label = $HudPanel/HudLabel
@onready var log_label: Label = $LogPanel/LogLabel
@onready var message_label: Label = $MessageLabel
@onready var enemy_row: HBoxContainer = $EnemyRow
@onready var hand_row: HBoxContainer = $HandRow
@onready var end_turn_button: Button = $EndTurnButton
@onready var background_art: TextureRect = $BackgroundArt

var state: Dictionary = {}
var player: Dictionary = {}
var targeting_uid: String = ""
var resolving: bool = false


func _ready() -> void:
	_begin_combat()
	_refresh()


func _begin_combat() -> void:
	var meta: Dictionary = GameState.combat if GameState.combat else {}
	var kind: String = str(meta.get("kind", "combat"))
	var floor: int = int(meta.get("floor", GameState.floor))
	var rand := Callable(GameState, "_rand")
	var enemy_ids: Array = meta.get("enemy_ids", [])
	if enemy_ids.is_empty():
		enemy_ids = CombatLogic.encounter_ids(kind, floor, rand)
	var deck: Array = []
	for card in GameState.deck:
		var def := Cards.get_card(str(card.get("defId", "")))
		if def.get("type") != "status":
			deck.append(card)
	if deck.is_empty():
		deck = GameState.loadout_deck()
	player = GameState.player_hook()
	state = CombatLogic.start_combat(deck, enemy_ids, player, floor, rand)
	GameState.combat = state
	GameState.extra_energy_next = 0
	GameState.apply_player_hook(player)
	_apply_biome_art(enemy_ids)
	message_label.text = "%s　%s" % [Floors.layer_label(floor), Floors.floor_kind_label(kind, floor)]


func _apply_biome_art(enemy_ids: Array) -> void:
	if enemy_ids.is_empty():
		return
	var def := Enemies.get_enemy(str(enemy_ids[0]))
	var biome: String = str(def.get("biome", "reef"))
	var path := "res://art/pixel/bg/%s.jpg" % biome
	if ResourceLoader.exists(path):
		background_art.texture = load(path)


func _on_end_turn_pressed() -> void:
	if resolving or state.is_empty():
		return
	if state.get("phase") != "player" or state.get("result") != "ongoing":
		return
	_end_turn()


func _play_card(card_uid: String, target_id) -> void:
	if resolving or state.get("phase") != "player" or state.get("result") != "ongoing":
		return
	var played: Dictionary = CombatLogic.play_card(state, player, card_uid, target_id, Callable(GameState, "_rand"))
	if played.get("error"):
		message_label.text = str(played.error)
		return
	targeting_uid = ""
	GameState.apply_player_hook(player)
	_refresh()
	if state.get("forceEnd") and state.get("result") == "ongoing":
		_end_turn()
		return
	_check_result()


func _end_turn() -> void:
	targeting_uid = ""
	CombatLogic.end_turn(state, player, Callable(GameState, "_rand"))
	GameState.apply_player_hook(player)
	_refresh()
	_check_result()


func _on_hand_pressed(card_uid: String) -> void:
	if resolving:
		return
	var card = _find_hand(card_uid)
	if card == null:
		return
	if not CombatLogic.can_play(state, card):
		message_label.text = "今は出せない。"
		return
	var d := Cards.get_card(str(card.defId))
	var live := CombatLogic.living(state)
	if d.get("target") == "enemy" and live.size() > 1:
		targeting_uid = card_uid
		message_label.text = "対象の敵を選んでください。"
		_refresh()
		return
	var target_id = live[0].uid if (d.get("target") == "enemy" and live.size() == 1) else null
	_play_card(card_uid, target_id)


func _on_enemy_pressed(enemy_uid: String) -> void:
	if resolving:
		return
	if targeting_uid == "":
		return
	_play_card(targeting_uid, enemy_uid)


func _find_hand(card_uid: String):
	for card in state.get("hand", []):
		if str(card.uid) == card_uid:
			return card
	return null


func _check_result() -> void:
	var result: String = str(state.get("result", "ongoing"))
	if result == "ongoing" or resolving:
		return
	resolving = true
	end_turn_button.disabled = true
	if result == "win":
		message_label.text = "回廊は、しばらく静かだ。"
		get_tree().create_timer(RESULT_WIN_DELAY).timeout.connect(func(): GameState.win_combat(get_tree()))
	elif result == "fled":
		message_label.text = "敵が逃げ去った。"
		get_tree().create_timer(RESULT_FLEE_DELAY).timeout.connect(func(): GameState.resolve_flee(get_tree()))
	else:
		message_label.text = "肉体が、折れた。" if int(player.hp) <= 0 else "正気が、0になった。"
		get_tree().create_timer(RESULT_LOSE_DELAY).timeout.connect(func(): GameState.lose_combat(get_tree()))


func _refresh() -> void:
	if state.is_empty():
		return
	_refresh_hud()
	_refresh_log()
	_refresh_enemies()
	_refresh_hand()
	var player_turn: bool = state.get("phase") == "player" and state.get("result") == "ongoing" and not resolving
	end_turn_button.disabled = not player_turn


func _refresh_hud() -> void:
	var sealed = state.get("sealed")
	var sealed_txt := ""
	if sealed:
		sealed_txt = "　封印:%s" % ("攻撃" if sealed == "attack" else "技能")
	var powers_txt := ""
	for p in state.get("powers", []):
		powers_txt += "\n%s" % CombatLogic.POWER_TEXT.get(p, p)
	hud_label.text = "HP %d/%d　SAN %d/%d\nエネルギー %d/%d　ブロック %d\n筋力 %d　弱体 %d　毒 %d%s%s" % [
		int(player.hp),
		int(player.maxHp),
		int(player.sanity),
		int(player.maxSanity),
		int(state.get("energy", 0)),
		int(state.get("maxEnergy", 0)),
		int(state.get("block", 0)),
		int(state.get("strength", 0)),
		int(state.get("weak", 0)),
		int(state.get("poison", 0)),
		sealed_txt,
		powers_txt,
	]


func _refresh_log() -> void:
	var log: Array = state.get("log", [])
	var start: int = maxi(0, log.size() - 6)
	var lines: PackedStringArray = PackedStringArray()
	for i in range(start, log.size()):
		lines.append(str(log[i]))
	log_label.text = "\n".join(lines)


func _refresh_enemies() -> void:
	for child in enemy_row.get_children():
		child.queue_free()
	for e in state.get("enemies", []):
		var dead: bool = int(e.hp) <= 0
		var def := Enemies.get_enemy(str(e.defId))
		var wrap := VBoxContainer.new()
		wrap.custom_minimum_size = Vector2(180, 220)
		wrap.alignment = BoxContainer.ALIGNMENT_END
		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(160, 140)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var art_path: String = str(def.get("art", ""))
		if art_path != "" and ResourceLoader.exists(art_path):
			art.texture = load(art_path)
		if dead:
			art.modulate = Color(0.35, 0.35, 0.35, 0.45)
		wrap.add_child(art)
		var intent: Dictionary = e.get("shownIntent", e.get("intent", {}))
		var btn := PIXEL_BUTTON.instantiate()
		btn.text = _enemy_label(def, e, intent, dead)
		btn.disabled = dead or targeting_uid == "" or resolving
		var uid: String = str(e.uid)
		btn.pressed.connect(_on_enemy_pressed.bind(uid))
		wrap.add_child(btn)
		enemy_row.add_child(wrap)


func _enemy_label(def: Dictionary, e: Dictionary, intent: Dictionary, dead: bool) -> String:
	if dead:
		return "%s\n撃破" % def.get("name", e.defId)
	var kind: String = str(intent.get("kind", "unknown"))
	var intent_txt := kind
	if intent.get("damage"):
		intent_txt = "攻撃 %d" % int(intent.damage)
	elif intent.get("block"):
		intent_txt = "防御 %d" % int(intent.block)
	return "%s\nHP %d/%d\n%s" % [def.get("name", e.defId), int(e.hp), int(e.maxHp), intent_txt]


func _refresh_hand() -> void:
	for child in hand_row.get_children():
		child.queue_free()
	var player_turn: bool = state.get("phase") == "player" and state.get("result") == "ongoing" and not resolving
	for card in state.get("hand", []):
		var d := Cards.get_card(str(card.defId))
		var playable: bool = player_turn and CombatLogic.can_play(state, card)
		var btn := PIXEL_BUTTON.instantiate()
		var cost: int = Cards.card_cost(card)
		var mark := "◆" if str(card.uid) == targeting_uid else ""
		btn.text = "%s%s\n%dE  %s" % [mark, d.get("name", card.defId), cost, d.get("text", "")]
		btn.custom_minimum_size = Vector2(128, 160)
		btn.disabled = not playable
		var uid: String = str(card.uid)
		btn.pressed.connect(_on_hand_pressed.bind(uid))
		hand_row.add_child(btn)
