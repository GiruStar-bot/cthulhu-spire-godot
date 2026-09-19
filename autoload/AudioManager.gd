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
}

const SFX_PATHS := {
	"attack": "res://audio/sfx/attack.wav",
	"block": "res://audio/sfx/block.wav",
	"hurt": "res://audio/sfx/hurt.wav",
	"step": "res://audio/sfx/step.mp3",
	"lose": "res://audio/sfx/lose.mp3",
	"select": "res://audio/sfx/select.mp3",
}

var music_volume := 0.9
var sfx_volume := 1.0
var current_bgm := "none"
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}


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


func _on_bgm_finished() -> void:
	if current_bgm != "none" and _bgm_player.stream:
		_bgm_player.play()


func play_bgm_for_scene(scene_name: String) -> void:
	match scene_name:
		"title": play_bgm("title")
		"hub", "rest": play_bgm("rest")
		"combat":
			var kind := str(GameState.combat.get("kind", "combat")) if GameState.combat is Dictionary else "combat"
			play_bgm("boss" if kind == "boss" else "combat")
		"event", "blessing": play_bgm("event")
		"reward", "victory":
			play_bgm("none")
			play_sfx("reward")
		"defeat", "shatter":
			play_bgm("none")
			play_sfx("lose")
		"dream_gate": play_bgm("none")
		"dream_title": play_bgm("title")
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


func play_sfx(cue: String) -> void:
	var sample := _sample_for(cue)
	var path := str(SFX_PATHS.get(sample, ""))
	var stream := _load_stream(path)
	if stream == null or _sfx_players.is_empty():
		return
	var player := _next_sfx_player()
	player.stop()
	player.stream = stream
	player.pitch_scale = 1.0
	player.volume_db = 0.0
	if sample == "select":
		player.volume_db = -3.0
	player.play()


func play_cues(cues: Array) -> void:
	var played := {}
	for cue in cues:
		var key := str(cue)
		if not played.has(key):
			played[key] = true
			play_sfx(key)


func play_ui() -> void:
	play_sfx("select")


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
		"hit": return "attack"
		"skill", "play", "draw", "hover", "ui", "reward", "win": return "select"
		_: return cue


func _next_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players.pick_random()


func _load_stream(path: String) -> AudioStream:
	if path == "":
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
