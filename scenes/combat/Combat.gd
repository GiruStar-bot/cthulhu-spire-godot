extends Control

## CombatView.tsx の操作フローを再現する戦闘コントローラ。
## 手札はドラッグ&ドロップでプレイ（原作 resolveDrop / isAboveHand / pickFoe 相当）。
## HUD/ログは薄いオーバーレイ。ドラッグ中の補助文言・ドロップ枠は出さない。
## ゲームロジック（_play_card / _end_turn 等）は変更しない。

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const RESULT_WIN_DELAY := 0.92
const RESULT_FLEE_DELAY := 0.92
const RESULT_LOSE_DELAY := 0.56
const HAND_ABOVE_MARGIN := 20.0
const CARD_SIZE := Vector2(128, 176)
const INTENT_ATTACK := "res://art/pixel/runes/str.png"
const INTENT_DEFEND := "res://art/pixel/runes/blk.png"
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"

@onready var hud_label: Label = $HudPanel/HudLabel
@onready var log_scroll: ScrollContainer = $LogPanel/LogScroll
@onready var log_label: Label = $LogPanel/LogScroll/LogLabel
@onready var message_label: Label = $MessageLabel
@onready var enemy_row: HBoxContainer = $EnemyRow
@onready var hand_row: HBoxContainer = $HandRow
@onready var hand_tray: Panel = $HandTray
@onready var end_turn_button: Button = $EndTurnButton
@onready var background_art: TextureRect = $BackgroundArt
@onready var floater_layer: Control = $FloaterLayer

var state: Dictionary = {}
var player: Dictionary = {}
var targeting_uid: String = ""
var resolving: bool = false
var _shown_floaters := {}
var _enemy_art_by_uid := {}
var _enemy_hit_by_uid := {}
var _drag_uid: String = ""
var _drag_ghost: CombatCard = null
var _drag_source: CombatCard = null


func _ready() -> void:
	_begin_combat()
	_refresh()


func _input(event: InputEvent) -> void:
	if _drag_uid == "":
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_sync_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()


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
	if _drag_uid == "":
		_refresh_enemies()
		_refresh_hand()
	_show_new_floaters()
	var player_turn: bool = state.get("phase") == "player" and state.get("result") == "ongoing" and not resolving
	end_turn_button.disabled = not player_turn


func _refresh_hud() -> void:
	var line1 := "HP %d/%d　SAN %d/%d　エネルギー %d/%d　ブロック %d" % [
		int(player.hp),
		int(player.maxHp),
		int(player.sanity),
		int(player.maxSanity),
		int(state.get("energy", 0)),
		int(state.get("maxEnergy", 0)),
		int(state.get("block", 0)),
	]
	var bits: PackedStringArray = PackedStringArray()
	var strength: int = int(state.get("strength", 0))
	var weak: int = int(state.get("weak", 0))
	var poison: int = int(state.get("poison", 0))
	if strength > 0:
		bits.append("筋力 %d" % strength)
	if weak > 0:
		bits.append("弱体 %d" % weak)
	if poison > 0:
		bits.append("毒 %d" % poison)
	var sealed = state.get("sealed")
	if sealed:
		bits.append("封印:%s" % ("攻撃" if sealed == "attack" else "技能"))
	for p in state.get("powers", []):
		bits.append(str(CombatLogic.POWER_TEXT.get(p, p)))
	if bits.is_empty():
		hud_label.text = line1
	else:
		hud_label.text = "%s\n%s" % [line1, "　".join(bits)]


func _refresh_log() -> void:
	var log_lines: Array = state.get("log", [])
	var lines: PackedStringArray = PackedStringArray()
	for i in log_lines.size():
		lines.append(str(log_lines[i]))
	log_label.text = "\n".join(lines)
	call_deferred("_scroll_log_to_end")


func _scroll_log_to_end() -> void:
	if log_scroll == null or not is_instance_valid(log_scroll):
		return
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _refresh_enemies() -> void:
	for child in enemy_row.get_children():
		child.queue_free()
	_enemy_art_by_uid.clear()
	_enemy_hit_by_uid.clear()
	for e in state.get("enemies", []):
		var dead: bool = int(e.hp) <= 0
		var def := Enemies.get_enemy(str(e.defId))
		var uid: String = str(e.uid)
		var root := Control.new()
		root.custom_minimum_size = Vector2(236, 320)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.set_meta("enemy_uid", uid)
		root.set_meta("dead", dead)

		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_END
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var intent: Dictionary = {}
		if e.get("shownIntent") is Dictionary:
			intent = e.get("shownIntent") as Dictionary
		elif e.get("intent") is Dictionary:
			intent = e.get("intent") as Dictionary
		col.add_child(_make_intent_row(intent, dead))

		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(220, 210)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture = _load_texture_safe(str(def.get("art", "")))
		if dead:
			art.modulate = Color(0.35, 0.35, 0.35, 0.45)
		col.add_child(art)

		var name_label := Label.new()
		name_label.text = str(def.get("name", e.defId))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color("e9dcc1") if not dead else Color(0.45, 0.42, 0.38))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_label)

		var hp_label := Label.new()
		if dead:
			hp_label.text = "撃破"
		else:
			var block_txt := ""
			if int(e.get("block", 0)) > 0:
				block_txt = "  防 %d" % int(e.block)
			hp_label.text = "HP %d/%d%s" % [int(e.hp), int(e.maxHp), block_txt]
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.add_theme_font_size_override("font_size", 11)
		hp_label.add_theme_color_override("font_color", Color("c4b79a"))
		hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(hp_label)

		root.add_child(col)
		enemy_row.add_child(root)
		_enemy_art_by_uid[uid] = art
		if not dead:
			_enemy_hit_by_uid[uid] = root
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
	if _drag_uid != "":
		return
	for child in hand_row.get_children():
		child.queue_free()
	var player_turn: bool = state.get("phase") == "player" and state.get("result") == "ongoing" and not resolving
	for card in state.get("hand", []):
		var d := Cards.get_card(str(card.defId))
		var playable: bool = player_turn and CombatLogic.can_play(state, card)
		var btn: CombatCard = COMBAT_CARD.new()
		btn.custom_minimum_size = CARD_SIZE
		btn.configure(card, d, playable, str(card.uid) == targeting_uid)
		btn.drag_began.connect(_on_drag_began)
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
		var id: String = str(floater.get("id", ""))
		if id == "" or _shown_floaters.has(id):
			continue
		_shown_floaters[id] = true
		_spawn_floater(floater)


func _spawn_floater(floater: Dictionary) -> void:
	var label := Label.new()
	var kind: String = str(floater.get("kind", "info"))
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
	var start: Vector2 = _floater_position(str(floater.get("who", "player")))
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
	var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
	if art == null:
		return
	var tween := art.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(art, "modulate", Color(1.55, 1.25, 1.25, 1.0), 0.07)
	tween.parallel().tween_property(art, "scale", Vector2(0.96, 1.06), 0.07)
	tween.tween_property(art, "modulate", Color.WHITE, 0.21)
	tween.parallel().tween_property(art, "scale", Vector2.ONE, 0.21)


func _on_drag_began(card_uid: String) -> void:
	if resolving or _drag_uid != "" or state.is_empty():
		return
	if state.get("phase") != "player" or state.get("result") != "ongoing":
		return
	var card = _find_hand(card_uid)
	if card == null:
		return
	if not CombatLogic.can_play(state, card):
		message_label.text = "今は出せない。"
		return
	_drag_uid = card_uid
	_drag_source = null
	for child in hand_row.get_children():
		if child is CombatCard and (child as CombatCard).card_uid == card_uid:
			_drag_source = child
			child.modulate.a = 0.0
			break
	_spawn_ghost(card)
	_sync_drag()


func _spawn_ghost(card) -> void:
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	var definition: Dictionary = Cards.get_card(str(card.defId))
	var ghost: CombatCard = COMBAT_CARD.new()
	ghost.custom_minimum_size = CARD_SIZE
	ghost.size = CARD_SIZE
	ghost.configure(card, definition, true, false)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 120
	ghost.scale = Vector2(1.06, 1.06)
	floater_layer.add_child(ghost)
	_drag_ghost = ghost


func _sync_drag() -> void:
	if _drag_uid == "":
		return
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		var mouse := get_global_mouse_position()
		_drag_ghost.global_position = mouse - (_drag_ghost.size * 0.5)


func _finish_drag() -> void:
	if _drag_uid == "":
		return
	var card_uid: String = _drag_uid
	var pos := get_global_mouse_position()
	var drop: Dictionary = _resolve_drop(card_uid, pos)
	_clear_drag()
	var ok: bool = drop.get("ok") and true
	if not ok:
		return
	_play_card(card_uid, drop.get("target_id"))


func _clear_drag() -> void:
	if _drag_source != null and is_instance_valid(_drag_source):
		_drag_source.modulate.a = 1.0
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null
	_drag_source = null
	_drag_uid = ""


func _resolve_drop(card_uid: String, pos: Vector2) -> Dictionary:
	var fail := {"ok": false, "target_id": null}
	var card = _find_hand(card_uid)
	if card == null:
		return fail
	var definition: Dictionary = Cards.get_card(str(card.defId))
	if not _is_above_hand(pos):
		return fail
	var target_kind: String = str(definition.get("target", "none"))
	if target_kind != "enemy":
		return {"ok": true, "target_id": null}
	var living: Array = CombatLogic.living(state)
	var foe_uid: String = _pick_foe(pos)
	if foe_uid != "":
		return {"ok": true, "target_id": foe_uid}
	if living.size() == 1:
		return {"ok": true, "target_id": str(living[0].uid)}
	return fail


func _is_above_hand(pos: Vector2) -> bool:
	var tray: Rect2 = hand_tray.get_global_rect()
	return pos.y < tray.position.y - HAND_ABOVE_MARGIN


func _pick_foe(pos: Vector2) -> String:
	for uid in _enemy_hit_by_uid:
		var node: Control = _enemy_hit_by_uid[uid]
		if node == null or not is_instance_valid(node):
			continue
		if node.get_meta("dead", false):
			continue
		if node.get_global_rect().has_point(pos):
			return str(uid)
	return ""


func _make_intent_row(intent: Dictionary, dead: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dead:
		return row
	var kind: String = str(intent.get("kind", "unknown"))
	var damage: int = int(intent.get("damage", 0))
	var block: int = int(intent.get("block", 0))
	if kind == "attack" or damage > 0:
		row.add_child(_intent_icon(INTENT_ATTACK))
		if damage > 0:
			row.add_child(_intent_value(str(damage), Color("ff6b61")))
		var hits: int = int(intent.get("hits", 1))
		if hits > 1:
			row.add_child(_intent_value("x%d" % hits, Color("ff6b61")))
	elif kind == "defend" or block > 0:
		row.add_child(_intent_icon(INTENT_DEFEND))
		if block > 0:
			row.add_child(_intent_value(str(block), Color("75c7df")))
	else:
		var unknown := Label.new()
		unknown.text = "?"
		unknown.add_theme_font_size_override("font_size", 22)
		unknown.add_theme_color_override("font_color", Color("d4a84b"))
		unknown.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.95))
		unknown.add_theme_constant_override("outline_size", 4)
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(unknown)
	return row


func _intent_icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _load_texture_safe(path)
	return icon


func _intent_value(text: String, tone: Color) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", tone)
	value.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.95))
	value.add_theme_constant_override("outline_size", 4)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return value


func _load_texture_safe(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return load(FALLBACK_TEX) as Texture2D
	var resource: Resource = ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return load(FALLBACK_TEX) as Texture2D
