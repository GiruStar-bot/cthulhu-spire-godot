class_name SanityTiers
extends RefCounted

## 正気度の「低い状態」の段階（0〜3）を決める唯一の定義。
## 見た目（四隅の縁取り・目・彩度）と音（sanity_low_1〜3 の持続音）、
## VitalsHud のゲージ刻みの位置は、すべてここの値を読む。
## 値は maxSanity に対する割合。この割合「未満」になるとその段階に入る。
const THRESHOLDS: Array[float] = [0.50, 0.30, 0.15]
const MAX_TIER := 3


## sanity / max_sanity から段階を返す。0 = 通常、1〜3 = 低い状態（3 が最も深い）。
static func tier_for(sanity: int, max_sanity: int) -> int:
	if max_sanity <= 0:
		return 0
	var ratio: float = float(sanity) / float(max_sanity)
	var tier: int = 0
	for frac in THRESHOLDS:
		if ratio < frac:
			tier += 1
	return tier


## ゲージ刻み用：しきい値の割合（0〜1）をそのまま返す。
static func threshold_fractions() -> Array[float]:
	return THRESHOLDS.duplicate()
