class_name VideoSettings
extends RefCounted

## 見た目の設定（現在は「画面の揺れ・歪みを減らす」のみ）。
## Autoload を増やさず、static に保持したインスタンス 1 つで共有する。
## 保存先は音量設定（user://cthulhu_spire_audio.cfg）とは別ファイル。

signal changed(reduce_motion: bool)

const SETTINGS_PATH := "user://cthulhu_spire_video.cfg"

static var _instance: VideoSettings = null

var reduce_motion: bool = false


static func get_instance() -> VideoSettings:
	if _instance == null:
		_instance = VideoSettings.new()
		_instance._load()
	return _instance


static func is_reduce_motion() -> bool:
	return get_instance().reduce_motion


static func set_reduce_motion(enabled: bool) -> void:
	var inst: VideoSettings = get_instance()
	if inst.reduce_motion == enabled:
		return
	inst.reduce_motion = enabled
	inst._save()
	inst.changed.emit(enabled)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var raw: Variant = config.get_value("video", "reduce_motion", false)
		reduce_motion = raw == true


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "reduce_motion", reduce_motion)
	config.save(SETTINGS_PATH)
