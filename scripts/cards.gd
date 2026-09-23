class_name Cards
extends RefCounted

## src/game/cards.ts の忠実な移植。数値・効果・条件は変更していない。
## art は asset() を res:// に読み替え。SHOP_CARDS は Object.assign(CARDS, SHOP_CARDS) と同じくマージ済み。

const DECK_LIMIT := 20

const ARCHETYPE_LABELS := {
	"fanatic": "狂信",
	"knight": "騎士",
	"poison": "毒",
	"outer": "外宇宙",
	"elder": "旧神",
	"deep": "深き者",
	"offering": "供物",
	"shadow": "影",
	"greatold": "旧支配者",
	"all": "全",
	"earth": "豊穣",
	"wind": "風",
	"fire": "火",
	"magic": "魔導",
	"bastet": "猫",
}

const ART_FALLBACK := {
	"res://art/pixel/cards/ancient_wisdom.jpg": "res://art/pixel/cards/tome.jpg",
	"res://art/pixel/cards/order_protection.jpg": "res://art/pixel/cards/ward.jpg",
	"res://art/pixel/cards/calm_blessing.jpg": "res://art/pixel/cards/resolve.jpg",
	"res://art/pixel/cards/sealing_moment.jpg": "res://art/pixel/cards/sigil.jpg",
	"res://art/pixel/cards/wardlight_afterglow.jpg": "res://art/pixel/cards/eldersign.jpg",
	"res://art/pixel/cards/dream_mending.jpg": "res://art/pixel/cards/resolve.jpg",
	"res://art/pixel/cards/far_guidance.jpg": "res://art/pixel/cards/tome.jpg",
	"res://art/pixel/cards/light_pillar.jpg": "res://art/pixel/cards/eldersign.jpg",
	"res://art/pixel/cards/trident.jpg": "res://art/pixel/cards/bash.jpg",
	"res://art/pixel/cards/cats_paw.jpg": "res://art/pixel/cards/strike.jpg",
	"res://art/pixel/cards/cat_fork.jpg": "res://art/pixel/cards/study.jpg",
	"res://art/pixel/cards/goddess_blessing.jpg": "res://art/pixel/cards/ward.jpg",
	"res://art/pixel/cards/goddess_offering.jpg": "res://art/pixel/cards/offering.jpg",
	"res://art/pixel/cards/goddess_contract.jpg": "res://art/pixel/cards/sigil.jpg",
	"res://art/pixel/cards/venom_blade.jpg": "res://art/pixel/cards/corrosive_strike.jpg",
	"res://art/pixel/cards/corroding_barrage.jpg": "res://art/pixel/cards/corrosive_strike.jpg",
	"res://art/pixel/cards/toxic_mist.jpg": "res://art/pixel/cards/pus_mist.jpg",
	"res://art/pixel/cards/pustule_armor.jpg": "res://art/pixel/cards/adapted_scales.jpg",
	"res://art/pixel/cards/venom_potency.jpg": "res://art/pixel/cards/pus_mist.jpg",
	"res://art/pixel/cards/self_poisoning.jpg": "res://art/pixel/cards/bloodpact.jpg",
}

const CARDS := {
	"chant": {
		"id": "chant",
		"name": "詠唱",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "knight",
		"cost": 1,
		"rarity": "common",
		"owner": "cultist",
		"text": "ブロック6を得る。筋力を2得る。",
		"upgradedText": "ブロック8を得る。筋力を3得る。",
		"flavor": "言葉が、自分を知っている。",
		"art": "res://art/pixel/cards/chant.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "strength",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 8,
			},
			{
				"t": "strength",
				"n": 3,
			},
		],
	},
	"echo": {
		"id": "echo",
		"name": "残響",
		"type": "power",
		"aiTag": "effect",
		"cost": 1,
		"rarity": "uncommon",
		"owner": "cultist",
		"text": "自分のターン開始時、ランダムな敵に4ダメージ。",
		"upgradedText": "自分のターン開始時、ランダムな敵に6ダメージ。",
		"flavor": "声を、後ろに残した。",
		"art": "res://art/pixel/cards/echo.jpg",
		"target": "none",
		"effects": [
			{
				"t": "gainPower",
				"id": "echo",
			},
		],
		"upgradedEffects": [
			{
				"t": "gainPower",
				"id": "echo",
			},
		],
	},
	"eldersign": {
		"id": "eldersign",
		"name": "古の印",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "elder",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック15を得る。正気が20以下なら、敵全体に15ダメージ。",
		"upgradedText": "ブロック20を得る。正気が25以下なら、敵全体に18ダメージ。",
		"flavor": "古い戦争を覚えている護符。",
		"art": "res://art/pixel/cards/eldersign.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 15,
			},
			{
				"t": "ifSanityBelow",
				"threshold": 21,
				"then": [
					{
						"t": "damageAll",
						"n": 15,
					},
				],
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 20,
			},
			{
				"t": "ifSanityBelow",
				"threshold": 26,
				"then": [
					{
						"t": "damageAll",
						"n": 18,
					},
				],
			},
		],
	},
	"dream_mending": {
		"id": "dream_mending",
		"name": "夢の癒し",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "elder",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"text": "体力20回復。状態異常を回復する。正気を4回復。",
		"upgradedText": "体力20回復。状態異常を回復する。正気を4回復。",
		"flavor": "バステトは、まだ眠る者を守る。",
		"art": "res://art/pixel/cards/dream_mending.jpg",
		"target": "none",
		"effects": [
			{"t": "heal", "n": 20},
			{"t": "clearStatus"},
			{"t": "sanity", "n": 4},
		],
		"upgradedEffects": [
			{"t": "heal", "n": 20},
			{"t": "clearStatus"},
			{"t": "sanity", "n": 4},
		],
	},
	"far_guidance": {
		"id": "far_guidance",
		"name": "彼方の導き",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "elder",
		"cost": 1,
		"rarity": "common",
		"owner": "shared",
		"text": "2枚引く。正気を2回復。",
		"upgradedText": "2枚引く。正気を2回復。",
		"flavor": "夢の岸から、白い手が伸びる。",
		"art": "res://art/pixel/cards/far_guidance.jpg",
		"target": "none",
		"effects": [
			{"t": "draw", "n": 2},
			{"t": "sanity", "n": 2},
		],
		"upgradedEffects": [
			{"t": "draw", "n": 2},
			{"t": "sanity", "n": 2},
		],
	},
	"light_pillar": {
		"id": "light_pillar",
		"name": "光の柱",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "elder",
		"cost": 2,
		"rarity": "uncommon",
		"owner": "shared",
		"text": "敵全体に13ダメージ。",
		"upgradedText": "敵全体に13ダメージ。",
		"flavor": "ウルは、夜を貫く。",
		"art": "res://art/pixel/cards/light_pillar.jpg",
		"target": "all",
		"effects": [
			{"t": "damageAll", "n": 13},
		],
		"upgradedEffects": [
			{"t": "damageAll", "n": 13},
		],
	},
	"trident": {
		"id": "trident",
		"name": "三叉の矛",
		"type": "attack",
		"vfx": "impact",
		"aiTag": "attack",
		"archetype": "elder",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "敵単体に22ダメージ。",
		"upgradedText": "敵単体に22ダメージ。",
		"flavor": "川の神の、忘れられた武具。",
		"art": "res://art/pixel/cards/trident.jpg",
		"target": "enemy",
		"effects": [
			{"t": "damage", "n": 22},
		],
		"upgradedEffects": [
			{"t": "damage", "n": 22},
		],
	},
	"cats_paw": {
		"id": "cats_paw",
		"name": "ねこの手",
		"type": "attack",
		"aiTag": "attack",
		"vfx": "impact",
		"archetype": "elder",
		"tags": ["cat"],
		"cost": 0,
		"rarity": "common",
		"owner": "shared",
		"text": "敵単体に5ダメージ。",
		"upgradedText": "敵単体に5ダメージ。",
		"flavor": "柔らかい。しかし、爪がある。",
		"art": "res://art/pixel/cards/cats_paw.jpg",
		"target": "enemy",
		"effects": [
			{"t": "damage", "n": 5},
		],
		"upgradedEffects": [
			{"t": "damage", "n": 5},
		],
	},
	"cat_fork": {
		"id": "cat_fork",
		"name": "猫叉",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "elder",
		"tags": ["cat"],
		"cost": 1,
		"rarity": "uncommon",
		"owner": "shared",
		"text": "デッキから「猫」をランダムに3枚手札に加える。",
		"upgradedText": "デッキから「猫」をランダムに3枚手札に加える。",
		"flavor": "三つの影が、同時に跳ねる。",
		"art": "res://art/pixel/cards/cat_fork.jpg",
		"target": "none",
		"effects": [
			{"t": "seekTagged", "tag": "cat", "n": 3},
		],
		"upgradedEffects": [
			{"t": "seekTagged", "tag": "cat", "n": 3},
		],
	},
	"goddess_blessing": {
		"id": "goddess_blessing",
		"name": "女神の加護",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "elder",
		"tags": ["cat"],
		"cost": 1,
		"rarity": "uncommon",
		"owner": "shared",
		"text": "このターン、「猫」を使用するたび、ブロック5と筋力1を得る。",
		"upgradedText": "このターン、「猫」を使用するたび、ブロック5と筋力1を得る。",
		"flavor": "猫神は、眷属を数える。",
		"art": "res://art/pixel/cards/goddess_blessing.jpg",
		"target": "none",
		"effects": [
			{"t": "bastBlessing", "block": 5, "strength": 1},
		],
		"upgradedEffects": [
			{"t": "bastBlessing", "block": 5, "strength": 1},
		],
	},
	"goddess_offering": {
		"id": "goddess_offering",
		"name": "女神への供物",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "elder",
		"tags": ["cat"],
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "体力を半分失う。「女神契約」をデッキに加える。破棄。",
		"upgradedText": "体力を半分失う。「女神契約」をデッキに加える。破棄。",
		"flavor": "血を半分。契約は、残る。",
		"art": "res://art/pixel/cards/goddess_offering.jpg",
		"target": "none",
		"exhaust": true,
		"effects": [
			{"t": "hpCostHalf"},
			{"t": "addToDraw", "id": "goddess_contract", "n": 1},
		],
		"upgradedEffects": [
			{"t": "hpCostHalf"},
			{"t": "addToDraw", "id": "goddess_contract", "n": 1},
		],
	},
	"goddess_contract": {
		"id": "goddess_contract",
		"name": "女神契約",
		"type": "power",
		"aiTag": "effect",
		"archetype": "elder",
		"tags": ["cat"],
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"unobtainable": true,
		"text": "「猫」の効果の数字を2倍にする。「ねこの手」を4枚手札に加える。",
		"upgradedText": "「猫」の効果の数字を2倍にする。「ねこの手」を4枚手札に加える。",
		"flavor": "名前を呼ばれた。従うほかない。",
		"art": "res://art/pixel/cards/goddess_contract.jpg",
		"target": "none",
		"effects": [
			{"t": "gainPower", "id": "goddessContract"},
			{"t": "addToHand", "id": "cats_paw", "n": 4},
		],
		"upgradedEffects": [
			{"t": "gainPower", "id": "goddessContract"},
			{"t": "addToHand", "id": "cats_paw", "n": 4},
		],
	},
	"thecall": {
		"id": "thecall",
		"name": "呼び声",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "fanatic",
		"cost": 2,
		"rarity": "rare",
		"owner": "cultist",
		"text": "敵全体に10ダメージ。弱体2。正気を6失う。破棄。",
		"upgradedText": "敵全体に14ダメージ。弱体3。正気を5失う。破棄。",
		"flavor": "母音を、待っていた。",
		"art": "res://art/pixel/cards/thecall.jpg",
		"target": "all",
		"exhaust": true,
		"effects": [
			{
				"t": "damageAll",
				"n": 10,
			},
			{
				"t": "weak",
				"n": 2,
			},
			{
				"t": "sanity",
				"n": -6,
			},
		],
		"upgradedEffects": [
			{
				"t": "damageAll",
				"n": 14,
			},
			{
				"t": "weak",
				"n": 3,
			},
			{
				"t": "sanity",
				"n": -5,
			},
		],
	},
	"laststand": {
		"id": "laststand",
		"name": "最期の抵抗",
		"type": "attack",
		"aiTag": "attack",
		"vfx": "impact",
		"archetype": "knight",
		"cost": 1,
		"rarity": "rare",
		"owner": "investigator",
		"text": "9ダメージ。体力が半分以下なら、さらに9。",
		"upgradedText": "12ダメージ。体力が半分以下なら、さらに12。",
		"flavor": "記録の中では、すでに死んでいる。",
		"art": "res://art/pixel/cards/laststand.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 9,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 12,
			},
		],
	},
	"adapted_scales": {
		"id": "adapted_scales",
		"name": "適応の鱗",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "deep",
		"cost": 1,
		"rarity": "common",
		"owner": "cultist",
		"text": "ブロック6を得る。1回復。",
		"upgradedText": "ブロック8を得る。1回復。",
		"flavor": "皮膚が、水を覚えている。",
		"art": "res://art/pixel/cards/adapted_scales.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "heal",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 8,
			},
			{
				"t": "heal",
				"n": 1,
			},
		],
	},
	"dread": {
		"id": "dread",
		"name": "恐怖",
		"type": "status",
		"cost": 0,
		"rarity": "status",
		"owner": "status",
		"text": "プレイ不可。引いたとき正気を2失う。",
		"upgradedText": "プレイ不可。引いたとき正気を2失う。",
		"flavor": "手札に、歯のように坐る。",
		"art": "res://art/pixel/cards/dread.jpg",
		"target": "none",
		"unplayable": true,
		"onDraw": [
			{
				"t": "sanityDamage",
				"n": 2,
			},
		],
		"effects": [],
		"upgradedEffects": [],
	},
	"frostbite": {
		"id": "frostbite",
		"name": "凍傷",
		"type": "status",
		"cost": 0,
		"rarity": "status",
		"owner": "status",
		"text": "引いたとき1ダメージを受ける。",
		"upgradedText": "引いたとき1ダメージを受ける。",
		"flavor": "指先から、世界が止まる。",
		"art": "res://art/pixel/cards/frostbite.jpg",
		"target": "none",
		"unplayable": true,
		"onDraw": [
			{
				"t": "hpCost",
				"n": 1,
			},
		],
		"effects": [],
		"upgradedEffects": [],
	},
	"all-distortion": {
		"id": "all-distortion",
		"name": "空間の歪み",
		"type": "skill",
		"aiTag": "defense",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"text": "ブロック8。1枚引く。使うたび最大体力を1失う。",
		"upgradedText": "ブロック11。1枚引く。使うたび最大体力を1失う。",
		"flavor": "落下は、解釈に過ぎない。",
		"art": "res://art/pixel/cards/all-distortion.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 8,
			},
			{
				"t": "draw",
				"n": 1,
			},
			{
				"t": "loseMaxHp",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 11,
			},
			{
				"t": "draw",
				"n": 1,
			},
			{
				"t": "loseMaxHp",
				"n": 1,
			},
		],
	},
	"all-zero": {
		"id": "all-zero",
		"name": "絶対零度の騙し絵",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "fanatic",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"text": "14ダメージ。脱力2。捨て札に凍傷を1枚。",
		"upgradedText": "18ダメージ。脱力2。捨て札に凍傷を1枚。",
		"flavor": "熱量を、ゼロと再定義する。",
		"art": "res://art/pixel/cards/all-zero.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 14,
			},
			{
				"t": "weak",
				"n": 2,
			},
			{
				"t": "addCurse",
				"id": "frostbite",
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 18,
			},
			{
				"t": "weak",
				"n": 2,
			},
			{
				"t": "addCurse",
				"id": "frostbite",
			},
		],
	},
	"all-geo": {
		"id": "all-geo",
		"name": "地磁気の強制共鳴",
		"type": "attack",
		"aiTag": "attack",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"exhaust": true,
		"text": "敵全体に10。1体につきブロック6。自分は3（貫通）。廃棄。",
		"upgradedText": "敵全体に14。1体につきブロック6。自分は3（貫通）。廃棄。",
		"flavor": "血が、大地に縫われる。",
		"art": "res://art/pixel/cards/all-geo.jpg",
		"target": "all",
		"effects": [
			{
				"t": "hpCost",
				"n": 3,
			},
			{
				"t": "damageAll",
				"n": 10,
			},
			{
				"t": "blockPerEnemy",
				"n": 6,
			},
		],
		"upgradedEffects": [
			{
				"t": "hpCost",
				"n": 3,
			},
			{
				"t": "damageAll",
				"n": 14,
			},
			{
				"t": "blockPerEnemy",
				"n": 6,
			},
		],
	},
	"all-diffuse": {
		"id": "all-diffuse",
		"name": "存在確率の拡散",
		"type": "power",
		"aiTag": "effect",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"exhaust": true,
		"text": "無形2ターン。最大体力-3。廃棄。",
		"upgradedText": "無形2ターン。最大体力-3。廃棄。",
		"flavor": "そこにいる。そこにはいない。",
		"art": "res://art/pixel/cards/all-diffuse.jpg",
		"target": "none",
		"effects": [
			{
				"t": "intangible",
				"n": 2,
			},
			{
				"t": "loseMaxHp",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "intangible",
				"n": 2,
			},
			{
				"t": "loseMaxHp",
				"n": 3,
			},
		],
	},
	"revelation": {
		"id": "revelation",
		"name": "大司祭の啓示",
		"type": "skill",
		"aiTag": "effect",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "恐怖を5枚デッキに差し込む。",
		"upgradedText": "恐怖を7枚デッキに差し込む。",
		"flavor": "禁忌の言葉が、聞く者の正気を蝕む。",
		"art": "res://art/pixel/cards/revelation.jpg",
		"target": "none",
		"effects": [
			{
				"t": "addDread",
				"n": 5,
			},
		],
		"upgradedEffects": [
			{
				"t": "addDread",
				"n": 7,
			},
		],
	},
	"chorusunity": {
		"id": "chorusunity",
		"name": "唱和の呪文",
		"type": "skill",
		"aiTag": "effect",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "筋力3を得る。",
		"upgradedText": "筋力4を得る。",
		"flavor": "声が声を呼び、力となる。",
		"art": "res://art/pixel/cards/chorusunity.jpg",
		"target": "none",
		"effects": [
			{
				"t": "strength",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "strength",
				"n": 4,
			},
		],
	},
	"embrace": {
		"id": "embrace",
		"name": "抱擁",
		"type": "skill",
		"aiTag": "defense",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "ブロック20を得る。",
		"upgradedText": "ブロック26を得る。",
		"flavor": "歪んだ母性が、その身を包み込む。",
		"art": "res://art/pixel/cards/embrace.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 20,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 26,
			},
		],
	},
	"flockrush": {
		"id": "flockrush",
		"name": "群れの急襲",
		"type": "attack",
		"aiTag": "attack",
		"vfx": "impact",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "13ダメージ。",
		"upgradedText": "17ダメージ。",
		"flavor": "無数の翼が、一斉に牙を立てる。",
		"art": "res://art/pixel/cards/flockrush.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 13,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 17,
			},
		],
	},
	"noneuclid": {
		"id": "noneuclid",
		"name": "非ユークリッドの罠",
		"type": "skill",
		"aiTag": "defense",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "ブロック22を得る。弱体2を与える。",
		"upgradedText": "ブロック28を得る。弱体3を与える。",
		"flavor": "角度が、あるべきでない形に曲がる。",
		"art": "res://art/pixel/cards/noneuclid.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "block",
				"n": 22,
			},
			{
				"t": "weak",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 28,
			},
			{
				"t": "weak",
				"n": 3,
			},
		],
	},
	"tollbell": {
		"id": "tollbell",
		"name": "鐘鳴らし",
		"type": "skill",
		"aiTag": "effect",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "弱体3を与える。",
		"upgradedText": "弱体4を与える。",
		"flavor": "沈んだ街に、今も鐘は鳴り続ける。",
		"art": "res://art/pixel/cards/tollbell.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "weak",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "weak",
				"n": 4,
			},
		],
	},
	"pricewisdom": {
		"id": "pricewisdom",
		"name": "千貌の代償",
		"type": "skill",
		"aiTag": "effect",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "相手の正気を8失わせ、弱体2を与える。",
		"upgradedText": "相手の正気を11失わせ、弱体3を与える。",
		"flavor": "知ることは、失うことと同義である。",
		"art": "res://art/pixel/cards/pricewisdom.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "sanity",
				"n": -8,
			},
			{
				"t": "weak",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "sanity",
				"n": -11,
			},
			{
				"t": "weak",
				"n": 3,
			},
		],
	},
	"protosurge": {
		"id": "protosurge",
		"name": "原形質の奔流",
		"type": "attack",
		"aiTag": "attack",
		"vfx": "impact",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "17ダメージ。",
		"upgradedText": "22ダメージ。",
		"flavor": "腐肉が形を失い、押し寄せる。",
		"art": "res://art/pixel/cards/protosurge.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 17,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 22,
			},
		],
	},
	"devourmaw": {
		"id": "devourmaw",
		"name": "貪る顎",
		"type": "attack",
		"aiTag": "attack",
		"vfx": "impact",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "25ダメージ。脆弱2を与える。",
		"upgradedText": "32ダメージ。脆弱3を与える。",
		"flavor": "それは、ただ喰らうために在る。",
		"art": "res://art/pixel/cards/devourmaw.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 25,
			},
			{
				"t": "vulnerable",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 32,
			},
			{
				"t": "vulnerable",
				"n": 3,
			},
		],
	},
	"evil_eye_bind": {
		"id": "evil_eye_bind",
		"name": "邪視の呪縛",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "shadow",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "相手の攻撃を封じる。弱体1を与える。",
		"upgradedText": "相手の攻撃を封じる。弱体2を与える。",
		"flavor": "千の仮面が見つめる先で、剣は震え、動けなくなる。",
		"art": "res://art/pixel/cards/evil_eye_bind.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "seal",
				"value": "attack",
			},
			{
				"t": "weak",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "seal",
				"value": "attack",
			},
			{
				"t": "weak",
				"n": 2,
			},
		],
	},
	"silent_bind": {
		"id": "silent_bind",
		"name": "沈黙の呪縛",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "shadow",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "相手の技能を封じる。",
		"upgradedText": "相手の技能を封じる。ブロック5を得る。",
		"flavor": "言葉は喉の奥で、形を失う。",
		"art": "res://art/pixel/cards/silent_bind.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "seal",
				"value": "skill",
			},
		],
		"upgradedEffects": [
			{
				"t": "seal",
				"value": "skill",
			},
			{
				"t": "block",
				"n": 5,
			},
		],
	},
	"crossbow": {
		"id": "crossbow",
		"name": "クロスボウ",
		"type": "attack",
		"aiTag": "attack",
		"vfx": "arrow",
		"archetype": "knight",
		"subArchetypes": ["weapon"],
		"cost": 1,
		"rarity": "common",
		"owner": "shared",
		"text": "敵全体に6ダメージ。",
		"upgradedText": "敵全体に6ダメージ。",
		"flavor": "引き絞られた弦は、眠る者にも届く。",
		"art": "res://art/pixel/cards/crossbow.jpg",
		"target": "all",
		"shop": true,
		"effects": [
			{
				"t": "damageAll",
				"n": 6,
			},
		],
		"upgradedEffects": [
			{
				"t": "damageAll",
				"n": 6,
			},
		],
	},
	"buckler": {
		"id": "buckler",
		"name": "バックラー",
		"type": "skill",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック4。",
		"upgradedText": "ブロック4。",
		"flavor": "",
		"art": "res://art/pixel/cards/buckler.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 4,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 4,
			},
		],
	},
	"beer": {
		"id": "beer",
		"name": "ビール瓶",
		"type": "skill",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "エネルギー2。2回使うと消える。",
		"upgradedText": "エネルギー2。2回使うと消える。",
		"flavor": "",
		"art": "res://art/pixel/cards/beer.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "energy",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "energy",
				"n": 2,
			},
		],
		"charges": 2,
	},
	"wound": {
		"id": "wound",
		"name": "負傷",
		"type": "status",
		"cost": 0,
		"rarity": "status",
		"owner": "status",
		"text": "プレイ不可。",
		"upgradedText": "プレイ不可。",
		"flavor": "",
		"art": "res://art/pixel/cards/study.jpg",
		"target": "none",
		"unplayable": true,
		"ethereal": true,
		"effects": [],
		"upgradedEffects": [],
	},
	"hallucination": {
		"id": "hallucination",
		"name": "おぞましい幻覚",
		"type": "status",
		"cost": 0,
		"rarity": "status",
		"owner": "status",
		"text": "プレイ不可。",
		"upgradedText": "プレイ不可。",
		"flavor": "",
		"art": "res://art/pixel/cards/study.jpg",
		"target": "none",
		"unplayable": true,
		"ethereal": true,
		"effects": [],
		"upgradedEffects": [],
	},
	"slime": {
		"id": "slime",
		"name": "粘液",
		"type": "status",
		"cost": 1,
		"rarity": "status",
		"owner": "status",
		"text": "廃棄される。",
		"upgradedText": "廃棄される。",
		"flavor": "",
		"art": "res://art/pixel/cards/ward.jpg",
		"target": "none",
		"exhaust": true,
		"ethereal": true,
		"effects": [],
		"upgradedEffects": [],
	},
	"sleep": {
		"id": "sleep",
		"name": "睡眠",
		"type": "status",
		"cost": 0,
		"rarity": "status",
		"owner": "status",
		"text": "プレイ不可。",
		"upgradedText": "プレイ不可。",
		"flavor": "",
		"art": "res://art/pixel/cards/study.jpg",
		"target": "none",
		"unplayable": true,
		"ethereal": true,
		"effects": [],
		"upgradedEffects": [],
	},
	"silver_key": {
		"id": "silver_key",
		"name": "銀の鍵",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "all",
		"cost": 4,
		"rarity": "legendary",
		"owner": "shared",
		"packOnly": true,
		"text": "手札上限までカードを引く。",
		"upgradedText": "手札上限までカードを引く。",
		"flavor": "門の向こうで、全なる者が待っている。",
		"art": "res://art/pixel/cards/silver_key.jpg",
		"target": "none",
		"effects": [
			{"t": "drawToHandLimit"},
		],
		"upgradedEffects": [
			{"t": "drawToHandLimit"},
		],
	},
	"collapse": {
		"id": "collapse",
		"name": "崩壊",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "all",
		"cost": 4,
		"rarity": "legendary",
		"owner": "shared",
		"packOnly": true,
		"vfx": "impact",
		"text": "敵全体に1000ダメージ。",
		"upgradedText": "敵全体に1000ダメージ。",
		"flavor": "世界が、ひとつの点に折れる。",
		"art": "res://art/pixel/cards/collapse.jpg",
		"target": "all",
		"effects": [
			{"t": "damageAll", "n": 1000},
		],
		"upgradedEffects": [
			{"t": "damageAll", "n": 1000},
		],
	},
	"omnipotence": {
		"id": "omnipotence",
		"name": "全能",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "all",
		"cost": 8,
		"rarity": "legendary",
		"owner": "shared",
		"packOnly": true,
		"oncePerTurn": true,
		"text": "エナジーを30得る。同名カードは1ターンに一度しか使えない。",
		"upgradedText": "エナジーを30得る。同名カードは1ターンに一度しか使えない。",
		"flavor": "すべてを動かす力は、ここに満ちる。",
		"art": "res://art/pixel/cards/omnipotence.jpg",
		"target": "none",
		"effects": [
			{"t": "energy", "n": 30},
		],
		"upgradedEffects": [
			{"t": "energy", "n": 30},
		],
	},
	"transcendent": {
		"id": "transcendent",
		"name": "超越者",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "all",
		"cost": 10,
		"rarity": "legendary",
		"owner": "shared",
		"packOnly": true,
		"text": "全回復、正気度全回復、状態異常回復。",
		"upgradedText": "全回復、正気度全回復、状態異常回復。",
		"flavor": "器が光になり、傷も狂気も残らない。",
		"art": "res://art/pixel/cards/transcendent.jpg",
		"target": "none",
		"effects": [
			{"t": "healFull"},
			{"t": "sanityFull"},
			{"t": "clearStatus"},
		],
		"upgradedEffects": [
			{"t": "healFull"},
			{"t": "sanityFull"},
			{"t": "clearStatus"},
		],
	},
	## ---- 外宇宙・アザトース ----
	"death": {
		"id": "death", "name": "死", "type": "skill", "aiTag": "effect",
		"archetype": "outer", "subArchetypes": ["tome", "chaos"],
		"cost": 2, "rarity": "common", "owner": "shared",
		"text": "正気度4を失う。体力4回復。4枚ドロー。",
		"upgradedText": "正気度4を失う。体力4回復。4枚ドロー。",
		"flavor": "", "art": "res://art/pixel/cards/death.jpg", "target": "none",
		"effects": [{"t": "sanity", "n": -4}, {"t": "heal", "n": 4}, {"t": "draw", "n": 4}],
		"upgradedEffects": [{"t": "sanity", "n": -4}, {"t": "heal", "n": 4}, {"t": "draw", "n": 4}],
	},
	"chaos_slumber": {
		"id": "chaos_slumber", "name": "混沌の微睡み", "type": "skill", "aiTag": "effect",
		"archetype": "outer", "subArchetypes": ["chaos"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "正気度6を失う。デッキから「混沌」カードを3枚手札に加える。",
		"upgradedText": "正気度6を失う。デッキから「混沌」カードを3枚手札に加える。",
		"flavor": "", "art": "res://art/pixel/cards/chaos_slumber.jpg", "target": "none",
		"effects": [{"t": "sanity", "n": -6}, {"t": "seekBySubArchetype", "sub": "chaos", "n": 3}],
		"upgradedEffects": [{"t": "sanity", "n": -6}, {"t": "seekBySubArchetype", "sub": "chaos", "n": 3}],
	},
	"snore": {
		"id": "snore", "name": "いびき", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "outer", "subArchetypes": ["chaos"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"text": "正気度2を失う。敵全体に10ダメージ。",
		"upgradedText": "正気度2を失う。敵全体に10ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/snore.jpg", "target": "all",
		"effects": [{"t": "sanity", "n": -2}, {"t": "damageAll", "n": 10}],
		"upgradedEffects": [{"t": "sanity", "n": -2}, {"t": "damageAll", "n": 10}],
	},
	"turn_over": {
		"id": "turn_over", "name": "寝返り", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "outer", "subArchetypes": ["chaos"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"text": "正気度2を失う。敵単体に16ダメージ。",
		"upgradedText": "正気度2を失う。敵単体に16ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/turn_over.jpg", "target": "enemy",
		"effects": [{"t": "sanity", "n": -2}, {"t": "damage", "n": 16}],
		"upgradedEffects": [{"t": "sanity", "n": -2}, {"t": "damage", "n": 16}],
	},
	"dreaming": {
		"id": "dreaming", "name": "夢見", "type": "skill", "aiTag": "effect",
		"archetype": "outer", "subArchetypes": ["chaos"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"text": "正気度10を失う。体力を全回復する。",
		"upgradedText": "正気度10を失う。体力を全回復する。",
		"flavor": "", "art": "res://art/pixel/cards/dreaming.jpg", "target": "none",
		"effects": [{"t": "sanity", "n": -10}, {"t": "healFull"}],
		"upgradedEffects": [{"t": "sanity", "n": -10}, {"t": "healFull"}],
	},
	"jester_gods_service": {
		"id": "jester_gods_service", "name": "戯神の奉仕", "type": "skill", "aiTag": "defense",
		"archetype": "outer", "subArchetypes": ["chaos"],
		"cost": 3, "rarity": "common", "owner": "shared",
		"text": "防御30を得る。",
		"upgradedText": "防御30を得る。",
		"flavor": "", "art": "res://art/pixel/cards/jester_gods_service.jpg", "target": "none",
		"effects": [{"t": "block", "n": 30}],
		"upgradedEffects": [{"t": "block", "n": 30}],
	},
	## ---- 豊穣・シュブ＝ニグラス ----
	"black_sheep": {
		"id": "black_sheep", "name": "黒羊", "type": "skill", "aiTag": "effect",
		"archetype": "earth", "subArchetypes": ["earth"],
		"cost": 0, "rarity": "status", "owner": "shared",
		"unobtainable": true, "token": true, "vanishOnUse": true,
		"text": "", "upgradedText": "", "flavor": "", "art": "", "target": "none",
		"effects": [], "upgradedEffects": [],
	},
	"darkness": {
		"id": "darkness", "name": "闇", "type": "skill", "aiTag": "effect",
		"archetype": "earth", "subArchetypes": ["earth", "fertility"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "デッキから「豊穣」カードを3枚手札に加える。",
		"upgradedText": "デッキから「豊穣」カードを3枚手札に加える。",
		"flavor": "", "art": "res://art/pixel/cards/darkness.jpg", "target": "none",
		"effects": [{"t": "seekBySubArchetype", "sub": "fertility", "n": 3}],
		"upgradedEffects": [{"t": "seekBySubArchetype", "sub": "fertility", "n": 3}],
	},
	"spawn": {
		"id": "spawn", "name": "落とし子", "type": "skill", "aiTag": "effect",
		"archetype": "earth", "subArchetypes": ["earth", "fertility"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "手札に「黒羊」を4枚加える。以降、毎ターン開始時に「黒羊」を1枚手札に加える。",
		"upgradedText": "手札に「黒羊」を4枚加える。以降、毎ターン開始時に「黒羊」を1枚手札に加える。",
		"flavor": "", "art": "res://art/pixel/cards/spawn.jpg", "target": "none",
		"effects": [
			{"t": "addToHand", "id": "black_sheep", "n": 4},
			{"t": "turnStartHook", "hook": "addToHand", "id": "black_sheep", "n": 1},
		],
		"upgradedEffects": [
			{"t": "addToHand", "id": "black_sheep", "n": 4},
			{"t": "turnStartHook", "hook": "addToHand", "id": "black_sheep", "n": 1},
		],
	},
	"nourishment": {
		"id": "nourishment", "name": "滋養", "type": "skill", "aiTag": "defense",
		"archetype": "earth", "subArchetypes": ["earth", "fertility"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"requireId": "black_sheep", "requireN": 1,
		"text": "「黒羊」を1枚消滅させて使用可能。正気度3を失う。体力20回復。",
		"upgradedText": "「黒羊」を1枚消滅させて使用可能。正気度3を失う。体力20回復。",
		"flavor": "", "art": "res://art/pixel/cards/nourishment.jpg", "target": "none",
		"effects": [
			{"t": "consumeId", "id": "black_sheep", "n": 1},
			{"t": "sanity", "n": -3},
			{"t": "heal", "n": 20},
		],
		"upgradedEffects": [
			{"t": "consumeId", "id": "black_sheep", "n": 1},
			{"t": "sanity", "n": -3},
			{"t": "heal", "n": 20},
		],
	},
	"earthquake": {
		"id": "earthquake", "name": "大地震", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "earth", "subArchetypes": ["earth", "fertility"],
		"cost": 2, "rarity": "common", "owner": "shared",
		"requireId": "black_sheep", "requireN": 2,
		"text": "「黒羊」を2枚消滅させて使用可能。敵全体に40ダメージ。",
		"upgradedText": "「黒羊」を2枚消滅させて使用可能。敵全体に40ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/earthquake.jpg", "target": "all",
		"effects": [
			{"t": "consumeId", "id": "black_sheep", "n": 2},
			{"t": "damageAll", "n": 40},
		],
		"upgradedEffects": [
			{"t": "consumeId", "id": "black_sheep", "n": 2},
			{"t": "damageAll", "n": 40},
		],
	},
	"charge": {
		"id": "charge", "name": "突進", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "earth", "subArchetypes": ["earth", "fertility"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"requireId": "black_sheep", "requireN": 1,
		"text": "「黒羊」を1枚消滅させて使用可能。敵単体に22ダメージ。",
		"upgradedText": "「黒羊」を1枚消滅させて使用可能。敵単体に22ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/charge.jpg", "target": "enemy",
		"effects": [
			{"t": "consumeId", "id": "black_sheep", "n": 1},
			{"t": "damage", "n": 22},
		],
		"upgradedEffects": [
			{"t": "consumeId", "id": "black_sheep", "n": 1},
			{"t": "damage", "n": 22},
		],
	},
	"mother_goddess": {
		"id": "mother_goddess", "name": "母なる神性", "type": "skill", "aiTag": "effect",
		"archetype": "earth", "subArchetypes": ["earth", "fertility"],
		"cost": 2, "rarity": "uncommon", "owner": "shared",
		"text": "「黒羊」を手札上限まで加える。この戦闘中、ターン開始時に「黒羊」を追加で1枚加える。",
		"upgradedText": "「黒羊」を手札上限まで加える。この戦闘中、ターン開始時に「黒羊」を追加で1枚加える。",
		"flavor": "千の落とし子が、同時に産声をあげる。",
		"art": "res://art/pixel/cards/mother_goddess.jpg", "target": "none",
		"effects": [
			{"t": "addToHandLimit", "id": "black_sheep"},
			{"t": "turnStartHook", "hook": "addToHand", "id": "black_sheep", "n": 1},
		],
		"upgradedEffects": [
			{"t": "addToHandLimit", "id": "black_sheep"},
			{"t": "turnStartHook", "hook": "addToHand", "id": "black_sheep", "n": 1},
		],
	},
	## ---- 深き者・水 ----
	"apocrypha": {
		"id": "apocrypha", "name": "異本", "type": "skill", "aiTag": "effect",
		"archetype": "deep", "subArchetypes": ["tome"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "正気度4を失う。3枚ドロー。",
		"upgradedText": "正気度4を失う。3枚ドロー。",
		"flavor": "", "art": "res://art/pixel/cards/apocrypha.jpg", "target": "none",
		"effects": [{"t": "sanity", "n": -4}, {"t": "draw", "n": 3}],
		"upgradedEffects": [{"t": "sanity", "n": -4}, {"t": "draw", "n": 3}],
	},
	"tentacle": {
		"id": "tentacle", "name": "触手", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "deep", "subArchetypes": ["water"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "正気度1を失う。敵単体に11ダメージ。",
		"upgradedText": "正気度1を失う。敵単体に11ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/tentacle.jpg", "target": "enemy",
		"effects": [{"t": "sanity", "n": -1}, {"t": "damage", "n": 11}],
		"upgradedEffects": [{"t": "sanity", "n": -1}, {"t": "damage", "n": 11}],
	},
	"scales": {
		"id": "scales", "name": "鱗", "type": "skill", "aiTag": "defense",
		"archetype": "deep", "subArchetypes": ["water"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "正気度1を失う。防御15を得る。",
		"upgradedText": "正気度1を失う。防御15を得る。",
		"flavor": "", "art": "res://art/pixel/cards/scales.jpg", "target": "none",
		"effects": [{"t": "sanity", "n": -1}, {"t": "block", "n": 15}],
		"upgradedEffects": [{"t": "sanity", "n": -1}, {"t": "block", "n": 15}],
	},
	"mothers_embrace": {
		"id": "mothers_embrace", "name": "母の抱擁", "type": "skill", "aiTag": "effect",
		"archetype": "deep", "subArchetypes": ["water"],
		"cost": 2, "rarity": "common", "owner": "shared",
		"text": "正気度5回復。体力5回復。",
		"upgradedText": "正気度5回復。体力5回復。",
		"flavor": "", "art": "res://art/pixel/cards/mothers_embrace.jpg", "target": "none",
		"effects": [{"t": "sanity", "n": 5}, {"t": "heal", "n": 5}],
		"upgradedEffects": [{"t": "sanity", "n": 5}, {"t": "heal", "n": 5}],
	},
	## sea_pact はデッキから「水」を引く。海トークンはもう生成しない。
	## 進行中の戦闘セーブが既に持っている場合に備え、定義だけ残す。
	"sea": {
		"id": "sea", "name": "海", "type": "skill", "aiTag": "defense",
		"archetype": "deep", "subArchetypes": ["water"],
		"cost": 0, "rarity": "status", "owner": "shared",
		"unobtainable": true, "token": true, "vanishOnUse": true,
		"text": "防御6を得る。",
		"upgradedText": "防御6を得る。",
		"flavor": "", "art": "", "target": "none",
		"effects": [{"t": "block", "n": 6}],
		"upgradedEffects": [{"t": "block", "n": 6}],
	},
	"sea_pact": {
		"id": "sea_pact", "name": "海契約", "type": "skill", "aiTag": "effect",
		"archetype": "deep",
		"cost": 0, "rarity": "common", "owner": "shared", "oncePerTurn": true,
		"text": "正気度5を失う。このターン、「水」属性カードの効果を2倍にする。デッキから「水」カードを2枚手札に加える。1ターンに1度しか使用できない。",
		"upgradedText": "正気度5を失う。このターン、「水」属性カードの効果を2倍にする。デッキから「水」カードを2枚手札に加える。1ターンに1度しか使用できない。",
		"flavor": "", "art": "res://art/pixel/cards/sea_pact.jpg", "target": "none",
		"effects": [
			{"t": "sanity", "n": -5},
			{"t": "subEffectMul", "sub": "water", "n": 2},
			{"t": "seekBySubArchetype", "sub": "water", "n": 2},
		],
		"upgradedEffects": [
			{"t": "sanity", "n": -5},
			{"t": "subEffectMul", "sub": "water", "n": 2},
			{"t": "seekBySubArchetype", "sub": "water", "n": 2},
		],
	},
	"gill_breathing": {
		"id": "gill_breathing", "name": "えら呼吸", "type": "skill", "aiTag": "effect",
		"archetype": "deep",
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "エネルギーを1得る。",
		"upgradedText": "エネルギーを1得る。",
		"flavor": "", "art": "res://art/pixel/cards/gill_breathing.jpg", "target": "none",
		"effects": [{"t": "energy", "n": 1}],
		"upgradedEffects": [{"t": "energy", "n": 1}],
	},
	## ---- 旧支配者・風／ハスター ----
	"wind_gods_bow": {
		"id": "wind_gods_bow", "name": "風神の弓", "type": "attack", "aiTag": "attack", "vfx": "arrow",
		"archetype": "wind", "subArchetypes": ["weapon", "wind"],
		"cost": 2, "rarity": "rare", "owner": "shared",
		"shop": true,
		"text": "敵全体に18ダメージ。",
		"upgradedText": "敵全体に18ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/wind_gods_bow.jpg", "target": "all",
		"effects": [{"t": "damageAll", "n": 18}],
		"upgradedEffects": [{"t": "damageAll", "n": 18}],
	},
	"king_in_yellow": {
		"id": "king_in_yellow", "name": "黄衣の王", "type": "skill", "aiTag": "effect",
		"archetype": "wind", "subArchetypes": ["tome", "wind"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "正気度5を失う。デッキから「風」カードを3枚手札に加える。",
		"upgradedText": "正気度5を失う。デッキから「風」カードを3枚手札に加える。",
		"flavor": "", "art": "res://art/pixel/cards/king_in_yellow.jpg", "target": "none",
		"effects": [
			{"t": "sanity", "n": -5},
			{"t": "seekBySubArchetype", "sub": "wind", "n": 3},
		],
		"upgradedEffects": [
			{"t": "sanity", "n": -5},
			{"t": "seekBySubArchetype", "sub": "wind", "n": 3},
		],
	},
	"yellow_coin": {
		"id": "yellow_coin", "name": "黄色のコイン", "type": "skill", "aiTag": "defense",
		"archetype": "wind", "subArchetypes": ["wind"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"unplayable": true,
		"handPresenceEffect": {"block": 20},
		"onDraw": [{"t": "sanity", "n": -3}],
		"text": "このカードを引いた時、正気度3を失う。手札にある間、防御20を得る。",
		"upgradedText": "このカードを引いた時、正気度3を失う。手札にある間、防御20を得る。",
		"flavor": "", "art": "res://art/pixel/cards/yellow_coin.jpg", "target": "none",
		"effects": [], "upgradedEffects": [],
	},
	"whirlwind": {
		"id": "whirlwind", "name": "つじ風", "type": "attack", "aiTag": "attack", "vfx": "slash",
		"archetype": "wind", "subArchetypes": ["wind", "arcane"],
		"cost": 1, "rarity": "uncommon", "owner": "shared",
		"text": "敵全体に6ダメージ。",
		"upgradedText": "敵全体に6ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/whirlwind.jpg", "target": "all",
		"effects": [{"t": "damageAll", "n": 6}],
		"upgradedEffects": [{"t": "damageAll", "n": 6}],
	},
	"whirlwind_free": {
		"id": "whirlwind_free", "name": "つじ風", "type": "attack", "aiTag": "attack", "vfx": "slash",
		"archetype": "wind", "subArchetypes": ["wind", "arcane"],
		"cost": 0, "rarity": "status", "owner": "shared",
		"unobtainable": true, "token": true, "vanishOnUse": true,
		"text": "敵全体に6ダメージ。",
		"upgradedText": "敵全体に6ダメージ。",
		"flavor": "", "art": "", "target": "all",
		"effects": [{"t": "damageAll", "n": 6}],
		"upgradedEffects": [{"t": "damageAll", "n": 6}],
	},
	"desert": {
		"id": "desert", "name": "砂漠", "type": "skill", "aiTag": "effect",
		"archetype": "wind", "subArchetypes": ["wind"],
		"cost": 3, "rarity": "common", "owner": "shared",
		"text": "このターン、「風」属性カードのダメージを2倍にする。敵味方全体に弱体2を付与する。",
		"upgradedText": "このターン、「風」属性カードのダメージを2倍にする。敵味方全体に弱体2を付与する。",
		"flavor": "", "art": "res://art/pixel/cards/desert.jpg", "target": "none",
		"effects": [
			{"t": "subDamageMul", "sub": "wind", "n": 2},
			{"t": "weakAllSides", "n": 2},
		],
		"upgradedEffects": [
			{"t": "subDamageMul", "sub": "wind", "n": 2},
			{"t": "weakAllSides", "n": 2},
		],
	},
	"yellow_hallucination": {
		"id": "yellow_hallucination", "name": "黄色の幻覚", "type": "skill", "aiTag": "effect",
		"archetype": "wind", "subArchetypes": ["wind"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"onDraw": [
			{"t": "sanity", "n": -3},
			{"t": "addToHand", "id": "whirlwind_free", "n": 3},
		],
		"text": "このカードを引いた時、正気度3を失う。コスト0の「つじ風」を3枚手札に加える（消滅型）。",
		"upgradedText": "このカードを引いた時、正気度3を失う。コスト0の「つじ風」を3枚手札に加える（消滅型）。",
		"flavor": "", "art": "res://art/pixel/cards/yellow_hallucination.jpg", "target": "none",
		"effects": [], "upgradedEffects": [],
	},
	## ---- 旧支配者・火／クトゥグァ ----
	"fireball": {
		"id": "fireball", "name": "火球", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "fire", "subArchetypes": ["fire", "arcane"],
		"cost": 0, "rarity": "common", "owner": "shared", "vanishOnUse": true,
		"text": "敵単体に6ダメージ。",
		"upgradedText": "敵単体に6ダメージ。",
		"flavor": "", "art": "res://art/pixel/cards/fireball.jpg", "target": "enemy",
		"effects": [{"t": "damage", "n": 6}],
		"upgradedEffects": [{"t": "damage", "n": 6}],
	},
	"fomalhaut": {
		"id": "fomalhaut", "name": "フォーマルハウト", "type": "skill", "aiTag": "effect",
		"archetype": "fire", "subArchetypes": ["star", "fire"],
		"cost": 2, "rarity": "common", "owner": "shared",
		"text": "このターン、「火」属性カードのダメージを3倍にする。「火球」を3枚手札に加える（消滅型）。",
		"upgradedText": "このターン、「火」属性カードのダメージを3倍にする。「火球」を3枚手札に加える（消滅型）。",
		"flavor": "", "art": "res://art/pixel/cards/fomalhaut.jpg", "target": "none",
		"effects": [
			{"t": "subDamageMul", "sub": "fire", "n": 3},
			{"t": "addToHand", "id": "fireball", "n": 3},
		],
		"upgradedEffects": [
			{"t": "subDamageMul", "sub": "fire", "n": 3},
			{"t": "addToHand", "id": "fireball", "n": 3},
		],
	},
	"flames_will": {
		"id": "flames_will", "name": "火の意思", "type": "skill", "aiTag": "effect",
		"archetype": "fire", "subArchetypes": ["fire"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "デッキから「火」カードを2枚手札に加える。「火球」を手札に2枚加える（消滅型）。",
		"upgradedText": "デッキから「火」カードを2枚手札に加える。「火球」を手札に2枚加える（消滅型）。",
		"flavor": "", "art": "res://art/pixel/cards/flames_will.jpg", "target": "none",
		"effects": [
			{"t": "seekBySubArchetype", "sub": "fire", "n": 2},
			{"t": "addToHand", "id": "fireball", "n": 2},
		],
		"upgradedEffects": [
			{"t": "seekBySubArchetype", "sub": "fire", "n": 2},
			{"t": "addToHand", "id": "fireball", "n": 2},
		],
	},
	"cold_flame": {
		"id": "cold_flame", "name": "冷たい炎", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "fire", "subArchetypes": ["fire"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "敵単体に3ダメージ。デッキから「火の意思」を1枚手札に加える。",
		"upgradedText": "敵単体に3ダメージ。デッキから「火の意思」を1枚手札に加える。",
		"flavor": "", "art": "res://art/pixel/cards/cold_flame.jpg", "target": "enemy",
		"effects": [
			{"t": "damage", "n": 3},
			{"t": "seekById", "id": "flames_will", "n": 1},
		],
		"upgradedEffects": [
			{"t": "damage", "n": 3},
			{"t": "seekById", "id": "flames_will", "n": 1},
		],
	},
	"flame_lord": {
		"id": "flame_lord", "name": "炎の主", "type": "skill", "aiTag": "effect",
		"archetype": "fire",
		"cost": 0, "rarity": "status", "owner": "shared",
		"unobtainable": true, "token": true, "vanishOnUse": true,
		"text": "「火球」を手札上限まで加える。",
		"upgradedText": "「火球」を手札上限まで加える。",
		"flavor": "", "art": "res://art/pixel/cards/flame_lord.jpg", "target": "none",
		"effects": [{"t": "addToHandLimit", "id": "fireball"}],
		"upgradedEffects": [{"t": "addToHandLimit", "id": "fireball"}],
	},
	"flame_god": {
		"id": "flame_god", "name": "炎の神", "type": "skill", "aiTag": "effect",
		"archetype": "fire",
		"cost": 0, "rarity": "status", "owner": "shared",
		"unobtainable": true, "token": true, "vanishOnUse": true,
		"text": "", "upgradedText": "", "flavor": "", "art": "res://art/pixel/cards/flame_god.jpg", "target": "none",
		"effects": [
			{"t": "enemyHpPercent", "n": 10},
			{"t": "hpToOne"},
		],
		"upgradedEffects": [
			{"t": "enemyHpPercent", "n": 10},
			{"t": "hpToOne"},
		],
	},
	"flame_pact": {
		"id": "flame_pact", "name": "炎契約", "type": "skill", "aiTag": "effect",
		"archetype": "fire",
		"cost": 0, "rarity": "common", "owner": "shared",
		"text": "正気度6を失う。手札の「火」カードを6枚捨てて「炎の主」を手札に加える。",
		"upgradedText": "正気度6を失う。手札の「火」カードを6枚捨てて「炎の主」を手札に加える。",
		"flavor": "", "art": "res://art/pixel/cards/flame_pact.jpg", "target": "none",
		"effects": [
			{"t": "sanity", "n": -6},
			{"t": "flamePact"},
		],
		"upgradedEffects": [
			{"t": "sanity", "n": -6},
			{"t": "flamePact"},
		],
	},
	"flame_drain": {
		"id": "flame_drain", "name": "炎の吸血", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "fire", "subArchetypes": ["fire"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"requireSubInHand": "fire", "requireSubN": 2,
		"text": "手札の「火」カードを2枚捨てる。敵単体に8ダメージ。体力8回復。",
		"upgradedText": "手札の「火」カードを2枚捨てる。敵単体に8ダメージ。体力8回復。",
		"flavor": "", "art": "res://art/pixel/cards/flame_drain.jpg", "target": "enemy",
		"effects": [
			{"t": "discardSubHand", "sub": "fire", "n": 2},
			{"t": "damage", "n": 8},
			{"t": "heal", "n": 8},
		],
		"upgradedEffects": [
			{"t": "discardSubHand", "sub": "fire", "n": 2},
			{"t": "damage", "n": 8},
			{"t": "heal", "n": 8},
		],
	},
	## ---- 騎士 ----
	"shield": {
		"id": "shield", "name": "盾", "type": "skill", "aiTag": "defense",
		"archetype": "knight",
		"cost": 0, "rarity": "common", "owner": "shared",
		"unplayable": true,
		"handPresenceEffect": {"block": 10},
		"upgradedHandPresenceEffect": {"block": 15},
		"text": "手札にある間、防御+10。",
		"upgradedText": "手札にある間、防御+15。",
		"flavor": "手を放さなければ、まだ守れる。", "art": "res://art/pixel/cards/buckler.jpg", "target": "none",
		"effects": [], "upgradedEffects": [],
	},
	"armory": {
		"id": "armory", "name": "武器庫", "type": "skill", "aiTag": "effect",
		"archetype": "knight",
		"cost": 1, "rarity": "common", "owner": "shared",
		"text": "デッキから「武器」カードを2枚手札に加える。",
		"upgradedText": "デッキから「武器」カードを2枚手札に加える。",
		"flavor": "錆びた扉の奥で、刃だけが眠らない。", "art": "res://art/pixel/cards/armory.jpg", "target": "none",
		"effects": [{"t": "seekBySubArchetype", "sub": "weapon", "n": 2}],
		"upgradedEffects": [{"t": "seekBySubArchetype", "sub": "weapon", "n": 2}],
	},
	"muramasa": {
		"id": "muramasa", "name": "ムラマサ", "type": "attack", "aiTag": "attack", "vfx": "slash",
		"archetype": "knight", "subArchetypes": ["weapon"],
		"cost": 1, "rarity": "rare", "owner": "shared",
		"text": "正気度4を失う。敵単体に20ダメージ。",
		"upgradedText": "正気度4を失う。敵単体に25ダメージ。",
		"flavor": "鞘に納めても、刃鳴りは止まらない。", "art": "res://art/pixel/cards/muramasa.jpg", "target": "enemy",
		"effects": [{"t": "sanity", "n": -4}, {"t": "damage", "n": 20}],
		"upgradedEffects": [{"t": "sanity", "n": -4}, {"t": "damage", "n": 25}],
	},
	"iron_armor": {
		"id": "iron_armor", "name": "鉄の鎧", "type": "skill", "aiTag": "defense",
		"archetype": "knight",
		"cost": 2, "rarity": "uncommon", "owner": "shared",
		"text": "毎ターン開始時、防御を+5する。",
		"upgradedText": "毎ターン開始時、防御を+5する。",
		"flavor": "鈍い鉄が、夜の牙を受け止める。", "art": "res://art/pixel/cards/iron_armor.jpg", "target": "none",
		"effects": [{"t": "turnStartHook", "hook": "block", "n": 5}],
		"upgradedEffects": [{"t": "turnStartHook", "hook": "block", "n": 5}],
	},
	"dull_blade": {
		"id": "dull_blade", "name": "なまくら", "type": "attack", "aiTag": "attack", "vfx": "slash",
		"archetype": "knight", "subArchetypes": ["weapon"],
		"cost": 1, "rarity": "common", "owner": "shared",
		## 鍛冶屋の「焼く」は廃止。この隠し強化は届かないデッドコード。将来の再設計まで残す。
		"fixedForgeUpgrade": true,
		"text": "敵単体に8ダメージ。",
		"upgradedText": "敵単体に16ダメージ。",
		"flavor": "磨かれれば、ようやく刃になる。",
		"art": "res://art/pixel/cards/dull_blade_base.jpg",
		"upgradedArt": "res://art/pixel/cards/dull_blade_upgraded.jpg",
		"target": "enemy",
		"effects": [{"t": "damage", "n": 8}],
		"upgradedEffects": [{"t": "damage", "n": 16}],
	},
	## ---- 魔導 ----
	"spellbook": {
		"id": "spellbook", "name": "呪文書", "type": "skill", "aiTag": "effect",
		"archetype": "magic", "subArchetypes": ["tome"],
		"cost": 0, "rarity": "common", "owner": "shared",
		"text": "正気度6を失う。デッキから「魔術」カードを3枚手札に加える。",
		"upgradedText": "正気度6を失う。デッキから「魔術」カードを3枚手札に加える。",
		"flavor": "読む者の方が、読まれている。", "art": "res://art/pixel/cards/spellbook.jpg", "target": "none",
		"effects": [{"t": "sanity", "n": -6}, {"t": "seekBySubArchetype", "sub": "arcane", "n": 3}],
		"upgradedEffects": [{"t": "sanity", "n": -6}, {"t": "seekBySubArchetype", "sub": "arcane", "n": 3}],
	},
	"ultimate_arcane": {
		"id": "ultimate_arcane", "name": "究極魔術", "type": "attack", "aiTag": "attack", "vfx": "impact",
		"archetype": "magic", "subArchetypes": ["arcane"],
		"cost": 0, "rarity": "rare", "owner": "shared",
		"requireSubsInHand": ["fire", "water", "wind", "earth"],
		"text": "手札の「火」「水」「風」「地」カードを1枚ずつ捨てて使用可能。敵全体に500ダメージ。",
		"upgradedText": "手札の「火」「水」「風」「地」カードを1枚ずつ捨てて使用可能。敵全体に500ダメージ。",
		"flavor": "四つの理が、ひとつの終わりを指す。", "art": "res://art/pixel/cards/ultimate_arcane.jpg", "target": "all",
		"effects": [{"t": "discardSubsHand", "subs": ["fire", "water", "wind", "earth"]}, {"t": "damageAll", "n": 500}],
		"upgradedEffects": [{"t": "discardSubsHand", "subs": ["fire", "water", "wind", "earth"]}, {"t": "damageAll", "n": 500}],
	},
	"wisdom": {
		"id": "wisdom", "name": "知", "type": "skill", "aiTag": "effect",
		"archetype": "magic", "subArchetypes": ["arcane"],
		"cost": 1, "rarity": "common", "owner": "shared",
		"requireSubInHand": "tome", "requireSubN": 1,
		"text": "「魔導書」カードを1枚捨てる。3枚ドローする。",
		"upgradedText": "「魔導書」カードを1枚捨てる。3枚ドローする。",
		"flavor": "理解は、紙より先に心を裂く。", "art": "res://art/pixel/cards/wisdom.jpg", "target": "none",
		"effects": [{"t": "discardSubHand", "sub": "tome", "n": 1}, {"t": "draw", "n": 3}],
		"upgradedEffects": [{"t": "discardSubHand", "sub": "tome", "n": 1}, {"t": "draw", "n": 3}],
	},
	"restoration": {
		"id": "restoration", "name": "回復", "type": "skill", "aiTag": "effect",
		"archetype": "magic", "subArchetypes": ["arcane"],
		"cost": 1, "rarity": "uncommon", "owner": "shared",
		"requireSubsInHand": ["water", "wind", "earth"],
		"text": "「水」「風」「地」カードを1枚ずつ捨てる。体力を全回復する。",
		"upgradedText": "「水」「風」「地」カードを1枚ずつ捨てる。体力を全回復する。",
		"flavor": "異なる流れが、ひとつの命を満たす。", "art": "res://art/pixel/cards/restoration.jpg", "target": "none",
		"effects": [{"t": "discardSubsHand", "subs": ["water", "wind", "earth"]}, {"t": "healFull"}],
		"upgradedEffects": [{"t": "discardSubsHand", "subs": ["water", "wind", "earth"]}, {"t": "healFull"}],
	},
	## ---- テスト用カード（基盤機構の動作確認用） ----
	"test_black_sheep": {
		"id": "test_black_sheep",
		"name": "黒羊（テスト）",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "generic",
		"cost": 0,
		"rarity": "common",
		"owner": "investigator",
		"subArchetypes": ["earth"],
		"vanishOnUse": true,
		"text": "（テスト）使用後に完全に消滅する。サブ属性「地」。",
		"upgradedText": "（テスト）使用後に完全に消滅する。サブ属性「地」。",
		"art": "",
		"target": "none",
		"effects": [],
		"upgradedEffects": [],
	},
}


const ALL_PACK_IDS := ["silver_key", "collapse", "omnipotence", "transcendent"]
const ALL_SET_COUNT := 16

const CARD_FRAME_CLASSES := [
	"frame-card-common",
	"frame-card-uncommon",
	"frame-card",
	"frame-card-greatold",
	"frame-card-elder",
	"frame-card-outer",
]

const _MYTHOS_FRAME_ARCHETYPES := ["greatold", "elder", "outer", "all", "knight", "magic", "wind", "fire", "earth", "bastet"]

const _AI_TRANSLATABLE := [
	"damage",
	"damageAll",
	"block",
	"blockPerEnemy",
	"strength",
	"weak",
	"vulnerable",
	"poison",
	"addDread",
	"heal",
]

const _AI_EXCLUDED_IDS := [
	"adapted_scales",
]


## cards.ts getCard()
static func get_card(id: String) -> Dictionary:
	if not CARDS.has(id):
		push_error("Unknown card %s" % id)
		return {}
	var d: Dictionary = CARDS[id]
	var art: String = str(d.get("art", ""))
	var resolved: String = resolve_art(art)
	var upgraded_art: String = str(d.get("upgradedArt", ""))
	var resolved_up: String = resolve_art(upgraded_art) if not upgraded_art.is_empty() else ""
	if resolved != art or (not upgraded_art.is_empty() and resolved_up != upgraded_art):
		var copy: Dictionary = d.duplicate()
		copy["art"] = resolved
		if not upgraded_art.is_empty():
			copy["upgradedArt"] = resolved_up
		return copy
	return d


## 表示用イラスト。強化済みかつ upgradedArt があればそちら。無ければ art。空なら呼び出し側が card_back へフォールバック。
static func card_art(card: Dictionary, def: Dictionary) -> String:
	var upgraded: bool = false
	if not card.is_empty():
		upgraded = card.get("upgraded", false) and true
	if upgraded:
		var upgraded_art: String = str(def.get("upgradedArt", ""))
		if not upgraded_art.is_empty():
			return resolve_art(upgraded_art)
	return resolve_art(str(def.get("art", "")))


static func has_tag(def: Dictionary, tag: String) -> bool:
	var tags = def.get("tags", [])
	return tags is Array and tags.has(tag)


static func has_sub_archetype(def: Dictionary, sub: String) -> bool:
	var subs = def.get("subArchetypes", [])
	return subs is Array and subs.has(sub)


## 未収録のカードイラストを、同系統の既存 jpg へ逃がす。
static func resolve_art(path: String) -> String:
	if path.is_empty():
		return path
	if FileAccess.file_exists(path):
		return path
	return ART_FALLBACK.get(path, path)


## cards.ts frameClassForCard()
static func frame_class_for_card(d: Dictionary) -> String:
	var arch: String = str(d.get("archetype", ""))
	if arch in _MYTHOS_FRAME_ARCHETYPES:
		return "frame-card-%s" % arch
	var rarity: String = str(d.get("rarity", ""))
	if rarity == "rare":
		return "frame-card"
	if rarity == "uncommon":
		return "frame-card-uncommon"
	if rarity == "common":
		return "frame-card-common"
	return ""


static func _has_translatable_effect(card: Dictionary) -> bool:
	var effects: Array = []
	effects.append_array(card.get("effects", []))
	effects.append_array(card.get("upgradedEffects", []))
	for e in effects:
		if e.get("t") == "draw":
			return false
	for e in effects:
		var t: String = str(e.get("t", ""))
		if t == "seal":
			return true
		if t in _AI_TRANSLATABLE:
			return true
		if t == "sanity" and typeof(e.get("n")) in [TYPE_INT, TYPE_FLOAT] and float(e.get("n")) < 0:
			return true
	return false


## cards.ts aiCardPool()
static func ai_card_pool(tag: String, max_rarities = null, archetype = null) -> Array:
	var out: Array = []
	for c in CARDS.values():
		if c.get("type") == "status" or c.get("type") == "power":
			continue
		if c.get("enemyOnly"):
			continue
		if c.get("aiTag") != tag:
			continue
		if not _has_translatable_effect(c):
			continue
		if str(c.get("id", "")) in _AI_EXCLUDED_IDS:
			continue
		if max_rarities != null and not (c.get("rarity") in max_rarities):
			continue
		if archetype != null and c.get("archetype") and c.get("archetype") != archetype:
			continue
		out.append(c)
	return out


## cards.ts aiCardPoolFrom()
static func ai_card_pool_from(deck_ids: Array, tag: String) -> Array:
	var out: Array = []
	for id in deck_ids:
		if not CARDS.has(id):
			continue
		var c: Dictionary = CARDS[id]
		if c.get("type") == "status" or c.get("type") == "power":
			continue
		if c.get("aiTag") != tag:
			continue
		if _has_translatable_effect(c):
			out.append(c)
	return out


## cards.ts makeCard()
static func make_card(def_id: String, upgraded: bool = false) -> Dictionary:
	var d := get_card(def_id)
	var inst := {
		"uid": Mulberry32.uid("c"),
		"defId": def_id,
		"upgraded": upgraded,
	}
	if d.has("charges"):
		inst["charges"] = d["charges"]
	return inst


## cards.ts cardText()
static func card_text(card: Dictionary) -> String:
	var d := get_card(str(card.get("defId", "")))
	return str(d.get("upgradedText") if card.get("upgraded") else d.get("text"))


## cards.ts cardCost()
static func card_cost(card: Dictionary) -> int:
	var d := get_card(str(card.get("defId", "")))
	if d.get("xCost"):
		return 0
	if card.get("upgraded") and d.has("upgradedCost"):
		return int(d["upgradedCost"])
	return int(d.get("cost", 0))


## cards.ts cardEffects()
static func card_effects(card: Dictionary) -> Array:
	var d := get_card(str(card.get("defId", "")))
	if card.get("upgraded"):
		return d.get("upgradedEffects", [])
	return d.get("effects", [])


## cards.ts scaleN()
static func scale_n(n: int, card = null) -> int:
	if card == null or not card.get("forge") or card.get("forge") == 1:
		return n
	var def: Dictionary = get_card(str(card.get("defId", "")))
	## fixedForgeUpgrade は鍛冶屋廃止後、新規には付かない。既存セーブの forge 済み用に残す。
	if def.get("fixedForgeUpgrade", false) and card.get("upgraded", false):
		return n
	return maxi(1, int(floor(float(n) * float(card.get("forge")))))


## cards.ts rewardPool()
static func reward_pool(owner: String) -> Array:
	var out: Array = []
	for c in CARDS.values():
		if c.get("rarity") == "status":
			continue
		if c.get("grimoire") or c.get("shop") or c.get("enemyOnly") or c.get("packOnly"):
			continue
		if c.get("retired") or c.get("unobtainable"):
			continue
		if c.get("owner") == "shared" or c.get("owner") == owner:
			out.append(c)
	return out


## store.ts の archetypeCardPool()。rewardPool()と異なりshopフラグ付きカードも含む
## （旧支配者等、鍛冶屋専用装備しか存在しないアーキタイプでもパックが保証できるようにするため）。
static func archetype_card_pool(owner: String, archetype: String) -> Array:
	var out: Array = []
	for c in CARDS.values():
		if c.get("archetype") != archetype:
			continue
		if c.get("rarity") == "status":
			continue
		if c.get("grimoire") or c.get("enemyOnly") or c.get("packOnly"):
			continue
		if c.get("retired") or c.get("unobtainable"):
			continue
		if c.get("owner") == "shared" or c.get("owner") == owner:
			out.append(c)
	return out


## 複数アーキタイプのパック強制枠。空の属性は飛ばし、全部空なら呼び出し側が reward_pool に逃がす。
static func archetype_card_pool_multi(owner: String, archetypes: Array) -> Array:
	var out: Array = []
	for archetype in archetypes:
		var part: Array = archetype_card_pool(owner, str(archetype))
		for card in part:
			out.append(card)
	return out


## store.ts の weightedCard() が両関数で共有するレアリティ→プール絞り込みロジック
static func _rarity_sliced_pool(pool: Array, rand: Callable) -> Array:
	var roll: float = rand.call()
	var rarity := "common" if roll < 0.62 else ("uncommon" if roll < 0.9 else "rare")
	var sliced: Array = pool.filter(func(c): return c.get("rarity") == rarity)
	return sliced if not sliced.is_empty() else pool


## store.ts の weightedCard(owner, rand)。所持枚数が少ないカードほど選ばれやすい
## （1 / (1 + 所持数)）重み付けで rewardPool(owner) から1枚選ぶ。
static func weighted_card(owner: String, rand: Callable) -> Dictionary:
	var pool := reward_pool(owner)
	var candidates := _rarity_sliced_pool(pool, rand)
	var owned: Array = CollectionData.inventory.cards
	var def: Dictionary = Mulberry32.weighted_pick_by(candidates, func(c):
		var n := 0
		for o in owned:
			if str(o.get("base_card_id", "")) == str(c.get("id", "")):
				n += 1
		return 1.0 / (1.0 + float(n))
	, rand)
	return make_card(str(def.get("id", "")), false)


## store.ts の weightedArchetypeCard(owner, archetype, rand)
static func weighted_archetype_card(owner: String, archetype: String, rand: Callable) -> Dictionary:
	return weighted_archetype_cards(owner, [archetype], rand)


## 旧支配者（greatold+wind+fire）と外宇宙（outer+earth）の混合強制枠。
## 単一属性は weighted_archetype_card がこの関数へ渡す。プールが空なら reward_pool に逃がす。
static func weighted_archetype_cards(owner: String, archetypes: Array, rand: Callable) -> Dictionary:
	var pool: Array = archetype_card_pool_multi(owner, archetypes)
	var base_pool: Array = pool if not pool.is_empty() else reward_pool(owner)
	var candidates: Array = _rarity_sliced_pool(base_pool, rand)
	var owned: Array = CollectionData.inventory.cards
	var def: Dictionary = Mulberry32.weighted_pick_by(candidates, func(c):
		var n := 0
		for o in owned:
			if str(o.get("base_card_id", "")) == str(c.get("id", "")):
				n += 1
		return 1.0 / (1.0 + float(n))
	, rand)
	return make_card(str(def.get("id", "")), false)


static func pick_all_pack_card(rand: Callable) -> Dictionary:
	var def_id: String = str(Mulberry32.pick_rand(ALL_PACK_IDS, rand))
	return make_card(def_id, false)


static func count_all_in_deck(deck: Array) -> int:
	var n: int = 0
	for card in deck:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var def: Dictionary = get_card(str(card.get("defId", "")))
		if str(def.get("archetype", "")) == "all":
			n += 1
	return n
