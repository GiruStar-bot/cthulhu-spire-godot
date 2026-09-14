extends Control

## CombatView.tsx の操作フローを簡易UIで再現する戦闘コントローラ。
## 見た目（扇状手札・ドラッグドロップ）は後続。ここでは
## 手札クリック → playCard →（必要なら対象選択）→ ターン終了 → endTurn のループと
## presentCombat() 相当の勝敗遷移だけを実装する。

const PIXEL_BUTTON := preload("res://scenes/ui/PixelButton.tscn")
const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
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
@onready var floater_layer: Control = $FloaterLayer

var state: Dictionary = {}
var player: Dictionary = {}
var targeting_uid: String = ""
var resolving: bool = false
var _shown_floaters := {}
var _enemy_art_by_uid := {}


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
	var selected_card = _find_hand(card_uid)
	var card_type := str(Cards.get_card(str(selected_card.defId)).get("type", "skill")) if selected_card else "skill"
	var played: Dictionary = CombatLogic.play_card(state, player, card_uid, target_id, Callable(GameState, "_rand"))
	if played.get("error"):
		message_label.text = str(played.error)
		return
	AudioManager.play_sfx("attack" if card_type == "attack" else "skill")
	targeting_uid = ""
	GameState.apply_player_hook(player)
	_refresh()
	if state.get("forceEnd") and state.get("result") == "ongoing":
		_end_turn()
		return
	_check_result()


func _end_turn() -> void:
	targeting_uid = ""
	AudioManager.play_sfx("step")
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
		AudioManager.play_sfx("win")
		message_label.text = "回廊は、しばらく静かだ。"
		get_tree().create_timer(RESULT_WIN_DELAY).timeout.connect(func(): GameState.win_combat(get_tree()))
	elif result == "fled":
		message_label.text = "敵が逃げ去った。"
		get_tree().create_timer(RESULT_FLEE_DELAY).timeout.connect(func(): GameState.resolve_flee(get_tree()))
	else:
		AudioManager.play_sfx("lose")
		message_label.text = "肉体が、折れた。" if int(player.hp) <= 0 else "正気が、0になった。"
		get_tree().create_timer(RESULT_LOSE_DELAY).timeout.connect(func(): GameState.lose_combat(get_tree()))


func _refresh() -> void:
	if state.is_empty():
		return
	_refresh_hud()
	_refresh_log()
	_refresh_enemies()
	_refresh_hand()
	_show_new_floaters()
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
	var log_lines: Array = state.get("log", [])
	var start: int = maxi(0, log_lines.size() - 6)
	var lines: PackedStringArray = PackedStringArray()
	for i in range(start, log_lines.size()):
		lines.append(str(log_lines[i]))
	log_label.text = "\n".join(lines)


func _refresh_enemies() -> void:
	for child in enemy_row.get_children():
		child.queue_free()
	_enemy_art_by_uid.clear()
	for e in state.get("enemies", []):
		var dead: bool = int(e.hp) <= 0
		var def := Enemies.get_enemy(str(e.defId))
		var enemy_wrap := VBoxContainer.new()
		enemy_wrap.custom_minimum_size = Vector2(180, 220)
		enemy_wrap.alignment = BoxContainer.ALIGNMENT_END
		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(160, 140)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var art_path: String = str(def.get("art", ""))
		if art_path != "" and ResourceLoader.exists(art_path):
			art.texture = load(art_path)
		if dead:
			art.modulate = Color(0.35, 0.35, 0.35, 0.45)
		enemy_wrap.add_child(art)
		var intent: Dictionary = e.get("shownIntent", e.get("intent", {}))
		var btn := PIXEL_BUTTON.instantiate()
		btn.text = _enemy_label(def, e, intent, dead)
		btn.disabled = dead or targeting_uid == "" or resolving
		var uid: String = str(e.uid)
		_enemy_art_by_uid[uid] = art
		btn.pressed.connect(_on_enemy_pressed.bind(uid))
		enemy_wrap.add_child(btn)
		enemy_row.add_child(enemy_wrap)
		if not dead:
			_start_enemy_idle(art)


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
		var btn: CombatCard = COMBAT_CARD.new()
		btn.custom_minimum_size = Vector2(128, 176)
		btn.configure(card, d, playable, str(card.uid) == targeting_uid)
		var uid: String = str(card.uid)
		btn.pressed.connect(_on_hand_pressed.bind(uid))
		hand_row.add_child(btn)


func _start_enemy_idle(art: TextureRect) -> void:
	art.pivot_offset = art.custom_minimum_size * 0.5
	var tween := art.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(art, "scale", Vector2(1.03, 1.03), 1.25)
	tween.parallel().tween_property(art, "position:y", -6.0, 1.25)
	tween.tween_property(art, "scale", Vector2.ONE, 1.25)
	tween.parallel().tween_property(art, "position:y", 0.0, 1.25)


func _show_new_floaters() -> void:
	for floater in state.get("floaters", []):
		var id := str(floater.get("id", ""))
		if id == "" or _shown_floaters.has(id):
			continue
		_shown_floaters[id] = true
		_spawn_floater(floater)


func _spawn_floater(floater: Dictionary) -> void:
	var label := Label.new()
	var kind := str(floater.get("kind", "info"))
	label.text = str(floater.get("text", ""))
	label.size = Vector2(110, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_color", _floater_color(kind))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 100
	var start := _floater_position(str(floater.get("who", "player")))
	label.position = start - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.72, 0.72)
	floater_layer.add_child(label)
	var rise := label.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	rise.tween_property(label, "position:y", label.position.y - 8.0, 0.126)
	rise.tween_property(label, "position:y", label.position.y - 36.0, 0.574)
	var scale_tween := label.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.126)
	scale_tween.tween_property(label, "scale", Vector2.ONE, 0.574)
	var fade := label.create_tween()
	fade.tween_interval(0.126)
	fade.tween_property(label, "modulate:a", 0.0, 0.574)
	fade.tween_callback(label.queue_free)
	if kind == "dmg" and str(floater.get("who", "")) != "player":
		_animate_enemy_hit(str(floater.get("who", "")))


func _floater_color(kind: String) -> Color:
	match kind:
		"dmg": return Color("ff6b61")
		"heal": return Color("90d99d")
		"block": return Color("75c7df")
		"sanity": return Color("77ddd5")
		_: return Color("f0d58b")


func _floater_position(who: String) -> Vector2:
	if who == "player":
		return Vector2(size.x * 0.28, size.y * 0.67)
	var enemies: Array = state.get("enemies", [])
	for index in enemies.size():
		if str(enemies[index].get("uid", "")) == who:
			var ratio := (float(index) + 1.0) / (float(enemies.size()) + 1.0)
			return Vector2(lerpf(size.x * 0.31, size.x * 0.69, ratio), size.y * 0.42)
	return Vector2(size.x * 0.5, size.y * 0.42)


func _animate_enemy_hit(uid: String) -> void:
	var art := _enemy_art_by_uid.get(uid) as TextureRect
	if art == null:
		return
	var tween := art.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(art, "modulate", Color(1.55, 1.25, 1.25, 1.0), 0.07)
	tween.parallel().tween_property(art, "scale", Vector2(0.96, 1.06), 0.07)
	tween.tween_property(art, "modulate", Color.WHITE, 0.21)
	tween.parallel().tween_property(art, "scale", Vector2.ONE, 0.21)
