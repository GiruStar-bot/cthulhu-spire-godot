class_name Enemies
extends RefCounted

## combat.ts が import する getEnemy() のため、enemies.ts のカタログ＋getEnemy を最小移植。

## ドット立ち絵。本体1コマ128×224、効果1コマ128×288（上64は頭上の余白）。横8コマ。
## 0待機A 1待機B 2〜7カード使用。sprite は接頭辞で、実ファイルは <sprite>_body_1.png など。
const PX_BODY_W := 128
const PX_BODY_H := 224
const PX_FX_W := 128
const PX_FX_H := 288
const PX_FX_TOP := 64
const PX_FRAME_COUNT := 8

const ENEMIES := {
	"acolyte": {
		"id": "acolyte",
		"name": "侍祭",
		"art": "res://art/pixel/acolyte.png",
		"poster": "res://art/pixel/acolyte.png",
		"sprite": "res://art/pixel/enemies_px/acolyte",
		"biome": "shrine",
		"maxHp": 32,
		"archetype": "fanatic",
	},
	"fanatic": {
		"id": "fanatic",
		"name": "狂信者",
		"art": "res://art/pixel/fanatic.png",
		"poster": "res://art/pixel/fanatic.png",
		"sprite": "res://art/pixel/enemies_px/fanatic",
		"biome": "shrine",
		"maxHp": 42,
		"tier": "elite",
		"archetype": "fanatic",
	},
	"drowned": {
		"id": "drowned",
		"name": "溺れた眷属",
		"art": "res://art/pixel/drowned.png",
		"poster": "res://art/pixel/drowned.png",
		"biome": "reef",
		"maxHp": 44,
		"archetype": "poison",
	},
	"byakhee": {
		"id": "byakhee",
		"name": "翼ある飢え",
		"art": "res://art/pixel/byakhee.png",
		"poster": "res://art/pixel/byakhee.png",
		"biome": "void",
		"maxHp": 38,
		"tier": "elite",
		"archetype": "outer",
		"floats": true,
	},
	"coral": {
		"id": "coral",
		"name": "礁の衛士",
		"art": "res://art/pixel/coral.png",
		"poster": "res://art/pixel/coral.png",
		"biome": "reef",
		"maxHp": 48,
		"tier": "elite",
		"archetype": "knight",
	},
	"starveling": {
		"id": "starveling",
		"name": "飢えし仔",
		"art": "res://art/pixel/starveling.png",
		"poster": "res://art/pixel/starveling.png",
		"biome": "reef",
		"maxHp": 86,
		"tier": "elite",
		"archetype": "water",
	},
	"serpent": {
		"id": "serpent",
		"name": "ムーの蛇人",
		"art": "res://art/pixel/serpent.png",
		"poster": "res://art/pixel/serpent.png",
		"biome": "mu",
		"maxHp": 54,
		"archetype": "water",
	},
	"spawn": {
		"id": "spawn",
		"name": "ガタノトアの落とし子",
		"art": "res://art/pixel/spawn.png",
		"poster": "res://art/pixel/spawn.png",
		"biome": "mu",
		"maxHp": 62,
		"archetype": "outer",
	},
	"migo": {
		"id": "migo",
		"name": "ミーゴ",
		"art": "res://art/pixel/migo.png",
		"poster": "res://art/pixel/migo.png",
		"biome": "void",
		"maxHp": 40,
		"archetype": "outer",
		"floats": true,
	},
	"colour": {
		"id": "colour",
		"name": "星から来た色",
		"art": "res://art/pixel/colour.png",
		"poster": "res://art/pixel/colour.png",
		"biome": "colour",
		"maxHp": 48,
		"archetype": "outer",
	},
	"starvamp": {
		"id": "starvamp",
		"name": "星の吸血獣",
		"art": "res://art/pixel/starvamp.png",
		"poster": "res://art/pixel/starvamp.png",
		"biome": "void",
		"maxHp": 56,
		"tier": "elite",
		"archetype": "outer",
		"floats": true,
	},
	"shan": {
		"id": "shan",
		"name": "シャガイの昆虫",
		"art": "res://art/pixel/shan.png",
		"poster": "res://art/pixel/shan.png",
		"biome": "void",
		"maxHp": 36,
		"archetype": "outer",
		"floats": true,
	},
	"priest": {
		"id": "priest",
		"name": "尖塔の大司祭",
		"art": "res://art/pixel/priest.png",
		"poster": "res://art/pixel/priest.png",
		"sprite": "res://art/pixel/enemies_px/priest",
		"px": {"body_w": 91, "body_h": 162, "fx_top": 48, "body_frames": 10},
		"biome": "shrine",
		"maxHp": 168,
		"archetype": "fanatic",
		"signatureCardId": "revelation",
		"cardsPerTurn": 2,
		"deck": ["revelation", "lash", "bash", "ward", "chant"],
	},
	"choir": {
		"id": "choir",
		"name": "塩の唱者",
		"art": "res://art/pixel/choir.png",
		"poster": "res://art/pixel/choir.png",
		"biome": "street",
		"maxHp": 42,
		"trait": "choir",
		"archetype": "shadow",
		"signatureCardId": "chorusunity",
		"cardsPerTurn": 2,
		"deck": ["chorusunity", "strike", "sigil", "rite"],
	},
	"nurse": {
		"id": "nurse",
		"name": "深きものの乳母",
		"art": "res://art/pixel/nurse.png",
		"poster": "res://art/pixel/nurse.png",
		"biome": "reef",
		"maxHp": 112,
		"trait": "nurse",
		"archetype": "poison",
		"signatureCardId": "embrace",
		"cardsPerTurn": 2,
		"deck": ["embrace", "dressing", "bash", "all-vacuum"],
	},
	"flock": {
		"id": "flock",
		"name": "飢えた翼",
		"art": "res://art/pixel/flock.png",
		"poster": "res://art/pixel/flock.png",
		"biome": "reef",
		"maxHp": 52,
		"archetype": "water",
		"floats": true,
		"signatureCardId": "flockrush",
		"cardsPerTurn": 2,
		"deck": ["flockrush", "lash", "all-glass", "ward"],
	},
	## 60階ボス。毎ターン寒気を積み上げてくるので短期決戦を迫る（trait "windwalker"）。
	## 神話の固有名は画面に出さない方針。表示名は二つ名だけ。
	"ithaqua": {
		"id": "ithaqua",
		"dev_name": "イタカ",  ## 開発用の呼び名。画面には出さない
		"name": "風に乗りて歩むもの",
		"art": "res://art/pixel/enemies/ithaqua.png",
		"poster": "res://art/pixel/enemies/ithaqua.png",
		"biome": "fold",  ## 仮。専用背景は後日
		"maxHp": 120,
		"trait": "windwalker",
		"floats": true,
		"signatureCardId": "sky_snatch",
		"cardsPerTurn": 2,
		"deck": ["sky_snatch", "frost_breath", "gale_claw", "flockrush"],
	},
	## 70階ボス。3の倍数ターンは満潮で、1枚目が必ず大海嘯になる（trait "tide"）。
	## HP50%以下で一度だけ溺れた眷属を1体呼ぶ。神話の固有名は画面に出さない方針。
	"dagon": {
		"id": "dagon",
		"dev_name": "ダゴン",  ## 開発用の呼び名。画面には出さない
		"name": "深みの父",
		"art": "res://art/pixel/enemies/dagon.png",
		"poster": "res://art/pixel/enemies/dagon.png",
		"biome": "street",
		"maxHp": 140,
		"trait": "tide",
		"signatureCardId": "great_surge",
		"cardsPerTurn": 2,
		"deck": ["great_surge", "abyss_grasp", "brine_hide", "sea"],
	},
	"nyar": {
		"id": "nyar",
		"name": "門番ナイアルラト",
		"art": "res://art/pixel/nyar.png",
		"poster": "res://art/pixel/nyar.png",
		"biome": "throne",
		"maxHp": 124,
		"archetype": "shadow",
		"signatureCardId": "pricewisdom",
		"cardsPerTurn": 2,
		"deck": ["pricewisdom", "all-necrosis", "rite", "all-vacuum", "eldersign", "evil_eye_bind", "silent_bind"],
	},
	"iha": {
		"id": "iha",
		"name": "緑の腐肉、イハ",
		"art": "res://art/pixel/iha.png",
		"poster": "res://art/pixel/iha.png",
		"biome": "throne",
		"maxHp": 96,
		"trait": "split",
		"archetype": "greatold",
		"signatureCardId": "protosurge",
		"cardsPerTurn": 2,
		"deck": ["protosurge", "all-geo", "all-glass", "ironwill", "all-zero"],
	},
	"herald": {
		"id": "herald",
		"name": "呼び声の使徒",
		"art": "res://art/pixel/herald.png",
		"poster": "res://art/pixel/herald.png",
		"biome": "throne",
		"maxHp": 214,
		"archetype": "offering",
		"signatureCardId": "heraldscall",
		"cardsPerTurn": 2,
		"deck": ["heraldscall", "thecall", "all-zero", "ironwill", "eldersign"],
	},
	"yog_sothoth": {
		"id": "yog_sothoth",
		"name": "全なる者",
		"art": "res://art/pixel/yog_sothoth.png",
		"poster": "res://art/pixel/yog_sothoth.png",
		"biome": "beyond",
		"maxHp": 9999,
		"signatureCardId": "thecall",
		"cardsPerTurn": 3,
		"deck": ["eldersign", "star_sword", "yog_gun", "blood_toll", "tower_shield", "cthulhu_mail", "self_offering", "perfect_stealth", "deep_ones_blessing", "thecall", "silver_key", "collapse", "omnipotence", "transcendent"],
	},
	## イベント「アイホートくん」の「戦う」からだけ出る（ランダム遭遇には出ない）。
	"eihort": {
		"id": "eihort",
		"dev_name": "アイホートくん",  ## 開発用の呼び名。画面には出さない
		"name": "？？？",  ## 敵名欄・戦闘ログに出る表示名
		"art": "res://art/pixel/enemies/eihort.png",
		"poster": "res://art/pixel/enemies/eihort.png",
		"biome": "labyrinth",  ## イベントと同じ迷路背景で戦う（Biomes.biome_for_encounter で最優先）
		"maxHp": 35,
		"deck": ["child_bearing"],
	},
	"treasure_wanderer": {
		"id": "treasure_wanderer",
		"name": "宝殻の徘徊者",
		"art": "res://art/pixel/treasure_wanderer.png",
		"poster": "res://art/pixel/treasure_wanderer.png",
		"biome": "reef",
		"maxHp": 18,
		"trait": "flee",
		"deck": ["sea"],  ## バックラー削除。小さい防御は既存の「海」（ブロック6）
	},
}

## enemies.ts getEnemy()
static func get_enemy(id: String) -> Dictionary:
	if not ENEMIES.has(id):
		push_error("Unknown enemy %s" % id)
		return {}
	return ENEMIES[id]


## layer は "body" か "fx"。variant は 1（1枚）か 2（2枚同時）。
static func px_sheet_path(sprite_base: String, layer: String, variant: int) -> String:
	if sprite_base == "":
		return ""
	var n: int = 2 if variant >= 2 else 1
	return "%s_%s_%d.png" % [sprite_base, layer, n]


## キャラごとのドット立ち絵の寸法。def に "px" が無ければ既定（128x224、上64、8コマ）。
static func px_dims(def: Dictionary) -> Dictionary:
	var p: Dictionary = {}
	var raw: Variant = def.get("px", {})
	if raw is Dictionary:
		p = raw
	var bw: int = int(p.get("body_w", PX_BODY_W))
	var bh: int = int(p.get("body_h", PX_BODY_H))
	var top: int = int(p.get("fx_top", PX_FX_TOP))
	return {
		"bw": bw, "bh": bh, "top": top,
		"fw": bw, "fh": bh + top,
		"body_frames": int(p.get("body_frames", PX_FRAME_COUNT)),
	}


const BOSS_IDS := ["priest", "choir", "nurse", "flock", "herald", "ithaqua", "dagon", "nyar", "iha", "yog_sothoth"]


static func combat_ids_for_archetype(archetype: String) -> Array:
	var out: Array = []
	for enemy_id in ENEMIES.keys():
		if BOSS_IDS.has(enemy_id) or enemy_id == "treasure_wanderer":
			continue
		var def: Dictionary = ENEMIES[enemy_id]
		if str(def.get("archetype", "")) == archetype:
			out.append(enemy_id)
	return out

