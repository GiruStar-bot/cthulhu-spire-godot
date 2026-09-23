class_name Profile
extends RefCounted

## src/game/profile.ts 相当。PlayerProfileの純粋関数群＋セーブ/ロード。
## GameState.gd（実行中の状態）はここの関数に委譲し、計算式を二重管理しない。
##
## 参照: reference/cthulhu-spire-main/src/game/profile.ts

const STAT_MIN := 0
const STAT_KEYS := ["hp", "san", "intelligent", "strength", "energy"]
const MADNESS_STEP := 30
const SANITY_PENALTY_PER_TIER := 40
const GRIMOIRE_MIND := 11
const GRIMOIRE_ENABLED := false  ## 実ソースで無効化済み。移植でも無効のまま踏襲する。

const SAVE_PATH := "user://cthulhu_spire_profile_v1.json"


static func empty_stats() -> Dictionary:
	return {"hp": 0, "san": 0, "intelligent": 0, "strength": 0, "energy": 0}


static func empty_profile() -> Dictionary:
	return {
		"player_name": "",
		"stats": empty_stats(),
		"best_floor": 0,
		"wins": 0,
		"runs": 0,
		"earned_points": 0,
		"unspent_points": 0,
		"madness": 0,
		"sanity": null,
		"seen_rlyeh": false,
		"grimoire_read": [],
		"equipped": {},
		"shells": 0,
		"equipment_presets": {},
		"starter_chosen": false,
		"collection_saved": false,
	}


## profile.ts の statSum()
static func stat_sum(stats: Dictionary) -> int:
	var total := 0
	for key in STAT_KEYS:
		total += max(0, int(stats.get(key, 0)))
	return total


## profile.ts の totalPoints(): 10層ごとに1ポイント
static func total_points(best_floor: int) -> int:
	return max(0, int(best_floor / 10.0))


## profile.ts の statBudget()：totalPoints()のエイリアス
static func stat_budget(best_floor: int) -> int:
	return total_points(best_floor)


## profile.ts の riteGain()
static func rite_gain(floor: int) -> int:
	return max(0, int(floor / 10.0))


## profile.ts の clampStats()
static func clamp_stats(stats: Dictionary) -> Dictionary:
	if stats.has("hp") or stats.has("san") or stats.has("strength"):
		return {
			"hp": max(STAT_MIN, int(stats.get("hp", 0))),
			"san": max(STAT_MIN, int(stats.get("san", 0))),
			"intelligent": max(STAT_MIN, int(stats.get("intelligent", 0))),
			"strength": max(STAT_MIN, int(stats.get("strength", 0))),
			"energy": max(STAT_MIN, int(stats.get("energy", 0))),
		}
	return empty_stats()


## profile.ts の madnessTiers()
static func madness_tiers(madness: int) -> int:
	return int(max(0, madness) / float(MADNESS_STEP))


## profile.ts の madnessPenalty()
static func madness_penalty(madness: int) -> int:
	return madness_tiers(madness) * SANITY_PENALTY_PER_TIER


## profile.ts の derivedVitals()
static func derived_vitals(stats: Dictionary, madness: int = 0) -> Dictionary:
	return {
		"max_hp": 50 + int(stats.get("hp", 0)) * 2,
		"max_sanity": max(0, 50 + int(stats.get("san", 0)) * 2 - madness_penalty(madness)),
		"intelligent": int(int(stats.get("intelligent", 0)) / 5.0),
		"strength": int(int(stats.get("strength", 0)) / 5.0),
		"energy": 3 + int(int(stats.get("energy", 0)) / 10.0),
	}


## profile.ts の statFinal()
static func stat_final(key: String, sp: int, madness: int = 0) -> int:
	if key == "hp":
		return 50 + sp * 2
	if key == "san":
		return max(0, 50 + sp * 2 - madness_penalty(madness))
	if key == "energy":
		return 3 + int(sp / 10.0)
	return int(sp / 5.0)


## profile.ts の statBase()
static func stat_base(key: String, madness: int = 0) -> int:
	return stat_final(key, 0, madness)


## profile.ts の grimoireOpen()：GRIMOIRE_ENABLEDがfalseなので常にfalse
static func grimoire_open(stats: Dictionary) -> bool:
	return GRIMOIRE_ENABLED and int(stats.get("san", 0)) >= GRIMOIRE_MIND


## profile.ts の unlockedFeatures()
static func unlocked_features(stats: Dictionary) -> Array:
	var out: Array = []
	if int(stats.get("hp", 0)) >= 6:
		out.append("重鎧の適性")
	if int(stats.get("san", 0)) >= 6:
		out.append("禁断の術の萌芽")
	if int(stats.get("strength", 0)) >= 6:
		out.append("儀式の耐性")
	if int(stats.get("hp", 0)) >= 8:
		out.append("筋肉による解決")
	if int(stats.get("intelligent", 0)) >= 8:
		out.append("理解による代償の制御")
	return out


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

	var stats: Dictionary = clamp_stats(parsed.get("stats", empty_stats()))
	var best_floor: int = max(0, int(parsed.get("best_floor", 0)))
	var budget: int = total_points(best_floor)
	var fitted: Dictionary = empty_stats() if stat_sum(stats) > budget else stats

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
	profile.stats = fitted
	profile.best_floor = best_floor
	profile.earned_points = budget
	profile.unspent_points = max(0, budget - stat_sum(fitted))
	profile.madness = max(0, int(parsed.get("madness", 0)))
	profile.sanity = sanity
	profile.seen_rlyeh = not not parsed.get("seen_rlyeh", false)
	profile.grimoire_read = grimoire_read
	profile.equipped = parsed.get("equipped", {})
	var shells_raw = parsed.get("shells", 0)
	profile.shells = max(0, int(shells_raw)) if (typeof(shells_raw) == TYPE_FLOAT or typeof(shells_raw) == TYPE_INT) else 0
	profile.equipment_presets = parsed.get("equipment_presets", {})
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
