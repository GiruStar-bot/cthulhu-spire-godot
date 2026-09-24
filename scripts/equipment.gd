class_name Equipment
extends RefCounted

## src/game/equipment.ts 相当。
## プレイヤー向けの装備機能（所持・着脱・UI）は削除済み。
## combat.gd が参照する数値計算ヘルパーのみ残す。

const MIN_CHIP_DAMAGE := 1


## equipment.ts の applyFlatDefense()
static func apply_flat_defense(damage: int, defense: float) -> int:
	if damage <= 0:
		return damage
	var reduced: float = damage - defense
	return max(MIN_CHIP_DAMAGE, int(round(reduced)))


## equipment.ts の applyFlatResist()
static func apply_flat_resist(amount: int, resist: float) -> int:
	if amount <= 0:
		return amount
	return max(0, int(round(amount - resist)))
