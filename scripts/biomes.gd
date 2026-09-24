class_name Biomes
extends RefCounted

## src/game/biomes.ts の忠実移植。

const BIOMES := {
	"reef": {"id": "reef", "name": "礁の層", "art": "res://art/pixel/bg/reef.jpg"},
	"street": {"id": "street", "name": "沈んだ街", "art": "res://art/pixel/bg/street.jpg"},
	"mu": {"id": "mu", "name": "ムーの残骸", "art": "res://art/pixel/bg/mu.jpg"},
	"fold": {"id": "fold", "name": "曲がる石", "art": "res://art/pixel/bg/fold.jpg"},
	"throne": {"id": "throne", "name": "緑の広間", "art": "res://art/pixel/bg/throne.jpg"},
	"void": {"id": "void", "name": "外宇宙", "art": "res://art/pixel/bg/void.jpg"},
	"colour": {"id": "colour", "name": "色の井戸", "art": "res://art/pixel/bg/colour.jpg"},
	"shrine": {"id": "shrine", "name": "教団の間", "art": "res://art/pixel/bg/shrine.jpg"},
	"beyond": {"id": "beyond", "name": "時空の狭間", "art": "res://art/pixel/bg/beyond.jpg"},
	## アイホートくんの迷路。イベント画面と同じ背景のまま戦闘を続けるための専用バイオーム。
	"labyrinth": {"id": "labyrinth", "name": "迷路", "art": "res://art/pixel/events/eihort_labyrinth.png"},
	## dream_hub.jpg が無い場合は dream_title.png にフォールバック
	"dream_hub": {"id": "dream_hub", "name": "夢の島拠点", "art": "res://art/pixel/bg/dream_hub.jpg"},
}

const DEPTH := ["reef", "street", "mu", "fold", "throne"]


static func biome_for_floor(current_floor: int) -> String:
	if current_floor >= 80:
		return "throne"
	if current_floor >= 60:
		return "fold"
	if current_floor >= 40:
		return "mu"
	if current_floor >= 20:
		return "street"
	return "reef"


static func biome_for_encounter(enemy_ids: Array, current_floor: int) -> String:
	var ids: Array = []
	for enemy_id in enemy_ids:
		var def: Dictionary = Enemies.get_enemy(str(enemy_id))
		var biome: String = str(def.get("biome", ""))
		if biome != "":
			ids.append(biome)
	if ids.has("labyrinth"):
		return "labyrinth"
	if ids.has("colour"):
		return "colour"
	if ids.has("void"):
		return "void"
	if ids.has("shrine"):
		return "shrine"
	if ids.has("beyond"):
		return "beyond"
	var best: String = ""
	var best_d: int = -1
	for biome in ids:
		var d: int = DEPTH.find(biome)
		if d > best_d:
			best = biome
			best_d = d
	if best != "":
		return best
	return biome_for_floor(current_floor)


static func biome_art(biome_id: String) -> String:
	var def: Dictionary = BIOMES.get(biome_id, {})
	return str(def.get("art", "res://art/pixel/bg/reef.jpg"))


static func biome_name(biome_id: String) -> String:
	var def: Dictionary = BIOMES.get(biome_id, {})
	return str(def.get("name", biome_id))
