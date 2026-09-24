class_name Runes
extends RefCounted

## src/game/runes.ts 相当。
## プレイヤー向けのルーン機能（入手・所持・ソケット）は削除済み。
## blessings.gd が参照する RUNE_CATALOG のみ残す。

## effect -> base value（blessings.gd の _apply_rune() が参照する）
const RUNE_CATALOG := {
	"BLK+": 2,
	"DRAW": 1,
	"SAN+": 3,
	"STR+": 1,
	"POISON": 2,
	"HEAL": 4,
	"VULN+": 1,
	"ENERGY+": 1,
	"THORN": 2,
}
