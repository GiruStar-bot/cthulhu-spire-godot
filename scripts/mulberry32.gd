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


## rng.ts の pick(arr, rng) 相当（Mulberry32 インスタンス版）
static func pick(arr: Array, rng: Mulberry32):
	return arr[int(rng.next_float() * arr.size())]


## rng.ts の pick(arr, rand: () => number)
static func pick_rand(arr: Array, rand: Callable):
	return arr[int(rand.call() * arr.size())]


## rng.ts の shuffle()
static func shuffle(arr: Array, rand: Callable) -> Array:
	var a: Array = arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := int(rand.call() * (i + 1))
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


## rng.ts の uid()
static func uid(prefix: String) -> String:
	var n := randi()
	var s := ""
	var alphabet := "0123456789abcdefghijklmnopqrstuvwxyz"
	if n == 0:
		s = "0"
	else:
		while n > 0 and s.length() < 7:
			s = alphabet[n % 36] + s
			n = int(n / 36)
	return "%s_%s" % [prefix, s]


## rng.ts の weightedPickBy(items, weight, rand)
static func weighted_pick_by(items: Array, weight_fn: Callable, rand: Callable):
	var weights: Array = []
	var total := 0.0
	for item in items:
		var w := float(weight_fn.call(item))
		weights.append(w)
		total += w
	if total <= 0.0:
		return items[int(rand.call() * items.size())]
	var roll: float = rand.call() * total
	for i in range(items.size()):
		if roll < float(weights[i]):
			return items[i]
		roll -= float(weights[i])
	return items[items.size() - 1]


## rng.ts の weightedPick()
static func weighted_pick(weights: Dictionary, rand: Callable):
	var entries: Array = weights.keys()
	var total := 0.0
	for k in entries:
		total += float(weights[k])
	if total <= 0.0:
		return entries[int(rand.call() * entries.size())]
	var roll: float = rand.call() * total
	for k in entries:
		var w := float(weights[k])
		if roll < w:
			return k
		roll -= w
	return entries[entries.size() - 1]
