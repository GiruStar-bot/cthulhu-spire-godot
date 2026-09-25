class_name Profile
extends RefCounted

## src/game/profile.ts 相当。PlayerProfileの純粋関数群＋セーブ/ロード。
## GameState.gd（実行中の状態）はここの関数に委譲し、計算式を二重管理しない。
##
## 参照: reference/cthulhu-spire-main/src/game/profile.ts

const MADNESS_STEP := 30
const SANITY_PENALTY_PER_TIER := 40

const SAVE_PATH := "user://cthulhu_spire_profile_v1.json"

const BASE_MAX_HP := 50
const BASE_MAX_SANITY := 50
const BASE_ENERGY := 3


static func empty_profile() -> Dictionary:
	return {
		"player_name": "",
		"best_floor": 0,
		"wins": 0,
		"runs": 0,
		"earned_points": 0,
		"unspent_points": 0,
		"compass": [],
		"transcend": [],
		"transcend_unlocked": false,
		"white_points": 0,
		"black_points": 0,
		"madness": 0,
		"sanity": null,
		"seen_rlyeh": false,
		"grimoire_read": [],
		"shells": 0,
		"starter_chosen": false,
		"collection_saved": false,
	}


## 旧仕様の到達階層換算（10層ごとに1）。現在の総ポイントは earned_points。
## この式は既存セーブを読み込むときの下限にだけ使う。
static func total_points(best_floor: int) -> int:
	return max(0, int(best_floor / 10.0))


## profile.ts の riteGain()
static func rite_gain(floor: int) -> int:
	return max(0, int(floor / 10.0))


## profile.ts の madnessTiers()
static func madness_tiers(madness: int) -> int:
	return int(max(0, madness) / float(MADNESS_STEP))


## profile.ts の madnessPenalty()
static func madness_penalty(madness: int) -> int:
	return madness_tiers(madness) * SANITY_PENALTY_PER_TIER


## ラン開始時の基礎値。bonus は Compass.bonus() の結果（羅針盤の取得済みマスの合算）。
static func derived_vitals(bonus: Dictionary, madness: int = 0) -> Dictionary:
	return {
		"max_hp": BASE_MAX_HP + int(bonus.get("max_hp", 0)),
		"max_sanity": max(0, BASE_MAX_SANITY + int(bonus.get("max_sanity", 0)) - madness_penalty(madness)),
		"strength": int(bonus.get("strength", 0)),
		"energy": BASE_ENERGY + int(bonus.get("energy", 0)),
	}


static func _non_negative_int(raw) -> int:
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return max(0, int(raw))
	return 0


## profile.ts の homeScene()：常に"title"
static func home_scene() -> String:
	return "title"


## profile.ts の loadProfile()。セーブファイルが無い/壊れている場合は空プロフィール。
## 新フィールド追加時は必ずデフォルト値を用意すること（移植時の地雷、引き継ぎ資料参照）。
static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return empty_profile()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return empty_profile()
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return empty_profile()

	var best_floor: int = max(0, int(parsed.get("best_floor", 0)))
	## 既存セーブは earned_points が階層÷10 と同じか、キーが無い。
	## ボス撃破でそれより多く貯めた値は減らさない。
	var budget: int = max(_non_negative_int(parsed.get("earned_points", 0)), total_points(best_floor))
	## 旧ステータス配分（stats）は羅針盤へ置き換えたので全て払い戻す（読み捨てる）。
	## 羅針盤は一本道として正しいマスだけ残し、総ポイントを超える分は全返却する。
	var compass: Array = Compass.sanitize(parsed.get("compass", []), Compass.ELEMENTS)
	if compass.size() > budget:
		compass = []
	var white_points: int = _non_negative_int(parsed.get("white_points", 0))
	var black_points: int = _non_negative_int(parsed.get("black_points", 0))
	var transcend: Array = Compass.sanitize(parsed.get("transcend", []), Compass.TRANSCEND_SIDES)
	if Compass.count_in(transcend, ["elder"]) > white_points or Compass.count_in(transcend, ["trickster"]) > black_points:
		transcend = []

	var sanity_raw = parsed.get("sanity")
	var sanity = null
	if typeof(sanity_raw) == TYPE_FLOAT or typeof(sanity_raw) == TYPE_INT:
		sanity = max(0, sanity_raw)

	var grimoire_read_raw = parsed.get("grimoire_read", [])
	var grimoire_read: Array = []
	if typeof(grimoire_read_raw) == TYPE_ARRAY:
		for entry in grimoire_read_raw:
			if typeof(entry) == TYPE_STRING:
				grimoire_read.append(entry)

	var profile := empty_profile()
	profile.merge(parsed, true)
	profile.erase("stats")
	profile.best_floor = best_floor
	profile.earned_points = budget
	profile.unspent_points = max(0, budget - compass.size())
	profile.compass = compass
	profile.transcend = transcend
	profile.transcend_unlocked = parsed.get("transcend_unlocked", false) == true
	profile.white_points = white_points
	profile.black_points = black_points
	profile.madness = max(0, int(parsed.get("madness", 0)))
	profile.sanity = sanity
	profile.seen_rlyeh = not not parsed.get("seen_rlyeh", false)
	profile.grimoire_read = grimoire_read
	var shells_raw = parsed.get("shells", 0)
	profile.shells = max(0, int(shells_raw)) if (typeof(shells_raw) == TYPE_FLOAT or typeof(shells_raw) == TYPE_INT) else 0
	profile.starter_chosen = (not not parsed.get("starter_chosen", true)) if typeof(parsed.get("starter_chosen")) == TYPE_BOOL else true
	return profile


## profile.ts の saveProfile()
static func save_profile(profile: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(profile))
	file.close()


## profile.ts の wipeProfile()
static func wipe_profile() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	return empty_profile()
