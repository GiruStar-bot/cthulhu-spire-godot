class_name Mulberry32
extends RefCounted

## src/game/rng.ts の mulberry32() を忠実に移植した決定的疑似乱数生成器。
## GDScriptのintは64bit符号付きのため、32bit符号なし乗算(JSのMath.imul相当)は
## 桁あふれを避けるため16bit分割で計算する。

var _state: int


func _init(seed_value: int) -> void:
	_state = seed_value & 0xFFFFFFFF


## mulberry32のnext()相当。[0, 1)の浮動小数を返す。
func next_float() -> float:
	_state = (_state + 0x6d2b79f5) & 0xFFFFFFFF
	var t: int = _state
	t = _imul32(t ^ (t >> 15), t | 1) & 0xFFFFFFFF
	t = (t ^ ((t + _imul32(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


## Math.imul(a, b) の下位32bit相当を64bit桁あふれ無しで計算する。
static func _imul32(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	var a_lo := a & 0xFFFF
	var a_hi := (a >> 16) & 0xFFFF
	var b_lo := b & 0xFFFF
	var b_hi := (b >> 16) & 0xFFFF
	var low := a_lo * b_lo
	var mid := (a_hi * b_lo + a_lo * b_hi) & 0xFFFFFFFF
	return (low + (mid << 16)) & 0xFFFFFFFF


## rng.ts の pick() 相当
static func pick(arr: Array, rng: Mulberry32):
	return arr[int(rng.next_float() * arr.size())]
