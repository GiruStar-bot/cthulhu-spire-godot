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
}

const ART_FALLBACK := {
	"res://art/pixel/cards/ancient_wisdom.jpg": "res://art/pixel/cards/tome.jpg",
	"res://art/pixel/cards/order_protection.jpg": "res://art/pixel/cards/ward.jpg",
	"res://art/pixel/cards/calm_blessing.jpg": "res://art/pixel/cards/resolve.jpg",
	"res://art/pixel/cards/sealing_moment.jpg": "res://art/pixel/cards/sigil.jpg",
	"res://art/pixel/cards/wardlight_afterglow.jpg": "res://art/pixel/cards/eldersign.jpg",
	"res://art/pixel/cards/venom_blade.jpg": "res://art/pixel/cards/corrosive_strike.jpg",
	"res://art/pixel/cards/corroding_barrage.jpg": "res://art/pixel/cards/corrosive_strike.jpg",
	"res://art/pixel/cards/toxic_mist.jpg": "res://art/pixel/cards/pus_mist.jpg",
	"res://art/pixel/cards/pustule_armor.jpg": "res://art/pixel/cards/adapted_scales.jpg",
	"res://art/pixel/cards/venom_potency.jpg": "res://art/pixel/cards/pus_mist.jpg",
	"res://art/pixel/cards/self_poisoning.jpg": "res://art/pixel/cards/bloodpact.jpg",
}

const CARDS := {
	"strike": {
		"id": "strike",
		"name": "打撃",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "generic",
		"cost": 1,
		"rarity": "starter",
		"owner": "investigator",
		"text": "6ダメージ。",
		"upgradedText": "9ダメージ。",
		"flavor": "肉体は、まだ拳を信じている。",
		"art": "res://art/pixel/cards/strike.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 6,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 9,
			},
		],
	},
	"ward": {
		"id": "ward",
		"name": "結界",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "knight",
		"cost": 1,
		"rarity": "starter",
		"owner": "investigator",
		"text": "ブロック5を得る。",
		"upgradedText": "ブロック8を得る。",
		"flavor": "塩の円。長くは持たない。",
		"art": "res://art/pixel/cards/ward.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 5,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 8,
			},
		],
	},
	"study": {
		"id": "study",
		"name": "精読",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "outer",
		"cost": 1,
		"rarity": "starter",
		"owner": "investigator",
		"text": "2枚引く。正気を2失う。",
		"upgradedText": "3枚引く。正気を2失う。",
		"flavor": "一頁ごとに、少しずつ削れる。",
		"art": "res://art/pixel/cards/study.jpg",
		"target": "none",
		"effects": [
			{
				"t": "draw",
				"n": 2,
			},
			{
				"t": "sanity",
				"n": -2,
			},
		],
		"upgradedEffects": [
			{
				"t": "draw",
				"n": 3,
			},
			{
				"t": "sanity",
				"n": -2,
			},
		],
	},
	"lash": {
		"id": "lash",
		"name": "鞭撃",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "generic",
		"cost": 1,
		"rarity": "starter",
		"owner": "cultist",
		"text": "7ダメージ。",
		"upgradedText": "10ダメージ。",
		"flavor": "打てば、何かが応える。",
		"art": "res://art/pixel/cards/lash.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 7,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 10,
			},
		],
	},
	"sigil": {
		"id": "sigil",
		"name": "印",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "knight",
		"cost": 1,
		"rarity": "starter",
		"owner": "cultist",
		"text": "ブロック5を得る。",
		"upgradedText": "ブロック8を得る。",
		"flavor": "掌の印が、冷たく燃える。",
		"art": "res://art/pixel/cards/sigil.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 5,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 8,
			},
		],
	},
	"whisper": {
		"id": "whisper",
		"name": "囁き",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "outer",
		"cost": 0,
		"rarity": "starter",
		"owner": "cultist",
		"text": "1枚引く。正気を2失う。",
		"upgradedText": "2枚引く。正気を2失う。",
		"flavor": "すでに、話していた。",
		"art": "res://art/pixel/cards/whisper.jpg",
		"target": "none",
		"effects": [
			{
				"t": "draw",
				"n": 1,
			},
			{
				"t": "sanity",
				"n": -2,
			},
		],
		"upgradedEffects": [
			{
				"t": "draw",
				"n": 2,
			},
			{
				"t": "sanity",
				"n": -2,
			},
		],
	},
	"precise": {
		"id": "precise",
		"name": "計測打撃",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "generic",
		"cost": 1,
		"rarity": "common",
		"owner": "investigator",
		"text": "8ダメージ。敵の意図が攻撃なら、さらに5。",
		"upgradedText": "11ダメージ。敵の意図が攻撃なら、さらに6。",
		"flavor": "死にかけても、記録は続ける。",
		"art": "res://art/pixel/cards/precise.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 8,
			},
			{
				"t": "ifIntentAttack",
				"then": [
					{
						"t": "damage",
						"n": 5,
					},
				],
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 11,
			},
			{
				"t": "ifIntentAttack",
				"then": [
					{
						"t": "damage",
						"n": 6,
					},
				],
			},
		],
	},
	"dressing": {
		"id": "dressing",
		"name": "応急処置",
		"type": "skill",
		"aiTag": "defense",
		"cost": 1,
		"rarity": "common",
		"owner": "investigator",
		"text": "ブロック7を得る。3回復。",
		"upgradedText": "ブロック10を得る。4回復。",
		"flavor": "布と、意地。",
		"art": "res://art/pixel/cards/dressing.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 7,
			},
			{
				"t": "heal",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "heal",
				"n": 4,
			},
		],
	},
	"bloodpact": {
		"id": "bloodpact",
		"name": "血契",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "offering",
		"cost": 0,
		"rarity": "common",
		"owner": "shared",
		"text": "体力を4失う。エネルギーを2得る。",
		"upgradedText": "体力を3失う。エネルギーを2得る。",
		"flavor": "インクは、インク以上を受け入れる。",
		"art": "res://art/pixel/cards/bloodpact.jpg",
		"target": "none",
		"effects": [
			{
				"t": "hpCost",
				"n": 4,
			},
			{
				"t": "energy",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "hpCost",
				"n": 3,
			},
			{
				"t": "energy",
				"n": 2,
			},
		],
	},
	"insight": {
		"id": "insight",
		"name": "啓示",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "outer",
		"cost": 1,
		"rarity": "common",
		"owner": "shared",
		"text": "2枚引く。エネルギーを1得る。正気を3失う。",
		"upgradedText": "3枚引く。エネルギーを1得る。正気を3失う。",
		"flavor": "模様は、最初からそこにあった。",
		"art": "res://art/pixel/cards/insight.jpg",
		"target": "none",
		"effects": [
			{
				"t": "draw",
				"n": 2,
			},
			{
				"t": "energy",
				"n": 1,
			},
			{
				"t": "sanity",
				"n": -3,
			},
		],
		"upgradedEffects": [
			{
				"t": "draw",
				"n": 3,
			},
			{
				"t": "energy",
				"n": 1,
			},
			{
				"t": "sanity",
				"n": -3,
			},
		],
	},
	"offering": {
		"id": "offering",
		"name": "供物",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "fanatic",
		"cost": 1,
		"rarity": "common",
		"owner": "cultist",
		"text": "正気を5失う。14ダメージ。",
		"upgradedText": "正気を4失う。18ダメージ。",
		"flavor": "それは、君の味を好む。",
		"art": "res://art/pixel/cards/offering.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "sanity",
				"n": -5,
			},
			{
				"t": "damage",
				"n": 14,
			},
		],
		"upgradedEffects": [
			{
				"t": "sanity",
				"n": -4,
			},
			{
				"t": "damage",
				"n": 18,
			},
		],
	},
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
	"sweep": {
		"id": "sweep",
		"name": "闇の薙ぎ",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "deep",
		"cost": 1,
		"rarity": "common",
		"owner": "cultist",
		"text": "敵全体に5ダメージ。",
		"upgradedText": "敵全体に8ダメージ。",
		"flavor": "回廊は、見た目より長い。",
		"art": "res://art/pixel/cards/sweep.jpg",
		"target": "all",
		"effects": [
			{
				"t": "damageAll",
				"n": 5,
			},
		],
		"upgradedEffects": [
			{
				"t": "damageAll",
				"n": 8,
			},
		],
	},
	"ironwill": {
		"id": "ironwill",
		"name": "鉄の意志",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "knight",
		"cost": 2,
		"rarity": "uncommon",
		"owner": "investigator",
		"text": "ブロック12を得る。筋力を2得る。",
		"upgradedText": "ブロック16を得る。筋力を3得る。",
		"flavor": "廊下の形を、拒む。",
		"art": "res://art/pixel/cards/ironwill.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 12,
			},
			{
				"t": "strength",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 16,
			},
			{
				"t": "strength",
				"n": 3,
			},
		],
	},
	"resolve": {
		"id": "resolve",
		"name": "覚悟",
		"type": "power",
		"aiTag": "effect",
		"cost": 1,
		"rarity": "uncommon",
		"owner": "investigator",
		"text": "攻撃を出すたび、ブロック3を得る。",
		"upgradedText": "攻撃を出すたび、ブロック4を得る。",
		"flavor": "習慣は、希望より長く生きる。",
		"art": "res://art/pixel/cards/resolve.jpg",
		"target": "none",
		"effects": [
			{
				"t": "gainPower",
				"id": "resolve",
			},
		],
		"upgradedEffects": [
			{
				"t": "gainPower",
				"id": "resolve",
			},
		],
	},
	"echo": {
		"id": "echo",
		"name": "残響",
		"type": "power",
		"aiTag": "effect",
		"archetype": "elder",
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
	"rite": {
		"id": "rite",
		"name": "眼の儀式",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "fanatic",
		"cost": 0,
		"rarity": "uncommon",
		"owner": "cultist",
		"text": "2枚引く。脆弱1を与える。正気を4失う。",
		"upgradedText": "2枚引く。脆弱2を与える。正気を3失う。",
		"flavor": "見よ。そして、見られよ。",
		"art": "res://art/pixel/cards/rite.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "draw",
				"n": 2,
			},
			{
				"t": "vulnerable",
				"n": 1,
			},
			{
				"t": "sanity",
				"n": -4,
			},
		],
		"upgradedEffects": [
			{
				"t": "draw",
				"n": 2,
			},
			{
				"t": "vulnerable",
				"n": 2,
			},
			{
				"t": "sanity",
				"n": -3,
			},
		],
	},
	"oath": {
		"id": "oath",
		"name": "血の誓い",
		"type": "power",
		"aiTag": "effect",
		"archetype": "elder",
		"cost": 1,
		"rarity": "uncommon",
		"owner": "shared",
		"text": "正気を失うたび、筋力を2得る。",
		"upgradedText": "正気を失うたび、筋力を3得る。",
		"flavor": "すでに署名した契約。",
		"art": "res://art/pixel/cards/oath.jpg",
		"target": "none",
		"effects": [
			{
				"t": "gainPower",
				"id": "bloodOath",
			},
		],
		"upgradedEffects": [
			{
				"t": "gainPower",
				"id": "bloodOath",
			},
		],
	},
	"bash": {
		"id": "bash",
		"name": "破砕",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "knight",
		"cost": 2,
		"rarity": "uncommon",
		"owner": "investigator",
		"text": "10ダメージ。脆弱2を与える。",
		"upgradedText": "13ダメージ。脆弱3を与える。",
		"flavor": "扉の中には、人がいる。",
		"art": "res://art/pixel/cards/bash.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 10,
			},
			{
				"t": "vulnerable",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 13,
			},
			{
				"t": "vulnerable",
				"n": 3,
			},
		],
	},
	"tome": {
		"id": "tome",
		"name": "禁断の書",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "fanatic",
		"cost": 1,
		"rarity": "rare",
		"owner": "investigator",
		"text": "3枚引く。筋力を2得る。正気を6失う。",
		"upgradedText": "4枚引く。筋力を3得る。正気を5失う。",
		"flavor": "最終章は、君の筆跡で書かれている。",
		"art": "res://art/pixel/cards/tome.jpg",
		"target": "none",
		"effects": [
			{
				"t": "draw",
				"n": 3,
			},
			{
				"t": "strength",
				"n": 2,
			},
			{
				"t": "sanity",
				"n": -6,
			},
		],
		"upgradedEffects": [
			{
				"t": "draw",
				"n": 4,
			},
			{
				"t": "strength",
				"n": 3,
			},
			{
				"t": "sanity",
				"n": -5,
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
	"ancient_wisdom": {
		"id": "ancient_wisdom",
		"name": "古の叡智",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "elder",
		"cost": 1,
		"rarity": "common",
		"owner": "shared",
		"text": "2枚引く。",
		"upgradedText": "3枚引く。",
		"flavor": "読み解ける者にしか、価値の無い書物。",
		"art": "res://art/pixel/cards/ancient_wisdom.jpg",
		"target": "none",
		"effects": [
			{
				"t": "draw",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "draw",
				"n": 3,
			},
		],
	},
	"order_protection": {
		"id": "order_protection",
		"name": "秩序の守り",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "elder",
		"cost": 1,
		"rarity": "uncommon",
		"owner": "shared",
		"text": "ブロック6を得る。毒を治療する。",
		"upgradedText": "ブロック9を得る。毒を治療する。",
		"flavor": "秩序は、混沌を体外へ押し出す。",
		"art": "res://art/pixel/cards/order_protection.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "curePoison",
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 9,
			},
			{
				"t": "curePoison",
			},
		],
	},
	"calm_blessing": {
		"id": "calm_blessing",
		"name": "静穏の加護",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "elder",
		"cost": 1,
		"rarity": "uncommon",
		"owner": "shared",
		"text": "3回復。ブロック5を得る。",
		"upgradedText": "5回復。ブロック7を得る。",
		"flavor": "古き神々は、時に慈悲深い。",
		"art": "res://art/pixel/cards/calm_blessing.jpg",
		"target": "none",
		"effects": [
			{
				"t": "heal",
				"n": 3,
			},
			{
				"t": "block",
				"n": 5,
			},
		],
		"upgradedEffects": [
			{
				"t": "heal",
				"n": 5,
			},
			{
				"t": "block",
				"n": 7,
			},
		],
	},
	"sealing_moment": {
		"id": "sealing_moment",
		"name": "封印の刻",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "elder",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "相手の技能を封じる。",
		"upgradedText": "相手の技能を封じる。ブロック5を得る。",
		"flavor": "言葉は、発せられる前に凍りつく。",
		"art": "res://art/pixel/cards/sealing_moment.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "sealEnemy",
				"value": "skill",
			},
		],
		"upgradedEffects": [
			{
				"t": "sealEnemy",
				"value": "skill",
			},
			{
				"t": "block",
				"n": 5,
			},
		],
	},
	"wardlight_afterglow": {
		"id": "wardlight_afterglow",
		"name": "護符の残光",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "elder",
		"cost": 1,
		"rarity": "common",
		"owner": "shared",
		"text": "ブロック10を得る。",
		"upgradedText": "ブロック14を得る。",
		"flavor": "光が消えても、守りはまだそこにある。",
		"art": "res://art/pixel/cards/wardlight_afterglow.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 10,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 14,
			},
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
	"corrosive_strike": {
		"id": "corrosive_strike",
		"name": "腐食の一撃",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "poison",
		"cost": 1,
		"rarity": "common",
		"owner": "investigator",
		"text": "5ダメージ。毒2を与える。",
		"upgradedText": "7ダメージ。毒3を与える。",
		"flavor": "刃が触れた場所から、腐敗が始まる。",
		"art": "res://art/pixel/cards/corrosive_strike.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 5,
			},
			{
				"t": "poison",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 7,
			},
			{
				"t": "poison",
				"n": 3,
			},
		],
	},
	"pus_mist": {
		"id": "pus_mist",
		"name": "膿の霧",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "poison",
		"cost": 1,
		"rarity": "uncommon",
		"owner": "cultist",
		"text": "敵全体に弱体1、毒3を与える。",
		"upgradedText": "敵全体に弱体2、毒4を与える。",
		"flavor": "息を吸うだけで、肺が腐っていく。",
		"art": "res://art/pixel/cards/pus_mist.jpg",
		"target": "all",
		"effects": [
			{
				"t": "weak",
				"n": 1,
			},
			{
				"t": "poison",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "weak",
				"n": 2,
			},
			{
				"t": "poison",
				"n": 4,
			},
		],
	},
	"venom_blade": {
		"id": "venom_blade",
		"name": "猛毒の刃",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "poison",
		"cost": 1,
		"rarity": "common",
		"owner": "investigator",
		"text": "6ダメージ。毒3を与える。",
		"upgradedText": "8ダメージ。毒4を与える。",
		"flavor": "刃先に塗られた毒液は、いかなる傷も致命傷に変える。",
		"art": "res://art/pixel/cards/venom_blade.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 6,
			},
			{
				"t": "poison",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 8,
			},
			{
				"t": "poison",
				"n": 4,
			},
		],
	},
	"corroding_barrage": {
		"id": "corroding_barrage",
		"name": "腐食の乱打",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "poison",
		"cost": 2,
		"rarity": "uncommon",
		"owner": "investigator",
		"text": "4ダメージ、毒2を与える動作を2回。",
		"upgradedText": "5ダメージ、毒3を与える動作を2回。",
		"flavor": "一度目は傷、二度目は死の宣告。",
		"art": "res://art/pixel/cards/corroding_barrage.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 4,
			},
			{
				"t": "poison",
				"n": 2,
			},
			{
				"t": "damage",
				"n": 4,
			},
			{
				"t": "poison",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 5,
			},
			{
				"t": "poison",
				"n": 3,
			},
			{
				"t": "damage",
				"n": 5,
			},
			{
				"t": "poison",
				"n": 3,
			},
		],
	},
	"toxic_mist": {
		"id": "toxic_mist",
		"name": "毒霧散布",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "poison",
		"cost": 1,
		"rarity": "common",
		"owner": "cultist",
		"text": "敵全体に毒2を与える。",
		"upgradedText": "敵全体に毒3を与える。",
		"flavor": "風に乗って、静かに広がっていく。",
		"art": "res://art/pixel/cards/toxic_mist.jpg",
		"target": "all",
		"effects": [
			{
				"t": "poison",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "poison",
				"n": 3,
			},
		],
	},
	"pustule_armor": {
		"id": "pustule_armor",
		"name": "膿の鎧",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "poison",
		"cost": 1,
		"rarity": "common",
		"owner": "investigator",
		"text": "ブロック9を得る。",
		"upgradedText": "ブロック13を得る。",
		"flavor": "腐りゆく皮膚もまた、鎧になる。",
		"art": "res://art/pixel/cards/pustule_armor.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 9,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 13,
			},
		],
	},
	"venom_potency": {
		"id": "venom_potency",
		"name": "猛毒強化",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "poison",
		"cost": 1,
		"rarity": "rare",
		"owner": "cultist",
		"text": "敵に毒5、弱体1を与える。",
		"upgradedText": "敵に毒7、弱体2を与える。",
		"flavor": "毒はもう、血の一部になっている。",
		"art": "res://art/pixel/cards/venom_potency.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "poison",
				"n": 5,
			},
			{
				"t": "weak",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "poison",
				"n": 7,
			},
			{
				"t": "weak",
				"n": 2,
			},
		],
	},
	"self_poisoning": {
		"id": "self_poisoning",
		"name": "自家中毒",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "poison",
		"cost": 0,
		"rarity": "uncommon",
		"owner": "investigator",
		"text": "体力を3失う。筋力2を得る。",
		"upgradedText": "体力を3失う。筋力3を得る。",
		"flavor": "毒に慣れた体は、毒を糧にする。",
		"art": "res://art/pixel/cards/self_poisoning.jpg",
		"target": "none",
		"effects": [
			{
				"t": "hpCost",
				"n": 3,
			},
			{
				"t": "strength",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "hpCost",
				"n": 3,
			},
			{
				"t": "strength",
				"n": 3,
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
	"deep_breath": {
		"id": "deep_breath",
		"name": "深海の呼吸",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "deep",
		"cost": 2,
		"rarity": "uncommon",
		"owner": "shared",
		"text": "ブロック10を得る。5回復。",
		"upgradedText": "ブロック13を得る。6回復。",
		"flavor": "水圧の底でだけ、息が楽になる。",
		"art": "res://art/pixel/cards/deep_breath.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "heal",
				"n": 5,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 13,
			},
			{
				"t": "heal",
				"n": 6,
			},
		],
	},
	"deep_ones_blessing": {
		"id": "deep_ones_blessing",
		"name": "深きものの加護",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "deep",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"exhaust": true,
		"text": "8回復。自身の毒を全て解除する。廃棄。",
		"upgradedText": "11回復。自身の毒を全て解除する。廃棄。",
		"flavor": "深淵は、毒すらも古い記憶に変える。",
		"art": "res://art/pixel/cards/deep_ones_blessing.jpg",
		"target": "none",
		"effects": [
			{
				"t": "heal",
				"n": 8,
			},
			{
				"t": "curePoison",
			},
		],
		"upgradedEffects": [
			{
				"t": "heal",
				"n": 11,
			},
			{
				"t": "curePoison",
			},
		],
	},
	"self_offering": {
		"id": "self_offering",
		"name": "己を捧げる",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "offering",
		"cost": 0,
		"rarity": "common",
		"owner": "cultist",
		"text": "体力を3失う。1枚引く。",
		"upgradedText": "体力を2失う。1枚引く。",
		"flavor": "痛みは、答えを急かす。",
		"art": "res://art/pixel/cards/self_offering.jpg",
		"target": "none",
		"effects": [
			{
				"t": "hpCost",
				"n": 3,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "hpCost",
				"n": 2,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
	},
	"blood_toll": {
		"id": "blood_toll",
		"name": "血の代価",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "offering",
		"cost": 1,
		"rarity": "uncommon",
		"owner": "investigator",
		"text": "体力を4失う。18ダメージ。",
		"upgradedText": "体力を4失う。24ダメージ。",
		"flavor": "己の血を対価に、刃を振るう。",
		"art": "res://art/pixel/cards/blood_toll.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "hpCost",
				"n": 4,
			},
			{
				"t": "damage",
				"n": 18,
			},
		],
		"upgradedEffects": [
			{
				"t": "hpCost",
				"n": 4,
			},
			{
				"t": "damage",
				"n": 24,
			},
		],
	},
	"final_offering": {
		"id": "final_offering",
		"name": "終の供物",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "offering",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"exhaust": true,
		"text": "体力を半分失う。敵全体に30ダメージ。廃棄。",
		"upgradedText": "体力を半分失う。敵全体に38ダメージ。廃棄。",
		"flavor": "全てを差し出した者だけが、聞く声がある。",
		"art": "res://art/pixel/cards/final_offering.jpg",
		"target": "all",
		"effects": [
			{
				"t": "hpCostHalf",
			},
			{
				"t": "damageAll",
				"n": 30,
			},
		],
		"upgradedEffects": [
			{
				"t": "hpCostHalf",
			},
			{
				"t": "damageAll",
				"n": 38,
			},
		],
	},
	"into_the_dark": {
		"id": "into_the_dark",
		"name": "暗がりへ",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "shadow",
		"cost": 1,
		"rarity": "common",
		"owner": "investigator",
		"text": "無形1ターンを得る。",
		"upgradedText": "無形1ターンを得る。1枚引く。",
		"flavor": "見えなければ、傷つかない。",
		"art": "res://art/pixel/cards/into_the_dark.jpg",
		"target": "none",
		"effects": [
			{
				"t": "intangible",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "intangible",
				"n": 1,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
	},
	"blindside_strike": {
		"id": "blindside_strike",
		"name": "死角からの一撃",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "shadow",
		"cost": 2,
		"rarity": "uncommon",
		"owner": "cultist",
		"text": "7ダメージ。無形1ターンを得る。",
		"upgradedText": "10ダメージ。無形1ターンを得る。",
		"flavor": "斬った後には、もう誰もいない。",
		"art": "res://art/pixel/cards/blindside_strike.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 7,
			},
			{
				"t": "intangible",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 10,
			},
			{
				"t": "intangible",
				"n": 1,
			},
		],
	},
	"perfect_stealth": {
		"id": "perfect_stealth",
		"name": "完全なる隠密",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "shadow",
		"cost": 2,
		"rarity": "rare",
		"owner": "investigator",
		"exhaust": true,
		"text": "無形2ターンを得る。1枚引く。廃棄。",
		"upgradedText": "無形3ターンを得る。1枚引く。廃棄。",
		"flavor": "完全に消えた者に、刃は届かない。",
		"art": "res://art/pixel/cards/perfect_stealth.jpg",
		"target": "none",
		"effects": [
			{
				"t": "intangible",
				"n": 2,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "intangible",
				"n": 3,
			},
			{
				"t": "draw",
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
	"all-vacuum": {
		"id": "all-vacuum",
		"name": "擬似真空",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "poison",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"text": "弱体1、毒5。このターン、攻撃するたび自分は1。",
		"upgradedText": "弱体1、毒7。このターン、攻撃するたび自分は1。",
		"flavor": "肺の中を、無にする。",
		"art": "res://art/pixel/cards/all-vacuum.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "weak",
				"n": 1,
			},
			{
				"t": "poison",
				"n": 5,
			},
			{
				"t": "attackSelfHurt",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "weak",
				"n": 1,
			},
			{
				"t": "poison",
				"n": 7,
			},
			{
				"t": "attackSelfHurt",
				"n": 1,
			},
		],
	},
	"all-phase": {
		"id": "all-phase",
		"name": "位相遅延",
		"type": "skill",
		"aiTag": "defense",
		"archetype": "knight",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"text": "ブロック12。次のターン開始時、このターン失ったブロック分ダメージ。",
		"upgradedText": "ブロック16。次のターン開始時、このターン失ったブロック分ダメージ。",
		"flavor": "痛みを、遅らせて返す。",
		"art": "res://art/pixel/cards/all-phase.jpg",
		"target": "none",
		"effects": [
			{
				"t": "block",
				"n": 12,
			},
			{
				"t": "phaseDelay",
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 16,
			},
			{
				"t": "phaseDelay",
			},
		],
	},
	"all-blind": {
		"id": "all-blind",
		"name": "知覚盲点",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "shadow",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"exhaust": true,
		"text": "無形1ターン。次の攻撃が2倍。廃棄。",
		"upgradedText": "無形1ターン。次の攻撃が2倍。廃棄。",
		"flavor": "光子を、届かせない。",
		"art": "res://art/pixel/cards/all-blind.jpg",
		"target": "none",
		"effects": [
			{
				"t": "intangible",
				"n": 1,
			},
			{
				"t": "nextAttackMul",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "intangible",
				"n": 1,
			},
			{
				"t": "nextAttackMul",
				"n": 2,
			},
		],
	},
	"all-overclock": {
		"id": "all-overclock",
		"name": "シナプス・オーバークロック",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "outer",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"text": "自分は4（貫通）。エネルギー+2。2枚引く。",
		"upgradedText": "自分は4（貫通）。エネルギー+2。3枚引く。",
		"flavor": "リミッターを、壊す。",
		"art": "res://art/pixel/cards/all-overclock.jpg",
		"target": "none",
		"effects": [
			{
				"t": "hpCost",
				"n": 4,
			},
			{
				"t": "energy",
				"n": 2,
			},
			{
				"t": "draw",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "hpCost",
				"n": 4,
			},
			{
				"t": "energy",
				"n": 2,
			},
			{
				"t": "draw",
				"n": 3,
			},
		],
	},
	"all-glass": {
		"id": "all-glass",
		"name": "骨格のガラス化",
		"type": "attack",
		"aiTag": "attack",
		"archetype": "fanatic",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"text": "7ダメージ。脆弱2。",
		"upgradedText": "7ダメージ。脆弱2。",
		"flavor": "骨に、固有振動を与える。",
		"art": "res://art/pixel/cards/all-glass.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "damage",
				"n": 7,
			},
			{
				"t": "vulnerable",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 7,
			},
			{
				"t": "vulnerable",
				"n": 2,
			},
		],
	},
	"all-necrosis": {
		"id": "all-necrosis",
		"name": "壊死の伝播",
		"type": "skill",
		"aiTag": "effect",
		"archetype": "poison",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"grimoire": true,
		"exhaust": true,
		"text": "弱体2、毒9。廃棄。",
		"upgradedText": "弱体2、毒12。廃棄。",
		"flavor": "分裂を、止める。",
		"art": "res://art/pixel/cards/all-necrosis.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "weak",
				"n": 2,
			},
			{
				"t": "poison",
				"n": 9,
			},
		],
		"upgradedEffects": [
			{
				"t": "weak",
				"n": 2,
			},
			{
				"t": "poison",
				"n": 12,
			},
		],
	},
	"all-diffuse": {
		"id": "all-diffuse",
		"name": "存在確率の拡散",
		"type": "power",
		"aiTag": "effect",
		"archetype": "elder",
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
	"heraldscall": {
		"id": "heraldscall",
		"name": "呼び声",
		"type": "skill",
		"aiTag": "effect",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"enemyOnly": true,
		"text": "脆弱3を与える。恐怖を2枚差し込む。",
		"upgradedText": "脆弱4を与える。恐怖を3枚差し込む。",
		"flavor": "その声を聞いた者は、二度と元には戻れない。",
		"art": "res://art/pixel/cards/heraldscall.jpg",
		"target": "enemy",
		"effects": [
			{
				"t": "vulnerable",
				"n": 3,
			},
			{
				"t": "addDread",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "vulnerable",
				"n": 4,
			},
			{
				"t": "addDread",
				"n": 3,
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
	"iron_sword": {
		"id": "iron_sword",
		"name": "鉄剣",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "8ダメージ。",
		"upgradedText": "8ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/iron_sword.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 8,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 8,
			},
		],
	},
	"iron_axe": {
		"id": "iron_axe",
		"name": "鉄斧",
		"type": "attack",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "12ダメージ。",
		"upgradedText": "12ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/iron_axe.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 12,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 12,
			},
		],
	},
	"knife": {
		"id": "knife",
		"name": "ナイフ",
		"type": "attack",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "4ダメージ。",
		"upgradedText": "4ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/knife.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 4,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 4,
			},
		],
	},
	"ritual_dagger": {
		"id": "ritual_dagger",
		"name": "祭祀の短剣",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "10ダメージ。このカードで倒すと2回復。",
		"upgradedText": "10ダメージ。このカードで倒すと2回復。",
		"flavor": "",
		"art": "res://art/pixel/cards/ritual_dagger.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 10,
			},
			{
				"t": "healOnKill",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 10,
			},
			{
				"t": "healOnKill",
				"n": 2,
			},
		],
		"archetype": "fanatic",
	},
	"ghoul_claw": {
		"id": "ghoul_claw",
		"name": "グールの爪剣",
		"type": "attack",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "5ダメージ。毒2。",
		"upgradedText": "5ダメージ。毒2。",
		"flavor": "",
		"art": "res://art/pixel/cards/ghoul_claw.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 5,
			},
			{
				"t": "poison",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 5,
			},
			{
				"t": "poison",
				"n": 2,
			},
		],
	},
	"deep_spear": {
		"id": "deep_spear",
		"name": "深きものの鉾",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "9ダメージ。脆弱1。",
		"upgradedText": "9ダメージ。脆弱1。",
		"flavor": "",
		"art": "res://art/pixel/cards/deep_spear.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 9,
			},
			{
				"t": "vulnerable",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 9,
			},
			{
				"t": "vulnerable",
				"n": 1,
			},
		],
		"archetype": "deep",
	},
	"star_sword": {
		"id": "star_sword",
		"name": "忌まわしき星の剣",
		"type": "attack",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "16ダメージ。デッキに負傷を加える。",
		"upgradedText": "16ダメージ。デッキに負傷を加える。",
		"flavor": "",
		"art": "res://art/pixel/cards/star_sword.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 16,
			},
			{
				"t": "addCurse",
				"id": "wound",
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 16,
			},
			{
				"t": "addCurse",
				"id": "wound",
			},
		],
		"archetype": "greatold",
	},
	"spawn_blade": {
		"id": "spawn_blade",
		"name": "星の落とし子の触手刃",
		"type": "attack",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"text": "24ダメージ。拘束。幻覚が混入する。",
		"upgradedText": "24ダメージ。拘束。幻覚が混入する。",
		"flavor": "",
		"art": "res://art/pixel/cards/spawn_blade.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 24,
			},
			{
				"t": "bind",
			},
			{
				"t": "addCurse",
				"id": "hallucination",
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 24,
			},
			{
				"t": "bind",
			},
			{
				"t": "addCurse",
				"id": "hallucination",
			},
		],
		"archetype": "greatold",
	},
	"cthugha_blade": {
		"id": "cthugha_blade",
		"name": "クトゥグアの炎剣",
		"type": "attack",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "20ダメージ。手札をすべて廃棄。",
		"upgradedText": "20ダメージ。手札をすべて廃棄。",
		"flavor": "",
		"art": "res://art/pixel/cards/cthugha_blade.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 20,
			},
			{
				"t": "exhaustHand",
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 20,
			},
			{
				"t": "exhaustHand",
			},
		],
		"archetype": "outer",
	},
	"nyar_fake": {
		"id": "nyar_fake",
		"name": "ニャルラトホテプの偽剣",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "30ダメージ。手札2枚を戦闘終了まで消す。",
		"upgradedText": "30ダメージ。手札2枚を戦闘終了まで消す。",
		"flavor": "",
		"art": "res://art/pixel/cards/nyar_fake.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 30,
			},
			{
				"t": "banish",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 30,
			},
			{
				"t": "banish",
				"n": 2,
			},
		],
		"archetype": "outer",
	},
	"azathoth_end": {
		"id": "azathoth_end",
		"name": "アザトースの断末魔",
		"type": "attack",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "X×15ダメージ。全エネルギー消費。最大体力が半分になる。",
		"upgradedText": "X×15ダメージ。全エネルギー消費。最大体力が半分になる。",
		"flavor": "",
		"art": "res://art/pixel/cards/azathoth_end.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damageX",
				"n": 15,
			},
			{
				"t": "loseMaxHpHalf",
			},
		],
		"upgradedEffects": [
			{
				"t": "damageX",
				"n": 15,
			},
			{
				"t": "loseMaxHpHalf",
			},
		],
		"xCost": true,
		"archetype": "outer",
	},
	"short_bow": {
		"id": "short_bow",
		"name": "ショートボウ",
		"type": "attack",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "3ダメージ。",
		"upgradedText": "3ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/short_bow.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 3,
			},
		],
	},
	"hunter_bow": {
		"id": "hunter_bow",
		"name": "狩人の弓",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "7ダメージ。",
		"upgradedText": "7ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/hunter_bow.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 7,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 7,
			},
		],
	},
	"crossbow": {
		"id": "crossbow",
		"name": "クロスボウ",
		"type": "attack",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "11ダメージ。",
		"upgradedText": "11ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/crossbow.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 11,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 11,
			},
		],
	},
	"bone_bow": {
		"id": "bone_bow",
		"name": "骨削りの弓",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "5ダメージを2回。",
		"upgradedText": "5ダメージを2回。",
		"flavor": "",
		"art": "res://art/pixel/cards/bone_bow.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 5,
			},
			{
				"t": "damage",
				"n": 5,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 5,
			},
			{
				"t": "damage",
				"n": 5,
			},
		],
	},
	"fanatic_dart": {
		"id": "fanatic_dart",
		"name": "狂信者の吹き矢",
		"type": "attack",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "4ダメージ。手札を1枚捨て、毒3。",
		"upgradedText": "4ダメージ。手札を1枚捨て、毒3。",
		"flavor": "",
		"art": "res://art/pixel/cards/fanatic_dart.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 4,
			},
			{
				"t": "discardRandom",
				"n": 1,
			},
			{
				"t": "poison",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 4,
			},
			{
				"t": "discardRandom",
				"n": 1,
			},
			{
				"t": "poison",
				"n": 3,
			},
		],
		"archetype": "fanatic",
	},
	"migo_gun": {
		"id": "migo_gun",
		"name": "ミ＝ゴの電撃銃",
		"type": "attack",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "敵全体に12ダメージ。",
		"upgradedText": "敵全体に12ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/migo_gun.jpg",
		"target": "all",
		"shop": true,
		"effects": [
			{
				"t": "damageAll",
				"n": 12,
			},
		],
		"upgradedEffects": [
			{
				"t": "damageAll",
				"n": 12,
			},
		],
		"archetype": "outer",
	},
	"elder_staff": {
		"id": "elder_staff",
		"name": "古きものの水晶杖",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "8ダメージ。1枚引く。",
		"upgradedText": "8ダメージ。1枚引く。",
		"flavor": "",
		"art": "res://art/pixel/cards/elder_staff.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 8,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 8,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
		"archetype": "outer",
	},
	"hastur_bow": {
		"id": "hastur_bow",
		"name": "ハスターの風弓",
		"type": "attack",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "敵全体に18ダメージ。弱体1。",
		"upgradedText": "敵全体に18ダメージ。弱体1。",
		"flavor": "",
		"art": "res://art/pixel/cards/hastur_bow.jpg",
		"target": "all",
		"shop": true,
		"effects": [
			{
				"t": "damageAll",
				"n": 18,
			},
			{
				"t": "weak",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "damageAll",
				"n": 18,
			},
			{
				"t": "weak",
				"n": 1,
			},
		],
		"archetype": "greatold",
	},
	"blackwood_bow": {
		"id": "blackwood_bow",
		"name": "黒き森の弓",
		"type": "attack",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "6ダメージを3回。狂気を加える。",
		"upgradedText": "6ダメージを3回。狂気を加える。",
		"flavor": "",
		"art": "res://art/pixel/cards/blackwood_bow.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 6,
			},
			{
				"t": "damage",
				"n": 6,
			},
			{
				"t": "damage",
				"n": 6,
			},
			{
				"t": "addCurse",
				"id": "dread",
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 6,
			},
			{
				"t": "damage",
				"n": 6,
			},
			{
				"t": "damage",
				"n": 6,
			},
			{
				"t": "addCurse",
				"id": "dread",
			},
		],
	},
	"hunter_shot": {
		"id": "hunter_shot",
		"name": "忌まわしき狩人の魔弾",
		"type": "attack",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"text": "40ダメージ。意図を消す。次ターンエネルギー-1。",
		"upgradedText": "40ダメージ。意図を消す。次ターンエネルギー-1。",
		"flavor": "",
		"art": "res://art/pixel/cards/hunter_shot.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "damage",
				"n": 40,
			},
			{
				"t": "cancelIntent",
			},
			{
				"t": "energyNext",
				"n": -1,
			},
		],
		"upgradedEffects": [
			{
				"t": "damage",
				"n": 40,
			},
			{
				"t": "cancelIntent",
			},
			{
				"t": "energyNext",
				"n": -1,
			},
		],
	},
	"yog_gun": {
		"id": "yog_gun",
		"name": "ヨグ＝ソトースの次元銃",
		"type": "attack",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"text": "敵全体に35。次のドローを飛ばす。",
		"upgradedText": "敵全体に35。次のドローを飛ばす。",
		"flavor": "",
		"art": "res://art/pixel/cards/yog_gun.jpg",
		"target": "all",
		"shop": true,
		"effects": [
			{
				"t": "damageAll",
				"n": 35,
			},
			{
				"t": "skipDraw",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "damageAll",
				"n": 35,
			},
			{
				"t": "skipDraw",
				"n": 1,
			},
		],
		"archetype": "outer",
	},
	"iron_shield": {
		"id": "iron_shield",
		"name": "鉄の盾",
		"type": "skill",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック8。",
		"upgradedText": "ブロック8。",
		"flavor": "",
		"art": "res://art/pixel/cards/iron_shield.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 8,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 8,
			},
		],
	},
	"tower_shield": {
		"id": "tower_shield",
		"name": "タワーシールド",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック13。",
		"upgradedText": "ブロック13。",
		"flavor": "",
		"art": "res://art/pixel/cards/tower_shield.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 13,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 13,
			},
		],
	},
	"chain_mail": {
		"id": "chain_mail",
		"name": "鎖帷子",
		"type": "skill",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック5。このターン、ブロックが残る。",
		"upgradedText": "ブロック5。このターン、ブロックが残る。",
		"flavor": "",
		"art": "res://art/pixel/cards/chain_mail.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 5,
			},
			{
				"t": "retainBlock",
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 5,
			},
			{
				"t": "retainBlock",
			},
		],
	},
	"deep_scale": {
		"id": "deep_scale",
		"name": "深きものの鱗鎧",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック16。脆弱1を自分に。",
		"upgradedText": "ブロック16。脆弱1を自分に。",
		"flavor": "",
		"art": "res://art/pixel/cards/deep_scale.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 16,
			},
			{
				"t": "selfVulnerable",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 16,
			},
			{
				"t": "selfVulnerable",
				"n": 1,
			},
		],
		"archetype": "deep",
	},
	"shoggoth_plate": {
		"id": "shoggoth_plate",
		"name": "ショゴスの粘液装甲",
		"type": "skill",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック10。粘液が混入する。",
		"upgradedText": "ブロック10。粘液が混入する。",
		"flavor": "",
		"art": "res://art/pixel/cards/shoggoth_plate.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "addCurse",
				"id": "slime",
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "addCurse",
				"id": "slime",
			},
		],
		"archetype": "outer",
	},
	"yith_shell": {
		"id": "yith_shell",
		"name": "イスの金属殻",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック18。手札1枚を残す。",
		"upgradedText": "ブロック18。手札1枚を残す。",
		"flavor": "",
		"art": "res://art/pixel/cards/yith_shell.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 18,
			},
			{
				"t": "retainCards",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 18,
			},
			{
				"t": "retainCards",
				"n": 1,
			},
		],
		"archetype": "outer",
	},
	"dagon_shield": {
		"id": "dagon_shield",
		"name": "ダゴンの儀式盾",
		"type": "skill",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック22。3回復。",
		"upgradedText": "ブロック22。3回復。",
		"flavor": "",
		"art": "res://art/pixel/cards/dagon_shield.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 22,
			},
			{
				"t": "heal",
				"n": 3,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 22,
			},
			{
				"t": "heal",
				"n": 3,
			},
		],
		"archetype": "deep",
	},
	"cthulhu_mail": {
		"id": "cthulhu_mail",
		"name": "クトゥルフの夢装甲",
		"type": "skill",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック30。睡眠が混入する。",
		"upgradedText": "ブロック30。睡眠が混入する。",
		"flavor": "",
		"art": "res://art/pixel/cards/cthulhu_mail.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 30,
			},
			{
				"t": "addCurse",
				"id": "sleep",
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 30,
			},
			{
				"t": "addCurse",
				"id": "sleep",
			},
		],
		"archetype": "greatold",
	},
	"tsathoggua_shield": {
		"id": "tsathoggua_shield",
		"name": "ツァトゥグァの怠惰盾",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック22。次のドロー-1。",
		"upgradedText": "ブロック22。次のドロー-1。",
		"flavor": "",
		"art": "res://art/pixel/cards/tsathoggua_shield.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 22,
			},
			{
				"t": "skipDraw",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 22,
			},
			{
				"t": "skipDraw",
				"n": 1,
			},
		],
		"archetype": "greatold",
	},
	"yog_gate": {
		"id": "yog_gate",
		"name": "ヨグ＝ソトースの門",
		"type": "skill",
		"cost": 3,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック45。廃棄。次ターンエネルギー-2。",
		"upgradedText": "ブロック45。廃棄。次ターンエネルギー-2。",
		"flavor": "",
		"art": "res://art/pixel/cards/yog_gate.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 45,
			},
			{
				"t": "energyNext",
				"n": -2,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 45,
			},
			{
				"t": "energyNext",
				"n": -2,
			},
		],
		"exhaust": true,
		"archetype": "outer",
	},
	"plateau_mail": {
		"id": "plateau_mail",
		"name": "狂気山脈の凍てつく鎧",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック35。毎ターン開始時1ダメージ。",
		"upgradedText": "ブロック35。毎ターン開始時1ダメージ。",
		"flavor": "",
		"art": "res://art/pixel/cards/plateau_mail.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 35,
			},
			{
				"t": "cold",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 35,
			},
			{
				"t": "cold",
				"n": 1,
			},
		],
		"archetype": "outer",
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
	"leather": {
		"id": "leather",
		"name": "革の鎧",
		"type": "skill",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック6。1枚引く。",
		"upgradedText": "ブロック6。1枚引く。",
		"flavor": "",
		"art": "res://art/pixel/cards/leather.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "draw",
				"n": 1,
			},
		],
	},
	"thief_cloak": {
		"id": "thief_cloak",
		"name": "盗賊のマント",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック10。無形1。",
		"upgradedText": "ブロック10。無形1。",
		"flavor": "",
		"art": "res://art/pixel/cards/thief_cloak.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "intangible",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "intangible",
				"n": 1,
			},
		],
		"archetype": "shadow",
	},
	"ghoul_rags": {
		"id": "ghoul_rags",
		"name": "食尸鬼のボロ布",
		"type": "skill",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック6。体力1失う。",
		"upgradedText": "ブロック6。体力1失う。",
		"flavor": "",
		"art": "res://art/pixel/cards/ghoul_rags.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "hpCost",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "hpCost",
				"n": 1,
			},
		],
	},
	"gaki_hide": {
		"id": "gaki_hide",
		"name": "妖鬼の皮鎧",
		"type": "skill",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック9。手札を1枚捨てる。",
		"upgradedText": "ブロック9。手札を1枚捨てる。",
		"flavor": "",
		"art": "res://art/pixel/cards/gaki_hide.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 9,
			},
			{
				"t": "discardRandom",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 9,
			},
			{
				"t": "discardRandom",
				"n": 1,
			},
		],
	},
	"yith_coat": {
		"id": "yith_coat",
		"name": "偉大なる種族の外套",
		"type": "skill",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック10。手札を2枚まで残す。",
		"upgradedText": "ブロック10。手札を2枚まで残す。",
		"flavor": "",
		"art": "res://art/pixel/cards/yith_coat.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "retainCards",
				"n": 2,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 10,
			},
			{
				"t": "retainCards",
				"n": 2,
			},
		],
		"archetype": "outer",
	},
	"penguin_fur": {
		"id": "penguin_fur",
		"name": "盲目のペンギンの毛皮",
		"type": "skill",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック6。敵を拘束する。",
		"upgradedText": "ブロック6。敵を拘束する。",
		"flavor": "",
		"art": "res://art/pixel/cards/penguin_fur.jpg",
		"target": "enemy",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "bind",
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 6,
			},
			{
				"t": "bind",
			},
		],
	},
	"yellow_rags": {
		"id": "yellow_rags",
		"name": "黄衣の王の襤褸",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック20。攻撃してきた敵に脆弱。",
		"upgradedText": "ブロック20。攻撃してきた敵に脆弱。",
		"flavor": "",
		"art": "res://art/pixel/cards/yellow_rags.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 20,
			},
			{
				"t": "thornsVulnerable",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 20,
			},
			{
				"t": "thornsVulnerable",
				"n": 1,
			},
		],
		"archetype": "shadow",
	},
	"nameless_veil": {
		"id": "nameless_veil",
		"name": "無貌の影衣",
		"type": "skill",
		"cost": 1,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック12。次ターン無形。呪いが混入。",
		"upgradedText": "ブロック12。次ターン無形。呪いが混入。",
		"flavor": "",
		"art": "res://art/pixel/cards/nameless_veil.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 12,
			},
			{
				"t": "intangible",
				"n": 1,
			},
			{
				"t": "addCurse",
				"id": "dread",
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 12,
			},
			{
				"t": "intangible",
				"n": 1,
			},
			{
				"t": "addCurse",
				"id": "dread",
			},
		],
		"archetype": "shadow",
	},
	"azathoth_nap": {
		"id": "azathoth_nap",
		"name": "アザトースの微睡み",
		"type": "skill",
		"cost": 0,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック15。50%でターン終了。",
		"upgradedText": "ブロック15。50%でターン終了。",
		"flavor": "",
		"art": "res://art/pixel/cards/azathoth_nap.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 15,
			},
			{
				"t": "endTurnMaybe",
				"p": 0.5,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 15,
			},
			{
				"t": "endTurnMaybe",
				"p": 0.5,
			},
		],
		"archetype": "outer",
	},
	"colour_robe": {
		"id": "colour_robe",
		"name": "宇宙の色彩の衣",
		"type": "skill",
		"cost": 2,
		"rarity": "rare",
		"owner": "shared",
		"text": "ブロック25。5回復。最大体力-1。",
		"upgradedText": "ブロック25。5回復。最大体力-1。",
		"flavor": "",
		"art": "res://art/pixel/cards/colour_robe.jpg",
		"target": "none",
		"shop": true,
		"effects": [
			{
				"t": "block",
				"n": 25,
			},
			{
				"t": "heal",
				"n": 5,
			},
			{
				"t": "loseMaxHp",
				"n": 1,
			},
		],
		"upgradedEffects": [
			{
				"t": "block",
				"n": 25,
			},
			{
				"t": "heal",
				"n": 5,
			},
			{
				"t": "loseMaxHp",
				"n": 1,
			},
		],
		"archetype": "outer",
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
}


const CARD_FRAME_CLASSES := [
	"frame-card-common",
	"frame-card-uncommon",
	"frame-card",
	"frame-card-greatold",
	"frame-card-elder",
	"frame-card-outer",
]

const _MYTHOS_FRAME_ARCHETYPES := ["greatold", "elder", "outer"]

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
	"precise",
	"tome",
	"deep_ones_blessing",
	"dressing",
	"adapted_scales",
	"deep_breath",
	"self_offering",
	"blood_toll",
	"self_poisoning",
	"sealing_moment",
]


## cards.ts getCard()
static func get_card(id: String) -> Dictionary:
	if not CARDS.has(id):
		push_error("Unknown card %s" % id)
		return {}
	var d: Dictionary = CARDS[id]
	var art: String = str(d.get("art", ""))
	var resolved: String = resolve_art(art)
	if resolved != art:
		var copy: Dictionary = d.duplicate()
		copy["art"] = resolved
		return copy
	return d


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
	return maxi(1, int(floor(float(n) * float(card.get("forge")))))


## cards.ts rewardPool()
static func reward_pool(owner: String) -> Array:
	var out: Array = []
	for c in CARDS.values():
		if c.get("rarity") == "starter" or c.get("rarity") == "status":
			continue
		if c.get("grimoire") or c.get("shop") or c.get("enemyOnly"):
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
		if c.get("rarity") == "starter" or c.get("rarity") == "status":
			continue
		if c.get("grimoire") or c.get("enemyOnly"):
			continue
		if c.get("owner") == "shared" or c.get("owner") == owner:
			out.append(c)
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
	var pool := archetype_card_pool(owner, archetype)
	var base_pool: Array = pool if not pool.is_empty() else reward_pool(owner)
	var candidates := _rarity_sliced_pool(base_pool, rand)
	var owned: Array = CollectionData.inventory.cards
	var def: Dictionary = Mulberry32.weighted_pick_by(candidates, func(c):
		var n := 0
		for o in owned:
			if str(o.get("base_card_id", "")) == str(c.get("id", "")):
				n += 1
		return 1.0 / (1.0 + float(n))
	, rand)
	return make_card(str(def.get("id", "")), false)
