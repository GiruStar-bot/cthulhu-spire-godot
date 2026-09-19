extends Node

## 所持カード／UI枠テクスチャのキャッシュ。Hub 売却・デッキ一覧が毎回
## ResourceLoader.load で冷えるのを防ぐ。GameState.begin 後に warm_for_collection()。

signal warm_progress(done: int, total: int)
signal warm_finished()

const CARD_BACK := "res://art/pixel/ui/card_back.png"
const SHARED_UI_FRAMES: Array[String] = [
	"res://art/pixel/ui/card_back.png",
	"res://art/pixel/ui/card_back_pack.png",
	"res://art/pixel/ui/frame_card_9.png",
	"res://art/pixel/ui/frame_card_common_9.png",
	"res://art/pixel/ui/frame_card_uncommon_9.png",
	"res://art/pixel/ui/frame_card_elder_9.png",
	"res://art/pixel/ui/frame_card_greatold_9.png",
	"res://art/pixel/ui/frame_card_outer_9.png",
	"res://art/pixel/ui/frame_card_all_9.png",
]

var _cache: Dictionary = {}  ## path(String) -> Texture2D
var _is_warming: bool = false
var _warm_done: int = 0
var _warm_total: int = 0
var _pending_threaded: Array = []  ## path strings awaiting load_threaded_get


func is_warming() -> bool:
	return _is_warming


func get_progress() -> Dictionary:
	return {"done": _warm_done, "total": _warm_total}


## キャッシュ命中なら再利用。ミス時は CACHE_MODE_REUSE で同期ロードして格納。
## 存在しない／非 Texture2D の場合は null（呼び出し側でフォールバック）。
func get_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var resolved: String = _resolve_path(path)
	if resolved.is_empty():
		return null
	if _cache.has(resolved):
		return _cache[resolved] as Texture2D
	if not ResourceLoader.exists(resolved, "Texture2D"):
		return null
	var resource: Resource = ResourceLoader.load(resolved, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if resource is Texture2D:
		var tex: Texture2D = resource as Texture2D
		_cache[resolved] = tex
		if path != resolved:
			_cache[path] = tex
		return tex
	push_warning("ArtCache: Texture2Dとして読み込めませんでした: %s" % resolved)
	return null


func has_cached(path: String) -> bool:
	var resolved: String = _resolve_path(path)
	return _cache.has(resolved) or _cache.has(path)


func clear_cache() -> void:
	_cache.clear()


## 同期ウォーム。paths を順に get_texture する。
func warm_paths(paths: Array) -> void:
	var unique: Dictionary = {}
	for raw in paths:
		var p: String = str(raw)
		if p.is_empty():
			continue
		unique[_resolve_path(p)] = true
	_warm_total = unique.size()
	_warm_done = 0
	_is_warming = true
	for path_key in unique.keys():
		var path: String = str(path_key)
		if not path.is_empty():
			get_texture(path)
		_warm_done += 1
		warm_progress.emit(_warm_done, _warm_total)
	_is_warming = false
	warm_finished.emit()


## スレッド要求バッチ。呼び出し後は await_warm() か process_frame ループで待つ。
func warm_paths_threaded(paths: Array) -> void:
	var unique: Dictionary = {}
	for raw in paths:
		var p: String = str(raw)
		if p.is_empty():
			continue
		var resolved: String = _resolve_path(p)
		if resolved.is_empty() or _cache.has(resolved):
			continue
		if not ResourceLoader.exists(resolved, "Texture2D"):
			continue
		unique[resolved] = true
	_pending_threaded.clear()
	for path_key in unique.keys():
		var path: String = str(path_key)
		var err: Error = ResourceLoader.load_threaded_request(path, "Texture2D", true)
		if err == OK:
			_pending_threaded.append(path)
	_warm_total = _pending_threaded.size()
	_warm_done = 0
	_is_warming = _warm_total > 0
	if not _is_warming:
		warm_finished.emit()


## 1フレーム分のスレッド完了を回収。true = まだ残りあり。
func poll_threaded_warm() -> bool:
	if not _is_warming:
		return false
	var still: Array = []
	for path_variant in _pending_threaded:
		var path: String = str(path_variant)
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource is Texture2D:
				_cache[path] = resource as Texture2D
			_warm_done += 1
			warm_progress.emit(_warm_done, _warm_total)
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			still.append(path)
		else:
			_warm_done += 1
			warm_progress.emit(_warm_done, _warm_total)
	_pending_threaded = still
	if _pending_threaded.is_empty():
		_is_warming = false
		warm_finished.emit()
		return false
	return true


## CollectionData 所持カードの art + 共有 UI 枠をウォーム（同期）。
func warm_for_collection() -> void:
	var paths: Array = _collect_owned_art_paths()
	warm_paths(paths)


## 所持数が多めのとき用。begin 側で await_warm() と組み合わせる。
func warm_for_collection_threaded() -> void:
	var paths: Array = _collect_owned_art_paths()
	warm_paths_threaded(paths)


## スレッドウォーム完了まで process_frame で待つ（呼び出し元が Node のとき用）。
func await_warm() -> void:
	while _is_warming:
		poll_threaded_warm()
		await get_tree().process_frame


func _collect_owned_art_paths() -> Array:
	var paths: Array = []
	var seen: Dictionary = {}

	for frame_path in SHARED_UI_FRAMES:
		_add_path(paths, seen, frame_path)

	if CollectionData == null:
		return paths

	var owned: Dictionary = CollectionData.owned_card_counts()
	for card_id_variant in owned.keys():
		var card_id: String = str(card_id_variant)
		var def: Dictionary = Cards.get_card(card_id)
		if def.is_empty():
			continue
		var art: String = str(def.get("art", ""))
		_add_path(paths, seen, art)

	## 装備に art フィールドが付いている場合のみ（現行定義は未設定でも安全）
	for inst in CollectionData.inventory.equipment:
		if not (inst is Dictionary):
			continue
		var def_id: String = str(inst.get("def_id", ""))
		if def_id.is_empty():
			continue
		var eq: Dictionary = Equipment.get_equipment(def_id)
		var eq_art: String = str(eq.get("art", ""))
		_add_path(paths, seen, eq_art)
		## 慣例パスも試す（存在しなければ warm 時にスキップ）
		_add_path(paths, seen, "res://art/pixel/equipment/%s.jpg" % def_id)
		_add_path(paths, seen, "res://art/pixel/equipment/%s.png" % def_id)

	return paths


func _add_path(paths: Array, seen: Dictionary, path: String) -> void:
	if path.is_empty():
		return
	var resolved: String = _resolve_path(path)
	if resolved.is_empty() or seen.has(resolved):
		return
	seen[resolved] = true
	paths.append(resolved)


func _resolve_path(path: String) -> String:
	if path.is_empty():
		return ""
	## Cards.resolve_art は未配置 jpg を同系統フォールバックへ逃がす
	return Cards.resolve_art(path)
