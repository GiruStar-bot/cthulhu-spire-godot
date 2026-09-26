extends Control

## CombatView.tsx の操作フローを再現する戦闘コントローラ。
## 手札はドラッグ&ドロップでプレイ（原作 resolveDrop / isAboveHand / pickFoe 相当）。
## HUD/ログは原作の石枠パネル。敵は全身＋右に使用カードとステータスパネル。
## ゲームロジック（_play_card / _end_turn 等）は変更しない。

const COMBAT_CARD := preload("res://scenes/combat/CombatCard.gd")
const PIXEL_BUTTON := preload("res://scenes/ui/PixelButton.tscn")
## 山札・捨て札ボタンの描画順。HudPanel/LogPanel（z=30）と揃え、敵の立ち絵（EnemyRow z=1）より手前に出す
const PILE_BUTTON_Z := 30
const DISSOLVE_SHADER := preload("res://scenes/combat/enemy_dissolve.gdshader")
const DISSOLVE_NOISE := preload("res://art/pixel/ui/dissolve_noise.png")
const SHOCK_CARDS := ["migo_gun"]
const SHOCK_CORE := Color(0.70, 0.95, 0.28, 0.95)
const SHOCK_GLOW := Color(0.48, 0.12, 0.62, 0.38)
const SHOCK_SPARK := Color(0.78, 0.42, 0.95, 1.0)
const FX_IMPACT := preload("res://art/pixel/fx/fx_impact.png")
const FX_SLASH := preload("res://art/pixel/fx/fx_slash.png")
const FX_ARROW := preload("res://art/pixel/fx/fx_arrow.png")
const RESULT_WIN_DELAY := 0.92
const RESULT_FLEE_DELAY := 0.92
const RESULT_LOSE_DELAY := 0.56
const HAND_ABOVE_MARGIN := 20.0
const DRAW_IN_DURATION := 0.35
const DRAW_IN_STAGGER := 0.04
const DRAW_IN_STAGGER_CAP := 8
const DRAW_IN_SCALE := 0.42
const DRAW_IN_ROT_OFFSET := -16.0
const CARD_SIZE := Vector2(128, 192)
const PREVIEW_CARD_SIZE := Vector2(112, 160)
const PREVIEW_CARD_SIZE_DUAL := Vector2(76, 114)
const FALLBACK_TEX := "res://art/pixel/ui/card_back.png"
const ENEMY_PLATE_W := 176.0
const ENEMY_PLATE_W_DUAL := 148.0
const ENEMY_PLATE_GAP := 8.0
const ENEMY_CUTOUT_W := 688.0
const ENEMY_CUTOUT_H := 608.0
const ENEMY_CUTOUT_W_DUAL := 640.0
const ENEMY_BOSS_W := 816.0
const ENEMY_BOSS_H := 688.0
const ENEMY_GROUND_SINGLE := 0.20
const ENEMY_GROUND_DUAL := 0.14
const ENEMY_BOSS_HP := 150
const PX_IDLE_STEP := 0.5
const PX_CAST_STAGGER := 0.2
const PX_CAST_HOLDS: Array = [0.10, 0.18, 0.22, 0.20, 0.16, 0.26]

@onready var hud_panel: VitalsHud = $HudPanel
@onready var hud_label: Label = $HudPanel/HudLabel
@onready var log_scroll: ScrollContainer = $LogPanel/LogScroll
@onready var log_label: Label = $LogPanel/LogScroll/LogLabel
@onready var log_panel: Panel = $LogPanel
@onready var message_label: Label = $MessageLabel
@onready var enemy_row: Control = $EnemyRow
@onready var hand_row: Control = $HandRow
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
var _draw_btn: Button
var _discard_btn: Button
var _chrome_ready: bool = false
var _death_fx_done: Dictionary = {}
var _hit_tweens: Dictionary = {}
var _float_tweens: Dictionary = {}
var _px_idle_tweens: Dictionary = {}
var _px_cast_tweens: Dictionary = {}
var _prev_hp: int = -1
var _prev_sanity: int = -1
var _prev_block: int = -1
var _fx_canvas: CanvasLayer
## 正気度の演出（払った／削られた／低い状態）。旧 _fx_vertigo（全画面ぼかし・歪み）の置き換え。
var _sanity_fx: SanityFx
## 直前にプレイしたカードの画面位置（雫の出発点）。不明なら手札の中央。
var _sanity_drop_from: Vector2 = Vector2(-1.0, -1.0)
var _shield: Polygon2D
var _shield_tween: Tween
var _hurt_flash: ColorRect
var _hurt_tween: Tween
var _vfx_layer: Node2D
var _draw_in_tweens: Dictionary = {}


func _ready() -> void:
	_build_chrome()
	_ensure_sanity_fx()
	if log_scroll:
		log_scroll.resized.connect(_fit_log_label)
	if enemy_row and not enemy_row.resized.is_connected(_layout_enemies):
		enemy_row.resized.connect(_layout_enemies)
	if hand_row and not hand_row.resized.is_connected(_layout_fan):
		hand_row.resized.connect(_layout_fan)
	VideoSettings.get_instance().changed.connect(_on_px_reduce_motion)
	_begin_combat()
	_refresh()
	call_deferred("_fit_log_label")
	call_deferred("_layout_enemies")


func _exit_tree() -> void:
	var settings: VideoSettings = VideoSettings.get_instance()
	if settings.changed.is_connected(_on_px_reduce_motion):
		settings.changed.disconnect(_on_px_reduce_motion)


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
		enemy_ids = CombatLogic.encounter_ids(kind, floor, rand, GameState.encounter_bias)
	var deck: Array = []
	GameState.prune_run_deck()
	for card in GameState.deck:
		var def: Dictionary = Cards.get_card(str(card.get("defId", "")))
		if def.get("type") != "status":
			deck.append(card)
	if deck.is_empty():
		deck = GameState.loadout_deck()
	## アイホートくんの呪い：この戦闘だけ、デッキを同じ枚数の「百目の子」に置き換える。
	## 状態カードの除外より後で差し替える（ランのデッキ GameState.deck は書き換えない）。
	var eihort_cursed: bool = GameState.consume_eihort_curse(floor)
	if eihort_cursed:
		var cursed_deck: Array = []
		for i in deck.size():
			cursed_deck.append(Cards.make_card("hundred_eyed_child"))
		deck = cursed_deck
	player = GameState.player_hook()
	state = CombatLogic.start_combat(deck, enemy_ids, player, floor, rand)
	if eihort_cursed:
		state.log.append("無数の赤い瞳が、手札から見返している。")
	GameState.combat = state
	GameState.extra_energy_next = 0
	GameState.apply_player_hook(player)
	_apply_biome_art(enemy_ids)
	message_label.text = ""
	_prev_hp = int(player.hp)
	_prev_sanity = int(player.sanity)
	_prev_block = int(state.get("block", 0))


func _apply_biome_art(enemy_ids: Array) -> void:
	var biome_id: String = Biomes.biome_for_encounter(enemy_ids, int(GameState.floor))
	var path: String = Biomes.biome_art(biome_id)
	if FileAccess.file_exists(path):
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
	_sanity_drop_from = _hand_card_center(card_uid)
	var played: Dictionary = CombatLogic.play_card(state, player, card_uid, target_id, Callable(GameState, "_rand"))
	if played.get("error"):
		message_label.text = str(played.error)
		return
	var def_id: String = ""
	if selected_card != null:
		def_id = str(selected_card.get("defId", ""))
	var hp_before: int = int(player.hp)
	var definition: Dictionary = Cards.get_card(def_id) if def_id != "" else {}
	var vfx_kind: String = str(definition.get("vfx", "impact"))
	# カード固有 SFX（ねこの手・電撃銃など）を優先。なければ vfx / skill
	AudioManager.play_sfx(AudioManager.resolve_card_sfx(def_id, card_type, vfx_kind))
	targeting_uid = ""
	var hand_before: int = int(state.hand.size()) if state.get("hand") else 0
	GameState.apply_player_hook(player)
	_refresh()
	_play_draw_sfx(hand_before)
	# 自傷（hpCost 等）は敵被弾と別キュー
	if int(player.hp) < hp_before:
		AudioManager.play_sfx("hurt_self")
	if SHOCK_CARDS.has(def_id):
		_fx_shock_living()
	_fx_card_vfx(def_id, target_id)
	if state.get("forceEnd") and state.get("result") == "ongoing":
		_end_turn()
		return
	_check_result()


func _end_turn() -> void:
	targeting_uid = ""
	AudioManager.play_sfx("step")
	var hp_before: int = int(player.hp)
	var hand_before: int = int(state.hand.size()) if state.get("hand") else 0
	var alive_before: Array = []
	for foe in CombatLogic.living(state):
		alive_before.append(str(foe.get("uid", "")))
	var turn_sfx: Array = CombatLogic.end_turn(state, player, Callable(GameState, "_rand"))
	GameState.apply_player_hook(player)
	if state.get("eihortCursed", false):
		state.erase("eihortCursed")
		GameState.apply_eihort_curse()
	_refresh()
	_play_enemy_card_motions(alive_before)
	AudioManager.play_cues(turn_sfx)
	_play_draw_sfx(hand_before)
	# 毒・冷気など、敵ヒット以外のHP減
	var had_enemy_hit := "hurt_from_enemy" in turn_sfx or "hurt" in turn_sfx
	if int(player.hp) < hp_before and not had_enemy_hit:
		AudioManager.play_sfx("hurt_self")
	_check_result()



func _play_draw_sfx(hand_before: int) -> void:
	var hand_now: int = int(state.hand.size()) if state.get("hand") else 0
	var gained: int = hand_now - hand_before
	if gained <= 0:
		return
	for _i in range(gained):
		AudioManager.play_sfx("paper_draw")
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
	## 戦闘が終わったら（敗北演出の開始を含む）持続音と四隅の縁取りを止める
	if _sanity_fx != null and is_instance_valid(_sanity_fx):
		_sanity_fx.stop_all()
	GameState.prune_run_deck()
	if result == "win":
		if GameState.note_boss_status_point(state):
			_refresh()
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
	_run_player_hit_fx()
	var player_turn: bool = state.get("phase") == "player" and state.get("result") == "ongoing" and not resolving
	end_turn_button.disabled = not player_turn


func _refresh_hud() -> void:
	if not _chrome_ready:
		_build_chrome()
	var pname: String = GameState.player_name
	var current_floor: int = int(GameState.floor)
	var floor_text: String = "%s · %s · %s" % [Floors.floor_band(current_floor), Floors.layer_label(current_floor), Floors.floor_kind_label(str(GameState.floor_kind), current_floor)]
	var sealed_raw = state.get("sealed")
	hud_panel.bind({
		"player_name": pname,
		"floor_text": floor_text,
		"hp": int(player.hp),
		"max_hp": int(player.maxHp),
		"sanity": int(player.sanity),
		"max_sanity": int(player.maxSanity),
		"energy": int(state.get("energy", 0)),
		"max_energy": int(state.get("maxEnergy", 0)),
		"block": CombatLogic.displayed_block(state),
		"strength": int(state.get("strength", 0)),
		"weak": int(state.get("weak", 0)),
		"poison": int(state.get("poison", 0)),
		"cold": int(state.get("cold", 0)),
		"sealed": sealed_raw,
		"powers": state.get("powers", []),
		"shells": GameState.shells,
		"show_header": true,
		"show_energy": true,
		"show_status": true,
		"show_shells": true,
	})
	if _draw_btn:
		_draw_btn.text = "山札: %d" % int((state.get("draw", []) as Array).size())
	if _discard_btn:
		_discard_btn.text = "捨て札: %d" % int((state.get("discard", []) as Array).size())
	hud_label.visible = false


func _refresh_log() -> void:
	var log_lines: Array = state.get("log", [])
	var recent: Array = log_lines.slice(maxi(0, log_lines.size() - 5), log_lines.size())
	var lines: PackedStringArray = PackedStringArray()
	for i in recent.size():
		lines.append(str(recent[i]))
	if lines.is_empty():
		log_label.text = "まだ記録がない。"
	else:
		log_label.text = "\n".join(lines)
	_fit_log_label()
	call_deferred("_scroll_log_to_end")


func _fit_log_label() -> void:
	if log_label == null or log_scroll == null or not is_instance_valid(log_label):
		return
	var w: float = maxf(8.0, log_scroll.size.x)
	log_label.custom_minimum_size.x = w
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _scroll_log_to_end() -> void:
	if log_scroll == null or not is_instance_valid(log_scroll):
		return
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _refresh_enemies() -> void:
	var living: int = 0
	for e in state.get("enemies", []):
		if int(e.hp) > 0:
			living += 1
	var dual: bool = living >= 2
	var seen: Dictionary = {}
	for e in state.get("enemies", []):
		var uid: String = str(e.uid)
		var dead: bool = int(e.hp) <= 0
		seen[uid] = true
		if dead and str(_death_fx_done.get(uid, "")) == "gone":
			var leftover: Control = _find_enemy_stage(uid)
			if leftover != null:
				leftover.queue_free()
			_enemy_art_by_uid.erase(uid)
			_enemy_hit_by_uid.erase(uid)
			continue
		if dead and str(_death_fx_done.get(uid, "")) == "playing":
			if _find_enemy_stage(uid) == null:
				continue
		var stage: Control = _find_enemy_stage(uid)
		if stage == null:
			stage = _spawn_enemy_stage(e, dead, dual)
			enemy_row.add_child(stage)
		if stage.get_meta("dissolving", false):
			continue
		_sync_enemy_stage(stage, e, dead, dual)
	for child in enemy_row.get_children():
		if child.is_queued_for_deletion():
			continue
		var uid: String = str(child.get_meta("enemy_uid", ""))
		if uid != "" and not seen.has(uid):
			child.queue_free()
			_enemy_art_by_uid.erase(uid)
			_enemy_hit_by_uid.erase(uid)
			_kill_px_idle(uid)
			_kill_px_cast(uid)
	if enemy_row.size.x >= 16.0 and enemy_row.size.y >= 16.0:
		_layout_enemies()
	else:
		call_deferred("_layout_enemies")


func _find_enemy_stage(uid: String) -> Control:
	for child in enemy_row.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Control and str(child.get_meta("enemy_uid", "")) == uid:
			return child as Control
	return null


func _spawn_enemy_stage(e: Dictionary, dead: bool, dual: bool = false) -> Control:
	var def: Dictionary = Enemies.get_enemy(str(e.defId))
	var uid: String = str(e.uid)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = false
	stage.set_meta("enemy_uid", uid)
	stage.set_meta("dead", dead)
	stage.set_meta("max_hp", int(e.maxHp))
	stage.set_meta("boss", int(e.maxHp) >= ENEMY_BOSS_HP)
	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_enemy_portrait(art, def)
	art.set_meta("dead", dead)
	stage.add_child(art)
	_enemy_art_by_uid[uid] = art
	if def.get("floats", false) and not dead:
		_start_enemy_float(uid, art)
	if not dead:
		var plate: VBoxContainer = _make_enemy_plate(e, def, dual)
		plate.name = "Plate"
		plate.z_index = 12
		stage.add_child(plate)
		_enemy_hit_by_uid[uid] = art
		if art.get_meta("px_sprite", false):
			_start_px_idle(uid, art)
	return stage


func _sync_enemy_stage(stage: Control, e: Dictionary, dead: bool, dual: bool = false) -> void:
	var uid: String = str(e.uid)
	var def: Dictionary = Enemies.get_enemy(str(e.defId))
	var art: TextureRect = stage.get_node_or_null("Art") as TextureRect
	stage.set_meta("dead", dead)
	stage.set_meta("max_hp", int(e.maxHp))
	stage.set_meta("boss", int(e.maxHp) >= ENEMY_BOSS_HP)
	if art != null:
		art.set_meta("dead", dead)
		_enemy_art_by_uid[uid] = art
	if dead:
		_enemy_hit_by_uid.erase(uid)
		var plate: Node = stage.get_node_or_null("Plate")
		if plate != null:
			stage.remove_child(plate)
			plate.queue_free()
		if not _death_fx_done.has(uid):
			_death_fx_done[uid] = "playing"
			_start_enemy_dissolve(stage, art)
		return
	_death_fx_done.erase(uid)
	if art != null:
		_enemy_hit_by_uid[uid] = art
	var old_plate: Node = stage.get_node_or_null("Plate")
	if old_plate != null:
		stage.remove_child(old_plate)
		old_plate.queue_free()
	var plate: VBoxContainer = _make_enemy_plate(e, def, dual)
	plate.name = "Plate"
	plate.z_index = 12
	stage.add_child(plate)


func _start_enemy_dissolve(stage: Control, art: TextureRect) -> void:
	if art == null or not is_instance_valid(art):
		return
	if art.get_meta("dissolving", false):
		return
	var uid: String = str(stage.get_meta("enemy_uid", ""))
	_kill_hit_tween(uid)
	_kill_float_tween(uid)
	_kill_px_idle(uid)
	_kill_px_cast(uid)
	art.set_meta("float_y", 0.0)
	art.modulate = Color.WHITE
	art.self_modulate = Color.WHITE
	art.scale = Vector2.ONE
	art.pivot_offset = art.size * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE_SHADER
	mat.set_shader_parameter("noise_tex", DISSOLVE_NOISE)
	mat.set_shader_parameter("progress", 0.0)
	art.material = mat
	art.set_meta("dissolving", true)
	stage.set_meta("dissolving", true)
	var tween := stage.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(mat, "shader_parameter/progress", 1.0, 0.9)
	tween.tween_interval(0.1)
	tween.tween_callback(_finish_enemy_dissolve.bind(stage, uid))
	_spawn_dust_motes(art)


func _finish_enemy_dissolve(stage: Control, uid: String) -> void:
	_death_fx_done[uid] = "gone"
	_kill_hit_tween(uid)
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
	_enemy_art_by_uid.erase(uid)
	_enemy_hit_by_uid.erase(uid)
	call_deferred("_layout_enemies")


func _spawn_dust_motes(art: TextureRect) -> void:
	if art == null or not is_instance_valid(art):
		return
	if art.get_meta("dust_spawned", false):
		return
	var box: Vector2 = art.size
	if box.x <= 1.0 or box.y <= 1.0:
		return
	art.set_meta("dust_spawned", true)
	var n: int = 23 + randi() % 16
	for i in n:
		var mote := ColorRect.new()
		var mote_size: float = 3.0 + randf() * 4.0
		mote.size = Vector2(mote_size, mote_size)
		mote.color = Color(0.36, 0.34, 0.30, 0.9)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.z_index = 20
		mote.use_parent_material = false
		var left_p: float = 0.40 + randf() * 0.20
		var top_p: float = 0.50 + randf() * 0.30
		mote.position = Vector2(box.x * left_p, box.y * top_p)
		art.add_child(mote)
		var angle: float = deg_to_rad((randf() - 0.5) * 140.0)
		var dist: float = 40.0 + randf() * 60.0
		var delay: float = randf() * 0.3
		var dest: Vector2 = mote.position + Vector2.UP.rotated(angle) * dist
		var tw := mote.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(mote, "position", dest, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mote, "modulate:a", 0.0, 0.9)
		tw.tween_callback(mote.queue_free)


func _kill_hit_tween(uid: String) -> void:
	if uid == "" or not _hit_tweens.has(uid):
		return
	var tw: Tween = _hit_tweens.get(uid) as Tween
	_hit_tweens.erase(uid)
	if tw != null and tw.is_valid():
		tw.kill()


func _kill_float_tween(uid: String) -> void:
	if uid == "" or not _float_tweens.has(uid):
		return
	var tw: Tween = _float_tweens.get(uid) as Tween
	_float_tweens.erase(uid)
	if tw != null and is_instance_valid(tw):
		tw.kill()


func _apply_enemy_portrait(art: TextureRect, def: Dictionary) -> void:
	var sprite_path: String = str(def.get("sprite", ""))
	## 書き出し後は res:// の元PNGが無く .import だけになる。FileAccess.file_exists は false になる。
	if sprite_path != "" and ResourceLoader.exists(sprite_path, "Texture2D"):
		var loaded: Resource = ResourceLoader.load(sprite_path, "Texture2D")
		var sheet: Texture2D = loaded as Texture2D
		if sheet != null:
			art.set_meta("px_sprite", true)
			art.set_meta("px_sheet", sheet)
			art.set_meta("px_frame", 0)
			art.texture = _make_px_atlas(sheet, 0)
			return
	art.set_meta("px_sprite", false)
	art.texture = _load_texture_safe(str(def.get("art", "")))


func _make_px_atlas(sheet: Texture2D, frame: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.filter_clip = true
	var index: int = clampi(frame, 0, Enemies.PX_FRAME_COUNT - 1)
	atlas.region = Rect2(index * Enemies.PX_FRAME_W, 0, Enemies.PX_FRAME_W, Enemies.PX_FRAME_H)
	return atlas


func _set_px_frame(art: TextureRect, frame: int) -> void:
	if art == null or not is_instance_valid(art):
		return
	if not art.get_meta("px_sprite", false):
		return
	var sheet: Texture2D = art.get_meta("px_sheet") as Texture2D
	if sheet == null:
		return
	var index: int = clampi(frame, 0, Enemies.PX_FRAME_COUNT - 1)
	var atlas: AtlasTexture = art.texture as AtlasTexture
	if atlas == null or atlas.atlas != sheet:
		art.texture = _make_px_atlas(sheet, index)
	else:
		atlas.region = Rect2(index * Enemies.PX_FRAME_W, 0, Enemies.PX_FRAME_W, Enemies.PX_FRAME_H)
	art.set_meta("px_frame", index)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _start_px_idle(uid: String, art: TextureRect) -> void:
	_kill_px_idle(uid)
	if art == null or not is_instance_valid(art):
		return
	if not art.get_meta("px_sprite", false) or art.get_meta("dissolving", false):
		return
	if VideoSettings.is_reduce_motion():
		_set_px_frame(art, 0)
		return
	if int(art.get_meta("px_frame", 0)) > 1:
		_set_px_frame(art, 0)
	var tw: Tween = art.create_tween().set_loops()
	tw.tween_interval(PX_IDLE_STEP)
	tw.tween_callback(_toggle_px_idle.bind(uid))
	_px_idle_tweens[uid] = tw


func _toggle_px_idle(uid: String) -> void:
	var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
	if art == null or not is_instance_valid(art) or art.get_meta("dissolving", false):
		return
	var cur: int = int(art.get_meta("px_frame", 0))
	_set_px_frame(art, 0 if cur == 1 else 1)


func _kill_px_idle(uid: String) -> void:
	if uid == "" or not _px_idle_tweens.has(uid):
		return
	var tw: Tween = _px_idle_tweens.get(uid) as Tween
	_px_idle_tweens.erase(uid)
	if tw != null and tw.is_valid():
		tw.kill()


func _kill_px_cast(uid: String) -> void:
	if uid == "" or not _px_cast_tweens.has(uid):
		return
	var tw: Tween = _px_cast_tweens.get(uid) as Tween
	_px_cast_tweens.erase(uid)
	if tw != null and tw.is_valid():
		tw.kill()


func _play_enemy_card_motions(alive_before: Array) -> void:
	if VideoSettings.is_reduce_motion():
		return
	var still_alive: Dictionary = {}
	for foe in CombatLogic.living(state):
		var foe_uid: String = str(foe.get("uid", ""))
		still_alive[foe_uid] = true
	var slot: int = 0
	for uid in alive_before:
		var uid_s: String = str(uid)
		if not still_alive.has(uid_s):
			continue
		var art: TextureRect = _enemy_art_by_uid.get(uid_s) as TextureRect
		if art == null or not is_instance_valid(art):
			continue
		if not art.get_meta("px_sprite", false) or art.get_meta("dissolving", false):
			continue
		_play_px_cast(uid_s, art, PX_CAST_STAGGER * float(slot))
		slot += 1


func _play_px_cast(uid: String, art: TextureRect, delay: float) -> void:
	_kill_px_idle(uid)
	_kill_px_cast(uid)
	var tw: Tween = art.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	var i: int = 0
	while i < PX_CAST_HOLDS.size():
		var frame: int = 2 + i
		var hold: float = float(PX_CAST_HOLDS[i])
		tw.tween_callback(_set_px_frame.bind(art, frame))
		tw.tween_interval(hold)
		i += 1
	tw.tween_callback(_set_px_frame.bind(art, 0))
	tw.tween_callback(_resume_px_idle.bind(uid))
	_px_cast_tweens[uid] = tw


func _resume_px_idle(uid: String) -> void:
	_px_cast_tweens.erase(uid)
	var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
	if art == null or not is_instance_valid(art) or art.get_meta("dissolving", false):
		return
	if VideoSettings.is_reduce_motion():
		_set_px_frame(art, 0)
		return
	_start_px_idle(uid, art)


func _on_px_reduce_motion(enabled: bool) -> void:
	if enabled:
		var idle_ids: Array = _px_idle_tweens.keys()
		for uid in idle_ids:
			_kill_px_idle(str(uid))
		var cast_ids: Array = _px_cast_tweens.keys()
		for uid2 in cast_ids:
			_kill_px_cast(str(uid2))
		for uid3 in _enemy_art_by_uid.keys():
			var art: TextureRect = _enemy_art_by_uid[uid3] as TextureRect
			if art != null and is_instance_valid(art) and art.get_meta("px_sprite", false):
				_set_px_frame(art, 0)
		return
	for uid4 in _enemy_art_by_uid.keys():
		var art2: TextureRect = _enemy_art_by_uid[uid4] as TextureRect
		if art2 == null or not is_instance_valid(art2):
			continue
		if not art2.get_meta("px_sprite", false) or art2.get_meta("dissolving", false):
			continue
		if art2.get_meta("dead", false):
			continue
		_start_px_idle(str(uid4), art2)


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
	var player_turn: bool = state.get("phase") == "player" and state.get("result") == "ongoing" and not resolving
	var desired: Array = state.get("hand", [])
	var desired_uids: Dictionary = {}
	for card in desired:
		desired_uids[str(card.uid)] = true

	# Drop cards no longer in hand.
	var stale: Array = []
	for child in hand_row.get_children():
		if child is CombatCard:
			var uid: String = (child as CombatCard).card_uid
			if not desired_uids.has(uid):
				stale.append(child)
	for child in stale:
		var uid: String = (child as CombatCard).card_uid
		_kill_draw_in(uid)
		hand_row.remove_child(child)
		child.queue_free()

	# Reuse by uid; spawn only brand-new cards.
	var by_uid: Dictionary = {}
	for child in hand_row.get_children():
		if child is CombatCard:
			by_uid[(child as CombatCard).card_uid] = child

	var new_uids: Array = []
	var order_index: int = 0
	for card in desired:
		var uid: String = str(card.uid)
		var d: Dictionary = Cards.get_card(str(card.defId))
		var playable: bool = player_turn and CombatLogic.can_play(state, card)
		var btn: CombatCard = by_uid.get(uid) as CombatCard
		if btn == null:
			btn = COMBAT_CARD.new()
			btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			btn.custom_minimum_size = CARD_SIZE
			btn.size = CARD_SIZE
			btn.configure(card, d, playable, uid == targeting_uid)
			btn.drag_began.connect(_on_drag_began)
			btn.set_meta("draw_in", true)
			hand_row.add_child(btn)
			new_uids.append(uid)
		else:
			btn.configure(card, d, playable, uid == targeting_uid)
			if not _draw_in_tweens.has(uid):
				btn.set_meta("draw_in", false)
		hand_row.move_child(btn, order_index)
		order_index += 1

	_layout_fan(new_uids)
	call_deferred("_layout_fan_deferred")


func _layout_fan_deferred() -> void:
	_layout_fan([])


func _upcoming_card_ids(e: Dictionary) -> Array:
	var shown: Variant = e.get("shownCardIds")
	if shown is Array and (shown as Array).size() > 0:
		return shown as Array
	var ids: Variant = e.get("actionCardIds", [])
	if ids is Array:
		return ids as Array
	return []


func _enemy_action_text(e: Dictionary) -> String:
	var ids: Array = _upcoming_card_ids(e)
	if ids.size() == 0:
		return "行動準備"
	var names: PackedStringArray = PackedStringArray()
	for id in ids:
		names.append(str(Cards.get_card(str(id)).get("name", "")))
	return "%sを使用" % "・".join(names)


func _make_upcoming_cards(e: Dictionary, compact: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6 if compact else 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_size: Vector2 = PREVIEW_CARD_SIZE_DUAL if compact else PREVIEW_CARD_SIZE
	for id in _upcoming_card_ids(e):
		var definition: Dictionary = Cards.get_card(str(id))
		var fake: Dictionary = {"uid": "", "defId": str(id)}
		var preview: CombatCard = COMBAT_CARD.new()
		preview.custom_minimum_size = card_size
		preview.size = card_size
		preview.configure(fake, definition, true, false, false)
		row.add_child(preview)
	return row


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
	var text: String = str(floater.get("text", ""))
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.size = Vector2(maxf(110.0, 22.0 * float(text.length()) + 16.0), 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	if str(_death_fx_done.get(uid, "")) != "":
		return
	var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
	if art == null or not is_instance_valid(art):
		return
	if art.get_meta("dissolving", false):
		return
	_kill_hit_tween(uid)
	art.pivot_offset = art.size * 0.5
	var tween := art.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(art, "modulate", Color(1.55, 1.25, 1.25, 1.0), 0.07)
	tween.parallel().tween_property(art, "scale", Vector2(0.96, 1.06), 0.07)
	tween.tween_property(art, "modulate", Color.WHITE, 0.21)
	tween.parallel().tween_property(art, "scale", Vector2.ONE, 0.21)
	_hit_tweens[uid] = tween


func _on_drag_began(card_uid: String) -> void:
	# Prefer drag only after draw-in lands.
	for child in hand_row.get_children():
		if child is CombatCard and (child as CombatCard).card_uid == card_uid:
			if child.get_meta("draw_in", false) == true:
				return
			break
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


func _make_enemy_plate(e: Dictionary, def: Dictionary, compact: bool = false) -> VBoxContainer:
	var plate := VBoxContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_constant_override("separation", 3 if compact else 4)
	var plate_w: float = ENEMY_PLATE_W_DUAL if compact else ENEMY_PLATE_W
	plate.custom_minimum_size = Vector2(plate_w, 0)
	plate.add_child(_make_upcoming_cards(e, compact))

	var box := Panel.new()
	box.custom_minimum_size = Vector2(plate_w, 64 if compact else 72)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.05, 0.045, 0.94)
	style.border_color = Color(0.42, 0.36, 0.26, 1)
	style.set_border_width_all(2)
	style.content_margin_left = 8 if not compact else 6
	style.content_margin_right = 8 if not compact else 6
	style.content_margin_top = 6 if not compact else 4
	style.content_margin_bottom = 6 if not compact else 4
	box.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_right = -8
	col.offset_top = 6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = str(def.get("name", e.defId))
	name_label.add_theme_font_size_override("font_size", 12 if compact else 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)

	var action_label := Label.new()
	action_label.text = _enemy_action_text(e)
	action_label.add_theme_font_size_override("font_size", 11)
	action_label.add_theme_color_override("font_color", Color("d4a84b"))
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(action_label)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(0, 6)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.color = Color("161512")
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	var ratio: float = 0.0
	if int(e.maxHp) > 0:
		ratio = clampf(float(e.hp) / float(e.maxHp), 0.0, 1.0)
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = ratio
	fill.color = Color("8b1e1e")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	col.add_child(track)

	var hp_label := Label.new()
	hp_label.text = "%d/%d" % [int(e.hp), int(e.maxHp)]
	hp_label.add_theme_font_size_override("font_size", 10)
	hp_label.add_theme_color_override("font_color", Color("b8ad96"))
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hp_label)

	var status_row := HFlowContainer.new()
	status_row.add_theme_constant_override("h_separation", 6)
	status_row.add_theme_constant_override("v_separation", 2)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if int(e.get("block", 0)) > 0:
		status_row.add_child(VitalsHud.make_icon_stat(VitalsHud.ICON_BLOCK, str(int(e.block)), Color("ede4d0")))
	if int(e.get("strength", 0)) > 0:
		status_row.add_child(VitalsHud.make_icon_stat(VitalsHud.ICON_STR, str(int(e.strength)), Color("3aa39a")))
	if int(e.get("weak", 0)) > 0:
		status_row.add_child(VitalsHud.make_icon_stat(VitalsHud.ICON_WEAK, str(int(e.weak)), Color("c45c4a")))
	if int(e.get("poison", 0)) > 0:
		status_row.add_child(VitalsHud.make_icon_stat(VitalsHud.ICON_POISON, str(int(e.poison)), Color("3aa39a")))
	var enemy_sealed = e.get("sealed", "")
	if enemy_sealed != null and str(enemy_sealed) != "" and str(enemy_sealed) != "<null>":
		var seal_path: String = VitalsHud.ICON_SEAL_ATTACK if str(enemy_sealed) == "attack" else VitalsHud.ICON_SEAL_SKILL
		var seal_txt: String = "攻撃" if str(enemy_sealed) == "attack" else "技能"
		status_row.add_child(VitalsHud.make_icon_stat(seal_path, seal_txt, Color("c45c4a")))
	if status_row.get_child_count() > 0:
		col.add_child(status_row)

	box.add_child(col)
	plate.add_child(box)
	return plate


func _layout_fan(new_uids: Array = []) -> void:
	if hand_row == null or not is_instance_valid(hand_row):
		return
	var cards: Array = []
	for child in hand_row.get_children():
		if child is Control and not child.is_queued_for_deletion():
			cards.append(child)
	var n: int = cards.size()
	if n == 0:
		return
	var area: Vector2 = hand_row.size
	if area.x < 8.0 or area.y < 8.0:
		return
	var origin := Vector2(area.x * 0.5, area.y - 4.0)
	var overlap: float = 0.0
	if n > 1:
		if n <= 4:
			overlap = -8.0
		elif n <= 6:
			overlap = -24.0
		elif n <= 8:
			overlap = -40.0
		elif n <= 10:
			overlap = -56.0
		else:
			overlap = -68.0
	var step_angle: float = 0.0 if n <= 1 else minf(5.0, 24.0 / float(maxi(1, n - 1)))
	var spacing: float = CARD_SIZE.x + overlap
	var draw_offset := _draw_pile_offset_in_hand_row()
	var new_index: int = 0
	for i in n:
		var card: Control = cards[i] as Control
		var offset: float = float(i) - float(n - 1) / 2.0
		var rot: float = offset * step_angle
		var extra_y: float = absf(offset) * (5.0 if n >= 9 else 7.0)
		var x: float = offset * spacing
		var final_pos := Vector2(origin.x + x - CARD_SIZE.x * 0.5, origin.y - CARD_SIZE.y + extra_y)
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.size = CARD_SIZE
		card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
		card.z_index = i
		var uid: String = ""
		if card is CombatCard:
			uid = (card as CombatCard).card_uid
		var pending_draw: bool = (card.get_meta("draw_in", false) == true) and not _draw_in_tweens.has(uid)
		var should_draw_in: bool = uid != "" and (new_uids.has(uid) or pending_draw)
		card.set_meta("fan_pos", final_pos)
		card.set_meta("fan_rot", rot)
		if should_draw_in:
			_start_draw_in(card, uid, final_pos, rot, draw_offset, new_index)
			new_index += 1
		elif (card.get_meta("draw_in", false) == true) and _draw_in_tweens.has(uid):
			# Mid-flight: landing slot kept in fan_pos/fan_rot for _finish_draw_in.
			pass
		else:
			card.position = final_pos
			card.rotation_degrees = rot


func _draw_pile_offset_in_hand_row() -> Vector2:
	# Start from the real draw-pile button when available; fallback to upper-left ritual offset.
	if _draw_btn != null and is_instance_valid(_draw_btn) and hand_row != null:
		var pile_center: Vector2 = _draw_btn.get_global_rect().get_center()
		var hand_origin: Vector2 = hand_row.get_global_transform_with_canvas().origin
		var local_pile: Vector2 = pile_center - hand_origin - CARD_SIZE * 0.5
		# Offset from a typical fan landing near bottom-center toward the pile.
		var area: Vector2 = hand_row.size
		var typical := Vector2(area.x * 0.5 - CARD_SIZE.x * 0.5, area.y - CARD_SIZE.y - 4.0)
		return local_pile - typical
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(-0.36 * viewport_size.x, -0.28 * viewport_size.y)


func _kill_draw_in(uid: String) -> void:
	if not _draw_in_tweens.has(uid):
		return
	var tw: Tween = _draw_in_tweens[uid] as Tween
	_draw_in_tweens.erase(uid)
	if tw != null and is_instance_valid(tw):
		tw.kill()


func _start_draw_in(card: Control, uid: String, final_pos: Vector2, final_rot: float, draw_offset: Vector2, stagger_index: int) -> void:
	_kill_draw_in(uid)
	card.set_meta("draw_in", true)
	card.position = final_pos + draw_offset
	card.scale = Vector2(DRAW_IN_SCALE, DRAW_IN_SCALE)
	card.rotation_degrees = final_rot + DRAW_IN_ROT_OFFSET
	var base_a: float = 1.0
	if card is CombatCard and (card as CombatCard).disabled:
		base_a = 0.56
	var start_mod: Color = card.modulate
	start_mod.a = 0.0
	card.modulate = start_mod
	if card is CombatCard:
		(card as CombatCard).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var delay: float = float(mini(stagger_index, DRAW_IN_STAGGER_CAP)) * DRAW_IN_STAGGER
	var tw: Tween = card.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(card, "position", final_pos, DRAW_IN_DURATION)
	tw.tween_property(card, "scale", Vector2.ONE, DRAW_IN_DURATION)
	tw.tween_property(card, "rotation_degrees", final_rot, DRAW_IN_DURATION)
	tw.tween_property(card, "modulate:a", base_a, DRAW_IN_DURATION)
	tw.set_parallel(false)
	tw.tween_callback(_finish_draw_in.bind(uid))
	_draw_in_tweens[uid] = tw


func _finish_draw_in(uid: String) -> void:
	_draw_in_tweens.erase(uid)
	for child in hand_row.get_children():
		if child is CombatCard and (child as CombatCard).card_uid == uid:
			var card: CombatCard = child as CombatCard
			card.set_meta("draw_in", false)
			var fan_pos: Vector2 = card.get_meta("fan_pos", card.position)
			var fan_rot: float = float(card.get_meta("fan_rot", card.rotation_degrees))
			card.position = fan_pos
			card.rotation_degrees = fan_rot
			card.scale = Vector2.ONE
			if not card.disabled:
				card.mouse_filter = Control.MOUSE_FILTER_STOP
			return


func _build_chrome() -> void:
	if _chrome_ready:
		return
	_chrome_ready = true
	hud_label.visible = false
	_ensure_fx()
	_ensure_vfx_layer()
	_decorate_panel(log_panel)
	hud_panel.bind({
		"player_name": GameState.player_name,
		"floor_text": "",
		"hp": 0,
		"max_hp": 1,
		"sanity": 0,
		"max_sanity": 1,
		"show_header": true,
		"show_energy": true,
		"show_status": true,
		"show_shells": true,
		"shells": GameState.shells,
	})

	_draw_btn = PIXEL_BUTTON.instantiate() as Button
	_draw_btn.text = "山札: 0"
	_draw_btn.position = Vector2(12, 184)
	_draw_btn.size = Vector2(110, 36)
	_draw_btn.pressed.connect(func(): _open_pile("draw"))
	## 敵の立ち絵（EnemyRow, z=1）が横に広いと重なるので、HUDと同じ層で手前に描く
	_draw_btn.z_index = PILE_BUTTON_Z
	add_child(_draw_btn)

	_discard_btn = PIXEL_BUTTON.instantiate() as Button
	_discard_btn.text = "捨て札: 0"
	_discard_btn.position = Vector2(130, 184)
	_discard_btn.size = Vector2(120, 36)
	_discard_btn.pressed.connect(func(): _open_pile("discard"))
	_discard_btn.z_index = PILE_BUTTON_Z
	add_child(_discard_btn)


func _decorate_panel(panel: Panel) -> void:
	VitalsHud.attach_panel_frame(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.065, 0.055, 0.92)
	var inset: int = VitalsHud.FRAME_CONTENT_INSET
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	panel.add_theme_stylebox_override("panel", style)
	# StyleBoxFlat.content_margin does not inset Controls — pad LogScroll inside the stone frame.
	if panel == log_panel and log_scroll != null:
		VitalsHud.apply_framed_content_inset(log_scroll, inset)


func _open_pile(which: String) -> void:
	if state.is_empty():
		return
	var cards: Array = state.get(which, [])
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.02, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 80
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			overlay.queue_free()
	)
	add_child(overlay)
	var title := Label.new()
	title.text = ("山札 %d枚" if which == "draw" else "捨て札 %d枚") % cards.size()
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	overlay.add_child(title)
	var wrap := HFlowContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.offset_left = 24
	wrap.offset_top = 56
	wrap.offset_right = -24
	wrap.offset_bottom = -64
	wrap.add_theme_constant_override("h_separation", 8)
	wrap.add_theme_constant_override("v_separation", 8)
	overlay.add_child(wrap)
	for card in cards:
		var d: Dictionary = Cards.get_card(str(card.defId))
		var preview: CombatCard = COMBAT_CARD.new()
		preview.custom_minimum_size = CARD_SIZE
		preview.size = CARD_SIZE
		preview.configure(card, d, true, false, false)
		wrap.add_child(preview)
	var close_btn: Button = PIXEL_BUTTON.instantiate() as Button
	close_btn.text = "閉じる"
	close_btn.position = Vector2(24, size.y - 56)
	close_btn.size = Vector2(120, 40)
	close_btn.pressed.connect(overlay.queue_free)
	overlay.add_child(close_btn)


func _layout_enemies() -> void:
	if enemy_row == null or not is_instance_valid(enemy_row):
		return
	var area: Vector2 = enemy_row.size
	if area.x < 16.0 or area.y < 16.0:
		return
	var stages: Array = []
	for child in enemy_row.get_children():
		if child is Control and not child.is_queued_for_deletion():
			stages.append(child)
	var n: int = stages.size()
	if n <= 0:
		return
	for i in n:
		_layout_enemy_stage(stages[i] as Control, i, n, area)


func _layout_enemy_stage(stage: Control, index: int, count: int, area: Vector2) -> void:
	if stage.get_meta("dissolving", false):
		return
	var art: TextureRect = stage.get_node_or_null("Art") as TextureRect
	var plate: Control = stage.get_node_or_null("Plate") as Control
	var slot_w: float
	var slot_x: float
	if count <= 1:
		slot_w = area.x
		slot_x = 0.0
	else:
		## 原作 dual は各 figure が min(80vw, 40rem)。スロットを半分より広く取り、絵を優先して重ねる。
		slot_w = area.x * 0.56
		slot_x = 0.0 if index == 0 else area.x - slot_w
	stage.position = Vector2(slot_x, 0.0)
	stage.size = Vector2(slot_w, area.y)
	if art == null or art.texture == null:
		return
	if art.get_meta("dissolving", false):
		return
	var tex_size: Vector2 = art.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var view: Vector2 = get_viewport_rect().size
	var is_boss: bool = stage.get_meta("boss", false) and true
	var max_w: float
	var max_h: float
	if count == 1:
		if is_boss:
			max_w = minf(view.x, ENEMY_BOSS_W)
			max_h = minf(view.y * 0.78, ENEMY_BOSS_H)
		else:
			max_w = minf(view.x * 0.94, ENEMY_CUTOUT_W)
			max_h = minf(view.y * 0.70, ENEMY_CUTOUT_H)
	else:
		max_w = minf(slot_w * 0.98, minf(view.x * 0.80, ENEMY_CUTOUT_W_DUAL))
		max_h = minf(view.y * 0.70, ENEMY_CUTOUT_H)
		if is_boss:
			max_h = minf(view.y * 0.78, ENEMY_BOSS_H)
	var art_box := Vector2(maxf(64.0, max_w), maxf(64.0, max_h))

	var drawn: Vector2
	if art.get_meta("px_sprite", false):
		var step: int = maxi(1, int(floor(minf(art_box.x / float(Enemies.PX_FRAME_W), art_box.y / float(Enemies.PX_FRAME_H)))))
		drawn = Vector2(float(Enemies.PX_FRAME_W * step), float(Enemies.PX_FRAME_H * step))
	else:
		var fitted: float = minf(art_box.x / tex_size.x, art_box.y / tex_size.y)
		drawn = tex_size * fitted
	var ground_ratio: float = ENEMY_GROUND_DUAL if count >= 2 else ENEMY_GROUND_SINGLE
	var ground_y: float = area.y * (1.0 - ground_ratio)
	var art_pos := Vector2((slot_w - drawn.x) * 0.5, ground_y - drawn.y)
	var float_y: float = 0.0
	if art.has_meta("float_y"):
		float_y = float(art.get_meta("float_y"))
	art_pos.y += float_y
	if plate != null:
		var plate_w: float = ENEMY_PLATE_W_DUAL if count >= 2 else ENEMY_PLATE_W
		var plate_h: float = maxf(140.0 if count >= 2 else 220.0, plate.get_combined_minimum_size().y)
		if count == 1:
			var gap: float = ENEMY_PLATE_GAP
			art_pos.x = (slot_w - drawn.x) * 0.5
			var plate_x: float = art_pos.x + drawn.x + gap
			var overflow: float = plate_x + plate_w - slot_w
			if overflow > 0.0:
				art_pos.x -= overflow
				plate_x -= overflow
			if art_pos.x < 0.0:
				art_pos.x = 0.0
				plate_x = drawn.x + gap
			_place_unanchored(plate, Vector2(plate_x, area.y * 0.14), Vector2(plate_w, plate_h))
		else:
			## 原作 .enemy-vitals は figure 上に重ねる。絵の幅を奪わない。
			art_pos.x = (slot_w - drawn.x) * 0.5
			var plate_x: float = art_pos.x + drawn.x * 0.52
			if index == 1:
				plate_x = art_pos.x + drawn.x * 0.48 - plate_w
			if plate_x < 4.0:
				plate_x = 4.0
			if plate_x + plate_w > slot_w - 4.0:
				plate_x = slot_w - plate_w - 4.0
			var plate_y: float = maxf(8.0, area.y * 0.16)
			_place_unanchored(plate, Vector2(plate_x, plate_y), Vector2(plate_w, plate_h))
	_place_unanchored(art, art_pos, drawn)


func _place_unanchored(node: Control, pos: Vector2, node_size: Vector2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.position = pos
	node.size = node_size


func _align_art_to_ground(_art: TextureRect) -> void:
	_layout_enemies()


func _load_texture_safe(path: String) -> Texture2D:
	var resolved: String = Cards.resolve_art(path)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		return load(FALLBACK_TEX) as Texture2D
	var resource: Resource = ResourceLoader.load(resolved, "Texture2D")
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Texture2Dとして読み込めませんでした: %s" % path)
	return load(FALLBACK_TEX) as Texture2D


func _ensure_fx() -> void:
	if _fx_canvas != null and is_instance_valid(_fx_canvas):
		return
	_fx_canvas = CanvasLayer.new()
	_fx_canvas.name = "CombatFx"
	_fx_canvas.layer = 80
	add_child(_fx_canvas)
	_shield = Polygon2D.new()
	_shield.name = "HitShield"
	_shield.color = Color(0.72, 0.92, 1.0, 0.42)
	_shield.polygon = _octagon_points(118.0)
	_shield.modulate.a = 0.0
	_fx_canvas.add_child(_shield)
	_hurt_flash = ColorRect.new()
	_hurt_flash.name = "HurtFlash"
	_hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_flash.color = Color(0.72, 0.08, 0.06, 0.0)
	_fx_canvas.add_child(_hurt_flash)


func _octagon_points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var i: int = 0
	while i < 8:
		var ang: float = deg_to_rad(22.5 + float(i) * 45.0)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
		i += 1
	return pts


func _run_player_hit_fx() -> void:
	if player.is_empty():
		return
	var hp_now: int = int(player.hp)
	var san_now: int = int(player.sanity)
	var block_now: int = int(state.get("block", 0)) if not state.is_empty() else 0
	## HitShield = 防御成功（block消費）。完全／部分ブロックどちらも。
	if _prev_block >= 0 and block_now < _prev_block:
		_fx_shield()
	## HP減は痛み用（毒・貫通・無防御被弾）。盾とは分離。
	if _prev_hp >= 0 and hp_now < _prev_hp:
		_fx_player_hurt()
	_run_sanity_fx(san_now)
	_prev_hp = hp_now
	_prev_sanity = san_now
	_prev_block = block_now


func _ensure_sanity_fx() -> void:
	if _sanity_fx != null and is_instance_valid(_sanity_fx):
		return
	_sanity_fx = SanityFx.new()
	add_child(_sanity_fx)
	_sanity_fx.hit_shown.connect(_on_sanity_hit_shown)


## 正気度の減少を理由別に読んで演出する。CombatLogic が c.sanityLossPaid / c.sanityLossHit に
## 累計した値を使い、使ったら 0 に戻す。理由の分からない減少（将来の追加経路など）は「削られた」扱い。
func _run_sanity_fx(san_now: int) -> void:
	_ensure_sanity_fx()
	var paid: int = int(state.get("sanityLossPaid", 0))
	var hit: int = int(state.get("sanityLossHit", 0))
	state["sanityLossPaid"] = 0
	state["sanityLossHit"] = 0
	if _prev_sanity >= 0 and san_now < _prev_sanity and paid <= 0 and hit <= 0:
		hit = _prev_sanity - san_now
	if paid > 0 or hit > 0:
		var from: Vector2 = _sanity_drop_from
		if from.x < 0.0:
			from = hand_row.get_global_rect().get_center() if hand_row else get_viewport_rect().size * 0.5
		_sanity_fx.play_loss(paid, hit, from, hud_panel.sanity_bar_global_rect())
	_sanity_drop_from = Vector2(-1.0, -1.0)
	if str(state.get("result", "ongoing")) == "ongoing":
		_sanity_fx.set_sanity(san_now, int(player.get("maxSanity", 0)))


func _on_sanity_hit_shown(crack_tex: Texture2D, shake: bool) -> void:
	hud_panel.flash_sanity_crack(crack_tex, shake)


func _hand_card_center(card_uid: String) -> Vector2:
	if hand_row == null:
		return Vector2(-1.0, -1.0)
	for child in hand_row.get_children():
		if child is CombatCard and (child as CombatCard).card_uid == card_uid:
			return (child as CombatCard).get_global_rect().get_center()
	return Vector2(-1.0, -1.0)


func _fx_shield() -> void:
	_ensure_fx()
	var view: Vector2 = get_viewport_rect().size
	_shield.position = view * 0.5
	_shield.scale = Vector2(0.72, 0.72)
	_shield.modulate = Color(0.78, 0.94, 1.0, 0.55)
	if _shield_tween != null and is_instance_valid(_shield_tween):
		_shield_tween.kill()
	_shield_tween = create_tween()
	_shield_tween.set_parallel(true)
	_shield_tween.tween_property(_shield, "scale", Vector2(1.18, 1.18), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shield_tween.tween_property(_shield, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## HP減用の被弾フラッシュ。盾（ブロック成功）とは別チャンネル。
func _fx_player_hurt() -> void:
	_ensure_fx()
	if _hurt_flash == null or not is_instance_valid(_hurt_flash):
		return
	_hurt_flash.color = Color(0.72, 0.08, 0.06, 0.38)
	if _hurt_tween != null and is_instance_valid(_hurt_tween):
		_hurt_tween.kill()
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(_hurt_flash, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _fx_shock_living() -> void:
	var living: Array = CombatLogic.living(state)
	for e in living:
		var uid: String = str(e.get("uid", ""))
		var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
		if art != null and is_instance_valid(art):
			_fx_shock_on(art)


func _fx_shock_on(art: TextureRect) -> void:
	var w: float = art.size.x
	var h: float = art.size.y
	if w < 8.0 or h < 8.0:
		return
	_fx_shock_flash(art)
	var origins: Array = [
		Vector2(w * randf_range(0.10, 0.28), h * randf_range(0.10, 0.30)),
		Vector2(w * randf_range(0.40, 0.60), h * randf_range(0.06, 0.20)),
		Vector2(w * randf_range(0.72, 0.90), h * randf_range(0.12, 0.32)),
	]
	var n: int = 0
	while n < origins.size():
		var origin: Vector2 = origins[n]
		var ending := Vector2(origin.x + randf_range(-w * 0.16, w * 0.16), h * randf_range(0.70, 0.94))
		ending.x = clampf(ending.x, w * 0.06, w * 0.94)
		var main: PackedVector2Array = _lightning_path(origin, ending, 6, w * 0.09)
		_spawn_bolt(art, main, true)
		var mid_i: int = 2 + (randi() % 3)
		if mid_i < main.size() - 1:
			var mid: Vector2 = main[mid_i]
			var br_end: Vector2 = mid + Vector2(randf_range(-w * 0.24, w * 0.24), randf_range(h * 0.06, h * 0.22))
			_spawn_bolt(art, _lightning_path(mid, br_end, 3, w * 0.05), false)
		if randf() < 0.55 and mid_i > 1:
			var mid2: Vector2 = main[maxi(1, mid_i - 1)]
			var br2: Vector2 = mid2 + Vector2(randf_range(-w * 0.18, w * 0.18), randf_range(h * 0.04, h * 0.16))
			_spawn_bolt(art, _lightning_path(mid2, br2, 3, w * 0.04), false)
		_spawn_sparks(art, main)
		n += 1


func _lightning_path(start: Vector2, ending: Vector2, segs: int, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(start)
	var i: int = 1
	while i < segs:
		var t: float = float(i) / float(segs)
		var p: Vector2 = start.lerp(ending, t)
		var side: Vector2 = (ending - start).orthogonal().normalized()
		p += side * randf_range(-jag, jag)
		p.y += randf_range(-jag * 0.25, jag * 0.25)
		pts.append(p)
		i += 1
	pts.append(ending)
	return pts


func _spawn_bolt(host: Control, pts: PackedVector2Array, is_main: bool) -> void:
	if pts.size() < 2:
		return
	var holder := Node2D.new()
	host.add_child(holder)
	var glow: Line2D = _make_shock_line(pts, 15.0 if is_main else 9.0, SHOCK_GLOW, true, false)
	var core: Line2D = _make_shock_line(pts, 5.5 if is_main else 3.0, SHOCK_CORE, false, true)
	var hot: Line2D = _make_shock_line(pts, 2.0 if is_main else 1.2, Color(0.92, 1.0, 0.55, 0.85), true, false)
	holder.add_child(glow)
	holder.add_child(core)
	holder.add_child(hot)
	var tw: Tween = holder.create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(holder, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)


func _make_shock_line(pts: PackedVector2Array, width: float, color: Color, additive: bool, taper: bool) -> Line2D:
	var line := Line2D.new()
	line.points = pts
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	line.end_cap_mode = Line2D.LINE_CAP_NONE
	line.antialiased = false
	if taper:
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(0.55, 0.7))
		curve.add_point(Vector2(1.0, 0.18))
		line.width_curve = curve
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		line.material = mat
	return line


func _spawn_sparks(host: Control, pts: PackedVector2Array) -> void:
	var count: int = mini(12, 6 + pts.size())
	var i: int = 0
	while i < count:
		var anchor: Vector2 = pts[randi() % pts.size()]
		var spark := Polygon2D.new()
		var r: float = randf_range(2.2, 4.6)
		spark.polygon = PackedVector2Array([
			Vector2(0.0, -r),
			Vector2(r * 0.7, 0.0),
			Vector2(0.0, r),
			Vector2(-r * 0.7, 0.0),
		])
		spark.color = SHOCK_SPARK if i % 2 == 0 else Color(0.85, 0.95, 0.35, 1.0)
		spark.position = anchor + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spark.material = mat
		host.add_child(spark)
		var dest: Vector2 = spark.position + Vector2(randf_range(-14.0, 14.0), randf_range(-18.0, 8.0))
		var tw: Tween = spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", dest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, 0.22)
		tw.set_parallel(false)
		tw.tween_callback(spark.queue_free)
		i += 1


func _fx_shock_flash(art: TextureRect) -> void:
	if art.get_meta("dissolving", false):
		return
	var tw: Tween = art.create_tween()
	tw.tween_property(art, "self_modulate", Color(1.22, 1.08, 1.30, 1.0), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(art, "self_modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _start_enemy_float(uid: String, art: TextureRect) -> void:
	if uid == "" or art == null:
		return
	_kill_float_tween(uid)
	art.set_meta("float_y", 0.0)
	var amp: float = 9.0 + randf_range(-2.0, 3.0)
	var half: float = 1.55 + randf_range(0.0, 0.5)
	var tw: Tween = create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_float_y.bind(uid), 0.0, -amp, half)
	tw.tween_method(_set_float_y.bind(uid), -amp, amp, half)
	tw.tween_method(_set_float_y.bind(uid), amp, 0.0, half)
	_float_tweens[uid] = tw


func _set_float_y(y: float, uid: String) -> void:
	var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
	if art != null and is_instance_valid(art):
		art.set_meta("float_y", y)
	_layout_enemies()

func _ensure_vfx_layer() -> void:
	if _vfx_layer != null and is_instance_valid(_vfx_layer):
		return
	_vfx_layer = Node2D.new()
	_vfx_layer.name = "VfxLayer"
	_vfx_layer.z_index = 16
	add_child(_vfx_layer)


func _fx_card_vfx(def_id: String, target_id) -> void:
	if def_id == "":
		return
	var definition: Dictionary = Cards.get_card(def_id)
	var kind: String = str(definition.get("vfx", ""))
	if kind == "":
		return
	var uids: Array = _vfx_target_uids(definition, target_id)
	if uids.is_empty():
		return
	if kind == "arrow":
		for uid in uids:
			_fx_arrow_to(str(uid))
		return
	if kind == "slash":
		for uid in uids:
			_fx_slash_on(str(uid))
		return
	if kind == "impact":
		for uid in uids:
			_fx_impact_on(str(uid))


func _vfx_target_uids(definition: Dictionary, target_id) -> Array:
	var uids: Array = []
	if str(definition.get("target", "")) == "all":
		for e in state.get("enemies", []):
			var uid: String = str(e.get("uid", ""))
			if uid == "" or str(_death_fx_done.get(uid, "")) == "gone":
				continue
			uids.append(uid)
		return uids
	if target_id != null:
		uids.append(str(target_id))
		return uids
	for e in state.get("enemies", []):
		var uid: String = str(e.get("uid", ""))
		if uid == "" or str(_death_fx_done.get(uid, "")) == "gone":
			continue
		uids.append(uid)
		break
	return uids


func _vfx_center_of(uid: String) -> Vector2:
	_ensure_vfx_layer()
	var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
	if art != null and is_instance_valid(art):
		var rect: Rect2 = art.get_global_rect()
		return _vfx_layer.to_local(rect.position + rect.size * 0.5)
	return Vector2(size.x * 0.5, size.y * 0.42)


func _vfx_fit(uid: String) -> float:
	var art: TextureRect = _enemy_art_by_uid.get(uid) as TextureRect
	if art != null and is_instance_valid(art):
		var span: float = minf(art.size.x, art.size.y)
		if span > 8.0:
			return clampf(span / 512.0, 0.18, 0.55)
	return 0.32


func _spawn_vfx_sprite(tex: Texture2D, pos: Vector2, sc: float) -> Sprite2D:
	_ensure_vfx_layer()
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = Vector2(sc, sc)
	_vfx_layer.add_child(spr)
	return spr


func _fx_impact_on(uid: String) -> void:
	_fx_impact_at(_vfx_center_of(uid), _vfx_fit(uid))


func _fx_impact_at(pos: Vector2, fit: float) -> void:
	var spr: Sprite2D = _spawn_vfx_sprite(FX_IMPACT, pos, fit * 0.32)
	spr.modulate.a = 0.95
	var tw: Tween = spr.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(fit * 1.12, fit * 1.12), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(spr.queue_free)


func _fx_slash_on(uid: String) -> void:
	var fit: float = _vfx_fit(uid) * 1.05
	var spr: Sprite2D = _spawn_vfx_sprite(FX_SLASH, _vfx_center_of(uid), fit * 0.55)
	spr.modulate.a = 0.0
	spr.flip_h = randf() < 0.5
	spr.flip_v = randf() < 0.5
	spr.rotation_degrees = randf_range(-16.0, 16.0)
	var tw: Tween = spr.create_tween()
	tw.tween_property(spr, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "scale", Vector2(fit, fit), 0.08)
	tw.tween_property(spr, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(spr.queue_free)


func _fx_arrow_to(uid: String) -> void:
	_ensure_vfx_layer()
	var dest: Vector2 = _vfx_center_of(uid)
	var start := Vector2(size.x * 0.5, size.y * 0.80)
	var spr: Sprite2D = _spawn_vfx_sprite(FX_ARROW, start, 0.34)
	var delta: Vector2 = dest - start
	if delta.length() > 1.0:
		spr.rotation = delta.angle()
	var tw: Tween = spr.create_tween()
	tw.tween_property(spr, "position", dest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_fx_arrow_land.bind(spr, dest, _vfx_fit(uid)))


func _fx_arrow_land(spr: Sprite2D, dest: Vector2, fit: float) -> void:
	if spr != null and is_instance_valid(spr):
		spr.queue_free()
	_fx_impact_at(dest, fit)
