extends Node
## audio.ts の「いつ、何を鳴らすか」を Godot の AudioStreamPlayer に置換する。
## BGM は GameState.goto_scene() から明示的に切り替え、効果音は AudioManager.play_sfx() で呼び出す。

const SETTINGS_PATH := "user://cthulhu_spire_audio.cfg"
const BGM_BUS := "BGM"
const SFX_BUS := "SFX"
const SFX_PLAYER_COUNT := 8

const BGM_PATHS := {
	"title": "res://audio/music/dunkle-herrlichkeit.mp3",
	"combat": "res://audio/music/combat.mp3",
	"boss": "res://audio/music/boss.mp3",
	"rest": "res://audio/music/rest.mp3",
	"event": "res://audio/music/event.mp3",
	"dream_title": "res://audio/music/bgm_dream_title.mp3",
	"dream_hub": "res://audio/music/bgm_dream_title.mp3",
}

const SFX_PATHS := {
	"attack": "res://audio/sfx/attack.wav",
	"block": "res://audio/sfx/sfx_block.wav",
	"hurt": "res://audio/sfx/sfx_hurt_from_enemy.wav",
	"hurt_from_enemy": "res://audio/sfx/sfx_hurt_from_enemy.wav",
	"hurt_self": "res://audio/sfx/sfx_hurt_self.wav",
	"hurt_sanity": "res://audio/sfx/sfx_hurt_sanity.wav",
	"step": "res://audio/sfx/step.mp3",
	"lose": "res://audio/sfx/lose.mp3",
	"select": "res://audio/sfx/select.mp3",
	"skill": "res://audio/sfx/sfx_skill.wav",
	"card_draw": "res://audio/sfx/sfx_paper_draw.wav",
	"paper_draw": "res://audio/sfx/sfx_paper_draw.wav",
	"gift_open": "res://audio/sfx/sfx_gift_open.wav",
	"gift_confirm": "res://audio/sfx/sfx_gift_confirm.wav",
	"gift_talk": "res://audio/sfx/sfx_gift_talk.wav",
	"gift_reveal": "res://audio/sfx/sfx_gift_reveal.wav",
	"gift_type": "res://audio/sfx/sfx_gift_type.wav",
	"vfx_impact": "res://audio/sfx/sfx_vfx_impact.wav",
	"vfx_slash": "res://audio/sfx/sfx_vfx_slash.wav",
	"vfx_arrow": "res://audio/sfx/sfx_vfx_arrow.wav",
	"cat_hiss": "res://audio/sfx/sfx_cat_hiss.wav",
	"electric": "res://audio/sfx/sfx_electric.wav",
	## パック開封（音楽くん / pack-open）
	"pack_idle": "res://audio/sfx/sfx_pack_idle.wav",
	"pack_shake": "res://audio/sfx/sfx_pack_shake.wav",
	"pack_burst": "res://audio/sfx/sfx_pack_burst.wav",
	"pack_deal": "res://audio/sfx/sfx_pack_deal.wav",
	"pack_flip": "res://audio/sfx/sfx_pack_flip.wav",
	"pack_tell": "res://audio/sfx/sfx_pack_tell.wav",
	"pack_hit_elder": "res://audio/sfx/sfx_pack_hit_elder.wav",
	"pack_hit_greatold": "res://audio/sfx/sfx_pack_hit_greatold.wav",
	"pack_hit_outer": "res://audio/sfx/sfx_pack_hit_outer.wav",
	"pack_hit_all": "res://audio/sfx/sfx_pack_hit_all.wav",
	"pack_new": "res://audio/sfx/sfx_pack_new.wav",
	"pack_done": "res://audio/sfx/sfx_pack_done.wav",
	## 共通UI・勝利
	"ui_click": "res://audio/sfx/sfx_ui_click.wav",
	"win": "res://audio/sfx/sfx_win.wav",
}

# Per-card SFX (text/image faithful). Checked before vfx bucket.
const CARD_SFX_OVERRIDES := {
	"cats_paw": "cat_hiss",
	"migo_gun": "electric",
}

var music_volume := 0.9
var sfx_volume := 1.0
var current_bgm := "none"
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _loop_player: AudioStreamPlayer
var _loop_tween: Tween
var _bgm_duck_tween: Tween
var _bgm_duck_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_ensure_bus(BGM_BUS)
	_ensure_bus(SFX_BUS)
	_apply_volumes()
	_create_players()
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group("audio_ui_button"):
		_bind_button(node)
	call_deferred("play_bgm_for_scene", str(GameState.scene))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _create_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = BGM_BUS
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)
	for index in range(SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
	## ループ効果音（パック開封待ちなど）専用。SFX バスに流す。
	_loop_player = AudioStreamPlayer.new()
	_loop_player.name = "SfxLoopPlayer"
	_loop_player.bus = SFX_BUS
	add_child(_loop_player)


func _on_bgm_finished() -> void:
	if current_bgm != "none" and _bgm_player.stream:
		_bgm_player.play()


func play_bgm_for_scene(scene_name: String) -> void:
	match scene_name:
		"title": play_bgm("title")
		"hub", "rest":
			if scene_name == "hub" and str(GameState.realm) == "dream":
				play_bgm("dream_hub")
			else:
				play_bgm("rest")
		"combat":
			var kind := str(GameState.combat.get("kind", "combat")) if GameState.combat is Dictionary else "combat"
			play_bgm("boss" if kind == "boss" else "combat")
		"event", "blessing": play_bgm("event")
		"reward", "victory":
			play_bgm("none")
			play_sfx("reward")
		"defeat", "shatter":
			# lose SFX is already played in Combat._check_result(); do not double-fire here
			play_bgm("none")
		"dream_gate": play_bgm("none")
		"dream_title": play_bgm("dream_title")
		"dream_hub": play_bgm("dream_hub")
		_: play_bgm("none")


func play_bgm(id: String) -> void:
	if id == current_bgm:
		return
	current_bgm = id
	_bgm_player.stop()
	if id == "none":
		return
	var path := str(BGM_PATHS.get(id, ""))
	var stream := _load_stream(path)
	if stream:
		_bgm_player.stream = stream
		_bgm_player.play()


func stop_bgm() -> void:
	play_bgm("none")



func resolve_card_sfx(def_id: String, card_type: String, vfx_kind: String = "") -> String:
	if CARD_SFX_OVERRIDES.has(def_id):
		return str(CARD_SFX_OVERRIDES[def_id])
	if card_type != "attack":
		return "skill"
	match vfx_kind:
		"slash":
			return "vfx_slash"
		"arrow":
			return "vfx_arrow"
		_:
			return "vfx_impact"

## pitch_scale を渡すと音程を変えて鳴らす（パックの揺れ・配りで段階的に上げる用）。
## 省略時（0 以下）は従来どおり 1.0。
func play_sfx(cue: String, pitch_scale: float = 0.0) -> void:
	var sample := _sample_for(cue)
	var path := str(SFX_PATHS.get(sample, ""))
	var stream := _load_stream(path)
	if stream == null or _sfx_players.is_empty():
		return
	var player := _next_sfx_player()
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch_scale if pitch_scale > 0.0 else 1.0
	## gift_type: Undertale-ish blip with light pitch jitter (±5%)
	if sample == "gift_type":
		player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = 0.0
	if sample in ["select", "skill", "card_draw"]:
		player.volume_db = -3.0
	player.play()


func play_cues(cues: Array) -> void:
	var played := {}
	for cue in cues:
		var key := str(cue)
		if not played.has(key):
			played[key] = true
			play_sfx(key)


## ボタン確定音。専用の ui_click があればそれ、無ければ従来の select。
## ホバーでは鳴らさない（pressed にだけ繋いでいる）。
func play_ui() -> void:
	if has_sfx("ui_click"):
		play_sfx("ui_click")
	else:
		play_sfx("select")


## キーが登録済みで、ファイルも読み込めるか。
func has_sfx(cue: String) -> bool:
	var path := str(SFX_PATHS.get(_sample_for(cue), ""))
	return path != "" and ResourceLoader.exists(path)


## ループ効果音を 1 本だけ鳴らす（既に同じものが鳴っていれば何もしない）。
## WAV は取り込み設定に関係なく、ここで前方ループに切り替える。
func play_sfx_loop(cue: String, fade_in_s: float = 0.0) -> void:
	var path := str(SFX_PATHS.get(_sample_for(cue), ""))
	var stream := _load_stream(path)
	if stream == null or _loop_player == null:
		return
	_kill_loop_tween()
	var looped := _make_looping(stream)
	if _loop_player.playing and _loop_player.stream == looped:
		_loop_player.volume_db = 0.0
		return
	_loop_player.stop()
	_loop_player.stream = looped
	_loop_player.volume_db = -40.0 if fade_in_s > 0.0 else 0.0
	_loop_player.play()
	if fade_in_s > 0.0:
		_loop_tween = create_tween()
		_loop_tween.tween_property(_loop_player, "volume_db", 0.0, fade_in_s)


## ループ効果音を止める。fade_out_s 秒かけて下げてから停止する。
func stop_sfx_loop(fade_out_s: float = 0.1) -> void:
	if _loop_player == null or not _loop_player.playing:
		return
	_kill_loop_tween()
	if fade_out_s <= 0.0:
		_loop_player.stop()
		return
	_loop_tween = create_tween()
	_loop_tween.tween_property(_loop_player, "volume_db", -40.0, fade_out_s)
	_loop_tween.tween_callback(_loop_player.stop)


## BGM を一時的に下げる（パック開封中など）。音量設定（バス）とは別に、プレイヤー側で下げる。
func duck_bgm(db: float = -12.0, fade_s: float = 0.2) -> void:
	_tween_bgm_duck(db, fade_s)


## duck_bgm で下げた BGM を戻す。
func restore_bgm(fade_s: float = 0.5) -> void:
	_tween_bgm_duck(0.0, fade_s)


func _tween_bgm_duck(target_db: float, fade_s: float) -> void:
	_bgm_duck_db = target_db
	if _bgm_duck_tween != null and _bgm_duck_tween.is_valid():
		_bgm_duck_tween.kill()
	if _bgm_player == null:
		return
	if fade_s <= 0.0:
		_bgm_player.volume_db = target_db
		return
	_bgm_duck_tween = create_tween()
	_bgm_duck_tween.tween_property(_bgm_player, "volume_db", target_db, fade_s)


func _kill_loop_tween() -> void:
	if _loop_tween != null and _loop_tween.is_valid():
		_loop_tween.kill()
	_loop_tween = null


func _make_looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			return wav
		var key := "loop::%s" % wav.resource_path
		if _sfx_streams.has(key):
			return _sfx_streams[key] as AudioStream
		var copy := wav.duplicate() as AudioStreamWAV
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		copy.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
		_sfx_streams[key] = copy
		return copy
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func get_music_volume() -> float:
	return music_volume


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func get_sfx_volume() -> float:
	return sfx_volume


func _sample_for(cue: String) -> String:
	match cue:
		"hit":
			return "vfx_impact"
		"attack":
			return "vfx_impact"
		"hurt":
			return "hurt_from_enemy"
		"draw":
			return "paper_draw"
		"play", "hover", "ui", "reward":
			return "select"
		_:
			return cue


func _next_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players.pick_random()


func _load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	## 未ベイク / 欠落ファイルは soft-fail（音楽くん作業中でも落ちない）
	if not ResourceLoader.exists(path):
		return null
	if not _sfx_streams.has(path):
		_sfx_streams[path] = load(path)
	var stream = _sfx_streams[path]
	return stream as AudioStream


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		call_deferred("_bind_button", node)


func _bind_button(node: Node) -> void:
	if not is_instance_valid(node) or not (node is BaseButton):
		return
	if node.has_meta("audio_manager_bound"):
		return
	node.set_meta("audio_manager_bound", true)
	node.pressed.connect(play_ui)


func _apply_volumes() -> void:
	var bgm_index := AudioServer.get_bus_index(BGM_BUS)
	var sfx_index := AudioServer.get_bus_index(SFX_BUS)
	if bgm_index >= 0:
		AudioServer.set_bus_volume_db(bgm_index, linear_to_db(maxf(music_volume, 0.0001)))
	if sfx_index >= 0:
		AudioServer.set_bus_volume_db(sfx_index, linear_to_db(maxf(sfx_volume * sfx_volume * 0.8, 0.0001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)


# ---------------------------------------------------------------------------
# 正気度の音（feat/sanity-fx）
# パック開封用の SfxLoopPlayer とは別に、専用のプレイヤーを持つ。
#  - 持続音 sanity_low_1〜3: 2 本の AudioStreamPlayer を交互に使ってクロスフェード。
#  - 一発音 sanity_pay / sanity_hit: 専用 1 本を stop → play で鳴らし直す（重ねない）。
# キーが SFX_PATHS に無い、またはファイルが読めない場合は何もしない。
# ---------------------------------------------------------------------------

const SANITY_DRONE_FADE := 0.8
const SANITY_DRONE_SILENT_DB := -40.0

var _sanity_drone_players: Array[AudioStreamPlayer] = []
var _sanity_drone_active: int = 0
var _sanity_drone_tier: int = 0
var _sanity_drone_tweens: Array[Tween] = [null, null]
var _sanity_sfx_player: AudioStreamPlayer


## 正気度の一発音を専用プレイヤーで鳴らす。連続で呼ばれても重ねず、頭から鳴らし直す。
## 鳴らせた場合 true。
func play_sanity_sfx(cue: String) -> bool:
	var stream: AudioStream = _sanity_stream(cue)
	if stream == null:
		return false
	if _sanity_sfx_player == null:
		_sanity_sfx_player = AudioStreamPlayer.new()
		_sanity_sfx_player.name = "SanitySfxPlayer"
		_sanity_sfx_player.bus = SFX_BUS
		add_child(_sanity_sfx_player)
	_sanity_sfx_player.stop()
	_sanity_sfx_player.stream = stream
	_sanity_sfx_player.play()
	return true


## 低い状態の持続音を段階 tier（1〜3）に切り替える。0 以下なら止める。
## 段階が変わるたびに SANITY_DRONE_FADE 秒でクロスフェード（上がる時も下がる時も）。
func play_sanity_drone(tier: int) -> void:
	if tier <= 0:
		stop_sanity_drone()
		return
	if tier == _sanity_drone_tier and _sanity_drone_is_playing():
		return
	var stream: AudioStream = _sanity_stream("sanity_low_%d" % tier)
	if stream == null:
		stop_sanity_drone()
		return
	_ensure_sanity_drone_players()
	_sanity_drone_tier = tier
	var old_index: int = _sanity_drone_active
	var new_index: int = 1 - old_index
	var new_p: AudioStreamPlayer = _sanity_drone_players[new_index]
	_fade_sanity_drone(old_index, SANITY_DRONE_SILENT_DB, SANITY_DRONE_FADE, true)
	new_p.stop()
	new_p.stream = _make_looping(stream)
	new_p.volume_db = SANITY_DRONE_SILENT_DB
	new_p.play()
	_fade_sanity_drone(new_index, 0.0, SANITY_DRONE_FADE, false)
	_sanity_drone_active = new_index


## 持続音を止める（戦闘の外・敗北演出・勝利時）。
func stop_sanity_drone(fade_out_s: float = 0.4) -> void:
	_sanity_drone_tier = 0
	if _sanity_drone_players.is_empty():
		return
	for index in range(_sanity_drone_players.size()):
		var p: AudioStreamPlayer = _sanity_drone_players[index]
		if p.playing:
			_fade_sanity_drone(index, SANITY_DRONE_SILENT_DB, fade_out_s, true)


## テスト・デバッグ用：今鳴っている持続音の段階（0 = 無音）。
func get_sanity_drone_tier() -> int:
	return _sanity_drone_tier if _sanity_drone_is_playing() else 0


func _sanity_drone_is_playing() -> bool:
	if _sanity_drone_players.is_empty():
		return false
	return _sanity_drone_players[_sanity_drone_active].playing


func _ensure_sanity_drone_players() -> void:
	if not _sanity_drone_players.is_empty():
		return
	for index in range(2):
		var p := AudioStreamPlayer.new()
		p.name = "SanityDrone%d" % index
		p.bus = SFX_BUS
		p.volume_db = SANITY_DRONE_SILENT_DB
		add_child(p)
		_sanity_drone_players.append(p)


func _fade_sanity_drone(index: int, target_db: float, fade_s: float, stop_after: bool) -> void:
	var old_tween: Tween = _sanity_drone_tweens[index]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var p: AudioStreamPlayer = _sanity_drone_players[index]
	if fade_s <= 0.0:
		p.volume_db = target_db
		if stop_after:
			p.stop()
		_sanity_drone_tweens[index] = null
		return
	var tw: Tween = create_tween()
	tw.tween_property(p, "volume_db", target_db, fade_s)
	if stop_after:
		tw.tween_callback(p.stop)
	_sanity_drone_tweens[index] = tw


func _sanity_stream(cue: String) -> AudioStream:
	if not SFX_PATHS.has(cue):
		return null
	return _load_stream(str(SFX_PATHS[cue]))
